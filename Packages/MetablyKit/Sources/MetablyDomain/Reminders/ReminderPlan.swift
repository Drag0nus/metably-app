import Foundation

/// What a reminder is for. Texts are chosen by the app layer and never contain a measured
/// value, a dose or a medicine name: notifications can show on the Lock Screen.
public enum ReminderKind: Sendable, Hashable, Codable {
    case fastingCheck
    case preMealCheck(MealSlot)
    case meal(MealSlot)
    case snack(index: Int)
    case bedtimeCheck
    case medication(UUID)
    case water
}

/// Which groups of reminders the user wants. Not health data. Raw keys are persisted.
public struct ReminderSettings: Sendable, Hashable, Codable {
    public var glucoseChecks: Bool
    public var meals: Bool
    public var medications: Bool
    public var water: Bool
    /// After an eaten meal is recorded, remind to check glucose this many minutes after it started.
    public var postMealCheck: Bool
    public var postMealMinutes: Int
    public var preMealLeadMinutes: Int
    public var waterIntervalMinutes: Int
    /// Reminders the user switched off one by one, by `PlannedReminder.id`.
    public var disabledIDs: Set<String>

    public static let postMealOptions = [60, 90, 120]
    public static let waterIntervalOptions = [60, 90, 120, 180]

    public static let `default` = ReminderSettings(
        glucoseChecks: true, meals: true, medications: true, water: false,
        postMealCheck: true, postMealMinutes: 120, preMealLeadMinutes: 15,
        waterIntervalMinutes: 120, disabledIDs: []
    )

    public init(
        glucoseChecks: Bool, meals: Bool, medications: Bool, water: Bool,
        postMealCheck: Bool, postMealMinutes: Int, preMealLeadMinutes: Int,
        waterIntervalMinutes: Int, disabledIDs: Set<String>
    ) {
        self.glucoseChecks = glucoseChecks
        self.meals = meals
        self.medications = medications
        self.water = water
        self.postMealCheck = postMealCheck
        self.postMealMinutes = postMealMinutes
        self.preMealLeadMinutes = preMealLeadMinutes
        self.waterIntervalMinutes = waterIntervalMinutes
        self.disabledIDs = disabledIDs
    }
}

/// One daily reminder at a time of day.
public struct PlannedReminder: Sendable, Hashable, Identifiable {
    /// Stable across re-planning, so a reminder switched off stays off when times change.
    public let id: String
    public let kind: ReminderKind
    public let minute: Int
    public var isEnabled: Bool

    public init(id: String, kind: ReminderKind, minute: Int, isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.minute = ((minute % 1440) + 1440) % 1440
        self.isEnabled = isEnabled
    }
}

/// Builds the daily reminder plan from the user's routine and profile.
///
/// The plan only schedules what the user asked for: checks at the usual times, meals,
/// medicines at their prescribed times and, if wanted, water while awake. It never changes or
/// suggests a dose. iOS keeps at most 64 pending notifications per app, so the plan is capped
/// below that, leaving room for one-off reminders such as a post-meal check.
public struct ReminderPlanner: Sendable {
    public static let maximumDaily = 56

    public init() {}

    public func plan(routine: DayRoutine, profile: UserProfile, settings: ReminderSettings) -> [PlannedReminder] {
        var items: [PlannedReminder] = []
        if settings.glucoseChecks {
            items.append(PlannedReminder(id: "check.fasting", kind: .fastingCheck, minute: routine.wakeMinute + 15))
            for meal in routine.mainMeals {
                items.append(PlannedReminder(
                    id: "check.preMeal.\(meal.slot.rawValue)",
                    kind: .preMealCheck(meal.slot),
                    minute: meal.minute - settings.preMealLeadMinutes
                ))
            }
            items.append(PlannedReminder(id: "check.bedtime", kind: .bedtimeCheck, minute: routine.schedule.bedtimeMinute - 15))
        }
        if settings.meals {
            for meal in routine.mainMeals {
                items.append(PlannedReminder(id: "meal.\(meal.slot.rawValue)", kind: .meal(meal.slot), minute: meal.minute))
            }
            for (index, minute) in routine.snackMinutes.enumerated() {
                items.append(PlannedReminder(id: "meal.snack.\(index)", kind: .snack(index: index), minute: minute))
            }
        }
        if settings.medications {
            for medicine in profile.medicines {
                for minute in medicine.minutes {
                    items.append(PlannedReminder(
                        id: "med.\(medicine.id.uuidString).\(minute)",
                        kind: .medication(medicine.id),
                        minute: minute
                    ))
                }
            }
        }
        if settings.water, settings.waterIntervalMinutes >= 30 {
            var minute = routine.wakeMinute + settings.waterIntervalMinutes
            let awakeMinutes = (routine.schedule.bedtimeMinute - routine.wakeMinute + 1440) % 1440
            var elapsed = settings.waterIntervalMinutes
            while elapsed < awakeMinutes {
                items.append(PlannedReminder(id: "water.\(minute % 1440)", kind: .water, minute: minute))
                minute += settings.waterIntervalMinutes
                elapsed += settings.waterIntervalMinutes
            }
        }
        let sorted = items
            .map { item -> PlannedReminder in
                var item = item
                item.isEnabled = !settings.disabledIDs.contains(item.id)
                return item
            }
            .sorted { ($0.minute, $0.id) < ($1.minute, $1.id) }
        // Medicines first when trimming: they matter most, water least.
        guard sorted.filter(\.isEnabled).count > Self.maximumDaily else { return sorted }
        var budget = Self.maximumDaily
        var keep: Set<String> = []
        for priority in [0, 1, 2, 3] {
            for item in sorted where item.isEnabled && Self.priority(item.kind) == priority && budget > 0 {
                keep.insert(item.id)
                budget -= 1
            }
        }
        return sorted.map { item in
            var item = item
            item.isEnabled = item.isEnabled && keep.contains(item.id)
            return item
        }
    }

    static func priority(_ kind: ReminderKind) -> Int {
        switch kind {
        case .medication: 0
        case .fastingCheck, .preMealCheck, .bedtimeCheck: 1
        case .meal, .snack: 2
        case .water: 3
        }
    }
}
