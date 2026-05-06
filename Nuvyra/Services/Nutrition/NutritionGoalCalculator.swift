import Foundation

struct NutritionGoalCalculationInput: Equatable {
    var age: Int
    var gender: Gender
    var heightCm: Double
    var weightKg: Double
    var targetWeightKg: Double?
    var activityLevel: ActivityLevel
    var goalType: GoalType
    var goalPace: GoalPace

    static let defaultSetup = NutritionGoalCalculationInput(
        age: 30,
        gender: .preferNotToSay,
        heightCm: 175,
        weightKg: 78,
        targetWeightKg: nil,
        activityLevel: .lightlyActive,
        goalType: .healthyLiving,
        goalPace: .balanced
    )
}

struct CalculatedNutritionTargets: Equatable {
    var dailyCalories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var waterMl: Int
    var stepTarget: Int
    var bmr: Int
    var tdee: Int

    var waterLitersText: String {
        let liters = Double(waterMl) / 1_000
        return String(format: "%.1f L", liters)
    }
}

enum NutritionGoalCalculator {
    static func calculate(for input: NutritionGoalCalculationInput) -> CalculatedNutritionTargets {
        let safeAge = min(max(input.age, 13), 100)
        let safeHeight = min(max(input.heightCm, 130), 220)
        let safeWeight = min(max(input.weightKg, 35), 220)

        let bmr = mifflinStJeor(
            age: safeAge,
            gender: input.gender,
            heightCm: safeHeight,
            weightKg: safeWeight
        )
        let tdee = bmr * input.activityLevel.multiplier
        let adjustedCalories = calorieTarget(from: tdee, goal: input.goalType, pace: input.goalPace)
        let calories = roundToNearest(adjustedCalories, step: 25)
        let protein = roundToNearest(safeWeight * proteinMultiplier(for: input.goalType), step: 5)
        let fat = roundToNearest((Double(calories) * fatRatio(for: input.goalType)) / 9, step: 5)
        let carbsCalories = max(Double(calories) - Double(protein * 4) - Double(fat * 9), 80)
        let carbs = roundToNearest(carbsCalories / 4, step: 5)
        let water = roundToNearest(min(max(safeWeight * 35, 1_800), 4_200), step: 50)
        let steps = stepTarget(activityLevel: input.activityLevel, goal: input.goalType)

        return CalculatedNutritionTargets(
            dailyCalories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            waterMl: water,
            stepTarget: steps,
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded())
        )
    }

    private static func mifflinStJeor(age: Int, gender: Gender, heightCm: Double, weightKg: Double) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        switch gender {
        case .male:
            return base + 5
        case .female:
            return base - 161
        case .other, .preferNotToSay:
            // Neutral midpoint between female and male constants to avoid forcing a binary assumption.
            return base - 78
        }
    }

    private static func calorieTarget(from tdee: Double, goal: GoalType, pace: GoalPace) -> Double {
        switch goal {
        case .loseWeight:
            return tdee - calorieDelta(for: pace, direction: .deficit)
        case .gainHealthy, .gainMuscle:
            return tdee + calorieDelta(for: pace, direction: .surplus)
        case .maintain, .walkMore, .eatHealthier, .healthyLiving, .stayFit:
            return tdee
        }
    }

    private enum CalorieDirection {
        case deficit
        case surplus
    }

    private static func calorieDelta(for pace: GoalPace, direction: CalorieDirection) -> Double {
        switch (pace, direction) {
        case (.slow, .deficit): 250
        case (.balanced, .deficit): 400
        case (.fast, .deficit): 550
        case (.slow, .surplus): 180
        case (.balanced, .surplus): 300
        case (.fast, .surplus): 420
        }
    }

    private static func proteinMultiplier(for goal: GoalType) -> Double {
        switch goal {
        case .loseWeight:
            1.8
        case .gainHealthy, .gainMuscle:
            2.0
        case .walkMore, .stayFit:
            1.7
        case .maintain, .eatHealthier, .healthyLiving:
            1.55
        }
    }

    private static func fatRatio(for goal: GoalType) -> Double {
        switch goal {
        case .gainHealthy, .gainMuscle:
            0.27
        case .loseWeight:
            0.30
        case .maintain, .walkMore, .eatHealthier, .healthyLiving, .stayFit:
            0.28
        }
    }

    private static func stepTarget(activityLevel: ActivityLevel, goal: GoalType) -> Int {
        let baseline: Int
        switch activityLevel {
        case .sedentary: baseline = 6_500
        case .lightlyActive: baseline = 7_500
        case .moderatelyActive: baseline = 8_500
        case .veryActive: baseline = 9_500
        case .athlete: baseline = 11_000
        }

        let goalBonus: Int
        switch goal {
        case .walkMore, .stayFit:
            goalBonus = 1_000
        case .loseWeight, .healthyLiving:
            goalBonus = 500
        case .maintain, .gainHealthy, .gainMuscle, .eatHealthier:
            goalBonus = 0
        }

        return min(max(baseline + goalBonus, 6_000), 12_000)
    }

    private static func roundToNearest(_ value: Double, step: Int) -> Int {
        let stepValue = Double(step)
        return Int((value / stepValue).rounded() * stepValue)
    }
}
