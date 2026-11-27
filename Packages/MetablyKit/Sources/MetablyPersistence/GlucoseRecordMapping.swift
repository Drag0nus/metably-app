import Foundation
import MetablyDomain

/// Mapping between domain `GlucoseReading` values and SwiftData records.
/// Kept in one place so views and features never see persistence types.
enum GlucoseRecordMapping {
    static let entityType = "glucoseReading"

    static func makeRecords(
        for reading: GlucoseReading,
        deviceID: UUID
    ) -> (TimelineEventRecord, GlucoseReadingRecord) {
        let event = TimelineEventRecord(
            id: reading.id,
            kindRaw: EventKind.glucose.rawValue,
            startDate: reading.measuredAt,
            endDate: reading.measuredAt,
            timeZoneID: reading.timeZoneID,
            timeZoneIsInferred: reading.timeZoneIsInferred,
            localDay: reading.localDay.isoString,
            sourceRaw: reading.provenance.source.rawValue,
            providerID: reading.provenance.providerID,
            sourceDetail: reading.provenance.sourceDetail,
            externalID: reading.provenance.externalID,
            isUserVerified: reading.isUserVerified,
            note: reading.note,
            createdAt: reading.createdAt,
            modifiedAt: reading.modifiedAt,
            deletedAt: reading.deletedAt,
            version: reading.version,
            serverVersion: nil,
            originDeviceID: deviceID,
            lastModifiedDeviceID: deviceID,
            syncCategoryRaw: EventKind.glucose.syncCategory.rawValue,
            isHealthKitDerived: reading.provenance.source == .healthKit,
            schemaVersion: SyncEnvelope.currentSchemaVersion
        )
        let detail = GlucoseReadingRecord(
            valueMmolL: reading.concentration.millimolesPerLiter,
            enteredValue: reading.enteredValue,
            enteredUnitRaw: reading.enteredUnit.rawValue,
            contextRaw: reading.context.rawValue,
            specimenRaw: reading.specimen.rawValue,
            flagsRaw: reading.flags.rawValue,
            minutesAfterMeal: reading.minutesAfterMeal,
            deviceName: reading.provenance.deviceName,
            deviceSerialHash: reading.provenance.deviceSerialHash
        )
        return (event, detail)
    }

    /// Copies mutable domain fields onto existing records (identity and origin stay).
    static func apply(_ reading: GlucoseReading, to event: TimelineEventRecord, detail: GlucoseReadingRecord) {
        event.startDate = reading.measuredAt
        event.endDate = reading.measuredAt
        event.timeZoneID = reading.timeZoneID
        event.timeZoneIsInferred = reading.timeZoneIsInferred
        event.localDay = reading.localDay.isoString
        event.isUserVerified = reading.isUserVerified
        event.note = reading.note
        event.deletedAt = reading.deletedAt
        detail.valueMmolL = reading.concentration.millimolesPerLiter
        detail.enteredValue = reading.enteredValue
        detail.enteredUnitRaw = reading.enteredUnit.rawValue
        detail.contextRaw = reading.context.rawValue
        detail.specimenRaw = reading.specimen.rawValue
        detail.flagsRaw = reading.flags.rawValue
        detail.minutesAfterMeal = reading.minutesAfterMeal
    }

    static func makeReading(from event: TimelineEventRecord) throws(RepositoryError) -> GlucoseReading {
        guard let detail = event.glucose,
              let unit = GlucoseUnit(rawValue: detail.enteredUnitRaw),
              let context = GlucoseMeasurementContext(rawValue: detail.contextRaw),
              let specimen = GlucoseSpecimen(rawValue: detail.specimenRaw),
              let source = EventSource(rawValue: event.sourceRaw),
              let timeZone = TimeZone(identifier: event.timeZoneID)
        else { throw .corruptRecord }

        var reading = GlucoseReading(
            id: event.id,
            enteredValue: detail.enteredValue,
            enteredUnit: unit,
            context: context,
            specimen: specimen,
            flags: GlucoseReadingFlags(rawValue: detail.flagsRaw),
            minutesAfterMeal: detail.minutesAfterMeal,
            measuredAt: event.startDate,
            timeZone: timeZone,
            timeZoneIsInferred: event.timeZoneIsInferred,
            provenance: Provenance(
                source: source,
                providerID: event.providerID,
                sourceDetail: event.sourceDetail,
                deviceName: detail.deviceName,
                deviceSerialHash: detail.deviceSerialHash,
                externalID: event.externalID
            ),
            note: event.note,
            isUserVerified: event.isUserVerified,
            createdAt: event.createdAt,
            modifiedAt: event.modifiedAt,
            version: event.version,
            deletedAt: event.deletedAt
        )
        // Keep the canonical value exactly as stored rather than recomputing it.
        reading.concentration = GlucoseConcentration(millimolesPerLiter: detail.valueMmolL)
        return reading
    }
}
