import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isTesting = false
    @State private var showingResetAlert = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoStartBackup") private var autoStartBackup = true
    @AppStorage("keepHistoryDays") private var keepHistoryDays = 30
    
    var body: some View {
        Form {
            Section(header: Text("Genel")) {
                Toggle("Bildirimleri Etkinleştir", isOn: $notificationsEnabled)
                Toggle("Başlangıçta Otomatik Başlat", isOn: $autoStartBackup)
                
                Picker("Geçmişi Saklama Süresi (Gün)", selection: $keepHistoryDays) {
                    Text("7 Gün").tag(7)
                    Text("30 Gün").tag(30)
                    Text("90 Gün").tag(90)
                    Text("Süresiz").tag(0)
                }
            }
            
            Section(header: Text("Hakkında")) {
                HStack {
                    Text("Sürüm")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    // TODO: Open app review page
                }) {
                    Text("Uygulamayı Değerlendir")
                }
                
                Button(action: {
                    // TODO: Open support email
                }) {
                    Text("Destekle İletişime Geç")
                }
            }
            
            Section(header: Text("Geliştirici Ayarları")) {
                NavigationLink(destination: TestFTPView()) {
                    Label("FTP Bağlantı Testi", systemImage: "network")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Tüm Verileri Sıfırla")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Ayarlar")
        .alert("Tüm Verileri Sıfırla", isPresented: $showingResetAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sıfırla", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("Bu işlem tüm yedekleme görevlerini, geçmişi ve ayarları siler. Bu işlem geri alınamaz.")
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
