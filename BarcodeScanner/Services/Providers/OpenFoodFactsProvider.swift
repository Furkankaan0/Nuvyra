//
//  OpenFoodFactsProvider.swift
//  Nuvyra - Barcode Scanner
//
//  Open Food Facts API entegrasyonu.
//  Current stable product API: https://world.openfoodfacts.org/api/v2/product/{barcode}.json
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
            public let productNameEn: String?
            public let genericName: String?
            public let brands: String?
            public let imageUrl: String?
            public let imageFrontUrl: String?
            public let nutriments: Nutriments?
        }

        public struct Nutriments: Codable, Sendable {
            public let energyKcal100G: Double?
            public let energyKcalValue: Double?
            public let energyKJ100G: Double?
            public let proteins100G: Double?
            public let fat100G: Double?
            public let carbohydrates100G: Double?
            public let fiber100G: Double?

            enum CodingKeys: String, CodingKey {
                case energyKcal100G = "energy-kcal_100g"
                case energyKcalValue = "energy-kcal_value"
                case energyKJ100G = "energy_100g"
                case proteins100G = "proteins_100g"
                case fat100G = "fat_100g"
                case carbohydrates100G = "carbohydrates_100g"
                case fiber100G = "fiber_100g"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                energyKcal100G = try container.decodeFlexibleDouble(forKey: .energyKcal100G)
                energyKcalValue = try container.decodeFlexibleDouble(forKey: .energyKcalValue)
                energyKJ100G = try container.decodeFlexibleDouble(forKey: .energyKJ100G)
                proteins100G = try container.decodeFlexibleDouble(forKey: .proteins100G)
                fat100G = try container.decodeFlexibleDouble(forKey: .fat100G)
                carbohydrates100G = try container.decodeFlexibleDouble(forKey: .carbohydrates100G)
                fiber100G = try container.decodeFlexibleDouble(forKey: .fiber100G)
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(energyKcal100G, forKey: .energyKcal100G)
                try container.encodeIfPresent(energyKcalValue, forKey: .energyKcalValue)
                try container.encodeIfPresent(energyKJ100G, forKey: .energyKJ100G)
                try container.encodeIfPresent(proteins100G, forKey: .proteins100G)
                try container.encodeIfPresent(fat100G, forKey: .fat100G)
                try container.encodeIfPresent(carbohydrates100G, forKey: .carbohydrates100G)
                try container.encodeIfPresent(fiber100G, forKey: .fiber100G)
            }
        }
    }

    // MARK: - Properties

    public let sourceName = "OpenFoodFacts"
    private let client: HTTPClient
    private let baseURL: URL

    // MARK: - Init

    public init(
        client: HTTPClient,
        baseURL: URL = URL(string: "https://world.openfoodfacts.org")!
    ) {
        self.client = client
        self.baseURL = baseURL
    }

    // MARK: - Public API

    /// Barkoddan ürünü getirir. UPC-A barkodlar bazı kameralar tarafından
    /// EAN-13 gibi başında `0` ile dönebildiği için iki varyantı da dener.
    public func fetch(barcode: String) async throws -> ScannedProduct {
        var lastError: Error?

        for candidate in barcodeCandidates(from: barcode) {
            do {
                let response = try await client.send(request(for: candidate), as: Response.self)
                guard let product = makeProduct(from: response, requestedBarcode: barcode) else {
                    throw HTTPClientError.notFound
                }
                return product
            } catch {
                lastError = error
                if let httpError = error as? HTTPClientError, case .notFound = httpError {
                    continue
                }
                throw error
            }
        }

        throw lastError ?? HTTPClientError.notFound
    }

    // MARK: - Mapping

    func makeProduct(from response: Response, requestedBarcode barcode: String) -> ScannedProduct? {
        guard response.status != 0, let product = response.product else { return nil }

        let name = product.productNameTr?.nonEmpty
            ?? product.productName?.nonEmpty
            ?? product.productNameEn?.nonEmpty
            ?? product.genericName?.nonEmpty
            ?? "Bilinmeyen Ürün"

        let nutriments = product.nutriments
        let kcal = nutriments?.energyKcal100G
            ?? nutriments?.energyKcalValue
            ?? nutriments?.energyKJ100G.map { $0 / 4.184 }
            ?? 0

        return ScannedProduct(
            barcode: barcode,
            name: name,
            brand: product.brands?.firstBrand,
            caloriesPer100g: kcal,
            protein: nutriments?.proteins100G ?? 0,
            fat: nutriments?.fat100G ?? 0,
            carbs: nutriments?.carbohydrates100G ?? 0,
            fiber: nutriments?.fiber100G,
            imageURL: [product.imageFrontUrl, product.imageUrl]
                .compactMap { $0?.nonEmpty }
                .compactMap(URL.init(string:))
                .first,
            source: .openFoodFacts
        )
    }

    private func request(for barcode: String) -> HTTPRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v2/product/\(barcode).json"
        components.queryItems = [
            URLQueryItem(name: "lc", value: "tr"),
            URLQueryItem(name: "fields", value: [
                "status",
                "product_name",
                "product_name_tr",
                "product_name_en",
                "generic_name",
                "brands",
                "image_url",
                "image_front_url",
                "nutriments"
            ].joined(separator: ","))
        ]

        return HTTPRequest(
            url: components.url ?? baseURL.appendingPathComponent("api/v2/product/\(barcode).json"),
            headers: ["User-Agent": "Nuvyra-iOS/1.0 (contact@nuvyra.app)"]
        )
    }

    private func barcodeCandidates(from barcode: String) -> [String] {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 13, trimmed.hasPrefix("0") else { return [trimmed] }
        return [trimmed, String(trimmed.dropFirst())]
    }
}

// MARK: - Helpers

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let raw = try? decodeIfPresent(String.self, forKey: key) {
            let normalized = raw.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var firstBrand: String? {
        split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}
