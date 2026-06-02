import Foundation

/// Live AI coach backed by the Anthropic Messages API (`claude-sonnet-4-6`).
///
/// Surface contract:
/// - Implements `AICoachService` so swap-in at the `AICoachViewModel` layer is
///   a one-liner.
/// - Translates every Anthropic/transport error into a calm-tone
///   `AICoachError`. The view model surfaces `errorDescription` directly to
///   the user, so we never let stack traces or HTTP details leak through.
/// - Multi-turn chat history is forwarded verbatim. The system prompt and
///   per-message context block are reconstructed locally so we don't depend
///   on the server's memory.
///
/// Safety stance:
/// - The system prompt enforces the wellness-coach guardrails. A 401 from a
///   bad key is mapped to `.notImplemented` so the UI falls back gracefully
///   instead of telling the user "credentials missing".
@MainActor
final class RemoteAICoachService: AICoachService {

    // MARK: - Configuration

    struct Configuration: Sendable {
        let apiKey: String
        let endpoint: URL
        let model: String
        let maxTokens: Int
        let temperature: Double

        init(
            apiKey: String,
            endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
            model: String = "claude-sonnet-4-6",
            maxTokens: Int = 512,
            temperature: Double = 0.4
        ) {
            self.apiKey = apiKey
            self.endpoint = endpoint
            self.model = model
            self.maxTokens = maxTokens
            self.temperature = temperature
        }
    }

    // MARK: - Stored

    private let configuration: Configuration
    private let client: HTTPClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: Configuration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .useDefaultKeys
        enc.outputFormatting = []
        self.encoder = enc
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .useDefaultKeys
        self.decoder = dec
    }

    // MARK: - AICoachService

    func generateInsights(context: AICoachContext) async throws -> [AICoachInsight] {
        let request = ClaudeMessagesAPI.Request(
            model: configuration.model,
            maxTokens: configuration.maxTokens,
            temperature: configuration.temperature,
            system: ClaudeCoachPromptBuilder.systemPrompt,
            messages: [
                ClaudeMessagesAPI.Message(
                    role: .user,
                    content: ClaudeCoachPromptBuilder.insightsUserPrompt(context)
                )
            ]
        )
        let text = try await send(request)
        return InsightParser.parse(text, generatedAt: Date())
    }

    func reply(to message: String, context: AICoachContext, history: [AICoachMessage]) async throws -> AICoachMessage {
        // Convert history into Anthropic's role pairs. The latest user line
        // carries the context block so the model has fresh numbers without
        // bloating earlier turns.
        var apiMessages: [ClaudeMessagesAPI.Message] = []
        for entry in history.dropLast() {
            // `history` contains the new user message at the end (the view
            // model appends it before calling). Drop it so we can inject the
            // augmented version below.
            apiMessages.append(
                ClaudeMessagesAPI.Message(
                    role: entry.role == .coach ? .assistant : .user,
                    content: entry.text
                )
            )
        }
        apiMessages.append(
            ClaudeMessagesAPI.Message(
                role: .user,
                content: ClaudeCoachPromptBuilder.chatUserPrompt(message, context: context)
            )
        )

        let request = ClaudeMessagesAPI.Request(
            model: configuration.model,
            maxTokens: configuration.maxTokens,
            temperature: configuration.temperature,
            system: ClaudeCoachPromptBuilder.systemPrompt,
            messages: apiMessages
        )
        let text = try await send(request)
        return AICoachMessage(role: .coach, text: text)
    }

    // MARK: - Networking

    /// Shared send → decode → unwrap-text path. Errors are normalised into
    /// `AICoachError` so the call sites can use a single throw type.
    private func send(_ request: ClaudeMessagesAPI.Request) async throws -> String {
        let body: Data
        do {
            body = try encoder.encode(request)
        } catch {
            // Encoder failure means we shipped a programmer error — surface
            // as `.notImplemented` so the UI shows the calm fallback copy
            // instead of an opaque "decoding error".
            throw AICoachError.notImplemented
        }

        let httpRequest = HTTPRequest(
            url: configuration.endpoint,
            method: "POST",
            headers: [
                "x-api-key": configuration.apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json"
            ],
            body: body,
            timeout: 30
        )

        let response: ClaudeMessagesAPI.Response
        do {
            let data = try await client.sendData(httpRequest)
            response = try decoder.decode(ClaudeMessagesAPI.Response.self, from: data)
        } catch let error as HTTPClientError {
            throw Self.mapTransportError(error)
        } catch is DecodingError {
            // Shape changed under us — bubble up as a generic "service is
            // currently unavailable" message rather than the raw decoder error.
            throw AICoachError.notImplemented
        } catch {
            throw AICoachError.network
        }

        guard let text = response.concatenatedText else {
            throw AICoachError.notImplemented
        }
        return text
    }

    /// Maps `HTTPClientError` to the user-safe `AICoachError`. HTTP 4xx
    /// scenarios get split out: 401/403 → `.notImplemented` (we don't tell
    /// the user "auth missing"), 429 → `.rateLimited`, everything else
    /// transport-like → `.network`.
    static func mapTransportError(_ error: HTTPClientError) -> AICoachError {
        switch error {
        case .http(let status, _):
            switch status {
            case 401, 403: return .notImplemented
            case 429: return .rateLimited
            default: return .network
            }
        case .timeout, .offline, .transport:
            return .network
        case .invalidURL, .decoding, .notFound:
            return .notImplemented
        }
    }
}

/// Parses the strict-format response produced by `insightsUserPrompt` into
/// `AICoachInsight` rows. The parser is tolerant: missing labels yield
/// fewer cards instead of throwing.
enum InsightParser {
    /// Map between the prompt label and the typed topic.
    private static let topicMap: [String: AICoachInsight.Topic] = [
        "DAILY": .daily,
        "WEEKLY": .weekly,
        "CALORIES": .calories,
        "WATER": .water,
        "STEPS": .steps
    ]

    static func parse(_ raw: String, generatedAt: Date) -> [AICoachInsight] {
        var results: [AICoachInsight] = []
        let lines = raw.split(whereSeparator: { $0.isNewline })
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let labelPart = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let bodyPart = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            guard !bodyPart.isEmpty, let topic = topicMap[labelPart.uppercased()] else { continue }
            results.append(
                AICoachInsight(
                    topic: topic,
                    title: topic.title,
                    body: bodyPart,
                    generatedAt: generatedAt
                )
            )
        }
        return results
    }
}
