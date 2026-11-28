import Foundation

/// A link between two timeline events, confirmed by the user: for now a glucose reading taken
/// before or after a meal. Links are never created without the user's confirmation.
///
/// Links live in their own table (see the data model), so a reading or a meal never changes
/// when a link is added or removed.
public struct EventLink: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    /// The reading.
    public var fromID: UUID
    /// The meal.
    public var toID: UUID
    public var relation: EventLinkRelation
    /// Signed minutes from meal start to the reading at the time of linking.
    public var minutesFromMealStart: Int?
    public var createdAt: Date
    public var modifiedAt: Date
    public var version: Int
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        fromID: UUID,
        toID: UUID,
        relation: EventLinkRelation,
        minutesFromMealStart: Int?,
        createdAt: Date,
        modifiedAt: Date? = nil,
        version: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.relation = relation
        self.minutesFromMealStart = minutesFromMealStart
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.version = version
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }
}

/// Storage for confirmed links.
@MainActor
public protocol EventLinkRepository: AnyObject {
    func insert(_ link: EventLink) throws
    func softDelete(id: UUID) throws
    /// Non-deleted links whose `fromID` is one of `fromIDs`.
    func links(fromIDs: Set<UUID>) throws -> [EventLink]
}

/// In-memory links for previews and tests.
@MainActor
public final class InMemoryEventLinkRepository: EventLinkRepository {
    public private(set) var storage: [UUID: EventLink] = [:]
    private let dateProvider: any DateProvider

    public init(links: [EventLink] = [], dateProvider: any DateProvider = SystemDateProvider()) {
        self.dateProvider = dateProvider
        for link in links { storage[link.id] = link }
    }

    public func insert(_ link: EventLink) throws {
        guard storage[link.id] == nil else { throw RepositoryError.duplicateID }
        storage[link.id] = link
    }

    public func softDelete(id: UUID) throws {
        guard var link = storage[id] else { throw RepositoryError.notFound }
        guard link.deletedAt == nil else { return }
        let now = dateProvider.now()
        link.deletedAt = now
        link.modifiedAt = now
        link.version += 1
        storage[id] = link
    }

    public func links(fromIDs: Set<UUID>) throws -> [EventLink] {
        storage.values
            .filter { !$0.isDeleted && fromIDs.contains($0.fromID) }
            .sorted { $0.createdAt < $1.createdAt }
    }
}
