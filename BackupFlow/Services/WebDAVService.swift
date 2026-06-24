#if canImport(FilesProvider)

import Foundation
import FilesProvider
import OSLog
import Combine
@preconcurrency import Photos
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
    private let temporaryExportRootName = "backupflow_exports"
    private let photoLibraryManager = PhotoLibraryManager.shared
    private let backgroundUploader = WebDAVBackgroundUploader(logger: Logger(subsystem: "com.backupflow.app", category: "WebDAVService"))
    
    private var webdavProvider: WebDAVFileProvider?
    private var currentBaseURL: URL?
    private var currentCredential: URLCredential?
    private var backgroundURLSession: URLSession?
    private var backgroundURLSessionCompletionHandler: (() -> Void)?
    private var currentUploadTask: URLSessionTask?
    private lazy var backgroundSessionDelegate = WebDAVBackgroundSessionDelegate(
        logger: logger,
        allowSelfSigned: self.allowSelfSignedCertificates,
        onTaskProgress: { [weak self] task, totalBytesSent, totalBytesExpected in
            guard totalBytesExpected > 0 else { return }
            let progress = Double(totalBytesSent) / Double(totalBytesExpected)
            Task { @MainActor in
                self?.updateCurrentUploadProgress(
                    progress: progress,
                    bytesSent: totalBytesSent,
                    totalBytes: totalBytesExpected
                )
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
    private var lastLoggedNetworkStatus: NWPath.Status?
    
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
        // Not resetting progress/currentFile here to preserve UI continuity across foreground/background
        self.logger.info("📱 \(isBackground ? "Background" : "Foreground") upload mode enabled")
    }
    
    @Published private(set) var isConnected = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    @Published private(set) var currentFileBytesTransferred: Int64 = 0
    @Published private(set) var currentFileTotalBytes: Int64 = 0
    @Published private(set) var transferSpeedBytesPerSecond: Double = 0
    @Published private(set) var networkPermissionGranted = false
    private(set) var lastError: Error?
    private var lastProgressSample: (date: Date, bytes: Int64)?
    private var currentUploadProgressHandler: ((Double) -> Void)?
    
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
        let clamped = max(0.0, min(1.0, Double(progress)))
        let estimatedBytes = currentFileTotalBytes > 0 ? Int64(Double(currentFileTotalBytes) * clamped) : 0
        updateCurrentUploadProgress(
            progress: clamped,
            bytesSent: estimatedBytes,
            totalBytes: currentFileTotalBytes
        )
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
            guard let self else { return }
            self.networkPermissionGranted = status == .satisfied
            let didChange = self.lastLoggedNetworkStatus != status
            self.lastLoggedNetworkStatus = status
            guard didChange else { return }
            if status == .satisfied {
                self.logger.info("Ağ bağlantısı kullanılabilir")
            } else {
                let statusString = WebDAVNetworkMonitor.statusString(status)
                self.logger.warning("Ağ bağlantısı kullanılamıyor: \(statusString)")
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
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler, allowBackgroundSession: false, timeoutMultiplier: 1.0)
    }
    
    private func uploadFile(
        localURL: URL,
        remotePath: String,
        progressHandler: ((Double) -> Void)?,
        allowBackgroundSession: Bool,
        timeoutMultiplier: Double = 1.0
    ) async throws {
        guard webdavProvider != nil else {
            throw BackupServiceError.connectionFailed
        }
        
        // Sync sırasında enqueue edip "başarılı" saymamak için background opsiyonel.
        let useBackgroundSession = allowBackgroundSession && isBackgroundUploading && backgroundURLSession != nil
        
        if useBackgroundSession {
            // Set current file for UI feedback only if empty to reduce UI flicker/resets
            if self.currentFile.isEmpty { self.currentFile = localURL.lastPathComponent }
            prepareCurrentUpload(localURL: localURL, progressHandler: progressHandler)
            try await uploadFileUsingBackgroundSession(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
            return
        }
        
        // Foreground uploads: stream from file to avoid memory pressure
        do {
            prepareCurrentUpload(localURL: localURL, progressHandler: progressHandler)
            let timeoutSeconds = uploadTimeoutSeconds(for: localURL) * max(1.0, timeoutMultiplier)
            try await executeWithRetry {
                try await self.uploadFileUsingForegroundSession(
                    localURL: localURL,
                    remotePath: remotePath,
                    timeoutSeconds: timeoutSeconds
                )
            }
        } catch {
            self.lastError = error
            if isUploadTimeoutError(error) {
                throw error
            }
            throw WebDAVErrorMapper.mapError(error)
        }
    }

    private func uploadTimeoutSeconds(for localURL: URL) -> TimeInterval {
        let fileSizeBytes = Int64((try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let fileSizeMB = Double(max(fileSizeBytes, 0)) / (1024.0 * 1024.0)
        let ext = localURL.pathExtension.lowercased()
        let isLikelyVideo = ["mp4", "mov", "m4v", "avi", "mkv", "hevc"].contains(ext)
        let base = isLikelyVideo ? 240.0 : 120.0
        let perMB = isLikelyVideo ? 14.0 : 8.0
        // Video-heavy uploads on slow links need wider timeout budget.
        return min(3600, max(120, base + (fileSizeMB * perMB)))
    }

    private func isUploadTimeoutError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
            return true
        }
        if case let BackupServiceError.unknown(underlying) = error {
            let underlyingNSError = underlying as NSError
            return underlyingNSError.domain == NSURLErrorDomain && underlyingNSError.code == NSURLErrorTimedOut
        }
        return false
    }

    private func prepareCurrentUpload(localURL: URL, progressHandler: ((Double) -> Void)? = nil) {
        currentFile = localURL.lastPathComponent
        progress = 0
        currentFileBytesTransferred = 0
        currentFileTotalBytes = Int64((try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        transferSpeedBytesPerSecond = 0
        lastProgressSample = (Date(), 0)
        currentUploadProgressHandler = progressHandler
        progressHandler?(0.0)
    }

    private func updateCurrentUploadProgress(progress: Double, bytesSent: Int64, totalBytes: Int64) {
        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
        let now = Date()
        let safeTotal = max(totalBytes, currentFileTotalBytes)
        let safeBytes = max(0, min(bytesSent, safeTotal > 0 ? safeTotal : bytesSent))

        if let sample = lastProgressSample {
            let elapsed = now.timeIntervalSince(sample.date)
            let delta = safeBytes - sample.bytes
            if elapsed > 0.35, delta >= 0 {
                transferSpeedBytesPerSecond = Double(delta) / elapsed
                lastProgressSample = (now, safeBytes)
            }
        } else {
            lastProgressSample = (now, safeBytes)
        }

        self.progress = safeProgress
        currentFileBytesTransferred = safeBytes
        currentFileTotalBytes = safeTotal
        currentUploadProgressHandler?(safeProgress)
    }

    private func makeUploadRequest(remotePath: String) throws -> URLRequest {
        guard let baseURL = currentBaseURL else {
            throw BackupServiceError.connectionFailed
        }

        let relativePath = remotePath.hasPrefix("/") ? String(remotePath.dropFirst()) : remotePath
        let targetURL = baseURL.appendingPathComponent(relativePath)

        var request = URLRequest(url: targetURL)
        request.httpMethod = "PUT"

        if let cred = currentCredential, let user = cred.user {
            let pwd = cred.password ?? ""
            let userPass = "\(user):\(pwd)"
            if let authData = userPass.data(using: .utf8) {
                let token = authData.base64EncodedString()
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        return request
    }

    private func uploadFileUsingForegroundSession(
        localURL: URL,
        remotePath: String,
        timeoutSeconds: TimeInterval
    ) async throws {
        let request = try makeUploadRequest(remotePath: remotePath)
        let fileSize = currentFileTotalBytes

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumeLock = NSLock()
            var didResume = false
            var session: URLSession?

            func finish(_ result: Result<Void, Error>) {
                var shouldResume = false
                resumeLock.lock()
                if !didResume {
                    didResume = true
                    shouldResume = true
                }
                resumeLock.unlock()

                guard shouldResume else { return }
                session?.finishTasksAndInvalidate()
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let delegate = WebDAVBackgroundSessionDelegate(
                logger: logger,
                allowSelfSigned: self.allowSelfSignedCertificates,
                onTaskProgress: { [weak self] _, totalBytesSent, totalBytesExpected in
                    guard let self else { return }
                    let expectedBytes = totalBytesExpected > 0 ? totalBytesExpected : fileSize
                    guard expectedBytes > 0 else { return }
                    let progress = Double(totalBytesSent) / Double(expectedBytes)
                    Task { @MainActor in
                        self.updateCurrentUploadProgress(
                            progress: progress,
                            bytesSent: totalBytesSent,
                            totalBytes: expectedBytes
                        )
                    }
                },
                onTaskComplete: { task, error in
                    if let error {
                        finish(.failure(WebDAVErrorMapper.mapError(error)))
                        return
                    }

                    if let response = task.response as? HTTPURLResponse,
                       !(200...299).contains(response.statusCode) {
                        let error = NSError(
                            domain: "WebDAVService",
                            code: response.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "WebDAV upload failed with HTTP \(response.statusCode)"]
                        )
                        finish(.failure(WebDAVErrorMapper.mapError(error)))
                        return
                    }

                    Task { @MainActor in
                        self.updateCurrentUploadProgress(progress: 1.0, bytesSent: fileSize, totalBytes: fileSize)
                    }
                    finish(.success(()))
                },
                onFinishEvents: {}
            )

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = timeoutSeconds
            configuration.httpMaximumConnectionsPerHost = 1
            configuration.allowsCellularAccess = true
            configuration.waitsForConnectivity = true

            session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session?.uploadTask(with: request, fromFile: localURL)
            self.currentUploadTask = task
            task?.resume()
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
        let request = try makeUploadRequest(remotePath: remotePath)

        // Set current file for UI feedback
        self.currentFile = localURL.lastPathComponent
        prepareCurrentUpload(localURL: localURL, progressHandler: progressHandler)
        self.logger.info("🌐 Enqueuing background PUT upload: \(request.url?.absoluteString ?? remotePath)")

        // Enqueue background upload task from file (no in-memory buffering)
        let task = session.uploadTask(with: request, fromFile: localURL)
        self.currentUploadTask = task
        
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

    func cancelCurrentTask() {
        logger.info("WebDAV işlemi iptal ediliyor...")
        currentUploadTask?.cancel()
        currentUploadTask = nil
        backgroundURLSession?.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
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

    private func listAllRemoteFiles(at path: String, relativeTo basePath: String = "") async throws -> [String: FileObject] {
        var allFiles: [String: FileObject] = [:]
        let files = try await listDirectory(at: path)

        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            if file.isDirectory {
                let subdirPath = path == "/" ? "/\(file.name)" : "\(path)/\(file.name)"
                let subFiles = try await listAllRemoteFiles(at: subdirPath, relativeTo: relativePath)
                allFiles.merge(subFiles) { _, new in new }
            } else {
                allFiles[relativePath] = file
            }
        }

        return allFiles
    }

    private func exportRootURL() -> URL {
        fileManager.temporaryDirectory.appendingPathComponent(temporaryExportRootName, isDirectory: true)
    }

    private func syncBackupPhotoLibraryDirect(
        remoteBasePath: String,
        mediaType: MediaType,
        includeICloudAssets: Bool,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> FTPService.SyncResult {
        try await ensureDirectoryExists(at: remoteBasePath)

        let assets = try await photoLibraryManager.getAllAssets(mediaType: mediaType)
        var result = FTPService.SyncResult()

        guard !assets.isEmpty else {
            progressHandler(1.0)
            return result
        }

        let existingFileMap = try await listAllRemoteFiles(at: remoteBasePath)
        let processedRelativePaths = Set(assets.map { photoLibraryManager.generateFileName(for: $0) })
        var timedOutUploads: [(asset: PHAsset, fileName: String, remotePath: String)] = []
        var failedUploads = 0
        let totalAssets = assets.count
        var lastHeartbeatAt = Date()

        try fileManager.createDirectory(at: exportRootURL(), withIntermediateDirectories: true)

        for (index, asset) in assets.enumerated() {
            if index == 0 || (index + 1).isMultiple(of: 10) {
                logger.info("📷 WebDAV photo sync progress: \(index + 1)/\(totalAssets) (uploaded: \(result.newFiles + result.updatedFiles), skipped: \(result.skippedFiles), iCloud-only: \(result.iCloudSkippedFiles), timeout: \(result.timedOutAssetReads), unreadable: \(result.failedAssetReads))")
            }
            if Date().timeIntervalSince(lastHeartbeatAt) >= 30 {
                logger.info("⏳ WebDAV photo sync heartbeat: processed \(index)/\(totalAssets), transferred \(result.totalBytes) bytes")
                lastHeartbeatAt = Date()
            }

            let fileName = photoLibraryManager.generateFileName(for: asset)
            let exportResult = await photoLibraryManager.exportAssetToTemporaryFile(
                asset: asset,
                fileName: fileName,
                allowNetworkAccess: includeICloudAssets
            )
            let tempURL: URL
            let localSize: Int64
            switch exportResult {
            case .success(let exportedURL, let exportedSize):
                tempURL = exportedURL
                localSize = exportedSize
            case .iCloudOnly:
                result.iCloudSkippedFiles += 1
                progressHandler(Double(index + 1) / Double(assets.count))
                continue
            case .timedOut:
                result.timedOutAssetReads += 1
                progressHandler(Double(index + 1) / Double(assets.count))
                continue
            case .unavailable:
                result.failedAssetReads += 1
                progressHandler(Double(index + 1) / Double(assets.count))
                continue
            }
            defer { try? fileManager.removeItem(at: tempURL) }

            let remotePath = remoteBasePath == "/" ? "/\(fileName)" : "\(remoteBasePath)/\(fileName)"

            if let remoteFile = existingFileMap[fileName], remoteFile.size == localSize {
                result.skippedFiles += 1
                result.totalBytes += localSize
                logger.debug("⏭️ Upload skipped (\(index + 1)/\(totalAssets)): \(fileName) (\(localSize) bytes)")
                progressHandler(Double(index + 1) / Double(assets.count))
                continue
            }

            do {
                logger.info("⬆️ Upload starting (\(index + 1)/\(totalAssets)): \(fileName) (\(localSize) bytes)")
                try await uploadFileAwaitingCompletion(localURL: tempURL, remotePath: remotePath) { fileProgress in
                    let assetShare = 1.0 / Double(max(assets.count, 1))
                    let overallProgress = (Double(index) / Double(max(assets.count, 1))) + (fileProgress * assetShare)
                    progressHandler(min(max(overallProgress, 0.0), 1.0))
                }
                logger.info("✅ Upload completed (\(index + 1)/\(totalAssets)): \(fileName)")
            } catch {
                if isUploadTimeoutError(error) {
                    timedOutUploads.append((asset: asset, fileName: fileName, remotePath: remotePath))
                    logger.warning("⏱️ Upload timeout queued for retry: \(fileName)")
                } else {
                    failedUploads += 1
                    logger.error("Upload failed (continuing): \(fileName) - \(error.localizedDescription)")
                }
                progressHandler(Double(index + 1) / Double(assets.count))
                continue
            }

            if existingFileMap[fileName] != nil {
                result.updatedFiles += 1
            } else {
                result.newFiles += 1
            }
            result.totalBytes += localSize
            progressHandler(Double(index + 1) / Double(assets.count))
        }

        if !timedOutUploads.isEmpty {
            logger.info("🔁 Retrying timed out uploads: \(timedOutUploads.count)")
            for item in timedOutUploads {
                let retryExportResult = await photoLibraryManager.exportAssetToTemporaryFile(
                    asset: item.asset,
                    fileName: item.fileName,
                    allowNetworkAccess: includeICloudAssets
                )
                let retryTempURL: URL
                let retrySize: Int64
                switch retryExportResult {
                case .success(let exportedURL, let exportedSize):
                    retryTempURL = exportedURL
                    retrySize = exportedSize
                case .iCloudOnly:
                    result.iCloudSkippedFiles += 1
                    failedUploads += 1
                    logger.warning("Retry skipped (asset iCloud-only): \(item.fileName)")
                    continue
                case .timedOut:
                    result.timedOutAssetReads += 1
                    failedUploads += 1
                    logger.warning("Retry skipped (asset read timeout): \(item.fileName)")
                    continue
                case .unavailable:
                    result.failedAssetReads += 1
                    failedUploads += 1
                    logger.warning("Retry skipped (asset data unavailable): \(item.fileName)")
                    continue
                }
                defer { try? fileManager.removeItem(at: retryTempURL) }

                do {
                    // Relax timeout budget for second-chance uploads on slow/unstable links.
                    try await uploadFile(
                        localURL: retryTempURL,
                        remotePath: item.remotePath,
                        progressHandler: nil,
                        allowBackgroundSession: false,
                        timeoutMultiplier: 2.5
                    )
                    if existingFileMap[item.fileName] != nil {
                        result.updatedFiles += 1
                    } else {
                        result.newFiles += 1
                    }
                    result.totalBytes += retrySize
                } catch {
                    failedUploads += 1
                    logger.error("Retry failed: \(item.fileName) - \(error.localizedDescription)")
                }
            }
        }

        if deleteOrphansEnabled {
            for (relativePath, _) in existingFileMap where !processedRelativePaths.contains(relativePath) {
                let fullRemotePath = remoteBasePath == "/" ? "/\(relativePath)" : "\(remoteBasePath)/\(relativePath)"
                do {
                    try await deleteFile(at: fullRemotePath)
                    result.deletedFiles += 1
                } catch {
                    logger.error("Failed to delete orphaned photo \(relativePath): \(error.localizedDescription)")
                }
            }
        }

        if let remaining = try? fileManager.contentsOfDirectory(
            at: exportRootURL(),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ), remaining.isEmpty {
            try? fileManager.removeItem(at: exportRootURL())
        }

        if failedUploads > 0 {
            logger.warning("⚠️ Photo sync completed with \(failedUploads) failed/timeouted uploads")
        }

        progressHandler(1.0)
        return result
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
        // Do not reset progress/currentFile here to avoid UI resets during transient reconnects
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
                let tempURL = fileManager.temporaryDirectory.appendingPathComponent(testFileName)
                try testContent.write(to: tempURL, options: .atomic)
                defer { try? fileManager.removeItem(at: tempURL) }

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
                    
                    provider.copyItem(localFile: tempURL, to: testFilePath, overwrite: true) { error in
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
            uploadFile: { [weak self] localURL, remotePath, progressHandler in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.uploadFileAwaitingCompletion(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
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
                        // Local-only mode: do not fetch image from iCloud.
                        options.isNetworkAccessAllowed = false
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
                    let resources = PHAssetResource.assetResources(for: asset)
                    guard let videoResource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first else {
                        continuation.resume()
                        return
                    }

                    let requestOptions = PHAssetResourceRequestOptions()
                    // Local-only mode: do not fetch video from iCloud.
                    requestOptions.isNetworkAccessAllowed = false

                    PHAssetResourceManager.default().writeData(for: videoResource, toFile: fileURL, options: requestOptions) { error in
                        if let error = error {
                            self.logger.error("Failed to write video resource: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                            return
                        }
                        saved += 1
                        continuation.resume()
                    }
                }
            }
        }
        return saved
    }
    
    // MARK: - Backup Implementation
    func performBackup(
        host: String,
        port: Int,
        username: String?,
        password: String?,
        sourcePath: String,
        isAnonymous: Bool,
        mediaType: MediaType,
        includeICloudAssets: Bool = true,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> FTPService.SyncResult {
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
        if cleanHost.hasPrefix("http:/") && !cleanHost.hasPrefix("http://") {
            cleanHost = cleanHost.replacingOccurrences(of: "http:/", with: "http://")
        }
        if cleanHost.hasPrefix("https:/") && !cleanHost.hasPrefix("https://") {
            cleanHost = cleanHost.replacingOccurrences(of: "https:/", with: "https://")
        }
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
        
        var result = FTPService.SyncResult()
        
        if sourcePath == "PHOTOS_LIBRARY" {
            self.logger.info("Backing up photo library...")
            // Mirror to a fixed 'photos' directory (no timestamp), with skip/update + orphan delete
            // Use base URL's root ("/") to avoid duplicating the WebDAV path segment.
            let remoteRoot = "/"
            let remotePhotosBase = remoteRoot.hasSuffix("/") ? remoteRoot + "photos" : remoteRoot + "/photos"
            result = try await syncBackupPhotoLibraryDirect(
                remoteBasePath: remotePhotosBase,
                mediaType: mediaType,
                includeICloudAssets: includeICloudAssets,
                progressHandler: progressHandler
            )
            self.logger.info("Successfully synced photos to WebDAV (uploaded: \(result.newFiles), updated: \(result.updatedFiles), skipped: \(result.skippedFiles), iCloud-skipped: \(result.iCloudSkippedFiles), timeouts: \(result.timedOutAssetReads), unreadable: \(result.failedAssetReads), deleted: \(result.deletedFiles))")
        } else {
            // Directory mirror - preserve source folder name
            self.logger.info("Backing up directory (mirror): \(sourcePath)")
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let sourceFolderName = sourceURL.lastPathComponent
            let remoteRoot = "/"
            let remoteDocumentsBase = remoteRoot == "/" ? "/\(sourceFolderName)" : "\(remoteRoot)/\(sourceFolderName)"
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
