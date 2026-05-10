import Foundation
import SwiftData

@Model
final class AppSettings: Identifiable {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var notificationsEnabled: Bool
    var healthPermissionAsked: Bool
    var reducedInsightCopy: Bool
    /// JSON-encoded `NotificationPreferences`. nil => use defaults until user customizes.
    var notificationPreferencesData: Data? = nil
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        notificationsEnabled: Bool = false,
        healthPermissionAsked: Bool = false,
        reducedInsightCopy: Bool = false,
        notificationPreferencesData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationsEnabled = notificationsEnabled
        self.healthPermissionAsked = healthPermissionAsked
        self.reducedInsightCopy = reducedInsightCopy
        self.notificationPreferencesData = notificationPreferencesData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension AppSettings {
    /// Decodes notification preferences, falling back to defaults if missing/corrupt.
    /// `masterEnabled` is mirrored from `notificationsEnabled` so the legacy toggle
    /// remains the source of truth for the on/off master switch.
    var notificationPreferences: NotificationPreferences {
        get {
            let decoded: NotificationPreferences
            if let data = notificationPreferencesData,
               let value = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
                decoded = value.migrated()
            } else {
                decoded = .default
            }
            var resolved = decoded
            resolved.masterEnabled = notificationsEnabled
            return resolved
        }
        set {
            notificationsEnabled = newValue.masterEnabled
            notificationPreferencesData = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}
