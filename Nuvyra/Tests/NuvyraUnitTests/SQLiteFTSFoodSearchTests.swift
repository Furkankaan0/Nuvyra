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
                servingDescription: "2 adet",
                keywords: "icli kofte bulgur et"
            )
        ])

        let results = try await service.search("icli kofte", limit: 5)

        XCTAssertEqual(results.first?.name, "İçli köfte")
        XCTAssertEqual(results.first?.calories, 320)
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NuvyraFoodSearchTests-\(UUID().uuidString).sqlite")
    }
}
