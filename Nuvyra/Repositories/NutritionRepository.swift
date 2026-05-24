import Foundation
import SwiftData

struct QuickFood: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: String

    static let turkishDefaults: [QuickFood] = [
        QuickFood(name: "Mercimek çorbası", calories: 210, protein: 11, carbs: 31, fat: 6, portion: "1 kase"),
        QuickFood(name: "Tavuk döner", calories: 520, protein: 36, carbs: 52, fat: 18, portion: "1 porsiyon"),
        QuickFood(name: "Pilav", calories: 280, protein: 5, carbs: 58, fat: 4, portion: "1 tabak"),
        QuickFood(name: "Izgara tavuk", calories: 360, protein: 48, carbs: 4, fat: 14, portion: "1 porsiyon"),
        QuickFood(name: "Menemen", calories: 330, protein: 18, carbs: 12, fat: 22, portion: "1 tabak"),
        QuickFood(name: "Yumurta", calories: 78, protein: 6, carbs: 1, fat: 5, portion: "1 adet"),
        QuickFood(name: "Yoğurt", calories: 120, protein: 8, carbs: 9, fat: 5, portion: "1 kase"),
        QuickFood(name: "Simit", calories: 360, protein: 10, carbs: 68, fat: 7, portion: "1 adet"),
        QuickFood(name: "Çay şekersiz", calories: 0, protein: 0, carbs: 0, fat: 0, portion: "1 bardak"),
        QuickFood(name: "Ayran", calories: 80, protein: 5, carbs: 6, fat: 3, portion: "1 bardak")
    ]
}

/// Aggregated values for a single day — used by Dashboard, Nutrition and Insights.
struct DailyMealSummary: Equatable {
    var date: Date
    var totals: NutritionValues
    var mealCount: Int

    static let empty = DailyMealSummary(date: Date(), totals: .zero, mealCount: 0)
}

@MainActor
protocol NutritionRepository {
    func meals(on date: Date) throws -> [MealEntry]
    func addMeal(_ meal: MealEntry) throws
    func updateMeal(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool) throws
    func deleteMeal(_ meal: MealEntry) throws
    func addQuickFood(_ food: QuickFood, mealType: MealType) throws
    func addQuickFood(_ food: QuickFood, mealType: MealType, date: Date) throws
    func copyMeal(_ meal: MealEntry, to date: Date) throws
    func copyMeals(from sourceDate: Date, to targetDate: Date) throws -> Int
    func favoriteMeals() throws -> [MealEntry]
    func totalCalories(on date: Date) throws -> Int
    func dailySummary(on date: Date) throws -> DailyMealSummary
}

@MainActor
final class SwiftDataNutritionRepository: NutritionRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func meals(on date: Date) throws -> [MealEntry] {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func addMeal(_ meal: MealEntry) throws {
        context.insert(meal)
        try context.save()
    }

    func updateMeal(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool) throws {
        meal.name = name
        meal.calories = values.calories
        meal.protein = values.protein
        meal.carbs = values.carbs
        meal.fat = values.fat
        meal.fiberGrams = values.fiber > 0 ? values.fiber : meal.fiberGrams
        meal.sodiumMg = values.sodium > 0 ? values.sodium : meal.sodiumMg
        meal.sugarGrams = values.sugar > 0 ? values.sugar : meal.sugarGrams
        meal.saturatedFatGrams = values.saturatedFat > 0 ? values.saturatedFat : meal.saturatedFatGrams
        meal.portionDescription = portion
        meal.mealType = mealType
        meal.date = date
        meal.isFavorite = isFavorite
        try context.save()
    }

    func deleteMeal(_ meal: MealEntry) throws {
        context.delete(meal)
        try context.save()
    }

    func addQuickFood(_ food: QuickFood, mealType: MealType) throws {
        try addQuickFood(food, mealType: mealType, date: Date())
    }

    func addQuickFood(_ food: QuickFood, mealType: MealType, date: Date) throws {
        let meal = MealEntry(
            date: date,
            mealType: mealType,
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
        try addMeal(meal)
    }

    func copyMeal(_ meal: MealEntry, to date: Date) throws {
        let copy = MealEntry(
            date: date,
            mealType: meal.mealType,
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            portionDescription: meal.portionDescription,
            isFavorite: meal.isFavorite,
            isVerifiedTurkishFood: meal.isVerifiedTurkishFood,
            isEstimated: meal.isEstimated
        )
        try addMeal(copy)
    }

    func copyMeals(from sourceDate: Date, to targetDate: Date) throws -> Int {
        let sourceMeals = try meals(on: sourceDate)
        for meal in sourceMeals {
            try copyMeal(meal, to: targetDate)
        }
        return sourceMeals.count
    }

    func favoriteMeals() throws -> [MealEntry] {
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func totalCalories(on date: Date) throws -> Int {
        try meals(on: date).reduce(0) { $0 + $1.calories }
    }

    func dailySummary(on date: Date) throws -> DailyMealSummary {
        let items = try meals(on: date)
        let totals = items.reduce(NutritionValues.zero) { acc, meal in
            acc + NutritionValues(
                calories: meal.calories,
                protein: meal.protein ?? 0,
                carbs: meal.carbs ?? 0,
                fat: meal.fat ?? 0,
                fiber: meal.fiberGrams ?? 0,
                sodium: meal.sodiumMg ?? 0,
                sugar: meal.sugarGrams ?? 0,
                saturatedFat: meal.saturatedFatGrams ?? 0
            )
        }
        return DailyMealSummary(date: date, totals: totals, mealCount: items.count)
    }
}
