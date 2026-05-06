import Foundation

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var state = SubscriptionState()
    @Published private(set) var products: [PremiumProduct] = PremiumProduct.fallback
    @Published var errorMessage: String?

    private let storeKitService: StoreKitService

    init(storeKitService: StoreKitService) {
        self.storeKitService = storeKitService
    }

    func loadProducts() async {
        products = await storeKitService.loadProducts()
    }

    func refresh(repository: SubscriptionRepository?) async {
        let entitlement = await storeKitService.currentEntitlement()
        state = entitlement
        try? repository?.save(isPremium: entitlement.isPremium, productId: entitlement.productId, expirationDate: entitlement.expirationDate, source: entitlement.entitlementSource)
    }

    func purchase(productID: String, repository: SubscriptionRepository?) async {
        do {
            state = try await storeKitService.purchase(productID: productID)
            try repository?.save(isPremium: state.isPremium, productId: state.productId, expirationDate: state.expirationDate, source: state.entitlementSource)
        } catch {
            errorMessage = "Satın alma tamamlanamadı. Lütfen biraz sonra tekrar dene."
        }
    }

    func restore(repository: SubscriptionRepository?) async {
        do {
            state = try await storeKitService.restorePurchases()
            try repository?.save(isPremium: state.isPremium, productId: state.productId, expirationDate: state.expirationDate, source: state.entitlementSource)
        } catch {
            errorMessage = "Satın alımlar geri yüklenemedi."
        }
    }
}
