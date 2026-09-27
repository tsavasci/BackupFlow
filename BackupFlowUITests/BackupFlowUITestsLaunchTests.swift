//
//  BackupFlowUITestsLaunchTests.swift
//  BackupFlowUITests
//
//  Created by Tamer Savaşcı on 19.09.2025.
//

import XCTest

final class BackupFlowUITestsLaunchTests: XCTestCase {

    // A single launch is enough; running it for every language × orientation × appearance
    // combination repeats this screenshot-only test dozens of times and slows the suite.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
