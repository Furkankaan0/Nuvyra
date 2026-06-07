import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class WeeklyGoalEngineTests: XCTestCase {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: NuvyraModelContainer.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: NuvyraModelContainer.schema, configurations: [config])
    }

    private func profile() -> UserProfile {
        let p = UserProfile(name: "Test")
        p.dailyStepTarget = 7_500
        p.dailyWaterTargetMl = 2_000
        p.dailyCalorieTarget = 1_900
        p.dailyProteinTargetGrams = 120
        return p
    }

    // MARK: - WeeklyGoalProgress value semantics

    func testAchievedThresholdIsFiveOfSeven() {
        XCTAssertFalse(WeeklyGoalProgress(metric: .steps, daysHit: 4, totalDays: 7).isAchieved)
        XCTAssertTrue(WeeklyGoalProgress(metric: .steps, daysHit: 5, totalDays: 7).isAchieved)
        XCTAssertEqual(WeeklyGoalProgress(metric: .water, daysHit: 7, totalDays: 7).fraction, 1.0, accuracy: 0.001)
    }

    // MARK: - Engine

    func testStepsGoalCountedFromWalkingLogs() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // 6 days at goal, 1 day under.
        for offset in 0..<6 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try activity.upsertWalkingSnapshot(date: date, steps: 9_000, activeEnergy: 300, distanceKm: 6, goal: 7_500)
        }
        let underDay = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        try activity.upsertWalkingSnapshot(date: underDay, steps: 3_000, activeEnergy: 100, distanceKm: 2, goal: 7_500)

        let engine = DefaultWeeklyGoalEngine()
        let summary = try engine.summary(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), mealStreak: .empty, waterStreak: .empty, endingOn: Date()
        )
        let steps = try XCTUnwrap(summary.progress.first { $0.metric == .steps })
        XCTAssertEqual(steps.daysHit, 6)
        XCTAssertTrue(steps.isAchieved)
    }

    func testCalorieBandExcludesStarveAndBinge() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // In-band (1700 ≈ 0.89 of 1900): hit.
        try nutrition.addMeal(MealEntry(date: today, name: "Balanced", calories: 1_700, protein: 100))
        // Starve (800 ≈ 0.42): miss.
        let day1 = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        try nutrition.addMeal(MealEntry(date: day1, name: "Tiny", calories: 800, protein: 40))
        // Binge (2600 ≈ 1.37): miss.
        let day2 = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        try nutrition.addMeal(MealEntry(date: day2, name: "Huge", calories: 2_600, protein: 120))

        let engine = DefaultWeeklyGoalEngine()
        let summary = try engine.summary(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), mealStreak: .empty, waterStreak: .empty, endingOn: Date()
        )
        let calories = try XCTUnwrap(summary.progress.first { $0.metric == .calories })
        XCTAssertEqual(calories.daysHit, 1)
    }

    // MARK: - Badges

    func testBalancedWeekBadgeRequiresAllMetricsAchieved() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let nutrition = SwiftDataNutritionRepository(context: context)
        let water = SwiftDataWaterRepository(context: context)
        let activity = SwiftDataActivityRepository(context: context)
        let calendar = Calendar.nuvyra
        let today = calendar.startOfDay(for: Date())

        // Hit all four on 6 of 7 days.
        for offset in 0..<6 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            try activity.upsertWalkingSnapshot(date: date, steps: 9_000, activeEnergy: 300, distanceKm: 6, goal: 7_500)
            try water.addWater(amountMl: 2_200, date: date)
            try nutrition.addMeal(MealEntry(date: date, name: "Balanced", calories: 1_800, protein: 130))
        }

        let engine = DefaultWeeklyGoalEngine()
        let summary = try engine.summary(
            nutrition: nutrition, water: water, activity: activity,
            profile: profile(), mealStreak: .empty, waterStreak: .empty, endingOn: Date()
        )
        let balanced = try XCTUnwrap(summary.badges.first { $0.id == "badge.week.balanced" })
        XCTAssertTrue(balanced.isEarned)
    }

    func testStreakBadgesDeriveFromLongestStreak() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let engine = DefaultWeeklyGoalEngine()
        let summary = try engine.summary(
            nutrition: SwiftDataNutritionRepository(context: context),
            water: SwiftDataWaterRepository(context: context),
            activity: SwiftDataActivityRepository(context: context),
            profile: profile(),
            mealStreak: StreakInsight(currentStreak: 7, longestStreak: 8, todayCompleted: true, lastSevenDays: Array(repeating: true, count: 7)),
            waterStreak: .empty,
            endingOn: Date()
        )
        let week = try XCTUnwrap(summary.badges.first { $0.id == "badge.streak.7" })
        let month = try XCTUnwrap(summary.badges.first { $0.id == "badge.streak.30" })
        XCTAssertTrue(week.isEarned)
        XCTAssertFalse(month.isEarned)
    }

    func testEnglishLocaleProducesEnglishBadgeTitles() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let engine = DefaultWeeklyGoalEngine(locale: Locale(identifier: "en_US"))
        let summary = try engine.summary(
            nutrition: SwiftDataNutritionRepository(context: context),
            water: SwiftDataWaterRepository(context: context),
            activity: SwiftDataActivityRepository(context: context),
            profile: profile(),
            mealStreak: .empty, waterStreak: .empty, endingOn: Date()
        )
        let streak7 = try XCTUnwrap(summary.badges.first { $0.id == "badge.streak.7" })
        XCTAssertEqual(streak7.title, "7-day rhythm")
        XCTAssertEqual(WeeklyGoalProgress.Metric.steps.title(in: Locale(identifier: "en_US")), "Steps")
    }

    func testTrendInsightCopyEnglishHeadlines() {
        let copy = TrendInsightCopy.english
        XCTAssertEqual(copy.proteinShortfallHeadline(days: 4), "Protein has been under target for 4 days")
        XCTAssertEqual(copy.weekendWaterDipHeadline(percent: 22), "Your water rhythm dips 22% on weekends")
    }
}
