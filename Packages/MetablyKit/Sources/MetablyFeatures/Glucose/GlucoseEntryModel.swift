import Foundation
import MetablyDomain
import Observation

public enum RecheckReminderState: Sendable, Hashable {
    case notScheduled
    case scheduled(at: Date)
    /// Notifications are off or scheduling failed.
    case unavailable
}

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
    /// Diary column of the reading. Suggested from the time of day; the user can change it.
    public var slot: DiarySlot
    public var measuredAt: Date
    public var note = ""
    public private(set) var saveError: GlucoseEntrySaveError?
    /// Set when the value looks like a double entry; the view asks before saving again.
    public private(set) var likelyDuplicate: GlucoseReading?
    public private(set) var recheckReminder: RecheckReminderState = .notScheduled

    /// The slots offered on the entry sheet, in diary order.
    public let availableSlots: [DiarySlot]
    public let targets: GlucoseTargets

    /// Latest time the picker allows (entries in the future are rejected).
    public let latestAllowedDate: Date

    @ObservationIgnored private let repository: any GlucoseRepository
    @ObservationIgnored private let dateProvider: any DateProvider
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let validator = GlucoseEntryValidator()
    @ObservationIgnored private let ingestor = GlucoseSampleIngestor()
    @ObservationIgnored private let duplicateDetector = DuplicateReadingDetector()
    @ObservationIgnored private var duplicateConfirmed = false
    @ObservationIgnored private let reminders: any RecheckReminderScheduling

    /// General rule for re-checking after a low reading (ADA Standards of Care, section 6).
    public static let recheckInterval: TimeInterval = 15 * 60

    public init(
        repository: any GlucoseRepository,
        unit: GlucoseUnit,
        dateProvider: any DateProvider = SystemDateProvider(),
        timeZone: TimeZone = .current,
        targets: GlucoseTargets = .adaDefaults,
        schedule: DailySchedule = .default,
        nightCheckEnabled: Bool = false,
        reminders: any RecheckReminderScheduling = NoopRecheckReminder()
    ) {
        self.repository = repository
        self.reminders = reminders
        self.unit = unit
        self.dateProvider = dateProvider
        self.timeZone = timeZone
        self.targets = targets
        let now = dateProvider.now()
        self.measuredAt = now
        self.latestAllowedDate = now
        self.availableSlots = DiarySlot.profileSlots(includingNight: nightCheckEnabled) + [.other]
        self.slot = DiarySlot.suggested(
            atMinute: DailySchedule.minuteOfDay(now, in: timeZone),
            schedule: schedule,
            nightCheckEnabled: nightCheckEnabled
        )
    }

    /// Stored context of the reading, derived from the chosen slot.
    public var context: GlucoseMeasurementContext { slot.context }

    /// The typed value, when it parses and is plausible.
    public var parsedConcentration: GlucoseConcentration? {
        guard case .success(let value) = validator.validate(text: valueText, unit: unit) else { return nil }
        return GlucoseConcentration(value: value, unit: unit)
    }

    /// Live status of the typed value against the user's targets, shown before saving.
    public var previewStatus: GlucoseTargetStatus? {
        parsedConcentration.flatMap { targets.status(of: $0, context: context, comparedIn: unit) }
    }

    /// The typed value is below 3.9 mmol/L: the sheet shows the low-glucose guidance.
    public var showsLowGlucoseGuidance: Bool {
        parsedConcentration.map { GlucoseTargets.isLow($0, comparedIn: unit) } ?? false
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
        likelyDuplicate = nil
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
        if !duplicateConfirmed,
           let existing = try? repository.readings(
               from: measuredAt.addingTimeInterval(-DuplicateReadingDetector.window),
               to: measuredAt.addingTimeInterval(DuplicateReadingDetector.window + 1)
           ),
           let duplicate = duplicateDetector.likelyDuplicate(
               of: GlucoseConcentration(value: value, unit: unit),
               at: measuredAt,
               among: existing
           ) {
            likelyDuplicate = duplicate
            return nil
        }
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

    /// Schedules a local reminder to re-check in 15 minutes.
    public func scheduleRecheckReminder() {
        let fireDate = dateProvider.now().addingTimeInterval(Self.recheckInterval)
        // The model is main-actor isolated (so it is Sendable); the callback may arrive on any
        // thread, so it hops back to the main actor before touching state.
        reminders.scheduleRecheck(in: Self.recheckInterval) { scheduled in
            Task { @MainActor in
                self.recheckReminder = scheduled ? .scheduled(at: fireDate) : .unavailable
            }
        }
    }

    /// The user confirmed that the similar reading is a separate measurement.
    @discardableResult
    public func saveDespiteDuplicate() -> GlucoseReading? {
        duplicateConfirmed = true
        return save()
    }

    public func dismissDuplicateWarning() {
        likelyDuplicate = nil
    }
}
