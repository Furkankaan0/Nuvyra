import Foundation

@MainActor
protocol EntitlementManaging: AnyObject {
    var state: EntitlementState { get }
    func refresh() async
    func purchase(productID: String) async throws
    func restore() async throws
}

@MainActor
final class EntitlementManager: ObservableObject, EntitlementManaging {
    @Published private(set) var state: EntitlementState

    private let storeKitService: StoreKitServicing
    private let keychainService: KeychainService
    private let cacheAccount = "nuvyra.entitlement.cache"

    init(storeKitService: StoreKitServicing, keychainService: KeychainService, initialState: EntitlementState = .free) {
        self.storeKitService = storeKitService
        self.keychainService = keychainService
        self.state = initialState
        if let cached = try? keychainService.readCodable(EntitlementState.self, account: cacheAccount) {
            self.state = EntitlementState(
                tier: cached.tier,
                activeProductID: cached.activeProductID,
                expiresAt: cached.expiresAt,
                verifiedAt: cached.verifiedAt,
                isOfflineCache: true
            )
        }
    }

    func refresh() async {
        let latest = await storeKitService.currentEntitlement()
        state = latest
        try? keychainService.saveCodable(latest, account: cacheAccount)
    }

    func purchase(productID: String) async throws {
        let purchased = try await storeKitService.purchase(productID: productID)
        state = purchased
        try? keychainService.saveCodable(purchased, account: cacheAccount)
    }

    func restore() async throws {
        let restored = try await storeKitService.restorePurchases()
        state = restored
        try? keychainService.saveCodable(restored, account: cacheAccount)
    }
}

@MainActor
final class PreviewEntitlementManager: EntitlementManaging {
    private(set) var state: EntitlementState

    init(state: EntitlementState = .free) {
        self.state = state
    }

    func refresh() async {}

    func purchase(productID: String) async throws {
        state = EntitlementState(
            tier: productID.contains("plus") ? .premiumPlus : .premium,
            activeProductID: productID,
            expiresAt: nil,
            verifiedAt: Date(),
            isOfflineCache: false
        )
    }

    func restore() async throws {}
}
