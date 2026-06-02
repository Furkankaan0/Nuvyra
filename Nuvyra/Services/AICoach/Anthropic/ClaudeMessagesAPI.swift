import Foundation

/// Anthropic Messages API DTOs (v1, `anthropic-version: 2023-06-01`).
/// Reference: https://docs.anthropic.com/en/api/messages
///
/// We model only the fields Nuvyra actually uses — Anthropic's response
/// schema is permissive and we want decoder errors to surface on unknown
/// shapes (e.g. tool_use blocks) so we can react instead of silently dropping
/// data.
enum ClaudeMessagesAPI {

    // MARK: - Request

    struct Request: Encodable, Sendable {
        let model: String
        let maxTokens: Int
        let temperature: Double
        let system: String?
        let messages: [Message]
        /// Optional list of `stop_sequences` — we don't need them today but
        /// keep the field around so the encoder doesn't crash if added later.
        let stopSequences: [String]?

        init(
            model: String,
            maxTokens: Int,
            temperature: Double,
            system: String?,
            messages: [Message],
            stopSequences: [String]? = nil
        ) {
            self.model = model
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.system = system
            self.messages = messages
            self.stopSequences = stopSequences
        }

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case temperature
            case system
            case messages
            case stopSequences = "stop_sequences"
        }
    }

    struct Message: Codable, Sendable, Equatable {
        enum Role: String, Codable, Sendable, Equatable {
            case user, assistant
        }

        let role: Role
        let content: String
    }

    // MARK: - Response

    /// Successful 200 response. The API returns a `content` array of blocks;
    /// for `claude-sonnet-4-6` with no tools the array contains a single
    /// `text` block, but we tolerate multiple by concatenating the texts.
    struct Response: Decodable, Sendable {
        let id: String
        let role: Message.Role
        let model: String
        let content: [ContentBlock]
        let stopReason: String?
        let usage: Usage?

        enum CodingKeys: String, CodingKey {
            case id, role, model, content
            case stopReason = "stop_reason"
            case usage
        }
    }

    struct ContentBlock: Decodable, Sendable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable, Sendable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    // MARK: - Error payload

    /// 4xx/5xx bodies follow `{ "type": "error", "error": { "type": ..., "message": ... } }`.
    struct ErrorEnvelope: Decodable, Sendable {
        let type: String
        let error: ErrorDetail
    }

    struct ErrorDetail: Decodable, Sendable {
        let type: String
        let message: String
    }
}

extension ClaudeMessagesAPI.Response {
    /// Flatten the multi-block content into a single string. Returns `nil`
    /// when no text-bearing block exists (e.g. tool-only responses), so the
    /// caller can surface a clean error instead of an empty bubble.
    var concatenatedText: String? {
        let parts = content.compactMap { $0.type == "text" ? $0.text : nil }
        let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
}
