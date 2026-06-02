import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class WeeklyInsightEngineTests: XCTestCase {

    // MARK: - Pure WeeklyMetric math

    func testChangeRatioPositive() {
        let metric = WeeklyMetric(kind: .steps, currentAverage: 8_000, previousAverage: 6_000)
        XCTAssertEqual(metric.changeRatio ?? 0, 0.3333, accuracy: 0.001)
        XCTAssertEqual(metric.direction, .up)
        XCTAssertEqual(metric.changeText, "↑ %33")
    }

    func testChangeRatioNegative() {
        let metric = WeeklyMetric(kind: .water, currentAverage: 1_500, previousAverage: 2_000)
        XCTAssertEqual(metric.changeRatio ?? 0, -0.25, accuracy: 0.001)
        XCTAssertEqual(metric.direction, .down)
        XCTAssertEqual(metric.changeText, "↓ %25")
    }

    func testChangeRatioBelowFlatThresholdReportsFlat() {
        // |2%| < 5% threshold → direction.flat, label "Aynı"
        let metric = WeeklyMetric(kind: .calories, currentAverage: 1_020, previousAverage: 1_000)
        XCTAssertEqual(metric.direction, .flat)
        XCTAssertEqual(metric.changeText, "Aynı")
    }

    func testZeroPreviousAverageYieldsBaseline() {
        // First-week scenario — no prior baseline, percent change is undefined.
        let metric = WeeklyMetric(kind: .protein, currentAverage: 80, previousAverage: 0)
        XCTAssertNil(metric.changeRatio)
        XCTAssertEqual(metric.direction, .baseline)
        XCTAssertEqual(metric.changeText, "İlk hafta")
    }

    // MARK: - Storyline edge cases

    func testStorylineEmptyWhenNotEnoughActiveDays() {
        let metrics = WeeklyMetric.Kind.allCases.map {
            WeeklyMetric(kind: $0, currentAverage: 0, previousAverage: 0)
        }
        let storyline = DefaultWeeklyInsightEngine.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: 1,
            hasEnoughData: false,
            locale: Locale(identifier: "tr_TR")
        )
        XCTAssertTrue(storyline.contains("birkaç güne yayılmış kayda"), "Empty storyline should ask for more data")
    }

    func testStorylineHighlightsBiggestPositiveMovement() {
        let metrics = [
            WeeklyMetric(kind: .calories, currentAverage: 1_900, previousAverage: 1_870),  // ~2% — below threshold
            WeeklyMetric(kind: .protein, currentAverage: 90, previousAverage: 85),         // ~6% — above 5% but below 10%
            WeeklyMetric(kind: .steps, currentAverage: 8_500, previousAverage: 6_500),     // ~31% — biggest move
            WeeklyMetric(kind: .water, currentAverage: 1_800, previousAverage: 1_600)      // ~13%
        ]
        let storyline = DefaultWeeklyInsightEngine.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: 5,
            hasEnoughData: true,
            locale: Locale(identifier: "tr_TR")
        )
        XCTAssertTrue(storyline.contains("adım"), "Should highlight steps as the biggest positive movement")
        XCTAssertTrue(storyline.contains("%31"), "Should include the actual percent change")
    }

    func testStorylineHighlightsBiggestNegativeWhenNoBigPositive() {
        let metrics = [
            WeeklyMetric(kind: .calories, currentAverage: 1_550, previousAverage: 1_900),  // -18%
            WeeklyMetric(kind: .protein, currentAverage: 60, previousAverage: 70),         // -14%
            WeeklyMetric(kind: .steps, currentAverage: 6_100, previousAverage: 6_500),     // -6% (flat-ish)
            WeeklyMetric(kind: .water, currentAverage: 1_700, previousAverage: 1_750)      // -3% (flat)
        ]
        let storyline = DefaultWeeklyInsightEngine.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: 6,
            hasEnoughData: true,
            locale: Locale(identifier: "tr_TR")
        )
        // -18% calories is biggest abs movement; storyline should mention "kalori".
        XCTAssertTrue(storyline.contains("Kalori") || storyline.contains("kalori"))
    }

    func testStorylineFallsBackWhenEverythingFlat() {
        let metrics = [
            WeeklyMetric(kind: .calories, currentAverage: 1_800, previousAverage: 1_800),
            WeeklyMetric(kind: .protein, currentAverage: 80, previousAverage: 80),
            WeeklyMetric(kind: .steps, currentAverage: 7_000, previousAverage: 7_000),
            WeeklyMetric(kind: .water, currentAverage: 1_700, previousAverage: 1_700)
        ]
        let storyline = DefaultWeeklyInsightEngine.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: 6,
            hasEnoughData: true,
            locale: Locale(identifier: "tr_TR")
        )
        XCTAssertTrue(storyline.contains("benzer bir ritimde"), "Flat week should get the calm holding-the-line copy")
    }

    // MARK: - Locale-aware storyline

    func testEnglishStorylineForLocaleEN() {
        // Same metrics that produce the Turkish "adım yükseldi" line should
        // produce the English equivalent when the locale flips. Guards
        // against the copy bank being inadvertently reused across languages.
        let metrics = [
            WeeklyMetric(kind: .steps, currentAverage: 8_500, previousAverage: 6_500),
            WeeklyMetric(kind: .calories, currentAverage: 1_800, previousAverage: 1_800),
            WeeklyMetric(kind: .protein, currentAverage: 90, previousAverage: 90),
            WeeklyMetric(kind: .water, currentAverage: 1_700, previousAverage: 1_700)
        ]
        let storyline = DefaultWeeklyInsightEngine.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: 6,
            hasEnoughData: true,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertTrue(storyline.lowercased().contains("step"), "English copy should use 'step'")
        XCTAssertFalse(storyline.contains("adım"), "Turkish word must not leak into English copy")
    }

    func testStorylineNeverContainsWeightOrMedicalLanguage() {
        // Calm-coach guardrail: no weight-loss or medical claims in any branch.
        let scenarios: [(metrics: [WeeklyMetric], activeDays: Int)] = [
            (WeeklyMetric.Kind.allCases.map { WeeklyMetric(kind: $0, currentAverage: 0, previousAverage: 0) }, 0),
            ([
                WeeklyMetric(kind: .calories, currentAverage: 1_950, previousAverage: 1_500),
                WeeklyMetric(kind: .protein, currentAverage: 110, previousAverage: 90),
                WeeklyMetric(kind: .steps, currentAverage: 10_000, previousAverage: 5_000),
                WeeklyMetric(kind: .water, currentAverage: 2_400, previousAverage: 1_800)
            ], 7),
            ([
                WeeklyMetric(kind: .calories, currentAverage: 1_200, previousAverage: 1_900),
                WeeklyMetric(kind: .protein, currentAverage: 50, previousAverage: 90),
                WeeklyMetric(kind: .steps, currentAverage: 3_000, previousAverage: 8_000),
                WeeklyMetric(kind: .water, currentAverage: 900, previousAverage: 1_900)
            ], 6)
        ]
        let banned = ["kilo", "diyet", "yağ yak", "hastalık", "tedavi", "ilaç", "doktor", "kg"]
        for scenario in scenarios {
            let storyline = DefaultWeeklyInsightEngine.makeStoryline(
                metrics: scenario.metrics,
                activeDaysThisWeek: scenario.activeDays,
                hasEnoughData: scenario.activeDays >= 2,
                locale: Locale(identifier: "tr_TR")
            )
            for word in banned {
                XCTAssertFalse(
                    storyline.lowercased().contains(word),
                    "Storyline should not contain '\(word)' — got: \(storyline)"
                )
            }
        }
    }

    // MARK: - End-to-end with SwiftData

    /// Seeds two MealEntry rows in "current week" and one in "prior week",
    /// then asserts the engine averages calories the way we'd hand-compute.
    func testComputeComparisonAveragesCaloriesAcrossSlices() throws {
        let container = try makeFreshContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let engine = DefaultWeeklyInsightEngine()
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // Current week — today + yesterday with 600 and 800 kcal.
        try nutrition.addMeal(MealEntry(date: today, name: "Today A", calories: 600, protein: 30))
        try nutrition.addMeal(MealEntry(
            date: calendar.date(byAdding: .day, value: -1, to: today) ?? today,
            name: "Yesterday A", calories: 800, protein: 40
        ))
        // Prior week — 10 days ago with 1_400 kcal.
        try nutrition.addMeal(MealEntry(
            date: calendar.date(byAdding: .day, value: -10, to: today) ?? today,
            name: "Prior A", calories: 1_400, protein: 60
        ))

        let comparison = try engine.computeComparison(
            nutrition: nutrition,
            water: water,
            activity: activity,
            endingOn: Date()
        )

        let calories = try XCTUnwrap(comparison.metrics.first { $0.kind == .calories })
        // Current week: (600 + 800 + 5×0) / 7 = 200; prior: (1_400 + 6×0) / 7 = 200.
        XCTAssertEqual(calories.currentAverage, 200, accuracy: 0.5)
        XCTAssertEqual(calories.previousAverage, 200, accuracy: 0.5)
        XCTAssertTrue(comparison.hasEnoughData, "2 active days this week → engine should report enough data")
    }

    func testComputeComparisonReportsNotEnoughDataForSingleDay() throws {
        let container = try makeFreshContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let engine = DefaultWeeklyInsightEngine()

        try nutrition.addMeal(MealEntry(date: Date(), name: "Single", calories: 500))

        let comparison = try engine.computeComparison(
            nutrition: nutrition,
            water: water,
            activity: activity,
            endingOn: Date()
        )
        XCTAssertFalse(comparison.hasEnoughData)
        XCTAssertEqual(comparison.activeDaysThisWeek, 1)
    }

    // MARK: - Helpers

    /// Bare in-memory container — bypasses `NuvyraModelContainer.preview()`'s
    /// SeedData so each test starts with empty tables.
    private func makeFreshContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: NuvyraModelContainer.schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: NuvyraModelContainer.schema, configurations: [configuration])
    }
}
