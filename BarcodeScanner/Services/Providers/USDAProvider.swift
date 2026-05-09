//
//  USDAProvider.swift
//  Nuvyra - Barcode Scanner
//
//  USDA FoodData Central — son çare sağlayıcı.
//  USDA barkod-bazlı sorgu sunmaz; ürün adı varsa onu kullanırız,
//  aksi halde barkodu query olarak deneriz (en yakın eşleşme).
//

import Foundation

public struct USDAProvider: NutritionProvider {

    // MARK: - DTO

    public struct SearchResponse: Codable, Sendable {
        public let foods: [Food]?

        public struct Food: Codable, Sendable {
            public let fdcId: Int?
            public let description: String?
            public let brandName: String?
            public let gtinUpc: String?
            public let foodNutrients: [Nutrient]?
        }

        public struct Nutrient: Codable, Sendable {
            public let nutrientId: Int?
            public let nutrientName: String?
            public let unitName: String?
            public let value: Double?
        }
    }

    // MARK: - Properties

    public let sourceName = "USDA"
    private let client: HTTPClient
    private let apiKey: String
    private let baseURL: URL

    // MARK: - Init

    /// - Parameters:
    ///   - client: Paylaşılan HTTPClient.
    ///   - apiKey: USDA FoodData Central API key (data.gov).
    public init(
        client: HTTPClient,
        apiKey: String,
        baseURL: URL = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
    ) {
        self.client = client
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    // MARK: - Public API

    /// USDA arama uç noktasını barkod ile sorgular ve ilk eşleşmeyi
    /// ScannedProduct'a normalize eder.
    public func fetch(barcode: String) async throws -> ScannedProduct {
        try await fetch(barcode: barcode, query: barcode)
    }

    /// Manuel arama / serbest metinle.
    public func fetch(barcode: String, query: String) async throws -> ScannedProduct {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = comps.url else { throw HTTPClientError.invalidURL }

        let response = try await client.send(
            HTTPRequest(url: url),
            as: SearchResponse.self
        )

        // Önce gtinUpc tam eşleşmesini, yoksa ilk sonucu seç
        let foods = response.foods ?? []
        let exact = foods.first { $0.gtinUpc?.trimmingCharacters(in: .whitespaces) == barcode }
        let chosen = exact ?? foods.first
        guard let f = chosen else {
            throw HTTPClientError.notFound
        }

        let kcal  = nutrientValue(in: f, byIDs: [1008], orNames: ["Energy"], unit: "KCAL") ?? 0
        let prot  = nutrientValue(in: f, byIDs: [1003], orNames: ["Protein"]) ?? 0
        let fat   = nutrientValue(in: f, byIDs: [1004], orNames: ["Total lipid (fat)"]) ?? 0
        let carbs = nutrientValue(in: f, byIDs: [1005], orNames: ["Carbohydrate, by difference"]) ?? 0
        let fiber = nutrientValue(in: f, byIDs: [1079], orNames: ["Fiber, total dietary"])

        return ScannedProduct(
            barcode: barcode,
            name: f.description ?? "Bilinmeyen Ürün",
            brand: f.brandName,
            caloriesPer100g: kcal,
            protein: prot,
            fat: fat,
            carbs: carbs,
            fiber: fiber,
            imageURL: nil,
            source: .usda
        )
    }

    // MARK: - Helpers

    /// Belirli bir nutrient ID'sine ya da isim eşleşmesine göre değer çeker.
    private func nutrientValue(
        in food: SearchResponse.Food,
        byIDs ids: Set<Int>,
        orNames names: [String],
        unit: String? = nil
    ) -> Double? {
        guard let nutrients = food.foodNutrients else { return nil }
        if let match = nutrients.first(where: { n in
            if let id = n.nutrientId, ids.contains(id) {
                if let unit, n.unitName?.uppercased() != unit.uppercased() { return false }
                return true
            }
            return false
        }) {
            return match.value
        }
        if let match = nutrients.first(where: { n in
            guard let nm = n.nutrientName?.lowercased() else { return false }
            return names.contains { nm.contains($0.lowercased()) }
        }) {
            return match.value
        }
        return nil
    }
}
