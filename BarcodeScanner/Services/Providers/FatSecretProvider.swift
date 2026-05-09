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

        public init(clientID: String, clientSecret: String, scope: String = "barcode") {
            self.clientID = clientID
            self.clientSecret = clientSecret
            self.scope = scope
        }
    }

    // MARK: - DTOs

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
            let serving: [Serving]?
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

    // MARK: - State

    public let sourceName = "FatSecret"
    private let client: HTTPClient
    private let credentials: Credentials
    private let tokenURL: URL
    private let apiURL: URL

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
        apiURL: URL = URL(string: "https://platform.fatsecret.com/rest/server.api")!
    ) {
        self.client = client
        self.credentials = credentials
        self.tokenURL = tokenURL
        self.apiURL = apiURL
    }

    // MARK: - Public API

    /// Barkodu önce FatSecret food_id'ye, sonra detaylı besin verisine çevirir.
    public func fetch(barcode: String) async throws -> ScannedProduct {
        let token = try await ensureToken()

        // 1) Barcode → food_id
        let foodID = try await lookupFoodID(barcode: barcode, token: token)

        // 2) food_id → detay
        let food = try await fetchFood(foodID: foodID, token: token)
        guard let f = food.food, let serving = f.servings?.serving?.first else {
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
        let body = "grant_type=client_credentials&scope=\(credentials.scope)"
            .data(using: .utf8)

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

    // MARK: - REST helpers

    /// food.find_id_for_barcode çağrısı.
    private func lookupFoodID(barcode: String, token: String) async throws -> String {
        let url = apiURL.appendingQueryItems([
            URLQueryItem(name: "method", value: "food.find_id_for_barcode"),
            URLQueryItem(name: "barcode", value: barcode),
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
            URLQueryItem(name: "format", value: "json")
        ])

        let request = HTTPRequest(
            url: url,
            headers: ["Authorization": "Bearer \(token)"]
        )

        return try await client.send(request, as: FoodResponse.self)
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
