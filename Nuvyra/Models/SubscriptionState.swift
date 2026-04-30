import Foundation
import SwiftData

@Model
final class SubscriptionState: Identifiable {
    @Attribute(.unique) var id: UUID
    var isPremium: Bool
    var productId: String?
    var expirationDate: Date?
    var lastVerifiedAt: Date
    var entitlementSource: EntitlementSource

    init(
        id: UUID = UUID(),
        isPremium: Bool = false,
        productId: String? = nil,
        expirationDate: Date? = nil,
        lastVerifiedAt: Date = Date(),
        entitlementSource: EntitlementSource = .localFallback
    ) {
        self.id = id
        self.isPremium = isPremium
        self.productId = productId
        self.expirationDate = expirationDate
        self.lastVerifiedAt = lastVerifiedAt
        self.entitlementSource = entitlementSource
    }

    /// True only if the entitlement is currently active. Use this — NOT
    /// `isPremium` — for any feature gating: an `isPremium == true` row
    /// whose `expirationDate` has passed is no longer a valid grant.
    /// `expirationDate == nil` means "non-renewable / lifetime", so the
    /// gate stays open.
    var isActive: Bool {
        guard isPremium else { return false }
        guard let expirationDate else { return true }
        return expirationDate > Date()
    }
}
