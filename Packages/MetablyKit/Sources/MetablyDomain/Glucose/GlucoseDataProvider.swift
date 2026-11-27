import Foundation

/// Kinds of glucose sources. Metably is vendor-neutral: every source sits behind
/// `GlucoseDataProvider` and is turned into readings by `GlucoseSampleIngestor`.
///
/// | Source            | Priority |
/// |-------------------|----------|
/// | Manual entry      | MVP      |
/// | Apple HealthKit   | High     |
/// | Bluetooth meter   | Later    |
/// | CGM               | Later    |
/// | CSV import        | Later    |
/// | Vendor APIs       | Future   |
public enum GlucoseProviderKind: String, Sendable, Hashable, Codable, CaseIterable {
    case manual
    case healthKit
    case bluetoothMeter
    case cgm
    case csvImport
    case vendorAPI
    /// Development-only generator. Never available in release builds.
    case synthetic

    public var eventSource: EventSource {
        switch self {
        case .manual: .manual
        case .healthKit: .healthKit
        case .bluetoothMeter: .bluetoothMeter
        case .cgm: .cgm
        case .csvImport: .csvImport
        case .vendorAPI: .vendorAPI
        case .synthetic: .synthetic
        }
    }
}

/// A raw glucose value as delivered by a source, before validation and mapping.
public struct GlucoseSample: Sendable, Hashable {
    public var value: Double
    public var unit: GlucoseUnit
    public var measuredAt: Date
    public var timeZone: TimeZone
    /// True when the source did not supply a time zone and the device zone was assumed.
    public var timeZoneIsInferred: Bool
    public var context: GlucoseMeasurementContext?
    public var specimen: GlucoseSpecimen
    public var flags: GlucoseReadingFlags
    public var deviceName: String?
    /// Hash of the device serial number. Never store the raw serial.
    public var deviceSerialHash: String?
    /// Identifier of the sample in the source system (e.g. a HealthKit sample UUID).
    public var externalID: String?
    /// Source app bundle id or similar.
    public var sourceDetail: String?
    public var note: String?

    public init(
        value: Double,
        unit: GlucoseUnit,
        measuredAt: Date,
        timeZone: TimeZone,
        timeZoneIsInferred: Bool = false,
        context: GlucoseMeasurementContext? = nil,
        specimen: GlucoseSpecimen = .capillary,
        flags: GlucoseReadingFlags = [],
        deviceName: String? = nil,
        deviceSerialHash: String? = nil,
        externalID: String? = nil,
        sourceDetail: String? = nil,
        note: String? = nil
    ) {
        self.value = value
        self.unit = unit
        self.measuredAt = measuredAt
        self.timeZone = timeZone
        self.timeZoneIsInferred = timeZoneIsInferred
        self.context = context
        self.specimen = specimen
        self.flags = flags
        self.deviceName = deviceName
        self.deviceSerialHash = deviceSerialHash
        self.externalID = externalID
        self.sourceDetail = sourceDetail
        self.note = note
    }
}

/// A source of glucose samples. Implementations must not persist anything themselves;
/// they only deliver samples, and the importer decides what becomes a reading.
public protocol GlucoseDataProvider: Sendable {
    /// Stable identifier stored in `Provenance.providerID`, e.g. "manual", "healthkit".
    var id: String { get }
    var displayName: String { get }
    var kind: GlucoseProviderKind { get }
    /// Whether the source can deliver data right now (device support, permission, pairing).
    var isAvailable: Bool { get async }
    /// Samples measured after `since` (or all available samples when nil).
    func fetchSamples(since: Date?) async throws -> [GlucoseSample]
}

/// Manual entry. Samples are pushed by the entry screen rather than pulled, so
/// `fetchSamples` returns nothing; the provider exists so manual readings carry the
/// same provenance shape as every other source.
public struct ManualGlucoseProvider: GlucoseDataProvider {
    public static let providerID = "manual"

    public init() {}

    public var id: String { Self.providerID }
    public var displayName: String { "Manual entry" }
    public var kind: GlucoseProviderKind { .manual }
    public var isAvailable: Bool { get async { true } }
    public func fetchSamples(since: Date?) async throws -> [GlucoseSample] { [] }
}
