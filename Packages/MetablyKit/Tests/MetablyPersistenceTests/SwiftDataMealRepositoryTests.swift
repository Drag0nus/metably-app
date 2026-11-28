import Foundation
import MetablyDomain
import SwiftData
import Testing
@testable import MetablyPersistence

@MainActor
@Suite("SwiftData meal repository")
struct SwiftDataMealRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!

    /// The suite keeps the container alive for the whole test: a context whose container is
    /// released traps on the next fetch.
    let container: ModelContainer
    let repository: SwiftDataMealRepository

    init() throws {
        container = try MetablyModelContainer.make(inMemory: true)
        repository = SwiftDataMealRepository(
            context: container.mainContext, deviceID: UUID(),
            dateProvider: FixedDateProvider(Date(timeIntervalSince1970: 1_800_000_000))
        )
    }

    func makeMeal(minutesAgo: Double = 30) -> Meal {
        Meal(
            slot: .lunch, status: .eaten, startedAt: now.addingTimeInterval(-minutesAgo * 60), timeZone: kyiv,
            items: [
                MealItem(name: "Buckwheat", amountGrams: 150, carbohydrateGrams: 30),
                MealItem(name: "Salad", carbohydrateGrams: 6, proteinGrams: 2),
                MealItem(name: "Apple", amountGrams: 120, carbohydrateGrams: 14),
            ],
            portionSize: .medium, note: "synthetic", createdAt: now
        )
    }

    @Test("A meal round-trips with its items in order")
    func roundTrip() throws {
        let meal = makeMeal()
        try repository.insert(meal)
        let loaded = try #require(try repository.meal(id: meal.id))
        #expect(loaded == meal)
        #expect(loaded.items.map(\.name) == ["Buckwheat", "Salad", "Apple"])
        #expect(loaded.totalCarbohydrateGrams == 50)
        #expect(loaded.total(\.proteinGrams) == 2)
        #expect(loaded.total(\.fatGrams) == nil)
    }

    @Test("Update replaces the items, bumps the version and keeps a revision")
    func update() throws {
        let meal = makeMeal()
        try repository.insert(meal)
        var edited = meal
        edited.items = [MealItem(name: "Soup", carbohydrateGrams: 12)]
        edited.status = .eaten
        try repository.update(edited)

        let loaded = try #require(try repository.meal(id: meal.id))
        #expect(loaded.items.map(\.name) == ["Soup"])
        #expect(loaded.version == 2)
        #expect(try repository.revisions(for: meal.id).map(\.changeKindRaw) == ["create", "update"])
        // Old item rows are removed, not orphaned.
        #expect(try container.mainContext.fetchCount(FetchDescriptor<MealItemRecord>()) == 1)
    }

    @Test("Soft delete hides the meal from day queries")
    func softDelete() throws {
        let meal = makeMeal()
        try repository.insert(meal)
        try repository.softDelete(id: meal.id)
        #expect(try repository.meals(from: now.addingTimeInterval(-86_400), to: now).isEmpty)
        #expect(try repository.meal(id: meal.id)?.isDeleted == true)
    }

    @Test("Writes queue one coalesced outbox entry per meal")
    func outbox() throws {
        let meal = makeMeal()
        try repository.insert(meal)
        var edited = meal
        edited.note = nil
        try repository.update(edited)
        let entries = try container.mainContext.fetch(FetchDescriptor<OutboxEntryRecord>())
        #expect(entries.count == 1)
        let envelope = try JSONDecoder.metably.decode(SyncEnvelope.self, from: try #require(entries.first?.envelope))
        #expect(envelope.entityType == "meal")
        #expect(envelope.schemaVersion == SyncEnvelope.currentSchemaVersion)
    }

    @Test("Day query returns meals earliest first and excludes other days")
    func dayQuery() throws {
        let later = makeMeal(minutesAgo: 10)
        let earlier = makeMeal(minutesAgo: 120)
        let yesterday = makeMeal(minutesAgo: 60 * 30)
        for meal in [later, earlier, yesterday] { try repository.insert(meal) }
        let meals = try repository.meals(from: now.addingTimeInterval(-6 * 3600), to: now)
        #expect(meals.map(\.id) == [earlier.id, later.id])
    }
}
