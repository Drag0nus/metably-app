import Foundation
import MetablyDomain
import Observation

/// State of the Meals tab: one diary day, eaten and planned meals, carbohydrate totals.
@Observable
@MainActor
public final class MealsModel {
    public private(set) var day: LocalDay
    public private(set) var eaten: [Meal] = []
    public private(set) var planned: [Meal] = []
    public private(set) var loadFailed = false

    @ObservationIgnored private let dependencies: AppDependencies
    @ObservationIgnored private let timeZone: TimeZone

    public init(dependencies: AppDependencies, timeZone: TimeZone = .current) {
        self.dependencies = dependencies
        self.timeZone = timeZone
        self.day = LocalDay(instant: dependencies.dateProvider.now(), timeZone: timeZone)
    }

    public var today: LocalDay { LocalDay(instant: dependencies.dateProvider.now(), timeZone: timeZone) }
    public var isToday: Bool { day == today }
    public var breadUnits: BreadUnitConverter { dependencies.preferences.breadUnitConverter }
    /// The user's own daily carbohydrate goal in grams, or nil when not set.
    public var carbohydrateGoalGrams: Double? { dependencies.preferences.dailyCarbohydrateGoalGrams }

    /// Facts only: what was eaten. Planned meals never count as eaten.
    public var eatenCarbohydrateGrams: Double { eaten.reduce(0) { $0 + $1.totalCarbohydrateGrams } }
    public var plannedCarbohydrateGrams: Double { planned.reduce(0) { $0 + $1.totalCarbohydrateGrams } }

    /// Nutrients the user set a goal for, with what was eaten and the goal.
    public var nutrientProgress: [(nutrient: Nutrient, total: NutrientTotal, goal: Double)] {
        dependencies.preferences.trackedNutrients.compactMap { nutrient in
            dependencies.preferences.goal(for: nutrient).map { (nutrient, NutrientTotal(of: nutrient, in: eaten), $0) }
        }
    }

    /// Dietary sugars eaten today, from foods that know them. Never blood glucose.
    public var sugarBreakdown: DietarySugarBreakdown { DietarySugarBreakdown(meals: eaten) }

    public func reload() {
        guard let start = day.startInstant(in: timeZone),
              let end = day.adding(days: 1).startInstant(in: timeZone)
        else { return }
        do {
            let meals = try dependencies.mealRepository.meals(from: start, to: end)
            eaten = meals.filter { $0.status == .eaten }
            planned = meals.filter { $0.status == .planned }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    public func showDay(offset: Int) {
        let target = day.adding(days: offset)
        day = min(target, today.adding(days: 7))
        reload()
    }

    public func showToday() {
        day = today
        reload()
    }

    /// "Eaten as planned": one tap. A meal planned for later is recorded at the current time.
    public func markEaten(_ meal: Meal) {
        var updated = meal
        updated.status = .eaten
        let now = dependencies.dateProvider.now()
        if updated.startedAt > now {
            updated.startedAt = now
            updated.localDay = LocalDay(instant: now, timeZone: meal.timeZone)
        }
        do {
            try dependencies.mealRepository.update(updated)
        } catch {
            loadFailed = true
        }
        reload()
    }

    public func makeEntryModel(status: MealStatus = .eaten, editing: Meal? = nil) -> MealEntryModel {
        dependencies.makeMealEntryModel(status: status, editing: editing)
    }
}
