import Foundation
import FilesProvider
import OSLog
import Photos

struct FTPSyncResult {
    var newFiles: Int = 0
    var updatedFiles: Int = 0
    var skippedFiles: Int = 0
    var iCloudSkippedFiles: Int = 0
    var timedOutAssetReads: Int = 0
    var failedAssetReads: Int = 0
    var deletedFiles: Int = 0
    var verifiedFiles: Int = 0
    var totalBytes: Int64 = 0

    var totalProcessed: Int {
        return newFiles + updatedFiles + skippedFiles
    }
}

enum FTPFileComparisonResult {
    case new
    case updated
    case unchanged
}

struct FTPSyncEngine {
    let provider: FTPFileProvider
    let logger: Logger
    let isVerboseLoggingEnabled: Bool
    let fastPhotoNameSkipEnabled: Bool
    let isCancelled: () -> Bool
    let createDirectory: (String) async throws -> Void
    let deleteFile: (String) async throws -> Void
    let archiveFile: (String, String) async throws -> Void
    let uploadFile: (URL, String, ((Double) -> Void)?) async throws -> Void
    let verifyUpload: (URL, String) async throws -> Void
    let setCurrentFile: (String) -> Void
    let formatBytes: (Int64) -> String
    let mapError: (Error) -> FTPError
    let uploadPhotoFile: (URL, String, String) async throws -> Void

    func syncUploadDirectory(
        localURL: URL,
        remotePath: String = "",
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPSyncResult {
        guard !isCancelled() else {
            throw BackupServiceError.cancelled
        }

        var result = FTPSyncResult()
        let localPath = localURL.path

        logger.info("Starting enhanced mirror sync: \(localPath) -> \(remotePath)")

        var ensuredDirectories = Set<String>()
        if !options.isDryRun && !remotePath.isEmpty {
            try await createDirectory(remotePath)
            ensuredDirectories.insert(remotePath)
        }

        let localFileMap = try collectLocalFiles(from: localPath)
        let totalFiles = localFileMap.count
        logger.info("Found \(totalFiles) local files to sync")

        let remoteBasePath = remotePath.isEmpty ? "/" : remotePath
        let remoteFileMap = try await listAllFiles(at: remoteBasePath)
        logger.info("Found \(remoteFileMap.count) remote files")

        var uploadedCount = 0, skippedCount = 0, failedCount = 0, deletedCount = 0
        var archivedCount = 0
        var transferredBytes: Int64 = 0
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()

        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            guard !isCancelled() else { throw BackupServiceError.cancelled }

            let targetPath = remotePath.isEmpty ? relativePath : "\(remotePath)/\(relativePath)"
            let parentPath = (targetPath as NSString).deletingLastPathComponent
            if !options.isDryRun,
               !parentPath.isEmpty,
               parentPath != "/",
               !ensuredDirectories.contains(parentPath) {
                try await createDirectory(parentPath)
                ensuredDirectories.insert(parentPath)
            }

            let resourceValues = try localFileURL.resourceValues(forKeys: [.fileSizeKey])
            let localSize = Int64(resourceValues.fileSize ?? 0)
            let fileName = localFileURL.lastPathComponent

            let comparisonResult = compareFileEnhanced(
                relativePath: relativePath,
                localSize: localSize,
                existingFiles: remoteFileMap
            )

            switch comparisonResult {
            case .unchanged:
                result.skippedFiles += 1
                result.totalBytes += localSize
                skippedCount += 1
                setCurrentFile("backup.current_file.skipped_file".localized(with: fileName))
                if isVerboseLoggingEnabled {
                    logger.debug("Skipping identical file: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                }
            case .new:
                setCurrentFile("backup.current_file.uploading_file".localized(with: fileName))
                if !options.isDryRun {
                    try await uploadFile(localFileURL, targetPath) { fileProgress in
                        let fileShare = 0.8 / Double(max(totalFiles, 1))
                        let overallProgress = (Double(index) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                        progressHandler?(min(max(overallProgress, 0.0), 0.8))
                    }
                    if options.checksumMode == .verifyUploads {
                        try await verifyUpload(localFileURL, targetPath)
                        result.verifiedFiles += 1
                    }
                }
                result.newFiles += 1
                result.totalBytes += localSize
                if !options.isDryRun {
                    transferredBytes += localSize
                }
                uploadedCount += 1
                if isVerboseLoggingEnabled {
                    logger.debug("Successfully uploaded new file: \(relativePath)")
                }
            case .updated:
                setCurrentFile("backup.current_file.updating_file".localized(with: fileName))
                if !options.isDryRun {
                    try await uploadFile(localFileURL, targetPath) { fileProgress in
                        let fileShare = 0.8 / Double(max(totalFiles, 1))
                        let overallProgress = (Double(index) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                        progressHandler?(min(max(overallProgress, 0.0), 0.8))
                    }
                    if options.checksumMode == .verifyUploads {
                        try await verifyUpload(localFileURL, targetPath)
                        result.verifiedFiles += 1
                    }
                }
                result.updatedFiles += 1
                result.totalBytes += localSize
                if !options.isDryRun {
                    transferredBytes += localSize
                }
                uploadedCount += 1
                if isVerboseLoggingEnabled {
                    logger.debug("Successfully updated file: \(relativePath)")
                }
            }

            let progress = Double(index + 1) / Double(max(totalFiles, 1)) * 0.8
            progressHandler?(progress)
        }

        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)

        for (remotePath, _) in remoteFileMap where !BackupArchive.isReserved(relativePath: remotePath) {
            if !localRelativePaths.contains(remotePath) {
                let fullRemotePath = remoteBasePath == "/" ? "/\(remotePath)" : "\(remoteBasePath)/\(remotePath)"
                switch options.deletionPolicy {
                case .mirror:
                    if options.isDryRun {
                        result.deletedFiles += 1
                        deletedCount += 1
                    } else {
                        do {
                            logger.info("Deleting orphaned file: \(remotePath)")
                            try await deleteFile(fullRemotePath)
                            result.deletedFiles += 1
                            deletedCount += 1
                            logger.debug("Successfully deleted orphaned file: \(remotePath)")
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
                            archivedCount += 1
                            logger.info("Archived orphaned file: \(remotePath)")
                        } catch {
                            logger.error("Failed to archive orphaned file \(remotePath): \(error.localizedDescription)")
                            throw error
                        }
                    }
                }
            }
        }

        progressHandler?(1.0)

        debugLog("✅ BackupFlow: FTP enhanced mirror sync completed")
        debugLog("   📊 Sync Report:")
        debugLog("   📤 New files uploaded: \(result.newFiles)")
        debugLog("   🔄 Files updated: \(result.updatedFiles)")
        debugLog("   ⏭ Files skipped (identical): \(result.skippedFiles)")
        debugLog("   🗑 Orphaned files deleted: \(result.deletedFiles)")
        debugLog("   📦 Orphaned files archived: \(archivedCount)")
        debugLog("   ❌ Failed operations: \(failedCount)")
        debugLog("   💾 Total data transferred: \(formatBytes(transferredBytes))")

        if isVerboseLoggingEnabled {
            logger.info("Enhanced mirror sync completed - Uploaded: \(uploadedCount), Skipped: \(skippedCount), Failed: \(failedCount), Deleted: \(deletedCount)")
        }

        return result
    }

    func compareFileEnhanced(
        relativePath: String,
        localSize: Int64,
        existingFiles: [String: FileObject]
    ) -> FTPFileComparisonResult {
        guard let remoteFile = existingFiles[relativePath] else {
            return .new
        }
        return (localSize == remoteFile.size) ? .unchanged : .updated
    }

    func listAllFiles(at path: String, relativeTo basePath: String = "") async throws -> [String: FileObject] {
        var allFiles: [String: FileObject] = [:]

        let files = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileObject], Error>) in
            provider.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    continuation.resume(throwing: mapError(error))
                } else {
                    continuation.resume(returning: files)
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

    func collectLocalFiles(from localPath: String) throws -> [String: URL] {
        var fileMap: [String: URL] = [:]
        logger.info("🔍 Collecting files from: \(localPath)")

        do {
            try FileAccessManager.shared.accessFileProviderFiles(at: localPath) { coordinatedURL in
                logger.info("📂 Accessing coordinated URL: \(coordinatedURL.path)")

                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: coordinatedURL.path, isDirectory: &isDirectory)
                logger.info("📂 Directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")

                guard exists && isDirectory.boolValue else {
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.not_accessible".localized])
                }

                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: coordinatedURL.path)
                    if isVerboseLoggingEnabled {
                        logger.info("📁 Directory contents count: \(contents.count)")
                        if contents.isEmpty {
                            logger.warning("⚠️ Directory is empty: \(coordinatedURL.path)")
                        } else {
                            logger.info("📄 Directory contents: \(contents.prefix(5).joined(separator: ", "))\(contents.count > 5 ? "..." : "")")
                        }
                    }
                } catch {
                    logger.error("❌ Could not read directory contents: \(error.localizedDescription)")
                    throw error
                }

                guard let enumerator = FileManager.default.enumerator(
                    at: coordinatedURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    logger.error("❌ Could not create file enumerator for: \(coordinatedURL.path)")
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.enumeration_failed".localized])
                }

                var fileCount = 0
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory != true {
                            let relativePath = String(fileURL.path.dropFirst(coordinatedURL.path.count + 1))
                            fileMap[relativePath] = fileURL
                            fileCount += 1

                            if isVerboseLoggingEnabled && fileCount <= 5 {
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

    func syncBackupPhotoLibrary(
        mediaType: MediaType,
        includeICloudAssets: Bool,
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPSyncResult {
        let photoManager = PhotoLibraryManager.shared
        var result = FTPSyncResult()

        setCurrentFile("backup.current_file.scanning_library".localized)
        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count

        debugLog("📸 BackupFlow: \(totalCount) medya dosyası bulundu")

        let photosDir = "photos"
        if !options.isDryRun {
            do {
                try await createDirectory(photosDir)
                debugLog("📁 BackupFlow: Photos klasörü hazır: \(photosDir)")
            } catch {
                debugLog("⚠️ BackupFlow: Photos klasörü oluşturma hatası (devam edilecek): \(error)")
            }
        }

        let existingFileMap = try await listAllFiles(at: photosDir)
        logger.info("Found \(existingFileMap.count) existing photo files on FTP")
        if fastPhotoNameSkipEnabled {
            logger.info("Fast photo skip mode enabled (name-based)")
        }
        
        let legacyNamePattern = #"^\d{8}_\d{6}_\d{3}\.(jpg|mp4)$"#
        let hasLegacyNames = existingFileMap.values.contains { file in
            file.name.range(of: legacyNamePattern, options: .regularExpression) != nil
        }
        if hasLegacyNames {
            logger.warning("⚠️ Legacy photo filenames detected on FTP. Orphan deletion will be skipped to avoid data loss.")
        }

        for (index, asset) in assets.enumerated() {
            guard !isCancelled() else { throw BackupServiceError.cancelled }
            
            let stableFileName = photoManager.generateFileName(for: asset)

            if fastPhotoNameSkipEnabled, let remoteFile = existingFileMap[stableFileName] {
                result.skippedFiles += 1
                result.totalBytes += max(remoteFile.size, 0)
                setCurrentFile("backup.current_file.skipped_file".localized(with: stableFileName))
                if isVerboseLoggingEnabled {
                    logger.debug("Fast-skip by name: \(stableFileName)")
                }
                let progress = Double(index + 1) / Double(max(totalCount, 1)) * 0.8
                progressHandler?(progress)
                continue
            }

            let exportResult = await photoManager.exportAssetToTemporaryFile(
                asset: asset,
                fileName: stableFileName,
                allowNetworkAccess: includeICloudAssets
            )
            let localURL: URL
            let localSize: Int64
            switch exportResult {
            case .success(let exportedURL, let exportedSize):
                localURL = exportedURL
                localSize = exportedSize
            case .iCloudOnly:
                result.iCloudSkippedFiles += 1
                debugLog("☁️ BackupFlow: iCloud-only medya atlandı (ayar: sadece lokal): \(asset.localIdentifier)")
                continue
            case .timedOut:
                result.timedOutAssetReads += 1
                debugLog("⏱️ BackupFlow: Asset okuma zaman aşımı: \(asset.localIdentifier)")
                continue
            case .unavailable:
                result.failedAssetReads += 1
                debugLog("⚠️ BackupFlow: Asset verisi alınamadı: \(asset.localIdentifier)")
                continue
            }
            defer { try? FileManager.default.removeItem(at: localURL) }

            let remotePath = "\(photosDir)/\(stableFileName)"

            let comparisonResult = compareFileEnhanced(
                relativePath: stableFileName,
                localSize: localSize,
                existingFiles: existingFileMap
            )

            switch comparisonResult {
            case .unchanged:
                result.skippedFiles += 1
                result.totalBytes += localSize
                setCurrentFile("backup.current_file.skipped_file".localized(with: stableFileName))
                debugLog("⏭ BackupFlow: Aynı dosya pas geçildi: \(stableFileName) (\(formatBytes(localSize)))")
            case .new:
                setCurrentFile("backup.current_file.uploading_file".localized(with: stableFileName))
                if !options.isDryRun {
                    try await uploadPhotoFile(localURL, remotePath, stableFileName)
                    if options.checksumMode == .verifyUploads {
                        try await verifyUpload(localURL, remotePath)
                        result.verifiedFiles += 1
                    }
                }
                result.newFiles += 1
                result.totalBytes += localSize
                debugLog("📤 BackupFlow: Yeni dosya yüklendi: \(stableFileName) (\(formatBytes(localSize)))")
            case .updated:
                setCurrentFile("backup.current_file.updating_file".localized(with: stableFileName))
                if !options.isDryRun {
                    try await uploadPhotoFile(localURL, remotePath, stableFileName)
                    if options.checksumMode == .verifyUploads {
                        try await verifyUpload(localURL, remotePath)
                        result.verifiedFiles += 1
                    }
                }
                result.updatedFiles += 1
                result.totalBytes += localSize
                debugLog("🔄 BackupFlow: Güncellenmiş dosya yüklendi: \(stableFileName) (\(formatBytes(localSize)))")
            }

            let progress = Double(index + 1) / Double(max(totalCount, 1)) * 0.8
            progressHandler?(progress)
        }

        if hasLegacyNames {
            logger.warning("Skipping orphan deletion while legacy filenames exist to prevent accidental data loss.")
            progressHandler?(1.0)
            return result
        }
        
        logger.info("Checking for orphaned photo files to delete...")
        let processedFiles = Set(assets.map { photoManager.generateFileName(for: $0) })
        let canDeletePhotoOrphans = options.permitsPhotoOrphanDeletion(
            hasFullLibraryAccess: photoManager.hasFullLibraryAccess,
            visibleAssetCount: assets.count
        )

        if !canDeletePhotoOrphans && options.deletionPolicy == .mirror {
            logger.warning("Skipping orphan photo deletion because full Photo Library access is unavailable or the visible library is empty.")
        }

        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()
        for (remotePath, remoteFile) in existingFileMap where !BackupArchive.isReserved(relativePath: remotePath) {
            if !processedFiles.contains(remoteFile.name) {
                let fullRemotePath = "\(photosDir)/\(remotePath)"
                switch options.deletionPolicy {
                case .mirror where canDeletePhotoOrphans:
                    if options.isDryRun {
                        result.deletedFiles += 1
                    } else {
                        do {
                            try await deleteFile(fullRemotePath)
                            result.deletedFiles += 1
                            debugLog("🗑 BackupFlow: Silinmiş fotoğraf FTP'den kaldırıldı: \(remoteFile.name)")
                            logger.debug("Successfully deleted orphaned photo: \(remoteFile.name)")
                        } catch {
                            debugLog("⚠️ BackupFlow: Fotoğraf silinemedi: \(remoteFile.name), hata: \(error)")
                            logger.error("Failed to delete orphaned photo \(remoteFile.name): \(error.localizedDescription)")
                        }
                    }
                case .mirror:
                    break
                case .appendOnly:
                    logger.info("Skipping orphan photo deletion because append-only policy is active: \(remoteFile.name)")
                case .archive:
                    if options.isDryRun {
                        logger.info("Would archive orphaned photo: \(remoteFile.name)")
                    } else {
                        do {
                            let archivePath = BackupArchive.destinationPath(
                                basePath: photosDir,
                                runIdentifier: archiveRunIdentifier,
                                relativePath: remotePath
                            )
                            try await archiveFile(fullRemotePath, archivePath)
                            logger.info("Archived orphaned photo: \(remoteFile.name)")
                        } catch {
                            logger.error("Failed to archive orphaned photo \(remoteFile.name): \(error.localizedDescription)")
                            throw error
                        }
                    }
                }
            }
        }

        progressHandler?(1.0)
        return result
    }
}
