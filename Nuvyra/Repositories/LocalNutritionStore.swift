import Combine
import Foundation
import SwiftData

/// Lightweight async-facing facade in front of `NutritionRepository`. Centralises
/// the small bits of orchestration (analytics + haptic + cache invalidation) that
/// view models would otherwise duplicate.
@MainActor
protocol LocalNutritionStore {
    var meals: [MealEntry] { get }
    var favorites: [MealEntry] { get }
    var summary: DailyMealSummary { get }

    func refresh(on date: Date) async
    func add(_ meal: MealEntry) async throws
    func update(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool) async throws
    func delete(_ meal: MealEntry) async throws
}

@MainActor
final class DefaultLocalNutritionStore: LocalNutritionStore, ObservableObject {
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var favorites: [MealEntry] = []
    @Published private(set) var summary: DailyMealSummary = .empty

    private let repository: NutritionRepository
    private var cachedDate: Date = Date.distantPast

    init(repository: NutritionRepository) {
        self.repository = repository
    }

    func refresh(on date: Date) async {
        do {
            meals = try repository.meals(on: date)
            favorites = try repository.favoriteMeals()
            summary = try repository.dailySummary(on: date)
            cachedDate = date
        } catch {
            // Empty state is preserved on failure.
            meals = []
            favorites = []
            summary = .empty
        }
    }

    func add(_ meal: MealEntry) async throws {
        try repository.addMeal(meal)
        await refresh(on: cachedDate)
    }

    func update(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool) async throws {
        try repository.updateMeal(meal, with: values, name: name, portion: portion, mealType: mealType, date: date, isFavorite: isFavorite)
        await refresh(on: cachedDate)
    }

    func delete(_ meal: MealEntry) async throws {
        try repository.deleteMeal(meal)
        await refresh(on: cachedDate)
    }
}
