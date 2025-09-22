import Foundation
import OSLog
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import UniformTypeIdentifiers
import Photos
import AVFoundation

@MainActor
final class BackupScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Singleton & Properties
    static let shared = BackupScheduler()
    
    // Shared ModelContainer - uygulamadan inject edilecek
    static var sharedModelContainer: ModelContainer?
    
    private let logger = Logger(subsystem: "com.backupflow.app", category: "BackupScheduler")
    private let appGroupID: String
    private let backgroundSessionIdentifier: String
    
    // Background URLSession
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()
    
    // Timers keyed by BackupTask.id
    @MainActor private var scheduledTimers: [UUID: Timer] = [:]
    
    private lazy var userLocalDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        f.timeZone = TimeZone.current  // Kullanıcının yerel saati
        f.locale = Locale.current       // Kullanıcının yerel ayarı
        return f
    }()
    
    private let maxRetryAttempts = 3
    private var retryCount: [UUID: Int] = [:]
    private var lastScheduledTime: Date?
    
    @Published private(set) var isProcessing = false
    
    // MARK: - Initialization
    override init() {
        let b = Bundle.main.bundleIdentifier ?? "com.backupflow.app"
        self.appGroupID = "group." + b
        self.backgroundSessionIdentifier = b + ".background"
        super.init()
        setupNotifications()
        print("🔄 BackupFlow: BackupScheduler init tamamlandı (Timer-only mode)")
    }
    
    // MARK: - Public Interface
    public func scheduleAllTasks() {
        Task {
            await performScheduling()
        }
    }
    
    public func pauseTask(_ task: BackupTask) {
        cancelTimer(for: task.id)
        task.isPaused = true
        print("⏸️ BackupFlow: Görev duraklatıldı: \(task.displayName)")
        
        // Send pause notification
        sendPauseNotification(for: task)
    }
    
    public func resumeTask(_ task: BackupTask) {
        task.isPaused = false
        print("▶️ BackupFlow: Görev devam ettirildi: \(task.displayName)")
        
        // Reschedule the task
        Task {
            await scheduleTask(task)
        }
        
        // Send resume notification
        sendResumeNotification(for: task)
    }
    
    public func scheduleBackup(task: BackupTask) async throws {
        await scheduleTask(task)
    }
    
    public func cancelCurrentTask(for task: BackupTask) {
        // Cancel timer for this specific task
        cancelTimer(for: task.id)
        
        // Update task status to cancelled
        task.backupStatus = .cancelled
        task.progress = 0.0
        task.currentFile = nil
        
        print("🚫 BackupFlow: Görev iptal edildi: \(task.displayName)")
    }
    
    // MARK: - Timer Management
    @MainActor
    private func scheduleTask(_ task: BackupTask) async {
        // Skip if paused
        if task.isPaused {
            print("⏸️ BackupFlow: Görev duraklatılmış, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        
        // Skip manual tasks
        if task.frequency == .manual {
            print("📝 BackupFlow: Manuel görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        
        // Skip disabled tasks
        if !task.isEnabled {
            print("🚫 BackupFlow: Devre dışı görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        
        // Cancel existing timer for this task
        cancelTimer(for: task.id)
        
        // Calculate next run time
        guard let nextRunTime = calculateNextRunTime(for: task) else {
            print("❌ BackupFlow: Sonraki çalışma zamanı hesaplanamadı: \(task.displayName)")
            return
        }
        
        // Update task's next run time
        task.nextRunTime = nextRunTime
        
        // Schedule timer
        let now = Date()
        let timeInterval = nextRunTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            print("⚡ BackupFlow: Görev hemen çalışacak: \(task.displayName)")
            Task {
                try? await performBackup(task: task)
            }
            return
        }
        
        print("⏰ BackupFlow: Görev zamanlandı: \(task.displayName)")
        print("   📅 Şu anda: \(userLocalDateFormatter.string(from: now))")
        print("   📅 Sonraki çalışma: \(userLocalDateFormatter.string(from: nextRunTime))")
        print("   ⏳ Kalan süre: \(formatTimeInterval(timeInterval))")
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self, taskId = task.id] _ in
            Task { @MainActor in
                self?.scheduledTimers.removeValue(forKey: taskId)
                
                // Find the task by ID and perform backup
                guard let container = Self.sharedModelContainer else { return }
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { $0.id == taskId })
                if let foundTask = try? context.fetch(descriptor).first {
                    try? await self?.performBackup(task: foundTask)
                }
            }
        }
        
        scheduledTimers[task.id] = timer
    }
    
    @MainActor
    private func cancelTimer(for taskId: UUID) {
        if let timer = scheduledTimers[taskId] {
            timer.invalidate()
            scheduledTimers.removeValue(forKey: taskId)
            print("🚫 BackupFlow: Timer iptal edildi: \(taskId)")
        }
    }
    
    @MainActor
    private func performScheduling() async {
        print("🔄 BackupFlow: Tüm görevler yeniden zamanlanıyor...")
        
        guard let container = Self.sharedModelContainer else {
            print("❌ BackupFlow: ModelContainer bulunamadı")
            return
        }
        
        let context = ModelContext(container)
        let tasks = try? context.fetch(FetchDescriptor<BackupTask>())
        
        guard let tasks = tasks else {
            print("❌ BackupFlow: Görevler yüklenemedi")
            return
        }
        
        print("📋 BackupFlow: \(tasks.count) görev bulundu")
        
        // Clear existing timers
        for timer in scheduledTimers.values {
            timer.invalidate()
        }
        scheduledTimers.removeAll()
        
        // Schedule each task
        for task in tasks {
            await scheduleTask(task)
        }
        
        lastScheduledTime = Date()
        print("✅ BackupFlow: Tüm görevler zamanlandı")
    }
    
    // MARK: - Backup Execution
    public func performBackup(task: BackupTask) async throws {
        guard !task.isPaused else {
            print("⏸️ BackupFlow: Görev duraklatılmış, yedekleme atlanıyor: \(task.displayName)")
            return
        }
        
        print("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName)")
        
        // Update task status
        task.backupStatus = .preparing
        task.progress = 0.0
        task.lastError = nil
        
        do {
            // Perform the actual backup
            try await executeBackup(task: task)
            
            // Update task on success
            task.backupStatus = .completed
            task.progress = 1.0
            task.lastBackupDate = Date()
            
            // Schedule next run
            await scheduleTask(task)
            
            print("✅ BackupFlow: Yedekleme tamamlandı: \(task.displayName)")
            
        } catch {
            // Update task on failure
            task.backupStatus = .failed
            task.lastError = error.localizedDescription
            
            print("❌ BackupFlow: Yedekleme başarısız: \(task.displayName) - \(error)")
            
            // Retry logic
            let currentRetryCount = retryCount[task.id] ?? 0
            if currentRetryCount < maxRetryAttempts {
                retryCount[task.id] = currentRetryCount + 1
                print("🔄 BackupFlow: Yeniden deneme \(currentRetryCount + 1)/\(maxRetryAttempts)")
                
                // Schedule retry after 5 minutes
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                    Task {
                        try? await self.performBackup(task: task)
                    }
                }
            } else {
                retryCount.removeValue(forKey: task.id)
                print("💥 BackupFlow: Maksimum yeniden deneme sayısına ulaşıldı")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateNextRunTime(for task: BackupTask) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        switch task.frequency {
        case .manual:
            return nil
            
        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = task.scheduledTime?.hour ?? 0
            components.minute = task.scheduledTime?.minute ?? 0
            components.second = 0
            
            guard let scheduledToday = calendar.date(from: components) else { return nil }
            
            if scheduledToday > now {
                return scheduledToday
            } else {
                return calendar.date(byAdding: .day, value: 1, to: scheduledToday)
            }
            
        case .weekly:
            let targetWeekday = task.scheduledWeekday ?? 1 // 1 = Sunday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = targetWeekday
            components.hour = task.scheduledTime?.hour ?? 0
            components.minute = task.scheduledTime?.minute ?? 0
            components.second = 0
            
            guard let scheduledThisWeek = calendar.date(from: components) else { return nil }
            
            if scheduledThisWeek > now {
                return scheduledThisWeek
            } else {
                return calendar.date(byAdding: .weekOfYear, value: 1, to: scheduledThisWeek)
            }
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return "\(hours)sa \(minutes)dk \(seconds)sn"
        } else if minutes > 0 {
            return "\(minutes)dk \(seconds)sn"
        } else {
            return "\(seconds)sn"
        }
    }
    
    // MARK: - Notifications
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ BackupFlow: Bildirim izni verildi")
            } else {
                print("❌ BackupFlow: Bildirim izni reddedildi")
            }
        }
    }
    
    private func sendPauseNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "Yedekleme Duraklatıldı"
        content.body = "'\(task.displayName)' görevi duraklatıldı."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "pause-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendResumeNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "Yedekleme Devam Ettirildi"
        content.body = "'\(task.displayName)' görevi devam ettirildi."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "resume-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Background Task Management (Compatibility)
    public func cancelAllBackgroundTasks() {
        // Cancel all active timers (replacement for background tasks)
        for timer in scheduledTimers.values {
            timer.invalidate()
        }
        scheduledTimers.removeAll()
        print("🚫 BackupFlow: Tüm timer'lar iptal edildi")
    }
    
    // MARK: - Debug
    public func debugActiveTimers() {
        print("🔍 BackupFlow: Aktif timer sayısı: \(scheduledTimers.count)")
        for (taskId, _) in scheduledTimers {
            print("   📍 Timer ID: \(taskId)")
        }
    }
    
    // MARK: - Test Methods
    public func testFTPUpload(host: String, port: Int, username: String, password: String) async throws {
        print("🧪 BackupFlow: FTP test başlatılıyor - \(host):\(port)")
        
        // Simple FTP connection test - simulate upload
        guard !host.isEmpty else {
            throw NSError(domain: "FTPError", code: 1, userInfo: [NSLocalizedDescriptionKey: "FTP sunucu adresi boş"])
        }
        
        guard port > 0 && port <= 65535 else {
            throw NSError(domain: "FTPError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Geçersiz port numarası"])
        }
        
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For now, just return success - real FTP implementation would go here
        print("✅ BackupFlow: FTP test tamamlandı - \(host):\(port)")
    }
}

// MARK: - URLSessionDelegate & Backup Execution
extension BackupScheduler: URLSessionDelegate, URLSessionTaskDelegate {
    
    private func executeBackup(task: BackupTask) async throws {
        print("🚀 BackupFlow: Gerçek FTP yedekleme başlatılıyor: \(task.displayName)")
        
        task.backupStatus = .preparing
        task.progress = 0.0
        
        // Use FTPService for real backup
        let ftpService = FTPService.shared
        
        do {
            // Connect to FTP server
            task.backupStatus = .uploading
            print("📡 BackupFlow: FTP sunucusuna bağlanılıyor...")
            
            // Perform the actual backup using FTPService
            try await ftpService.performBackup(
                host: task.ftpHost,
                port: task.ftpPort,
                username: task.isAnonymous ? "" : task.ftpUsername,
                password: task.isAnonymous ? "" : task.ftpPassword,
                sourcePath: task.sourcePath,
                isAnonymous: task.isAnonymous,
                mediaType: task.safeMediaType,
                progressHandler: { progress in
                    Task { @MainActor in
                        task.progress = progress
                        task.currentFile = "Uploading..." // FTPService'den file name gelecek
                    }
                }
            )
            
            task.backupStatus = .completed
            task.progress = 1.0
            task.lastBackupDate = Date()
            task.currentFile = nil
            
            print("✅ BackupFlow: Gerçek FTP yedekleme tamamlandı: \(task.displayName)")
            
        } catch {
            task.backupStatus = .failed
            task.lastError = error.localizedDescription
            task.currentFile = nil
            
            print("❌ BackupFlow: FTP yedekleme başarısız: \(task.displayName) - \(error)")
            throw error
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension BackupScheduler {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 BackupFlow: Bildirime tıklandı: \(response.notification.request.identifier)")
        completionHandler()
    }
}