import Foundation
import MetablyDomain

extension GlucoseMeasurementContext {
    public var localizedName: String {
        switch self {
        case .fasting: String(localized: "context.fasting", bundle: .module)
        case .beforeMeal: String(localized: "context.beforeMeal", bundle: .module)
        case .afterMeal: String(localized: "context.afterMeal", bundle: .module)
        case .bedtime: String(localized: "context.bedtime", bundle: .module)
        case .night: String(localized: "context.night", bundle: .module)
        case .random: String(localized: "context.random", bundle: .module)
        }
    }
}

extension GlucoseEntryError {
    public var localizedMessage: String {
        switch self {
        case .empty:
            String(localized: "entry.error.empty", bundle: .module)
        case .notANumber:
            String(localized: "entry.error.notANumber", bundle: .module)
        case let .outOfPlausibleRange(lower, upper, unit):
            String(
                localized: "entry.error.range \(Self.format(lower, unit)) \(Self.format(upper, unit)) \(unit.symbol)",
                bundle: .module
            )
        case .measuredInFuture:
            String(localized: "entry.error.future", bundle: .module)
        }
    }

    private static func format(_ value: Double, _ unit: GlucoseUnit) -> String {
        value.formatted(.number.precision(.fractionLength(unit.fractionDigits)))
    }
}
