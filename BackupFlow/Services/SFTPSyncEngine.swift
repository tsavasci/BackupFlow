import Foundation
import FilesProvider
import OSLog
import Photos

struct SFTPSyncEngine {
    let prefetchRemoteFiles: (String) async throws -> [String: Int64]
    let createDirectory: (String) async throws -> Void
    let deleteFile: (String) async throws -> Void
    let uploadFile: (URL, String, Int64, Bool) async throws -> Bool
    let beginTransferBackgroundTask: (() -> Void)?
    let endTransferBackgroundTask: (() -> Void)?
    let isCancelled: (() -> Bool)?
    
    private let logger = Logger(subsystem: "com.backupflow.app", category: "SFTPSyncEngine")
    
    func syncUploadDirectory(
        localURL: URL,
        remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPService.SyncResult {
        var result = FTPService.SyncResult()
        let remoteBase = remotePath

        let localFileMap = try collectLocalFiles(from: localURL.path)
        let totalFiles = localFileMap.count

        let remoteFileMap = try await prefetchRemoteFiles(remotePath)
        
        var transferred: Int64 = 0
        
        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            let targetPath = remotePath.hasSuffix("/") ? remotePath + relativePath : "\(remotePath)/\(relativePath)"
            let parentPath = (targetPath as NSString).deletingLastPathComponent
            if !parentPath.isEmpty && parentPath != "/" {
                try await createDirectory(parentPath)
            }
            
            let resourceValues = try localFileURL.resourceValues(forKeys: [.fileSizeKey])
            let localSize = Int64(resourceValues.fileSize ?? 0)
            
            if let remoteSize = remoteFileMap[relativePath], remoteSize == localSize {
                result.skippedFiles += 1
            } else if remoteFileMap[relativePath] != nil {
                beginTransferBackgroundTask?()
                defer { endTransferBackgroundTask?() }
                let didUpload = try await uploadFile(localFileURL, targetPath, localSize, true)
                if didUpload {
                    result.updatedFiles += 1
                    result.totalBytes += localSize
                    transferred += localSize
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            } else {
                beginTransferBackgroundTask?()
                defer { endTransferBackgroundTask?() }
                let didUpload = try await uploadFile(localFileURL, targetPath, localSize, true)
                if didUpload {
                    result.newFiles += 1
                    result.totalBytes += localSize
                    transferred += localSize
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            }
            
            progressHandler?(Double(index + 1) / Double(max(totalFiles, 1)) * 0.8)
        }
        
        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)
        for remoteRelativePath in remoteFileMap.keys {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            if !localRelativePaths.contains(remoteRelativePath) {
                let fullRemotePath = remoteBase.hasSuffix("/") ? remoteBase + remoteRelativePath : "\(remoteBase)/\(remoteRelativePath)"
                do {
                    try await deleteFile(fullRemotePath)
                    result.deletedFiles += 1
                } catch {
                    logger.error("Failed to delete orphaned file \(remoteRelativePath): \(error.localizedDescription)")
                }
            }
        }
        
        progressHandler?(1.0)
        logger.info("SFTP mirror sync completed - Uploaded: \(result.newFiles), Updated: \(result.updatedFiles), Skipped: \(result.skippedFiles), Deleted: \(result.deletedFiles)")
        
        return result
    }
    
    func syncBackupPhotoLibrary(
        mediaType: MediaType,
        remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPService.SyncResult {
        let photoManager = PhotoLibraryManager.shared
        var result = FTPService.SyncResult()
        
        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count
        
        let photosDir = remotePath
        logger.info("SFTP sync target directory: \(photosDir)")
        try? await createDirectory(photosDir)
        
        let existingFileMap = try await prefetchRemoteFiles(photosDir)
        
        for (index, asset) in assets.enumerated() {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            let fileName = photoManager.generateFileName(for: asset)
            guard let data = try await photoManager.getAssetData(asset: asset) else { continue }
            let localSize = Int64(data.count)
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let remotePath = "\(photosDir)/\(fileName)"
            
            if let remoteSize = existingFileMap[fileName], remoteSize == localSize {
                result.skippedFiles += 1
                result.totalBytes += localSize
            } else if existingFileMap[fileName] != nil {
                beginTransferBackgroundTask?()
                defer { endTransferBackgroundTask?() }
                let didUpload = try await uploadFile(tempURL, remotePath, localSize, true)
                if didUpload {
                    result.updatedFiles += 1
                    result.totalBytes += localSize
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            } else {
                beginTransferBackgroundTask?()
                defer { endTransferBackgroundTask?() }
                let didUpload = try await uploadFile(tempURL, remotePath, localSize, true)
                if didUpload {
                    result.newFiles += 1
                    result.totalBytes += localSize
                } else {
                    result.skippedFiles += 1
                    result.totalBytes += localSize
                }
            }
            
            let progress = Double(index + 1) / Double(max(totalCount, 1))
            progressHandler?(progress)
        }
        
        let processedFiles = Set(assets.map { photoManager.generateFileName(for: $0) })
        for remotePath in existingFileMap.keys {
            if isCancelled?() == true {
                throw BackupServiceError.cancelled
            }
            if !processedFiles.contains(remotePath) {
                do {
                    let fullRemotePath = "\(photosDir)/\(remotePath)"
                    try await deleteFile(fullRemotePath)
                    result.deletedFiles += 1
                } catch {
                    logger.error("Failed to delete orphaned file \(remotePath): \(error.localizedDescription)")
                }
            }
        }
        
        return result
    }
    
    private func collectLocalFiles(from localPath: String) throws -> [String: URL] {
        var fileMap: [String: URL] = [:]
        
        try FileAccessManager.shared.accessFileProviderFiles(at: localPath) { coordinatedURL in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: coordinatedURL.path, isDirectory: &isDirectory)
            guard exists && isDirectory.boolValue else {
                throw NSError(domain: "SFTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist or is not accessible"])
            }
            
            guard let enumerator = FileManager.default.enumerator(
                at: coordinatedURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw NSError(domain: "SFTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not enumerate directory"])
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
