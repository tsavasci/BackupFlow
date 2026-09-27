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
        debugLog("🔄 BackupFlow: AppDelegate başlatıldı (BGTaskScheduler mode)")
        
        // Suppress auto-layout constraint warnings
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfied")
        
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
                    debugLog("✅ BackupFlow: Bildirim izni verildi")
                } else {
                    debugLog("❌ BackupFlow: Bildirim izni reddedildi")
                }
            } catch {
                debugLog("❌ BackupFlow: Bildirim izni hatası: \(error)")
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

        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_1H_ACTION",
            title: "backup.notification.action.postpone_1h".localized,
            options: []
        )

        let detailsAction = UNNotificationAction(
            identifier: "OPEN_DETAILS_ACTION",
            title: "backup.notification.action.details".localized,
            options: [.foreground]
        )
        
        // Create notification category
        let scheduledBackupCategory = UNNotificationCategory(
            identifier: "SCHEDULED_BACKUP",
            actions: [startAction, postponeAction, detailsAction, cancelAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([scheduledBackupCategory])
        debugLog("✅ BackupFlow: Notification kategorileri kaydedildi")
    }

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            // This is called by the OS when it's time to run the task
            debugLog("🔄 BGTaskScheduler: Görev çalıştırılıyor.")
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleAppRefresh(task: appRefreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingTaskIdentifier, using: nil) { task in
            debugLog("🔄 BGTaskScheduler: Processing görevi çalıştırılıyor.")
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleProcessing(task: processingTask)
        }
        // Not: AppRefresh görevi kayıtlı fakat her background geçişinde planlanmıyor; çifte tetiklemeyi azaltmak için Processing tercih edildi.
        debugLog("✅ BGTaskScheduler: Arka plan görevi kaydedildi.")
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        debugLog("🔄 BGTaskScheduler: Arka plan yenileme görevi başlatılıyor...")
        
        // Schedule a new refresh task for the future
        BackupScheduler.shared.scheduleAppRefresh()
        
        // Log task details
        debugLog("ℹ️ Görev detayları:")
        debugLog("   - ID: \(task.identifier)")
        debugLog("   - Başlangıç: \(Date())")
        
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
            debugLog("⚠️ BGTaskScheduler: Görev süresi doluyor...")
            debugLog("ℹ️ BGTaskScheduler: Aktif aktarım iptal edilerek sonraki çalışmaya ertelenecek")
            Task { @MainActor in
                BackupScheduler.shared.cancelActiveBackgroundBackup()
            }
            complete(false)
        }

        // Perform the backup in a background-safe way
        Task { @MainActor in
            WebDAVService.shared.updateBackgroundMode(isBackground: true)
            FTPService.shared.updateBackgroundMode(isBackground: true)
        }
        let startTime = Date()
        Task {
            debugLog("⏳ BGTaskScheduler: Yedekleme işlemi başlatılıyor...")
            
            // Log available background time on the main actor because it reads UIApplication state
            let remainingText: String = await MainActor.run {
                let remainingTime = UIApplication.shared.backgroundTimeRemaining
                return remainingTime.isFinite ? String(format: "%.1f", remainingTime) : "∞"
            }
            debugLog("   ⏳ Kalan arka plan süresi: \(remainingText) saniye")
            
            // Also check if any timers should have fired but didn't
            debugLog("🔍 BGTaskScheduler: Timer durumları kontrol ediliyor...")
            await BackupScheduler.shared.checkMissedTimers()
            
            let success = await BackupScheduler.shared.executeBackgroundTask()
            
            // Log completion status and duration
            let duration = Date().timeIntervalSince(startTime)
            if success {
                debugLog("✅ BGTaskScheduler: Görev başarıyla tamamlandı.")
                debugLog("   ⏱️ Toplam süre: \(String(format: "%.1f", duration)) saniye")
            } else {
                debugLog("⚠️ BGTaskScheduler: Görev tamamlandı ancak yedekleme yapılamadı.")
            }
            
            complete(success)
        }
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        debugLog("🌐 Background URLSession event received: \(identifier)")
        
        // Store the completion handler for WebDAVService to call when background session completes
        DispatchQueue.main.async {
            WebDAVService.shared.setBackgroundURLSessionCompletionHandler(completionHandler)
        }
    }

    func handleProcessing(task: BGProcessingTask) {
        debugLog("🔄 BGTaskScheduler: Uzun süreli işlem görevi başlatılıyor...")
        
        // Re-schedule after finish
        BackupScheduler.shared.scheduleProcessingTask()
        
        // Log task details
        debugLog("ℹ️ İşlem görevi detayları:")
        debugLog("   - ID: \(task.identifier)")
        debugLog("   - Başlangıç: \(Date())")
        
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
        Task { @MainActor in
            WebDAVService.shared.updateBackgroundMode(isBackground: true)
            FTPService.shared.updateBackgroundMode(isBackground: true)
        }
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        task.expirationHandler = {
            debugLog("⚠️ BGTaskScheduler: İşlem süresi doluyor...")
            debugLog("ℹ️ BGTaskScheduler: Aktif aktarım iptal edilerek sonraki çalışmaya ertelenecek")
            Task { @MainActor in
                BackupScheduler.shared.cancelActiveBackgroundBackup()
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
            complete(false)
        }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            debugLog("⚠️ Arka plan süresi doluyor, işlem sonlandırılıyor...")
            Task { @MainActor in
                BackupScheduler.shared.cancelActiveBackgroundBackup()
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
            complete(false)
        }
        
        let startTime = Date()
        Task {
            debugLog("⏳ BGTaskScheduler: Uzun süreli yedekleme işlemi başlatılıyor...")
            
            // Log available background time on the main actor because it reads UIApplication state
            let remainingText: String = await MainActor.run {
                let remainingTime = UIApplication.shared.backgroundTimeRemaining
                return remainingTime.isFinite ? String(format: "%.1f", remainingTime) : "∞"
            }
            debugLog("   ⏳ Kalan arka plan süresi: \(remainingText) saniye")
            
            let success = await BackupScheduler.shared.executeBackgroundTask()
            
            // Log completion status and duration
            let duration = Date().timeIntervalSince(startTime)
            if success {
                debugLog("✅ BGTaskScheduler: İşlem görevi başarıyla tamamlandı.")
                debugLog("   ⏱️ Toplam süre: \(String(format: "%.1f", duration)) saniye")
            } else {
                debugLog("⚠️ BGTaskScheduler: İşlem tamamlandı ancak yedekleme yapılamadı.")
            }
            
            // End the background task on the main actor to avoid background-thread UIKit calls
            await MainActor.run {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
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
            debugLog("⚠️ BackupFlow: Application Support dizini oluşturulamadı: \(error)")
        }
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Migration: Mevcut BackupTask'lara default mediaType değeri ata
            Task {
                await performMediaTypeMigration(container: container)
            }
            
            return container
        } catch {
            assertionFailure("Could not create ModelContainer: \(error)")
            let fallbackConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                preconditionFailure("Could not create fallback ModelContainer: \(error)")
            }
        }
    }()
    
    @MainActor
    private static func performMediaTypeMigration(container: ModelContainer) async {
        let context = ModelContext(container)
        
        do {
            let tasks = try context.fetch(FetchDescriptor<BackupTask>())
            for task in tasks {
                task.migratePasswordToKeychainIfNeeded()
            }
            
            // Eğer başka migration işlemleri yapılıyorsa, burada devam edilebilir
            try context.save()
            debugLog("✅ BackupFlow: Veritabanı güncellendi")
        } catch {
            debugLog("❌ BackupFlow: Veritabanı güncelleme hatası: \(error)")
        }
    }
    
    init() {
        // BackupScheduler'a shared container'ı inject et
        BackupScheduler.sharedModelContainer = sharedModelContainer
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { (oldPhase: ScenePhase, newPhase: ScenePhase) in
            if newPhase == .background {
                WebDAVService.shared.updateBackgroundMode(isBackground: true)
                FTPService.shared.updateBackgroundMode(isBackground: true)
                if BackupScheduler.shared.isProcessing {
                    debugLog("⚠️ App moved to background. Active backup detected - keeping current process running.")
                    debugLog("📱 WebDAV may continue via background URLSession; FTP is limited to its current iOS execution window.")
                } else {
                    debugLog("🔄 App moved to background. Scheduling processing task.")
                }
                // Processing görevi ağ ve uzun işlem için daha uygun
                BackupScheduler.shared.scheduleProcessingTask()
            } else if newPhase == .active {
                debugLog("📱 BackupFlow: App foreground'a geldi")
                WebDAVService.shared.updateBackgroundMode(isBackground: false)
                FTPService.shared.updateBackgroundMode(isBackground: false)
                
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
                        debugLog("🔔 BackupFlow: App badge temizlendi")
                    } catch {
                        debugLog("❌ BackupFlow: Badge temizleme hatası: \(error)")
                    }
                }
            }
        }
    }
}
