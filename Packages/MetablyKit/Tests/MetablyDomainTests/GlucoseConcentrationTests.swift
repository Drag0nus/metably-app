import Foundation
import Testing
@testable import MetablyDomain

@Suite("Glucose concentration and units")
struct GlucoseConcentrationTests {
    @Test("mmol/L to mg/dL uses 18.016")
    func mmolToMg() {
        let value = GlucoseConcentration(value: 5.5, unit: .millimolesPerLiter)
        #expect(abs(value.value(in: .milligramsPerDeciliter) - 99.088) < 0.0001)
        #expect(value.roundedValue(in: .milligramsPerDeciliter) == 99)
    }

    @Test("mg/dL is stored canonically as mmol/L")
    func mgToMmol() {
        let value = GlucoseConcentration(value: 100, unit: .milligramsPerDeciliter)
        #expect(abs(value.millimolesPerLiter - 5.5506) < 0.0001)
        #expect(value.roundedValue(in: .millimolesPerLiter) == 5.6)
    }

    @Test("Round trip keeps the entered value", arguments: [40.0, 72, 100, 126, 180, 250, 400])
    func roundTrip(mgPerDL: Double) {
        let value = GlucoseConcentration(value: mgPerDL, unit: .milligramsPerDeciliter)
        #expect(value.roundedValue(in: .milligramsPerDeciliter) == mgPerDL)
    }

    @Test("Formatting follows the locale decimal separator")
    func formatting() {
        let value = GlucoseConcentration(millimolesPerLiter: 6.44)
        #expect(value.formattedValue(in: .millimolesPerLiter, locale: Locale(identifier: "uk_UA")) == "6,4")
        #expect(value.formattedValue(in: .millimolesPerLiter, locale: Locale(identifier: "en_US")) == "6.4")
        #expect(value.formattedValue(in: .milligramsPerDeciliter, locale: Locale(identifier: "en_US")) == "116")
    }

    @Test("Concentrations compare by canonical value")
    func comparable() {
        #expect(GlucoseConcentration(value: 90, unit: .milligramsPerDeciliter)
            < GlucoseConcentration(value: 5.5, unit: .millimolesPerLiter))
    }
}

@Suite("Parsing and validation of entered values")
struct GlucoseEntryValidationTests {
    let validator = GlucoseEntryValidator()

    @Test("Accepts decimal comma and point", arguments: [("6,4", 6.4), ("6.4", 6.4), (" 7 ", 7.0), ("12,0", 12.0)])
    func parsesDecimals(text: String, expected: Double) {
        #expect(GlucoseValueParser.parse(text) == expected)
    }

    @Test("Rejects malformed input", arguments: ["", "abc", "6,4,1", "6..4", "-5", "1e3", "٦"])
    func rejectsMalformed(text: String) {
        #expect(GlucoseValueParser.parse(text) == nil)
    }

    @Test("Empty and non-numeric input give specific errors")
    func specificErrors() {
        #expect(validator.validate(text: "  ", unit: .millimolesPerLiter) == .failure(.empty))
        #expect(validator.validate(text: "x", unit: .millimolesPerLiter) == .failure(.notANumber))
    }

    @Test("Values outside plausibility bounds are rejected in the entered unit")
    func plausibility() {
        #expect(validator.validate(text: "64", unit: .millimolesPerLiter)
            == .failure(.outOfPlausibleRange(lower: 0.5, upper: 35.0, unit: .millimolesPerLiter)))
        #expect(validator.validate(text: "5", unit: .milligramsPerDeciliter)
            == .failure(.outOfPlausibleRange(lower: 9, upper: 631, unit: .milligramsPerDeciliter)))
        #expect(validator.validate(text: "6,4", unit: .millimolesPerLiter) == .success(6.4))
        #expect(validator.validate(text: "115", unit: .milligramsPerDeciliter) == .success(115))
    }

    @Test("Meter HI/LO values bypass plausibility bounds")
    func meterLimits() {
        #expect(validator.validate(value: 0.4, unit: .millimolesPerLiter, flags: .meterLow) == .success(0.4))
    }

    @Test("Times more than five minutes in the future are rejected")
    func futureTimes() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(validator.validate(measuredAt: now.addingTimeInterval(4 * 60), now: now) == nil)
        #expect(validator.validate(measuredAt: now.addingTimeInterval(6 * 60), now: now) == .measuredInFuture)
    }
}
