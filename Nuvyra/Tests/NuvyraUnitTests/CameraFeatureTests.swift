import XCTest
@testable import Nuvyra

final class CameraFeatureTests: XCTestCase {
    func testFrameRateLimiterAcceptsFirstFrameAndThrottlesNextFrame() {
        var limiter = FrameRateLimiter(maxFramesPerSecond: 4)

        XCTAssertTrue(limiter.shouldAcceptFrame(at: 10.0))
        XCTAssertFalse(limiter.shouldAcceptFrame(at: 10.10))
        XCTAssertTrue(limiter.shouldAcceptFrame(at: 10.25))
    }

    func testCameraDetectionConfidencePercentRoundsForUI() {
        let detection = CameraDetection(
            label: "Elma",
            confidence: 0.904,
            boundingBox: .zero
        )

        XCTAssertEqual(detection.confidencePercent, 90)
    }
}
