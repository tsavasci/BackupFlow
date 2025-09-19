import Foundation
import SwiftUI
import Combine

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            saveLanguagePreference()
            applyLanguageChange()
        }
    }
    
    enum SupportedLanguage: String, CaseIterable, Identifiable {
        case system = "system"
        case turkish = "tr"
        case english = "en"
        case german = "de"
        case french = "fr"
        case chinese = "zh"
        case japanese = "ja"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .system:
                return "🌐 " + NSLocalizedString("language.system", comment: "System language option")
            case .turkish:
                return "🇹🇷 Türkçe"
            case .english:
                return "🇺🇸 English"
            case .german:
                return "🇩🇪 Deutsch"
            case .french:
                return "🇫🇷 Français"
            case .chinese:
                return "🇨🇳 中文"
            case .japanese:
                return "🇯🇵 日本語"
            }
        }
        
        var languageCode: String? {
            switch self {
            case .system:
                return nil // Use system language
            default:
                return rawValue
            }
        }
    }
    
    private init() {
        // Load saved language preference or default to system
        let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? SupportedLanguage.system.rawValue
        self.currentLanguage = SupportedLanguage(rawValue: savedLanguage) ?? .system
        
        // Apply the language immediately
        applyLanguageChange()
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
    }
    
    private func applyLanguageChange() {
        if let languageCode = currentLanguage.languageCode {
            // Set the app language override
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            // Remove override to use system language
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
    
    /// Get localized string with current language preference
    func localizedString(for key: String, comment: String = "") -> String {
        // First try direct file reading approach
        let languageCode = currentLanguage.languageCode ?? Locale.current.language.languageCode?.identifier ?? "en"
        
        if let localizedString = getLocalizedStringFromFile(key: key, languageCode: languageCode) {
            return localizedString
        }
        
        // Fallback to traditional NSLocalizedString approach
        if let languageCodeForBundle = currentLanguage.languageCode,
           let path = Bundle.main.path(forResource: languageCodeForBundle, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = NSLocalizedString(key, bundle: bundle, value: key, comment: comment)
            if localizedString != key {
                return localizedString
            }
        }
        
        // System localization fallback
        let systemString = NSLocalizedString(key, value: key, comment: comment)
        if systemString != key {
            return systemString
        }
        
        // Final fallback: try Turkish (our primary language)
        if let turkishString = getLocalizedStringFromFile(key: key, languageCode: "tr") {
            return turkishString
        }
        
        return key
    }
    
    private func getLocalizedStringFromFile(key: String, languageCode: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(languageCode).lproj"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        // Parse the strings file manually
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.starts(with: "\"\(key)\"") {
                // Extract value between quotes after =
                if let equalRange = trimmed.range(of: " = \""),
                   let startIndex = trimmed.range(of: "\"", range: equalRange.upperBound..<trimmed.endIndex)?.lowerBound,
                   let endIndex = trimmed.range(of: "\";", range: startIndex..<trimmed.endIndex)?.lowerBound {
                    let value = String(trimmed[trimmed.index(after: startIndex)..<endIndex])
                    return value
                }
            }
        }
        return nil
    }
}

// MARK: - String Extensions for easier localization
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
    
    func localized(comment: String) -> String {
        return LanguageManager.shared.localizedString(for: self, comment: comment)
    }
}