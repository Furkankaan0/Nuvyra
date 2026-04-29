import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var waterMl = 0
    @Published var healthSnapshot = HealthSnapshot.fallback
    @Published var isLoading = false

    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 1_900 }
    var stepTarget: Int { profile?.dailyStepTarget ?? 7_500 }
    var waterTarget: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var remainingCalories: Int { max(calorieTarget - totalCalories + Int(healthSnapshot.activeEnergy), 0) }

    var insight: String {
        if healthSnapshot.steps >= stepTarget {
            return "Bugünkü yürüyüş ritmin tamamlandı. Akşamı sakin kapatmak yeterli."
        }
        if healthSnapshot.steps > stepTarget / 2 {
            return "Bugün adım ritmin iyi gidiyor. Akşam kısa bir yürüyüşle hedefi rahat tamamlayabilirsin."
        }
        if meals.isEmpty {
            return "İlk öğününü ekleyerek günün dengesini daha net görebilirsin."
        }
        return "Bugün küçük bir yürüyüş molası ritmini toparlamana yardımcı olabilir."
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
            if healthSnapshot.steps >= stepTarget {
                await dependencies.analytics.track(.stepGoalCompleted, payload: AnalyticsPayload())
            }
        } catch {
            healthSnapshot = .fallback
        }
    }

    func addWater(context: ModelContext, dependencies: DependencyContainer, amount: Int) async {
        do {
            try dependencies.waterRepository(context: context).addWater(amountMl: amount, date: Date())
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
            await load(context: context, dependencies: dependencies)
        } catch {}
    }
}
