import XCTest
@testable import Nuvyra

@MainActor
final class MealTimingEngineTests: XCTestCase {

    private let engine = DefaultMealTimingEngine(locale: Locale(identifier: "tr_TR"))
    private let englishEngine = DefaultMealTimingEngine(locale: Locale(identifier: "en_US"))
    private let calendar = Calendar.nuvyra

    // MARK: - Helpers

    /// Build a Date at HH:00 on today.
    private func today(at hour: Int, minute: Int = 0) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    private func meal(_ type: MealType, hour: Int, minute: Int = 0, calories: Int = 400) -> MealEntry {
        MealEntry(
            date: today(at: hour, minute: minute),
            mealType: type,
            name: "Test \(type.rawValue)",
            calories: calories,
            portionDescription: "1 porsiyon"
        )
    }

    // MARK: - Empty

    func testEmptyMealsReturnsEmptyInsight() {
        let insight = engine.evaluate(meals: [], at: today(at: 14))
        XCTAssertFalse(insight.hasAnyMeal)
        XCTAssertEqual(insight.severity, .calm)
        XCTAssertEqual(insight.slotStatuses.count, MealType.allCases.count)
        XCTAssertTrue(insight.slotStatuses.allSatisfy { !$0.logged })
    }

    // MARK: - Rule 1: Skipped breakfast

    func testSkippedBreakfastAfter1PM() {
        let meals = [meal(.lunch, hour: 13, minute: 30)]
        let insight = engine.evaluate(meals: meals, at: today(at: 14))
        XCTAssertEqual(insight.severity, .nudge)
        XCTAssertTrue(insight.headline.contains("kahvaltı"))
    }

    func testNoSkippedBreakfastBefore1PM() {
        // At 12:00 we shouldn't accuse the user yet — they may still log breakfast.
        let meals = [meal(.snack, hour: 11, minute: 30)]
        let insight = engine.evaluate(meals: meals, at: today(at: 12, minute: 30))
        XCTAssertFalse(insight.headline.contains("kahvaltı kaydı yok"))
    }

    // MARK: - Rule 2: Late dinner

    func testLateDinnerAfter9PMWhenDinnerMissing() {
        let meals = [
            meal(.breakfast, hour: 8),
            meal(.lunch, hour: 13)
        ]
        let insight = engine.evaluate(meals: meals, at: today(at: 21, minute: 30))
        XCTAssertEqual(insight.severity, .nudge)
        XCTAssertTrue(insight.headline.lowercased().contains("akşam"))
    }

    func testDinnerAlreadyLoggedSuppressesLateDinnerNudge() {
        let meals = [
            meal(.breakfast, hour: 8),
            meal(.lunch, hour: 13),
            meal(.dinner, hour: 19)
        ]
        let insight = engine.evaluate(meals: meals, at: today(at: 21, minute: 30))
        XCTAssertEqual(insight.severity, .calm, "Dinner already logged → no nudge")
    }

    // MARK: - Rule 3: Long gap (5+ hours)

    func testLongGapTriggersNudgeDuringWakingHours() {
        // Last meal at 09:00, now 15:00 → 6h gap, hour in [9, 22).
        let meals = [
            meal(.breakfast, hour: 9)
        ]
        let insight = engine.evaluate(meals: meals, at: today(at: 15))
        XCTAssertEqual(insight.severity, .nudge)
        XCTAssertTrue(insight.headline.contains("saat geçti"))
    }

    func testShortGapDoesNotTriggerNudge() {
        let meals = [meal(.lunch, hour: 13)]
        let insight = engine.evaluate(meals: meals, at: today(at: 15))
        XCTAssertEqual(insight.severity, .calm)
        XCTAssertFalse(insight.headline.contains("saat geçti"))
    }

    // MARK: - Rule 4: Balanced day

    func testBalancedDayReturnsCalm() {
        let meals = [
            meal(.breakfast, hour: 8),
            meal(.lunch, hour: 13),
            meal(.dinner, hour: 19)
        ]
        let insight = engine.evaluate(meals: meals, at: today(at: 20))
        XCTAssertEqual(insight.severity, .calm)
        XCTAssertTrue(insight.headline.contains("sakin"))
    }

    // MARK: - Slot statuses

    func testSlotStatusesReflectLoggedMeals() {
        let meals = [
            meal(.breakfast, hour: 8),
            meal(.dinner, hour: 19)
        ]
        let insight = engine.evaluate(meals: meals, at: today(at: 20))
        let breakfast = insight.slotStatuses.first { $0.meal == .breakfast }
        let lunch = insight.slotStatuses.first { $0.meal == .lunch }
        let dinner = insight.slotStatuses.first { $0.meal == .dinner }
        XCTAssertTrue(breakfast?.logged ?? false)
        XCTAssertFalse(lunch?.logged ?? true)
        XCTAssertTrue(dinner?.logged ?? false)
    }

    // MARK: - Locale-aware copy

    func testEnglishLocaleRendersEnglishCopy() {
        // Same rule path that produces "Bugün kahvaltı kaydı yok." in TR
        // must produce the English equivalent when the engine is pinned to
        // en_US. Guards against the copy bank being inadvertently shared.
        let meals = [meal(.lunch, hour: 13, minute: 30)]
        let insight = englishEngine.evaluate(meals: meals, at: today(at: 14))
        XCTAssertEqual(insight.severity, .nudge)
        XCTAssertTrue(insight.headline.lowercased().contains("breakfast"))
        XCTAssertFalse(insight.headline.contains("kahvaltı"), "Turkish word must not leak into English copy")
    }

    func testEnglishEmptyStateUsesEnglishCopy() {
        let insight = englishEngine.evaluate(meals: [], at: today(at: 14))
        XCTAssertFalse(insight.hasAnyMeal)
        XCTAssertTrue(insight.headline.lowercased().contains("no meals logged"))
    }

    func testEnglishLongGapUsesAgoForm() {
        // 6h gap at 15:00 with last meal at 09:00 should produce the EN
        // "It's been 6h since your …" wording with no Turkish leakage.
        let meals = [meal(.breakfast, hour: 9)]
        let insight = englishEngine.evaluate(meals: meals, at: today(at: 15))
        XCTAssertEqual(insight.severity, .nudge)
        XCTAssertTrue(insight.headline.contains("6h"), "Hour count should appear in compact form")
        XCTAssertFalse(insight.headline.contains("saat"))
    }

    // MARK: - Calm-coach guardrail

    func testInsightCopyNeverMentionsBannedHealthTerms() {
        let scenarios: [(meals: [MealEntry], at: Date)] = [
            ([], today(at: 14)),
            ([meal(.lunch, hour: 13)], today(at: 14)),                                  // skipped breakfast
            ([meal(.breakfast, hour: 8), meal(.lunch, hour: 13)], today(at: 21, minute: 30)), // late dinner
            ([meal(.breakfast, hour: 8)], today(at: 15)),                               // long gap
            ([meal(.breakfast, hour: 8), meal(.lunch, hour: 13), meal(.dinner, hour: 19)], today(at: 20)) // balanced
        ]
        let banned = ["kilo", "diyet", "yağ yak", "hastalık", "tedavi", "ilaç", "doktor"]
        for scenario in scenarios {
            let insight = engine.evaluate(meals: scenario.meals, at: scenario.at)
            let text = (insight.headline + " " + (insight.detail ?? "")).lowercased()
            for word in banned {
                XCTAssertFalse(text.contains(word), "Banned word '\(word)' in: \(text)")
            }
        }
    }
}
