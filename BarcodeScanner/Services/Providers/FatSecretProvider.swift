//
//  FatSecretProvider.swift
//  Nuvyra - Barcode Scanner
//
//  FatSecret Platform API entegrasyonu.
//  - OAuth 2.0 client_credentials flow ile token yönetimi.
//  - food.find_id_for_barcode → food.get.v4 zinciri.
//  Token erişimi actor-isolated tutulur (thread-safe).
//

import Foundation

/// FatSecret OAuth2 + besin verisi sağlayıcısı.
public actor FatSecretProvider: NutritionProvider {

    // MARK: - Config

    /// FatSecret API kimlik bilgileri. Build-time ya da Keychain'den enjekte edilir.
    public struct Credentials: Sendable {
        public let clientID: String
        public let clientSecret: String
        public let scope: String

        public init(clientID: String, clientSecret: String, scope: String = "premier barcode localization") {
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.scope = scope
        }
    }

    // MARK: - DTOs

    private struct OneOrMany<Element: Codable & Sendable>: Codable, Sendable {
        let values: [Element]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let array = try? container.decode([Element].self) {
                values = array
            } else {
                values = [try container.decode(Element.self)]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(values)
        }
    }

    private struct TokenResponse: Codable, Sendable {
        let accessToken: String
        let expiresIn: Int
        let tokenType: String
    }

    private struct BarcodeLookupResponse: Codable, Sendable {
        let foodIdToFoodId: FoodIdContainer?

        enum CodingKeys: String, CodingKey {
            case foodIdToFoodId = "food_id"
        }

        struct FoodIdContainer: Codable, Sendable {
            let value: String?
        }
    }

    private struct FoodResponse: Codable, Sendable {
        let food: Food?

        struct Food: Codable, Sendable {
            let foodId: String?
            let foodName: String?
            let brandName: String?
            let servings: Servings?
        }

        struct Servings: Codable, Sendable {
            let serving: OneOrMany<Serving>?
        }

        struct Serving: Codable, Sendable {
            let metricServingAmount: String?
            let metricServingUnit: String?
            let calories: String?
            let protein: String?
            let fat: String?
            let carbohydrate: String?
            let fiber: String?
        }
    }

    private struct FoodsSearchResponse: Codable, Sendable {
        let foods: Foods?

        struct Foods: Codable, Sendable {
            let food: OneOrMany<FoodHit>?
        }

        struct FoodHit: Codable, Sendable {
            let foodId: String?
            let foodName: String?
            let brandName: String?
            let foodDescription: String?
        }
    }

    // MARK: - State

    public let sourceName = "FatSecret"
    private let client: HTTPClient
    private let credentials: Credentials
    private let tokenURL: URL
    private let apiURL: URL
    private let region: String
    private let language: String

    private var cachedToken: String?
    private var tokenExpiresAt: Date = .distantPast

    // MARK: - Init

    /// - Parameters:
    ///   - client:      Paylaşılan HTTPClient.
    ///   - credentials: API anahtarları.
    public init(
        client: HTTPClient,
        credentials: Credentials,
        tokenURL: URL = URL(string: "https://oauth.fatsecret.com/connect/token")!,
        apiURL: URL = URL(string: "https://platform.fatsecret.com/rest/server.api")!,
        region: String = "US",
        language: String = "en"
    ) {
        self.client = client
        self.credentials = credentials
        self.tokenURL = tokenURL
        self.apiURL = apiURL
        self.region = region
        self.language = language
    }

    // MARK: - Public API

    /// Barkodu önce FatSecret food_id'ye, sonra detaylı besin verisine çevirir.
    public func fetch(barcode: String) async throws -> ScannedProduct {
        let token = try await ensureToken()

        // 1) Barcode → food_id
        let foodID = try await lookupFoodID(barcode: barcode, token: token)

        // 2) food_id → detay
        let food = try await fetchFood(foodID: foodID, token: token)
        guard let f = food.food, let serving = f.servings?.serving?.values.first else {
            throw HTTPClientError.notFound
        }

        // FatSecret değerleri belirli bir serving (örn. 100 g) üzerinden döner.
        // Veriyi 100 g'a normalize et.
        let amount = Double(serving.metricServingAmount ?? "100") ?? 100
        let unit = (serving.metricServingUnit ?? "g").lowercased()
        let factor: Double = (unit.contains("g") && amount > 0) ? (100.0 / amount) : 1.0

        let kcal  = (Double(serving.calories ?? "0") ?? 0) * factor
        let prot  = (Double(serving.protein ?? "0") ?? 0) * factor
        let fat   = (Double(serving.fat ?? "0") ?? 0) * factor
        let carbs = (Double(serving.carbohydrate ?? "0") ?? 0) * factor
        let fiber = serving.fiber.flatMap(Double.init).map { $0 * factor }

        return ScannedProduct(
            barcode: barcode,
            name: f.foodName ?? "Bilinmeyen Ürün",
            brand: f.brandName,
            caloriesPer100g: kcal,
            protein: prot,
            fat: fat,
            carbs: carbs,
            fiber: fiber,
            imageURL: nil,
            source: .fatSecret
        )
    }

    // MARK: - OAuth2

    /// Geçerli bir access token döner; yoksa veya yakında dolacaksa yenisini alır.
    private func ensureToken() async throws -> String {
        if let token = cachedToken, Date() < tokenExpiresAt.addingTimeInterval(-30) {
            return token
        }

        var headers: [String: String] = [
            "Content-Type": "application/x-www-form-urlencoded"
        ]
        if let basic = makeBasicAuthHeader() {
            headers["Authorization"] = basic
        }
        let body = formBody([
            ("grant_type", "client_credentials"),
            ("scope", credentials.scope)
        ]).data(using: .utf8)

        let request = HTTPRequest(
            url: tokenURL,
            method: "POST",
            headers: headers,
            body: body
        )

        let response = try await client.send(request, as: TokenResponse.self)
        cachedToken = response.accessToken
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        return response.accessToken
    }

    /// HTTP Basic Authorization header'ı üretir.
    private func makeBasicAuthHeader() -> String? {
        let raw = "\(credentials.clientID):\(credentials.clientSecret)"
        guard let data = raw.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    private func formBody(_ pairs: [(String, String)]) -> String {
        pairs
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .joined(separator: "&")
    }

    // MARK: - REST helpers

    /// food.find_id_for_barcode çağrısı.
    private func lookupFoodID(barcode: String, token: String) async throws -> String {
        let url = apiURL.appendingQueryItems([
            URLQueryItem(name: "method", value: "food.find_id_for_barcode"),
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "region", value: region),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json")
        ])

        let request = HTTPRequest(
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )

        let resp = try await client.send(request, as: BarcodeLookupResponse.self)
        guard let id = resp.foodIdToFoodId?.value, id != "0", !id.isEmpty else {
            throw HTTPClientError.notFound
        }
        return id
    }

    /// food.get.v4 çağrısı.
    private func fetchFood(foodID: String, token: String) async throws -> FoodResponse {
        let url = apiURL.appendingQueryItems([
            URLQueryItem(name: "method", value: "food.get.v4"),
            URLQueryItem(name: "food_id", value: foodID),
            URLQueryItem(name: "region", value: region),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json")
        ])

        let request = HTTPRequest(
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )

        return try await client.send(request, as: FoodResponse.self)
    }

    private func searchFoodHits(query: String, token: String, limit: Int) async throws -> [FoodsSearchResponse.FoodHit] {
        let url = apiURL.appendingQueryItems([
            URLQueryItem(name: "method", value: "foods.search"),
            URLQueryItem(name: "search_expression", value: query),
            URLQueryItem(name: "max_results", value: "\(max(1, min(limit, 50)))"),
            URLQueryItem(name: "region", value: region),
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "format", value: "json")
        ])

        let request = HTTPRequest(
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )

        let response = try await client.send(request, as: FoodsSearchResponse.self)
        return response.foods?.food?.values ?? []
    }

    private func makeSearchResult(
        from food: FoodResponse.Food,
        fallbackHit: FoodsSearchResponse.FoodHit? = nil
    ) -> FoodSearchResult? {
        let serving = food.servings?.serving?.values.first
        let nutrients = serving.map(normalizedNutrients)
        let externalID = food.foodId ?? fallbackHit?.foodId ?? food.foodName ?? UUID().uuidString

        return FoodSearchResult(
            id: FoodSearchResult.remoteID(source: .fatSecret, externalID: externalID),
            name: food.foodName ?? fallbackHit?.foodName ?? "Bilinmeyen urun",
            brand: food.brandName ?? fallbackHit?.brandName,
            calories: Int((nutrients?.calories ?? 0).rounded()),
            servingDescription: "100 g",
            score: 0,
            protein: nutrients?.protein ?? 0,
            carbs: nutrients?.carbs ?? 0,
            fat: nutrients?.fat ?? 0,
            fiber: nutrients?.fiber,
            imageURL: nil,
            source: .fatSecret,
            externalID: externalID,
            isVerified: true
        )
    }

    private func makeFallbackSearchResult(from hit: FoodsSearchResponse.FoodHit) -> FoodSearchResult? {
        guard let name = hit.foodName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let nutrients = parseNutritionDescription(hit.foodDescription ?? "")
        let externalID = hit.foodId ?? name

        return FoodSearchResult(
            id: FoodSearchResult.remoteID(source: .fatSecret, externalID: externalID),
            name: name,
            brand: hit.brandName,
            calories: Int((nutrients.calories ?? 0).rounded()),
            servingDescription: "100 g",
            score: 0,
            protein: nutrients.protein ?? 0,
            carbs: nutrients.carbs ?? 0,
            fat: nutrients.fat ?? 0,
            fiber: nil,
            imageURL: nil,
            source: .fatSecret,
            externalID: externalID,
            isVerified: nutrients.calories != nil
        )
    }

    private func normalizedNutrients(from serving: FoodResponse.Serving) -> (
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double?
    ) {
        let amount = Double(serving.metricServingAmount ?? "100") ?? 100
        let unit = (serving.metricServingUnit ?? "g").lowercased()
        let factor: Double = (unit.contains("g") && amount > 0) ? (100.0 / amount) : 1.0

        let calories = (Double(serving.calories ?? "0") ?? 0) * factor
        let protein = (Double(serving.protein ?? "0") ?? 0) * factor
        let fat = (Double(serving.fat ?? "0") ?? 0) * factor
        let carbs = (Double(serving.carbohydrate ?? "0") ?? 0) * factor
        let fiber = serving.fiber.flatMap(Double.init).map { $0 * factor }

        return (calories, protein, carbs, fat, fiber)
    }

    private func parseNutritionDescription(_ description: String) -> (
        calories: Double?,
        protein: Double?,
        carbs: Double?,
        fat: Double?
    ) {
        (
            calories: firstNumber(after: "Calories:", in: description),
            protein: firstNumber(after: "Protein:", in: description),
            carbs: firstNumber(after: "Carbs:", in: description),
            fat: firstNumber(after: "Fat:", in: description)
        )
    }

    private func firstNumber(after marker: String, in value: String) -> Double? {
        guard let range = value.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let suffix = value[range.upperBound...].drop(while: { $0.isWhitespace })
        let number = String(suffix.prefix { $0.isNumber || $0 == "." || $0 == "," })
            .replacingOccurrences(of: ",", with: ".")
        return Double(number)
    }
}

extension FatSecretProvider: FoodItemNutritionProvider {}

extension FatSecretProvider: RemoteFoodSearchProvider {
    func searchFoods(query: String, limit: Int) async throws -> [FoodSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        let token = try await ensureToken()
        let hits = try await searchFoodHits(query: trimmedQuery, token: token, limit: limit)

        var results: [FoodSearchResult] = []
        for hit in hits.prefix(max(1, min(limit, 12))) {
            if
                let foodID = hit.foodId,
                let detail = try? await fetchFood(foodID: foodID, token: token),
                let food = detail.food,
                let result = makeSearchResult(from: food, fallbackHit: hit)
            {
                results.append(result)
            } else if let fallback = makeFallbackSearchResult(from: hit) {
                results.append(fallback)
            }
        }

        return results
    }
}

// MARK: - URL Helpers

private extension URL {
    /// Var olan URL'e query item ekler.
    func appendingQueryItems(_ items: [URLQueryItem]) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var existing = comps.queryItems ?? []
        existing.append(contentsOf: items)
        comps.queryItems = existing
        return comps.url ?? self
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")
            .replacingOccurrences(of: " ", with: "+")
            ?? self
    }
}
