import SwiftData
import XCTest
@testable import Nuvyra

@MainActor
final class WalkingInsightTests: XCTestCase {
    func testWalkingInsightEncouragesWithoutBlame() async throws {
        let container = NuvyraModelContainer.preview()
        let dependencies = DependencyContainer.preview()
        let viewModel = WalkingViewModel()

        await viewModel.load(context: container.mainContext, dependencies: dependencies)

        XCTAssertFalse(viewModel.insight.localizedCaseInsensitiveContains("kaçırdın"))
        XCTAssertFalse(viewModel.insight.localizedCaseInsensitiveContains("hemen yürü"))
    }
}
