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
    let setCurrentFile: (String) -> Void
    let isCancelled: () -> Bool
    let uploadFile: (URL, String, ((Double) -> Void)?) async throws -> Void
    let verifyUpload: (URL, String) async throws -> Void

    func syncUploadDirectory(
        localPath: String,
        remoteBasePath: String,
        options: BackupExecutionOptions = .defaults,
        progressHandler: @escaping (Double) -> Void
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

        var uploaded = 0, skipped = 0, failed = 0, deleted = 0, verified = 0, archived = 0
        var transferred: Int64 = 0
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()

        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            guard !isCancelled() else { throw BackupServiceError.cancelled }
            let remotePath = remoteBasePath == "/" ? "/\(relativePath)" : "\(remoteBasePath)/\(relativePath)"

            let parentPath = (remotePath as NSString).deletingLastPathComponent
            if !options.isDryRun && !parentPath.isEmpty && parentPath != "/" {
                try await ensureDirectoryExists(parentPath)
            }

            let localSize = Int64((try? localFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let fileName = localFileURL.lastPathComponent
            setCurrentFile(fileName)

            if let remoteFile = remoteFileMap[relativePath],
               remoteFile.size == localSize,
               remoteFile.name == fileName {
                logger.debug("Skipping identical file: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                skipped += 1
            } else {
                do {
                    logger.info("Uploading: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                    if !options.isDryRun {
                        try await uploadFile(localFileURL, remotePath) { fileProgress in
                            let fileShare = 0.8 / Double(max(totalFiles, 1))
                            let overallProgress = (Double(index) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                            progressHandler(min(max(overallProgress, 0.0), 0.8))
                        }
                        if options.checksumMode == .verifyUploads {
                            try await verifyUpload(localFileURL, remotePath)
                            verified += 1
                        }
                    }
                    logger.debug("Successfully uploaded: \(relativePath)")
                    uploaded += 1
                    if !options.isDryRun {
                        transferred += localSize
                    }
                } catch {
                    logger.error("Upload failed for \(relativePath): \(error.localizedDescription)")
                    failed += 1
                }
            }

            progressHandler(Double(index + 1) / Double(max(totalFiles, 1)) * 0.8)
        }

        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)

        if failed > 0 {
            logger.warning("Skipping orphan deletion because \(failed) upload(s) failed.")
        } else {
            for (remotePath, _) in remoteFileMap where !BackupArchive.isReserved(relativePath: remotePath) {
                guard !isCancelled() else { throw BackupServiceError.cancelled }
                if !localRelativePaths.contains(remotePath) {
                    let fullRemotePath = remoteBasePath == "/" ? "/\(remotePath)" : "\(remoteBasePath)/\(remotePath)"
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
                            let relativePath = String(fileURL.path.dropFirst(coordinatedURL.path.count + 1))
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
