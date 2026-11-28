import Foundation
import MetablyDomain
import SwiftData
import Testing
@testable import MetablyPersistence

@MainActor
@Suite("SwiftData event link repository")
struct SwiftDataEventLinkRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    /// Owned by the suite so the context stays valid for the whole test.
    let container: ModelContainer
    let repository: SwiftDataEventLinkRepository

    init() throws {
        container = try MetablyModelContainer.make(inMemory: true)
        repository = SwiftDataEventLinkRepository(
            context: container.mainContext, deviceID: UUID(),
            dateProvider: FixedDateProvider(Date(timeIntervalSince1970: 1_800_000_000))
        )
    }

    @Test("Links round-trip and are found by reading")
    func roundTrip() throws {
        let reading = UUID()
        let link = EventLink(fromID: reading, toID: UUID(), relation: .postMeal, minutesFromMealStart: 115, createdAt: now)
        try repository.insert(link)
        try repository.insert(EventLink(fromID: UUID(), toID: UUID(), relation: .preMeal, minutesFromMealStart: -10, createdAt: now))
        #expect(try repository.links(fromIDs: [reading]) == [link])
        #expect(try repository.links(fromIDs: []).isEmpty)
        #expect(throws: RepositoryError.duplicateID) { try repository.insert(link) }
    }

    @Test("Soft delete hides the link, keeps a revision and queues one delete")
    func softDelete() throws {
        let reading = UUID()
        let link = EventLink(fromID: reading, toID: UUID(), relation: .postMeal, minutesFromMealStart: 120, createdAt: now)
        try repository.insert(link)
        try repository.softDelete(id: link.id)
        #expect(try repository.links(fromIDs: [reading]).isEmpty)

        let revisions = try container.mainContext.fetch(FetchDescriptor<RecordRevisionRecord>(sortBy: [SortDescriptor(\.version)]))
        #expect(revisions.map(\.changeKindRaw) == ["create", "delete"])
        let outbox = try container.mainContext.fetch(FetchDescriptor<OutboxEntryRecord>())
        #expect(outbox.count == 1)
        #expect(outbox.first?.operationRaw == "delete")
        #expect(outbox.first?.entityType == "eventLink")
        #expect(throws: RepositoryError.notFound) { try repository.softDelete(id: UUID()) }
    }
}
