import Foundation
import MetablyDomain
import OSLog
import SwiftData

/// SwiftData-backed `EventLinkRepository`. Each change writes the link, a revision and a
/// coalesced outbox entry in one save, like the other repositories.
///
/// Logging rule: never log identifiers. Only error types.
@MainActor
public final class SwiftDataEventLinkRepository: EventLinkRepository {
    static let entityType = "eventLink"

    private let context: ModelContext
    private let deviceID: UUID
    private let dateProvider: any DateProvider
    private let encoder: JSONEncoder
    private static let logger = Logger(subsystem: "app.metably", category: "persistence")

    public init(context: ModelContext, deviceID: UUID, dateProvider: any DateProvider = SystemDateProvider()) {
        self.context = context
        self.deviceID = deviceID
        self.dateProvider = dateProvider
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    public func insert(_ link: EventLink) throws {
        guard try fetch(id: link.id) == nil else { throw RepositoryError.duplicateID }
        try transaction {
            let record = EventLinkRecord(
                id: link.id,
                fromID: link.fromID,
                toID: link.toID,
                relationRaw: link.relation.rawValue,
                minutesFromMealStart: link.minutesFromMealStart,
                createdAt: link.createdAt,
                modifiedAt: link.modifiedAt,
                deletedAt: link.deletedAt,
                version: link.version,
                serverVersion: nil,
                originDeviceID: deviceID,
                lastModifiedDeviceID: deviceID,
                schemaVersion: SyncEnvelope.currentSchemaVersion
            )
            context.insert(record)
            appendRevision(for: record, kind: .create, previous: nil)
            try enqueue(record, operation: .upsert)
        }
    }

    public func softDelete(id: UUID) throws {
        guard let record = try fetch(id: id) else { throw RepositoryError.notFound }
        guard record.deletedAt == nil else { return }
        let previous = try Self.makeLink(from: record)
        try transaction {
            record.deletedAt = dateProvider.now()
            record.modifiedAt = dateProvider.now()
            record.version += 1
            record.lastModifiedDeviceID = deviceID
            appendRevision(for: record, kind: .delete, previous: previous)
            try enqueue(record, operation: .delete)
        }
    }

    public func links(fromIDs: Set<UUID>) throws -> [EventLink] {
        guard !fromIDs.isEmpty else { return [] }
        let ids = Array(fromIDs)
        let predicate = #Predicate<EventLinkRecord> { $0.deletedAt == nil && ids.contains($0.fromID) }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).map { try Self.makeLink(from: $0) }
    }

    // MARK: - Private

    static func makeLink(from record: EventLinkRecord) throws(RepositoryError) -> EventLink {
        guard let relation = EventLinkRelation(rawValue: record.relationRaw) else { throw .corruptRecord }
        return EventLink(
            id: record.id,
            fromID: record.fromID,
            toID: record.toID,
            relation: relation,
            minutesFromMealStart: record.minutesFromMealStart,
            createdAt: record.createdAt,
            modifiedAt: record.modifiedAt,
            version: record.version,
            deletedAt: record.deletedAt
        )
    }

    private func fetch(id: UUID) throws -> EventLinkRecord? {
        var descriptor = FetchDescriptor<EventLinkRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func appendRevision(for record: EventLinkRecord, kind: RevisionChangeKind, previous: EventLink?) {
        let snapshot = previous.flatMap { try? encoder.encode($0) }
        context.insert(RecordRevisionRecord(
            recordID: record.id,
            entityType: Self.entityType,
            version: record.version,
            changedAt: dateProvider.now(),
            deviceID: deviceID,
            changeKindRaw: kind.rawValue,
            previousValues: snapshot
        ))
    }

    private func enqueue(_ record: EventLinkRecord, operation: SyncOperation) throws {
        let envelope = SyncEnvelope(
            recordID: record.id,
            entityType: Self.entityType,
            // A link carries no values of its own; it syncs with the glucose category it explains.
            category: .glucose,
            operation: operation,
            baseVersion: record.serverVersion ?? 0,
            version: record.version,
            schemaVersion: record.schemaVersion,
            deviceID: deviceID,
            isHealthKitDerived: false,
            payload: try encoder.encode(try Self.makeLink(from: record))
        )
        let data = try encoder.encode(envelope)
        let recordID = record.id
        let existing = try context.fetch(FetchDescriptor<OutboxEntryRecord>(predicate: #Predicate { $0.recordID == recordID }))
        if let pending = existing.first {
            pending.operationRaw = operation.rawValue
            pending.envelope = data
        } else {
            context.insert(OutboxEntryRecord(
                recordID: recordID,
                entityType: Self.entityType,
                operationRaw: operation.rawValue,
                baseVersion: record.serverVersion ?? 0,
                envelope: data,
                createdAt: dateProvider.now(),
                nextAttemptAt: dateProvider.now()
            ))
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        do {
            try body()
            try context.save()
        } catch {
            context.rollback()
            Self.logger.error("Event link repository write failed: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
    }
}
