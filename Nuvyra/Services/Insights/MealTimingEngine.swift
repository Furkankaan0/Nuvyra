import Foundation

/// One slot's status — whether the user logged a meal of that type today and,
/// if so, the earliest log time for it. The Dashboard timeline uses these to
/// render the chevron row.
struct MealSlotStatus: Equatable, Hashable, Identifiable {
    let meal: MealType
    let logged: Bool
    let loggedAt: Date?

    var id: String { meal.rawValue }
}

/// Single calm, non-judgmental headline + optional detail produced by the
/// timing engine. `Severity` lets the UI tint the hero — `.nudge` adds a
/// soft amber accent, `.calm` stays neutral mint.
struct MealTimingInsight: Equatable {
    enum Severity: Equatable { case calm, nudge }

    let headline: String
    let detail: String?
    let severity: Severity
    let slotStatuses: [MealSlotStatus]
    let hasAnyMeal: Bool

    /// Locale-aware empty state. Defaults to `Locale.current` so the existing
    /// `@Published var mealTiming: MealTimingInsight = .empty` initialisers
    /// keep working; tests pass an explicit locale for determinism.
    static func empty(in locale: Locale = .current) -> MealTimingInsight {
        let copy = MealTimingCopy.resolved(for: locale)
        return MealTimingInsight(
            headline: copy.emptyHeadline,
            detail: copy.emptyDetail,
            severity: .calm,
            slotStatuses: MealType.allCases.map { MealSlotStatus(meal: $0, logged: false, loggedAt: nil) },
            hasAnyMeal: false
        )
    }

    /// Backwards-compatible accessor — preserves call sites that read
    /// `.empty` as a property rather than calling the new factory.
    static var empty: MealTimingInsight { empty(in: .current) }
}

@MainActor
protocol MealTimingEngine {
    func evaluate(meals: [MealEntry], at now: Date) -> MealTimingInsight
}

/// Rule-based engine. Order matters — the first matching rule wins so we can
/// surface the *most actionable* nudge instead of stacking several at once.
@MainActor
struct DefaultMealTimingEngine: MealTimingEngine {
    private let calendar: Calendar
    private let locale: Locale

    init(calendar: Calendar = .nuvyra, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    func evaluate(meals: [MealEntry], at now: Date = Date()) -> MealTimingInsight {
        let copy = MealTimingCopy.resolved(for: locale)
        guard !meals.isEmpty else { return .empty(in: locale) }

        let slotStatuses: [MealSlotStatus] = MealType.allCases.map { type in
            let logs = meals.filter { $0.mealType == type }
            return MealSlotStatus(
                meal: type,
                logged: !logs.isEmpty,
                loggedAt: logs.map(\.date).min()
            )
        }

        let sorted = meals.sorted { $0.date < $1.date }
        guard let lastMeal = sorted.last else { return .empty(in: locale) }
        let hoursSinceLast = max(now.timeIntervalSince(lastMeal.date) / 3600, 0)

        let hour = calendar.component(.hour, from: now)
        let breakfastDone = slotStatuses.first(where: { $0.meal == .breakfast })?.logged ?? false
        let lunchDone = slotStatuses.first(where: { $0.meal == .lunch })?.logged ?? false
        let dinnerDone = slotStatuses.first(where: { $0.meal == .dinner })?.logged ?? false

        // Rule 1 — Skipped breakfast (after 13:00 with no breakfast logged).
        // Highest-priority nudge because the rest of the day's slot detection
        // hinges on having an anchor early meal.
        if hour >= 13 && !breakfastDone {
            return MealTimingInsight(
                headline: copy.skippedBreakfastHeadline,
                detail: copy.skippedBreakfastDetail,
                severity: .nudge,
                slotStatuses: slotStatuses,
                hasAnyMeal: true
            )
        }

        // Rule 2 — Late dinner (21:00+ and dinner still not logged).
        if hour >= 21 && !dinnerDone {
            return MealTimingInsight(
                headline: copy.lateDinnerHeadline,
                detail: copy.lateDinnerDetail,
                severity: .nudge,
                slotStatuses: slotStatuses,
                hasAnyMeal: true
            )
        }

        // Rule 3 — Long gap (5+ hrs since last meal during waking hours).
        if hoursSinceLast >= 5 && hour >= 9 && hour < 22 {
            let lastTitle = copy.lowercased(lastMeal.mealType.title)
            let gap = Int(hoursSinceLast.rounded())
            return MealTimingInsight(
                headline: copy.longGapHeadline(lastSlot: lastTitle, hours: gap),
                detail: copy.longGapDetail,
                severity: .nudge,
                slotStatuses: slotStatuses,
                hasAnyMeal: true
            )
        }

        // Rule 4 — Balanced day, all three main slots covered.
        if breakfastDone && lunchDone && dinnerDone {
            return MealTimingInsight(
                headline: copy.balancedHeadline,
                detail: copy.balancedDetail,
                severity: .calm,
                slotStatuses: slotStatuses,
                hasAnyMeal: true
            )
        }

        // Default — neutral last-meal summary.
        let lastTitle = lastMeal.mealType.title
        let hoursText = copy.relativeHoursText(hours: hoursSinceLast)
        return MealTimingInsight(
            headline: copy.neutralHeadline(lastSlot: lastTitle, hoursText: hoursText),
            detail: nil,
            severity: .calm,
            slotStatuses: slotStatuses,
            hasAnyMeal: true
        )
    }
}

/// Two-language copy bank for the meal timing engine. Sits next to the
/// engine so the rule order and the language stay in sync when either side
/// is tweaked.
struct MealTimingCopy: Sendable {
    let emptyHeadline: String
    let emptyDetail: String
    let skippedBreakfastHeadline: String
    let skippedBreakfastDetail: String
    let lateDinnerHeadline: String
    let lateDinnerDetail: String
    let longGapDetail: String
    let balancedHeadline: String
    let balancedDetail: String

    private let longGap: (_ lastSlot: String, _ hours: Int) -> String
    private let neutral: (_ lastSlot: String, _ hoursText: String) -> String
    private let lowercaseLocale: Locale
    private let justNow: String
    private let hoursAgoSuffix: (Int) -> String

    func longGapHeadline(lastSlot: String, hours: Int) -> String { longGap(lastSlot, hours) }
    func neutralHeadline(lastSlot: String, hoursText: String) -> String { neutral(lastSlot, hoursText) }

    /// "1 saat önce" / "1 hour ago" — locale-aware so the neutral last-meal
    /// summary reads correctly in either language.
    func relativeHoursText(hours: Double) -> String {
        if hours < 1 { return justNow }
        return hoursAgoSuffix(Int(hours.rounded()))
    }

    /// Locale-correct lowercase — Turkish has dotted/dotless i rules so we
    /// can't reuse `Locale.current` blindly.
    func lowercased(_ value: String) -> String {
        value.lowercased(with: lowercaseLocale)
    }

    static func resolved(for locale: Locale) -> MealTimingCopy {
        let code = locale.language.languageCode?.identifier ?? "tr"
        return code == "en" ? .english : .turkish
    }

    static let turkish = MealTimingCopy(
        emptyHeadline: "Bugün için öğün kaydı henüz yok.",
        emptyDetail: "Bir kahvaltı ekledikten sonra burada öğün ritmin görünür.",
        skippedBreakfastHeadline: "Bugün kahvaltı kaydı yok.",
        skippedBreakfastDetail: "Atladıysan da bir bardak su + protein eklemek günün geri kalanına denge getirebilir.",
        lateDinnerHeadline: "Akşam yemeğin sona kayıyor.",
        lateDinnerDetail: "Geç akşam yemekleri uyku ritmini etkileyebilir; hafif bir tabak nazik bir tercih olur.",
        longGapDetail: "Küçük bir atıştırma veya bir bardak su sakin bir mola yaratır.",
        balancedHeadline: "Bugünkü öğün düzenin sakin görünüyor.",
        balancedDetail: "Kahvaltı, öğle ve akşam dengede — devam etmek tek başına anlamlı bir tercih.",
        longGap: { slot, hours in "Son \(slot) üzerinden \(hours) saat geçti." },
        neutral: { slot, text in "Son öğünün: \(slot), \(text)." },
        lowercaseLocale: Locale(identifier: "tr_TR"),
        justNow: "az önce",
        hoursAgoSuffix: { "\($0) saat önce" }
    )

    static let english = MealTimingCopy(
        emptyHeadline: "No meals logged today yet.",
        emptyDetail: "Once you log breakfast, your daily rhythm shows up here.",
        skippedBreakfastHeadline: "Breakfast hasn't been logged today.",
        skippedBreakfastDetail: "Even if you skipped it, a glass of water with some protein can balance the rest of the day.",
        lateDinnerHeadline: "Dinner is drifting late.",
        lateDinnerDetail: "Late dinners can affect sleep — a lighter plate is a kind choice.",
        longGapDetail: "A small snack or a glass of water makes for a calm pause.",
        balancedHeadline: "Today's meal pattern looks calm.",
        balancedDetail: "Breakfast, lunch and dinner are in balance — just staying the course is meaningful.",
        longGap: { slot, hours in "It's been \(hours)h since your \(slot)." },
        neutral: { slot, text in "Your last meal: \(slot), \(text)." },
        lowercaseLocale: Locale(identifier: "en_US"),
        justNow: "just now",
        hoursAgoSuffix: { hours in "\(hours)h ago" }
    )
}

#if DEBUG
extension MealTimingInsight {
    /// Realistic shape used by the SwiftUI preview — breakfast and lunch
    /// logged, dinner pending, 4 h since lunch.
    static let previewSample = MealTimingInsight(
        headline: "Son öğle üzerinden 4 saat geçti.",
        detail: "Küçük bir atıştırma veya bir bardak su sakin bir mola yaratır.",
        severity: .nudge,
        slotStatuses: [
            MealSlotStatus(meal: .breakfast, logged: true, loggedAt: Date().addingTimeInterval(-7 * 3600)),
            MealSlotStatus(meal: .lunch, logged: true, loggedAt: Date().addingTimeInterval(-4 * 3600)),
            MealSlotStatus(meal: .snack, logged: false, loggedAt: nil),
            MealSlotStatus(meal: .dinner, logged: false, loggedAt: nil)
        ],
        hasAnyMeal: true
    )
}
#endif
