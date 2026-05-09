import Foundation

#if DEBUG
enum DashboardMockPreviewData {
    static let nutrition = DailyNutritionSummary(consumed: 1_240, burned: 280, target: 1_900)

    static let macros: [MacroSummary] = [
        MacroSummary(kind: .protein, consumedGrams: 78, targetGrams: 120),
        MacroSummary(kind: .carbs, consumedGrams: 132, targetGrams: 210),
        MacroSummary(kind: .fat, consumedGrams: 41, targetGrams: 65)
    ]

    static let water = WaterSummary(consumedMl: 1_400, targetMl: 2_000)

    static let steps = StepSummary(steps: 5_360, goal: 7_500, distanceKm: 3.8, activeEnergyKcal: 280)

    static let recentFoods: [RecentFoodLog] = [
        RecentFoodLog(name: "Mercimek çorbası", mealType: .lunch, calories: 210, portion: "1 kase", loggedAt: Date().addingTimeInterval(-1_800)),
        RecentFoodLog(name: "Izgara tavuk", mealType: .lunch, calories: 360, portion: "1 porsiyon", loggedAt: Date().addingTimeInterval(-3_400)),
        RecentFoodLog(name: "Yoğurt", mealType: .snack, calories: 120, portion: "1 kase", loggedAt: Date().addingTimeInterval(-7_200))
    ]

    static let aiInsight = "Bugün protein hedefinin yarısındasın. Akşam öğününe yumurta veya yoğurt eklemek ritmini dengeleyebilir."

    static let userName = "Furkan"
}
#endif
