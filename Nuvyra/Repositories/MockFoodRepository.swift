import Foundation

/// In-memory `FoodRepository` for previews + unit tests. Tüm state actor
/// içinde tutulur → çağrılar arası leakage yok, paralel test isolation
/// garanti. Production'da kullanılmaz; `DependencyContainer.mock()` ve
/// `.preview()` enjekte eder, `.live()` hâlâ `DefaultFoodRepository`'yi
/// kullanır (gerçek SQLite + remote).
actor MockFoodRepository: FoodRepository {

    // MARK: - State

    private var itemsByRowID: [Int64: FoodItem] = [:]
    /// Manuel item'lar — deterministicRowID yok, UUID anahtarıyla saklanır.
    private var manualItems: [UUID: FoodItem] = [:]
    private var favorites: Set<Int64> = []
    private var useCounts: [Int64: Int] = [:]
    private var lastUsed: [Int64: Date] = [:]

    // MARK: - Init

    /// İsteğe bağlı seed — testler "öncesinde 3 favori vardı" senaryolarını
    /// kolayca kurabilsin diye. Production fixture'ları (örn. canlı önizleme)
    /// `previewSeed` üzerinden gelir.
    init(seed: [FoodItem] = []) {
        for item in seed {
            if let rowID = item.deterministicRowID {
                itemsByRowID[rowID] = item
            } else {
                manualItems[item.id] = item
            }
        }
    }

    /// SwiftUI preview / dev fixture'larında gösterilebilecek minimum bir
    /// veri. Local TR seed'lerine paralel ama bağımsız (testler bundle JSON'a
    /// dokunmadan çalışabilsin).
    static let previewSeed: [FoodItem] = [
        FoodItem(
            source: .estimated,
            externalID: "local:mercimek-corbasi",
            name: "Lentil Soup",
            localizedNameTR: "Mercimek çorbası",
            category: .localTurkish,
            servingSizes: [.hundredGrams, ServingSize(label: "1 bowl", labelTR: "1 kase", grams: 240, isDefault: true)],
            nutritionPer100g: NutritionValues(calories: 80, protein: 4.6, carbs: 13, fat: 2.5, fiber: 2.1, sodium: 380),
            verifiedLevel: .approximate,
            confidenceScore: 0.6
        ),
        FoodItem(
            source: .openFoodFacts,
            externalID: "8690000000000",
            name: "Whole Wheat Biscuit",
            localizedNameTR: "Tam Tahıllı Bisküvi",
            brand: "Nuvyra",
            barcode: "8690000000000",
            category: .bakedGood,
            servingSizes: [.hundredGrams, ServingSize(label: "1 piece", labelTR: "1 adet", grams: 25, isDefault: true)],
            nutritionPer100g: NutritionValues(calories: 421, protein: 8.2, carbs: 63.5, fat: 14.1, fiber: 5.7),
            allergens: [.gluten, .dairy],
            nutriScore: .c,
            novaGroup: .processed,
            verifiedLevel: .verified,
            confidenceScore: 0.85
        )
    ]

    // MARK: - FoodRepository

    func searchItems(query: String, limit: Int) async -> [FoodItem] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else { return [] }
        let pool = allItems()
        let matches = pool.filter { item in
            item.preferredDisplayName.lowercased().contains(normalized)
                || item.name.lowercased().contains(normalized)
                || (item.brand?.lowercased().contains(normalized) ?? false)
        }
        // Favoriler önce, sonra use_count desc, sonra rankingScore.
        let sorted = matches.sorted { lhs, rhs in
            let lFav = lhs.deterministicRowID.map { favorites.contains($0) } ?? false
            let rFav = rhs.deterministicRowID.map { favorites.contains($0) } ?? false
            if lFav != rFav { return lFav && !rFav }
            let lUse = lhs.deterministicRowID.flatMap { useCounts[$0] } ?? 0
            let rUse = rhs.deterministicRowID.flatMap { useCounts[$0] } ?? 0
            if lUse != rUse { return lUse > rUse }
            return lhs.rankingScore > rhs.rankingScore
        }
        return Array(sorted.prefix(limit))
    }

    func fetchItem(barcode: String) async -> FoodItem? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return allItems().first { $0.barcode == trimmed }
    }

    @discardableResult
    func addUserItem(_ item: FoodItem) async throws -> FoodItem {
        ingest(item)
        return item
    }

    func cacheItem(_ item: FoodItem) async {
        ingest(item)
    }

    func recordUse(id: Int64) async {
        useCounts[id, default: 0] += 1
        lastUsed[id] = Date()
    }

    func setFavorite(id: Int64, _ isFavorite: Bool) async {
        if isFavorite { favorites.insert(id) } else { favorites.remove(id) }
    }

    func isFavorite(id: Int64) async -> Bool {
        favorites.contains(id)
    }

    func recentItems(limit: Int) async -> [FoodItem] {
        let dated = itemsByRowID.compactMap { (id, item) -> (FoodItem, Date)? in
            guard let date = lastUsed[id] else { return nil }
            return (item, date)
        }
        return dated.sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    func favoriteItems(limit: Int) async -> [FoodItem] {
        let favList = favorites.compactMap { itemsByRowID[$0] }
        // use_count desc + lastUsed desc (mirror SQLite favoriteItemsSQL).
        let sorted = favList.sorted { lhs, rhs in
            let lUse = lhs.deterministicRowID.flatMap { useCounts[$0] } ?? 0
            let rUse = rhs.deterministicRowID.flatMap { useCounts[$0] } ?? 0
            if lUse != rUse { return lUse > rUse }
            let lDate = lhs.deterministicRowID.flatMap { lastUsed[$0] } ?? .distantPast
            let rDate = rhs.deterministicRowID.flatMap { lastUsed[$0] } ?? .distantPast
            return lDate > rDate
        }
        return Array(sorted.prefix(limit))
    }

    // MARK: - Helpers

    private func ingest(_ item: FoodItem) {
        if let rowID = item.deterministicRowID {
            itemsByRowID[rowID] = item
        } else {
            manualItems[item.id] = item
        }
    }

    private func allItems() -> [FoodItem] {
        Array(itemsByRowID.values) + Array(manualItems.values)
    }
}
