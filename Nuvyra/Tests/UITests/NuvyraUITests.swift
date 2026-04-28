import XCTest

final class NuvyraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingWelcomeAppearsOnFreshInstall() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Katı diyet değil, sürdürülebilir ritim."].waitForExistence(timeout: 6))
    }

    func testOnboardingCanMoveToGoalSelection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let continueButton = app.buttons["Devam"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 6))
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["Bugün en çok neyi kolaylaştırmak istiyorsun?"].waitForExistence(timeout: 3))
    }
}
