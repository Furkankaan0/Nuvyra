import Foundation

/// Placeholder for the future remote AI Coach service (Gemini/OpenAI/Anthropic).
/// Currently delegates to `MockAICoachService` so that runtime behaviour is stable
/// before the network adapter is wired up. The real implementation will replace
/// `dailyInsights` and `reply` with a privacy-respecting backend call.
final class RemoteAICoachService: AICoachService {
    private let fallback: AICoachService
    private let endpoint: URL?
    private let apiKey: String?
    private let session: URLSession

    init(
        endpoint: URL? = nil,
        apiKey: String? = nil,
        session: URLSession = .shared,
        fallback: AICoachService = MockAICoachService()
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
        self.fallback = fallback
    }

    func dailyInsights(context: AICoachContext) async -> [AICoachInsight] {
        await fallback.dailyInsights(context: context)
    }

    func reply(to question: String, history: [AICoachMessage], context: AICoachContext) async throws -> AICoachMessage {
        try await fallback.reply(to: question, history: history, context: context)
    }
}
