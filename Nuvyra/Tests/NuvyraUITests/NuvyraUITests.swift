import XCTest

final class NuvyraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingWelcomeAndCompletionReachDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ritmini yeniden kur."].waitForExistence(timeout: 8))
        for _ in 0..<4 { app.buttons["Devam"].tap() }
        app.buttons["Ritmime başla"].tap()
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))
    }

    func testPaywallRestoreButtonExistsFromProfile() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        if app.staticTexts["Ritmini yeniden kur."].waitForExistence(timeout: 3) {
            for _ in 0..<4 { app.buttons["Devam"].tap() }
            app.buttons["Ritmime başla"].tap()
        }
        app.tabBars.buttons["Profil"].tap()
        app.staticTexts["Premium'u keşfet"].tap()
        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 5))
    }

    func testNativeFoundationEntryPointsRender() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        if app.staticTexts["Ritmini yeniden kur."].waitForExistence(timeout: 3) {
            for _ in 0..<4 { app.buttons["Devam"].tap() }
            app.buttons["Ritmime başla"].tap()
        }

        app.tabBars.buttons["Yürüyüş"].tap()
        XCTAssertTrue(app.buttons["Yürüyüş başlat"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Beslenme"].tap()
        XCTAssertTrue(app.staticTexts["Akıllı kayıt"].waitForExistence(timeout: 5))
    }
}
