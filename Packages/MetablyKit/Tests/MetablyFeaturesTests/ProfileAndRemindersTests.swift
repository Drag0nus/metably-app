import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@MainActor
@Suite("Profile and reminders")
struct ProfileAndRemindersTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "profile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("The profile is kept in its file and read back")
    func profileRoundTrip() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = makeDefaults()
        let profile = UserProfile(
            diabetesType: .type2,
            heightCentimeters: 178,
            weightKilograms: 84.5,
            medicines: [ProfileMedicine(name: "Synthetic tablet", kind: .tablet, doseText: "1 tab", minutes: [480])]
        )
        let store = ProfileStore(directory: directory, defaults: defaults)
        #expect(store.profile == nil)
        #expect(!store.hasCompletedOnboarding)
        store.save(profile)
        store.completeOnboarding()
        #expect(!store.saveFailed)

        let reopened = ProfileStore(directory: directory, defaults: defaults)
        #expect(reopened.profile == profile)
        #expect(reopened.hasCompletedOnboarding)
        // The profile is not in UserDefaults.
        #expect(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.contains("profile.json") })
    }

    @Test("The editor validates height, weight and medicine names")
    func editorValidation() {
        let preferences = UserPreferencesStore(defaults: makeDefaults())
        let editor = ProfileEditorModel(profileStore: ProfileStore(directory: nil, defaults: makeDefaults()), preferences: preferences)
        #expect(editor.canSave)
        editor.heightText = "17"
        #expect(editor.validationError == .height)
        editor.heightText = "175,5"
        editor.weightText = "abc"
        #expect(editor.validationError == .weight)
        editor.weightText = "80"
        #expect(editor.bodyMassIndex == 26)
        editor.addMedicine()
        #expect(editor.validationError == .medicineName)
        editor.medicines[0].name = "  Synthetic  "
        #expect(editor.canSave)
    }

    @Test("Saving keeps the profile and routine, and insulin shows the insulin module")
    func editorSave() {
        let preferences = UserPreferencesStore(defaults: makeDefaults())
        preferences.usesInsulin = false
        let store = ProfileStore(directory: nil, defaults: makeDefaults())
        let editor = ProfileEditorModel(profileStore: store, preferences: preferences)
        editor.diabetesType = .type1
        editor.addMedicine()
        editor.medicines[0].name = " Synthetic basal "
        editor.medicines[0].kind = .basalInsulin
        editor.setMainMeal(.lunch, eaten: false)
        editor.addSnack()
        #expect(editor.save())
        #expect(store.profile?.diabetesType == .type1)
        #expect(store.profile?.medicines.first?.name == "Synthetic basal")
        #expect(preferences.usesInsulin)
        #expect(preferences.dayRoutine.skippedMeals == [.lunch])
        #expect(preferences.dayRoutine.snackMinutes.count == 1)
    }

    @Test("Routine and reminder choices persist in preferences")
    func preferencesPersist() {
        let defaults = makeDefaults()
        let preferences = UserPreferencesStore(defaults: defaults)
        var routine = DayRoutine.default
        routine.wakeMinute = 6 * 60
        preferences.dayRoutine = routine
        preferences.reminderSettings.water = true
        let reopened = UserPreferencesStore(defaults: defaults)
        #expect(reopened.dayRoutine.wakeMinute == 360)
        #expect(reopened.dailySchedule == routine.schedule)
        #expect(reopened.reminderSettings.water)
    }

    func makeCoordinator(status: ReminderAuthorization) -> (ReminderCoordinator, RecordingReminderScheduler, UserPreferencesStore) {
        let scheduler = RecordingReminderScheduler(status: status)
        let preferences = UserPreferencesStore(defaults: makeDefaults())
        let coordinator = ReminderCoordinator(
            preferences: preferences,
            profileStore: ProfileStore(directory: nil, defaults: makeDefaults()),
            scheduler: scheduler,
            dateProvider: FixedDateProvider(now)
        )
        return (coordinator, scheduler, preferences)
    }

    @Test("Applying the plan schedules only enabled reminders, and never asks for permission")
    func applyPlan() async {
        let (coordinator, scheduler, _) = makeCoordinator(status: .allowed)
        coordinator.setEnabled(false, id: "check.bedtime")
        await coordinator.applyIfAllowed()
        let daily = await scheduler.daily
        #expect(daily.count == coordinator.plan.count - 1)
        #expect(!daily.contains { $0.request.id == "check.bedtime" })
        #expect(await scheduler.authorizationRequests == 0)
    }

    @Test("Without permission nothing is scheduled until the user asks")
    func notDetermined() async {
        let (coordinator, scheduler, _) = makeCoordinator(status: .notDetermined)
        await coordinator.applyIfAllowed()
        #expect(await scheduler.daily.isEmpty)
        #expect(await scheduler.authorizationRequests == 0)
        #expect(await coordinator.enableAndApply())
        #expect(await scheduler.authorizationRequests == 1)
        #expect(await scheduler.daily.isEmpty == false)
    }

    @Test("Notification texts never carry the medicine name or dose")
    func genericTexts() async {
        let scheduler = RecordingReminderScheduler(status: .allowed)
        let store = ProfileStore(directory: nil, defaults: makeDefaults())
        store.save(UserProfile(medicines: [ProfileMedicine(name: "Synthetic-X", kind: .tablet, doseText: "750 mg", minutes: [480])]))
        let coordinator = ReminderCoordinator(
            preferences: UserPreferencesStore(defaults: makeDefaults()),
            profileStore: store,
            scheduler: scheduler,
            dateProvider: FixedDateProvider(now)
        )
        await coordinator.applyIfAllowed()
        let daily = await scheduler.daily
        #expect(daily.contains { $0.request.id.hasPrefix("med.") })
        #expect(daily.allSatisfy { !"\($0.request.title) \($0.request.body)".contains("Synthetic-X") })
        #expect(daily.allSatisfy { !"\($0.request.title) \($0.request.body)".contains("750") })
        // The in-app list may name it.
        if let medication = coordinator.plan.first(where: { $0.id.hasPrefix("med.") }) {
            #expect(coordinator.label(for: medication.kind).contains("Synthetic-X"))
        }
    }

    func meal(startedAt: Date, status: MealStatus = .eaten) -> Meal {
        Meal(slot: .lunch, status: status, startedAt: startedAt, timeZone: .gmt, items: [], createdAt: startedAt)
    }

    @Test("An eaten meal schedules a check after the chosen time; planned or deleted cancels it")
    func postMeal() async {
        let (coordinator, scheduler, preferences) = makeCoordinator(status: .allowed)
        preferences.reminderSettings.postMealMinutes = 90
        var eaten = meal(startedAt: now.addingTimeInterval(-10 * 60))
        await coordinator.mealSaved(eaten)
        let id = ReminderCoordinator.postMealID(eaten.id)
        #expect(await scheduler.once[id] == eaten.startedAt.addingTimeInterval(90 * 60))

        eaten.status = .planned
        await coordinator.mealSaved(eaten)
        #expect(await scheduler.once[id] == nil)

        eaten.status = .eaten
        await coordinator.mealSaved(eaten)
        await coordinator.mealDeleted(id: eaten.id)
        #expect(await scheduler.once[id] == nil)
    }

    @Test("No post-meal check when it is already past or switched off")
    func postMealSkipped() async {
        let (coordinator, scheduler, preferences) = makeCoordinator(status: .allowed)
        let old = meal(startedAt: now.addingTimeInterval(-3 * 3600))
        await coordinator.mealSaved(old)
        #expect(await scheduler.once.isEmpty)
        preferences.reminderSettings.postMealCheck = false
        await coordinator.mealSaved(meal(startedAt: now))
        #expect(await scheduler.once.isEmpty)
    }
}
