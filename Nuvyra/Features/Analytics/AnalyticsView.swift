import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground(.animated)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    AnalyticsHeader(summary: viewModel.currentSummary)
                    WeeklyComparisonCard(comparison: viewModel.weeklyComparison)
                    AnalyticsSegmentedControl(selection: $viewModel.selectedPeriod)

                    analyticsState
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable {
                await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies)
            }
        }
        .navigationTitle("Analiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies) }
        }
    }

    @ViewBuilder
    private var analyticsState: some View {
        if viewModel.isLoading {
            AnalyticsLoadingState()
        } else if let errorMessage = viewModel.errorMessage {
            AnalyticsErrorState(message: errorMessage) {
                Task { await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies) }
            }
        } else if let summary = viewModel.currentSummary {
            if summary.isEmpty {
                AnalyticsEmptyState(period: viewModel.selectedPeriod)
            } else {
                AnalyticsContent(summary: summary)
            }
        } else {
            AnalyticsLoadingState()
        }
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
