import Foundation

/// A column of the paper self-control diary: the 7-point profile plus the optional
/// 03:00 night check and "other" for readings outside the routine.
///
/// A slot is derived, not stored: the reading stores its `GlucoseMeasurementContext` and time,
/// and the slot follows from those and the user's `DailySchedule`. So no schema change is needed
/// when the schedule changes.
public enum DiarySlot: String, Sendable, Hashable, CaseIterable, Identifiable {
    case fasting
    case afterBreakfast
    case beforeLunch
    case afterLunch
    case beforeDinner
    case afterDinner
    case bedtime
    case night
    case other

    public var id: String { rawValue }

    /// The 7-point profile in diary order, with the night check appended when enabled.
    public static func profileSlots(includingNight: Bool) -> [DiarySlot] {
        let seven: [DiarySlot] = [.fasting, .afterBreakfast, .beforeLunch, .afterLunch, .beforeDinner, .afterDinner, .bedtime]
        return includingNight ? seven + [.night] : seven
    }

    /// The context stored for a reading taken in this slot.
    public var context: GlucoseMeasurementContext {
        switch self {
        case .fasting: .fasting
        case .afterBreakfast, .afterLunch, .afterDinner: .afterMeal
        case .beforeLunch, .beforeDinner: .beforeMeal
        case .bedtime: .bedtime
        case .night: .night
        case .other: .random
        }
    }

    /// Suggests a slot from the time of day. The user always sees and can change it.
    ///
    /// Windows: 45 min either side of lunch and dinner count as "before"; from 45 min after a
    /// meal until 45 min before the next one count as "after"; from 30 min before bedtime is
    /// bedtime. 02:00–05:00 is the night check when enabled.
    public static func suggested(
        atMinute minute: Int,
        schedule: DailySchedule = .default,
        nightCheckEnabled: Bool
    ) -> DiarySlot {
        let window = 45
        if minute < 5 * 60 {
            return nightCheckEnabled && minute >= 2 * 60 ? .night : .other
        }
        if minute < schedule.breakfastMinute + window { return .fasting }
        if minute < schedule.lunchMinute - window { return .afterBreakfast }
        if minute < schedule.lunchMinute + window { return .beforeLunch }
        if minute < schedule.dinnerMinute - window { return .afterLunch }
        if minute < schedule.dinnerMinute + window { return .beforeDinner }
        if minute < schedule.bedtimeMinute - 30 { return .afterDinner }
        return .bedtime
    }

    /// Places a stored reading back into a slot from its context and local time.
    public static func slot(
        for context: GlucoseMeasurementContext,
        atMinute minute: Int,
        schedule: DailySchedule = .default
    ) -> DiarySlot {
        switch context {
        case .fasting: return .fasting
        case .bedtime: return .bedtime
        case .night: return .night
        case .random: return .other
        case .beforeMeal:
            // "Before breakfast" is the fasting column of the diary.
            if minute < (schedule.breakfastMinute + schedule.lunchMinute) / 2 { return .fasting }
            if minute < (schedule.lunchMinute + schedule.dinnerMinute) / 2 { return .beforeLunch }
            return .beforeDinner
        case .afterMeal:
            // Belongs to the latest meal that started (30 min tolerance for an early meal).
            if minute >= schedule.dinnerMinute - 30 { return .afterDinner }
            if minute >= schedule.lunchMinute - 30 { return .afterLunch }
            return .afterBreakfast
        }
    }
}

extension GlucoseReading {
    public func diarySlot(schedule: DailySchedule = .default) -> DiarySlot {
        DiarySlot.slot(
            for: context,
            atMinute: DailySchedule.minuteOfDay(measuredAt, in: timeZone),
            schedule: schedule
        )
    }
}

/// Finds a likely accidental double entry: the same value within 5 minutes.
/// It only warns; nothing is merged or dropped without the user's say.
public struct DuplicateReadingDetector: Sendable {
    public static let window: TimeInterval = 5 * 60

    public init() {}

    public func likelyDuplicate(
        of concentration: GlucoseConcentration,
        at instant: Date,
        among readings: [GlucoseReading]
    ) -> GlucoseReading? {
        readings.first { reading in
            !reading.isDeleted
                && abs(reading.measuredAt.timeIntervalSince(instant)) <= Self.window
                && abs(reading.concentration.millimolesPerLiter - concentration.millimolesPerLiter) < 0.05
        }
    }
}
