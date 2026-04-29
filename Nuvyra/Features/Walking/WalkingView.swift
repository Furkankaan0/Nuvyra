import SwiftData
import SwiftUI

struct WalkingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = WalkingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Yürüyüş", subtitle: "Bugün düşük tempoda kalmak da sorun değil. Devamlılık daha önemli.")
                    StepGoalCard(steps: viewModel.snapshot.steps, goal: viewModel.stepGoal, remaining: viewModel.remainingSteps)
                    WalkingStreakCard(streak: viewModel.streak, averageSteps: viewModel.averageSteps, completionRate: viewModel.completionRate)
                    WeeklyStepsChart(logs: viewModel.logs, goal: viewModel.stepGoal)
                    NuvyraGlassCard {
                        Label("Yürüyüş önerisi", systemImage: "figure.walk.motion")
                            .font(NuvyraTypography.section)
                        Text(viewModel.insight)
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.snapshot.source != .healthKit {
                        NuvyraCard {
                            Text("Manuel mod")
                                .font(NuvyraTypography.section)
                            Text("Apple Health izni yoksa uygulama kırılmaz. Adım verisi CoreMotion veya manuel moda düşer.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("Yürüyüş")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
    }
}

#Preview {
    NavigationStack { WalkingView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
