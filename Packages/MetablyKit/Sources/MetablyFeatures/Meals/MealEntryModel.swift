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
        /// Typed values of the nutrients the user tracks (see `trackedNutrients`).
        public var nutrientTexts: [Nutrient: String]
        /// The catalog food the values come from; nil for a food typed by hand.
        public private(set) var food: Food?
        /// A household measure of `food`; nil means the amount is typed in grams.
        public private(set) var portion: Food.Portion?
        /// How many portions, e.g. "2" eggs. Used only with a portion.
        public private(set) var quantityText: String
        /// The user unlinked the catalog food, so its stored values must not stay.
        public private(set) var didClearFood = false

        public init(
            id: UUID = UUID(),
            name: String = "",
            amountText: String = "",
            carbsText: String = "",
            nutrientTexts: [Nutrient: String] = [:],
            food: Food? = nil
        ) {
            self.id = id
            self.name = name
            self.amountText = amountText
            self.carbsText = carbsText
            self.nutrientTexts = nutrientTexts
            self.food = food
            self.portion = nil
            self.quantityText = "1"
        }

        // MARK: Catalog food

        /// Fills the row from a catalog food: its name, its first household measure (or 100 g),
        /// and every value computed from that amount.
        public mutating func select(_ food: Food, trackedNutrients: [Nutrient]) {
            self.food = food
            didClearFood = true
            name = food.localizedName
            portion = food.portions.first
            quantityText = "1"
            if portion == nil { amountText = MealEntryModel.text(100) }
            recalculate(trackedNutrients: trackedNutrients)
        }

        /// Back to a food typed by hand; the typed values stay as they are.
        public mutating func clearFood() {
            didClearFood = true
            food = nil
            portion = nil
            quantityText = "1"
        }

        /// nil switches to grams, keeping the current weight.
        public mutating func setPortion(_ portion: Food.Portion?, trackedNutrients: [Nutrient]) {
            self.portion = portion
            if portion != nil { quantityText = "1" }
            recalculate(trackedNutrients: trackedNutrients)
        }

        public mutating func setQuantityText(_ text: String, trackedNutrients: [Nutrient]) {
            quantityText = text
            recalculate(trackedNutrients: trackedNutrients)
        }

        /// The weight typed in grams; with a catalog food the values follow it.
        public mutating func setAmountText(_ text: String, trackedNutrients: [Nutrient]) {
            amountText = text
            if food != nil, portion == nil { recalculate(trackedNutrients: trackedNutrients) }
        }

        /// Carbohydrates and tracked nutrients from the catalog for the current amount.
        /// Typed carbs are overwritten only here, when the amount or food changes.
        mutating func recalculate(trackedNutrients: [Nutrient]) {
            guard let food else { return }
            if let portion {
                guard let quantity = DecimalInputParser.parse(quantityText.trimmingCharacters(in: .whitespaces)),
                      quantity > 0
                else { return }
                amountText = MealEntryModel.text(Food.round(quantity * portion.grams))
            }
            guard let grams = DecimalInputParser.parse(amountText.trimmingCharacters(in: .whitespaces)) else { return }
            let item = food.mealItem(grams: grams, name: name, id: id)
            carbsText = MealEntryModel.text(item.carbohydrateGrams)
            for nutrient in trackedNutrients {
                nutrientTexts[nutrient] = item[keyPath: nutrient.keyPath].map(MealEntryModel.text) ?? ""
            }
        }

        /// Grams per portion for display, e.g. "= 100 g".
        public var computedGrams: Double? { DecimalInputParser.parse(amountText.trimmingCharacters(in: .whitespaces)) }

        var isBlank: Bool {
            name.trimmingCharacters(in: .whitespaces).isEmpty && amountText.isEmpty && carbsText.isEmpty
                && nutrientTexts.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        /// Text binding helper for one nutrient field.
        public func text(for nutrient: Nutrient) -> String { nutrientTexts[nutrient] ?? "" }
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
    /// Nutrients with a daily goal: the sheet shows a field for each, per food.
    public let trackedNutrients: [Nutrient]
    /// The offline food list used for name suggestions.
    public let catalog: FoodCatalog

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
        trackedNutrients: [Nutrient] = [],
        catalog: FoodCatalog = .empty,
        status: MealStatus = .eaten,
        editing: Meal? = nil
    ) {
        self.catalog = catalog
        self.repository = repository
        self.dateProvider = dateProvider
        self.timeZone = timeZone
        self.breadUnits = breadUnits
        self.trackedNutrients = trackedNutrients
        self.editing = editing
        let now = dateProvider.now()
        if let meal = editing {
            slot = meal.slot
            self.status = meal.status
            startedAt = meal.startedAt
            items = meal.items.map { item in
                var texts: [Nutrient: String] = [:]
                for nutrient in trackedNutrients {
                    if let value = item[keyPath: nutrient.keyPath] { texts[nutrient] = Self.text(value) }
                }
                return ItemDraft(
                    id: item.id,
                    name: item.name,
                    amountText: item.amountGrams.map(Self.text) ?? "",
                    carbsText: Self.text(item.carbohydrateGrams),
                    nutrientTexts: texts,
                    food: item.foodID.flatMap(catalog.food(id:))
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

    /// Catalog foods matching a row's name while it is not linked to one yet.
    public func suggestions(for item: ItemDraft) -> [Food] {
        guard item.food == nil else { return [] }
        let query = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        return catalog.search(query, limit: 5)
    }

    public func select(_ food: Food, forItem id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].select(food, trackedNutrients: trackedNutrients)
    }

    /// True when any row's values come from the catalog, so the sheet shows the source.
    public var usesCatalog: Bool { items.contains { $0.food != nil } }

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
            var item: MealItem
            if let food = draft.food, let amount {
                // Every value the catalog knows for this weight, including the individual sugars.
                item = food.mealItem(grams: amount, name: "", id: draft.id)
            } else if let stored = editing?.items.first(where: { $0.id == draft.id }), !draft.didClearFood {
                // Start from the stored food so values of untracked nutrients are kept.
                item = stored
            } else {
                // A new row, or one unlinked from its catalog food: nothing from the catalog stays.
                item = MealItem(id: draft.id, name: "", carbohydrateGrams: 0)
            }
            item.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            item.amountGrams = amount
            item.carbohydrateGrams = carbs
            for nutrient in trackedNutrients {
                let text = draft.text(for: nutrient).trimmingCharacters(in: .whitespaces)
                if text.isEmpty {
                    item[keyPath: nutrient.keyPath] = nil
                } else {
                    guard let value = DecimalInputParser.parse(text) else { return nil }
                    item[keyPath: nutrient.keyPath] = value
                }
            }
            result.append(item)
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
