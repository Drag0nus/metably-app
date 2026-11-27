import Foundation

/// Parses a glucose value typed by the user.
///
/// Accepts both "6,4" (Ukrainian decimal comma) and "6.4", regardless of the device locale,
/// because users switch keyboards. Only ASCII digits and a single separator are accepted.
public enum GlucoseValueParser {
    public static func parse(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              normalized.filter({ $0 == "." }).count <= 1,
              normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") })
        else { return nil }
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
