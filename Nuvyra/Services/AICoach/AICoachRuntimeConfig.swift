import Foundation

/// Runtime config for the coach service — mirrors the
/// `FoodDataRuntimeConfig` pattern: env var first, Info.plist second,
/// `$()`-prefixed placeholders treated as absent.
///
/// Keys resolved (first-match wins, env then Info.plist):
/// - `CLAUDE_API_KEY` — required to enable `RemoteAICoachService`.
/// - `CLAUDE_MODEL` — optional override (default: `claude-sonnet-4-6`).
/// - `CLAUDE_ENDPOINT` — optional override for staging/proxy hosts.
enum AICoachRuntimeConfig {

    static var claudeAPIKey: String? {
        value(for: "CLAUDE_API_KEY")
    }

    static var claudeModel: String {
        value(for: "CLAUDE_MODEL") ?? "claude-sonnet-4-6"
    }

    static var claudeEndpoint: URL {
        if let raw = value(for: "CLAUDE_ENDPOINT"), let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://api.anthropic.com/v1/messages")!
    }

    /// True when we have everything required to instantiate
    /// `RemoteAICoachService`; the factory uses this as the decision gate.
    static var hasLiveCredentials: Bool {
        guard let key = claudeAPIKey else { return false }
        return !key.isEmpty
    }

    static func makeRemoteConfiguration() -> RemoteAICoachService.Configuration? {
        guard let key = claudeAPIKey else { return nil }
        return RemoteAICoachService.Configuration(
            apiKey: key,
            endpoint: claudeEndpoint,
            model: claudeModel
        )
    }

    // MARK: - Private

    private static func value(for key: String) -> String? {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return [environmentValue, bundleValue]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { value in
                !value.isEmpty && !value.hasPrefix("$(")
            }
    }
}

/// Tiny factory wrapper. Lives next to the runtime config so the call site
/// doesn't import both files. `live()` picks remote when credentials are
/// present, otherwise hands back the deterministic on-device mock.
@MainActor
enum AICoachServiceFactory {
    static func live() -> AICoachService {
        if let config = AICoachRuntimeConfig.makeRemoteConfiguration() {
            return RemoteAICoachService(configuration: config)
        }
        return MockAICoachService()
    }
}
