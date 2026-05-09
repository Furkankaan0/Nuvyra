import Foundation
import UserNotifications

protocol NotificationService {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    /// Schedule personalized reminders. Pass nil context for defaults (no name / no goal).
    func schedule(preferences: NotificationPreferences, context: NotificationPersonalContext) async
    func cancelAll() async
    /// Backward-compatible default schedule used by older call sites.
    func scheduleGentleReminders() async
}

// Quiet-hour bounds — no notifications outside this window even if user picks a time.
struct NotificationQuietHours {
    static let startHour = 7
    static let endHour = 22
    static let endMinute = 30

    static func isWithinAllowedHours(hour: Int, minute: Int) -> Bool {
        if hour < startHour { return false }
        if hour > endHour { return false }
        if hour == endHour && minute > endMinute { return false }
        return true
    }
}

final class LiveNotificationService: NotificationService {
    private let center: UNUserNotificationCenter
    private let copywriter: NotificationCopywriter
    /// Identifier prefix used so we can wipe everything Nuvyra schedules without
    /// touching foreign categories registered by app extensions in the future.
    private let identifierPrefix = "nuvyra.notif."

    init(center: UNUserNotificationCenter = .current(),
         copywriter: NotificationCopywriter = NotificationCopywriter()) {
        self.center = center
        self.copywriter = copywriter
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func schedule(preferences: NotificationPreferences, context: NotificationPersonalContext) async {
        await cancelAll()
        guard preferences.masterEnabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        for preference in preferences.categories where preference.isEnabled {
            guard NotificationQuietHours.isWithinAllowedHours(hour: preference.hour, minute: preference.minute) else { continue }
            let copy = copywriter.compose(category: preference.category, context: context)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.threadIdentifier = preference.category.grouping.rawValue
            content.userInfo = ["category": preference.category.rawValue]

            var components = DateComponents()
            components.hour = preference.hour
            components.minute = preference.minute
            if let weekday = preference.category.weekday {
                components.weekday = weekday
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = identifierPrefix + preference.category.rawValue
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let nuvyraIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        if !nuvyraIds.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: nuvyraIds)
        }
        // Legacy ids from earlier builds.
        center.removePendingNotificationRequests(withIdentifiers: ["nuvyra.water", "nuvyra.walk", "nuvyra.meal", "nuvyra.weekly"])
    }

    func scheduleGentleReminders() async {
        // Backward-compatible path: enable a sensible default subset with no personal context.
        var preferences = NotificationPreferences.default
        preferences.masterEnabled = true
        await schedule(preferences: preferences, context: .empty)
    }
}

struct MockNotificationService: NotificationService {
    func requestAuthorization() async -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func schedule(preferences: NotificationPreferences, context: NotificationPersonalContext) async {}
    func cancelAll() async {}
    func scheduleGentleReminders() async {}
}
