import XCTest

final class NuvyraUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `-ui-testing` makes the app boot a SwiftData container with
    /// onboarding pre-completed via `SeedData.seedUITesting`, so every
    /// test below opens directly on the dashboard.
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    // MARK: - Onboarding (seeded path)

    func testAppLaunchesOntoDashboard() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))
    }

    // MARK: - Restore Purchases (App Store review requirement)

    /// Apple's review guideline 3.1.1 mandates a working "Restore
    /// Purchases" path. This test exercises the button and asserts that
    /// _something_ happens (a result alert) — silently failing here is a
    /// rejection risk.
    func testPaywallRestoreButtonProducesResultAlert() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))

        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.staticTexts["Premium'u keşfet"].waitForExistence(timeout: 5))
        app.staticTexts["Premium'u keşfet"].tap()

        let restoreButton = app.buttons["restorePurchasesButton"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
        restoreButton.tap()

        // The mock store returns `.nothingToRestore`, which surfaces a
        // "Geri yüklenecek satın alma yok" alert. The exact title may
        // change, but *some* alert MUST appear — that's the regression
        // we're guarding against.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Restore Purchases must always produce visible feedback (App Store review requirement)")
        alert.buttons["Tamam"].tap()
    }

    func testSubscriptionSettingsAlsoExposesRestoreButton() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Profil"].tap()
        XCTAssertTrue(app.staticTexts["Abonelik"].waitForExistence(timeout: 5))
        app.staticTexts["Abonelik"].tap()
        XCTAssertTrue(app.buttons["restorePurchasesButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Tabs

    func testNativeFoundationEntryPointsRender() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))

        app.tabBars.buttons["Yürüyüş"].tap()
        XCTAssertTrue(app.buttons["Yürüyüş başlat"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Beslenme"].tap()
        XCTAssertTrue(app.staticTexts["Akıllı kayıt"].waitForExistence(timeout: 5))
    }
}
