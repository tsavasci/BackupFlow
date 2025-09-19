//
//  BackupFlowApp.swift
//  BackupFlow
//
//  Created by Tamer Savaşcı on 19.09.2025.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

// MARK: - AppDelegate for handling app lifecycle
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        BackupScheduler.shared.backgroundCompletionHandler = completionHandler
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        Task {
            try? await BackupScheduler.shared.refreshTaskStatuses()
            try? await BackupScheduler.shared.checkAndRescheduleTasks()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Task {
            // Aktif görevleri kaydet
            try? await BackupScheduler.shared.saveActiveTaskStates()
        }
    }
}

@main
struct BackupFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
    }
}
