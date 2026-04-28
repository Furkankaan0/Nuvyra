import Foundation

protocol CoachingGenerating {
    func dailyPlan(for profile: UserProfile, meals: [MealLog], steps: StepSnapshot, waterGlasses: Int) -> DailyPlan
    func todayRecommendation(meals: [MealLog], steps: StepSnapshot, waterGlasses: Int) -> CoachingMessage
    func weeklySummary(meals: [MealLog], steps: [StepHistoryDay], waterLogs: [WaterLog]) -> WeeklySummary
}

struct CoachingEngine: CoachingGenerating {
    private let calorieCalculator = CalorieTargetCalculator()

    func dailyPlan(for profile: UserProfile, meals: [MealLog], steps: StepSnapshot, waterGlasses: Int) -> DailyPlan {
        let target = calorieCalculator.target(for: profile)
        return DailyPlan(
            calorieTarget: target,
            stepGoal: steps.goal,
            message: todayRecommendation(meals: meals, steps: steps, waterGlasses: waterGlasses)
        )
    }

    func todayRecommendation(meals: [MealLog], steps: StepSnapshot, waterGlasses: Int) -> CoachingMessage {
        if meals.isEmpty {
            return CoachingMessage(
                title: "İlk öğününü ekleyelim",
                body: "Bugünü kusursuz yapmak zorunda değiliz. İlk öğün kaydı, ritmini görmek için yeterli bir başlangıç.",
                tone: .supportive
            )
        }

        if steps.remainingSteps > 0 {
            return CoachingMessage(
                title: "Bugün için önerim",
                body: "Akşam yemeğinden sonra yaklaşık \(max(steps.estimatedMinutesToFinish, 8)) dakikalık hafif yürüyüş bugünkü hedefi tamamlamana yardımcı olabilir.",
                tone: .practical
            )
        }

        if waterGlasses < 5 {
            return CoachingMessage(
                title: "Küçük bir su molası",
                body: "Bugün adım ritmin iyi. Şimdi bir bardak suyla günü biraz daha dengeli kapatabiliriz.",
                tone: .supportive
            )
        }

        return CoachingMessage(
            title: "Ritmin dengede",
            body: "Bugün iyi bir temel kurdun. Daha fazlası şart değil; sürdürülebilirlik burada başlıyor.",
            tone: .supportive
        )
    }

    func weeklySummary(meals: [MealLog], steps: [StepHistoryDay], waterLogs: [WaterLog]) -> WeeklySummary {
        let averageCalories = averageDailyCalories(from: meals)
        let averageSteps = steps.isEmpty ? 0 : steps.map(\.steps).reduce(0, +) / steps.count
        let bestDay = steps.max(by: { $0.steps < $1.steps }).map { weekdayName(for: $0.date) } ?? "-"
        let challengingDay = steps.min(by: { $0.steps < $1.steps }).map { weekdayName(for: $0.date) } ?? "-"

        return WeeklySummary(
            averageCalories: averageCalories,
            averageSteps: averageSteps,
            bestDay: bestDay,
            challengingDay: challengingDay,
            mealRhythm: meals.count >= 7 ? "Öğün kayıtların haftaya yayılmış." : "Öğün kaydını birkaç güne daha yaymak ritmi daha görünür yapar.",
            waterRhythm: waterLogs.count >= 5 ? "Su hedefin düzenli ilerlemiş." : "Su takibini küçük hatırlatmalarla daha kolaylaştırabiliriz.",
            suggestions: [
                "Akşam yemeğinden sonra 10 dakikalık hafif yürüyüş ekle.",
                "Yoğun günler için hazır bir Türk yemeği favorisi seç.",
                "Su hedefini sabah, öğlen ve akşam küçük parçalara böl."
            ],
            insight: "Bu hafta \(challengingDay) günü ritmin daha düşük kalmış. Haftaya bunu telafi etmek yerine, o güne uygulanabilir küçük bir yürüyüş ve daha sade bir öğün planı ekleyebiliriz."
        )
    }

    private func averageDailyCalories(from meals: [MealLog]) -> Int {
        let grouped = Dictionary(grouping: meals) { DateFormatter.nuvyraDayKey.string(from: $0.loggedAt) }
        guard !grouped.isEmpty else { return 0 }
        let total = grouped.values.map { $0.map(\.calories).reduce(0, +) }.reduce(0, +)
        return total / grouped.count
    }

    private func weekdayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).capitalized(with: Locale(identifier: "tr_TR"))
    }
}
