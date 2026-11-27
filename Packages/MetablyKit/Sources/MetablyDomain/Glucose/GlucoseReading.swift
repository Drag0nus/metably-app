import Foundation

/// One blood glucose measurement, as the domain sees it (a plain value type, no persistence).
///
/// Stores both the value exactly as entered and a canonical mmol/L value, the instant in UTC
/// plus the IANA time zone it was taken in, and where the value came from.
public struct GlucoseReading: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public var concentration: GlucoseConcentration
    public var enteredValue: Double
    public var enteredUnit: GlucoseUnit
    public var context: GlucoseMeasurementContext
    public var specimen: GlucoseSpecimen
    public var flags: GlucoseReadingFlags
    /// Minutes after the start of the linked meal, when known.
    public var minutesAfterMeal: Int?
    /// When the blood was measured (absolute instant).
    public var measuredAt: Date
    /// IANA identifier of the zone the reading was taken in, e.g. "Europe/Kyiv".
    public var timeZoneID: String
    /// True when the zone was not supplied by the source and was assumed at import.
    public var timeZoneIsInferred: Bool
    /// Diary day in the reading's own zone (day starts at local midnight).
    public var localDay: LocalDay
    public var provenance: Provenance
    public var note: String?
    /// Imported data the user has confirmed or edited.
    public var isUserVerified: Bool
    public var createdAt: Date
    public var modifiedAt: Date
    /// Local version, incremented on every change. Starts at 1.
    public var version: Int
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        enteredValue: Double,
        enteredUnit: GlucoseUnit,
        context: GlucoseMeasurementContext,
        specimen: GlucoseSpecimen = .capillary,
        flags: GlucoseReadingFlags = [],
        minutesAfterMeal: Int? = nil,
        measuredAt: Date,
        timeZone: TimeZone,
        timeZoneIsInferred: Bool = false,
        provenance: Provenance,
        note: String? = nil,
        isUserVerified: Bool = true,
        createdAt: Date,
        modifiedAt: Date? = nil,
        version: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.concentration = GlucoseConcentration(value: enteredValue, unit: enteredUnit)
        self.enteredValue = enteredValue
        self.enteredUnit = enteredUnit
        self.context = context
        self.specimen = specimen
        self.flags = flags
        self.minutesAfterMeal = minutesAfterMeal
        self.measuredAt = measuredAt
        self.timeZoneID = timeZone.identifier
        self.timeZoneIsInferred = timeZoneIsInferred
        self.localDay = LocalDay(instant: measuredAt, timeZone: timeZone)
        self.provenance = provenance
        self.note = note
        self.isUserVerified = isUserVerified
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.version = version
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }

    /// The zone the reading was taken in, falling back to UTC if the identifier is unknown.
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }
}
