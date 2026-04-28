import XCTest
@testable import Nuvyra

final class MealLogServiceTests: XCTestCase {
    func testAddMealPersistsAndReturnsTodayMeals() async throws {
        let store = LocalStore.inMemory()
        let repository = LocalMealRepository(store: store)
        let service = MealLogService(repository: repository)
        let meal = MealLog(
            name: "Yoğurt",
            calories: 120,
            macros: MacroNutrients(proteinGrams: 8, carbohydrateGrams: 9, fatGrams: 5),
            source: .manual,
            isEstimated: false
        )

        let meals = try await service.addMeal(meal)

        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals.first?.name, "Yoğurt")
        XCTAssertEqual(try await repository.loadMeals().count, 1)
    }

    func testDeleteMealRemovesOnlySelectedRecord() async throws {
        let store = LocalStore.inMemory()
        let repository = LocalMealRepository(store: store)
        let service = MealLogService(repository: repository)
        let first = MealLog(name: "Menemen", calories: 330, macros: .empty, source: .manual, isEstimated: false)
        let second = MealLog(name: "Ayran", calories: 80, macros: .empty, source: .manual, isEstimated: false)
        _ = try await service.addMeal(first)
        _ = try await service.addMeal(second)

        let remaining = try await service.deleteMeal(id: first.id)

        XCTAssertEqual(remaining.map(\.name), ["Ayran"])
    }
}
