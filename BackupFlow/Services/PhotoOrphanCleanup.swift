import Foundation
import OSLog

/// Applies the task's deletion policy to photos that are on the server but no longer in
/// the library. Shared by the FTP, SFTP and WebDAV photo syncs; each one decides which
/// remote files count as orphans and whether deleting them is safe.
enum PhotoOrphanCleanup {
    struct Orphan {
        /// Path below the photo folder; also used for the archive location.
        let relativePath: String
        let fullRemotePath: String
    }

    /// - Parameters:
    ///   - canDelete: Whether the mirror policy may delete. Photo deletion is only safe with
    ///     full library access and a non-empty library, and the caller may add its own checks.
    ///   - isCancelled: Checked before each file; a cancel stops before touching the next one.
    /// - Returns: How many files were deleted, or would be on a dry run.
    static func apply(
        to orphans: [Orphan],
        basePath: String,
        options: BackupExecutionOptions,
        canDelete: Bool,
        logger: Logger,
        isCancelled: () -> Bool,
        deleteFile: (String) async throws -> Void,
        archiveFile: (_ from: String, _ to: String) async throws -> Void
    ) async throws -> Int {
        var deletedCount = 0
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()

        for orphan in orphans {
            guard !isCancelled() else { throw BackupServiceError.cancelled }

            switch options.deletionPolicy {
            case .mirror where canDelete:
                if options.isDryRun {
                    deletedCount += 1
                } else {
                    do {
                        try await deleteFile(orphan.fullRemotePath)
                        deletedCount += 1
                    } catch {
                        logger.error("Failed to delete orphaned photo \(orphan.relativePath): \(error.localizedDescription)")
                    }
                }
            case .mirror:
                break
            case .appendOnly:
                logger.info("Skipping orphan photo deletion because append-only policy is active: \(orphan.relativePath)")
            case .archive:
                if options.isDryRun {
                    logger.info("Would archive orphaned photo: \(orphan.relativePath)")
                } else {
                    do {
                        let archivePath = BackupArchive.destinationPath(
                            basePath: basePath,
                            runIdentifier: archiveRunIdentifier,
                            relativePath: orphan.relativePath
                        )
                        try await archiveFile(orphan.fullRemotePath, archivePath)
                        logger.info("Archived orphaned photo: \(orphan.relativePath)")
                    } catch {
                        logger.error("Failed to archive orphaned photo \(orphan.relativePath): \(error.localizedDescription)")
                        throw error
                    }
                }
            }
        }

        return deletedCount
    }
}
