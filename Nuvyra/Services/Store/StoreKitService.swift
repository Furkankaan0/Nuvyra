import Foundation
import StoreKit

struct PremiumProduct: Identifiable, Equatable {
    var id: String
    var title: String
    var price: String
    var isYearly: Bool
    var features: [String]

    static let fallback: [PremiumProduct] = [
        PremiumProduct(id: StoreKitServiceProductID.yearly, title: "Premium Yıllık", price: "App Store fiyatı", isYearly: true, features: ["Detaylı haftalık trendler", "Premium widget", "Gelişmiş yürüyüş içgörüleri"]),
        PremiumProduct(id: StoreKitServiceProductID.monthly, title: "Premium Aylık", price: "App Store fiyatı", isYearly: false, features: ["Sınırsız favori öğün", "Haftalık sağlık özeti", "Premium tema detayları"])
    ]
}

enum StoreKitServiceProductID {
    static let monthly = "com.nuvyra.premium.monthly"
    static let yearly = "com.nuvyra.premium.yearly"
    static let all = [monthly, yearly]
}

@MainActor
protocol StoreKitService {
    func loadProducts() async -> [PremiumProduct]
    func purchase(productID: String) async throws -> SubscriptionState
    func restorePurchases() async throws -> SubscriptionState
    func currentEntitlement() async -> SubscriptionState
}

@MainActor
final class LiveStoreKitService: StoreKitService {
    private var products: [Product] = []

    func loadProducts() async -> [PremiumProduct] {
        do {
            products = try await Product.products(for: StoreKitServiceProductID.all)
            let mapped = products.map { product in
                PremiumProduct(
                    id: product.id,
                    title: product.displayName.isEmpty ? fallbackTitle(for: product.id) : product.displayName,
                    price: product.displayPrice,
                    isYearly: product.id == StoreKitServiceProductID.yearly,
                    features: product.id == StoreKitServiceProductID.yearly ? PremiumProduct.fallback[0].features : PremiumProduct.fallback[1].features
                )
            }
            return mapped.isEmpty ? PremiumProduct.fallback : mapped.sorted { $0.isYearly && !$1.isYearly }
        } catch {
            return PremiumProduct.fallback
        }
    }

    func purchase(productID: String) async throws -> SubscriptionState {
        if products.isEmpty { _ = await loadProducts() }
        guard let product = products.first(where: { $0.id == productID }) else {
            return SubscriptionState(isPremium: false, productId: nil, entitlementSource: .localFallback)
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return SubscriptionState(isPremium: true, productId: transaction.productID, expirationDate: transaction.expirationDate, entitlementSource: .storeKit)
        case .pending, .userCancelled:
            return await currentEntitlement()
        @unknown default:
            return await currentEntitlement()
        }
    }

    func restorePurchases() async throws -> SubscriptionState {
        try await AppStore.sync()
        return await currentEntitlement()
    }

    func currentEntitlement() async -> SubscriptionState {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, StoreKitServiceProductID.all.contains(transaction.productID) {
                return SubscriptionState(isPremium: true, productId: transaction.productID, expirationDate: transaction.expirationDate, entitlementSource: .storeKit)
            }
        }
        return SubscriptionState(isPremium: false, productId: nil, entitlementSource: .localFallback)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    private func fallbackTitle(for productID: String) -> String {
        productID == StoreKitServiceProductID.yearly ? "Premium Yıllık" : "Premium Aylık"
    }
}

@MainActor
struct MockStoreKitService: StoreKitService {
    func loadProducts() async -> [PremiumProduct] { PremiumProduct.fallback }
    func purchase(productID: String) async throws -> SubscriptionState { SubscriptionState(isPremium: true, productId: productID, entitlementSource: .localFallback) }
    func restorePurchases() async throws -> SubscriptionState { SubscriptionState(isPremium: false, entitlementSource: .localFallback) }
    func currentEntitlement() async -> SubscriptionState { SubscriptionState(isPremium: false, entitlementSource: .localFallback) }
}
