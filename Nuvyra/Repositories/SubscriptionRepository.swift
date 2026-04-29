import Foundation
import SwiftData

@MainActor
protocol SubscriptionRepository {
    func state() throws -> SubscriptionState
    func save(isPremium: Bool, productId: String?, expirationDate: Date?, source: EntitlementSource) throws
}

@MainActor
final class SwiftDataSubscriptionRepository: SubscriptionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func state() throws -> SubscriptionState {
        if let existing = try context.fetch(FetchDescriptor<SubscriptionState>()).first { return existing }
        let fallback = SubscriptionState()
        context.insert(fallback)
        try context.save()
        return fallback
    }

    func save(isPremium: Bool, productId: String?, expirationDate: Date?, source: EntitlementSource) throws {
        let current = try state()
        current.isPremium = isPremium
        current.productId = productId
        current.expirationDate = expirationDate
        current.lastVerifiedAt = Date()
        current.entitlementSource = source
        try context.save()
    }
}
