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
            public let brandOwner: String?
            public let gtinUpc: String?
            public let ingredients: String?
            public let dataType: String?
            public let foodCategory: String?
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

extension USDAProvider: RemoteFoodSearchProvider {
    func searchFoods(query: String, limit: Int) async throws -> [FoodSearchResult] {
        let foods = try await rawSearch(query: query, limit: limit)
        return foods
            .compactMap { makeFoodSearchResult(from: $0) }
            .prefix(limit)
            .map { $0 }
    }

    func searchItems(query: String, limit: Int) async throws -> [FoodItem] {
        let foods = try await rawSearch(query: query, limit: limit)
        return foods
            .compactMap { makeFoodItem(from: $0, fallbackBarcode: nil) }
            .prefix(limit)
            .map { $0 }
    }

    private func rawSearch(query: String, limit: Int) async throws -> [SearchResponse.Food] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }
        comps.queryItems = [
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "pageSize", value: "\(max(1, min(limit, 50)))"),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = comps.url else { throw HTTPClientError.invalidURL }

        let response = try await client.send(
            HTTPRequest(url: url),
            as: SearchResponse.self
        )

        return response.foods ?? []
    }

    private func makeFoodSearchResult(from food: SearchResponse.Food) -> FoodSearchResult? {
        guard let name = food.description, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let externalID = food.fdcId.map(String.init) ?? food.gtinUpc ?? name
        let calories = nutrientValue(in: food, byIDs: [1008], orNames: ["Energy"], unit: "KCAL") ?? 0
        let protein = nutrientValue(in: food, byIDs: [1003], orNames: ["Protein"]) ?? 0
        let fat = nutrientValue(in: food, byIDs: [1004], orNames: ["Total lipid (fat)"]) ?? 0
        let carbs = nutrientValue(in: food, byIDs: [1005], orNames: ["Carbohydrate, by difference"]) ?? 0
        let fiber = nutrientValue(in: food, byIDs: [1079], orNames: ["Fiber, total dietary"])

        return FoodSearchResult(
            id: FoodSearchResult.remoteID(source: .usda, externalID: externalID),
            name: name,
            brand: food.brandName,
            calories: Int(calories.rounded()),
            servingDescription: "100 g",
            score: 0,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            source: .usda,
            externalID: externalID,
            isVerified: true
        )
    }
}

// MARK: - Rich FoodItem path

extension USDAProvider {

    func fetchItem(barcode: String) async throws -> FoodItem {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw HTTPClientError.invalidURL
        }
        comps.queryItems = [
            URLQueryItem(name: "query", value: barcode),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        guard let url = comps.url else { throw HTTPClientError.invalidURL }

        let response = try await client.send(HTTPRequest(url: url), as: SearchResponse.self)
        let foods = response.foods ?? []
        let exact = foods.first { $0.gtinUpc?.trimmingCharacters(in: .whitespaces) == barcode }
        guard let food = exact ?? foods.first, let item = makeFoodItem(from: food, fallbackBarcode: barcode) else {
            throw HTTPClientError.notFound
        }
        return item
    }

    /// Build a rich FoodItem from a USDA food row. Returns nil if the row has
    /// no usable name. Missing nutrients are left as zero on the per-100g
    /// macros and as nil on the micronutrient panel — never fabricated.
    func makeFoodItem(from food: SearchResponse.Food, fallbackBarcode: String?) -> FoodItem? {
        guard let name = food.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }

        let externalID = food.fdcId.map(String.init) ?? food.gtinUpc ?? name

        let kcal = nutrientValue(in: food, byIDs: [1008], orNames: ["Energy"], unit: "KCAL")
            ?? nutrientValue(in: food, byIDs: [1062], orNames: ["Energy"], unit: "KJ").map { $0 / 4.184 }
            ?? 0
        let protein = nutrientValue(in: food, byIDs: [1003], orNames: ["Protein"]) ?? 0
        let fat = nutrientValue(in: food, byIDs: [1004], orNames: ["Total lipid (fat)"]) ?? 0
        let carbs = nutrientValue(in: food, byIDs: [1005], orNames: ["Carbohydrate, by difference"]) ?? 0
        let fiber = nutrientValue(in: food, byIDs: [1079], orNames: ["Fiber, total dietary"]) ?? 0
        let sodium = nutrientValue(in: food, byIDs: [1093], orNames: ["Sodium"]) ?? 0
        let sugar = nutrientValue(in: food, byIDs: [2000, 1063], orNames: ["Sugars, total"]) ?? 0
        let saturatedFat = nutrientValue(in: food, byIDs: [1258], orNames: ["Fatty acids, total saturated"]) ?? 0

        let nutrition = NutritionValues(
            calories: Int(kcal.rounded()),
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            sugar: sugar,
            saturatedFat: saturatedFat
        )

        let micros = Micronutrients(
            calciumMg:       nutrientValue(in: food, byIDs: [1087], orNames: ["Calcium"]),
            ironMg:          nutrientValue(in: food, byIDs: [1089], orNames: ["Iron"]),
            magnesiumMg:     nutrientValue(in: food, byIDs: [1090], orNames: ["Magnesium"]),
            phosphorusMg:    nutrientValue(in: food, byIDs: [1091], orNames: ["Phosphorus"]),
            potassiumMg:     nutrientValue(in: food, byIDs: [1092], orNames: ["Potassium"]),
            zincMg:          nutrientValue(in: food, byIDs: [1095], orNames: ["Zinc"]),
            vitaminAUg:      nutrientValue(in: food, byIDs: [1106], orNames: ["Vitamin A, RAE"]),
            vitaminCMg:      nutrientValue(in: food, byIDs: [1162], orNames: ["Vitamin C"]),
            vitaminDUg:      nutrientValue(in: food, byIDs: [1114], orNames: ["Vitamin D"]),
            vitaminEMg:      nutrientValue(in: food, byIDs: [1109], orNames: ["Vitamin E"]),
            vitaminKUg:      nutrientValue(in: food, byIDs: [1185], orNames: ["Vitamin K"]),
            vitaminB1Mg:     nutrientValue(in: food, byIDs: [1165], orNames: ["Thiamin"]),
            vitaminB2Mg:     nutrientValue(in: food, byIDs: [1166], orNames: ["Riboflavin"]),
            vitaminB3Mg:     nutrientValue(in: food, byIDs: [1167], orNames: ["Niacin"]),
            vitaminB6Mg:     nutrientValue(in: food, byIDs: [1175], orNames: ["Vitamin B-6"]),
            folateUg:        nutrientValue(in: food, byIDs: [1177, 1187], orNames: ["Folate"]),
            vitaminB12Ug:    nutrientValue(in: food, byIDs: [1178], orNames: ["Vitamin B-12"]),
            cholesterolMg:   nutrientValue(in: food, byIDs: [1253], orNames: ["Cholesterol"])
        )

        let brand = food.brandName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? food.brandOwner?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredients = food.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines)
        let confidence = micros.hasAnyValue ? 0.85 : 0.72

        return FoodItem(
            source: .usda,
            externalID: externalID,
            name: name,
            localizedNameTR: nil,
            brand: brand?.isEmpty == true ? nil : brand,
            barcode: food.gtinUpc ?? fallbackBarcode,
            imageURL: nil,
            category: nil,
            subCategory: food.foodCategory,
            servingSizes: [.hundredGrams, .onePortion],
            nutritionPer100g: nutrition,
            micronutrients: micros.hasAnyValue ? micros : nil,
            ingredients: ingredients?.isEmpty == true ? nil : ingredients,
            verifiedLevel: .verified,
            confidenceScore: confidence
        )
    }
}
