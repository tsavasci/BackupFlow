#if os(iOS)

import AVFoundation
@preconcurrency import BackgroundTasks
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
    private var lastBGTaskNotificationAt: Date? = nil
    
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

    private let baseRetryDelay: TimeInterval = 300
    private func jitteredDelay(for attempt: Int) -> TimeInterval {
        let jitter = Double.random(in: 0...0.3)
        return baseRetryDelay * pow(2.0, Double(attempt - 1)) * (1.0 + jitter)
    }
    
    private var lastBGSubmitAt: Date? = nil
    private var lastSubmitByIdentifier: [String: Date] = [:]
    
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
        
        // Only schedule if there is at least one active (enabled and not paused) task
        if let container = Self.sharedModelContainer {
            let context = ModelContext(container)
            if let tasks = try? context.fetch(FetchDescriptor<BackupTask>()) {
                let hasAnyActive = tasks.contains { $0.isEnabled && !$0.isPaused }
                if !hasAnyActive {
                    print("ℹ️ BGTaskScheduler: Etkin görev yok, processing planlanmadı")
                    return
                }
            }
        }

        // Respect user preference for external power requirement (default false)
        let requireExternal = UserDefaults.standard.bool(forKey: "RequireExternalPower")
        var earliestBeginDate: Date? = nil

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
                    earliestBeginDate = candidate
                }
            }
        }
        
        let id = identifier
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let hasPending = requests.contains { $0.identifier == id }
            Task { @MainActor in
                BackupScheduler.shared.handleProcessingPendingCheck(
                    hasPending: hasPending,
                    identifier: id,
                    earliestBeginDate: earliestBeginDate,
                    requireExternal: requireExternal
                )
            }
        }
    }

    @MainActor
    private func handleProcessingPendingCheck(
        hasPending: Bool,
        identifier: String,
        earliestBeginDate: Date?,
        requireExternal: Bool
    ) {
        if hasPending {
            print("ℹ️ BGTaskScheduler: Processing görevi zaten pending, yeniden planlama atlandı")
            return
        }
        
        if let last = lastSubmitByIdentifier[identifier], Date().timeIntervalSince(last) < 900 {
            print("ℹ️ BGTaskScheduler: Son 15 dk içinde submit edilmiş ama pending yok; yeniden planlanıyor")
        }
        
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = requireExternal
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            lastBGSubmitAt = Date()
            lastSubmitByIdentifier[identifier] = Date()
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
        // Skip if paused, manual, or disabled
        if task.isPaused {
            print("⏸️ BackupFlow: Görev duraklatılmış, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        if case .manual = task.frequency {
            print("📝 BackupFlow: Manuel görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        if !task.isEnabled {
            print("🚫 BackupFlow: Devre dışı görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }

        // Cancel any existing legacy timer for this task to be safe
        cancelTimer(for: task.id)

        // Calculate and set the next run time
        guard let nextRunTime = calculateNextRunTime(for: task) else {
            print("❌ BackupFlow: Sonraki çalışma zamanı hesaplanamadı: \(task.displayName)")
            return
        }
        task.nextRunTime = nextRunTime
        if let context = task.modelContext {
            do {
                try context.save()
            } catch {
                print("❌ BackupFlow: nextRunTime kaydedilemedi: \(error)")
            }
        }
        
        let timeUntilNextRun = nextRunTime.timeIntervalSinceNow
        
        // Zamanlayıcıyı sadece 10 saniyeden daha uzun bir süre varsa kur
        // Bu, anlık veya çok yakın görevler için gereksiz timer oluşturmayı önler
        if timeUntilNextRun > 10 {
            let newTimer = Timer(fireAt: nextRunTime, interval: 0, target: self, selector: #selector(timerFired), userInfo: ["taskId": task.id], repeats: false)
            RunLoop.main.add(newTimer, forMode: .common)
            scheduledTimers[task.id] = newTimer
            
            print("✅ BackupFlow: Görev zamanlayıcı ile planlandı: \(task.displayName) -> \(userLocalDateFormatter.string(from: nextRunTime))")
        } else {
            // Eğer görev çok yakında ise, doğrudan tetikle
            print("ℹ️ BackupFlow: Görev çok yakında, doğrudan tetikleniyor: \(task.displayName)")
            Task {
                try? await performBackup(task: task)
            }
        }
        
        // Also schedule with BGTaskScheduler as a fallback
        scheduleAppRefresh()
        scheduleProcessingTask()
    }
    
    @MainActor
    private func cancelTimer(for taskId: UUID) {
        if let timer = scheduledTimers[taskId] {
            timer.invalidate()
            scheduledTimers.removeValue(forKey: taskId)
            print("🚫 BackupFlow: Timer iptal edildi: \(taskId)")
        }
    }
    
    @objc private func timerFired(timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let taskId = userInfo["taskId"] as? UUID else {
            print("❌ BackupFlow: Timer tetiklendi ancak görev ID'si bulunamadı")
            return
        }
        
        print("⏰ BackupFlow: Timer tetiklendi: \(taskId)")
        
        // Find the task and perform the backup
        Task {
            guard let container = Self.sharedModelContainer else {
                print("❌ BackupFlow: ModelContainer bulunamadı (timerFired)")
                return
            }
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<BackupTask>(
                predicate: #Predicate { $0.id == taskId }
            )
            descriptor.fetchLimit = 1
            
            if let taskToRun = try? context.fetch(descriptor).first {
                print("▶️ BackupFlow: Timer'dan yedekleme başlatılıyor: \(taskToRun.displayName)")
                try? await performBackup(task: taskToRun)
            } else {
                print("❌ BackupFlow: Timer tetiklendi ancak görev veritabanında bulunamadı: \(taskId)")
            }
        }
    }
    
    // MARK: - Backup Execution
    public func performBackup(task: BackupTask, bypassThrottle: Bool = false) async throws {
        let runStart = Date()
        // Re-entrancy guard: Çok sık tetiklemeyi engelle
        if !bypassThrottle, let last = lastRunAt, Date().timeIntervalSince(last) < minRunInterval {
            print("ℹ️ BackupFlow: Son çalıştırmadan bu yana minimum süre dolmadı, tetikleme atlandı")
            return
        }
        if !bypassThrottle {
            lastRunAt = runStart
        }
        
        guard !task.isPaused else {
            print("⏸️ BackupFlow: Görev duraklatılmış, yedekleme atlanıyor: \(task.displayName)")
            return
        }
        
        // Fail-safe: if no internet at start, handle staged retries and return
        let currentType = await getCurrentNetworkType()
        let online = (currentType == .wifi || currentType == .cellular || currentType == .ethernet)
        if !online {
            print("⚠️ BackupFlow: Ağ bağlantısı yok - failsafe devrede")
            await handleNoNetworkFor(task: task)
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
                // Ensure a pending BGProcessing task exists for upcoming schedules
                scheduleProcessingTask()
            }
        }
        
        print("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName)")
        
        // Update task status with safe initial progress, but avoid resetting during an ongoing run
        if task.backupStatus != .uploading {
            task.backupStatus = .preparing
        }
        if task.progress <= 0.0 || task.progress.isNaN || task.progress.isInfinite {
            task.progress = 0.0
        }
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
            let duration = Date().timeIntervalSince(runStart)
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
            // If currently offline, use the no-network staged retry flow
            let currentType = await getCurrentNetworkType()
            if !(currentType == .wifi || currentType == .cellular || currentType == .ethernet) {
                await handleNoNetworkFor(task: task)
                return
            }
            
            // Update task on failure
            task.backupStatus = .failed
            task.lastError = error.localizedDescription
            
            print("❌ BackupFlow: Yedekleme başarısız: \(task.displayName) - \(error)")
            
            // Retry logic
            let currentRetryCount = retryCount[task.id] ?? 0
            if currentRetryCount < maxRetryAttempts {
                retryCount[task.id] = currentRetryCount + 1
                print("🔄 BackupFlow: Yeniden deneme \(currentRetryCount + 1)/\(maxRetryAttempts)")
                
                let delay = self.jitteredDelay(for: currentRetryCount + 1)
                // Advance nextRunTime to avoid foreground re-trigger via missed timers
                task.nextRunTime = Date().addingTimeInterval(delay)
                if let context = task.modelContext {
                    do { try context.save() }
                    catch { print("❌ BackupFlow: nextRunTime kaydedilemedi (retry): \\ (error)") }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    Task {
                        try? await self.performBackup(task: task)
                    }
                }
            } else {
                retryCount.removeValue(forKey: task.id)
                print("💥 BackupFlow: Maksimum yeniden deneme sayısına ulaşıldı")
                // Move to the next scheduled time to prevent immediate re-run on foreground
                task.nextRunTime = calculateNextRunTime(for: task)
                if let context = task.modelContext {
                    do { try context.save() }
                    catch { print("❌ BackupFlow: nextRunTime kaydedilemedi (max retry): \\ (error)") }
                }
            }
            
            // Create backup history record for failure
            let duration = Date().timeIntervalSince(runStart)
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
        if let last = lastNotificationSentAt[task.id], Date().timeIntervalSince(last) < 120 {
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
    
    /// FTP'nin arka planda çalışmasının limitleri hakkında uyarı bildirimi gönderir.
    private func sendBackgroundFTPWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "FTP Yedekleme Başladı"
        content.body = "Büyük dosyaların sorunsuz yedeklenmesi için uygulamanın ön planda tutulması önerilir."
        content.sound = .default
        
        // identifier'ı sabit tutarak aynı anda birden fazla uyarının birikmesini önle
        let request = UNNotificationRequest(
            identifier: "ftp-background-warning",
            content: content,
            trigger: nil // Immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ BackupFlow: FTP uyarı bildirimi gönderilemedi: \(error.localizedDescription)")
            } else {
                print("🔔 BackupFlow: FTP arka plan uyarı bildirimi gönderildi.")
            }
        }
    }
    
    /// Sends a no-network retry notification like: "Ağ bağlantısı yok. Tekrar denenecek 1/3"
    private func sendNoNetworkRetryNotification(task: BackupTask, attempt: Int, maxAttempts: Int, delaySeconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Ağ Bağlantısı Yok"
        let minutes = Int(delaySeconds / 60)
        if minutes >= 1 {
            content.body = "Ağ bağlantısı yok. Tekrar denenecek \(attempt)/\(maxAttempts) (\(minutes) dk sonra)."
        } else {
            content.body = "Ağ bağlantısı yok. Tekrar denenecek \(attempt)/\(maxAttempts)."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "no-network-retry-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("❌ BackupFlow: No-network retry bildirimi hatası: \(error)") }
        }
    }
    
    /// Sends a final postponement notification
    private func sendPostponedDueToNoNetworkNotification(task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "Yedekleme Ertelendi"
        content.body = "Ağ bağlantısı olmadığı için yedekleme ertelendi. Yarın aynı saatte tekrar denenecek."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "no-network-postponed-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("❌ BackupFlow: Erteleme bildirimi hatası: \(error)") }
        }
    }
    
    /// Handles no-network scenario with 3 attempts: 1 min, then 5 min, then postpone by 24h.
    private func handleNoNetworkFor(task: BackupTask) async {
        let maxAttempts = 3
        let current = retryCount[task.id] ?? 0

        if current >= maxAttempts {
            // Already exceeded, ensure reset and postpone
            retryCount.removeValue(forKey: task.id)
            await finalizePostponeDueToNoNetwork(task: task)
            return
        }

        let nextAttempt = current + 1
        retryCount[task.id] = nextAttempt

        // Determine delay: attempt 1 -> 60s, attempt 2 -> 300s, attempt 3 -> finalize
        if nextAttempt == 1 {
            sendNoNetworkRetryNotification(task: task, attempt: nextAttempt, maxAttempts: maxAttempts, delaySeconds: 60)
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                Task { try? await self.performBackup(task: task) }
            }
            return
        } else if nextAttempt == 2 {
            sendNoNetworkRetryNotification(task: task, attempt: nextAttempt, maxAttempts: maxAttempts, delaySeconds: 300)
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                Task { try? await self.performBackup(task: task) }
            }
            return
        } else {
            // Third failure -> postpone 24 hours
            retryCount.removeValue(forKey: task.id)
            await finalizePostponeDueToNoNetwork(task: task)
        }
    }
    
    /// Finalize postponement: notify user, mark as failed, push nextRunTime by 24h and create a history record.
    private func finalizePostponeDueToNoNetwork(task: BackupTask) async {
        sendPostponedDueToNoNetworkNotification(task: task)

        // Mark task failed state
        task.backupStatus = .failed
        task.lastError = "Ağ bağlantısı olmadığı için yedekleme ertelendi."
        task.progress = 0.0
        task.currentFile = nil
        task.lastBackupDate = Date()

        // Shift next run time by +24h from scheduled time if exists; otherwise from now
        let day: TimeInterval = 24 * 60 * 60
        if let existing = task.nextRunTime {
            task.nextRunTime = existing.addingTimeInterval(day)
        } else {
            task.nextRunTime = Date().addingTimeInterval(day)
        }

        // Persist changes
        if let context = task.modelContext {
            do { try context.save() } catch { print("❌ BackupFlow: Erteleme kaydı sırasında hata: \(error)") }
        }

        // Create a failed history record
        await createBackupHistoryRecord(
            task: task,
            syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
            duration: 0,
            status: "failed",
            errorMessage: "Ağ bağlantısı olmadığı için yedekleme ertelendi."
        )

        // Re-schedule background tasks
        scheduleAppRefresh()
        scheduleProcessingTask()
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
        
        let id = identifier
        if let last = lastSubmitByIdentifier[id], Date().timeIntervalSince(last) < 900 { // 15 minutes
            return
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            lastBGSubmitAt = Date()
            lastSubmitByIdentifier[id] = Date()
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
                        if let last = lastRunAt, Date().timeIntervalSince(last) < minRunInterval {
                            print("ℹ️ checkMissedTimers: Minimum aralık dolmadı, atlanıyor")
                            continue
                        }
                        if isProcessing {
                            print("ℹ️ checkMissedTimers: Aktif işlem var, tetikleme atlandı")
                            continue
                        }
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
            scheduleProcessingTask()
            return true
        }
        
        await sendBackgroundTaskStartedNotification(taskCount: dueTasks.count)

        print("🚀 BGTaskScheduler: \(dueTasks.count) görev arka planda yürütülecek")
        
        var anySuccess = false
        for taskToRun in dueTasks {
            
            // Check if it's an FTP task in the background and send a warning notification
            if taskToRun.backupType == .ftp {
                #if canImport(UIKit)
                if UIApplication.shared.applicationState == .background {
                    sendBackgroundFTPWarningNotification()
                }
                #endif
            }
            
            print("📱 BGTaskScheduler: Arka plan görevi başlatılıyor: \(taskToRun.displayName)")
            do {
                try await performBackup(task: taskToRun, bypassThrottle: true)
                anySuccess = true
                print("✅ BGTaskScheduler: Arka plan görevi başarıyla tamamlandı: \(taskToRun.displayName)")
            } catch {
                print("⚠️ BGTaskScheduler: Arka plan görevi başarısız -> \(taskToRun.displayName) - \(error)")
            }
        }
        
        scheduleAppRefresh()
        scheduleProcessingTask()
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
                deletedFiles: syncResult.deletedFiles,
                taskDisplayName: task.displayName,
                taskSourcePath: task.sourcePath,
                taskServerHost: task.serverHost,
                taskServerPort: task.serverPort,
                taskUsername: task.serverUsername,
                taskIsAnonymous: task.isAnonymous,
                taskMediaTypeRaw: task.mediaType.rawValue
            )

            // Attach the task to the history record
            historyRecord.task = task

            do {
                // In many cases, appending to a relationship is enough; insert is optional
                try context.save()
                HistoryRetentionManager.pruneIfNeeded(context: context)
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
                deletedFiles: syncResult.deletedFiles,
                taskDisplayName: taskInContext.displayName,
                taskSourcePath: taskInContext.sourcePath,
                taskServerHost: taskInContext.serverHost,
                taskServerPort: taskInContext.serverPort,
                taskUsername: taskInContext.serverUsername,
                taskIsAnonymous: taskInContext.isAnonymous,
                taskMediaTypeRaw: taskInContext.mediaType.rawValue
            )

            historyRecord.task = taskInContext

            try context.save()
            HistoryRetentionManager.pruneIfNeeded(context: context)
            print("📝 BackupFlow: Geçmiş kaydı eklendi (refetched) - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
        } catch {
            print("❌ BackupFlow: Geçmiş kaydı hatası (refetch): \(error)")
        }
    }

    /// BGTask tetiklendiğinde kullanıcıya bildirim gönderir (debounced).
    private func sendBackgroundTaskStartedNotification(taskCount: Int) async {
        guard await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized else {
            return
        }
        if let last = lastBGTaskNotificationAt, Date().timeIntervalSince(last) < 300 {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Arka Plan Görevi Başladı"
        content.body = "Yedekleme arka planda başlatıldı (\(taskCount) görev)."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "bg_task_started",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            lastBGTaskNotificationAt = Date()
            print("🔔 BackupFlow: BGTask başlangıç bildirimi gönderildi")
        } catch {
            print("❌ BackupFlow: BGTask başlangıç bildirimi hatası: \(error)")
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

