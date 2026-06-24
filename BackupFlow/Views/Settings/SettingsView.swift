import Foundation
import SwiftUI
import SwiftData
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @State private var isTesting = false
    @State private var showingResetAlert = false
    @AppStorage("keepHistoryDays") private var keepHistoryDays = 30
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = "system"
    @AppStorage("RequireExternalPower") private var requireExternalPower = false
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

    private struct LanguageOption: Identifiable {
        let code: String
        let flag: String
        let name: String
        var id: String { code }
    }

    private var supportedLanguages: [LanguageOption] {
        [
            .init(code: "system", flag: "🌐", name: "settings.language.system".localized),
            .init(code: "ar", flag: "🇸🇦", name: "العربية"),
            .init(code: "de", flag: "🇩🇪", name: "Deutsch"),
            .init(code: "en", flag: "🇬🇧", name: "English"),
            .init(code: "es", flag: "🇪🇸", name: "Español"),
            .init(code: "fr", flag: "🇫🇷", name: "Français"),
            .init(code: "hi", flag: "🇮🇳", name: "हिन्दी"),
            .init(code: "ja", flag: "🇯🇵", name: "日本語"),
            .init(code: "ko", flag: "🇰🇷", name: "한국어"),
            .init(code: "pt", flag: "🇵🇹", name: "Português"),
            .init(code: "ru", flag: "🇷🇺", name: "Русский"),
            .init(code: "tr", flag: "🇹🇷", name: "Türkçe"),
            .init(code: "zh", flag: "🇨🇳", name: "中文")
        ]
    }
    
    var body: some View {
        Form {
            Section(header: Text("settings.general".localized)) {
                Picker("settings.history_retention".localized, selection: $keepHistoryDays) {
                    Text("settings.7_days".localized).tag(7)
                    Text("settings.30_days".localized).tag(30)
                    Text("settings.90_days".localized).tag(90)
                    Text("settings.unlimited".localized).tag(0)
                }
                Toggle("settings.require_external_power".localized, isOn: $requireExternalPower)
                Text("settings.require_external_power_note".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .liquidListRow()
            
            Section(header: Text("settings.language".localized)) {
                Picker("settings.language".localized, selection: $selectedLanguageCode) {
                    ForEach(supportedLanguages) { language in
                        Text("\(language.flag) \(language.name)")
                        .tag(language.code)
                    }
                }
            }
            .liquidListRow()

            
            Section(header: Text("settings.about_section".localized)) {
                HStack {
                    Text("settings.version".localized)
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    openAppStoreReview()
                }) {
                    Text("settings.rate_app".localized)
                }
                
                Button(action: {
                    openSupportEmail()
                }) {
                    Text("settings.contact_support".localized)
                }
            }
            .liquidListRow()
            
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("settings.reset_all_data".localized)
                        Spacer()
                    }
                }
            }
            .liquidListRow()
        }
        .navigationTitle("settings.title".localized)
        .scrollContentBackground(.hidden)
        .liquidBackground()
        .onAppear {
            let codes = Set(supportedLanguages.map { $0.code })
            if !codes.contains(selectedLanguageCode) {
                selectedLanguageCode = "system"
            }
        }
        .onChange(of: keepHistoryDays) { _, _ in
            applyHistoryRetention()
        }
        .alert("settings.reset_confirm_title".localized, isPresented: $showingResetAlert) {
            Button("alert.cancel".localized, role: .cancel) { }
            Button("settings.reset".localized, role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("settings.reset_confirm_message".localized)
        }
    }
    
    private func openAppStoreReview() {
        #if canImport(UIKit)
        if #available(iOS 14.0, *) {
            // This uses the modern SwiftUI approach which is preferred.
            // It automatically finds the correct scene.
            requestReview()
            debugLog("📱 BackupFlow: requestReview() çağrıldı (iOS 14+)")
        } else {
            // Fallback for iOS 13.
            SKStoreReviewController.requestReview()
            debugLog("📱 BackupFlow: SKStoreReviewController.requestReview() çağrıldı (iOS 13)")
        }
        #elseif os(macOS)
        if #available(macOS 11.0, *) {
            requestReview()
            debugLog("🖥️ BackupFlow: requestReview() çağrıldı (macOS 11+)")
        } else {
            // Fallback for macOS 10.14, 10.15.
            SKStoreReviewController.requestReview()
            debugLog("🖥️ BackupFlow: SKStoreReviewController.requestReview() çağrıldı (eski macOS)")
        }
        #endif
    }
    
    private func openSupportEmail() {
        let email = "tamersavasci@icloud.com"
        let subject = "BackupFlow Support Request"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #if canImport(UIKit)
        let deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        #else
        let deviceModel = "Unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        
        let body = """
        
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
        OS: \(osVersion)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else {
            debugLog("❌ BackupFlow: Geçersiz email URL")
            return
        }

        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            debugLog("📧 BackupFlow: Destek email'i açılıyor")
        } else {
            // Mail app yoksa, sadece email adresini clipboard'a kopyala
            UIPasteboard.general.string = email
            debugLog("📋 BackupFlow: Email adresi kopyalandı: \(email)")
        }
        #else
        debugLog("📧 BackupFlow: Mail URL: \(mailtoURL)")
        #endif
    }
    
    
    private func resetAllData() {
        Task {
            // Cancel all background tasks
            BackupScheduler.shared.cancelAllBackgroundTasks()
            
            // Clear all BackupTasks
            do {
                let taskDescriptor = FetchDescriptor<BackupTask>()
                let allTasks = try modelContext.fetch(taskDescriptor)
                for task in allTasks {
                    task.removeStoredPassword()
                    modelContext.delete(task)
                }
                
                // Clear all BackupHistory
                let historyDescriptor = FetchDescriptor<BackupHistory>()
                let allHistory = try modelContext.fetch(historyDescriptor)
                for history in allHistory {
                    modelContext.delete(history)
                }
                
                try modelContext.save()
                debugLog("✅ BackupFlow: Tüm veriler başarıyla silindi")
                
                // Reset app storage values to defaults
                keepHistoryDays = 30
                
                // Dil sıfırlama kaldırıldı - Uygulama sadece Türkçe
                
            } catch {
                debugLog("❌ BackupFlow: Veri silme hatası: \(error)")
            }
        }
    }

    private func applyHistoryRetention() {
        HistoryRetentionManager.pruneIfNeeded(context: modelContext)
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
