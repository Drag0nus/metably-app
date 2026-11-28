import Foundation

/// A food from a reference database, with nutrients per 100 g and household portions.
///
/// Values are reference averages from the source (USDA FoodData Central), not a measurement of
/// the user's food. A nutrient the source does not report is nil, never zero.
public struct Food: Sendable, Hashable, Codable, Identifiable {
    public struct Per100g: Sendable, Hashable, Codable {
        public var kcal: Double?
        public var protein: Double?
        public var fat: Double?
        public var carbohydrate: Double?
        public var sugars: Double?
        public var fiber: Double?
        public var sucrose: Double?
        public var glucose: Double?
        public var fructose: Double?
        public var lactose: Double?
        public var maltose: Double?
        public var galactose: Double?

        public init(
            kcal: Double? = nil, protein: Double? = nil, fat: Double? = nil, carbohydrate: Double? = nil,
            sugars: Double? = nil, fiber: Double? = nil, sucrose: Double? = nil, glucose: Double? = nil,
            fructose: Double? = nil, lactose: Double? = nil, maltose: Double? = nil, galactose: Double? = nil
        ) {
            self.kcal = kcal
            self.protein = protein
            self.fat = fat
            self.carbohydrate = carbohydrate
            self.sugars = sugars
            self.fiber = fiber
            self.sucrose = sucrose
            self.glucose = glucose
            self.fructose = fructose
            self.lactose = lactose
            self.maltose = maltose
            self.galactose = galactose
        }

        func value(for sugar: DietarySugar) -> Double? {
            switch sugar {
            case .sucrose: sucrose
            case .glucose: glucose
            case .fructose: fructose
            case .lactose: lactose
            case .maltose: maltose
            case .galactose: galactose
            }
        }
    }

    /// A household measure, e.g. "1 piece, large = 50 g".
    public struct Portion: Sendable, Hashable, Codable {
        public var nameEN: String
        public var nameUK: String
        public var grams: Double
        /// Where the weight comes from when it is not USDA, e.g. "diary p. 14" for the
        /// Ukrainian self-control diary's bread-unit tables.
        public var source: String?

        public init(nameEN: String, nameUK: String, grams: Double, source: String? = nil) {
            self.nameEN = nameEN
            self.nameUK = nameUK
            self.grams = grams
            self.source = source
        }
    }

    /// Stable id, e.g. "usda-sr-173424". Stored on meal items; never change it for a food.
    public var id: String
    public var nameEN: String
    public var nameUK: String
    public var category: String
    /// The source's own description, kept for attribution and traceability.
    public var sourceDescription: String
    public var per100g: Per100g
    public var portions: [Portion]

    public init(
        id: String, nameEN: String, nameUK: String, category: String,
        sourceDescription: String, per100g: Per100g, portions: [Portion] = []
    ) {
        self.id = id
        self.nameEN = nameEN
        self.nameUK = nameUK
        self.category = category
        self.sourceDescription = sourceDescription
        self.per100g = per100g
        self.portions = portions
    }

    /// A meal item for `grams` of this food, every known nutrient scaled from 100 g.
    /// Carbohydrates the source lacks count as 0 g only because a meal item needs a number;
    /// the user can still edit them.
    public func mealItem(grams: Double, name: String, id: UUID = UUID()) -> MealItem {
        let factor = grams / 100
        func scaled(_ value: Double?) -> Double? { value.map { Self.round($0 * factor) } }
        var item = MealItem(
            id: id,
            name: name,
            amountGrams: Self.round(grams),
            carbohydrateGrams: scaled(per100g.carbohydrate) ?? 0,
            sugarsGrams: scaled(per100g.sugars),
            fiberGrams: scaled(per100g.fiber),
            proteinGrams: scaled(per100g.protein),
            fatGrams: scaled(per100g.fat),
            energyKilocalories: per100g.kcal.map { ($0 * factor).rounded() },
            foodID: self.id
        )
        for sugar in DietarySugar.allCases {
            item[keyPath: sugar.keyPath] = scaled(per100g.value(for: sugar))
        }
        return item
    }

    /// One decimal is the precision of the source; more would be false accuracy.
    public static func round(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}

/// The bundled, read-only food list with search across Ukrainian and English names.
public struct FoodCatalog: Sendable {
    /// Attribution shown in the app, e.g. "USDA FoodData Central, SR Legacy …".
    public let source: String
    public let sourceURL: URL?
    public let foods: [Food]
    private let byID: [String: Food]
    private let searchKeys: [String: [String]]

    public init(source: String, sourceURL: URL?, foods: [Food]) {
        self.source = source
        self.sourceURL = sourceURL
        self.foods = foods
        byID = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        searchKeys = Dictionary(
            foods.map { ($0.id, [Self.normalize($0.nameUK), Self.normalize($0.nameEN)]) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// An empty catalog, e.g. when the resource cannot be read.
    public static let empty = FoodCatalog(source: "", sourceURL: nil, foods: [])

    public func food(id: String) -> Food? { byID[id] }

    /// Foods whose name matches every word of `query`, best first: a name starting with the
    /// query, then a word starting with it, then any match. Case and accents are ignored.
    public func search(_ query: String, limit: Int = 8) -> [Food] {
        let words = Self.normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        let joined = words.joined(separator: " ")
        var scored: [(score: Int, index: Int, food: Food)] = []
        for (index, food) in foods.enumerated() {
            guard let keys = searchKeys[food.id] else { continue }
            var best: Int?
            for key in keys where words.allSatisfy({ key.contains($0) }) {
                let score: Int
                if key.hasPrefix(joined) {
                    score = 0
                } else if key.split(separator: " ").contains(where: { $0.hasPrefix(words[0]) }) {
                    score = 1
                } else {
                    score = 2
                }
                best = min(best ?? score, score)
            }
            if let best { scored.append((best, index, food)) }
        }
        return scored
            .sorted { ($0.score, $0.index) < ($1.score, $1.index) }
            .prefix(limit)
            .map(\.food)
    }

    /// Lowercased, accents folded, punctuation as spaces. "ґ" and "й" keep their identity
    /// because folding would merge different Ukrainian letters.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        var result = ""
        for character in lowered {
            if character == "ґ" || character == "й" || character == "ї" || character == "є" {
                result.append(character)
            } else if character.isLetter || character.isNumber {
                result += String(character).folding(options: .diacriticInsensitive, locale: nil)
            } else {
                result.append(" ")
            }
        }
        return result.split(separator: " ").joined(separator: " ")
    }
}

/// The on-disk shape of a catalog file.
public struct FoodCatalogFile: Sendable, Codable {
    public var source: String
    public var sourceURL: String?
    public var foods: [Food]

    public static func decode(_ data: Data) throws -> FoodCatalog {
        let file = try JSONDecoder().decode(FoodCatalogFile.self, from: data)
        return FoodCatalog(source: file.source, sourceURL: file.sourceURL.flatMap(URL.init(string:)), foods: file.foods)
    }
}
