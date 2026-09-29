import XCTest

/// Captures the App Store screenshots: 10 screens in every supported language,
/// using the app's in-memory demo data (`-ScreenshotDemoData`, DEBUG builds only).
/// PNGs are written to /tmp/bf_shots/<language>/NN.png.
final class AppStoreScreenshots: XCTestCase {
    private let languages: [(code: String, locale: String)] = [
        ("tr", "tr_TR"), ("en", "en_US"), ("de", "de_DE"), ("fr", "fr_FR"),
        ("es", "es_ES"), ("pt", "pt_BR"), ("ru", "ru_RU"), ("ar", "ar_SA"),
        ("hi", "hi_IN"), ("ja", "ja_JP"), ("ko", "ko_KR"), ("zh", "zh_CN")
    ]
    private let outputRoot = URL(fileURLWithPath: "/tmp/bf_shots")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        // Optional comma-separated language codes in /tmp/bf_shot_languages limit a
        // re-capture to the languages whose screens changed.
        let only = (try? String(contentsOfFile: "/tmp/bf_shot_languages", encoding: .utf8))?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for language in languages where only?.contains(language.code) ?? true {
            try capture(language: language.code, locale: language.locale)
        }
    }

    @MainActor
    private func capture(language: String, locale: String) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ScreenshotDemoData",
            "-selectedLanguageCode", language,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale
        ]
        app.launch()
        defer { app.terminate() }

        let directory = outputRoot.appendingPathComponent(language)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var index = 0
        func shot() throws {
            index += 1
            sleep(1) // let transitions settle
            let url = directory.appendingPathComponent(String(format: "%02d.png", index))
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        }

        XCTAssertTrue(app.buttons["dashboard.settings"].waitForExistence(timeout: 10))
        sleep(2) // demo data is inserted just after launch

        // 1–2: dashboard, top and scrolled
        try shot()
        app.swipeUp()
        try shot()

        // 3–4: history list and one run's details
        tap(app.buttons["dashboard.history"], in: app)
        try shot()
        app.buttons["history.item"].firstMatch.tap()
        try shot()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["sheet.close"].firstMatch.tap()

        // 5: a saved task's details
        tap(app.buttons["dashboard.server_details"].firstMatch, in: app)
        try shot()
        app.buttons["sheet.close"].firstMatch.tap()

        // 6–9: new backup form for FTP, SFTP and WebDAV, then a daily schedule
        tap(app.buttons["dashboard.add"], in: app)
        try shot()
        // Protocol names are the same in every language, so select by label; segment
        // order is mirrored in right-to-left languages.
        let targetPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(targetPicker.waitForExistence(timeout: 3))
        let isRightToLeft = targetPicker.buttons.element(boundBy: 0).label == "WebDAV"
        targetPicker.buttons["SFTP"].tap()
        try shot()
        targetPicker.buttons["WebDAV"].tap()
        try shot()
        app.swipeUp()
        app.swipeUp()
        // Frequency segments: Manual, Daily, Weekly, Monthly, Interval (mirrored in RTL).
        let frequencyPicker = app.segmentedControls.element(boundBy: 1)
        if frequencyPicker.waitForExistence(timeout: 3) {
            let count = frequencyPicker.buttons.count
            frequencyPicker.buttons.element(boundBy: isRightToLeft ? count - 2 : 1).tap()
        }
        try shot()
        app.buttons["sheet.close"].firstMatch.tap()

        // 10: settings
        tap(app.buttons["dashboard.settings"], in: app)
        try shot()
    }

    /// Scrolls the dashboard until `element` can be tapped, then taps it.
    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<3 where !element.isHittable {
            app.swipeDown()
        }
        for _ in 0..<4 where !element.isHittable {
            app.swipeUp()
        }
        element.tap()
    }
}
