import Combine
import Foundation
import SwiftData

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: AnalyticsPeriod = .weekly
    @Published private(set) var weeklySummary: WeeklySummary?
    @Published private(set) var monthlySummary: MonthlySummary?
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
    }

    func reloadSelectedPeriod(context: ModelContext, dependencies: DependencyContainer) async {
        guard !isLoading else { return }
        await load(context: context, dependencies: dependencies)
    }
}
