import Foundation
import FilesProvider
import OSLog
import Photos

struct SFTPSyncEngine {
    let prefetchRemoteFiles: (String) async throws -> [String: Int64]
    let createDirectory: (String) async throws -> Void
    let deleteFile: (String) async throws -> Void
    let archiveFile: (String, String) async throws -> Void
    let uploadFile: (URL, String, Int64, Bool, ((Double) -> Void)?) async throws -> Bool
    let verifyUpload: (URL, String) async throws -> Void
    let beginTransferBackgroundTask: (() -> Void)?
    let endTransferBackgroundTask: (() -> Void)?
    let isCancelled: (() -> Bool)?
    let loadCheckpoint: (() async -> Set<String>)?
    let markCheckpoint: ((String) async -> Void)?
    let clearCheckpoint: (() async -> Void)?
    
    private let logger = Logger(subsystem: "com.backupflow.app", category: "SFTPSyncEngine")
    
    func syncUploadDirectory(
        localURL: URL,
        remotePath: String,
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPService.SyncResult {
        var result = FTPService.SyncResult()
        let remoteBase = remotePath
        beginTransferBackgroundTask?()
        defer { endTransferBackgroundTask?() }

        let localFileMap = try collectLocalFiles(from: localURL.path)
        let totalFiles = localFileMap.count

        let remoteFileMap = try await prefetchRemoteFiles(remotePath)
        var checkpoint = await loadCheckpoint?() ?? []
        if !checkpoint.isEmpty {
            logger.info("SFTP resume checkpoint loaded (\(checkpoint.count) files)")
        }
        
        var transferred: Int64 = 0
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()
        
        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            let targetPath = remotePath.hasSuffix("/") ? remotePath + relativePath : "\(remotePath)/\(relativePath)"
            let parentPath = (targetPath as NSString).deletingLastPathComponent
            if !options.isDryRun && !parentPath.isEmpty && parentPath != "/" {
                try await createDirectory(parentPath)
            }
            
            let resourceValues = try localFileURL.resourceValues(forKeys: [.fileSizeKey])
            let localSize = Int64(resourceValues.fileSize ?? 0)

            if checkpoint.contains(relativePath), remoteFileMap[relativePath] != nil {
                result.skippedFiles += 1
                result.totalBytes += localSize
                progressHandler?(Double(index + 1) / Double(max(totalFiles, 1)) * 0.8)
                continue
            }
            
            if let remoteSize = remoteFileMap[relativePath], remoteSize == localSize {
                result.skippedFiles += 1
                result.totalBytes += localSize
                if !options.isDryRun {
                    checkpoint.insert(relativePath)
                    await markCheckpoint?(relativePath)
                }
            } else if remoteFileMap[relativePath] != nil {
                let didUpload = options.isDryRun ? true : try await uploadFile(localFileURL, targetPath, localSize, true) { fileProgress in
                    let fileShare = 0.8 / Double(max(totalFiles, 1))
                    let overallProgress = (Double(index) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                    progressHandler?(min(max(overallProgress, 0.0), 0.8))
                }
                if didUpload {
                    if !options.isDryRun && options.checksumMode == .verifyUploads {
                        try await verifyUpload(localFileURL, targetPath)
                        result.verifiedFiles += 1
                    }
                    result.updatedFiles += 1
                    result.totalBytes += localSize
                    transferred += localSize
                    if !options.isDryRun {
                        checkpoint.insert(relativePath)
                        await markCheckpoint?(relativePath)
                    }
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            } else {
                let didUpload = options.isDryRun ? true : try await uploadFile(localFileURL, targetPath, localSize, true) { fileProgress in
                    let fileShare = 0.8 / Double(max(totalFiles, 1))
                    let overallProgress = (Double(index) / Double(max(totalFiles, 1)) * 0.8) + (fileProgress * fileShare)
                    progressHandler?(min(max(overallProgress, 0.0), 0.8))
                }
                if didUpload {
                    if !options.isDryRun && options.checksumMode == .verifyUploads {
                        try await verifyUpload(localFileURL, targetPath)
                        result.verifiedFiles += 1
                    }
                    result.newFiles += 1
                    result.totalBytes += localSize
                    transferred += localSize
                    if !options.isDryRun {
                        checkpoint.insert(relativePath)
                        await markCheckpoint?(relativePath)
                    }
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            }
            
            progressHandler?(Double(index + 1) / Double(max(totalFiles, 1)) * 0.8)
        }
        
        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)
        for remoteRelativePath in remoteFileMap.keys where !BackupArchive.isReserved(relativePath: remoteRelativePath) {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            if !localRelativePaths.contains(remoteRelativePath) {
                let fullRemotePath = remoteBase.hasSuffix("/") ? remoteBase + remoteRelativePath : "\(remoteBase)/\(remoteRelativePath)"
                switch options.deletionPolicy {
                case .mirror:
                    if options.isDryRun {
                        result.deletedFiles += 1
                    } else {
                        do {
                            try await deleteFile(fullRemotePath)
                            result.deletedFiles += 1
                        } catch {
                            logger.error("Failed to delete orphaned file \(remoteRelativePath): \(error.localizedDescription)")
                        }
                    }
                case .appendOnly:
                    logger.info("Skipping orphan deletion because append-only policy is active: \(remoteRelativePath)")
                case .archive:
                    if options.isDryRun {
                        logger.info("Would archive orphaned file: \(remoteRelativePath)")
                    } else {
                        do {
                            let archivePath = BackupArchive.destinationPath(
                                basePath: remoteBase,
                                runIdentifier: archiveRunIdentifier,
                                relativePath: remoteRelativePath
                            )
                            try await archiveFile(fullRemotePath, archivePath)
                            logger.info("Archived orphaned file: \(remoteRelativePath)")
                        } catch {
                            logger.error("Failed to archive orphaned file \(remoteRelativePath): \(error.localizedDescription)")
                            throw error
                        }
                    }
                }
            }
        }
        
        progressHandler?(1.0)
        if !options.isDryRun {
            await clearCheckpoint?()
        }
        logger.info("SFTP mirror sync completed - Uploaded: \(result.newFiles), Updated: \(result.updatedFiles), Skipped: \(result.skippedFiles), Deleted: \(result.deletedFiles)")
        
        return result
    }
    
    func syncBackupPhotoLibrary(
        mediaType: MediaType,
        remotePath: String,
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPService.SyncResult {
        let photoManager = PhotoLibraryManager.shared
        var result = FTPService.SyncResult()
        beginTransferBackgroundTask?()
        defer { endTransferBackgroundTask?() }
        
        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count
        
        let photosDir = remotePath
        logger.info("SFTP sync target directory: \(photosDir)")
        if !options.isDryRun {
            do {
                try await createDirectory(photosDir)
            } catch {
                logger.error("SFTP base directory creation failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        let existingFileMap = try await prefetchRemoteFiles(photosDir)
        var checkpoint = await loadCheckpoint?() ?? []
        if !checkpoint.isEmpty {
            logger.info("SFTP resume checkpoint loaded (\(checkpoint.count) files)")
        }
        
        for (index, asset) in assets.enumerated() {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            let fileName = photoManager.generateFileName(for: asset)

            if checkpoint.contains(fileName), existingFileMap[fileName] != nil {
                result.skippedFiles += 1
                let progress = Double(index + 1) / Double(max(totalCount, 1))
                progressHandler?(progress)
                continue
            }

            let exportResult = await photoManager.exportAssetToTemporaryFile(asset: asset, fileName: fileName)
            let tempURL: URL
            let localSize: Int64
            switch exportResult {
            case .success(let exportedURL, let exportedSize):
                tempURL = exportedURL
                localSize = exportedSize
            case .iCloudOnly, .timedOut, .unavailable:
                continue
            }
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let remotePath = "\(photosDir)/\(fileName)"
            
            if let remoteSize = existingFileMap[fileName], remoteSize == localSize {
                result.skippedFiles += 1
                result.totalBytes += localSize
                if !options.isDryRun {
                    checkpoint.insert(fileName)
                    await markCheckpoint?(fileName)
                }
            } else if existingFileMap[fileName] != nil {
                let didUpload = options.isDryRun ? true : try await uploadFile(tempURL, remotePath, localSize, true) { fileProgress in
                    let assetShare = 1.0 / Double(max(totalCount, 1))
                    let overallProgress = (Double(index) / Double(max(totalCount, 1))) + (fileProgress * assetShare)
                    progressHandler?(min(max(overallProgress, 0.0), 1.0))
                }
                if didUpload {
                    if !options.isDryRun && options.checksumMode == .verifyUploads {
                        try await verifyUpload(tempURL, remotePath)
                        result.verifiedFiles += 1
                    }
                    result.updatedFiles += 1
                    result.totalBytes += localSize
                    if !options.isDryRun {
                        checkpoint.insert(fileName)
                        await markCheckpoint?(fileName)
                    }
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            } else {
                let didUpload = options.isDryRun ? true : try await uploadFile(tempURL, remotePath, localSize, true) { fileProgress in
                    let assetShare = 1.0 / Double(max(totalCount, 1))
                    let overallProgress = (Double(index) / Double(max(totalCount, 1))) + (fileProgress * assetShare)
                    progressHandler?(min(max(overallProgress, 0.0), 1.0))
                }
                if didUpload {
                    if !options.isDryRun && options.checksumMode == .verifyUploads {
                        try await verifyUpload(tempURL, remotePath)
                        result.verifiedFiles += 1
                    }
                    result.newFiles += 1
                    result.totalBytes += localSize
                    if !options.isDryRun {
                        checkpoint.insert(fileName)
                        await markCheckpoint?(fileName)
                    }
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            }
            
            let progress = Double(index + 1) / Double(max(totalCount, 1))
            progressHandler?(progress)
        }
        
        let processedFiles = Set(assets.map { photoManager.generateFileName(for: $0) })
        let canDeletePhotoOrphans = options.permitsPhotoOrphanDeletion(
            hasFullLibraryAccess: photoManager.hasFullLibraryAccess,
            visibleAssetCount: assets.count
        )
        if !canDeletePhotoOrphans && options.deletionPolicy == .mirror {
            logger.warning("Skipping orphan photo deletion because full Photo Library access is unavailable or the visible library is empty.")
        }
        let archiveRunIdentifier = BackupArchive.makeRunIdentifier()
        for remotePath in existingFileMap.keys where !BackupArchive.isReserved(relativePath: remotePath) {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            if !processedFiles.contains(remotePath) {
                let fullRemotePath = "\(photosDir)/\(remotePath)"
                switch options.deletionPolicy {
                case .mirror where canDeletePhotoOrphans:
                    if options.isDryRun {
                        result.deletedFiles += 1
                    } else {
                        do {
                            try await deleteFile(fullRemotePath)
                            result.deletedFiles += 1
                        } catch {
                            logger.error("Failed to delete orphaned file \(remotePath): \(error.localizedDescription)")
                        }
                    }
                case .mirror:
                    break
                case .appendOnly:
                    logger.info("Skipping orphan photo deletion because append-only policy is active: \(remotePath)")
                case .archive:
                    if options.isDryRun {
                        logger.info("Would archive orphaned photo: \(remotePath)")
                    } else {
                        do {
                            let archivePath = BackupArchive.destinationPath(
                                basePath: photosDir,
                                runIdentifier: archiveRunIdentifier,
                                relativePath: remotePath
                            )
                            try await archiveFile(fullRemotePath, archivePath)
                            logger.info("Archived orphaned photo: \(remotePath)")
                        } catch {
                            logger.error("Failed to archive orphaned photo \(remotePath): \(error.localizedDescription)")
                            throw error
                        }
                    }
                }
            }
        }

        if !options.isDryRun {
            await clearCheckpoint?()
        }
        
        return result
    }
    
    private func collectLocalFiles(from localPath: String) throws -> [String: URL] {
        var fileMap: [String: URL] = [:]
        
        try FileAccessManager.shared.accessFileProviderFiles(at: localPath) { coordinatedURL in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: coordinatedURL.path, isDirectory: &isDirectory)
            guard exists && isDirectory.boolValue else {
                throw NSError(domain: "SFTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.not_accessible".localized])
            }
            
            guard let enumerator = FileManager.default.enumerator(
                at: coordinatedURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw NSError(domain: "SFTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.directory.enumeration_failed".localized])
            }
            
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory != true {
                    let relativePath = String(fileURL.path.dropFirst(coordinatedURL.path.count + 1))
                    fileMap[relativePath] = fileURL
                }
            }
        }
        
        return fileMap
    }
}
