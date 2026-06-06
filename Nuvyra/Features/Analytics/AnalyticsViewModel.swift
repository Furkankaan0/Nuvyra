import Combine
import Foundation
import SwiftData

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .weekly
    @Published private(set) var weeklySummary: WeeklySummary?
    @Published private(set) var monthlySummary: MonthlySummary?
    @Published private(set) var weeklyComparison: WeeklyComparison = .empty
    @Published private(set) var weeklyGoals: WeeklyGoalSummary = .empty
    @Published private(set) var trendInsights: [TrendInsight] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var currentSummary: AnalyticsSummary? {
        switch selectedPeriod {
        case .weekly:
            weeklySummary?.analytics
        case .monthly:
            monthlySummary?.analytics
        }
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let repository = dependencies.analyticsRepository(context: context)
            weeklySummary = try repository.weeklySummary()
            monthlySummary = try repository.monthlySummary()
        } catch {
            errorMessage = "Analiz verileri yüklenemedi. Lütfen tekrar dene."
        }

        // 14-day this-vs-prior comparison shares the Dashboard engine so the
        // user sees the exact same storyline on both screens. We intentionally
        // do not fail the whole screen if this fetch errors — the summary
        // charts are still useful on their own.
        let nutritionRepository = dependencies.nutritionRepository(context: context)
        let waterRepository = dependencies.waterRepository(context: context)
        let activityRepository = dependencies.activityRepository(context: context)
        weeklyComparison = (try? dependencies.weeklyInsightEngine.computeComparison(
            nutrition: nutritionRepository,
            water: waterRepository,
            activity: activityRepository,
            endingOn: Date()
        )) ?? .empty

        // Goal completion + trend patterns mirror the dashboard so the
        // Insights tab is a single, fuller home for the same signals.
        let profile = try? dependencies.userRepository(context: context).profile()
        let mealStreak = (try? nutritionRepository.mealStreak(daysBack: 60)) ?? .empty
        let waterTarget = profile?.dailyWaterTargetMl ?? 2_000
        let waterStreak = (try? waterRepository.waterStreak(daysBack: 60, targetMl: waterTarget)) ?? .empty

        weeklyGoals = (try? dependencies.weeklyGoalEngine.summary(
            nutrition: nutritionRepository,
            water: waterRepository,
            activity: activityRepository,
            profile: profile,
            mealStreak: mealStreak,
            waterStreak: waterStreak,
            endingOn: Date()
        )) ?? .empty

        trendInsights = (try? dependencies.trendInsightEngine.detect(
            nutrition: nutritionRepository,
            water: waterRepository,
            activity: activityRepository,
            profile: profile,
            endingOn: Date()
        )) ?? []
    }

    func reloadSelectedPeriod(context: ModelContext, dependencies: DependencyContainer) async {
        guard !isLoading else { return }
        await load(context: context, dependencies: dependencies)
    }
}
