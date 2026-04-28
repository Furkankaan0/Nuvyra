import Foundation

@MainActor
final class WalkingViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var recommendation: StepGoalRecommendation?

    func refresh(appState: AppState) async {
        isRefreshing = true
        await appState.refreshSteps()
        recommendation = StepGoalAdapter().adaptedGoal(currentGoal: appState.stepSnapshot.goal, recentDays: appState.stepHistory)
        isRefreshing = false
    }
}
