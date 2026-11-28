import Foundation
import UserNotifications

/// A notification ready to schedule: the text was chosen by the app and never contains a
/// measured value, a dose or a medicine name.
public struct ReminderRequest: Sendable, Hashable {
    public var id: String
    public var title: String
    public var body: String

    public init(id: String, title: String, body: String) {
        self.id = id
        self.title = title
        self.body = body
    }
}

/// A reminder repeating every day at a minute of the day.
public struct DailyReminder: Sendable, Hashable {
    public var request: ReminderRequest
    public var minute: Int

    public init(request: ReminderRequest, minute: Int) {
        self.request = request
        self.minute = minute
    }
}

/// Whether the app may show notifications.
public enum ReminderAuthorization: Sendable, Hashable {
    case notDetermined
    case allowed
    case denied
}

/// Local notifications behind a protocol, so models can be tested without UserNotifications.
public protocol ReminderScheduling: Sendable {
    func authorization() async -> ReminderAuthorization
    /// Asks the user once; returns true when notifications are allowed.
    func requestAuthorization() async -> Bool
    /// Replaces every daily reminder with these, repeating at their minute of day.
    func replaceDaily(_ reminders: [DailyReminder]) async
    /// A one-off reminder, replacing any pending one with the same id.
    func scheduleOnce(_ request: ReminderRequest, at date: Date) async
    func cancel(id: String) async
}

/// UserNotifications implementation. Daily reminders share the "daily." id prefix so a new
/// plan removes exactly the old one and nothing else (such as a low-glucose recheck).
public struct NotificationReminderScheduler: ReminderScheduling {
    static let dailyPrefix = "daily."

    public init() {}

    public func authorization() async -> ReminderAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    public func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func replaceDaily(_ reminders: [DailyReminder]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix(Self.dailyPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        for reminder in reminders {
            var components = DateComponents()
            components.hour = reminder.minute / 60
            components.minute = reminder.minute % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.dailyPrefix + reminder.request.id,
                content: Self.content(reminder.request),
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    public func scheduleOnce(_ request: ReminderRequest, at date: Date) async {
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [request.id])
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: request.id, content: Self.content(request), trigger: trigger))
    }

    public func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    private static func content(_ request: ReminderRequest) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        return content
    }
}

/// Records what would be scheduled. Used in previews and tests.
public actor RecordingReminderScheduler: ReminderScheduling {
    public private(set) var daily: [DailyReminder] = []
    public private(set) var once: [String: Date] = [:]
    public private(set) var onceRequests: [String: ReminderRequest] = [:]
    public private(set) var authorizationRequests = 0
    private var status: ReminderAuthorization

    public init(status: ReminderAuthorization = .allowed) {
        self.status = status
    }

    public func authorization() async -> ReminderAuthorization { status }

    public func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        if status == .notDetermined { status = .allowed }
        return status == .allowed
    }

    public func replaceDaily(_ reminders: [DailyReminder]) async {
        daily = reminders
    }

    public func scheduleOnce(_ request: ReminderRequest, at date: Date) async {
        once[request.id] = date
        onceRequests[request.id] = request
    }

    public func cancel(id: String) async {
        once[id] = nil
        onceRequests[id] = nil
    }
}
