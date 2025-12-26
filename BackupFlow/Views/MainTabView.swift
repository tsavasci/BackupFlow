import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showBackupAlert = false
    @State private var pendingBackupTask: BackupTask?
    
    var body: some View {
        TabView {
            // BackupView'ı çağırmadan önce NavigationStack'e bir referans vererek belirsizliği giderin
            NavigationStack {
                BackupView()
            }
            .tabItem {
                Label("nav.backup".localized, systemImage: "externaldrive.fill")
            }
            
            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("nav.tasks".localized, systemImage: "checklist")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("nav.history".localized, systemImage: "clock.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("nav.settings".localized, systemImage: "gearshape.fill")
            }
            
            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("nav.about".localized, systemImage: "info.circle.fill")
            }
        }
        .accentColor(.blue)
        .onAppear {
            checkForPendingBackup()
        }
        .alert("backup.start_confirmation".localized, isPresented: $showBackupAlert) {
            Button("backup.start".localized) {
                if let task = pendingBackupTask {
                    startPendingBackup(task: task)
                }
            }
            Button("alert.cancel".localized, role: .cancel) {
                clearPendingBackup()
            }
        } message: {
            if let task = pendingBackupTask {
                Text(String(format: "backup.pending_message".localized, task.displayName))
            }
        }
    }
    
    private func checkForPendingBackup() {
        guard let taskIdString = UserDefaults.standard.string(forKey: "pendingBackupTaskId"),
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }
        
        // Timestamp kontrolü (çok eski istekleri görmezden gel)
        let timestamp = UserDefaults.standard.double(forKey: "pendingBackupTimestamp")
        let now = Date().timeIntervalSince1970
        if now - timestamp > 3600 { // 1 saat geçtiyse iptal et
            clearPendingBackup()
            return
        }
        
        // Task'ı bul
        do {
            let descriptor = FetchDescriptor<BackupTask>()
            let allTasks = try modelContext.fetch(descriptor)
            let matchingTask = allTasks.first { $0.id == taskId }
            
            if let task = matchingTask, task.isEnabled && !task.isPaused {
                pendingBackupTask = task
                showBackupAlert = true
                print("📱 BackupFlow: Pending backup bulundu: \(task.displayName)")
            } else {
                clearPendingBackup()
            }
        } catch {
            print("❌ BackupFlow: Pending backup kontrolü hatası: \(error)")
            clearPendingBackup()
        }
    }
    
    private func startPendingBackup(task: BackupTask) {
        clearPendingBackup()
        
        // Yedeklemeyi başlat
        Task {
            do {
                try await BackupScheduler.shared.performBackup(task: task)
                print("✅ BackupFlow: Bildirimden başlatılan yedekleme tamamlandı")
            } catch {
                print("❌ BackupFlow: Bildirimden başlatılan yedekleme hatası: \(error)")
            }
        }
    }
    
    private func clearPendingBackup() {
        UserDefaults.standard.removeObject(forKey: "pendingBackupTaskId")
        UserDefaults.standard.removeObject(forKey: "pendingBackupTimestamp")
        pendingBackupTask = nil
    }
}
