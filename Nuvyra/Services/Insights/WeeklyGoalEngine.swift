import Foundation

/// One tracked weekly goal — how many of the last 7 days hit the daily
/// target for a given metric. Computed from existing logs, so there's
/// no new persistence to migrate.
struct WeeklyGoalProgress: Identifiable, Equatable {
    enum Metric: String, CaseIterable, Identifiable {
        case steps, water, calories, protein
        var id: String { rawValue }

        /// Locale-aware human title. Engine resolves via `WeeklyGoalCopy`;
        /// callers that don't have a locale fall back to Turkish so the
        /// existing TR-only UI keeps working.
        func title(in locale: Locale = .current) -> String {
            WeeklyGoalCopy.resolved(for: locale).metricTitle(for: self)
        }

        /// Backwards-compatible accessor — preserves call sites that read
        /// `.title` as a property.
        var title: String { title(in: .current) }

        var systemImage: String {
            switch self {
            case .steps: "figure.walk"
            case .water: "drop.fill"
            case .calories: "flame.fill"
            case .protein: "bolt.heart"
            }
        }
    }

    let metric: Metric
    /// Days (of the last 7) that hit the target.
    let daysHit: Int
    /// Always 7 — kept explicit so the UI doesn't hardcode it.
    let totalDays: Int

    var id: String { metric.rawValue }
    var fraction: Double { totalDays > 0 ? Double(daysHit) / Double(totalDays) : 0 }
    /// A metric "passes" its weekly goal at 5/7 — the calm-coach bar is
    /// "most days", not "every day".
    var isAchieved: Bool { daysHit >= 5 }
}

/// A milestone the user has earned. Badges are derived, not stored —
/// re-computed each load from the streak / goal data. Keeps the model
/// layer clean and means a user who reinstalls re-earns the same badges
/// from their synced history.
struct NuvyraBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    /// True once the user meets the badge's condition. Locked badges
    /// still render (greyed) so the user can see what's next.
    let isEarned: Bool
}

/// Rolled-up weekly goal snapshot the UI consumes.
struct WeeklyGoalSummary: Equatable {
    let progress: [WeeklyGoalProgress]
    let badges: [NuvyraBadge]
    /// 0–1 overall: average of the per-metric fractions. Drives the
    /// header ring.
    let overallFraction: Double
    /// Count of metrics that hit their weekly goal (≥5/7).
    var achievedCount: Int { progress.filter(\.isAchieved).count }

    static let empty = WeeklyGoalSummary(progress: [], badges: [], overallFraction: 0)
}

@MainActor
protocol WeeklyGoalEngine {
    func summary(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        mealStreak: StreakInsight,
        waterStreak: StreakInsight,
        endingOn date: Date
    ) throws -> WeeklyGoalSummary
}

@MainActor
struct DefaultWeeklyGoalEngine: WeeklyGoalEngine {
    private let calendar: Calendar
    private let locale: Locale
    init(calendar: Calendar = .nuvyra, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    func summary(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        mealStreak: StreakInsight,
        waterStreak: StreakInsight,
        endingOn date: Date = Date()
    ) throws -> WeeklyGoalSummary {
        let stepTarget = profile?.dailyStepTarget ?? 7_500
        let waterTarget = profile?.dailyWaterTargetMl ?? 2_000
        let calorieTarget = profile?.dailyCalorieTarget ?? 1_900
        let proteinTarget = Double(profile?.dailyProteinTargetGrams ?? 120)

        let nutritionDays = try nutrition.dailySummaries(days: 7, endingOn: date)
        let waterDays = try water.dailyTotals(days: 7, endingOn: date)
        let walkingLogs = try activity.walkingLogs(days: 7, endingOn: date)
        let stepsByDay = Dictionary(
            walkingLogs.map { (calendar.startOfDay(for: $0.date), $0.steps) },
            uniquingKeysWith: { _, last in last }
        )

        // Steps — day counts as hit at or above goal.
        let stepsHit = (0..<7).reduce(0) { acc, offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date)) ?? date
            return acc + ((stepsByDay[day] ?? 0) >= stepTarget ? 1 : 0)
        }

        // Water — hit at or above target.
        let waterHit = waterDays.filter { $0.totalMl >= waterTarget }.count

        // Calories — "hit" means within a sensible band (80–110% of
        // target). Both starving and bingeing miss the goal.
        let caloriesHit = nutritionDays.filter { day in
            guard day.mealCount > 0 else { return false }
            let ratio = Double(day.totals.calories) / Double(max(calorieTarget, 1))
            return ratio >= 0.8 && ratio <= 1.1
        }.count

        // Protein — at or above target.
        let proteinHit = nutritionDays.filter { $0.totals.protein >= proteinTarget }.count

        let progress = [
            WeeklyGoalProgress(metric: .steps, daysHit: stepsHit, totalDays: 7),
            WeeklyGoalProgress(metric: .water, daysHit: waterHit, totalDays: 7),
            WeeklyGoalProgress(metric: .calories, daysHit: caloriesHit, totalDays: 7),
            WeeklyGoalProgress(metric: .protein, daysHit: proteinHit, totalDays: 7)
        ]

        let overall = progress.map(\.fraction).reduce(0, +) / Double(progress.count)
        let badges = makeBadges(
            progress: progress,
            mealStreak: mealStreak,
            waterStreak: waterStreak,
            copy: WeeklyGoalCopy.resolved(for: locale)
        )

        return WeeklyGoalSummary(progress: progress, badges: badges, overallFraction: overall)
    }

    /// Derives the badge set. Earned state is recomputed each load — no
    /// persistence. Locked badges still render so the user sees the
    /// next target.
    private func makeBadges(
        progress: [WeeklyGoalProgress],
        mealStreak: StreakInsight,
        waterStreak: StreakInsight,
        copy: WeeklyGoalCopy
    ) -> [NuvyraBadge] {
        let allAchieved = progress.allSatisfy(\.isAchieved)
        let bestStreak = max(mealStreak.longestStreak, waterStreak.longestStreak)

        return [
            NuvyraBadge(
                id: "badge.week.balanced",
                title: copy.balancedWeekTitle,
                detail: copy.balancedWeekDetail,
                systemImage: "checkmark.seal.fill",
                isEarned: allAchieved
            ),
            NuvyraBadge(
                id: "badge.streak.7",
                title: copy.streak7Title,
                detail: copy.streak7Detail,
                systemImage: "flame.fill",
                isEarned: bestStreak >= 7
            ),
            NuvyraBadge(
                id: "badge.streak.30",
                title: copy.streak30Title,
                detail: copy.streak30Detail,
                systemImage: "crown.fill",
                isEarned: bestStreak >= 30
            ),
            NuvyraBadge(
                id: "badge.steps.week",
                title: copy.stepsWeekTitle,
                detail: copy.stepsWeekDetail,
                systemImage: "figure.walk.motion",
                isEarned: progress.first { $0.metric == .steps }?.isAchieved ?? false
            )
        ]
    }
}

/// Two-language copy bank for `WeeklyGoalEngine` — same pattern as the
/// other engine copy banks. Drives the metric titles + the four badge
/// strings; everything else is data-driven.
struct WeeklyGoalCopy: Sendable {
    let stepsTitle: String
    let waterTitle: String
    let caloriesTitle: String
    let proteinTitle: String

    let balancedWeekTitle: String
    let balancedWeekDetail: String
    let streak7Title: String
    let streak7Detail: String
    let streak30Title: String
    let streak30Detail: String
    let stepsWeekTitle: String
    let stepsWeekDetail: String

    func metricTitle(for metric: WeeklyGoalProgress.Metric) -> String {
        switch metric {
        case .steps: stepsTitle
        case .water: waterTitle
        case .calories: caloriesTitle
        case .protein: proteinTitle
        }
    }

    static func resolved(for locale: Locale) -> WeeklyGoalCopy {
        let code = locale.language.languageCode?.identifier ?? "tr"
        return code == "en" ? .english : .turkish
    }

    static let turkish = WeeklyGoalCopy(
        stepsTitle: "Adım",
        waterTitle: "Su",
        caloriesTitle: "Kalori",
        proteinTitle: "Protein",
        balancedWeekTitle: "Dengeli hafta",
        balancedWeekDetail: "Bu hafta dört hedefin de çoğu günde tamam.",
        streak7Title: "7 gün ritim",
        streak7Detail: "7 günlük bir alışkanlık serisi tamamla.",
        streak30Title: "30 gün ritim",
        streak30Detail: "Bir aylık tutarlılık — kalıcı alışkanlık.",
        stepsWeekTitle: "Yürüyüş haftası",
        stepsWeekDetail: "Adım hedefini haftanın çoğunda tuttur."
    )

    static let english = WeeklyGoalCopy(
        stepsTitle: "Steps",
        waterTitle: "Water",
        caloriesTitle: "Calories",
        proteinTitle: "Protein",
        balancedWeekTitle: "Balanced week",
        balancedWeekDetail: "All four goals hit on most days this week.",
        streak7Title: "7-day rhythm",
        streak7Detail: "Build a 7-day habit streak.",
        streak30Title: "30-day rhythm",
        streak30Detail: "A month of consistency — a lasting habit.",
        stepsWeekTitle: "Walking week",
        stepsWeekDetail: "Hit your step goal on most days of the week."
    )
}

/// Static stub for previews + tests.
@MainActor
struct MockWeeklyGoalEngine: WeeklyGoalEngine {
    var summaryValue: WeeklyGoalSummary
    init(summary: WeeklyGoalSummary = .empty) { self.summaryValue = summary }
    func summary(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        profile: UserProfile?,
        mealStreak: StreakInsight,
        waterStreak: StreakInsight,
        endingOn date: Date
    ) throws -> WeeklyGoalSummary {
        summaryValue
    }
}

extension WeeklyGoalSummary {
    static let previewSample = WeeklyGoalSummary(
        progress: [
            WeeklyGoalProgress(metric: .steps, daysHit: 6, totalDays: 7),
            WeeklyGoalProgress(metric: .water, daysHit: 5, totalDays: 7),
            WeeklyGoalProgress(metric: .calories, daysHit: 4, totalDays: 7),
            WeeklyGoalProgress(metric: .protein, daysHit: 3, totalDays: 7)
        ],
        badges: [
            NuvyraBadge(id: "badge.steps.week", title: "Yürüyüş haftası", detail: "Adım hedefini haftanın çoğunda tuttur.", systemImage: "figure.walk.motion", isEarned: true),
            NuvyraBadge(id: "badge.streak.7", title: "7 gün ritim", detail: "7 günlük bir alışkanlık serisi tamamla.", systemImage: "flame.fill", isEarned: true),
            NuvyraBadge(id: "badge.week.balanced", title: "Dengeli hafta", detail: "Bu hafta dört hedefin de çoğu günde tamam.", systemImage: "checkmark.seal.fill", isEarned: false),
            NuvyraBadge(id: "badge.streak.30", title: "30 gün ritim", detail: "Bir aylık tutarlılık.", systemImage: "crown.fill", isEarned: false)
        ],
        overallFraction: 0.64
    )
}
