import Combine
import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var waterMl = 0
    @Published var healthSnapshot = HealthSnapshot.fallback
    @Published var isLoading = false
    @Published var lastUpdated: Date = Date()
    @Published var actionFeedback: String?

    private var didPlayStepGoalHaptic = false

    // MARK: - Targets
    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 1_900 }
    var stepTarget: Int { profile?.dailyStepTarget ?? 7_500 }
    var waterTarget: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var proteinTarget: Double { Double(profile?.dailyProteinTargetGrams ?? 120) }
    var carbsTarget: Double { Double(profile?.dailyCarbsTargetGrams ?? 210) }
    var fatTarget: Double { Double(profile?.dailyFatTargetGrams ?? 65) }

    // MARK: - Totals
    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { meals.reduce(0) { $0 + ($1.protein ?? 0) } }
    var totalCarbs: Double { meals.reduce(0) { $0 + ($1.carbs ?? 0) } }
    var totalFat: Double { meals.reduce(0) { $0 + ($1.fat ?? 0) } }
    var remainingCalories: Int { max(calorieTarget - totalCalories + Int(healthSnapshot.activeEnergy), 0) }

    var hasAnyData: Bool { !meals.isEmpty || waterMl > 0 || healthSnapshot.steps > 0 }
    var greetingName: String { profile?.name.isEmpty == false ? profile!.name : "Hoş geldin" }

    // MARK: - Summaries
    var nutritionSummary: DailyNutritionSummary {
        DailyNutritionSummary(
            consumedCalories: totalCalories,
            burnedCalories: Int(healthSnapshot.activeEnergy.rounded()),
            targetCalories: calorieTarget
        )
    }

    var macroSummaries: [MacroSummary] {
        [
            MacroSummary(kind: .protein, consumedGrams: totalProtein, targetGrams: proteinTarget),
            MacroSummary(kind: .carbs, consumedGrams: totalCarbs, targetGrams: carbsTarget),
            MacroSummary(kind: .fat, consumedGrams: totalFat, targetGrams: fatTarget)
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
            activeEnergy: healthSnapshot.activeEnergy
        )
    }

    var recentFoods: [RecentFoodLog] {
        meals
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map(RecentFoodLog.init(meal:))
    }

    // MARK: - AI insight (lightweight, on-device, non-medical)
    var insight: String {
        let summary = nutritionSummary
        let water = waterSummary
        let steps = stepSummary
        let proteinShortfall = max(proteinTarget - totalProtein, 0)

        if !hasAnyData {
            return "Güne başlamak için bir öğün veya bir bardak su kaydı eklemen yeterli. Nuvyra ritmini buradan okuyacak."
        }
        if steps.isGoalReached && water.isGoalReached && summary.consumedCalories >= summary.targetCalories - 200 {
            return "Bugünkü ritmin oldukça dengeli. Akşamı sakin geçirmek vücudunun toparlanmasına yardım eder."
        }
        if proteinShortfall > 30 {
            return "Protein hedefine ulaşmak için \(Int(proteinShortfall)) g daha alabilirsin — ızgara tavuk, yoğurt veya yumurta iyi bir seçim olabilir."
        }
        if !water.isGoalReached, water.remainingMl >= 500 {
            return "Su tüketimin biraz geride. \(water.remainingMl) ml daha içmen günü dengelemene yardım eder."
        }
        if !steps.isGoalReached, steps.remaining > 0 {
            return "Hedefe \(steps.remaining.formatted()) adım kaldı — 15-20 dakikalık tempolu bir yürüyüş bunu rahatça tamamlar."
        }
        return "Bugünkü dengeni korumak için küçük bir yürüyüş veya bir bardak daha su iyi gelecek."
    }

    // MARK: - Load
    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }
        do {
            let userRepository = dependencies.userRepository(context: context)
            let nutritionRepository = dependencies.nutritionRepository(context: context)
            let waterRepository = dependencies.waterRepository(context: context)
            let activityRepository = dependencies.activityRepository(context: context)
            profile = try userRepository.profile()
            meals = try nutritionRepository.meals(on: Date())
            waterMl = try waterRepository.totalWater(on: Date())
            healthSnapshot = await dependencies.healthService.todaySnapshot()
            try activityRepository.upsertWalkingSnapshot(
                date: Date(),
                steps: healthSnapshot.steps,
                activeEnergy: healthSnapshot.activeEnergy,
                distanceKm: healthSnapshot.distanceKm,
                goal: stepTarget
            )
            if healthSnapshot.steps >= stepTarget, !didPlayStepGoalHaptic {
                didPlayStepGoalHaptic = true
                dependencies.haptics.goalCompleted()
                await dependencies.analytics.track(.stepGoalCompleted, payload: AnalyticsPayload())
            } else if healthSnapshot.steps < stepTarget {
                didPlayStepGoalHaptic = false
            }
        } catch {
            healthSnapshot = .fallback
        }
    }

    // MARK: - Actions
    func addWater(context: ModelContext, dependencies: DependencyContainer, amount: Int) async {
        do {
            try dependencies.waterRepository(context: context).addWater(amountMl: amount, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
            await load(context: context, dependencies: dependencies)
            flash("+\(amount) ml eklendi")
        } catch {}
    }

    func removeLastWater(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let removed = try dependencies.waterRepository(context: context).removeLastEntry(on: Date())
            if removed > 0 {
                dependencies.haptics.waterAdded()
                flash("-\(removed) ml geri alındı")
            }
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    func startWalking(dependencies: DependencyContainer) async {
        dependencies.haptics.walkStarted()
        await dependencies.walkingLiveActivityService.start(goal: stepTarget, initialSteps: healthSnapshot.steps)
        flash("Yürüyüş odağı başlatıldı")
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}
