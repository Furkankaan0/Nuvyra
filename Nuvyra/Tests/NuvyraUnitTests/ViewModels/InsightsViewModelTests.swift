import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class InsightsViewModelTests: XCTestCase {
    func testTrendTextHighlightsStrongStepsAndWater() {
        let text = InsightsViewModel.makeTrendText(steps: 6_001, calories: 0, water: 1_500)

        XCTAssertEqual(
            text,
            "Bu hafta yürüyüş ve su ritmin iyi bir zemine oturuyor. Aynı sakin düzeni koruyabilirsin."
        )
    }

    func testTrendTextPrioritizesLowStepsBelowFourThousand() {
        let text = InsightsViewModel.makeTrendText(steps: 3_999, calories: 1_200, water: 2_000)

        XCTAssertEqual(
            text,
            "Adım ortalaman düşük kalmış. Bugün 12 dakikalık kısa bir yürüyüş ritmini toparlayabilir."
        )
    }

    func testTrendTextUsesCaloriePromptAtFourThousandStepsWhenCaloriesAreZero() {
        let text = InsightsViewModel.makeTrendText(steps: 4_000, calories: 0, water: 500)

        XCTAssertEqual(
            text,
            "Öğün kayıtlarını birkaç güne yaydığında kalori dengesi daha net görünür."
        )
    }

    func testTrendTextLowStepsWinWhenCaloriesAreAlsoZero() {
        let text = InsightsViewModel.makeTrendText(steps: 0, calories: 0, water: 0)

        XCTAssertEqual(
            text,
            "Adım ortalaman düşük kalmış. Bugün 12 dakikalık kısa bir yürüyüş ritmini toparlayabilir."
        )
    }

    func testTrendTextSixThousandStepsIsNotStrongRhythmBoundary() {
        let text = InsightsViewModel.makeTrendText(steps: 6_000, calories: 900, water: 1_500)

        XCTAssertEqual(
            text,
            "Haftalık ritminde küçük ama görünür bir temel oluşuyor. Bugün sadece devam etmek yeterli."
        )
    }

    func testTrendTextNeedsAtLeastFifteenHundredWaterForStrongRhythm() {
        let text = InsightsViewModel.makeTrendText(steps: 6_001, calories: 900, water: 1_499)

        XCTAssertEqual(
            text,
            "Haftalık ritminde küçük ama görünür bir temel oluşuyor. Bugün sadece devam etmek yeterli."
        )
    }

    func testLoadReadsMockDependenciesWithInMemoryContext() throws {
        let harness = try makeHarness()

        harness.context.insert(
            MealEntry(
                date: Date(),
                mealType: .breakfast,
                name: "Yoğurt",
                calories: 220,
                protein: 12,
                carbs: 18,
                fat: 8
            )
        )
        harness.context.insert(WaterEntry(date: Date(), amountMl: 1_700, drinkType: .water))
        harness.context.insert(WalkingLog(date: Date(), steps: 6_200, activeEnergy: 210, distanceKm: 4.1))
        try harness.context.save()

        let viewModel = InsightsViewModel()
        viewModel.load(context: harness.context, dependencies: harness.dependencies)

        XCTAssertEqual(viewModel.averageCalories, 220)
        XCTAssertEqual(viewModel.averageSteps, 6_200)
        XCTAssertEqual(viewModel.waterAverage, 1_700)
        XCTAssertEqual(
            viewModel.trendText,
            "Bu hafta yürüyüş ve su ritmin iyi bir zemine oturuyor. Aynı sakin düzeni koruyabilirsin."
        )
    }

    private func makeHarness() throws -> TestHarness {
        let configuration = ModelConfiguration(
            schema: NuvyraModelContainer.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: NuvyraModelContainer.schema, configurations: [configuration])
        return TestHarness(
            container: container,
            context: container.mainContext,
            dependencies: DependencyContainer.mock()
        )
    }
}

private struct TestHarness {
    let container: ModelContainer
    let context: ModelContext
    let dependencies: DependencyContainer
}
