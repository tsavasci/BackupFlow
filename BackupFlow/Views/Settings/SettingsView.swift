import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isTesting = false
    @State private var showingResetAlert = false
    @State private var showingLanguageAlert = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoStartBackup") private var autoStartBackup = true
    @AppStorage("keepHistoryDays") private var keepHistoryDays = 30
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("settings.general".localized)) {
                Toggle("settings.notifications_enabled".localized, isOn: $notificationsEnabled)
                Toggle("settings.auto_start".localized, isOn: $autoStartBackup)
                
                Picker("settings.history_retention".localized, selection: $keepHistoryDays) {
                    Text("settings.7_days".localized).tag(7)
                    Text("settings.30_days".localized).tag(30)
                    Text("settings.90_days".localized).tag(90)
                    Text("settings.unlimited".localized).tag(0)
                }
                
                // Language Selection
                Picker("language.selection".localized, selection: $languageManager.currentLanguage) {
                    ForEach(LanguageManager.SupportedLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: languageManager.currentLanguage) { _, _ in
                    showingLanguageAlert = true
                }
            }
            
            Section(header: Text("settings.about_section".localized)) {
                HStack {
                    Text("settings.version".localized)
                    Spacer()
                    Text("1.0.0")
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
            
            Section(header: Text("settings.developer_settings".localized)) {
                NavigationLink(destination: BatterySettingsView()) {
                    Label("battery.settings".localized, systemImage: "battery.75")
                }
                
                NavigationLink(destination: TestFTPView()) {
                    Label("settings.ftp_connection_test".localized, systemImage: "network")
                }
            }
            
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
        }
        .navigationTitle("settings.title".localized)
        .alert("settings.reset_confirm_title".localized, isPresented: $showingResetAlert) {
            Button("alert.cancel".localized, role: .cancel) { }
            Button("settings.reset".localized, role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("settings.reset_confirm_message".localized)
        }
        .alert("language.restart_required".localized, isPresented: $showingLanguageAlert) {
            Button("alert.ok".localized) { }
        } message: {
            Text("language.restart_message".localized)
        }
    }
    
    private func openAppStoreReview() {
        // iOS 14+ için SKStoreReviewController kullan (daha iyi UX)
        if #available(iOS 14.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                print("📱 BackupFlow: Native review dialog açılıyor")
            }
        } else {
            // iOS 13 için fallback
            SKStoreReviewController.requestReview()
            print("📱 BackupFlow: Review request gönderildi")
        }
        
        // Alternatif olarak direkt App Store'a yönlendirmek için:
        // Bu kodu yayınlandıktan sonra gerçek App ID ile kullanabilirsiniz
        /*
        let appID = "YOUR_APP_ID_HERE" 
        let reviewURL = "https://apps.apple.com/app/id\(appID)?action=write-review"
        
        if let url = URL(string: reviewURL) {
            UIApplication.shared.open(url)
        }
        */
    }
    
    private func openSupportEmail() {
        let email = "tamersavasci@icloud.com"
        let subject = "BackupFlow Support Request"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        
        let body = """
        
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
        iOS: \(iosVersion)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else {
            print("❌ BackupFlow: Geçersiz email URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            print("📧 BackupFlow: Destek email'i açılıyor")
        } else {
            // Mail app yoksa, sadece email adresini clipboard'a kopyala
            UIPasteboard.general.string = email
            print("📋 BackupFlow: Email adresi kopyalandı: \(email)")
        }
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
                    modelContext.delete(task)
                }
                
                // Clear all BackupHistory
                let historyDescriptor = FetchDescriptor<BackupHistory>()
                let allHistory = try modelContext.fetch(historyDescriptor)
                for history in allHistory {
                    modelContext.delete(history)
                }
                
                try modelContext.save()
                print("✅ BackupFlow: Tüm veriler başarıyla silindi")
                
                // Reset app storage values to defaults
                notificationsEnabled = true
                autoStartBackup = true
                keepHistoryDays = 30
                
                // Reset language to system default
                languageManager.setLanguage(.system)
                
            } catch {
                print("❌ BackupFlow: Veri silme hatası: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
