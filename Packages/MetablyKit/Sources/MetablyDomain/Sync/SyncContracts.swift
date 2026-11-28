import Foundation

/// Sync contracts, defined from day one so local records stay sync-ready.
/// The sync engine itself (push/pull, cursors, backoff) is a later milestone; today the
/// outbox is filled in the same transaction as each change and simply not drained.

public enum SyncOperation: String, Sendable, Hashable, Codable {
    case upsert
    case delete
}

public enum RevisionChangeKind: String, Sendable, Hashable, Codable {
    case create
    case update
    case delete
    case merge
    case conflictResolved
}

/// A record as the sync engine sees it: versioned metadata plus an opaque payload.
/// The engine never needs domain knowledge, and the payload can later be encrypted
/// end-to-end without changing this shape.
public struct SyncEnvelope: Sendable, Hashable, Codable {
    /// Payload schema version. 2 adds the optional glucose `activityLevel`; 3 adds meals; 4 adds event links.
    public static let currentSchemaVersion = 4

    public var recordID: UUID
    public var entityType: String
    public var category: SyncCategory
    public var operation: SyncOperation
    /// Last server version this change is based on (0 = never synced). Used for optimistic concurrency.
    public var baseVersion: Int64
    /// Local version after the change.
    public var version: Int
    public var schemaVersion: Int
    public var deviceID: UUID
    public var isHealthKitDerived: Bool
    public var payload: Data

    public init(
        recordID: UUID,
        entityType: String,
        category: SyncCategory,
        operation: SyncOperation,
        baseVersion: Int64,
        version: Int,
        schemaVersion: Int = SyncEnvelope.currentSchemaVersion,
        deviceID: UUID,
        isHealthKitDerived: Bool,
        payload: Data
    ) {
        self.recordID = recordID
        self.entityType = entityType
        self.category = category
        self.operation = operation
        self.baseVersion = baseVersion
        self.version = version
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.isHealthKitDerived = isHealthKitDerived
        self.payload = payload
    }
}
