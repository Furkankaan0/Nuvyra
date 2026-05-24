import Combine
import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var summary: DailyMealSummary = .empty
    @Published var selectedMealType: MealType = .breakfast
    @Published var selectedDate: Date = Date()
    @Published var showingAddMeal = false
    @Published var showingCamera = false
    @Published var showingBarcodeScanner = false
    @Published var showingFoodSearch = false
    @Published var editingMeal: MealEntry?
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
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
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
        } catch {
            errorMessage = "Öğün eklenemedi."
        }
    }

    func addFoodSearchResult(_ result: FoodSearchResult, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: result.name,
                calories: result.calories,
                protein: 0,
                carbs: 0,
                fat: 0,
                portionDescription: result.servingDescription,
                isFavorite: false,
                isVerifiedTurkishFood: false,
                isEstimated: true
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "fts_food_search"]))
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Arama sonucundan öğün eklenemedi."
        }
    }

    func addScannedProduct(_ product: ScannedProduct, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
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
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "barcode", "provider": product.source.rawValue]))
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Barkoddan gelen ürün öğüne eklenemedi."
        }
    }

    func delete(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) {
        do {
            try dependencies.nutritionRepository(context: context).deleteMeal(meal)
            load(context: context, dependencies: dependencies)
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
            flash("Öğün bugüne kopyalandı")
        } catch {
            errorMessage = "Öğün bugüne kopyalanamadı."
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
