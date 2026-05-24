import Foundation
import UserNotifications

/// Lightweight contract over `NotificationService` reserved for the water
/// reminders flow. Lets the UI ask for "schedule daily reminders" / "cancel"
/// without depending on `UNUserNotificationCenter` directly. Real scheduling is
/// optional — the default impl just delegates to the existing gentle reminders.
@MainActor
protocol WaterReminderScheduler {
    var isAvailable: Bool { get async }
    func ensureAuthorization() async -> Bool
    func scheduleHourlyReminders(startHour: Int, endHour: Int) async
    func cancelReminders() async
}

@MainActor
final class DefaultWaterReminderScheduler: WaterReminderScheduler {
    private let notificationService: NotificationService
    private let center: UNUserNotificationCenter
    private let identifierPrefix = "nuvyra.water.reminder"

    init(notificationService: NotificationService, center: UNUserNotificationCenter = .current()) {
        self.notificationService = notificationService
        self.center = center
    }

    var isAvailable: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
    }

    func ensureAuthorization() async -> Bool {
        await notificationService.requestAuthorization()
    }

    func scheduleHourlyReminders(startHour: Int, endHour: Int) async {
        await cancelReminders()
        for hour in stride(from: max(0, startHour), through: min(23, endHour), by: 2) {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let content = UNMutableNotificationContent()
            content.title = "Su molası"
            content.body = "Kısa bir su molası ritmini canlı tutar."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix).\(hour)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

@MainActor
struct MockWaterReminderScheduler: WaterReminderScheduler {
    var isAvailable: Bool { true }
    func ensureAuthorization() async -> Bool { true }
    func scheduleHourlyReminders(startHour: Int, endHour: Int) async {}
    func cancelReminders() async {}
}
