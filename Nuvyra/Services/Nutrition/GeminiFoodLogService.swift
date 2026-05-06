import Foundation

struct FoodLog: Codable, Equatable, Identifiable {
    var id: String { "\(name)-\(quantity)-\(calories)" }
    let name: String
    let quantity: String
    let calories: Int
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
            EstimatedMealResult(
                name: food.name,
                calories: food.calories,
                protein: 0,
                carbs: 0,
                fat: 0,
                portion: food.quantity,
                confidence: 0.76,
                source: .cloudProvider,
                isEstimated: true
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
        Türkçe doğal dilde anlatılan öğünü besin kayıtlarına çevir.
        Yalnızca JSON Schema'ya uyan JSON döndür.
        Kalori değerleri tahmini kcal integer olmalı.
        Tıbbi tavsiye verme, açıklama metni yazma.

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
                description: "Doğal dilden çıkarılan besin kayıtları.",
                items: GeminiJSONSchema(
                    type: "object",
                    properties: [
                        "name": GeminiJSONSchema(type: "string", description: "Besinin kısa adı."),
                        "quantity": GeminiJSONSchema(type: "string", description: "Porsiyon veya miktar bilgisi."),
                        "calories": GeminiJSONSchema(type: "integer", description: "Tahmini kcal değeri.")
                    ],
                    required: ["name", "quantity", "calories"],
                    propertyOrdering: ["name", "quantity", "calories"]
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
