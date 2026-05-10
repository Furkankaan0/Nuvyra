import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DashboardViewModel()
    @State private var presentAICoach = false
    @State private var presentWaterTracking = false

    private let waterQuickAdd = 250

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    DashboardHeroHeader(
                        userName: viewModel.profile?.name,
                        date: Date(),
                        insight: viewModel.insight,
                        onTapInsight: { presentAICoach = true }
                    )

                    CalorieHeroCard(summary: viewModel.nutritionSummary)

                    if viewModel.hasAnyData {
                        DashboardMacrosBar(macros: viewModel.macroSummaries)

                        DashboardMetricTilesRow(
                            water: viewModel.waterSummary,
                            step: viewModel.stepSummary,
                            protein: viewModel.macroSummaries.first(where: { $0.kind == .protein }),
                            onWaterTap: { presentWaterTracking = true },
                            onStepsTap: { router.selectedTab = .walking },
                            onProteinTap: { router.selectedTab = .nutrition }
                        )

                        DashboardMealsStrip(
                            meals: viewModel.meals,
                            onSelect: { _ in router.requestNutritionAction(.openAddMeal) },
                            onSeeAll: { router.selectedTab = .nutrition }
                        )
                    } else {
                        DashboardEmptyStateCard {
                            router.requestNutritionAction(.openAddMeal)
                        }
                    }

                    QuickActionsRail(actions: quickActions)
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.top, NuvyraSpacing.sm)
                .padding(.bottom, NuvyraSpacing.xxl)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.selectedTab = .profile
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                }
                .accessibilityLabel("Profil")
            }
        }
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .sheet(isPresented: $presentAICoach) {
            AICoachView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $presentWaterTracking, onDismiss: {
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }) {
            WaterTrackingView()
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Quick actions (3 essentials)

    private var quickActions: [DashboardQuickAction] {
        [
            DashboardQuickAction(title: "Yemek ekle", systemImage: "fork.knife", tint: NuvyraColors.accent) {
                router.requestNutritionAction(.openAddMeal)
            },
            DashboardQuickAction(title: "+250 ml", systemImage: "drop.fill", tint: Color(red: 0.30, green: 0.70, blue: 0.95)) {
                addWater()
            },
            DashboardQuickAction(title: "AI Coach", systemImage: "sparkles", tint: NuvyraColors.softSand) {
                presentAICoach = true
            }
        ]
    }

    private func addWater() {
        Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: waterQuickAdd) }
    }
}

#if DEBUG
#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}
#endif
