import Foundation

public enum GlucoseEntryError: Error, Sendable, Hashable {
    case empty
    case notANumber
    /// Outside the technical plausibility bounds; the range is expressed in the entered unit.
    case outOfPlausibleRange(lower: Double, upper: Double, unit: GlucoseUnit)
    /// The measurement time is later than now (beyond a small clock tolerance).
    case measuredInFuture
}

/// Validates glucose input before it becomes a fact in the diary.
///
/// The bounds below are **technical plausibility limits to catch typos**, not clinical targets
/// and not a diagnosis. Home meters typically report roughly 0.6–33.3 mmol/L (10–600 mg/dL) and
/// show "LO"/"HI" outside that; such readings are recorded with `GlucoseReadingFlags` instead.
public struct GlucoseEntryValidator: Sendable {
    public static let plausibleRangeMillimolesPerLiter: ClosedRange<Double> = 0.5...35.0
    /// Allowed clock skew between the device and the meter when checking for future times.
    public static let futureTolerance: TimeInterval = 5 * 60

    public init() {}

    public func validate(text: String, unit: GlucoseUnit) -> Result<Double, GlucoseEntryError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard let value = GlucoseValueParser.parse(trimmed) else { return .failure(.notANumber) }
        return validate(value: value, unit: unit, flags: [])
    }

    public func validate(
        value: Double,
        unit: GlucoseUnit,
        flags: GlucoseReadingFlags
    ) -> Result<Double, GlucoseEntryError> {
        // A meter "LO"/"HI" value is the meter's own limit; keep it as reported.
        if !flags.intersection([.meterLow, .meterHigh]).isEmpty { return .success(value) }
        let mmol = GlucoseConcentration(value: value, unit: unit).millimolesPerLiter
        guard Self.plausibleRangeMillimolesPerLiter.contains(mmol) else {
            let range = Self.plausibleRangeMillimolesPerLiter
            return .failure(.outOfPlausibleRange(
                lower: GlucoseConcentration(millimolesPerLiter: range.lowerBound).roundedValue(in: unit),
                upper: GlucoseConcentration(millimolesPerLiter: range.upperBound).roundedValue(in: unit),
                unit: unit
            ))
        }
        return .success(value)
    }

    public func validate(measuredAt: Date, now: Date) -> GlucoseEntryError? {
        measuredAt.timeIntervalSince(now) > Self.futureTolerance ? .measuredInFuture : nil
    }
}
