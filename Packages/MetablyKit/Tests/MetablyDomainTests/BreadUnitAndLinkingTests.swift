import Foundation
import Testing
@testable import MetablyDomain

@Suite("Bread units")
struct BreadUnitConverterTests {
    @Test("Default is 12 g of carbohydrate per bread unit")
    func defaultFactor() {
        #expect(BreadUnitConverter.standard.carbsPerBreadUnit == 12)
        #expect(BreadUnitConverter.standard.breadUnits(forCarbohydrateGrams: 60) == 5)
    }

    @Test("The 10 g system is configurable")
    func tenGrams() throws {
        let converter = try BreadUnitConverter(carbsPerBreadUnit: 10)
        #expect(converter.breadUnits(forCarbohydrateGrams: 45) == 4.5)
        #expect(converter.carbohydrateGrams(forBreadUnits: 3) == 30)
    }

    @Test("Implausible factors are rejected", arguments: [0.0, -12, 4.9, 20.1, .nan, .infinity])
    func rejectsBadFactor(factor: Double) {
        #expect(throws: BreadUnitConverterError.factorOutOfRange) {
            try BreadUnitConverter(carbsPerBreadUnit: factor)
        }
    }
}

@Suite("Meal link suggestions")
struct MealLinkSuggesterTests {
    let suggester = MealLinkSuggester()
    let breakfastStart = Date(timeIntervalSince1970: 1_800_000_000)
    let breakfast = MealTimeReference(id: UUID(), slot: .breakfast, startedAt: Date(timeIntervalSince1970: 1_800_000_000))

    @Test("A reading two hours after breakfast is suggested as its post-meal reading")
    func postMeal() {
        let result = suggester.suggestions(
            readingAt: breakfastStart.addingTimeInterval(120 * 60), context: .afterMeal, meals: [breakfast]
        )
        #expect(result == [MealLinkSuggestion(mealID: breakfast.id, relation: .postMeal, minutesFromMealStart: 120)])
    }

    @Test("A reading 45 minutes after a meal is outside the post-meal window")
    func tooEarly() {
        #expect(suggester.suggestions(
            readingAt: breakfastStart.addingTimeInterval(45 * 60), context: .afterMeal, meals: [breakfast]
        ).isEmpty)
    }

    @Test("A before-meal reading links to the meal that follows within an hour")
    func preMeal() {
        let result = suggester.suggestions(
            readingAt: breakfastStart.addingTimeInterval(-20 * 60), context: .beforeMeal, meals: [breakfast]
        )
        #expect(result.first?.relation == .preMeal)
        #expect(result.first?.minutesFromMealStart == -20)
    }

    @Test("The closest match to two hours wins")
    func ordering() {
        let snack = MealTimeReference(id: UUID(), slot: .snack, startedAt: breakfastStart.addingTimeInterval(30 * 60))
        // Reading at +150 min from breakfast = +120 min from snack.
        let result = suggester.suggestions(
            readingAt: breakfastStart.addingTimeInterval(150 * 60), context: .afterMeal, meals: [breakfast, snack]
        )
        #expect(result.map(\.mealID) == [snack.id, breakfast.id])
    }

    @Test("Bedtime readings get no meal suggestion")
    func bedtime() {
        #expect(suggester.suggestions(
            readingAt: breakfastStart.addingTimeInterval(120 * 60), context: .bedtime, meals: [breakfast]
        ).isEmpty)
    }
}
