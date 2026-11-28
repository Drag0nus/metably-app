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

extension DiarySlot {
    public var localizedName: String {
        switch self {
        case .fasting: String(localized: "slot.fasting", bundle: .module)
        case .afterBreakfast: String(localized: "slot.afterBreakfast", bundle: .module)
        case .beforeLunch: String(localized: "slot.beforeLunch", bundle: .module)
        case .afterLunch: String(localized: "slot.afterLunch", bundle: .module)
        case .beforeDinner: String(localized: "slot.beforeDinner", bundle: .module)
        case .afterDinner: String(localized: "slot.afterDinner", bundle: .module)
        case .bedtime: String(localized: "slot.bedtime", bundle: .module)
        case .night: String(localized: "slot.night", bundle: .module)
        case .other: String(localized: "slot.other", bundle: .module)
        }
    }

    /// Two-to-three letter label for the compact 7-slot strip.
    public var shortName: String {
        switch self {
        case .fasting: String(localized: "slot.short.fasting", bundle: .module)
        case .afterBreakfast: String(localized: "slot.short.afterBreakfast", bundle: .module)
        case .beforeLunch: String(localized: "slot.short.beforeLunch", bundle: .module)
        case .afterLunch: String(localized: "slot.short.afterLunch", bundle: .module)
        case .beforeDinner: String(localized: "slot.short.beforeDinner", bundle: .module)
        case .afterDinner: String(localized: "slot.short.afterDinner", bundle: .module)
        case .bedtime: String(localized: "slot.short.bedtime", bundle: .module)
        case .night: String(localized: "slot.short.night", bundle: .module)
        case .other: String(localized: "slot.short.other", bundle: .module)
        }
    }
}

extension GlucoseTargetStatus {
    public var localizedName: String {
        switch self {
        case .below: String(localized: "status.below", bundle: .module)
        case .inRange: String(localized: "status.inRange", bundle: .module)
        case .above: String(localized: "status.above", bundle: .module)
        }
    }

    /// Status is never shown by colour alone: symbol and word always go with it.
    public var symbolName: String {
        switch self {
        case .below: "arrow.down"
        case .inRange: "checkmark"
        case .above: "arrow.up"
        }
    }
}

extension EventSource {
    public var localizedName: String {
        switch self {
        case .manual: String(localized: "source.manual", bundle: .module)
        case .watch: String(localized: "source.watch", bundle: .module)
        case .healthKit: String(localized: "source.healthKit", bundle: .module)
        case .bluetoothMeter: String(localized: "source.bluetoothMeter", bundle: .module)
        case .cgm: String(localized: "source.cgm", bundle: .module)
        case .csvImport: String(localized: "source.csvImport", bundle: .module)
        case .vendorAPI: String(localized: "source.vendorAPI", bundle: .module)
        case .synthetic: String(localized: "source.synthetic", bundle: .module)
        }
    }
}
