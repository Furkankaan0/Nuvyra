import Foundation
import SwiftData

@MainActor
protocol UserRepository {
    func settings() throws -> AppSettings
    func profile() throws -> UserProfile?
    func saveOnboardingProfile(name: String, goalType: GoalType) throws -> UserProfile
    func savePersonalizedOnboardingProfile(
        name: String,
        input: NutritionGoalCalculationInput,
        targets: CalculatedNutritionTargets
    ) throws -> UserProfile
    func markOnboardingCompleted() throws
}

@MainActor
final class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func settings() throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    func profile() throws -> UserProfile? {
        try context.fetch(FetchDescriptor<UserProfile>()).first
    }

    func saveOnboardingProfile(name: String, goalType: GoalType) throws -> UserProfile {
        var input = NutritionGoalCalculationInput.defaultSetup
        input.goalType = goalType
        let targets = NutritionGoalCalculator.calculate(for: input)
        return try savePersonalizedOnboardingProfile(name: name, input: input, targets: targets)
    }

    func savePersonalizedOnboardingProfile(
        name: String,
        input: NutritionGoalCalculationInput,
        targets: CalculatedNutritionTargets
    ) throws -> UserProfile {
        let profile: UserProfile
        if let existing = try self.profile() {
            profile = existing
        } else {
            profile = UserProfile()
            context.insert(profile)
        }
        profile.name = name.isEmpty ? "Nuvyra" : name
        profile.age = input.age
        profile.gender = input.gender
        profile.heightCm = input.heightCm
        profile.weightKg = input.weightKg
        profile.targetWeightKg = input.targetWeightKg
        profile.goalType = input.goalType
        profile.activityLevel = input.activityLevel
        profile.goalPace = input.goalType.isPaceSensitive ? input.goalPace : nil
        profile.dailyCalorieTarget = targets.dailyCalories
        profile.dailyProteinTargetGrams = targets.proteinGrams
        profile.dailyCarbsTargetGrams = targets.carbsGrams
        profile.dailyFatTargetGrams = targets.fatGrams
        profile.dailyStepTarget = targets.stepTarget
        profile.dailyWaterTargetMl = targets.waterMl
        profile.updatedAt = Date()

        let nutritionGoal = try currentNutritionGoal()
        nutritionGoal.dailyCalories = targets.dailyCalories
        nutritionGoal.proteinGrams = Double(targets.proteinGrams)
        nutritionGoal.carbsGrams = Double(targets.carbsGrams)
        nutritionGoal.fatGrams = Double(targets.fatGrams)
        nutritionGoal.updatedAt = Date()

        try markOnboardingCompleted()
        try context.save()
        return profile
    }

    func markOnboardingCompleted() throws {
        let current = try settings()
        current.hasCompletedOnboarding = true
        current.updatedAt = Date()
        try context.save()
    }

    private func currentNutritionGoal() throws -> NutritionGoal {
        if let existing = try context.fetch(FetchDescriptor<NutritionGoal>()).first {
            return existing
        }
        let goal = NutritionGoal()
        context.insert(goal)
        return goal
    }
}
