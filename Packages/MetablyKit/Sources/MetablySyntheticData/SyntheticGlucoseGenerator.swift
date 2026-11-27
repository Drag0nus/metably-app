import Foundation
import MetablyDomain

/// Deterministic pseudo-random generator (SplitMix64) so synthetic data is reproducible.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Generates **synthetic** glucose diaries for previews, tests and development.
///
/// Values are plausible-looking but invented; they do not model any real person and must
/// never be used as clinical reference. Every generated reading has `source == .synthetic`.
public struct SyntheticGlucoseGenerator: Sendable {
    public static let providerID = "synthetic"

    struct Slot {
        let hour: Int
        let minute: Int
        let context: GlucoseMeasurementContext
        let minutesAfterMeal: Int?
        let range: ClosedRange<Double>
        /// Probability that this slot is measured on a given day.
        let probability: Double
    }

    // A loose 7-point profile day. Ranges are arbitrary synthetic values in mmol/L.
    static let slots: [Slot] = [
        Slot(hour: 7, minute: 0, context: .fasting, minutesAfterMeal: nil, range: 5.2...7.8, probability: 1.0),
        Slot(hour: 10, minute: 0, context: .afterMeal, minutesAfterMeal: 120, range: 6.5...10.5, probability: 0.5),
        Slot(hour: 13, minute: 0, context: .beforeMeal, minutesAfterMeal: nil, range: 5.0...7.5, probability: 0.3),
        Slot(hour: 15, minute: 0, context: .afterMeal, minutesAfterMeal: 120, range: 6.5...11.0, probability: 0.4),
        Slot(hour: 18, minute: 30, context: .beforeMeal, minutesAfterMeal: nil, range: 5.0...8.0, probability: 0.3),
        Slot(hour: 21, minute: 0, context: .afterMeal, minutesAfterMeal: 120, range: 6.5...11.5, probability: 0.4),
        Slot(hour: 22, minute: 30, context: .bedtime, minutesAfterMeal: nil, range: 5.5...8.5, probability: 0.5),
    ]

    public let seed: UInt64

    public init(seed: UInt64 = 2026) {
        self.seed = seed
    }

    /// Readings for `days` diary days ending on `lastDay` (inclusive), oldest first.
    public func makeReadings(days: Int, endingOn lastDay: LocalDay, timeZone: TimeZone) -> [GlucoseReading] {
        guard days > 0 else { return [] }
        var rng = SeededRandomNumberGenerator(seed: seed)
        var readings: [GlucoseReading] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let day = lastDay.adding(days: -offset)
            for slot in Self.slots {
                guard Double.random(in: 0..<1, using: &rng) < slot.probability else { continue }
                let jitter = Int.random(in: -20...20, using: &rng)
                guard let base = day.instant(hour: slot.hour, minute: slot.minute, in: timeZone) else { continue }
                let measuredAt = base.addingTimeInterval(TimeInterval(jitter * 60))
                let value = (Double.random(in: slot.range, using: &rng) * 10).rounded() / 10
                readings.append(GlucoseReading(
                    id: Self.makeUUID(using: &rng),
                    enteredValue: value,
                    enteredUnit: .millimolesPerLiter,
                    context: slot.context,
                    minutesAfterMeal: slot.minutesAfterMeal.map { $0 + jitter },
                    measuredAt: measuredAt,
                    timeZone: timeZone,
                    provenance: Provenance(
                        source: .synthetic,
                        providerID: Self.providerID,
                        sourceDetail: "Synthetic data generator"
                    ),
                    isUserVerified: true,
                    createdAt: measuredAt
                ))
            }
        }
        return readings
    }

    static func makeUUID(using rng: inout SeededRandomNumberGenerator) -> UUID {
        let high = rng.next()
        let low = rng.next()
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8(truncatingIfNeeded: high >> (8 * UInt64(index)))
            bytes[index + 8] = UInt8(truncatingIfNeeded: low >> (8 * UInt64(index)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
