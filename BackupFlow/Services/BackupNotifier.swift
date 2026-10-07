import Foundation
import UserNotifications

/// Builds, sends and removes the app's local notifications: reminders for scheduled
/// FTP/SFTP runs and notices about Wi-Fi waits, missing network, interrupted, completed
/// and background runs. Deciding *when* to notify stays with BackupScheduler, which is
/// also the notification center's delegate.
@MainActor
final class BackupNotifier {
    static let shared = BackupNotifier()

    /// Last "time to back up" notice per task; it is not repeated within two minutes.
    private var lastScheduledNoticeAt: [UUID: Date] = [:]
    /// Last "background task started" notice; sent at most every five minutes.
    private var lastBackgroundTaskNoticeAt: Date?

    private var center: UNUserNotificationCenter { .current() }

    /// Same format as BackupScheduler's log timestamps; kept here so the notifier
    /// doesn't reach back into the scheduler.
    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()

    private init() {}

    // MARK: - Identifiers

    static let reminderIdentifierPrefix = "scheduled-backup-"

    static func reminderIdentifier(for taskID: UUID) -> String {
        "\(reminderIdentifierPrefix)\(taskID)"
    }

    static func wifiWaitNotificationIdentifier(for taskID: UUID) -> String {
        "wifi-wait-\(taskID)"
    }

    // MARK: - Scheduled-Run Reminders

    /// Zamanı gelen görev için bildirim gönderir (action button ile)
    func sendScheduledBackupNotification(for task: BackupTask) {
        // Son bildirimin üzerinden yeterli süre geçmediyse tekrarlama (debounce)
        if let last = lastScheduledNoticeAt[task.id], Date().timeIntervalSince(last) < 120 {
            debugLog("ℹ️ BackupFlow: Yakın zamanda aynı görev için bildirim gönderilmiş, tekrar edilmiyor")
            return
        }

        // Hemen gönder: önce aynı kimlikli pending ve delivered bildirimleri temizle
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier(for: task.id),
            content: makeScheduledBackupContent(for: task),
            trigger: nil
        )
        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [request.identifier])
        center.add(request)
        debugLog("🔔 BackupFlow: Zamanlanmış yedekleme bildirimi gönderildi: \(task.displayName)")
        lastScheduledNoticeAt[task.id] = Date()
    }

    /// Keeps a reminder queued in the system for the task's next FTP/SFTP run.
    ///
    /// iOS can't start FTP/SFTP at an exact time in the background, and never launches a
    /// force-quit app for background tasks. A notification scheduled with the system is
    /// delivered regardless, and its "Start" action opens the app so the backup can run
    /// as a user-initiated continued processing task.
    func refreshReminder(for task: BackupTask) {
        let identifier = Self.reminderIdentifier(for: task.id)
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
        debugLog("⏰ BackupFlow: Hatırlatma planlandı: \(task.displayName) -> \(logDateFormatter.string(from: fireDate))")
    }

    /// Removes the task's queued and shown reminders, e.g. when it is paused or deleted.
    func removeReminder(forTaskID taskID: UUID) {
        let identifier = Self.reminderIdentifier(for: taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        lastScheduledNoticeAt[taskID] = nil
    }

    /// Clears notices that would offer to start a run that has just finished.
    func removeDeliveredRunPrompts(forTaskID taskID: UUID) {
        center.removeDeliveredNotifications(withIdentifiers: [
            Self.reminderIdentifier(for: taskID),
            Self.wifiWaitNotificationIdentifier(for: taskID)
        ])
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
        if Self.isLocalServer(host: task.serverHost) {
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

    /// Local server IP adresini kontrol eder
    private static func isLocalServer(host: String) -> Bool {
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

    // MARK: - Wi-Fi Wait

    /// One notice when a scheduled FTP/SFTP run starts waiting for Wi-Fi, instead of a
    /// reminder at every retry.
    func sendWaitingForWiFiNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.wifi_wait.title".localized
        content.body = String(format: "backup.wifi_wait.body".localized, task.displayName)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.wifiWaitNotificationIdentifier(for: task.id),
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func removeDeliveredWaitingForWiFiNotification(forTaskID taskID: UUID) {
        center.removeDeliveredNotifications(withIdentifiers: [Self.wifiWaitNotificationIdentifier(for: taskID)])
    }

    // MARK: - Run Notices

    /// Tells the user iOS stopped an FTP/SFTP run before it finished, so opening the app
    /// (or tapping the reminder) is needed to continue; the sync resumes where it left off.
    func sendBackgroundInterruptedNotification(for task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.background_interrupted.title".localized
        content.body = String(format: "backup.background_interrupted.body".localized, task.displayName)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "background-interrupted-\(task.id)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    /// Sends a no-network retry notification like: "Ağ bağlantısı yok. Tekrar denenecek 1/3"
    func sendNoNetworkRetryNotification(task: BackupTask, attempt: Int, maxAttempts: Int, delaySeconds: TimeInterval) {
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
        center.add(request) { error in
            if let error = error { debugLog("❌ BackupFlow: No-network retry bildirimi hatası: \(error)") }
        }
    }

    /// Sends a final postponement notification
    func sendPostponedDueToNoNetworkNotification(task: BackupTask) {
        let content = UNMutableNotificationContent()
        content.title = "backup.network_postponed.title".localized
        content.body = "backup.network_postponed.body".localized
        content.sound = .default
        let request = UNNotificationRequest(identifier: "no-network-postponed-\(task.id)", content: content, trigger: nil)
        center.add(request) { error in
            if let error = error { debugLog("❌ BackupFlow: Erteleme bildirimi hatası: \(error)") }
        }
    }

    /// Detaylı yedekleme tamamlanma bildirimi gönder
    func sendBackupCompletionNotification(task: BackupTask, syncResult: FTPService.SyncResult) async {
        guard await center.notificationSettings().authorizationStatus == .authorized else {
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
            try await center.add(request)
            debugLog("🔔 BackupFlow: Detaylı yedekleme bildirimi gönderildi")
        } catch {
            debugLog("❌ BackupFlow: Bildirim gönderme hatası: \(error)")
        }
    }

    /// BGTask tetiklendiğinde kullanıcıya bildirim gönderir (debounced).
    func sendBackgroundTaskStartedNotification(taskCount: Int) async {
        guard await center.notificationSettings().authorizationStatus == .authorized else {
            return
        }
        if let last = lastBackgroundTaskNoticeAt, Date().timeIntervalSince(last) < 300 {
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
            try await center.add(request)
            lastBackgroundTaskNoticeAt = Date()
            debugLog("🔔 BackupFlow: BGTask başlangıç bildirimi gönderildi")
        } catch {
            debugLog("❌ BackupFlow: BGTask başlangıç bildirimi hatası: \(error)")
        }
    }
}
