import XCTest
@testable import Nuvyra

final class NuvyraWalkingLiveActivityTests: XCTestCase {
    func testContentStateSanitizesNegativeValues() throws {
        guard #available(iOS 16.1, *) else { return }

        let state = NuvyraWalkingAttributes.ContentState.walking(
            steps: -20,
            caloriesBurned: -5,
            elapsedTime: -120
        )

        XCTAssertEqual(state.steps, 0)
        XCTAssertEqual(state.caloriesBurned, 0)
        XCTAssertEqual(state.elapsedTime, 0)
        XCTAssertEqual(state.elapsedMinutes, 0)
    }

    func testContentStateFormatsWalkingSummary() throws {
        guard #available(iOS 16.1, *) else { return }

        let state = NuvyraWalkingAttributes.ContentState.walking(
            steps: 1_240,
            caloriesBurned: 86.6,
            elapsedTime: 12 * 60
        )

        XCTAssertEqual(state.formattedCalories, "87 kcal")
        XCTAssertTrue(state.summary.contains("1.240 adım") || state.summary.contains("1,240 adım"))
        XCTAssertTrue(state.summary.contains("87 kcal"))
        XCTAssertTrue(state.summary.contains("12 dk"))
    }

    @MainActor
    func testMockManagerStartUpdateEndKeepsLatestState() async throws {
        guard #available(iOS 16.1, *) else { return }

        let manager = MockNuvyraWalkingLiveActivityManager()
        await manager.startLiveActivity(steps: 10, caloriesBurned: 2, elapsedTime: 60)
        await manager.updateLiveActivity(steps: 220, caloriesBurned: 18, elapsedTime: 6 * 60)
        await manager.endLiveActivity(steps: 400, caloriesBurned: 32, elapsedTime: 10 * 60)

        XCTAssertTrue(manager.didStart)
        XCTAssertTrue(manager.didEnd)
        XCTAssertEqual(manager.lastState?.steps, 400)
        XCTAssertEqual(manager.lastState?.elapsedMinutes, 10)
    }
}
