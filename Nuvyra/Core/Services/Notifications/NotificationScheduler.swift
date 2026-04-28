import Foundation
import UserNotifications

struct NotificationSettings: Codable, Equatable {
    var mealReminderEnabled: Bool
    var waterReminderEnabled: Bool
    var walkingReminderEnabled: Bool
    var weeklySummaryEnabled: Bool
    var preferredHour: Int

    static let gentleDefault = NotificationSettings(
        mealReminderEnabled: true,
        waterReminderEnabled: true,
        walkingReminderEnabled: true,
        weeklySummaryEnabled: true,
        preferredHour: 19
    )
}

enum NotificationPermissionStatus: String, Codable {
    case granted
    case denied
    case provisional
}

protocol NotificationScheduling {
    func requestAuthorization() async -> NotificationPermissionStatus
    func scheduleGentleReminders(settings: NotificationSettings, remainingSteps: Int) async throws
    func cancelAll() async
}

final class NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> NotificationPermissionStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    func scheduleGentleReminders(settings: NotificationSettings, remainingSteps: Int) async throws {
        await cancelAll()
        if settings.walkingReminderEnabled {
            try await schedule(
                id: "walking_evening",
                title: "Kısa bir yürüyüş yeterli olabilir",
                body: "Bugünkü hedefe \(remainingSteps.formatted()) adım kaldı. 8-12 dakikalık hafif bir yürüyüş ritmini toparlayabilir.",
                hour: settings.preferredHour,
                minute: 15
            )
        }
        if settings.waterReminderEnabled {
            try await schedule(
                id: "water_midday",
                title: "Su molası",
                body: "Bir bardak su, bugünkü ritmini küçük ama iyi bir yerden destekler.",
                hour: 14,
                minute: 30
            )
        }
        if settings.weeklySummaryEnabled {
            try await scheduleWeeklySummary()
        }
    }

    func cancelAll() async {
        center.removePendingNotificationRequests(withIdentifiers: ["walking_evening", "water_midday", "weekly_summary"])
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) async throws {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleWeeklySummary() async throws {
        var components = DateComponents()
        components.weekday = 2
        components.hour = 9
        components.minute = 30
        let content = UNMutableNotificationContent()
        content.title = "Haftalık koç özetin hazır"
        content.body = "Geçen haftanın ritmini sakin bir şekilde birlikte okuyalım."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: "weekly_summary", content: content, trigger: trigger))
    }
}

struct PreviewNotificationScheduler: NotificationScheduling {
    func requestAuthorization() async -> NotificationPermissionStatus { .granted }
    func scheduleGentleReminders(settings: NotificationSettings, remainingSteps: Int) async throws {}
    func cancelAll() async {}
}
