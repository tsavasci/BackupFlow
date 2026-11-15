import FilesProvider
import Foundation

nonisolated struct RemoteStorageEntry: Sendable, Hashable {
    let name: String
    let fullPath: String
    let isDirectory: Bool
    let size: Int64
    let modifiedDate: Date?
}

nonisolated struct SmartRestoreTaskSnapshot: Sendable {
    let id: UUID
    let displayName: String
    let backupType: BackupType
    let serverHost: String
    let serverPort: Int
    let serverUsername: String?
    let serverPassword: String?
    let sftpAuthMethod: SFTPAuthMethod
    let privateKey: String?
    let passphrase: String?
    let sourcePath: String
    let destinationPath: String
    let mediaType: MediaType
    let photoFolderStructure: PhotoFolderStructure
    let preserveOriginalPhotoFormat: Bool

    var isPhotoLibrarySource: Bool {
        sourcePath == "PHOTOS_LIBRARY"
    }

    @MainActor
    init(task: BackupTask) {
        let store = BackupCredentialStore.shared
        let rawPass = store.password(for: task.id) ?? task.serverPassword
        let trimmedUser = task.serverUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = task.id
        self.displayName = task.displayName
        self.backupType = task.backupType
        self.serverHost = task.serverHost
        self.serverPort = task.serverPort
        self.serverUsername = trimmedUser.isEmpty ? nil : trimmedUser
        self.serverPassword = rawPass.isEmpty ? nil : rawPass
        self.sftpAuthMethod = task.sftpAuthMethod
        self.privateKey = task.sftpAuthMethod == .privateKey ? store.privateKey(for: task.id) : nil
        self.passphrase = task.sftpAuthMethod == .privateKey ? store.passphrase(for: task.id) : nil
        self.sourcePath = task.sourcePath ?? ""
        self.destinationPath = task.destinationPath
        self.mediaType = task.mediaType
        self.photoFolderStructure = task.photoFolderStructure
        self.preserveOriginalPhotoFormat = task.preserveOriginalPhotoFormat
    }

    nonisolated init(
        id: UUID = UUID(),
        displayName: String = "Test Task",
        backupType: BackupType = .sftp,
        serverHost: String = "localhost",
        serverPort: Int = 22,
        serverUsername: String? = "user",
        serverPassword: String? = nil,
        sftpAuthMethod: SFTPAuthMethod = .password,
        privateKey: String? = nil,
        passphrase: String? = nil,
        sourcePath: String,
        destinationPath: String = "/Backups",
        mediaType: MediaType = .photosAndVideos,
        photoFolderStructure: PhotoFolderStructure = .flat,
        preserveOriginalPhotoFormat: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.backupType = backupType
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.serverUsername = serverUsername
        self.serverPassword = serverPassword
        self.sftpAuthMethod = sftpAuthMethod
        self.privateKey = privateKey
        self.passphrase = passphrase
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.mediaType = mediaType
        self.photoFolderStructure = photoFolderStructure
        self.preserveOriginalPhotoFormat = preserveOriginalPhotoFormat
    }
}

protocol RemoteStorageClient: Sendable {
    func connect() async throws
    func disconnect() async
    func resolveEffectiveBackupRoot() async throws -> String
    func listDirectory(at path: String) async throws -> [RemoteStorageEntry]
    func downloadFile(remotePath: String, to localURL: URL, resumeOffset: Int64) async throws
}

extension RemoteStorageClient {
    func downloadFile(remotePath: String, to localURL: URL) async throws {
        try await downloadFile(remotePath: remotePath, to: localURL, resumeOffset: 0)
    }

    nonisolated static func mapFileObjects(_ items: [FileObject], parentPath: String) -> [RemoteStorageEntry] {
        items
            .filter { $0.name != "." && $0.name != ".." && !$0.name.isEmpty }
            .map { item in
                let fullPath = item.path.isEmpty
                    ? BackupArchive.safeRemotePath(basePath: parentPath, relativePath: item.name)
                    : item.path
                return RemoteStorageEntry(
                    name: item.name.precomposedStringWithCanonicalMapping,
                    fullPath: fullPath,
                    isDirectory: item.isDirectory,
                    size: max(item.size, 0),
                    modifiedDate: item.modifiedDate
                )
            }
    }
}

enum RemoteRestoreClientFactory {
    nonisolated static func makeClient(for snapshot: SmartRestoreTaskSnapshot) -> any RemoteStorageClient {
        switch snapshot.backupType {
        case .ftp:
            return FTPRestoreClient(snapshot: snapshot)
        case .sftp:
            return SFTPRestoreClient(snapshot: snapshot)
        case .webdav:
            return WebDAVRestoreClient(snapshot: snapshot)
        }
    }
}

// MARK: - FTP Adapter

nonisolated struct FTPRestoreClient: RemoteStorageClient {
    let snapshot: SmartRestoreTaskSnapshot

    func connect() async throws {
        try await FTPService.shared.connect(
            host: snapshot.serverHost,
            port: snapshot.serverPort,
            username: snapshot.serverUsername,
            password: snapshot.serverPassword
        )
    }

    func disconnect() async {
        await MainActor.run {
            FTPService.shared.disconnect()
        }
    }

    func resolveEffectiveBackupRoot() async throws -> String {
        let trimmed = snapshot.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName: String = snapshot.isPhotoLibrarySource
            ? "/photos"
            : "/\(URL(fileURLWithPath: snapshot.sourcePath).lastPathComponent)"
        if trimmed.isEmpty || trimmed == "/" {
            return fallbackName
        }
        var normalized = trimmed.replacingOccurrences(of: "\\", with: "/")
        if !normalized.hasPrefix("/") { normalized = "/" + normalized }
        while normalized.count > 1 && normalized.hasSuffix("/") { normalized.removeLast() }
        return normalized
    }

    func listDirectory(at path: String) async throws -> [RemoteStorageEntry] {
        let items = try await FTPService.shared.listDirectory(at: path)
        return Self.mapFileObjects(items, parentPath: path)
    }

    func downloadFile(remotePath: String, to localURL: URL, resumeOffset: Int64) async throws {
        try await FTPService.shared.downloadFile(remotePath: remotePath, to: localURL)
    }
}

// MARK: - SFTP Adapter

nonisolated struct SFTPRestoreClient: RemoteStorageClient {
    let snapshot: SmartRestoreTaskSnapshot

    func connect() async throws {
        try await SFTPService.shared.connect(
            host: snapshot.serverHost,
            port: snapshot.serverPort,
            username: snapshot.serverUsername,
            password: snapshot.sftpAuthMethod == .password ? snapshot.serverPassword : nil,
            privateKey: snapshot.privateKey,
            passphrase: snapshot.passphrase
        )
    }

    func disconnect() async {
        await MainActor.run {
            SFTPService.shared.disconnect()
        }
    }

    func resolveEffectiveBackupRoot() async throws -> String {
        let trimmed = snapshot.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "/" {
            return trimmed
        }
        if snapshot.isPhotoLibrarySource {
            return "photos"
        }
        let folder = URL(fileURLWithPath: snapshot.sourcePath).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return folder.isEmpty ? "backup" : folder
    }

    func listDirectory(at path: String) async throws -> [RemoteStorageEntry] {
        let items = try await SFTPService.shared.listDirectory(at: path)
        return Self.mapFileObjects(items, parentPath: path)
    }

    func downloadFile(remotePath: String, to localURL: URL, resumeOffset: Int64) async throws {
        try await SFTPService.shared.downloadFile(remotePath: remotePath, to: localURL)
    }
}

// MARK: - WebDAV Adapter

nonisolated struct WebDAVRestoreClient: RemoteStorageClient {
    let snapshot: SmartRestoreTaskSnapshot

    func connect() async throws {
        try await WebDAVService.shared.connect(
            host: snapshot.serverHost,
            port: snapshot.serverPort,
            username: snapshot.serverUsername,
            password: snapshot.serverPassword
        )
    }

    func disconnect() async {
        await MainActor.run {
            WebDAVService.shared.disconnect()
        }
    }

    func resolveEffectiveBackupRoot() async throws -> String {
        let trimmed = snapshot.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRoot: String = {
            if trimmed.isEmpty || trimmed == "/" || trimmed == "/remote.php/dav/files/username/" {
                return "/"
            }
            var p = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
            while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
            return p
        }()

        let childFolder: String = snapshot.isPhotoLibrarySource
            ? "photos"
            : URL(fileURLWithPath: snapshot.sourcePath).lastPathComponent

        guard !childFolder.isEmpty else { return normalizedRoot }
        let candidateSubfolder = normalizedRoot == "/" ? "/\(childFolder)" : "\(normalizedRoot)/\(childFolder)"

        // WebDAV backups place photos inside `<dest>/photos` and folders inside `<dest>/<sourceFolderName>`.
        // Check if that subfolder exists on the server; if not, fall back to `normalizedRoot`.
        if let rootEntries = try? await listDirectory(at: normalizedRoot),
           rootEntries.contains(where: { $0.isDirectory && NormalizedPathKey($0.name) == NormalizedPathKey(childFolder) }) {
            return candidateSubfolder
        }
        return normalizedRoot
    }

    func listDirectory(at path: String) async throws -> [RemoteStorageEntry] {
        let items = try await WebDAVService.shared.listDirectory(at: path)
        return Self.mapFileObjects(items, parentPath: path)
    }

    func downloadFile(remotePath: String, to localURL: URL, resumeOffset: Int64) async throws {
        try await WebDAVService.shared.downloadFile(remotePath: remotePath, to: localURL)
    }
}
