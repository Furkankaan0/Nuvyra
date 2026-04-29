import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Haftalık içgörüler", subtitle: "Sayıları suçlamadan, ritmini anlamak için oku.")
                    TrendCard(title: "Kalori", value: "\(viewModel.averageCalories) kcal", detail: "Bugünkü kayıt", systemImage: "flame")
                    TrendCard(title: "Adım", value: viewModel.averageSteps.formatted(), detail: "7 günlük ortalama", systemImage: "figure.walk")
                    TrendCard(title: "Su", value: "\(viewModel.waterAverage) ml", detail: "Bugünkü toplam", systemImage: "drop")
                    RhythmTrendCard(
                        calories: viewModel.averageCalories,
                        calorieTarget: 1_900,
                        steps: viewModel.averageSteps,
                        stepGoal: 7_500,
                        waterMl: viewModel.waterAverage,
                        waterTarget: 2_000
                    )
                    WeeklySummaryView(insight: viewModel.trendText)
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("İçgörü")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext, dependencies: dependencies) }
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
