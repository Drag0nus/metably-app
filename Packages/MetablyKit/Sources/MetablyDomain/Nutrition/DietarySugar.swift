import Foundation

/// Individual sugars in food, in grams. These are dietary sugars eaten, never blood glucose.
/// Raw values may be persisted in exports; never rename them.
public enum DietarySugar: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case sucrose
    case glucose
    case fructose
    case lactose
    case maltose
    case galactose

    public var id: String { rawValue }

    public var keyPath: WritableKeyPath<MealItem, Double?> {
        switch self {
        case .sucrose: \.sucroseGrams
        case .glucose: \.glucoseGrams
        case .fructose: \.fructoseGrams
        case .lactose: \.lactoseGrams
        case .maltose: \.maltoseGrams
        case .galactose: \.galactoseGrams
        }
    }

    /// Plausible grams in one food (catches typos only).
    public static let itemRange: ClosedRange<Double> = 0...500
}

/// One day's sugars from the foods eaten, honest about gaps.
///
/// Each sugar is summed only over foods that know it; `foodsWithoutBreakdown` counts foods with
/// no individual sugar at all, so the UI can say "no data for N foods" instead of showing zero.
public struct DietarySugarBreakdown: Sendable, Hashable {
    /// Total sugars (USDA "Sugars, total"), with the count of foods that lack it.
    public var totalSugars: NutrientTotalValue
    /// Only sugars known for at least one food, in `DietarySugar.allCases` order.
    public var sugars: [SugarTotal]
    public var foodsWithoutBreakdown: Int
    public var foodCount: Int

    public init(meals: [Meal]) {
        let items = meals.flatMap(\.items)
        foodCount = items.count
        totalSugars = NutrientTotalValue(items: items, keyPath: \.sugarsGrams)
        sugars = DietarySugar.allCases.compactMap { sugar in
            let total = NutrientTotalValue(items: items, keyPath: sugar.keyPath)
            return total.foodsWithValue > 0 ? SugarTotal(sugar: sugar, total: total) : nil
        }
        foodsWithoutBreakdown = items.filter { item in
            DietarySugar.allCases.allSatisfy { item[keyPath: $0.keyPath] == nil }
        }.count
    }

    /// True when at least one food knows any individual sugar.
    public var hasBreakdown: Bool { !sugars.isEmpty }
}

/// One sugar's daily sum.
public struct SugarTotal: Sendable, Hashable, Identifiable {
    public var sugar: DietarySugar
    public var total: NutrientTotalValue
    public var id: DietarySugar { sugar }
}

/// A sum over the foods that have a value, plus how many foods had one.
public struct NutrientTotalValue: Sendable, Hashable {
    public var value: Double
    public var foodsWithValue: Int
    public var foodsWithoutValue: Int

    public init(items: [MealItem], keyPath: KeyPath<MealItem, Double?>) {
        let known = items.compactMap { $0[keyPath: keyPath] }
        value = known.reduce(0, +)
        foodsWithValue = known.count
        foodsWithoutValue = items.count - known.count
    }
}
