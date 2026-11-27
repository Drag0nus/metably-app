import Foundation

/// What kind of thing a timeline event records. Raw values are persisted; never rename them.
public enum EventKind: String, Sendable, Hashable, Codable, CaseIterable {
    case glucose
    case meal
    case medication
    case bodyMeasurement
    case lab
    case activity
    case sleep
    case symptom
    case note

    public var syncCategory: SyncCategory {
        switch self {
        case .glucose: .glucose
        case .meal: .nutrition
        case .medication: .medication
        case .bodyMeasurement: .body
        case .lab: .labs
        case .activity: .activity
        case .sleep: .sleep
        case .symptom, .note: .diary
        }
    }
}

/// Where a record came from. Raw values are persisted; never rename them.
public enum EventSource: String, Sendable, Hashable, Codable, CaseIterable {
    case manual
    case watch
    case healthKit
    case bluetoothMeter
    case cgm
    case csvImport
    case vendorAPI
    /// Development-only synthetic data. Never produced in release builds.
    case synthetic
}

/// Data categories used for selective cloud sync (later milestone).
public enum SyncCategory: String, Sendable, Hashable, Codable, CaseIterable {
    case glucose
    case nutrition
    case medication
    case body
    case labs
    case activity
    case sleep
    case diary
}

/// Who or what created a record. Present on every record.
public struct Provenance: Sendable, Hashable, Codable {
    public var source: EventSource
    /// Stable id of the `GlucoseDataProvider` (or other importer) that produced the record.
    public var providerID: String
    /// Source app bundle id or similar.
    public var sourceDetail: String?
    public var deviceName: String?
    /// Hashed device serial. Never the raw serial.
    public var deviceSerialHash: String?
    /// Identifier in the source system, e.g. HealthKit sample UUID.
    public var externalID: String?

    public init(
        source: EventSource,
        providerID: String,
        sourceDetail: String? = nil,
        deviceName: String? = nil,
        deviceSerialHash: String? = nil,
        externalID: String? = nil
    ) {
        self.source = source
        self.providerID = providerID
        self.sourceDetail = sourceDetail
        self.deviceName = deviceName
        self.deviceSerialHash = deviceSerialHash
        self.externalID = externalID
    }

    public static let manual = Provenance(source: .manual, providerID: ManualGlucoseProvider.providerID)
}
