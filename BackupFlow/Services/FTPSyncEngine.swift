import Foundation
import FilesProvider
import OSLog
import Photos

struct FTPSyncResult {
    var newFiles: Int = 0
    var updatedFiles: Int = 0
    var skippedFiles: Int = 0
    var deletedFiles: Int = 0
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
    let isCancelled: () -> Bool
    let createDirectory: (String) async throws -> Void
    let deleteFile: (String) async throws -> Void
    let uploadFile: (URL, String) async throws -> Void
    let setCurrentFile: (String) -> Void
    let formatBytes: (Int64) -> String
    let mapError: (Error) -> FTPError
    let uploadPhotoData: (Data, String, String) async throws -> Void

    func syncUploadDirectory(
        localURL: URL,
        remotePath: String = "",
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPSyncResult {
        guard !isCancelled() else {
            throw FTPError.fileOperationFailed
        }

        var result = FTPSyncResult()
        let localPath = localURL.path

        logger.info("Starting enhanced mirror sync: \(localPath) -> \(remotePath)")

        if !remotePath.isEmpty {
            try await createDirectory(remotePath)
        }

        let localFileMap = try collectLocalFiles(from: localPath)
        let totalFiles = localFileMap.count
        logger.info("Found \(totalFiles) local files to sync")

        let remoteBasePath = remotePath.isEmpty ? "/" : remotePath
        let remoteFileMap = try await listAllFiles(at: remoteBasePath)
        logger.info("Found \(remoteFileMap.count) remote files")

        var uploadedCount = 0, skippedCount = 0, failedCount = 0, deletedCount = 0
        var transferredBytes: Int64 = 0

        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            guard !isCancelled() else { break }

            let targetPath = remotePath.isEmpty ? relativePath : "\(remotePath)/\(relativePath)"
            let parentPath = (targetPath as NSString).deletingLastPathComponent
            if !parentPath.isEmpty && parentPath != "/" {
                try await createDirectory(parentPath)
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
                setCurrentFile("Atlandı: \(fileName)")
                if isVerboseLoggingEnabled {
                    logger.debug("Skipping identical file: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                }
            case .new:
                setCurrentFile("Yükleniyor: \(fileName)")
                try await uploadFile(localFileURL, targetPath)
                result.newFiles += 1
                result.totalBytes += localSize
                transferredBytes += localSize
                uploadedCount += 1
                if isVerboseLoggingEnabled {
                    logger.debug("Successfully uploaded new file: \(relativePath)")
                }
            case .updated:
                setCurrentFile("Güncelleniyor: \(fileName)")
                try await uploadFile(localFileURL, targetPath)
                result.updatedFiles += 1
                result.totalBytes += localSize
                transferredBytes += localSize
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

        for (remotePath, _) in remoteFileMap {
            if !localRelativePaths.contains(remotePath) {
                let fullRemotePath = remoteBasePath == "/" ? "/\(remotePath)" : "\(remoteBasePath)/\(remotePath)"
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
        }

        progressHandler?(1.0)

        print("✅ BackupFlow: FTP enhanced mirror sync completed")
        print("   📊 Sync Report:")
        print("   📤 New files uploaded: \(result.newFiles)")
        print("   🔄 Files updated: \(result.updatedFiles)")
        print("   ⏭ Files skipped (identical): \(result.skippedFiles)")
        print("   🗑 Orphaned files deleted: \(result.deletedFiles)")
        print("   ❌ Failed operations: \(failedCount)")
        print("   💾 Total data transferred: \(formatBytes(transferredBytes))")

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
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist or is not accessible"])
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
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not enumerate directory"])
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
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> FTPSyncResult {
        let photoManager = PhotoLibraryManager.shared
        var result = FTPSyncResult()

        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count

        print("📸 BackupFlow: \(totalCount) medya dosyası bulundu")

        let photosDir = "photos"
        do {
            try await createDirectory(photosDir)
            print("📁 BackupFlow: Photos klasörü hazır: \(photosDir)")
        } catch {
            print("⚠️ BackupFlow: Photos klasörü oluşturma hatası (devam edilecek): \(error)")
        }

        let existingFileMap = try await listAllFiles(at: photosDir)
        logger.info("Found \(existingFileMap.count) existing photo files on FTP")

        for (index, asset) in assets.enumerated() {
            guard !isCancelled() else { break }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = asset.creationDate ?? Date()
            let dateString = dateFormatter.string(from: date)

            let fileExtension = asset.mediaType == .image ? "jpg" : "mp4"
            let safeFileName = "\(dateString)_\(String(index + 1).padding(toLength: 3, withPad: "0", startingAt: 0)).\(fileExtension)"

            guard let data = try await photoManager.getAssetData(asset: asset) else {
                print("⚠️ BackupFlow: Asset verisi alınamadı: \(asset.localIdentifier)")
                continue
            }

            let localSize = Int64(data.count)
            let remotePath = "\(photosDir)/\(safeFileName)"

            let comparisonResult = compareFileEnhanced(
                relativePath: safeFileName,
                localSize: localSize,
                existingFiles: existingFileMap
            )

            switch comparisonResult {
            case .unchanged:
                result.skippedFiles += 1
                result.totalBytes += localSize
                setCurrentFile("Atlandı: \(safeFileName)")
                print("⏭ BackupFlow: Aynı dosya pas geçildi: \(safeFileName) (\(formatBytes(localSize)))")
            case .new:
                setCurrentFile("Yükleniyor: \(safeFileName)")
                try await uploadPhotoData(data, remotePath, safeFileName)
                result.newFiles += 1
                result.totalBytes += localSize
                print("📤 BackupFlow: Yeni dosya yüklendi: \(safeFileName) (\(formatBytes(localSize)))")
            case .updated:
                setCurrentFile("Güncelleniyor: \(safeFileName)")
                try await uploadPhotoData(data, remotePath, safeFileName)
                result.updatedFiles += 1
                result.totalBytes += localSize
                print("🔄 BackupFlow: Güncellenmiş dosya yüklendi: \(safeFileName) (\(formatBytes(localSize)))")
            }

            let progress = Double(index + 1) / Double(totalCount)
            progressHandler?(progress)
        }

        logger.info("Checking for orphaned photo files to delete...")
        let processedFiles = Set(assets.enumerated().map { index, asset in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = asset.creationDate ?? Date()
            let dateString = dateFormatter.string(from: date)
            let fileExtension = asset.mediaType == .image ? "jpg" : "mp4"
            return "\(dateString)_\(String(index + 1).padding(toLength: 3, withPad: "0", startingAt: 0)).\(fileExtension)"
        })

        for (remotePath, remoteFile) in existingFileMap {
            if !processedFiles.contains(remoteFile.name) {
                do {
                    let fullRemotePath = "\(photosDir)/\(remotePath)"
                    try await deleteFile(fullRemotePath)
                    result.deletedFiles += 1
                    print("🗑 BackupFlow: Silinmiş fotoğraf FTP'den kaldırıldı: \(remoteFile.name)")
                    logger.debug("Successfully deleted orphaned photo: \(remoteFile.name)")
                } catch {
                    print("⚠️ BackupFlow: Fotoğraf silinemedi: \(remoteFile.name), hata: \(error)")
                    logger.error("Failed to delete orphaned photo \(remoteFile.name): \(error.localizedDescription)")
                }
            }
        }

        return result
    }
}
