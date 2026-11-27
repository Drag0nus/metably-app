import Foundation

/// Source of the current time. Injected so tests never depend on the real clock.
/// (Named `DateProvider` to avoid clashing with the standard library `Clock` protocol.)
public protocol DateProvider: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}
    public func now() -> Date { Date() }
}

public struct FixedDateProvider: DateProvider {
    public let date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { date }
}
