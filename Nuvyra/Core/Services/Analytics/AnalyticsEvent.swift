import Foundation

enum AnalyticsEventName: String, Codable {
    case onboardingStarted = "onboarding_started"
    case goalSelected = "goal_selected"
    case onboardingCompleted = "onboarding_completed"
    case healthKitPrepromptViewed = "healthkit_preprompt_viewed"
    case healthKitGrantedSteps = "healthkit_granted_steps"
    case healthKitDeniedSteps = "healthkit_denied_steps"
    case mealLoggedFirst = "meal_logged_first"
    case mealLogged = "meal_logged"
    case photoMealStarted = "photo_meal_started"
    case photoMealCompleted = "photo_meal_completed"
    case walkGoalCompleted = "walk_goal_completed"
    case weeklySummaryOpened = "weekly_summary_opened"
    case paywallViewed = "paywall_viewed"
    case trialStarted = "trial_started"
    case subscriptionPurchased = "subscription_purchased"
    case restorePurchasesTapped = "restore_purchases_tapped"
    case subscriptionCancelIntent = "subscription_cancel_intent"
    case notificationPermissionGranted = "notification_permission_granted"
    case notificationPermissionDenied = "notification_permission_denied"
    case watchConnected = "watch_connected"
}

struct AnalyticsEvent: Codable, Equatable {
    var name: AnalyticsEventName
    var payload: [String: String]
    var occurredAt: Date

    init(_ name: AnalyticsEventName, payload: [String: String] = [:], occurredAt: Date = Date()) {
        self.name = name
        self.payload = payload
        self.occurredAt = occurredAt
    }
}
