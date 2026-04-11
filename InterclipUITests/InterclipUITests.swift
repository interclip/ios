//
//  InterclipUITests.swift
//  InterclipUITests
//

import XCTest

@MainActor
final class InterclipUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    // MARK: - Screenshots

    @MainActor
    func testScreenshots() throws {
        // 1. Send tab — empty state
        snapshot("01_Send")

        // 2. Receive tab — empty state
        app.tabBars.buttons["Receive"].tap()
        snapshot("02_Receive")

        // 3. Settings
        app.tabBars.buttons["Settings"].tap()
        snapshot("03_Settings")

        // 4. About page
        app.tables.staticTexts["About"].tap()
        snapshot("04_About")
    }
}
