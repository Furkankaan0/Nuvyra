import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class NutritionRepositoryTests: XCTestCase {
    func testQuickFoodIsEstimatedAndVerifiedTurkishFood() throws {
        let container = NuvyraModelContainer.preview()
        let repository = SwiftDataNutritionRepository(context: container.mainContext)
        let food = QuickFood.turkishDefaults.first { $0.name == "Mercimek çorbası" }!

        try repository.addQuickFood(food, mealType: .lunch)
        let meals = try repository.meals(on: Date())

        XCTAssertTrue(meals.contains { $0.name == "Mercimek çorbası" && $0.isEstimated && $0.isVerifiedTurkishFood })
    }
}
