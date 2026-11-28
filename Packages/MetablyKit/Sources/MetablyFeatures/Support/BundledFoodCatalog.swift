import Foundation
import MetablyDomain

/// The offline food catalog shipped in the app (`Resources/Foods/foods.json`).
///
/// Loaded once on first use. If the file cannot be read the catalog is empty and meal entry
/// works as before, by typing values; the error type is the only thing worth knowing.
enum BundledFoodCatalog {
    static let shared: FoodCatalog = load()

    static func load(bundle: Bundle = .module) -> FoodCatalog {
        guard let url = bundle.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? FoodCatalogFile.decode(data)
        else { return .empty }
        return catalog
    }
}
