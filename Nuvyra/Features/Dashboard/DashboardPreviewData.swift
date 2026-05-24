#if DEBUG
import Foundation

enum DashboardPreviewData {
    static let nutrition = DailyNutritionSummary(consumedCalories: 1_240, burnedCalories: 320, targetCalories: 1_900)

    static let macros: [MacroSummary] = [
        MacroSummary(kind: .protein, consumedGrams: 78, targetGrams: 120),
        MacroSummary(kind: .carbs, consumedGrams: 162, targetGrams: 210),
        MacroSummary(kind: .fat, consumedGrams: 41, targetGrams: 65)
    ]

    static let water = WaterSummary(consumedMl: 1_250, targetMl: 2_000)
    static let steps = StepSummary(steps: 5_360, goal: 7_500, distanceKm: 3.8, activeEnergy: 280)

    static let recentFoods: [RecentFoodLog] = [
        RecentFoodLog(
            id: UUID(),
            name: "Mercimek çorbası",
            calories: 210,
            portion: "1 kase",
            mealType: .lunch,
            createdAt: Date().addingTimeInterval(-1_800)
        ),
        RecentFoodLog(
            id: UUID(),
            name: "Izgara tavuk",
            calories: 360,
            portion: "1 porsiyon",
            mealType: .lunch,
            createdAt: Date().addingTimeInterval(-3_600)
        ),
        RecentFoodLog(
            id: UUID(),
            name: "Yoğurt",
            calories: 120,
            portion: "1 kase",
            mealType: .breakfast,
            createdAt: Date().addingTimeInterval(-9_400)
        )
    ]

    static let aiInsight = "Bugün proteinin biraz geride. Akşam öğününe 1 porsiyon ızgara tavuk eklemek dengeyi tamamlayabilir."
}
#endif
