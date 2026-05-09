//
//  OpenFoodFactsProvider.swift
//  Nuvyra - Barcode Scanner
//
//  Open Food Facts v3 API entegrasyonu (Türkiye barkodları için birincil).
//  Endpoint: https://world.openfoodfacts.org/api/v3/product/{barcode}.json
//

import Foundation

/// Open Food Facts sağlayıcısı.
public struct OpenFoodFactsProvider: NutritionProvider {

    // MARK: - DTO

    /// API yanıtının ihtiyaç duyduğumuz kısmı.
    public struct Response: Codable, Sendable {
        public let status: Int?
        public let product: Product?

        public struct Product: Codable, Sendable {
            public let productName: String?
            public let productNameTr: String?
            public let brands: String?
            public let imageUrl: String?
            public let nutriments: Nutriments?
        }

        public struct Nutriments: Codable, Sendable {
            // OFF anahtarları snake_case → keyDecodingStrategy ile camelCase olur
            public let energyKcal100G: Double?       // energy-kcal_100g
            public let energyKcalValue: Double?      // energy_kcal_value
            public let proteins100G: Double?
            public let fat100G: Double?
            public let carbohydrates100G: Double?
            public let fiber100G: Double?

            // OFF anahtarları arasında "energy-kcal_100g" gibi tire içeren
            // alanlar var; convertFromSnakeCase tireyi parse etmediği için
            // CodingKeys ile manuel eşleştiriyoruz.
            enum CodingKeys: String, CodingKey {
                case energyKcal100G    = "energy-kcal_100g"
                case energyKcalValue   = "energy_kcal_value"
                case proteins100G      = "proteins_100g"
                case fat100G           = "fat_100g"
                case carbohydrates100G = "carbohydrates_100g"
                case fiber100G         = "fiber_100g"
            }
        }
    }

    // MARK: - Properties

    public let sourceName = "OpenFoodFacts"
    private let client: HTTPClient
    private let baseURL: URL

    // MARK: - Init

    /// - Parameter client: Paylaşılan HTTPClient.
    public init(
        client: HTTPClient,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!
    ) {
        self.client = client
        self.baseURL = baseURL
    }

    // MARK: - Public API

    /// Barkoddan ürün getirir. Bulunmazsa `HTTPClientError.notFound`.
    public func fetch(barcode: String) async throws -> ScannedProduct {
        let url = baseURL.appendingPathComponent("api/v3/product/\(barcode).json")
        let request = HTTPRequest(
            url: url,
            headers: ["User-Agent": "Nuvyra-iOS/1.0 (contact@nuvyra.app)"]
        )

        // Not: OFF, ürün yoksa 200 + status:0 döner; bunu da notFound say.
        let response = try await client.send(request, as: Response.self)
        guard let p = response.product, response.status != 0 else {
            throw HTTPClientError.notFound
        }

        let name = p.productNameTr?.nonEmpty
            ?? p.productName?.nonEmpty
            ?? "Bilinmeyen Ürün"
        let kcal = p.nutriments?.energyKcal100G
            ?? p.nutriments?.energyKcalValue
            ?? 0

        return ScannedProduct(
            barcode: barcode,
            name: name,
            brand: p.brands?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) },
            caloriesPer100g: kcal,
            protein: p.nutriments?.proteins100G ?? 0,
            fat: p.nutriments?.fat100G ?? 0,
            carbs: p.nutriments?.carbohydrates100G ?? 0,
            fiber: p.nutriments?.fiber100G,
            imageURL: p.imageUrl.flatMap(URL.init(string:)),
            source: .openFoodFacts
        )
    }
}

// MARK: - Helpers

private extension String {
    /// Boş veya sadece whitespace ise nil döner.
    var nonEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
