import Foundation

/// BMI category buckets per WHO. Used to colour the gauge and label the value.
enum BMICategory: String, CaseIterable {
    case underweight, normal, overweight, obese1, obese2, obese3

    var title: String {
        switch self {
        case .underweight: "Düşük kilolu"
        case .normal: "Normal aralıkta"
        case .overweight: "Fazla kilolu"
        case .obese1: "Obezite (Sınıf I)"
        case .obese2: "Obezite (Sınıf II)"
        case .obese3: "Obezite (Sınıf III)"
        }
    }

    var caption: String {
        switch self {
        case .underweight: "BMI 18.5'in altında"
        case .normal: "BMI 18.5 – 24.9 arasında"
        case .overweight: "BMI 25 – 29.9 arasında"
        case .obese1: "BMI 30 – 34.9 arasında"
        case .obese2: "BMI 35 – 39.9 arasında"
        case .obese3: "BMI 40 ve üzerinde"
        }
    }

    /// Mid-point of the bucket on the BMI scale — used to lay out a gauge with
    /// stops at 18.5 / 25 / 30 / 35 / 40.
    static func from(_ bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5: .underweight
        case 18.5..<25: .normal
        case 25..<30: .overweight
        case 30..<35: .obese1
        case 35..<40: .obese2
        default: .obese3
        }
    }
}

/// Snapshot of derived body metrics — BMI + the BMR/TDEE NutritionGoalCalculator
/// already produces. Mainly a presentation-layer convenience.
struct BodyMetricsSummary: Equatable {
    var bmi: Double
    var category: BMICategory
    var bmr: Int
    var tdee: Int
    var weightKg: Double
    var heightCm: Double

    var bmiFormatted: String { String(format: "%.1f", bmi) }

    static let empty = BodyMetricsSummary(bmi: 0, category: .normal, bmr: 0, tdee: 0, weightKg: 0, heightCm: 0)
}

/// Today's energy balance computed for the Dashboard: what TDEE expects vs. what
/// the user actually ate vs. extra calories burned via activity. Positive deficit
/// means the user ate less than TDEE (informational only — not medical advice).
struct EnergyBalanceSummary: Equatable {
    var tdee: Int
    var caloriesConsumed: Int
    var caloriesBurned: Int

    /// Positive = deficit (ate less than burned), negative = surplus.
    var netDeficit: Int { tdee + caloriesBurned - caloriesConsumed }
    var isDeficit: Bool { netDeficit > 0 }
    var isSurplus: Bool { netDeficit < 0 }

    /// Progress along the "consumed vs total burn" axis (0...1.x).
    var consumedRatio: Double {
        let totalBurn = max(tdee + caloriesBurned, 1)
        return Double(caloriesConsumed) / Double(totalBurn)
    }

    static let empty = EnergyBalanceSummary(tdee: 0, caloriesConsumed: 0, caloriesBurned: 0)
}

enum BodyMetricsCalculator {
    /// Pure BMI = kg / m².
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let meters = heightCm / 100
        return weightKg / (meters * meters)
    }

    /// Derive a full summary from a `UserProfile` — pipes height/weight through
    /// the BMI formula and pipes the rest of the profile through the existing
    /// `NutritionGoalCalculator` to get BMR/TDEE.
    static func summary(for profile: UserProfile) -> BodyMetricsSummary {
        let bmi = bmi(weightKg: profile.weightKg, heightCm: profile.heightCm)
        let input = NutritionGoalCalculationInput(
            age: profile.age,
            gender: profile.gender ?? .preferNotToSay,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            targetWeightKg: profile.targetWeightKg,
            activityLevel: profile.activityLevel,
            goalType: profile.goalType,
            goalPace: profile.goalPace ?? .balanced
        )
        let targets = NutritionGoalCalculator.calculate(for: input)
        return BodyMetricsSummary(
            bmi: bmi,
            category: BMICategory.from(bmi),
            bmr: targets.bmr,
            tdee: targets.tdee,
            weightKg: profile.weightKg,
            heightCm: profile.heightCm
        )
    }

    /// Build the per-day energy balance from a summary + today's intake/activity.
    static func energyBalance(
        summary: BodyMetricsSummary,
        caloriesConsumed: Int,
        caloriesBurned: Int
    ) -> EnergyBalanceSummary {
        EnergyBalanceSummary(
            tdee: summary.tdee,
            caloriesConsumed: caloriesConsumed,
            caloriesBurned: caloriesBurned
        )
    }
}
