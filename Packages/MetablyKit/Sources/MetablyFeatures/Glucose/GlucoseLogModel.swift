import Foundation
import MetablyDomain
import MetablySyntheticData
import Observation

/// The Journal: readings grouped by diary day, newest first, as a list or as the
/// paper-diary table (one row per day, one column per slot).
@Observable
@MainActor
public final class GlucoseLogModel {
    public struct DaySection: Identifiable, Hashable, Sendable {
        public let day: LocalDay
        public let readings: [GlucoseReading]
        public var id: LocalDay { day }
    }

    /// One row of the diary table.
    public struct DiaryRow: Identifiable, Hashable, Sendable {
        public let day: LocalDay
        /// Readings per slot, newest first.
        public let cells: [DiarySlot: [GlucoseReading]]
        public var id: LocalDay { day }
    }

    public enum Layout: String, Hashable, CaseIterable, Sendable {
        case list
        case table
    }

    public var layout: Layout = .list
    public private(set) var sections: [DaySection] = []
    public private(set) var loadFailed = false

    @ObservationIgnored private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Columns of the diary table: the 7-point profile, the night check when enabled, and other.
    public var tableSlots: [DiarySlot] {
        DiarySlot.profileSlots(includingNight: dependencies.preferences.nightCheckEnabled) + [.other]
    }

    public var diaryRows: [DiaryRow] {
        Self.rows(from: sections, schedule: dependencies.preferences.dailySchedule)
    }

    public func reload() {
        do {
            sections = Self.group(try dependencies.glucoseRepository.allReadings())
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    public func delete(id: UUID) {
        do {
            try dependencies.glucoseRepository.softDelete(id: id)
        } catch {
            loadFailed = true
        }
        reload()
    }

    public func makeEntryModel(editing: GlucoseReading? = nil) -> GlucoseEntryModel {
        dependencies.makeGlucoseEntryModel(editing: editing)
    }

    #if DEBUG
    /// Development helper: inserts synthetic readings and meals (never real data). Debug builds only.
    public func loadSyntheticData(days: Int = 14) {
        let timeZone = TimeZone.current
        let now = dependencies.dateProvider.now()
        let today = LocalDay(instant: now, timeZone: timeZone)
        let seed = UInt64(now.timeIntervalSince1970)
        let readings = SyntheticGlucoseGenerator(seed: seed)
            .makeReadings(days: days, endingOn: today, timeZone: timeZone)
            .filter { $0.measuredAt <= now }
        for reading in readings {
            try? dependencies.glucoseRepository.insert(reading)
        }
        // A different seed so meal ids never repeat reading ids (both live in the event table).
        let meals = SyntheticMealGenerator(seed: seed ^ 0x6D65_616C)
            .makeMeals(days: days, endingOn: today, timeZone: timeZone, now: now)
        for meal in meals {
            try? dependencies.mealRepository.insert(meal)
        }
        reload()
    }
    #endif

    static func rows(from sections: [DaySection], schedule: DailySchedule) -> [DiaryRow] {
        sections.map { section in
            DiaryRow(
                day: section.day,
                cells: Dictionary(grouping: section.readings) { $0.diarySlot(schedule: schedule) }
            )
        }
    }

    static func group(_ readings: [GlucoseReading]) -> [DaySection] {
        Dictionary(grouping: readings, by: \.localDay)
            .map { DaySection(day: $0.key, readings: $0.value.sorted { $0.measuredAt > $1.measuredAt }) }
            .sorted { $0.day > $1.day }
    }
}
