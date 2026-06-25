import Foundation

struct BackupExecutionOptions: Codable, Equatable {
    var isDryRun: Bool
    var deletionPolicy: BackupDeletionPolicy
    var checksumMode: BackupChecksumMode
    var requiresWiFi: Bool
    var requiresExternalPower: Bool
    var allowedStartTime: ScheduleTime?
    var allowedEndTime: ScheduleTime?

    nonisolated static let defaults = BackupExecutionOptions(
        isDryRun: false,
        deletionPolicy: .mirror,
        checksumMode: .off,
        requiresWiFi: false,
        requiresExternalPower: false,
        allowedStartTime: nil,
        allowedEndTime: nil
    )

    static func forTask(_ task: BackupTask, isDryRun: Bool = false) -> BackupExecutionOptions {
        BackupExecutionOptions(
            isDryRun: isDryRun,
            deletionPolicy: task.deletionPolicy,
            checksumMode: task.checksumMode,
            requiresWiFi: task.requiresWiFi,
            requiresExternalPower: task.requiresExternalPower,
            allowedStartTime: task.allowedStartTime,
            allowedEndTime: task.allowedEndTime
        )
    }
}

struct BackupPreviewResult: Codable, Equatable {
    var newFiles: Int = 0
    var updatedFiles: Int = 0
    var skippedFiles: Int = 0
    var deletedFiles: Int = 0
    var iCloudSkippedFiles: Int = 0
    var timedOutAssetReads: Int = 0
    var failedAssetReads: Int = 0
    var totalBytes: Int64 = 0
    var deletionPolicy: BackupDeletionPolicy = .mirror

    var totalChanges: Int {
        newFiles + updatedFiles + deletedFiles
    }

    var summarySnapshot: String {
        "new=\(newFiles);updated=\(updatedFiles);skipped=\(skippedFiles);deleted=\(deletedFiles);bytes=\(totalBytes);policy=\(deletionPolicy.rawValue)"
    }

    static func fromSyncResult(_ result: FTPSyncResult, deletionPolicy: BackupDeletionPolicy) -> BackupPreviewResult {
        BackupPreviewResult(
            newFiles: result.newFiles,
            updatedFiles: result.updatedFiles,
            skippedFiles: result.skippedFiles,
            deletedFiles: result.deletedFiles,
            iCloudSkippedFiles: result.iCloudSkippedFiles,
            timedOutAssetReads: result.timedOutAssetReads,
            failedAssetReads: result.failedAssetReads,
            totalBytes: result.totalBytes,
            deletionPolicy: deletionPolicy
        )
    }
}
