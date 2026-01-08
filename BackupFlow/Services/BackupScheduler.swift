#if os(iOS)

import AVFoundation
import BackgroundTasks
import Combine
import Foundation
import Network
import Photos
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// The type of network connection.
enum NetworkType {
    case wifi
    case cellular
    case ethernet
    case unknown

    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Hücresel"
        case .ethernet: return "Ethernet"
        case .unknown: return "Bilinmeyen"
        }
    }
}

/// A thread-safe, sendable class to manage a `CheckedContinuation`.
/// This ensures that the continuation is resumed exactly once.
private final class ResumptionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NetworkType, Never>?

    init(_ continuation: CheckedContinuation<NetworkType, Never>) {
        self.continuation = continuation
    }

    /// Attempts to resume the continuation.
    /// - Parameter type: The `NetworkType` to resume with.
    /// - Returns: `true` if the continuation was resumed, `false` otherwise.
    func resume(with type: NetworkType) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let c = continuation {
            continuation = nil
            c.resume(returning: type)
            return true
        }
        return false
    }
}


@MainActor
final class BackupScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    
    // MARK: - Singleton & Properties
    static let shared = BackupScheduler()
    
    // Shared ModelContainer - uygulamadan inject edilecek
    static var sharedModelContainer: ModelContainer?
    
    private var retryCount: [UUID: Int] = [:]
    
    private var lastNotificationSentAt: [UUID: Date] = [:]
    private var lastScheduledTargetTime: [UUID: Date] = [:]
    
    private var lastRunAt: Date? = nil
    private let minRunInterval: TimeInterval = 60 // en az 60 sn arayla çalıştır
    
    @Published private(set) var isProcessing = false
    
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
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotifications()
        print("🔄 BackupFlow: BackupScheduler init tamamlandı (BGTask + Timer hibrit)")
        
        // Debug: Veritabanındaki tüm görevleri listele
        if let container = Self.sharedModelContainer {
            let context = ModelContext(container)
            if let tasks = try? context.fetch(FetchDescriptor<BackupTask>()) {
                print("📋 BackupFlow: Veritabanında \(tasks.count) görev bulundu:")
                for (index, task) in tasks.enumerated() {
                    let statusText = task.isEnabled ? (task.isPaused ? "⏸️ Duraklatılmış" : "✅ Aktif") : "❌ Devre dışı"
                    let freqText: String = {
                        switch task.frequency {
                        case .manual: return "Manuel"
                        case .daily(let time): return "Günlük (\(time.timeString))"
                        case .weekly(let day, let time):
                            let dayName = ["Pzr", "Pzt", "Sal", "Çrş", "Prş", "Cum", "Cts"][day - 1]
                            return "Haftalık (\(dayName) \(time.timeString))"
                        }
                    }()
                    let nextRunText = task.nextRunTime.map { userLocalDateFormatter.string(from: $0) } ?? "Belirlenmedi"
                    print("   \(index + 1). \(task.displayName)")
                    print("      - Tür: \(task.backupType.displayName)")
                    print("      - Durum: \(statusText)")
                    print("      - Sıklık: \(freqText)")
                    print("      - Sonraki çalışma: \(nextRunText)")
                }
            }
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
        if case .manual = task.frequency {
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
        let stateText: String = {
            #if canImport(UIKit)
            switch UIApplication.shared.applicationState {
            case .active: return "active"
            case .background: return "background"
            case .inactive: return "inactive"
            @unknown default: return "unknown"
            }
            #else
            return "active"
            #endif
        }()
        print("   📱 Mevcut app state: \(stateText)")
        print("   📅 Sonraki çalışma: \(userLocalDateFormatter.string(from: nextRunTime))")
        print("   ⏳ Kalan süre: \(formatTimeInterval(timeInterval))")
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self, taskId = task.id] _ in
            print("⏰ BackupFlow: Timer tetiklendi! Task ID: \(taskId)")
            Task { @MainActor in
                print("📱 BackupFlow: Timer callback MainActor'da çalışıyor")
                self?.scheduledTimers.removeValue(forKey: taskId)
                
                // Find the task by ID
                guard let container = Self.sharedModelContainer else { 
                    print("❌ BackupFlow: ModelContainer bulunamadı!")
                    return 
                }
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<BackupTask>()
                if let foundTask = try? context.fetch(descriptor).first(where: { $0.id == taskId }) {
                    print("✅ BackupFlow: Timer'da görev bulundu: \(foundTask.displayName)")
                    // App state'ini tekrar kontrol et (arka plana geçmiş olabilir)
                    let (isActive, stateText2): (Bool, String) = {
                        #if canImport(UIKit)
                        let s = UIApplication.shared.applicationState
                        let txt: String = {
                            switch s {
                            case .active: return "active"
                            case .background: return "background"
                            case .inactive: return "inactive"
                            @unknown default: return "unknown"
                            }
                        }()
                        return (s == .active, txt)
                        #else
                        return (true, "active")
                        #endif
                    }()
                    print("📲 BackupFlow: Mevcut app state: \(stateText2)")
                    if isActive {
                        print("📱 BackupFlow: Uygulama aktif - Yedekleme direkt başlatılıyor")
                        try? await self?.performBackup(task: foundTask)
                    } else {
                        print("🔔 BackupFlow: Uygulama arka planda (state: \(stateText2)) - Bildirim gönderiliyor")
                        self?.sendScheduledBackupNotification(for: foundTask)
                    }
                } else {
                    print("❌ BackupFlow: Timer'da görev bulunamadı! Task ID: \(taskId)")
                }
            }
        }
        
        scheduledTimers[task.id] = timer
        
        // Timer'ın background'da çalışması için RunLoop'a ekle
        RunLoop.main.add(timer, forMode: .common)
        print("✅ BackupFlow: Timer RunLoop'a eklendi (common mode)")
    }
    
    @MainActor
    private func cancelTimer(for taskId: UUID) {
        if let timer = scheduledTimers[taskId] {
            timer.invalidate()
            scheduledTimers.removeValue(forKey: taskId)
            print("🚫 BackupFlow: Timer iptal edildi: \(taskId)")
        }
    }
    
    // MARK: - Backup Execution
    public func performBackup(task: BackupTask) async throws {
        // Re-entrancy guard: Çok sık tetiklemeyi engelle
        if let last = lastRunAt, Date().timeIntervalSince(last) < minRunInterval {
            print("ℹ️ BackupFlow: Son çalıştırmadan bu yana minimum süre dolmadı, tetikleme atlandı")
            return
        }
        lastRunAt = Date()
        
        guard !task.isPaused else {
            print("⏸️ BackupFlow: Görev duraklatılmış, yedekleme atlanıyor: \(task.displayName)")
            return
        }
        
        // Set processing flag to prevent interruption
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // Clear processing flag when done
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        print("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName)")
        
        // Update task status with safe initial progress
        task.backupStatus = .preparing
        task.progress = 0.0  // Start at 0.0, safe value
        task.lastError = nil
        
        do {
            let syncResult: FTPService.SyncResult
            // Perform the actual backup
            switch task.backupType {
            case .ftp:
                syncResult = try await executeFTPBackup(task: task, startTime: Date())
            case .webdav:
                syncResult = try await executeWebDAVBackup(task: task, startTime: Date())
            }
            
            // Update task on success with safe progress
            task.backupStatus = .completed
            task.progress = 1.0  // Success is always 1.0, safe value
            task.lastBackupDate = Date()
            task.currentFile = nil
            
            // Schedule next run
            task.nextRunTime = calculateNextRunTime(for: task)
            
            // Create backup history record
            let duration = Date().timeIntervalSince(lastRunAt ?? Date())
            await createBackupHistoryRecord(
                task: task,
                syncResult: syncResult,
                duration: duration,
                status: "completed"
            )
            
            // Send detailed notification with sync results
            await sendBackupCompletionNotification(task: task, syncResult: syncResult)

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
            
            // Create backup history record for failure
            let duration = Date().timeIntervalSince(lastRunAt ?? Date())
            await createBackupHistoryRecord(
                task: task,
                syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: duration,
                status: "failed",
                errorMessage: error.localizedDescription
            )
        }
    }
    
    // MARK: - Helper Methods
    private func calculateNextRunTime(for task: BackupTask) -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        switch task.frequency {
        case .manual:
            return nil
            
        case .daily(let time):
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0
            
            guard let scheduledToday = calendar.date(from: components) else { return nil }
            
            if scheduledToday > now {
                return scheduledToday
            } else {
                return calendar.date(byAdding: .day, value: 1, to: scheduledToday)
            }
            
        case .weekly(let day, let time):
            let targetWeekday = day // 1 = Sunday
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = targetWeekday
            components.hour = time.hour
            components.minute = time.minute
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
        // Delegate sadece burada atanır. İzin isteği AppDelegate tarafından yönetilir.
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Zamanı gelen görev için bildirim gönderir (action button ile)
    public func sendScheduledBackupNotification(for task: BackupTask) {
        // Son bildirimin üzerinden yeterli süre geçmediyse tekrarlama (debounce)
        if let last = lastNotificationSentAt[task.id], Date().timeIntervalSince(last) < 60 {
            print("ℹ️ BackupFlow: Yakın zamanda aynı görev için bildirim gönderilmiş, tekrar edilmiyor")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "backup.scheduled.notification.title".localized
        
        // Görev türüne göre mesajı özelleştir
        let frequencyText: String
        switch task.frequency {
        case .manual:
            frequencyText = "backup.frequency_text.manual".localized
        case .daily:
            frequencyText = "backup.frequency_text.daily".localized
        case .weekly:
            frequencyText = "backup.frequency_text.weekly".localized
        }
        
        // Base body
        var bodyMessage = String(format: "backup.scheduled.notification.body".localized, task.displayName, frequencyText)

        // Local server warning addendum (existing localized strings already include leading newlines)
        if isLocalServer(host: task.serverHost) {
            if task.allowCellularForLocalServer {
                bodyMessage += "backup.scheduled.notification.local_cellular".localized
            } else {
                bodyMessage += "backup.scheduled.notification.local_wifi".localized
            }
        }
        
        content.body = bodyMessage
        content.sound = .default
        content.badge = 1
        
        // Kategori zaten AppDelegate'te kaydedildi, sadece identifier'ı ayarla
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
        print("🔔 BackupFlow: Zamanlanmış yedekleme bildirimi gönderildi: \(task.displayName) (\(frequencyText))")
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
    
    /// Missed timer kontrolü - BGTask tarafından çağrılır
    public func checkMissedTimers() async {
        guard let container = Self.sharedModelContainer else {
            print("❌ checkMissedTimers: ModelContainer yok")
            return
        }
        
        let context = ModelContext(container)
        let now = Date()
        let descriptor = FetchDescriptor<BackupTask>()
        
        guard let tasks = try? context.fetch(descriptor) else {
            print("❌ checkMissedTimers: Görevler yüklenemedi")
            return
        }
        
        print("🔍 checkMissedTimers: \(tasks.count) görev kontrol ediliyor")
        
        for task in tasks {
            guard !task.isPaused, task.isEnabled else { continue }
            if case .manual = task.frequency { continue }
            
            if let nextRunTime = task.nextRunTime {
                let timeDiff = now.timeIntervalSince(nextRunTime)
                
                // Timer 2+ dakika geç kalmışsa manuel tetikle
                if timeDiff > 120 { // 2 dakika
                    print("⚠️ checkMissedTimers: Kaçırılmış görev tespit edildi: \(task.displayName)")
                    print("   📅 Planlanmış: \(userLocalDateFormatter.string(from: nextRunTime))")
                    print("   📅 Şu anda: \(userLocalDateFormatter.string(from: now))")
                    print("   ⏰ Gecikme: \(String(format: "%.1f", timeDiff)) saniye")
                    
                    // App state kontrol et
                    let isActive: Bool = {
                        #if canImport(UIKit)
                        return UIApplication.shared.applicationState == .active
                        #else
                        return true
                        #endif
                    }()
                    if isActive {
                        print("📱 checkMissedTimers: App aktif - Yedekleme başlatılıyor")
                        try? await performBackup(task: task)
                    } else {
                        print("🔔 checkMissedTimers: App arka planda - Bildirim gönderiliyor")
                        sendScheduledBackupNotification(for: task)
                    }
                }
            }
        }
    }

    /// Arka plan görevi tetiklendiğinde çağrılır.
    public func executeBackgroundTask() async -> Bool {
        // Re-entrancy guard: allow only one background execution at a time
        if isProcessing {
            print("ℹ️ BGTaskScheduler: Zaten bir işlem sürüyor, yeni görev atlandı")
            return false
        }
        
        // İşlem başladığını işaretle
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            // İşlem bittiğinde işareti temizle
            Task { @MainActor in
                isProcessing = false
            }
        }

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
            guard !task.isPaused, task.isEnabled else { return false }
            // Exclude manual tasks
            if case .manual = task.frequency { return false }
            if let next = task.nextRunTime { return next <= now }
            return false
        }
        if dueTasks.isEmpty {
            print("⏱️ BGTaskScheduler: Zamanı gelen görev yok, yeniden planlanıyor")
            scheduleAppRefresh()
            return true
        }
        
        print("🚀 BGTaskScheduler: \(dueTasks.count) görev arka planda yürütülecek")
        
        // Arka plan modunda hızlı işlem için sadece ilk görevi çalıştır
        let taskToRun = dueTasks.first!
        print("📱 BGTaskScheduler: Arka plan optimizasyonu - sadece 1 görev: \(taskToRun.displayName)")
        
        var anySuccess = false
        do {
            try await performBackup(task: taskToRun)
            anySuccess = true
            print("✅ BGTaskScheduler: Arka plan görevi başarıyla tamamlandı: \(taskToRun.displayName)")
        } catch {
            print("⚠️ BGTaskScheduler: Arka plan görevi başarısız -> \(taskToRun.displayName) - \(error)")
        }
        
        scheduleAppRefresh()
        return anySuccess
    }
}

// MARK: - Backup Execution
extension BackupScheduler {
    
    private func executeBackup(task: BackupTask) async throws -> FTPService.SyncResult {
        print("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName) - \(task.backupType.rawValue)")
        
        // Network türü kontrolü - local server için WiFi gerekli (ayar kontrollü)
        if isLocalServer(host: task.serverHost) && !task.allowCellularForLocalServer {
            let networkType = await getCurrentNetworkType()
            if networkType != .wifi {
                let errorMessage = "Local sunucu erişimi için WiFi bağlantısı gerekli (Şu anda: \(networkType.description)). Ayarlardan hücresel veri kullanımını aktifleştirebilirsiniz."
                print("❌ BackupFlow: \(errorMessage)")
                throw NSError(domain: "NetworkError", code: -1000, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            print("✅ BackupFlow: WiFi bağlantısı tespit edildi, local server erişimi uygun")
        } else if isLocalServer(host: task.serverHost) && task.allowCellularForLocalServer {
            let networkType = await getCurrentNetworkType()
            print("⚠️ BackupFlow: Local server için hücresel veri kullanımına izin verildi (Şu anda: \(networkType.description))")
        }
        
        task.backupStatus = .preparing
        task.progress = 0.0
        let startTime = Date()
        
        do {
            let syncResult: FTPService.SyncResult
            switch task.backupType {
            case .ftp:
                syncResult = try await executeFTPBackup(task: task, startTime: startTime)
            case .webdav:
                syncResult = try await executeWebDAVBackup(task: task, startTime: startTime)
            }
            return syncResult
        } catch {
            task.backupStatus = .failed
            task.lastBackupDate = Date()
            task.currentFile = nil
            
            throw error
        }
    }
    
    private func executeFTPBackup(task: BackupTask, startTime: Date) async throws -> FTPService.SyncResult {
        print("📡 BackupFlow: FTP yedekleme başlatılıyor...")
        task.backupStatus = .uploading
        
        let ftpService = FTPService.shared
        
        // Perform the actual backup using FTPService
        let syncResult = try await ftpService.performBackup(
            host: task.serverHost,
            port: task.serverPort,
            username: task.isAnonymous ? "" : task.serverUsername,
            password: task.isAnonymous ? "" : task.serverPassword,
            sourcePath: task.sourcePath ?? "",
            isAnonymous: task.isAnonymous,
            mediaType: task.mediaType,
            progressHandler: { progress in
                Task { @MainActor in
                    // NaN kontrolü ile güvenli progress update
                    let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                    task.progress = safeProgress
                    task.currentFile = "Uploading..."
                }
            }
        )
        
        return syncResult
    }
    
    private func executeWebDAVBackup(task: BackupTask, startTime: Date) async throws -> FTPService.SyncResult {
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
            let sourcePathValue = task.sourcePath ?? ""
            let sourcePath = sourcePathValue == "PHOTOS_LIBRARY" ? "PHOTOS_LIBRARY" : sourcePathValue
            
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
                    Task { @MainActor in
                        // NaN kontrolü ile güvenli progress update
                        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                        task.progress = safeProgress
                        task.currentFile = webDAVService.currentFile
                    }
                }
            )
            
            return syncResult
            
        } catch {
            task.backupStatus = .failed
            task.progress = 0.0  // Reset to 0.0 on failure, safe value
            task.currentFile = "Hata: \(error.localizedDescription)"
            
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
        if actionIdentifier == "START_BACKUP_ACTION" {
            // Notification'dan task ID'yi al
            if identifier.hasPrefix("scheduled-backup-") {
                let taskIdString = String(identifier.dropFirst("scheduled-backup-".count))
                if let taskId = UUID(uuidString: taskIdString) {
                    print("📱 BackupFlow: Yedekleme başlatma talebi - Task ID: \(taskId.uuidString)")
                    
                    // Global state'e yedekleme talebi kaydet
                    UserDefaults.standard.set(taskId.uuidString, forKey: "pendingBackupTaskId")
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "pendingBackupTimestamp")
                    
                    // App açıldığında bu task otomatik başlatılacak
                }
            }
        } else if actionIdentifier == "CANCEL_BACKUP_ACTION" {
            print("❌ BackupFlow: Kullanıcı yedeklemeyi iptal etti")
            // İsteğe bağlı: İptal bildirimi gönder
        }
        
        completionHandler()
    }
    
    // MARK: - Network Detection Helpers
    
    /// Local server IP adresini kontrol eder
    private func isLocalServer(host: String) -> Bool {
        // Local IP ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x, localhost
        let localPatterns = [
            "^192\\.168\\.",
            "^10\\.",
            "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",
            "^127\\.",
            "localhost"
        ]
        
        return localPatterns.contains { pattern in
            host.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    /// Network türünü tespit eder
    private func getCurrentNetworkType() async -> NetworkType {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor")
            let resumptionManager = ResumptionManager(continuation)

            monitor.pathUpdateHandler = { path in
                let networkType: NetworkType
                if path.usesInterfaceType(.wifi) {
                    networkType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    networkType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    networkType = .ethernet
                } else {
                    networkType = .unknown
                }

                Task { @MainActor in
                    if resumptionManager.resume(with: networkType) {
                        monitor.cancel()
                    }
                }
            }

            monitor.start(queue: queue)

            // Timeout after 5 seconds (fallback)
            queue.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in
                    if resumptionManager.resume(with: .unknown) {
                        monitor.cancel()
                    }
                }
            }
        }
    }
}

#else

import Foundation

@MainActor
final class BackupScheduler: NSObject, ObservableObject {
    static let shared = BackupScheduler()
    static var sharedModelContainer: Any?

    func cancelAllBackgroundTasks() {}
    func scheduleProcessingTask() {}
    func scheduleAppRefresh() {}
    func checkMissedTimers() async {}
    func executeBackgroundTask() async -> Bool { false }
}

#endif
