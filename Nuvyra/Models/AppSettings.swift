import Foundation
import SwiftData

@Model
final class AppSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var healthPermissionAsked: Bool
    var reducedInsightCopy: Bool
    /// Set when the user opted into nazik bildirimler in onboarding but
    /// the system permission prompt was denied. Drives the "Bildirim
    /// izni gerekli — Ayarları aç" deeplink banner on the dashboard,
    /// since the system prompt can only be shown once.
    var notificationsDeniedByUser: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        healthPermissionAsked: Bool = false,
        reducedInsightCopy: Bool = false,
        notificationsDeniedByUser: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.healthPermissionAsked = healthPermissionAsked
        self.reducedInsightCopy = reducedInsightCopy
        self.notificationsDeniedByUser = notificationsDeniedByUser
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
