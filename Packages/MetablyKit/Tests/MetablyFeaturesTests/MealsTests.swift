import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@MainActor
@Suite("Meal entry")
struct MealEntryModelTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func makeModel(at date: Date, repository: InMemoryMealRepository = InMemoryMealRepository(), status: MealStatus = .eaten) -> MealEntryModel {
        MealEntryModel(repository: repository, dateProvider: FixedDateProvider(date), timeZone: kyiv, status: status)
    }

    @Test("The meal is suggested from the nearest usual meal time, a snack in between")
    func suggestedSlot() {
        #expect(makeModel(at: instant(8, 20)).slot == .breakfast)
        #expect(makeModel(at: instant(13, 30)).slot == .lunch)
        #expect(makeModel(at: instant(16, 0)).slot == .snack)
        #expect(makeModel(at: instant(19, 45)).slot == .dinner)
    }

    @Test("Totals follow the typed carbs live; bread units use the factor")
    func totals() {
        let model = makeModel(at: instant(13))
        model.items[0].name = "Buckwheat"
        model.items[0].carbsText = "30"
        model.addItem()
        model.items[1].name = "Bread"
        model.items[1].carbsText = "1"
        #expect(model.totalCarbohydrateGrams == 31)
        model.items[1].carbsText = "6,0"
        #expect(model.totalCarbohydrateGrams == 36)
        #expect(model.totalBreadUnits == 3)
    }

    @Test("Blank rows are ignored; a food without carbs or name cannot be saved")
    func validation() {
        let model = makeModel(at: instant(13))
        #expect(!model.canSave)
        #expect(model.validationError == .invalid(.noItems))
        model.items[0].name = "Soup"
        #expect(model.validationError == .unreadableNumber)
        model.items[0].carbsText = "12"
        model.addItem()
        #expect(model.canSave)
        model.items[1].carbsText = "5"
        #expect(model.validationError == .invalid(.emptyName))
        model.items[1].name = "Bread"
        model.items[1].amountText = "abc"
        #expect(model.validationError == .unreadableNumber)
    }

    @Test("Saving stores grams, portion and note; blank rows are dropped")
    func save() throws {
        let repository = InMemoryMealRepository()
        let model = makeModel(at: instant(13), repository: repository)
        model.items[0].name = "  Buckwheat "
        model.items[0].amountText = "150"
        model.items[0].carbsText = "30,5"
        model.addItem()
        model.portionSize = .large
        model.note = " synthetic "
        let saved = try #require(model.save())
        #expect(saved.items.count == 1)
        #expect(saved.items[0].name == "Buckwheat")
        #expect(saved.items[0].amountGrams == 150)
        #expect(saved.items[0].carbohydrateGrams == 30.5)
        #expect(saved.portionSize == .large)
        #expect(saved.note == "synthetic")
        #expect(saved.slot == .lunch)
        #expect(try repository.meal(id: saved.id) == saved)
    }

    @Test("A planned meal may be in the future; switching to eaten brings it back to now")
    func plannedTime() throws {
        let now = instant(12)
        let model = makeModel(at: now, status: .planned)
        #expect(model.latestAllowedDate == nil)
        model.startedAt = instant(19)
        model.items[0].name = "Soup"
        model.items[0].carbsText = "12"
        model.status = .eaten
        let saved = try #require(model.save())
        #expect(saved.startedAt == now)
    }

    @Test("Editing prefills the rows and keeps the id; delete is a soft delete")
    func editAndDelete() throws {
        let now = instant(14)
        let meal = Meal(
            slot: .lunch, status: .eaten, startedAt: instant(13), timeZone: kyiv,
            items: [MealItem(name: "Rice", amountGrams: 100, carbohydrateGrams: 28)], createdAt: instant(13)
        )
        let repository = InMemoryMealRepository(meals: [meal], dateProvider: FixedDateProvider(now))
        let model = MealEntryModel(repository: repository, dateProvider: FixedDateProvider(now), timeZone: kyiv, editing: meal)
        #expect(model.isEditing)
        #expect(model.items.first?.carbsText == "28")
        #expect(model.items.first?.amountText == "100")
        model.items[0].carbsText = "30"
        let saved = try #require(model.save())
        #expect(saved.id == meal.id)
        #expect(saved.version == 2)
        #expect(saved.totalCarbohydrateGrams == 30)
        #expect(model.delete())
        #expect(try repository.meal(id: meal.id)?.isDeleted == true)
    }

    @Test("Removing the last row leaves one empty row to type into")
    func removeLastRow() {
        let model = makeModel(at: instant(13))
        model.removeItems(at: [0])
        #expect(model.items.count == 1)
    }
}

@MainActor
@Suite("Meals tab")
struct MealsModelTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ day: LocalDay, _ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func meal(_ slot: MealSlot, _ status: MealStatus, carbs: Double, at date: Date) -> Meal {
        Meal(slot: slot, status: status, startedAt: date, timeZone: kyiv,
             items: [MealItem(name: "Food", carbohydrateGrams: carbs)], createdAt: date)
    }

    func makeModel(meals: [Meal], now: Date, goal: Double? = nil) -> (MealsModel, InMemoryMealRepository) {
        let defaults = UserDefaults(suiteName: "test.meals.\(UUID().uuidString)")!
        let preferences = UserPreferencesStore(defaults: defaults)
        preferences.dailyCarbohydrateGoalGrams = goal
        let repository = InMemoryMealRepository(meals: meals, dateProvider: FixedDateProvider(now))
        let dependencies = AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(),
            mealRepository: repository,
            preferences: preferences,
            dateProvider: FixedDateProvider(now)
        )
        return (MealsModel(dependencies: dependencies, timeZone: kyiv), repository)
    }

    @Test("The day's sugars come from eaten meals only")
    func sugars() {
        let eaten = Meal(slot: .breakfast, status: .eaten, startedAt: instant(day, 8), timeZone: kyiv,
                         items: [MealItem(name: "Milk", carbohydrateGrams: 12, sugarsGrams: 12.6, lactoseGrams: 12.6),
                                 MealItem(name: "Bread", carbohydrateGrams: 15)],
                         createdAt: instant(day, 8))
        let planned = Meal(slot: .dinner, status: .planned, startedAt: instant(day, 19), timeZone: kyiv,
                           items: [MealItem(name: "Juice", carbohydrateGrams: 20, sugarsGrams: 20, fructoseGrams: 10)],
                           createdAt: instant(day, 8))
        let (model, _) = makeModel(meals: [eaten, planned], now: instant(day, 15))
        model.reload()
        let sugars = model.sugarBreakdown
        #expect(sugars.sugars.map(\.sugar) == [.lactose])
        #expect(sugars.totalSugars.value == 12.6)
        #expect(sugars.foodsWithoutBreakdown == 1)
    }

    @Test("Eaten and planned meals are kept apart; planned carbs never count as eaten")
    func totals() {
        let meals = [
            meal(.breakfast, .eaten, carbs: 40, at: instant(day, 8)),
            meal(.lunch, .eaten, carbs: 55, at: instant(day, 13)),
            meal(.dinner, .planned, carbs: 50, at: instant(day, 19)),
            meal(.lunch, .eaten, carbs: 99, at: instant(day.adding(days: -1), 13)),
        ]
        let (model, _) = makeModel(meals: meals, now: instant(day, 15), goal: 180)
        model.reload()
        #expect(model.eaten.map(\.slot) == [.breakfast, .lunch])
        #expect(model.planned.map(\.slot) == [.dinner])
        #expect(model.eatenCarbohydrateGrams == 95)
        #expect(model.plannedCarbohydrateGrams == 50)
        #expect(model.carbohydrateGoalGrams == 180)
    }

    @Test("Eaten as planned moves the meal and records a future plan at the current time")
    func markEaten() throws {
        let now = instant(day, 15)
        let planned = meal(.dinner, .planned, carbs: 50, at: instant(day, 19))
        let (model, repository) = makeModel(meals: [planned], now: now)
        model.reload()
        model.markEaten(planned)
        #expect(model.planned.isEmpty)
        #expect(model.eatenCarbohydrateGrams == 50)
        let stored = try #require(try repository.meal(id: planned.id))
        #expect(stored.status == .eaten)
        #expect(stored.startedAt == now)
    }

    @Test("Days can be browsed back freely and up to a week ahead for planning")
    func browsing() {
        let (model, _) = makeModel(meals: [], now: instant(day, 12))
        #expect(model.isToday)
        model.showDay(offset: -3)
        #expect(model.day == day.adding(days: -3))
        #expect(!model.isToday)
        model.showDay(offset: 30)
        #expect(model.day == day.adding(days: 7))
        model.showToday()
        #expect(model.isToday)
    }

    @Test("No carbohydrate goal until the user sets one")
    func noDefaultGoal() {
        let defaults = UserDefaults(suiteName: "test.meals.\(UUID().uuidString)")!
        #expect(UserPreferencesStore(defaults: defaults).dailyCarbohydrateGoalGrams == nil)
    }
}

@Suite("App version")
struct AppVersionTests {
    @Test("Version and build come from the Info.plist keys")
    func fromInfo() {
        let version = AppVersion(
            infoDictionary: ["CFBundleShortVersionString": "0.5.0", "CFBundleVersion": "5"],
            builtAt: nil
        )
        #expect(version.versionAndBuild == "0.5.0 (5)")
    }

    @Test("Missing keys show a dash instead of failing")
    func missing() {
        #expect(AppVersion(infoDictionary: [:], builtAt: nil).versionAndBuild == "– (–)")
    }
}
