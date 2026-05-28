import XCTest
@testable import Nuvyra

final class SQLiteFTSFoodSearchTests: XCTestCase {
    func testNormalizerIgnoresTurkishDiacritics() {
        XCTAssertEqual(FoodSearchNormalizer.normalized("Şeftali Çilek İçli Köfte"), "seftali cilek icli kofte")
        XCTAssertEqual(FoodSearchNormalizer.makeFTSQuery(from: "seftali"), "\"seftali\"*")
    }

    func testFTSSearchFindsSeftaliWhenQueryHasNoDiacritics() async throws {
        let service = SQLiteFTSFoodSearchService(databaseURL: temporaryDatabaseURL())

        let results = try await service.search("seftali", limit: 5)

        XCTAssertTrue(results.contains { $0.name == "Şeftali" })
    }

    func testFTSSearchFindsInsertedTurkishFoodWithoutDiacritics() async throws {
        let service = SQLiteFTSFoodSearchService(databaseURL: temporaryDatabaseURL())
        try await service.upsert(records: [
            FoodSearchRecord(
                id: 99_001,
                name: "İçli köfte",
                brand: nil,
                calories: 320,
                protein: 14,
                carbs: 36,
                fat: 13,
                servingDescription: "2 adet",
                keywords: "icli kofte bulgur et"
            )
        ])

        let results = try await service.search("icli kofte", limit: 5)

        XCTAssertEqual(results.first?.name, "İçli köfte")
        XCTAssertEqual(results.first?.calories, 320)
        XCTAssertEqual(results.first?.protein, 14)
        XCTAssertEqual(results.first?.carbs, 36)
        XCTAssertEqual(results.first?.fat, 13)
    }

    func testSearchItemsRehydratesThinRecordWithNutritionValues() async throws {
        let service = SQLiteFTSFoodSearchService(databaseURL: temporaryDatabaseURL())
        try await service.upsert(records: [
            FoodSearchRecord(
                id: 99_002,
                name: "Macrotest Yoğurt",
                brand: "Nuvyra Test",
                calories: 120,
                protein: 10.5,
                carbs: 8.2,
                fat: 4.1,
                fiber: 1.4,
                sodium: 55,
                sugar: 6.2,
                saturatedFat: 2.0,
                servingDescription: "100 g",
                keywords: "macrotest yogurt protein"
            )
        ])

        let items = try await service.searchItems("macrotest", limit: 5)
        let item = try XCTUnwrap(items.first { $0.name == "Macrotest Yoğurt" })

        XCTAssertEqual(item.caloriesPer100g, 120)
        XCTAssertEqual(item.proteinPer100g, 10.5, accuracy: 0.01)
        XCTAssertEqual(item.carbsPer100g, 8.2, accuracy: 0.01)
        XCTAssertEqual(item.fatPer100g, 4.1, accuracy: 0.01)
        XCTAssertEqual(item.fiberPer100g, 1.4, accuracy: 0.01)
        XCTAssertEqual(item.sodiumPer100g, 55, accuracy: 0.01)
        XCTAssertEqual(item.sugarPer100g, 6.2, accuracy: 0.01)
        XCTAssertEqual(item.saturatedFatPer100g, 2.0, accuracy: 0.01)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NuvyraFoodSearchTests-\(UUID().uuidString).sqlite")
    }
}
