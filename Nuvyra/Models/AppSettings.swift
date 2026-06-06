import Foundation
import SwiftData

@Model
final class AppSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var healthPermissionAsked: Bool
    var reducedInsightCopy: Bool
    /// Set to true when the user finishes (or dismisses) the day-one guided tour.
    var didCompleteDayOneTour: Bool = false
    /// First time the user launched the app (post-onboarding). Drives the
    /// "1 week of Nuvyra" upsell trigger.
    var firstLaunchAt: Date?
    /// Last time we surfaced a behavioural upsell — used as a cooldown.
    var lastUpsellShownAt: Date?
    /// Comma-separated raw values of `UpsellTrigger` cases already presented,
    /// so we don't re-show the same trigger multiple times.
    var shownUpsellTriggers: String = ""
    /// One-shot dashboard toast asking for sleep + resting heart HealthKit reads.
    var vitalsPermissionToastShown: Bool = false
    /// User opt-in for the CloudKit mirror. Off by default — the app is
    /// local-first; the user enables iCloud backup explicitly from
    /// Profile. When false, every `cloudSyncService.push` call site
    /// no-ops early so we never touch CloudKit without consent.
    var iCloudSyncEnabled: Bool = false
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        healthPermissionAsked: Bool = false,
        reducedInsightCopy: Bool = false,
        didCompleteDayOneTour: Bool = false,
        firstLaunchAt: Date? = nil,
        lastUpsellShownAt: Date? = nil,
        shownUpsellTriggers: String = "",
        vitalsPermissionToastShown: Bool = false,
        iCloudSyncEnabled: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.healthPermissionAsked = healthPermissionAsked
        self.reducedInsightCopy = reducedInsightCopy
        self.didCompleteDayOneTour = didCompleteDayOneTour
        self.firstLaunchAt = firstLaunchAt
        self.lastUpsellShownAt = lastUpsellShownAt
        self.shownUpsellTriggers = shownUpsellTriggers
        self.vitalsPermissionToastShown = vitalsPermissionToastShown
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
