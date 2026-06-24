import Foundation

/// A simple logger to help with debugging localization issues
private struct LocalizationLogger {
    nonisolated static func logMissingLocalization(for key: String) {
        #if DEBUG
        debugLog("⚠️ Missing localization for key: \(key)")
        #endif
    }
}

public extension String {
    /// Returns the localized string for the given key from the Turkish strings file.
    /// If the key is not found, returns the key itself and logs a warning in debug builds.
    nonisolated var localized: String {
        let selected = UserDefaults.standard.string(forKey: "selectedLanguageCode")
        let bundle: Bundle = {
            if let code = selected, code != "system",
               let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let b = Bundle(path: path) {
                return b
            }
            return .main
        }()

        let localizedString = NSLocalizedString(
            self,
            tableName: "Localizable",
            bundle: bundle,
            value: self,
            comment: ""
        )

        if localizedString != self {
            return localizedString
        }

        if let trPath = Bundle.main.path(forResource: "tr", ofType: "lproj"),
           let trBundle = Bundle(path: trPath) {
            let trString = NSLocalizedString(
                self,
                tableName: "Localizable",
                bundle: trBundle,
                value: self,
                comment: ""
            )
            if trString != self {
                return trString
            }
        }
        
        LocalizationLogger.logMissingLocalization(for: self)
        return self
    }
    
    /// Returns a localized string using the format string and the provided arguments.
    /// - Parameter arguments: The arguments to substitute into the format string.
    /// - Returns: A localized formatted string.
    nonisolated func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

