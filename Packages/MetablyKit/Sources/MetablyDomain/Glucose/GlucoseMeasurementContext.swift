import Foundation

/// When a reading was taken relative to daily routine. Mirrors the columns of the
/// reference self-control diary (before / 2 h after each meal, bedtime, night).
public enum GlucoseMeasurementContext: String, Sendable, Hashable, Codable, CaseIterable {
    case fasting
    case beforeMeal
    case afterMeal
    case bedtime
    case night
    case random
}

/// What the sample was measured from. Lets analytics keep fingerstick and continuous data apart.
public enum GlucoseSpecimen: String, Sendable, Hashable, Codable, CaseIterable {
    /// Fingerstick capillary blood (meter). Default for manual entries.
    case capillary
    /// Interstitial fluid from a CGM sensor (future source).
    case cgmInterstitial
    /// Venous plasma measured by a laboratory.
    case lab
}

/// Meter-specific markers that change how a value must be interpreted.
public struct GlucoseReadingFlags: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Meter showed "LO": the true value is below the stored value (the meter's lower limit).
    public static let meterLow = GlucoseReadingFlags(rawValue: 1 << 0)
    /// Meter showed "HI": the true value is above the stored value (the meter's upper limit).
    public static let meterHigh = GlucoseReadingFlags(rawValue: 1 << 1)
    /// Control solution test, not a blood measurement. Excluded from analytics.
    public static let controlSolution = GlucoseReadingFlags(rawValue: 1 << 2)
}
