import Foundation

enum NotificationCategory: String, CaseIterable, Codable, Identifiable {
    case morningKickoff
    case hydrationMorning
    case hydrationAfternoon
    case hydrationEvening
    case breakfastReminder
    case lunchReminder
    case dinnerReminder
    case eveningWalk
    case eveningReflection
    case weeklySummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningKickoff: "Sabah merhaba"
        case .hydrationMorning: "Sabah suyu"
        case .hydrationAfternoon: "Öğleden sonra suyu"
        case .hydrationEvening: "Akşam suyu"
        case .breakfastReminder: "Kahvaltı kaydı"
        case .lunchReminder: "Öğle kaydı"
        case .dinnerReminder: "Akşam kaydı"
        case .eveningWalk: "Akşam yürüyüşü"
        case .eveningReflection: "Günü kapat"
        case .weeklySummary: "Haftalık özet"
        }
    }

    var subtitle: String {
        switch self {
        case .morningKickoff: "Güne sakin bir karşılama."
        case .hydrationMorning: "Sabah suyunu unutma."
        case .hydrationAfternoon: "Öğleden sonra hidrasyon."
        case .hydrationEvening: "Akşam küçük yudumlar."
        case .breakfastReminder: "Kahvaltını kaydetmeyi hatırla."
        case .lunchReminder: "Öğle öğününü ekle."
        case .dinnerReminder: "Akşam öğününü işle."
        case .eveningWalk: "Kısa bir yürüyüş ritmini kapatır."
        case .eveningReflection: "Bugünkü ritmine kısa bir bakış."
        case .weeklySummary: "Haftalık ritmin pazar akşamı."
        }
    }

    var systemImage: String {
        switch self {
        case .morningKickoff: "sunrise.fill"
        case .hydrationMorning, .hydrationAfternoon, .hydrationEvening: "drop.fill"
        case .breakfastReminder: "sunrise"
        case .lunchReminder: "fork.knife"
        case .dinnerReminder: "moon.stars.fill"
        case .eveningWalk: "figure.walk"
        case .eveningReflection: "sparkles"
        case .weeklySummary: "calendar"
        }
    }

    /// Default trigger time when the user hasn't customized.
    var defaultHour: Int {
        switch self {
        case .morningKickoff: 8
        case .hydrationMorning: 10
        case .hydrationAfternoon: 14
        case .hydrationEvening: 18
        case .breakfastReminder: 9
        case .lunchReminder: 13
        case .dinnerReminder: 19
        case .eveningWalk: 19
        case .eveningReflection: 21
        case .weeklySummary: 20
        }
    }

    var defaultMinute: Int {
        switch self {
        case .morningKickoff: 0
        case .hydrationMorning: 30
        case .hydrationAfternoon: 30
        case .hydrationEvening: 0
        case .breakfastReminder: 0
        case .lunchReminder: 0
        case .dinnerReminder: 0
        case .eveningWalk: 30
        case .eveningReflection: 30
        case .weeklySummary: 0
        }
    }

    var enabledByDefault: Bool {
        switch self {
        case .morningKickoff, .hydrationAfternoon, .lunchReminder, .eveningWalk, .weeklySummary: true
        default: false
        }
    }

    /// Sunday for weekly summary; nil for daily repeating.
    var weekday: Int? {
        switch self {
        case .weeklySummary: 1 // Apple's calendar uses 1 = Sunday
        default: nil
        }
    }

    var grouping: NotificationGrouping {
        switch self {
        case .morningKickoff, .eveningReflection: .reflection
        case .hydrationMorning, .hydrationAfternoon, .hydrationEvening: .hydration
        case .breakfastReminder, .lunchReminder, .dinnerReminder: .meal
        case .eveningWalk: .movement
        case .weeklySummary: .summary
        }
    }
}

enum NotificationGrouping: String, Codable, CaseIterable, Identifiable {
    case reflection
    case hydration
    case meal
    case movement
    case summary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reflection: "Günün ritmi"
        case .hydration: "Su"
        case .meal: "Öğünler"
        case .movement: "Hareket"
        case .summary: "Özetler"
        }
    }

    var subtitle: String {
        switch self {
        case .reflection: "Sabah karşılama ve akşam kapanış."
        case .hydration: "Gün boyunca düşük frekanslı su hatırlatıcıları."
        case .meal: "Öğün kaydı için nazik ipuçları."
        case .movement: "Akşam yürüyüş davetleri."
        case .summary: "Haftanın özeti."
        }
    }

    var systemImage: String {
        switch self {
        case .reflection: "sparkles"
        case .hydration: "drop.fill"
        case .meal: "fork.knife"
        case .movement: "figure.walk"
        case .summary: "calendar"
        }
    }

    var categories: [NotificationCategory] {
        NotificationCategory.allCases.filter { $0.grouping == self }
    }
}

struct NotificationCategoryPreference: Codable, Equatable, Identifiable {
    var category: NotificationCategory
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var id: String { category.rawValue }
}

struct NotificationPreferences: Codable, Equatable {
    var masterEnabled: Bool
    var categories: [NotificationCategoryPreference]

    static let `default` = NotificationPreferences(
        masterEnabled: false,
        categories: NotificationCategory.allCases.map { category in
            NotificationCategoryPreference(
                category: category,
                isEnabled: category.enabledByDefault,
                hour: category.defaultHour,
                minute: category.defaultMinute
            )
        }
    )

    func preference(for category: NotificationCategory) -> NotificationCategoryPreference {
        categories.first(where: { $0.category == category })
            ?? NotificationCategoryPreference(
                category: category,
                isEnabled: category.enabledByDefault,
                hour: category.defaultHour,
                minute: category.defaultMinute
            )
    }

    mutating func update(_ preference: NotificationCategoryPreference) {
        if let index = categories.firstIndex(where: { $0.category == preference.category }) {
            categories[index] = preference
        } else {
            categories.append(preference)
        }
    }

    /// Migrates legacy stores where `categories` may be missing newer entries.
    func migrated() -> NotificationPreferences {
        var result = self
        for category in NotificationCategory.allCases where !result.categories.contains(where: { $0.category == category }) {
            result.categories.append(
                NotificationCategoryPreference(
                    category: category,
                    isEnabled: category.enabledByDefault,
                    hour: category.defaultHour,
                    minute: category.defaultMinute
                )
            )
        }
        return result
    }
}

/// Personal context used by the copywriter to localize notification text.
struct NotificationPersonalContext: Equatable {
    var firstName: String?
    var goalType: GoalType?
    var activityLevel: ActivityLevel?

    var resolvedFirstName: String? {
        guard let name = firstName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return name.split(separator: " ").first.map(String.init)
    }

    static let empty = NotificationPersonalContext(firstName: nil, goalType: nil, activityLevel: nil)
}

struct NotificationContent: Equatable {
    var identifier: String
    var title: String
    var body: String
    var category: NotificationCategory
    var hour: Int
    var minute: Int
    var weekday: Int?
}
