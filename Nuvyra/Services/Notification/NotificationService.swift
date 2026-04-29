import Foundation
import UserNotifications

protocol NotificationService {
    func requestAuthorization() async -> Bool
    func scheduleGentleReminders() async
}

final class LiveNotificationService: NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func scheduleGentleReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: ["nuvyra.water", "nuvyra.walk", "nuvyra.meal", "nuvyra.weekly"])
        await add(id: "nuvyra.water", title: "Su molası", body: "Bir bardak su, bugünkü ritmini nazikçe destekler.", hour: 14, minute: 30)
        await add(id: "nuvyra.walk", title: "Kısa yürüyüş zamanı", body: "Kısa bir yürüyüş ritmini tamamlamana yardımcı olabilir.", hour: 19, minute: 10)
    }

    private func add(id: String, title: String, body: String, hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

struct MockNotificationService: NotificationService {
    func requestAuthorization() async -> Bool { true }
    func scheduleGentleReminders() async {}
}
