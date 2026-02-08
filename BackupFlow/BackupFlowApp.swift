//
//  BackupFlowApp.swift
//  BackupFlow
//
//  Created by Tamer Savaşcı on 19.09.2025.
//

import SwiftUI
import Foundation
import SwiftData
import UserNotifications
import BackgroundTasks
import os.log

// MARK: - System Log Filtering Helper
// FIGSANDBOX, AVFoundation ve benzer system loglar için filter helper
private class SystemLogFilter {
    /// System loglarının (FIGSANDBOX, AVFoundation, Accounts vb.) debug seviyesinde filtrenmesi
    /// Bu loglar genellikle gürültülüdür ve kritik sorun göstermez.
    static func suppressSystemNoise() {
        // isLoggingEnabled değeri kontrol edilmeye başlayacak
        // DEBUG build'inde false ise, system framework'ler debug log göndermeyecek
        #if DEBUG
        // FIGSANDBOX, FigApplicationStateMonitor uyarıları
        // Bu, Photos ve AVFoundation framework'lerinin iç işleyişinde oluşan log output'u
        os_log("📋 DEBUG MODE: System framework uyarıları (FIGSANDBOX, AVFoundation) beklenebilir ve güvenlidir", log: .default, type: .debug)
        #endif
    }
}

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
        
        // Suppress system framework noise logs (FIGSANDBOX, AVFoundation warnings)
        SystemLogFilter.suppressSystemNoise()
        TemporaryStorageMaintenance.cleanupStaleFiles()
        
        registerBackgroundTask()
        
        // Setup notification categories and request permissions
        setupNotificationCategories()
        
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
    
    private func setupNotificationCategories() {
        // Define actions for scheduled backup notifications
        let startAction = UNNotificationAction(
            identifier: "START_BACKUP_ACTION",
            title: "backup.notification.action.start".localized,
            options: [.foreground]  // Opens the app
        )
        
        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_BACKUP_ACTION",
            title: "alert.cancel".localized,
            options: []
        )
        
        // Create notification category
        let scheduledBackupCategory = UNNotificationCategory(
            identifier: "SCHEDULED_BACKUP",
            actions: [startAction, cancelAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([scheduledBackupCategory])
        print("✅ BackupFlow: Notification kategorileri kaydedildi")
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
        // Not: AppRefresh görevi kayıtlı fakat her background geçişinde planlanmıyor; çifte tetiklemeyi azaltmak için Processing tercih edildi.
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
        
        let completionLock = NSLock()
        var didComplete = false
        func complete(_ success: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !didComplete else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
        }
        
        task.expirationHandler = {
            // Clean up any unfinished work
            print("⚠️ BGTaskScheduler: Görev süresi doluyor...")
            print("ℹ️ BGTaskScheduler: Upload işlemi devam ediyor, sistem iptal etse de network aktif kalacak")
            // Görevi tamamlandı olarak işaretle; upload devam edebilir ama BGTask kapanmalı
            complete(false)
        }

        // Perform the backup in a background-safe way
        let startTime = Date()
        Task {
            print("⏳ BGTaskScheduler: Yedekleme işlemi başlatılıyor...")
            
            // Log available background time
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            let remainingText: String = remainingTime.isFinite ? String(format: "%.1f", remainingTime) : "∞"
            print("   ⏳ Kalan arka plan süresi: \(remainingText) saniye")
            
            // Also check if any timers should have fired but didn't
            print("🔍 BGTaskScheduler: Timer durumları kontrol ediliyor...")
            await BackupScheduler.shared.checkMissedTimers()
            
            let success = await BackupScheduler.shared.executeBackgroundTask()
            
            // Log completion status and duration
            let duration = Date().timeIntervalSince(startTime)
            if success {
                print("✅ BGTaskScheduler: Görev başarıyla tamamlandı.")
                print("   ⏱️ Toplam süre: \(String(format: "%.1f", duration)) saniye")
            } else {
                print("⚠️ BGTaskScheduler: Görev tamamlandı ancak yedekleme yapılamadı.")
            }
            
            complete(success)
        }
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        print("🌐 Background URLSession event received: \(identifier)")
        
        // Store the completion handler for WebDAVService to call when background session completes
        DispatchQueue.main.async {
            WebDAVService.shared.setBackgroundURLSessionCompletionHandler(completionHandler)
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
        
        let completionLock = NSLock()
        var didComplete = false
        func complete(_ success: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !didComplete else { return }
            didComplete = true
            task.setTaskCompleted(success: success)
        }
        
        // Start a background task to ensure we have enough time
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        task.expirationHandler = {
            print("⚠️ BGTaskScheduler: İşlem süresi doluyor...")
            print("ℹ️ BGTaskScheduler: Upload devam ediyor, network bağlantısı korunuyor")
            // Upload işlemi devam etsin, BGTask tamamlanmış sayılsın
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            complete(false)
        }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            print("⚠️ Arka plan süresi doluyor, işlem sonlandırılıyor...")
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
            complete(false)
        }
        
        let startTime = Date()
        Task {
            print("⏳ BGTaskScheduler: Uzun süreli yedekleme işlemi başlatılıyor...")
            
            // Log available background time
            let remainingTime = UIApplication.shared.backgroundTimeRemaining
            let remainingText: String = remainingTime.isFinite ? String(format: "%.1f", remainingTime) : "∞"
            print("   ⏳ Kalan arka plan süresi: \(remainingText) saniye")
            
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
            
            complete(success)
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
        
        // Ensure Application Support directory exists before opening the store
        do {
            let appSupportURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        } catch {
            print("⚠️ BackupFlow: Application Support dizini oluşturulamadı: \(error)")
        }
        
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
        
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { (oldPhase: ScenePhase, newPhase: ScenePhase) in
            if newPhase == .background {
                WebDAVService.shared.updateBackgroundMode(isBackground: true)
                if BackupScheduler.shared.isProcessing {
                    print("⚠️ App moved to background. Active backup detected - keeping current process running.")
                    print("📱 Background URLSession will continue the upload process.")
                } else {
                    print("🔄 App moved to background. Scheduling processing task.")
                }
                // Processing görevi ağ ve uzun işlem için daha uygun
                BackupScheduler.shared.scheduleProcessingTask()
            } else if newPhase == .active {
                print("📱 BackupFlow: App foreground'a geldi")
                WebDAVService.shared.updateBackgroundMode(isBackground: false)
                
                // Missed timer kontrolü
                Task {
                    await BackupScheduler.shared.checkMissedTimers()
                }

                Task {
                    HistoryRetentionManager.pruneIfNeeded(container: sharedModelContainer)
                }
                
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
