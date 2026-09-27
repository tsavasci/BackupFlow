//
//  BackupFlowUITests.swift
//  BackupFlowUITests
//
//  Created by Tamer Savaşcı on 19.09.2025.
//

import XCTest

final class BackupFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsSheetClosesWithCloseButton() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["dashboard.settings"].tap()
        let close = app.buttons["sheet.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))

        close.tap()
        XCTAssertTrue(app.buttons["dashboard.settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(close.exists)
    }

    @MainActor
    func testSaveIsDisabledOnEmptyBackupForm() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["dashboard.add"].tap()
        let save = app.buttons["backup.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)

        app.buttons["sheet.close"].tap()
        XCTAssertFalse(save.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
