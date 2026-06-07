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
    private let locale: Locale

    init(calendar: Calendar = .nuvyra, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    func detect(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        endingOn date: Date = Date()
    ) throws -> [TrendInsight] {
        let copy = TrendInsightCopy.resolved(for: locale)
        let days = 14
        let nutritionDays = try nutrition.dailySummaries(days: days, endingOn: date)
        let waterDays = try water.dailyTotals(days: days, endingOn: date)
        let walkingLogs = try activity.walkingLogs(days: days, endingOn: date)

        let stepsByDay = Dictionary(
            walkingLogs.map { (calendar.startOfDay(for: $0.date), $0.steps) },
            uniquingKeysWith: { _, last in last }
        )

        var found: [TrendInsight] = []

        if let proteinTrend = proteinShortfallTrend(nutritionDays, profile: profile, copy: copy) {
            found.append(proteinTrend)
        }
        if let weekendWater = weekendWaterDipTrend(waterDays, targetMl: profile?.dailyWaterTargetMl ?? 2_000, copy: copy) {
            found.append(weekendWater)
        }
        if let stepStreak = stepImprovementTrend(stepsByDay: stepsByDay, endingOn: date, goal: profile?.dailyStepTarget ?? 7_500, copy: copy) {
            found.append(stepStreak)
        }
        if let consistency = loggingConsistencyTrend(nutritionDays, copy: copy) {
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
    private func proteinShortfallTrend(_ days: [DailyMealSummary], profile: UserProfile?, copy: TrendInsightCopy) -> TrendInsight? {
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
            headline: copy.proteinShortfallHeadline(days: run),
            detail: copy.proteinShortfallDetail,
            tone: .nudge,
            systemImage: "bolt.heart"
        )
    }

    /// Weekend water average noticeably below the weekday average.
    private func weekendWaterDipTrend(_ days: [WaterDayTotal], targetMl: Int, copy: TrendInsightCopy) -> TrendInsight? {
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
            headline: copy.weekendWaterDipHeadline(percent: dropPercent),
            detail: copy.weekendWaterDipDetail,
            tone: .nudge,
            systemImage: "drop.fill"
        )
    }

    /// 4+ consecutive recent days that hit the step goal.
    private func stepImprovementTrend(stepsByDay: [Date: Int], endingOn date: Date, goal: Int, copy: TrendInsightCopy) -> TrendInsight? {
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
            headline: copy.stepStreakHeadline(days: run),
            detail: copy.stepStreakDetail,
            tone: .encouraging,
            systemImage: "figure.walk.motion"
        )
    }

    /// Logged a meal on 6 of the last 7 days.
    private func loggingConsistencyTrend(_ days: [DailyMealSummary], copy: TrendInsightCopy) -> TrendInsight? {
        let lastSeven = Array(days.suffix(7))
        guard lastSeven.count == 7 else { return nil }
        let loggedDays = lastSeven.filter { $0.mealCount > 0 }.count
        guard loggedDays >= 6 else { return nil }
        return TrendInsight(
            id: "logging.consistency",
            headline: copy.loggingConsistencyHeadline(daysLogged: loggedDays),
            detail: copy.loggingConsistencyDetail,
            tone: .encouraging,
            systemImage: "checkmark.seal.fill"
        )
    }
}

/// Two-language copy bank — same pattern as `MealTimingCopy`. Keeps the
/// engine's rule logic and the user-facing language right next to each
/// other so they stay in sync when either side moves.
private typealias TrendDaysBuilder = @Sendable (Int) -> String
private typealias TrendPercentBuilder = @Sendable (Int) -> String

struct TrendInsightCopy: Sendable {
    let proteinShortfallDetail: String
    let weekendWaterDipDetail: String
    let stepStreakDetail: String
    let loggingConsistencyDetail: String

    private let proteinShortfall: TrendDaysBuilder
    private let weekendWaterDip: TrendPercentBuilder
    private let stepStreak: TrendDaysBuilder
    private let loggingConsistency: TrendDaysBuilder

    func proteinShortfallHeadline(days: Int) -> String { proteinShortfall(days) }
    func weekendWaterDipHeadline(percent: Int) -> String { weekendWaterDip(percent) }
    func stepStreakHeadline(days: Int) -> String { stepStreak(days) }
    func loggingConsistencyHeadline(daysLogged: Int) -> String { loggingConsistency(daysLogged) }

    static func resolved(for locale: Locale) -> TrendInsightCopy {
        let code = locale.language.languageCode?.identifier ?? "tr"
        return code == "en" ? .english : .turkish
    }

    static let turkish = TrendInsightCopy(
        proteinShortfallDetail: "Yoğurt, mercimek veya yumurta gibi küçük eklemeler ortalamanı nazikçe yukarı çeker.",
        weekendWaterDipDetail: "Hafta sonu sabahına bir bardak su eklemek bu farkı kapatmanın en sade yolu.",
        stepStreakDetail: "Bu tür sakin tutarlılık, tek seferlik büyük çıkışlardan daha kalıcıdır.",
        loggingConsistencyDetail: "Kayıt tutmak, beslenmeni suçlulukla değil farkındalıkla izlemenin en yumuşak yolu.",
        proteinShortfall: { days in "\(days) gündür protein hedefinin altındasın" },
        weekendWaterDip: { percent in "Su ritmin hafta sonu %\(percent) düşüyor" },
        stepStreak: { days in "\(days) gündür adım hedefini tutturuyorsun" },
        loggingConsistency: { logged in "Son 7 günün \(logged)'sinde öğün kaydı tuttun" }
    )

    static let english = TrendInsightCopy(
        proteinShortfallDetail: "Small additions like yogurt, lentils or eggs can lift your average gently.",
        weekendWaterDipDetail: "A glass of water with your weekend mornings is the simplest way to close that gap.",
        stepStreakDetail: "This kind of calm consistency lasts longer than one-off big pushes.",
        loggingConsistencyDetail: "Logging is the gentlest way to follow your nutrition with awareness, not guilt.",
        proteinShortfall: { days in "Protein has been under target for \(days) days" },
        weekendWaterDip: { percent in "Your water rhythm dips \(percent)% on weekends" },
        stepStreak: { days in "You've hit your step goal \(days) days running" },
        loggingConsistency: { logged in "You logged a meal on \(logged) of the last 7 days" }
    )
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
