import XCTest

final class CoreFlowsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDashboardWaterQuickActionAddsWater() throws {
        let app = launchAppReadyForMainTabs()

        XCTAssertTrue(app.staticTexts["Bugünkü ritmin"].waitForExistence(timeout: 8))
        tapWhenVisible(app.buttons["Su ekle"], in: app)

        XCTAssertTrue(app.staticTexts["+250 ml eklendi"].waitForExistence(timeout: 5))
    }

    func testNutritionBarcodeButtonExists() throws {
        let app = launchAppReadyForMainTabs()

        app.tabBars.buttons["Beslenme"].tap()
        XCTAssertTrue(app.navigationBars["Beslenme"].waitForExistence(timeout: 5))
        scrollUntilVisible(app.buttons["Barkod"], in: app)

        XCTAssertTrue(app.buttons["Barkod"].exists)
    }

    private func launchAppReadyForMainTabs() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        if app.staticTexts["Nuvyra'ya hoş geldin"].waitForExistence(timeout: 3) {
            completePremiumOnboarding(in: app)
        }

        return app
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

    private func tapWhenVisible(_ element: XCUIElement, in app: XCUIApplication) {
        scrollUntilHittable(element, in: app)
        element.tap()
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline, !element.exists {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline, (!element.exists || !element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }
}
