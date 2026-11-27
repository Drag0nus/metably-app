import Foundation
import Testing
@testable import MetablyDomain

@Suite("Diary day (LocalDay)")
struct LocalDayTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let newYork = TimeZone(identifier: "America/New_York")!

    @Test("Day starts at local midnight, not UTC midnight")
    func midnightBoundary() throws {
        // 2026-03-10 22:30 UTC is 2026-03-11 00:30 in Kyiv (UTC+2).
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-03-10T22:30:00Z"))
        #expect(LocalDay(instant: instant, timeZone: kyiv) == LocalDay(year: 2026, month: 3, day: 11))
        #expect(LocalDay(instant: instant, timeZone: .gmt) == LocalDay(year: 2026, month: 3, day: 10))
    }

    @Test("A 03:00 night reading belongs to the new day")
    func nightReading() throws {
        let day = LocalDay(year: 2026, month: 6, day: 2)
        let instant = try #require(day.instant(hour: 3, minute: 0, in: kyiv))
        #expect(LocalDay(instant: instant, timeZone: kyiv) == day)
    }

    @Test("ISO string round trip and validation")
    func isoString() {
        #expect(LocalDay(year: 2026, month: 1, day: 5).isoString == "2026-01-05")
        #expect(LocalDay(isoString: "2026-01-05") == LocalDay(year: 2026, month: 1, day: 5))
        #expect(LocalDay(isoString: "2026-02-30") == nil)
        #expect(LocalDay(isoString: "2026-1-5") == nil)
        #expect(LocalDay(isoString: "garbage") == nil)
    }

    @Test("Adding days crosses month and year ends")
    func addingDays() {
        #expect(LocalDay(year: 2026, month: 12, day: 31).adding(days: 1) == LocalDay(year: 2027, month: 1, day: 1))
        #expect(LocalDay(year: 2026, month: 3, day: 1).adding(days: -1) == LocalDay(year: 2026, month: 2, day: 28))
    }

    @Test("Wall-clock time is DST aware")
    func dst() throws {
        // Kyiv switches to summer time on 2026-03-29; 07:00 local is 04:00 UTC afterwards.
        let day = LocalDay(year: 2026, month: 3, day: 29)
        let instant = try #require(day.instant(hour: 7, minute: 0, in: kyiv))
        #expect(instant == ISO8601DateFormatter().date(from: "2026-03-29T04:00:00Z"))
    }

    @Test("Ordering and Codable as a plain string")
    func codable() throws {
        #expect(LocalDay(year: 2026, month: 1, day: 2) < LocalDay(year: 2026, month: 1, day: 10))
        let data = try JSONEncoder().encode(LocalDay(year: 2026, month: 7, day: 4))
        #expect(String(decoding: data, as: UTF8.self) == "\"2026-07-04\"")
        #expect(try JSONDecoder().decode(LocalDay.self, from: data) == LocalDay(year: 2026, month: 7, day: 4))
    }

    @Test("Reading keeps the zone it was taken in")
    func readingKeepsZone() throws {
        let instant = try #require(LocalDay(year: 2026, month: 5, day: 1).instant(hour: 7, minute: 30, in: kyiv))
        let reading = GlucoseReading(
            enteredValue: 6.1, enteredUnit: .millimolesPerLiter, context: .fasting,
            measuredAt: instant, timeZone: kyiv, provenance: .manual, createdAt: instant
        )
        #expect(reading.timeZoneID == "Europe/Kyiv")
        #expect(reading.localDay == LocalDay(year: 2026, month: 5, day: 1))
        // Viewed from New York it is still the Kyiv diary day.
        #expect(LocalDay(instant: instant, timeZone: newYork) == LocalDay(year: 2026, month: 5, day: 1))
    }
}
