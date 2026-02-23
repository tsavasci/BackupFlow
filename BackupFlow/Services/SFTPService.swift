import Foundation
import FilesProvider
import OSLog
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Network)
import Network
#endif

struct SFTPHostKeyResult {
    let isNewHostKey: Bool
    let fingerprint: String?
}

#if canImport(NMSSH)
import NMSSH
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
        message = "SFTP kimlik doğrulama başarısız. Kullanıcı adı/şifreyi ve sunucu izinlerini kontrol edin."
    case .timeout:
        code = SFTPFailureCode.timeout.rawValue
        message = "SFTP bağlantısı zaman aşımına uğradı. Ağ erişimini ve sunucu yanıt süresini kontrol edin."
    case .hostKeyMismatch:
        code = SFTPFailureCode.hostKeyMismatch.rawValue
        message = "SFTP host key doğrulaması başarısız. Sunucu anahtarı değişmiş olabilir."
    case .connection:
        code = SFTPFailureCode.connection.rawValue
        message = "SFTP sunucusuna bağlantı kurulamadı."
    case .fileOperation:
        code = SFTPFailureCode.fileOperation.rawValue
        message = "SFTP dosya işlemi başarısız."
    case .unavailable:
        code = SFTPFailureCode.unavailable.rawValue
        message = "SFTP desteği etkin değil. NMSSH kütüphanesi eklenmeli."
    }

    var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
    if let details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        userInfo[NSLocalizedDescriptionKey] = "\(message) Detay: \(details)"
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

final class SFTPService: NSObject, @unchecked Sendable, BackupServiceProtocol {
    static let shared = SFTPService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "SFTPService")
    private let queue = DispatchQueue(label: "com.backupflow.sftp.queue")
    private let cancellationLock = NSLock()
    private var isCancelled = false
    private let connectionLock = NSLock()
    private var lastConnection: (host: String, port: Int, username: String, password: String)?
    
    private var session: NMSSHSession?
    private var sftp: NMSFTP?
    private(set) var lastError: Error?
    private(set) var isConnected = false
    
    private let hostKeyStore = SFTPHostKeyStore()
#if canImport(UIKit)
    private let backgroundTaskCoordinator = SFTPBackgroundTaskCoordinator()
#endif
    private let prefetchTimeoutSeconds: TimeInterval = 60
    
    private override init() {
        super.init()
#if canImport(NMSSH)
        let nmsshLogger = NMSSHLogger.shared()
        nmsshLogger.isEnabled = true
        nmsshLogger.logLevel = .error
#endif
#if canImport(UIKit)
        backgroundTaskCoordinator.onExpiration = { [weak self] in
            self?.handleBackgroundExpiration()
        }
#endif
    }
    
    func testConnection(host: String, port: Int, username: String, password: String) async throws -> SFTPHostKeyResult {
        let result = try await connectInternal(
            host: host,
            port: port,
            username: username,
            password: password,
            notifyOnNewHostKey: false
        )
        disconnect()
        return result ?? SFTPHostKeyResult(isNewHostKey: false, fingerprint: nil)
    }
    
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        if let username {
            storeConnection(host: host, port: port, username: username, password: password ?? "")
        }
        _ = try await connectInternal(
            host: host,
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
            skipRemoteStat: false
        )
        progressHandler?(1.0)
    }
    
    func createDirectory(at path: String) async throws {
        try await runOnQueue {
            guard let sftp = self.sftp else {
                throw BackupServiceError.connectionFailed
            }
            
            if !sftp.directoryExists(atPath: path) {
                let success = sftp.createDirectory(atPath: path)
                if !success {
                    throw BackupServiceError.fileOperationFailed
                }
            }
        }
    }
    
    func listDirectory(at path: String) async throws -> [FileObject] {
        try await listDirectory(at: path, timeout: nil)
    }

    private func listDirectory(at path: String, timeout: TimeInterval?) async throws -> [FileObject] {
        try await runOnQueue {
            guard let sftp = self.sftp, let session = self.session else {
                throw BackupServiceError.connectionFailed
            }
            let previousTimeout = session.timeout
            if let timeout {
                session.timeout = NSNumber(value: timeout)
            }
            defer { session.timeout = previousTimeout }
            
            guard let files = sftp.contentsOfDirectory(atPath: path) else {
                throw BackupServiceError.fileOperationFailed
            }
            let mapped: [FileObject] = files.map { file in
                var values: [URLResourceKey: Any] = [:]
                values[.nameKey] = file.filename
                values[.pathKey] = file.filename
                values[.fileSizeKey] = file.fileSize?.int64Value ?? 0
                values[.fileResourceTypeKey] = file.isDirectory ? URLFileResourceType.directory : URLFileResourceType.regular
                values[.contentModificationDateKey] = file.modificationDate
                values[.creationDateKey] = file.modificationDate
                return FileObject(allValues: values)
            }
            return mapped
        }
    }

    private func prefetchRemoteFileMap(at path: String, timeout: TimeInterval) async throws -> [String: Int64] {
        var allFiles: [String: Int64] = [:]

        func listAll(at currentPath: String, relativeTo basePath: String) async throws {
            let files = try await listDirectory(at: currentPath, timeout: timeout)
            for file in files {
                let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
                if file.isDirectory {
                    let subdirPath = currentPath == "/" ? "/\(file.name)" : "\(currentPath)/\(file.name)"
                    try await listAll(at: subdirPath, relativeTo: relativePath)
                } else {
                    allFiles[relativePath] = file.size
                }
            }
        }

        try await listAll(at: path, relativeTo: "")
        return allFiles
    }
    
    func deleteFile(at path: String) async throws {
        try await runOnQueue {
            guard let sftp = self.sftp else {
                throw BackupServiceError.connectionFailed
            }
            if !sftp.removeFile(atPath: path) {
                throw BackupServiceError.fileOperationFailed
            }
        }
    }
    
    func disconnect() {
        queue.sync {
            sftp?.disconnect()
            session?.disconnect()
            sftp = nil
            session = nil
            isConnected = false
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
        progressHandler: ((Double) -> Void)?
    ) async throws -> FTPService.SyncResult {
        resetCancellation()
        storeConnection(host: host, port: port, username: username, password: password)
        try await connect(host: host, port: port, username: username, password: password)
        defer { disconnect() }
        
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
            uploadFile: { [weak self] localURL, remotePath, expectedSize, skipRemoteStat in
                guard let self else { return false }
                return try await self.uploadFileWithRetry(
                    localURL: localURL,
                    remotePath: remotePath,
                    expectedSize: expectedSize,
                    skipRemoteStat: skipRemoteStat
                )
            },
            beginTransferBackgroundTask: { [weak self] in
                self?.beginTransferBackgroundTask()
            },
            endTransferBackgroundTask: { [weak self] in
                self?.endTransferBackgroundTask()
            },
            isCancelled: { [weak self] in
                return self?.isCancelled ?? false
            }
        )
        
        if sourcePath == "PHOTOS_LIBRARY" {
            let photosDir = normalizedRemoteBase(
                destinationPath: destinationPath,
                fallback: "photos",
                allowRelative: true
            )
            logger.info("SFTP photos remote dir: \(photosDir)")
            return try await engine.syncBackupPhotoLibrary(
                mediaType: mediaType,
                remotePath: photosDir,
                progressHandler: progressHandler
            )
        }
        
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let sourceFolderName = sourceURL.lastPathComponent
        let safeRemoteBase = normalizedRemoteBase(
            destinationPath: destinationPath,
            fallback: sourceFolderName,
            allowRelative: true
        )
        logger.info("SFTP folder remote dir: \(safeRemoteBase)")
        return try await engine.syncUploadDirectory(
            localURL: sourceURL,
            remotePath: safeRemoteBase,
            progressHandler: progressHandler
        )
    }

    private func normalizedRemoteBase(
        destinationPath: String,
        fallback: String,
        allowRelative: Bool
    ) -> String {
        let trimmed = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "/" else {
            return fallback
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
        return path
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

    private func ensureConnected() async throws {
        if isCancelledState() {
            throw BackupServiceError.cancelled
        }
        let isAlive = queue.sync { () -> Bool in
            guard let session, let sftp else { return false }
            return session.isConnected && session.isAuthorized && sftp.isConnected
        }
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
        try await runOnQueue {
            guard let sftp = self.sftp else {
                throw makeSFTPError(.connection)
            }
            if !sftp.fileExists(atPath: path) {
                return nil
            }
            let info = sftp.infoForFile(atPath: path)
            return info?.fileSize?.int64Value
        }
    }

    private func uploadFileWithRetry(
        localURL: URL,
        remotePath: String,
        expectedSize: Int64,
        skipRemoteStat: Bool
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
                        return false
                    } else if remoteSize > 0 {
                        try? await deleteFile(at: remotePath)
                    }
                }
            }
            
            do {
                try await runOnQueue {
                    guard let sftp = self.sftp else {
                        throw BackupServiceError.connectionFailed
                    }
                    let success = sftp.writeFile(atPath: localURL.path, toFileAtPath: remotePath)
                    if !success {
                        throw BackupServiceError.fileOperationFailed
                    }
                }
                return true
            } catch {
                logger.warning("SFTP upload attempt \(attempt + 1) failed: \(error.localizedDescription)")
                disconnect()
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
#if canImport(Network)
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
#else
        let nanos = UInt64(timeout * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanos)
#endif
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
        
        let hostKeyResult = try await runOnQueue { () -> SFTPHostKeyResult? in
            let session = NMSSHSession.connect(toHost: host, port: port, withUsername: username)
            self.session = session
            
            guard session.isConnected else {
                if let lastError = session.lastError {
                    throw classifySFTPError(lastError, defaultKind: .connection)
                }
                throw makeSFTPError(.connection)
            }
            
            if let password {
                let methods = session.supportedAuthenticationMethods() ?? []
                if methods.isEmpty || methods.contains("password") {
                    session.authenticate(byPassword: password)
                }
                if !session.isAuthorized && methods.contains("keyboard-interactive") {
                    _ = session.authenticateByKeyboardInteractive(block: { _ in
                        password
                    })
                }
            }
            
            guard session.isAuthorized else {
                if let lastError = session.lastError {
                    throw classifySFTPError(lastError, defaultKind: .authentication)
                }
                throw makeSFTPError(.authentication)
            }
            
            try self.hostKeyStore.verifyOrTrust(session: session, host: host, port: port)
            
            let sftp = session.sftp
            if !sftp.connect() {
                if let lastError = session.lastError {
                    throw classifySFTPError(lastError, defaultKind: .connection)
                }
                throw makeSFTPError(.connection)
            }
            sftp.bufferSize = 256 * 1024
            self.sftp = sftp
            self.isConnected = sftp.isConnected
            
            return self.hostKeyStore.lastResult
        }
        
        if notifyOnNewHostKey, let result = hostKeyResult, result.isNewHostKey {
            await sendHostKeyNotification(fingerprint: result.fingerprint)
        }
        
        return hostKeyResult
    }

    private func runOnQueue<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if self.isCancelledState() {
                    continuation.resume(throwing: BackupServiceError.cancelled)
                    return
                }
                do {
                    let result = try work()
                    if self.isCancelledState() {
                        continuation.resume(throwing: BackupServiceError.cancelled)
                    } else {
                        continuation.resume(returning: result)
                    }
                } catch {
                    if self.isCancelledState() {
                        continuation.resume(throwing: BackupServiceError.cancelled)
                    } else {
                        self.lastError = error
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func beginTransferBackgroundTask() {
#if canImport(UIKit)
        logger.info("SFTP background task started for transfer")
        backgroundTaskCoordinator.begin()
#endif
    }

    private func endTransferBackgroundTask() {
#if canImport(UIKit)
        logger.info("SFTP background task ended for transfer")
        backgroundTaskCoordinator.end()
#endif
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

#if canImport(UIKit)
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
#endif

private final class SFTPHostKeyStore {
    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "sftp_hostkey_"
    private(set) var lastResult: SFTPHostKeyResult?
    
    func verifyOrTrust(session: NMSSHSession, host: String, port: Int) throws {
        let key = "\(keyPrefix)\(host):\(port)"
        lastResult = nil
        let fingerprint = session.fingerprint(.SHA1) ?? session.fingerprint(.MD5)
        guard let fingerprint else { return }
        
        if let saved = userDefaults.string(forKey: key) {
            if saved != fingerprint {
                throw makeSFTPError(
                    .hostKeyMismatch,
                    details: "Host: \(host):\(port), beklenen: \(saved), gelen: \(fingerprint)"
                )
            }
            lastResult = SFTPHostKeyResult(isNewHostKey: false, fingerprint: fingerprint)
            return
        }
        
        userDefaults.set(fingerprint, forKey: key)
        lastResult = SFTPHostKeyResult(isNewHostKey: true, fingerprint: fingerprint)
    }
}

#if canImport(Network)
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
#endif

#else

final class SFTPService: NSObject, @unchecked Sendable, BackupServiceProtocol {
    static let shared = SFTPService()
    private(set) var isConnected = false
    private(set) var lastError: Error?
    private let unavailableError = NSError(
        domain: "SFTPUnavailable",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "SFTP desteği etkin değil. NMSSH kütüphanesi eklenmeli."]
    )
    
    private override init() {
        super.init()
    }
    
    func testConnection(host: String, port: Int, username: String, password: String) async throws -> SFTPHostKeyResult {
        throw unavailableError
    }
    
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        throw unavailableError
    }

    
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)?) async throws {
        throw unavailableError
    }
    
    func createDirectory(at path: String) async throws {
        throw unavailableError
    }
    
    func listDirectory(at path: String) async throws -> [FileObject] {
        throw unavailableError
    }
    
    func deleteFile(at path: String) async throws {
        throw unavailableError
    }
    
    func disconnect() {}
    
    func performBackup(
        host: String,
        port: Int,
        username: String,
        password: String,
        sourcePath: String,
        destinationPath: String,
        mediaType: MediaType,
        progressHandler: ((Double) -> Void)?
    ) async throws -> FTPService.SyncResult {
        throw unavailableError
    }
}

#endif
