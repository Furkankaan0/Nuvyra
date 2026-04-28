import Foundation
import StoreKit

enum StoreKitServiceError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound: "Abonelik ürünü bulunamadı."
        case .failedVerification: "Satın alma doğrulanamadı. Lütfen daha sonra tekrar dene."
        }
    }
}

@MainActor
protocol StoreKitServicing {
    func loadProducts() async throws -> [SubscriptionProduct]
    func purchase(productID: String) async throws -> EntitlementState
    func restorePurchases() async throws -> EntitlementState
    func currentEntitlement() async -> EntitlementState
}

@MainActor
final class StoreKitService: StoreKitServicing {
    private let productIDs: Set<String>
    private var products: [Product] = []

    init(productIDs: Set<String> = StoreKitService.defaultProductIDs) {
        self.productIDs = productIDs
    }

    static let defaultProductIDs: Set<String> = [
        "com.nuvyra.premium.monthly",
        "com.nuvyra.premium.yearly",
        "com.nuvyra.plus.monthly",
        "com.nuvyra.plus.yearly"
    ]

    func loadProducts() async throws -> [SubscriptionProduct] {
        products = try await Product.products(for: Array(productIDs)).sorted { $0.displayName < $1.displayName }
        let mapped = products.map(mapProduct)
        return mapped.isEmpty ? SubscriptionProduct.fallback : mapped
    }

    func purchase(productID: String) async throws -> EntitlementState {
        if products.isEmpty { _ = try await loadProducts() }
        guard let product = products.first(where: { $0.id == productID }) else { throw StoreKitServiceError.productNotFound }
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return state(for: transaction.productID, expiresAt: transaction.expirationDate)
        case .pending, .userCancelled:
            return await currentEntitlement()
        @unknown default:
            return await currentEntitlement()
        }
    }

    func restorePurchases() async throws -> EntitlementState {
        try await AppStore.sync()
        return await currentEntitlement()
    }

    func currentEntitlement() async -> EntitlementState {
        var bestState = EntitlementState.free
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            let state = state(for: transaction.productID, expiresAt: transaction.expirationDate)
            if state.tier > bestState.tier {
                bestState = state
            }
        }
        return bestState
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreKitServiceError.failedVerification
        }
    }

    private func mapProduct(_ product: Product) -> SubscriptionProduct {
        SubscriptionProduct(
            id: product.id,
            title: product.displayName,
            priceDisplay: product.displayPrice,
            period: product.id.contains("yearly") ? .yearly : .monthly,
            tier: product.id.contains("plus") ? .premiumPlus : .premium,
            features: product.id.contains("plus")
                ? ["AI koç sohbeti", "İleri trend analizi", "Daha kişisel haftalık plan"]
                : ["Sınırsız fotoğraflı öğün kaydı", "Adaptif yürüyüş planı", "Haftalık koç özeti"]
        )
    }

    private func state(for productID: String, expiresAt: Date?) -> EntitlementState {
        EntitlementState(
            tier: productID.contains("plus") ? .premiumPlus : .premium,
            activeProductID: productID,
            expiresAt: expiresAt,
            verifiedAt: Date(),
            isOfflineCache: false
        )
    }
}

@MainActor
struct PreviewStoreKitService: StoreKitServicing {
    func loadProducts() async throws -> [SubscriptionProduct] { SubscriptionProduct.fallback }
    func purchase(productID: String) async throws -> EntitlementState {
        EntitlementState(tier: productID.contains("plus") ? .premiumPlus : .premium, activeProductID: productID, expiresAt: nil, verifiedAt: Date(), isOfflineCache: false)
    }
    func restorePurchases() async throws -> EntitlementState { .free }
    func currentEntitlement() async -> EntitlementState { .free }
}
