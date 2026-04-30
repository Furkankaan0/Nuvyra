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

@MainActor
protocol NutritionRepository {
    func meals(on date: Date) throws -> [MealEntry]
    /// Inserts the meal and returns the day's post-write calorie total.
    @discardableResult
    func addMeal(_ meal: MealEntry) throws -> Int
    @discardableResult
    func addQuickFood(_ food: QuickFood, mealType: MealType) throws -> Int
    func favoriteMeals() throws -> [MealEntry]
    func totalCalories(on date: Date) throws -> Int
}

@MainActor
final class SwiftDataNutritionRepository: NutritionRepository {
    private let context: ModelContext
    private let calendar: Calendar
    /// Optional hook invoked after every successful mutation. The
    /// `DependencyContainer` wires it to `WidgetRefresh.reload(...)` so the
    /// home-screen widget sees the change immediately. Tests pass `nil`.
    private let onMutate: (@MainActor () -> Void)?

    init(
        context: ModelContext,
        calendar: Calendar = .nuvyra,
        onMutate: (@MainActor () -> Void)? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.onMutate = onMutate
    }

    func meals(on date: Date) throws -> [MealEntry] {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func addMeal(_ meal: MealEntry) throws -> Int {
        context.insert(meal)
        try context.save()
        let total = try totalCalories(on: meal.date)
        onMutate?()
        return total
    }

    @discardableResult
    func addQuickFood(_ food: QuickFood, mealType: MealType) throws -> Int {
        let meal = MealEntry(
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
        return try addMeal(meal)
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
}
