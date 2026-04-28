import Foundation

protocol MealLogServicing {
    func meals(on date: Date) async throws -> [MealLog]
    func allMeals() async throws -> [MealLog]
    func addMeal(_ meal: MealLog) async throws -> [MealLog]
    func updateMeal(_ meal: MealLog) async throws -> [MealLog]
    func deleteMeal(id: UUID) async throws -> [MealLog]
}

struct MealLogService: MealLogServicing {
    let repository: MealRepository
    var calendar: Calendar = .current

    func meals(on date: Date) async throws -> [MealLog] {
        try await allMeals()
            .filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    func allMeals() async throws -> [MealLog] {
        try await repository.loadMeals()
    }

    func addMeal(_ meal: MealLog) async throws -> [MealLog] {
        var meals = try await repository.loadMeals()
        meals.append(meal)
        try await repository.saveMeals(meals)
        return try await self.meals(on: meal.loggedAt)
    }

    func updateMeal(_ meal: MealLog) async throws -> [MealLog] {
        var meals = try await repository.loadMeals()
        guard let index = meals.firstIndex(where: { $0.id == meal.id }) else { return try await self.meals(on: meal.loggedAt) }
        meals[index] = meal
        try await repository.saveMeals(meals)
        return try await self.meals(on: meal.loggedAt)
    }

    func deleteMeal(id: UUID) async throws -> [MealLog] {
        var meals = try await repository.loadMeals()
        let deletedDate = meals.first(where: { $0.id == id })?.loggedAt ?? Date()
        meals.removeAll { $0.id == id }
        try await repository.saveMeals(meals)
        return try await self.meals(on: deletedDate)
    }
}

struct PreviewMealLogService: MealLogServicing {
    var meals: [MealLog] = MealLog.sampleToday

    func meals(on date: Date) async throws -> [MealLog] { meals }
    func allMeals() async throws -> [MealLog] { meals }
    func addMeal(_ meal: MealLog) async throws -> [MealLog] { [meal] + meals }
    func updateMeal(_ meal: MealLog) async throws -> [MealLog] { meals.map { $0.id == meal.id ? meal : $0 } }
    func deleteMeal(id: UUID) async throws -> [MealLog] { meals.filter { $0.id != id } }
}
