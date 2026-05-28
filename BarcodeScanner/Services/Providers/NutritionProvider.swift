//
//  NutritionProvider.swift
//  Nuvyra - Barcode Scanner
//
//  Common protocol for nutrition data providers.
//

import Foundation

/// Public barcode-to-product interface used by the scanner flow.
public protocol NutritionProvider: Sendable {
    /// Human-readable source name for logging.
    var sourceName: String { get }

    /// Fetches a normalized product for a barcode. Providers should throw
    /// `HTTPClientError.notFound` when no product exists.
    func fetch(barcode: String) async throws -> ScannedProduct
}

protocol FoodItemNutritionProvider: NutritionProvider {
    /// Fetches the same barcode as a richer app-domain model. Providers can
    /// override this to preserve allergens, micronutrients, Nutri-Score, and
    /// NOVA data instead of falling back to a minimal mapped item.
    func fetchItem(barcode: String) async throws -> FoodItem
}

extension FoodItemNutritionProvider {
    func fetchItem(barcode: String) async throws -> FoodItem {
        let product = try await fetch(barcode: barcode)
        return FoodItem.from(scannedProduct: product)
    }
}
