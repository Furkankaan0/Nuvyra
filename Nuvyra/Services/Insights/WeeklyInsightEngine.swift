import Foundation

/// Per-metric weekly comparison row. Holds raw averages so the UI can render
/// both the absolute value and the change indicator without re-doing math.
struct WeeklyMetric: Equatable, Hashable, Identifiable {
    enum Kind: String, CaseIterable, Identifiable, Hashable {
        case calories, protein, steps, water

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calories: "Kalori"
            case .protein: "Protein"
            case .steps: "Adım"
            case .water: "Su"
            }
        }

        var systemImage: String {
            switch self {
            case .calories: "flame.fill"
            case .protein: "bolt.heart"
            case .steps: "figure.walk"
            case .water: "drop.fill"
            }
        }

        /// Compact unit suffix shown under the current-week value.
        var unitLabel: String {
            switch self {
            case .calories: "kcal/gün"
            case .protein: "g/gün"
            case .steps: "adım/gün"
            case .water: "ml/gün"
            }
        }
    }

    /// UI grouping for the change indicator (arrow + tint).
    enum Direction: Equatable {
        /// No previous-week baseline — show "İlk hafta" copy instead of a %.
        case baseline
        /// |change| < 5% — treated as effectively flat.
        case flat
        case up
        case down
    }

    let kind: Kind
    let currentAverage: Double
    let previousAverage: Double

    var id: Kind.RawValue { kind.rawValue }

    /// Signed ratio: (current - previous) / previous. `nil` when previous == 0
    /// to avoid an artificial "+∞%" reading on the very first week.
    var changeRatio: Double? {
        guard previousAverage > 0 else { return nil }
        return (currentAverage - previousAverage) / previousAverage
    }

    var direction: Direction {
        guard let ratio = changeRatio else { return .baseline }
        if ratio >= 0.05 { return .up }
        if ratio <= -0.05 { return .down }
        return .flat
    }

    /// Short human-readable change ("↑ %12", "↓ %8", "Aynı", "İlk hafta").
    var changeText: String {
        guard let ratio = changeRatio else { return "İlk hafta" }
        if abs(ratio) < 0.05 { return "Aynı" }
        let percent = Int((abs(ratio) * 100).rounded())
        return direction == .up ? "↑ %\(percent)" : "↓ %\(percent)"
    }

    var currentDisplay: String { Self.formatted(currentAverage, kind: kind) }
    var previousDisplay: String { Self.formatted(previousAverage, kind: kind) }

    private static func formatted(_ value: Double, kind: Kind) -> String {
        switch kind {
        case .calories, .steps, .water:
            return Int(value.rounded()).formatted(.number.locale(Locale(identifier: "tr_TR")))
        case .protein:
            return String(format: "%.0f", value)
        }
    }
}

/// Container the UI consumes. `hasEnoughData == false` when the user has fewer
/// than 2 active days this week — the card renders a soft empty state copy
/// instead of misleading percentages.
struct WeeklyComparison: Equatable {
    let metrics: [WeeklyMetric]
    let storyline: String
    let hasEnoughData: Bool
    let activeDaysThisWeek: Int

    /// Builds an empty comparison localised against `locale`. Defaults to the
    /// device-current locale so production code (`@Published weeklyComparison
    /// = .empty`) can use the property-style accessor without changes; tests
    /// can pin a specific language with `WeeklyComparison.empty(in:)`.
    static func empty(in locale: Locale = .current) -> WeeklyComparison {
        WeeklyComparison(
            metrics: WeeklyMetric.Kind.allCases.map {
                WeeklyMetric(kind: $0, currentAverage: 0, previousAverage: 0)
            },
            storyline: WeeklyStorylineCopy.resolved(for: locale).firstWeek,
            hasEnoughData: false,
            activeDaysThisWeek: 0
        )
    }

    /// Convenience accessor — `WeeklyComparison.empty` keeps compiling for the
    /// existing call sites that don't care about locale injection.
    static var empty: WeeklyComparison { empty(in: .current) }

    #if DEBUG
    /// Realistic-looking comparison shown in SwiftUI previews and Mock-backed
    /// Dashboard runs. Keeps storyline in sync with the metric movement so
    /// preview screenshots stay consistent.
    static let previewSample = WeeklyComparison(
        metrics: [
            WeeklyMetric(kind: .calories, currentAverage: 1_820, previousAverage: 1_710),
            WeeklyMetric(kind: .protein, currentAverage: 92, previousAverage: 78),
            WeeklyMetric(kind: .steps, currentAverage: 7_320, previousAverage: 6_140),
            WeeklyMetric(kind: .water, currentAverage: 1_780, previousAverage: 1_640)
        ],
        storyline: "Bu hafta adım ortalaman geçen haftaya göre %19 daha yüksek. Sakin bir ivme yakalamışsın.",
        hasEnoughData: true,
        activeDaysThisWeek: 6
    )
    #endif
}

@MainActor
protocol WeeklyInsightEngine {
    func computeComparison(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        endingOn date: Date
    ) throws -> WeeklyComparison
}

@MainActor
struct DefaultWeeklyInsightEngine: WeeklyInsightEngine {
    private let calendar: Calendar
    private let locale: Locale

    init(calendar: Calendar = .nuvyra, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    /// Pulls 14 days of data with three repo fetches, slices into prior/current
    /// halves, and averages each metric. The card consuming this expects the
    /// returned arrays to be exactly 14 entries (the repos guarantee that).
    func computeComparison(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        endingOn endDate: Date = Date()
    ) throws -> WeeklyComparison {
        let nutritionDays = try nutrition.dailySummaries(days: 14, endingOn: endDate)
        let waterDays = try water.dailyTotals(days: 14, endingOn: endDate)
        let walkingLogs = try activity.walkingLogs(days: 14, endingOn: endDate)

        let stepsByDay: [Date: Int] = Dictionary(
            walkingLogs.map { (calendar.startOfDay(for: $0.date), $0.steps) },
            uniquingKeysWith: { _, last in last }
        )
        let stepsSeries = stepSeries(endingOn: endDate, days: 14, stepsByDay: stepsByDay)

        // Slice [0..<7] = prior week (oldest → newest), [7..<14] = current week.
        let priorIdx = 0..<7
        let currentIdx = 7..<14

        let currentCalories = average(nutritionDays[currentIdx].map { Double($0.totals.calories) })
        let priorCalories = average(nutritionDays[priorIdx].map { Double($0.totals.calories) })

        let currentProtein = average(nutritionDays[currentIdx].map { $0.totals.protein })
        let priorProtein = average(nutritionDays[priorIdx].map { $0.totals.protein })

        let currentWater = average(waterDays[currentIdx].map { Double($0.totalMl) })
        let priorWater = average(waterDays[priorIdx].map { Double($0.totalMl) })

        let currentSteps = average(stepsSeries[currentIdx].map { Double($0) })
        let priorSteps = average(stepsSeries[priorIdx].map { Double($0) })

        let metrics: [WeeklyMetric] = [
            WeeklyMetric(kind: .calories, currentAverage: currentCalories, previousAverage: priorCalories),
            WeeklyMetric(kind: .protein, currentAverage: currentProtein, previousAverage: priorProtein),
            WeeklyMetric(kind: .steps, currentAverage: currentSteps, previousAverage: priorSteps),
            WeeklyMetric(kind: .water, currentAverage: currentWater, previousAverage: priorWater)
        ]

        // "Active day this week" = at least one logged meal, water entry, or
        // recorded steps. We use this to decide whether to show real numbers
        // or the soft empty-state copy.
        let activeDays = (0..<7).reduce(0) { count, offset in
            let cIdx = 7 + offset
            let hasMeals = nutritionDays[cIdx].mealCount > 0
            let hasWater = waterDays[cIdx].totalMl > 0
            let hasSteps = stepsSeries[cIdx] > 0
            return count + ((hasMeals || hasWater || hasSteps) ? 1 : 0)
        }

        let hasEnoughData = activeDays >= 2
        let storyline = Self.makeStoryline(
            metrics: metrics,
            activeDaysThisWeek: activeDays,
            hasEnoughData: hasEnoughData,
            locale: locale
        )

        return WeeklyComparison(
            metrics: metrics,
            storyline: storyline,
            hasEnoughData: hasEnoughData,
            activeDaysThisWeek: activeDays
        )
    }

    // MARK: - Helpers

    private func average(_ values: some Collection<Double>) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Produces an oldest → newest int series of steps for `days` days ending
    /// on `endDate`, defaulting to 0 for days that have no `WalkingLog` row.
    private func stepSeries(endingOn endDate: Date, days: Int, stepsByDay: [Date: Int]) -> [Int] {
        let startOfEnd = calendar.startOfDay(for: endDate)
        return (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfEnd) ?? startOfEnd
            return stepsByDay[day] ?? 0
        }
    }

    /// Calm, non-judgmental, non-medical storyline. Never references weight
    /// loss/gain. Picks the most pronounced movement (positive first, then
    /// negative) and falls back to a gentle "you're holding the rhythm" line.
    ///
    /// `locale` toggles between the Turkish and English copy banks; the
    /// branching is structural so the same rule fires regardless of language.
    static func makeStoryline(
        metrics: [WeeklyMetric],
        activeDaysThisWeek: Int,
        hasEnoughData: Bool,
        locale: Locale = .current
    ) -> String {
        let copy = WeeklyStorylineCopy.resolved(for: locale)
        guard hasEnoughData else { return copy.needsMoreData }

        let comparable = metrics.compactMap { metric -> (WeeklyMetric, Double)? in
            guard let ratio = metric.changeRatio else { return nil }
            return (metric, ratio)
        }

        guard !comparable.isEmpty else { return copy.firstWeek }

        let positives = comparable
            .filter { $0.1 >= 0.05 }
            .sorted { abs($0.1) > abs($1.1) }
        let negatives = comparable
            .filter { $0.1 <= -0.05 }
            .sorted { abs($0.1) > abs($1.1) }

        if let top = positives.first, abs(top.1) >= 0.10 {
            let percent = Int((abs(top.1) * 100).rounded())
            return copy.positive(for: top.0.kind, percent: percent)
        }

        if let bottom = negatives.first, abs(bottom.1) >= 0.15 {
            let percent = Int((abs(bottom.1) * 100).rounded())
            return copy.negative(for: bottom.0.kind, percent: percent)
        }

        return copy.holdingSteady
    }
}

/// Two-language copy bank for the weekly storyline. Lives next to the engine
/// so the rules and the language sit in the same file and stay in sync.
struct WeeklyStorylineCopy: Sendable {
    let needsMoreData: String
    let firstWeek: String
    let holdingSteady: String
    private let positive: [WeeklyMetric.Kind: (Int) -> String]
    private let negative: [WeeklyMetric.Kind: (Int) -> String]

    func positive(for kind: WeeklyMetric.Kind, percent: Int) -> String {
        positive[kind]?(percent) ?? holdingSteady
    }

    func negative(for kind: WeeklyMetric.Kind, percent: Int) -> String {
        negative[kind]?(percent) ?? holdingSteady
    }

    static func resolved(for locale: Locale) -> WeeklyStorylineCopy {
        let code = locale.language.languageCode?.identifier ?? "tr"
        return code == "en" ? .english : .turkish
    }

    static let turkish = WeeklyStorylineCopy(
        needsMoreData: "Geçen haftaya kıyasla net bir karşılaştırma için birkaç güne yayılmış kayda ihtiyaç var. Bugün küçük bir öğün veya su kaydı eklemek yeter.",
        firstWeek: "Bu hafta yeni bir başlangıç gibi görünüyor. Geçen haftayla karşılaştırma için birkaç güne yayılmış kayıt yeter.",
        holdingSteady: "Bu hafta geçen haftayla benzer bir ritimde. Devam etmek tek başına anlamlı bir tercih.",
        positive: [
            .steps: { p in "Bu hafta adım ortalaman geçen haftaya göre %\(p) daha yüksek. Sakin bir ivme yakalamışsın." },
            .water: { p in "Su ritmin geçen haftadan %\(p) güçlü. Vücudunun ona ihtiyacı olan denge giderek oturuyor." },
            .protein: { p in "Protein ortalaman geçen haftadan %\(p) daha iyi. Toparlanmana yardım eden küçük bir adım." },
            .calories: { p in "Kalori takibin geçen haftaya göre %\(p) daha düzenli görünüyor." }
        ],
        negative: [
            .steps: { p in "Bu hafta adım ortalaman geçen haftadan %\(p) düşük. 15 dakikalık kısa bir yürüyüş ritmi geri getirebilir." },
            .water: { p in "Su tüketimin geçen haftadan %\(p) geride. Yarına bir bardak daha eklemek küçük bir dokunuş." },
            .protein: { p in "Protein ortalaman geçen haftadan %\(p) düşmüş. Bir öğünde yoğurt veya yumurta nazik bir denge sağlar." },
            .calories: { p in "Kalori kaydın bu hafta geçen haftadan %\(p) az. Kayıt tutmak farkındalığını koruyan en yumuşak araç." }
        ]
    )

    static let english = WeeklyStorylineCopy(
        needsMoreData: "We need a few more days of logs to compare with last week. Even a small meal or water entry today helps.",
        firstWeek: "This week looks like a fresh start. A few more days of logs will unlock last-week comparisons.",
        holdingSteady: "This week mirrors last week's rhythm. Staying the course is itself a meaningful choice.",
        positive: [
            .steps: { p in "Your daily step average is \(p)% higher than last week. A calm momentum is building." },
            .water: { p in "Your hydration rhythm is \(p)% stronger than last week. The balance your body needs is settling in." },
            .protein: { p in "Your protein average is \(p)% better than last week — a small step that supports recovery." },
            .calories: { p in "Your calorie tracking looks \(p)% more consistent than last week." }
        ],
        negative: [
            .steps: { p in "Your step average is \(p)% lower than last week. A 15-minute walk can ease you back into the rhythm." },
            .water: { p in "Your water intake is \(p)% behind last week. Adding one more glass tomorrow is a gentle nudge." },
            .protein: { p in "Your protein average is \(p)% below last week. Yogurt or an egg with one meal brings a kind balance." },
            .calories: { p in "Your calorie logs are \(p)% lighter than last week. Logging itself is the gentlest tool to stay aware." }
        ]
    )
}

/// In-memory stub for SwiftUI previews and unit tests. The default initialiser
/// returns the same shape as `WeeklyComparison.empty`; callers can pass any
/// pre-built `WeeklyComparison` to drive richer preview states.
@MainActor
struct MockWeeklyInsightEngine: WeeklyInsightEngine {
    let comparison: WeeklyComparison

    init(comparison: WeeklyComparison = .empty) {
        self.comparison = comparison
    }

    func computeComparison(
        nutrition: NutritionRepository,
        water: WaterRepository,
        activity: ActivityRepository,
        endingOn date: Date
    ) throws -> WeeklyComparison {
        comparison
    }
}
