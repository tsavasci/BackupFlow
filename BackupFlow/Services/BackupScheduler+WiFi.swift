
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
    // MARK: - Wi-Fi Wait

    func startWiFiMonitoring() {
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
    func waitForWiFi(task: BackupTask) async {
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
                notifier.sendWaitingForWiFiNotification(for: task)
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
            notifier.removeDeliveredWaitingForWiFiNotification(forTaskID: task.id)
            try? task.modelContext?.save()
            BackupHistoryRecorder.record(
                for: task,
                syncResult: Self.emptySyncResult,
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
}
