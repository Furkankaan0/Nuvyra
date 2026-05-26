import Foundation
import SwiftData
import WidgetKit

@MainActor
enum NuvyraWidgetSnapshotWriter {
    static func writeTodaySnapshot(context: ModelContext, healthService: HealthService) async {
        let today = Date()
        let profile = try? SwiftDataUserRepository(context: context).profile()
        let summary = (try? SwiftDataNutritionRepository(context: context).dailySummary(on: today)) ?? .empty
        let waterRepository = SwiftDataWaterRepository(context: context)
        let waterMl = (try? waterRepository.totalWater(on: today)) ?? 0
        let waterTarget = profile?.dailyWaterTargetMl ?? NuvyraWidgetSnapshot.empty.waterTargetMl
        let healthSnapshot = await healthService.todaySnapshot()
        let waterStreak = (try? waterRepository.waterStreak(daysBack: 60, targetMl: waterTarget)) ?? .empty
        let mealStreak = (try? SwiftDataNutritionRepository(context: context).mealStreak(daysBack: 60)) ?? .empty

        let snapshot = NuvyraWidgetSnapshot(
            snapshotDate: today,
            updatedAt: today,
            userName: profile?.name ?? NuvyraWidgetSnapshot.empty.userName,
            caloriesConsumed: summary.totals.calories,
            calorieTarget: profile?.dailyCalorieTarget ?? NuvyraWidgetSnapshot.empty.calorieTarget,
            caloriesBurned: Int(healthSnapshot.activeEnergy.rounded()),
            waterMl: waterMl,
            waterTargetMl: waterTarget,
            steps: healthSnapshot.steps,
            stepTarget: profile?.dailyStepTarget ?? NuvyraWidgetSnapshot.empty.stepTarget,
            proteinGrams: summary.totals.protein,
            proteinTargetGrams: profile?.dailyProteinTargetGrams ?? NuvyraWidgetSnapshot.empty.proteinTargetGrams,
            mealCount: summary.mealCount,
            waterStreakDays: waterStreak.currentStreak,
            mealStreakDays: mealStreak.currentStreak
        )

        NuvyraWidgetSnapshotStore.write(snapshot)
        reloadWidgetTimelines()
    }

    static func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: NuvyraWidgetSnapshotStore.widgetKind)
    }
}
