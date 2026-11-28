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

extension MealSlot {
    public var localizedName: String {
        switch self {
        case .breakfast: String(localized: "meal.slot.breakfast", bundle: .module)
        case .lunch: String(localized: "meal.slot.lunch", bundle: .module)
        case .dinner: String(localized: "meal.slot.dinner", bundle: .module)
        case .snack: String(localized: "meal.slot.snack", bundle: .module)
        }
    }

    public var symbolName: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "sunset"
        case .snack: "carrot"
        }
    }
}

extension PortionSize {
    /// The paper diary's letters: М / С / В in Ukrainian, S / M / L in English.
    public var shortName: String {
        switch self {
        case .small: String(localized: "meal.portion.short.small", bundle: .module)
        case .medium: String(localized: "meal.portion.short.medium", bundle: .module)
        case .large: String(localized: "meal.portion.short.large", bundle: .module)
        }
    }

    public var localizedName: String {
        switch self {
        case .small: String(localized: "meal.portion.small", bundle: .module)
        case .medium: String(localized: "meal.portion.medium", bundle: .module)
        case .large: String(localized: "meal.portion.large", bundle: .module)
        }
    }
}

extension MealEntryModel.SaveError {
    public var localizedMessage: String {
        switch self {
        case .invalid(.noItems): String(localized: "meal.error.noItems", bundle: .module)
        case .invalid(.emptyName): String(localized: "meal.error.emptyName", bundle: .module)
        case .invalid(.carbohydratesOutOfRange): String(localized: "meal.error.carbs", bundle: .module)
        case .invalid(.amountOutOfRange): String(localized: "meal.error.amount", bundle: .module)
        case .invalid(.nutrientOutOfRange(let nutrient)):
            String(localized: "meal.error.nutrient \(nutrient.localizedName)", bundle: .module)
        case .invalid(.sugarOutOfRange(let sugar)):
            String(localized: "meal.error.nutrient \(sugar.localizedName)", bundle: .module)
        case .unreadableNumber: String(localized: "meal.error.number", bundle: .module)
        case .storage: String(localized: "meal.error.storage", bundle: .module)
        }
    }
}

/// Shared number formats for nutrition: grams without decimals, bread units with one.
enum NutritionFormat {
    static func grams(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    /// Small amounts such as individual sugars, with one decimal.
    static func tenths(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "g" / "г".
    static var gramsUnit: String { String(localized: "unit.grams", bundle: .module) }

    static func breadUnits(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

/// "2 h 5 min after lunch" / "20 min before dinner". Ukrainian needs the meal name in the
/// genitive ("після обіду"), so each meal and direction has its own string.
enum MealLinkText {
    static func text(slot: MealSlot, minutes: Int) -> String {
        let duration = Duration.seconds(abs(minutes) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        if minutes < 0 {
            switch slot {
            case .breakfast: return String(localized: "meal.link.before.breakfast \(duration)", bundle: .module)
            case .lunch: return String(localized: "meal.link.before.lunch \(duration)", bundle: .module)
            case .dinner: return String(localized: "meal.link.before.dinner \(duration)", bundle: .module)
            case .snack: return String(localized: "meal.link.before.snack \(duration)", bundle: .module)
            }
        }
        switch slot {
        case .breakfast: return String(localized: "meal.link.after.breakfast \(duration)", bundle: .module)
        case .lunch: return String(localized: "meal.link.after.lunch \(duration)", bundle: .module)
        case .dinner: return String(localized: "meal.link.after.dinner \(duration)", bundle: .module)
        case .snack: return String(localized: "meal.link.after.snack \(duration)", bundle: .module)
        }
    }
}

extension Nutrient {
    public var localizedName: String {
        switch self {
        case .protein: String(localized: "nutrient.protein", bundle: .module)
        case .fat: String(localized: "nutrient.fat", bundle: .module)
        case .fiber: String(localized: "nutrient.fiber", bundle: .module)
        case .energy: String(localized: "nutrient.energy", bundle: .module)
        }
    }

    /// "g" or "kcal", localized ("г", "ккал").
    public var unitSymbol: String {
        isEnergy ? String(localized: "unit.kcal", bundle: .module) : String(localized: "unit.grams", bundle: .module)
    }
}

extension DietarySugar {
    public var localizedName: String {
        switch self {
        case .sucrose: String(localized: "sugar.sucrose", bundle: .module)
        case .glucose: String(localized: "sugar.glucose", bundle: .module)
        case .fructose: String(localized: "sugar.fructose", bundle: .module)
        case .lactose: String(localized: "sugar.lactose", bundle: .module)
        case .maltose: String(localized: "sugar.maltose", bundle: .module)
        case .galactose: String(localized: "sugar.galactose", bundle: .module)
        }
    }
}

/// The catalog has Ukrainian and English names; the app's own language picks one.
enum CatalogLanguage {
    static var isUkrainian: Bool {
        Bundle.module.preferredLocalizations.first?.hasPrefix("uk") ?? false
    }
}

extension Food {
    var localizedName: String { CatalogLanguage.isUkrainian ? nameUK : nameEN }
}

extension Food.Portion {
    var localizedName: String { CatalogLanguage.isUkrainian ? nameUK : nameEN }
}

extension DiabetesType {
    public var localizedName: String {
        switch self {
        case .type1: String(localized: "diabetes.type1", bundle: .module)
        case .type2: String(localized: "diabetes.type2", bundle: .module)
        case .prediabetes: String(localized: "diabetes.prediabetes", bundle: .module)
        case .gestational: String(localized: "diabetes.gestational", bundle: .module)
        case .other: String(localized: "diabetes.other", bundle: .module)
        case .notSpecified: String(localized: "diabetes.notSpecified", bundle: .module)
        }
    }
}

extension MedicineKind {
    public var localizedName: String {
        switch self {
        case .tablet: String(localized: "medicine.kind.tablet", bundle: .module)
        case .basalInsulin: String(localized: "medicine.kind.basalInsulin", bundle: .module)
        case .bolusInsulin: String(localized: "medicine.kind.bolusInsulin", bundle: .module)
        case .injectionOther: String(localized: "medicine.kind.injectionOther", bundle: .module)
        case .other: String(localized: "medicine.kind.other", bundle: .module)
        }
    }
}

extension ProfileEditorModel.SaveError {
    public var localizedMessage: String {
        switch self {
        case .height: String(localized: "profile.error.height", bundle: .module)
        case .weight: String(localized: "profile.error.weight", bundle: .module)
        case .medicineName: String(localized: "profile.error.medicineName", bundle: .module)
        case .storage: String(localized: "profile.error.storage", bundle: .module)
        }
    }
}
