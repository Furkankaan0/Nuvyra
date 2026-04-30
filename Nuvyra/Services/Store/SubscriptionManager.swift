import Foundation
import SwiftData

/// One-shot UI feedback emitted after a purchase or restore action. The
/// view binds an `.alert` (or banner) to this so we never silently
/// swallow a result. Cleared by the view after dismissal.
struct StoreUserMessage: Identifiable, Equatable {
    enum Kind: Equatable {
        case success
        case info
        case warning
        case error
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

@MainActor
final class SubscriptionManager: ObservableObject {
    /// The current entitlement, mirrored from `Transaction.currentEntitlements`
    /// + the `Transaction.updates` stream. UI gates on `state.isActive`.
    @Published private(set) var entitlement: SubscriptionEntitlement = .none
    @Published private(set) var products: [PremiumProduct] = PremiumProduct.fallback
    /// Set when an Ask-to-Buy / Family Sharing purchase is awaiting an
    /// adult approval. The Premium screen shows a dedicated banner for
    /// this case so the user understands why the purchase didn't
    /// complete immediately.
    @Published private(set) var isAwaitingApproval = false
    /// One-shot result of the latest purchase / restore action.
    @Published var lastMessage: StoreUserMessage?

    private let storeKitService: StoreKitService
    private var streamTask: Task<Void, Never>?
    private weak var lastRepository: SubscriptionRepository?

    init(storeKitService: StoreKitService) {
        self.storeKitService = storeKitService
    }

    deinit {
        streamTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Starts the StoreKit `Transaction.updates` listener and bridges
    /// pushed entitlement changes onto our `@Published` state. Idempotent.
    func startListening(repository: SubscriptionRepository?) {
        lastRepository = repository
        storeKitService.startTransactionListener()
        guard streamTask == nil else { return }
        let stream = storeKitService.entitlementUpdates
        streamTask = Task { [weak self] in
            for await update in stream {
                await self?.applyExternalUpdate(update)
            }
        }
    }

    func stopListening() {
        streamTask?.cancel()
        streamTask = nil
        storeKitService.stopTransactionListener()
    }

    // MARK: - Public API

    func loadProducts() async {
        products = await storeKitService.loadProducts()
    }

    /// Pulls the canonical entitlement from StoreKit and persists it. Run
    /// on every cold start + foreground so an expiration that happened
    /// while the app was suspended is reflected immediately.
    func refresh(repository: SubscriptionRepository?) async {
        lastRepository = repository
        let fresh = await storeKitService.currentEntitlement()
        applyEntitlement(fresh, repository: repository)
    }

    /// Initiates a purchase. The returned outcome is also reflected on
    /// `isAwaitingApproval` / `lastMessage` so simple views can just
    /// observe state.
    @discardableResult
    func purchase(productID: String, repository: SubscriptionRepository?) async -> PurchaseOutcome {
        lastRepository = repository
        do {
            let outcome = try await storeKitService.purchase(productID: productID)
            handlePurchaseOutcome(outcome, repository: repository)
            return outcome
        } catch let error as StoreKitServiceError {
            lastMessage = StoreUserMessage(
                kind: .error,
                title: "Satın alma başarısız",
                message: error.errorDescription ?? "Lütfen biraz sonra tekrar dene."
            )
            return .unverified(reason: error.errorDescription ?? "")
        } catch {
            lastMessage = StoreUserMessage(
                kind: .error,
                title: "Satın alma başarısız",
                message: error.localizedDescription
            )
            return .unverified(reason: error.localizedDescription)
        }
    }

    /// "Restore Purchases" handler. App Store review *will* reject the
    /// app if this path silently fails, so every branch produces a
    /// `lastMessage` for the UI alert.
    @discardableResult
    func restore(repository: SubscriptionRepository?) async -> RestoreOutcome {
        lastRepository = repository
        do {
            let outcome = try await storeKitService.restorePurchases()
            handleRestoreOutcome(outcome, repository: repository)
            return outcome
        } catch {
            let message = error.localizedDescription
            lastMessage = StoreUserMessage(
                kind: .error,
                title: "Geri yükleme başarısız",
                message: message
            )
            return .failure(message: message)
        }
    }

    // MARK: - Internal handlers

    private func handlePurchaseOutcome(_ outcome: PurchaseOutcome, repository: SubscriptionRepository?) {
        switch outcome {
        case .purchased(let entitlement):
            isAwaitingApproval = false
            applyEntitlement(entitlement, repository: repository)
            lastMessage = StoreUserMessage(
                kind: .success,
                title: "Premium aktif",
                message: "Satın alman tamamlandı. Yeni özellikler kullanıma hazır."
            )
        case .pendingApproval:
            isAwaitingApproval = true
            lastMessage = StoreUserMessage(
                kind: .info,
                title: "Ebeveyn onayı bekleniyor",
                message: "Aile paylaşımı veya Ask-to-Buy nedeniyle satın alma onay sonrasında etkinleşecek. Onaylandığında premium otomatik açılır."
            )
        case .userCancelled:
            isAwaitingApproval = false
            lastMessage = StoreUserMessage(
                kind: .info,
                title: "Satın alma iptal edildi",
                message: "Hazır olduğunda tekrar deneyebilirsin."
            )
        case .unverified(let reason):
            isAwaitingApproval = false
            lastMessage = StoreUserMessage(
                kind: .error,
                title: "Doğrulanamayan işlem",
                message: "Bu işlem App Store tarafından doğrulanamadı. Tekrar dene veya destek ile iletişime geç. (\(reason))"
            )
        }
    }

    private func handleRestoreOutcome(_ outcome: RestoreOutcome, repository: SubscriptionRepository?) {
        switch outcome {
        case .restored(let entitlement):
            applyEntitlement(entitlement, repository: repository)
            lastMessage = StoreUserMessage(
                kind: .success,
                title: "Satın alımlar geri yüklendi",
                message: "Premium hesabına bağlandı."
            )
        case .nothingToRestore:
            // Important: we still persist the empty entitlement so the
            // UI updates if the user used to be premium but their
            // subscription has lapsed.
            applyEntitlement(.none, repository: repository)
            lastMessage = StoreUserMessage(
                kind: .warning,
                title: "Geri yüklenecek satın alma yok",
                message: "Bu Apple ID üzerinde aktif Nuvyra premium aboneliği bulunamadı."
            )
        case .failure(let message):
            lastMessage = StoreUserMessage(
                kind: .error,
                title: "Geri yükleme başarısız",
                message: message
            )
        }
    }

    private func applyExternalUpdate(_ update: SubscriptionEntitlement) async {
        // External update means an Ask-to-Buy was approved, a refund
        // landed, a renewal happened, etc. Always clear the pending flag
        // and persist whatever the latest verified state is.
        isAwaitingApproval = false
        applyEntitlement(update, repository: lastRepository)
        if update.isActive {
            // Don't spam users with a redundant alert if they're already
            // looking at the success message. But for refunds /
            // expirations we leave `lastMessage` alone — the natural
            // place to surface those is the Subscription settings view.
            lastMessage = StoreUserMessage(
                kind: .success,
                title: "Premium güncellendi",
                message: "Aboneliğin App Store'da güncellendi."
            )
        }
    }

    private func applyEntitlement(_ entitlement: SubscriptionEntitlement, repository: SubscriptionRepository?) {
        self.entitlement = entitlement
        try? repository?.save(
            isPremium: entitlement.isPremium,
            productId: entitlement.productId,
            expirationDate: entitlement.expirationDate,
            source: entitlement.source
        )
    }
}
