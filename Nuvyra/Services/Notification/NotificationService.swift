import Foundation
import UserNotifications

/// User-specific routine that drives notification scheduling. Captured
/// during onboarding (and editable later from settings).
struct DailyRoutine: Equatable {
    /// Hour the user typically wakes up (0…23).
    var wakeHour: Int
    var wakeMinute: Int
    /// Hour the user typically goes to sleep (0…23). May be < wake for
    /// night-shift users; the active window then wraps midnight.
    var sleepHour: Int
    var sleepMinute: Int

    static let `default` = DailyRoutine(wakeHour: 7, wakeMinute: 0, sleepHour: 23, sleepMinute: 0)

    /// Builds a routine from the (optional) values stored on
    /// `UserProfile`. Falls back to a sensible default whenever any
    /// component is missing.
    static func resolved(wakeHour: Int?, wakeMinute: Int?, sleepHour: Int?, sleepMinute: Int?) -> DailyRoutine {
        DailyRoutine(
            wakeHour: wakeHour ?? DailyRoutine.default.wakeHour,
            wakeMinute: wakeMinute ?? DailyRoutine.default.wakeMinute,
            sleepHour: sleepHour ?? DailyRoutine.default.sleepHour,
            sleepMinute: sleepMinute ?? DailyRoutine.default.sleepMinute
        )
    }
}

/// Mirrors `UNAuthorizationStatus` minus the bits we don't care about.
/// Lets the UI react to "needs Settings deeplink" without importing
/// UserNotifications.
enum NotificationAuthorizationState: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

/// Notification category / action identifiers. Strings live in one
/// place so the service that schedules and the delegate that handles
/// taps can't drift.
enum NotificationIdentifier {
    enum Category {
        static let waterReminder = "nuvyra.category.water"
        static let walkReminder = "nuvyra.category.walk"
    }
    enum Action {
        static let addWater250 = "nuvyra.action.water.250"
        static let addWater500 = "nuvyra.action.water.500"
        static let startWalkingFocus = "nuvyra.action.walk.start"
    }
    enum UserInfo {
        static let waterAmountKey = "amount_ml"
    }
    enum Request {
        static let morningWater = "nuvyra.request.water.morning"
        static let middayWater = "nuvyra.request.water.midday"
        static let eveningWalk = "nuvyra.request.walk.evening"
        static let weekly = "nuvyra.request.weekly"
        /// Older fixed-time identifiers we used to schedule under. Kept
        /// here so we can tear them down on first launch after upgrade.
        static let legacy: [String] = ["nuvyra.water", "nuvyra.walk", "nuvyra.meal", "nuvyra.weekly"]
    }
}

protocol NotificationService {
    /// Reads the system-side authorization status without prompting.
    /// Use this on every foreground refresh so the UI banner stays in
    /// sync if the user toggles Settings outside the app.
    func authorizationStatus() async -> NotificationAuthorizationState
    func requestAuthorization() async -> Bool
    /// Re-builds the schedule from scratch. Idempotent — safe to call
    /// every time `routine` changes (onboarding completion, settings
    /// edit) and on every cold launch.
    func scheduleGentleReminders(routine: DailyRoutine) async
    /// Removes every scheduled Nuvyra reminder. Used when the user
    /// turns notifications off in our settings.
    func cancelAll() async
}

final class LiveNotificationService: NotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        registerCategories()
    }

    func authorizationStatus() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .notDetermined
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func scheduleGentleReminders(routine: DailyRoutine) async {
        // Drop both the legacy fixed-time requests and any current ones
        // so a routine change doesn't leave stale fires queued.
        let allIdentifiers = NotificationIdentifier.Request.legacy + [
            NotificationIdentifier.Request.morningWater,
            NotificationIdentifier.Request.middayWater,
            NotificationIdentifier.Request.eveningWalk,
            NotificationIdentifier.Request.weekly
        ]
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)

        let plan = SchedulePlan(routine: routine)

        await add(
            id: NotificationIdentifier.Request.morningWater,
            categoryId: NotificationIdentifier.Category.waterReminder,
            title: "Güne suyla başla",
            body: "Uyandıktan sonra bir bardak su, gün boyu nazik bir başlangıç.",
            triggerAt: plan.morningWater
        )
        await add(
            id: NotificationIdentifier.Request.middayWater,
            categoryId: NotificationIdentifier.Category.waterReminder,
            title: "Su molası",
            body: "Bir bardak su, bugünkü ritmini nazikçe destekler.",
            triggerAt: plan.middayWater
        )
        await add(
            id: NotificationIdentifier.Request.eveningWalk,
            categoryId: NotificationIdentifier.Category.walkReminder,
            title: "Kısa yürüyüş zamanı",
            body: "12 dakikalık nazik bir yürüyüş günün dengesini tamamlar.",
            triggerAt: plan.eveningWalk
        )
    }

    func cancelAll() async {
        let allIdentifiers = NotificationIdentifier.Request.legacy + [
            NotificationIdentifier.Request.morningWater,
            NotificationIdentifier.Request.middayWater,
            NotificationIdentifier.Request.eveningWalk,
            NotificationIdentifier.Request.weekly
        ]
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
    }

    // MARK: - Categories

    /// Register interactive categories on every init so the system
    /// always has the latest action set even if a previous build
    /// registered a stripped-down version.
    private func registerCategories() {
        let add250 = UNNotificationAction(
            identifier: NotificationIdentifier.Action.addWater250,
            title: "+250 ml ekle",
            options: []
        )
        let add500 = UNNotificationAction(
            identifier: NotificationIdentifier.Action.addWater500,
            title: "+500 ml ekle",
            options: []
        )
        let waterCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.Category.waterReminder,
            actions: [add250, add500],
            intentIdentifiers: [],
            options: []
        )

        let walkAction = UNNotificationAction(
            identifier: NotificationIdentifier.Action.startWalkingFocus,
            title: "Yürüyüş başlat",
            options: [.foreground] // bring app forward so the focus screen is visible
        )
        let walkCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.Category.walkReminder,
            actions: [walkAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([waterCategory, walkCategory])
    }

    // MARK: - Add

    private func add(
        id: String,
        categoryId: String,
        title: String,
        body: String,
        triggerAt components: DateComponents
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryId
        if categoryId == NotificationIdentifier.Category.waterReminder {
            content.userInfo = [NotificationIdentifier.UserInfo.waterAmountKey: 250]
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

/// Computes routine-relative trigger times. Keeps the math out of the
/// service so we can unit-test the wrap-around logic.
struct SchedulePlan {
    let morningWater: DateComponents
    let middayWater: DateComponents
    let eveningWalk: DateComponents

    init(routine: DailyRoutine) {
        // Express wake / sleep as minutes from midnight (0..<1440) and
        // expand the day if sleep wraps past midnight. Trigger times
        // are then stamped back into the system calendar.
        let wakeMin = routine.wakeHour * 60 + routine.wakeMinute
        let sleepMin = routine.sleepHour * 60 + routine.sleepMinute
        let wrappedSleepMin = sleepMin > wakeMin ? sleepMin : sleepMin + 24 * 60
        let activeMinutes = wrappedSleepMin - wakeMin

        // Anchor offsets relative to wake / sleep:
        //   morning hydration = wake + 60 min
        //   midday water      = wake + ~45% of active window
        //   evening walk      = sleep − 4 hours (capped to wake + 6h)
        let morningOffset = min(60, max(20, activeMinutes / 8))
        let middayOffset = activeMinutes * 45 / 100
        let walkPreSleepOffset = min(4 * 60, max(60, activeMinutes / 4))

        let morningTotal = wakeMin + morningOffset
        let middayTotal = wakeMin + middayOffset
        let walkTotal = wrappedSleepMin - walkPreSleepOffset

        morningWater = SchedulePlan.components(forMinuteOfDay: morningTotal % (24 * 60))
        middayWater = SchedulePlan.components(forMinuteOfDay: middayTotal % (24 * 60))
        eveningWalk = SchedulePlan.components(forMinuteOfDay: walkTotal % (24 * 60))
    }

    private static func components(forMinuteOfDay minute: Int) -> DateComponents {
        var components = DateComponents()
        components.hour = (minute / 60) % 24
        components.minute = minute % 60
        return components
    }
}

struct MockNotificationService: NotificationService {
    var status: NotificationAuthorizationState = .authorized
    var grantedOnRequest: Bool = true
    func authorizationStatus() async -> NotificationAuthorizationState { status }
    func requestAuthorization() async -> Bool { grantedOnRequest }
    func scheduleGentleReminders(routine: DailyRoutine) async {}
    func cancelAll() async {}
}
