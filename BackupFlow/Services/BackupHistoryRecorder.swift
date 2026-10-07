import Foundation
import SwiftData

/// Writes the history entry for a backup run: completed, failed, interrupted or deferred.
@MainActor
enum BackupHistoryRecorder {
    static func record(
        for task: BackupTask,
        syncResult: FTPService.SyncResult,
        duration: TimeInterval,
        status: String,
        errorMessage: String? = nil,
        failureCategory: BackupFailureCategory? = nil,
        previewSummarySnapshot: String? = nil
    ) {
        guard let container = BackupScheduler.sharedModelContainer else { return }

        // Cancelled and failed runs pass an empty result; record what was actually
        // uploaded before they stopped. "Transferred" counts uploads only, not files
        // that were already on the server.
        var syncResult = syncResult
        let tally = BackupRunTally.shared
        if syncResult.totalProcessed == 0 && tally.uploadedFiles > 0 {
            syncResult.newFiles = tally.uploadedFiles
            syncResult.totalBytes = tally.uploadedBytes
        }

        func makeRecord(describing task: BackupTask) -> BackupHistory {
            BackupHistory(
                id: UUID(),
                timestamp: Date(),
                status: status,
                filesProcessed: syncResult.totalProcessed,
                totalFiles: syncResult.totalProcessed,
                bytesTransferred: tally.uploadedBytes,
                totalBytes: syncResult.totalBytes,
                errorMessage: errorMessage,
                duration: duration,
                skippedFiles: syncResult.skippedFiles,
                deletedFiles: syncResult.deletedFiles,
                newFiles: syncResult.newFiles,
                updatedFiles: syncResult.updatedFiles,
                verifiedFiles: syncResult.verifiedFiles,
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
        }

        // Prefer the task's own ModelContext to avoid cross-context attachment
        if let context = task.modelContext {
            let historyRecord = makeRecord(describing: task)
            context.insert(historyRecord)
            historyRecord.task = task

            do {
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

            let historyRecord = makeRecord(describing: taskInContext)
            context.insert(historyRecord)
            historyRecord.task = taskInContext

            try context.save()
            HistoryRetentionManager.pruneIfNeeded(context: context)
            debugLog("📝 BackupFlow: Geçmiş kaydı eklendi (refetched) - \(syncResult.totalProcessed) dosya, \(Int(duration))s")
        } catch {
            debugLog("❌ BackupFlow: Geçmiş kaydı hatası (refetch): \(error)")
        }
    }
}
