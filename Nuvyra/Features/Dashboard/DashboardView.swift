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
                    DashboardHeroHeader(userName: viewModel.profile?.name, date: Date())

                    CalorieHeroCard(summary: viewModel.nutritionSummary)

                    QuickActionsRail(actions: quickActions)

                    if viewModel.hasAnyData {
                        MacroRowSection(macros: viewModel.macroSummaries)

                        WaterStepRow(
                            water: viewModel.waterSummary,
                            step: viewModel.stepSummary,
                            onAddWater: { addWater() },
                            onRemoveWater: { removeWater() },
                            onWaterDetail: { presentWaterTracking = true }
                        )

                        MealsTodaySection(meals: viewModel.meals) { mealType in
                            router.requestNutritionAction(.openAddMeal)
                        }

                        RecentFoodsSection(items: viewModel.recentFoods) {
                            router.selectedTab = .nutrition
                        }
                    } else {
                        DashboardEmptyStateCard {
                            router.requestNutritionAction(.openAddMeal)
                        }
                    }

                    AIInsightTeaserCard(insight: viewModel.insight) {
                        presentAICoach = true
                    }

                    premiumTeaser
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.top, NuvyraSpacing.md)
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
                    Image(systemName: "person.crop.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NuvyraColors.accent)
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
        }
        .sheet(isPresented: $presentWaterTracking, onDismiss: {
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }) {
            WaterTrackingView()
        }
    }

    private var quickActions: [DashboardQuickAction] {
        [
            DashboardQuickAction(title: "Yemek ekle", systemImage: "fork.knife", tint: NuvyraColors.accent) {
                router.requestNutritionAction(.openAddMeal)
            },
            DashboardQuickAction(title: "Barkod tara", systemImage: "barcode.viewfinder", tint: NuvyraColors.softSand) {
                router.requestNutritionAction(.openBarcodeScanner)
            },
            DashboardQuickAction(title: "Sesle ekle", systemImage: "mic.fill", tint: NuvyraColors.mutedCoral) {
                router.requestNutritionAction(.openVoiceEntry)
            },
            DashboardQuickAction(title: "Su ekle", systemImage: "drop.fill", tint: Color(red: 0.30, green: 0.70, blue: 0.95)) {
                addWater()
            },
            DashboardQuickAction(title: "Su azalt", systemImage: "drop", tint: Color(red: 0.30, green: 0.70, blue: 0.95).opacity(0.7)) {
                removeWater()
            },
            DashboardQuickAction(title: "Yürüyüş", systemImage: "figure.walk", tint: NuvyraColors.paleLime) {
                router.selectedTab = .walking
            }
        ]
    }

    private var premiumTeaser: some View {
        Group {
            if !dependencies.subscriptionManager.isPremium {
                NuvyraGlassCard {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill").foregroundStyle(NuvyraColors.softSand)
                            Text("Premium ile derinleş")
                                .font(NuvyraTypography.section)
                        }
                        Text("Haftalık trendler, gelişmiş içgörüler ve sınırsız AI Coach soruları.")
                            .foregroundStyle(.secondary)
                        NuvyraSecondaryButton(title: "Premium'u keşfet", systemImage: "sparkles") {
                            router.selectedTab = .profile
                        }
                    }
                }
            }
        }
    }

    private func addWater() {
        Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: waterQuickAdd) }
    }

    private func removeWater() {
        Task { await viewModel.removeLatestWater(context: modelContext, dependencies: dependencies) }
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
