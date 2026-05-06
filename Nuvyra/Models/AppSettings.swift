import Foundation
import SwiftData

@Model
final class AppSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var healthPermissionAsked: Bool
    var reducedInsightCopy: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        healthPermissionAsked: Bool = false,
        reducedInsightCopy: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.healthPermissionAsked = healthPermissionAsked
        self.reducedInsightCopy = reducedInsightCopy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
