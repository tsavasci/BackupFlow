import Foundation

struct BackupExecutionOptions: Codable, Equatable {
    var isDryRun: Bool
    var deletionPolicy: BackupDeletionPolicy
    var checksumMode: BackupChecksumMode
    var requiresWiFi: Bool
    var requiresExternalPower: Bool
    var allowedStartTime: ScheduleTime?
    var allowedEndTime: ScheduleTime?
    var photoFolderStructure: PhotoFolderStructure = .flat
    var preserveOriginalPhotoFormat: Bool = false

    nonisolated static let defaults = BackupExecutionOptions(
        isDryRun: false,
        deletionPolicy: .appendOnly,
        checksumMode: .off,
        requiresWiFi: false,
        requiresExternalPower: false,
        allowedStartTime: nil,
        allowedEndTime: nil,
        photoFolderStructure: .flat,
        preserveOriginalPhotoFormat: false
    )

    static func forTask(_ task: BackupTask, isDryRun: Bool = false) -> BackupExecutionOptions {
        BackupExecutionOptions(
            isDryRun: isDryRun,
            deletionPolicy: task.deletionPolicy,
            checksumMode: task.checksumMode,
            requiresWiFi: task.requiresWiFi,
            requiresExternalPower: task.requiresExternalPower,
            allowedStartTime: task.allowedStartTime,
            allowedEndTime: task.allowedEndTime,
            photoFolderStructure: task.photoFolderStructure,
            preserveOriginalPhotoFormat: task.preserveOriginalPhotoFormat
        )
    }

    var performsRemoteMutations: Bool {
        !isDryRun
    }

    var shouldSkipRemotePreparation: Bool {
        isDryRun
    }

    func permitsPhotoOrphanDeletion(hasFullLibraryAccess: Bool, visibleAssetCount: Int) -> Bool {
        deletionPolicy == .mirror && hasFullLibraryAccess && visibleAssetCount > 0
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
            deletedFiles: deletionPolicy == .mirror ? result.deletedFiles : 0,
            iCloudSkippedFiles: result.iCloudSkippedFiles,
            timedOutAssetReads: result.timedOutAssetReads,
            failedAssetReads: result.failedAssetReads,
            totalBytes: result.totalBytes,
            deletionPolicy: deletionPolicy
        )
    }
}
