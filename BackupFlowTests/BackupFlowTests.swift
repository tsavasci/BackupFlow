import XCTest
import Photos
import FilesProvider
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

    @MainActor
    func testUserInitiatedRunBypassesBatteryPowerAndWindowConditions() {
        let scheduler = BackupScheduler.shared
        let calendar = Calendar.current
        let noon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 12, minute: 0))!
        var options = BackupExecutionOptions.defaults
        options.requiresExternalPower = true
        options.allowedStartTime = ScheduleTime(hour: 23, minute: 0)
        options.allowedEndTime = ScheduleTime(hour: 6, minute: 0)

        // Scheduled run (bypassConditions: false) should be blocked by external power, low battery, or time window.
        XCTAssertNotNil(
            scheduler.blockedReason(
                for: options,
                bypassConditions: false,
                batteryState: .unplugged,
                batteryReason: .some(nil),
                now: noon
            )
        )

        var batteryOnlyOptions = BackupExecutionOptions.defaults
        XCTAssertEqual(
            scheduler.blockedReason(
                for: batteryOnlyOptions,
                bypassConditions: false,
                batteryState: .unplugged,
                batteryReason: .some("Pil seviyesi düşük (%25), en az %30 gerekli"),
                now: noon
            ),
            "Pil seviyesi düşük (%25), en az %30 gerekli"
        )

        batteryOnlyOptions.allowedStartTime = ScheduleTime(hour: 23, minute: 0)
        batteryOnlyOptions.allowedEndTime = ScheduleTime(hour: 6, minute: 0)
        XCTAssertNotNil(
            scheduler.blockedReason(
                for: batteryOnlyOptions,
                bypassConditions: false,
                batteryState: .charging,
                batteryReason: .some(nil),
                now: noon
            )
        )

        // User-initiated run (bypassConditions: true) must bypass all three conditions.
        XCTAssertNil(
            scheduler.blockedReason(
                for: options,
                bypassConditions: true,
                batteryState: .unplugged,
                batteryReason: .some("Pil seviyesi düşük (%25), en az %30 gerekli"),
                now: noon
            )
        )
    }

    // MARK: - Smart Differential Restore Tests

    func testNormalizedPathKeyUnicodeAndCaseCollision() {
        // NFD ("s + cedilla", "g + breve") vs NFC ("ş", "ğ")
        let nfd = "Belgeler/s\u{0327}ag\u{0306}_rapor.PDF"
        let nfc = "belgeler/şağ_rapor.pdf"
        XCTAssertEqual(NormalizedPathKey(nfd), NormalizedPathKey(nfc))

        // Locale-agnostic ASCII I/i folding must keep "IMG_0001.JPG" == "img_0001.jpg"
        XCTAssertEqual(NormalizedPathKey("IMG_0001.JPG"), NormalizedPathKey("img_0001.jpg"))

        // Server case-collision detection: both "Rapor.pdf" and "rapor.pdf" must be preserved
        let remoteItems = [
            RemoteRestoreItem(relativePath: "Rapor.pdf", fullRemotePath: "/Backup/Rapor.pdf", size: 120),
            RemoteRestoreItem(relativePath: "rapor.pdf", fullRemotePath: "/Backup/rapor.pdf", size: 240)
        ]
        let plan = SmartRestoreEngine.computeFolderDiff(
            taskID: UUID(),
            remoteRootPath: "/Backup",
            remoteItems: remoteItems,
            localItems: [:],
            ignoredKeys: []
        )
        XCTAssertEqual(plan.caseCollisionCount, 2)
        XCTAssertEqual(plan.missingItems.count, 2)
    }

    func testPhotoDiffTwoPassAndBurstSizeDisambiguation() throws {
        let ledger = RestoredPhotoLedgerStore()
        let taskID = UUID()
        let utc = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let burstDate = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12, minute: 0, second: 0))!

        // 1. Two-Pass Verification:
        // Remote A (missing) and Remote B (present locally by exact idFragment) share the same timestamp & size.
        // Pass 1 must claim asset B for Remote B so Pass 2 does NOT pair asset B with Remote A.
        let remoteA = RemoteRestoreItem(
            relativePath: "20261114_120000_AAAAAAAAAAAA.heic",
            fullRemotePath: "/photos/20261114_120000_AAAAAAAAAAAA.heic",
            size: 1_000
        )
        let remoteB = RemoteRestoreItem(
            relativePath: "20261114_120000_BBBBBBBBBBBB.heic",
            fullRemotePath: "/photos/20261114_120000_BBBBBBBBBBBB.heic",
            size: 1_000
        )
        let localOnlyB = [
            LocalPhotoAssetSnapshot(
                localIdentifier: "BBBBBBBBBBBB-0000-1111/L0/001",
                creationDate: burstDate,
                isVideo: false,
                resourceSize: 1_000
            )
        ]

        let twoPassPlan = try SmartRestoreEngine.computePhotoDiff(
            taskID: taskID,
            remoteRootPath: "/photos",
            remoteItems: [remoteA, remoteB],
            localAssets: localOnlyB,
            authorizationStatus: .authorized,
            ledgerStore: ledger,
            timeZone: utc
        )
        XCTAssertEqual(twoPassPlan.unchangedCount, 1)
        XCTAssertEqual(twoPassPlan.missingItems.map(\.remoteItem.name), ["20261114_120000_AAAAAAAAAAAA.heic"])

        // 2. Burst Exact-Size Disambiguation on a New Device (different localIdentifiers):
        // 4 burst photos at the exact same second with sizes 100, 200, 300, 400.
        // Only sizes 200 and 400 exist on the new device -> sizes 100 and 300 must be identified as missing.
        let burstRemotes = [
            RemoteRestoreItem(relativePath: "20261114_120000_111111111111.jpg", fullRemotePath: "/p/1.jpg", size: 100),
            RemoteRestoreItem(relativePath: "20261114_120000_222222222222.jpg", fullRemotePath: "/p/2.jpg", size: 200),
            RemoteRestoreItem(relativePath: "20261114_120000_333333333333.jpg", fullRemotePath: "/p/3.jpg", size: 300),
            RemoteRestoreItem(relativePath: "20261114_120000_444444444444.jpg", fullRemotePath: "/p/4.jpg", size: 400)
        ]
        let newDeviceBurstLocals = [
            LocalPhotoAssetSnapshot(localIdentifier: "NEWDEV_ID_01/L0/001", creationDate: burstDate, isVideo: false, resourceSize: 200),
            LocalPhotoAssetSnapshot(localIdentifier: "NEWDEV_ID_02/L0/001", creationDate: burstDate, isVideo: false, resourceSize: 400)
        ]

        let burstPlan = try SmartRestoreEngine.computePhotoDiff(
            taskID: taskID,
            remoteRootPath: "/p",
            remoteItems: burstRemotes,
            localAssets: newDeviceBurstLocals,
            authorizationStatus: .authorized,
            ledgerStore: RestoredPhotoLedgerStore(),
            timeZone: utc
        )
        XCTAssertEqual(burstPlan.unchangedCount, 2)
        XCTAssertEqual(
            burstPlan.missingItems.map(\.remoteItem.relativePath),
            ["20261114_120000_111111111111.jpg", "20261114_120000_333333333333.jpg"]
        )
    }

    func testPhotoDiffAmbiguousWhenSizeDiffers() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let photoDate = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 15, minute: 30, second: 0))!

        let remote = RemoteRestoreItem(
            relativePath: "20261114_153000_OLDDEVICE123.heic",
            fullRemotePath: "/photos/20261114_153000_OLDDEVICE123.heic",
            size: 4_200_000
        )
        // Same timestamp and mediaType on a new device, but size differs (e.g. edited or re-encoded)
        let local = LocalPhotoAssetSnapshot(
            localIdentifier: "NEWDEVICE999-AAAA/L0/001",
            creationDate: photoDate,
            isVideo: false,
            resourceSize: 3_100_000
        )

        let plan = try SmartRestoreEngine.computePhotoDiff(
            taskID: UUID(),
            remoteRootPath: "/photos",
            remoteItems: [remote],
            localAssets: [local],
            authorizationStatus: .authorized,
            ledgerStore: RestoredPhotoLedgerStore(),
            timeZone: utc
        )
        XCTAssertTrue(plan.missingItems.isEmpty)
        XCTAssertEqual(plan.ambiguousItems.count, 1)
        XCTAssertFalse(plan.ambiguousItems[0].isSelected)
    }

    func testPhotoDiffBlockedWhenAccessIsLimited() {
        XCTAssertThrowsError(
            try SmartRestoreEngine.computePhotoDiff(
                taskID: UUID(),
                remoteRootPath: "/photos",
                remoteItems: [],
                localAssets: [],
                authorizationStatus: .limited
            )
        ) { error in
            XCTAssertEqual(error as? SmartRestoreError, .photoAccessLimited)
        }
    }

    func testRestoredPhotoDoesNotDuplicateOnNextBackup() throws {
        let store = RestoredPhotoLedgerStore.shared
        store.clearAllForTesting()
        defer { store.clearAllForTesting() }

        let taskID = UUID()
        let originalRelative = "2026/11/20261114_153022_OLDID1234567.heic"
        let originalFileName = "20261114_153022_OLDID1234567.heic"
        let newAssetID = "NEWASSET987654321/L0/001"

        store.recordRestoredPhoto(
            taskID: taskID,
            relativePath: originalRelative,
            originalFileName: originalFileName,
            newLocalIdentifier: newAssetID,
            remoteSize: 2_048_000
        )

        // 1. Next backup run: PhotoLibraryManager must resolve the restored asset to its original server filename & path
        let resolvedName = PhotoLibraryManager.resolveFileName(
            creationDate: Date(),
            localIdentifier: newAssetID,
            mediaType: .image,
            originalExtension: "heic",
            preserveOriginalExtension: true
        )
        let resolvedRelPath = PhotoLibraryManager.resolveRelativePath(
            creationDate: Date(),
            localIdentifier: newAssetID,
            mediaType: .image,
            folderStructure: .yearMonthSlash,
            originalExtension: "heic",
            preserveOriginalExtension: true
        )
        XCTAssertEqual(resolvedName, originalFileName)
        XCTAssertEqual(resolvedRelPath, originalRelative)

        // 2. Next Smart Restore scan: must recognize the restored photo via Ledger Pass 1 and report 0 missing
        let remoteItem = RemoteRestoreItem(
            relativePath: originalRelative,
            fullRemotePath: "/photos/\(originalRelative)",
            size: 2_048_000
        )
        let localSnapshot = LocalPhotoAssetSnapshot(
            localIdentifier: newAssetID,
            creationDate: Date(),
            isVideo: false,
            resourceSize: 2_048_000
        )
        let plan = try SmartRestoreEngine.computePhotoDiff(
            taskID: taskID,
            remoteRootPath: "/photos",
            remoteItems: [remoteItem],
            localAssets: [localSnapshot],
            authorizationStatus: .authorized,
            ledgerStore: store
        )
        XCTAssertEqual(plan.alreadyRestoredCount, 1)
        XCTAssertTrue(plan.missingItems.isEmpty)
    }

    func testCrashRecoverySkipsAlreadyMaterializedItem() async throws {
        final class CountingMockClient: RemoteStorageClient, @unchecked Sendable {
            var downloadCalls = 0
            func connect() async throws {}
            func disconnect() async {}
            func resolveEffectiveBackupRoot() async throws -> String { "/Backup" }
            func listDirectory(at path: String) async throws -> [RemoteStorageEntry] { [] }
            func downloadFile(remotePath: String, to localURL: URL, resumeOffset: Int64) async throws {
                downloadCalls += 1
                try Data("hello".utf8).write(to: localURL)
            }
        }

        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartRestoreCrashTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempFolder) }

        // Simulate a file that was already materialized on disk before a crash (size == 5 bytes)
        let existingFile = tempFolder.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: existingFile)

        let remoteItem = RemoteRestoreItem(
            relativePath: "notes.txt",
            fullRemotePath: "/Backup/notes.txt",
            size: 5
        )
        let candidate = SmartRestoreCandidate(
            remoteItem: remoteItem,
            state: .missingLocally,
            isSelected: true
        )
        let plan = SmartRestorePlan(
            taskID: UUID(),
            isPhotoLibrarySource: false,
            remoteRootPath: "/Backup",
            totalRemoteFiles: 1,
            unchangedCount: 0,
            alreadyRestoredCount: 0,
            caseCollisionCount: 0,
            autoSelectionDisabledByThreshold: false,
            missingItems: [candidate],
            ambiguousItems: [],
            conflictItems: [],
            ignoredItems: []
        )
        let snapshot = SmartRestoreTaskSnapshot(sourcePath: tempFolder.path, destinationPath: "/Backup")
        let mockClient = CountingMockClient()

        let result = try await SmartRestoreEngine.executeRestorePlan(
            snapshot: snapshot,
            plan: plan,
            client: mockClient
        )
        XCTAssertEqual(mockClient.downloadCalls, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.restoredCount, 0)
    }

    func testLargeMissingCountStartsUnselectedAndKeepBothName() {
        let remotes = (1...5).map { idx in
            RemoteRestoreItem(
                relativePath: "doc_\(idx).pdf",
                fullRemotePath: "/Backup/doc_\(idx).pdf",
                size: 100
            )
        }
        let plan = SmartRestoreEngine.computeFolderDiff(
            taskID: UUID(),
            remoteRootPath: "/Backup",
            remoteItems: remotes,
            localItems: [:],
            ignoredKeys: [],
            autoSelectThreshold: 3
        )
        XCTAssertTrue(plan.autoSelectionDisabledByThreshold)
        XCTAssertTrue(plan.missingItems.allSatisfy { !$0.isSelected })

        let existing: Set<NormalizedPathKey> = [
            NormalizedPathKey("sub/rapor.pdf"),
            NormalizedPathKey("sub/rapor (Restored).pdf")
        ]
        let keepBothName = NormalizedPathKey.makeKeepBothRelativePath(
            for: "sub/rapor.pdf",
            existingKeys: existing
        )
        XCTAssertEqual(keepBothName, "sub/rapor (Restored 2).pdf")
    }

    func testSFTPMapFileObjectsPreservesParentPath() {
        var values: [URLResourceKey: Any] = [:]
        values[.nameKey] = "20260101_120000_ABCDEF123456.jpg"
        values[.pathKey] = "20260101_120000_ABCDEF123456.jpg" // Bare filename as returned by SFTP readdir
        values[.fileSizeKey] = Int64(2048)
        values[.fileResourceTypeKey] = URLFileResourceType.regular
        let fileObject = FileObject(allValues: values)

        let entries = SFTPRestoreClient.mapFileObjects([fileObject], parentPath: "/Users/test/photos")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.fullPath, "/Users/test/photos/20260101_120000_ABCDEF123456.jpg")
    }

    func testFTPControlReplyFramingSingleAndMultiline() {
        XCTAssertFalse(FTPFileProvider.isCompleteFTPControlReply("220 Ready"))
        XCTAssertTrue(FTPFileProvider.isCompleteFTPControlReply("220 Ready\r\n"))

        // Multi-line banner must not complete until matching "220 " terminator arrives
        XCTAssertFalse(FTPFileProvider.isCompleteFTPControlReply("220-Welcome to NAS\r\n220-Line 2\r\n"))
        XCTAssertTrue(FTPFileProvider.isCompleteFTPControlReply("220-Welcome to NAS\r\n220-Line 2\r\n220 Ready\r\n"))

        // MLST 250- multi-line response with space-indented middle entry
        let mlstIncomplete = "250-Listing /photos\r\n type=dir;modify=20261118120000; /photos\r\n"
        XCTAssertFalse(FTPFileProvider.isCompleteFTPControlReply(mlstIncomplete))
        let mlstComplete = mlstIncomplete + "250 End\r\n"
        XCTAssertTrue(FTPFileProvider.isCompleteFTPControlReply(mlstComplete))
    }

    func testFTPLoopbackUploadAtomicRenameOverwriteAndDownload() async throws {
        final class LoopbackFTPServer: @unchecked Sendable {
            private let controlListenFD: Int32
            let port: Int
            private let lock = NSLock()
            private var files: [String: Data] = ["/photos/existing.txt": Data("old".utf8)]
            private(set) var controlConnectionsCount = 0
            private(set) var quitReceivedCount = 0
            private var isStopped = false

            init() throws {
                let fd = socket(AF_INET, SOCK_STREAM, 0)
                var yes: Int32 = 1
                setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = 0
                addr.sin_addr.s_addr = inet_addr("127.0.0.1")

                let bindRes = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                _ = listen(fd, 16)

                var boundAddr = sockaddr_in()
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                _ = withUnsafeMutablePointer(to: &boundAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        getsockname(fd, $0, &len)
                    }
                }
                self.controlListenFD = fd
                self.port = Int(UInt16(bigEndian: boundAddr.sin_port))
                XCTAssertGreaterThanOrEqual(fd, 0)
                XCTAssertEqual(bindRes, 0)
                Thread.detachNewThread { [weak self] in
                    self?.acceptLoop()
                }
            }

            func stop() {
                lock.withLock { isStopped = true }
                close(controlListenFD)
            }

            func storedData(for path: String) -> Data? {
                lock.withLock { files[path] }
            }

            private func acceptLoop() {
                while true {
                    var clientAddr = sockaddr_in()
                    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                    let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            accept(controlListenFD, $0, &len)
                        }
                    }
                    if clientFD < 0 { break }
                    lock.withLock { controlConnectionsCount += 1 }
                    Thread.detachNewThread { [weak self] in
                        self?.handleClient(fd: clientFD)
                    }
                }
            }

            private func sendLine(_ fd: Int32, _ text: String) {
                let data = Data((text + "\r\n").utf8)
                _ = data.withUnsafeBytes { ptr in
                     Darwin.send(fd, ptr.baseAddress, data.count, 0)
                }
            }

            private func openPassiveListener() -> (fd: Int32, port: Int) {
                let fd = socket(AF_INET, SOCK_STREAM, 0)
                var yes: Int32 = 1
                setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = 0
                addr.sin_addr.s_addr = inet_addr("127.0.0.1")
                _ = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                _ = listen(fd, 4)
                var bound = sockaddr_in()
                var len = socklen_t(MemoryLayout<sockaddr_in>.size)
                _ = withUnsafeMutablePointer(to: &bound) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        getsockname(fd, $0, &len)
                    }
                }
                return (fd, Int(UInt16(bigEndian: bound.sin_port)))
            }

            private func handleClient(fd: Int32) {
                defer { close(fd) }
                // Send multi-line 220 banner in two parts to test RFC 959 framing
                sendLine(fd, "220-Welcome to BackupFlow Loopback FTP")
                usleep(5_000)
                sendLine(fd, "220 Ready")

                var pasvListenFD: Int32 = -1
                var pendingRenameFrom: String?
                var buffer = Data()
                var temp = [UInt8](repeating: 0, count: 4096)

                defer {
                    if pasvListenFD >= 0 { close(pasvListenFD) }
                }

                while true {
                    let n = Darwin.recv(fd, &temp, temp.count, 0)
                    if n <= 0 { break }
                    buffer.append(temp, count: n)

                    while let range = buffer.range(of: Data("\r\n".utf8)) {
                        let lineData = buffer.subdata(in: 0..<range.lowerBound)
                        buffer.removeSubrange(0..<range.upperBound)
                        let line = String(data: lineData, encoding: .utf8) ?? ""
                        let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                        let cmd = parts.first?.uppercased() ?? ""
                        let arg = parts.count > 1 ? String(parts[1]) : ""

                        switch cmd {
                        case "USER":
                            sendLine(fd, "331 Password required")
                        case "PASS":
                            sendLine(fd, "230 Logged in")
                        case "OPTS":
                            sendLine(fd, "200 UTF8 set")
                        case "TYPE":
                            sendLine(fd, "200 Type set to I")
                        case "MLST", "MLSD":
                            sendLine(fd, "500 MLST not supported")
                        case "PASV":
                            if pasvListenFD >= 0 { close(pasvListenFD) }
                            let opened = openPassiveListener()
                            pasvListenFD = opened.fd
                            let p1 = opened.port >> 8
                            let p2 = opened.port & 0xFF
                            sendLine(fd, "227 Entering Passive Mode (127,0,0,1,\(p1),\(p2)).")
                        case "LIST":
                            var cAddr = sockaddr_in()
                            var cLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                            let dataFD = withUnsafeMutablePointer(to: &cAddr) {
                                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                    accept(pasvListenFD, $0, &cLen)
                                }
                            }
                            sendLine(fd, "150 Opening ASCII mode data connection")
                            if dataFD >= 0 {
                                let listing = "-rw-r--r-- 1 user staff 3 Nov 18 12:00 existing.txt\r\n"
                                _ = listing.withCString { ptr in
                                    Darwin.send(dataFD, ptr, strlen(ptr), 0)
                                }
                                close(dataFD)
                            }
                            close(pasvListenFD)
                            pasvListenFD = -1
                            sendLine(fd, "226 Directory send OK")
                        case "STOR":
                            var cAddr = sockaddr_in()
                            var cLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                            let dataFD = withUnsafeMutablePointer(to: &cAddr) {
                                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                    accept(pasvListenFD, $0, &cLen)
                                }
                            }
                            sendLine(fd, "150 Ok to send data")
                            var received = Data()
                            if dataFD >= 0 {
                                var chunk = [UInt8](repeating: 0, count: 16384)
                                while true {
                                    let r = Darwin.recv(dataFD, &chunk, chunk.count, 0)
                                    if r <= 0 { break }
                                    received.append(chunk, count: r)
                                }
                                close(dataFD)
                            }
                            close(pasvListenFD)
                            pasvListenFD = -1
                            lock.withLock { files[arg] = received }
                            sendLine(fd, "226 Transfer complete")
                        case "RETR":
                            var cAddr = sockaddr_in()
                            var cLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                            let dataFD = withUnsafeMutablePointer(to: &cAddr) {
                                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                    accept(pasvListenFD, $0, &cLen)
                                }
                            }
                            sendLine(fd, "150 Opening BINARY mode data connection")
                            if dataFD >= 0 {
                                if let payload = lock.withLock({ files[arg] }) {
                                    _ = payload.withUnsafeBytes { ptr in
                                        Darwin.send(dataFD, ptr.baseAddress, payload.count, 0)
                                    }
                                }
                                close(dataFD)
                            }
                            close(pasvListenFD)
                            pasvListenFD = -1
                            sendLine(fd, "226 Transfer complete")
                        case "RNFR":
                            pendingRenameFrom = arg
                            sendLine(fd, "350 Ready for RNTO")
                        case "RNTO":
                            guard let from = pendingRenameFrom else {
                                sendLine(fd, "503 Bad sequence of commands")
                                break
                            }
                            let targetExists = lock.withLock { files[arg] != nil }
                            if targetExists {
                                // Strict server behavior: reject RNTO when destination exists until DELE is sent
                                sendLine(fd, "550 Destination file already exists")
                            } else {
                                lock.withLock {
                                    files[arg] = files.removeValue(forKey: from)
                                }
                                pendingRenameFrom = nil
                                sendLine(fd, "250 Rename successful")
                            }
                        case "DELE":
                            _ = lock.withLock { files.removeValue(forKey: arg) }
                            sendLine(fd, "250 Deleted")
                        case "QUIT":
                            lock.withLock { quitReceivedCount += 1 }
                            sendLine(fd, "221 Goodbye")
                            return
                        default:
                            sendLine(fd, "200 OK")
                        }
                    }
                }
            }
        }

        let server = try LoopbackFTPServer()
        defer { server.stop() }

        let baseURL = URL(string: "ftp://127.0.0.1:\(server.port)/")!
        let credential = URLCredential(user: "test", password: "secret", persistence: .forSession)
        let provider = try XCTUnwrap(FTPFileProvider(baseURL: baseURL, mode: .passive, credential: credential))

        // 1. attributesOfItem on a server returning 500 for MLST must fall back to LIST and resume CheckedContinuation exactly once
        let attrFile: FileObject? = try await withCheckedThrowingContinuation { continuation in
            provider.attributesOfItem(path: "/photos/existing.txt") { file, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: file)
                }
            }
        }
        XCTAssertEqual(attrFile?.name, "existing.txt")

        // 2. Upload with atomicMoveTo over an existing file on a single control session
        let payload = Data(repeating: 0x42, count: 96_000)
        let localSource = FileManager.default.temporaryDirectory.appendingPathComponent("ftp-upload-\(UUID().uuidString).bin")
        let localDest = FileManager.default.temporaryDirectory.appendingPathComponent("ftp-download-\(UUID().uuidString).bin")
        try payload.write(to: localSource)
        defer {
            try? FileManager.default.removeItem(at: localSource)
            try? FileManager.default.removeItem(at: localDest)
        }

        let connectionsBeforeUpload = server.controlConnectionsCount
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = provider.copyItem(
                localFile: localSource,
                to: "/photos/existing.txt.backupflow-partial-1",
                overwrite: true,
                atomicMoveTo: "/photos/existing.txt"
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        // Upload + atomic RNFR/DELE/RNTO must reuse the single control connection
        XCTAssertEqual(server.controlConnectionsCount - connectionsBeforeUpload, 1)
        XCTAssertEqual(server.storedData(for: "/photos/existing.txt"), payload)

        // 3. Download file back and verify contents
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = provider.copyItem(path: "/photos/existing.txt", toLocalURL: localDest) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        let downloaded = try Data(contentsOf: localDest)
        XCTAssertEqual(downloaded, payload)
    }

    func testSFTPSyncEngineSkipsCreateDirectoryForUnchangedFilesAndDeduplicatesSubfolders() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("sftp-sync-dir-\(UUID().uuidString)", isDirectory: true)
        let subA = tempRoot.appendingPathComponent("2026/05", isDirectory: true)
        let subB = tempRoot.appendingPathComponent("2026/06", isDirectory: true)
        try FileManager.default.createDirectory(at: subA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subB, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        // 2026/05 has an already-uploaded unchanged file (should NOT trigger createDirectory)
        let unchangedFile = subA.appendingPathComponent("already_synced.jpg")
        try Data(repeating: 0x11, count: 128).write(to: unchangedFile)

        // 2026/06 has two new files in the same subfolder (should trigger createDirectory for /Backup/2026/06 only ONCE)
        let newFile1 = subB.appendingPathComponent("new1.jpg")
        let newFile2 = subB.appendingPathComponent("new2.jpg")
        try Data(repeating: 0x22, count: 256).write(to: newFile1)
        try Data(repeating: 0x33, count: 512).write(to: newFile2)

        let lock = NSLock()
        var createdDirs: [String] = []
        var uploadedPaths: [String] = []

        let engine = SFTPSyncEngine(
            prefetchRemoteFiles: { _ in
                ["2026/05/already_synced.jpg": 128]
            },
            createDirectory: { dir in
                lock.withLock { createdDirs.append(dir) }
            },
            deleteFile: { _ in },
            archiveFile: { _, _ in },
            uploadFile: { _, targetPath, _, _, _ in
                lock.withLock { uploadedPaths.append(targetPath) }
                return true
            },
            verifyUpload: { _, _ in },
            beginTransferBackgroundTask: nil,
            endTransferBackgroundTask: nil,
            isCancelled: { false },
            loadCheckpoint: { [] },
            markCheckpoint: { _ in },
            clearCheckpoint: {}
        )

        let result = try await engine.syncUploadDirectory(
            localURL: tempRoot,
            remotePath: "/Backup"
        )

        XCTAssertEqual(result.skippedFiles, 1)
        XCTAssertEqual(result.newFiles, 2)
        XCTAssertEqual(createdDirs, ["/Backup/2026/06"])
        XCTAssertEqual(Set(uploadedPaths), Set(["/Backup/2026/06/new1.jpg", "/Backup/2026/06/new2.jpg"]))
    }
}
