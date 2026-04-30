import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var selectedMealType: MealType = .breakfast
    @Published var showingAddMeal = false
    @Published var errorMessage: String?
    @Published var smartMealText = ""
    @Published var estimatedResults: [EstimatedMealResult] = []
    @Published var isEstimating = false

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.nutritionRepository(context: context)
            meals = try repository.meals(on: Date())
            favorites = try repository.favoriteMeals()
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
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
}
