import Foundation
import SwiftData

/// Version 3 of the on-device schema: adds meals (`MealRecord`, `MealItemRecord`) and the
/// `TimelineEventRecord.meal` relationship. New entities and an optional relationship are a
/// lightweight migration; V1 and V2 stay frozen as shipped.
public enum MetablySchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            TimelineEventRecord.self,
            GlucoseReadingRecord.self,
            MealRecord.self,
            MealItemRecord.self,
            RecordRevisionRecord.self,
            OutboxEntryRecord.self,
        ]
    }
}

extension MetablySchemaV3 {
    /// Header of every timeline row: when, what kind, where it came from, plus sync metadata.
    /// Exactly one detail record hangs off it (only glucose exists in V1).
    @Model
    public final class TimelineEventRecord {
        #Index<TimelineEventRecord>([\.startDate], [\.localDay], [\.kindRaw], [\.externalID])

        @Attribute(.unique) public var id: UUID
        public var kindRaw: String
        public var startDate: Date
        public var endDate: Date
        public var timeZoneID: String
        public var timeZoneIsInferred: Bool
        /// "YYYY-MM-DD" in the event's own zone.
        public var localDay: String
        public var sourceRaw: String
        public var providerID: String
        public var sourceDetail: String?
        public var externalID: String?
        public var isUserVerified: Bool
        public var note: String?
        public var createdAt: Date
        public var modifiedAt: Date
        public var deletedAt: Date?

        // Sync metadata (see the data model's "Sync, versioning and provenance fields").
        public var version: Int
        public var serverVersion: Int64?
        public var originDeviceID: UUID
        public var lastModifiedDeviceID: UUID
        public var syncCategoryRaw: String
        public var isHealthKitDerived: Bool
        public var schemaVersion: Int

        @Relationship(deleteRule: .cascade, inverse: \GlucoseReadingRecord.event)
        public var glucose: GlucoseReadingRecord?

        @Relationship(deleteRule: .cascade, inverse: \MealRecord.event)
        public var meal: MealRecord?

        public init(
            id: UUID,
            kindRaw: String,
            startDate: Date,
            endDate: Date,
            timeZoneID: String,
            timeZoneIsInferred: Bool,
            localDay: String,
            sourceRaw: String,
            providerID: String,
            sourceDetail: String?,
            externalID: String?,
            isUserVerified: Bool,
            note: String?,
            createdAt: Date,
            modifiedAt: Date,
            deletedAt: Date?,
            version: Int,
            serverVersion: Int64?,
            originDeviceID: UUID,
            lastModifiedDeviceID: UUID,
            syncCategoryRaw: String,
            isHealthKitDerived: Bool,
            schemaVersion: Int
        ) {
            self.id = id
            self.kindRaw = kindRaw
            self.startDate = startDate
            self.endDate = endDate
            self.timeZoneID = timeZoneID
            self.timeZoneIsInferred = timeZoneIsInferred
            self.localDay = localDay
            self.sourceRaw = sourceRaw
            self.providerID = providerID
            self.sourceDetail = sourceDetail
            self.externalID = externalID
            self.isUserVerified = isUserVerified
            self.note = note
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.deletedAt = deletedAt
            self.version = version
            self.serverVersion = serverVersion
            self.originDeviceID = originDeviceID
            self.lastModifiedDeviceID = lastModifiedDeviceID
            self.syncCategoryRaw = syncCategoryRaw
            self.isHealthKitDerived = isHealthKitDerived
            self.schemaVersion = schemaVersion
        }
    }

    /// Glucose detail of a timeline event.
    @Model
    public final class GlucoseReadingRecord {
        public var valueMmolL: Double
        public var enteredValue: Double
        public var enteredUnitRaw: String
        public var contextRaw: String
        public var specimenRaw: String
        public var flagsRaw: Int
        public var minutesAfterMeal: Int?
        public var deviceName: String?
        public var deviceSerialHash: String?
        /// Activity level 1–5 at the time of the check (paper diary scale). New in V2; nil when
        /// not recorded, including every reading created before V2.
        public var activityLevel: Int? = nil
        public var event: TimelineEventRecord?

        public init(
            valueMmolL: Double,
            enteredValue: Double,
            enteredUnitRaw: String,
            contextRaw: String,
            specimenRaw: String,
            flagsRaw: Int,
            minutesAfterMeal: Int?,
            deviceName: String?,
            deviceSerialHash: String?,
            activityLevel: Int?
        ) {
            self.valueMmolL = valueMmolL
            self.enteredValue = enteredValue
            self.enteredUnitRaw = enteredUnitRaw
            self.contextRaw = contextRaw
            self.specimenRaw = specimenRaw
            self.flagsRaw = flagsRaw
            self.minutesAfterMeal = minutesAfterMeal
            self.deviceName = deviceName
            self.deviceSerialHash = deviceSerialHash
            self.activityLevel = activityLevel
        }
    }

    /// Append-only history. Keeps the previous state of a record on every change, so edited
    /// measurements never lose their original value, unit, timestamp or source.
    @Model
    public final class RecordRevisionRecord {
        #Index<RecordRevisionRecord>([\.recordID])

        @Attribute(.unique) public var id: UUID
        public var recordID: UUID
        public var entityType: String
        public var version: Int
        public var changedAt: Date
        public var deviceID: UUID
        public var changeKindRaw: String
        /// JSON snapshot of the record before the change (nil for `create`).
        public var previousValues: Data?

        public init(
            id: UUID = UUID(),
            recordID: UUID,
            entityType: String,
            version: Int,
            changedAt: Date,
            deviceID: UUID,
            changeKindRaw: String,
            previousValues: Data?
        ) {
            self.id = id
            self.recordID = recordID
            self.entityType = entityType
            self.version = version
            self.changedAt = changedAt
            self.deviceID = deviceID
            self.changeKindRaw = changeKindRaw
            self.previousValues = previousValues
        }
    }

    /// Transactional outbox: written in the same save as the change it describes.
    /// At most one pending entry per record; later changes coalesce into it.
    @Model
    public final class OutboxEntryRecord {
        #Index<OutboxEntryRecord>([\.recordID], [\.nextAttemptAt])

        @Attribute(.unique) public var id: UUID
        public var recordID: UUID
        public var entityType: String
        public var operationRaw: String
        public var baseVersion: Int64
        /// JSON-encoded `SyncEnvelope`.
        public var envelope: Data
        public var createdAt: Date
        public var attempts: Int
        public var nextAttemptAt: Date
        public var lastError: String?

        public init(
            id: UUID = UUID(),
            recordID: UUID,
            entityType: String,
            operationRaw: String,
            baseVersion: Int64,
            envelope: Data,
            createdAt: Date,
            attempts: Int = 0,
            nextAttemptAt: Date,
            lastError: String? = nil
        ) {
            self.id = id
            self.recordID = recordID
            self.entityType = entityType
            self.operationRaw = operationRaw
            self.baseVersion = baseVersion
            self.envelope = envelope
            self.createdAt = createdAt
            self.attempts = attempts
            self.nextAttemptAt = nextAttemptAt
            self.lastError = lastError
        }
    }

    /// Meal detail of a timeline event (new in V3). Time, zone and day live on the event.
    @Model
    public final class MealRecord {
        public var slotRaw: String
        public var statusRaw: String
        public var portionSizeRaw: String?
        @Relationship(deleteRule: .cascade, inverse: \MealItemRecord.meal)
        public var items: [MealItemRecord] = []
        public var event: TimelineEventRecord?

        public init(slotRaw: String, statusRaw: String, portionSizeRaw: String?) {
            self.slotRaw = slotRaw
            self.statusRaw = statusRaw
            self.portionSizeRaw = portionSizeRaw
        }
    }

    /// One food of a meal (new in V3). `position` keeps the user's order.
    @Model
    public final class MealItemRecord {
        public var id: UUID
        public var position: Int
        public var name: String
        public var amountGrams: Double?
        public var carbohydrateGrams: Double
        public var sugarsGrams: Double?
        public var fiberGrams: Double?
        public var proteinGrams: Double?
        public var fatGrams: Double?
        public var energyKilocalories: Double?
        public var meal: MealRecord?

        public init(
            id: UUID,
            position: Int,
            name: String,
            amountGrams: Double?,
            carbohydrateGrams: Double,
            sugarsGrams: Double?,
            fiberGrams: Double?,
            proteinGrams: Double?,
            fatGrams: Double?,
            energyKilocalories: Double?
        ) {
            self.id = id
            self.position = position
            self.name = name
            self.amountGrams = amountGrams
            self.carbohydrateGrams = carbohydrateGrams
            self.sugarsGrams = sugarsGrams
            self.fiberGrams = fiberGrams
            self.proteinGrams = proteinGrams
            self.fatGrams = fatGrams
            self.energyKilocalories = energyKilocalories
        }
    }
}
