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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
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
