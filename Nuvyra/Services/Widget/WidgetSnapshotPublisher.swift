import Foundation
import SwiftData

/// Reads the latest data from repositories + HealthService and writes a
/// `WidgetSnapshot` to the App Group store. Called from any ViewModel that
/// mutates data the widget renders.
@MainActor
enum WidgetSnapshotPublisher {
    static func publish(context: ModelContext, dependencies: DependencyContainer) async {
        let snapshot = await build(context: context, dependencies: dependencies)
        WidgetSnapshotStore.write(snapshot)
    }

    /// Build without writing — useful for tests or for callers that compose snapshots.
    static func build(context: ModelContext, dependencies: DependencyContainer) async -> WidgetSnapshot {
        let userRepo = dependencies.userRepository(context: context)
        let nutritionRepo = dependencies.nutritionRepository(context: context)
        let waterRepo = dependencies.waterRepository(context: context)

        let profile = (try? userRepo.profile()) ?? nil
        let meals = (try? nutritionRepo.meals(on: Date())) ?? []
        let waterMl = (try? waterRepo.totalWater(on: Date())) ?? 0
        let health = await dependencies.healthService.todaySnapshot()

        let totalKcal = meals.reduce(0) { $0 + $1.calories }
        let protein = meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
        let carbs = meals.reduce(0.0) { $0 + ($1.carbs ?? 0) }
        let fat = meals.reduce(0.0) { $0 + ($1.fat ?? 0) }
        let lastMeal = meals.max(by: { $0.createdAt < $1.createdAt })

        return WidgetSnapshot(
            generatedAt: Date(),
            caloriesConsumed: totalKcal,
            calorieTarget: profile?.dailyCalorieTarget ?? 1_900,
            caloriesBurned: Int(health.activeEnergy),
            proteinGrams: protein,
            proteinTargetGrams: Double(profile?.dailyProteinTargetGrams ?? 120),
            carbsGrams: carbs,
            carbsTargetGrams: Double(profile?.dailyCarbsTargetGrams ?? 210),
            fatGrams: fat,
            fatTargetGrams: Double(profile?.dailyFatTargetGrams ?? 65),
            waterMl: waterMl,
            waterTargetMl: profile?.dailyWaterTargetMl ?? 2_000,
            steps: health.steps,
            stepGoal: profile?.dailyStepTarget ?? 7_500,
            distanceKm: health.distanceKm,
            lastMealName: lastMeal?.name,
            lastMealLoggedAt: lastMeal?.createdAt,
            todayMealCount: meals.count,
            insight: composedInsight(meals: meals, water: waterMl, waterTarget: profile?.dailyWaterTargetMl ?? 2_000, steps: health.steps, stepGoal: profile?.dailyStepTarget ?? 7_500),
            displayName: profile?.name
        )
    }

    private static func composedInsight(meals: [MealEntry], water: Int, waterTarget: Int, steps: Int, stepGoal: Int) -> String {
        if steps >= stepGoal {
            return "Adım hedefin tamamlandı. Akşamı sakin kapatmak yeterli."
        }
        if water < waterTarget / 2 {
            return "Su tüketimin günün yarısının altında. Önündeki saatlerde küçük yudumlar dengeyi getirir."
        }
        if meals.isEmpty {
            return "Bugüne henüz başlamadın. Küçük bir öğün günü açabilir."
        }
        if steps > stepGoal / 2 {
            return "Bugün adım ritmin iyi. Akşam kısa bir yürüyüşle hedefi tamamla."
        }
        return "Bugün küçük bir yürüyüş molası ritmini toparlamana yardımcı olabilir."
    }
}
