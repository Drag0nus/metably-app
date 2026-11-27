import Foundation
import MetablyDomain
import SwiftData
import Testing
@testable import MetablyPersistence

@MainActor
@Suite("SwiftData glucose repository")
struct SwiftDataGlucoseRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let deviceID = UUID()
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!

    func makeRepository() throws -> (SwiftDataGlucoseRepository, ModelContainer) {
        let container = try MetablyModelContainer.make(inMemory: true)
        let repository = SwiftDataGlucoseRepository(
            context: container.mainContext, deviceID: deviceID, dateProvider: FixedDateProvider(now)
        )
        return (repository, container)
    }

    func makeReading(value: Double = 112, unit: GlucoseUnit = .milligramsPerDeciliter, minutesAgo: Double = 10, externalID: String? = nil) -> GlucoseReading {
        GlucoseReading(
            enteredValue: value, enteredUnit: unit, context: .fasting, flags: [],
            measuredAt: now.addingTimeInterval(-minutesAgo * 60), timeZone: kyiv,
            provenance: Provenance(source: .manual, providerID: "manual", deviceName: "Meter", externalID: externalID),
            note: "synthetic", createdAt: now
        )
    }

    @Test("A saved reading round-trips without losing entered value, unit, zone or provenance")
    func roundTrip() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let reading = makeReading()
        try repository.insert(reading)

        let loaded = try #require(try repository.reading(id: reading.id))
        #expect(loaded == reading)
        #expect(loaded.enteredValue == 112)
        #expect(loaded.enteredUnit == .milligramsPerDeciliter)
        #expect(loaded.timeZoneID == "Europe/Kyiv")
        #expect(loaded.provenance.deviceName == "Meter")
    }

    @Test("Insert writes a create revision and one outbox entry in the same save")
    func outboxOnInsert() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let reading = makeReading()
        try repository.insert(reading)

        let revisions = try repository.revisions(for: reading.id)
        #expect(revisions.map(\.changeKindRaw) == ["create"])
        #expect(revisions.first?.previousValues == nil)

        let outbox = try repository.pendingOutboxEntries()
        #expect(outbox.count == 1)
        #expect(outbox.first?.operationRaw == "upsert")
        #expect(outbox.first?.baseVersion == 0)

        let envelope = try JSONDecoder.metably.decode(SyncEnvelope.self, from: try #require(outbox.first?.envelope))
        #expect(envelope.recordID == reading.id)
        #expect(envelope.category == .glucose)
        #expect(envelope.deviceID == deviceID)
        #expect(envelope.version == 1)
        #expect(!envelope.isHealthKitDerived)
    }

    @Test("Update bumps the version, keeps the previous value in history and coalesces the outbox")
    func update() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let original = makeReading(value: 112)
        try repository.insert(original)

        var edited = original
        edited.enteredValue = 121
        edited.concentration = GlucoseConcentration(value: 121, unit: .milligramsPerDeciliter)
        try repository.update(edited)

        let loaded = try #require(try repository.reading(id: original.id))
        #expect(loaded.enteredValue == 121)
        #expect(loaded.version == 2)

        let revisions = try repository.revisions(for: original.id)
        #expect(revisions.map(\.changeKindRaw) == ["create", "update"])
        let previous = try JSONDecoder.metably.decode(GlucoseReading.self, from: try #require(revisions.last?.previousValues))
        #expect(previous.enteredValue == 112)

        #expect(try repository.pendingOutboxEntries().count == 1)
    }

    @Test("Soft delete keeps a tombstone, hides the reading and queues a delete")
    func softDelete() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let reading = makeReading()
        try repository.insert(reading)
        try repository.softDelete(id: reading.id)

        #expect(try repository.allReadings().isEmpty)
        let tombstone = try #require(try repository.reading(id: reading.id))
        #expect(tombstone.deletedAt == now)
        #expect(tombstone.version == 2)
        #expect(try repository.pendingOutboxEntries().first?.operationRaw == "delete")

        // Deleting twice is a no-op.
        try repository.softDelete(id: reading.id)
        #expect(try repository.revisions(for: reading.id).count == 2)
    }

    @Test("Date range queries are half-open and sorted newest first")
    func rangeQuery() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let a = makeReading(minutesAgo: 30)
        let b = makeReading(minutesAgo: 20)
        let c = makeReading(minutesAgo: 10)
        for reading in [a, b, c] { try repository.insert(reading) }

        let result = try repository.readings(from: a.measuredAt, to: c.measuredAt)
        #expect(result.map(\.id) == [b.id, a.id])
    }

    @Test("Duplicates by id or by external id are rejected and nothing is written")
    func duplicates() throws {
        let (repository, container) = try makeRepository()
        _ = container
        let reading = makeReading(externalID: "HK-1")
        try repository.insert(reading)
        #expect(throws: RepositoryError.duplicateID) { try repository.insert(reading) }
        #expect(throws: RepositoryError.duplicateExternalID) { try repository.insert(makeReading(externalID: "HK-1")) }
        #expect(try repository.allReadings().count == 1)
        #expect(try repository.pendingOutboxEntries().count == 1)
    }

    @Test("Updating or deleting a missing reading throws notFound")
    func notFound() throws {
        let (repository, container) = try makeRepository()
        _ = container
        #expect(throws: RepositoryError.notFound) { try repository.update(makeReading()) }
        #expect(throws: RepositoryError.notFound) { try repository.softDelete(id: UUID()) }
    }
}

extension JSONDecoder {
    static var metably: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
