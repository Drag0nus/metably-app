import Foundation
import MetablyDomain
import Testing
@testable import MetablySyntheticData

@Suite("Synthetic glucose generator")
struct SyntheticGlucoseGeneratorTests {
    let kyiv = TimeZone(identifier: "Europe/Kyiv")!
    let lastDay = LocalDay(year: 2026, month: 11, day: 27)

    @Test("Same seed gives the same diary")
    func deterministic() {
        let a = SyntheticGlucoseGenerator(seed: 7).makeReadings(days: 14, endingOn: lastDay, timeZone: kyiv)
        let b = SyntheticGlucoseGenerator(seed: 7).makeReadings(days: 14, endingOn: lastDay, timeZone: kyiv)
        #expect(a == b)
        #expect(a != SyntheticGlucoseGenerator(seed: 8).makeReadings(days: 14, endingOn: lastDay, timeZone: kyiv))
    }

    @Test("Every day has a fasting reading and all data is marked synthetic")
    func shape() {
        let readings = SyntheticGlucoseGenerator().makeReadings(days: 14, endingOn: lastDay, timeZone: kyiv)
        let days = Set(readings.map(\.localDay))
        #expect(days.count == 14)
        #expect(days.max() == lastDay)
        for day in days {
            #expect(readings.contains { $0.localDay == day && $0.context == .fasting })
        }
        #expect(readings.allSatisfy { $0.provenance.source == .synthetic })
        #expect(Set(readings.map(\.id)).count == readings.count)
    }

    @Test("Values pass the same validation as real entries")
    func plausible() {
        let validator = GlucoseEntryValidator()
        let readings = SyntheticGlucoseGenerator().makeReadings(days: 30, endingOn: lastDay, timeZone: kyiv)
        for reading in readings {
            #expect(validator.validate(value: reading.enteredValue, unit: reading.enteredUnit, flags: reading.flags)
                == .success(reading.enteredValue))
        }
    }

    @Test("Zero days gives no readings")
    func empty() {
        #expect(SyntheticGlucoseGenerator().makeReadings(days: 0, endingOn: lastDay, timeZone: kyiv).isEmpty)
    }
}
