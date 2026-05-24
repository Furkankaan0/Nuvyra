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
    @Published var showingFoodSearch = false
    @Published var editingMeal: MealEntry?
    @Published var errorMessage: String?
    @Published var smartMealText = ""
    @Published var estimatedResults: [EstimatedMealResult] = []
    @Published var isEstimating = false

    var sectionedMeals: [(MealType, [MealEntry])] {
        MealType.allCases.map { type in
            (type, meals.filter { $0.mealType == type })
        }
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
            try dependencies.nutritionRepository(context: context).addQuickFood(food, mealType: selectedMealType)
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
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "fts_food_search"]))
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Arama sonucundan öğün eklenemedi."
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
}
