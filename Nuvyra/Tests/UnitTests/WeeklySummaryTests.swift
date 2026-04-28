import XCTest
@testable import Nuvyra

final class WeeklySummaryTests: XCTestCase {
    func testWeeklySummaryUsesSupportiveLanguage() {
        let summary = CoachingEngine().weeklySummary(
            meals: MealLog.sampleToday,
            steps: StepHistoryDay.sampleWeek,
            waterLogs: [WaterLog(glasses: 1), WaterLog(glasses: 1)]
        )

        XCTAssertFalse(summary.insight.localizedCaseInsensitiveContains("başarısız"))
        XCTAssertFalse(summary.insight.localizedCaseInsensitiveContains("yanlış"))
        XCTAssertEqual(summary.suggestions.count, 3)
        XCTAssertGreaterThan(summary.averageSteps, 0)
    }
}
