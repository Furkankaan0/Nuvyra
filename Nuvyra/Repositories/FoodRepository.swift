import Foundation

/// Tek giriş noktası: katalog araması, barkod çözümü, kullanıcı ekleme,
/// son kullanılanlar ve favoriler. Local SQLite katmanı her zaman önce
/// sorgulanır; remote sağlayıcılar (USDA / OpenFoodFacts / FatSecret) sadece
/// gerektiğinde devreye girer ve sonuçları write-through olarak SQLite'a yazar.
protocol FoodRepository: Sendable {
    /// Arama. Sıralama: yerel SQLite (favoriler + sık kullanılanlar önce) →
    /// remote sonuçlar (`rankingScore` ile). Remote hit'leri sessizce local
    /// cache'e yazılır.
    func searchItems(query: String, limit: Int) async -> [FoodItem]

    /// Barkod araması. Sırayla: kalıcı cache (SQLite) → remote provider zinciri
    /// (OpenFoodFacts → FatSecret → USDA). Bulunan rich item local'e yazılır.
    /// `nil` döner ürün hiçbir kaynakta bulunmazsa.
    func fetchItem(barcode: String) async -> FoodItem?

    /// Manuel besin ekleme — kullanıcı tarafından yaratılan FoodItem'ı
    /// local'e yazar ve geri döner.
    @discardableResult
    func addUserItem(_ item: FoodItem) async throws -> FoodItem

    /// Non-throwing write-through cache. Barcode scan ya da harici akıştan
    /// gelen `FoodItem`'ı local SQLite'a sessizce yazar; başarısız olursa
    /// caller'ı bilgilendirmez (best-effort cache).
    func cacheItem(_ item: FoodItem) async

    /// Bir item kullanıldığında recents/frequents istatistiğini günceller.
    /// `id` parametresi remote item'lar için deterministik (source+externalID
    /// hash'i), manuel item'lar için SQLite rowid'i.
    func recordUse(id: Int64) async

    /// Favorilere ekle / çıkar.
    func setFavorite(id: Int64, _ isFavorite: Bool) async

    /// Belirli bir rowID için mevcut favorite durumu — UI star ikonunun
    /// initial state'ini set etmek için. SQLite'da yoksa false döner.
    func isFavorite(id: Int64) async -> Bool

    func recentItems(limit: Int) async -> [FoodItem]
    func favoriteItems(limit: Int) async -> [FoodItem]
}

extension FoodRepository {
    func searchItems(query: String) async -> [FoodItem] {
        await searchItems(query: query, limit: 24)
    }

    func recentItems() async -> [FoodItem] { await recentItems(limit: 20) }
    func favoriteItems() async -> [FoodItem] { await favoriteItems(limit: 50) }
}

// MARK: - Default implementation

final class DefaultFoodRepository: FoodRepository, @unchecked Sendable {

    private let localStore: SQLiteFTSFoodSearchService
    private let remoteSearch: RemoteFoodSearchService
    private let barcodeProviders: [any FoodItemNutritionProvider]

    init(
        localStore: SQLiteFTSFoodSearchService = .shared,
        remoteSearch: RemoteFoodSearchService = RemoteFoodSearchService(),
        barcodeProviders: [any FoodItemNutritionProvider] = FoodDataProviderFactory.foodItemBarcodeProviders()
    ) {
        self.localStore = localStore
        self.remoteSearch = remoteSearch
        self.barcodeProviders = barcodeProviders
    }

    // MARK: Search

    func searchItems(query: String, limit: Int) async -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let localItems: [FoodItem] = (try? await localStore.searchItems(trimmed, limit: limit)) ?? []
        let remoteItems = await remoteSearch.searchItems(trimmed, limit: limit)

        // Fire-and-forget write-through: every remote hit goes into local
        // cache so the next identical search short-circuits to SQLite.
        Task { [weak self, remoteItems] in
            await self?.writeThrough(remoteItems)
        }

        return merge(local: localItems, remote: remoteItems, limit: limit)
    }

    // MARK: Barcode

    func fetchItem(barcode: String) async -> FoodItem? {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let cached = try? await localStore.findItem(barcode: trimmed) {
            return cached
        }

        for provider in barcodeProviders {
            do {
                let item = try await provider.fetchItem(barcode: trimmed)
                try? await localStore.upsertItem(item)
                return item
            } catch {
                continue
            }
        }

        return nil
    }

    // MARK: Manual entry

    @discardableResult
    func addUserItem(_ item: FoodItem) async throws -> FoodItem {
        try await localStore.upsertItem(item)
        return item
    }

    func cacheItem(_ item: FoodItem) async {
        try? await localStore.upsertItem(item)
    }

    // MARK: Usage

    func recordUse(id: Int64) async {
        try? await localStore.recordUse(rowID: id)
    }

    func setFavorite(id: Int64, _ isFavorite: Bool) async {
        try? await localStore.setFavorite(rowID: id, isFavorite)
    }

    func isFavorite(id: Int64) async -> Bool {
        (try? await localStore.isFavorite(rowID: id)) ?? false
    }

    func recentItems(limit: Int) async -> [FoodItem] {
        (try? await localStore.recentItems(limit: limit)) ?? []
    }

    func favoriteItems(limit: Int) async -> [FoodItem] {
        (try? await localStore.favoriteItems(limit: limit)) ?? []
    }

    // MARK: Helpers

    private func writeThrough(_ items: [FoodItem]) async {
        for item in items {
            try? await localStore.upsertItem(item)
        }
    }

    /// Dedupe local + remote by (source, externalID) — local always wins when
    /// the same product was already cached, then any remote-only newcomers are
    /// appended in `rankingScore` order. Up to `limit`.
    private func merge(local: [FoodItem], remote: [FoodItem], limit: Int) -> [FoodItem] {
        var seen = Set<String>()
        var merged: [FoodItem] = []

        func key(for item: FoodItem) -> String {
            if let ext = item.externalID?.lowercased() {
                return "\(item.source.rawValue):\(ext)"
            }
            return "name:\(FoodSearchNormalizer.normalized(item.preferredDisplayName)):\(item.brand ?? "")"
        }

        for item in local {
            let k = key(for: item)
            if seen.insert(k).inserted { merged.append(item) }
            if merged.count >= limit { return merged }
        }

        let sortedRemote = remote.sorted { $0.rankingScore > $1.rankingScore }
        for item in sortedRemote {
            let k = key(for: item)
            if seen.insert(k).inserted { merged.append(item) }
            if merged.count >= limit { break }
        }

        return merged
    }
}
