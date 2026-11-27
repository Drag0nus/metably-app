import Foundation

/// Units a blood glucose concentration can be entered or displayed in.
///
/// The raw value is the unit symbol, which is also what we persist, so it must never change.
public enum GlucoseUnit: String, Sendable, Hashable, Codable, CaseIterable {
    case millimolesPerLiter = "mmol/L"
    case milligramsPerDeciliter = "mg/dL"

    /// Fraction digits used when displaying a value in this unit:
    /// mmol/L with one decimal, mg/dL as an integer (common meter convention).
    public var fractionDigits: Int {
        switch self {
        case .millimolesPerLiter: 1
        case .milligramsPerDeciliter: 0
        }
    }

    public var symbol: String { rawValue }
}
