import Foundation

enum AnalyticsEvent: String, CaseIterable {
    case appOpened = "app_opened"
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case healthPermissionRequested = "health_permission_requested"
    case healthPermissionGranted = "health_permission_granted"
    case mealAdded = "meal_added"
    case waterAdded = "water_added"
    case stepGoalCompleted = "step_goal_completed"
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseFailed = "purchase_failed"
    case restorePurchasesTapped = "restore_purchases_tapped"
}

struct AnalyticsPayload: Equatable {
    var values: [String: String] = [:]
}
