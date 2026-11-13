
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

extension BackupScheduler {
    // MARK: - Notifications
    func setupNotifications() {
        // Delegate sadece burada atanır. İzin isteği AppDelegate tarafından yönetilir.
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - No Network

    /// Handles no-network scenario with 3 attempts: 1 min, then 5 min, then postpone by 24h.
    func handleNoNetworkFor(task: BackupTask) async {
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
            notifier.sendNoNetworkRetryNotification(task: task, attempt: nextAttempt, maxAttempts: maxAttempts, delaySeconds: 60)
            task.nextRunTime = Date().addingTimeInterval(60)
            if let context = task.modelContext { try? context.save() }
            scheduleProcessingTask()
            return
        } else if nextAttempt == 2 {
            notifier.sendNoNetworkRetryNotification(task: task, attempt: nextAttempt, maxAttempts: maxAttempts, delaySeconds: 300)
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
        notifier.sendPostponedDueToNoNetworkNotification(task: task)
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
        BackupHistoryRecorder.record(
            for: task,
            syncResult: Self.emptySyncResult,
            duration: 0,
            status: "failed",
            errorMessage: postponedMessage,
            failureCategory: .network
        )

        // Re-schedule background tasks
        scheduleAppRefresh()
        scheduleProcessingTask()
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // While the app is open the in-app timer starts the backup itself, so a
        // "time to back up" reminder would only ask for something already happening.
        if notification.request.identifier.hasPrefix(BackupNotifier.reminderIdentifierPrefix) {
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

        let prefix = BackupNotifier.reminderIdentifierPrefix
        guard identifier.hasPrefix(prefix),
              let taskId = UUID(uuidString: String(identifier.dropFirst(prefix.count))) else {
            completionHandler()
            return
        }

        switch actionIdentifier {
        case "START_BACKUP_ACTION", UNNotificationDefaultActionIdentifier:
            // Opening or tapping "Start" on the reminder brings the app active so the run
            // counts as user-initiated and can continue in the background.
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
        notifier.refreshReminder(for: task)
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
            notifier.refreshReminder(for: task)
            scheduleAppRefresh()
            scheduleProcessingTask()
            debugLog("⏰ BackupFlow: Görev 1 saat ertelendi: \(task.displayName)")
        } catch {
            debugLog("❌ BackupFlow: Görev erteleme kaydedilemedi: \(error)")
        }
    }
}
