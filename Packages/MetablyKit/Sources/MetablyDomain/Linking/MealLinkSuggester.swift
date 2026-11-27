import Foundation

public enum MealSlot: String, Sendable, Hashable, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
}

/// Relations of the generic EventLink table (see the data model). Raw values are persisted.
public enum EventLinkRelation: String, Sendable, Hashable, Codable, CaseIterable {
    case preMeal
    case postMeal
    case doseForMeal
    case correction
    case symptomAt
    case treatedBy
}

/// The minimum a suggester needs to know about a meal.
public struct MealTimeReference: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var slot: MealSlot
    public var startedAt: Date

    public init(id: UUID, slot: MealSlot, startedAt: Date) {
        self.id = id
        self.slot = slot
        self.startedAt = startedAt
    }
}

public struct MealLinkSuggestion: Sendable, Hashable {
    public let mealID: UUID
    public let relation: EventLinkRelation
    /// Signed minutes from meal start to the reading (negative before the meal).
    public let minutesFromMealStart: Int
}

/// Proposes links between a glucose reading and nearby meals.
///
/// Suggestions are never stored automatically: the UI asks ("Link to breakfast at 08:10?")
/// and the user confirms. Windows follow the data model defaults and are configurable.
public struct MealLinkSuggester: Sendable {
    /// A pre-meal reading may be taken up to this long before the meal starts.
    public var preMealWindow: TimeInterval
    /// Post-meal window after meal start; the diary's "2 h after" sits in the middle.
    public var postMealWindow: ClosedRange<TimeInterval>

    public init(
        preMealWindow: TimeInterval = 60 * 60,
        postMealWindow: ClosedRange<TimeInterval> = (90 * 60)...(150 * 60)
    ) {
        self.preMealWindow = preMealWindow
        self.postMealWindow = postMealWindow
    }

    /// Suggestions sorted best first (closest to the expected time).
    public func suggestions(
        readingAt: Date,
        context: GlucoseMeasurementContext,
        meals: [MealTimeReference]
    ) -> [MealLinkSuggestion] {
        let twoHours: TimeInterval = 120 * 60
        var scored: [(score: TimeInterval, suggestion: MealLinkSuggestion)] = []
        for meal in meals {
            let offset = readingAt.timeIntervalSince(meal.startedAt)
            let minutes = Int((offset / 60).rounded())
            switch context {
            case .beforeMeal, .fasting:
                if offset <= 0, -offset <= preMealWindow {
                    scored.append((-offset, MealLinkSuggestion(mealID: meal.id, relation: .preMeal, minutesFromMealStart: minutes)))
                }
            case .afterMeal, .random:
                if postMealWindow.contains(offset) {
                    scored.append((abs(offset - twoHours), MealLinkSuggestion(mealID: meal.id, relation: .postMeal, minutesFromMealStart: minutes)))
                }
            case .bedtime, .night:
                break
            }
        }
        return scored.sorted { $0.score < $1.score }.map(\.suggestion)
    }
}
