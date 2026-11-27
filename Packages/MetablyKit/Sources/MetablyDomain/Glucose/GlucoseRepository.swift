import Foundation

public enum RepositoryError: Error, Sendable, Hashable {
    case duplicateID
    case duplicateExternalID
    case notFound
    /// A stored record could not be mapped back to the domain (e.g. unknown enum raw value).
    case corruptRecord
}

/// Storage abstraction for glucose readings. Features depend on this protocol only, so the
/// SwiftData implementation can be swapped (or faked in tests and previews).
///
/// Isolated to the main actor because SwiftData's `mainContext` is main-actor bound.
@MainActor
public protocol GlucoseRepository: AnyObject {
    /// Inserts a new reading. Throws `duplicateID` or `duplicateExternalID`.
    func insert(_ reading: GlucoseReading) throws
    /// Replaces an existing reading, increments its version and records a revision.
    func update(_ reading: GlucoseReading) throws
    /// Marks a reading deleted (tombstone). The record stays for history and sync.
    func softDelete(id: UUID) throws
    func reading(id: UUID) throws -> GlucoseReading?
    func reading(externalID: String, providerID: String) throws -> GlucoseReading?
    /// Non-deleted readings with `from <= measuredAt < to`, newest first.
    func readings(from: Date, to: Date) throws -> [GlucoseReading]
    /// All non-deleted readings, newest first.
    func allReadings() throws -> [GlucoseReading]
}

/// Simple in-memory repository for previews and unit tests of features.
@MainActor
public final class InMemoryGlucoseRepository: GlucoseRepository {
    public private(set) var storage: [UUID: GlucoseReading] = [:]
    private let dateProvider: any DateProvider

    public init(readings: [GlucoseReading] = [], dateProvider: any DateProvider = SystemDateProvider()) {
        self.dateProvider = dateProvider
        for reading in readings { storage[reading.id] = reading }
    }

    public func insert(_ reading: GlucoseReading) throws {
        guard storage[reading.id] == nil else { throw RepositoryError.duplicateID }
        if let externalID = reading.provenance.externalID,
           try self.reading(externalID: externalID, providerID: reading.provenance.providerID) != nil {
            throw RepositoryError.duplicateExternalID
        }
        storage[reading.id] = reading
    }

    public func update(_ reading: GlucoseReading) throws {
        guard let existing = storage[reading.id] else { throw RepositoryError.notFound }
        var updated = reading
        updated.version = existing.version + 1
        updated.modifiedAt = dateProvider.now()
        storage[reading.id] = updated
    }

    public func softDelete(id: UUID) throws {
        guard var existing = storage[id] else { throw RepositoryError.notFound }
        guard existing.deletedAt == nil else { return }
        let now = dateProvider.now()
        existing.deletedAt = now
        existing.modifiedAt = now
        existing.version += 1
        storage[id] = existing
    }

    public func reading(id: UUID) throws -> GlucoseReading? { storage[id] }

    public func reading(externalID: String, providerID: String) throws -> GlucoseReading? {
        storage.values.first {
            $0.provenance.externalID == externalID && $0.provenance.providerID == providerID
        }
    }

    public func readings(from: Date, to: Date) throws -> [GlucoseReading] {
        try allReadings().filter { $0.measuredAt >= from && $0.measuredAt < to }
    }

    public func allReadings() throws -> [GlucoseReading] {
        storage.values
            .filter { !$0.isDeleted }
            .sorted { $0.measuredAt > $1.measuredAt }
    }
}
