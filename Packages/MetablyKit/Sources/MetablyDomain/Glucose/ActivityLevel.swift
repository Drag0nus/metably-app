import Foundation

/// Physical activity around a glucose check on the paper diary's 1–5 scale
/// (1 = minimal, 5 = high). Self-reported context, not a measurement.
///
/// The raw value is persisted (schema V2) and must keep its meaning.
public struct ActivityLevel: RawRepresentable, Sendable, Hashable, Comparable, Codable, Identifiable {
    public let rawValue: Int

    public static let range: ClosedRange<Int> = 1...5

    /// Returns nil outside 1...5, so an unknown stored value is dropped rather than misread.
    public init?(rawValue: Int) {
        guard Self.range.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    public static let all: [ActivityLevel] = range.compactMap(ActivityLevel.init(rawValue:))

    public var id: Int { rawValue }

    /// Encoded as a bare number, e.g. `3`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int.self)
        guard let level = ActivityLevel(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Activity level out of range")
        }
        self = level
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: ActivityLevel, rhs: ActivityLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}
