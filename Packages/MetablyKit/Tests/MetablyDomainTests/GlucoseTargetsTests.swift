import Foundation
import Testing
@testable import MetablyDomain

@Suite("Glucose targets")
struct GlucoseTargetsTests {
    let targets = GlucoseTargets.adaDefaults

    func mmol(_ value: Double) -> GlucoseConcentration { GlucoseConcentration(millimolesPerLiter: value) }

    @Test("Before-meal and fasting readings use 4.4–7.2 mmol/L, inclusive")
    func preMeal() {
        #expect(targets.status(of: mmol(4.4), context: .fasting) == .inRange)
        #expect(targets.status(of: mmol(7.2), context: .beforeMeal) == .inRange)
        #expect(targets.status(of: mmol(7.3), context: .beforeMeal) == .above)
        #expect(targets.status(of: mmol(4.3), context: .fasting) == .below)
    }

    @Test("After-meal readings are in target up to 10.0 mmol/L")
    func postMeal() {
        #expect(targets.status(of: mmol(9.8), context: .afterMeal) == .inRange)
        #expect(targets.status(of: mmol(10.0), context: .afterMeal) == .inRange)
        #expect(targets.status(of: mmol(10.1), context: .afterMeal) == .above)
    }

    @Test("mg/dL values compare at mg/dL precision: 80–130 before meals, up to 180 after")
    func milligrams() {
        let mgdl = GlucoseUnit.milligramsPerDeciliter
        func value(_ v: Double) -> GlucoseConcentration { GlucoseConcentration(value: v, unit: mgdl) }
        #expect(targets.status(of: value(130), context: .beforeMeal, comparedIn: mgdl) == .inRange)
        #expect(targets.status(of: value(131), context: .beforeMeal, comparedIn: mgdl) == .above)
        #expect(targets.status(of: value(80), context: .fasting, comparedIn: mgdl) == .inRange)
        #expect(targets.status(of: value(180), context: .afterMeal, comparedIn: mgdl) == .inRange)
        #expect(targets.status(of: value(181), context: .afterMeal, comparedIn: mgdl) == .above)
    }

    @Test("Contexts without a target give no verdict, except below the low threshold")
    func noTargetContexts() {
        #expect(targets.status(of: mmol(8.5), context: .bedtime) == nil)
        #expect(targets.status(of: mmol(12.0), context: .random) == nil)
        #expect(targets.status(of: mmol(3.5), context: .night) == .below)
    }

    @Test("Low threshold is below 3.9 mmol/L (70 mg/dL)")
    func lowThreshold() {
        #expect(GlucoseTargets.isLow(mmol(3.8)))
        #expect(!GlucoseTargets.isLow(mmol(3.9)))
        let mgdl = GlucoseUnit.milligramsPerDeciliter
        #expect(!GlucoseTargets.isLow(GlucoseConcentration(value: 70, unit: mgdl), comparedIn: mgdl))
        #expect(GlucoseTargets.isLow(GlucoseConcentration(value: 69, unit: mgdl), comparedIn: mgdl))
    }

    @Test("Inconsistent targets are invalid")
    func validity() {
        #expect(targets.isValid)
        #expect(!GlucoseTargets(preMealLowerMmolL: 7, preMealUpperMmolL: 6, postMealUpperMmolL: 10).isValid)
        #expect(!GlucoseTargets(preMealLowerMmolL: 4.4, preMealUpperMmolL: 7.2, postMealUpperMmolL: 7.0).isValid)
        #expect(!GlucoseTargets(preMealLowerMmolL: 1, preMealUpperMmolL: 7.2, postMealUpperMmolL: 10).isValid)
    }

    @Test("Meter HI and LO readings report their direction")
    func meterFlags() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let hi = GlucoseReading(enteredValue: 33.3, enteredUnit: .millimolesPerLiter, context: .bedtime,
                                flags: .meterHigh, measuredAt: date, timeZone: .gmt, provenance: .manual, createdAt: date)
        #expect(hi.targetStatus(using: targets) == .above)
        let lo = GlucoseReading(enteredValue: 0.6, enteredUnit: .millimolesPerLiter, context: .fasting,
                                flags: .meterLow, measuredAt: date, timeZone: .gmt, provenance: .manual, createdAt: date)
        #expect(lo.targetStatus(using: targets) == .below)
        #expect(lo.isLow)
    }
}

@Suite("Diary slots")
struct DiarySlotTests {
    func minute(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

    @Test("Slot suggestions follow the default day", arguments: [
        (6, 30, DiarySlot.fasting),
        (8, 30, DiarySlot.fasting),
        (10, 15, DiarySlot.afterBreakfast),
        (12, 30, DiarySlot.beforeLunch),
        (13, 40, DiarySlot.beforeLunch),
        (15, 5, DiarySlot.afterLunch),
        (18, 30, DiarySlot.beforeDinner),
        (21, 0, DiarySlot.afterDinner),
        (22, 15, DiarySlot.bedtime),
        (23, 50, DiarySlot.bedtime),
        (1, 0, DiarySlot.other),
    ])
    func suggestions(hour: Int, minute: Int, expected: DiarySlot) {
        #expect(DiarySlot.suggested(atMinute: self.minute(hour, minute), nightCheckEnabled: false) == expected)
    }

    @Test("The 03:00 window suggests the night check only when it is enabled")
    func night() {
        #expect(DiarySlot.suggested(atMinute: minute(3), nightCheckEnabled: true) == .night)
        #expect(DiarySlot.suggested(atMinute: minute(3), nightCheckEnabled: false) == .other)
        #expect(DiarySlot.suggested(atMinute: minute(0, 30), nightCheckEnabled: true) == .other)
    }

    @Test("Every slot maps to the context it stores, and placing it back is stable")
    func roundTrip() {
        let typicalMinute: [DiarySlot: Int] = [
            .fasting: minute(7), .afterBreakfast: minute(10), .beforeLunch: minute(12, 50),
            .afterLunch: minute(15), .beforeDinner: minute(18, 50), .afterDinner: minute(21),
            .bedtime: minute(22, 30), .night: minute(3), .other: minute(16),
        ]
        for (slot, minute) in typicalMinute {
            #expect(DiarySlot.slot(for: slot.context, atMinute: minute) == slot)
        }
    }

    @Test("A before-meal reading early in the morning is the fasting column")
    func beforeBreakfast() {
        #expect(DiarySlot.slot(for: .beforeMeal, atMinute: minute(7, 45)) == .fasting)
    }

    @Test("Profile has seven slots, eight with the night check")
    func profile() {
        #expect(DiarySlot.profileSlots(includingNight: false).count == 7)
        #expect(DiarySlot.profileSlots(includingNight: true).last == .night)
    }

    @Test("Minute of day uses the given zone")
    func minuteOfDay() {
        let kyiv = TimeZone(identifier: "Europe/Kyiv")!
        let day = LocalDay(year: 2026, month: 11, day: 27)
        let instant = day.instant(hour: 13, minute: 5, in: kyiv)!
        #expect(DailySchedule.minuteOfDay(instant, in: kyiv) == 13 * 60 + 5)
        #expect(DailySchedule.minuteOfDay(instant, in: .gmt) == 11 * 60 + 5)
    }
}

@Suite("Duplicate detection")
struct DuplicateReadingDetectorTests {
    let base = Date(timeIntervalSince1970: 1_800_000_000)

    func reading(_ value: Double, _ offset: TimeInterval, unit: GlucoseUnit = .millimolesPerLiter) -> GlucoseReading {
        GlucoseReading(enteredValue: value, enteredUnit: unit, context: .random,
                       measuredAt: base.addingTimeInterval(offset), timeZone: .gmt, provenance: .manual, createdAt: base)
    }

    @Test("Same value within 5 minutes is a likely duplicate")
    func duplicate() {
        let detector = DuplicateReadingDetector()
        let existing = [reading(6.5, -4 * 60)]
        #expect(detector.likelyDuplicate(of: GlucoseConcentration(millimolesPerLiter: 6.5), at: base, among: existing) != nil)
    }

    @Test("Different value or more than 5 minutes apart is not a duplicate")
    func notDuplicate() {
        let detector = DuplicateReadingDetector()
        #expect(detector.likelyDuplicate(of: GlucoseConcentration(millimolesPerLiter: 6.6), at: base, among: [reading(6.5, 0)]) == nil)
        #expect(detector.likelyDuplicate(of: GlucoseConcentration(millimolesPerLiter: 6.5), at: base, among: [reading(6.5, -6 * 60)]) == nil)
    }

    @Test("Same mg/dL value entered twice is a duplicate")
    func milligrams() {
        let detector = DuplicateReadingDetector()
        let existing = [reading(117, -60, unit: .milligramsPerDeciliter)]
        #expect(detector.likelyDuplicate(of: GlucoseConcentration(value: 117, unit: .milligramsPerDeciliter), at: base, among: existing) != nil)
    }
}
