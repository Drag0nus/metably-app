import Foundation

/// The user's usual meal and bed times, as minutes after local midnight.
///
/// Used only to suggest a diary slot for a new reading and to place readings in the
/// 7-point profile. It is never used to judge the user. The defaults are a guess at a typical
/// day; a settings screen for them comes later.
public struct DailySchedule: Sendable, Hashable, Codable {
    public var breakfastMinute: Int
    public var lunchMinute: Int
    public var dinnerMinute: Int
    public var bedtimeMinute: Int

    public static let `default` = DailySchedule(
        breakfastMinute: 8 * 60,
        lunchMinute: 13 * 60,
        dinnerMinute: 19 * 60,
        bedtimeMinute: 22 * 60 + 30
    )

    public init(breakfastMinute: Int, lunchMinute: Int, dinnerMinute: Int, bedtimeMinute: Int) {
        self.breakfastMinute = breakfastMinute
        self.lunchMinute = lunchMinute
        self.dinnerMinute = dinnerMinute
        self.bedtimeMinute = bedtimeMinute
    }

    /// Minutes after local midnight of an instant in a zone (0..<1440).
    public static func minuteOfDay(_ instant: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: instant)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
