import Foundation
import MetablyDomain

/// Generates **synthetic** meals for previews, tests and the Debug data loader.
/// Foods and amounts are invented examples, not dietary advice. `source == .synthetic`.
public struct SyntheticMealGenerator: Sendable {
    public static let providerID = "synthetic"

    struct Template {
        let slot: MealSlot
        let hour: Int
        let minute: Int
        let items: [(name: String, grams: Double, carbs: Double, protein: Double, fat: Double, kcal: Double)]
    }

    static let templates: [Template] = [
        Template(slot: .breakfast, hour: 7, minute: 40, items: [
            ("Oatmeal", 200, 24, 5, 3, 140), ("Egg", 55, 0, 7, 5, 75), ("Apple", 150, 18, 0, 0, 78),
        ]),
        Template(slot: .lunch, hour: 13, minute: 15, items: [
            ("Vegetable soup", 300, 18, 4, 6, 140), ("Buckwheat, boiled", 150, 30, 5, 1.5, 150),
            ("Rye bread", 30, 14, 2.5, 0.5, 70), ("Chicken breast", 120, 0, 28, 3, 140),
        ]),
        Template(slot: .snack, hour: 16, minute: 30, items: [("Kefir", 250, 10, 7, 6, 125)]),
        Template(slot: .dinner, hour: 19, minute: 0, items: [
            ("Baked fish", 150, 0, 30, 6, 180), ("Green salad", 200, 8, 2, 7, 100),
        ]),
    ]

    /// Invented sugar breakdown per 100 g for a few foods, so the sugars card has something to
    /// show; other foods stay unknown on purpose.
    static let sugarsPer100g: [String: [DietarySugar: Double]] = [
        "Apple": [.fructose: 6, .glucose: 2.5, .sucrose: 2],
        "Kefir": [.lactose: 4, .galactose: 0.2],
    ]

    public let seed: UInt64

    public init(seed: UInt64 = 11) { self.seed = seed }

    /// Eaten meals for each day; on the last day, meals after `now` are planned.
    public func makeMeals(days: Int, endingOn lastDay: LocalDay, timeZone: TimeZone, now: Date) -> [Meal] {
        guard days > 0 else { return [] }
        var rng = SeededRandomNumberGenerator(seed: seed)
        var meals: [Meal] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let day = lastDay.adding(days: -offset)
            for template in Self.templates {
                guard let start = day.instant(hour: template.hour, minute: template.minute, in: timeZone) else { continue }
                let jitter = TimeInterval(Int.random(in: -15...15, using: &rng) * 60)
                let startedAt = start.addingTimeInterval(jitter)
                let scale = Double.random(in: 0.8...1.2, using: &rng)
                let items = template.items.map { food in
                    var item = MealItem(
                        id: SyntheticGlucoseGenerator.makeUUID(using: &rng),
                        name: food.name,
                        amountGrams: (food.grams * scale).rounded(),
                        carbohydrateGrams: (food.carbs * scale).rounded(),
                        proteinGrams: (food.protein * scale).rounded(),
                        fatGrams: (food.fat * scale).rounded(),
                        energyKilocalories: (food.kcal * scale).rounded()
                    )
                    if let sugars = Self.sugarsPer100g[food.name], let grams = item.amountGrams {
                        for (sugar, per100g) in sugars {
                            item[keyPath: sugar.keyPath] = (per100g * grams / 10).rounded() / 10
                        }
                        item.sugarsGrams = (sugars.values.reduce(0, +) * grams / 10).rounded() / 10
                    }
                    return item
                }
                meals.append(Meal(
                    id: SyntheticGlucoseGenerator.makeUUID(using: &rng),
                    slot: template.slot,
                    status: startedAt <= now ? .eaten : .planned,
                    startedAt: startedAt,
                    timeZone: timeZone,
                    items: items,
                    provenance: Provenance(source: .synthetic, providerID: Self.providerID, sourceDetail: "Synthetic data generator"),
                    createdAt: min(startedAt, now)
                ))
            }
        }
        return meals
    }
}
