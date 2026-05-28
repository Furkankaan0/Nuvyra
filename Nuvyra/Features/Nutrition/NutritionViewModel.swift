import Combine
import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var summary: DailyMealSummary = .empty
    @Published var streak: StreakInsight = .empty
    @Published var selectedMealType: MealType = .breakfast
    @Published var selectedDate: Date = Date()
    @Published var showingAddMeal = false
    @Published var showingCamera = false
    @Published var showingBarcodeScanner = false
    @Published var showingFoodSearch = false
    @Published var editingMeal: MealEntry?
    /// Barcode tarama başarılı olunca burası set olur ve view bunu
    /// `.sheet(item:)` ile `FoodDetailView` olarak açar. Portion picker
    /// sonrası `addFoodSelection` üzerinden öğüne dönüşür.
    @Published var pendingBarcodeItem: FoodItem?
    @Published var errorMessage: String?
    @Published var smartMealText = ""
    @Published var estimatedResults: [EstimatedMealResult] = []
    @Published var isEstimating = false
    @Published var actionFeedback: String?

    var sectionedMeals: [(MealType, [MealEntry])] {
        MealType.allCases.map { type in
            (type, meals.filter { $0.mealType == type })
        }
    }

    var isViewingToday: Bool {
        Calendar.nuvyra.isDateInToday(selectedDate)
    }

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.nutritionRepository(context: context)
            meals = try repository.meals(on: selectedDate)
            favorites = try repository.favoriteMeals()
            summary = try repository.dailySummary(on: selectedDate)
            profile = try? dependencies.userRepository(context: context).profile()
            streak = (try? repository.mealStreak(daysBack: 60)) ?? .empty
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
    }

    var macroTarget: MacroTarget {
        profile.map(MacroTarget.init(profile:)) ?? .defaultTarget
    }

    func changeDate(to date: Date, context: ModelContext, dependencies: DependencyContainer) {
        selectedDate = date
        load(context: context, dependencies: dependencies)
    }

    func moveDate(by days: Int, context: ModelContext, dependencies: DependencyContainer) {
        guard let next = Calendar.nuvyra.date(byAdding: .day, value: days, to: selectedDate), next <= Date() else { return }
        changeDate(to: next, context: context, dependencies: dependencies)
    }

    func estimateSmartMeal(dependencies: DependencyContainer) async {
        let input = smartMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isEstimating = true
        errorMessage = nil
        defer { isEstimating = false }
        do {
            estimatedResults = try await dependencies.foodIntelligenceService.estimateFromText(input, mealType: selectedMealType)
            if estimatedResults.isEmpty {
                errorMessage = "Bu metinden öğün çıkaramadık. Biraz daha açıklayıcı yazabilirsin."
            }
        } catch {
            errorMessage = "Akıllı kayıt şu an hazırlanamadı."
        }
    }

    func addEstimatedResult(_ result: EstimatedMealResult, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: result.name,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                portionDescription: result.portion,
                isFavorite: false,
                isVerifiedTurkishFood: result.source == .localTurkishNLP,
                isEstimated: result.isEstimated
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "smart_text", "estimated": "true"]))
            smartMealText = ""
            estimatedResults = []
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Tahmini öğün eklenemedi."
        }
    }

    func addQuickFood(_ food: QuickFood, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: food.name,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                portionDescription: food.portion,
                isFavorite: false,
                isVerifiedTurkishFood: true,
                isEstimated: true
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "quick_food", "name": food.name]))
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün eklenemedi."
        }
    }

    /// Phase 6 entry point — `FoodDetailView` kullanıcının seçtiği porsiyon
    /// + miktarı scaled `NutritionValues` ile birlikte yollar; burası onu
    /// `MealEntry`'ye çevirir. Repository tarafında usage frequency artırılır.
    func addFoodSelection(_ selection: FoodSelection, context: ModelContext, dependencies: DependencyContainer) async {
        let item = selection.item
        let values = selection.values
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
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
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()

            if let rowID = selection.deterministicRowID {
                await dependencies.foodRepository.recordUse(id: rowID)
            }

            await dependencies.analytics.track(
                .mealAdded,
                payload: AnalyticsPayload(values: [
                    "source": "food_detail",
                    "provider": item.source.rawValue,
                    "verified": item.verifiedLevel.rawValue
                ])
            )
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Seçilen besinden öğün eklenemedi."
        }
    }

    /// Phase 6.5 — barkod taramasından gelen `ScannedProduct`'ı rich `FoodItem`'a
    /// yükseltir, repository'ye write-through ile cache eder ve
    /// `pendingBarcodeItem` set ederek `FoodDetailView`'in modal olarak
    /// açılmasını tetikler. Portion picker sonrası `addFoodSelection` öğünü
    /// yaratır — eskiden "100 g - barkod" olarak sabit eklenen meal artık
    /// kullanıcı seçimine göre porsiyonlanır.
    func handleScannedProduct(_ product: ScannedProduct, dependencies: DependencyContainer) async {
        let item = FoodItem.from(scannedProduct: product)
        await dependencies.foodRepository.cacheItem(item)
        pendingBarcodeItem = item
        // NOT: meal_added analytics burada DEĞİL — kullanıcı daha henüz
        // porsiyon seçmedi. `addFoodSelection` (FoodDetailView confirm)
        // tarafından track edilir.
    }

    func delete(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) {
        do {
            try dependencies.nutritionRepository(context: context).deleteMeal(meal)
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün silinemedi."
        }
    }

    func startEditing(_ meal: MealEntry) {
        editingMeal = meal
    }

    func copyPreviousDayMeals(context: ModelContext, dependencies: DependencyContainer) async {
        guard let sourceDate = Calendar.nuvyra.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        do {
            let count = try dependencies.nutritionRepository(context: context).copyMeals(from: sourceDate, to: selectedDate)
            let copiedMeals = try dependencies.nutritionRepository(context: context).meals(on: selectedDate)
            for meal in copiedMeals.suffix(count) {
                await dependencies.healthService.saveNutrition(for: meal)
            }
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
            flash(count > 0 ? "\(count) öğün kopyalandı" : "Kopyalanacak öğün yok")
        } catch {
            errorMessage = "Öğünler kopyalanamadı."
        }
    }

    func copyMealToToday(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            try dependencies.nutritionRepository(context: context).copyMeal(meal, to: Date())
            if isViewingToday {
                load(context: context, dependencies: dependencies)
            }
            refreshWidget(context: context, dependencies: dependencies)
            flash("Öğün bugüne kopyalandı")
        } catch {
            errorMessage = "Öğün bugüne kopyalanamadı."
        }
    }

    private func refreshWidgetIfViewingToday(context: ModelContext, dependencies: DependencyContainer) {
        guard isViewingToday else { return }
        refreshWidget(context: context, dependencies: dependencies)
    }

    private func refreshWidget(context: ModelContext, dependencies: DependencyContainer) {
        Task { @MainActor in
            await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: context, healthService: dependencies.healthService)
        }
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}
