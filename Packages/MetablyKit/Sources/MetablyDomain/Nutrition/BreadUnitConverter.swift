import Foundation

public enum BreadUnitConverterError: Error, Sendable, Hashable {
    case factorOutOfRange
}

/// Converts carbohydrate grams to bread units (XE, "хлібні одиниці").
///
/// Grams are always the stored fact; bread units are derived for display only.
/// Both 10 g and 12 g systems are in use; Metably defaults to 12 g and lets the user change it.
public struct BreadUnitConverter: Sendable, Hashable, Codable {
    public static let defaultCarbsPerBreadUnit: Double = 12
    /// Accepted configuration range, wide enough for the 10 g and 12 g systems and local variants.
    public static let allowedCarbsPerBreadUnit: ClosedRange<Double> = 5...20
    public static let standard = BreadUnitConverter(unchecked: defaultCarbsPerBreadUnit)

    public let carbsPerBreadUnit: Double

    public init(carbsPerBreadUnit: Double) throws(BreadUnitConverterError) {
        guard carbsPerBreadUnit.isFinite, Self.allowedCarbsPerBreadUnit.contains(carbsPerBreadUnit) else {
            throw .factorOutOfRange
        }
        self.carbsPerBreadUnit = carbsPerBreadUnit
    }

    private init(unchecked value: Double) {
        carbsPerBreadUnit = value
    }

    public func breadUnits(forCarbohydrateGrams grams: Double) -> Double {
        grams / carbsPerBreadUnit
    }

    public func carbohydrateGrams(forBreadUnits units: Double) -> Double {
        units * carbsPerBreadUnit
    }
}
