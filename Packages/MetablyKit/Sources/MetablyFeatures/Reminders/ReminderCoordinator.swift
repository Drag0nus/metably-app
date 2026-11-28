import Foundation
import MetablyDomain
import Observation

/// Turns the user's routine, profile and reminder choices into scheduled notifications.
///
/// Notifications are asked for only when the user switches reminders on, never at launch.
/// Their texts never contain a value, a dose or a medicine name (Lock Screen); the in-app plan
/// list may name the medicine because only the user sees it.
@Observable
@MainActor
public final class ReminderCoordinator {
    public private(set) var authorization: ReminderAuthorization = .notDetermined

    @ObservationIgnored private let preferences: UserPreferencesStore
    @ObservationIgnored private let profileStore: ProfileStore
    @ObservationIgnored private let scheduler: any ReminderScheduling
    @ObservationIgnored private let dateProvider: any DateProvider
    @ObservationIgnored private let planner = ReminderPlanner()

    public init(
        preferences: UserPreferencesStore,
        profileStore: ProfileStore,
        scheduler: any ReminderScheduling,
        dateProvider: any DateProvider = SystemDateProvider()
    ) {
        self.preferences = preferences
        self.profileStore = profileStore
        self.scheduler = scheduler
        self.dateProvider = dateProvider
    }

    /// Today's plan, including reminders the user switched off (shown as off).
    public var plan: [PlannedReminder] {
        planner.plan(
            routine: preferences.dayRoutine,
            profile: profileStore.profile ?? UserProfile(),
            settings: preferences.reminderSettings
        )
    }

    public func setEnabled(_ enabled: Bool, id: String) {
        if enabled {
            preferences.reminderSettings.disabledIDs.remove(id)
        } else {
            preferences.reminderSettings.disabledIDs.insert(id)
        }
    }

    public func refreshAuthorization() async {
        authorization = await scheduler.authorization()
    }

    /// Asks for permission if needed, then schedules the plan.
    @discardableResult
    public func enableAndApply() async -> Bool {
        let allowed = await scheduler.requestAuthorization()
        authorization = allowed ? .allowed : .denied
        if allowed { await apply() }
        return allowed
    }

    /// Re-schedules the plan when notifications are already allowed (for example after the
    /// routine or a medicine time changed). Never asks for permission.
    public func applyIfAllowed() async {
        await refreshAuthorization()
        guard authorization == .allowed else { return }
        await apply()
    }

    func apply() async {
        let reminders = plan.filter(\.isEnabled).map { item in
            DailyReminder(request: ReminderRequest(id: item.id, title: title(for: item.kind), body: body(for: item.kind)), minute: item.minute)
        }
        await scheduler.replaceDaily(reminders)
    }

    // MARK: - After a meal

    static func postMealID(_ mealID: UUID) -> String { "postMeal.\(mealID.uuidString)" }

    /// After an eaten meal is saved: remind to check glucose N minutes after it started, if
    /// that is still ahead. A planned or deleted meal cancels its reminder.
    public func mealSaved(_ meal: Meal) async {
        let id = Self.postMealID(meal.id)
        let settings = preferences.reminderSettings
        let fireDate = meal.startedAt.addingTimeInterval(TimeInterval(settings.postMealMinutes * 60))
        guard settings.postMealCheck, meal.status == .eaten, !meal.isDeleted,
              fireDate > dateProvider.now()
        else {
            await scheduler.cancel(id: id)
            return
        }
        await refreshAuthorization()
        guard authorization == .allowed else { return }
        let request = ReminderRequest(
            id: id,
            title: String(localized: "reminder.postMeal.title", bundle: .module),
            body: String(localized: "reminder.postMeal.body \(Self.duration(minutes: settings.postMealMinutes))", bundle: .module)
        )
        await scheduler.scheduleOnce(request, at: fireDate)
    }

    public func mealDeleted(id: UUID) async {
        await scheduler.cancel(id: Self.postMealID(id))
    }

    // MARK: - Texts

    /// What the in-app list shows for a reminder (may name a medicine).
    public func label(for kind: ReminderKind) -> String {
        switch kind {
        case let .medication(id):
            if let medicine = profileStore.profile?.medicines.first(where: { $0.id == id }) {
                let name = medicine.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let dose = medicine.doseText.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty { return title(for: kind) }
                return dose.isEmpty ? name : "\(name), \(dose)"
            }
            return title(for: kind)
        default:
            return title(for: kind)
        }
    }

    func title(for kind: ReminderKind) -> String {
        switch kind {
        case .fastingCheck: String(localized: "reminder.fasting.title", bundle: .module)
        case .preMealCheck(.breakfast): String(localized: "reminder.preMeal.breakfast.title", bundle: .module)
        case .preMealCheck(.lunch): String(localized: "reminder.preMeal.lunch.title", bundle: .module)
        case .preMealCheck(.dinner): String(localized: "reminder.preMeal.dinner.title", bundle: .module)
        case .preMealCheck(.snack): String(localized: "reminder.preMeal.snack.title", bundle: .module)
        case let .meal(slot): slot.localizedName
        case .snack: MealSlot.snack.localizedName
        case .bedtimeCheck: String(localized: "reminder.bedtime.title", bundle: .module)
        case .medication: String(localized: "reminder.medication.title", bundle: .module)
        case .water: String(localized: "reminder.water.title", bundle: .module)
        }
    }

    func body(for kind: ReminderKind) -> String {
        switch kind {
        case .fastingCheck, .preMealCheck, .bedtimeCheck: String(localized: "reminder.check.body", bundle: .module)
        case .meal, .snack: String(localized: "reminder.meal.body", bundle: .module)
        case .medication: String(localized: "reminder.medication.body", bundle: .module)
        case .water: String(localized: "reminder.water.body", bundle: .module)
        }
    }

    static func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }
}

/// "07:15" for a minute of the day, in the user's 12/24-hour style.
enum MinuteOfDayFormat {
    static func text(_ minute: Int) -> String {
        date(for: minute).formatted(date: .omitted, time: .shortened)
    }

    /// Today at that time in the current calendar, for `DatePicker`.
    static func date(for minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
