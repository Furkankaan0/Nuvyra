import XCTest
@testable import Nuvyra

final class NutritionGoalCalculatorTests: XCTestCase {
    func testPersonalizedTargetsUseActivityAndGoalPace() {
        let input = NutritionGoalCalculationInput(
            age: 32,
            gender: .male,
            heightCm: 180,
            weightKg: 82,
            targetWeightKg: 76,
            activityLevel: .moderatelyActive,
            goalType: .loseWeight,
            goalPace: .balanced
        )

        let targets = NutritionGoalCalculator.calculate(for: input)

        XCTAssertGreaterThan(targets.bmr, 1_700)
        XCTAssertLessThan(targets.dailyCalories, targets.tdee)
        XCTAssertEqual(targets.proteinGrams, 150)
        XCTAssertEqual(targets.stepTarget, 9_000)
        XCTAssertGreaterThanOrEqual(targets.waterMl, 2_800)
    }

    func testMuscleGainCreatesCalorieSurplusAndHigherProtein() {
        let input = NutritionGoalCalculationInput(
            age: 28,
            gender: .female,
            heightCm: 168,
            weightKg: 64,
            targetWeightKg: nil,
            activityLevel: .veryActive,
            goalType: .gainMuscle,
            goalPace: .slow
        )

        let targets = NutritionGoalCalculator.calculate(for: input)

        XCTAssertGreaterThan(targets.dailyCalories, targets.tdee)
        XCTAssertEqual(targets.proteinGrams, 130)
        XCTAssertGreaterThan(targets.carbsGrams, 150)
        XCTAssertEqual(targets.stepTarget, 9_500)
    }
}
