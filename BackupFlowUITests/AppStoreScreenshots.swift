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

        // 1: Home (Tasks tab — 14-day chart + task rows)
        try shot()

        // 2: Task Detail
        tap(app.buttons["dashboard.server_details"].firstMatch, in: app)
        try shot()
        app.buttons["sheet.close"].firstMatch.tap()

        // 3–5: New Backup form for FTP, SFTP, and WebDAV
        tap(app.buttons["dashboard.add"], in: app)
        try shot()
        let targetPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(targetPicker.waitForExistence(timeout: 3))
        targetPicker.buttons["SFTP"].tap()
        try shot()
        targetPicker.buttons["WebDAV"].tap()
        try shot()
        app.buttons["sheet.close"].firstMatch.tap()

        // 6–7: History tab and History Detail
        selectTab(index: 1, language: language, in: app)
        try shot()
        let firstHistory = app.buttons["history.item"].firstMatch
        if firstHistory.waitForExistence(timeout: 3) {
            firstHistory.tap()
            try shot()
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        // 8: Restore tab
        selectTab(index: 2, language: language, in: app)
        try shot()

        // 9: Settings (from Tasks tab)
        selectTab(index: 0, language: language, in: app)
        tap(app.buttons["dashboard.settings"], in: app)
        try shot()
    }

    @MainActor
    private func selectTab(index: Int, language: String, in app: XCUIApplication) {
        let tabBarButton = app.tabBars.buttons.element(boundBy: index)
        if tabBarButton.waitForExistence(timeout: 1.5) {
            tabBarButton.tap()
            return
        }
        let titlesByLanguage: [String: [String]] = [
            "tr": ["Görevler", "Geçmiş", "Geri Yükle"],
            "en": ["Tasks", "History", "Restore"],
            "de": ["Aufgaben", "Verlauf", "Wiederherstellen"],
            "fr": ["Tâches", "Historique", "Restaurer"],
            "es": ["Tareas", "Historial", "Restaurar"],
            "pt": ["Tarefas", "Histórico", "Restaurar"],
            "ru": ["Задачи", "История", "Восстановить"],
            "ar": ["المهام", "السجل", "استعادة"],
            "hi": ["कार्य", "इतिहास", "पुनर्स्थापित करें"],
            "ja": ["タスク", "履歴", "復元"],
            "ko": ["작업", "기록", "복원"],
            "zh": ["任务", "历史", "恢复"],
        ]
        let label = titlesByLanguage[language]?[index] ?? ""
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab button '\(label)'")
        button.tap()
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
