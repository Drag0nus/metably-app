import Foundation

/// Nutrients besides carbohydrates that a user may track against their own daily goal.
/// Raw values are stored in preferences; never rename them.
public enum Nutrient: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case protein
    case fat
    case fiber
    case energy

    public var id: String { rawValue }

    /// Where the value lives on a food.
    public var keyPath: WritableKeyPath<MealItem, Double?> {
        switch self {
        case .protein: \.proteinGrams
        case .fat: \.fatGrams
        case .fiber: \.fiberGrams
        case .energy: \.energyKilocalories
        }
    }

    /// Kilocalories for energy, grams otherwise.
    public var isEnergy: Bool { self == .energy }

    /// Accepted daily goal range (catches typos only).
    public var goalRange: ClosedRange<Double> {
        switch self {
        case .protein: 10...400
        case .fat: 10...400
        case .fiber: 5...100
        case .energy: 500...6000
        }
    }

    /// Stepper increment for the goal.
    public var goalStep: Double { isEnergy ? 50 : 5 }

    /// Plausible amount in one food (catches typos only).
    public var itemRange: ClosedRange<Double> { isEnergy ? 0...5000 : 0...500 }
}

/// Nutrient totals of a day, honest about gaps.
public struct NutrientTotal: Sendable, Hashable {
    public var value: Double
    /// Foods eaten that day without a value for this nutrient.
    public var foodsWithoutValue: Int

    public init(of nutrient: Nutrient, in meals: [Meal]) {
        let items = meals.flatMap(\.items)
        let known = items.compactMap { $0[keyPath: nutrient.keyPath] }
        value = known.reduce(0, +)
        foodsWithoutValue = items.count - known.count
    }
}
