import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class TrendInsightEngineTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: NuvyraModelContainer.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: NuvyraModelContainer.schema, configurations: [config])
    }

    private func profile(proteinTarget: Int = 120, stepTarget: Int = 7_500, waterTarget: Int = 2_000) -> UserProfile {
        let p = UserProfile(name: "Test")
        p.dailyProteinTargetGrams = proteinTarget
        p.dailyStepTarget = stepTarget
        p.dailyWaterTargetMl = waterTarget
        return p
    }

    // MARK: - Protein shortfall

    func testProteinShortfallRunSurfacesNudge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // Last 3 days: meals logged, protein well under 70% of 120 = 84 g.
        for offset in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try nutrition.addMeal(MealEntry(date: date, name: "Low protein", calories: 500, protein: 20))
        }

        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), endingOn: Date()
        )
        XCTAssertTrue(insights.contains { $0.id == "protein.shortfall" })
    }

    func testProteinAboveThresholdDoesNotSurface() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            // 100 g > 84 g threshold.
            try nutrition.addMeal(MealEntry(date: date, name: "High protein", calories: 600, protein: 100))
        }

        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), endingOn: Date()
        )
        XCTAssertFalse(insights.contains { $0.id == "protein.shortfall" })
    }

    // MARK: - Logging consistency

    func testSixOfSevenLoggedDaysSurfacesEncouraging() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // 6 of last 7 days logged (skip offset 3) with healthy protein
        // so the shortfall detector doesn't also fire.
        for offset in 0..<7 where offset != 3 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try nutrition.addMeal(MealEntry(date: date, name: "Meal", calories: 500, protein: 100))
        }

        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), endingOn: Date()
        )
        XCTAssertTrue(insights.contains { $0.id == "logging.consistency" })
    }

    // MARK: - Step streak

    func testStepStreakSurfacesEncouraging() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // 5 consecutive days at goal.
        for offset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try activity.upsertWalkingSnapshot(date: date, steps: 9_000, activeEnergy: 300, distanceKm: 6, goal: 7_500)
        }

        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), endingOn: Date()
        )
        XCTAssertTrue(insights.contains { $0.id == "steps.streak" })
    }

    // MARK: - Empty

    func testNoDataYieldsNoInsights() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: SwiftDataNutritionRepository(context: context),
            water: SwiftDataWaterRepository(context: context),
            activity: SwiftDataActivityRepository(context: context),
            profile: profile(),
            endingOn: Date()
        )
        XCTAssertTrue(insights.isEmpty)
    }

    func testCapsAtTwoInsights() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // Trigger protein shortfall + logging consistency + step streak.
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try nutrition.addMeal(MealEntry(date: date, name: "Low protein", calories: 500, protein: 20))
            try activity.upsertWalkingSnapshot(date: date, steps: 9_000, activeEnergy: 300, distanceKm: 6, goal: 7_500)
        }

        let engine = DefaultTrendInsightEngine()
        let insights = try engine.detect(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), endingOn: Date()
        )
        XCTAssertLessThanOrEqual(insights.count, 2)
    }
}
