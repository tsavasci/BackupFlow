import Foundation
import Crypto
import FilesProvider
import OSLog
import UIKit
import Network

struct SFTPHostKeyResult {
    let isNewHostKey: Bool
    let fingerprint: String?
}

import Citadel
import NIO
import UserNotifications

private enum SFTPFailureKind {
    case authentication
    case timeout
    case hostKeyMismatch
    case connection
    case fileOperation
    case unavailable
}

private enum SFTPFailureCode: Int {
    case authentication = 1001
    case timeout = 1002
    case hostKeyMismatch = 1003
    case connection = 1004
    case fileOperation = 1005
    case unavailable = 1006
}

private func makeSFTPError(
    _ kind: SFTPFailureKind,
    details: String? = nil,
    underlying: Error? = nil
) -> NSError {
    let message: String
    let code: Int
    switch kind {
    case .authentication:
        code = SFTPFailureCode.authentication.rawValue
        message = "error.sftp.authentication".localized
    case .timeout:
        code = SFTPFailureCode.timeout.rawValue
        message = "error.sftp.timeout".localized
    case .hostKeyMismatch:
        code = SFTPFailureCode.hostKeyMismatch.rawValue
        message = "error.sftp.host_key_mismatch".localized
    case .connection:
        code = SFTPFailureCode.connection.rawValue
        message = "error.sftp.connection".localized
    case .fileOperation:
        code = SFTPFailureCode.fileOperation.rawValue
        message = "error.sftp.file_operation".localized
    case .unavailable:
        code = SFTPFailureCode.unavailable.rawValue
        message = "error.sftp.unavailable".localized
    }

    var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        userInfo[NSLocalizedDescriptionKey] = "error.with_detail".localized(with: message, details)
    }
    if let underlying {
        userInfo[NSUnderlyingErrorKey] = underlying
    }
    return NSError(domain: "SFTPError", code: code, userInfo: userInfo)
}

private func classifySFTPError(_ error: Error, defaultKind: SFTPFailureKind) -> Error {
    if let backupError = error as? BackupServiceError, case .cancelled = backupError {
        return backupError
    }

    if let hostKeyError = error as? SFTPHostKeyValidationError {
        switch hostKeyError {
        case .changedHostKey:
            return makeSFTPError(.hostKeyMismatch, details: hostKeyError.localizedDescription, underlying: error)
        case .keychainFailure:
            return makeSFTPError(.connection, details: hostKeyError.localizedDescription, underlying: error)
        }
    }

    let nsError = error as NSError
    if nsError.domain == "SFTPError" {
        return error
    }

    if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut:
            return makeSFTPError(.timeout, details: urlError.localizedDescription, underlying: error)
        case .userAuthenticationRequired, .userCancelledAuthentication:
            return makeSFTPError(.authentication, details: urlError.localizedDescription, underlying: error)
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
            return makeSFTPError(.connection, details: urlError.localizedDescription, underlying: error)
        default:
            return makeSFTPError(defaultKind, details: urlError.localizedDescription, underlying: error)
        }
    }

    let message = nsError.localizedDescription.lowercased()
    if message.contains("host key") || message.contains("fingerprint") || message.contains("known host") || message.contains("mismatch") {
        return makeSFTPError(.hostKeyMismatch, details: nsError.localizedDescription, underlying: error)
    }
    if message.contains("timed out") || message.contains("timeout") {
        return makeSFTPError(.timeout, details: nsError.localizedDescription, underlying: error)
    }
    if message.contains("auth") || message.contains("password") || message.contains("permission denied") || message.contains("userauth") || message.contains("access denied") {
        return makeSFTPError(.authentication, details: nsError.localizedDescription, underlying: error)
    }
    if message.contains("socket") || message.contains("connect") || message.contains("handshake") || message.contains("network") || message.contains("active session") {
        return makeSFTPError(.connection, details: nsError.localizedDescription, underlying: error)
    }
    if message.contains("file") || message.contains("directory") || message.contains("stat") || message.contains("read") || message.contains("write") || message.contains("sftp") {
        return makeSFTPError(.fileOperation, details: nsError.localizedDescription, underlying: error)
    }

    return makeSFTPError(defaultKind, details: nsError.localizedDescription, underlying: error)
}

private actor SFTPResumeCheckpointStore {
    private let defaults = UserDefaults.standard
    private let keyPrefix = "sftp.resume.checkpoint."

    private func storageKey(for id: String) -> String {
        let encoded = Data(id.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return keyPrefix + encoded
    }

    func load(id: String) -> Set<String> {
        let key = storageKey(for: id)
        guard let list = defaults.array(forKey: key) as? [String] else {
            return []
        }
        return Set(list)
    }

    func mark(id: String, item: String) {
        let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var values = load(id: id)
        values.insert(normalized)
        defaults.set(Array(values), forKey: storageKey(for: id))
    }

    func clear(id: String) {
        defaults.removeObject(forKey: storageKey(for: id))
    }
}

final class SFTPService: NSObject, @unchecked Sendable {
    static let shared = SFTPService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "SFTPService")
    private let cancellationLock = NSLock()
    private let stateLock = NSLock()
    private var isCancelled = false
    private let connectionLock = NSLock()
    private var lastConnection: (host: String, port: Int, username: String, password: String)?
    
    private var sshClient: SSHClient?
    private var sftpClient: SFTPClient?
    private var _currentFile: String = ""
    private var _progress: Double = 0
    private var _currentFileBytesTransferred: Int64 = 0
    private var _currentFileTotalBytes: Int64 = 0
    private var _transferSpeedBytesPerSecond: Double = 0
    private var lastProgressSample: (date: Date, bytes: Int64)?
    private var currentUploadProgressHandler: ((Double) -> Void)?
    private let backgroundTaskCoordinator = SFTPBackgroundTaskCoordinator()
    private let prefetchTimeoutSeconds: TimeInterval = 60
    private let resumeCheckpointStore = SFTPResumeCheckpointStore()
    
    private override init() {
        super.init()
        backgroundTaskCoordinator.onExpiration = { [weak self] in
            // A continued processing task keeps the app alive past the UIKit window.
            guard !ContinuedBackupRunner.isRunning else { return }
            self?.handleBackgroundExpiration()
        }
    }

    var currentFile: String {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _currentFile
    }

    var progress: Double {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _progress
    }

    var currentFileBytesTransferred: Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _currentFileBytesTransferred
    }

    var currentFileTotalBytes: Int64 {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _currentFileTotalBytes
    }

    var transferSpeedBytesPerSecond: Double {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _transferSpeedBytesPerSecond
    }

    private func normalizedHost(_ rawHost: String) throws -> String {
        var host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else {
            throw makeSFTPError(.connection)
        }

        if host.hasPrefix("http:/") && !host.hasPrefix("http://") {
            host = host.replacingOccurrences(of: "http:/", with: "http://")
        }
        if host.hasPrefix("https:/") && !host.hasPrefix("https://") {
            host = host.replacingOccurrences(of: "https:/", with: "https://")
        }
        if host.hasPrefix("sftp:/") && !host.hasPrefix("sftp://") {
            host = host.replacingOccurrences(of: "sftp:/", with: "sftp://")
        }

        if host.contains("://"), let components = URLComponents(string: host), let parsedHost = components.host, !parsedHost.isEmpty {
            host = parsedHost
        } else {
            if let schemeRange = host.range(of: "://") {
                host = String(host[schemeRange.upperBound...])
            }
            if let atRange = host.lastIndex(of: "@") {
                host = String(host[host.index(after: atRange)...])
            }
            if let slashRange = host.firstIndex(of: "/") {
                host = String(host[..<slashRange])
            }
            if host.hasPrefix("["), let closeBracket = host.firstIndex(of: "]") {
                host = String(host[host.index(after: host.startIndex)..<closeBracket])
            } else if let colonRange = host.lastIndex(of: ":") {
                let portPart = host[host.index(after: colonRange)...]
                if !portPart.isEmpty && Int(portPart) != nil {
                    host = String(host[..<colonRange])
                }
            }
        }

        host = host.trimmingCharacters(in: CharacterSet(charactersIn: "/[] ").union(.whitespacesAndNewlines))
        let lowerHost = host.lowercased()
        if host.isEmpty || lowerHost == "http" || lowerHost == "https" || lowerHost == "sftp" || lowerHost == "ftp" {
            throw makeSFTPError(.connection, details: rawHost)
        }

        var validation = URLComponents()
        validation.scheme = "sftp"
        validation.host = host
        guard validation.url != nil else {
            throw makeSFTPError(.connection, details: rawHost)
        }

        return host
    }
    
    func testConnection(host: String, port: Int, username: String, password: String) async throws -> SFTPHostKeyResult {
        let normalizedHost = try normalizedHost(host)
        let result = try await connectInternal(
            host: normalizedHost,
            port: port,
            username: username,
            password: password,
            notifyOnNewHostKey: false
        )
        await disconnectInternal()
        return result ?? SFTPHostKeyResult(isNewHostKey: false, fingerprint: nil)
    }
    
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        let normalizedHost = try normalizedHost(host)
        if let username {
            storeConnection(host: normalizedHost, port: port, username: username, password: password ?? "")
        }
        _ = try await connectInternal(
            host: normalizedHost,
            port: port,
            username: username,
            password: password,
            notifyOnNewHostKey: true
        )
    }
    
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)?) async throws {
        let size = try localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        _ = try await uploadFileWithRetry(
            localURL: localURL,
            remotePath: remotePath,
            expectedSize: Int64(size),
            skipRemoteStat: false,
            progressHandler: progressHandler
        )
        progressHandler?(1.0)
    }
    
    func createDirectory(at path: String) async throws {
        guard let sftp = currentSFTPClient() else {
            throw BackupServiceError.connectionFailed
        }
        
        let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty, normalizedPath != "/" else {
            return
        }
        
        // İlk olarak parent directory'yi oluşturmayı dene (recursive)
        let parentPath = (normalizedPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != "/" && parentPath != normalizedPath {
            do {
                try await createDirectory(at: parentPath)
            } catch {
                logger.warning("SFTP parent directory creation warning for \(parentPath): \(error.localizedDescription)")
                // Parent oluşturulamasa da devam et, belki zaten var
            }
        }
        
        // Şimdi hedef directory'yi oluştur
        do {
            _ = try await sftp.getAttributes(at: normalizedPath)
            logger.debug("SFTP directory already exists: \(normalizedPath)")
            return
        } catch {
            logger.debug("SFTP directory not found, creating: \(normalizedPath)")
            do {
                try await sftp.createDirectory(atPath: normalizedPath)
                logger.debug("SFTP directory created successfully: \(normalizedPath)")
            } catch {
                logger.error("SFTP directory creation failed for \(normalizedPath): \(error.localizedDescription)")
                throw error
            }
        }
    }

    func cancelCurrentTask() {
        logger.info("SFTP işlemi iptal ediliyor...")
        markCancelled()
        disconnect()
    }
    
    func listDirectory(at path: String) async throws -> [FileObject] {
        try await listDirectory(at: path, timeout: nil)
    }

    private func listDirectory(at path: String, timeout: TimeInterval?) async throws -> [FileObject] {
        guard let sftp = currentSFTPClient() else {
            throw BackupServiceError.connectionFailed
        }

        // Local function — avoids needing to name the Citadel entry type explicitly
        func fetch() async throws -> [FileObject] {
            let entries = try await sftp.listDirectory(atPath: path)
            return entries.flatMap(\.components)
                .filter { $0.filename != "." && $0.filename != ".." }
                .map { item in
                    var values: [URLResourceKey: Any] = [:]
                    values[.nameKey] = item.filename
                    values[.pathKey] = item.filename
                    values[.fileSizeKey] = Int64(item.attributes.size ?? 0)
                    let permissions = item.attributes.permissions ?? 0
                    let isDirectory = (permissions & 0o170000) == 0o040000
                    values[.fileResourceTypeKey] = isDirectory ? URLFileResourceType.directory : URLFileResourceType.regular
                    let modified = item.attributes.accessModificationTime?.modificationTime
                    values[.contentModificationDateKey] = modified
                    values[.creationDateKey] = modified
                    return FileObject(allValues: values)
                }
        }

        guard let timeout else {
            return try await fetch()
        }

        let timeoutError = makeSFTPError(.timeout)
        return try await withThrowingTaskGroup(of: [FileObject].self) { group in
            group.addTask { try await fetch() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw timeoutError
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func prefetchRemoteFileMap(at path: String, timeout: TimeInterval) async throws -> [String: Int64] {
        var allFiles: [String: Int64] = [:]

        func listAll(at currentPath: String, relativeTo basePath: String) async throws {
            let files = try await listDirectory(at: currentPath, timeout: timeout)
            for file in files {
                let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
                if BackupArchive.isReserved(relativePath: relativePath) {
                    continue
                }
                if file.isDirectory {
                    let subdirPath = currentPath == "/" ? "/\(file.name)" : "\(currentPath)/\(file.name)"
                    try await listAll(at: subdirPath, relativeTo: relativePath)
                } else {
                    allFiles[relativePath] = file.size
                }
            }
        }

        do {
            try await listAll(at: path, relativeTo: "")
        } catch where Self.isNoSuchFile(error) {
            // A new destination folder doesn't exist yet; uploads create it.
            logger.info("SFTP remote dir does not exist yet, treating as empty: \(path)")
            return [:]
        }
        return allFiles
    }
    
    func deleteFile(at path: String) async throws {
        guard let sftp = currentSFTPClient() else {
            throw BackupServiceError.connectionFailed
        }
        try await sftp.remove(at: path)
    }
    
    func disconnect() {
        Task { [weak self] in
            await self?.disconnectInternal()
        }
    }
    
    func performBackup(
        host: String,
        port: Int,
        username: String,
        password: String,
        sourcePath: String,
        destinationPath: String,
        mediaType: MediaType,
        includeICloudAssets: Bool,
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)?
    ) async throws -> FTPService.SyncResult {
        resetCancellation()
        let normalizedHost = try normalizedHost(host)
        storeConnection(host: normalizedHost, port: port, username: username, password: password)
        try await connect(host: normalizedHost, port: port, username: username, password: password)
        defer { disconnect() }
        
        let isPhotosSource = sourcePath == "PHOTOS_LIBRARY"
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let sourceFolderName = sourceURL.lastPathComponent
        let relativeRemoteBase = normalizedRemoteBase(
            destinationPath: destinationPath,
            fallback: isPhotosSource ? "photos" : sourceFolderName,
            allowRelative: true
        )
        let effectiveRemotePath = try await resolveRemoteBase(relativeRemoteBase)
        let checkpointID = makeResumeCheckpointID(
            host: normalizedHost,
            port: port,
            username: username,
            sourcePath: isPhotosSource ? "PHOTOS_LIBRARY" : sourcePath,
            destinationPath: effectiveRemotePath,
            mediaType: mediaType
        )

        let engine = SFTPSyncEngine(
            prefetchRemoteFiles: { [weak self] path in
                guard let self else { return [:] }
                return try await self.prefetchRemoteFileMap(at: path, timeout: self.prefetchTimeoutSeconds)
            },
            createDirectory: { [weak self] path in
                guard let self else { return }
                try await self.createDirectory(at: path)
            },
            deleteFile: { [weak self] path in
                guard let self else { return }
                try await self.deleteFile(at: path)
            },
            archiveFile: { [weak self] sourcePath, destinationPath in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.archiveFile(from: sourcePath, to: destinationPath)
            },
            uploadFile: { [weak self] localURL, remotePath, expectedSize, skipRemoteStat, progressHandler in
                guard let self else { return false }
                return try await self.uploadFileWithRetry(
                    localURL: localURL,
                    remotePath: remotePath,
                    expectedSize: expectedSize,
                    skipRemoteStat: skipRemoteStat,
                    progressHandler: progressHandler
                )
            },
            verifyUpload: { [weak self] localURL, remotePath in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.verifyUploadChecksum(localURL: localURL, remotePath: remotePath)
            },
            beginTransferBackgroundTask: { [weak self] in
                self?.beginTransferBackgroundTask()
            },
            endTransferBackgroundTask: { [weak self] in
                self?.endTransferBackgroundTask()
            },
            isCancelled: { [weak self] in
                return self?.isCancelledState() ?? false
            },
            loadCheckpoint: { [weak self] in
                guard let self else { return [] }
                return await self.resumeCheckpointStore.load(id: checkpointID)
            },
            markCheckpoint: { [weak self] relativePath in
                guard let self else { return }
                await self.resumeCheckpointStore.mark(id: checkpointID, item: relativePath)
            },
            clearCheckpoint: { [weak self] in
                guard let self else { return }
                await self.resumeCheckpointStore.clear(id: checkpointID)
            }
        )

        if isPhotosSource {
            logger.info("SFTP health-check host=\(normalizedHost):\(port), source=PHOTOS_LIBRARY, remote=\(effectiveRemotePath)")
            logger.info("SFTP photos remote dir: \(effectiveRemotePath)")
            let result = try await engine.syncBackupPhotoLibrary(
                mediaType: mediaType,
                remotePath: effectiveRemotePath,
                includeICloudAssets: includeICloudAssets,
                options: options,
                progressHandler: progressHandler
            )
            if !options.isDryRun {
                try await uploadManifest(syncResult: result, remoteBasePath: effectiveRemotePath, options: options)
            }
            return result
        }

        logger.info("SFTP health-check host=\(normalizedHost):\(port), source=FOLDER, remote=\(effectiveRemotePath)")
        logger.info("SFTP folder remote dir: \(effectiveRemotePath)")
        let result = try await engine.syncUploadDirectory(
            localURL: sourceURL,
            remotePath: effectiveRemotePath,
            options: options,
            progressHandler: progressHandler
        )
        if !options.isDryRun {
            try await uploadManifest(syncResult: result, remoteBasePath: effectiveRemotePath, options: options)
        }
        return result
    }

    private func verifyUploadChecksum(localURL: URL, remotePath: String) async throws {
        guard let sftp = currentSFTPClient() else {
            throw makeSFTPError(.connection)
        }

        let remoteChecksum = try await sftp.withFile(filePath: remotePath, flags: .read) { remoteFile in
            var remoteHasher = SHA256()
            var offset: UInt64 = 0
            while true {
                let buffer = try await remoteFile.read(from: offset, length: 256 * 1024)
                guard buffer.readableBytes > 0 else { break }
                remoteHasher.update(data: Data(buffer.readableBytesView))
                offset += UInt64(buffer.readableBytes)
            }
            return remoteHasher.finalize().map { String(format: "%02x", $0) }.joined()
        }

        let localChecksum = try BackupChecksum.sha256(of: localURL)
        guard localChecksum == remoteChecksum else {
            throw BackupIntegrityError.checksumMismatch(path: remotePath)
        }
    }

    private func archiveFile(from sourcePath: String, to destinationPath: String) async throws {
        guard let sftp = currentSFTPClient() else {
            throw makeSFTPError(.connection)
        }
        let parentPath = (destinationPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != "/" {
            try await createDirectory(at: parentPath)
        }
        try await sftp.rename(at: sourcePath, to: destinationPath)
    }

    private func uploadManifest(syncResult: FTPService.SyncResult, remoteBasePath: String, options: BackupExecutionOptions) async throws {
        let manifest = """
        {
          "generatedAt": "\(ISO8601DateFormatter().string(from: Date()))",
          "newFiles": \(syncResult.newFiles),
          "updatedFiles": \(syncResult.updatedFiles),
          "skippedFiles": \(syncResult.skippedFiles),
          "deletedFiles": \(syncResult.deletedFiles),
          "verifiedFiles": \(syncResult.verifiedFiles),
          "totalBytes": \(syncResult.totalBytes),
          "deletionPolicy": "\(options.deletionPolicy.rawValue)",
          "checksumMode": "\(options.checksumMode.rawValue)"
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backupflow_manifest_\(UUID().uuidString).json")
        try manifest.data(using: .utf8)?.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let remotePath = remoteBasePath.hasSuffix("/") ? remoteBasePath + ".backupflow_manifest.json" : "\(remoteBasePath)/.backupflow_manifest.json"
        try await uploadFile(localURL: url, remotePath: remotePath, progressHandler: nil)
    }

    private func normalizedRemoteBase(
        destinationPath: String,
        fallback: String,
        allowRelative: Bool
    ) -> String {
        let trimmed = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTrimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFallback = fallbackTrimmed.isEmpty ? "backup" : fallbackTrimmed

        guard !trimmed.isEmpty, trimmed != "/" else {
            return safeFallback
        }
        var path = trimmed
        if !allowRelative && !path.hasPrefix("/") {
            path = "/" + path
        }
        while path.contains("//") {
            path = path.replacingOccurrences(of: "//", with: "/")
        }
        if path.hasSuffix("/") {
            path.removeLast()
        }
        return path.isEmpty ? safeFallback : path
    }

    private func resolveRemoteBase(_ basePath: String) async throws -> String {
        let trimmed = basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "backup"
        }
        if trimmed.hasPrefix("/") {
            return trimmed
        }
        guard let sftp = currentSFTPClient() else {
            return trimmed
        }
        do {
            let home = try await sftp.getRealPath(atPath: ".")
            let homeTrimmed = home.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !homeTrimmed.isEmpty else {
                return trimmed
            }
            var combined = homeTrimmed.hasSuffix("/") ? homeTrimmed + trimmed : "\(homeTrimmed)/\(trimmed)"
            while combined.contains("//") {
                combined = combined.replacingOccurrences(of: "//", with: "/")
            }
            if combined.hasSuffix("/") {
                combined.removeLast()
            }
            return combined
        } catch {
            logger.error("SFTP realpath lookup failed, using relative path: \(error.localizedDescription)")
            return trimmed
        }
    }

    private func makeResumeCheckpointID(
        host: String,
        port: Int,
        username: String,
        sourcePath: String,
        destinationPath: String,
        mediaType: MediaType
    ) -> String {
        [
            "host=\(host.lowercased())",
            "port=\(port)",
            "user=\(username.lowercased())",
            "source=\(sourcePath)",
            "dest=\(destinationPath)",
            "media=\(mediaType.rawValue)"
        ].joined(separator: "|")
    }

    private func storeConnection(host: String, port: Int, username: String, password: String) {
        connectionLock.lock()
        lastConnection = (host, port, username, password)
        connectionLock.unlock()
    }

    private func fetchConnection() -> (host: String, port: Int, username: String, password: String)? {
        connectionLock.lock()
        let value = lastConnection
        connectionLock.unlock()
        return value
    }

    private func setClients(ssh: SSHClient?, sftp: SFTPClient?) {
        stateLock.lock()
        sshClient = ssh
        sftpClient = sftp
        stateLock.unlock()
    }

    private func currentSFTPClient() -> SFTPClient? {
        stateLock.lock()
        let sftp = sftpClient
        stateLock.unlock()
        return sftp
    }

    private func currentSSHClient() -> SSHClient? {
        stateLock.lock()
        let ssh = sshClient
        stateLock.unlock()
        return ssh
    }

    func clearStoredConnection() {
        connectionLock.lock()
        lastConnection = nil
        connectionLock.unlock()
    }

    private func disconnectInternal() async {
        let ssh: SSHClient?
        let sftp: SFTPClient?
        (ssh, sftp) = stateLock.withLock {
            let currentSSH = sshClient
            let currentSFTP = sftpClient
            sshClient = nil
            sftpClient = nil
            return (currentSSH, currentSFTP)
        }

        clearStoredConnection()

        if let sftp {
            try? await sftp.close()
        }
        if let ssh {
            try? await ssh.close()
        }
    }

    private func ensureConnected() async throws {
        if isCancelledState() {
            throw BackupServiceError.cancelled
        }
        let isAlive = (currentSSHClient()?.isConnected == true) && (currentSFTPClient()?.isActive == true)
        if isAlive {
            return
        }
        logger.info("SFTP session not alive, reconnecting...")
        guard let conn = fetchConnection() else {
            throw makeSFTPError(.connection)
        }
        _ = try await connectInternal(
            host: conn.host,
            port: conn.port,
            username: conn.username,
            password: conn.password,
            notifyOnNewHostKey: false
        )
    }

    private func remoteFileSize(at path: String) async throws -> Int64? {
        guard let sftp = currentSFTPClient() else {
            throw makeSFTPError(.connection)
        }
        do {
            let attrs = try await sftp.getAttributes(at: path)
            return attrs.size.map(Int64.init)
        } catch where Self.isNoSuchFile(error) {
            return nil
        }
    }

    /// Citadel reports a missing path either wrapped in SFTPError or as a bare status.
    private static func isNoSuchFile(_ error: Error) -> Bool {
        if let status = error as? SFTPMessage.Status {
            return status.errorCode == .noSuchFile
        }
        if case .errorStatus(let status)? = error as? SFTPError {
            return status.errorCode == .noSuchFile
        }
        return false
    }

    private func prepareCurrentUpload(
        localURL: URL,
        expectedSize: Int64,
        progressHandler: ((Double) -> Void)?
    ) {
        stateLock.lock()
        _currentFile = localURL.lastPathComponent
        _progress = 0
        _currentFileBytesTransferred = 0
        _currentFileTotalBytes = expectedSize
        _transferSpeedBytesPerSecond = 0
        lastProgressSample = (Date(), 0)
        currentUploadProgressHandler = progressHandler
        stateLock.unlock()

        progressHandler?(0.0)
    }

    private func updateCurrentUploadProgress(bytesSent: Int64, totalBytes: Int64) {
        let now = Date()
        let safeTotal = max(totalBytes, 0)
        let safeBytes = max(0, min(bytesSent, safeTotal > 0 ? safeTotal : bytesSent))
        let safeProgress = safeTotal > 0 ? Double(safeBytes) / Double(safeTotal) : 0
        var handler: ((Double) -> Void)?

        stateLock.lock()
        if let sample = lastProgressSample {
            let elapsed = now.timeIntervalSince(sample.date)
            let delta = safeBytes - sample.bytes
            if elapsed > 0.35, delta >= 0 {
                _transferSpeedBytesPerSecond = Double(delta) / elapsed
                lastProgressSample = (now, safeBytes)
            }
        } else {
            lastProgressSample = (now, safeBytes)
        }

        _progress = min(max(safeProgress, 0), 1)
        _currentFileBytesTransferred = safeBytes
        _currentFileTotalBytes = safeTotal
        handler = currentUploadProgressHandler
        let progress = _progress
        stateLock.unlock()

        handler?(progress)
    }

    private func uploadLocalFile(
        localURL: URL,
        remotePath: String,
        expectedSize: Int64,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        guard let sftp = currentSFTPClient() else {
            throw makeSFTPError(.connection)
        }
        let handle = try FileHandle(forReadingFrom: localURL)
        defer { try? handle.close() }

        let fileName = (remotePath as NSString).lastPathComponent
        let parentPath = (remotePath as NSString).deletingLastPathComponent
        
        logger.debug("SFTP uploading file: \(fileName) to \(parentPath)")
        
        do {
            try await sftp.withFile(
                filePath: remotePath,
                flags: [.write, .create, .truncate]
            ) { remoteFile in
                var offset: UInt64 = 0
                while !(await self.isCancelledState()) {
                    guard let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty else {
                        break
                    }
                    var buffer = ByteBufferAllocator().buffer(capacity: chunk.count)
                    buffer.writeBytes(chunk)
                    try await remoteFile.write(buffer, at: offset)
                    offset += UInt64(chunk.count)
                    await self.updateCurrentUploadProgress(bytesSent: Int64(offset), totalBytes: expectedSize)
                }
                if await self.isCancelledState() {
                    throw BackupServiceError.cancelled
                }
            }
            logger.debug("SFTP upload successful: \(fileName)")
        } catch {
            logger.error("SFTP upload failed for \(fileName): \(error.localizedDescription)")
            throw error
        }
    }

    private func uploadFileWithRetry(
        localURL: URL,
        remotePath: String,
        expectedSize: Int64,
        skipRemoteStat: Bool,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Bool {
        let retryDelays: [TimeInterval] = [5, 10, 10]
        
        for attempt in 0..<retryDelays.count {
            if isCancelledState() {
                throw BackupServiceError.cancelled
            }
            
            try await ensureConnected()
            
            if !skipRemoteStat {
                if let remoteSize = try await remoteFileSize(at: remotePath) {
                    if remoteSize == expectedSize {
                        logger.info("SFTP remote file already uploaded, skipping")
                        prepareCurrentUpload(localURL: localURL, expectedSize: expectedSize, progressHandler: progressHandler)
                        updateCurrentUploadProgress(bytesSent: expectedSize, totalBytes: expectedSize)
                        return false
                    } else if remoteSize > 0 {
                        try? await deleteFile(at: remotePath)
                    }
                }
            }
            
            do {
                prepareCurrentUpload(localURL: localURL, expectedSize: expectedSize, progressHandler: progressHandler)
                try await uploadLocalFile(
                    localURL: localURL,
                    remotePath: remotePath,
                    expectedSize: expectedSize,
                    progressHandler: progressHandler
                )
                updateCurrentUploadProgress(bytesSent: expectedSize, totalBytes: expectedSize)
                return true
            } catch {
                logger.warning("SFTP upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                await disconnectInternal()
                if attempt == retryDelays.count - 1 {
                    throw classifySFTPError(error, defaultKind: .fileOperation)
                }
                logger.info("SFTP retrying after \(retryDelays[attempt])s")
                await waitForReachable(timeout: retryDelays[attempt])
                continue
            }
        }
        
        throw makeSFTPError(.fileOperation)
    }

    private func waitForReachable(timeout: TimeInterval) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.backupflow.sftp.reachability")
            let resumptionManager = VoidResumptionManager(continuation)

            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    Task { @MainActor in
                        if resumptionManager.resume() {
                            monitor.cancel()
                        }
                    }
                }
            }

            monitor.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                Task { @MainActor in
                    if resumptionManager.resume() {
                        monitor.cancel()
                    }
                }
            }
        }
    }

    private func connectInternal(
        host: String,
        port: Int,
        username: String?,
        password: String?,
        notifyOnNewHostKey: Bool
    ) async throws -> SFTPHostKeyResult? {
        guard let username else {
            throw makeSFTPError(.authentication)
        }

        guard let password else {
            throw makeSFTPError(.authentication)
        }

        let hostKeyValidator = SFTPHostKeyValidator(host: host, port: port)
        do {
            await disconnectInternal()

            var settings = SSHClientSettings(
                host: host,
                port: port,
                authenticationMethod: { .passwordBased(username: username, password: password) },
                hostKeyValidator: .custom(hostKeyValidator)
            )
            settings.algorithms = SSHAlgorithms()
            settings.connectTimeout = .seconds(20)

            let ssh = try await SSHClient.connect(to: settings)
            let sftp = try await ssh.openSFTP()
            setClients(ssh: ssh, sftp: sftp)
        } catch {
            await disconnectInternal()
            throw classifySFTPError(error, defaultKind: .connection)
        }

        let validationOutcome = hostKeyValidator.outcome
        let hostKeyResult = SFTPHostKeyResult(
            isNewHostKey: validationOutcome?.isNewHostKey ?? false,
            fingerprint: validationOutcome?.fingerprint
        )
        if notifyOnNewHostKey, hostKeyResult.isNewHostKey {
            await sendHostKeyNotification(fingerprint: hostKeyResult.fingerprint)
        }

        return hostKeyResult
    }

    private func beginTransferBackgroundTask() {
        logger.info("SFTP background task started for transfer")
        backgroundTaskCoordinator.begin()
    }

    private func endTransferBackgroundTask() {
        logger.info("SFTP background task ended for transfer")
        backgroundTaskCoordinator.end()
    }

    private func handleBackgroundExpiration() {
        logger.warning("SFTP background time expired, cancelling transfer")
        markCancelled()
        disconnect()
    }

    private func markCancelled() {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        isCancelled = true
    }

    private func resetCancellation() {
        cancellationLock.lock()
        isCancelled = false
        cancellationLock.unlock()
    }

    private func isCancelledState() -> Bool {
        cancellationLock.lock()
        let value = isCancelled
        cancellationLock.unlock()
        return value
    }

    private func sendHostKeyNotification(fingerprint: String?) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "sftp.hostkey_title".localized
        if let fingerprint {
            content.body = String(format: "sftp.hostkey_message".localized, fingerprint)
        } else {
            content.body = "sftp.hostkey_message".localized
        }
        let request = UNNotificationRequest(
            identifier: "sftp-hostkey-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("SFTP host key notification failed: \(error.localizedDescription)")
        }
    }
}

private final class SFTPBackgroundTaskCoordinator {
    private let lock = NSLock()
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var renewTimer: DispatchSourceTimer?
    var onExpiration: (() -> Void)?
    private let renewInterval: TimeInterval = 25
    
    func begin() {
        lock.lock()
        endLocked()
        startTaskLocked()
        startRenewTimerLocked()
        lock.unlock()
    }
    
    func end() {
        lock.lock()
        endLocked()
        stopRenewTimerLocked()
        lock.unlock()
    }
    
    private func handleExpiration() {
        onExpiration?()
        end()
    }

    private func startTaskLocked() {
        let newID = UIApplication.shared.beginBackgroundTask(withName: "SFTPFileTransfer") { [weak self] in
            self?.handleExpiration()
        }
        taskID = newID
    }

    private func endLocked() {
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }
    }

    private func startRenewTimerLocked() {
        stopRenewTimerLocked()
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + renewInterval, repeating: renewInterval)
        timer.setEventHandler { [weak self] in
            self?.renew()
        }
        timer.resume()
        renewTimer = timer
    }

    private func stopRenewTimerLocked() {
        renewTimer?.cancel()
        renewTimer = nil
    }

    private func renew() {
        lock.lock()
        guard taskID != .invalid else {
            lock.unlock()
            return
        }
        endLocked()
        startTaskLocked()
        lock.unlock()
    }
}

private final class VoidResumptionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let c = continuation {
            continuation = nil
            c.resume()
            return true
        }
        return false
    }
}

