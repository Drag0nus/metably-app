import Foundation

/// How a reading relates to the user's own target for its context.
public enum GlucoseTargetStatus: Sendable, Hashable {
    case below
    case inRange
    case above
}

/// The user's glucose targets, stored canonically in mmol/L.
///
/// Defaults follow the ADA Standards of Care for adults with diabetes (section 6, glycemic goals):
/// before meals 4.4–7.2 mmol/L (80–130 mg/dL), peak after meals below 10.0 mmol/L (180 mg/dL).
/// The low threshold is ADA level 1 hypoglycemia, below 3.9 mmol/L (70 mg/dL).
/// Targets are personal and set with a doctor; every value here is user-editable.
///
/// Bedtime, night and other readings have no default target: the app does not invent one.
/// For those contexts only the low threshold applies.
public struct GlucoseTargets: Sendable, Hashable, Codable {
    /// Before meals and fasting.
    public var preMealLowerMmolL: Double
    public var preMealUpperMmolL: Double
    /// Upper bound after meals (about 1–2 h after the start of the meal).
    public var postMealUpperMmolL: Double

    /// ADA level 1 hypoglycemia threshold. Fixed: it drives the low-glucose guidance.
    public static let lowThresholdMmolL: Double = 3.9

    /// Editable bounds that keep a mistyped target from making every reading "in range".
    public static let editableRangeMmolL: ClosedRange<Double> = 3.0...15.0

    public static let adaDefaults = GlucoseTargets(
        preMealLowerMmolL: 4.4,
        preMealUpperMmolL: 7.2,
        postMealUpperMmolL: 10.0
    )

    public init(preMealLowerMmolL: Double, preMealUpperMmolL: Double, postMealUpperMmolL: Double) {
        self.preMealLowerMmolL = preMealLowerMmolL
        self.preMealUpperMmolL = preMealUpperMmolL
        self.postMealUpperMmolL = postMealUpperMmolL
    }

    /// True when the bounds are ordered and inside the editable range.
    public var isValid: Bool {
        let range = Self.editableRangeMmolL
        return range.contains(preMealLowerMmolL)
            && range.contains(preMealUpperMmolL)
            && range.contains(postMealUpperMmolL)
            && preMealLowerMmolL < preMealUpperMmolL
            && preMealUpperMmolL <= postMealUpperMmolL
    }

    /// Target range for a context, or nil when the user has no target for it.
    public func range(for context: GlucoseMeasurementContext) -> ClosedRange<Double>? {
        switch context {
        case .fasting, .beforeMeal: preMealLowerMmolL...preMealUpperMmolL
        case .afterMeal: preMealLowerMmolL...postMealUpperMmolL
        case .bedtime, .night, .random: nil
        }
    }

    /// Status of a value in its context. Contexts without a target only report `below`
    /// when the value is under the low threshold, otherwise nil (no verdict).
    ///
    /// Value and bounds are compared at the display precision of `unit` (the unit the value was
    /// entered in), so 130 mg/dL is "in target" for an upper bound of 7.2 mmol/L even though
    /// 130 mg/dL is 7.22 mmol/L unrounded.
    public func status(
        of concentration: GlucoseConcentration,
        context: GlucoseMeasurementContext,
        comparedIn unit: GlucoseUnit = .millimolesPerLiter
    ) -> GlucoseTargetStatus? {
        guard let range = range(for: context) else {
            return Self.isLow(concentration, comparedIn: unit) ? .below : nil
        }
        let value = concentration.roundedValue(in: unit)
        if value < GlucoseConcentration(millimolesPerLiter: range.lowerBound).roundedValue(in: unit) { return .below }
        if value > GlucoseConcentration(millimolesPerLiter: range.upperBound).roundedValue(in: unit) { return .above }
        return .inRange
    }

    /// Below the level 1 hypoglycemia threshold: under 3.9 mmol/L, or under 70 mg/dL for
    /// values entered in mg/dL.
    public static func isLow(
        _ concentration: GlucoseConcentration,
        comparedIn unit: GlucoseUnit = .millimolesPerLiter
    ) -> Bool {
        concentration.roundedValue(in: unit)
            < GlucoseConcentration(millimolesPerLiter: lowThresholdMmolL).roundedValue(in: unit)
    }
}

extension GlucoseReading {
    /// Status against the user's targets. Meter "HI"/"LO" readings report their direction.
    public func targetStatus(using targets: GlucoseTargets) -> GlucoseTargetStatus? {
        if flags.contains(.meterLow) { return .below }
        if flags.contains(.meterHigh) { return .above }
        return targets.status(of: concentration, context: context, comparedIn: enteredUnit)
    }

    public var isLow: Bool {
        flags.contains(.meterLow) || GlucoseTargets.isLow(concentration, comparedIn: enteredUnit)
    }
}
