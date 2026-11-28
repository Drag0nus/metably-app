import Foundation
import MetablyDomain
import Observation

/// App preferences (display unit, bread unit factor, module switches).
///
/// Preferences are not health records, so `UserDefaults` is acceptable here. Do not put
/// measurements, diagnoses or anything identifying into this store.
@Observable
@MainActor
public final class UserPreferencesStore {
    private enum Keys {
        static let displayGlucoseUnit = "prefs.displayGlucoseUnit"
        static let carbsPerBreadUnit = "prefs.carbsPerBreadUnit"
        static let usesInsulin = "prefs.usesInsulin"
        static let nightCheckEnabled = "prefs.nightCheckEnabled"
        static let glucoseTargets = "prefs.glucoseTargets"
        static let lastActivityLevel = "prefs.lastActivityLevel"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var displayGlucoseUnit: GlucoseUnit {
        didSet { defaults.set(displayGlucoseUnit.rawValue, forKey: Keys.displayGlucoseUnit) }
    }

    /// Grams of carbohydrate per bread unit (XE). Default 12 g.
    public var carbsPerBreadUnit: Double {
        didSet { defaults.set(carbsPerBreadUnit, forKey: Keys.carbsPerBreadUnit) }
    }

    /// Shows the insulin module. Off by default (MVP centres on tablets).
    public var usesInsulin: Bool {
        didSet { defaults.set(usesInsulin, forKey: Keys.usesInsulin) }
    }

    /// Optional 03:00 night check slot in the daily grid. Off by default.
    public var nightCheckEnabled: Bool {
        didSet { defaults.set(nightCheckEnabled, forKey: Keys.nightCheckEnabled) }
    }

    /// The user's glucose targets. Defaults to the ADA values. Invalid targets are never
    /// persisted (the settings screen only offers valid ones).
    public var glucoseTargets: GlucoseTargets {
        didSet {
            guard glucoseTargets.isValid else { return }
            if let data = try? JSONEncoder().encode(glucoseTargets) {
                defaults.set(data, forKey: Keys.glucoseTargets)
            }
        }
    }

    /// The activity level chosen on the last reading, used to preset the next one.
    /// A UI convenience only; the reading itself stores its own level.
    public var lastActivityLevel: ActivityLevel? {
        didSet { defaults.set(lastActivityLevel?.rawValue ?? 0, forKey: Keys.lastActivityLevel) }
    }

    /// Usual meal and bed times. Not editable yet; see `DailySchedule`.
    public var dailySchedule: DailySchedule { .default }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayGlucoseUnit = defaults.string(forKey: Keys.displayGlucoseUnit)
            .flatMap(GlucoseUnit.init(rawValue:)) ?? .millimolesPerLiter
        let storedFactor = defaults.double(forKey: Keys.carbsPerBreadUnit)
        carbsPerBreadUnit = BreadUnitConverter.allowedCarbsPerBreadUnit.contains(storedFactor)
            ? storedFactor
            : BreadUnitConverter.defaultCarbsPerBreadUnit
        usesInsulin = defaults.bool(forKey: Keys.usesInsulin)
        nightCheckEnabled = defaults.bool(forKey: Keys.nightCheckEnabled)
        lastActivityLevel = ActivityLevel(rawValue: defaults.integer(forKey: Keys.lastActivityLevel))
        glucoseTargets = defaults.data(forKey: Keys.glucoseTargets)
            .flatMap { try? JSONDecoder().decode(GlucoseTargets.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil } ?? .adaDefaults
    }

    public var breadUnitConverter: BreadUnitConverter {
        (try? BreadUnitConverter(carbsPerBreadUnit: carbsPerBreadUnit)) ?? .standard
    }
}
