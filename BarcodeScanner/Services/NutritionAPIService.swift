//
//  NutritionAPIService.swift
//  Nuvyra - Barcode Scanner
//
//  Üç sağlayıcı (Open Food Facts → FatSecret → USDA) arasında sıralı
//  fallback yapan thread-safe orkestratör. Cache (memory + SQLite) ile
//  birlikte çalışır.
//

import Foundation

/// Hangi sağlayıcının denendiğini ve sonucunu raporlayan log entry.
public struct ProviderAttempt: Sendable {
    public let source: ProductSource
    public let succeeded: Bool
    public let error: String?
    public let durationMs: Int
}

/// Servis seviyesinde toplu hata.
public enum NutritionAPIError: LocalizedError, Sendable {
    case notFoundInAnyProvider([ProviderAttempt])
    case offlineAndNotCached

    public var errorDescription: String? {
        switch self {
        case .notFoundInAnyProvider:
            return "Ürün hiçbir kaynakta bulunamadı."
        case .offlineAndNotCached:
            return "İnternet yok ve bu barkod önbellekte mevcut değil."
        }
    }
}

/// Sıralı fallback besin verisi servisi.
public actor NutritionAPIService {

    // MARK: - Properties

    private let providers: [any NutritionProvider]
    private let memoryCache: MemoryProductCache
    private let diskCache: ProductCacheService?

    /// Son taramada hangi sağlayıcı(lar) denendi (UI/log için).
    public private(set) var lastAttempts: [ProviderAttempt] = []

    // MARK: - Init

    /// - Parameters:
    ///   - providers: Sıralı fallback zinciri (öndeki önce denenir).
    ///   - memoryCache: NSCache tabanlı bellek cache (24 saatlik TTL).
    ///   - diskCache: Opsiyonel SQLite kalıcı cache.
    public init(
        providers: [any NutritionProvider],
        memoryCache: MemoryProductCache = MemoryProductCache(),
        diskCache: ProductCacheService? = nil
    ) {
        self.providers = providers
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }

    // MARK: - Public API

    /// Verilen barkod için ürünü:
    /// 1) Memory cache'ten,
    /// 2) Sıralı sağlayıcılardan,
    /// 3) (offline veya hepsi başarısızsa) SQLite cache'ten döndürür.
    public func fetchProduct(barcode: String) async throws -> ScannedProduct {
        lastAttempts.removeAll()

        // 1) Memory cache (hızlı yol)
        if let cached = memoryCache.product(for: barcode) {
            return cached
        }

        // 2) Provider chain
        var attempts: [ProviderAttempt] = []
        for provider in providers {
            let start = Date()
            do {
                let product = try await provider.fetch(barcode: barcode)
                let dur = Int(Date().timeIntervalSince(start) * 1000)
                attempts.append(ProviderAttempt(
                    source: product.source,
                    succeeded: true,
                    error: nil,
                    durationMs: dur
                ))
                memoryCache.store(product)
                if let diskCache {
                    try? await diskCache.upsert(product)
                }
                lastAttempts = attempts
                return product
            } catch {
                let dur = Int(Date().timeIntervalSince(start) * 1000)
                attempts.append(ProviderAttempt(
                    source: providerSource(provider),
                    succeeded: false,
                    error: error.localizedDescription,
                    durationMs: dur
                ))
                // Network seviyesinde offline/timeout: zinciri kır, cache fallback'e geç
                if case HTTPClientError.offline = error { break }
                continue
            }
        }
        lastAttempts = attempts

        // 3) Disk cache (offline son çare)
        if let diskCache, let cached = try? await diskCache.get(barcode: barcode) {
            memoryCache.store(cached)
            return cached
        }

        if attempts.allSatisfy({ $0.error?.contains("Bağlantı") == true
                              || $0.error?.contains("internet") == true }) {
            throw NutritionAPIError.offlineAndNotCached
        }
        throw NutritionAPIError.notFoundInAnyProvider(attempts)
    }

    /// Manuel olarak girilmiş bir ürünü kalıcı cache'e ekler.
    public func saveManual(_ product: ScannedProduct) async {
        memoryCache.store(product)
        if let diskCache {
            try? await diskCache.upsert(product)
        }
    }

    // MARK: - Helpers

    /// Provider tipinden ProductSource'a haritalama (loglama için).
    private nonisolated func providerSource(_ p: any NutritionProvider) -> ProductSource {
        switch p.sourceName {
        case "OpenFoodFacts": return .openFoodFacts
        case "FatSecret":     return .fatSecret
        case "USDA":          return .usda
        default:              return .cache
        }
    }
}
