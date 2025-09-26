import Foundation

// Turkish-only localization shim
// Forces lookups into tr.lproj regardless of system language
private let trBundle: Bundle = {
    // First try to find the Turkish bundle
    if let path = Bundle.main.path(forResource: "tr", ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle
    }
    
    // If not found, log an error but return main bundle as fallback
    print("❌ Turkish localization bundle not found! Falling back to main bundle.")
    return .main
}()

/// A simple logger to help with debugging localization issues
private struct LocalizationLogger {
    static func logMissingLocalization(for key: String) {
        #if DEBUG
        print("⚠️ Missing localization for key: \(key)")
        #endif
    }
}

public extension String {
    /// Returns the localized string for the given key from the Turkish strings file.
    /// If the key is not found, returns the key itself and logs a warning in debug builds.
    var localized: String {
        let localizedString = NSLocalizedString(
            self,
            tableName: "Localizable",
            bundle: trBundle,
            value: self,
            comment: ""
        )
        
        // Log missing localizations in debug builds
        if localizedString == self {
            LocalizationLogger.logMissingLocalization(for: self)
        }
        
        return localizedString
    }
    
    /// Returns a localized string using the format string and the provided arguments.
    /// - Parameter arguments: The arguments to substitute into the format string.
    /// - Returns: A localized formatted string.
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
