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
}
