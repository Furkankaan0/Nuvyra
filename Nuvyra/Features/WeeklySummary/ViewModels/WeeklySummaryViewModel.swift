import Foundation

@MainActor
final class WeeklySummaryViewModel: ObservableObject {
    func markOpened(appState: AppState) async {
        await appState.environment.analytics.track(AnalyticsEvent(.weeklySummaryOpened))
    }
}
