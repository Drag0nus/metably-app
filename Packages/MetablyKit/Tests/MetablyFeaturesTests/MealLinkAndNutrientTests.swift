import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@MainActor
@Suite("Reading to meal links")
struct MealLinkTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func lunch(status: MealStatus = .eaten, at date: Date? = nil) -> Meal {
        let start = date ?? instant(13, 10)
        return Meal(slot: .lunch, status: status, startedAt: start, timeZone: kyiv,
                    items: [MealItem(name: "Soup", carbohydrateGrams: 20)], createdAt: start)
    }

    struct Fixture {
        let readings: InMemoryGlucoseRepository
        let meals: InMemoryMealRepository
        let links: InMemoryEventLinkRepository
    }

    func makeFixture(meals: [Meal], now: Date) -> Fixture {
        Fixture(
            readings: InMemoryGlucoseRepository(),
            meals: InMemoryMealRepository(meals: meals, dateProvider: FixedDateProvider(now)),
            links: InMemoryEventLinkRepository(dateProvider: FixedDateProvider(now))
        )
    }

    func makeModel(_ fixture: Fixture, now: Date, editing: GlucoseReading? = nil) -> GlucoseEntryModel {
        GlucoseEntryModel(
            repository: fixture.readings, unit: .millimolesPerLiter, dateProvider: FixedDateProvider(now),
            timeZone: kyiv, meals: fixture.meals, links: fixture.links, editing: editing
        )
    }

    @Test("A reading two hours after lunch suggests the lunch, unconfirmed")
    func suggestsAfterMeal() throws {
        let meal = lunch()
        let fixture = makeFixture(meals: [meal], now: instant(15, 15))
        let model = makeModel(fixture, now: instant(15, 15))
        #expect(model.slot == .afterLunch)
        let candidate = try #require(model.mealCandidate)
        #expect(candidate.meal.id == meal.id)
        #expect(candidate.relation == .postMeal)
        #expect(candidate.minutesFromMealStart == 125)
        #expect(!model.linksToMeal)
    }

    @Test("Without the user's confirmation nothing is linked")
    func noLinkWithoutConfirmation() throws {
        let fixture = makeFixture(meals: [lunch()], now: instant(15, 15))
        let model = makeModel(fixture, now: instant(15, 15))
        model.valueText = "8,4"
        _ = try #require(model.save())
        #expect(fixture.links.storage.isEmpty)
    }

    @Test("A confirmed link is stored with the reading")
    func confirmedLink() throws {
        let meal = lunch()
        let fixture = makeFixture(meals: [meal], now: instant(15, 15))
        let model = makeModel(fixture, now: instant(15, 15))
        model.valueText = "8,4"
        model.linksToMeal = true
        let reading = try #require(model.save())
        let links = try fixture.links.links(fromIDs: [reading.id])
        #expect(links.map(\.toID) == [meal.id])
        #expect(links.first?.relation == .postMeal)
    }

    @Test("Planned meals are offered only for a reading before the meal")
    func plannedMeals() {
        let planned = lunch(status: .planned)
        let after = makeModel(makeFixture(meals: [planned], now: instant(15, 15)), now: instant(15, 15))
        #expect(after.mealCandidate == nil)
        let before = makeModel(makeFixture(meals: [planned], now: instant(12, 50)), now: instant(12, 50))
        #expect(before.slot == .beforeLunch)
        #expect(before.mealCandidate?.relation == .preMeal)
    }

    @Test("Moving the time to another meal resets the confirmation")
    func confirmationIsPerMeal() {
        let breakfast = Meal(slot: .breakfast, status: .eaten, startedAt: instant(8), timeZone: kyiv,
                             items: [MealItem(name: "Oatmeal", carbohydrateGrams: 30)], createdAt: instant(8))
        let fixture = makeFixture(meals: [breakfast, lunch()], now: instant(15, 15))
        let model = makeModel(fixture, now: instant(15, 15))
        model.linksToMeal = true
        model.slot = .afterBreakfast
        model.measuredAt = instant(10)
        #expect(model.mealCandidate?.meal.id == breakfast.id)
        #expect(!model.linksToMeal)
    }

    @Test("Editing shows the existing link; switching it off removes it")
    func editAndUnlink() throws {
        let meal = lunch()
        let fixture = makeFixture(meals: [meal], now: instant(15, 30))
        let first = makeModel(fixture, now: instant(15, 15))
        first.valueText = "8,4"
        first.linksToMeal = true
        let reading = try #require(first.save())

        let edit = makeModel(fixture, now: instant(15, 30), editing: reading)
        #expect(edit.linksToMeal)
        #expect(edit.mealCandidate?.meal.id == meal.id)
        edit.linksToMeal = false
        _ = try #require(edit.save())
        #expect(try fixture.links.links(fromIDs: [reading.id]).isEmpty)
    }

    @Test("Linked readings get a display text from the current times")
    func displayText() throws {
        let meal = lunch()
        let now = instant(15, 15)
        let reading = GlucoseReading(enteredValue: 8.4, enteredUnit: .millimolesPerLiter, context: .afterMeal,
                                     measuredAt: now, timeZone: kyiv, provenance: .manual, createdAt: now)
        let link = EventLink(fromID: reading.id, toID: meal.id, relation: .postMeal, minutesFromMealStart: 125, createdAt: now)
        let defaults = UserDefaults(suiteName: "test.links.\(UUID().uuidString)")!
        let dependencies = AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(readings: [reading]),
            mealRepository: InMemoryMealRepository(meals: [meal]),
            linkRepository: InMemoryEventLinkRepository(links: [link]),
            preferences: UserPreferencesStore(defaults: defaults),
            dateProvider: FixedDateProvider(now)
        )
        let texts = dependencies.mealLinkTexts(for: [reading])
        #expect(texts[reading.id] == MealLinkText.text(slot: .lunch, minutes: 125))
        #expect(texts[reading.id]?.isEmpty == false)
    }
}

@MainActor
@Suite("Nutrient goals")
struct NutrientGoalTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Goals are off by default, persist, and ignore out-of-range values")
    func preferences() {
        let name = "test.nutrients.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let store = UserPreferencesStore(defaults: defaults)
        #expect(store.trackedNutrients.isEmpty)
        store.setGoal(90, for: .protein)
        store.setGoal(99_999, for: .energy)
        #expect(store.goal(for: .protein) == 90)
        #expect(store.goal(for: .energy) == nil)
        let reloaded = UserPreferencesStore(defaults: UserDefaults(suiteName: name)!)
        #expect(reloaded.trackedNutrients == [.protein])
        reloaded.setGoal(nil, for: .protein)
        #expect(reloaded.trackedNutrients.isEmpty)
    }

    @Test("Tracked nutrients are saved per food; untracked values of an edited food are kept")
    func entryFields() throws {
        let item = MealItem(name: "Egg", amountGrams: 50, carbohydrateGrams: 0, proteinGrams: 6, fatGrams: 5)
        let meal = Meal(slot: .breakfast, status: .eaten, startedAt: now, timeZone: .gmt, items: [item], createdAt: now)
        let repository = InMemoryMealRepository(meals: [meal], dateProvider: FixedDateProvider(now))
        let model = MealEntryModel(repository: repository, dateProvider: FixedDateProvider(now), timeZone: .gmt,
                                   trackedNutrients: [.protein], editing: meal)
        #expect(model.items[0].text(for: .protein) == "6")
        model.items[0].nutrientTexts[.protein] = "6,5"
        let saved = try #require(model.save())
        #expect(saved.items[0].proteinGrams == 6.5)
        #expect(saved.items[0].fatGrams == 5)
    }

    @Test("A typo in a nutrient field blocks saving")
    func entryValidation() {
        let model = MealEntryModel(repository: InMemoryMealRepository(), dateProvider: FixedDateProvider(now),
                                   timeZone: .gmt, trackedNutrients: [.fat])
        model.items[0].name = "Butter"
        model.items[0].carbsText = "0"
        model.items[0].nutrientTexts[.fat] = "800"
        #expect(model.validationError == .invalid(.nutrientOutOfRange(.fat)))
        model.items[0].nutrientTexts[.fat] = "x"
        #expect(model.validationError == .unreadableNumber)
        model.items[0].nutrientTexts[.fat] = ""
        #expect(model.canSave)
    }
}

@MainActor
@Suite("Today carbohydrates")
struct TodayCarbohydrateTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    @Test("Today sums eaten and planned carbs of the day only; the card needs a meal or a goal")
    func carbs() {
        let at = { (hour: Int) in self.day.instant(hour: hour, minute: 0, in: self.kyiv)! }
        let meals = [
            Meal(slot: .breakfast, status: .eaten, startedAt: at(8), timeZone: kyiv,
                 items: [MealItem(name: "Oatmeal", carbohydrateGrams: 30)], createdAt: at(8)),
            Meal(slot: .dinner, status: .planned, startedAt: at(19), timeZone: kyiv,
                 items: [MealItem(name: "Rice", carbohydrateGrams: 45)], createdAt: at(8)),
            Meal(slot: .lunch, status: .eaten, startedAt: at(13).addingTimeInterval(-86_400), timeZone: kyiv,
                 items: [MealItem(name: "Bread", carbohydrateGrams: 99)], createdAt: at(8)),
        ]
        let defaults = UserDefaults(suiteName: "test.todaycarbs.\(UUID().uuidString)")!
        let dependencies = AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(),
            mealRepository: InMemoryMealRepository(meals: meals),
            preferences: UserPreferencesStore(defaults: defaults),
            dateProvider: FixedDateProvider(at(12))
        )
        let model = TodayModel(dependencies: dependencies, timeZone: kyiv)
        model.reload()
        #expect(model.eatenCarbohydrateGrams == 30)
        #expect(model.plannedCarbohydrateGrams == 45)
        #expect(model.showsCarbohydrateCard)

        let empty = TodayModel(dependencies: AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(),
            preferences: UserPreferencesStore(defaults: UserDefaults(suiteName: "test.todaycarbs.\(UUID().uuidString)")!),
            dateProvider: FixedDateProvider(at(12))
        ), timeZone: kyiv)
        empty.reload()
        #expect(!empty.showsCarbohydrateCard)
    }
}
