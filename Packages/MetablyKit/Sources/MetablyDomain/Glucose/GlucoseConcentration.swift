import Foundation

/// A blood glucose concentration, stored canonically in mmol/L.
///
/// This type is deliberately distinct from any nutrition quantity (for example dietary sugars
/// in grams), so the compiler prevents mixing blood glucose with sugar intake.
public struct GlucoseConcentration: Sendable, Hashable, Comparable, Codable {
    /// mg/dL per mmol/L for glucose (molar mass 180.16 g/mol). 1 mmol/L = 18.016 mg/dL.
    public static let milligramsPerDeciliterPerMillimolePerLiter: Double = 18.016

    /// Canonical value in mmol/L.
    public let millimolesPerLiter: Double

    public init(millimolesPerLiter: Double) {
        self.millimolesPerLiter = millimolesPerLiter
    }

    public init(value: Double, unit: GlucoseUnit) {
        switch unit {
        case .millimolesPerLiter:
            millimolesPerLiter = value
        case .milligramsPerDeciliter:
            millimolesPerLiter = value / Self.milligramsPerDeciliterPerMillimolePerLiter
        }
    }

    /// Unrounded value in the requested unit.
    public func value(in unit: GlucoseUnit) -> Double {
        switch unit {
        case .millimolesPerLiter:
            millimolesPerLiter
        case .milligramsPerDeciliter:
            millimolesPerLiter * Self.milligramsPerDeciliterPerMillimolePerLiter
        }
    }

    /// Value rounded to the display precision of the unit.
    public func roundedValue(in unit: GlucoseUnit) -> Double {
        let scale = pow(10.0, Double(unit.fractionDigits))
        return (value(in: unit) * scale).rounded(.toNearestOrAwayFromZero) / scale
    }

    /// Localized number without the unit symbol, e.g. "6,4" in Ukrainian or "6.4" in English.
    public func formattedValue(in unit: GlucoseUnit, locale: Locale = .current) -> String {
        roundedValue(in: unit).formatted(
            .number.precision(.fractionLength(unit.fractionDigits)).locale(locale)
        )
    }

    public static func < (lhs: GlucoseConcentration, rhs: GlucoseConcentration) -> Bool {
        lhs.millimolesPerLiter < rhs.millimolesPerLiter
    }
}
