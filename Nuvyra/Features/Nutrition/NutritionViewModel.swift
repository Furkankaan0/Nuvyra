import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var selectedMealType: MealType = .breakfast
    @Published var showingAddMeal = false
    @Published var errorMessage: String?

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.nutritionRepository(context: context)
            meals = try repository.meals(on: Date())
            favorites = try repository.favoriteMeals()
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
    }

    func addQuickFood(_ food: QuickFood, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            try dependencies.nutritionRepository(context: context).addQuickFood(food, mealType: selectedMealType)
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "quick_food", "name": food.name]))
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün eklenemedi."
        }
    }
}
