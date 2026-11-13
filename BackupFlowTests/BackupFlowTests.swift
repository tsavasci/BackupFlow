import XCTest
import Photos
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

        service.updateBackgroundMode(isBackground: false)
        XCTAssertFalse(service.isBackgroundUploading)
    }

    func testSFTPBackgroundExpirationFlagIsConsumedOnce() throws {
        let service = SFTPService.shared
        XCTAssertFalse(service.consumeBackgroundExpiration())

        service.cancelForBackgroundExpiration()
        XCTAssertTrue(service.consumeBackgroundExpiration())
        XCTAssertFalse(service.consumeBackgroundExpiration())
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

    func testWebDAVConnectionBuilderDefaultsToHTTPS() throws {
        let httpsDefault = try WebDAVConnectionBuilder.build(host: "nas.local", port: 5005)
        XCTAssertEqual(httpsDefault.scheme, "https")
        XCTAssertEqual(httpsDefault.url.scheme, "https")

        let explicitHttp = try WebDAVConnectionBuilder.build(host: "http://nas.local", port: 5005)
        XCTAssertEqual(explicitHttp.scheme, "http")

        let port80Http = try WebDAVConnectionBuilder.build(host: "nas.local", port: 80)
        XCTAssertEqual(port80Http.scheme, "http")

        let explicitHttps = try WebDAVConnectionBuilder.build(host: "https://nas.local", port: 443)
        XCTAssertEqual(explicitHttps.scheme, "https")
    }

    func testWebDAVCertificateStoreValidationAndMismatch() throws {
        let store = WebDAVCertificateStore.shared
        let testHost = "test-host-\(UUID().uuidString).local"
        let testPort = 5006
        let fingerprint1 = "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        let fingerprint2 = "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="

        defer { store.delete(host: testHost, port: testPort) }

        // First validation should store the fingerprint (return true)
        let isNew = try store.validate(fingerprint: fingerprint1, host: testHost, port: testPort)
        XCTAssertTrue(isNew)

        // Second validation with same fingerprint should match (return false)
        let isMatching = try store.validate(fingerprint: fingerprint1, host: testHost, port: testPort)
        XCTAssertFalse(isMatching)

        // Validation with different fingerprint should throw changedCertificate
        XCTAssertThrowsError(try store.validate(fingerprint: fingerprint2, host: testHost, port: testPort)) { error in
            guard case WebDAVCertificateError.changedCertificate = error else {
                XCTFail("Expected changedCertificate error but got \(error)")
                return
            }
        }
    }

    func testSFTPHostKeyStoreStoredFingerprintAndDelete() throws {
        let store = SFTPHostKeyStore.shared
        let testHost = "sftp-test-\(UUID().uuidString).local"
        let testPort = 2222
        let fingerprint = "SHA256:dGVzdGZpbmdlcnByaW50MTIzNDU2Nzg5MDEyMzQ1Njc"

        defer { store.delete(host: testHost, port: testPort) }

        XCTAssertNil(store.storedFingerprint(host: testHost, port: testPort))

        let isNew = try store.validate(fingerprint: fingerprint, host: testHost, port: testPort)
        XCTAssertTrue(isNew)
        XCTAssertEqual(store.storedFingerprint(host: testHost, port: testPort), fingerprint)

        store.delete(host: testHost, port: testPort)
        XCTAssertNil(store.storedFingerprint(host: testHost, port: testPort))
    }

    func testSFTPHostKeyStoreDetectsMismatch() throws {
        let store = SFTPHostKeyStore.shared
        let testHost = "sftp-test-\(UUID().uuidString).local"
        let testPort = 2222
        let fingerprintOriginal = "SHA256:MTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTE"
        let fingerprintChanged = "SHA256:MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjI"

        defer { store.delete(host: testHost, port: testPort) }

        _ = try store.validate(fingerprint: fingerprintOriginal, host: testHost, port: testPort)

        XCTAssertThrowsError(try store.validate(fingerprint: fingerprintChanged, host: testHost, port: testPort)) { error in
            guard case SFTPHostKeyValidationError.changedHostKey = error else {
                XCTFail("Expected changedHostKey error but got \(error)")
                return
            }
        }
    }

    func testSFTPServiceClearStoredConnectionPurgesMemory() {
        let service = SFTPService.shared
        service.clearStoredConnection()
        service.clearStoredConnection()
    }

    func testBackupArchiveSanitizesPathTraversal() {
        let maliciousPath = "../../etc/passwd"
        let sanitized = BackupArchive.sanitize(relativePath: maliciousPath)
        XCTAssertEqual(sanitized, "etc/passwd")

        let complexTraversal = "photos/../../secret/./notes.txt"
        let sanitizedComplex = BackupArchive.sanitize(relativePath: complexTraversal)
        XCTAssertEqual(sanitizedComplex, "photos/secret/notes.txt")

        let leadingTrailing = "///folder/subfolder///file.jpg///"
        let sanitizedSlashes = BackupArchive.sanitize(relativePath: leadingTrailing)
        XCTAssertEqual(sanitizedSlashes, "folder/subfolder/file.jpg")
    }

    func testBackupArchiveSafeRemotePath() {
        let remoteBase = "/volume1/backups"
        let maliciousRelative = "../../../sensitive/data.db"
        let safePath = BackupArchive.safeRemotePath(basePath: remoteBase, relativePath: maliciousRelative)
        XCTAssertEqual(safePath, "/volume1/backups/sensitive/data.db")

        let rootBase = "/"
        let safeRoot = BackupArchive.safeRemotePath(basePath: rootBase, relativePath: maliciousRelative)
        XCTAssertEqual(safeRoot, "/sensitive/data.db")

        let emptyBase = ""
        let safeEmpty = BackupArchive.safeRemotePath(basePath: emptyBase, relativePath: maliciousRelative)
        XCTAssertEqual(safeEmpty, "sensitive/data.db")
    }

    @MainActor
    func testParseWebDAVURLPreservesSubpathAndFallback() throws {
        let keenetic = BackupFormModel.parseWebDAVURL(
            "https://tamersavasci.keenetic.link/webdav",
            portOverride: "443",
            fallbackPath: "/"
        )
        XCTAssertEqual(keenetic.host, "https://tamersavasci.keenetic.link/webdav")
        XCTAssertEqual(keenetic.port, 443)

        let withFallback = BackupFormModel.parseWebDAVURL(
            "tamersavasci.keenetic.link",
            portOverride: "443",
            fallbackPath: "/webdav"
        )
        XCTAssertEqual(withFallback.host, "https://tamersavasci.keenetic.link/webdav")
        XCTAssertEqual(withFallback.port, 443)

        let built = try WebDAVConnectionBuilder.build(host: keenetic.host, port: keenetic.port)
        XCTAssertEqual(built.url.absoluteString, "https://tamersavasci.keenetic.link/webdav/")
        XCTAssertEqual(built.path, "/webdav/")
    }

    func testPhotoFolderStructureSubfolderPrefixes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 14, minute: 30))!

        XCTAssertNil(PhotoFolderStructure.flat.subfolderPrefix(for: date, calendar: calendar))
        XCTAssertEqual(PhotoFolderStructure.yearMonthSlash.subfolderPrefix(for: date, calendar: calendar), "2026/10")
        XCTAssertEqual(PhotoFolderStructure.yearMonthDash.subfolderPrefix(for: date, calendar: calendar), "2026-10")
    }

    func testPhotoFileNamePreservesOriginalExtensionWhenEnabled() throws {
        let date = Date(timeIntervalSince1970: 1_761_652_200)
        let defaultName = PhotoLibraryManager.formatFileName(
            creationDate: date,
            localIdentifier: "ABCD1234-5678-90EF/L0/001",
            mediaType: .image,
            originalExtension: "HEIC",
            preserveOriginalExtension: false
        )
        XCTAssertTrue(defaultName.hasSuffix("_ABCD1234-567.jpg"))

        let preservedHeic = PhotoLibraryManager.formatFileName(
            creationDate: date,
            localIdentifier: "ABCD1234-5678-90EF/L0/001",
            mediaType: .image,
            originalExtension: ".HEIC",
            preserveOriginalExtension: true
        )
        XCTAssertTrue(preservedHeic.hasSuffix("_ABCD1234-567.heic"))

        let preservedMov = PhotoLibraryManager.formatFileName(
            creationDate: date,
            localIdentifier: "ABCD1234-5678-90EF/L0/001",
            mediaType: .video,
            originalExtension: "MOV",
            preserveOriginalExtension: true
        )
        XCTAssertTrue(preservedMov.hasSuffix("_ABCD1234-567.mov"))
    }

    func testBackupExecutionOptionsPropagatesPhotoFolderAndFormatSettings() throws {
        let task = BackupTask(
            sourcePath: "PHOTOS_LIBRARY",
            photoFolderStructure: .yearMonthSlash,
            preserveOriginalPhotoFormat: true
        )
        let options = BackupExecutionOptions.forTask(task)
        XCTAssertEqual(options.photoFolderStructure, .yearMonthSlash)
        XCTAssertTrue(options.preserveOriginalPhotoFormat)
    }

    func testResumeCheckpointStorePersistsAndIsolatesProtocols() async {
        let suiteName = "BackupFlowTests.Checkpoint.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let ftpStore = ResumeCheckpointStore(keyPrefix: "ftp.resume.checkpoint.", defaults: defaults)
        let sftpStore = ResumeCheckpointStore(keyPrefix: "sftp.resume.checkpoint.", defaults: defaults)
        let id = ResumeCheckpointStore.makeID(
            scheme: "ftp",
            host: "nas.local",
            port: 21,
            username: "tamer",
            source: "PHOTOS_LIBRARY",
            destination: "/Backup"
        )

        await ftpStore.mark(id: id, item: "2026/01/IMG_001.jpg")
        let ftpLoaded = await ftpStore.load(id: id)
        let sftpLoaded = await sftpStore.load(id: id)
        XCTAssertEqual(ftpLoaded, ["2026/01/IMG_001.jpg"])
        XCTAssertTrue(sftpLoaded.isEmpty)

        await ftpStore.clear(id: id)
        let ftpCleared = await ftpStore.load(id: id)
        XCTAssertTrue(ftpCleared.isEmpty)
    }

    func testDiagnosticsExporterRedactsSecretsAndIncludesLogs() {
        DebugLogBuffer.shared.clear()
        debugLog("Connecting to sftp://tamer:SuperSecretPass@nas.local:22 password=MyPassword123")
        let report = BackupDiagnosticsExporter.buildReport()
        XCTAssertFalse(report.contains("SuperSecretPass"))
        XCTAssertFalse(report.contains("MyPassword123"))
        XCTAssertTrue(report.contains("sftp://tamer:***@nas.local:22"))
        XCTAssertTrue(report.contains("password=***"))
    }

    func testConcurrentTransferQueueRespectsLimitAndPreservesOrder() async throws {
        let items = Array(0..<10)
        let results = try await ConcurrentTransferQueue.run(items: items, maxConcurrency: 3) { index, item in
            try await Task.sleep(nanoseconds: UInt64((10 - item) * 1_000_000))
            return index * 2
        }
        XCTAssertEqual(results, items.map { $0 * 2 })
    }

    func testSFTPAuthMethodSupportsEd25519PasswordAndRejectsInvalidKey() throws {
        // Password fallback
        _ = try SFTPService.makeAuthenticationMethod(
            username: "tamer",
            password: "secret",
            privateKey: nil,
            passphrase: nil
        )

        // Valid OpenSSH Ed25519 private key (throwaway test fixture)
        let testEd25519Key = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
        QyNTUxOQAAACDBGYBbmd3j2EZRzvdBqb+nT4x7fxKbzaCbL9BMiN144AAAAKglPKgoJTyo
        KAAAAAtzc2gtZWQyNTUxOQAAACDBGYBbmd3j2EZRzvdBqb+nT4x7fxKbzaCbL9BMiN144A
        AAAECzwNvJ7Nw02/QF7ugM2MUfbNRZdIkuYEZFC0pUW2I7TcEZgFuZ3ePYRlHO90Gpv6dP
        jHt/EpvNoJsv0EyI3XjgAAAAJHRhbWVyc2F2YXNjaUBHb3pkZS1NYWNCb29rLUFpci5sb2
        NhbAE=
        -----END OPENSSH PRIVATE KEY-----
        """
        _ = try SFTPService.makeAuthenticationMethod(
            username: "tamer",
            password: nil,
            privateKey: testEd25519Key,
            passphrase: nil
        )

        // Invalid key must throw
        XCTAssertThrowsError(
            try SFTPService.makeAuthenticationMethod(
                username: "tamer",
                password: nil,
                privateKey: "not-a-valid-ssh-key",
                passphrase: nil
            )
        )
    }

    func testCredentialStorePrivateKeyAndPassphraseCRUD() {
        let taskID = UUID()
        defer {
            BackupCredentialStore.shared.deletePrivateKey(for: taskID)
            BackupCredentialStore.shared.deletePassphrase(for: taskID)
        }

        BackupCredentialStore.shared.savePrivateKey("TEST-KEY-PEM", for: taskID)
        BackupCredentialStore.shared.savePassphrase("TEST-PASSPHRASE", for: taskID)

        XCTAssertEqual(BackupCredentialStore.shared.privateKey(for: taskID), "TEST-KEY-PEM")
        XCTAssertEqual(BackupCredentialStore.shared.passphrase(for: taskID), "TEST-PASSPHRASE")

        BackupCredentialStore.shared.deletePrivateKey(for: taskID)
        BackupCredentialStore.shared.deletePassphrase(for: taskID)

        XCTAssertNil(BackupCredentialStore.shared.privateKey(for: taskID))
        XCTAssertNil(BackupCredentialStore.shared.passphrase(for: taskID))
    }

    func testBonjourTargetMappingAndFallbackHostName() {
        let ftp = LocalServerDiscoveryService.targetInfo(for: "_ftp._tcp")
        XCTAssertEqual(ftp.target, .ftp)
        XCTAssertEqual(ftp.defaultPort, 21)
        XCTAssertFalse(ftp.usesHTTPS)

        let sftp = LocalServerDiscoveryService.targetInfo(for: "_sftp-ssh._tcp")
        XCTAssertEqual(sftp.target, .sftp)
        XCTAssertEqual(sftp.defaultPort, 22)
        XCTAssertFalse(sftp.usesHTTPS)

        let webdavs = LocalServerDiscoveryService.targetInfo(for: "_webdavs._tcp")
        XCTAssertEqual(webdavs.target, .webdav)
        XCTAssertEqual(webdavs.defaultPort, 443)
        XCTAssertTrue(webdavs.usesHTTPS)

        let webdav = LocalServerDiscoveryService.targetInfo(for: "_webdav._tcp")
        XCTAssertEqual(webdav.target, .webdav)
        XCTAssertEqual(webdav.defaultPort, 80)
        XCTAssertFalse(webdav.usesHTTPS)

        XCTAssertEqual(LocalServerDiscoveryService.fallbackHostName(for: "Synology NAS"), "Synology-NAS.local")
        XCTAssertEqual(LocalServerDiscoveryService.fallbackHostName(for: "macmini.local"), "macmini.local")
    }

    func testRestoreServiceArchivePathAndMediaExtensionHelpers() {
        XCTAssertEqual(
            RestoreService.archiveRootPath(for: "/Backups"),
            "/Backups/.backupflow_archive"
        )
        XCTAssertEqual(
            RestoreService.archiveRootPath(for: "/"),
            "/.backupflow_archive"
        )
        XCTAssertTrue(RestoreService.isImageExtension("HEIC"))
        XCTAssertTrue(RestoreService.isImageExtension("jpg"))
        XCTAssertFalse(RestoreService.isImageExtension("pdf"))
        XCTAssertTrue(RestoreService.isVideoExtension("MOV"))
        XCTAssertTrue(RestoreService.isVideoExtension("mp4"))
        XCTAssertFalse(RestoreService.isVideoExtension("txt"))
    }

    func testWidgetSnapshotStoreRoundTripAndClear() {
        let suiteName = "BackupFlowTests.WidgetSnapshot.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let snapshot = BackupWidgetSnapshot(
            lastBackupDate: now,
            lastStatus: "completed",
            lastTaskName: "NAS Photos",
            nextRunDate: now.addingTimeInterval(3600),
            nextTaskName: "NAS Photos",
            activeTaskName: nil,
            activeProgress: 1.0,
            activeFileName: nil,
            updatedAt: now
        )

        BackupWidgetSnapshotStore.save(snapshot, defaults: defaults)
        let loaded = BackupWidgetSnapshotStore.load(defaults: defaults)
        XCTAssertEqual(loaded, snapshot)

        BackupWidgetSnapshotStore.clear(defaults: defaults)
        XCTAssertNil(BackupWidgetSnapshotStore.load(defaults: defaults))
    }
}
