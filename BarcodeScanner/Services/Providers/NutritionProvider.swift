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
}
