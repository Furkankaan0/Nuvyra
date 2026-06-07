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

/// A frequently-logged food + how often it appeared in the lookback
/// window. `template` is a representative entry (most recent occurrence)
/// the UI clones when the user taps "quick add".
struct FrequentMeal: Identifiable, Equatable {
    var id: String { template.name }
    let template: MealEntry
    let count: Int

    static func == (lhs: FrequentMeal, rhs: FrequentMeal) -> Bool {
        lhs.template.id == rhs.template.id && lhs.count == rhs.count
    }
}

@MainActor
protocol NutritionRepository {
    func meals(on date: Date) throws -> [MealEntry]
    func addMeal(_ meal: MealEntry) throws
    func updateMeal(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool, photoData: Data?) throws
    func deleteMeal(_ meal: MealEntry) throws
    func addQuickFood(_ food: QuickFood, mealType: MealType) throws
    func addQuickFood(_ food: QuickFood, mealType: MealType, date: Date) throws
    func copyMeal(_ meal: MealEntry, to date: Date) throws
    func copyMeals(from sourceDate: Date, to targetDate: Date) throws -> Int
    func favoriteMeals() throws -> [MealEntry]
    /// Most-frequently-logged meals over the lookback window, most
    /// frequent first. One representative `MealEntry` per distinct
    /// food name. Powers the "quick repeat" suggestions.
    func frequentMeals(daysBack: Int, limit: Int) throws -> [FrequentMeal]
    func totalCalories(on date: Date) throws -> Int
    func dailySummary(on date: Date) throws -> DailyMealSummary
    /// Per-day rollups for a range, oldest → newest. Missing days return `.empty`
    /// with that day's date stamped, so callers can rely on `result.count == days`.
    func dailySummaries(days: Int, endingOn date: Date) throws -> [DailyMealSummary]
    func mealStreak(daysBack: Int) throws -> StreakInsight
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

    func updateMeal(_ meal: MealEntry, with values: NutritionValues, name: String, portion: String, mealType: MealType, date: Date, isFavorite: Bool, photoData: Data?) throws {
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
        meal.photoData = photoData
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
            isEstimated: meal.isEstimated,
            fiberGrams: meal.fiberGrams,
            sodiumMg: meal.sodiumMg,
            sugarGrams: meal.sugarGrams,
            saturatedFatGrams: meal.saturatedFatGrams,
            photoData: meal.photoData
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

    /// Single window fetch → group by (case-insensitive) name → count.
    /// We keep the most-recent entry per name as the clone template so
    /// the quick-add carries the freshest macros the user logged for
    /// that food. Names that only appear once are dropped — a "frequent"
    /// list of one-offs isn't useful.
    func frequentMeals(daysBack: Int = 14, limit: Int = 6) throws -> [FrequentMeal] {
        let startDay = calendar.date(
            byAdding: .day,
            value: -(daysBack - 1),
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        // `fetchLimit` caps the row count for very heavy loggers. Even
        // 14 days of 6+ meals/day stays well under this; the limit just
        // protects against pathological cases.
        var descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= startDay },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let rows = try context.fetch(descriptor)

        // Group by lowercased trimmed name. First row wins as template
        // because the fetch is already newest-first.
        var templates: [String: MealEntry] = [:]
        var counts: [String: Int] = [:]
        for row in rows {
            let key = row.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "tr_TR"))
            guard !key.isEmpty else { continue }
            counts[key, default: 0] += 1
            if templates[key] == nil { templates[key] = row }
        }

        return counts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { key, count in
                guard let template = templates[key] else { return nil }
                return FrequentMeal(template: template, count: count)
            }
    }

    func totalCalories(on date: Date) throws -> Int {
        try meals(on: date).reduce(0) { $0 + $1.calories }
    }

    func dailySummary(on date: Date) throws -> DailyMealSummary {
        let items = try meals(on: date)
        let totals = items.reduce(NutritionValues.zero) { acc, meal in
            acc + meal.nutritionValues
        }
        return DailyMealSummary(date: date, totals: totals, mealCount: items.count)
    }

    /// One `MealEntry` fetch over the whole window, then in-memory groupBy by
    /// start-of-day — keeps the SwiftData round-trip count at 1 regardless of
    /// `days`. Empty days are filled with `.empty` so the result array is
    /// always exactly `days` long, oldest → newest.
    func dailySummaries(days: Int, endingOn endDate: Date = Date()) throws -> [DailyMealSummary] {
        guard days > 0 else { return [] }
        let endOfWindow = calendar.startAndEndOfDay(for: endDate).1
        let startDay = calendar.date(
            byAdding: .day,
            value: -(days - 1),
            to: calendar.startOfDay(for: endDate)
        ) ?? endDate
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= startDay && $0.date < endOfWindow }
        )
        let rows = try context.fetch(descriptor)
        let grouped = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.date) }
        return (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: endDate)) ?? endDate
            let meals = grouped[day] ?? []
            let totals = meals.reduce(NutritionValues.zero) { $0 + $1.nutritionValues }
            return DailyMealSummary(date: day, totals: totals, mealCount: meals.count)
        }
    }

    /// "Logged a meal that day" streak. We use *any* meal — even a quick water
    /// or snack — because the engagement signal is the act of logging, not
    /// hitting a calorie threshold (that's covered separately by the calorie ring).
    func mealStreak(daysBack: Int = 60) throws -> StreakInsight {
        // Cache 60 days into memory in one query to avoid one fetch per day.
        let endOfToday = calendar.startAndEndOfDay(for: Date()).1
        let startDay = calendar.date(byAdding: .day, value: -(daysBack - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= startDay && $0.date < endOfToday }
        )
        let rows = try context.fetch(descriptor)
        // Group by start-of-day for fast O(1) lookup.
        let completedDays: Set<Date> = Set(rows.map { calendar.startOfDay(for: $0.date) })
        return StreakCalculator.calculate(daysBack: daysBack, calendar: calendar) { day in
            completedDays.contains(calendar.startOfDay(for: day))
        }
    }
}
