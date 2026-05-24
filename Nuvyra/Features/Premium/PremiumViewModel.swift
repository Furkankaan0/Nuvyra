import Combine
import Foundation
import SwiftData

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published var products: [PremiumProduct] = PremiumProduct.fallback
    @Published var selectedProductID = ProductID.premiumYearly.rawValue
    @Published var isLoading = false

    var selectedProduct: PremiumProduct? {
        products.first { $0.id == selectedProductID }
    }

    func load(dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        await dependencies.subscriptionManager.loadProducts()
        products = dependencies.subscriptionManager.products.isEmpty ? PremiumProduct.fallback : dependencies.subscriptionManager.products
        selectedProductID = products.first(where: { $0.productID == .premiumYearly })?.id ?? products.first?.id ?? ProductID.premiumYearly.rawValue
        await dependencies.analytics.track(.paywallViewed, payload: AnalyticsPayload())
    }

    func purchase(context: ModelContext, dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.purchaseStarted, payload: AnalyticsPayload(values: ["product_id": selectedProductID]))
        let repository = dependencies.subscriptionRepository(context: context)
        await dependencies.subscriptionManager.purchase(productID: selectedProductID, repository: repository)
        await dependencies.analytics.track(
            dependencies.subscriptionManager.state.isPremium ? .purchaseCompleted : .purchaseFailed,
            payload: AnalyticsPayload(values: ["product_id": selectedProductID])
        )
    }

    func restore(context: ModelContext, dependencies: DependencyContainer) async {
        await dependencies.analytics.track(.restorePurchasesTapped, payload: AnalyticsPayload())
        await dependencies.subscriptionManager.restore(repository: dependencies.subscriptionRepository(context: context))
    }
}
