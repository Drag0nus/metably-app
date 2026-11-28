import Foundation
import Testing
@testable import MetablyDomain

@Suite("Food catalog")
struct FoodCatalogTests {
    static let egg = Food(
        id: "usda-sr-173424", nameEN: "Egg, hard-boiled", nameUK: "Яйце варене", category: "eggsDairy",
        sourceDescription: "Egg, whole, cooked, hard-boiled",
        per100g: .init(kcal: 155, protein: 12.58, fat: 10.61, carbohydrate: 1.12, sugars: 1.12, fiber: 0),
        portions: [.init(nameEN: "piece, large", nameUK: "шт. (великий розмір)", grams: 50)]
    )
    static let milk = Food(
        id: "usda-sr-1", nameEN: "Milk 3.2%", nameUK: "Молоко 3,2%", category: "eggsDairy",
        sourceDescription: "Milk, whole",
        per100g: .init(kcal: 61, protein: 3.15, fat: 3.25, carbohydrate: 4.8, sugars: 5.05, lactose: 5.05, galactose: 0)
    )
    static let dumplings = Food(
        id: "usda-sr-2", nameEN: "Dumplings", nameUK: "Вареники", category: "dishes",
        sourceDescription: "Dumpling, potato- or cheese-filled, frozen", per100g: .init(kcal: 200, protein: 5, fat: 3, carbohydrate: 38)
    )
    static let yolk = Food(
        id: "usda-sr-3", nameEN: "Egg yolk", nameUK: "Яєчний жовток", category: "eggsDairy",
        sourceDescription: "Egg, yolk, raw, fresh", per100g: .init(kcal: 322, protein: 15.9, fat: 26.5, carbohydrate: 3.6)
    )
    let catalog = FoodCatalog(source: "test", sourceURL: nil, foods: [yolk, egg, milk, dumplings])

    @Test("Search matches Ukrainian and English, ignoring case")
    func searchLanguages() {
        #expect(catalog.search("яйце").map(\.id) == [Self.egg.id])
        #expect(catalog.search("МОЛОКО").map(\.id) == [Self.milk.id])
        #expect(catalog.search("milk").map(\.id) == [Self.milk.id])
    }

    @Test("A name starting with the query ranks before a later word or a match inside a word")
    func ranking() {
        // "Вареники" starts with "варен"; in "Яйце варене" only the second word does.
        #expect(catalog.search("варен").map(\.id) == [Self.dumplings.id, Self.egg.id])
        // Inside a word only ("hard-boiled" has no word starting with "oiled").
        #expect(catalog.search("oiled").map(\.id) == [Self.egg.id])
    }

    @Test("Every word must match, in any order")
    func multipleWords() {
        #expect(catalog.search("варене яйце").map(\.id) == [Self.egg.id])
        #expect(catalog.search("яйце смажене").isEmpty)
        #expect(catalog.search("  ").isEmpty)
    }

    @Test("Two boiled eggs: values scale from 100 g, one decimal")
    func scaling() {
        let item = Self.egg.mealItem(grams: 100, name: "Яйце варене")
        #expect(item.amountGrams == 100)
        #expect(item.carbohydrateGrams == 1.1)
        #expect(item.proteinGrams == 12.6)
        #expect(item.fatGrams == 10.6)
        #expect(item.energyKilocalories == 155)
        #expect(item.foodID == Self.egg.id)
    }

    @Test("A sugar the source does not report stays unknown, not zero")
    func unknownSugars() {
        let egg = Self.egg.mealItem(grams: 50, name: "Egg")
        #expect(egg.lactoseGrams == nil)
        #expect(egg.sucroseGrams == nil)
        let milk = Self.milk.mealItem(grams: 250, name: "Milk")
        #expect(milk.lactoseGrams == 12.6)
        #expect(milk.galactoseGrams == 0)
        #expect(milk.fiberGrams == nil)
    }

    @Test("The catalog file decodes, extra fields are ignored")
    func decode() throws {
        let json = """
        {"source":"USDA","sourceURL":"https://fdc.nal.usda.gov/","foods":[{"id":"usda-sr-9","fdcId":9,
        "nameEN":"Apple","nameUK":"Яблуко","category":"fruits","sourceDescription":"Apples, raw",
        "per100g":{"kcal":52,"protein":0.26,"fat":0.17,"carbohydrate":13.81,"fructose":5.9},
        "portions":[{"nameEN":"piece, small","nameUK":"шт. (маленьке)","grams":100,"source":"diary p. 11"}]}]}
        """
        let catalog = try FoodCatalogFile.decode(Data(json.utf8))
        #expect(catalog.foods.count == 1)
        #expect(catalog.food(id: "usda-sr-9")?.per100g.fructose == 5.9)
        #expect(catalog.food(id: "usda-sr-9")?.portions.first?.source == "diary p. 11")
        #expect(catalog.sourceURL?.host() == "fdc.nal.usda.gov")
    }
}

@Suite("Dietary sugars")
struct DietarySugarTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Each sugar sums only the foods that know it; gaps are counted, not zero-filled")
    func breakdown() {
        let milk = MealItem(name: "Milk", carbohydrateGrams: 12, sugarsGrams: 12.6, lactoseGrams: 12.6)
        let apple = MealItem(name: "Apple", carbohydrateGrams: 14, sugarsGrams: 10, sucroseGrams: 2, glucoseGrams: 2.4, fructoseGrams: 5.9)
        let bread = MealItem(name: "Bread", carbohydrateGrams: 15)
        let meal = Meal(slot: .breakfast, status: .eaten, startedAt: now, timeZone: .gmt, items: [milk, apple, bread], createdAt: now)
        let result = DietarySugarBreakdown(meals: [meal])
        #expect(abs(result.totalSugars.value - 22.6) < 0.001)
        #expect(result.totalSugars.foodsWithoutValue == 1)
        #expect(result.sugars.map(\.sugar) == [.sucrose, .glucose, .fructose, .lactose])
        #expect(result.sugars.first { $0.sugar == .lactose }?.total.value == 12.6)
        #expect(result.foodsWithoutBreakdown == 1)
        #expect(!result.sugars.contains { $0.sugar == .maltose })
    }

    @Test("No food with sugar data means no breakdown")
    func empty() {
        let meal = Meal(slot: .lunch, status: .eaten, startedAt: now, timeZone: .gmt,
                        items: [MealItem(name: "Soup", carbohydrateGrams: 10)], createdAt: now)
        let result = DietarySugarBreakdown(meals: [meal])
        #expect(!result.hasBreakdown)
        #expect(result.totalSugars.foodsWithValue == 0)
    }

    @Test("An implausible sugar amount is rejected as a typo")
    func validation() {
        let item = MealItem(name: "Typo", carbohydrateGrams: 10, sucroseGrams: 900)
        #expect(MealValidator().validate(item) == .sugarOutOfRange(.sucrose))
    }
}
