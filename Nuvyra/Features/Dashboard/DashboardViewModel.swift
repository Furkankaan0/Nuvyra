import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var waterMl = 0
    @Published var healthSnapshot = HealthSnapshot.fallback
    @Published var isLoading = false
    private var didPlayStepGoalHaptic = false

    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 1_900 }
    var stepTarget: Int { profile?.dailyStepTarget ?? 7_500 }
    var waterTarget: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var remainingCalories: Int { max(calorieTarget - totalCalories + Int(healthSnapshot.activeEnergy), 0) }

    var nutritionSummary: DailyNutritionSummary {
        DailyNutritionSummary(
            consumed: totalCalories,
            burned: Int(healthSnapshot.activeEnergy),
            target: calorieTarget
        )
    }

    var macroSummaries: [MacroSummary] {
        let consumedProtein = meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
        let consumedCarbs = meals.reduce(0.0) { $0 + ($1.carbs ?? 0) }
        let consumedFat = meals.reduce(0.0) { $0 + ($1.fat ?? 0) }
        let proteinTarget = Double(profile?.dailyProteinTargetGrams ?? 120)
        let carbsTarget = Double(profile?.dailyCarbsTargetGrams ?? 210)
        let fatTarget = Double(profile?.dailyFatTargetGrams ?? 65)
        return [
            MacroSummary(kind: .protein, consumedGrams: consumedProtein, targetGrams: proteinTarget),
            MacroSummary(kind: .carbs, consumedGrams: consumedCarbs, targetGrams: carbsTarget),
            MacroSummary(kind: .fat, consumedGrams: consumedFat, targetGrams: fatTarget)
        ]
    }

    var waterSummary: WaterSummary {
        WaterSummary(consumedMl: waterMl, targetMl: waterTarget)
    }

    var stepSummary: StepSummary {
        StepSummary(
            steps: healthSnapshot.steps,
            goal: stepTarget,
            distanceKm: healthSnapshot.distanceKm,
            activeEnergyKcal: healthSnapshot.activeEnergy
        )
    }

    var recentFoods: [RecentFoodLog] {
        meals
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map(RecentFoodLog.init(from:))
    }

    var hasAnyData: Bool {
        !meals.isEmpty || waterMl > 0 || healthSnapshot.steps > 0
    }

    var insight: String {
        if !hasAnyData {
            return "Bugüne henüz başlamadın. İlk öğününü veya yürüyüşünü kaydederek ritmini görmeye başla."
        }
        if healthSnapshot.steps >= stepTarget && waterMl >= waterTarget {
            return "Bugün adım ve su hedeflerini tamamladın. Akşamı sakin kapatmak yeterli."
        }
        if healthSnapshot.steps >= stepTarget {
            return "Bugünkü yürüyüş ritmin tamamlandı. Su tüketimini de hedefe yaklaştırırsan günün dengeli kapanır."
        }
        if waterMl < waterTarget / 2 {
            return "Su tüketimin günün yarısının altında. Bir bardak su ile ritmini yumuşakça toparlayabilirsin."
        }
        if let proteinTarget = profile?.dailyProteinTargetGrams, totalProtein() < Double(proteinTarget) / 2 {
            return "Protein hedefinin yarısının altındasın. Akşam öğününe yumurta veya yoğurt eklemek dengeli bir kapanış olabilir."
        }
        if healthSnapshot.steps > stepTarget / 2 {
            return "Adım ritmin iyi gidiyor. Akşam kısa bir yürüyüşle hedefi rahat tamamlayabilirsin."
        }
        return "Bugün küçük bir yürüyüş molası ritmini toparlamana yardımcı olabilir."
    }

    private func totalProtein() -> Double {
        meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userRepository = dependencies.userRepository(context: context)
            let nutritionRepository = dependencies.nutritionRepository(context: context)
            let waterRepository = dependencies.waterRepository(context: context)
            let activityRepository = dependencies.activityRepository(context: context)
            profile = try userRepository.profile()
            meals = try nutritionRepository.meals(on: Date())
            waterMl = try waterRepository.totalWater(on: Date())
            healthSnapshot = await dependencies.healthService.todaySnapshot()
            try activityRepository.upsertWalkingSnapshot(date: Date(), steps: healthSnapshot.steps, activeEnergy: healthSnapshot.activeEnergy, distanceKm: healthSnapshot.distanceKm, goal: stepTarget)
            if healthSnapshot.steps >= stepTarget, !didPlayStepGoalHaptic {
                didPlayStepGoalHaptic = true
                dependencies.haptics.goalCompleted()
                await dependencies.analytics.track(.stepGoalCompleted, payload: AnalyticsPayload())
            } else if healthSnapshot.steps < stepTarget {
                didPlayStepGoalHaptic = false
            }
            await WidgetSnapshotPublisher.publish(context: context, dependencies: dependencies)
        } catch {
            healthSnapshot = .fallback
        }
    }

    func addWater(context: ModelContext, dependencies: DependencyContainer, amount: Int) async {
        do {
            try dependencies.waterRepository(context: context).addWater(amountMl: amount, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    func removeLatestWater(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let removed = try dependencies.waterRepository(context: context).removeLatestEntry(on: Date())
            if removed != nil {
                dependencies.haptics.waterAdded()
            }
            await load(context: context, dependencies: dependencies)
        } catch {}
    }
}
