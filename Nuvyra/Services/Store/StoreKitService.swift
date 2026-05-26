import Foundation
import StoreKit

enum ProductID: String, CaseIterable, Codable, Identifiable {
    case premiumMonthly = "com.nuvyra.premium.monthly"
    case premiumYearly = "com.nuvyra.premium.yearly"
    case premiumLifetime = "com.nuvyra.premium.lifetime"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .premiumMonthly: "Aylık Premium"
        case .premiumYearly: "Yıllık Premium"
        case .premiumLifetime: "Ömür boyu Premium"
        }
    }

    var fallbackPrice: String {
        switch self {
        case .premiumMonthly: "₺99,99 / ay"
        case .premiumYearly: "₺699,99 / yıl"
        case .premiumLifetime: "₺1.999,99 tek sefer"
        }
    }

    var badge: String? {
        switch self {
        case .premiumMonthly: nil
        case .premiumYearly: "En avantajlı"
        case .premiumLifetime: "Tek seferlik"
        }
    }

    var isRecurring: Bool {
        switch self {
        case .premiumMonthly, .premiumYearly: true
        case .premiumLifetime: false
        }
    }

    var sortPriority: Int {
        switch self {
        case .premiumYearly: 0
        case .premiumMonthly: 1
        case .premiumLifetime: 2
        }
    }
}

enum StoreKitServiceProductID {
    static let monthly = ProductID.premiumMonthly.rawValue
    static let yearly = ProductID.premiumYearly.rawValue
    static let lifetime = ProductID.premiumLifetime.rawValue
    static let all = ProductID.allCases.map(\.rawValue)
}

enum EntitlementState: Equatable {
    case free
    case premium(productID: ProductID?, expirationDate: Date?)
    case lifetime(productID: ProductID)

    var isPremium: Bool {
        switch self {
        case .free: false
        case .premium, .lifetime: true
        }
    }

    var title: String {
        switch self {
        case .free: "Free"
        case .premium(let productID, _): productID?.title ?? "Premium"
        case .lifetime: "Ömür boyu Premium"
        }
    }
}

/// Introductory offer attached to a `PremiumProduct` — mirrors Apple's
/// `Product.SubscriptionInfo.IntroductoryOffer` but stays a plain value type
/// so the UI doesn't depend on StoreKit symbols directly.
struct IntroductoryOffer: Equatable, Hashable {
    enum Mode: String, Codable { case freeTrial, payAsYouGo, payUpFront }

    var mode: Mode
    var days: Int
    var displayText: String

    /// Short capsule copy ("İlk 7 gün ücretsiz", "İlk ay ₺19,99").
    var badge: String {
        switch mode {
        case .freeTrial: "İlk \(days) gün ücretsiz"
        case .payAsYouGo, .payUpFront: displayText
        }
    }
}

struct PremiumProduct: Identifiable, Equatable {
    var id: String
    var productID: ProductID
    var title: String
    var price: String
    var badge: String?
    var renewalDescription: String
    var isYearly: Bool
    var isLifetime: Bool
    var features: [String]
    var introductoryOffer: IntroductoryOffer?

    static let premiumFeatures = [
        "Sınırsız yemek kaydı",
        "Gelişmiş analizler",
        "AI Coach",
        "Sesle yemek ekleme",
        "Barkod tarama",
        "Kamera ile besin tanıma",
        "Premium tema",
        "Gelişmiş yürüyüş koçu",
        "HealthKit detaylı içgörüler"
    ]

    static let fallback: [PremiumProduct] = ProductID.allCases
        .sorted { $0.sortPriority < $1.sortPriority }
        .map { productID in
            PremiumProduct(
                id: productID.rawValue,
                productID: productID,
                title: productID.title,
                price: productID.fallbackPrice,
                badge: productID.badge,
                renewalDescription: productID.renewalDescription,
                isYearly: productID == .premiumYearly,
                isLifetime: productID == .premiumLifetime,
                features: PremiumProduct.premiumFeatures,
                introductoryOffer: productID.isRecurring
                    ? IntroductoryOffer(mode: .freeTrial, days: 7, displayText: "7 gün ücretsiz")
                    : nil
            )
        }
}

private extension ProductID {
    var renewalDescription: String {
        switch self {
        case .premiumMonthly:
            "Aylık yenilenir. İstediğin zaman Apple ID ayarlarından iptal edebilirsin."
        case .premiumYearly:
            "Yıllık yenilenir. Aylığa göre en avantajlı premium ritim."
        case .premiumLifetime:
            "Tek seferlik satın alma. Abonelik yenilemesi yoktur."
        }
    }
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
            let mapped = products.compactMap(mapProduct)
                .sorted { $0.productID.sortPriority < $1.productID.sortPriority }
            return mapped.isEmpty ? PremiumProduct.fallback : mapped
        } catch {
            return PremiumProduct.fallback
        }
    }

    func purchase(productID: String) async throws -> SubscriptionState {
        if products.isEmpty { _ = await loadProducts() }
        guard let product = products.first(where: { $0.id == productID }) else {
            return SubscriptionState(isPremium: false, productId: nil, entitlementSource: EntitlementSource.localFallback)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return SubscriptionState(
                isPremium: true,
                productId: transaction.productID,
                expirationDate: transaction.expirationDate,
                entitlementSource: EntitlementSource.storeKit
            )
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
        var bestState = SubscriptionState(isPremium: false, productId: nil, entitlementSource: EntitlementSource.localFallback)

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  StoreKitServiceProductID.all.contains(transaction.productID) else {
                continue
            }

            if transaction.productID == ProductID.premiumLifetime.rawValue {
                return SubscriptionState(
                    isPremium: true,
                    productId: transaction.productID,
                    expirationDate: nil,
                    entitlementSource: EntitlementSource.storeKit
                )
            }

            bestState = SubscriptionState(
                isPremium: true,
                productId: transaction.productID,
                expirationDate: transaction.expirationDate,
                entitlementSource: EntitlementSource.storeKit
            )
        }

        return bestState
    }

    private func mapProduct(_ product: Product) -> PremiumProduct? {
        guard let productID = ProductID(rawValue: product.id) else { return nil }
        return PremiumProduct(
            id: product.id,
            productID: productID,
            title: product.displayName.isEmpty ? productID.title : product.displayName,
            price: product.displayPrice,
            badge: productID.badge,
            renewalDescription: productID.renewalDescription,
            isYearly: productID == .premiumYearly,
            isLifetime: productID == .premiumLifetime,
            features: PremiumProduct.premiumFeatures,
            introductoryOffer: introductoryOffer(for: product)
        )
    }

    /// Convert Apple's StoreKit2 introductory offer into our value-type representation.
    /// Falls back to a 7-day free trial copy for recurring products when App Store
    /// Connect hasn't been configured yet.
    private func introductoryOffer(for product: Product) -> IntroductoryOffer? {
        guard let subscription = product.subscription else { return nil }
        if let intro = subscription.introductoryOffer {
            let days = approximateDays(unit: intro.period.unit, value: intro.period.value)
            let totalDays = max(days * max(intro.periodCount, 1), 1)
            let mode: IntroductoryOffer.Mode
            switch intro.paymentMode {
            case .freeTrial: mode = .freeTrial
            case .payAsYouGo: mode = .payAsYouGo
            case .payUpFront: mode = .payUpFront
            default: mode = .freeTrial
            }
            let displayText: String
            switch mode {
            case .freeTrial: displayText = "\(totalDays) gün ücretsiz"
            case .payAsYouGo: displayText = "İlk \(totalDays) gün \(intro.displayPrice)"
            case .payUpFront: displayText = "İlk \(totalDays) gün \(intro.displayPrice)"
            }
            return IntroductoryOffer(mode: mode, days: totalDays, displayText: displayText)
        }
        // Fall back so the UI can still show "7 gün ücretsiz" — the actual offer
        // becomes authoritative as soon as App Store Connect serves one.
        return IntroductoryOffer(mode: .freeTrial, days: 7, displayText: "7 gün ücretsiz")
    }

    private func approximateDays(unit: Product.SubscriptionPeriod.Unit, value: Int) -> Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}

@MainActor
struct MockStoreKitService: StoreKitService {
    func loadProducts() async -> [PremiumProduct] { PremiumProduct.fallback }
    func purchase(productID: String) async throws -> SubscriptionState {
        SubscriptionState(isPremium: true, productId: productID, entitlementSource: EntitlementSource.localFallback)
    }
    func restorePurchases() async throws -> SubscriptionState {
        SubscriptionState(isPremium: false, entitlementSource: EntitlementSource.localFallback)
    }
    func currentEntitlement() async -> SubscriptionState {
        SubscriptionState(isPremium: false, entitlementSource: EntitlementSource.localFallback)
    }
}
