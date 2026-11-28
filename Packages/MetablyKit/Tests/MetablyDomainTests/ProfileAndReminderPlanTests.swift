import Foundation
import Testing
@testable import MetablyDomain

@Suite("Profile")
struct UserProfileTests {
    @Test("BMI is weight over height squared, one decimal")
    func bodyMassIndex() {
        #expect(UserProfile(heightCentimeters: 180, weightKilograms: 81).bodyMassIndex == 25)
        #expect(UserProfile(heightCentimeters: 165, weightKilograms: 70).bodyMassIndex == 25.7)
    }

    @Test("BMI is absent when height or weight is missing or implausible")
    func bodyMassIndexMissing() {
        #expect(UserProfile(heightCentimeters: 180).bodyMassIndex == nil)
        #expect(UserProfile(weightKilograms: 80).bodyMassIndex == nil)
        #expect(UserProfile(heightCentimeters: 18, weightKilograms: 80).bodyMassIndex == nil)
    }

    @Test("Medicine times are clamped, sorted and unique")
    func medicineTimes() {
        let medicine = ProfileMedicine(name: "Synthetic", kind: .tablet, minutes: [1200, 480, 480, 2000])
        #expect(medicine.minutes == [480, 1200, 1439])
    }

    @Test("Insulin in the profile is recognised")
    func usesInsulin() {
        #expect(!UserProfile(medicines: [ProfileMedicine(name: "A", kind: .tablet)]).usesInsulin)
        #expect(UserProfile(medicines: [ProfileMedicine(name: "B", kind: .basalInsulin)]).usesInsulin)
    }

    @Test("The routine counts meals and knows waking hours, also past midnight")
    func routine() {
        var routine = DayRoutine(wakeMinute: 420, schedule: .default, skippedMeals: [.lunch, .snack], snackMinutes: [960, 600, 700, 800])
        #expect(routine.mainMeals.map(\.slot) == [.breakfast, .dinner])
        #expect(routine.snackMinutes == [600, 700, 800])
        #expect(routine.mealsPerDay == 5)
        #expect(routine.isAwake(atMinute: 720))
        #expect(!routine.isAwake(atMinute: 300))
        routine.schedule.bedtimeMinute = 60
        #expect(routine.isAwake(atMinute: 30))
        #expect(!routine.isAwake(atMinute: 200))
    }
}

@Suite("Reminder plan")
struct ReminderPlannerTests {
    let planner = ReminderPlanner()
    let routine = DayRoutine.default

    @Test("Default plan: fasting, pre-meal and bedtime checks plus meals, in time order")
    func defaultPlan() {
        let plan = planner.plan(routine: routine, profile: UserProfile(), settings: .default)
        #expect(plan.map(\.id) == [
            "check.fasting", "check.preMeal.breakfast", "meal.breakfast",
            "check.preMeal.lunch", "meal.lunch",
            "check.preMeal.dinner", "meal.dinner", "check.bedtime",
        ])
        #expect(plan.first?.minute == 7 * 60 + 15)
        #expect(plan.last?.minute == 22 * 60 + 15)
        let allEnabled = plan.allSatisfy { $0.isEnabled }
        #expect(allEnabled)
    }

    @Test("Medicines are reminded at each prescribed time")
    func medicines() {
        let medicine = ProfileMedicine(name: "Synthetic", kind: .tablet, doseText: "1", minutes: [480, 1200])
        var settings = ReminderSettings.default
        settings.glucoseChecks = false
        settings.meals = false
        let plan = planner.plan(routine: routine, profile: UserProfile(medicines: [medicine]), settings: settings)
        #expect(plan.map(\.minute) == [480, 1200])
        #expect(plan.allSatisfy { $0.kind == .medication(medicine.id) })
    }

    @Test("Skipped meals and switched-off groups get no reminders; snacks do")
    func groupsAndSkips() {
        let routine = DayRoutine(wakeMinute: 420, schedule: .default, skippedMeals: [.breakfast], snackMinutes: [960])
        var settings = ReminderSettings.default
        settings.glucoseChecks = false
        let plan = planner.plan(routine: routine, profile: UserProfile(), settings: settings)
        #expect(plan.map(\.id) == ["meal.lunch", "meal.snack.0", "meal.dinner"])
    }

    @Test("A reminder switched off stays in the plan as off")
    func disabled() {
        var settings = ReminderSettings.default
        settings.disabledIDs = ["check.bedtime"]
        let plan = planner.plan(routine: routine, profile: UserProfile(), settings: settings)
        #expect(plan.first { $0.id == "check.bedtime" }?.isEnabled == false)
        #expect(plan.filter(\.isEnabled).count == plan.count - 1)
    }

    @Test("Water reminders fall between waking and bedtime only")
    func water() {
        var settings = ReminderSettings.default
        settings.glucoseChecks = false
        settings.meals = false
        settings.water = true
        settings.waterIntervalMinutes = 120
        let plan = planner.plan(routine: routine, profile: UserProfile(), settings: settings)
        #expect(plan.map(\.minute) == [540, 660, 780, 900, 1020, 1140, 1260])
        #expect(plan.allSatisfy { routine.isAwake(atMinute: $0.minute) })
    }

    @Test("Over the iOS limit, medicines are kept first and water is dropped first")
    func cap() {
        let times = Array(stride(from: 0, to: 1440, by: 30))
        let medicines = (0..<2).map { _ in ProfileMedicine(name: "Synthetic", kind: .tablet, minutes: times) }
        var settings = ReminderSettings.default
        settings.water = true
        settings.waterIntervalMinutes = 60
        let plan = planner.plan(routine: routine, profile: UserProfile(medicines: medicines), settings: settings)
        let enabled = plan.filter(\.isEnabled)
        #expect(enabled.count == ReminderPlanner.maximumDaily)
        #expect(enabled.allSatisfy { if case .medication = $0.kind { true } else { false } })
    }
}
