import Foundation
import MetablyDomain

// Planned HealthKit integration: contracts only, no implementation in this milestone.
// This target deliberately does not `import HealthKit` yet, so the app needs no HealthKit
// entitlement or usage strings until the feature is built. See docs/adr/0003.
//
// Design rules carried over from the HealthKit mapping doc:
// - HealthKit is an external source/target, never the primary store.
// - Permissions are requested per type, only when the feature is first used.
// - HealthKit never reveals whether *read* access was granted: an empty result means
//   "no data or no access", and the UI must say so.
// - Every sample Metably writes carries HKMetadataKeySyncIdentifier = record id and
//   HKMetadataKeySyncVersion = record version; on import, samples from our own app are skipped.

/// Health data types Metably plans to read or write.
public enum HealthDataType: String, Sendable, Hashable, CaseIterable {
    case bloodGlucose
    case insulinDelivery
    case bodyMass
    case height
    case waistCircumference
    case bodyFatPercentage
    case bloodPressure
    case restingHeartRate
    case heartRate
    case heartRateVariability
    case stepCount
    case walkingRunningDistance
    case activeEnergy
    case workouts
    case sleepAnalysis
}

/// Mirrors `HKAuthorizationRequestStatus`: whether the system sheet would be shown.
/// It says nothing about whether read access was granted.
public enum HealthAuthorizationRequestStatus: Sendable, Hashable {
    case healthDataUnavailable
    case shouldRequest
    case alreadyRequested
}

public protocol HealthAuthorizationProviding: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestStatus(read: Set<HealthDataType>, write: Set<HealthDataType>) async throws -> HealthAuthorizationRequestStatus
    func requestAuthorization(read: Set<HealthDataType>, write: Set<HealthDataType>) async throws
}

/// Persists `HKQueryAnchor` data per type for incremental anchored imports.
public protocol HealthKitAnchorStore: Sendable {
    func anchor(for type: HealthDataType) async throws -> Data?
    func setAnchor(_ anchor: Data?, for type: HealthDataType) async throws
}

/// Result of one incremental import pass for a type.
public struct HealthKitImportBatch: Sendable {
    public var samples: [GlucoseSample]
    /// External ids of samples deleted in Health since the last anchor.
    public var deletedExternalIDs: [String]
    public var newAnchor: Data?

    public init(samples: [GlucoseSample], deletedExternalIDs: [String], newAnchor: Data?) {
        self.samples = samples
        self.deletedExternalIDs = deletedExternalIDs
        self.newAnchor = newAnchor
    }
}

/// Reads glucose incrementally (HKAnchoredObjectQuery in the future implementation).
public protocol HealthKitGlucoseReading: Sendable {
    func importGlucose(since anchor: Data?) async throws -> HealthKitImportBatch
}

/// Writes manual readings to Health. Only the originating device writes a record.
public protocol HealthKitGlucoseWriting: Sendable {
    func write(_ reading: GlucoseReading) async throws
    func deleteSample(syncIdentifier: UUID) async throws
}
