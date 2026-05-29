import Foundation

struct FoodLog: Codable, Equatable, Identifiable {
    var id: String { "\(name)-\(quantity)-\(calories)" }
    let name: String
    let quantity: String
    let calories: Int

    // Phase 12.5 — per-100g makro + ikincil makrolar + gerçek porsiyon gram'ı.
    // Geriye uyumluluk için tümü default nil; eski response'lar da decode olur,
    // mevcut testler `FoodLog(name:quantity:calories:)` ile çalışmaya devam eder.
    let portionGrams: Double?
    let protein100g: Double?
    let carbs100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sodium100gMg: Double?
    let sugar100g: Double?
    let saturatedFat100g: Double?

    init(
        name: String,
        quantity: String,
        calories: Int,
        portionGrams: Double? = nil,
        protein100g: Double? = nil,
        carbs100g: Double? = nil,
        fat100g: Double? = nil,
        fiber100g: Double? = nil,
        sodium100gMg: Double? = nil,
        sugar100g: Double? = nil,
        saturatedFat100g: Double? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.calories = calories
        self.portionGrams = portionGrams
        self.protein100g = protein100g
        self.carbs100g = carbs100g
        self.fat100g = fat100g
        self.fiber100g = fiber100g
        self.sodium100gMg = sodium100gMg
        self.sugar100g = sugar100g
        self.saturatedFat100g = saturatedFat100g
    }
}

struct GeminiFoodLogResponse: Codable, Equatable {
    let foodLog: [FoodLog]

    enum CodingKeys: String, CodingKey {
        case foodLog = "FoodLog"
    }
}

protocol GeminiHTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: GeminiHTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

enum GeminiFoodLogServiceError: LocalizedError, Equatable {
    case emptyInput
    case missingAPIKey
    case invalidEndpoint
    case invalidHTTPStatus(Int, String)
    case emptyModelResponse

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Besin kaydı oluşturmak için önce bir açıklama yazmalısın."
        case .missingAPIKey:
            return "Gemini API anahtarı yapılandırılmamış."
        case .invalidEndpoint:
            return "Gemini API adresi hazırlanamadı."
        case .invalidHTTPStatus(let statusCode, let body):
            return "Gemini API isteği başarısız oldu. HTTP \(statusCode): \(body)"
        case .emptyModelResponse:
            return "Gemini geçerli bir besin kaydı döndürmedi."
        }
    }
}

final class GeminiFoodLogService: FoodIntelligenceService {
    private let apiKey: String
    private let model: String
    private let baseURL: URL
    private let session: GeminiHTTPSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        apiKey: String,
        model: String = "gemini-2.5-flash",
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        session: GeminiHTTPSession = URLSession.shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    func logFood(from naturalLanguageInput: String) async throws -> [FoodLog] {
        let request = try makeGenerateContentRequest(for: naturalLanguageInput)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiFoodLogServiceError.emptyModelResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Yanıt okunamadı."
            throw GeminiFoodLogServiceError.invalidHTTPStatus(httpResponse.statusCode, body)
        }

        let geminiResponse = try decoder.decode(GeminiGenerateContentResponse.self, from: data)
        guard let jsonText = geminiResponse.firstText, !jsonText.isEmpty else {
            throw GeminiFoodLogServiceError.emptyModelResponse
        }

        let foodLogResponse = try decoder.decode(GeminiFoodLogResponse.self, from: Data(jsonText.utf8))
        return foodLogResponse.foodLog
    }

    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult] {
        let logs = try await logFood(from: input)
        return logs.map { food in
            // Gemini'nin verdiği `calories` PORSİYON BAŞINA değer; ama
            // EstimatedMealResult per-100g taşır. `portionGrams` yoksa 200g
            // varsayılan kullan ve `protein100g` vs zaten per-100g geliyor.
            let portionGrams = max(1, food.portionGrams ?? 200)
            let portionFactor = portionGrams / 100
            let calories100g = portionFactor > 0
                ? Int((Double(food.calories) / portionFactor).rounded())
                : food.calories
            return EstimatedMealResult(
                name: food.name,
                portion: food.quantity,
                portionGrams: portionGrams,
                calories: calories100g,
                protein: food.protein100g ?? 0,
                carbs: food.carbs100g ?? 0,
                fat: food.fat100g ?? 0,
                fiber: food.fiber100g,
                sodium: food.sodium100gMg,
                sugar: food.sugar100g,
                saturatedFat: food.saturatedFat100g,
                confidence: 0.78,
                source: .cloudProvider
            )
        }
    }

    func makeGenerateContentRequest(for naturalLanguageInput: String) throws -> URLRequest {
        let trimmedInput = naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            throw GeminiFoodLogServiceError.emptyInput
        }

        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw GeminiFoodLogServiceError.missingAPIKey
        }

        let url = baseURL
            .appendingPathComponent("models")
            .appendingPathComponent("\(model):generateContent")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try encoder.encode(GeminiGenerateContentRequest(
            contents: [
                .init(parts: [
                    .init(text: Self.prompt(for: trimmedInput))
                ])
            ],
            generationConfig: .foodLogJSON
        ))
        return request
    }

    private static func prompt(for input: String) -> String {
        """
        Türk mutfağı ve beslenme uzmanı gibi davran. Kullanıcı bir yemek,
        içecek veya ürün ismini Türkçe yazacak; sen onu standart bir veya
        birkaç (en fazla 4) farklı yorumla besin kayıtlarına çevir.

        Kurallar:
        • Yanıtın sadece JSON Schema'ya uyan JSON olsun; açıklama, başlık,
          markdown veya tıbbi tavsiye yazma.
        • Yemek adını (`name`) Türkçe ve sade tut (örn. "Mercimek çorbası",
          "Tavuk şiş", "Yulaf ezmesi (sütlü)"). Marka adı verme.
        • Birden fazla yaygın yorum varsa hepsini ayrı kayıt olarak ekle
          (örn. "yulaf" → sade yulaf ezmesi, sütlü yulaf, granola). Sıralama:
          en yaygın yorum ilk.
        • `quantity` kültürel porsiyon ifadesi olsun: "1 kase", "1 dilim",
          "1 tabak", "1 porsiyon", "1 bardak", "1 adet" vb.
        • `portionGrams` bu porsiyonun **ortalama gerçek gram karşılığı**.
          Örn: 1 kase çorba ≈ 240g, 1 lahmacun ≈ 140g, 1 dilim ekmek ≈ 30g,
          1 yumurta ≈ 50g, 1 bardak ayran ≈ 240g, 1 tabak pilav ≈ 180g.
        • `calories` o porsiyondaki toplam kcal (integer).
        • Diğer tüm besin değerleri (`*_100g`) **100 gram başına** ve gram
          (sodium hariç → mg) cinsinden. Sodium içermiyorsa 0, hesaplanamıyorsa
          null bırak.
        • Türkiye'de yaygın olmayan / uydurma yemekleri tahmin etme;
          en yakın tanıdığın yemek üzerinden açıkla.

        Kullanıcı girdisi:
        \(input)
        """
    }
}

private struct GeminiGenerateContentRequest: Encodable {
    let contents: [Content]
    let generationConfig: GenerationConfig

    struct Content: Encodable {
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let responseMimeType: String
        let responseJsonSchema: GeminiJSONSchema

        static let foodLogJSON = GenerationConfig(
            temperature: 0.1,
            responseMimeType: "application/json",
            responseJsonSchema: .foodLogSchema
        )
    }
}

private final class GeminiJSONSchema: Encodable {
    let type: String
    let description: String?
    let properties: [String: GeminiJSONSchema]?
    let items: GeminiJSONSchema?
    let required: [String]?
    let propertyOrdering: [String]?

    init(
        type: String,
        description: String? = nil,
        properties: [String: GeminiJSONSchema]? = nil,
        items: GeminiJSONSchema? = nil,
        required: [String]? = nil,
        propertyOrdering: [String]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
        self.items = items
        self.required = required
        self.propertyOrdering = propertyOrdering
    }

    static let foodLogSchema = GeminiJSONSchema(
        type: "object",
        properties: [
            "FoodLog": GeminiJSONSchema(
                type: "array",
                description: "Doğal dilden çıkarılan besin kayıtları. Her giriş, kullanıcının yazdığı yemeğin yaygın bir yorumudur (max 4).",
                items: GeminiJSONSchema(
                    type: "object",
                    properties: [
                        "name": GeminiJSONSchema(type: "string", description: "Besinin Türkçe kısa adı (örn. 'Mercimek çorbası')."),
                        "quantity": GeminiJSONSchema(type: "string", description: "Kültürel porsiyon ifadesi (örn. '1 kase', '1 dilim', '1 tabak')."),
                        "calories": GeminiJSONSchema(type: "integer", description: "Bu porsiyondaki toplam kcal (integer)."),
                        "portionGrams": GeminiJSONSchema(type: "number", description: "Porsiyonun ortalama gerçek gram karşılığı (örn. 1 kase çorba ≈ 240, 1 dilim ekmek ≈ 30)."),
                        "protein100g": GeminiJSONSchema(type: "number", description: "100 g başına protein (gram). Bilinmiyorsa 0."),
                        "carbs100g": GeminiJSONSchema(type: "number", description: "100 g başına karbonhidrat (gram)."),
                        "fat100g": GeminiJSONSchema(type: "number", description: "100 g başına yağ (gram)."),
                        "fiber100g": GeminiJSONSchema(type: "number", description: "100 g başına lif (gram). Yoksa 0."),
                        "sodium100gMg": GeminiJSONSchema(type: "number", description: "100 g başına sodyum (miligram). Tuz içermiyorsa 0."),
                        "sugar100g": GeminiJSONSchema(type: "number", description: "100 g başına şeker (gram). Tatlandırılmamışsa 0."),
                        "saturatedFat100g": GeminiJSONSchema(type: "number", description: "100 g başına doymuş yağ (gram).")
                    ],
                    required: ["name", "quantity", "calories", "portionGrams", "protein100g", "carbs100g", "fat100g"],
                    propertyOrdering: [
                        "name",
                        "quantity",
                        "portionGrams",
                        "calories",
                        "protein100g",
                        "carbs100g",
                        "fat100g",
                        "fiber100g",
                        "sodium100gMg",
                        "sugar100g",
                        "saturatedFat100g"
                    ]
                )
            )
        ],
        required: ["FoodLog"],
        propertyOrdering: ["FoodLog"]
    )
}

private struct GeminiGenerateContentResponse: Decodable {
    let candidates: [Candidate]

    var firstText: String? {
        candidates.first?.content.parts.compactMap(\.text).first
    }

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String?
    }
}
