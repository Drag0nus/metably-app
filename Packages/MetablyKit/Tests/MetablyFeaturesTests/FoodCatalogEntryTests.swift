import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@Suite("Bundled food catalog")
struct BundledFoodCatalogTests {
    let catalog = BundledFoodCatalog.shared

    @Test("The bundled list loads with unique ids, names in both languages and the core nutrients")
    func loads() {
        #expect(catalog.foods.count >= 250)
        #expect(Set(catalog.foods.map(\.id)).count == catalog.foods.count)
        #expect(catalog.source.contains("USDA"))
        for food in catalog.foods {
            #expect(!food.nameUK.isEmpty && !food.nameEN.isEmpty, "\(food.id)")
            #expect(food.per100g.carbohydrate != nil && food.per100g.kcal != nil, "\(food.id)")
            #expect(food.portions.allSatisfy { $0.grams > 0 }, "\(food.id)")
        }
    }

    @Test("Everyday Ukrainian words find the food")
    func search() {
        #expect(catalog.search("яйце варене").first?.nameUK == "Яйце варене")
        #expect(catalog.search("гречка").contains { $0.nameUK == "Гречка варена" })
        #expect(catalog.search("boiled egg").first?.nameEN == "Egg, hard-boiled")
    }

    @Test("Diary measures are marked with their page")
    func diaryPortions() throws {
        let potato = try #require(catalog.search("картопля варена").first)
        let portion = try #require(potato.portions.first)
        #expect(portion.grams == 75)
        #expect(portion.source == "diary p. 14")
    }
}

@MainActor
@Suite("Meal entry with the food catalog")
struct MealEntryCatalogTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let now = LocalDay(year: 2026, month: 11, day: 28).instant(hour: 8, minute: 0, in: TimeZone(identifier: "Europe/Kyiv")!)!

    static let egg = Food(
        id: "usda-sr-173424", nameEN: "Egg, hard-boiled", nameUK: "Яйце варене", category: "eggsDairy",
        sourceDescription: "Egg, whole, cooked, hard-boiled",
        per100g: .init(kcal: 155, protein: 12.58, fat: 10.61, carbohydrate: 1.12, sugars: 1.12, fiber: 0),
        portions: [.init(nameEN: "piece, large", nameUK: "шт. (великий розмір)", grams: 50)]
    )
    static let milk = Food(
        id: "usda-sr-171265", nameEN: "Milk 3.2%", nameUK: "Молоко 3,2%", category: "eggsDairy",
        sourceDescription: "Milk, whole, 3.25% milkfat",
        per100g: .init(kcal: 61, protein: 3.15, fat: 3.25, carbohydrate: 4.8, sugars: 5.05, lactose: 5.05)
    )
    let catalog = FoodCatalog(source: "test", sourceURL: nil, foods: [egg, milk])

    func makeModel(repository: InMemoryMealRepository = InMemoryMealRepository(), tracked: [Nutrient] = [.protein], editing: Meal? = nil) -> MealEntryModel {
        MealEntryModel(
            repository: repository, dateProvider: FixedDateProvider(now), timeZone: kyiv,
            trackedNutrients: tracked, catalog: catalog, editing: editing
        )
    }

    @Test("Typing a name suggests catalog foods; a picked food stops suggesting")
    func suggestions() {
        let model = makeModel()
        model.items[0].name = "я"
        #expect(model.suggestions(for: model.items[0]).isEmpty)
        model.items[0].name = "яйце"
        #expect(model.suggestions(for: model.items[0]).map(\.id) == [Self.egg.id])
        model.select(Self.egg, forItem: model.items[0].id)
        #expect(model.suggestions(for: model.items[0]).isEmpty)
        #expect(model.usesCatalog)
    }

    @Test("Two boiled eggs: weight, carbs and tracked protein are computed from the measure")
    func twoEggs() throws {
        let model = makeModel()
        model.select(Self.egg, forItem: model.items[0].id)
        #expect(model.items[0].portion?.grams == 50)
        model.items[0].setQuantityText("2", trackedNutrients: model.trackedNutrients)
        #expect(model.items[0].amountText == "100")
        #expect(model.items[0].carbsText == MealEntryModel.text(1.1))
        #expect(model.items[0].text(for: .protein) == MealEntryModel.text(12.6))
        let meal = try #require(model.save())
        let item = try #require(meal.items.first)
        #expect(item.foodID == Self.egg.id)
        #expect(item.amountGrams == 100)
        #expect(item.fatGrams == 10.6)
        #expect(item.sugarsGrams == 1.1)
    }

    @Test("A food without measures starts at 100 g; typed grams rescale; sugars are saved")
    func gramsAndSugars() throws {
        let model = makeModel()
        model.select(Self.milk, forItem: model.items[0].id)
        #expect(model.items[0].portion == nil)
        #expect(model.items[0].amountText == "100")
        model.items[0].setAmountText("250", trackedNutrients: model.trackedNutrients)
        #expect(model.items[0].carbsText == "12")
        let item = try #require(model.save()?.items.first)
        #expect(item.lactoseGrams == 12.6)
        #expect(item.sucroseGrams == nil)
    }

    @Test("Carbs typed over the computed value are what is saved")
    func carbsOverride() throws {
        let model = makeModel()
        model.select(Self.milk, forItem: model.items[0].id)
        model.items[0].carbsText = "10"
        let item = try #require(model.save()?.items.first)
        #expect(item.carbohydrateGrams == 10)
        #expect(item.foodID == Self.milk.id)
    }

    @Test("Unlinking the food keeps the typed values but drops catalog-only ones")
    func unlink() throws {
        let model = makeModel()
        model.select(Self.milk, forItem: model.items[0].id)
        model.items[0].clearFood()
        let item = try #require(model.save()?.items.first)
        #expect(item.foodID == nil)
        #expect(item.lactoseGrams == nil)
        #expect(item.carbohydrateGrams == 4.8)
    }

    @Test("Editing a catalog item relinks the food and keeps its sugars")
    func editCatalogItem() throws {
        let item = Self.milk.mealItem(grams: 200, name: "Milk")
        let meal = Meal(slot: .breakfast, status: .eaten, startedAt: now, timeZone: kyiv, items: [item], createdAt: now)
        let repository = InMemoryMealRepository(meals: [meal], dateProvider: FixedDateProvider(now))
        let model = makeModel(repository: repository, editing: meal)
        #expect(model.items[0].food?.id == Self.milk.id)
        model.items[0].setAmountText("100", trackedNutrients: model.trackedNutrients)
        let saved = try #require(model.save()?.items.first)
        #expect(saved.lactoseGrams == Food.round(5.05))
        #expect(saved.carbohydrateGrams == 4.8)
    }

    @Test("Editing an item whose food left the catalog keeps everything stored")
    func editUnknownFood() throws {
        var item = MealItem(name: "Old food", amountGrams: 100, carbohydrateGrams: 20, foodID: "usda-sr-0")
        item.fructoseGrams = 3
        let meal = Meal(slot: .lunch, status: .eaten, startedAt: now, timeZone: kyiv, items: [item], createdAt: now)
        let repository = InMemoryMealRepository(meals: [meal], dateProvider: FixedDateProvider(now))
        let model = makeModel(repository: repository, editing: meal)
        #expect(model.items[0].food == nil)
        let saved = try #require(model.save()?.items.first)
        #expect(saved.fructoseGrams == 3)
        #expect(saved.foodID == "usda-sr-0")
    }
}
