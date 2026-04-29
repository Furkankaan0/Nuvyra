import XCTest
@testable import Nuvyra

@MainActor
final class SubscriptionFallbackTests: XCTestCase {
    func testMockProductsKeepPaywallRenderable() async {
        let products = await MockStoreKitService().loadProducts()
        XCTAssertEqual(products.map(\.id), [StoreKitServiceProductID.yearly, StoreKitServiceProductID.monthly])
    }
}
