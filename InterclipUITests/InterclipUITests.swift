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

        // 2. Files tab — file upload
        app.tabBars.buttons["Files"].tap()
        snapshot("02_Files")

        // 3. Receive tab — empty state
        app.tabBars.buttons["Receive"].tap()
        snapshot("03_Receive")

        // 4. Settings
        app.tabBars.buttons["Settings"].tap()
        snapshot("04_Settings")

        // 5. About page
        let aboutCell = app.tables.staticTexts["About"]
        XCTAssert(aboutCell.waitForExistence(timeout: 5))
        aboutCell.tap()
        snapshot("05_About")
    }
}
