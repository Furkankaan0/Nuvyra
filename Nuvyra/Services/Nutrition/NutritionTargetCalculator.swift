import Foundation

/// Inputs needed to derive a personalised daily energy/water/step target.
///
/// All body metrics are required. Defaults belong to the UI layer (the user
/// types them in onboarding); this struct intentionally has no convenience
/// initialiser so we can never silently fall back to a fictional 30 yaş /
/// 175 cm / 78 kg "Furkan" profile.
struct NutritionTargetInput {
    let gender: Gender
    let age: Int
    let heightCm: Double
    let weightKg: Double
    let activityLevel: ActivityLevel
    let goal: GoalType
}

/// Output of the calculator. All values are clamped to safe ranges so that
/// rounding errors or extreme inputs cannot push us below ~1.200 kcal or
/// above ~3.500 kcal.
struct NutritionTargetResult: Equatable {
    let bmr: Int
    let tdee: Int
    let dailyCalories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let dailyStepTarget: Int
    let dailyWaterTargetMl: Int
}

/// Computes calorie / macro / step / water targets from a user's body
/// metrics + goal, using the Mifflin–St Jeor BMR formula and a goal-driven
/// kcal delta on top of TDEE.
struct NutritionTargetCalculator {
    /// Lower safety floor for daily kcal — never recommend below this.
    static let minimumDailyCalories = 1_200
    /// Upper safety ceiling for daily kcal in the consumer onboarding flow.
    static let maximumDailyCalories = 3_500

    func compute(_ input: NutritionTargetInput) -> NutritionTargetResult {
        let bmr = mifflinStJeor(
            gender: input.gender,
            age: input.age,
            heightCm: input.heightCm,
            weightKg: input.weightKg
        )
        let tdee = bmr * input.activityLevel.multiplier
        let delta = goalDelta(for: input.goal)
        let raw = tdee + delta
        let clamped = min(
            Double(Self.maximumDailyCalories),
            max(Double(Self.minimumDailyCalories), raw)
        )
        // Round to the nearest 10 kcal so the UI shows tidy numbers.
        let dailyCalories = Int((clamped / 10).rounded()) * 10

        let macros = macroSplit(for: input.goal, calories: Double(dailyCalories), weightKg: input.weightKg)

        return NutritionTargetResult(
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded()),
            dailyCalories: dailyCalories,
            proteinGrams: macros.protein,
            carbsGrams: macros.carbs,
            fatGrams: macros.fat,
            dailyStepTarget: stepTarget(for: input.goal, activityLevel: input.activityLevel),
            dailyWaterTargetMl: waterTarget(weightKg: input.weightKg)
        )
    }

    // MARK: - Mifflin–St Jeor

    /// Mifflin–St Jeor Resting/Basal Metabolic Rate.
    /// Men:   BMR = 10·kg + 6.25·cm − 5·age + 5
    /// Women: BMR = 10·kg + 6.25·cm − 5·age − 161
    /// "Other" / preferNotToSay: average of the two formulas.
    private func mifflinStJeor(gender: Gender, age: Int, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch gender {
        case .male: return base + 5
        case .female: return base - 161
        case .other, .preferNotToSay: return base - 78 // mid-point of +5 and −161
        }
    }

    // MARK: - Goal deltas (kcal/day applied on top of TDEE)

    /// Returns the kcal adjustment for each goal. Conservative ranges keep
    /// us inside the 300–500 kcal/day window the user requested.
    private func goalDelta(for goal: GoalType) -> Double {
        switch goal {
        case .loseWeight: return -500
        case .gainHealthy: return 300
        case .maintain: return 0
        case .walkMore: return -150     // mild deficit while building habit
        case .eatHealthier: return -100  // gentle nudge below maintenance
        }
    }

    // MARK: - Macro split

    private func macroSplit(for goal: GoalType, calories: Double, weightKg: Double) -> (protein: Double, carbs: Double, fat: Double) {
        let proteinPerKg: Double
        let fatRatio: Double
        switch goal {
        case .loseWeight:
            proteinPerKg = 1.8
            fatRatio = 0.30
        case .gainHealthy:
            proteinPerKg = 1.6
            fatRatio = 0.28
        case .maintain, .eatHealthier, .walkMore:
            proteinPerKg = 1.4
            fatRatio = 0.30
        }
        let proteinG = (proteinPerKg * weightKg).rounded()
        let fatG = ((calories * fatRatio) / 9).rounded()
        let proteinKcal = proteinG * 4
        let fatKcal = fatG * 9
        let carbsG = max(0, (calories - proteinKcal - fatKcal) / 4).rounded()
        return (proteinG, carbsG, fatG)
    }

    // MARK: - Steps

    private func stepTarget(for goal: GoalType, activityLevel: ActivityLevel) -> Int {
        let base: Int
        switch goal {
        case .walkMore: base = 9_000
        case .loseWeight: base = 8_000
        case .gainHealthy: base = 6_500
        case .maintain, .eatHealthier: base = 7_500
        }
        // Slight bump for already-active users so the goal stays meaningful.
        let bump: Int
        switch activityLevel {
        case .sedentary: bump = -500
        case .light: bump = 0
        case .moderate: bump = 500
        case .active: bump = 1_000
        case .veryActive: bump = 1_500
        }
        return max(4_000, base + bump)
    }

    // MARK: - Water

    /// 35 ml/kg, rounded to the nearest 250 ml, clamped to a sane range.
    private func waterTarget(weightKg: Double) -> Int {
        let raw = weightKg * 35
        let rounded = (raw / 250).rounded() * 250
        return Int(min(4_000, max(1_500, rounded)))
    }
}
