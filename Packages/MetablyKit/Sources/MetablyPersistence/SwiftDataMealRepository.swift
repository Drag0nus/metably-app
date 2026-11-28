import Foundation
import MetablyDomain
import OSLog
import SwiftData

/// SwiftData-backed `MealRepository`. Same guarantees as `SwiftDataGlucoseRepository`: each change
/// writes the record, a revision with the previous values and a coalesced outbox entry in one save.
///
/// Logging rule: never log food names, amounts, notes or identifiers. Only error types.
@MainActor
public final class SwiftDataMealRepository: MealRepository {
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

    // MARK: - Writes

    public func insert(_ meal: Meal) throws {
        guard try fetchEvent(id: meal.id) == nil else { throw RepositoryError.duplicateID }
        try transaction {
            let (event, detail, items) = MealRecordMapping.makeRecords(for: meal, deviceID: deviceID)
            context.insert(event)
            context.insert(detail)
            for item in items { context.insert(item) }
            detail.items = items
            event.meal = detail
            appendRevision(for: event, kind: .create, previous: nil)
            try enqueue(event: event, meal: meal, operation: .upsert)
        }
    }

    public func update(_ meal: Meal) throws {
        guard let event = try fetchEvent(id: meal.id), let detail = event.meal else {
            throw RepositoryError.notFound
        }
        let previous = try MealRecordMapping.makeMeal(from: event)
        try transaction {
            MealRecordMapping.apply(meal, to: event, detail: detail)
            for old in detail.items { context.delete(old) }
            let items = MealRecordMapping.makeItemRecords(meal.items)
            for item in items { context.insert(item) }
            detail.items = items
            touch(event)
            appendRevision(for: event, kind: .update, previous: previous)
            try enqueue(event: event, meal: try MealRecordMapping.makeMeal(from: event), operation: .upsert)
        }
    }

    public func softDelete(id: UUID) throws {
        guard let event = try fetchEvent(id: id), event.meal != nil else { throw RepositoryError.notFound }
        guard event.deletedAt == nil else { return }
        let previous = try MealRecordMapping.makeMeal(from: event)
        try transaction {
            event.deletedAt = dateProvider.now()
            touch(event)
            appendRevision(for: event, kind: .delete, previous: previous)
            try enqueue(event: event, meal: try MealRecordMapping.makeMeal(from: event), operation: .delete)
        }
    }

    // MARK: - Reads

    public func meal(id: UUID) throws -> Meal? {
        guard let event = try fetchEvent(id: id), event.meal != nil else { return nil }
        return try MealRecordMapping.makeMeal(from: event)
    }

    public func meals(from: Date, to: Date) throws -> [Meal] {
        let kind = EventKind.meal.rawValue
        let predicate = #Predicate<TimelineEventRecord> {
            $0.kindRaw == kind && $0.deletedAt == nil && $0.startDate >= from && $0.startDate < to
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate)])
        return try context.fetch(descriptor).map { try MealRecordMapping.makeMeal(from: $0) }
    }

    public func revisions(for recordID: UUID) throws -> [RecordRevisionRecord] {
        let predicate = #Predicate<RecordRevisionRecord> { $0.recordID == recordID }
        return try context.fetch(FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.version)]))
    }

    // MARK: - Private

    private func fetchEvent(id: UUID) throws -> TimelineEventRecord? {
        var descriptor = FetchDescriptor<TimelineEventRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func touch(_ event: TimelineEventRecord) {
        event.version += 1
        event.modifiedAt = dateProvider.now()
        event.lastModifiedDeviceID = deviceID
    }

    private func appendRevision(for event: TimelineEventRecord, kind: RevisionChangeKind, previous: Meal?) {
        let snapshot = previous.flatMap { try? encoder.encode($0) }
        context.insert(RecordRevisionRecord(
            recordID: event.id,
            entityType: MealRecordMapping.entityType,
            version: event.version,
            changedAt: dateProvider.now(),
            deviceID: deviceID,
            changeKindRaw: kind.rawValue,
            previousValues: snapshot
        ))
    }

    private func enqueue(event: TimelineEventRecord, meal: Meal, operation: SyncOperation) throws {
        let envelope = SyncEnvelope(
            recordID: event.id,
            entityType: MealRecordMapping.entityType,
            category: SyncCategory(rawValue: event.syncCategoryRaw) ?? .nutrition,
            operation: operation,
            baseVersion: event.serverVersion ?? 0,
            version: event.version,
            schemaVersion: event.schemaVersion,
            deviceID: deviceID,
            isHealthKitDerived: event.isHealthKitDerived,
            payload: try encoder.encode(meal)
        )
        let data = try encoder.encode(envelope)
        let recordID = event.id
        let existing = try context.fetch(FetchDescriptor<OutboxEntryRecord>(predicate: #Predicate { $0.recordID == recordID }))
        if let pending = existing.first {
            pending.operationRaw = operation.rawValue
            pending.envelope = data
        } else {
            context.insert(OutboxEntryRecord(
                recordID: recordID,
                entityType: MealRecordMapping.entityType,
                operationRaw: operation.rawValue,
                baseVersion: event.serverVersion ?? 0,
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
            Self.logger.error("Meal repository write failed: \(String(describing: type(of: error)), privacy: .public)")
            throw error
        }
    }
}
