import Foundation
import SwiftData

@MainActor
protocol UserRepository {
    func settings() throws -> AppSettings
    func profile() throws -> UserProfile?
    func saveOnboardingProfile(
        name: String,
        goalType: GoalType,
        gender: Gender,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel
    ) throws -> UserProfile
    func markOnboardingCompleted() throws
}

@MainActor
final class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext
    private let calculator: NutritionTargetCalculator
    private let onMutate: (@MainActor () -> Void)?

    init(
        context: ModelContext,
        calculator: NutritionTargetCalculator = NutritionTargetCalculator(),
        onMutate: (@MainActor () -> Void)? = nil
    ) {
        self.context = context
        self.calculator = calculator
        self.onMutate = onMutate
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

    func saveOnboardingProfile(
        name: String,
        goalType: GoalType,
        gender: Gender,
        age: Int,
        heightCm: Double,
        weightKg: Double,
        activityLevel: ActivityLevel
    ) throws -> UserProfile {
        let target = calculator.compute(
            NutritionTargetInput(
                gender: gender,
                age: age,
                heightCm: heightCm,
                weightKg: weightKg,
                activityLevel: activityLevel,
                goal: goalType
            )
        )

        let resolvedName = name.isEmpty ? "Nuvyra" : name

        let profile: UserProfile
        if let existing = try self.profile() {
            existing.name = resolvedName
            existing.age = age
            existing.gender = gender
            existing.heightCm = heightCm
            existing.weightKg = weightKg
            existing.goalType = goalType
            existing.activityLevel = activityLevel
            existing.dailyCalorieTarget = target.dailyCalories
            existing.dailyStepTarget = target.dailyStepTarget
            existing.dailyWaterTargetMl = target.dailyWaterTargetMl
            existing.updatedAt = Date()
            profile = existing
        } else {
            profile = UserProfile(
                name: resolvedName,
                age: age,
                gender: gender,
                heightCm: heightCm,
                weightKg: weightKg,
                dailyCalorieTarget: target.dailyCalories,
                dailyStepTarget: target.dailyStepTarget,
                dailyWaterTargetMl: target.dailyWaterTargetMl,
                goalType: goalType,
                activityLevel: activityLevel
            )
            context.insert(profile)
        }

        try upsertNutritionGoal(target: target)
        try markOnboardingCompleted()
        try context.save()
        onMutate?()
        return profile
    }

    func markOnboardingCompleted() throws {
        let current = try settings()
        current.hasCompletedOnboarding = true
        current.updatedAt = Date()
        try context.save()
    }

    // MARK: - Helpers

    private func upsertNutritionGoal(target: NutritionTargetResult) throws {
        let existing = try context.fetch(FetchDescriptor<NutritionGoal>()).first
        if let existing {
            existing.dailyCalories = target.dailyCalories
            existing.proteinGrams = target.proteinGrams
            existing.carbsGrams = target.carbsGrams
            existing.fatGrams = target.fatGrams
            existing.updatedAt = Date()
        } else {
            let goal = NutritionGoal(
                dailyCalories: target.dailyCalories,
                proteinGrams: target.proteinGrams,
                carbsGrams: target.carbsGrams,
                fatGrams: target.fatGrams
            )
            context.insert(goal)
        }
    }
}
