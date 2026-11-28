import Foundation
import UserNotifications

/// Schedules the "check your glucose again" reminder offered after a low reading.
public protocol RecheckReminderScheduling: Sendable {
    /// Calls `completion` with true when the reminder is scheduled, false when notifications
    /// are not allowed or scheduling failed. The completion may run on any thread.
    func scheduleRecheck(in interval: TimeInterval, completion: @escaping @Sendable (Bool) -> Void)
}

/// Local notification via UserNotifications. Permission is asked only when the user taps
/// the reminder button, never at launch.
///
/// The notification text never contains a glucose value: it can show on the Lock Screen.
public struct NotificationRecheckReminder: RecheckReminderScheduling {
    public init() {}

    public func scheduleRecheck(in interval: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                completion(false)
                return
            }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "reminder.recheck.title", bundle: .module)
            content.body = String(localized: "reminder.recheck.body", bundle: .module)
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "glucose.recheck.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request) { error in
                completion(error == nil)
            }
        }
    }
}

/// Does nothing. Used in previews and tests.
public struct NoopRecheckReminder: RecheckReminderScheduling {
    public let succeeds: Bool
    public init(succeeds: Bool = true) { self.succeeds = succeeds }
    public func scheduleRecheck(in interval: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) {
        completion(succeeds)
    }
}
