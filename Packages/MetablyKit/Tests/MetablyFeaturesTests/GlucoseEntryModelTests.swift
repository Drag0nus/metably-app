import Foundation
import MetablyDomain
import Testing
@testable import MetablyFeatures

@MainActor
@Suite("Glucose entry model")
struct GlucoseEntryModelTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!

    func makeModel(repository: InMemoryGlucoseRepository = InMemoryGlucoseRepository()) -> GlucoseEntryModel {
        GlucoseEntryModel(repository: repository, unit: .millimolesPerLiter, dateProvider: FixedDateProvider(now), timeZone: kyiv)
    }

    @Test("Empty input cannot be saved but shows no error yet")
    func emptyInput() {
        let model = makeModel()
        #expect(!model.canSave)
        #expect(model.validationError == .empty)
        #expect(model.visibleValidationError == nil)
    }

    @Test("Typed invalid input shows an error")
    func invalidInput() {
        let model = makeModel()
        model.valueText = "99"
        #expect(model.visibleValidationError == .outOfPlausibleRange(lower: 0.5, upper: 35.0, unit: .millimolesPerLiter))
        #expect(model.save() == nil)
        #expect(model.saveError == .invalid(.outOfPlausibleRange(lower: 0.5, upper: 35.0, unit: .millimolesPerLiter)))
    }

    @Test("Saving stores a manual, verified reading with the chosen context and zone")
    func save() throws {
        let repository = InMemoryGlucoseRepository()
        let model = makeModel(repository: repository)
        model.valueText = "6,4"
        model.slot = .fasting
        model.note = "synthetic note"
        model.measuredAt = now.addingTimeInterval(-15 * 60)

        let saved = try #require(model.save())
        #expect(saved.enteredValue == 6.4)
        #expect(saved.context == .fasting)
        #expect(saved.provenance.source == .manual)
        #expect(saved.timeZoneID == "Europe/Kyiv")
        #expect(try repository.allReadings() == [saved])
    }

    @Test("Switching unit re-validates the same text")
    func unitSwitch() {
        let model = makeModel()
        model.valueText = "120"
        #expect(!model.canSave)
        model.unit = .milligramsPerDeciliter
        #expect(model.canSave)
    }

    @Test("Diary groups readings by local day, newest day first")
    func grouping() {
        let day1 = LocalDay(year: 2026, month: 11, day: 26)
        let day2 = LocalDay(year: 2026, month: 11, day: 27)
        func reading(_ day: LocalDay, _ hour: Int) -> GlucoseReading {
            let date = day.instant(hour: hour, minute: 0, in: kyiv)!
            return GlucoseReading(enteredValue: 6, enteredUnit: .millimolesPerLiter, context: .random,
                                  measuredAt: date, timeZone: kyiv, provenance: .manual, createdAt: date)
        }
        let sections = GlucoseLogModel.group([reading(day1, 7), reading(day2, 7), reading(day2, 22)])
        #expect(sections.map(\.day) == [day2, day1])
        #expect(sections.first?.readings.count == 2)
        #expect(sections.first?.readings.first?.measuredAt == day2.instant(hour: 22, minute: 0, in: kyiv))
    }
}
