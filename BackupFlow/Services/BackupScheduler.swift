
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

import UIKit

/// The type of network connection.
enum NetworkType {
    case wifi
    case cellular
    case ethernet
    case unknown

    var description: String {
        switch self {
        case .wifi: return "network.type.wifi".localized
        case .cellular: return "network.type.cellular".localized
        case .ethernet: return "network.type.ethernet".localized
        case .unknown: return "network.type.unknown".localized
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
    
    private var lastRunAtByTask: [UUID: Date] = [:]
    private let minRunInterval: TimeInterval = 60 // en az 60 sn arayla çalıştır
    private var activeBackgroundTaskID: UUID?
    private var backgroundExpirationTaskIDs: Set<UUID> = []
    
    @Published private(set) var isProcessing = false
    /// Task whose details a notification action asked to open; the dashboard presents it.
    @Published var requestedDetailTaskID: UUID?
    /// Task a reminder's "Start" action asked to run once the app is active.
    private var pendingStartTaskID: UUID?
    /// Tasks with a run in progress. Several paths can start the same task at once
    /// (a notification action, checkMissedTimers, a timer); only the first one runs.
    private var runningTaskIDs: Set<UUID> = []
    /// Tasks the user just started whose run hasn't begun yet. On a device that start
    /// goes through a continued processing task that launches a moment later;
    /// checkMissedTimers leaves these alone so that the run which can keep going in
    /// the background is the one that happens.
    private var userStartedTaskIDs: [UUID: Date] = [:]
    private var isCheckingMissedTimers = false
    /// Tasks the user chose to start without Wi-Fi despite their Wi-Fi requirement, with
    /// when they confirmed. The run that follows consumes the entry.
    private var wifiOverrideTaskIDs: [UUID: Date] = [:]
    /// A reminder's "Start" reached a task that needs Wi-Fi while there is none;
    /// the dashboard asks whether to start it anyway.
    @Published var wifiConfirmationTaskID: UUID?
    /// Watches for Wi-Fi so runs waiting for it start as soon as it is back.
    private let wifiPathMonitor = NWPathMonitor()
    /// Latest state from `wifiPathMonitor`; nil until its first update.
    private(set) var isOnWiFi: Bool?
    /// How long a scheduled run may wait for Wi-Fi before it is skipped.
    private let maxWiFiWait: TimeInterval = 6 * 60 * 60
    private let wifiRetryInterval: TimeInterval = 15 * 60
    
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
        startWiFiMonitoring()
        debugLog("🔄 BackupFlow: BackupScheduler init tamamlandı (BGTask + Timer hibrit)")
        
        // Debug: Veritabanındaki tüm görevleri listele
        if let container = Self.sharedModelContainer {
            let context = ModelContext(container)
            if let tasks = try? context.fetch(FetchDescriptor<BackupTask>()) {
                debugLog("📋 BackupFlow: Veritabanında \(tasks.count) görev bulundu:")
                for (index, task) in tasks.enumerated() {
                    let statusText = task.isEnabled ? (task.isPaused ? "⏸️ Duraklatılmış" : "✅ Aktif") : "❌ Devre dışı"
                    let freqText: String = {
                        switch task.frequency {
                        case .manual: return "Manuel"
                        case .daily(let time): return "Günlük (\(time.timeString))"
                        case .weekly(let day, let time):
                            let dayName = ["Pzr", "Pzt", "Sal", "Çrş", "Prş", "Cum", "Cts"][day - 1]
                            return "Haftalık (\(dayName) \(time.timeString))"
                        case .monthly(let day, let time):
                            return "Aylık (\(day). gün \(time.timeString))"
                        case .intervalHours(let hours):
                            return "Her \(hours) saat"
                        }
                    }()
                    let nextRunText = task.nextRunTime.map { userLocalDateFormatter.string(from: $0) } ?? "Belirlenmedi"
                    debugLog("   \(index + 1). \(task.displayName)")
                    debugLog("      - Tür: \(task.backupType.displayName)")
                    debugLog("      - Durum: \(statusText)")
                    debugLog("      - Sıklık: \(freqText)")
                    debugLog("      - Sonraki çalışma: \(nextRunText)")
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
                    debugLog("ℹ️ BGTaskScheduler: Etkin görev yok, processing planlanmadı")
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
                        debugLog("ℹ️ BGTaskScheduler: Processing earliest çok yakın, 15 dk'ya yuvarlandı -> \(userLocalDateFormatter.string(from: candidate))")
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
            debugLog("ℹ️ BGTaskScheduler: Processing görevi zaten pending, yeniden planlama atlandı")
            return
        }
        
        if let last = lastSubmitByIdentifier[identifier], Date().timeIntervalSince(last) < 900 {
            debugLog("ℹ️ BGTaskScheduler: Son 15 dk içinde submit edilmiş ama pending yok; yeniden planlanıyor")
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
                debugLog("✅ BGTaskScheduler: Processing görevi planlandı -> \(userLocalDateFormatter.string(from: d))")
            } else {
                debugLog("✅ BGTaskScheduler: Processing görevi planlandı (tarih yok)")
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
            debugLog("❌ BGTaskScheduler: Processing planlanamadı (code=\(nsError.code) reason=\(reason)): \(error)")
        }
    }
    
    public func pauseTask(_ task: BackupTask) {
        cancelTimer(for: task.id)
        task.isPaused = true
        debugLog("⏸️ BackupFlow: Görev duraklatıldı: \(task.displayName)")
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
        debugLog("▶️ BackupFlow: Görev devam ettirildi: \(task.displayName)")
        
        // Reschedule the task (bildirim gönderimi yok)
        Task {
            await scheduleTask(task)
        }
    }
    
    public func scheduleBackup(task: BackupTask) async throws {
        await scheduleTask(task)
    }
    
    /// Stops the run in progress. The schedule is left alone, so the task still runs next time.
    public func cancelCurrentTask(for task: BackupTask) {
        switch task.backupType {
        case .ftp:
            FTPService.shared.cancelCurrentTask()
        case .sftp:
            SFTPService.shared.cancelCurrentTask()
        case .webdav:
            WebDAVService.shared.cancelCurrentTask()
        }
        
        // Update task status to cancelled
        task.backupStatus = .cancelled
        task.progress = 0.0
        task.currentFile = nil
        resetCurrentFileProgress(for: task)
        
        debugLog("🚫 BackupFlow: Görev iptal edildi: \(task.displayName)")
    }

    /// Called by BGTask expiration handlers. The transfer must be cancelled before
    /// iOS reclaims the execution window; the task is then retried by a later run.
    public func cancelActiveBackgroundBackup() {
        guard let taskID = activeBackgroundTaskID,
              let container = Self.sharedModelContainer else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackupTask>()
        guard let tasks = try? context.fetch(descriptor),
              let task = tasks.first(where: { $0.id == taskID }) else { return }

        backgroundExpirationTaskIDs.insert(task.id)
        switch task.backupType {
        case .ftp:
            FTPService.shared.cancelForBackgroundExpiration()
        case .sftp:
            SFTPService.shared.cancelCurrentTask()
        case .webdav:
            WebDAVService.shared.cancelCurrentTask()
        }
        task.backupStatus = .cancelled
        task.lastError = BackupServiceError.cancelled.localizedDescription
        task.nextRunTime = Date().addingTimeInterval(15 * 60)
        try? context.save()
        refreshReminder(for: task)
        debugLog("⏱️ BGTaskScheduler: Süresi dolan aktif yedek iptal edildi: \(task.displayName)")
    }
    
    /// Entry point for backups the user starts explicitly (buttons, notification actions).
    /// FTP/SFTP runs go through a continued processing task when available so they keep
    /// running after the app is backgrounded; everything else runs directly as before.
    /// - Parameter ignoreWiFiRequirement: The user confirmed starting this run without Wi-Fi.
    public func startUserInitiatedBackup(task: BackupTask, ignoreWiFiRequirement: Bool = false) {
        userStartedTaskIDs[task.id] = Date()
        if ignoreWiFiRequirement {
            wifiOverrideTaskIDs[task.id] = Date()
        }
        if ContinuedBackupRunner.shared.start(task: task) { return }
        Task {
            try? await performBackup(task: task, bypassThrottle: true)
        }
    }

    /// Whether starting this task now should first ask the user to go ahead without Wi-Fi.
    public func needsWiFiConfirmation(for task: BackupTask) -> Bool {
        task.requiresWiFi && isOnWiFi == false
    }

    // MARK: - Wi-Fi Wait

    private func startWiFiMonitoring() {
        wifiPathMonitor.pathUpdateHandler = { path in
            let onWiFi = path.status == .satisfied && path.usesInterfaceType(.wifi)
            Task { @MainActor in
                BackupScheduler.shared.wifiPathChanged(onWiFi: onWiFi)
            }
        }
        wifiPathMonitor.start(queue: DispatchQueue(label: "BackupScheduler.WiFiMonitor"))
    }

    private func wifiPathChanged(onWiFi: Bool) {
        let wasOnWiFi = isOnWiFi
        isOnWiFi = onWiFi
        // Wi-Fi is back while the app is open: runs waiting for it go now rather than
        // at their next 15-minute retry. checkMissedTimers picks them up.
        guard onWiFi, wasOnWiFi != true,
              UIApplication.shared.applicationState == .active else { return }
        debugLog("📶 BackupFlow: Wi-Fi bağlandı, Wi-Fi bekleyen görevler kontrol ediliyor")
        Task {
            await checkMissedTimers()
        }
    }

    /// Holds a scheduled run that needs Wi-Fi. It is retried every 15 minutes, or as soon
    /// as the open app sees Wi-Fi, until the task's next regular run and for at most
    /// 6 hours. After that this occurrence is skipped with a single history record.
    private func waitForWiFi(task: BackupTask) async {
        task.lastError = "backup.defer.wifi_required".localized
        // A manual task has no schedule to hold; the user starts it again on Wi-Fi.
        guard task.frequency != .manual else {
            try? task.modelContext?.save()
            return
        }

        let now = Date()
        if task.wifiWaitDeadline == nil {
            let nextRegularRun = calculateNextRunTime(for: task) ?? now.addingTimeInterval(maxWiFiWait)
            task.wifiWaitDeadline = min(nextRegularRun, now.addingTimeInterval(maxWiFiWait))
            // WebDAV has no reminders to replace; FTP/SFTP get one notice instead of a
            // "time to back up" reminder every 15 minutes.
            if task.backupType == .ftp || task.backupType == .sftp {
                sendWaitingForWiFiNotification(for: task)
            }
        }

        let retryAt = now.addingTimeInterval(wifiRetryInterval)
        if let deadline = task.wifiWaitDeadline, retryAt < deadline {
            task.nextRunTime = retryAt
            try? task.modelContext?.save()
            debugLog("📶 BackupFlow: Wi-Fi bekleniyor, yeniden deneme: \(userLocalDateFormatter.string(from: retryAt)) - \(task.displayName)")
        } else {
            let skippedMessage = "backup.defer.wifi_skipped".localized
            task.wifiWaitDeadline = nil
            task.lastError = skippedMessage
            task.nextRunTime = calculateNextRunTime(for: task)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.wifiWaitNotificationIdentifier(for: task.id)])
            try? task.modelContext?.save()
            await createBackupHistoryRecord(
                task: task,
                syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: 0,
                status: "deferred",
                errorMessage: skippedMessage,
                failureCategory: .network
            )
            debugLog("⏭️ BackupFlow: Wi-Fi gelmedi, bu çalıştırma atlandı: \(task.displayName)")
        }

        rearmTimer(for: task)
        scheduleAppRefresh()
        scheduleProcessingTask()
    }

    private static func wifiWaitNotificationIdentifier(for taskID: UUID) -> String {
        "wifi-wait-\(taskID)"
    }

    private func sendWaitingForWiFiNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.wifi_wait.title".localized
        content.body = String(format: "backup.wifi_wait.body".localized, task.displayName)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.wifiWaitNotificationIdentifier(for: task.id),
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Timer Management
    @MainActor
    private func scheduleTask(_ task: BackupTask) async {
        // Skip if paused, manual, or disabled
        if task.isPaused {
            debugLog("⏸️ BackupFlow: Görev duraklatılmış, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        if case .manual = task.frequency {
            debugLog("📝 BackupFlow: Manuel görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }
        if !task.isEnabled {
            debugLog("🚫 BackupFlow: Devre dışı görev, zamanlama atlanıyor: \(task.displayName)")
            return
        }

        // Cancel any existing legacy timer for this task to be safe
        cancelTimer(for: task.id)
        // A fresh schedule starts over; an earlier wait for Wi-Fi no longer applies.
        task.wifiWaitDeadline = nil

        // Calculate and set the next run time
        guard let nextRunTime = calculateNextRunTime(for: task) else {
            debugLog("❌ BackupFlow: Sonraki çalışma zamanı hesaplanamadı: \(task.displayName)")
            return
        }
        task.nextRunTime = nextRunTime
        if let context = task.modelContext {
            do {
                try context.save()
            } catch {
                debugLog("❌ BackupFlow: nextRunTime kaydedilemedi: \(error)")
            }
        }
        refreshReminder(for: task)
        
        let timeUntilNextRun = nextRunTime.timeIntervalSinceNow
        
        // Zamanlayıcıyı sadece 10 saniyeden daha uzun bir süre varsa kur
        // Bu, anlık veya çok yakın görevler için gereksiz timer oluşturmayı önler
        if timeUntilNextRun > 10 {
            let newTimer = Timer(fireAt: nextRunTime, interval: 0, target: self, selector: #selector(timerFired), userInfo: ["taskId": task.id], repeats: false)
            RunLoop.main.add(newTimer, forMode: .common)
            scheduledTimers[task.id] = newTimer
            
            debugLog("✅ BackupFlow: Görev zamanlayıcı ile planlandı: \(task.displayName) -> \(userLocalDateFormatter.string(from: nextRunTime))")
        } else {
            // Eğer görev çok yakında ise, doğrudan tetikle
            debugLog("ℹ️ BackupFlow: Görev çok yakında, doğrudan tetikleniyor: \(task.displayName)")
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
            debugLog("🚫 BackupFlow: Timer iptal edildi: \(taskId)")
        }
    }
    
    /// Re-arms the in-app timer at the task's current `nextRunTime` after it was moved
    /// (skipped or postponed), so the stale timer doesn't still run the old occurrence.
    @MainActor
    private func rearmTimer(for task: BackupTask) {
        cancelTimer(for: task.id)
        guard task.isEnabled, !task.isPaused, task.frequency != .manual,
              let nextRunTime = task.nextRunTime, nextRunTime.timeIntervalSinceNow > 10 else { return }
        let newTimer = Timer(fireAt: nextRunTime, interval: 0, target: self, selector: #selector(timerFired), userInfo: ["taskId": task.id], repeats: false)
        RunLoop.main.add(newTimer, forMode: .common)
        scheduledTimers[task.id] = newTimer
    }

    @objc private func timerFired(timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any],
              let taskId = userInfo["taskId"] as? UUID else {
            debugLog("❌ BackupFlow: Timer tetiklendi ancak görev ID'si bulunamadı")
            return
        }
        
        debugLog("⏰ BackupFlow: Timer tetiklendi: \(taskId)")
        scheduledTimers.removeValue(forKey: taskId)

        // A timer that came due while the app was suspended fires the moment anything
        // wakes the app, including a notification response, before that response is
        // handled. Starting here would run a backup the user just skipped with the
        // reminder's "Cancel". Only run for an active app: once it comes forward,
        // checkMissedTimers runs the task if it is still due, and in the background
        // the reminder and BGProcessingTask paths take over.
        guard UIApplication.shared.applicationState == .active else {
            debugLog("ℹ️ BackupFlow: Uygulama aktif değil; zamanlayıcı yedeği başlatmadı: \(taskId)")
            return
        }

        // Find the task and perform the backup
        Task {
            guard let container = Self.sharedModelContainer else {
                debugLog("❌ BackupFlow: ModelContainer bulunamadı (timerFired)")
                return
            }
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<BackupTask>(
                predicate: #Predicate { $0.id == taskId }
            )
            descriptor.fetchLimit = 1
            
            if let taskToRun = try? context.fetch(descriptor).first {
                debugLog("▶️ BackupFlow: Timer'dan yedekleme başlatılıyor: \(taskToRun.displayName)")
                try? await performBackup(task: taskToRun)
            } else {
                debugLog("❌ BackupFlow: Timer tetiklendi ancak görev veritabanında bulunamadı: \(taskId)")
            }
        }
    }
    
    // MARK: - Backup Execution
    public func performBackup(task: BackupTask, bypassThrottle: Bool = false) async throws {
        userStartedTaskIDs[task.id] = nil
        // Claim the task before the first await so a second caller sees it running.
        guard !runningTaskIDs.contains(task.id) else {
            debugLog("ℹ️ BackupFlow: Görev zaten çalışıyor, ikinci başlatma yok sayıldı: \(task.displayName)")
            return
        }
        runningTaskIDs.insert(task.id)
        defer { runningTaskIDs.remove(task.id) }
        BackupRunTally.shared.reset()
        // Every exit path below may move nextRunTime; keep the queued reminder in sync.
        defer { refreshReminder(for: task) }
        let runStart = Date()
        var executionOptions = BackupExecutionOptions.forTask(task)
        // The user confirmed starting this run without Wi-Fi; a stale confirmation
        // (its run never began) must not lift the rule for a later scheduled run.
        if let confirmedAt = wifiOverrideTaskIDs.removeValue(forKey: task.id),
           Date().timeIntervalSince(confirmedAt) < 120 {
            executionOptions.requiresWiFi = false
        }
        if executionOptions.requiresWiFi {
            guard await getCurrentNetworkType() == .wifi else {
                debugLog("📶 BackupFlow: Wi-Fi yok, görev Wi-Fi bekliyor: \(task.displayName)")
                await waitForWiFi(task: task)
                return
            }
            task.wifiWaitDeadline = nil
        }
        if let blockReason = await blockedReason(for: task, options: executionOptions) {
            debugLog("⏸️ BackupFlow: Görev koşullar nedeniyle ertelendi: \(blockReason)")
            task.lastError = blockReason
            task.nextRunTime = Date().addingTimeInterval(15 * 60)
            await createBackupHistoryRecord(
                task: task,
                syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: 0,
                status: "deferred",
                errorMessage: blockReason,
                failureCategory: .network
            )
            return
        }

        // Re-entrancy guard: Çok sık tetiklemeyi engelle
        if !bypassThrottle,
           let last = lastRunAtByTask[task.id],
           Date().timeIntervalSince(last) < minRunInterval {
            debugLog("ℹ️ BackupFlow: Son çalıştırmadan bu yana minimum süre dolmadı, tetikleme atlandı")
            return
        }
        if !bypassThrottle {
            lastRunAtByTask[task.id] = runStart
        }
        
        guard !task.isPaused else {
            debugLog("⏸️ BackupFlow: Görev duraklatılmış, yedekleme atlanıyor: \(task.displayName)")
            return
        }
        
        // Fail-safe: if no internet at start, handle staged retries and return
        let currentType = await getCurrentNetworkType()
        let online = (currentType == .wifi || currentType == .cellular || currentType == .ethernet)
        if !online {
            debugLog("⚠️ BackupFlow: Ağ bağlantısı yok - failsafe devrede")
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
        
        debugLog("🚀 BackupFlow: Yedekleme başlatılıyor: \(task.displayName)")
        
        // Update task status with safe initial progress, but avoid resetting during an ongoing run
        if task.backupStatus != .uploading {
            task.backupStatus = .preparing
        }
        if task.progress <= 0.0 || task.progress.isNaN || task.progress.isInfinite {
            task.progress = 0.0
            resetCurrentFileProgress(for: task)
        }
        task.lastError = nil
        
        do {
            let syncResult: FTPService.SyncResult
            // Perform the actual backup
            switch task.backupType {
            case .ftp:
                syncResult = try await executeFTPBackup(task: task, startTime: Date(), options: executionOptions)
            case .sftp:
                syncResult = try await executeSFTPBackup(task: task, startTime: Date(), options: executionOptions)
            case .webdav:
                syncResult = try await executeWebDAVBackup(task: task, startTime: Date(), options: executionOptions)
            }
            
            // Update task on success with safe progress
            task.backupStatus = .completed
            task.progress = 1.0  // Success is always 1.0, safe value
            task.lastBackupDate = Date()
            task.currentFile = nil
            resetCurrentFileProgress(for: task)
            task.lastFailureCategory = nil
            task.consecutiveFailureCount = 0
            
            // Schedule next run
            task.nextRunTime = calculateNextRunTime(for: task)
            // This run is done; a still-visible reminder for it would only start a duplicate.
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
                Self.reminderIdentifier(for: task.id),
                Self.wifiWaitNotificationIdentifier(for: task.id)
            ])
            
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

            debugLog("✅ BackupFlow: Yedekleme tamamlandı: \(task.displayName)")
            
        } catch {
            if let backupError = error as? BackupServiceError, case .cancelled = backupError {
                let expiredBySystem = backgroundExpirationTaskIDs.remove(task.id) != nil
                    || (task.backupType == .ftp && FTPService.shared.consumeBackgroundExpiration())
                task.backupStatus = .cancelled
                task.lastError = backupError.localizedDescription
                task.progress = 0.0
                task.currentFile = nil
                resetCurrentFileProgress(for: task)
                task.nextRunTime = expiredBySystem
                    ? Date().addingTimeInterval(15 * 60)
                    : calculateNextRunTime(for: task)
                
                let duration = Date().timeIntervalSince(runStart)
                await createBackupHistoryRecord(
                    task: task,
                    syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                    duration: duration,
                    status: "interrupted",
                    errorMessage: backupError.localizedDescription,
                    failureCategory: .cancelled
                )
                
                if expiredBySystem {
                    scheduleProcessingTask()
                    // Only socket transfers are cut off here; WebDAV continues in its background session.
                    if task.backupType == .ftp || task.backupType == .sftp {
                        sendBackgroundInterruptedNotification(for: task)
                    }
                    debugLog("⏱️ BackupFlow: Arka plan süresi dolduğu için yedekleme ertelendi: \(task.displayName)")
                } else {
                    debugLog("⏸️ BackupFlow: Yedekleme yarıda kesildi: \(task.displayName)")
                }
                return
            }

            let currentType = await getCurrentNetworkType()

            // Wi-Fi dropped during a run that requires it: wait for Wi-Fi again rather
            // than spend a retry on a connection this task isn't allowed to use.
            if executionOptions.requiresWiFi, currentType != .wifi {
                debugLog("📶 BackupFlow: Yedekleme sırasında Wi-Fi koptu: \(task.displayName) - \(error)")
                task.backupStatus = task.frequency == .manual ? .failed : .idle
                task.progress = 0.0
                task.currentFile = nil
                resetCurrentFileProgress(for: task)
                // Keep a record of what was sent before the drop.
                if BackupRunTally.shared.uploadedFiles > 0 {
                    await createBackupHistoryRecord(
                        task: task,
                        syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                        duration: Date().timeIntervalSince(runStart),
                        status: "interrupted",
                        errorMessage: "backup.defer.wifi_lost".localized,
                        failureCategory: .network
                    )
                }
                await waitForWiFi(task: task)
                return
            }

            // If currently offline, use the no-network staged retry flow
            if !(currentType == .wifi || currentType == .cellular || currentType == .ethernet) {
                await handleNoNetworkFor(task: task)
                return
            }
            
            // Update task on failure
            task.backupStatus = .failed
            task.lastError = error.localizedDescription
            let failureCategory = categorizeFailure(error)
            task.lastFailureCategory = failureCategory
            task.consecutiveFailureCount += 1
            
            debugLog("❌ BackupFlow: Yedekleme başarısız: \(task.displayName) - \(error)")

            // Record every failed run, including ones that will be retried; the dashboard
            // failure counter already counts them, so history must show them too.
            let duration = Date().timeIntervalSince(runStart)
            await createBackupHistoryRecord(
                task: task,
                syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
                duration: duration,
                status: "failed",
                errorMessage: error.localizedDescription,
                failureCategory: failureCategory
            )

            // Retry logic, for scheduled tasks only: a manual task runs when the user
            // starts it and must not gain a "next backup" time from a retry.
            let currentRetryCount = retryCount[task.id] ?? 0
            if task.frequency != .manual, currentRetryCount < maxRetryAttempts {
                retryCount[task.id] = currentRetryCount + 1
                debugLog("🔄 BackupFlow: Yeniden deneme \(currentRetryCount + 1)/\(maxRetryAttempts)")

                let delay = self.jitteredDelay(for: currentRetryCount + 1)
                // Advance nextRunTime to avoid foreground re-trigger via missed timers
                task.nextRunTime = Date().addingTimeInterval(delay)
                if let context = task.modelContext {
                    do { try context.save() }
                    catch { debugLog("❌ BackupFlow: nextRunTime kaydedilemedi (retry): \(error)") }
                }
                // Delayed dispatch does not run reliably while the app is
                // suspended. Persist the retry and let BGTaskScheduler decide
                // the next execution window.
                scheduleProcessingTask()
            } else {
                retryCount.removeValue(forKey: task.id)
                if task.frequency != .manual {
                    debugLog("💥 BackupFlow: Maksimum yeniden deneme sayısına ulaşıldı")
                }
                // Move to the next scheduled time to prevent immediate re-run on foreground
                task.nextRunTime = calculateNextRunTime(for: task)
                if let context = task.modelContext {
                    do { try context.save() }
                    catch { debugLog("❌ BackupFlow: nextRunTime kaydedilemedi (max retry): \(error)") }
                }
            }
        }
    }

    public func previewBackup(task: BackupTask) async throws -> BackupPreviewResult {
        let options = BackupExecutionOptions.forTask(task, isDryRun: true)
        let syncResult: FTPService.SyncResult
        switch task.backupType {
        case .ftp:
            syncResult = try await executeFTPBackup(task: task, startTime: Date(), options: options)
        case .sftp:
            syncResult = try await executeSFTPBackup(task: task, startTime: Date(), options: options)
        case .webdav:
            syncResult = try await executeWebDAVBackup(task: task, startTime: Date(), options: options)
        }
        task.backupStatus = .idle
        task.progress = 0.0
        task.currentFile = nil
        resetCurrentFileProgress(for: task)
        return BackupPreviewResult.fromSyncResult(syncResult, deletionPolicy: options.deletionPolicy)
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
        case .monthly(let day, let time):
            let safeDay = max(1, min(31, day))
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = safeDay
            components.hour = time.hour
            components.minute = time.minute
            components.second = 0

            func validMonthlyDate(from components: DateComponents) -> Date? {
                guard let date = calendar.date(from: components),
                      calendar.component(.day, from: date) == safeDay else {
                    return nil
                }
                return date
            }

            if let scheduledThisMonth = validMonthlyDate(from: components), scheduledThisMonth > now {
                return scheduledThisMonth
            }

            for offset in 1...12 {
                guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: now) else { continue }
                var nextComponents = calendar.dateComponents([.year, .month], from: nextMonth)
                nextComponents.day = safeDay
                nextComponents.hour = time.hour
                nextComponents.minute = time.minute
                nextComponents.second = 0
                if let date = validMonthlyDate(from: nextComponents), date > now {
                    return date
                }
            }
            return nil
        case .intervalHours(let hours):
            let interval = TimeInterval(max(1, hours) * 3600)
            if let nextRun = task.nextRunTime, nextRun > now {
                return nextRun
            }
            return Date().addingTimeInterval(interval)
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
            debugLog("ℹ️ BackupFlow: Yakın zamanda aynı görev için bildirim gönderilmiş, tekrar edilmiyor")
            return
        }

        let content = makeScheduledBackupContent(for: task)
        
        // Hemen gönder: önce aynı kimlikli pending ve delivered bildirimleri temizle
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(for: task.id),
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [request.identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
        UNUserNotificationCenter.current().add(request)
        debugLog("🔔 BackupFlow: Zamanlanmış yedekleme bildirimi gönderildi: \(task.displayName)")
        lastNotificationSentAt[task.id] = Date()
    }

    /// Tells the user iOS stopped an FTP/SFTP run before it finished, so opening the app
    /// (or tapping the reminder) is needed to continue; the sync resumes where it left off.
    private func sendBackgroundInterruptedNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.background_interrupted.title".localized
        content.body = String(format: "backup.background_interrupted.body".localized, task.displayName)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "background-interrupted-\(task.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func reminderIdentifier(for taskID: UUID) -> String {
        "scheduled-backup-\(taskID)"
    }

    /// Keeps a reminder queued in the system for the task's next FTP/SFTP run.
    ///
    /// iOS can't start FTP/SFTP at an exact time in the background, and never launches a
    /// force-quit app for background tasks. A notification scheduled with the system is
    /// delivered regardless, and its "Start" action opens the app so the backup can run
    /// as a user-initiated continued processing task.
    public func refreshReminder(for task: BackupTask) {
        let identifier = Self.reminderIdentifier(for: task.id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // WebDAV continues through its background URLSession and needs no reminder.
        let usesSocketTransfer = task.backupType == .ftp || task.backupType == .sftp
        // While waiting for Wi-Fi a reminder every retry would only start a run that
        // defers again; the task sent a single "waiting for Wi-Fi" notice instead.
        guard usesSocketTransfer,
              task.isEnabled, !task.isPaused,
              task.frequency != .manual,
              task.wifiWaitDeadline == nil,
              let fireDate = task.nextRunTime, fireDate > Date() else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: makeScheduledBackupContent(for: task),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        center.add(request)
        debugLog("⏰ BackupFlow: Hatırlatma planlandı: \(task.displayName) -> \(userLocalDateFormatter.string(from: fireDate))")
    }

    public func removeReminder(forTaskID taskID: UUID) {
        let identifier = Self.reminderIdentifier(for: taskID)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func makeScheduledBackupContent(for task: BackupTask) -> UNMutableNotificationContent {
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
        case .monthly:
            frequencyText = "backup.frequency_text.monthly".localized
        case .intervalHours:
            frequencyText = "backup.frequency_text.interval".localized
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
        content.userInfo = ["taskId": task.id.uuidString]
        
        // Kategori zaten AppDelegate'te kaydedildi, sadece identifier'ı ayarla
        content.categoryIdentifier = "SCHEDULED_BACKUP"
        return content
    }
    
    /// Sends a no-network retry notification like: "Ağ bağlantısı yok. Tekrar denenecek 1/3"
    private func sendNoNetworkRetryNotification(task: BackupTask, attempt: Int, maxAttempts: Int, delaySeconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "backup.network_unavailable.title".localized
        let minutes = Int(delaySeconds / 60)
        if minutes >= 1 {
            content.body = "backup.network_unavailable.body_with_delay".localized(with: attempt, maxAttempts, minutes)
        } else {
            content.body = "backup.network_unavailable.body".localized(with: attempt, maxAttempts)
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "no-network-retry-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { debugLog("❌ BackupFlow: No-network retry bildirimi hatası: \(error)") }
        }
    }
    
    /// Sends a final postponement notification
    private func sendPostponedDueToNoNetworkNotification(task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.network_postponed.title".localized
        content.body = "backup.network_postponed.body".localized
        content.sound = .default
        let request = UNNotificationRequest(identifier: "no-network-postponed-\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { debugLog("❌ BackupFlow: Erteleme bildirimi hatası: \(error)") }
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
            task.nextRunTime = Date().addingTimeInterval(60)
            if let context = task.modelContext { try? context.save() }
            scheduleProcessingTask()
            return
        } else if nextAttempt == 2 {
            sendNoNetworkRetryNotification(task: task, attempt: nextAttempt, maxAttempts: maxAttempts, delaySeconds: 300)
            task.nextRunTime = Date().addingTimeInterval(300)
            if let context = task.modelContext { try? context.save() }
            scheduleProcessingTask()
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
        let postponedMessage = "backup.network_postponed.body".localized

        // Mark task failed state
        task.backupStatus = .failed
        task.lastError = postponedMessage
        task.progress = 0.0
        task.currentFile = nil
        resetCurrentFileProgress(for: task)
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
            do { try context.save() } catch { debugLog("❌ BackupFlow: Erteleme kaydı sırasında hata: \(error)") }
        }

        // Create a failed history record
        await createBackupHistoryRecord(
            task: task,
            syncResult: FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0),
            duration: 0,
            status: "failed",
            errorMessage: postponedMessage,
            failureCategory: .network
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
        debugLog("🚫 BackupFlow: Tüm timer'lar iptal edildi")
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
                debugLog("ℹ️ BGTaskScheduler: Earliest çok yakın, 15 dk'ya yuvarlandı -> \(userLocalDateFormatter.string(from: candidate))")
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
                debugLog("✅ BGTaskScheduler: App refresh görevi planlandı -> \(userLocalDateFormatter.string(from: d))")
            } else {
                debugLog("✅ BGTaskScheduler: App refresh görevi planlandı (tarih yok)")
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
            debugLog("❌ BGTaskScheduler: Görev planlanamadı (code=\(nsError.code) reason=\(reason)): \(error)")
            debugLog("⛑ Fallback: Foreground timer'lar çalışmaya devam edecek.")
        }
    }
    
    /// Missed timer kontrolü - BGTask tarafından çağrılır
    public func checkMissedTimers() async {
        // One activation can report "active" twice; a concurrent pass would find the
        // same due tasks again.
        guard !isCheckingMissedTimers else { return }
        isCheckingMissedTimers = true
        defer { isCheckingMissedTimers = false }

        guard let container = Self.sharedModelContainer else {
            debugLog("❌ checkMissedTimers: ModelContainer yok")
            return
        }
        
        let context = ModelContext(container)
        let now = Date()
        let descriptor = FetchDescriptor<BackupTask>()
        
        guard let tasks = try? context.fetch(descriptor) else {
            debugLog("❌ checkMissedTimers: Görevler yüklenemedi")
            return
        }
        
        debugLog("🔍 checkMissedTimers: \(tasks.count) görev kontrol ediliyor")
        
        for task in tasks {
            guard !task.isPaused, task.isEnabled else { continue }
            if case .manual = task.frequency { continue }
            // Already running, or the user just started it and its run is about to begin.
            if runningTaskIDs.contains(task.id) { continue }
            if let startedAt = userStartedTaskIDs[task.id], now.timeIntervalSince(startedAt) < 60 { continue }

            if let nextRunTime = task.nextRunTime {
                let timeDiff = now.timeIntervalSince(nextRunTime)
                
                // Timer 2+ dakika geç kalmışsa manuel tetikle. A due task with no pending
                // timer (it fired while the app was inactive and skipped the run) must not
                // wait out that grace period, or opening the app shortly after would miss it.
                let hasPendingTimer = scheduledTimers[task.id] != nil
                // A run waiting for Wi-Fi goes as soon as Wi-Fi is back, not at its next retry.
                let wifiReturned = task.wifiWaitDeadline != nil && isOnWiFi == true
                if timeDiff > 120 || (timeDiff >= 0 && !hasPendingTimer) || wifiReturned {
                    debugLog("⚠️ checkMissedTimers: Kaçırılmış görev tespit edildi: \(task.displayName)")
                    debugLog("   📅 Planlanmış: \(userLocalDateFormatter.string(from: nextRunTime))")
                    debugLog("   📅 Şu anda: \(userLocalDateFormatter.string(from: now))")
                    debugLog("   ⏰ Gecikme: \(String(format: "%.1f", timeDiff)) saniye")
                    
                    // App state kontrol et
                    let isActive: Bool = {
                        return UIApplication.shared.applicationState == .active
                    }()
                    if isActive {
                        if let last = lastRunAtByTask[task.id], Date().timeIntervalSince(last) < minRunInterval {
                            debugLog("ℹ️ checkMissedTimers: Minimum aralık dolmadı, atlanıyor")
                            continue
                        }
                        if isProcessing {
                            debugLog("ℹ️ checkMissedTimers: Aktif işlem var, tetikleme atlandı")
                            continue
                        }
                        debugLog("📱 checkMissedTimers: App aktif - Yedekleme başlatılıyor")
                        // The pending Wi-Fi retry timer would start this run a second time.
                        if wifiReturned { cancelTimer(for: task.id) }
                        try? await performBackup(task: task)
                    } else {
                        if isProcessing {
                            debugLog("ℹ️ checkMissedTimers: App arka planda ama aktif işlem var, tetikleme atlandı")
                            continue
                        }
                        debugLog("🌙 checkMissedTimers: App arka planda - otomatik yedekleme deneniyor")
                        if wifiReturned { cancelTimer(for: task.id) }
                        do {
                            try await performBackup(task: task, bypassThrottle: true)
                        } catch {
                            debugLog("⚠️ checkMissedTimers: Arka plan otomatik yedekleme başarısız, bildirim fallback: \(error)")
                            sendScheduledBackupNotification(for: task)
                        }
                    }
                }
            }
        }
    }

    /// Arka plan görevi tetiklendiğinde çağrılır.
    public func executeBackgroundTask() async -> Bool {
        // Re-entrancy guard: allow only one background execution at a time
        if isProcessing {
            // Another backup is already running (foreground/background). Treat as handled.
            debugLog("ℹ️ BGTaskScheduler: Zaten bir işlem sürüyor, yeni görev başarılı kabul edilerek atlandı")
            return true
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
            debugLog("❌ BGTaskScheduler: ModelContainer yok")
            return false
        }
        let context = ModelContext(container)
        let now = Date()
        let descriptor = FetchDescriptor<BackupTask>()
        guard let tasks = try? context.fetch(descriptor), !tasks.isEmpty else {
            debugLog("ℹ️ BGTaskScheduler: Çalışacak görev yok")
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
            debugLog("⏱️ BGTaskScheduler: Zamanı gelen görev yok, yeniden planlanıyor")
            scheduleAppRefresh()
            scheduleProcessingTask()
            return true
        }
        
        await sendBackgroundTaskStartedNotification(taskCount: dueTasks.count)

        debugLog("🚀 BGTaskScheduler: \(dueTasks.count) görev arka planda yürütülecek")
        
        var anySuccess = false
        for taskToRun in dueTasks {
            activeBackgroundTaskID = taskToRun.id

            
            debugLog("📱 BGTaskScheduler: Arka plan görevi başlatılıyor: \(taskToRun.displayName)")
            do {
                try await performBackup(task: taskToRun, bypassThrottle: true)
                anySuccess = true
                debugLog("✅ BGTaskScheduler: Arka plan görevi başarıyla tamamlandı: \(taskToRun.displayName)")
            } catch {
                debugLog("⚠️ BGTaskScheduler: Arka plan görevi başarısız -> \(taskToRun.displayName) - \(error)")
            }
            if activeBackgroundTaskID == taskToRun.id {
                activeBackgroundTaskID = nil
            }
        }
        
        scheduleAppRefresh()
        scheduleProcessingTask()
        return anySuccess
    }
}

// MARK: - Backup Execution
extension BackupScheduler {
    
    private func executeFTPBackup(task: BackupTask, startTime: Date, options: BackupExecutionOptions = .defaults) async throws -> FTPService.SyncResult {
        debugLog("📡 BackupFlow: FTP yedekleme başlatılıyor...")
        task.backupStatus = task.sourcePath == "PHOTOS_LIBRARY" ? .scanning : .preparing
        task.currentFile = "backup.current_file.preparing".localized
        
        let ftpService = FTPService.shared
        
        // Perform the actual backup using FTPService
            let syncResult = try await ftpService.performBackup(
                host: task.serverHost,
                port: task.serverPort,
                username: task.isAnonymous ? "" : task.serverUsername,
                password: task.isAnonymous ? "" : task.resolvedServerPassword,
                sourcePath: task.sourcePath ?? "",
                destinationPath: task.destinationPath,
                isAnonymous: task.isAnonymous,
                mediaType: task.mediaType,
                includeICloudAssets: task.includeICloudAssets,
                options: options,
                progressHandler: { progress in
                    Task { @MainActor in
                        // NaN kontrolü ile güvenli progress update
                        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                        task.progress = safeProgress
                        task.currentFile = ftpService.currentFile.isEmpty ? "backup.current_file.uploading".localized : ftpService.currentFile
                        task.currentFileProgress = ftpService.progress
                        task.currentFileBytesTransferred = ftpService.currentFileBytesTransferred
                        task.currentFileTotalBytes = ftpService.currentFileTotalBytes
                        task.transferSpeedBytesPerSecond = ftpService.transferSpeedBytesPerSecond
                    }
                }
            )
        
        return syncResult
    }
    
    private func executeWebDAVBackup(task: BackupTask, startTime: Date, options: BackupExecutionOptions = .defaults) async throws -> FTPService.SyncResult {
        debugLog("🌐 BackupFlow: WebDAV yedekleme başlatılıyor...")
        task.backupStatus = .uploading
        
        do {
            // Get WebDAV service instance
            let webDAVService = WebDAVService.shared
            
            // Update UI with connection status
            task.currentFile = "backup.current_file.connecting_webdav".localized
            
            // Configure WebDAV connection parameters
            let username = task.serverUsername.isEmpty ? nil : task.serverUsername
            let resolvedPassword = task.resolvedServerPassword
            let password = resolvedPassword.isEmpty ? nil : resolvedPassword
            
            // Convert host to proper format if needed
            let rawHost = task.serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowerRawHost = rawHost.lowercased()
            let hasScheme = lowerRawHost.hasPrefix("http://") || lowerRawHost.hasPrefix("https://")
            let schemeFromPort: String = {
                if task.serverPort == 5005 || task.serverPort == 80 { return "http" }
                if task.serverPort == 5006 || task.serverPort == 443 { return "https" }
                return "https"
            }()
            let hostWithScheme = hasScheme ? rawHost : "\(schemeFromPort)://\(rawHost)"
            
            // Extract host and port from URL
            guard let url = URL(string: hostWithScheme) else {
                throw NSError(domain: "WebDAV Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "backup.error.invalid_webdav_host".localized])
            }
            
            let hostName = url.host ?? rawHost
            let port = url.port ?? (task.serverPort > 0 ? task.serverPort : ((url.scheme?.lowercased() == "https") ? 443 : 80))
            let path = url.path
            let hostForConnect: String = {
                guard let scheme = url.scheme, let host = url.host else { return hostWithScheme }
                let normalizedPath = (path.isEmpty || path == "/") ? "" : path
                return "\(scheme)://\(host)\(normalizedPath)"
            }()
            
            // Update UI with connection status
            task.currentFile = "backup.current_file.connecting_webdav_host".localized(with: hostName)
            
            // Connect to WebDAV server
            try await webDAVService.connect(
                host: hostForConnect,
                port: port,
                username: username,
                password: password
            )
            
            // Update UI with backup status
            task.currentFile = "backup.current_file.preparing".localized
            
            // Determine source path
            let sourcePathValue = task.sourcePath ?? ""
            let sourcePath = sourcePathValue == "PHOTOS_LIBRARY" ? "PHOTOS_LIBRARY" : sourcePathValue
            
            // Start backup
            let syncResult = try await webDAVService.performBackup(
                host: hostForConnect,
                port: port,
                username: username,
                password: password,
                sourcePath: sourcePath,
                isAnonymous: username == nil,
                mediaType: task.mediaType,
                includeICloudAssets: task.includeICloudAssets,
                options: options,
                progressHandler: { progress in
                    Task { @MainActor in
                        // NaN kontrolü ile güvenli progress update
                        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                        task.progress = safeProgress
                        task.currentFile = webDAVService.currentFile
                        task.currentFileProgress = webDAVService.progress
                        task.currentFileBytesTransferred = webDAVService.currentFileBytesTransferred
                        task.currentFileTotalBytes = webDAVService.currentFileTotalBytes
                        task.transferSpeedBytesPerSecond = webDAVService.transferSpeedBytesPerSecond
                    }
                }
            )
            
            return syncResult
            
        } catch {
            task.backupStatus = .failed
            task.progress = 0.0  // Reset to 0.0 on failure, safe value
            task.currentFile = "backup.current_file.error".localized(with: error.localizedDescription)
            resetCurrentFileProgress(for: task)
            
            debugLog("❌ BackupFlow: WebDAV yedekleme hatası: \(error.localizedDescription)")
            throw error
        }
    }

    private func executeSFTPBackup(task: BackupTask, startTime: Date, options: BackupExecutionOptions = .defaults) async throws -> FTPService.SyncResult {
        debugLog("🔐 BackupFlow: SFTP yedekleme başlatılıyor...")
        let effectiveDestination: String = {
            let trimmed = task.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "/" {
                return trimmed
            }
            if (task.sourcePath ?? "") == "PHOTOS_LIBRARY" {
                return "photos"
            }
            let sourceFolder = URL(fileURLWithPath: task.sourcePath ?? "").lastPathComponent
            let safeSourceFolder = sourceFolder.trimmingCharacters(in: .whitespacesAndNewlines)
            return safeSourceFolder.isEmpty ? "backup" : safeSourceFolder
        }()
        debugLog("🔐 BackupFlow: SFTP hedef dizin (effective): \(effectiveDestination)")
        debugLog("🔐 BackupFlow: SFTP kaynak: \(task.sourcePath ?? "")")
        task.backupStatus = .uploading
        
        do {
            let sftpService = SFTPService.shared
            task.currentFile = "backup.current_file.connecting_sftp".localized
            
            let syncResult = try await sftpService.performBackup(
                host: task.serverHost,
                port: task.serverPort,
                username: task.serverUsername,
                password: task.resolvedServerPassword,
                sourcePath: task.sourcePath ?? "",
                destinationPath: task.destinationPath,
                mediaType: task.mediaType,
                options: options,
                progressHandler: { progress in
                    Task { @MainActor in
                        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                        task.progress = safeProgress
                        task.currentFile = sftpService.currentFile.isEmpty ? "backup.current_file.uploading".localized : sftpService.currentFile
                        task.currentFileProgress = sftpService.progress
                        task.currentFileBytesTransferred = sftpService.currentFileBytesTransferred
                        task.currentFileTotalBytes = sftpService.currentFileTotalBytes
                        task.transferSpeedBytesPerSecond = sftpService.transferSpeedBytesPerSecond
                    }
                }
            )
            
            return syncResult
        } catch {
            task.backupStatus = .failed
            task.progress = 0.0
            task.currentFile = "backup.current_file.error".localized(with: error.localizedDescription)
            resetCurrentFileProgress(for: task)
            debugLog("❌ BackupFlow: SFTP yedekleme hatası: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func resetCurrentFileProgress(for task: BackupTask) {
        task.currentFileProgress = 0
        task.currentFileBytesTransferred = 0
        task.currentFileTotalBytes = 0
        task.transferSpeedBytesPerSecond = 0
    }

    /// Conditions other than Wi-Fi, which performBackup handles through `waitForWiFi`.
    private func blockedReason(for task: BackupTask, options: BackupExecutionOptions) async -> String? {
        if options.requiresExternalPower {
            let batteryState = BatteryManager.shared.batteryState
            if batteryState != .charging && batteryState != .full {
                return "backup.defer.external_power_required".localized
            }
        }

        if let batteryReason = BatteryManager.shared.getReasonForBlockedBackup() {
            return batteryReason
        }

        if let start = options.allowedStartTime, let end = options.allowedEndTime, !isNowWithinAllowedWindow(start: start, end: end) {
            return "backup.defer.outside_allowed_window".localized
        }

        return nil
    }

    private func isNowWithinAllowedWindow(start: ScheduleTime, end: ScheduleTime, now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startMinute = start.hour * 60 + start.minute
        let endMinute = end.hour * 60 + end.minute

        if startMinute == endMinute {
            return true
        }
        if startMinute < endMinute {
            return currentMinute >= startMinute && currentMinute <= endMinute
        }
        return currentMinute >= startMinute || currentMinute <= endMinute
    }

    private func categorizeFailure(_ error: Error) -> BackupFailureCategory {
        if let backupError = error as? BackupServiceError, case .cancelled = backupError {
            return .cancelled
        }

        let message = error.localizedDescription.lowercased()
        if message.contains("auth") || message.contains("password") || message.contains("credential") || message.contains("login") {
            return .auth
        }
        if message.contains("permission") || message.contains("denied") || message.contains("not allowed") {
            return .permission
        }
        if message.contains("network") || message.contains("internet") || message.contains("offline") || message.contains("timed out") {
            return .network
        }
        if message.contains("quota") || message.contains("space") || message.contains("disk") {
            return .quota
        }
        if message.contains("icloud") || message.contains("cloud") {
            return .iCloud
        }
        if message.contains("certificate") || message.contains("host key") || message.contains("ssl") || message.contains("tls") {
            return .certificate
        }
        if message.contains("server") || message.contains("host") || message.contains("response") {
            return .server
        }
        return .unknown
    }

    private func verifiedFileCount(syncResult: FTPService.SyncResult) -> Int {
        syncResult.verifiedFiles
    }

    /// Detaylı yedekleme tamamlanma bildirimi gönder
    private func sendBackupCompletionNotification(task: BackupTask, syncResult: FTPService.SyncResult) async {
        guard await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "backup.completed.notification.title".localized
        content.body = "backup.completed.notification.body".localized(with: task.displayName, syncResult.newFiles, syncResult.updatedFiles, syncResult.skippedFiles, syncResult.deletedFiles, syncResult.totalProcessed)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "backup_completed_\(task.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            debugLog("🔔 BackupFlow: Detaylı yedekleme bildirimi gönderildi")
        } catch {
            debugLog("❌ BackupFlow: Bildirim gönderme hatası: \(error)")
        }
    }
    
    /// Backup history record oluştur
    private func createBackupHistoryRecord(
        task: BackupTask,
        syncResult: FTPService.SyncResult,
        duration: TimeInterval,
        status: String,
        errorMessage: String? = nil,
        failureCategory: BackupFailureCategory? = nil,
        previewSummarySnapshot: String? = nil
    ) async {
        guard let container = Self.sharedModelContainer else { return }

        // Cancelled and failed runs pass an empty result; record what was actually
        // uploaded before they stopped. "Transferred" counts uploads only, not files
        // that were already on the server.
        var syncResult = syncResult
        let tally = BackupRunTally.shared
        if syncResult.totalProcessed == 0 && tally.uploadedFiles > 0 {
            syncResult.newFiles = tally.uploadedFiles
            syncResult.totalBytes = tally.uploadedBytes
        }
        let uploadedBytes = tally.uploadedBytes

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
                bytesTransferred: uploadedBytes,
                totalBytes: syncResult.totalBytes,
                errorMessage: errorMessage,
                duration: duration,
                skippedFiles: syncResult.skippedFiles,
                deletedFiles: syncResult.deletedFiles,
                newFiles: syncResult.newFiles,
                updatedFiles: syncResult.updatedFiles,
                verifiedFiles: verifiedFileCount(syncResult: syncResult),
                failureCategory: failureCategory,
                previewSummarySnapshot: previewSummarySnapshot,
                taskDisplayName: task.displayName,
                taskSourcePath: task.sourcePath,
                taskServerHost: task.serverHost,
                taskServerPort: task.serverPort,
                taskUsername: task.serverUsername,
                taskIsAnonymous: task.isAnonymous,
                taskMediaTypeRaw: task.mediaType.rawValue
            )

            context.insert(historyRecord)
            // Attach the task to the history record
            historyRecord.task = task

            do {
                // In many cases, appending to a relationship is enough; insert is optional
                try context.save()
                HistoryRetentionManager.pruneIfNeeded(context: context)
                debugLog("📝 BackupFlow: Geçmiş kaydı eklendi - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
            } catch {
                debugLog("❌ BackupFlow: Geçmiş kaydı hatası (taskContext): \(error)")
            }
            return
        }

        // Fallback: no task.modelContext (edge case). Use a new context and refetch task in that context.
        let context = ModelContext(container)
        do {
            let fetch = FetchDescriptor<BackupTask>()
            guard let taskInContext = try context.fetch(fetch).first(where: { $0.id == task.id }) else {
                debugLog("❌ BackupFlow: Geçmiş kaydı için görev bulunamadı (refetch failed)")
                return
            }

            let historyRecord = BackupHistory(
                id: UUID(),
                timestamp: Date(),
                status: status,
                filesProcessed: syncResult.totalProcessed,
                totalFiles: syncResult.totalProcessed,
                bytesTransferred: uploadedBytes,
                totalBytes: syncResult.totalBytes,
                errorMessage: errorMessage,
                duration: duration,
                skippedFiles: syncResult.skippedFiles,
                deletedFiles: syncResult.deletedFiles,
                newFiles: syncResult.newFiles,
                updatedFiles: syncResult.updatedFiles,
                verifiedFiles: verifiedFileCount(syncResult: syncResult),
                failureCategory: failureCategory,
                previewSummarySnapshot: previewSummarySnapshot,
                taskDisplayName: taskInContext.displayName,
                taskSourcePath: taskInContext.sourcePath,
                taskServerHost: taskInContext.serverHost,
                taskServerPort: taskInContext.serverPort,
                taskUsername: taskInContext.serverUsername,
                taskIsAnonymous: taskInContext.isAnonymous,
                taskMediaTypeRaw: taskInContext.mediaType.rawValue
            )

            context.insert(historyRecord)
            historyRecord.task = taskInContext

            try context.save()
            HistoryRetentionManager.pruneIfNeeded(context: context)
            debugLog("📝 BackupFlow: Geçmiş kaydı eklendi (refetched) - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
        } catch {
            debugLog("❌ BackupFlow: Geçmiş kaydı hatası (refetch): \(error)")
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
        content.title = "backup.background_task.started.title".localized
        content.body = "backup.background_task.started.body".localized(with: taskCount)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "bg_task_started",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            lastBGTaskNotificationAt = Date()
            debugLog("🔔 BackupFlow: BGTask başlangıç bildirimi gönderildi")
        } catch {
            debugLog("❌ BackupFlow: BGTask başlangıç bildirimi hatası: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension BackupScheduler {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // While the app is open the in-app timer starts the backup itself, so a
        // "time to back up" reminder would only ask for something already happening.
        if notification.request.identifier.hasPrefix("scheduled-backup-") {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        debugLog("🔔 BackupFlow: Bildirime tıklandı - ID: \(identifier), Action: \(actionIdentifier)")
        
        // Bildirim okunduğunda badge'i temizle
        Task {
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            } catch {
                debugLog("❌ BackupFlow: Badge temizleme hatası: \(error)")
            }
        }

        guard identifier.hasPrefix("scheduled-backup-"),
              let taskId = UUID(uuidString: String(identifier.dropFirst("scheduled-backup-".count))) else {
            completionHandler()
            return
        }

        switch actionIdentifier {
        case "START_BACKUP_ACTION":
            // The action opens the app; start once it is active so the run counts as
            // user-initiated and can continue in the background.
            pendingStartTaskID = taskId
            if UIApplication.shared.applicationState == .active {
                startPendingNotificationBackup()
            }
        case "OPEN_DETAILS_ACTION":
            requestedDetailTaskID = taskId
        case "POSTPONE_1H_ACTION":
            Task {
                await self.postponeTask(taskId: taskId, interval: 3600)
            }
        case "CANCEL_BACKUP_ACTION":
            skipScheduledRun(taskId: taskId)
        default:
            break
        }
        
        completionHandler()
    }

    /// Starts the backup requested from a reminder's "Start" action. Called when the app
    /// becomes active, since continued processing requests must come from the foreground.
    public func startPendingNotificationBackup() {
        guard let taskId = pendingStartTaskID else { return }
        pendingStartTaskID = nil
        guard let task = fetchMainContextTask(id: taskId) else {
            debugLog("❌ BackupFlow: Bildirimdeki görev bulunamadı: \(taskId)")
            return
        }
        let isRunning = task.backupStatus == .preparing || task.backupStatus == .scanning || task.backupStatus == .uploading
        guard !isRunning else { return }
        if needsWiFiConfirmation(for: task) {
            // The dashboard asks whether to start without Wi-Fi.
            wifiConfirmationTaskID = task.id
            return
        }
        debugLog("▶️ BackupFlow: Bildirimden yedekleme başlatılıyor: \(task.displayName)")
        startUserInitiatedBackup(task: task)
    }

    /// "Cancel" on a reminder skips this occurrence and moves on to the next scheduled one.
    private func skipScheduledRun(taskId: UUID) {
        guard let task = fetchMainContextTask(id: taskId) else { return }
        task.wifiWaitDeadline = nil
        task.nextRunTime = calculateNextRunTime(for: task)
        try? task.modelContext?.save()
        rearmTimer(for: task)
        refreshReminder(for: task)
        scheduleProcessingTask()
        debugLog("⏭️ BackupFlow: Zamanlanmış çalıştırma atlandı: \(task.displayName)")
    }

    /// Uses the UI's main context so progress from a user-started run shows up live.
    private func fetchMainContextTask(id: UUID) -> BackupTask? {
        guard let container = Self.sharedModelContainer else { return nil }
        var descriptor = FetchDescriptor<BackupTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? container.mainContext.fetch(descriptor).first
    }

    private func postponeTask(taskId: UUID, interval: TimeInterval) async {
        guard let container = Self.sharedModelContainer else { return }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BackupTask>(
            predicate: #Predicate { $0.id == taskId }
        )
        descriptor.fetchLimit = 1

        guard let task = try? context.fetch(descriptor).first else { return }
        task.nextRunTime = Date().addingTimeInterval(interval)
        do {
            try context.save()
            rearmTimer(for: task)
            refreshReminder(for: task)
            scheduleAppRefresh()
            scheduleProcessingTask()
            debugLog("⏰ BackupFlow: Görev 1 saat ertelendi: \(task.displayName)")
        } catch {
            debugLog("❌ BackupFlow: Görev erteleme kaydedilemedi: \(error)")
        }
    }
    
    // MARK: - Network Detection Helpers
    
    /// Local server IP adresini kontrol eder
    private func isLocalServer(host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostToCheck: String = {
            guard !trimmed.isEmpty else { return trimmed }
            if let parsedHost = URL(string: trimmed)?.host {
                return parsedHost.lowercased()
            }
            return trimmed.lowercased()
        }()

        // Local IP ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x, localhost
        let localPatterns = [
            "^192\\.168\\.",
            "^10\\.",
            "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",
            "^127\\.",
            "localhost"
        ]
        
        return localPatterns.contains { pattern in
            hostToCheck.range(of: pattern, options: .regularExpression) != nil
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

