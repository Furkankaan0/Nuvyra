//
//  MemoryProductCache.swift
//  Nuvyra - Barcode Scanner
//
//  Bellek içi (NSCache tabanlı) 24 saatlik TTL'li ürün cache'i.
//  URLCache ham yanıtları tutarken bu sınıf decode edilmiş ScannedProduct'ları
//  saklar — böylece tekrarlı taramalarda decode maliyeti de elenir.
//

import Foundation

/// Decode edilmiş ScannedProduct cache'i (NSCache).
public final class MemoryProductCache: @unchecked Sendable {

    // MARK: - Storage

    private final class Entry {
        let product: ScannedProduct
        let storedAt: Date
        init(product: ScannedProduct, storedAt: Date) {
            self.product = product
            self.storedAt = storedAt
        }
    }

    private let cache = NSCache<NSString, Entry>()
    private let ttl: TimeInterval

    // MARK: - Init

    /// 24 saatlik TTL ile yeni cache oluşturur.
    /// - Parameter ttlSeconds: Time-to-live saniye cinsinden (default 86400).
    public init(ttlSeconds: TimeInterval = 24 * 60 * 60, countLimit: Int = 512) {
        self.ttl = ttlSeconds
        self.cache.countLimit = countLimit
    }

    // MARK: - Public API

    /// Verilen barkod için cache'lenmiş ürünü döner. TTL dolduysa nil.
    public func product(for barcode: String) -> ScannedProduct? {
        guard let entry = cache.object(forKey: barcode as NSString) else { return nil }
        if Date().timeIntervalSince(entry.storedAt) > ttl {
            cache.removeObject(forKey: barcode as NSString)
            return nil
        }
        return entry.product
    }

    /// Bir ürünü cache'e koyar.
    public func store(_ product: ScannedProduct) {
        let entry = Entry(product: product, storedAt: .now)
        cache.setObject(entry, forKey: product.barcode as NSString)
    }

    /// Tüm cache'i temizler.
    public func clear() {
        cache.removeAllObjects()
    }
}
