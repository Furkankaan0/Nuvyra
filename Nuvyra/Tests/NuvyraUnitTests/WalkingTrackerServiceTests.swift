import CoreMotion
import XCTest
@testable import Nuvyra

final class WalkingTrackerServiceTests: XCTestCase {
    func testWalkingFlagsStartStepCountingWhenCurrentlyPaused() {
        let flags = WalkingActivityFlags(isStationary: false, isWalking: true, isRunning: false)

        let action = WalkingTrackerBatteryPolicy.action(for: flags, isCountingSteps: false)

        XCTAssertEqual(action, .start)
    }

    func testRunningFlagsStartStepCountingWhenCurrentlyPaused() {
        let flags = WalkingActivityFlags(isStationary: false, isWalking: false, isRunning: true)

        let action = WalkingTrackerBatteryPolicy.action(for: flags, isCountingSteps: false)

        XCTAssertEqual(action, .start)
    }

    func testStationaryFlagsPauseStepCountingToReduceBatteryDrain() {
        let flags = WalkingActivityFlags(isStationary: true, isWalking: false, isRunning: false)

        let action = WalkingTrackerBatteryPolicy.action(for: flags, isCountingSteps: true)

        XCTAssertEqual(action, .pause)
    }

    func testUnknownFlagsPauseStepCountingToAvoidSensorDrain() {
        let flags = WalkingActivityFlags(isStationary: false, isWalking: false, isRunning: false)

        let action = WalkingTrackerBatteryPolicy.action(for: flags, isCountingSteps: true)

        XCTAssertEqual(action, .pause)
    }

    func testSnapshotPrioritizesRunningOverWalkingForDisplayState() {
        let snapshot = WalkingTrackerSnapshot(
            isStationary: false,
            isWalking: true,
            isRunning: true,
            isStepCountingActive: true,
            trackedSteps: 480,
            confidence: .high,
            updatedAt: Date()
        )

        XCTAssertEqual(snapshot.activityState, .running)
    }
}
