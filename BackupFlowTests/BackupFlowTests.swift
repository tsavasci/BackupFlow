import XCTest
@testable import BackupFlow

final class BackupFlowTests: XCTestCase {
    func testNewTasksDefaultToAppendOnlyAndNoChecksum() throws {
        let task = BackupTask(sourcePath: "/tmp/source")

        let options = BackupExecutionOptions.forTask(task)

        XCTAssertFalse(options.isDryRun)
        // New tasks must never delete remote files unless mirroring is chosen explicitly.
        XCTAssertEqual(options.deletionPolicy, .appendOnly)
        XCTAssertEqual(BackupExecutionOptions.defaults.deletionPolicy, .appendOnly)
        XCTAssertEqual(options.checksumMode, .off)
        XCTAssertFalse(options.requiresWiFi)
        XCTAssertFalse(options.requiresExternalPower)
    }

    func testDryRunOptionsPreserveTaskPolicies() throws {
        let task = BackupTask(
            sourcePath: "/tmp/source",
            deletionPolicy: .appendOnly,
            checksumMode: .verifyUploads,
            requiresExternalPower: true,
            requiresWiFi: true
        )

        let options = BackupExecutionOptions.forTask(task, isDryRun: true)

        XCTAssertTrue(options.isDryRun)
        XCTAssertEqual(options.deletionPolicy, .appendOnly)
        XCTAssertEqual(options.checksumMode, .verifyUploads)
        XCTAssertTrue(options.requiresWiFi)
        XCTAssertTrue(options.requiresExternalPower)
    }

    func testPreviewSummarySnapshotContainsCountsAndPolicy() throws {
        let result = FTPSyncResult(
            newFiles: 2,
            updatedFiles: 1,
            skippedFiles: 3,
            deletedFiles: 4,
            totalBytes: 1024
        )

        let preview = BackupPreviewResult.fromSyncResult(result, deletionPolicy: .mirror)

        XCTAssertEqual(preview.totalChanges, 7)
        XCTAssertTrue(preview.summarySnapshot.contains("new=2"))
        XCTAssertTrue(preview.summarySnapshot.contains("deleted=4"))
        XCTAssertTrue(preview.summarySnapshot.contains("policy=mirror"))
    }

    func testAppendOnlyPreviewNeverReportsDeletes() throws {
        let result = FTPSyncResult(deletedFiles: 12)

        let preview = BackupPreviewResult.fromSyncResult(result, deletionPolicy: .appendOnly)

        XCTAssertEqual(preview.deletedFiles, 0)
        XCTAssertTrue(preview.summarySnapshot.contains("deleted=0"))
    }

    func testDryRunNeverPermitsRemoteMutations() throws {
        let task = BackupTask(sourcePath: "/tmp/source")

        let options = BackupExecutionOptions.forTask(task, isDryRun: true)

        XCTAssertFalse(options.performsRemoteMutations)
        XCTAssertTrue(options.shouldSkipRemotePreparation)
    }

    func testPhotoOrphanDeletionRequiresFullAccessAndVisibleAssets() throws {
        let task = BackupTask(sourcePath: "PHOTOS_LIBRARY", deletionPolicy: .mirror)
        let options = BackupExecutionOptions.forTask(task)

        XCTAssertFalse(options.permitsPhotoOrphanDeletion(hasFullLibraryAccess: false, visibleAssetCount: 10))
        XCTAssertFalse(options.permitsPhotoOrphanDeletion(hasFullLibraryAccess: true, visibleAssetCount: 0))
        XCTAssertTrue(options.permitsPhotoOrphanDeletion(hasFullLibraryAccess: true, visibleAssetCount: 10))
    }

    func testSHA256UsesFileContents() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backupflow-checksum-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("abc".utf8).write(to: fileURL)

        XCTAssertEqual(
            try BackupChecksum.sha256(of: fileURL),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testArchivePathPreservesRelativeHierarchy() throws {
        let path = BackupArchive.destinationPath(
            basePath: "/photos",
            runIdentifier: "20260721-120000-deadbeef",
            relativePath: "albums/summer/photo.jpg"
        )

        XCTAssertEqual(
            path,
            "/photos/.backupflow_archive/20260721-120000-deadbeef/albums/summer/photo.jpg"
        )
    }

    func testArchiveAndManifestPathsAreReserved() throws {
        XCTAssertTrue(BackupArchive.isReserved(relativePath: ".backupflow_manifest.json"))
        XCTAssertTrue(BackupArchive.isReserved(relativePath: ".backupflow_archive/old/file.jpg"))
        XCTAssertFalse(BackupArchive.isReserved(relativePath: "albums/file.jpg"))
    }

    @MainActor
    func testWebDAVBackgroundUploadIsEnabledForBackgroundExecution() async throws {
        let service = WebDAVService.shared
        service.updateBackgroundMode(isBackground: true)

        XCTAssertTrue(service.isBackgroundUploading)
        XCTAssertTrue(service.shouldUseBackgroundUploadSession(allowBackgroundSession: true))
    }

    @MainActor
    func testFTPBackgroundUploadIsEnabledForBackgroundExecution() async throws {
        let service = FTPService.shared
        service.updateBackgroundMode(isBackground: true)

        XCTAssertTrue(service.isBackgroundUploading)
    }

    @MainActor
    func testFTPBackgroundModeIsClearedOnForeground() async throws {
        let service = FTPService.shared
        service.updateBackgroundMode(isBackground: true)
        service.updateBackgroundMode(isBackground: false)

        XCTAssertFalse(service.isBackgroundUploading)
    }

    @MainActor
    func testWebDAVBackupsAreNotHandedToContinuedProcessing() throws {
        // WebDAV already continues through its background URLSession.
        let task = BackupTask(sourcePath: "/tmp/source", backupType: .webdav, serverHost: "dav.example.org")

        XCTAssertFalse(ContinuedBackupRunner.shared.start(task: task))
        XCTAssertFalse(ContinuedBackupRunner.isRunning)
    }

    func testRegularLocalFilesAreReadableWithoutICloud() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backupflow-availability-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("x".utf8).write(to: fileURL)

        // Only iCloud files that aren't on the device are skipped.
        XCTAssertTrue(LocalFileAvailability.isReadableNow(fileURL))
    }

    func testBackupStatusScanningAndPreparingAreUserFriendly() throws {
        XCTAssertFalse(BackupStatus.scanning.displayName.isEmpty)
        XCTAssertFalse(BackupStatus.preparing.displayName.isEmpty)
        XCTAssertNotEqual(BackupStatus.scanning.displayName, "backup.status.scanning")
        XCTAssertNotEqual(BackupStatus.preparing.displayName, "backup.status.preparing")
    }
}
