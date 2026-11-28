import Foundation
import MetablyDomain
import Observation

/// State and logic of the meal entry sheet: a new meal (eaten or planned) or editing one.
@Observable
@MainActor
public final class MealEntryModel: Identifiable {
    /// One editable food row. Text fields stay text until saving so typing "1," is not lost.
    public struct ItemDraft: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var name: String
        public var amountText: String
        public var carbsText: String

        public init(id: UUID = UUID(), name: String = "", amountText: String = "", carbsText: String = "") {
            self.id = id
            self.name = name
            self.amountText = amountText
            self.carbsText = carbsText
        }

        var isBlank: Bool {
            name.trimmingCharacters(in: .whitespaces).isEmpty && amountText.isEmpty && carbsText.isEmpty
        }
    }

    public enum SaveError: Error, Sendable, Hashable {
        case invalid(MealValidationError)
        case unreadableNumber
        case storage
    }

    public var slot: MealSlot
    public var status: MealStatus
    public var startedAt: Date
    public var items: [ItemDraft]
    public var portionSize: PortionSize?
    public var note: String
    public private(set) var saveError: SaveError?

    public let editing: Meal?
    public var isEditing: Bool { editing != nil }
    public let breadUnits: BreadUnitConverter

    @ObservationIgnored private let repository: any MealRepository
    @ObservationIgnored private let dateProvider: any DateProvider
    @ObservationIgnored private let timeZone: TimeZone
    @ObservationIgnored private let validator = MealValidator()

    public init(
        repository: any MealRepository,
        dateProvider: any DateProvider = SystemDateProvider(),
        timeZone: TimeZone = .current,
        schedule: DailySchedule = .default,
        breadUnits: BreadUnitConverter = .standard,
        status: MealStatus = .eaten,
        editing: Meal? = nil
    ) {
        self.repository = repository
        self.dateProvider = dateProvider
        self.timeZone = timeZone
        self.breadUnits = breadUnits
        self.editing = editing
        let now = dateProvider.now()
        if let meal = editing {
            slot = meal.slot
            self.status = meal.status
            startedAt = meal.startedAt
            items = meal.items.map {
                ItemDraft(
                    id: $0.id,
                    name: $0.name,
                    amountText: $0.amountGrams.map(Self.text) ?? "",
                    carbsText: Self.text($0.carbohydrateGrams)
                )
            }
            portionSize = meal.portionSize
            note = meal.note ?? ""
        } else {
            slot = Self.suggestedSlot(atMinute: DailySchedule.minuteOfDay(now, in: timeZone), schedule: schedule)
            self.status = status
            startedAt = now
            items = [ItemDraft()]
            portionSize = nil
            note = ""
        }
    }

    /// The meal whose usual time is nearest; between meals, a snack.
    static func suggestedSlot(atMinute minute: Int, schedule: DailySchedule) -> MealSlot {
        let candidates: [(MealSlot, Int)] = [
            (.breakfast, schedule.breakfastMinute), (.lunch, schedule.lunchMinute), (.dinner, schedule.dinnerMinute),
        ]
        let nearest = candidates.min { abs($0.1 - minute) < abs($1.1 - minute) }
        guard let nearest, abs(nearest.1 - minute) <= 90 else { return .snack }
        return nearest.0
    }

    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    // MARK: - Items

    public func addItem() {
        items.append(ItemDraft())
    }

    public func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        if items.isEmpty { items = [ItemDraft()] }
    }

    // MARK: - Derived

    /// Items that would be saved, or nil when a number cannot be read.
    var parsedItems: [MealItem]? {
        var result: [MealItem] = []
        for draft in items where !draft.isBlank {
            let carbsText = draft.carbsText.trimmingCharacters(in: .whitespaces)
            let amountText = draft.amountText.trimmingCharacters(in: .whitespaces)
            guard let carbs = DecimalInputParser.parse(carbsText) else { return nil }
            var amount: Double?
            if !amountText.isEmpty {
                guard let parsed = DecimalInputParser.parse(amountText) else { return nil }
                amount = parsed
            }
            result.append(MealItem(
                id: draft.id,
                name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                amountGrams: amount,
                carbohydrateGrams: carbs
            ))
        }
        return result
    }

    /// Carbohydrates of the rows that can be read so far (live total while typing).
    public var totalCarbohydrateGrams: Double {
        items.compactMap { DecimalInputParser.parse($0.carbsText) }.reduce(0, +)
    }

    public var totalBreadUnits: Double { breadUnits.breadUnits(forCarbohydrateGrams: totalCarbohydrateGrams) }

    public var validationError: SaveError? {
        guard let parsed = parsedItems else { return .unreadableNumber }
        if let error = validator.validate(draftMeal(items: parsed)) { return .invalid(error) }
        return nil
    }

    public var canSave: Bool { validationError == nil }

    /// Eaten meals cannot be in the future; planned ones can.
    public var latestAllowedDate: Date? {
        status == .eaten ? dateProvider.now().addingTimeInterval(5 * 60) : nil
    }

    private func draftMeal(items: [MealItem]) -> Meal {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        // A meal switched from planned to eaten cannot keep a time in the future.
        var startedAt = startedAt
        if let latest = latestAllowedDate, startedAt > latest { startedAt = dateProvider.now() }
        if var meal = editing {
            meal.slot = slot
            meal.status = status
            meal.startedAt = startedAt
            meal.localDay = LocalDay(instant: startedAt, timeZone: meal.timeZone)
            meal.items = items
            meal.portionSize = portionSize
            meal.note = trimmedNote.isEmpty ? nil : trimmedNote
            return meal
        }
        return Meal(
            slot: slot,
            status: status,
            startedAt: startedAt,
            timeZone: timeZone,
            items: items,
            portionSize: portionSize,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            createdAt: dateProvider.now()
        )
    }

    // MARK: - Actions

    @discardableResult
    public func save() -> Meal? {
        saveError = nil
        guard let parsed = parsedItems else {
            saveError = .unreadableNumber
            return nil
        }
        let meal = draftMeal(items: parsed)
        if let error = validator.validate(meal) {
            saveError = .invalid(error)
            return nil
        }
        do {
            if isEditing {
                try repository.update(meal)
                return try repository.meal(id: meal.id) ?? meal
            }
            try repository.insert(meal)
            return meal
        } catch {
            saveError = .storage
            return nil
        }
    }

    @discardableResult
    public func delete() -> Bool {
        guard let meal = editing else { return false }
        do {
            try repository.softDelete(id: meal.id)
            return true
        } catch {
            saveError = .storage
            return false
        }
    }
}
