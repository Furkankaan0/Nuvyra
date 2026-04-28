import XCTest
@testable import Nuvyra

final class StepGoalAdapterTests: XCTestCase {
    func testInitialGoalUsesActivityLevelBaseline() {
        XCTAssertEqual(StepGoalAdapter().initialGoal(for: .light), 6_500)
        XCTAssertEqual(StepGoalAdapter().initialGoal(for: .active), 9_500)
    }

    func testGoalIncreasesAfterThreeStrongDays() {
        let days = (0..<3).map { offset in
            StepHistoryDay(date: Date().addingTimeInterval(Double(offset) * 86_400), steps: 7_100, goal: 6_500)
        }

        let recommendation = StepGoalAdapter().adaptedGoal(currentGoal: 6_500, recentDays: days)

        XCTAssertEqual(recommendation.goal, 7_000)
        XCTAssertTrue(recommendation.reason.contains("yükselttik"))
    }

    func testGoalSoftensAfterTwoLowDays() {
        let days = (0..<2).map { offset in
            StepHistoryDay(date: Date().addingTimeInterval(Double(offset) * 86_400), steps: 2_000, goal: 6_500)
        }

        let recommendation = StepGoalAdapter().adaptedGoal(currentGoal: 6_500, recentDays: days)

        XCTAssertEqual(recommendation.goal, 6_000)
        XCTAssertTrue(recommendation.reason.contains("cezalandırmadan"))
    }
}
