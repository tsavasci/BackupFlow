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
    let backgroundTaskIdentifier = "com.tamersavasci.BackupFlow.backupTask"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("🔄 BackupFlow: AppDelegate başlatıldı (BGTaskScheduler mode)")

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
        print("✅ BGTaskScheduler: Arka plan görevi kaydedildi.")
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule a new refresh task for the future
        BackupScheduler.shared.scheduleAppRefresh()

        task.expirationHandler = {
            // Clean up any unfinished work
            task.setTaskCompleted(success: false)
            print("❌ BGTaskScheduler: Görev süresi doldu, iptal edildi.")
        }

        // Perform the backup in a background-safe way
        Task {
            print("⏳ BGTaskScheduler: Yedekleme işlemi başlatılıyor...")
            let success = await BackupScheduler.shared.executeBackgroundTask()
            print(success ? "✅ BGTaskScheduler: Görev başarıyla tamamlandı." : "⚠️ BGTaskScheduler: Görev tamamlandı ancak yedekleme yapılamadı.")
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
            let descriptor = FetchDescriptor<BackupTask>()
            let tasks = try context.fetch(descriptor)
            
            var migrationNeeded = false
            for task in tasks {
                if task.mediaType == nil {
                    task.mediaType = .photosOnly // Default değer ata
                    migrationNeeded = true
                }
            }
            
            if migrationNeeded {
                try context.save()
                print("✅ BackupFlow: MediaType migration tamamlandı")
            }
        } catch {
            print("❌ BackupFlow: MediaType migration hatası: \(error)")
        }
    }

    init() {
        // Initialize LanguageManager early
        _ = LanguageManager.shared
        
        // Test localization
        print("🌍 Test localization: \("settings.title".localized)")
        
        // BackupScheduler'a shared container'ı inject et
        BackupScheduler.sharedModelContainer = sharedModelContainer
        
        // Set default appearance for navigation and tab bars
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase, { oldValue, newValue in
            if newValue == .background {
                print("🔄 App moved to background. Scheduling app refresh task.")
                BackupScheduler.shared.scheduleAppRefresh()
            } else if newValue == .active {
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
        })
    }
}
