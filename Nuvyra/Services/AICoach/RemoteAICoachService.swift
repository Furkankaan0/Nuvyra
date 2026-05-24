import Foundation

/// Placeholder for a future LLM-backed coach (Claude / Gemini / OpenAI).
/// Currently throws `.notImplemented` so the UI can fall back to the local
/// mock. The intent is for the adapter to be filled in once the team picks
/// a provider and exposes an API key + endpoint config.
@MainActor
final class RemoteAICoachService: AICoachService {
    let endpoint: URL?
    let apiKey: String?
    private let session: URLSession

    init(endpoint: URL? = nil, apiKey: String? = nil, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
    }

    func generateInsights(context: AICoachContext) async throws -> [AICoachInsight] {
        throw AICoachError.notImplemented
    }

    func reply(to message: String, context: AICoachContext, history: [AICoachMessage]) async throws -> AICoachMessage {
        throw AICoachError.notImplemented
    }
}
