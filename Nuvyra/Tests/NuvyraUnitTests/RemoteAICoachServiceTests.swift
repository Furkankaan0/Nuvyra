import XCTest
@testable import Nuvyra

@MainActor
final class RemoteAICoachServiceTests: XCTestCase {

    // MARK: - Request encoding

    func testRequestEncodesAnthropicShape() throws {
        let request = ClaudeMessagesAPI.Request(
            model: "claude-sonnet-4-6",
            maxTokens: 256,
            temperature: 0.4,
            system: "system-prompt",
            messages: [
                ClaudeMessagesAPI.Message(role: .user, content: "merhaba")
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(json["max_tokens"] as? Int, 256, "snake_case required by Anthropic API")
        XCTAssertEqual(json["temperature"] as? Double, 0.4)
        XCTAssertEqual(json["system"] as? String, "system-prompt")

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?["role"] as? String, "user")
        XCTAssertEqual(messages.first?["content"] as? String, "merhaba")
    }

    func testNilStopSequencesAreNotEncoded() throws {
        // Optional stop_sequences must not appear in the JSON when nil; the
        // API rejects nulls in some fields, so we lean on Swift's optional
        // encoding to drop them.
        let request = ClaudeMessagesAPI.Request(
            model: "x",
            maxTokens: 1,
            temperature: 0,
            system: nil,
            messages: []
        )
        let data = try JSONEncoder().encode(request)
        let raw = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(raw.contains("stop_sequences"))
        XCTAssertFalse(raw.contains("\"system\""), "Nil system field should also be omitted")
    }

    // MARK: - Response decoding

    func testResponseDecodesMultipleContentBlocks() throws {
        let raw = """
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "content": [
            { "type": "text", "text": "Birinci satır." },
            { "type": "text", "text": "İkinci satır." }
          ],
          "stop_reason": "end_turn",
          "usage": { "input_tokens": 42, "output_tokens": 17 }
        }
        """
        let data = Data(raw.utf8)
        let response = try JSONDecoder().decode(ClaudeMessagesAPI.Response.self, from: data)
        XCTAssertEqual(response.id, "msg_123")
        XCTAssertEqual(response.model, "claude-sonnet-4-6")
        XCTAssertEqual(response.concatenatedText, "Birinci satır.\nİkinci satır.")
        XCTAssertEqual(response.usage?.inputTokens, 42)
        XCTAssertEqual(response.usage?.outputTokens, 17)
    }

    func testConcatenatedTextSkipsNonTextBlocks() throws {
        // Future tool-use blocks should be silently ignored, not crash.
        let raw = """
        {
          "id": "msg_x",
          "role": "assistant",
          "model": "claude-sonnet-4-6",
          "content": [
            { "type": "tool_use", "text": null },
            { "type": "text", "text": "Sadece bu görünmeli." }
          ]
        }
        """
        let response = try JSONDecoder().decode(ClaudeMessagesAPI.Response.self, from: Data(raw.utf8))
        XCTAssertEqual(response.concatenatedText, "Sadece bu görünmeli.")
    }

    // MARK: - Insight parsing

    func testInsightParserHandlesAllFiveTopics() {
        let raw = """
        DAILY: Bugünkü ritmin sakin görünüyor.
        WEEKLY: Bu hafta adımların geçen haftaya göre artmış.
        CALORIES: Kalori hedefine 320 kcal kaldı.
        WATER: Su hedefine yakınsın, 250 ml kaldı.
        STEPS: 2.000 adım daha rahat tamamlanır.
        """
        let insights = InsightParser.parse(raw, generatedAt: Date())
        XCTAssertEqual(insights.count, 5)
        XCTAssertEqual(insights[0].topic, .daily)
        XCTAssertEqual(insights[1].topic, .weekly)
        XCTAssertTrue(insights[2].body.contains("320 kcal"))
    }

    func testInsightParserIgnoresExtraOrMalformedLines() {
        let raw = """
        DAILY: Birinci.
        Extra serbest açıklama satırı — atlanmalı.
        UNKNOWN_TOPIC: Bilinmeyen.
        WEEKLY: İkinci.
        """
        let insights = InsightParser.parse(raw, generatedAt: Date())
        XCTAssertEqual(insights.count, 2)
        XCTAssertEqual(insights.map(\.topic), [.daily, .weekly])
    }

    func testInsightParserSkipsEmptyBodies() {
        // Anthropic occasionally emits "DAILY: " with no body when the
        // context is too empty — we must drop the row instead of rendering
        // an empty card.
        let raw = """
        DAILY:
        WEEKLY: Bir şey var.
        """
        let insights = InsightParser.parse(raw, generatedAt: Date())
        XCTAssertEqual(insights.count, 1)
        XCTAssertEqual(insights.first?.topic, .weekly)
    }

    // MARK: - Error mapping

    func testTransportErrorMapping() {
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.http(status: 401, body: nil)), .notImplemented)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.http(status: 403, body: nil)), .notImplemented)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.http(status: 429, body: nil)), .rateLimited)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.http(status: 500, body: nil)), .network)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.timeout), .network)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.offline), .network)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.notFound), .notImplemented)
        XCTAssertEqual(RemoteAICoachService.mapTransportError(.invalidURL), .notImplemented)
    }

    // MARK: - Prompt builder

    func testContextBlockIncludesDailyAndWeeklyNumbers() {
        let context = AICoachContext(
            greetingName: "Furkan",
            caloriesConsumed: 1_500,
            caloriesTarget: 1_900,
            proteinGrams: 80,
            proteinTargetGrams: 120,
            waterMl: 1_200,
            waterTargetMl: 2_000,
            steps: 5_500,
            stepTarget: 7_500,
            weeklyAverageSteps: 7_000,
            weeklyAverageWaterMl: 1_600,
            weeklyComparison: WeeklyComparison(
                metrics: [
                    WeeklyMetric(kind: .calories, currentAverage: 1_800, previousAverage: 1_700),
                    WeeklyMetric(kind: .protein, currentAverage: 90, previousAverage: 85),
                    WeeklyMetric(kind: .steps, currentAverage: 7_000, previousAverage: 6_000),
                    WeeklyMetric(kind: .water, currentAverage: 1_700, previousAverage: 1_600)
                ],
                storyline: "Bu hafta adımların geçen haftadan %17 daha yüksek.",
                hasEnoughData: true,
                activeDaysThisWeek: 6
            )
        )
        let block = ClaudeCoachPromptBuilder.contextBlock(context)
        XCTAssertTrue(block.contains("Furkan"))
        XCTAssertTrue(block.contains("1500 / 1900 kcal"))
        XCTAssertTrue(block.contains("BU HAFTA"))
        XCTAssertTrue(block.contains("%17"), "Storyline percent should make it into the prompt")
    }

    func testContextBlockOmitsWeeklySectionWhenNotEnoughData() {
        let block = ClaudeCoachPromptBuilder.contextBlock(.empty)
        XCTAssertFalse(block.contains("BU HAFTA"), "Empty comparison should suppress the weekly block")
    }

    func testSystemPromptForbidsBannedVocabulary() {
        // Sanity check — the system prompt must spell out the banned list so
        // the model can refuse on its own even if our context block leaks a
        // word. Regression-protect against accidental edits.
        let banned = ["kilo", "diyet", "doktor", "hastalık", "ilaç"]
        let prompt = ClaudeCoachPromptBuilder.systemPrompt.lowercased()
        for word in banned {
            XCTAssertTrue(prompt.contains(word), "System prompt should still mention '\(word)' as forbidden")
        }
    }
}
