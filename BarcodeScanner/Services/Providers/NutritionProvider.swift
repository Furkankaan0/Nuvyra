//
//  NutritionProvider.swift
//  Nuvyra - Barcode Scanner
//
//  Tüm besin verisi sağlayıcılarının ortak protokolü.
//

import Foundation

/// Bir barkod verildiğinde ScannedProduct döndüren tek-yönlü interface.
public protocol NutritionProvider: Sendable {
    /// İnsan-okur kaynak adı (loglama için).
    var sourceName: String { get }

    /// Barkoddan ürün getirir. Ürün bulunamazsa
    /// `HTTPClientError.notFound` fırlatmalıdır.
    func fetch(barcode: String) async throws -> ScannedProduct

    /// Aynı barkodu zengin domain modeli olarak getirir. Default uygulama
    /// `fetch(barcode:)` çıktısını minimal `FoodItem`'a çevirir; sağlayıcı
    /// bunu override ederek allergens / micros / nutri-score gibi alanları
    /// kayba uğramadan döner.
    func fetchItem(barcode: String) async throws -> FoodItem
}

public extension NutritionProvider {
    func fetchItem(barcode: String) async throws -> FoodItem {
        let product = try await fetch(barcode: barcode)
        return FoodItem.from(scannedProduct: product)
    }
}
