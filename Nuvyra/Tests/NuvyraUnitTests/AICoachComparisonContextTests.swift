import XCTest
@testable import Nuvyra

@MainActor
final class AICoachComparisonContextTests: XCTestCase {

    private let stepsUpComparison = WeeklyComparison(
        metrics: [
            WeeklyMetric(kind: .calories, currentAverage: 1_800, previousAverage: 1_800),
            WeeklyMetric(kind: .protein, currentAverage: 90, previousAverage: 90),
            WeeklyMetric(kind: .steps, currentAverage: 8_500, previousAverage: 6_500),
            WeeklyMetric(kind: .water, currentAverage: 1_700, previousAverage: 1_700)
        ],
        storyline: "Bu hafta adım ortalaman geçen haftaya göre %31 daha yüksek. Sakin bir ivme yakalamışsın.",
        hasEnoughData: true,
        activeDaysThisWeek: 6
    )

    private let waterDownComparison = WeeklyComparison(
        metrics: [
            WeeklyMetric(kind: .calories, currentAverage: 1_800, previousAverage: 1_800),
            WeeklyMetric(kind: .protein, currentAverage: 90, previousAverage: 90),
            WeeklyMetric(kind: .steps, currentAverage: 7_000, previousAverage: 7_000),
            WeeklyMetric(kind: .water, currentAverage: 1_200, previousAverage: 1_900)
        ],
        storyline: "Su tüketimin geçen haftadan %37 geride. Yarına bir bardak daha eklemek küçük bir dokunuş.",
        hasEnoughData: true,
        activeDaysThisWeek: 5
    )

    private func makeContext(comparison: WeeklyComparison) -> AICoachContext {
        AICoachContext(
            greetingName: "Furkan",
            caloriesConsumed: 1_400,
            caloriesTarget: 1_900,
            proteinGrams: 80,
            proteinTargetGrams: 120,
            waterMl: 1_200,
            waterTargetMl: 2_000,
            steps: 5_500,
            stepTarget: 7_500,
            weeklyAverageSteps: Int((comparison.metrics.first(where: { $0.kind == .steps })?.currentAverage ?? 0).rounded()),
            weeklyAverageWaterMl: Int((comparison.metrics.first(where: { $0.kind == .water })?.currentAverage ?? 0).rounded()),
            weeklyComparison: comparison
        )
    }

    // MARK: - Weekly insight

    func testWeeklyInsightUsesComparisonStorylineWhenEnoughData() async throws {
        let service = MockAICoachService()
        let context = makeContext(comparison: stepsUpComparison)
        let insights = try await service.generateInsights(context: context)
        let weekly = try XCTUnwrap(insights.first(where: { $0.topic == .weekly }))
        XCTAssertEqual(weekly.body, stepsUpComparison.storyline)
    }

    func testWeeklyInsightFallsBackWhenNotEnoughData() async throws {
        let service = MockAICoachService()
        let context = makeContext(comparison: .empty)
        let insights = try await service.generateInsights(context: context)
        let weekly = try XCTUnwrap(insights.first(where: { $0.topic == .weekly }))
        // Empty comparison → should use the legacy step-status copy, not the
        // storyline (which would surface the "first week" empty-state line).
        XCTAssertFalse(weekly.body.contains("ivme"))
    }

    // MARK: - Reply intent routing

    func testReplyToWeeklyTrendQuestionEchoesStorylineAndBreakdown() async throws {
        let service = MockAICoachService()
        let context = makeContext(comparison: stepsUpComparison)
        let reply = try await service.reply(
            to: "Bu hafta geçen haftaya göre nasılım?",
            context: context,
            history: []
        )
        XCTAssertTrue(reply.text.contains("Sakin bir ivme"), "Should include the storyline")
        XCTAssertTrue(reply.text.contains("Adım"), "Should list a per-metric breakdown line")
        XCTAssertTrue(reply.text.contains("genel bilgilendirme"), "Safety outro must remain")
    }

    func testReplyFocusedOnWaterCitesWaterMetricSpecifically() async throws {
        let service = MockAICoachService()
        let context = makeContext(comparison: waterDownComparison)
        let reply = try await service.reply(
            to: "Geçen hafta su tüketimim nasıldı?",
            context: context,
            history: []
        )
        XCTAssertTrue(reply.text.localizedCaseInsensitiveContains("su"), "Reply should focus on water")
        XCTAssertTrue(reply.text.contains("1.200") || reply.text.contains("1200"), "Should mention current avg")
        XCTAssertTrue(reply.text.contains("1.900") || reply.text.contains("1900"), "Should mention prior avg")
        XCTAssertTrue(reply.text.contains("↓"), "Down direction arrow should appear in the change chip text")
    }

    func testReplyForFirstWeekUserExplainsLackOfBaseline() async throws {
        let service = MockAICoachService()
        let context = makeContext(comparison: .empty)
        let reply = try await service.reply(
            to: "Bu hafta geçen haftaya göre nasılım?",
            context: context,
            history: []
        )
        XCTAssertTrue(reply.text.contains("birkaç güne yayılmış kayıt"))
    }

    // MARK: - Backward compat

    func testProteinIntentStillRoutesToProteinBranch() async throws {
        // Comparison intent matcher must not steal the "protein" question.
        let service = MockAICoachService()
        let context = makeContext(comparison: stepsUpComparison)
        let reply = try await service.reply(
            to: "Daha çok protein için ne ekleyebilirim?",
            context: context,
            history: []
        )
        XCTAssertTrue(reply.text.lowercased().contains("yoğurt"), "Generic protein branch should still fire")
    }

    // MARK: - Calm-coach guardrail

    func testComparisonReplyContainsNoMedicalOrWeightLanguage() async throws {
        let service = MockAICoachService()
        let contexts = [
            makeContext(comparison: stepsUpComparison),
            makeContext(comparison: waterDownComparison),
            makeContext(comparison: .empty)
        ]
        let banned = ["kilo", "diyet", "yağ yak", "hastalık", "tedavi", "ilaç", "doktor", "kg"]
        for ctx in contexts {
            let reply = try await service.reply(
                to: "Bu hafta geçen haftaya göre nasılım?",
                context: ctx,
                history: []
            )
            for word in banned {
                XCTAssertFalse(
                    reply.text.lowercased().contains(word),
                    "Comparison reply contained banned word '\(word)': \(reply.text)"
                )
            }
        }
    }
}
