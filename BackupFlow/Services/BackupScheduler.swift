
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

@MainActor
final class BackupScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    
    // MARK: - Singleton & Properties
    static let shared = BackupScheduler()
    
    // Shared ModelContainer - uygulamadan inject edilecek
    static var sharedModelContainer: ModelContainer?
    
    /// Sends and removes the app's local notifications.
    let notifier = BackupNotifier.shared

    var retryCount: [UUID: Int] = [:]
    
    private var lastScheduledTargetTime: [UUID: Date] = [:]
    
    var lastRunAtByTask: [UUID: Date] = [:]
    let minRunInterval: TimeInterval = 60 // en az 60 sn arayla çalıştır
    private var activeBackgroundTaskID: UUID?
    var backgroundExpirationTaskIDs: Set<UUID> = []
    
    @Published var isProcessing = false
    /// Task whose details a notification action asked to open; the dashboard presents it.
    @Published var requestedDetailTaskID: UUID?
    /// Task a reminder's "Start" action asked to run once the app is active.
    var pendingStartTaskID: UUID?
    /// Tasks with a run in progress. Several paths can start the same task at once
    /// (a notification action, checkMissedTimers, a timer); only the first one runs.
    var runningTaskIDs: Set<UUID> = []
    /// Tasks the user just started whose run hasn't begun yet. On a device that start
    /// goes through a continued processing task that launches a moment later;
    /// checkMissedTimers leaves these alone so that the run which can keep going in
    /// the background is the one that happens.
    var userStartedTaskIDs: [UUID: Date] = [:]
    private var isCheckingMissedTimers = false
    /// Tasks the user chose to start without Wi-Fi despite their Wi-Fi requirement, with
    /// when they confirmed. The run that follows consumes the entry.
    var wifiOverrideTaskIDs: [UUID: Date] = [:]
    /// A reminder's "Start" reached a task that needs Wi-Fi while there is none;
    /// the dashboard asks whether to start it anyway.
    @Published var wifiConfirmationTaskID: UUID?
    /// Watches for Wi-Fi so runs waiting for it start as soon as it is back.
    let wifiPathMonitor = NWPathMonitor()
    /// Latest state from `wifiPathMonitor`; nil until its first update.
    var isOnWiFi: Bool?
    /// How long a scheduled run may wait for Wi-Fi before it is skipped.
    let maxWiFiWait: TimeInterval = 6 * 60 * 60
    let wifiRetryInterval: TimeInterval = 15 * 60
    
    // Timers keyed by BackupTask.id
    @MainActor private var scheduledTimers: [UUID: Timer] = [:]
    
    lazy var userLocalDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        f.timeZone = TimeZone.current  // Kullanıcının yerel saati
        f.locale = Locale.current       // Kullanıcının yerel ayarı
        return f
    }()
    
    let maxRetryAttempts = 3

    private let baseRetryDelay: TimeInterval = 300
    func jitteredDelay(for attempt: Int) -> TimeInterval {
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
            let pending = requests.first { $0.identifier == id }
            let hasPending = pending != nil
            let pendingBeginDate = pending?.earliestBeginDate
            Task { @MainActor in
                BackupScheduler.shared.handleProcessingPendingCheck(
                    hasPending: hasPending,
                    pendingBeginDate: pendingBeginDate,
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
        pendingBeginDate: Date?,
        identifier: String,
        earliestBeginDate: Date?,
        requireExternal: Bool
    ) {
        if hasPending {
            // Keep the pending request unless a task now needs to run earlier than it
            // allows (e.g. its time was moved forward). Replacing it with a later date
            // would only push the next background run further out.
            guard let newDate = earliestBeginDate,
                  let pendingDate = pendingBeginDate,
                  newDate.addingTimeInterval(60) < pendingDate else {
                debugLog("ℹ️ BGTaskScheduler: Processing görevi zaten pending, yeniden planlama atlandı")
                return
            }
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            debugLog("🔁 BGTaskScheduler: Bekleyen processing görevi daha erken tarihe alınıyor: \(userLocalDateFormatter.string(from: pendingDate)) -> \(userLocalDateFormatter.string(from: newDate))")
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
        notifier.removeReminder(forTaskID: task.id)
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
        notifier.refreshReminder(for: task)
        debugLog("⏱️ BGTaskScheduler: Süresi dolan aktif yedek iptal edildi: \(task.displayName)")
    }
    
    /// Entry point for backups the user starts explicitly (buttons, notification actions).
    /// FTP/SFTP runs go through a continued processing task when available so they keep
    /// running after the app is backgrounded; everything else runs directly as before.
    /// - Parameters:
    ///   - task: The backup task to run.
    ///   - ignoreWiFiRequirement: The user confirmed starting this run without Wi-Fi.
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
        notifier.refreshReminder(for: task)
        
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
    func rearmTimer(for task: BackupTask) {
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

        let isActive = UIApplication.shared.applicationState == .active

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
                // A timer that came due while the app was suspended fires the moment anything
                // wakes the app, including a notification response, before that response is
                // handled. Starting here would run an FTP/SFTP backup the user just skipped
                // with the reminder's "Cancel"; for those, checkMissedTimers runs the task
                // once the app comes forward, and the reminder covers the background.
                // WebDAV has no reminder, so its timer still runs in the background.
                if !isActive, taskToRun.backupType != .webdav {
                    debugLog("ℹ️ BackupFlow: Uygulama aktif değil; zamanlayıcı yedeği başlatmadı: \(taskToRun.displayName)")
                    return
                }
                // The run was skipped or postponed after this timer was armed.
                if let nextRunTime = taskToRun.nextRunTime, nextRunTime.timeIntervalSinceNow > 10 {
                    debugLog("ℹ️ BackupFlow: Görevin zamanı ileri alınmış; zamanlayıcı yedeği başlatmadı: \(taskToRun.displayName)")
                    return
                }
                debugLog("▶️ BackupFlow: Timer'dan yedekleme başlatılıyor: \(taskToRun.displayName)")
                try? await performBackup(task: taskToRun)
            } else {
                debugLog("❌ BackupFlow: Timer tetiklendi ancak görev veritabanında bulunamadı: \(taskId)")
            }
        }
    }

    // MARK: - Helper Methods
    func calculateNextRunTime(for task: BackupTask) -> Date? {
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
                            notifier.sendScheduledBackupNotification(for: task)
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
        
        await notifier.sendBackgroundTaskStartedNotification(taskCount: dueTasks.count)

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
