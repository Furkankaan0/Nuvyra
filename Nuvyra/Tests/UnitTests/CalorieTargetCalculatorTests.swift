import XCTest
@testable import Nuvyra

final class CalorieTargetCalculatorTests: XCTestCase {
    func testLoseWeightTargetStaysInSafeMVPRange() {
        let profile = UserProfile(
            goal: .loseWeight,
            age: 32,
            heightCentimeters: 175,
            weightKilograms: 82,
            targetWeightKilograms: 76,
            gender: .preferNotToSay,
            activityLevel: .light,
            routine: .preview
        )

        let target = CalorieTargetCalculator().target(for: profile)

        XCTAssertGreaterThanOrEqual(target.recommended, 1_350)
        XCTAssertEqual(target.upperBound - target.lowerBound, 300)
        XCTAssertTrue(target.lowerBound...target.upperBound ~= target.recommended)
    }
}
