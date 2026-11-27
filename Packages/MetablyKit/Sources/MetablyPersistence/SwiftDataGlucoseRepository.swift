import Foundation
import MetablyDomain
import OSLog
import SwiftData

/// SwiftData-backed `GlucoseRepository`.
///
/// Every change saves, in one transaction: the record, an append-only revision, and a
/// coalesced outbox entry for future sync. If any part fails, the whole change is rolled back.
///
/// Logging rule: never log measurement values, notes or identifiers. Only error types.
@MainActor
public final class SwiftDataGlucoseRepository: GlucoseRepository {
    private let context: ModelContext
    private let deviceID: UUID
    private let dateProvider: any DateProvider
    private let encoder: JSONEncoder
    private static let logger = Logger(subsystem: "app.metably", category: "persistence")

    public init(context: ModelContext, deviceID: UUID, dateProvider: any DateProvider = SystemDateProvider()) {
        self.context = context
        self.deviceID = deviceID
        self.dateProvider = dateProvider
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    // MARK: - Writes

    public func insert(_ reading: GlucoseReading) throws {
        guard try fetchEvent(id: reading.id) == nil else { throw RepositoryError.duplicateID }
        if let externalID = reading.provenance.externalID,
           try fetchEvent(externalID: externalID, providerID: reading.provenance.providerID) != nil {
            throw RepositoryError.duplicateExternalID
        }
        try transaction {
            let (event, detail) = GlucoseRecordMapping.makeRecords(for: reading, deviceID: deviceID)
            context.insert(event)
            context.insert(detail)
            event.glucose = detail
            appendRevision(for: event, kind: .create, previous: nil)
            try enqueue(event: event, reading: reading, operation: .upsert)
        }
    }

    public func update(_ reading: GlucoseReading) throws {
        guard let event = try fetchEvent(id: reading.id), let detail = event.glucose else {
            throw RepositoryError.notFound
        }
        let previous = try GlucoseRecordMapping.makeReading(from: event)
        try transaction {
            GlucoseRecordMapping.apply(reading, to: event, detail: detail)
            touch(event)
            appendRevision(for: event, kind: .update, previous: previous)
            try enqueue(event: event, reading: try GlucoseRecordMapping.makeReading(from: event), operation: .upsert)
        }
    }

    public func softDelete(id: UUID) throws {
        guard let event = try fetchEvent(id: id) else { throw RepositoryError.notFound }
        guard event.deletedAt == nil else { return }
        let previous = try GlucoseRecordMapping.makeReading(from: event)
        try transaction {
            event.deletedAt = dateProvider.now()
            touch(event)
            appendRevision(for: event, kind: .delete, previous: previous)
            try enqueue(event: event, reading: try GlucoseRecordMapping.makeReading(from: event), operation: .delete)
        }
    }

    // MARK: - Reads

    public func reading(id: UUID) throws -> GlucoseReading? {
        try fetchEvent(id: id).map { try GlucoseRecordMapping.makeReading(from: $0) }
    }

    public func reading(externalID: String, providerID: String) throws -> GlucoseReading? {
        try fetchEvent(externalID: externalID, providerID: providerID)
            .map { try GlucoseRecordMapping.makeReading(from: $0) }
    }

    public func readings(from: Date, to: Date) throws -> [GlucoseReading] {
        let kind = EventKind.glucose.rawValue
        let predicate = #Predicate<TimelineEventRecord> {
            $0.kindRaw == kind && $0.deletedAt == nil && $0.startDate >= from && $0.startDate < to
        }
        return try fetchReadings(predicate)
    }

    public func allReadings() throws -> [GlucoseReading] {
        let kind = EventKind.glucose.rawValue
        let predicate = #Predicate<TimelineEventRecord> { $0.kindRaw == kind && $0.deletedAt == nil }
        return try fetchReadings(predicate)
    }

    // MARK: - Sync inspection (used by tests and the future sync engine)

    public func pendingOutboxEntries() throws -> [OutboxEntryRecord] {
        try context.fetch(FetchDescriptor<OutboxEntryRecord>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    public func revisions(for recordID: UUID) throws -> [RecordRevisionRecord] {
        let predicate = #Predicate<RecordRevisionRecord> { $0.recordID == recordID }
        return try context.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.version)]))
    }

    // MARK: - Private

    private func fetchReadings(_ predicate: Predicate<TimelineEventRecord>) throws -> [GlucoseReading] {
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return try context.fetch(descriptor).map { try GlucoseRecordMapping.makeReading(from: $0) }
    }

    private func fetchEvent(id: UUID) throws -> TimelineEventRecord? {
        var descriptor = FetchDescriptor<TimelineEventRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchEvent(externalID: String, providerID: String) throws -> TimelineEventRecord? {
        // Compare Optional to Optional: #Predicate needs both sides to have the same type.
        let wantedExternalID: String? = externalID
        let predicate = #Predicate<TimelineEventRecord> {
            $0.externalID == wantedExternalID && $0.providerID == providerID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func touch(_ event: TimelineEventRecord) {
        event.version += 1
        event.modifiedAt = dateProvider.now()
        event.lastModifiedDeviceID = deviceID
    }

    private func appendRevision(for event: TimelineEventRecord, kind: RevisionChangeKind, previous: GlucoseReading?) {
        let snapshot = previous.flatMap { try? encoder.encode($0) }
        context.insert(RecordRevisionRecord(
            recordID: event.id,
            entityType: GlucoseRecordMapping.entityType,
            version: event.version,
            changedAt: dateProvider.now(),
            deviceID: deviceID,
            changeKindRaw: kind.rawValue,
            previousValues: snapshot
        ))
    }

    private func enqueue(event: TimelineEventRecord, reading: GlucoseReading, operation: SyncOperation) throws {
        let envelope = SyncEnvelope(
            recordID: event.id,
            entityType: GlucoseRecordMapping.entityType,
            category: SyncCategory(rawValue: event.syncCategoryRaw) ?? .glucose,
            operation: operation,
            baseVersion: event.serverVersion ?? 0,
            version: event.version,
            schemaVersion: event.schemaVersion,
            deviceID: deviceID,
            isHealthKitDerived: event.isHealthKitDerived,
            payload: try encoder.encode(reading)
        )
        let data = try encoder.encode(envelope)
        let recordID = event.id
        let existing = try context.fetch(FetchDescriptor<OutboxEntryRecord>(predicate: #Predicate { $0.recordID == recordID }))
        if let pending = existing.first {
            // Coalesce: one pending entry per record carries the latest state.
            pending.operationRaw = operation.rawValue
            pending.envelope = data
        } else {
            context.insert(OutboxEntryRecord(
                recordID: recordID,
                entityType: GlucoseRecordMapping.entityType,
                operationRaw: operation.rawValue,
                baseVersion: event.serverVersion ?? 0,
                envelope: data,
                createdAt: dateProvider.now(),
                nextAttemptAt: dateProvider.now()
            ))
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        do {
            try body()
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Glucose repository write failed: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
    }
}
