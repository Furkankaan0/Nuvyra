import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dependencies: DependencyContainer
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var toastCenter: NuvyraToastCenter
    @StateObject private var viewModel = DashboardViewModel()

    @State private var presentedSheet: DashboardSheet?
    @State private var didAnimateAppearance = false
    /// Phase 7 — barcode tarama sonrası rich `FoodItem` portion picker'ı için.
    @State private var pendingBarcodeItem: FoodItem?

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    DashboardGreetingHeader(name: viewModel.greetingName, date: Date())
                        .padding(.top, NuvyraSpacing.xs)

                    // First-launch skeleton: shown only while the initial
                    // repository fetch is in flight *and* there's no
                    // local data yet. Prevents the "zero everywhere"
                    // flash that used to happen on the first second
                    // after sign-up.
                    if viewModel.isLoading && !viewModel.hasAnyData && viewModel.profile == nil {
                        NuvyraCardSkeleton(style: .hero)
                        NuvyraCardSkeleton(style: .strip)
                    }

                    if viewModel.shouldShowDayOneTour {
                        DayOneTourCard(
                            completed: viewModel.dayOneCompletedSteps,
                            onTapStep: { step in
                                switch step {
                                case .firstMeal:
                                    presentedSheet = .addMeal(.breakfast)
                                case .firstWater:
                                    Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 200) }
                                case .viewSteps:
                                    router.selectedTab = .walking
                                }
                            },
                            onDismiss: { viewModel.dismissDayOneTour(context: modelContext) }
                        )
                        .dashboardSlide(index: 0, animated: didAnimateAppearance)
                    }

                    // Single-glance "ritim skoru" hero — same numerical
                    // weighting as the lock-screen widget so the dashboard
                    // and the lock screen always agree.
                    DashboardRhythmHero(
                        summary: viewModel.nutritionSummary,
                        water: viewModel.waterSummary,
                        steps: viewModel.stepSummary,
                        proteinGrams: viewModel.totalProtein,
                        proteinTargetGrams: viewModel.proteinTarget
                    )
                    .dashboardSlide(index: 1, animated: didAnimateAppearance)

                    CalorieBalanceCard(summary: viewModel.nutritionSummary)
                        .dashboardSlide(index: 2, animated: didAnimateAppearance)

                    EnergyBalanceCard(balance: viewModel.energyBalance)
                        .dashboardSlide(index: 3, animated: didAnimateAppearance)

                    MacroSummaryCard(macros: viewModel.macroSummaries)
                        .dashboardSlide(index: 4, animated: didAnimateAppearance)

                    QuickActionsCard { handle($0) }
                        .dashboardSlide(index: 4, animated: didAnimateAppearance)

                    NavigationLink(value: DashboardDestination.waterTracking) {
                        WaterCard(
                            summary: viewModel.waterSummary,
                            onAdd250: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) } },
                            onAdd500: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 500) } },
                            onRemove: { Task { await viewModel.removeLastWater(context: modelContext, dependencies: dependencies) } }
                        )
                    }
                    // NavigationLink-wrapped cards use *only* press tilt.
                    // Stacking scrollTilt on top adds a second X-axis
                    // rotation3DEffect that conflicts with the tap-down
                    // tilt and reads as a jitter while the card scrolls.
                    .buttonStyle(.nuvyraPressTilt)
                    .dashboardSlide(index: 5, animated: didAnimateAppearance)

                    StepRingCard(summary: viewModel.stepSummary) {
                        Task { await viewModel.startWalking(dependencies: dependencies) }
                    }
                    .dashboardSlide(index: 6, animated: didAnimateAppearance)

                    TodayMealsCard(meals: viewModel.meals) { type in
                        presentedSheet = .addMeal(type)
                    }
                    .dashboardSlide(index: 7, animated: didAnimateAppearance)

                    MealTimingCard(insight: viewModel.mealTiming) { type in
                        presentedSheet = .addMeal(type)
                    }
                    .dashboardSlide(index: 8, animated: didAnimateAppearance)

                    RecentFoodsCard(entries: viewModel.recentFoods) {
                        router.selectedTab = .nutrition
                    }
                    .dashboardSlide(index: 9, animated: didAnimateAppearance)

                    WeeklyComparisonCard(comparison: viewModel.weeklyComparison)
                        .dashboardSlide(index: 10, animated: didAnimateAppearance)

                    SleepHeartCard(vitals: viewModel.vitals)
                        .dashboardSlide(index: 10, animated: didAnimateAppearance)

                    TrendInsightCard(insights: viewModel.trendInsights)
                        .dashboardSlide(index: 10, animated: didAnimateAppearance)

                    if viewModel.weightSummary.latestWeightKg != nil {
                        NavigationLink(value: DashboardDestination.bodyMeasurements) {
                            WeightTrendCard(
                                summary: viewModel.weightSummary,
                                targetWeightKg: viewModel.profile?.targetWeightKg,
                                onAddMeasurement: { router.selectedTab = .profile }
                            )
                        }
                        .buttonStyle(.nuvyraPressTilt)
                        .dashboardSlide(index: 11, animated: didAnimateAppearance)
                    }

                    VStack(spacing: NuvyraSpacing.md) {
                        StreakCard(kind: .meal, insight: viewModel.mealStreak)
                        StreakCard(kind: .water, insight: viewModel.waterStreak)
                    }
                    .dashboardSlide(index: 12, animated: didAnimateAppearance)

                    if let achievement = viewModel.shareableAchievement {
                        AchievementShareCard(achievement: achievement)
                            .dashboardSlide(index: 13, animated: didAnimateAppearance)
                    }

                    NavigationLink(value: DashboardDestination.coach) {
                        DailyInsightCard(text: viewModel.insight, onAskCoach: nil)
                    }
                    .buttonStyle(.nuvyraPressTilt)
                    .dashboardSlide(index: 14, animated: didAnimateAppearance)

                    if !viewModel.shouldShowDayOneTour && !viewModel.hasAnyData {
                        DashboardEmptyStateCard(
                            onAddFirstMeal: { presentedSheet = .addMeal(.breakfast) },
                            onAddWater: { Task { await viewModel.addWater(context: modelContext, dependencies: dependencies, amount: 250) } }
                        )
                        .dashboardSlide(index: 15, animated: didAnimateAppearance)
                    }

                    Color.clear.frame(height: NuvyraSpacing.md)
                }
                .padding(.horizontal, NuvyraSpacing.lg)
                .padding(.bottom, NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies, force: true) }
        }
        .navigationTitle("Nuvyra")
        .navigationBarTitleDisplayMode(.inline)
        // Forward the view model's action feedback into the shared toast
        // centre. Keeps the view model toast-agnostic (no DI bloat) while
        // moving the user-facing flash to the brand renderer.
        .onChange(of: viewModel.actionFeedback) { _, message in
            guard let message else { return }
            toastCenter.success(message)
            viewModel.actionFeedback = nil
        }
        .onChange(of: viewModel.shouldShowVitalsPermissionToast) { _, shouldShow in
            guard shouldShow else { return }
            viewModel.markVitalsPermissionToastShown(context: modelContext)
            toastCenter.warning(
                "Apple Sağlık'a izin ver",
                detail: "Uyku ve istirahat nabzını toparlanma kartında gösterebiliriz.",
                action: NuvyraToast.Action(title: "İzin ver") {
                    Task { @MainActor in
                        await viewModel.requestVitalsAuthorization(context: modelContext, dependencies: dependencies)
                    }
                }
            )
        }
        .task {
            await viewModel.load(context: modelContext, dependencies: dependencies)
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.78)) {
                didAnimateAppearance = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .sheet(item: $viewModel.pendingUpsell) { trigger in
            BehavioralPaywallSheet(
                trigger: trigger,
                onExplorePremium: {
                    viewModel.acknowledgeUpsell(trigger, context: modelContext)
                    router.selectedTab = .profile
                },
                onDismiss: { viewModel.acknowledgeUpsell(trigger, context: modelContext) }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addMeal(let type):
                AddMealView(defaultMealType: type)
                    .presentationDetents([.large])
                    .onDisappear {
                        Task { await viewModel.load(context: modelContext, dependencies: dependencies, force: true) }
                    }
            case .barcode:
                BarcodeScannerView(viewModel: makeBarcodeScannerViewModel()) { product in
                    Task {
                        await handleScannedProduct(product)
                        presentedSheet = nil
                    }
                }
            }
        }
        .sheet(item: $pendingBarcodeItem, onDismiss: { Task { await viewModel.load(context: modelContext, dependencies: dependencies, force: true) } }) { item in
            FoodDetailView(item: item) { values, serving, quantity in
                let selection = FoodSelection(item: item, values: values, serving: serving, quantity: quantity)
                Task { await addFoodSelection(selection) }
            }
        }
        .navigationDestination(for: DashboardDestination.self) { destination in
            switch destination {
            case .waterTracking:
                WaterTrackingView()
                    .onDisappear {
                        Task { await viewModel.load(context: modelContext, dependencies: dependencies, force: true) }
                    }
            case .coach:
                AICoachView()
            case .bodyMeasurements:
                BodyMeasurementsView()
                    .onDisappear {
                        Task { await viewModel.load(context: modelContext, dependencies: dependencies, force: true) }
                    }
            }
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
        return BarcodeScannerViewModel(
            scanner: BarcodeScannerService(),
            api: NutritionAPIService(
                providers: FoodDataProviderFactory.barcodeProviders(client: client),
                diskCache: try? ProductCacheService()
            )
        )
    }

    /// Phase 7 — barcode tarama sonucunu rich `FoodItem`'a yükselt, cache
    /// et ve `FoodDetailView` portion picker'ını tetikle. Phase 13 —
    /// veri sparse ise AI ile zenginleştir (aynı patern NutritionView'de).
    private func handleScannedProduct(_ product: ScannedProduct) async {
        var item = FoodItem.from(scannedProduct: product)

        let needsEnrichment = item.caloriesPer100g == 0
            || (item.proteinPer100g + item.carbsPer100g + item.fatPer100g) == 0
        if needsEnrichment {
            let query: String = {
                let countryHint = BarcodeNormalizer.countryHint(for: product.barcode)
                let countryClause = countryHint.isEmpty ? "" : " (\(countryHint) menşeli)"
                if !product.name.isEmpty && product.name != "Bilinmeyen Ürün" {
                    if let brand = product.brand, !brand.isEmpty {
                        return "\(brand) \(product.name)\(countryClause)"
                    }
                    return "\(product.name)\(countryClause)"
                }
                if let brand = product.brand, !brand.isEmpty {
                    return "\(brand) ürünü\(countryClause) — barkod \(product.barcode)"
                }
                if !countryHint.isEmpty {
                    return "\(countryHint) gıda ürünü (barkod \(product.barcode)) — bu ülkede yaygın bir gıda yorumu yap"
                }
                return "Gıda ürünü (barkod \(product.barcode)) — yaygın bir yorum yap"
            }()
            if let est = try? await dependencies.foodIntelligenceService
                .estimateFromText(query, mealType: currentMealSlot())
                .first {
                item = FoodItem(
                    id: item.id,
                    source: item.source,
                    externalID: item.externalID,
                    name: (item.name == "Bilinmeyen Ürün" || item.name.isEmpty) ? est.name : item.name,
                    localizedNameTR: (item.localizedNameTR == "Bilinmeyen Ürün" || item.localizedNameTR == nil) ? est.name : item.localizedNameTR,
                    brand: item.brand,
                    barcode: product.barcode,
                    imageURL: item.imageURL,
                    category: item.category,
                    subCategory: item.subCategory,
                    servingSizes: [
                        .hundredGrams,
                        ServingSize(label: est.portion, labelTR: est.portion, grams: est.portionGrams, isDefault: true)
                    ],
                    nutritionPer100g: NutritionValues(
                        calories: est.calories,
                        protein: est.protein,
                        carbs: est.carbs,
                        fat: est.fat,
                        fiber: est.fiber ?? 0,
                        sodium: est.sodium ?? 0,
                        sugar: est.sugar ?? 0,
                        saturatedFat: est.saturatedFat ?? 0
                    ),
                    micronutrients: item.micronutrients,
                    ingredients: item.ingredients,
                    allergens: item.allergens,
                    additives: item.additives,
                    nutriScore: item.nutriScore,
                    novaGroup: item.novaGroup,
                    verifiedLevel: .approximate,
                    confidenceScore: max(0.5, est.confidence),
                    lastUpdated: Date()
                )
            }
        }

        await dependencies.foodRepository.cacheItem(item)
        pendingBarcodeItem = item
    }

    /// FoodDetailView confirm callback — scaled values ile MealEntry yaratır,
    /// repo usage tracking + analytics + health save. NutritionViewModel'in
    /// addFoodSelection'unun Dashboard varyantı (currentMealSlot kullanır).
    private func addFoodSelection(_ selection: FoodSelection) async {
        let item = selection.item
        let values = selection.values
        do {
            let meal = MealEntry(
                mealType: currentMealSlot(),
                name: item.preferredDisplayName,
                calories: values.calories,
                protein: values.protein > 0 ? values.protein : nil,
                carbs: values.carbs > 0 ? values.carbs : nil,
                fat: values.fat > 0 ? values.fat : nil,
                portionDescription: selection.portionDescription,
                isFavorite: false,
                isVerifiedTurkishFood: item.verifiedLevel == .verified,
                isEstimated: item.verifiedLevel != .verified,
                fiberGrams: values.fiber > 0 ? values.fiber : nil,
                sodiumMg: values.sodium > 0 ? values.sodium : nil,
                sugarGrams: values.sugar > 0 ? values.sugar : nil,
                saturatedFatGrams: values.saturatedFat > 0 ? values.saturatedFat : nil
            )
            try dependencies.nutritionRepository(context: modelContext).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            await syncSavedMeal(meal)
            dependencies.haptics.mealLogged()

            if let rowID = selection.deterministicRowID {
                await dependencies.foodRepository.recordUse(id: rowID)
            }

            await dependencies.analytics.track(
                .mealAdded,
                payload: AnalyticsPayload(values: [
                    "source": "dashboard_food_detail",
                    "provider": item.source.rawValue,
                    "verified": item.verifiedLevel.rawValue
                ])
            )
            await viewModel.load(context: modelContext, dependencies: dependencies, force: true)
        } catch {
            await viewModel.load(context: modelContext, dependencies: dependencies, force: true)
        }
    }

    private func syncSavedMeal(_ meal: MealEntry) async {
        do {
            try await dependencies.cloudSyncService.push(meal)
        } catch {
            NuvyraSyncToastRouter.handle(error, centre: toastCenter)
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
    case bodyMeasurements
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
        .environmentObject(NuvyraToastCenter())
}
