import Foundation

/// Type of diabetes as the user states it. Raw values are persisted; never rename them.
public enum DiabetesType: String, Sendable, Hashable, Codable, CaseIterable {
    case type1
    case type2
    case prediabetes
    case gestational
    case other
    case notSpecified
}

/// How a medicine is taken. Raw values are persisted; never rename them.
public enum MedicineKind: String, Sendable, Hashable, Codable, CaseIterable {
    case tablet
    case basalInsulin
    case bolusInsulin
    case injectionOther
    case other

    public var isInsulin: Bool { self == .basalInsulin || self == .bolusInsulin }
}

/// A medicine as prescribed to the user. The dose is the user's own text, copied from the
/// prescription ("500 mg", "10 units"): the app records it and never computes or suggests one.
public struct ProfileMedicine: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var kind: MedicineKind
    public var doseText: String
    /// Times of day in minutes after midnight, sorted and unique.
    public var minutes: [Int]

    public init(id: UUID = UUID(), name: String, kind: MedicineKind, doseText: String = "", minutes: [Int] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.doseText = doseText
        self.minutes = Array(Set(minutes.map { min(max($0, 0), 1439) })).sorted()
    }
}

/// Facts the user tells the app about themselves. Health data: stored only on the device,
/// in a protected file, never in `UserDefaults` and never in logs.
public struct UserProfile: Sendable, Hashable, Codable {
    public var diabetesType: DiabetesType
    public var heightCentimeters: Double?
    public var weightKilograms: Double?
    public var medicines: [ProfileMedicine]

    public static let heightRange: ClosedRange<Double> = 50...250
    public static let weightRange: ClosedRange<Double> = 20...350

    public init(
        diabetesType: DiabetesType = .notSpecified,
        heightCentimeters: Double? = nil,
        weightKilograms: Double? = nil,
        medicines: [ProfileMedicine] = []
    ) {
        self.diabetesType = diabetesType
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.medicines = medicines
    }

    /// Body mass index (kg/m²) with one decimal, or nil when height or weight is missing or
    /// implausible. A plain number: the app does not label or judge it.
    public var bodyMassIndex: Double? {
        guard let height = heightCentimeters, let weight = weightKilograms,
              Self.heightRange.contains(height), Self.weightRange.contains(weight)
        else { return nil }
        let meters = height / 100
        return (weight / (meters * meters) * 10).rounded() / 10
    }

    public var usesInsulin: Bool { medicines.contains { $0.kind.isInsulin } }
}

/// The user's usual day: when they get up, eat and go to bed. Not health data.
public struct DayRoutine: Sendable, Hashable, Codable {
    public var wakeMinute: Int
    /// Main meal times and bedtime, also used to suggest diary slots.
    public var schedule: DailySchedule
    /// Main meals the user usually skips; they get no reminders.
    public var skippedMeals: Set<MealSlot>
    /// Snack times, sorted.
    public var snackMinutes: [Int]

    public static let `default` = DayRoutine(wakeMinute: 7 * 60, schedule: .default, skippedMeals: [], snackMinutes: [])
    public static let maximumSnacks = 3

    public init(wakeMinute: Int, schedule: DailySchedule, skippedMeals: Set<MealSlot>, snackMinutes: [Int]) {
        self.wakeMinute = wakeMinute
        self.schedule = schedule
        self.skippedMeals = skippedMeals.subtracting([.snack])
        self.snackMinutes = Array(snackMinutes.sorted().prefix(Self.maximumSnacks))
    }

    /// Main meals the user eats, in day order, with their minute of day.
    public var mainMeals: [(slot: MealSlot, minute: Int)] {
        [(MealSlot.breakfast, schedule.breakfastMinute), (.lunch, schedule.lunchMinute), (.dinner, schedule.dinnerMinute)]
            .filter { !skippedMeals.contains($0.0) }
            .map { (slot: $0.0, minute: $0.1) }
    }

    /// Meals per day, main meals plus snacks.
    public var mealsPerDay: Int { mainMeals.count + snackMinutes.count }

    /// True when a minute of day lies between waking and bedtime (handles a bedtime after midnight).
    public func isAwake(atMinute minute: Int) -> Bool {
        let bed = schedule.bedtimeMinute
        if wakeMinute <= bed { return minute >= wakeMinute && minute <= bed }
        return minute >= wakeMinute || minute <= bed
    }
}
