import Foundation
import Testing
@testable import MetablyDomain

@Suite("Glucose ingestion")
struct GlucoseSampleIngestorTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!

    @Test("Manual samples become verified readings with full provenance")
    func manual() throws {
        let sample = GlucoseSample(
            value: 112, unit: .milligramsPerDeciliter, measuredAt: now.addingTimeInterval(-600),
            timeZone: kyiv, context: .fasting, note: "  after walk  "
        )
        let reading = try GlucoseSampleIngestor().makeReading(
            from: sample, providerID: ManualGlucoseProvider.providerID, providerKind: .manual, now: now
        )
        #expect(reading.enteredValue == 112)
        #expect(reading.enteredUnit == .milligramsPerDeciliter)
        #expect(abs(reading.concentration.millimolesPerLiter - 6.2167) < 0.0001)
        #expect(reading.context == .fasting)
        #expect(reading.specimen == .capillary)
        #expect(reading.provenance.source == .manual)
        #expect(reading.provenance.providerID == "manual")
        #expect(reading.isUserVerified)
        #expect(reading.note == "after walk")
        #expect(reading.timeZoneID == "Europe/Kyiv")
        #expect(reading.version == 1)
        #expect(reading.createdAt == now)
    }

    @Test("Imported samples keep external ids and need confirmation")
    func imported() throws {
        let sample = GlucoseSample(
            value: 7.2, unit: .millimolesPerLiter, measuredAt: now, timeZone: kyiv, timeZoneIsInferred: true,
            deviceName: "Meter", externalID: "HK-123", sourceDetail: "com.example.meter"
        )
        let reading = try GlucoseSampleIngestor().makeReading(
            from: sample, providerID: "healthkit", providerKind: .healthKit, now: now
        )
        #expect(reading.provenance.source == .healthKit)
        #expect(reading.provenance.externalID == "HK-123")
        #expect(reading.provenance.sourceDetail == "com.example.meter")
        #expect(reading.timeZoneIsInferred)
        #expect(reading.context == .random)
        #expect(!reading.isUserVerified)
    }

    @Test("Invalid samples are rejected with the validator's error")
    func invalid() {
        let sample = GlucoseSample(value: 80, unit: .millimolesPerLiter, measuredAt: now, timeZone: kyiv)
        #expect(throws: GlucoseEntryError.outOfPlausibleRange(lower: 0.5, upper: 35.0, unit: .millimolesPerLiter)) {
            try GlucoseSampleIngestor().makeReading(from: sample, providerID: "manual", providerKind: .manual, now: now)
        }
    }

    @Test("Manual provider is always available and pulls nothing")
    func manualProvider() async throws {
        let provider = ManualGlucoseProvider()
        #expect(await provider.isAvailable)
        #expect(try await provider.fetchSamples(since: nil).isEmpty)
        #expect(provider.kind.eventSource == .manual)
    }
}

@MainActor
@Suite("In-memory repository")
struct InMemoryGlucoseRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func reading(minutesAgo: Double, externalID: String? = nil) -> GlucoseReading {
        GlucoseReading(
            enteredValue: 6.0, enteredUnit: .millimolesPerLiter, context: .random,
            measuredAt: now.addingTimeInterval(-minutesAgo * 60), timeZone: .gmt,
            provenance: Provenance(source: .manual, providerID: "manual", externalID: externalID),
            createdAt: now
        )
    }

    @Test("Insert, list newest first, soft delete")
    func lifecycle() throws {
        let repository = InMemoryGlucoseRepository(dateProvider: FixedDateProvider(now))
        let older = reading(minutesAgo: 60)
        let newer = reading(minutesAgo: 5)
        try repository.insert(older)
        try repository.insert(newer)
        #expect(try repository.allReadings().map(\.id) == [newer.id, older.id])

        try repository.softDelete(id: older.id)
        #expect(try repository.allReadings().map(\.id) == [newer.id])
        #expect(try repository.reading(id: older.id)?.deletedAt == now)
        #expect(try repository.reading(id: older.id)?.version == 2)
    }

    @Test("Duplicate ids and external ids are rejected")
    func duplicates() throws {
        let repository = InMemoryGlucoseRepository()
        let first = reading(minutesAgo: 1, externalID: "X")
        try repository.insert(first)
        #expect(throws: RepositoryError.duplicateID) { try repository.insert(first) }
        #expect(throws: RepositoryError.duplicateExternalID) { try repository.insert(reading(minutesAgo: 2, externalID: "X")) }
    }
}
