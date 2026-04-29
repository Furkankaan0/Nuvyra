import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class SwiftDataModelTests: XCTestCase {
    func testSeedDataCreatesSettingsAndDailyLog() throws {
        let container = NuvyraModelContainer.preview()
        let context = container.mainContext
        XCTAssertFalse(try context.fetch(FetchDescriptor<UserProfile>()).isEmpty)
        XCTAssertFalse(try context.fetch(FetchDescriptor<DailyLog>()).isEmpty)
        XCTAssertFalse(try context.fetch(FetchDescriptor<AppSettings>()).isEmpty)
    }
}
