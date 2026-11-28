import Foundation
import MetablyDomain
import SwiftData
import Testing
@testable import MetablyPersistence

@MainActor
@Suite("Schema migration")
struct SchemaMigrationTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A V1 store opens as V2; existing readings keep their values and have no activity level")
    func v1ToV2() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "metably-migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Metably.store")
        let id = UUID()

        // 1. Write a reading with the frozen V1 models.
        do {
            let schema = Schema(versionedSchema: MetablySchemaV1.self)
            let configuration = ModelConfiguration("Metably", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let event = MetablySchemaV1.TimelineEventRecord(
                id: id, kindRaw: EventKind.glucose.rawValue, startDate: now, endDate: now,
                timeZoneID: "Europe/Kyiv", timeZoneIsInferred: false, localDay: "2027-01-15",
                sourceRaw: EventSource.manual.rawValue, providerID: "manual", sourceDetail: nil,
                externalID: nil, isUserVerified: true, note: nil, createdAt: now, modifiedAt: now,
                deletedAt: nil, version: 1, serverVersion: nil, originDeviceID: UUID(),
                lastModifiedDeviceID: UUID(), syncCategoryRaw: SyncCategory.glucose.rawValue,
                isHealthKitDerived: false, schemaVersion: 1
            )
            let detail = MetablySchemaV1.GlucoseReadingRecord(
                valueMmolL: 6.4, enteredValue: 6.4, enteredUnitRaw: GlucoseUnit.millimolesPerLiter.rawValue,
                contextRaw: GlucoseMeasurementContext.fasting.rawValue,
                specimenRaw: GlucoseSpecimen.capillary.rawValue, flagsRaw: 0, minutesAfterMeal: nil,
                deviceName: nil, deviceSerialHash: nil
            )
            context.insert(event)
            context.insert(detail)
            event.glucose = detail
            try context.save()
        }

        // 2. Open the same file through the app's container (current schema + migration plan).
        let container = try MetablyModelContainer.make(url: url)
        let repository = SwiftDataGlucoseRepository(context: container.mainContext, deviceID: UUID())
        let reading = try #require(try repository.reading(id: id))
        #expect(reading.enteredValue == 6.4)
        #expect(reading.context == .fasting)
        #expect(reading.activityLevel == nil)

        // 3. The migrated store accepts the new field.
        var edited = reading
        edited.activityLevel = ActivityLevel(rawValue: 4)
        try repository.update(edited)
        #expect(try repository.reading(id: id)?.activityLevel == ActivityLevel(rawValue: 4))
    }

    @Test("Activity level round-trips through the store")
    func activityRoundTrip() throws {
        let container = try MetablyModelContainer.make(inMemory: true)
        let repository = SwiftDataGlucoseRepository(context: container.mainContext, deviceID: UUID(), dateProvider: FixedDateProvider(now))
        let reading = GlucoseReading(
            enteredValue: 7.1, enteredUnit: .millimolesPerLiter, context: .afterMeal,
            activityLevel: ActivityLevel(rawValue: 2), measuredAt: now.addingTimeInterval(-60),
            timeZone: .gmt, provenance: .manual, createdAt: now
        )
        try repository.insert(reading)
        #expect(try repository.reading(id: reading.id) == reading)
    }
}
