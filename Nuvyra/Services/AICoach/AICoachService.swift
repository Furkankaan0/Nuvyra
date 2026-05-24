import Foundation

/// Coach service contract — pure functions, no UI dependencies. Allows the view
/// model to swap a local rules-based service for a remote LLM (Claude, Gemini,
/// OpenAI) without any call-site changes.
@MainActor
protocol AICoachService {
    /// Produces the deterministic insight cards shown on the coach hero.
    func generateInsights(context: AICoachContext) async throws -> [AICoachInsight]

    /// Streams a single coach reply for a user message.
    /// Mock impl returns deterministic copy; remote impl will hit an LLM.
    func reply(to message: String, context: AICoachContext, history: [AICoachMessage]) async throws -> AICoachMessage
}

enum AICoachError: Error, LocalizedError {
    case notImplemented
    case rateLimited
    case network

    var errorDescription: String? {
        switch self {
        case .notImplemented: return "Bu servis henüz aktif değil."
        case .rateLimited: return "Çok fazla istek gönderildi, biraz sonra tekrar dene."
        case .network: return "Bağlantı sorunu. Lütfen tekrar dene."
        }
    }
}
