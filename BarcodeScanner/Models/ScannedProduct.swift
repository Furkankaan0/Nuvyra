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
    /// Phase 13.5 — OFF zaten döndürüyor; FoodDetailView secondary grid
    /// (lif/şeker/doymuş yağ/sodyum) dolu görünsün diye plumbed.
    public let sodium: Double?
    public let sugar: Double?
    public let saturatedFat: Double?

    // MARK: - Serving (Phase 13.5)

    /// OFF'tan gelen `serving_quantity` (gram cinsinden), örn. 30 g. Yoksa nil.
    public let servingGrams: Double?
    /// OFF'tan gelen `serving_size` text (örn. "30 g", "1 piece"). Yoksa nil.
    public let servingLabel: String?

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
        sodium: Double? = nil,
        sugar: Double? = nil,
        saturatedFat: Double? = nil,
        servingGrams: Double? = nil,
        servingLabel: String? = nil,
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
        self.sodium = sodium
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.servingGrams = servingGrams
        self.servingLabel = servingLabel
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
