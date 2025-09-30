//
//  BackupFlowApp.swift
//  BackupFlow
//
//  Created by Tamer Savaşcı on 19.09.2025.
//

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks

// MARK: - AppDelegate for handling app lifecycle
class AppDelegate: NSObject, UIApplicationDelegate {
    lazy var backgroundTaskIdentifier: String = {
        let base = Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow"
        return base + ".backupTask"
    }()
    lazy var processingTaskIdentifier: String = {
        let base = Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow"
        return base + ".processing"
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🔄 BackupFlow: AppDelegate başlatıldı (BGTaskScheduler mode)")
        
        // Suppress auto-layout constraint warnings
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfied")
        
        registerBackgroundTask()
        
        // Request notification permissions on app launch
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("✅ BackupFlow: Bildirim izni verildi")
                } else {
                    print("❌ BackupFlow: Bildirim izni reddedildi")
                }
            } catch {
                print("❌ BackupFlow: Bildirim izni hatası: \(error)")
            }
        }
        
        return true
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            // This is called by the OS when it's time to run the task
            print("🔄 BGTaskScheduler: Görev çalıştırılıyor.")
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            print("🔄 BGTaskScheduler: Processing görevi çalıştırılıyor.")
            self.handleProcessing(task: task as! BGProcessingTask)
        }
        print("✅ BGTaskScheduler: Arka plan görevi kaydedildi.")
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        print("🔄 BGTaskScheduler: Arka plan yenileme görevi başlatılıyor...")
        
        // Schedule a new refresh task for the future
        BackupScheduler.shared.scheduleAppRefresh()
        
        // Log task details
        print("ℹ️ Görev detayları:")
        print("   - ID: \(task.identifier)")
        print("   - Başlangıç: \(Date())")
        
        task.expirationHandler = {
            // Clean up any unfinished work
            print("⚠️ BGTaskScheduler: Görev süresi doluyor, işlemler sonlandırılıyor...")
            task.setTaskCompleted(success: false)
            print("❌ BGTaskScheduler: Görev süresi doldu, iptal edildi.")
        }

        // Perform the backup in a background-safe way
        let startTime = Date()
        Task {
            print("⏳ BGTaskScheduler: Yedekleme işlemi başlatılıyor...")
            
            // Log available background time
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            print("   ⏳ Kalan arka plan süresi: \(String(format: "%.1f", remainingTime)) saniye")
            
            let success = await BackupScheduler.shared.executeBackgroundTask()
            
            // Log completion status and duration
            let duration = Date().timeIntervalSince(startTime)
            if success {
                print("✅ BGTaskScheduler: Görev başarıyla tamamlandı.")
                print("   ⏱️ Toplam süre: \(String(format: "%.1f", duration)) saniye")
            } else {
                print("⚠️ BGTaskScheduler: Görev tamamlandı ancak yedekleme yapılamadı.")
            }
            
            task.setTaskCompleted(success: success)
        }
    }

    func handleProcessing(task: BGProcessingTask) {
        print("🔄 BGTaskScheduler: Uzun süreli işlem görevi başlatılıyor...")
        
        // Re-schedule after finish
        BackupScheduler.shared.scheduleProcessingTask()
        
        // Log task details
        print("ℹ️ İşlem görevi detayları:")
        print("   - ID: \(task.identifier)")
        print("   - Başlangıç: \(Date())")
        print("   - Ağ bağlantısı gerekli: \(task.requiresNetworkConnectivity)")
        print("   - Şarj gereksinimi: \(task.requiresExternalPower ? "Şarjda olmalı" : "Pil yeterli")")
        
        task.expirationHandler = {
            print("⚠️ BGTaskScheduler: İşlem süresi doluyor, temizlik yapılıyor...")
            task.setTaskCompleted(success: false)
            print("❌ BGTaskScheduler: İşlem süresi doldu, iptal edildi.")
        }

        // Start a background task to ensure we have enough time
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            print("⚠️ Arka plan süresi doluyor, işlem sonlandırılıyor...")
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
        
        let startTime = Date()
        Task {
            print("⏳ BGTaskScheduler: Uzun süreli yedekleme işlemi başlatılıyor...")
            
            // Log available background time
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            print("   ⏳ Kalan arka plan süresi: \(String(format: "%.1f", remainingTime)) saniye")
            
            let success = await BackupScheduler.shared.executeBackgroundTask()
            
            // Log completion status and duration
            let duration = Date().timeIntervalSince(startTime)
            if success {
                print("✅ BGTaskScheduler: İşlem görevi başarıyla tamamlandı.")
                print("   ⏱️ Toplam süre: \(String(format: "%.1f", duration)) saniye")
            } else {
                print("⚠️ BGTaskScheduler: İşlem tamamlandı ancak yedekleme yapılamadı.")
            }
            
            // End the background task
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            
            task.setTaskCompleted(success: success)
        }
    }
}

@main
struct BackupFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BackupTask.self,
            BackupHistory.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Migration: Mevcut BackupTask'lara default mediaType değeri ata
            Task {
                await performMediaTypeMigration(container: container)
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @MainActor
    private static func performMediaTypeMigration(container: ModelContainer) async {
        let context = ModelContext(container)
        
        do {
            // MediaType artık nil olamaz, bu yüzden migration gerekli değil
            // Eski verilerle uyumluluk için gerekliyse, başka bir migration stratejisi uygulanabilir
            
            // Eğer başka migration işlemleri yapılıyorsa, burada devam edilebilir
            try context.save()
            print("✅ BackupFlow: Veritabanı güncellendi")
        } catch {
            print("❌ BackupFlow: Veritabanı güncelleme hatası: \(error)")
        }
    }
    
    init() {
        // Test localization
        let testString = "settings.title".localized
        print("🌍 Test localization: \(testString)")
        
        // BackupScheduler'a shared container'ı inject et
        BackupScheduler.sharedModelContainer = sharedModelContainer
        
        // Set default appearance for navigation and tab bars
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Force Turkish locale for the app
        UserDefaults.standard.set(["tr"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { (oldPhase: ScenePhase, newPhase: ScenePhase) in
            if newPhase == .background {
                print("🔄 App moved to background. Scheduling app refresh task.")
                BackupScheduler.shared.scheduleAppRefresh()
                // Ayrıca processing görevi de planla (ağ gereksinimi olan daha uzun işler için)
                BackupScheduler.shared.scheduleProcessingTask()
            } else if newPhase == .active {
                // App açıldığında badge'i temizle
                Task {
                    do {
                        try await UNUserNotificationCenter.current().setBadgeCount(0)
                        print("🔔 BackupFlow: App badge temizlendi")
                    } catch {
                        print("❌ BackupFlow: Badge temizleme hatası: \(error)")
                    }
                }
            }
        }
    }
}
