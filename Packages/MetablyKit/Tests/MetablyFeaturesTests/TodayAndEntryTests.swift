import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@MainActor
@Suite("Glucose entry: slots, targets, duplicates and low guidance")
struct GlucoseEntryBehaviourTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func makeModel(
        at date: Date,
        repository: InMemoryGlucoseRepository = InMemoryGlucoseRepository(),
        nightCheck: Bool = false,
        reminders: any RecheckReminderScheduling = NoopRecheckReminder()
    ) -> GlucoseEntryModel {
        GlucoseEntryModel(
            repository: repository,
            unit: .millimolesPerLiter,
            dateProvider: FixedDateProvider(date),
            timeZone: kyiv,
            nightCheckEnabled: nightCheck,
            reminders: reminders
        )
    }

    @Test("The slot is suggested from the local time and maps to the stored context")
    func suggestedSlot() throws {
        let model = makeModel(at: instant(13, 5))
        #expect(model.slot == .beforeLunch)
        #expect(model.context == .beforeMeal)
        model.valueText = "6,5"
        let saved = try #require(model.save())
        #expect(saved.context == .beforeMeal)
        #expect(saved.diarySlot() == .beforeLunch)
    }

    @Test("The night slot is offered only when the night check is on")
    func nightSlotOffered() {
        #expect(!makeModel(at: instant(10)).availableSlots.contains(.night))
        #expect(makeModel(at: instant(10), nightCheck: true).availableSlots.contains(.night))
        #expect(makeModel(at: instant(3), nightCheck: true).slot == .night)
    }

    @Test("Typed value shows its status against the targets before saving")
    func previewStatus() {
        let model = makeModel(at: instant(13, 5))
        model.valueText = "7,1"
        #expect(model.previewStatus == .inRange)
        model.valueText = "12,1"
        #expect(model.previewStatus == .above)
        model.valueText = ""
        #expect(model.previewStatus == nil)
    }

    @Test("Low guidance appears below 3.9 mmol/L only")
    func lowGuidance() {
        let model = makeModel(at: instant(13, 5))
        model.valueText = "3,4"
        #expect(model.showsLowGlucoseGuidance)
        model.valueText = "3,9"
        #expect(!model.showsLowGlucoseGuidance)
    }

    @Test("Recheck reminder reports scheduled or unavailable")
    func recheckReminder() async {
        let model = makeModel(at: instant(13, 5))
        model.scheduleRecheckReminder()
        await waitUntil { model.recheckReminder != .notScheduled }
        #expect(model.recheckReminder == .scheduled(at: instant(13, 20)))

        let denied = makeModel(at: instant(13, 5), reminders: NoopRecheckReminder(succeeds: false))
        denied.scheduleRecheckReminder()
        await waitUntil { denied.recheckReminder != .notScheduled }
        #expect(denied.recheckReminder == .unavailable)
    }

    @Test("Same value within 5 minutes asks before saving another")
    func duplicateWarning() throws {
        let repository = InMemoryGlucoseRepository()
        let first = makeModel(at: instant(13, 5), repository: repository)
        first.valueText = "6,5"
        try #require(first.save() != nil)

        let second = makeModel(at: instant(13, 8), repository: repository)
        second.valueText = "6,5"
        #expect(second.save() == nil)
        #expect(second.likelyDuplicate != nil)
        #expect(try repository.allReadings().count == 1)

        #expect(second.saveDespiteDuplicate() != nil)
        #expect(second.likelyDuplicate == nil)
        #expect(try repository.allReadings().count == 2)
    }

    @Test("A different value is saved without a warning")
    func noDuplicate() throws {
        let repository = InMemoryGlucoseRepository()
        let first = makeModel(at: instant(13, 5), repository: repository)
        first.valueText = "6,5"
        try #require(first.save() != nil)
        let second = makeModel(at: instant(13, 8), repository: repository)
        second.valueText = "6,8"
        #expect(second.save() != nil)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}

@MainActor
@Suite("Today")
struct TodayModelTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ day: LocalDay, _ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func reading(_ value: Double, _ context: GlucoseMeasurementContext, at date: Date) -> GlucoseReading {
        GlucoseReading(enteredValue: value, enteredUnit: .millimolesPerLiter, context: context,
                       measuredAt: date, timeZone: kyiv, provenance: .manual, createdAt: date)
    }

    func makeModel(readings: [GlucoseReading], now: Date) -> TodayModel {
        let defaults = UserDefaults(suiteName: "test.today.\(UUID().uuidString)")!
        let dependencies = AppDependencies(
            glucoseRepository: InMemoryGlucoseRepository(readings: readings),
            preferences: UserPreferencesStore(defaults: defaults),
            dateProvider: FixedDateProvider(now)
        )
        return TodayModel(dependencies: dependencies, timeZone: kyiv)
    }

    @Test("Readings fill the 7-point strip; the newest reading wins a slot")
    func strip() {
        let readings = [
            reading(6.1, .fasting, at: instant(day, 7, 10)),
            reading(6.4, .fasting, at: instant(day, 7, 40)),
            reading(8.9, .afterMeal, at: instant(day, 10, 0)),
            reading(6.5, .beforeMeal, at: instant(day, 13, 5)),
            reading(5.9, .fasting, at: instant(day.adding(days: -1), 7, 0)),
        ]
        let model = makeModel(readings: readings, now: instant(day, 13, 20))
        model.reload()

        #expect(model.slotCells.count == 7)
        #expect(model.measuredSlotCount == 3)
        #expect(model.slotCells.first { $0.slot == .fasting }?.reading?.enteredValue == 6.4)
        #expect(model.slotCells.first { $0.slot == .afterBreakfast }?.reading?.enteredValue == 8.9)
        #expect(model.slotCells.first { $0.slot == .beforeLunch }?.reading?.enteredValue == 6.5)
        #expect(model.todayReadings.count == 4)
        #expect(model.latest?.enteredValue == 6.5)
    }

    @Test("Yesterday's reading is still the latest on an empty day")
    func latestFromYesterday() {
        let yesterday = reading(7.0, .bedtime, at: instant(day.adding(days: -1), 22, 0))
        let model = makeModel(readings: [yesterday], now: instant(day, 8, 0))
        model.reload()
        #expect(model.latest == yesterday)
        #expect(model.todayReadings.isEmpty)
        #expect(model.measuredSlotCount == 0)
    }

    @Test("Empty store shows no latest reading")
    func empty() {
        let model = makeModel(readings: [], now: instant(day, 8, 0))
        model.reload()
        #expect(model.latest == nil)
        #expect(model.slotCells.allSatisfy { $0.reading == nil })
    }
}

@MainActor
@Suite("Preferences")
struct PreferencesTargetTests {
    @Test("Targets default to ADA values and persist valid edits only")
    func targets() {
        let suite = "test.prefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = UserPreferencesStore(defaults: defaults)
        #expect(store.glucoseTargets == .adaDefaults)

        var edited = GlucoseTargets.adaDefaults
        edited.postMealUpperMmolL = 9.0
        store.glucoseTargets = edited
        #expect(UserPreferencesStore(defaults: defaults).glucoseTargets == edited)

        store.glucoseTargets = GlucoseTargets(preMealLowerMmolL: 8, preMealUpperMmolL: 6, postMealUpperMmolL: 9)
        #expect(UserPreferencesStore(defaults: defaults).glucoseTargets == edited)
    }
}

@MainActor
@Suite("Activity and diary table")
struct ActivityAndTableTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ day: LocalDay, _ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    @Test("The entry saves the chosen activity level, preset from the last choice")
    func activitySaved() throws {
        let repository = InMemoryGlucoseRepository()
        let model = GlucoseEntryModel(
            repository: repository, unit: .millimolesPerLiter,
            dateProvider: FixedDateProvider(instant(day, 13, 5)), timeZone: kyiv,
            activityLevel: ActivityLevel(rawValue: 3)
        )
        #expect(model.activityLevel == ActivityLevel(rawValue: 3))
        model.activityLevel = ActivityLevel(rawValue: 4)
        model.valueText = "6,5"
        let saved = try #require(model.save())
        #expect(saved.activityLevel == ActivityLevel(rawValue: 4))
    }

    @Test("Last activity level persists in preferences; cleared stays cleared")
    func lastActivity() {
        let defaults = UserDefaults(suiteName: "test.activity.\(UUID().uuidString)")!
        let store = UserPreferencesStore(defaults: defaults)
        #expect(store.lastActivityLevel == nil)
        store.lastActivityLevel = ActivityLevel(rawValue: 2)
        #expect(UserPreferencesStore(defaults: defaults).lastActivityLevel == ActivityLevel(rawValue: 2))
        store.lastActivityLevel = nil
        #expect(UserPreferencesStore(defaults: defaults).lastActivityLevel == nil)
    }

    @Test("Diary table rows place readings in slot columns, newest first per slot")
    func tableRows() {
        func reading(_ value: Double, _ context: GlucoseMeasurementContext, _ date: Date) -> GlucoseReading {
            GlucoseReading(enteredValue: value, enteredUnit: .millimolesPerLiter, context: context,
                           measuredAt: date, timeZone: kyiv, provenance: .manual, createdAt: date)
        }
        let readings = [
            reading(6.1, .fasting, instant(day, 7, 0)),
            reading(6.3, .fasting, instant(day, 7, 30)),
            reading(9.2, .afterMeal, instant(day, 15, 0)),
            reading(5.8, .random, instant(day, 16, 0)),
            reading(7.0, .bedtime, instant(day.adding(days: -1), 22, 30)),
        ]
        let rows = GlucoseLogModel.rows(from: GlucoseLogModel.group(readings), schedule: .default)
        #expect(rows.map(\.day) == [day, day.adding(days: -1)])
        #expect(rows[0].cells[.fasting]?.map(\.enteredValue) == [6.3, 6.1])
        #expect(rows[0].cells[.afterLunch]?.first?.enteredValue == 9.2)
        #expect(rows[0].cells[.other]?.count == 1)
        #expect(rows[1].cells[.bedtime]?.first?.enteredValue == 7.0)
    }
}

@MainActor
@Suite("Edit reading and meter LO/HI")
struct EditReadingTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let day = LocalDay(year: 2026, month: 11, day: 27)

    func instant(_ hour: Int, _ minute: Int = 0) -> Date { day.instant(hour: hour, minute: minute, in: kyiv)! }

    func model(_ repository: InMemoryGlucoseRepository, at date: Date, editing: GlucoseReading? = nil) -> GlucoseEntryModel {
        GlucoseEntryModel(
            repository: repository, unit: .millimolesPerLiter,
            dateProvider: FixedDateProvider(date), timeZone: kyiv, editing: editing
        )
    }

    func saved(_ repository: InMemoryGlucoseRepository, text: String = "6,5", at date: Date) throws -> GlucoseReading {
        let entry = model(repository, at: date)
        entry.valueText = text
        entry.activityLevel = ActivityLevel(rawValue: 2)
        return try #require(entry.save())
    }

    @Test("Editing prefills the form from the reading")
    func prefill() throws {
        let repository = InMemoryGlucoseRepository()
        let original = try saved(repository, at: instant(13, 5))
        let edit = model(repository, at: instant(14), editing: original)
        #expect(edit.isEditing)
        #expect(GlucoseValueParser.parse(edit.valueText) == 6.5)
        #expect(edit.slot == .beforeLunch)
        #expect(edit.measuredAt == original.measuredAt)
        #expect(edit.activityLevel == ActivityLevel(rawValue: 2))
    }

    @Test("Saving an edit updates the same reading and bumps its version")
    func update() throws {
        let repository = InMemoryGlucoseRepository()
        let original = try saved(repository, at: instant(13, 5))
        let edit = model(repository, at: instant(14), editing: original)
        edit.valueText = "7,2"
        edit.slot = .afterLunch
        let updated = try #require(edit.save())
        #expect(updated.id == original.id)
        #expect(updated.enteredValue == 7.2)
        #expect(updated.context == .afterMeal)
        #expect(updated.version == original.version + 1)
        #expect(try repository.allReadings().count == 1)
    }

    @Test("An unchanged value does not warn about itself as a duplicate")
    func noSelfDuplicate() throws {
        let repository = InMemoryGlucoseRepository()
        let original = try saved(repository, at: instant(13, 5))
        let edit = model(repository, at: instant(14), editing: original)
        edit.note = "synthetic note"
        #expect(edit.save() != nil)
        #expect(edit.likelyDuplicate == nil)
    }

    @Test("Deleting from the edit sheet soft-deletes the reading")
    func delete() throws {
        let repository = InMemoryGlucoseRepository()
        let original = try saved(repository, at: instant(13, 5))
        let edit = model(repository, at: instant(14), editing: original)
        #expect(edit.deleteEditedReading())
        #expect(try repository.allReadings().isEmpty)
        #expect(try repository.reading(id: original.id)?.isDeleted == true)
    }

    @Test("HI prefills the meter limit, skips plausibility bounds and is above target")
    func meterHigh() throws {
        let repository = InMemoryGlucoseRepository()
        let entry = model(repository, at: instant(13, 5))
        entry.meterDisplay = .high
        #expect(GlucoseValueParser.parse(entry.valueText) == 33.3)
        entry.valueText = "40"   // above the 35 mmol/L typo bound, allowed for HI
        #expect(entry.canSave)
        #expect(entry.previewStatus == .above)
        let reading = try #require(entry.save())
        #expect(reading.flags.contains(.meterHigh))
    }

    @Test("LO shows the low guidance and is stored with its flag")
    func meterLow() throws {
        let repository = InMemoryGlucoseRepository()
        let entry = model(repository, at: instant(13, 5))
        entry.meterDisplay = .low
        #expect(entry.showsLowGlucoseGuidance)
        let reading = try #require(entry.save())
        #expect(reading.flags.contains(.meterLow))
        #expect(reading.isLow)

        let edit = model(repository, at: instant(14), editing: reading)
        #expect(edit.meterDisplay == .low)
        #expect(GlucoseValueParser.parse(edit.valueText) == 0.6)
    }
}
