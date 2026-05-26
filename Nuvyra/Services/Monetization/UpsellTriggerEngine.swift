import Foundation

/// Behavioral upsell moments. Triggered proactively — *not* when the user
/// touches a premium-gated control (that's the reactive `PremiumFeatureGate`).
/// Designed to fire when the user has lived in the app long enough to
/// appreciate the value premium adds.
enum UpsellTrigger: String, CaseIterable, Codable, Identifiable {
    case oneWeekActive
    case firstStreakReached
    case healthGoalMet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oneWeekActive: "Bir haftadır Nuvyra'dasın 🌱"
        case .firstStreakReached: "İlk streak'ine ulaştın!"
        case .healthGoalMet: "Bugün tüm hedeflerini tamamladın"
        }
    }

    var subtitle: String {
        switch self {
        case .oneWeekActive: "İlk haftanı geride bıraktın. Premium ile gelişimin görünmeyen kısmını da gör — gelişmiş içgörüler, AI koç ve haftalık trendler."
        case .firstStreakReached: "Tutarlılık başlıyor. Premium ile derin analizler, AI sohbet ve barkod taramayla bir adım öteye geç."
        case .healthGoalMet: "Bu ritmi sürdürülebilir kılmak için Premium'un haftalık ritim okuması ve kişisel koç önerileri yardımcı olur."
        }
    }

    var systemImage: String {
        switch self {
        case .oneWeekActive: "calendar.badge.checkmark"
        case .firstStreakReached: "flame.fill"
        case .healthGoalMet: "sparkles"
        }
    }
}

/// Snapshot the engine reads. Keep this a plain value type so it's easy to
/// build in tests and on the main thread.
struct UpsellContext: Equatable {
    var isPremium: Bool
    var firstLaunchAt: Date?
    var lastShownAt: Date?
    var alreadyShown: Set<UpsellTrigger>
    var waterStreak: Int
    var mealStreak: Int
    var stepGoalCompletedToday: Bool
    var waterGoalCompletedToday: Bool
    var calorieGoalCompletedToday: Bool
}

@MainActor
protocol UpsellTriggerEngine {
    /// Returns the highest-priority trigger to surface, or nil if cooldown /
    /// premium status / no qualifying trigger.
    func nextTrigger(context: UpsellContext) -> UpsellTrigger?
}

@MainActor
struct DefaultUpsellTriggerEngine: UpsellTriggerEngine {
    /// Minimum hours between upsell surfacings. Pretty conservative — we'd
    /// rather under-show than annoy.
    var cooldownHours: Int = 24
    /// Hard upper bound: never show more than once per `cooldownHours` even
    /// across different triggers.
    var calendar: Calendar = .nuvyra

    func nextTrigger(context: UpsellContext) -> UpsellTrigger? {
        guard !context.isPremium else { return nil }

        // Cooldown gate — skip everything if we showed an upsell recently.
        if let last = context.lastShownAt,
           let hoursAgo = calendar.dateComponents([.hour], from: last, to: Date()).hour,
           hoursAgo < cooldownHours {
            return nil
        }

        // Priority order: highest-impact moments first.
        let priorityOrder: [UpsellTrigger] = [.firstStreakReached, .healthGoalMet, .oneWeekActive]
        for trigger in priorityOrder where !context.alreadyShown.contains(trigger) {
            if qualifies(trigger: trigger, context: context) {
                return trigger
            }
        }
        return nil
    }

    private func qualifies(trigger: UpsellTrigger, context: UpsellContext) -> Bool {
        switch trigger {
        case .oneWeekActive:
            guard let first = context.firstLaunchAt,
                  let days = calendar.dateComponents([.day], from: first, to: Date()).day else { return false }
            return days >= 7

        case .firstStreakReached:
            return context.waterStreak >= 3 || context.mealStreak >= 3

        case .healthGoalMet:
            return context.stepGoalCompletedToday
                && context.waterGoalCompletedToday
                && context.calorieGoalCompletedToday
        }
    }
}

extension UpsellTrigger {
    /// Round-trip helpers for the comma-joined `AppSettings.shownUpsellTriggers`.
    static func parse(rawList: String) -> Set<UpsellTrigger> {
        let parts = rawList.split(separator: ",").map(String.init)
        return Set(parts.compactMap(UpsellTrigger.init(rawValue:)))
    }

    static func encode(_ set: Set<UpsellTrigger>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}
