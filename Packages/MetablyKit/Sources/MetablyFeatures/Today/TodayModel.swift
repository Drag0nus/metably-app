import Foundation
import MetablyDomain
import Observation

/// State of the "Today" screen: latest reading, the day's 7-point strip and today's readings.
@Observable
@MainActor
public final class TodayModel {
    /// One cell of the 7-point strip.
    public struct SlotCell: Identifiable, Hashable, Sendable {
        public let slot: DiarySlot
        /// Latest reading of today in this slot, if any.
        public let reading: GlucoseReading?
        public var id: DiarySlot { slot }
    }

    public private(set) var latest: GlucoseReading?
    public private(set) var todayReadings: [GlucoseReading] = []
    public private(set) var slotCells: [SlotCell] = []
    public private(set) var today: LocalDay
    public private(set) var loadFailed = false
    public private(set) var mealLinkTexts: [UUID: String] = [:]
    /// Today's meals, for the carbohydrates card. Planned meals never count as eaten.
    public private(set) var eatenCarbohydrateGrams: Double = 0
    public private(set) var plannedCarbohydrateGrams: Double = 0
    public private(set) var hasMealsToday = false

    @ObservationIgnored private let dependencies: AppDependencies
    @ObservationIgnored private let timeZone: TimeZone

    public init(dependencies: AppDependencies, timeZone: TimeZone = .current) {
        self.dependencies = dependencies
        self.timeZone = timeZone
        self.today = LocalDay(instant: dependencies.dateProvider.now(), timeZone: timeZone)
    }

    public var targets: GlucoseTargets { dependencies.preferences.glucoseTargets }
    public var displayUnit: GlucoseUnit { dependencies.preferences.displayGlucoseUnit }
    public var carbohydrateGoalGrams: Double? { dependencies.preferences.dailyCarbohydrateGoalGrams }
    public var breadUnits: BreadUnitConverter { dependencies.preferences.breadUnitConverter }
    /// The carbs card shows once there is something to compare: a meal today or a goal.
    public var showsCarbohydrateCard: Bool { hasMealsToday || carbohydrateGoalGrams != nil }

    /// Number of 7-point slots measured today (the night check counts only when enabled).
    public var measuredSlotCount: Int { slotCells.filter { $0.reading != nil }.count }

    public func reload() {
        let now = dependencies.dateProvider.now()
        today = LocalDay(instant: now, timeZone: timeZone)
        do {
            // Newest first. Fine for the MVP volume of fingerstick readings; a dedicated
            // "latest" query can replace it once imports bring larger histories.
            let all = try dependencies.glucoseRepository.allReadings()
            latest = all.first { $0.measuredAt <= now }
            todayReadings = all.filter { $0.localDay == today }
            slotCells = Self.cells(
                for: todayReadings,
                schedule: dependencies.preferences.dailySchedule,
                includingNight: dependencies.preferences.nightCheckEnabled
            )
            mealLinkTexts = dependencies.mealLinkTexts(for: todayReadings)
            if let start = today.startInstant(in: timeZone), let end = today.adding(days: 1).startInstant(in: timeZone) {
                let meals = try dependencies.mealRepository.meals(from: start, to: end)
                eatenCarbohydrateGrams = meals.filter { $0.status == .eaten }.reduce(0) { $0 + $1.totalCarbohydrateGrams }
                plannedCarbohydrateGrams = meals.filter { $0.status == .planned }.reduce(0) { $0 + $1.totalCarbohydrateGrams }
                hasMealsToday = !meals.isEmpty
            }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    public func makeEntryModel(editing: GlucoseReading? = nil) -> GlucoseEntryModel {
        dependencies.makeGlucoseEntryModel(editing: editing)
    }

    /// Places readings (newest first) into the profile slots; the newest reading wins a slot.
    static func cells(
        for readings: [GlucoseReading],
        schedule: DailySchedule,
        includingNight: Bool
    ) -> [SlotCell] {
        var bySlot: [DiarySlot: GlucoseReading] = [:]
        for reading in readings.sorted(by: { $0.measuredAt > $1.measuredAt }) {
            let slot = reading.diarySlot(schedule: schedule)
            if bySlot[slot] == nil { bySlot[slot] = reading }
        }
        return DiarySlot.profileSlots(includingNight: includingNight).map {
            SlotCell(slot: $0, reading: bySlot[$0])
        }
    }
}
