import Foundation
import UIKit
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
        await add(id: "nuvyra.meal", title: "Öğün ritmi", body: "Kısa bir öğün kaydı günün resmini netleştirir.", hour: 12, minute: 15)
    }

    private func add(id: String, title: String, body: String, hour: Int, minute: Int) async {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if id == "nuvyra.water" {
            content.categoryIdentifier = NuvyraNotificationCategoryService.Category.waterReminder.rawValue
            content.attachments = Self.makeSymbolAttachment(name: "drop.fill", tint: .systemCyan)
        } else if id == "nuvyra.walk" {
            content.categoryIdentifier = NuvyraNotificationCategoryService.Category.stepReminder.rawValue
            content.attachments = Self.makeSymbolAttachment(name: "figure.walk", tint: .systemGreen)
        } else if id == "nuvyra.meal" {
            content.categoryIdentifier = NuvyraNotificationCategoryService.Category.mealReminder.rawValue
            content.attachments = Self.makeSymbolAttachment(name: "fork.knife", tint: .systemOrange)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func makeSymbolAttachment(name: String, tint: UIColor) -> [UNNotificationAttachment] {
        guard let symbol = UIImage(
            systemName: name,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 56, weight: .bold)
        ) else {
            return []
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160))
        let image = renderer.image { _ in
            tint.withAlphaComponent(0.14).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 160, height: 160), cornerRadius: 32).fill()
            symbol.withTintColor(tint, renderingMode: .alwaysOriginal)
                .draw(in: CGRect(x: 48, y: 48, width: 64, height: 64))
            UIColor.white.withAlphaComponent(0.38).setStroke()
            let stroke = UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: 158, height: 158), cornerRadius: 31)
            stroke.lineWidth = 2
            stroke.stroke()
        }

        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let safeName = name.replacingOccurrences(of: ".", with: "-")
        let url = directory.appendingPathComponent("nuvyra-notification-\(safeName).png")
        guard let data = image.pngData() else { return [] }
        do {
            try data.write(to: url, options: .atomic)
            return [try UNNotificationAttachment(identifier: name, url: url)]
        } catch {
            return []
        }
    }
}

struct MockNotificationService: NotificationService {
    func requestAuthorization() async -> Bool { true }
    func scheduleGentleReminders() async {}
}
