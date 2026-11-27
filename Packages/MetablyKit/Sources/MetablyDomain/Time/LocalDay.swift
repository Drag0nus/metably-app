import Foundation

/// A diary day (calendar date) in the time zone where an event happened.
///
/// The diary day starts at local midnight. A 03:00 reading belongs to the new day.
/// Stored as "YYYY-MM-DD" so it can be indexed and grouped without time zone math.
public struct LocalDay: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(instant: Date, timeZone: TimeZone) {
        let components = Self.calendar(in: timeZone).dateComponents([.year, .month, .day], from: instant)
        self.init(year: components.year ?? 0, month: components.month ?? 0, day: components.day ?? 0)
    }

    /// Parses "YYYY-MM-DD". Returns nil for malformed or impossible dates.
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let candidate = LocalDay(year: year, month: month, day: day)
        // Round-trip through the calendar to reject dates like 2026-02-30.
        guard let start = candidate.startInstant(in: .gmt),
              LocalDay(instant: start, timeZone: .gmt) == candidate
        else { return nil }
        self = candidate
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { isoString }

    /// Local midnight of this day in the given zone.
    public func startInstant(in timeZone: TimeZone) -> Date? {
        Self.calendar(in: timeZone).date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The instant of a local wall-clock time on this day (DST-aware).
    public func instant(hour: Int, minute: Int, in timeZone: TimeZone) -> Date? {
        Self.calendar(in: timeZone).date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )
    }

    public func adding(days: Int) -> LocalDay {
        let calendar = Self.calendar(in: .gmt)
        guard let start = startInstant(in: .gmt),
              let shifted = calendar.date(byAdding: .day, value: days, to: start)
        else { return self }
        return LocalDay(instant: shifted, timeZone: .gmt)
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = LocalDay(isoString: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid local day")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
