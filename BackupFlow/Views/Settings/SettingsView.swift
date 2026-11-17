import Foundation
import StoreKit
import SwiftData
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var scheduler = BackupScheduler.shared

    @State private var showingResetAlert = false
    @State private var showingOnboarding = false
    @AppStorage("keepHistoryDays") private var keepHistoryDays = 30
    @AppStorage("selectedLanguageCode") private var selectedLanguageCode = "system"
    @AppStorage("RequireExternalPower") private var requireExternalPower = false

    private struct LanguageOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    private var supportedLanguages: [LanguageOption] {
        [
            .init(code: "system", name: "settings.language.system".localized),
            .init(code: "ar", name: "العربية"),
            .init(code: "de", name: "Deutsch"),
            .init(code: "en", name: "English"),
            .init(code: "es", name: "Español"),
            .init(code: "fr", name: "Français"),
            .init(code: "hi", name: "हिन्दी"),
            .init(code: "ja", name: "日本語"),
            .init(code: "ko", name: "한국어"),
            .init(code: "pt", name: "Português"),
            .init(code: "ru", name: "Русский"),
            .init(code: "tr", name: "Türkçe"),
            .init(code: "zh", name: "中文")
        ]
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.history_retention".localized, selection: $keepHistoryDays) {
                        Text("settings.7_days".localized).tag(7)
                        Text("settings.30_days".localized).tag(30)
                        Text("settings.90_days".localized).tag(90)
                        Text("settings.unlimited".localized).tag(0)
                    }
                    Toggle("settings.require_external_power".localized, isOn: $requireExternalPower)
                    NavigationLink("battery.settings".localized) {
                        BatterySettingsView()
                    }
                } header: {
                    sectionLabel("settings.general".localized.uppercased())
                } footer: {
                    Text("settings.require_external_power_note".localized)
                }
                .listRowBackground(BF.surface)

                Section {
                    Picker("settings.language".localized, selection: $selectedLanguageCode) {
                        ForEach(supportedLanguages) { language in
                            Text(language.name).tag(language.code)
                        }
                    }
                } header: {
                    sectionLabel("settings.language".localized.uppercased())
                }
                .listRowBackground(BF.surface)

                Section {
                    LabeledContent("settings.version".localized) {
                        Text(versionString)
                            .font(BF.mono)
                            .monospacedDigit()
                    }
                    Button("settings.whats_new".localized) {
                        showingOnboarding = true
                    }
                    .accessibilityIdentifier("settings.whats_new")

                    Button("settings.rate_app".localized) {
                        openAppStoreReview()
                    }

                    Button("settings.contact_support".localized) {
                        openSupportEmail()
                    }

                    ShareLink(item: BackupDiagnosticsExporter.buildReport()) {
                        Text("settings.export_diagnostics".localized)
                    }
                } header: {
                    sectionLabel("settings.about_section".localized.uppercased())
                }
                .listRowBackground(BF.surface)

                Section {
                    Button("settings.reset_all_data".localized, role: .destructive) {
                        showingResetAlert = true
                    }
                    // A running backup still holds its task; deleting it underneath crashes SwiftData.
                    .disabled(scheduler.isProcessing)
                } footer: {
                    Text(
                        scheduler.isProcessing
                            ? "settings.reset_unavailable_while_backing_up".localized
                            : "settings.reset_footer_note".localized
                    )
                }
                .listRowBackground(BF.surface)
            }
            .scrollContentBackground(.hidden)
            .background(BF.bg)
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done".localized) { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("sheet.close")
                }
            }
            .onAppear {
                let codes = Set(supportedLanguages.map(\.code))
                if !codes.contains(selectedLanguageCode) {
                    selectedLanguageCode = "system"
                }
            }
            .onChange(of: keepHistoryDays) { _, _ in
                applyHistoryRetention()
            }
            .confirmationDialog(
                "settings.reset_confirm_title".localized,
                isPresented: $showingResetAlert,
                titleVisibility: .visible
            ) {
                Button("settings.reset".localized, role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("settings.reset_confirm_message".localized)
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView {
                    showingOnboarding = false
                }
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BF.monoSmall)
            .textCase(nil)
    }

    private func openAppStoreReview() {
        requestReview()
    }

    private func openSupportEmail() {
        let email = "tamersavasci@icloud.com"
        let subject = "BackupFlow Support Request"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion

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

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            debugLog("📧 BackupFlow: Destek email'i açılıyor")
        } else {
            UIPasteboard.general.string = email
            debugLog("📋 BackupFlow: Email adresi kopyalandı: \(email)")
        }
    }

    private func resetAllData() {
        Task {
            BackupScheduler.shared.cancelAllBackgroundTasks()

            do {
                let taskDescriptor = FetchDescriptor<BackupTask>()
                let allTasks = try modelContext.fetch(taskDescriptor)
                for task in allTasks {
                    BackupNotifier.shared.removeReminder(forTaskID: task.id)
                    task.removeStoredPassword()
                    modelContext.delete(task)
                }

                let historyDescriptor = FetchDescriptor<BackupHistory>()
                let allHistory = try modelContext.fetch(historyDescriptor)
                for history in allHistory {
                    modelContext.delete(history)
                }

                try modelContext.save()
                debugLog("✅ BackupFlow: Tüm veriler başarıyla silindi")

                keepHistoryDays = 30
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
    SettingsView()
}
