import Foundation
import MetablyDomain
import Observation

public enum GlucoseEntrySaveError: Error, Sendable, Hashable {
    case invalid(GlucoseEntryError)
    case duplicate
    case storage
}

/// State and logic of the quick glucose entry screen (manual fingerstick reading).
///
/// `@Observable` makes SwiftUI re-render views that read a property when it changes;
/// the view binds to it with `@Bindable`. All logic lives here so it is unit-testable.
@Observable
@MainActor
public final class GlucoseEntryModel: Identifiable {
    public var valueText = ""
    public var unit: GlucoseUnit
    public var context: GlucoseMeasurementContext = .random
    public var measuredAt: Date
    public var note = ""
    public private(set) var saveError: GlucoseEntrySaveError?

    /// Latest time the picker allows (entries in the future are rejected).
    public let latestAllowedDate: Date

    @ObservationIgnored private let repository: any GlucoseRepository
    @ObservationIgnored private let dateProvider: any DateProvider
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let validator = GlucoseEntryValidator()
    @ObservationIgnored private let ingestor = GlucoseSampleIngestor()

    public init(
        repository: any GlucoseRepository,
        unit: GlucoseUnit,
        dateProvider: any DateProvider = SystemDateProvider(),
        timeZone: TimeZone = .current
    ) {
        self.repository = repository
        self.unit = unit
        self.dateProvider = dateProvider
        self.timeZone = timeZone
        let now = dateProvider.now()
        self.measuredAt = now
        self.latestAllowedDate = now
    }

    /// The first problem with the current input, if any.
    public var validationError: GlucoseEntryError? {
        if case .failure(let error) = validator.validate(text: valueText, unit: unit) { return error }
        return validator.validate(measuredAt: measuredAt, now: dateProvider.now())
    }

    /// Do not nag while the field is still empty; show problems once the user typed something.
    public var visibleValidationError: GlucoseEntryError? {
        valueText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : validationError
    }

    public var canSave: Bool { validationError == nil }

    /// Validates, builds the reading through the shared ingestion path and stores it.
    /// Returns the saved reading, or nil and sets `saveError`.
    @discardableResult
    public func save() -> GlucoseReading? {
        saveError = nil
        let value: Double
        switch validator.validate(text: valueText, unit: unit) {
        case .success(let parsed): value = parsed
        case .failure(let error):
            saveError = .invalid(error)
            return nil
        }
        let sample = GlucoseSample(
            value: value,
            unit: unit,
            measuredAt: measuredAt,
            timeZone: timeZone,
            context: context,
            specimen: .capillary,
            note: note
        )
        do {
            let reading = try ingestor.makeReading(
                from: sample,
                providerID: ManualGlucoseProvider.providerID,
                providerKind: .manual,
                now: dateProvider.now()
            )
            try repository.insert(reading)
            return reading
        } catch let error as GlucoseEntryError {
            saveError = .invalid(error)
        } catch RepositoryError.duplicateID, RepositoryError.duplicateExternalID {
            saveError = .duplicate
        } catch {
            saveError = .storage
        }
        return nil
    }
}
