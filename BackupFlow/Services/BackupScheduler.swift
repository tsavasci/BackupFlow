import Foundation
import OSLog
import SwiftUI
import UIKit
import SwiftData
import Combine
import UserNotifications
import UniformTypeIdentifiers
import Photos
import AVFoundation
import BackgroundTasks

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
    private var lastNotificationSentAt: [UUID: Date] = [:]
    private var lastScheduledTargetTime: [UUID: Date] = [:]
    
    @Published private(set) var isProcessing = false
    
    // MARK: - Initialization
    override init() {
        let b = Bundle.main.bundleIdentifier ?? "com.backupflow.app"
        self.appGroupID = "group." + b
        self.backgroundSessionIdentifier = b + ".background"
        super.init()
        setupNotifications()
        print("🔄 BackupFlow: BackupScheduler init tamamlandı (BGTask + Timer hibrit)")
    }
    
    // MARK: - Public Interface
    public func scheduleAllTasks() {
        Task {
            await performScheduling()
        }
    }

    /// Daha uzun ve ağ bağlantısı gerektiren işler için BGProcessing görevi planlar.
    public func scheduleProcessingTask() {
        let identifier = (Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow") + ".processing"

        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true // Şarja takılıyken daha güvenilir (uzun işlemler için tercih)

        // earliestBeginDate'i, en yakın nextRunTime'a göre ayarla (en az 15 dk kuralına uyarak)
        if let container = Self.sharedModelContainer {
            let context = ModelContext(container)
            if let tasks = try? context.fetch(FetchDescriptor<BackupTask>()) {
                if let earliest = tasks.compactMap({ $0.nextRunTime }).sorted().first {
                    let now = Date()
                    var candidate = earliest < now ? now.addingTimeInterval(300) : earliest
                    let minimumLead: TimeInterval = 15 * 60
                    if candidate.timeIntervalSince(now) < minimumLead {
                        candidate = now.addingTimeInterval(minimumLead)
                        print("ℹ️ BGTaskScheduler: Processing earliest çok yakın, 15 dk'ya yuvarlandı -> \(userLocalDateFormatter.string(from: candidate))")
                    }
                    request.earliestBeginDate = candidate
                }
            }
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            if let d = request.earliestBeginDate {
                print("✅ BGTaskScheduler: Processing görevi planlandı -> \(userLocalDateFormatter.string(from: d))")
            } else {
                print("✅ BGTaskScheduler: Processing görevi planlandı (tarih yok)")
            }
        } catch {
            let nsError = error as NSError
            var reason = "bilinmeyen"
            if nsError.domain == "BGTaskSchedulerErrorDomain" {
                switch nsError.code {
                case 1: reason = "notPermitted (Background Modes veya identifier)"
                case 2: reason = "tooManyPendingTaskRequests"
                case 3: reason = "noSuchTaskRequest (identifier yanlış?)"
                default: break
                }
            }
            print("❌ BGTaskScheduler: Processing planlanamadı (code=\(nsError.code) reason=\(reason)): \(error)")
        }
    }
    
    public func pauseTask(_ task: BackupTask) {
        cancelTimer(for: task.id)
        task.isPaused = true
        print("⏸️ BackupFlow: Görev duraklatıldı: \(task.displayName)")
        // Kullanıcı bildirimi gönderme (gürültüyü azaltmak için kaldırıldı)

        // Ayrıca bekleyen zamanlanmış bildirimleri iptal et (çift bildirimi önlemek için)
        let pendingId = "scheduled-backup-\(task.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pendingId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [pendingId])
        lastNotificationSentAt[task.id] = nil
        lastScheduledTargetTime[task.id] = nil
    }
    
    public func resumeTask(_ task: BackupTask) {
        task.isPaused = false
        print("▶️ BackupFlow: Görev devam ettirildi: \(task.displayName)")
        
        // Reschedule the task (bildirim gönderimi yok)
        Task {
            await scheduleTask(task)
        }
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
        
        // Calculate next run time (prospective)
        guard let nextRunTime = calculateNextRunTime(for: task) else {
            print("❌ BackupFlow: Sonraki çalışma zamanı hesaplanamadı: \(task.displayName)")
            return
        }
        // Eğer aynı hedef zaman için zaten aktif bir timer varsa, tekrar planlama
        if let last = lastScheduledTargetTime[task.id], abs(last.timeIntervalSince(nextRunTime)) < 1, scheduledTimers[task.id] != nil {
            print("ℹ️ BackupFlow: Zaten aynı hedef zamana planlanmış, tekrar planlanmıyor: \(task.displayName)")
            return
        }

        // Cancel existing timer for this task
        cancelTimer(for: task.id)

        // Var ise bekleyen/delivered zamanlanmış bildirimleri temizle (önceki planlamadan kalmış olabilir)
        let pendingId = "scheduled-backup-\(task.id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [pendingId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [pendingId])
        
        // Update task's next run time
        task.nextRunTime = nextRunTime
        lastScheduledTargetTime[task.id] = nextRunTime
        
        // Schedule timer
        let now = Date()
        let timeInterval = nextRunTime.timeIntervalSince(now)
        
        // Grace period: 30 saniyeye kadar gecikme kabul et (notification delay için)
        if timeInterval <= 30 { // 30 saniye veya daha az varsa hemen çalıştır
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
                
                // Find the task by ID
                guard let container = Self.sharedModelContainer else { return }
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<BackupTask>()
                if let foundTask = try? context.fetch(descriptor).first(where: { $0.id == taskId }) {
                    // Uygulama ön plandaysa direkt başlat
                    if UIApplication.shared.applicationState == .active {
                        print("📱 BackupFlow: Uygulama aktif - Yedekleme direkt başlatılıyor")
                        try? await self?.performBackup(task: foundTask)
                    } else {
                        // Arka plandaysa: yalnızca MANUEL görevler için bildirim gönder
                        if foundTask.frequency == .manual {
                            print("🔔 BackupFlow: Uygulama arka planda - Bildirim gönderiliyor (manuel görev)")
                            self?.sendScheduledBackupNotification(for: foundTask)
                        } else {
                            print("ℹ️ BackupFlow: Arka planda bildirim atlandı (otomatik görev)")
                        }
                    }
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
    
    /// Zamanı gelen görev için bildirim gönderir (action button ile)
    public func sendScheduledBackupNotification(for task: BackupTask) {
        // Son bildirimin üzerinden yeterli süre geçmediyse tekrarlama (debounce)
        if let last = lastNotificationSentAt[task.id], Date().timeIntervalSince(last) < 60 {
            print("ℹ️ BackupFlow: Yakın zamanda aynı görev için bildirim gönderilmiş, tekrar edilmiyor")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "🕐 Yedekleme Zamanı!"
        content.body = "'\(task.displayName)' görevi çalıştırılmaya hazır."
        content.sound = .default
        content.badge = 1
        
        // Action button ekle
        let startAction = UNNotificationAction(
            identifier: "START_BACKUP_\(task.id)",
            title: "Yedeklemeyi Başlat",
            options: [.foreground]  // Uygulamayı açar
        )
        
        let cancelAction = UNNotificationAction(
            identifier: "CANCEL_BACKUP_\(task.id)",
            title: "İptal",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "SCHEDULED_BACKUP",
            actions: [startAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Category'yi register et
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "SCHEDULED_BACKUP"
        
        // Hemen gönder: önce aynı kimlikli pending ve delivered bildirimleri temizle
        let request = UNNotificationRequest(
            identifier: "scheduled-backup-\(task.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [request.identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
        UNUserNotificationCenter.current().add(request)
        print("🔔 BackupFlow: Zamanlanmış yedekleme bildirimi gönderildi: \(task.displayName)")
        lastNotificationSentAt[task.id] = Date()
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

    // MARK: - BGTaskScheduler Integration
    /// iOS arka plan yenileme görevi planlar.
    public func scheduleAppRefresh() {
        let identifier = (Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow") + ".backupTask"

        // En erken tarih hesapla
        let earliestDate: Date? = {
            guard let container = Self.sharedModelContainer else { return nil }
            let context = ModelContext(container)
            if let tasks = try? context.fetch(FetchDescriptor<BackupTask>()) {
                return tasks
                    .compactMap { $0.nextRunTime }
                    .sorted().first
            }
            return nil
        }()

        let request = BGAppRefreshTaskRequest(identifier: identifier)
        if let earliestDate = earliestDate {
            let now = Date()
            // Eğer earliestDate geçmişse 5 dk ileri al
            var candidate = earliestDate < now ? now.addingTimeInterval(300) : earliestDate
            // Apple genelde çok kısa aralıkları çalıştırmıyor; en az 15 dk kuralı (debug kolaylığı için)
            let minimumLead: TimeInterval = 15 * 60
            if candidate.timeIntervalSince(now) < minimumLead {
                candidate = now.addingTimeInterval(minimumLead)
                print("ℹ️ BGTaskScheduler: Earliest çok yakın, 15 dk'ya yuvarlandı -> \(userLocalDateFormatter.string(from: candidate))")
            }
            request.earliestBeginDate = candidate
        } else {
            // Hiç görev yoksa 1 saat sonrası
            request.earliestBeginDate = Date().addingTimeInterval(3600)
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            if let d = request.earliestBeginDate {
                print("✅ BGTaskScheduler: App refresh görevi planlandı -> \(userLocalDateFormatter.string(from: d))")
            } else {
                print("✅ BGTaskScheduler: App refresh görevi planlandı (tarih yok)")
            }
        } catch {
            let nsError = error as NSError
            var reason = "bilinmeyen"
            if nsError.domain == "BGTaskSchedulerErrorDomain" {
                switch nsError.code {
                case 1: reason = "notPermitted (Background Modes veya identifier)"
                case 2: reason = "tooManyPendingTaskRequests"
                case 3: reason = "noSuchTaskRequest (identifier yanlış?)"
                default: break
                }
            }
            print("❌ BGTaskScheduler: Görev planlanamadı (code=\(nsError.code) reason=\(reason)): \(error)")
            print("⛑ Fallback: Foreground timer'lar çalışmaya devam edecek.")
        }
    }

    /// Arka plan görevi tetiklendiğinde çağrılır.
    public func executeBackgroundTask() async -> Bool {
        // Re-entrancy guard: allow only one background execution at a time
        if isProcessing {
            print("ℹ️ BGTaskScheduler: Zaten bir işlem sürüyor, yeni görev atlandı")
            return false
        }
        isProcessing = true
        defer { isProcessing = false }

        guard let container = Self.sharedModelContainer else {
            print("❌ BGTaskScheduler: ModelContainer yok")
            return false
        }
        let context = ModelContext(container)
        let now = Date()
        let descriptor = FetchDescriptor<BackupTask>()
        guard let tasks = try? context.fetch(descriptor), !tasks.isEmpty else {
            print("ℹ️ BGTaskScheduler: Çalışacak görev yok")
            return true
        }
        let dueTasks = tasks.filter { task in
            guard !task.isPaused, task.isEnabled, task.frequency != .manual else { return false }
            if let next = task.nextRunTime { return next <= now }
            return false
        }
        if dueTasks.isEmpty {
            print("⏱️ BGTaskScheduler: Zamanı gelen görev yok, yeniden planlanıyor")
            scheduleAppRefresh()
            return true
        }
        print("🚀 BGTaskScheduler: \(dueTasks.count) görev arka planda yürütülecek")
        var anySuccess = false
        for task in dueTasks {
            do {
                try await performBackup(task: task)
                anySuccess = true
            } catch {
                print("⚠️ BGTaskScheduler: Görev başarısız -> \(task.displayName) - \(error)")
            }
        }
        scheduleAppRefresh()
        return anySuccess
    }
}

// MARK: - URLSessionDelegate & Backup Execution
extension BackupScheduler: URLSessionDelegate, URLSessionTaskDelegate {
    
    private func executeBackup(task: BackupTask) async throws {
        print("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName) - \(task.backupType.rawValue)")
        
        task.backupStatus = .preparing
        task.progress = 0.0
        let startTime = Date()
        
        do {
            switch task.backupType {
            case .ftp:
                try await executeFTPBackup(task: task, startTime: startTime)
            case .webdav:
                try await executeWebDAVBackup(task: task, startTime: startTime)
            }
            
            task.backupStatus = .completed
            task.progress = 1.0
            task.lastBackupDate = Date()
            task.currentFile = nil
            
            // Calculate next run time to prevent immediate re-execution
            task.nextRunTime = calculateNextRunTime(for: task)
            
            print("✅ BackupFlow: Yedekleme tamamlandı: \(task.displayName) - \(task.backupType.rawValue)")
            if let next = task.nextRunTime {
                print("⏰ BackupFlow: Sonraki çalışma zamanı: \(userLocalDateFormatter.string(from: next))")
            } else {
                print("⏰ BackupFlow: Sonraki çalışma zamanı: (manuel görev - zamanlanmadı)")
            }
        } catch {
            task.backupStatus = .failed
            task.lastBackupDate = Date()
            task.currentFile = nil
            
            // Create error history record
            let duration = Date().timeIntervalSince(startTime)
            await createBackupHistoryRecord(
                task: task,
                syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: duration,
                status: "failed"
            )
            
            throw error
        }
    }
    
    private func executeFTPBackup(task: BackupTask, startTime: Date) async throws {
        print("📡 BackupFlow: FTP yedekleme başlatılıyor...")
        task.backupStatus = .uploading
        
        let ftpService = FTPService.shared
        
        // Perform the actual backup using FTPService
        let syncResult = try await ftpService.performBackup(
            host: task.serverHost,
            port: task.serverPort,
            username: task.isAnonymous ? "" : task.serverUsername,
            password: task.isAnonymous ? "" : task.serverPassword,
            sourcePath: task.sourcePath,
            isAnonymous: task.isAnonymous,
            mediaType: task.mediaType,
            progressHandler: { progress in
                Task { @MainActor in
                    task.progress = progress
                    task.currentFile = "Uploading..."
                }
            }
        )
        
        // Create backup history record
        let duration = Date().timeIntervalSince(startTime)
        await createBackupHistoryRecord(
            task: task,
            syncResult: syncResult,
            duration: duration,
            status: "completed"
        )
        
        // Send detailed notification with sync results
        await sendBackupCompletionNotification(task: task, syncResult: syncResult)
    }
    
    private func executeWebDAVBackup(task: BackupTask, startTime: Date) async throws {
        print("🌐 BackupFlow: WebDAV yedekleme başlatılıyor...")
        task.backupStatus = .uploading
        
        do {
            // Get WebDAV service instance
            let webDAVService = WebDAVService.shared
            
            // Update UI with connection status
            task.currentFile = "WebDAV sunucusuna bağlanılıyor..."
            
            // Configure WebDAV connection parameters
            let username = task.serverUsername.isEmpty ? nil : task.serverUsername
            let password = task.serverPassword.isEmpty ? nil : task.serverPassword
            
            // Convert host to proper format if needed
            var host = task.serverHost
            if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
                host = "https://" + host
            }
            
            // Extract host and port from URL
            guard let url = URL(string: host) else {
                throw NSError(domain: "WebDAV Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geçersiz WebDAV sunucu adresi"])
            }
            
            let hostName = url.host ?? task.serverHost
            let port = url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
            
            // Update UI with connection status
            task.currentFile = "WebDAV sunucusuna bağlanılıyor: \(hostName)"
            
            // Connect to WebDAV server
            try await webDAVService.connect(
                host: hostName,
                port: port,
                username: username,
                password: password
            )
            
            // Update UI with backup status
            task.currentFile = "Yedekleme hazırlanıyor..."
            
            // Determine source path
            let sourcePath = task.sourcePath == "PHOTOS_LIBRARY" ? "PHOTOS_LIBRARY" : task.sourcePath
            
            // Start backup
            let syncResult = try await webDAVService.performBackup(
                host: hostName,
                port: port,
                username: username,
                password: password,
                sourcePath: sourcePath,
                isAnonymous: username == nil,
                mediaType: task.mediaType,
                progressHandler: { progress in
                    // Update progress on main actor
                    Task { @MainActor in
                        task.progress = progress
                        task.currentFile = webDAVService.currentFile
                    }
                }
            )
            
            // Update task status
            task.backupStatus = .completed
            task.lastBackupDate = Date()
            task.progress = 1.0
            task.currentFile = "Yedekleme tamamlandı"
            
            // Calculate next run time
            task.nextRunTime = calculateNextRunTime(for: task)
            
            // Create backup history record
            let duration = Date().timeIntervalSince(startTime)
            await createBackupHistoryRecord(
                task: task,
                syncResult: syncResult,
                duration: duration,
                status: "completed"
            )
            
            // Send detailed notification with sync results
            await sendBackupCompletionNotification(task: task, syncResult: syncResult)
            
            // Clear badge after successful backup
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                print("❌ BackupFlow: Badge temizleme hatası: \(error)")
            }
            
        } catch {
            task.backupStatus = .failed
            task.progress = 0.0
            task.currentFile = "Hata: \(error.localizedDescription)"
            
            // Create backup history record for failure
            let duration = Date().timeIntervalSince(startTime)
            await createBackupHistoryRecord(
                task: task,
syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: duration,
                status: "failed",
                errorMessage: error.localizedDescription
            )
            
            print("❌ BackupFlow: WebDAV yedekleme hatası: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Detaylı yedekleme tamamlanma bildirimi gönder
    private func sendBackupCompletionNotification(task: BackupTask, syncResult: FTPService.SyncResult) async {
        guard await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Yedekleme Tamamlandı"
        content.body = """
        \(task.displayName) yedekleme işlemi tamamlandı!
        
        📊 Yedekleme Raporu:
        📤 \(syncResult.newFiles) yeni dosya kopyalandı
        🔄 \(syncResult.updatedFiles) dosya güncellendi  
        ⏭ \(syncResult.skippedFiles) aynı dosya pas geçildi
        🗑 \(syncResult.deletedFiles) dosya silindi
        
        Toplam işlenen: \(syncResult.totalProcessed) dosya
        """
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "backup_completed_\(task.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 BackupFlow: Detaylı yedekleme bildirimi gönderildi")
        } catch {
            print("❌ BackupFlow: Bildirim gönderme hatası: \(error)")
        }
    }
    
    /// Backup history record oluştur
    private func createBackupHistoryRecord(
        task: BackupTask,
        syncResult: FTPService.SyncResult,
        duration: TimeInterval,
        status: String,
        errorMessage: String? = nil
    ) async {
        guard let container = Self.sharedModelContainer else { return }

        // Prefer the task's own ModelContext to avoid cross-context attachment
        if let taskContext = task.modelContext {
            let context = taskContext

            // Build history in the SAME context as task
            let historyRecord = BackupHistory(
                id: UUID(),
                timestamp: Date(),
                status: status,
                filesProcessed: syncResult.totalProcessed,
                totalFiles: syncResult.totalProcessed,
                bytesTransferred: syncResult.totalBytes,
                totalBytes: syncResult.totalBytes,
                errorMessage: errorMessage,
                duration: duration,
                skippedFiles: syncResult.skippedFiles,
                deletedFiles: syncResult.deletedFiles
            )

            // Attach the task to the history record
            historyRecord.task = task

            do {
                // In many cases, appending to a relationship is enough; insert is optional
                try context.save()
                print("📝 BackupFlow: Geçmiş kaydı eklendi - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
            } catch {
                print("❌ BackupFlow: Geçmiş kaydı hatası (taskContext): \(error)")
            }
            return
        }

        // Fallback: no task.modelContext (edge case). Use a new context and refetch task in that context.
        let context = ModelContext(container)
        do {
            let fetch = FetchDescriptor<BackupTask>()
            guard let taskInContext = try context.fetch(fetch).first(where: { $0.id == task.id }) else {
                print("❌ BackupFlow: Geçmiş kaydı için görev bulunamadı (refetch failed)")
                return
            }

            let historyRecord = BackupHistory(
                id: UUID(),
                timestamp: Date(),
                status: status,
                filesProcessed: syncResult.totalProcessed,
                totalFiles: syncResult.totalProcessed,
                bytesTransferred: syncResult.totalBytes,
                totalBytes: syncResult.totalBytes,
                errorMessage: errorMessage,
                duration: duration,
                skippedFiles: syncResult.skippedFiles,
                deletedFiles: syncResult.deletedFiles
            )

            historyRecord.task = taskInContext

            try context.save()
            print("📝 BackupFlow: Geçmiş kaydı eklendi (refetched) - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
        } catch {
            print("❌ BackupFlow: Geçmiş kaydı hatası (refetch): \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension BackupScheduler {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        print("🔔 BackupFlow: Bildirime tıklandı - ID: \(identifier), Action: \(actionIdentifier)")
        
        // Bildirim okunduğunda badge'i temizle
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
                print("🔔 BackupFlow: Bildirim badge temizlendi")
            } catch {
                print("❌ BackupFlow: Badge temizleme hatası: \(error)")
            }
        }
        
        // Action'a göre işlem yap
        if actionIdentifier.hasPrefix("START_BACKUP_") {
            // Task ID'yi çıkar
            let taskIdString = String(actionIdentifier.dropFirst("START_BACKUP_".count))
            if let taskId = UUID(uuidString: taskIdString) {
                print("📱 BackupFlow: Yedekleme başlatma talebi - Task ID: \(taskId.uuidString)")
                
                // Global state'e yedekleme talebi kaydet
                UserDefaults.standard.set(taskId.uuidString, forKey: "pendingBackupTaskId")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pendingBackupTimestamp")
                
                // App açıldığında bu task otomatik başlatılacak
            }
        } else if actionIdentifier.hasPrefix("CANCEL_BACKUP_") {
            print("❌ BackupFlow: Kullanıcı yedeklemeyi iptal etti")
            // İsteğe bağlı: İptal bildirimi gönder
        }
        
        completionHandler()
    }
    
    /// App icon badge'ini temizler
    @MainActor
    public func clearAppBadge() async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(0)
            print("🔔 BackupFlow: App badge manuel olarak temizlendi")
        } catch {
            print("❌ BackupFlow: Badge temizleme hatası: \(error)")
        }
    }
}