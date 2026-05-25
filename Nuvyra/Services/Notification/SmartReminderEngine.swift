import Foundation
import UserNotifications

/// Snapshot of "where the user is right now" — passed into the engine when the
/// app comes to foreground so the next batch of reminders can speak to today's
/// actual data, not generic static copy.
struct ReminderContext: Equatable {
    var firstName: String
    var caloriesConsumed: Int
    var calorieTarget: Int
    var hasLunchLogged: Bool
    var hasDinnerLogged: Bool
    var waterMl: Int
    var waterTargetMl: Int
    var steps: Int
    var stepTarget: Int
    var waterStreakDays: Int
    var mealStreakDays: Int

    var waterProgress: Double {
        guard waterTargetMl > 0 else { return 0 }
        return min(Double(waterMl) / Double(waterTargetMl), 1)
    }
    var stepProgress: Double {
        guard stepTarget > 0 else { return 0 }
        return min(Double(steps) / Double(stepTarget), 1)
    }

    static let empty = ReminderContext(
        firstName: "Hoş geldin",
        caloriesConsumed: 0,
        calorieTarget: 1_900,
        hasLunchLogged: false,
        hasDinnerLogged: false,
        waterMl: 0,
        waterTargetMl: 2_000,
        steps: 0,
        stepTarget: 7_500,
        waterStreakDays: 0,
        mealStreakDays: 0
    )
}

/// Slot the engine considers when picking what (if anything) to schedule.
enum ReminderSlot: String, CaseIterable {
    case lunch          // 12:30 — öğle kaydı kontrolü
    case afternoonWater // 15:00 — su yüzdesi düşükse
    case dinner         // 19:30 — akşam kaydı kontrolü
    case eveningWalk    // 20:00 — adım eksikse
    case streakNudge    // 21:30 — streak'te ise tebrik

    var hour: Int {
        switch self {
        case .lunch: 12
        case .afternoonWater: 15
        case .dinner: 19
        case .eveningWalk: 20
        case .streakNudge: 21
        }
    }
    var minute: Int {
        switch self {
        case .lunch: 30
        case .afternoonWater: 0
        case .dinner: 30
        case .eveningWalk: 0
        case .streakNudge: 30
        }
    }
    var identifier: String { "nuvyra.smart.\(rawValue)" }
}

/// Engine that turns a `ReminderContext` into 0-N personalised notifications.
/// Uses Apple's `UNUserNotificationCenter` directly — no third-party scheduler.
@MainActor
protocol SmartReminderEngine {
    func reschedule(context: ReminderContext) async
    func cancelAll() async
}

@MainActor
final class LiveSmartReminderEngine: SmartReminderEngine {
    private let center: UNUserNotificationCenter
    private let notificationService: NotificationService

    init(center: UNUserNotificationCenter = .current(), notificationService: NotificationService) {
        self.center = center
        self.notificationService = notificationService
    }

    func reschedule(context: ReminderContext) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        await cancelAll()

        for slot in ReminderSlot.allCases {
            guard let copy = copyFor(slot: slot, context: context) else { continue }
            await schedule(slot: slot, title: copy.title, body: copy.body)
        }
    }

    func cancelAll() async {
        let ids = ReminderSlot.allCases.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Copy bank
    /// Returns `nil` to skip a slot entirely — used when there's no useful
    /// signal to send (e.g. lunch already logged → no lunch nudge needed).
    private func copyFor(slot: ReminderSlot, context: ReminderContext) -> (title: String, body: String)? {
        switch slot {
        case .lunch:
            if context.hasLunchLogged { return nil }
            return (
                "Öğle vakti yaklaştı",
                "\(context.firstName), bugün öğle öğününü kaydetmeyi unutma — ritmini buradan okuyacağız."
            )

        case .afternoonWater:
            let progress = Int(context.waterProgress * 100)
            let remaining = max(context.waterTargetMl - context.waterMl, 0)
            if context.waterProgress >= 1 { return nil }
            if context.waterProgress >= 0.7 {
                return (
                    "Su hedefi yakın",
                    "Hedefin %\(progress)'ında — \(remaining) ml ile bugünkü kaydı tamamlayabilirsin."
                )
            }
            return (
                "Su molası 💧",
                "Bugün su hedefinin %\(progress)'ındasın, \(remaining) ml kaldı. Küçük bir bardak iyi gelir."
            )

        case .dinner:
            if context.hasDinnerLogged { return nil }
            return (
                "Akşam kaydı",
                "Akşam öğününü hızlıca eklemek günlük dengeyi daha net gösteriyor."
            )

        case .eveningWalk:
            if context.stepProgress >= 1 { return nil }
            let remaining = max(context.stepTarget - context.steps, 0)
            return (
                "Kısa yürüyüş zamanı",
                "Hedefe \(remaining.formatted()) adım kaldı — 15-20 dakikalık tempolu bir tur tamamlayabilir."
            )

        case .streakNudge:
            if context.waterStreakDays >= 3 {
                return (
                    "\(context.waterStreakDays) gündür su hedefinde!",
                    "Tutarlılık küçük adımlarla kurulur. Yarın da küçük bir hatırlatıcı olsun, kendine teşekkür et."
                )
            }
            if context.mealStreakDays >= 3 {
                return (
                    "\(context.mealStreakDays) gündür beslenme kaydı tuttun",
                    "Bu basit alışkanlık ritmini görmeni kolaylaştırıyor. Sürdürülebilir olan kazanır."
                )
            }
            return nil
        }
    }

    private func schedule(slot: ReminderSlot, title: String, body: String) async {
        var components = DateComponents()
        components.hour = slot.hour
        components.minute = slot.minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: slot.identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}

@MainActor
struct MockSmartReminderEngine: SmartReminderEngine {
    func reschedule(context: ReminderContext) async {}
    func cancelAll() async {}
}
