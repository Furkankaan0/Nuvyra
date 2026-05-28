import Foundation

final class RemoteFoodSearchService: @unchecked Sendable {
    private let providers: [any RemoteFoodSearchProvider]
    private let queue = DispatchQueue(label: "com.nuvyra.food-search.remote-cache", qos: .userInitiated)
    private var cache: [String: [FoodSearchResult]] = [:]
    private var itemCache: [String: [FoodItem]] = [:]

    init(providers: [any RemoteFoodSearchProvider] = FoodDataProviderFactory.remoteSearchProviders()) {
        self.providers = providers
    }

    func search(_ rawQuery: String, limit: Int = 24) async -> [FoodSearchResult] {
        let query = FoodSearchNormalizer.normalized(rawQuery)
        guard query.count >= 2 else { return [] }

        let cacheKey = "\(query)|\(limit)"
        if let cached = cachedResults(for: cacheKey) {
            return cached
        }

        var combined: [FoodSearchResult] = []
        for provider in providers {
            do {
                let results = try await provider.searchFoods(query: rawQuery, limit: limit)
                combined.append(contentsOf: results)
            } catch {
                continue
            }
        }

        let merged = mergeDeduplicating(combined).prefix(limit).map { $0 }
        store(merged, for: cacheKey)
        return merged
    }

    /// Phase 3 entry point — runs the providers' rich `searchItems` so
    /// allergens / micros / nutri-score / nova-group survive into the caller.
    /// Individual provider failures are swallowed; callers always get the
    /// union of whatever did succeed.
    func searchItems(_ rawQuery: String, limit: Int = 24) async -> [FoodItem] {
        let query = FoodSearchNormalizer.normalized(rawQuery)
        guard query.count >= 2 else { return [] }

        let cacheKey = "\(query)|\(limit)"
        if let cached = cachedItems(for: cacheKey) {
            return cached
        }

        var combined: [FoodItem] = []
        for provider in providers {
            do {
                let results = try await provider.searchItems(query: rawQuery, limit: limit)
                combined.append(contentsOf: results)
            } catch {
                continue
            }
        }

        let merged = mergeDeduplicatingItems(combined).prefix(limit).map { $0 }
        storeItems(merged, for: cacheKey)
        return merged
    }

    private func cachedResults(for key: String) -> [FoodSearchResult]? {
        queue.sync { cache[key] }
    }

    private func store(_ results: [FoodSearchResult], for key: String) {
        queue.async { [results] in
            self.cache[key] = results
            if self.cache.count > 80 {
                self.cache.removeAll(keepingCapacity: true)
                self.cache[key] = results
            }
        }
    }

    private func cachedItems(for key: String) -> [FoodItem]? {
        queue.sync { itemCache[key] }
    }

    private func storeItems(_ items: [FoodItem], for key: String) {
        queue.async { [items] in
            self.itemCache[key] = items
            if self.itemCache.count > 80 {
                self.itemCache.removeAll(keepingCapacity: true)
                self.itemCache[key] = items
            }
        }
    }

    private func mergeDeduplicating(_ results: [FoodSearchResult]) -> [FoodSearchResult] {
        var seen = Set<String>()
        var merged: [FoodSearchResult] = []

        for result in results {
            let key = result.externalID?.lowercased()
                ?? "\(result.source.rawValue):\(FoodSearchNormalizer.normalized(result.name)):\(result.brand ?? "")"
            guard seen.insert(key).inserted else { continue }
            merged.append(result)
        }

        return merged
    }

    /// Deduplicate by (lowercase externalID) first — same product across
    /// providers wins; otherwise fall back to (source, normalized name, brand).
    /// Among duplicates the higher `rankingScore` wins.
    private func mergeDeduplicatingItems(_ items: [FoodItem]) -> [FoodItem] {
        var bestByKey: [String: FoodItem] = [:]
        var order: [String] = []

        for item in items {
            let key = item.externalID?.lowercased()
                ?? "\(item.source.rawValue):\(FoodSearchNormalizer.normalized(item.preferredDisplayName)):\(item.brand ?? "")"

            if let existing = bestByKey[key] {
                if item.rankingScore > existing.rankingScore {
                    bestByKey[key] = item
                }
            } else {
                bestByKey[key] = item
                order.append(key)
            }
        }

        return order.compactMap { bestByKey[$0] }
            .sorted { $0.rankingScore > $1.rankingScore }
    }
}
