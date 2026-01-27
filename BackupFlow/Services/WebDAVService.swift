#if canImport(FilesProvider)

import Foundation
import FilesProvider
import OSLog
import Combine
@preconcurrency import Photos
import AVFoundation
import Network
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class TelemetryReporter: ObservableObject {
    static let shared = TelemetryReporter()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "Telemetry")

    private var lastEventTimestamps: [String: Date] = [:]
    private var minIntervalByKey: [String: TimeInterval] = [:]

    private init() {}

    func retryOccurred(error: Error, attempt: Int, delay: TimeInterval) {
        guard shouldEmit(key: "retry") else { return }
        #if DEBUG
        logger.debug("Telemetry: retryOccurred attempt=\(attempt), delay=\(String(format: "%.2f", delay))s, error=\(error.localizedDescription)")
        #endif
    }

    private func shouldEmit(key: String) -> Bool {
        if let minInterval = minIntervalByKey[key], let last = lastEventTimestamps[key] {
            if Date().timeIntervalSince(last) < minInterval {
                return false
            }
        }
        lastEventTimestamps[key] = Date()
        return true
    }
}

@MainActor
final class WebDAVService: NSObject, BackupServiceProtocol, FileProviderDelegate {
    // MARK: - Properties
    static let shared = WebDAVService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "WebDAVService")
    private let fileManager = FileManager.default
    private let photoLibraryManager = PhotoLibraryManager.shared
    private let backgroundUploader = WebDAVBackgroundUploader(logger: Logger(subsystem: "com.backupflow.app", category: "WebDAVService"))
    
    private var webdavProvider: WebDAVFileProvider?
    private var currentBaseURL: URL?
    private var currentCredential: URLCredential?
    private var backgroundURLSession: URLSession?
    private var backgroundURLSessionCompletionHandler: (() -> Void)?
    private lazy var backgroundSessionDelegate = WebDAVBackgroundSessionDelegate(
        logger: logger,
        allowSelfSigned: self.allowSelfSignedCertificates,
        onTaskProgress: { [weak self] task, totalBytesSent, totalBytesExpected in
            guard totalBytesExpected > 0 else { return }
            let progress = Double(totalBytesSent) / Double(totalBytesExpected)
            Task { @MainActor in
                self?.progress = progress
            }
        },
        onTaskComplete: { [weak self] task, error in
            if let error = error {
                self?.lastError = error
                self?.logger.error("🌐 Background upload failed: \(error.localizedDescription)")
            } else {
                self?.logger.info("🌐 Background upload completed: \(task.taskDescription ?? "")")
            }
        },
        onFinishEvents: { [weak self] in
            if let completionHandler = self?.backgroundURLSessionCompletionHandler {
                completionHandler()
                self?.backgroundURLSessionCompletionHandler = nil
            }
        }
    )
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()
    
    // Background session state tracking
    @Published private(set) var isBackgroundUploading = false

    private var deleteOrphansEnabled: Bool {
        if UserDefaults.standard.object(forKey: "WebDAVDeleteOrphans") == nil {
            return true // default enabled
        }
        return UserDefaults.standard.bool(forKey: "WebDAVDeleteOrphans")
    }
    
    func updateBackgroundMode(isBackground: Bool) {
        self.isBackgroundUploading = isBackground
        self.logger.info("📱 \(isBackground ? "Background" : "Foreground") upload mode enabled")
    }
    
    @Published private(set) var isConnected = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    @Published private(set) var networkPermissionGranted = false
    private(set) var lastError: Error?
    
    private let networkMonitor = WebDAVNetworkMonitor()
    
    private var isVerboseLoggingEnabled: Bool {
        UserDefaults.standard.bool(forKey: "WebDAVVerboseLogging")
    }
    
    private var allowSelfSignedCertificates: Bool {
        UserDefaults.standard.bool(forKey: "WebDAVAllowSelfSigned")
    }
    
    private func executeWithRetry<T>(maxAttempts: Int = 3, _ operation: @escaping () async throws -> T) async throws -> T {
        let config = WebDAVRetryPolicy()
        let attempts = min(maxAttempts, config.maxAttempts)
        var lastError: Error?
        for attempt in 1...attempts {
            do { return try await operation() } catch {
                lastError = error
                if !config.shouldRetry(error: error) {
                    throw WebDAVErrorMapper.mapError(error)
                }
                if attempt < attempts {
                    let delay = config.delayForAttempt(attempt)
                    if isVerboseLoggingEnabled {
                        self.logger.warning("Retryable error on attempt \(attempt)/\(attempts): \(error.localizedDescription). Waiting \(String(format: "%.2f", delay))s before retry...")
                    }
                    TelemetryReporter.shared.retryOccurred(error: error, attempt: attempt, delay: delay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw WebDAVErrorMapper.mapError(lastError ?? NSError(domain: "WebDAVService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error after retries"]))
    }
    
    // MARK: - FileProviderDelegate
    func fileproviderSucceed(_ fileProvider: FileProviderOperations, operation: FileOperationType) {
        self.logger.info("Operation successful: \(operation.description)")
    }
    
    func fileproviderFailed(_ fileProvider: FileProviderOperations, operation: FileOperationType, error: Error) {
        let nsError = error as NSError
        self.logger.error("Operation failed: \(operation.description) - \(error.localizedDescription)")
        self.logger.error("   - Error code: \(nsError.code)")
        self.logger.error("   - Error domain: \(nsError.domain)")
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            self.logger.error("   - Underlying error: \(underlyingError.localizedDescription)")
        }
    }
    
    func fileproviderProgress(_ fileProvider: FileProviderOperations, operation: FileOperationType, progress: Float) {
        let percent = Int(progress * 100)
        if isVerboseLoggingEnabled {
            self.logger.debug("Progress: \(operation.description) - \(percent)%")
        }
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupNetworkMonitoring()
        setupBackgroundURLSession()
    }
    
    // MARK: - Background URLSession Management
    private func setupBackgroundURLSession() {
        if isVerboseLoggingEnabled { self.logger.debug("Initializing background URLSession (WebDAV)") }
        // Create persistent background URLSession for WebDAV uploads
        let config = URLSessionConfiguration.background(withIdentifier: "com.backupflow.webdav.background")
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false  // Kritik yüklemeler için hemen başla
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 180.0  // Büyük dosyalar için daha uzun timeout
        config.httpMaximumConnectionsPerHost = 1
        
        // Resume desteği: Kısmi yüklemeler için HTTP 1.1 range requests
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true  // WiFi bağlantısının gelmesini bekle
        // Removed line: config.shouldUseExtendedBackgroundIdleMode = true  // Arka plan modda daha uzun süre bekle
        
        self.backgroundURLSession = URLSession(configuration: config, delegate: backgroundSessionDelegate, delegateQueue: nil)
        self.logger.info("🌐 WebDAV background URLSession initialized")
    }
    
    func setBackgroundURLSessionCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundURLSessionCompletionHandler = handler
        self.logger.info("🌐 Background URLSession completion handler registered")
    }
    
    // MARK: - Network Permission Management
    private func setupNetworkMonitoring() {
        networkMonitor.onUpdate = { [weak self] status in
            self?.networkPermissionGranted = status == .satisfied
            if status == .satisfied {
                self?.logger.info("Ağ bağlantısı kullanılabilir")
            } else {
                let statusString = WebDAVNetworkMonitor.statusString(status)
                self?.logger.warning("Ağ bağlantısı kullanılamıyor: \(statusString)")
            }
        }
        networkMonitor.start()
    }
    
    /// Ağ izninin verilmesini bekler ve gerekirse kullanıcıyı bilgilendirir
    private func waitForNetworkPermission() async throws {
        // İlk kez deneme - eğer ağ zaten varsa direkt geç
        if networkPermissionGranted {
            return
        }
        
        self.logger.info("Ağ izni bekleniyor... (İlk bağlantı için iOS izin isteyebilir)")
        
        // 10 saniye kadar bekle
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 saniye
            
            if networkPermissionGranted {
                self.logger.info("Ağ izni alındı (\(i). saniyede)")
                return
            }
            
            if i == 5 {
                self.logger.warning("Ağ izni hala bekleniyor... Kullanıcı pop-up'ı görmüş olabilir")
            }
        }
        
        // Hala ağ yoksa hata fırlat
        if !networkPermissionGranted {
            throw NSError(
                domain: "WebDAVError",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Ağ bağlantısı için izin gerekli. Lütfen Ayarlar > Gizlilik ve Güvenlik > Yerel Ağ'dan uygulamaya izin verin."]
            )
        }
    }
    
    // MARK: - BackupServiceProtocol
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        // Önce ağ iznini bekle
        try await waitForNetworkPermission()
        
        self.logger.info("Starting WebDAV connection: \(host):\(port)")
        
        self.logger.debug("Initial host: '\(host)'")
        
        // App is connecting - detect background mode for upload strategy logging
        let isBackgroundMode = UIApplication.shared.applicationState != .active
        if isBackgroundMode {
            self.isBackgroundUploading = true
            self.logger.info("📱 Background upload mode detected")
        } else {
            self.isBackgroundUploading = false
            self.logger.info("📱 Foreground upload mode detected")
        }
        
        // Configure the default URL cache
        URLCache.shared = URLCache(
            memoryCapacity: 0,
            diskCapacity: 0,
            diskPath: nil
        )
        
        let connectionInfo = try WebDAVConnectionBuilder.build(host: host, port: port)
        let url = connectionInfo.url
        self.logger.info("Determined scheme: \(connectionInfo.scheme) (Port: \(port))")
        self.logger.info("Final WebDAV URL: \(url.absoluteString)")
        
        // Set up credentials if provided
        let credential: URLCredential?
        if let username = username, !username.isEmpty {
            credential = URLCredential(
                user: username,
                password: password ?? "",
                persistence: .forSession
            )
            self.logger.debug("Credentials set - Username: \(username)")
        } else {
            credential = nil
            self.logger.warning("No credentials provided - attempting anonymous connection")
        }
        
        // Disconnect any existing connection
        disconnect()
        
        // Log the final configuration
        self.logger.debug("""
        WebDAV Connection Settings:
        - URL: \(url.absoluteString)
        - Scheme: \(connectionInfo.scheme)
        - Host: \(connectionInfo.host)
        - Port: \(port)
        - Path: \(connectionInfo.path)
        - Background Mode: \(isBackgroundMode)
        """)
        
        // Create and configure the WebDAV provider
        guard let provider = WebDAVFileProvider(baseURL: url, credential: credential) else {
            let error = NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create WebDAV provider"])
            self.logger.error("\(error.localizedDescription)")
            throw error
        }
        
        self.logger.info("WebDAV provider created")
        
        // Store the provider before testing connection
        self.webdavProvider = provider
        
        // Store base URL and credentials for background URLSession requests
        self.currentBaseURL = url
        self.currentCredential = credential
        
        self.isConnected = false
        
        // Test the connection
        self.logger.info("Testing WebDAV connection...")
        
        try await executeWithRetry {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var didResume = false
                func safeThrow(_ error: Error) {
                    if didResume { return }
                    didResume = true
                    continuation.resume(throwing: error)
                }
                func safeResume() {
                    if didResume { return }
                    didResume = true
                    continuation.resume()
                }
                
                provider.contentsOfDirectory(path: "/") { files, error in
                    if let error = error {
                        self.logger.error("Connection test failed: \(error.localizedDescription)")
                        
                        var errorMessage = "Could not connect to server."
                        var errorCode = -1
                        
                        if let nsError = error as NSError? {
                            errorCode = nsError.code
                            self.logger.error("   - Error code: \(nsError.code)")
                            self.logger.error("   - Error domain: \(nsError.domain)")
                            if nsError.domain == NSURLErrorDomain {
                                switch nsError.code {
                                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                                    errorMessage = "Server not found or unreachable."
                                    self.logger.error("   - DNS/Host resolution failed")
                                case NSURLErrorTimedOut:
                                    errorMessage = "Connection timed out."
                                    self.logger.error("   - Request timeout")
                                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                                    errorMessage = "No internet connection."
                                    self.logger.error("   - Network connection issue")
                                case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
                                    errorMessage = "Secure connection failed. SSL certificate may be invalid."
                                    self.logger.error("   - SSL certificate issue")
                                case NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication:
                                    errorMessage = "Authentication failed. Please check your username and password."
                                    self.logger.error("   - Authentication error")
                                default:
                                    errorMessage = "Network error occurred: \(nsError.localizedDescription)"
                                    self.logger.error("   - General network error")
                                }
                            } else if nsError.domain.contains("WebDav") {
                                switch nsError.code {
                                case 1:
                                    errorMessage = "Could not connect to server. Please check server address and port."
                                    self.logger.error("   - WebDAV Error Code 1: Connection failed")
                                case 2:
                                    errorMessage = "Authentication failed. Please check your username and password."
                                    self.logger.error("   - WebDAV Error Code 2: Authentication failed")
                                case 4:
                                    errorMessage = "Permission denied. You do not have sufficient permissions."
                                    self.logger.error("   - WebDAV Error Code 4: Permission error")
                                case 5:
                                    errorMessage = "Server error occurred. Please try again later."
                                    self.logger.error("   - WebDAV Error Code 5: Server error")
                                default:
                                    if nsError.code == 405 ||
                                       error.localizedDescription.contains("405") ||
                                       error.localizedDescription.contains("Method Not Allowed") ||
                                       (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == 405 {
                                        errorMessage = "WebDAV listing not supported in root directory. WebDAV may be active on a different path (e.g., /webdav, /storage). Please check the WebDAV path."
                                        self.logger.error("   - HTTP 405: WebDAV path issue")
                                    } else {
                                        errorMessage = "WebDAV error occurred: \(error.localizedDescription)"
                                        self.logger.error("   - General WebDAV error")
                                    }
                                }
                            }
                        }
                        
                        let detailedError = NSError(
                            domain: "WebDAVError",
                            code: errorCode,
                            userInfo: [
                                NSLocalizedDescriptionKey: errorMessage,
                                NSUnderlyingErrorKey: error
                            ]
                        )
                        
                        self.isConnected = false
                        self.webdavProvider = nil
                        self.lastError = detailedError
                        safeThrow(detailedError)
                    } else {
                        self.logger.info("Successfully connected. Found \(files.count) items.")
                        self.isConnected = true
                        safeResume()
                    }
                }
            }
        }
    }
    
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler, allowBackgroundSession: true)
    }
    
    /// Sync engine gibi "başarılı" sayılmadan önce gerçek tamamlanma bekleyen akışlar için.
    func uploadFileAwaitingCompletion(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler, allowBackgroundSession: false)
    }
    
    private func uploadFile(
        localURL: URL,
        remotePath: String,
        progressHandler: ((Double) -> Void)?,
        allowBackgroundSession: Bool
    ) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        
        // Sync sırasında enqueue edip "başarılı" saymamak için background opsiyonel.
        let useBackgroundSession = allowBackgroundSession && isBackgroundUploading && backgroundURLSession != nil
        
        if useBackgroundSession {
            try await uploadFileUsingBackgroundSession(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
            return
        }
        
        // Foreground uploads: stream from file to avoid memory pressure
        do {
            try await executeWithRetry {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var didResume = false
                    func safeThrow(_ error: Error) {
                        if didResume { return }
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                    func safeResume() {
                        if didResume { return }
                        didResume = true
                        continuation.resume()
                    }

                    provider.copyItem(localFile: localURL, to: remotePath, overwrite: true) { error in
                        if let error = error {
                            self.lastError = error
                            safeThrow(WebDAVErrorMapper.mapError(error))
                        } else {
                            safeResume()
                        }
                    }
                }
            }
        } catch {
            self.lastError = error
            throw WebDAVErrorMapper.mapError(error)
        }
    }
    
    // MARK: - Background URLSession Upload
    private func uploadFileUsingBackgroundSession(
        localURL: URL,
        remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        guard let session = backgroundURLSession else {
            throw BackupServiceError.connectionFailed
        }
        guard let baseURL = currentBaseURL else {
            throw BackupServiceError.connectionFailed
        }

        // Build absolute URL by appending the remote path to base URL
        let relativePath = remotePath.hasPrefix("/") ? String(remotePath.dropFirst()) : remotePath
        let targetURL = baseURL.appendingPathComponent(relativePath)

        var request = URLRequest(url: targetURL)
        request.httpMethod = "PUT"
        // Add Authorization header if we have credentials (Basic auth)
        if let cred = currentCredential, let user = cred.user {
            let pwd = cred.password ?? ""
            let userPass = "\(user):\(pwd)"
            if let authData = userPass.data(using: .utf8) {
                let token = authData.base64EncodedString()
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // Set current file for UI feedback
        self.currentFile = localURL.lastPathComponent
        self.logger.info("🌐 Enqueuing background PUT upload: \(targetURL.absoluteString)")

        // Enqueue background upload task from file (no in-memory buffering)
        let task = session.uploadTask(with: request, fromFile: localURL)
        
        if let activeIdString = UserDefaults.standard.string(forKey: "ActiveBackupTaskId") {
            struct _Meta: Codable { let taskId: String; let remotePath: String; let localFileName: String; let enqueuedAt: Date }
            let meta = _Meta(taskId: activeIdString, remotePath: remotePath, localFileName: localURL.lastPathComponent, enqueuedAt: Date())
            if let data = try? JSONEncoder().encode(meta), let json = String(data: data, encoding: .utf8) {
                task.taskDescription = json
            } else {
                task.taskDescription = "WebDAVUpload:\(remotePath)"
            }
        } else {
            task.taskDescription = "WebDAVUpload:\(remotePath)"
        }
        
        task.resume()

        // Best-effort initial progress callback
        progressHandler?(0.0)
    }
    
    // Returns file info (size, name) of remote item if exists, nil if not exists
    private func getRemoteFileInfo(at path: String) async throws -> (size: Int64, name: String)? {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(size: Int64, name: String)?, Error>) in
            var didResume = false
            func safeThrow(_ error: Error) {
                if didResume { return }
                didResume = true
                continuation.resume(throwing: error)
            }
            func safeResume(_ value: (size: Int64, name: String)?) {
                if didResume { return }
                didResume = true
                continuation.resume(returning: value)
            }
            
            provider.attributesOfItem(path: path) { file, error in
                if error != nil {
                    // Treat any error as non-existent to allow upload to proceed
                    safeResume(nil)
                } else if let file = file {
                    safeResume((size: file.size, name: file.name))
                } else {
                    safeResume(nil)
                }
            }
        }
    }
    
    // Mirror-style sync upload with full synchronization (upload new, skip identical, delete orphans)
    private func syncUploadDirectory(
        localPath: String,
        remoteBasePath: String,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (filesUploaded: Int, filesSkipped: Int, filesFailed: Int, bytesTransferred: Int64, deletedFiles: Int) {
        let engine = try makeSyncEngine()
        return try await engine.syncUploadDirectory(
            localPath: localPath,
            remoteBasePath: remoteBasePath,
            progressHandler: progressHandler
        )
    }

    func createDirectory(at path: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        let ops = WebDAVFileOperations(provider: provider)
        do {
            try await executeWithRetry {
                try await ops.createDirectory(at: path)
            }
        } catch {
            self.lastError = error
            throw error
        }
    }
    
    func listDirectory(at path: String) async throws -> [FileObject] {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        let ops = WebDAVFileOperations(provider: provider)
        do {
            return try await executeWithRetry {
                try await ops.listDirectory(at: path)
            }
        } catch {
            self.lastError = error
            throw error
        }
    }
    
    func deleteFile(at path: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        let ops = WebDAVFileOperations(provider: provider)
        do {
            try await executeWithRetry {
                try await ops.deleteFile(at: path)
            }
        } catch {
            self.lastError = error
            throw error
        }
    }
    
    func disconnect() {
        webdavProvider = nil
        currentBaseURL = nil
        currentCredential = nil
        isConnected = false
        lastError = nil
        isBackgroundUploading = false
    }
    
    /// Tests different common WebDAV paths to find the correct endpoint
    func findWebDAVPath(host: String, port: Int, username: String?, password: String?) async -> String? {
        let commonPaths = ["", "/webdav", "/dav", "/storage", "/usb", "/share"]
        
        for path in commonPaths {
            self.logger.info("Testing WebDAV path: \(path.isEmpty ? "/" : path)")
            
            do {
                let testHost = path.isEmpty ? host : host + path
                try await connect(host: testHost, port: port, username: username, password: password)
                
                // If we get here, the connection was successful
                self.logger.info("WebDAV path found: \(path.isEmpty ? "/" : path)")
                disconnect()
                return path.isEmpty ? "/" : path
            } catch {
                self.logger.debug("WebDAV path failed: \(path.isEmpty ? "/" : path) - \(error.localizedDescription)")
                disconnect()
            }
        }
        
        self.logger.error("No working WebDAV path found")
        return nil
    }
    
    /// Tests the WebDAV connection and authentication
    func testConnection(host: String, port: Int, username: String?, password: String?) async -> Bool {
        self.logger.info("Starting WebDAV connection test: \(host):\(port)")
        
        // Clean up any existing connection first
        disconnect()
        
        do {
            // Önce ağ iznini bekle
            try await waitForNetworkPermission()
            
            // First, try to connect with the provided credentials
            self.logger.info("Connecting to WebDAV server...")
            self.logger.info("   - Host: \(host)")
            self.logger.info("   - Port: \(port)")
            self.logger.info("   - User: \(username ?? "Not specified")")
            
            try await connect(host: host, port: port, username: username, password: password)
            
            guard let provider = webdavProvider else { 
                self.logger.error("Connection test failed: WebDAV provider could not be initialized")
                return false 
            }
            
            self.logger.info("Successfully connected. Checking authentication and permissions...")
            
            // First, try to list the root directory to verify read permissions
            self.logger.info("Listing root directory...")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var didResume = false
                func safeThrow(_ error: Error) {
                    if didResume { return }
                    didResume = true
                    continuation.resume(throwing: error)
                }
                func safeResume() {
                    if didResume { return }
                    didResume = true
                    continuation.resume()
                }
                
                provider.contentsOfDirectory(path: "/") { files, error in
                    if let error = error {
                        self.logger.error("Failed to list root directory: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            self.logger.error("   - Domain: \(nsError.domain)")
                            self.logger.error("   - Code: \(nsError.code)")
                        }
                        safeThrow(error)
                        return
                    }
                    self.logger.info("Successfully listed root directory. Found \(files.count) items.")
                    safeResume()
                }
            }
            
            // Test file upload
            let testFileName = "backupflow_test_\(UUID().uuidString.prefix(8)).txt"
            let testFilePath = "/\(testFileName)"
            let testContent = "BackupFlow test file".data(using: .utf8)!
            
            self.logger.info("Testing file upload to root directory...")
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var didResume = false
                    func safeThrow(_ error: Error) {
                        if didResume { return }
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                    func safeResume() {
                        if didResume { return }
                        didResume = true
                        continuation.resume()
                    }
                    
                    provider.writeContents(
                        path: testFilePath,
                        contents: testContent,
                        atomically: true,
                        overwrite: true
                    ) { error in
                        if let error = error {
                            self.logger.error("File upload test failed: \(error.localizedDescription)")
                            if let nsError = error as NSError? {
                                self.logger.error("   - Error domain: \(nsError.domain)")
                                self.logger.error("   - Error code: \(nsError.code)")
                                
                                // Provide user-friendly error messages
                                if nsError.domain.contains("WebDav") {
                                    switch nsError.code {
                                    case 1, 2:
                                        self.logger.error("   - The server may not have WebDAV enabled or the path is incorrect.")
                                    case 4:
                                        self.logger.error("   - Authentication failed. Please check your username and password.")
                                    case 5:
                                        self.logger.error("   - Permission denied. You may not have write access to the server.")
                                    default:
                                        break
                                    }
                                }
                            }
                            safeThrow(error)
                            return
                        }
                        self.logger.info("File upload successful")
                        
                        // Clean up the test file
                        provider.removeItem(path: testFilePath) { _ in }
                        safeResume()
                    }
                }
                
                self.logger.info("WebDAV connection test completed successfully!")
                return true
                
            } catch {
                // If file upload fails, still consider it a success if we could connect and list the directory
                self.logger.warning("File upload test failed, but connection was established. This might be due to read-only access.")
                return true
            }
            
        } catch {
            self.logger.error("Connection test failed with error: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                self.logger.error("   - Domain: \(nsError.domain)")
                self.logger.error("   - Code: \(nsError.code)")
                
                // Provide more user-friendly error messages based on the error code
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                        self.logger.error("   - Could not connect to the server. Please check the server address and port.")
                    case NSURLErrorUserAuthenticationRequired, NSURLErrorUserCancelledAuthentication:
                        self.logger.error("   - Authentication failed. Please check your username and password.")
                    case NSURLErrorTimedOut:
                        self.logger.error("   - Connection timed out. Please check your internet connection and try again.")
                    case NSURLErrorNetworkConnectionLost:
                        self.logger.error("   - Network connection was lost. Please check your internet connection.")
                    case NSURLErrorNotConnectedToInternet:
                        self.logger.error("   - Not connected to the internet. Please check your network connection.")
                    default:
                        break
                    }
                } else if nsError.domain.contains("WebDav") {
                    switch nsError.code {
                    case 1, 2:
                        self.logger.error("   - The server may not have WebDAV enabled or the path is incorrect.")
                    case 4:
                        self.logger.error("   - Authentication failed. Please check your username and password.")
                    case 5:
                        self.logger.error("   - Permission denied. You may not have the necessary permissions.")
                    default:
                        break
                    }
                }
            }
            return false
        }
    }
    
    // MARK: - Directory Management
    private func ensureDirectoryExists(at path: String) async throws {
        guard let provider = webdavProvider else {
            throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebDAV provider not available"])
        }
        let ops = WebDAVFileOperations(provider: provider)
        try await ops.ensureDirectoryExists(at: path, logger: logger)
    }

    private func makeSyncEngine() throws -> WebDAVSyncEngine {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        return WebDAVSyncEngine(
            provider: provider,
            fileManager: fileManager,
            logger: logger,
            deleteOrphansEnabled: deleteOrphansEnabled,
            ensureDirectoryExists: { [weak self] path in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.ensureDirectoryExists(at: path)
            },
            deleteFile: { [weak self] path in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.deleteFile(at: path)
            },
            setCurrentFile: { [weak self] name in
                self?.currentFile = name
            },
            uploadFile: { [weak self] localURL, remotePath in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.uploadFileAwaitingCompletion(localURL: localURL, remotePath: remotePath, progressHandler: nil)
            }
        )
    }
    
    private func uploadDirectory(localPath: String, remotePath: String, progressHandler: @escaping (Double) -> Void) async throws -> (filesUploaded: Int, filesSkipped: Int, filesFailed: Int, bytesTransferred: Int64) {
        guard let provider = webdavProvider else {
            self.logger.error("WebDAV provider not available")
            throw BackupServiceError.connectionFailed
        }
        
        self.logger.info("Uploading directory: \(localPath) -> \(remotePath)")
        
        // Ensure remote directory exists
        try await ensureDirectoryExists(at: remotePath)
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: localPath), 
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], 
            options: [.skipsHiddenFiles]
        )
        
        var uploaded = 0, skipped = 0, failed = 0
        var transferred: Int64 = 0
        
        for (index, fileURL) in fileURLs.enumerated() {
            let fileName = fileURL.lastPathComponent
            let remoteFilePath = remotePath.isEmpty ? fileName : (remotePath as NSString).appendingPathComponent(fileName)
            progressHandler(Double(index) / Double(fileURLs.count))
            
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            
            if resourceValues.isDirectory == true {
                // Handle directory
                try await createDirectory(at: remoteFilePath)
                let subResult = try await uploadDirectory(
                    localPath: fileURL.path, 
                    remotePath: remoteFilePath, 
                    progressHandler: { _ in }
                )
                uploaded += subResult.filesUploaded
                skipped += subResult.filesSkipped
                failed += subResult.filesFailed
                transferred += subResult.bytesTransferred
            } else {
                // Handle file
                let size = Int64(resourceValues.fileSize ?? 0)
                do {
                    // Upload file
                    self.logger.info("Uploading: \(fileURL.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
                    
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        // Upload file directly from URL to reduce memory usage
                        provider.copyItem(localFile: fileURL, to: remoteFilePath, overwrite: true) { error in
                            if let error = error {
                                self.logger.error("Failed to upload file: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
                                failed += 1
                                continuation.resume(throwing: error)
                            } else {
                                self.logger.info("Successfully uploaded: \(fileURL.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))")
                                uploaded += 1
                                transferred += size
                                continuation.resume()
                            }
                        }
                    }
                } catch {
                    self.logger.error("Failed to read file: \(fileURL.lastPathComponent) - \(error.localizedDescription)")
                    failed += 1
                }
            }
        }
        return (uploaded, skipped, failed, transferred)
    }
    
    private func backupPhotoLibrary(to destination: URL, mediaType: MediaType, progressHandler: @escaping (Double) -> Void) async throws -> Int {
        let status = PHPhotoLibrary.authorizationStatus()
        guard status == .authorized || status == .limited else {
            throw BackupServiceError.authenticationFailed
        }
        
        let fetchOptions = PHFetchOptions()
        
        // Metadata optimizasyonu - PHAsset özelliklerini önceden yükle
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        fetchOptions.includeHiddenAssets = false
        
        let fetchResult: PHFetchResult<PHAsset>
        
        switch mediaType {
        case .photosOnly: 
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        case .videosOnly: 
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
            fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        case .photosAndVideos: 
            fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        }
        
        let count = fetchResult.count
        guard count > 0 else { return 0 }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        let imageManager = PHImageManager.default()
        var saved = 0
        
        for i in 0..<count {
            let asset = fetchResult.object(at: i)
            let progress = Double(i + 1) / Double(count)
            progressHandler(progress)
            
            // Generate consistent filename like FTP service
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = asset.creationDate ?? Date()
            let dateString = dateFormatter.string(from: date)
            
            let fileExtension = asset.mediaType == .image ? "jpg" : "mp4"
            let consistentFilename = "\(dateString)_\(String(i + 1).padding(toLength: 3, withPad: "0", startingAt: 0)).\(fileExtension)"
            let fileURL = destination.appendingPathComponent(consistentFilename)
            
            if fileManager.fileExists(atPath: fileURL.path) { 
                saved += 1
                continue 
            }
            
            if asset.mediaType == .image {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // Performans için background thread'de çalıştır
                    DispatchQueue.global(qos: .userInitiated).async {
                        let options = PHImageRequestOptions()
                        options.isNetworkAccessAllowed = true
                        options.deliveryMode = .highQualityFormat
                        options.resizeMode = .none
                        options.isSynchronous = false
                        
                        imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                            do {
                                if let data = data {
                                    try data.write(to: fileURL)
                                    saved += 1
                                }
                                continuation.resume()
                            } catch {
                                self.logger.error("Failed to save image: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            } else if asset.mediaType == .video {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let options = PHVideoRequestOptions()
                    options.isNetworkAccessAllowed = true

                    imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                        guard let avAsset = avAsset else {
                            continuation.resume()
                            return
                        }

                        Task {
                            do {
                                guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
                                    continuation.resume()
                                    return
                                }
                                // Use modern async export API on AVAssetExportSession
                                try await exportSession.export(to: fileURL, as: AVFileType.mp4)
                                saved += 1
                                continuation.resume()
                            } catch {
                                self.logger.error("Failed to export video: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            }
        }
        return saved
    }
    
    // MARK: - Backup Implementation
    func performBackup(host: String, port: Int, username: String?, password: String?, sourcePath: String, isAnonymous: Bool, mediaType: MediaType, progressHandler: @escaping (Double) -> Void) async throws -> FTPService.SyncResult {
        self.logger.info("Starting backup: \(host):\(port)")
        if sourcePath == "PHOTOS_LIBRARY" {
            self.logger.info("Media type: \(mediaType == .photosOnly ? "Photos only" : "Photos and Videos")")
        } else {
            self.logger.info("Media type: Directory backup")
        }
        
        // Clean and validate the host string
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var webdavPath = "/"
        
        self.logger.debug("Backup - Initial host: '\(host)'")
        
        // Handle malformed URLs like "http:/192.168.2.106" (missing second slash)
        cleanHost = cleanHost.replacingOccurrences(of: "http:/", with: "http://")
        cleanHost = cleanHost.replacingOccurrences(of: "https:/", with: "https://")
        cleanHost = cleanHost.replacingOccurrences(of: "://http://", with: "://") // Fix double protocol
        cleanHost = cleanHost.replacingOccurrences(of: "://https://", with: "://") // Fix double protocol
        
        // Remove any URL scheme if present
        if let schemeRange = cleanHost.range(of: "://") {
            cleanHost = String(cleanHost[schemeRange.upperBound...])
        }
        
        // Extract WebDAV path if present (e.g., example.com/webdav)
        if let pathRange = cleanHost.range(of: "/") {
            webdavPath = String(cleanHost[pathRange.lowerBound...])
            cleanHost = String(cleanHost[..<pathRange.lowerBound])
            self.logger.info("Backup - Extracted WebDAV path: '\(webdavPath)'")
            self.logger.debug("Backup - Cleaned host: '\(cleanHost)'")
        }
        
        // Establish connection
        self.logger.info("Backup - Connecting to WebDAV server...")
        if !self.isConnected {
            try await connect(host: cleanHost, port: port, username: username, password: password)
        } else {
            self.logger.info("Backup - Reusing existing WebDAV connection")
        }
        
        guard webdavProvider != nil else {
            throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebDAV provider is not available"])
        }
        
        // Create a temporary directory for the backup
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        var result = FTPService.SyncResult()
        
        if sourcePath == "PHOTOS_LIBRARY" {
            self.logger.info("Backing up photo library...")
            let photoCount = try await backupPhotoLibrary(to: tempDir, mediaType: mediaType) { p in
                progressHandler(p * 0.5)
            }
            self.logger.info("Backed up \(photoCount) photos to temporary directory")

            // Mirror to a fixed 'photos' directory (no timestamp), with skip/update + orphan delete
            let remotePhotosBase = webdavPath + "photos"
            try await ensureDirectoryExists(at: remotePhotosBase)
            let sync = try await syncUploadDirectory(
                localPath: tempDir.path,
                remoteBasePath: remotePhotosBase,
                progressHandler: { p in progressHandler(0.5 + p * 0.5) }
            )
            result.newFiles = sync.filesUploaded
            result.skippedFiles = sync.filesSkipped
            result.deletedFiles = sync.deletedFiles
            result.totalBytes = sync.bytesTransferred
            self.logger.info("Successfully synced photos to WebDAV (uploaded: \(sync.filesUploaded), skipped: \(sync.filesSkipped), deleted: \(sync.deletedFiles))")
        } else {
            // Directory mirror - preserve source folder name
            self.logger.info("Backing up directory (mirror): \(sourcePath)")
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let sourceFolderName = sourceURL.lastPathComponent
            let remoteDocumentsBase = webdavPath.hasSuffix("/") ? webdavPath + sourceFolderName : webdavPath + "/" + sourceFolderName
            try await ensureDirectoryExists(at: remoteDocumentsBase)
            let sync = try await syncUploadDirectory(
                localPath: sourcePath,
                remoteBasePath: remoteDocumentsBase,
                progressHandler: progressHandler
            )
            result.newFiles = sync.filesUploaded
            result.skippedFiles = sync.filesSkipped
            result.deletedFiles = sync.deletedFiles
            result.totalBytes = sync.bytesTransferred
            self.logger.info("Successfully synced directory to WebDAV: \(sourceFolderName)/ (uploaded: \(sync.filesUploaded), skipped: \(sync.filesSkipped), deleted: \(sync.deletedFiles))")
        }
        
        return result
    }
}

#endif


