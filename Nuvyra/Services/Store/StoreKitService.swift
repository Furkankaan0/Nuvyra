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

/// Surfaceable outcome of `purchase(productID:)`. Lets the UI react to
/// Ask-to-Buy / Family Sharing pending state, user cancellation, and
/// JWS-verification failure with specific copy — instead of silently
/// returning the previous entitlement.
enum PurchaseOutcome: Equatable {
    case purchased(SubscriptionEntitlement)
    /// Family-sharing / Ask-to-Buy: an adult must approve before the
    /// transaction can complete. App Store will deliver the resolved
    /// transaction asynchronously via `Transaction.updates`.
    case pendingApproval
    case userCancelled
    case unverified(reason: String)
}

/// Outcome of the user tapping "Restore Purchases". Distinguishes a
/// successful restore from "AppStore.sync ran but nothing was found" so
/// the UI can show "Geri yüklenecek satın alma yok" instead of a
/// misleading "Geri yüklendi".
enum RestoreOutcome: Equatable {
    case restored(SubscriptionEntitlement)
    case nothingToRestore
    case failure(message: String)
}

/// Plain-Sendable representation of a verified entitlement. Mirrors the
/// fields stored on `SubscriptionState` but without the SwiftData baggage.
struct SubscriptionEntitlement: Equatable, Sendable {
    var isPremium: Bool
    var productId: String?
    var expirationDate: Date?
    var source: EntitlementSource

    static let none = SubscriptionEntitlement(isPremium: false, productId: nil, expirationDate: nil, source: .localFallback)

    /// True only if the entitlement is currently active. Replaces every
    /// previous `isPremium` check used for feature gating — an expired
    /// entitlement is no entitlement.
    var isActive: Bool {
        guard isPremium else { return false }
        guard let expirationDate else { return true }
        return expirationDate > Date()
    }
}

@MainActor
protocol StoreKitService {
    func loadProducts() async -> [PremiumProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    func restorePurchases() async throws -> RestoreOutcome
    func currentEntitlement() async -> SubscriptionEntitlement
    /// Stream of entitlement changes pushed by `Transaction.updates`
    /// (Ask-to-Buy approvals, cross-device purchases, refunds, family
    /// sharing). The `LiveStoreKitService` starts an internal listener
    /// in `startTransactionListener()`; this method exposes it to
    /// observers so `SubscriptionManager` can mirror the latest state.
    var entitlementUpdates: AsyncStream<SubscriptionEntitlement> { get }
    /// Begin observing `Transaction.updates`. Idempotent.
    func startTransactionListener()
    /// Stop observing. Called on app teardown / from tests.
    func stopTransactionListener()
}

@MainActor
final class LiveStoreKitService: StoreKitService {
    private var products: [Product] = []
    private var listenerTask: Task<Void, Never>?
    private var continuation: AsyncStream<SubscriptionEntitlement>.Continuation?
    private(set) lazy var entitlementUpdates: AsyncStream<SubscriptionEntitlement> = {
        AsyncStream<SubscriptionEntitlement> { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in }
        }
    }()

    deinit {
        listenerTask?.cancel()
        continuation?.finish()
    }

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

    func purchase(productID: String) async throws -> PurchaseOutcome {
        if products.isEmpty { _ = await loadProducts() }
        guard let product = products.first(where: { $0.id == productID }) else {
            throw StoreKitServiceError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                let entitlement = SubscriptionEntitlement(
                    isPremium: true,
                    productId: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    source: .storeKit
                )
                await transaction.finish()
                continuation?.yield(entitlement)
                return .purchased(entitlement)
            case .unverified(_, let error):
                return .unverified(reason: error.localizedDescription)
            }
        case .pending:
            return .pendingApproval
        case .userCancelled:
            return .userCancelled
        @unknown default:
            return .unverified(reason: "Bilinmeyen StoreKit durumu")
        }
    }

    func restorePurchases() async throws -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            return .failure(message: error.localizedDescription)
        }
        let entitlement = await currentEntitlement()
        if entitlement.isPremium {
            continuation?.yield(entitlement)
            return .restored(entitlement)
        }
        return .nothingToRestore
    }

    func currentEntitlement() async -> SubscriptionEntitlement {
        // Walk every active entitlement; if any of our product IDs is
        // present and verified AND not expired, treat the user as
        // premium. Expired entitlements are dropped on the floor — we
        // never grant premium based on a stale local cache.
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  StoreKitServiceProductID.all.contains(transaction.productID) else { continue }
            if let expiration = transaction.expirationDate, expiration <= Date() { continue }
            return SubscriptionEntitlement(
                isPremium: true,
                productId: transaction.productID,
                expirationDate: transaction.expirationDate,
                source: .storeKit
            )
        }
        return .none
    }

    // MARK: - Transaction.updates listener

    func startTransactionListener() {
        guard listenerTask == nil else { return }
        // `Task.detached` so the loop survives view-model lifetime; the
        // task only references the actor's continuation, which is safe
        // to yield to from any thread.
        listenerTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handleTransactionUpdate(update)
            }
        }
    }

    func stopTransactionListener() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Always finish so StoreKit doesn't keep redelivering it.
            await transaction.finish()
            // We only care about our own product IDs.
            guard StoreKitServiceProductID.all.contains(transaction.productID) else { return }
            // Recompute the snapshot from `currentEntitlements` so we
            // pick up revocations / expirations as well as new purchases.
            let entitlement = await currentEntitlement()
            continuation?.yield(entitlement)
        case .unverified:
            // Skip silently — an unverified transaction must not grant
            // entitlements.
            return
        }
    }

    // MARK: - Helpers

    private func fallbackTitle(for productID: String) -> String {
        productID == StoreKitServiceProductID.yearly ? "Premium Yıllık" : "Premium Aylık"
    }
}

enum StoreKitServiceError: LocalizedError, Equatable {
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Bu ürün şu anda App Store'dan yüklenemedi. Bağlantını kontrol edip tekrar dene."
        }
    }
}

@MainActor
final class MockStoreKitService: StoreKitService {
    var entitlementToReturn: SubscriptionEntitlement = .none
    var purchaseOutcome: PurchaseOutcome?
    var restoreOutcome: RestoreOutcome = .nothingToRestore
    private let stream: AsyncStream<SubscriptionEntitlement>
    private let continuation: AsyncStream<SubscriptionEntitlement>.Continuation

    init() {
        var continuationRef: AsyncStream<SubscriptionEntitlement>.Continuation!
        self.stream = AsyncStream { continuation in
            continuationRef = continuation
        }
        self.continuation = continuationRef
    }

    var entitlementUpdates: AsyncStream<SubscriptionEntitlement> { stream }

    func loadProducts() async -> [PremiumProduct] { PremiumProduct.fallback }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        if let outcome = purchaseOutcome { return outcome }
        let entitlement = SubscriptionEntitlement(
            isPremium: true,
            productId: productID,
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
            source: .localFallback
        )
        return .purchased(entitlement)
    }

    func restorePurchases() async throws -> RestoreOutcome { restoreOutcome }
    func currentEntitlement() async -> SubscriptionEntitlement { entitlementToReturn }
    func startTransactionListener() {}
    func stopTransactionListener() { continuation.finish() }
}
