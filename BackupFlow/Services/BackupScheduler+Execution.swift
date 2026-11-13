
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
        defer { notifier.refreshReminder(for: task) }
        let runStart = Date()

        guard let executionOptions = await preparedExecutionOptions(
            for: task,
            runStart: runStart,
            bypassThrottle: bypassThrottle
        ) else { return }

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
        markRunStarting(task)

        do {
            let syncResult = try await runBackup(task: task, options: executionOptions)
            await handleBackupSuccess(task: task, syncResult: syncResult, runStart: runStart)
        } catch BackupServiceError.cancelled {
            await handleBackupCancellation(task: task, runStart: runStart)
        } catch {
            await handleBackupFailure(task: task, error: error, options: executionOptions, runStart: runStart)
        }
    }

    public func previewBackup(task: BackupTask) async throws -> BackupPreviewResult {
        let options = BackupExecutionOptions.forTask(task, isDryRun: true)
        let syncResult = try await runBackup(task: task, options: options)
        task.backupStatus = .idle
        clearRunProgress(for: task)
        return BackupPreviewResult.fromSyncResult(syncResult, deletionPolicy: options.deletionPolicy)
    }

    // MARK: - Backup Run Phases

    /// Placeholder result for runs that transferred nothing (deferred, cancelled, failed).
    static let emptySyncResult = FTPService.SyncResult(newFiles: 0, skippedFiles: 0, totalBytes: 0)

    /// Checks every precondition for starting a run, in order: Wi-Fi requirement,
    /// battery/time-window conditions, throttle, pause state and connectivity.
    /// - Returns: The options to run with, or `nil` if the run must not start now.
    ///   Each blocked path has already handled its own follow-up (waiting, deferring, retrying).
    private func preparedExecutionOptions(
        for task: BackupTask,
        runStart: Date,
        bypassThrottle: Bool
    ) async -> BackupExecutionOptions? {
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
                return nil
            }
            task.wifiWaitDeadline = nil
        }

        if let blockReason = await blockedReason(for: task, options: executionOptions) {
            debugLog("⏸️ BackupFlow: Görev koşullar nedeniyle ertelendi: \(blockReason)")
            task.lastError = blockReason
            task.nextRunTime = Date().addingTimeInterval(15 * 60)
            BackupHistoryRecorder.record(
                for: task,
                syncResult: Self.emptySyncResult,
                duration: 0,
                status: "deferred",
                errorMessage: blockReason,
                failureCategory: .network
            )
            return nil
        }

        // Re-entrancy guard: Çok sık tetiklemeyi engelle
        if !bypassThrottle {
            if let last = lastRunAtByTask[task.id], Date().timeIntervalSince(last) < minRunInterval {
                debugLog("ℹ️ BackupFlow: Son çalıştırmadan bu yana minimum süre dolmadı, tetikleme atlandı")
                return nil
            }
            lastRunAtByTask[task.id] = runStart
        }

        guard !task.isPaused else {
            debugLog("⏸️ BackupFlow: Görev duraklatılmış, yedekleme atlanıyor: \(task.displayName)")
            return nil
        }

        // Fail-safe: if no internet at start, handle staged retries
        guard await getCurrentNetworkType().isOnline else {
            debugLog("⚠️ BackupFlow: Ağ bağlantısı yok - failsafe devrede")
            await handleNoNetworkFor(task: task)
            return nil
        }

        return executionOptions
    }

    /// Sets the initial run state without resetting progress of a run already uploading.
    private func markRunStarting(_ task: BackupTask) {
        if task.backupStatus != .uploading {
            task.backupStatus = .preparing
        }
        if task.progress <= 0.0 || task.progress.isNaN || task.progress.isInfinite {
            task.progress = 0.0
            resetCurrentFileProgress(for: task)
        }
        task.lastError = nil

        BackupLiveActivityManager.shared.start(
            taskName: task.displayName,
            protocolName: task.backupType.rawValue,
            statusText: "backup.status.preparing".localized
        )
        WidgetSnapshotProgressThrottle.reset(initialProgress: task.progress)
        BackupWidgetSnapshotStore.save(
            makeWidgetSnapshot(
                for: task,
                status: "running",
                activeTaskName: task.displayName,
                activeProgress: task.progress,
                activeFileName: task.currentFile
            )
        )
    }

    /// Runs the backup (or dry run) through the service matching the task's protocol.
    private func runBackup(task: BackupTask, options: BackupExecutionOptions) async throws -> FTPService.SyncResult {
        switch task.backupType {
        case .ftp:
            return try await executeFTPBackup(task: task, startTime: Date(), options: options)
        case .sftp:
            return try await executeSFTPBackup(task: task, startTime: Date(), options: options)
        case .webdav:
            return try await executeWebDAVBackup(task: task, startTime: Date(), options: options)
        }
    }

    /// Resets the per-run progress shown in the UI.
    private func clearRunProgress(for task: BackupTask) {
        task.progress = 0.0
        task.currentFile = nil
        resetCurrentFileProgress(for: task)
    }

    private func handleBackupSuccess(task: BackupTask, syncResult: FTPService.SyncResult, runStart: Date) async {
        task.backupStatus = .completed
        task.progress = 1.0
        task.lastBackupDate = Date()
        task.currentFile = nil
        resetCurrentFileProgress(for: task)
        task.lastFailureCategory = nil
        task.consecutiveFailureCount = 0
        task.nextRunTime = calculateNextRunTime(for: task)

        // This run is done; a still-visible reminder for it would only start a duplicate.
        notifier.removeDeliveredRunPrompts(forTaskID: task.id)

        BackupHistoryRecorder.record(
            for: task,
            syncResult: syncResult,
            duration: Date().timeIntervalSince(runStart),
            status: "completed"
        )
        await notifier.sendBackupCompletionNotification(task: task, syncResult: syncResult)

        BackupLiveActivityManager.shared.end(
            statusText: "backup.status.completed".localized,
            success: true
        )
        BackupWidgetSnapshotStore.save(
            makeWidgetSnapshot(
                for: task,
                status: "completed",
                activeProgress: 1.0,
                syncResult: syncResult
            )
        )

        debugLog("✅ BackupFlow: Yedekleme tamamlandı: \(task.displayName)")
    }

    /// Handles a run stopped by the user or by background time expiring.
    /// System expiration reschedules soon; a user cancellation moves on to the next scheduled run.
    private func handleBackupCancellation(task: BackupTask, runStart: Date) async {
        let message = BackupServiceError.cancelled.localizedDescription
        let expiredBySystem = backgroundExpirationTaskIDs.remove(task.id) != nil
            || (task.backupType == .ftp && FTPService.shared.consumeBackgroundExpiration())
            || (task.backupType == .sftp && SFTPService.shared.consumeBackgroundExpiration())
        task.backupStatus = .cancelled
        task.lastError = message
        clearRunProgress(for: task)
        task.nextRunTime = expiredBySystem
            ? Date().addingTimeInterval(15 * 60)
            : calculateNextRunTime(for: task)

        BackupLiveActivityManager.shared.end(
            statusText: "backup.status.cancelled".localized,
            success: false
        )
        BackupWidgetSnapshotStore.save(
            makeWidgetSnapshot(
                for: task,
                status: "cancelled",
                activeProgress: 0.0
            )
        )

        BackupHistoryRecorder.record(
            for: task,
            syncResult: Self.emptySyncResult,
            duration: Date().timeIntervalSince(runStart),
            status: "interrupted",
            errorMessage: message,
            failureCategory: .cancelled
        )

        if expiredBySystem {
            scheduleProcessingTask()
            notifier.sendBackgroundInterruptedNotification(for: task)
            debugLog("⏱️ BackupFlow: Arka plan süresi dolduğu için yedekleme ertelendi: \(task.displayName)")
        } else {
            debugLog("⏸️ BackupFlow: Yedekleme yarıda kesildi: \(task.displayName)")
        }
    }

    /// Handles a failed run: lost connectivity goes back to waiting, anything else
    /// is recorded as a failure and retried (scheduled tasks only).
    private func handleBackupFailure(
        task: BackupTask,
        error: Error,
        options: BackupExecutionOptions,
        runStart: Date
    ) async {
        let currentType = await getCurrentNetworkType()

        // Wi-Fi dropped during a run that requires it: wait for Wi-Fi again rather
        // than spend a retry on a connection this task isn't allowed to use.
        if options.requiresWiFi, currentType != .wifi {
            debugLog("📶 BackupFlow: Yedekleme sırasında Wi-Fi koptu: \(task.displayName) - \(error)")
            task.backupStatus = task.frequency == .manual ? .failed : .idle
            clearRunProgress(for: task)
            // Keep a record of what was sent before the drop.
            if BackupRunTally.shared.uploadedFiles > 0 {
                BackupHistoryRecorder.record(
                    for: task,
                    syncResult: Self.emptySyncResult,
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
        guard currentType.isOnline else {
            await handleNoNetworkFor(task: task)
            return
        }

        task.backupStatus = .failed
        task.lastError = error.localizedDescription
        let failureCategory = categorizeFailure(error)
        task.lastFailureCategory = failureCategory
        task.consecutiveFailureCount += 1

        BackupLiveActivityManager.shared.end(
            statusText: "backup.status.failed".localized,
            success: false
        )
        BackupWidgetSnapshotStore.save(
            makeWidgetSnapshot(
                for: task,
                status: "failed",
                activeProgress: 0.0,
                errorMessage: error.localizedDescription
            )
        )

        debugLog("❌ BackupFlow: Yedekleme başarısız: \(task.displayName) - \(error)")

        // Record every failed run, including ones that will be retried; the dashboard
        // failure counter already counts them, so history must show them too.
        BackupHistoryRecorder.record(
            for: task,
            syncResult: Self.emptySyncResult,
            duration: Date().timeIntervalSince(runStart),
            status: "failed",
            errorMessage: error.localizedDescription,
            failureCategory: failureCategory
        )

        scheduleRetryOrNextRun(for: task)
    }

    /// Retry logic, for scheduled tasks only: a manual task runs when the user
    /// starts it and must not gain a "next backup" time from a retry.
    private func scheduleRetryOrNextRun(for task: BackupTask) {
        let currentRetryCount = retryCount[task.id] ?? 0
        if task.frequency != .manual, currentRetryCount < maxRetryAttempts {
            retryCount[task.id] = currentRetryCount + 1
            debugLog("🔄 BackupFlow: Yeniden deneme \(currentRetryCount + 1)/\(maxRetryAttempts)")

            // Advance nextRunTime to avoid foreground re-trigger via missed timers
            task.nextRunTime = Date().addingTimeInterval(jitteredDelay(for: currentRetryCount + 1))
            saveNextRunTime(of: task, context: "retry")
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
            saveNextRunTime(of: task, context: "max retry")
        }
    }

    private func saveNextRunTime(of task: BackupTask, context label: String) {
        guard let context = task.modelContext else { return }
        do { try context.save() }
        catch { debugLog("❌ BackupFlow: nextRunTime kaydedilemedi (\(label)): \(error)") }
    }

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
                progressHandler: makeProgressHandler(for: task, source: ftpService)
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
                destinationPath: task.destinationPath,
                isAnonymous: username == nil,
                mediaType: task.mediaType,
                includeICloudAssets: task.includeICloudAssets,
                options: options,
                progressHandler: makeProgressHandler(for: task, source: webDAVService, usePlaceholderForEmptyFile: false)
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
            
            let credentialStore = BackupCredentialStore.shared
            let privateKey = task.sftpAuthMethod == .privateKey ? credentialStore.privateKey(for: task.id) : nil
            let passphrase = task.sftpAuthMethod == .privateKey ? credentialStore.passphrase(for: task.id) : nil

            let syncResult = try await sftpService.performBackup(
                host: task.serverHost,
                port: task.serverPort,
                username: task.serverUsername,
                password: task.resolvedServerPassword,
                privateKey: privateKey,
                passphrase: passphrase,
                sourcePath: task.sourcePath ?? "",
                destinationPath: task.destinationPath,
                mediaType: task.mediaType,
                includeICloudAssets: task.includeICloudAssets,
                options: options,
                progressHandler: makeProgressHandler(for: task, source: sftpService)
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
    
    /// Builds the callback a transfer service calls as it uploads: copies the overall
    /// progress and the service's current-file details onto `task` on the main actor.
    /// - Parameter usePlaceholderForEmptyFile: Show "Uploading…" while the service has no
    ///   current file name yet (FTP/SFTP); WebDAV shows its own value as is.
    private func makeProgressHandler(
        for task: BackupTask,
        source: some TransferProgressSource,
        usePlaceholderForEmptyFile: Bool = true
    ) -> @Sendable (Double) -> Void {
        nonisolated(unsafe) let mainActorTask = task
        return { progress in
            Task { @MainActor in
                // NaN kontrolü ile güvenli progress update
                mainActorTask.progress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
                let currentFile = source.currentFile
                mainActorTask.currentFile = usePlaceholderForEmptyFile && currentFile.isEmpty
                    ? "backup.current_file.uploading".localized
                    : currentFile
                mainActorTask.currentFileProgress = source.progress
                mainActorTask.currentFileBytesTransferred = source.currentFileBytesTransferred
                mainActorTask.currentFileTotalBytes = source.currentFileTotalBytes
                mainActorTask.transferSpeedBytesPerSecond = source.transferSpeedBytesPerSecond

                BackupLiveActivityManager.shared.update(
                    progress: mainActorTask.progress,
                    fileName: mainActorTask.currentFile ?? "",
                    statusText: "backup.status.uploading".localized
                )

                if WidgetSnapshotProgressThrottle.shouldUpdate(progress: mainActorTask.progress) {
                    BackupWidgetSnapshotStore.save(
                        self.makeWidgetSnapshot(
                            for: mainActorTask,
                            status: "running",
                            activeTaskName: mainActorTask.displayName,
                            activeProgress: mainActorTask.progress,
                            activeFileName: mainActorTask.currentFile
                        )
                    )
                }
            }
        }
    }

    private func makeWidgetSnapshot(
        for task: BackupTask,
        status: String,
        activeTaskName: String? = nil,
        activeProgress: Double,
        activeFileName: String? = nil,
        syncResult: FTPService.SyncResult? = nil,
        errorMessage: String? = nil
    ) -> BackupWidgetSnapshot {
        let statusDisplayText: String = {
            switch status {
            case "running": return "widget.status.running".localized
            case "completed": return "backup.status.completed".localized
            case "cancelled": return "backup.status.cancelled".localized
            case "failed": return "backup.status.failed".localized
            default: return status
            }
        }()

        let filesSummaryText: String? = syncResult.map { result in
            let sizeText = ByteCountFormatter.string(fromByteCount: result.totalBytes, countStyle: .file)
            return "widget.label.files_summary".localized(with: result.totalProcessed, sizeText)
        }

        return BackupWidgetSnapshot(
            lastBackupDate: task.lastBackupDate,
            lastStatus: status,
            lastTaskName: task.displayName,
            nextRunDate: task.nextRunTime,
            nextTaskName: task.displayName,
            activeTaskName: activeTaskName,
            activeProgress: activeProgress,
            activeFileName: activeFileName,
            updatedAt: Date(),
            protocolName: task.backupType.rawValue,
            statusDisplayText: statusDisplayText,
            filesSummaryText: filesSummaryText,
            lastErrorSummary: errorMessage,
            lastSyncLabel: "widget.label.last_sync".localized,
            nextRunLabel: "widget.label.next_run".localized,
            openActionLabel: "widget.action.open".localized
        )
    }

    func resetCurrentFileProgress(for task: BackupTask) {
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
}

@MainActor
private enum WidgetSnapshotProgressThrottle {
    private static var lastUpdateAt: Date = .distantPast
    private static var lastProgress: Double = -1

    static func reset(initialProgress: Double = 0) {
        lastUpdateAt = Date()
        lastProgress = initialProgress
    }

    static func shouldUpdate(progress: Double, now: Date = Date()) -> Bool {
        let delta = abs(progress - lastProgress)
        guard now.timeIntervalSince(lastUpdateAt) >= 3.0 || delta >= 0.05 || (progress >= 1.0 && lastProgress < 1.0) else {
            return false
        }
        lastUpdateAt = now
        lastProgress = progress
        return true
    }
}
