import Foundation

/// One detected behavioural pattern over the recent window. The card UI
/// renders the `headline` + `detail`, tints by `tone`, and uses
/// `systemImage` for the medallion.
struct TrendInsight: Equatable, Identifiable {
    enum Tone: Equatable {
        /// Positive momentum — accent tint, "keep going" framing.
        case encouraging
        /// Gentle nudge — sand tint, an actionable suggestion.
        case nudge
        /// Neutral observation — gray tint.
        case neutral
    }

    let id: String
    let headline: String
    let detail: String
    let tone: Tone
    let systemImage: String
}

/// Multi-day pattern detector. Where `WeeklyInsightEngine` answers
/// "this week vs last week", this one answers "what's been happening
/// across the last N days" — consecutive shortfalls, weekend dips,
/// improving streaks. Pure value-in / value-out so it unit-tests
/// without SwiftData.
@MainActor
protocol TrendInsightEngine {
    func detect(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        endingOn date: Date
    ) throws -> [TrendInsight]
}

@MainActor
struct DefaultTrendInsightEngine: TrendInsightEngine {
    private let calendar: Calendar

    init(calendar: Calendar = .nuvyra) {
        self.calendar = calendar
    }

    func detect(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        endingOn date: Date = Date()
    ) throws -> [TrendInsight] {
        let days = 14
        let nutritionDays = try nutrition.dailySummaries(days: days, endingOn: date)
        let waterDays = try water.dailyTotals(days: days, endingOn: date)
        let walkingLogs = try activity.walkingLogs(days: days, endingOn: date)

        let stepsByDay = Dictionary(
            walkingLogs.map { (calendar.startOfDay(for: $0.date), $0.steps) },
            uniquingKeysWith: { _, last in last }
        )

        var found: [TrendInsight] = []

        if let proteinTrend = proteinShortfallTrend(nutritionDays, profile: profile) {
            found.append(proteinTrend)
        }
        if let weekendWater = weekendWaterDipTrend(waterDays, targetMl: profile?.dailyWaterTargetMl ?? 2_000) {
            found.append(weekendWater)
        }
        if let stepStreak = stepImprovementTrend(stepsByDay: stepsByDay, endingOn: date, goal: profile?.dailyStepTarget ?? 7_500) {
            found.append(stepStreak)
        }
        if let consistency = loggingConsistencyTrend(nutritionDays) {
            found.append(consistency)
        }

        // Cap at the two strongest so the dashboard never turns into a
        // wall of advice. Encouraging signals sort ahead of nudges so
        // the user reads the win first.
        return Array(found.sorted { rank($0.tone) < rank($1.tone) }.prefix(2))
    }

    private func rank(_ tone: TrendInsight.Tone) -> Int {
        switch tone {
        case .encouraging: 0
        case .nudge: 1
        case .neutral: 2
        }
    }

    // MARK: - Detectors

    /// 3+ consecutive recent days below 70% of the protein target.
    private func proteinShortfallTrend(_ days: [DailyMealSummary], profile: UserProfile?) -> TrendInsight? {
        let target = Double(profile?.dailyProteinTargetGrams ?? 120)
        guard target > 0 else { return nil }
        let threshold = target * 0.7

        // Count the trailing run of days (with logged meals) under the
        // threshold. Days with no meals at all don't count as shortfall
        // — they're "didn't track", not "ate low protein".
        var run = 0
        for day in days.reversed() {
            guard day.mealCount > 0 else { break }
            if day.totals.protein < threshold { run += 1 } else { break }
        }
        guard run >= 3 else { return nil }
        return TrendInsight(
            id: "protein.shortfall",
            headline: "\(run) gündür protein hedefinin altındasın",
            detail: "Yoğurt, mercimek veya yumurta gibi küçük eklemeler ortalamanı nazikçe yukarı çeker.",
            tone: .nudge,
            systemImage: "bolt.heart"
        )
    }

    /// Weekend water average noticeably below the weekday average.
    private func weekendWaterDipTrend(_ days: [WaterDayTotal], targetMl: Int) -> TrendInsight? {
        var weekdayTotals: [Int] = []
        var weekendTotals: [Int] = []
        for day in days {
            let weekday = calendar.component(.weekday, from: day.date)
            // Gregorian: 1 = Sunday, 7 = Saturday.
            if weekday == 1 || weekday == 7 {
                weekendTotals.append(day.totalMl)
            } else {
                weekdayTotals.append(day.totalMl)
            }
        }
        guard weekendTotals.count >= 2, weekdayTotals.count >= 3 else { return nil }
        let weekdayAvg = Double(weekdayTotals.reduce(0, +)) / Double(weekdayTotals.count)
        let weekendAvg = Double(weekendTotals.reduce(0, +)) / Double(weekendTotals.count)
        guard weekdayAvg > 0, weekendAvg < weekdayAvg * 0.8 else { return nil }
        let dropPercent = Int(((weekdayAvg - weekendAvg) / weekdayAvg * 100).rounded())
        return TrendInsight(
            id: "water.weekend.dip",
            headline: "Su ritmin hafta sonu %\(dropPercent) düşüyor",
            detail: "Hafta sonu sabahına bir bardak su eklemek bu farkı kapatmanın en sade yolu.",
            tone: .nudge,
            systemImage: "drop.fill"
        )
    }

    /// 4+ consecutive recent days that hit the step goal.
    private func stepImprovementTrend(stepsByDay: [Date: Int], endingOn date: Date, goal: Int) -> TrendInsight? {
        guard goal > 0 else { return nil }
        let startOfEnd = calendar.startOfDay(for: date)
        var run = 0
        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfEnd) ?? startOfEnd
            let steps = stepsByDay[day] ?? 0
            if steps >= goal { run += 1 } else { break }
        }
        guard run >= 4 else { return nil }
        return TrendInsight(
            id: "steps.streak",
            headline: "\(run) gündür adım hedefini tutturuyorsun",
            detail: "Bu tür sakin tutarlılık, tek seferlik büyük çıkışlardan daha kalıcıdır.",
            tone: .encouraging,
            systemImage: "figure.walk.motion"
        )
    }

    /// Logged a meal on 6 of the last 7 days.
    private func loggingConsistencyTrend(_ days: [DailyMealSummary]) -> TrendInsight? {
        let lastSeven = Array(days.suffix(7))
        guard lastSeven.count == 7 else { return nil }
        let loggedDays = lastSeven.filter { $0.mealCount > 0 }.count
        guard loggedDays >= 6 else { return nil }
        return TrendInsight(
            id: "logging.consistency",
            headline: "Son 7 günün \(loggedDays)'sinde öğün kaydı tuttun",
            detail: "Kayıt tutmak, beslenmeni suçlulukla değil farkındalıkla izlemenin en yumuşak yolu.",
            tone: .encouraging,
            systemImage: "checkmark.seal.fill"
        )
    }
}

/// Static stub for previews + tests.
@MainActor
struct MockTrendInsightEngine: TrendInsightEngine {
    var insights: [TrendInsight]
    init(insights: [TrendInsight] = []) { self.insights = insights }
    func detect(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        endingOn date: Date
    ) throws -> [TrendInsight] {
        insights
    }
}
