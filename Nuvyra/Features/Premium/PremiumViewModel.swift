import Foundation
import SwiftData

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published var products: [PremiumProduct] = PremiumProduct.fallback
    @Published var selectedProductID = StoreKitServiceProductID.yearly
    @Published var isLoading = false

    func load(dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        products = await dependencies.subscriptionManager.storeProductsFallbackAware()
        selectedProductID = products.first(where: { $0.isYearly })?.id ?? products.first?.id ?? StoreKitServiceProductID.yearly
        await dependencies.analytics.track(.paywallViewed, payload: AnalyticsPayload())
    }

    func purchase(context: ModelContext, dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.purchaseStarted, payload: AnalyticsPayload(values: ["product_id": selectedProductID]))
        let repository = dependencies.subscriptionRepository(context: context)
        await dependencies.subscriptionManager.purchase(productID: selectedProductID, repository: repository)
        await dependencies.analytics.track(dependencies.subscriptionManager.state.isPremium ? .purchaseCompleted : .purchaseFailed, payload: AnalyticsPayload())
    }

    func restore(context: ModelContext, dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.restorePurchasesTapped, payload: AnalyticsPayload())
        await dependencies.subscriptionManager.restore(repository: dependencies.subscriptionRepository(context: context))
    }
}

private extension SubscriptionManager {
    func storeProductsFallbackAware() async -> [PremiumProduct] {
        await loadProducts()
        return products.isEmpty ? PremiumProduct.fallback : products
    }
}
