import XCTest
@testable import Nuvyra

final class EntitlementStateTests: XCTestCase {
    func testTierOrderingProtectsPremiumPlusAccess() {
        XCTAssertTrue(EntitlementTier.premiumPlus > .premium)
        XCTAssertTrue(EntitlementTier.premium > .free)
        XCTAssertTrue(EntitlementState(tier: .premium, activeProductID: "premium", expiresAt: nil, verifiedAt: Date(), isOfflineCache: false).hasPremiumAccess)
    }
}
