import XCTest
@testable import Nuvyra

@MainActor
final class NativeFoundationTests: XCTestCase {
    func testFoodIntelligenceParsesTurkishSmartMealText() async throws {
        let service = MockFoodIntelligenceService()
        let results = try await service.estimateFromText("öğlen mercimek çorbası ve ayran içtim", mealType: .lunch)

        XCTAssertTrue(results.contains { $0.name == "Mercimek çorbası" && $0.isEstimated })
        XCTAssertTrue(results.contains { $0.name == "Ayran" && $0.source == .localTurkishNLP })
    }

    func testWalkingLiveActivityMockTransitions() async {
        let service = MockWalkingLiveActivityService()

        await service.start(goal: 7_500, initialSteps: 1_200)
        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.lastState?.remaining, 6_300)

        await service.update(steps: 7_500, goal: 7_500, elapsedMinutes: 24)
        XCTAssertEqual(service.lastState?.remaining, 0)

        await service.end(finalSteps: 7_500, goal: 7_500)
        XCTAssertFalse(service.isActive)
    }

    func testMotionActivityStateTitlesAreStable() {
        XCTAssertEqual(MotionActivityState.walking.title, "Yürüyüş")
        XCTAssertEqual(MotionActivityState.automotive.title, "Araçta")
    }

    func testHapticsFallbackDoesNotCrash() {
        let haptics = MockHapticsService()
        haptics.mealLogged()
        haptics.waterAdded()
        haptics.walkStarted()
        haptics.goalCompleted()
    }
}
