//
//  ProductSource.swift
//  Nuvyra - Barcode Scanner
//
//  Bir ScannedProduct'ın hangi kaynaktan geldiğini belirten enum.
//

import Foundation

/// Ürün verisinin geldiği kaynak.
public enum ProductSource: String, Codable, Sendable, CaseIterable, Hashable {
    case openFoodFacts
    case fatSecret
    case usda
    case cache
    case manual
    case estimated

    /// UI'da gösterilecek başlık.
    public var displayLabel: String {
        switch self {
        case .openFoodFacts: return "Open Food Facts"
        case .fatSecret:     return "FatSecret"
        case .usda:          return "USDA FoodData"
        case .cache:         return "Önbellek"
        case .manual:        return "Manuel"
        case .estimated:     return "Nuvyra tahmini"
        }
    }
}
