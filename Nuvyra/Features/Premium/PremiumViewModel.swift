import Foundation
import SwiftData

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published var products: [PremiumProduct] = PremiumProduct.fallback
    @Published var selectedProductID = StoreKitServiceProductID.yearly
    @Published var isLoading = false
    @Published var isProcessing = false

    func load(dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        await dependencies.subscriptionManager.loadProducts()
        products = dependencies.subscriptionManager.products.isEmpty
            ? PremiumProduct.fallback
            : dependencies.subscriptionManager.products
        selectedProductID = products.first(where: { $0.isYearly })?.id
            ?? products.first?.id
            ?? StoreKitServiceProductID.yearly
        await dependencies.analytics.track(.paywallViewed, payload: AnalyticsPayload())
    }

    func purchase(context: ModelContext, dependencies: DependencyContainer) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        await dependencies.analytics.track(
            .purchaseStarted,
            payload: AnalyticsPayload(values: ["product_id": selectedProductID])
        )
        let outcome = await dependencies.subscriptionManager.purchase(
            productID: selectedProductID,
            repository: dependencies.subscriptionRepository(context: context)
        )
        let event: AnalyticsEvent
        switch outcome {
        case .purchased: event = .purchaseCompleted
        case .pendingApproval: event = .purchasePending
        case .userCancelled: event = .purchaseCancelled
        case .unverified: event = .purchaseFailed
        }
        await dependencies.analytics.track(event, payload: AnalyticsPayload(values: ["product_id": selectedProductID]))
    }

    func restore(context: ModelContext, dependencies: DependencyContainer) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        await dependencies.analytics.track(.restorePurchasesTapped, payload: AnalyticsPayload())
        _ = await dependencies.subscriptionManager.restore(
            repository: dependencies.subscriptionRepository(context: context)
        )
    }
}
