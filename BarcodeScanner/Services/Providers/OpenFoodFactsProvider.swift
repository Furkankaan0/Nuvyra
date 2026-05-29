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
            public let code: String?
            public let productName: String?
            public let productNameTr: String?
            public let productNameEn: String?
            public let genericName: String?
            public let brands: String?
            public let imageUrl: String?
            public let imageFrontUrl: String?
            public let nutriments: Nutriments?

            // Phase 2: composition & classification. Property names line up
            // with OFF's snake_case JSON via JSONDecoder.convertFromSnakeCase,
            // so synthesized Codable works for everything here.
            public let ingredientsTextTr: String?
            public let ingredientsTextEn: String?
            public let ingredientsText: String?
            public let allergens: String?
            public let allergensTags: [String]?
            public let additivesTags: [String]?
            public let nutriscoreGrade: String?
            public let novaGroup: Int?
            public let categoriesTags: [String]?
            public let labelsTags: [String]?

            // Phase 13.5 — gerçek porsiyon büyüklüğü. OFF API'sinde
            // `serving_size` text "30 g" gibi, `serving_quantity` Double
            // gram cinsinden (bazen string olarak gelir).
            public let servingSize: String?
            public let servingQuantity: Double?
        }

        public struct Nutriments: Codable, Sendable {
            public let energyKcal100G: Double?
            public let energyKcalValue: Double?
            public let energyKJ100G: Double?
            public let proteins100G: Double?
            public let fat100G: Double?
            public let saturatedFat100G: Double?
            public let carbohydrates100G: Double?
            public let sugars100G: Double?
            public let fiber100G: Double?
            public let sodium100G: Double?
            public let salt100G: Double?
            public let cholesterol100G: Double?

            // Minerals (OFF stores per-100g in grams → multiply by 1000 → mg)
            public let calcium100G: Double?
            public let iron100G: Double?
            public let magnesium100G: Double?
            public let phosphorus100G: Double?
            public let potassium100G: Double?
            public let zinc100G: Double?

            // Vitamins (OFF stores per-100g in grams → convert at the mapper boundary)
            public let vitaminA100G: Double?
            public let vitaminC100G: Double?
            public let vitaminD100G: Double?
            public let vitaminE100G: Double?
            public let vitaminK100G: Double?
            public let vitaminB1100G: Double?
            public let vitaminB2100G: Double?
            public let vitaminPP100G: Double?
            public let vitaminB6100G: Double?
            public let vitaminB9100G: Double?
            public let vitaminB12100G: Double?

            // Bug fix: HTTPClient `convertFromSnakeCase` ile decode ediyor;
            // bu strategy JSON anahtarlarındaki underscore'ları kaldırıp
            // sonraki kelimeyi capitalize ediyor. Dolayısıyla raw value'lar
            // ORİJİNAL JSON anahtarları değil, **dönüştürülmüş** formları
            // olmalı (örn. "proteins_100g" → "proteins100g"). Hyphen'lar
            // korunur. Aksi halde tüm makro alanlar 0 olarak decode olur.
            enum CodingKeys: String, CodingKey {
                case energyKcal100G = "energy-kcal100g"
                case energyKcalValue = "energy-kcalValue"
                case energyKJ100G = "energy100g"
                case proteins100G = "proteins100g"
                case fat100G = "fat100g"
                case saturatedFat100G = "saturated-fat100g"
                case carbohydrates100G = "carbohydrates100g"
                case sugars100G = "sugars100g"
                case fiber100G = "fiber100g"
                case sodium100G = "sodium100g"
                case salt100G = "salt100g"
                case cholesterol100G = "cholesterol100g"
                case calcium100G = "calcium100g"
                case iron100G = "iron100g"
                case magnesium100G = "magnesium100g"
                case phosphorus100G = "phosphorus100g"
                case potassium100G = "potassium100g"
                case zinc100G = "zinc100g"
                case vitaminA100G = "vitamin-a100g"
                case vitaminC100G = "vitamin-c100g"
                case vitaminD100G = "vitamin-d100g"
                case vitaminE100G = "vitamin-e100g"
                case vitaminK100G = "vitamin-k100g"
                case vitaminB1100G = "vitamin-b1100g"
                case vitaminB2100G = "vitamin-b2100g"
                case vitaminPP100G = "vitamin-pp100g"
                case vitaminB6100G = "vitamin-b6100g"
                case vitaminB9100G = "vitamin-b9100g"
                case vitaminB12100G = "vitamin-b12100g"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                energyKcal100G = try container.decodeFlexibleDouble(forKey: .energyKcal100G)
                energyKcalValue = try container.decodeFlexibleDouble(forKey: .energyKcalValue)
                energyKJ100G = try container.decodeFlexibleDouble(forKey: .energyKJ100G)
                proteins100G = try container.decodeFlexibleDouble(forKey: .proteins100G)
                fat100G = try container.decodeFlexibleDouble(forKey: .fat100G)
                saturatedFat100G = try container.decodeFlexibleDouble(forKey: .saturatedFat100G)
                carbohydrates100G = try container.decodeFlexibleDouble(forKey: .carbohydrates100G)
                sugars100G = try container.decodeFlexibleDouble(forKey: .sugars100G)
                fiber100G = try container.decodeFlexibleDouble(forKey: .fiber100G)
                sodium100G = try container.decodeFlexibleDouble(forKey: .sodium100G)
                salt100G = try container.decodeFlexibleDouble(forKey: .salt100G)
                cholesterol100G = try container.decodeFlexibleDouble(forKey: .cholesterol100G)
                calcium100G = try container.decodeFlexibleDouble(forKey: .calcium100G)
                iron100G = try container.decodeFlexibleDouble(forKey: .iron100G)
                magnesium100G = try container.decodeFlexibleDouble(forKey: .magnesium100G)
                phosphorus100G = try container.decodeFlexibleDouble(forKey: .phosphorus100G)
                potassium100G = try container.decodeFlexibleDouble(forKey: .potassium100G)
                zinc100G = try container.decodeFlexibleDouble(forKey: .zinc100G)
                vitaminA100G = try container.decodeFlexibleDouble(forKey: .vitaminA100G)
                vitaminC100G = try container.decodeFlexibleDouble(forKey: .vitaminC100G)
                vitaminD100G = try container.decodeFlexibleDouble(forKey: .vitaminD100G)
                vitaminE100G = try container.decodeFlexibleDouble(forKey: .vitaminE100G)
                vitaminK100G = try container.decodeFlexibleDouble(forKey: .vitaminK100G)
                vitaminB1100G = try container.decodeFlexibleDouble(forKey: .vitaminB1100G)
                vitaminB2100G = try container.decodeFlexibleDouble(forKey: .vitaminB2100G)
                vitaminPP100G = try container.decodeFlexibleDouble(forKey: .vitaminPP100G)
                vitaminB6100G = try container.decodeFlexibleDouble(forKey: .vitaminB6100G)
                vitaminB9100G = try container.decodeFlexibleDouble(forKey: .vitaminB9100G)
                vitaminB12100G = try container.decodeFlexibleDouble(forKey: .vitaminB12100G)
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(energyKcal100G, forKey: .energyKcal100G)
                try container.encodeIfPresent(energyKcalValue, forKey: .energyKcalValue)
                try container.encodeIfPresent(energyKJ100G, forKey: .energyKJ100G)
                try container.encodeIfPresent(proteins100G, forKey: .proteins100G)
                try container.encodeIfPresent(fat100G, forKey: .fat100G)
                try container.encodeIfPresent(saturatedFat100G, forKey: .saturatedFat100G)
                try container.encodeIfPresent(carbohydrates100G, forKey: .carbohydrates100G)
                try container.encodeIfPresent(sugars100G, forKey: .sugars100G)
                try container.encodeIfPresent(fiber100G, forKey: .fiber100G)
                try container.encodeIfPresent(sodium100G, forKey: .sodium100G)
                try container.encodeIfPresent(salt100G, forKey: .salt100G)
                try container.encodeIfPresent(cholesterol100G, forKey: .cholesterol100G)
                try container.encodeIfPresent(calcium100G, forKey: .calcium100G)
                try container.encodeIfPresent(iron100G, forKey: .iron100G)
                try container.encodeIfPresent(magnesium100G, forKey: .magnesium100G)
                try container.encodeIfPresent(phosphorus100G, forKey: .phosphorus100G)
                try container.encodeIfPresent(potassium100G, forKey: .potassium100G)
                try container.encodeIfPresent(zinc100G, forKey: .zinc100G)
                try container.encodeIfPresent(vitaminA100G, forKey: .vitaminA100G)
                try container.encodeIfPresent(vitaminC100G, forKey: .vitaminC100G)
                try container.encodeIfPresent(vitaminD100G, forKey: .vitaminD100G)
                try container.encodeIfPresent(vitaminE100G, forKey: .vitaminE100G)
                try container.encodeIfPresent(vitaminK100G, forKey: .vitaminK100G)
                try container.encodeIfPresent(vitaminB1100G, forKey: .vitaminB1100G)
                try container.encodeIfPresent(vitaminB2100G, forKey: .vitaminB2100G)
                try container.encodeIfPresent(vitaminPP100G, forKey: .vitaminPP100G)
                try container.encodeIfPresent(vitaminB6100G, forKey: .vitaminB6100G)
                try container.encodeIfPresent(vitaminB9100G, forKey: .vitaminB9100G)
                try container.encodeIfPresent(vitaminB12100G, forKey: .vitaminB12100G)
            }
        }
    }

    public struct SearchResponse: Codable, Sendable {
        public let products: [Response.Product]?
        public let count: Int?
        public let page: Int?
        public let pageSize: Int?
    }

    // MARK: - Properties

    public let sourceName = "OpenFoodFacts"
    private let client: HTTPClient
    private let baseURL: URL

    /// Fields query for both barcode and search endpoints. Kept central so the
    /// two call sites stay in sync as we extend coverage.
    static let requestedFields: String = [
        "status",
        "code",
        "product_name", "product_name_tr", "product_name_en",
        "generic_name",
        "brands",
        "image_url", "image_front_url",
        "nutriments",
        "ingredients_text", "ingredients_text_tr", "ingredients_text_en",
        "allergens", "allergens_tags",
        "additives_tags",
        "nutriscore_grade",
        "nova_group",
        "categories_tags",
        "labels_tags",
        "serving_size",
        "serving_quantity"
    ].joined(separator: ",")

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

        // OFF DB'de barkod kayıtlı ama hem isim hem besin değeri eksikse,
        // "Bilinmeyen Ürün + 0 makro" göstermek yerine notFound'a düş ki
        // chain'deki diğer provider'lar (FatSecret, USDA) denensin, sonunda
        // ManualProductEntryView açılsın. Brand yeterli signal — onunla
        // devam edebiliriz.
        let hasName = (product.productName?.nonEmpty
            ?? product.productNameTr?.nonEmpty
            ?? product.productNameEn?.nonEmpty
            ?? product.genericName?.nonEmpty) != nil
        let hasBrand = product.brands?.nonEmpty != nil
        let n = product.nutriments
        let hasAnyNutrition = (n?.energyKcal100G ?? n?.energyKcalValue ?? n?.energyKJ100G ?? 0) > 0
            || (n?.proteins100G ?? 0) > 0
            || (n?.carbohydrates100G ?? 0) > 0
            || (n?.fat100G ?? 0) > 0
        if !hasName && !hasBrand && !hasAnyNutrition {
            return nil
        }

        if let result = makeFoodSearchResult(from: product, fallbackBarcode: barcode) {
            let nutriments = product.nutriments
            let kcal = nutriments?.energyKcal100G
                ?? nutriments?.energyKcalValue
                ?? nutriments?.energyKJ100G.map { $0 / 4.184 }
                ?? Double(result.calories)

            // Sodium fallback: OFF salt_100g (g) varsa × 400 → mg
            let sodiumMg: Double? = {
                if let s = nutriments?.sodium100G { return s * 1000 }
                if let salt = nutriments?.salt100G { return salt * 400 }
                return nil
            }()
            // Servingsize fallback: OFF bazen serving_quantity'yi string yollar
            // ve Double? decode'u nil bırakır → serving_size text'inden gram
            // çıkar (örn. "30 g" → 30, "1 piece (30g)" → 30).
            let servingGrams = product.servingQuantity ?? Self.parseGrams(from: product.servingSize)
            return ScannedProduct(
                barcode: barcode,
                name: result.name,
                brand: result.brand,
                caloriesPer100g: kcal,
                protein: result.protein,
                fat: result.fat,
                carbs: result.carbs,
                fiber: result.fiber,
                sodium: sodiumMg,
                sugar: nutriments?.sugars100G,
                saturatedFat: nutriments?.saturatedFat100G,
                servingGrams: servingGrams,
                servingLabel: product.servingSize?.nonEmpty,
                imageURL: result.imageURL,
                source: .openFoodFacts
            )
        }

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

        let sodiumMgFallback: Double? = {
            if let s = nutriments?.sodium100G { return s * 1000 }
            if let salt = nutriments?.salt100G { return salt * 400 }
            return nil
        }()
        let servingGramsFallback = product.servingQuantity ?? Self.parseGrams(from: product.servingSize)
        return ScannedProduct(
            barcode: barcode,
            name: name,
            brand: product.brands?.firstBrand,
            caloriesPer100g: kcal,
            protein: nutriments?.proteins100G ?? 0,
            fat: nutriments?.fat100G ?? 0,
            carbs: nutriments?.carbohydrates100G ?? 0,
            fiber: nutriments?.fiber100G,
            sodium: sodiumMgFallback,
            sugar: nutriments?.sugars100G,
            saturatedFat: nutriments?.saturatedFat100G,
            servingGrams: servingGramsFallback,
            servingLabel: product.servingSize?.nonEmpty,
            imageURL: [product.imageFrontUrl, product.imageUrl]
                .compactMap { $0?.nonEmpty }
                .compactMap(URL.init(string:))
                .first,
            source: .openFoodFacts
        )
    }

    /// "30 g", "30g", "1 piece (30g)", "30 ml" gibi serbest metinden ilk
    /// numerik değeri çekip Double olarak döner. OFF `serving_quantity`'i
    /// bazen string yolladığı (Double? decode'u nil bırakır) için fallback.
    static func parseGrams(from text: String?) -> Double? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        // Virgülü noktaya çevir (Avrupa locale'i için).
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        // Scanner ile ilk floatı yakala.
        let scanner = Scanner(string: normalized)
        scanner.charactersToBeSkipped = .whitespacesAndNewlines
        var value: Double = 0
        if scanner.scanDouble(&value), value > 0 {
            return value
        }
        return nil
    }

    func makeFoodSearchResult(from product: Response.Product, fallbackBarcode: String? = nil) -> FoodSearchResult? {
        let name = product.productNameTr?.nonEmpty
            ?? product.productName?.nonEmpty
            ?? product.productNameEn?.nonEmpty
            ?? product.genericName?.nonEmpty
            ?? "Bilinmeyen urun"

        let nutriments = product.nutriments
        let kcal = nutriments?.energyKcal100G
            ?? nutriments?.energyKcalValue
            ?? nutriments?.energyKJ100G.map { $0 / 4.184 }
            ?? 0
        let externalID = product.code?.nonEmpty ?? fallbackBarcode ?? name

        return FoodSearchResult(
            id: FoodSearchResult.remoteID(source: .openFoodFacts, externalID: externalID),
            name: name,
            brand: product.brands?.firstBrand,
            calories: Int(kcal.rounded()),
            servingDescription: "100 g",
            score: 0,
            protein: nutriments?.proteins100G ?? 0,
            carbs: nutriments?.carbohydrates100G ?? 0,
            fat: nutriments?.fat100G ?? 0,
            fiber: nutriments?.fiber100G,
            imageURL: [product.imageFrontUrl, product.imageUrl]
                .compactMap { $0?.nonEmpty }
                .compactMap(URL.init(string:))
                .first,
            source: .openFoodFacts,
            externalID: externalID,
            isVerified: true
        )
    }

    private func request(for barcode: String) -> HTTPRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v2/product/\(barcode).json"
        components.queryItems = [
            URLQueryItem(name: "lc", value: "tr"),
            URLQueryItem(name: "fields", value: Self.requestedFields)
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

    // MARK: - Rich FoodItem path

    /// Barkoddan tam zengin `FoodItem` döner — allergens, micros, nutri-score
    /// dahil. `fetch(barcode:)` çağrısı `ScannedProduct` formatını koruduğu
    /// için bu varyant Phase 3 repository'sinden ayrı bir yol olarak gider.
    func fetchItem(barcode: String) async throws -> FoodItem {
        var lastError: Error?

        for candidate in barcodeCandidates(from: barcode) {
            do {
                let response = try await client.send(request(for: candidate), as: Response.self)
                guard response.status != 0, let product = response.product else {
                    throw HTTPClientError.notFound
                }
                // Boş/sparse → notFound döndür ki chain'deki diğer provider'lar denensin.
                let hasName = (product.productName?.nonEmpty
                    ?? product.productNameTr?.nonEmpty
                    ?? product.productNameEn?.nonEmpty
                    ?? product.genericName?.nonEmpty) != nil
                let hasBrand = product.brands?.nonEmpty != nil
                let n = product.nutriments
                let hasNutri = (n?.energyKcal100G ?? n?.energyKcalValue ?? n?.energyKJ100G ?? 0) > 0
                    || (n?.proteins100G ?? 0) > 0
                    || (n?.carbohydrates100G ?? 0) > 0
                    || (n?.fat100G ?? 0) > 0
                guard hasName || hasBrand || hasNutri else {
                    throw HTTPClientError.notFound
                }
                return makeFoodItem(from: product, fallbackBarcode: barcode)
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
}

extension OpenFoodFactsProvider: FoodItemNutritionProvider {}

extension OpenFoodFactsProvider: RemoteFoodSearchProvider {
    func searchFoods(query: String, limit: Int) async throws -> [FoodSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmedQuery),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "lc", value: "tr"),
            URLQueryItem(name: "page_size", value: "\(max(1, min(limit, 50)))"),
            URLQueryItem(name: "fields", value: Self.requestedFields)
        ]

        guard let url = components.url else { throw HTTPClientError.invalidURL }
        let response = try await client.send(
            HTTPRequest(
                url: url,
                headers: ["User-Agent": "Nuvyra-iOS/1.0 (contact@nuvyra.app)"]
            ),
            as: SearchResponse.self
        )

        return (response.products ?? [])
            .compactMap { makeFoodSearchResult(from: $0) }
            .prefix(limit)
            .map { $0 }
    }

    func searchItems(query: String, limit: Int) async throws -> [FoodItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/cgi/search.pl"
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmedQuery),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "lc", value: "tr"),
            URLQueryItem(name: "page_size", value: "\(max(1, min(limit, 50)))"),
            URLQueryItem(name: "fields", value: Self.requestedFields)
        ]

        guard let url = components.url else { throw HTTPClientError.invalidURL }
        let response = try await client.send(
            HTTPRequest(
                url: url,
                headers: ["User-Agent": "Nuvyra-iOS/1.0 (contact@nuvyra.app)"]
            ),
            as: SearchResponse.self
        )

        return (response.products ?? [])
            .map { makeFoodItem(from: $0, fallbackBarcode: nil) }
            .prefix(limit)
            .map { $0 }
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

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let raw = try? decodeIfPresent(String.self, forKey: key) {
            return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
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

// MARK: - Rich mapping helpers

extension OpenFoodFactsProvider {

    /// Open Food Facts response → zengin `FoodItem`. Aşağıdaki dönüşümler
    /// kayba uğramadan taşınır:
    /// - tüm makro besinler (kcal, P, F, C, fiber, sugar, saturated fat, sodium)
    /// - sodium yoksa salt (g) × 400 → mg yedek
    /// - tam mineral paneli (Ca, Fe, Mg, P, K, Zn) → mg
    /// - vitamin paneli (A, C, D, E, K, B-kompleks, B12) — OFF birimine göre
    /// - allergens_tags → `[Allergen]`
    /// - additives_tags → `[String]` (E-kodlar)
    /// - nutriscore_grade → `NutriScore`
    /// - nova_group → `NovaGroup`
    /// - ingredients_text_tr > _en > generic → `ingredients`
    /// - categories_tags → `FoodCategory`
    func makeFoodItem(from product: Response.Product, fallbackBarcode: String?) -> FoodItem {
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

        let sodiumMg: Double = {
            if let s = nutriments?.sodium100G { return s * 1000 }
            if let salt = nutriments?.salt100G { return salt * 400 }
            return 0
        }()

        let nutrition = NutritionValues(
            calories: Int(kcal.rounded()),
            protein: nutriments?.proteins100G ?? 0,
            carbs: nutriments?.carbohydrates100G ?? 0,
            fat: nutriments?.fat100G ?? 0,
            fiber: nutriments?.fiber100G ?? 0,
            sodium: sodiumMg,
            sugar: nutriments?.sugars100G ?? 0,
            saturatedFat: nutriments?.saturatedFat100G ?? 0
        )

        let micros = makeMicronutrients(from: nutriments)
        let allergens = makeAllergens(product: product)
        let additives = makeAdditives(tags: product.additivesTags)
        let nutriScore = NutriScore(rawTag: product.nutriscoreGrade)
        let novaGroup = NovaGroup(value: product.novaGroup)
        let category = makeCategory(tags: product.categoriesTags)
        let ingredients = product.ingredientsTextTr?.nonEmpty
            ?? product.ingredientsTextEn?.nonEmpty
            ?? product.ingredientsText?.nonEmpty

        let imageURL = [product.imageFrontUrl, product.imageUrl]
            .compactMap { $0?.nonEmpty }
            .compactMap(URL.init(string:))
            .first

        let externalID = product.code?.nonEmpty ?? fallbackBarcode ?? name
        let barcode = product.code?.nonEmpty ?? fallbackBarcode

        let confidence: Double = {
            var score = 0.65
            if nutriments?.proteins100G != nil { score += 0.05 }
            if nutriScore != nil { score += 0.05 }
            if novaGroup != nil { score += 0.05 }
            if ingredients != nil { score += 0.05 }
            if !allergens.isEmpty { score += 0.05 }
            return min(0.95, score)
        }()

        // Phase 13.5 — OFF'un kendi `serving_size`/`serving_quantity` field'ları
        // varsa onu kullan; serving_quantity yoksa serving_size text'inden
        // gram parse et; o da yoksa generic 1 porsiyon (200 g) fallback.
        let servings: [ServingSize] = {
            let resolvedGrams = product.servingQuantity ?? Self.parseGrams(from: product.servingSize)
            if let grams = resolvedGrams, grams > 0 {
                let label = product.servingSize?.nonEmpty ?? "1 porsiyon"
                return [
                    .hundredGrams,
                    ServingSize(label: label, labelTR: label, grams: grams, isDefault: true)
                ]
            }
            return [.hundredGrams, .onePortion]
        }()

        return FoodItem(
            source: .openFoodFacts,
            externalID: externalID,
            name: name,
            localizedNameTR: product.productNameTr?.nonEmpty ?? name,
            brand: product.brands?.firstBrand,
            barcode: barcode,
            imageURL: imageURL,
            category: category,
            servingSizes: servings,
            nutritionPer100g: nutrition,
            micronutrients: micros?.hasAnyValue == true ? micros : nil,
            ingredients: ingredients,
            allergens: allergens,
            additives: additives,
            nutriScore: nutriScore,
            novaGroup: novaGroup,
            verifiedLevel: .verified,
            confidenceScore: confidence
        )
    }

    private func makeMicronutrients(from n: Response.Nutriments?) -> Micronutrients? {
        guard let n else { return nil }
        // OFF nutriments per-100g are stored in grams. Minerals → mg (×1000),
        // μg-vitamins (A, D, K, folate, B12) → μg (×1_000_000), mg-vitamins → mg (×1000).
        func mg(_ g: Double?) -> Double? { g.map { $0 * 1000 } }
        func ug(_ g: Double?) -> Double? { g.map { $0 * 1_000_000 } }

        return Micronutrients(
            calciumMg: mg(n.calcium100G),
            ironMg: mg(n.iron100G),
            magnesiumMg: mg(n.magnesium100G),
            phosphorusMg: mg(n.phosphorus100G),
            potassiumMg: mg(n.potassium100G),
            zincMg: mg(n.zinc100G),
            vitaminAUg: ug(n.vitaminA100G),
            vitaminCMg: mg(n.vitaminC100G),
            vitaminDUg: ug(n.vitaminD100G),
            vitaminEMg: mg(n.vitaminE100G),
            vitaminKUg: ug(n.vitaminK100G),
            vitaminB1Mg: mg(n.vitaminB1100G),
            vitaminB2Mg: mg(n.vitaminB2100G),
            vitaminB3Mg: mg(n.vitaminPP100G),
            vitaminB6Mg: mg(n.vitaminB6100G),
            folateUg: ug(n.vitaminB9100G),
            vitaminB12Ug: ug(n.vitaminB12100G),
            cholesterolMg: mg(n.cholesterol100G)
        )
    }

    private func makeAllergens(product: Response.Product) -> [Allergen] {
        if let tags = product.allergensTags, !tags.isEmpty {
            return Allergen.parse(offTags: tags.joined(separator: ","))
        }
        return Allergen.parse(offTags: product.allergens)
    }

    private func makeAdditives(tags: [String]?) -> [String] {
        guard let tags else { return [] }
        return tags.compactMap { tag -> String? in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stripped = trimmed.hasPrefix("en:") ? String(trimmed.dropFirst(3)) : trimmed
            guard !stripped.isEmpty else { return nil }
            return stripped.uppercased()
        }
    }

    /// Conservative mapper: only the well-known top-level OFF categories.
    /// Unmapped tags drop to `nil` rather than guessing.
    private func makeCategory(tags: [String]?) -> FoodCategory? {
        guard let tags else { return nil }
        // OFF returns categories from broad to specific; scan reverse for the
        // most specific match first.
        for raw in tags.reversed() {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let stripped = trimmed.hasPrefix("en:") ? String(trimmed.dropFirst(3)) : trimmed
            if let match = Self.categoryMap[stripped] { return match }
        }
        return nil
    }

    private static let categoryMap: [String: FoodCategory] = [
        "dairies": .dairy, "milks": .dairy, "yogurts": .dairy, "cheeses": .dairy, "butters": .dairy,
        "beverages": .beverage, "waters": .beverage, "sodas": .beverage, "juices": .beverage,
        "fruit-juices": .beverage, "teas": .beverage, "coffees": .beverage, "plant-based-beverages": .beverage,
        "alcoholic-beverages": .alcohol, "beers": .alcohol, "wines": .alcohol,
        "snacks": .snack, "salty-snacks": .snack, "appetizers": .snack, "chips-and-fries": .snack,
        "sweets": .sweet, "chocolates": .sweet, "candies": .sweet, "desserts": .sweet,
        "biscuits-and-cakes": .sweet, "ice-creams-and-sorbets": .sweet,
        "fruits": .fruit, "fresh-fruits": .fruit, "dried-fruits": .fruit,
        "vegetables": .vegetable, "fresh-vegetables": .vegetable,
        "meats": .meat, "meat-products": .meat,
        "poultries": .poultry, "chickens": .poultry,
        "fishes": .fish, "seafoods": .fish, "fish-and-seafood": .fish,
        "eggs": .egg,
        "nuts": .nutSeed, "nuts-and-their-products": .nutSeed, "seeds": .nutSeed,
        "fats": .oilFat, "vegetable-fats": .oilFat, "oils": .oilFat,
        "sauces": .sauceCondiment, "condiments": .sauceCondiment, "dressings": .sauceCondiment,
        "spices": .spiceHerb, "herbs": .spiceHerb,
        "breads": .bakedGood, "bakery": .bakedGood, "pastries": .bakedGood,
        "legumes": .legume, "legumes-and-their-products": .legume,
        "cereals-and-potatoes": .grain, "cereals": .grain, "breakfast-cereals": .grain,
        "rices": .grain, "pastas": .grain,
        "fast-foods": .fastFood, "sandwiches": .fastFood, "pizzas": .fastFood, "burgers": .fastFood,
        "ready-meals": .prepared, "prepared-meals": .prepared, "frozen-foods": .prepared,
        "baby-foods": .babyFood,
        "dietary-supplements": .supplement, "food-supplements": .supplement,
        "protein-bars": .protein, "high-protein-foods": .protein
    ]
}
