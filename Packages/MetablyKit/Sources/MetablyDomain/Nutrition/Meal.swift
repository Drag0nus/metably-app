import Foundation

/// Planned meals become eaten meals in one tap. Raw values are persisted; never rename them.
public enum MealStatus: String, Sendable, Hashable, Codable, CaseIterable {
    case planned
    case eaten
}

/// The paper diary's food volume for meals logged without weighing: М / С / В.
/// Raw values are persisted; never rename them.
public enum PortionSize: String, Sendable, Hashable, Codable, CaseIterable {
    case small
    case medium
    case large
}

/// One food in a meal. Carbohydrate grams are the stored fact; bread units are derived.
///
/// All nutrients other than carbohydrates are optional: the user may know only the carbs.
public struct MealItem: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    /// Weight or volume of the portion in grams (ml counted as g), when known.
    public var amountGrams: Double?
    public var carbohydrateGrams: Double
    public var sugarsGrams: Double?
    public var fiberGrams: Double?
    public var proteinGrams: Double?
    public var fatGrams: Double?
    public var energyKilocalories: Double?

    public init(
        id: UUID = UUID(),
        name: String,
        amountGrams: Double? = nil,
        carbohydrateGrams: Double,
        sugarsGrams: Double? = nil,
        fiberGrams: Double? = nil,
        proteinGrams: Double? = nil,
        fatGrams: Double? = nil,
        energyKilocalories: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.amountGrams = amountGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.sugarsGrams = sugarsGrams
        self.fiberGrams = fiberGrams
        self.proteinGrams = proteinGrams
        self.fatGrams = fatGrams
        self.energyKilocalories = energyKilocalories
    }
}

/// A meal on the timeline: planned or eaten, with its foods.
///
/// Dietary sugars here are grams of food, never blood glucose: the types are separate on purpose.
public struct Meal: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var slot: MealSlot
    public var status: MealStatus
    /// When the meal starts (eaten) or is planned to start.
    public var startedAt: Date
    public var timeZoneID: String
    /// Diary day in the meal's own zone.
    public var localDay: LocalDay
    public var items: [MealItem]
    public var portionSize: PortionSize?
    public var note: String?
    public var provenance: Provenance
    public var createdAt: Date
    public var modifiedAt: Date
    public var version: Int
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        slot: MealSlot,
        status: MealStatus,
        startedAt: Date,
        timeZone: TimeZone,
        items: [MealItem],
        portionSize: PortionSize? = nil,
        note: String? = nil,
        provenance: Provenance = Provenance(source: .manual, providerID: "manual"),
        createdAt: Date,
        modifiedAt: Date? = nil,
        version: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.slot = slot
        self.status = status
        self.startedAt = startedAt
        self.timeZoneID = timeZone.identifier
        self.localDay = LocalDay(instant: startedAt, timeZone: timeZone)
        self.items = items
        self.portionSize = portionSize
        self.note = note
        self.provenance = provenance
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.version = version
        self.deletedAt = deletedAt
    }

    public var isDeleted: Bool { deletedAt != nil }
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }

    public var totalCarbohydrateGrams: Double { items.reduce(0) { $0 + $1.carbohydrateGrams } }

    /// Sum of an optional nutrient, or nil when no item has it (unknown is not zero).
    public func total(_ nutrient: KeyPath<MealItem, Double?>) -> Double? {
        let known = items.compactMap { $0[keyPath: nutrient] }
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    /// Minimal view used by `MealLinkSuggester`.
    public var timeReference: MealTimeReference {
        MealTimeReference(id: id, slot: slot, startedAt: startedAt)
    }
}

public enum MealValidationError: Error, Sendable, Hashable {
    case noItems
    case emptyName
    case carbohydratesOutOfRange
    case amountOutOfRange
}

/// Plausibility checks to catch typos, not dietary advice.
public struct MealValidator: Sendable {
    public static let carbohydrateRangePerItem: ClosedRange<Double> = 0...500
    public static let amountRangeGrams: ClosedRange<Double> = 0...3000

    public init() {}

    public func validate(_ item: MealItem) -> MealValidationError? {
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyName }
        if !item.carbohydrateGrams.isFinite || !Self.carbohydrateRangePerItem.contains(item.carbohydrateGrams) {
            return .carbohydratesOutOfRange
        }
        if let amount = item.amountGrams, !amount.isFinite || !Self.amountRangeGrams.contains(amount) {
            return .amountOutOfRange
        }
        return nil
    }

    public func validate(_ meal: Meal) -> MealValidationError? {
        if meal.items.isEmpty { return .noItems }
        return meal.items.lazy.compactMap { self.validate($0) }.first
    }
}

/// Storage abstraction for meals, mirroring `GlucoseRepository`.
@MainActor
public protocol MealRepository: AnyObject {
    func insert(_ meal: Meal) throws
    func update(_ meal: Meal) throws
    func softDelete(id: UUID) throws
    func meal(id: UUID) throws -> Meal?
    /// Non-deleted meals with `from <= startedAt < to`, earliest first.
    func meals(from: Date, to: Date) throws -> [Meal]
}

/// In-memory meals for previews and tests.
@MainActor
public final class InMemoryMealRepository: MealRepository {
    public private(set) var storage: [UUID: Meal] = [:]
    private let dateProvider: any DateProvider

    public init(meals: [Meal] = [], dateProvider: any DateProvider = SystemDateProvider()) {
        self.dateProvider = dateProvider
        for meal in meals { storage[meal.id] = meal }
    }

    public func insert(_ meal: Meal) throws {
        guard storage[meal.id] == nil else { throw RepositoryError.duplicateID }
        storage[meal.id] = meal
    }

    public func update(_ meal: Meal) throws {
        guard let existing = storage[meal.id] else { throw RepositoryError.notFound }
        var updated = meal
        updated.version = existing.version + 1
        updated.modifiedAt = dateProvider.now()
        storage[meal.id] = updated
    }

    public func softDelete(id: UUID) throws {
        guard var existing = storage[id] else { throw RepositoryError.notFound }
        guard existing.deletedAt == nil else { return }
        let now = dateProvider.now()
        existing.deletedAt = now
        existing.modifiedAt = now
        existing.version += 1
        storage[id] = existing
    }

    public func meal(id: UUID) throws -> Meal? { storage[id] }

    public func meals(from: Date, to: Date) throws -> [Meal] {
        storage.values
            .filter { !$0.isDeleted && $0.startedAt >= from && $0.startedAt < to }
            .sorted { $0.startedAt < $1.startedAt }
    }
}
