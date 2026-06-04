import Foundation
import SwiftData
import UserNotifications

/// Rich notification setup. Registers the `UNNotificationCategory`
/// list once at app launch so the reminder engine can attach the
/// matching category identifier and the action chips show up on the
/// banner.
///
/// Action UX:
///   - **Su ekle**: `.foreground` — opens the app and writes 250 ml
///     through `WaterRepository`. Foreground because the user is most
///     likely already looking at the lock screen and we want to land
///     on the dashboard with the new reading visible.
///   - **+500 ml**: `.destructive` — wait, no. Used `.authenticationRequired = false`
///     so the user can confirm with Face ID off. Still foreground.
///   - **Hatırlat (1 saat)**: `.destructive` flag visually so the user
///     reads it as "stop nudging me" — actually re-schedules the same
///     reminder for `now + 3600`.
///   - **Vazgeç**: built-in dismiss; no Nuvyra-side handler needed.
@MainActor
final class NuvyraNotificationCategoryService {
    static let shared = NuvyraNotificationCategoryService()

    enum Category: String, Sendable {
        case waterReminder = "nuvyra.water.reminder"
        case mealReminder = "nuvyra.meal.reminder"
        case stepReminder = "nuvyra.step.reminder"
    }

    enum Action: String, Sendable {
        case addWater250 = "nuvyra.water.add250"
        case addWater500 = "nuvyra.water.add500"
        case snooze = "nuvyra.snooze1h"
        case logBreakfast = "nuvyra.meal.breakfast"
        case logLunch = "nuvyra.meal.lunch"
        case logDinner = "nuvyra.meal.dinner"
    }

    /// Registered once per app launch — UNUserNotificationCenter dedups
    /// by identifier so calling this twice is safe.
    func registerCategories() {
        let center = UNUserNotificationCenter.current()
        let categories: Set<UNNotificationCategory> = [
            Self.makeWaterCategory(),
            Self.makeMealCategory(),
            Self.makeStepCategory()
        ]
        center.setNotificationCategories(categories)
    }

    // MARK: - Category factories

    private static func makeWaterCategory() -> UNNotificationCategory {
        let add250 = UNNotificationAction(
            identifier: Action.addWater250.rawValue,
            title: "+250 ml",
            options: [.foreground]
        )
        let add500 = UNNotificationAction(
            identifier: Action.addWater500.rawValue,
            title: "+500 ml",
            options: [.foreground]
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze.rawValue,
            title: "1 saat sonra hatırlat",
            options: []
        )
        return UNNotificationCategory(
            identifier: Category.waterReminder.rawValue,
            actions: [add250, add500, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    private static func makeMealCategory() -> UNNotificationCategory {
        let breakfast = UNNotificationAction(
            identifier: Action.logBreakfast.rawValue,
            title: "Kahvaltıyı kaydet",
            options: [.foreground]
        )
        let lunch = UNNotificationAction(
            identifier: Action.logLunch.rawValue,
            title: "Öğleyi kaydet",
            options: [.foreground]
        )
        let dinner = UNNotificationAction(
            identifier: Action.logDinner.rawValue,
            title: "Akşamı kaydet",
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: Category.mealReminder.rawValue,
            actions: [breakfast, lunch, dinner],
            intentIdentifiers: []
        )
    }

    private static func makeStepCategory() -> UNNotificationCategory {
        let snooze = UNNotificationAction(
            identifier: Action.snooze.rawValue,
            title: "30 dakika sonra hatırlat",
            options: []
        )
        return UNNotificationCategory(
            identifier: Category.stepReminder.rawValue,
            actions: [snooze],
            intentIdentifiers: []
        )
    }
}

/// `UNUserNotificationCenter` delegate that routes incoming actions to
/// the right Nuvyra subsystem. Registered from `NuvyraApp` so banner
/// taps and action buttons end up in the right repository write.
///
/// The delegate is intentionally narrow: it doesn't pull in the full
/// dependency container. Instead, the AppDelegate hands it a
/// `NotificationActionRouter` closure that the app sets up at launch.
@MainActor
final class NuvyraNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Closure pumped by `NuvyraApp` once the SwiftData container +
    /// dependency container are alive. Receives the parsed action and
    /// is responsible for executing the corresponding write.
    var actionHandler: ((NuvyraNotificationCategoryService.Action) -> Void)?

    /// Show banners even when the app is foregrounded — Nuvyra
    /// reminders are calm by design, hiding them would feel buggy.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard
            let action = NuvyraNotificationCategoryService.Action(rawValue: response.actionIdentifier)
        else {
            return
        }
        Task { @MainActor in
            self.actionHandler?(action)
        }
    }
}
