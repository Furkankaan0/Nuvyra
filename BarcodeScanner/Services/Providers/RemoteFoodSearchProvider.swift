import Foundation

protocol RemoteFoodSearchProvider: Sendable {
    var sourceName: String { get }

    func searchFoods(query: String, limit: Int) async throws -> [FoodSearchResult]

    /// Zenginleştirilmiş arama. Default uygulama `searchFoods` çıktısını
    /// minimal `FoodItem`'a çevirir; sağlayıcılar override ederek allergens /
    /// micros / nutri-score / nova group gibi alanları taşır.
    func searchItems(query: String, limit: Int) async throws -> [FoodItem]
}

extension RemoteFoodSearchProvider {
    func searchItems(query: String, limit: Int) async throws -> [FoodItem] {
        let results = try await searchFoods(query: query, limit: limit)
        return results.map(FoodItem.from(searchResult:))
    }
}
