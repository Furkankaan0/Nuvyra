import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var profile: UserProfile?
    @Published var selectedMealType: MealType = .breakfast
    @Published var showingAddMeal = false
    @Published var showingCamera = false
    @Published var showingFoodSearch = false
    @Published var editingMeal: MealEntry?
    @Published var pendingDeleteMeal: MealEntry?
    @Published var errorMessage: String?
    @Published var smartMealText = ""
    @Published var estimatedResults: [EstimatedMealResult] = []
    @Published var isEstimating = false

    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }

    var nutritionSummary: DailyNutritionSummary {
        DailyNutritionSummary(
            consumed: totalCalories,
            burned: 0,
            target: profile?.dailyCalorieTarget ?? 1_900
        )
    }

    var macroSummaries: [MacroSummary] {
        let p = meals.reduce(0.0) { $0 + ($1.protein ?? 0) }
        let c = meals.reduce(0.0) { $0 + ($1.carbs ?? 0) }
        let f = meals.reduce(0.0) { $0 + ($1.fat ?? 0) }
        return [
            MacroSummary(kind: .protein, consumedGrams: p, targetGrams: Double(profile?.dailyProteinTargetGrams ?? 120)),
            MacroSummary(kind: .carbs, consumedGrams: c, targetGrams: Double(profile?.dailyCarbsTargetGrams ?? 210)),
            MacroSummary(kind: .fat, consumedGrams: f, targetGrams: Double(profile?.dailyFatTargetGrams ?? 65))
        ]
    }

    func mealsByType(_ type: MealType) -> [MealEntry] {
        meals.filter { $0.mealType == type }.sorted { $0.createdAt > $1.createdAt }
    }

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.nutritionRepository(context: context)
            let userRepo = dependencies.userRepository(context: context)
            profile = try userRepo.profile()
            meals = try repository.meals(on: Date())
            favorites = try repository.favoriteMeals()
            Task { await WidgetSnapshotPublisher.publish(context: context, dependencies: dependencies) }
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
    }

    func delete(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) {
        do {
            try dependencies.nutritionRepository(context: context).delete(meal)
            load(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün silinemedi."
        }
    }

    func startEditing(_ meal: MealEntry) {
        editingMeal = meal
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

    func addFoodSearchResult(_ result: FoodSearchResult, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
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
}
