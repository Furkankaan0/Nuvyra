import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func ensureMinimumData(in context: ModelContext) {
        ensureSettings(in: context)
        ensureSubscription(in: context)
        ensureNutritionGoal(in: context)
        seedDemoDailyDataIfNeeded(in: context)
        try? context.save()
    }

    @MainActor
    static func seedPreview(in context: ModelContext) {
        // Preview-only data. Never used in release builds — it's gated by
        // `#if DEBUG` callers and `NuvyraModelContainer.preview()`.
        let profile = UserProfile(
            name: "Önizleme",
            age: 30,
            gender: .preferNotToSay,
            heightCm: 175,
            weightKg: 78,
            targetWeightKg: 74,
            dailyCalorieTarget: 1_900,
            dailyStepTarget: 7_500,
            dailyWaterTargetMl: 2_000,
            goalType: .walkMore,
            activityLevel: .light
        )
        let settings = AppSettings(hasCompletedOnboarding: true, notificationsEnabled: true, healthPermissionAsked: true)
        let subscription = SubscriptionState(isPremium: false)
        let goal = NutritionGoal()
        let today = Date()

        context.insert(profile)
        context.insert(settings)
        context.insert(subscription)
        context.insert(goal)
        context.insert(DailyLog(date: today, totalCalories: 1_120, caloriesBurned: 280, steps: 5_360, waterMl: 1_250, streakCompleted: false, mood: .calm))
        context.insert(WalkingLog(date: today, steps: 5_360, activeEnergy: 280, distanceKm: 3.8, goalCompleted: false))
        context.insert(WaterEntry(date: today, amountMl: 750))
        context.insert(WaterEntry(date: today, amountMl: 500))
        context.insert(MealEntry(mealType: .breakfast, name: "Menemen", calories: 330, protein: 18, carbs: 12, fat: 22, portionDescription: "1 tabak", isFavorite: true, isVerifiedTurkishFood: true, isEstimated: true))
        context.insert(MealEntry(mealType: .lunch, name: "Mercimek çorbası", calories: 210, protein: 11, carbs: 31, fat: 6, portionDescription: "1 kase", isFavorite: true, isVerifiedTurkishFood: true, isEstimated: true))
        try? context.save()
    }

    /// Seeds a fully-onboarded user so UI tests can skip the onboarding
    /// flow and exercise the screens they actually want to assert on
    /// (Restore Purchases, Walking start, etc.). Distinct from
    /// `seedPreview` because it doesn't pre-populate meal/water demo
    /// rows that would interfere with assertions.
    @MainActor
    static func seedUITesting(in context: ModelContext) {
        ensureSettings(in: context)
        ensureSubscription(in: context)
        ensureNutritionGoal(in: context)

        let userProfileDescriptor = FetchDescriptor<UserProfile>()
        if (try? context.fetch(userProfileDescriptor).isEmpty) == true {
            let profile = UserProfile(
                name: "UITest",
                age: 30,
                gender: .preferNotToSay,
                heightCm: 175,
                weightKg: 78,
                targetWeightKg: 74,
                dailyCalorieTarget: 1_900,
                dailyStepTarget: 7_500,
                dailyWaterTargetMl: 2_000,
                goalType: .walkMore,
                activityLevel: .light
            )
            context.insert(profile)
        }

        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            settings.hasCompletedOnboarding = true
            settings.notificationsEnabled = true
            settings.healthPermissionAsked = true
        }

        try? context.save()
    }

    @MainActor
    private static func ensureSettings(in context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(descriptor), settings.isEmpty {
            context.insert(AppSettings())
        }
    }

    @MainActor
    private static func ensureSubscription(in context: ModelContext) {
        let descriptor = FetchDescriptor<SubscriptionState>()
        if let states = try? context.fetch(descriptor), states.isEmpty {
            context.insert(SubscriptionState())
        }
    }

    @MainActor
    private static func ensureNutritionGoal(in context: ModelContext) {
        let descriptor = FetchDescriptor<NutritionGoal>()
        if let goals = try? context.fetch(descriptor), goals.isEmpty {
            context.insert(NutritionGoal())
        }
    }

    @MainActor
    private static func seedDemoDailyDataIfNeeded(in context: ModelContext) {
        let logDescriptor = FetchDescriptor<DailyLog>()
        guard (try? context.fetch(logDescriptor).isEmpty) == true else { return }
        let today = Date()
        context.insert(DailyLog(date: today, totalCalories: 0, caloriesBurned: 0, steps: 0, waterMl: 0))
    }
}
