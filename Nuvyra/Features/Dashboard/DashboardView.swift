import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dependencies: DependencyContainer
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = DashboardViewModel()

    @State private var presentedSheet: DashboardSheet?
    @State private var didAnimateAppearance = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    DashboardGreetingHeader(name: viewModel.greetingName, date: Date())
                        .padding(.top, NuvyraSpacing.xs)

                    CalorieBalanceCard(summary: viewModel.nutritionSummary)
                        .dashboardSlide(index: 0, animated: didAnimateAppearance)

                    MacroSummaryCard(macros: viewModel.macroSummaries)
                        .dashboardSlide(index: 1, animated: didAnimateAppearance)

                    QuickActionsCard { handle($0) }
                        .dashboardSlide(index: 2, animated: didAnimateAppearance)

                    NavigationLink(value: DashboardDestination.waterTracking) {
                        WaterCard(
                            summary: viewModel.waterSummary,
                            onAdd250: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) } },
                            onAdd500: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 500) } },
                            onRemove: { Task { await viewModel.removeLastWater(context: modelContext, dependencies: dependencies) } }
                        )
                    }
                    .buttonStyle(.plain)
                    .dashboardSlide(index: 3, animated: didAnimateAppearance)

                    StepRingCard(summary: viewModel.stepSummary) {
                        Task { await viewModel.startWalking(dependencies: dependencies) }
                    }
                    .dashboardSlide(index: 4, animated: didAnimateAppearance)

                    TodayMealsCard(meals: viewModel.meals) { type in
                        presentedSheet = .addMeal(type)
                    }
                    .dashboardSlide(index: 5, animated: didAnimateAppearance)

                    RecentFoodsCard(entries: viewModel.recentFoods) {
                        router.selectedTab = .nutrition
                    }
                    .dashboardSlide(index: 6, animated: didAnimateAppearance)

                    NavigationLink(value: DashboardDestination.coach) {
                        DailyInsightCard(text: viewModel.insight, onAskCoach: nil)
                    }
                    .buttonStyle(.plain)
                    .dashboardSlide(index: 7, animated: didAnimateAppearance)

                    if !viewModel.hasAnyData {
                        DashboardEmptyStateCard(
                            onAddFirstMeal: { presentedSheet = .addMeal(.breakfast) },
                            onAddWater: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) } }
                        )
                        .dashboardSlide(index: 8, animated: didAnimateAppearance)
                    }

                    Color.clear.frame(height: NuvyraSpacing.md)
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.bottom, NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }

            actionFeedbackOverlay
        }
        .navigationTitle("Nuvyra")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(context: modelContext, dependencies: dependencies)
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.78)) {
                didAnimateAppearance = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addMeal(let type):
                AddMealView(defaultMealType: type)
                    .presentationDetents([.large])
                    .onDisappear {
                        Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
                    }
            case .barcode:
                BarcodeScannerView(viewModel: makeBarcodeScannerViewModel()) { product in
                    Task {
                        await addScannedProduct(product)
                        presentedSheet = nil
                    }
                }
            }
        }
        .navigationDestination(for: DashboardDestination.self) { destination in
            switch destination {
            case .waterTracking:
                WaterTrackingView()
                    .onDisappear {
                        Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
                    }
            case .coach:
                AICoachView()
            }
        }
    }

    @ViewBuilder
    private var actionFeedbackOverlay: some View {
        if let feedback = viewModel.actionFeedback {
            VStack {
                Spacer()
                Text(feedback)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(NuvyraColors.accent.opacity(0.92), in: Capsule())
                    .shadow(color: NuvyraColors.accent.opacity(0.35), radius: 12, y: 6)
                    .padding(.bottom, NuvyraSpacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .allowsHitTesting(false)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.actionFeedback)
        }
    }

    private func handle(_ action: DashboardQuickAction) {
        switch action {
        case .addMeal:
            presentedSheet = .addMeal(currentMealSlot())
        case .scanBarcode:
            presentedSheet = .barcode
        case .voiceLog:
            // SiriKit / AppIntents donation; for now route to nutrition where users can speak via system voice input.
            router.selectedTab = .nutrition
        case .addWater:
            Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) }
        case .removeWater:
            Task { await viewModel.removeLastWater(context: modelContext, dependencies: dependencies) }
        case .startWalking:
            Task { await viewModel.startWalking(dependencies: dependencies) }
            router.selectedTab = .walking
        }
    }

    private func currentMealSlot() -> MealType {
        let hour = Calendar.nuvyra.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<22: return .dinner
        default: return .snack
        }
    }

    private func makeBarcodeScannerViewModel() -> BarcodeScannerViewModel {
        let client = HTTPClient()
        let providers: [any NutritionProvider] = [OpenFoodFactsProvider(client: client)]
        return BarcodeScannerViewModel(
            scanner: BarcodeScannerService(),
            api: NutritionAPIService(
                providers: providers,
                diskCache: try? ProductCacheService()
            )
        )
    }

    private func addScannedProduct(_ product: ScannedProduct) async {
        do {
            let meal = MealEntry(
                mealType: currentMealSlot(),
                name: product.name,
                calories: Int(product.caloriesPer100g.rounded()),
                protein: product.protein,
                carbs: product.carbs,
                fat: product.fat,
                portionDescription: "100 g - barkod",
                isFavorite: false,
                isVerifiedTurkishFood: product.source == .openFoodFacts,
                isEstimated: true
            )
            try dependencies.nutritionRepository(context: modelContext).addMeal(meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "dashboard_barcode"]))
            await viewModel.load(context: modelContext, dependencies: dependencies)
        } catch {
            await viewModel.load(context: modelContext, dependencies: dependencies)
        }
    }
}

private enum DashboardSheet: Identifiable {
    case addMeal(MealType)
    case barcode

    var id: String {
        switch self {
        case .addMeal(let type): "addMeal-\(type.rawValue)"
        case .barcode: "barcode"
        }
    }
}

enum DashboardDestination: Hashable {
    case waterTracking
    case coach
}

private struct DashboardSlideModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var index: Int
    var animated: Bool

    func body(content: Content) -> some View {
        content
            .opacity(animated ? 1 : 0)
            .offset(y: animated ? 0 : 14)
            .animation(
                reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(Double(index) * 0.05),
                value: animated
            )
    }
}

private extension View {
    func dashboardSlide(index: Int, animated: Bool) -> some View {
        modifier(DashboardSlideModifier(index: index, animated: animated))
    }
}

#Preview {
    NavigationStack { DashboardView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}
