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
                    if let banner = viewModel.dataIssueBanner {
                        NuvyraDataIssueBanner(banner: banner) {
                            Task { await viewModel.retryHealth(context: modelContext, dependencies: dependencies) }
                        }
                    }
                    StepGoalCard(steps: viewModel.snapshot.steps, goal: viewModel.stepGoal, remaining: viewModel.remainingSteps)
                    WalkingFocusCard(
                        isActive: viewModel.walkingFocusActive,
                        motionState: viewModel.motionState,
                        elapsedMinutes: viewModel.focusElapsedMinutes,
                        onStart: { Task { await viewModel.startWalkingFocus(dependencies: dependencies) } },
                        onEnd: { Task { await viewModel.endWalkingFocus(dependencies: dependencies) } }
                    )
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
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
    }
}

#Preview {
    NavigationStack { WalkingView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}

private struct WalkingFocusCard: View {
    @Environment(\.colorScheme) private var scheme
    var isActive: Bool
    var motionState: MotionActivityState
    var elapsedMinutes: Int
    var onStart: () -> Void
    var onEnd: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    Label(isActive ? "Yürüyüş odağı açık" : "Yürüyüş odağı", systemImage: "figure.walk.motion")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Spacer()
                    Text(isActive ? "\(elapsedMinutes) dk" : motionState.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                Text(isActive ? "Live Activity ile Kilit Ekranı ve Dynamic Island’da yürüyüş ritmini takip et." : "Kısa yürüyüşü başlat; Nuvyra hedefini nazikçe görünür tutar.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                if isActive {
                    NuvyraSecondaryButton(title: "Yürüyüşü bitir", systemImage: "stop.circle", action: onEnd)
                } else {
                    NuvyraPrimaryButton(title: "Yürüyüş başlat", systemImage: "play.fill", action: onStart)
                }
            }
        }
    }
}
