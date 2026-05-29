import XCTest
@testable import Nuvyra

/// Phase 10 — `MockFoodRepository` davranış kontratını doğrular. Bu testler
/// `DependencyContainer.mock()`'a güvenen herhangi bir ViewModel/Feature
/// testi için repository'nin nasıl tepki verdiğini sabitler.
final class MockFoodRepositoryTests: XCTestCase {

    private func makeItem(
        slug: String,
        name: String,
        nameTR: String,
        calories: Int = 100,
        servingGrams: Double = 100,
        source: ProductSource = .estimated,
        verified: VerifiedLevel = .approximate
    ) -> FoodItem {
        FoodItem(
            source: source,
            externalID: "local:\(slug)",
            name: name,
            localizedNameTR: nameTR,
            category: .localTurkish,
            servingSizes: [.hundredGrams, ServingSize(label: "1 portion", labelTR: "1 porsiyon", grams: servingGrams, isDefault: true)],
            nutritionPer100g: NutritionValues(calories: calories, protein: 5, carbs: 15, fat: 3),
            verifiedLevel: verified,
            confidenceScore: 0.6
        )
    }

    func testSearchByPreferredTRName() async {
        let repo = MockFoodRepository(seed: [
            makeItem(slug: "mercimek-corbasi", name: "Lentil Soup", nameTR: "Mercimek çorbası"),
            makeItem(slug: "elma", name: "Apple", nameTR: "Elma", calories: 52)
        ])

        let results = await repo.searchItems(query: "Mercimek", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.localizedNameTR, "Mercimek çorbası")
    }

    func testSearchShortQueryReturnsEmpty() async {
        let repo = MockFoodRepository(seed: [
            makeItem(slug: "elma", name: "Apple", nameTR: "Elma")
        ])
        let results = await repo.searchItems(query: "e", limit: 10)
        XCTAssertTrue(results.isEmpty)
    }

    func testRecordUseElevatesRecentItems() async {
        let elma = makeItem(slug: "elma", name: "Apple", nameTR: "Elma")
        let muz = makeItem(slug: "muz", name: "Banana", nameTR: "Muz")
        let repo = MockFoodRepository(seed: [elma, muz])

        // Initially no recents — nothing has been used yet.
        let emptyRecents = await repo.recentItems(limit: 10)
        XCTAssertTrue(emptyRecents.isEmpty)

        // Record use of muz, then elma; elma should be first (most recent).
        guard let muzID = muz.deterministicRowID, let elmaID = elma.deterministicRowID else {
            return XCTFail("Seeded items should expose deterministicRowID")
        }
        await repo.recordUse(id: muzID)
        try? await Task.sleep(nanoseconds: 1_000_000)
        await repo.recordUse(id: elmaID)

        let recents = await repo.recentItems(limit: 10)
        XCTAssertEqual(recents.count, 2)
        XCTAssertEqual(recents.first?.externalID, "local:elma")
        XCTAssertEqual(recents.last?.externalID, "local:muz")
    }

    func testFavoriteToggleRoundTrip() async {
        let item = makeItem(slug: "elma", name: "Apple", nameTR: "Elma")
        guard let rowID = item.deterministicRowID else {
            return XCTFail("Seeded item should expose deterministicRowID")
        }
        let repo = MockFoodRepository(seed: [item])

        XCTAssertFalse(await repo.isFavorite(id: rowID))
        await repo.setFavorite(id: rowID, true)
        XCTAssertTrue(await repo.isFavorite(id: rowID))

        let favorites = await repo.favoriteItems(limit: 10)
        XCTAssertEqual(favorites.first?.externalID, "local:elma")

        await repo.setFavorite(id: rowID, false)
        XCTAssertFalse(await repo.isFavorite(id: rowID))
        XCTAssertTrue(await repo.favoriteItems(limit: 10).isEmpty)
    }

    func testAddUserItemAppearsInSearch() async throws {
        let repo = MockFoodRepository()
        let custom = FoodItem.userCreated(
            name: "Ev yapımı börek",
            servingSizes: [.hundredGrams, ServingSize(label: "1 slice", labelTR: "1 dilim", grams: 80, isDefault: true)],
            nutritionPer100g: NutritionValues(calories: 280, protein: 9, carbs: 30, fat: 14)
        )

        _ = try await repo.addUserItem(custom)

        let results = await repo.searchItems(query: "börek", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.verifiedLevel, .userCreated)
    }

    func testFetchByBarcodeReturnsMatchingItem() async {
        let bisküvi = FoodItem(
            source: .openFoodFacts,
            externalID: "8690000000000",
            name: "Whole Wheat Biscuit",
            brand: "Nuvyra",
            barcode: "8690000000000",
            servingSizes: [.hundredGrams],
            nutritionPer100g: NutritionValues(calories: 421, protein: 8, carbs: 63, fat: 14),
            verifiedLevel: .verified
        )
        let repo = MockFoodRepository(seed: [bisküvi])

        let hit = await repo.fetchItem(barcode: "8690000000000")
        XCTAssertEqual(hit?.name, "Whole Wheat Biscuit")
        XCTAssertEqual(hit?.brand, "Nuvyra")

        let miss = await repo.fetchItem(barcode: "0000000000000")
        XCTAssertNil(miss)
    }

    func testSearchRankingFavoritesThenFrequentsThenScore() async {
        // Üç item ortak "fruit" keyword'ü taşır (name'in içinde). Hepsi
        // searchItems("fruit") ile match olur, ranking'i izole gözleyebiliriz.
        let popular = makeItem(slug: "muz", name: "Banana fruit", nameTR: "Muz")
        let favorite = makeItem(slug: "elma", name: "Apple fruit", nameTR: "Elma")
        let unused = makeItem(slug: "armut", name: "Pear fruit", nameTR: "Armut")
        let repo = MockFoodRepository(seed: [popular, favorite, unused])

        guard let popularID = popular.deterministicRowID,
              let favoriteID = favorite.deterministicRowID else {
            return XCTFail("Seeded items should expose deterministicRowID")
        }

        // favorite = elma (favorited), popular = muz (used 3x), unused = armut.
        await repo.setFavorite(id: favoriteID, true)
        await repo.recordUse(id: popularID)
        await repo.recordUse(id: popularID)
        await repo.recordUse(id: popularID)

        let results = await repo.searchItems(query: "fruit", limit: 10)
        XCTAssertEqual(results.count, 3)
        // Beklenen sıra: favorite ilk (favori), sonra popular (en çok kullanılmış), en son unused.
        XCTAssertEqual(results[0].externalID, "local:elma")
        XCTAssertEqual(results[1].externalID, "local:muz")
        XCTAssertEqual(results[2].externalID, "local:armut")
    }

    func testCacheItemPersistsForBarcodeLookup() async {
        let repo = MockFoodRepository()
        let scanned = FoodItem(
            source: .openFoodFacts,
            externalID: "1234567890123",
            name: "Mineral Water",
            brand: "Akmina",
            barcode: "1234567890123",
            servingSizes: [.hundredGrams],
            nutritionPer100g: NutritionValues(calories: 0, protein: 0, carbs: 0, fat: 0),
            verifiedLevel: .verified
        )

        await repo.cacheItem(scanned)
        let hit = await repo.fetchItem(barcode: "1234567890123")
        XCTAssertEqual(hit?.brand, "Akmina")
    }
}
