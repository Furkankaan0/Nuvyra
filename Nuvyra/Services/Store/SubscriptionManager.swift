import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var state = SubscriptionState()
    @Published private(set) var products: [PremiumProduct] = PremiumProduct.fallback
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var errorMessage: String?

    private let storeKitService: StoreKitService
    private var transactionListener: Task<Void, Never>?
    private var listenerRepository: SubscriptionRepository?

    var entitlement: EntitlementState {
        guard state.isPremium else { return .free }
        let productID = state.productId.flatMap(ProductID.init(rawValue:))
        if productID == .premiumLifetime {
            return .lifetime(productID: .premiumLifetime)
        }
        return .premium(productID: productID, expirationDate: state.expirationDate)
    }

    var isPremium: Bool { entitlement.isPremium }

    init(storeKitService: StoreKitService) {
        self.storeKitService = storeKitService
    }

    deinit {
        transactionListener?.cancel()
    }

    func startTransactionListener(repository: SubscriptionRepository?) {
        listenerRepository = repository
        guard transactionListener == nil else { return }
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                guard StoreKitServiceProductID.all.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.refreshFromTransactionUpdate()
            }
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        products = await storeKitService.loadProducts()
    }

    func refresh(repository: SubscriptionRepository?) async {
        listenerRepository = repository
        startTransactionListener(repository: repository)
        let entitlement = await storeKitService.currentEntitlement()
        await apply(entitlement, repository: repository)
    }

    func purchase(productID: String, repository: SubscriptionRepository?) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let entitlement = try await storeKitService.purchase(productID: productID)
            await apply(entitlement, repository: repository)
        } catch {
            errorMessage = "Satın alma tamamlanamadı. App Store bağlantını kontrol edip tekrar dene."
        }
    }

    func restore(repository: SubscriptionRepository?) async {
        guard !isRestoring else { return }
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            let entitlement = try await storeKitService.restorePurchases()
            await apply(entitlement, repository: repository)
            if !entitlement.isPremium {
                errorMessage = "Aktif Premium satın alımı bulunamadı."
            }
        } catch {
            errorMessage = "Satın alımlar geri yüklenemedi. Lütfen tekrar dene."
        }
    }

    private func refreshFromTransactionUpdate() async {
        let entitlement = await storeKitService.currentEntitlement()
        await apply(entitlement, repository: listenerRepository)
    }

    private func apply(_ entitlement: SubscriptionState, repository: SubscriptionRepository?) async {
        state = entitlement
        try? repository?.save(
            isPremium: entitlement.isPremium,
            productId: entitlement.productId,
            expirationDate: entitlement.expirationDate,
            source: entitlement.entitlementSource
        )
    }
}
