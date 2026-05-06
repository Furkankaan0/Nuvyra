import CoreHaptics
import XCTest
@testable import Nuvyra

@MainActor
final class HapticManagerTests: XCTestCase {
    func testMealAddedSuccessPatternCanBeCreated() throws {
        let pattern = try HapticManager.shared.makeMealAddedSuccessPattern()

        XCTAssertNotNil(pattern)
    }

    func testWalkingHalfwayPatternCanBeCreated() throws {
        let pattern = try HapticManager.shared.makeWalkingHalfwayPattern()

        XCTAssertNotNil(pattern)
    }

    func testMockHapticsServiceSupportsHalfwayEvent() {
        let haptics = MockHapticsService()

        haptics.walkingHalfwayReached()
    }
}
