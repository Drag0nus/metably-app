import Foundation

/// Turns a provider sample into a validated `GlucoseReading` with full provenance.
/// Shared by manual entry and every future import path, so all sources obey the same rules.
public struct GlucoseSampleIngestor: Sendable {
    private let validator: GlucoseEntryValidator

    public init(validator: GlucoseEntryValidator = GlucoseEntryValidator()) {
        self.validator = validator
    }

    public func makeReading(
        from sample: GlucoseSample,
        providerID: String,
        providerKind: GlucoseProviderKind,
        now: Date,
        id: UUID = UUID()
    ) throws(GlucoseEntryError) -> GlucoseReading {
        if case .failure(let error) = validator.validate(value: sample.value, unit: sample.unit, flags: sample.flags) {
            throw error
        }
        if let error = validator.validate(measuredAt: sample.measuredAt, now: now) {
            throw error
        }
        let trimmedNote = sample.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GlucoseReading(
            id: id,
            enteredValue: sample.value,
            enteredUnit: sample.unit,
            context: sample.context ?? .random,
            specimen: sample.specimen,
            flags: sample.flags,
            measuredAt: sample.measuredAt,
            timeZone: sample.timeZone,
            timeZoneIsInferred: sample.timeZoneIsInferred,
            provenance: Provenance(
                source: providerKind.eventSource,
                providerID: providerID,
                sourceDetail: sample.sourceDetail,
                deviceName: sample.deviceName,
                deviceSerialHash: sample.deviceSerialHash,
                externalID: sample.externalID
            ),
            note: (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote,
            // Manual entries are verified by definition; imports need the user's confirmation.
            isUserVerified: providerKind == .manual,
            createdAt: now
        )
    }
}
