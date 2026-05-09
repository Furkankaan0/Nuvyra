//
//  ScannedProduct.swift
//  Nuvyra - Barcode Scanner
//
//  Tüm besin sağlayıcılarından gelen yanıtların normalize edildiği
//  domain model. 100 g referans alınır.
//

import Foundation

/// Tek bir taranan ürünün normalize gösterimi.
public struct ScannedProduct: Codable, Equatable, Hashable, Sendable, Identifiable {

    // MARK: - Identity

    public var id: String { barcode }

    /// Ürün barkodu (EAN/UPC/QR).
    public let barcode: String
    /// Ürün adı (örn. "Tam Buğday Ekmeği").
    public let name: String
    /// Marka (örn. "Eti", "Ülker"). Yoksa nil.
    public let brand: String?

    // MARK: - Nutriments (100 g üzerinden)

    public let caloriesPer100g: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let fiber: Double?

    // MARK: - Meta

    public let imageURL: URL?
    public let source: ProductSource
    public let fetchedAt: Date

    // MARK: - Init

    /// Tüm alanları açıkça alan tam constructor.
    public init(
        barcode: String,
        name: String,
        brand: String? = nil,
        caloriesPer100g: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        fiber: Double? = nil,
        imageURL: URL? = nil,
        source: ProductSource,
        fetchedAt: Date = .now
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.fiber = fiber
        self.imageURL = imageURL
        self.source = source
        self.fetchedAt = fetchedAt
    }

    // MARK: - Display Helpers

    /// "245 kcal | P 8g · F 4g · C 42g" şeklinde özet.
    public var compactSummary: String {
        let kcal = Int(caloriesPer100g.rounded())
        let p = String(format: "%.1f", protein)
        let f = String(format: "%.1f", fat)
        let c = String(format: "%.1f", carbs)
        return "\(kcal) kcal · P \(p)g · F \(f)g · C \(c)g"
    }
}
