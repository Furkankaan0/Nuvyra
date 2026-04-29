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
        let profile = UserProfile(name: "Furkan", goalType: .walkMore)
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
