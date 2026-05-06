import XCTest

final class NuvyraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingWelcomeAndCompletionReachDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Nuvyra'ya hoş geldin"].waitForExistence(timeout: 8))
        completePremiumOnboarding(in: app)
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))
    }

    func testPaywallRestoreButtonExistsFromProfile() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        if app.staticTexts["Nuvyra'ya hoş geldin"].waitForExistence(timeout: 3) {
            completePremiumOnboarding(in: app)
        }
        app.tabBars.buttons["Profil"].tap()
        app.staticTexts["Premium'u keşfet"].tap()
        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 5))
    }

    func testNativeFoundationEntryPointsRender() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        if app.staticTexts["Nuvyra'ya hoş geldin"].waitForExistence(timeout: 3) {
            completePremiumOnboarding(in: app)
        }

        app.tabBars.buttons["Yürüyüş"].tap()
        XCTAssertTrue(app.buttons["Yürüyüş başlat"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Beslenme"].tap()
        XCTAssertTrue(app.staticTexts["Akıllı kayıt"].waitForExistence(timeout: 5))
    }

    private func completePremiumOnboarding(in app: XCUIApplication) {
        for _ in 0..<8 {
            XCTAssertTrue(app.buttons["Devam"].waitForExistence(timeout: 5))
            app.buttons["Devam"].tap()
        }
        XCTAssertTrue(app.buttons["Apple Sağlık'ı ayarla"].waitForExistence(timeout: 5))
        app.buttons["Apple Sağlık'ı ayarla"].tap()
        XCTAssertTrue(app.buttons["Premium'u gör"].waitForExistence(timeout: 5))
        app.buttons["Premium'u gör"].tap()
        XCTAssertTrue(app.buttons["Dashboard'a geç"].waitForExistence(timeout: 5))
        app.buttons["Dashboard'a geç"].tap()
    }
}
