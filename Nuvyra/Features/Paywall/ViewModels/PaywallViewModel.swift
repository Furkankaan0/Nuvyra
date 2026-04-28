import Foundation

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var products: [SubscriptionProduct] = SubscriptionProduct.fallback
    @Published var selectedProductID: String = SubscriptionProduct.fallback.first?.id ?? "com.nuvyra.premium.yearly"
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await appState.environment.storeKitService.loadProducts()
            products = loaded
            selectedProductID = loaded.first?.id ?? selectedProductID
            await appState.environment.analytics.track(AnalyticsEvent(.paywallViewed))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await appState.environment.entitlementManager.purchase(productID: selectedProductID)
            appState.entitlementState = appState.environment.entitlementManager.state
            await appState.environment.analytics.track(AnalyticsEvent(.subscriptionPurchased, payload: ["product_id": selectedProductID]))
            NuvyraHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            NuvyraHaptics.warning()
        }
    }

    func restore(appState: AppState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            await appState.environment.analytics.track(AnalyticsEvent(.restorePurchasesTapped))
            try await appState.environment.entitlementManager.restore()
            appState.entitlementState = appState.environment.entitlementManager.state
            NuvyraHaptics.success()
        } catch {
            errorMessage = error.localizedDescription
            NuvyraHaptics.warning()
        }
    }
}
