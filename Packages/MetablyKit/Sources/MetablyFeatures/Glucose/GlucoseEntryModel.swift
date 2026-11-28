import Foundation
import MetablyDomain
import Observation

public enum RecheckReminderState: Sendable, Hashable {
    case notScheduled
    case scheduled(at: Date)
    /// Notifications are off or scheduling failed.
    case unavailable
}

/// What the meter showed: a number, or "LO"/"HI" when the value is outside its range.
public enum MeterDisplay: String, Sendable, Hashable, CaseIterable {
    case value
    case low
    case high

    var flags: GlucoseReadingFlags {
        switch self {
        case .value: []
        case .low: .meterLow
        case .high: .meterHigh
        }
    }

    /// Typical home meter limits, prefilled for "LO"/"HI" and editable (check your meter's manual).
    func typicalLimit(in unit: GlucoseUnit) -> Double? {
        switch (self, unit) {
        case (.value, _): nil
        case (.low, .millimolesPerLiter): 0.6
        case (.low, .milligramsPerDeciliter): 10
        case (.high, .millimolesPerLiter): 33.3
        case (.high, .milligramsPerDeciliter): 600
        }
    }
}

/// A meal the reading could be linked to, suggested from the times. Stored only if the user
/// switches the link on.
public struct MealLinkCandidate: Sendable, Hashable {
    public let meal: Meal
    public let relation: EventLinkRelation
    /// Signed minutes from meal start to the reading.
    public let minutesFromMealStart: Int
}

public enum GlucoseEntrySaveError: Error, Sendable, Hashable {
    case invalid(GlucoseEntryError)
    case duplicate
    case storage
}

/// State and logic of the glucose entry sheet: a new manual fingerstick reading, or editing
/// an existing one (`editing` is set).
///
/// `@Observable` makes SwiftUI re-render views that read a property when it changes;
/// the view binds to it with `@Bindable`. All logic lives here so it is unit-testable.
@Observable
@MainActor
public final class GlucoseEntryModel: Identifiable {
    public var valueText = ""
    public var unit: GlucoseUnit
    /// Diary column of the reading. Suggested from the time of day; the user can change it.
    public var slot: DiarySlot {
        didSet { if slot != oldValue { refreshMealCandidate() } }
    }
    public var measuredAt: Date {
        didSet { if measuredAt != oldValue { refreshMealCandidate() } }
    }
    /// The nearby meal suggested for a link, if any.
    public private(set) var mealCandidate: MealLinkCandidate?
    /// The user's confirmation of the link. Off for a suggestion until the user switches it on.
    public var linksToMeal = false
    public var note = ""
    /// "LO"/"HI" when the meter could not show a number. Switching prefills the meter limit.
    public var meterDisplay: MeterDisplay = .value {
        didSet {
            guard meterDisplay != oldValue, let limit = meterDisplay.typicalLimit(in: unit) else { return }
            valueText = Self.text(for: limit, unit: unit)
        }
    }
    /// Activity 1–5 at the time of the check. Preset to the user's last choice; tap again to clear.
    public var activityLevel: ActivityLevel?
    public private(set) var saveError: GlucoseEntrySaveError?
    /// Set when the value looks like a double entry; the view asks before saving again.
    public private(set) var likelyDuplicate: GlucoseReading?
    public private(set) var recheckReminder: RecheckReminderState = .notScheduled

    /// The slots offered on the entry sheet, in diary order.
    public let availableSlots: [DiarySlot]
    public let targets: GlucoseTargets
    /// The reading being edited, or nil for a new reading.
    public let editing: GlucoseReading?
    public var isEditing: Bool { editing != nil }

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
    @ObservationIgnored private let meals: (any MealRepository)?
    @ObservationIgnored private let links: (any EventLinkRepository)?
    @ObservationIgnored private var existingLink: EventLink?
    @ObservationIgnored private let linkSuggester = MealLinkSuggester()

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
        activityLevel: ActivityLevel? = nil,
        reminders: any RecheckReminderScheduling = NoopRecheckReminder(),
        meals: (any MealRepository)? = nil,
        links: (any EventLinkRepository)? = nil,
        editing: GlucoseReading? = nil
    ) {
        self.editing = editing
        self.meals = meals
        self.links = links
        self.repository = repository
        self.reminders = reminders
        self.unit = unit
        self.dateProvider = dateProvider
        self.timeZone = timeZone
        self.targets = targets
        self.activityLevel = activityLevel
        let now = dateProvider.now()
        self.measuredAt = now
        self.latestAllowedDate = now
        self.availableSlots = DiarySlot.profileSlots(includingNight: nightCheckEnabled) + [.other]
        self.slot = DiarySlot.suggested(
            atMinute: DailySchedule.minuteOfDay(now, in: timeZone),
            schedule: schedule,
            nightCheckEnabled: nightCheckEnabled
        )
        if let reading = editing {
            self.unit = reading.enteredUnit
            slot = reading.diarySlot(schedule: schedule)
            measuredAt = reading.measuredAt
            note = reading.note ?? ""
            self.activityLevel = reading.activityLevel
            if reading.flags.contains(.meterLow) {
                meterDisplay = .low
            } else if reading.flags.contains(.meterHigh) {
                meterDisplay = .high
            }
            // Set after `meterDisplay`, whose didSet prefills the typical meter limit.
            valueText = Self.text(for: reading.enteredValue, unit: reading.enteredUnit)
            existingLink = (try? links?.links(fromIDs: [reading.id]))?
                .first { $0.relation == .preMeal || $0.relation == .postMeal }
            linksToMeal = existingLink != nil
        }
        // Property observers do not run during init.
        refreshMealCandidate()
    }

    // MARK: - Meal link

    /// Finds the meal to offer: the already linked meal when editing, otherwise the best
    /// suggestion for the reading's time and slot.
    private func refreshMealCandidate() {
        guard let meals else { return }
        let previousMealID = mealCandidate?.meal.id
        if let link = existingLink, let meal = try? meals.meal(id: link.toID), !meal.isDeleted {
            mealCandidate = Self.candidate(meal: meal, readingAt: measuredAt)
            return
        }
        let nearby = (try? meals.meals(
            from: measuredAt.addingTimeInterval(-4 * 60 * 60),
            to: measuredAt.addingTimeInterval(2 * 60 * 60)
        )) ?? []
        // A reading after a meal needs an eaten meal; one before a meal may precede a planned one.
        let byID = Dictionary(nearby.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        mealCandidate = linkSuggester
            .suggestions(readingAt: measuredAt, context: context, meals: nearby.map(\.timeReference))
            .lazy
            .compactMap { suggestion -> MealLinkCandidate? in
                guard let meal = byID[suggestion.mealID],
                      suggestion.relation == .preMeal || meal.status == .eaten
                else { return nil }
                return MealLinkCandidate(meal: meal, relation: suggestion.relation, minutesFromMealStart: suggestion.minutesFromMealStart)
            }
            .first
        // A confirmation is for one meal: a different suggestion starts unconfirmed.
        if mealCandidate?.meal.id != previousMealID { linksToMeal = false }
    }

    static func candidate(meal: Meal, readingAt: Date) -> MealLinkCandidate {
        let minutes = Int((readingAt.timeIntervalSince(meal.startedAt) / 60).rounded())
        return MealLinkCandidate(meal: meal, relation: minutes < 0 ? .preMeal : .postMeal, minutesFromMealStart: minutes)
    }

    /// Writes the user's link choice for a saved reading. A failed link never fails the reading.
    private func applyMealLink(to reading: GlucoseReading) {
        guard let links else { return }
        let wanted = linksToMeal ? mealCandidate : nil
        if let existing = existingLink, existing.toID != wanted?.meal.id {
            try? links.softDelete(id: existing.id)
            existingLink = nil
        }
        if let wanted, existingLink == nil {
            let link = EventLink(
                fromID: reading.id,
                toID: wanted.meal.id,
                relation: wanted.relation,
                minutesFromMealStart: wanted.minutesFromMealStart,
                createdAt: dateProvider.now()
            )
            if (try? links.insert(link)) != nil { existingLink = link }
        }
    }

    /// Locale-aware text for a value, e.g. "6,4" in Ukrainian. Never built by string concatenation.
    static func text(for value: Double, unit: GlucoseUnit) -> String {
        value.formatted(.number.precision(.fractionLength(unit.fractionDigits)).grouping(.never))
    }

    /// Parses and validates the typed value. "LO"/"HI" values skip the plausibility bounds
    /// because they are the meter's own limit.
    private func validatedValue() -> Result<Double, GlucoseEntryError> {
        let trimmed = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let value = GlucoseValueParser.parse(trimmed) else { return .failure(.notANumber) }
        return validator.validate(value: value, unit: unit, flags: meterDisplay.flags)
    }

    /// Stored context of the reading, derived from the chosen slot.
    public var context: GlucoseMeasurementContext { slot.context }

    /// The typed value, when it parses and is plausible.
    public var parsedConcentration: GlucoseConcentration? {
        guard case .success(let value) = validatedValue() else { return nil }
        return GlucoseConcentration(value: value, unit: unit)
    }

    /// Live status of the typed value against the user's targets, shown before saving.
    public var previewStatus: GlucoseTargetStatus? {
        switch meterDisplay {
        case .low: return .below
        case .high: return .above
        case .value: break
        }
        return parsedConcentration.flatMap { targets.status(of: $0, context: context, comparedIn: unit) }
    }

    /// The typed value is below 3.9 mmol/L: the sheet shows the low-glucose guidance.
    public var showsLowGlucoseGuidance: Bool {
        if meterDisplay == .low { return true }
        return parsedConcentration.map { GlucoseTargets.isLow($0, comparedIn: unit) } ?? false
    }

    /// The first problem with the current input, if any.
    public var validationError: GlucoseEntryError? {
        if case .failure(let error) = validatedValue() { return error }
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
        switch validatedValue() {
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
            flags: meterDisplay.flags,
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
               among: existing.filter { $0.id != editing?.id }
           ) {
            likelyDuplicate = duplicate
            return nil
        }
        if let original = editing {
            return saveEdit(of: original, value: value)
        }
        do {
            var reading = try ingestor.makeReading(
                from: sample,
                providerID: ManualGlucoseProvider.providerID,
                providerKind: .manual,
                now: dateProvider.now()
            )
            reading.activityLevel = activityLevel
            try repository.insert(reading)
            applyMealLink(to: reading)
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

    /// Applies the edits to the stored reading. Identity, source and time zone stay; the
    /// repository keeps the previous values in the revision history.
    private func saveEdit(of original: GlucoseReading, value: Double) -> GlucoseReading? {
        if let error = validator.validate(measuredAt: measuredAt, now: dateProvider.now()) {
            saveError = .invalid(error)
            return nil
        }
        var updated = original
        updated.enteredValue = value
        updated.enteredUnit = unit
        updated.concentration = GlucoseConcentration(value: value, unit: unit)
        updated.context = context
        updated.flags = original.flags.subtracting([.meterLow, .meterHigh]).union(meterDisplay.flags)
        updated.measuredAt = measuredAt
        updated.localDay = LocalDay(instant: measuredAt, timeZone: original.timeZone)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmedNote.isEmpty ? nil : trimmedNote
        updated.activityLevel = activityLevel
        updated.isUserVerified = true
        do {
            try repository.update(updated)
            applyMealLink(to: updated)
            return try repository.reading(id: original.id) ?? updated
        } catch {
            saveError = .storage
            return nil
        }
    }

    /// Soft-deletes the reading being edited. Returns true on success.
    @discardableResult
    public func deleteEditedReading() -> Bool {
        guard let original = editing else { return false }
        do {
            try repository.softDelete(id: original.id)
            return true
        } catch {
            saveError = .storage
            return false
        }
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
