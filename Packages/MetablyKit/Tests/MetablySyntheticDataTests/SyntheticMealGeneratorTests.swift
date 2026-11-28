import Foundation
import MetablyDomain
import Testing
@testable import MetablySyntheticData

@Suite("Synthetic meal generator")
struct SyntheticMealGeneratorTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let lastDay = LocalDay(year: 2026, month: 11, day: 27)

    @Test("Same seed gives the same meals; every meal is synthetic and valid")
    func deterministicAndValid() {
        let now = lastDay.instant(hour: 23, minute: 59, in: kyiv)!
        let a = SyntheticMealGenerator(seed: 3).makeMeals(days: 7, endingOn: lastDay, timeZone: kyiv, now: now)
        let b = SyntheticMealGenerator(seed: 3).makeMeals(days: 7, endingOn: lastDay, timeZone: kyiv, now: now)
        #expect(a == b)
        #expect(Set(a.map(\.localDay)).count == 7)
        #expect(Set(a.map(\.id)).count == a.count)
        for meal in a {
            #expect(meal.provenance.source == .synthetic)
            #expect(MealValidator().validate(meal) == nil)
            #expect(meal.status == .eaten)
        }
    }

    @Test("Meals later than now on the last day are planned")
    func futureIsPlanned() {
        let now = lastDay.instant(hour: 12, minute: 0, in: kyiv)!
        let meals = SyntheticMealGenerator().makeMeals(days: 1, endingOn: lastDay, timeZone: kyiv, now: now)
        #expect(meals.contains { $0.status == .planned })
        for meal in meals {
            #expect((meal.status == .planned) == (meal.startedAt > now))
        }
    }
}
