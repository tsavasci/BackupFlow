import FilesProvider
import Foundation
import Observation
import Photos

@MainActor
@Observable
final class RestoreService {
    struct RemoteEntry: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int64
        let modifiedDate: Date?
    }

    enum RestoreDestination: String, CaseIterable, Identifiable, Sendable {
        case files
        case photos

        var id: String { rawValue }
    }

    struct RestoreResult: Sendable {
        let downloadedURLs: [URL]
        let savedToPhotosCount: Int
        let failedCount: Int
        let tempDirectory: URL
    }

    private(set) var isDownloading = false
    private(set) var progress: Double = 0
    private(set) var currentFileName: String = ""
    private(set) var completedCount: Int = 0
    private(set) var totalCount: Int = 0

    private var activeTask: Task<RestoreResult, Error>?

    nonisolated static func isImageExtension(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "dng", "tiff", "tif", "bmp"].contains(ext.lowercased())
    }

    nonisolated static func isVideoExtension(_ ext: String) -> Bool {
        ["mov", "mp4", "m4v", "avi", "3gp", "mkv"].contains(ext.lowercased())
    }

    nonisolated static func archiveRootPath(for destinationPath: String) -> String {
        BackupArchive.safeRemotePath(basePath: destinationPath, relativePath: BackupArchive.directoryName)
    }

    func cancelDownload() {
        activeTask?.cancel()
        activeTask = nil
        isDownloading = false
    }

    func connect(for task: BackupTask) async throws {
        let store = BackupCredentialStore.shared
        let password = store.password(for: task.id) ?? task.serverPassword
        let username = task.serverUsername.isEmpty ? nil : task.serverUsername

        switch task.backupType {
        case .ftp:
            try await FTPService.shared.connect(
                host: task.serverHost,
                port: task.serverPort,
                username: username,
                password: password.isEmpty ? nil : password
            )
        case .sftp:
            let privateKey = task.sftpAuthMethod == .privateKey ? store.privateKey(for: task.id) : nil
            let passphrase = task.sftpAuthMethod == .privateKey ? store.passphrase(for: task.id) : nil
            try await SFTPService.shared.connect(
                host: task.serverHost,
                port: task.serverPort,
                username: username,
                password: task.sftpAuthMethod == .password ? (password.isEmpty ? nil : password) : nil,
                privateKey: privateKey,
                passphrase: passphrase
            )
        case .webdav:
            try await WebDAVService.shared.connect(
                host: task.serverHost,
                port: task.serverPort,
                username: username,
                password: password.isEmpty ? nil : password
            )
        }
    }

    func listDirectory(task: BackupTask, path: String) async throws -> [RemoteEntry] {
        let items: [FileObject]
        switch task.backupType {
        case .ftp:
            items = try await FTPService.shared.listDirectory(at: path)
        case .sftp:
            items = try await SFTPService.shared.listDirectory(at: path)
        case .webdav:
            items = try await WebDAVService.shared.listDirectory(at: path)
        }

        return items
            .filter { $0.name != "." && $0.name != ".." }
            .map { item in
                let fullPath = item.path.isEmpty
                    ? BackupArchive.safeRemotePath(basePath: path, relativePath: item.name)
                    : item.path
                return RemoteEntry(
                    id: fullPath,
                    name: item.name,
                    path: fullPath,
                    isDirectory: item.isDirectory,
                    size: item.size,
                    modifiedDate: item.modifiedDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory && !rhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func downloadFiles(
        task: BackupTask,
        entries: [RemoteEntry],
        destination: RestoreDestination
    ) async throws -> RestoreResult {
        let fileEntries = entries.filter { !$0.isDirectory }
        guard !fileEntries.isEmpty else {
            return RestoreResult(
                downloadedURLs: [],
                savedToPhotosCount: 0,
                failedCount: 0,
                tempDirectory: FileManager.default.temporaryDirectory
            )
        }

        isDownloading = true
        progress = 0
        completedCount = 0
        totalCount = fileEntries.count
        currentFileName = fileEntries.first?.name ?? ""

        let downloadTask = Task<RestoreResult, Error> {
            defer {
                Task { @MainActor in
                    self.isDownloading = false
                    self.activeTask = nil
                }
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("BackupFlowRestore-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            if destination == .photos {
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    throw BackupServiceError.fileOperationFailed
                }
            }

            var downloadedURLs: [URL] = []
            var savedToPhotosCount = 0
            var failedCount = 0

            for (index, entry) in fileEntries.enumerated() {
                try Task.checkCancellation()
                currentFileName = entry.name
                let sanitizedName = BackupArchive.sanitize(relativePath: entry.name)
                    .replacingOccurrences(of: "/", with: "_")
                let safeName = sanitizedName.isEmpty ? "file-\(index)" : sanitizedName
                let localURL = tempDir.appendingPathComponent(safeName)

                do {
                    try await downloadSingleFile(task: task, remotePath: entry.path, to: localURL)
                    downloadedURLs.append(localURL)

                    if destination == .photos {
                        let ext = localURL.pathExtension
                        if Self.isImageExtension(ext) {
                            try await saveImageToPhotoLibrary(url: localURL)
                            savedToPhotosCount += 1
                        } else if Self.isVideoExtension(ext) {
                            try await saveVideoToPhotoLibrary(url: localURL)
                            savedToPhotosCount += 1
                        }
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    failedCount += 1
                    debugLog("❌ Restore failed for \(entry.path): \(error.localizedDescription)")
                }

                completedCount = index + 1
                progress = Double(completedCount) / Double(totalCount)
            }

            return RestoreResult(
                downloadedURLs: downloadedURLs,
                savedToPhotosCount: savedToPhotosCount,
                failedCount: failedCount,
                tempDirectory: tempDir
            )
        }

        activeTask = downloadTask
        return try await downloadTask.value
    }

    private func downloadSingleFile(task: BackupTask, remotePath: String, to localURL: URL) async throws {
        switch task.backupType {
        case .ftp:
            try await FTPService.shared.downloadFile(remotePath: remotePath, to: localURL)
        case .sftp:
            try await SFTPService.shared.downloadFile(remotePath: remotePath, to: localURL)
        case .webdav:
            try await WebDAVService.shared.downloadFile(remotePath: remotePath, to: localURL)
        }
    }

    private func saveImageToPhotoLibrary(url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }
    }

    private func saveVideoToPhotoLibrary(url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
