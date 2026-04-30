import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    TodaySummaryCard(title: "Bugünkü ritmin", date: Date())
                    if let banner = viewModel.dataIssueBanner {
                        NuvyraDataIssueBanner(banner: banner) {
                            Task { await viewModel.retryHealth(context: modelContext, dependencies: dependencies) }
                        }
                    }
                    CalorieBalanceCard(consumed: viewModel.totalCalories, burned: Int(viewModel.healthSnapshot.activeEnergy), target: viewModel.calorieTarget, remaining: viewModel.remainingCalories)
                    StepRingCard(steps: viewModel.healthSnapshot.steps, goal: viewModel.stepTarget)
                    WaterCard(waterMl: viewModel.waterMl, targetMl: viewModel.waterTarget) {
                        Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) }
                    } onAdd500: {
                        Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 500) }
                    }
                    RhythmTrendCard(
                        calories: viewModel.totalCalories,
                        calorieTarget: viewModel.calorieTarget,
                        steps: viewModel.healthSnapshot.steps,
                        stepGoal: viewModel.stepTarget,
                        waterMl: viewModel.waterMl,
                        waterTarget: viewModel.waterTarget
                    )
                    mealSlots
                    DailyInsightCard(text: viewModel.insight)
                    premiumTeaser
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("Nuvyra")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
    }

    private var mealSlots: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            NuvyraSectionHeader(title: "Öğünler", subtitle: "Kalori değerleri tahminidir.")
            ForEach(MealType.allCases) { type in
                let meal = viewModel.meals.first { $0.mealType == type }
                NuvyraCard {
                    HStack {
                        Label(type.title, systemImage: type.systemImage)
                            .font(NuvyraTypography.section)
                        Spacer()
                        if let meal {
                            Text("\(meal.calories) kcal")
                                .font(.headline.weight(.bold))
                        } else {
                            Button("Ekle") { router.selectedTab = .nutrition }
                                .font(.headline.weight(.semibold))
                        }
                    }
                    if let meal {
                        Text(meal.name)
                            .font(NuvyraTypography.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var premiumTeaser: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Haftalık trendlerini daha detaylı görmek ister misin?")
                    .font(NuvyraTypography.section)
                Text("Premium ile yürüyüş, su ve öğün ritmini daha net oku.")
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: "Premium'u keşfet", systemImage: "crown") {
                    router.selectedTab = .profile
                }
            }
        }
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}
