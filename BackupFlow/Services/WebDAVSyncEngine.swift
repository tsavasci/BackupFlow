import Foundation
import OSLog
import FilesProvider

struct WebDAVSyncEngine {
    let provider: WebDAVFileProvider
    let fileManager: FileManager
    let logger: Logger
    let ensureDirectoryExists: (String) async throws -> Void
    let deleteFile: (String) async throws -> Void
    let archiveFile: (String, String) async throws -> Void
    let setCurrentFile: @MainActor @Sendable (String) -> Void
    let isCancelled: () -> Bool
    let uploadFile: @Sendable (URL, String, (@Sendable (Double) -> Void)?) async throws -> Void
    let verifyUpload: @Sendable (URL, String) async throws -> Void
    var maxConcurrentUploads: @Sendable () -> Int = { 1 }

    func syncUploadDirectory(
        localPath: String,
        remoteBasePath: String,
        options: BackupExecutionOptions = .defaults,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> (filesUploaded: Int, filesSkipped: Int, filesFailed: Int, bytesTransferred: Int64, deletedFiles: Int, verifiedFiles: Int) {
        logger.info("Starting mirror sync: \(localPath) -> \(remoteBasePath)")

        if !options.isDryRun {
            try await ensureDirectoryExists(remoteBasePath)
        }

        let localFileMap = try collectLocalFiles(from: localPath)
        let totalFiles = localFileMap.count
        logger.info("Found \(totalFiles) local files to sync")

        let remoteFileMap = try await listAllFiles(at: remoteBasePath)
        logger.info("Found \(remoteFileMap.count) remote files")

        struct PendingUpload: Sendable {
            let relativePath: String
            let localFileURL: URL
            let remotePath: String
            let localSize: Int64
            let fileName: String
        }

        var uploaded = 0, skipped = 0, failed = 0, deleted = 0, verified = 0, archived = 0
        var transferred: Int64 = 0
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()
        var pendingUploads: [PendingUpload] = []

        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            guard !isCancelled() else { throw BackupServiceError.cancelled }
            guard LocalFileAvailability.isReadableNow(localFileURL) else {
                logger.info("☁️ iCloud'da, henüz indirilmedi; sonraki yedekte yüklenecek: \(relativePath)")
                continue
            }
            let remotePath = BackupArchive.safeRemotePath(basePath: remoteBasePath, relativePath: relativePath)

            let parentPath = (remotePath as NSString).deletingLastPathComponent
            if !options.isDryRun && !parentPath.isEmpty && parentPath != "/" {
                try await ensureDirectoryExists(parentPath)
            }

            let localSize = Int64((try? localFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let fileName = (relativePath as NSString).lastPathComponent

            if let remoteFile = remoteFileMap[relativePath],
               remoteFile.size == localSize,
               remoteFile.name == fileName {
                logger.debug("Skipping identical file: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                skipped += 1
                progressHandler(Double(index + 1) / Double(max(totalFiles, 1)) * 0.8)
            } else {
                pendingUploads.append(PendingUpload(
                    relativePath: relativePath,
                    localFileURL: localFileURL,
                    remotePath: remotePath,
                    localSize: localSize,
                    fileName: fileName
                ))
            }
        }

        let skippedCount = skipped
        let concurrency = maxConcurrentUploads()
        let outcomes = try await ConcurrentTransferQueue.run(
            items: pendingUploads,
            maxConcurrency: concurrency,
            isCancelled: isCancelled
        ) { [logger, uploadFile, verifyUpload, setCurrentFile] itemIndex, item -> (uploaded: Int, failed: Int, verified: Int, bytes: Int64) in
            await setCurrentFile(item.fileName)
            do {
                logger.info("Uploading: \(item.relativePath) (\(ByteCountFormatter.string(fromByteCount: item.localSize, countStyle: .file)))")
                if !options.isDryRun {
                    try await uploadFile(item.localFileURL, item.remotePath) { fileProgress in
                        if concurrency == 1 {
                            let fileShare = 0.8 / Double(max(totalFiles, 1))
                            let overallProgress = (Double(skippedCount + itemIndex) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                            progressHandler(min(max(overallProgress, 0.0), 0.8))
                        }
                    }
                    var itemVerified = 0
                    if options.checksumMode == .verifyUploads {
                        try await verifyUpload(item.localFileURL, item.remotePath)
                        itemVerified = 1
                    }
                    BackupRunTally.shared.recordUpload(bytes: item.localSize)
                    progressHandler(min(Double(skippedCount + itemIndex + 1) / Double(max(totalFiles, 1)) * 0.8, 0.8))
                    return (1, 0, itemVerified, item.localSize)
                }
                return (1, 0, 0, 0)
            } catch {
                logger.error("Upload failed for \(item.relativePath): \(error.localizedDescription)")
                return (0, 1, 0, 0)
            }
        }

        for outcome in outcomes {
            uploaded += outcome.uploaded
            failed += outcome.failed
            verified += outcome.verified
            transferred += outcome.bytes
        }

        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)

        if failed > 0 {
            logger.warning("Skipping orphan deletion because \(failed) upload(s) failed.")
        } else {
            for (remotePath, _) in remoteFileMap where !BackupArchive.isReserved(relativePath: remotePath) {
                guard !isCancelled() else { throw BackupServiceError.cancelled }
                if !localRelativePaths.contains(remotePath) {
                    let fullRemotePath = BackupArchive.safeRemotePath(basePath: remoteBasePath, relativePath: remotePath)
                    switch options.deletionPolicy {
                    case .mirror:
                        if options.isDryRun {
                            deleted += 1
                        } else {
                            do {
                                logger.info("Deleting orphaned file: \(remotePath)")
                                try await deleteFile(fullRemotePath)
                                deleted += 1
                                logger.debug("Successfully deleted: \(remotePath)")
                            } catch {
                                logger.error("Failed to delete orphaned file \(remotePath): \(error.localizedDescription)")
                            }
                        }
                    case .appendOnly:
                        logger.info("Skipping orphan deletion because append-only policy is active: \(remotePath)")
                    case .archive:
                        if options.isDryRun {
                            logger.info("Would archive orphaned file: \(remotePath)")
                        } else {
                            do {
                                let archivePath = BackupArchive.destinationPath(
                                    basePath: remoteBasePath,
                                    runIdentifier: archiveRunIdentifier,
                                    relativePath: remotePath
                                )
                                try await archiveFile(fullRemotePath, archivePath)
                                archived += 1
                                logger.info("Archived orphaned file: \(remotePath)")
                            } catch {
                                logger.error("Failed to archive orphaned file \(remotePath): \(error.localizedDescription)")
                                throw error
                            }
                        }
                    }
                }
            }
        }

        progressHandler(1.0)
        logger.info("Mirror sync completed - Uploaded: \(uploaded), Skipped: \(skipped), Failed: \(failed), Deleted: \(deleted), Archived: \(archived)")

        return (uploaded, skipped, failed, transferred, deleted, verified)
    }

    private func listAllFiles(at path: String, relativeTo basePath: String = "") async throws -> [String: FileObject] {
        var allFiles: [String: FileObject] = [:]

        let files = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileObject], Error>) in
            var didResume = false
            func safeThrow(_ error: Error) {
                if didResume { return }
                didResume = true
                continuation.resume(throwing: error)
            }
            func safeResume(_ value: [FileObject]) {
                if didResume { return }
                didResume = true
                continuation.resume(returning: value)
            }

            provider.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    safeThrow(error)
                } else {
                    safeResume(files)
                }
            }
        }

        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            if BackupArchive.isReserved(relativePath: relativePath) {
                continue
            }
            if file.isDirectory {
                let subdirPath = path == "/" ? "/\(file.name)" : "\(path)/\(file.name)"
                let subFiles = try await listAllFiles(at: subdirPath, relativeTo: relativePath)
                allFiles.merge(subFiles) { _, new in new }
            } else {
                allFiles[relativePath] = file
            }
        }

        return allFiles
    }

    private func collectLocalFiles(from localPath: String) throws -> [String: URL] {
        var fileMap: [String: URL] = [:]

        logger.info("🔍 Collecting files from: \(localPath)")

        do {
            try FileAccessManager.shared.accessFileProviderFiles(at: localPath) { coordinatedURL in
                logger.info("📂 Accessing coordinated URL: \(coordinatedURL.path)")

                var isDirectory: ObjCBool = false
                let exists = fileManager.fileExists(atPath: coordinatedURL.path, isDirectory: &isDirectory)
                logger.info("📂 Directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")

                guard exists && isDirectory.boolValue else {
                    throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.not_accessible".localized])
                }

                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: coordinatedURL.path)
                    logger.info("📁 Directory contents count: \(contents.count)")
                    if contents.isEmpty {
                        logger.warning("⚠️ Directory is empty: \(coordinatedURL.path)")
                    } else {
                        logger.info("📄 Directory contents: \(contents.prefix(5).joined(separator: ", "))\(contents.count > 5 ? "..." : "")")
                    }
                } catch {
                    logger.error("❌ Could not read directory contents: \(error.localizedDescription)")
                    throw error
                }

                guard let enumerator = fileManager.enumerator(
                    at: coordinatedURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    logger.error("❌ Could not create file enumerator for: \(coordinatedURL.path)")
                    throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.enumeration_failed".localized])
                }

                var fileCount = 0
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory != true {
                            // iOS may store names decomposed (NFD); servers expect composed "ş", "ğ", "ü".
                            let relativePath = String(fileURL.path.dropFirst(coordinatedURL.path.count + 1)).precomposedStringWithCanonicalMapping
                            fileMap[relativePath] = fileURL
                            fileCount += 1

                            if fileCount <= 5 {
                                logger.info("📄 Found file: \(relativePath)")
                            }
                        }
                    } catch {
                        logger.warning("⚠️ Could not get resource values for: \(fileURL.path) - \(error.localizedDescription)")
                    }
                }

                logger.info("📊 Total files collected: \(fileMap.count)")
            }
        } catch {
            logger.error("❌ Failed to access files: \(error.localizedDescription)")
            throw error
        }

        return fileMap
    }
}
