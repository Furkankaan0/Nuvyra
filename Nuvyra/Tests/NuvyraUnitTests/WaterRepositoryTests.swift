import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class WaterRepositoryTests: XCTestCase {
    func testWaterTotalsIncludeMultipleEntries() throws {
        let container = NuvyraModelContainer.preview()
        let repository = SwiftDataWaterRepository(context: container.mainContext)

        try repository.addWater(amountMl: 250, date: Date())
        try repository.addWater(amountMl: 500, date: Date())

        XCTAssertGreaterThanOrEqual(try repository.totalWater(on: Date()), 750)
    }
}
