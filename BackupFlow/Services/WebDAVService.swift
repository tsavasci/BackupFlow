
import Foundation
import FilesProvider
import OSLog
import Combine
@preconcurrency import Photos
import Network
import UIKit

@MainActor
final class WebDAVService: NSObject, FileProviderDelegate {
    // MARK: - Properties
    static let shared = WebDAVService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "WebDAVService")
    private let fileManager = FileManager.default
    private let temporaryExportRootName = "backupflow_exports"
    private let photoLibraryManager = PhotoLibraryManager.shared
    private var webdavProvider: WebDAVFileProvider?
    private var currentBaseURL: URL?
    private var currentCredential: URLCredential?
    /// Set for the duration of a backup whose task requires Wi-Fi.
    private var uploadsRequireWiFi = false
    private let backgroundTaskCoordinator = WebDAVBackgroundTaskCoordinator()
    private var isPerformingBackup = false
    private var ensuredRemoteDirectories: Set<String> = []
    private var pendingFinishEventsWorkItem: DispatchWorkItem?
    private var backgroundURLSession: URLSession?
    private var backgroundURLSessionCompletionHandler: (() -> Void)?
    private var currentUploadTask: URLSessionTask?
    private var backgroundUploadContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var backgroundUploadFileSizes: [Int: Int64] = [:]
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
            if self?.isPerformingBackup == true, UIApplication.shared.applicationState != .active {
                self?.backgroundTaskCoordinator.begin()
            }
            if let error = error {
                self?.lastError = error
                self?.logger.error("🌐 Background upload failed: \(error.localizedDescription)")
                self?.finishBackgroundUpload(task: task, result: .failure(WebDAVErrorMapper.mapError(error)))
            } else {
                self?.logger.info("🌐 Background upload completed: \(task.taskDescription ?? "")")
                if let response = task.response as? HTTPURLResponse,
                   !(200...299).contains(response.statusCode) {
                    let error = NSError(
                        domain: "WebDAVService",
                        code: response.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "error.webdav.upload_failed_http".localized(with: response.statusCode)]
                    )
                    self?.finishBackgroundUpload(task: task, result: .failure(WebDAVErrorMapper.mapError(error)))
                } else {
                    self?.finishBackgroundUpload(task: task, result: .success(()))
                }
            }
        },
        onFinishEvents: { [weak self] in
            self?.handleBackgroundSessionDidFinishEvents()
        }
    )
    private let lock = NSLock()
    private var lastLoggedNetworkStatus: NWPath.Status?
    
    // Background session state tracking
    @Published private(set) var isBackgroundUploading = false

    @MainActor
    func updateBackgroundMode(isBackground: Bool) {
        guard isBackground else {
            backgroundTaskCoordinator.end()
            self.isBackgroundUploading = false
            self.logger.info("📱 Foreground upload mode enabled")
            return
        }
        if isPerformingBackup || !backgroundUploadContinuations.isEmpty {
            backgroundTaskCoordinator.begin()
        }
        self.isBackgroundUploading = true
        // Not resetting progress/currentFile here to preserve UI continuity across foreground/background
        self.logger.info("📱 Background upload mode enabled")
    }

    private func handleBackgroundSessionDidFinishEvents() {
        // Because sequential uploads enqueue the next file right after the previous continuation
        // resumes (after exporting the next photo/video asset to tmp), calling the system completion
        // handler too early would let iOS suspend the app while a multi-GB video is still exporting
        // to disk before the next uploadTask is created. Hold the background assertion and flush
        // either when the next uploadTask starts, when the backup finishes, or after a generous safety window.
        if isPerformingBackup {
            if UIApplication.shared.applicationState != .active {
                backgroundTaskCoordinator.begin()
            }
            scheduleBackgroundSessionCompletionFlush(after: 180.0)
        } else {
            flushBackgroundURLSessionCompletionHandler()
        }
    }

    private func scheduleBackgroundSessionCompletionFlush(after delay: TimeInterval) {
        pendingFinishEventsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.flushBackgroundURLSessionCompletionHandler()
            }
        }
        pendingFinishEventsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func flushBackgroundURLSessionCompletionHandler() {
        pendingFinishEventsWorkItem?.cancel()
        pendingFinishEventsWorkItem = nil
        if let completionHandler = backgroundURLSessionCompletionHandler {
            backgroundURLSessionCompletionHandler = nil
            completionHandler()
        }
    }

    @MainActor
    func shouldUseBackgroundUploadSession(allowBackgroundSession: Bool) -> Bool {
        let appInBackground = UIApplication.shared.applicationState != .active
        return allowBackgroundSession && (isBackgroundUploading || appInBackground) && backgroundURLSession != nil
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
            try throwIfCancelled()
            do { return try await operation() } catch {
                lastError = error
                // A failure caused by the user's cancel must surface as a cancellation.
                try throwIfCancelled()
                if !config.shouldRetry(error: error) {
                    throw WebDAVErrorMapper.mapError(error)
                }
                if attempt < attempts {
                    let delay = config.delayForAttempt(attempt)
                    if isVerboseLoggingEnabled {
                        self.logger.warning("Retryable error on attempt \(attempt)/\(attempts): \(error.localizedDescription). Waiting \(String(format: "%.2f", delay))s before retry...")
                    }
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw WebDAVErrorMapper.mapError(lastError ?? NSError(domain: "WebDAVService", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.unknown_after_retries".localized]))
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
        config.timeoutIntervalForRequest = 300.0
        config.timeoutIntervalForResource = 7200.0  // Çoklu GB boyutundaki (ör. 2.4+ GB) videolar için 2 saat timeout
        config.httpMaximumConnectionsPerHost = 1
        
        // Resume desteği: Kısmi yüklemeler için HTTP 1.1 range requests
        config.allowsCellularAccess = true
        config.waitsForConnectivity = true  // WiFi bağlantısının gelmesini bekle
        
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
                userInfo: [NSLocalizedDescriptionKey: "error.network.local_permission_required".localized]
            )
        }
    }
    
    // MARK: - Connection & File Operations
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
            let error = NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.webdav.provider_create_failed".localized])
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
            try await self.verifyConnection(using: provider)
        }
    }

    /// Lists "/" once to check that the server accepts the connection and credentials.
    /// On failure the provider is dropped and the error explains what to check.
    private func verifyConnection(using provider: WebDAVFileProvider) async throws {
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
                    let detailedError = self.connectionTestError(from: error)
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

    /// Turns a failed connection test into an error whose message says what to check
    /// (address, credentials, certificate, WebDAV path), keeping the original as underlying error.
    private func connectionTestError(from error: Error) -> NSError {
        var errorMessage = "Could not connect to server."
        var errorCode = -1

        // FilesProvider reports HTTP failures as FileProviderHTTPError; a 401/403
        // is a credentials problem, not "could not connect".
        if let httpError = error as? FileProviderHTTPError,
           [401, 403].contains(httpError.code.rawValue) {
            errorCode = httpError.code.rawValue
            errorMessage = "backup.error.authentication_failed".localized
        } else if let nsError = error as NSError? {
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

        return NSError(
            domain: "WebDAVError",
            code: errorCode,
            userInfo: [
                NSLocalizedDescriptionKey: errorMessage,
                NSUnderlyingErrorKey: error
            ]
        )
    }
    
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler, allowBackgroundSession: true)
    }
    
    /// Sync engine gibi "başarılı" sayılmadan önce gerçek tamamlanma bekleyen akışlar için.
    func uploadFileAwaitingCompletion(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler, allowBackgroundSession: true, timeoutMultiplier: 1.0)
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
        let useBackgroundSession = shouldUseBackgroundUploadSession(allowBackgroundSession: allowBackgroundSession)
        
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
        // Video-heavy uploads on slow links need wider timeout budget (up to 2 hours for multi-GB videos).
        return min(7200, max(120, base + (fileSizeMB * perMB)))
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
        // The sessions allow cellular; a Wi-Fi-only task narrows each upload to Wi-Fi,
        // so a dropped Wi-Fi pauses the transfer instead of moving it to cellular.
        request.allowsCellularAccess = !uploadsRequireWiFi

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
        // Ensure parent directory exists before foreground upload
        let parentPath_fg = (remotePath as NSString).deletingLastPathComponent
        if !parentPath_fg.isEmpty && parentPath_fg != "/" {
            try await ensureDirectoryExists(at: parentPath_fg)
        }

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
                Task { @MainActor in
                    self.currentUploadTask = nil
                }
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
                            userInfo: [NSLocalizedDescriptionKey: "error.webdav.upload_failed_http".localized(with: response.statusCode)]
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
            configuration.timeoutIntervalForRequest = 300
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
        // Ensure parent directory exists before enqueuing background upload
        let parentPath_bg = (remotePath as NSString).deletingLastPathComponent
        if !parentPath_bg.isEmpty && parentPath_bg != "/" {
            try await ensureDirectoryExists(at: parentPath_bg)
        }

        guard let session = backgroundURLSession else {
            throw BackupServiceError.connectionFailed
        }
        let request = try makeUploadRequest(remotePath: remotePath)

        // Set current file for UI feedback
        self.currentFile = localURL.lastPathComponent
        prepareCurrentUpload(localURL: localURL, progressHandler: progressHandler)
        self.logger.info("🌐 Enqueuing background PUT upload: \(request.url?.absoluteString ?? remotePath)")

        if UIApplication.shared.applicationState != .active {
            backgroundTaskCoordinator.begin()
        }

        let uploadURL = try stageForBackgroundUpload(localURL)
        defer {
            if uploadURL != localURL { try? fileManager.removeItem(at: uploadURL) }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Enqueue background upload task from file (no in-memory buffering)
            let task = session.uploadTask(with: request, fromFile: uploadURL)
            self.currentUploadTask = task
            self.backgroundUploadContinuations[task.taskIdentifier] = continuation
            self.backgroundUploadFileSizes[task.taskIdentifier] = currentFileTotalBytes

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
            self.flushBackgroundURLSessionCompletionHandler()

            // Best-effort initial progress callback
            progressHandler?(0.0)
        }
    }

    /// The background upload daemon cannot read security-scoped files (File Provider
    /// folders) or files with complete protection, so hand it a copy in our own tmp.
    private func stageForBackgroundUpload(_ localURL: URL) throws -> URL {
        let tempRoot = fileManager.temporaryDirectory.standardizedFileURL.path
        if localURL.standardizedFileURL.path.hasPrefix(tempRoot) {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: localURL.path
            )
            return localURL
        }

        let stagingDir = fileManager.temporaryDirectory
            .appendingPathComponent("backupflow-webdav-upload", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let stagedURL = stagingDir.appendingPathComponent("\(UUID().uuidString)-\(localURL.lastPathComponent)")
        try fileManager.copyItem(at: localURL, to: stagedURL)
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: stagedURL.path
        )
        return stagedURL
    }

    private func finishBackgroundUpload(task: URLSessionTask, result: Result<Void, Error>) {
        if currentUploadTask === task {
            currentUploadTask = nil
        }
        let taskIdentifier = task.taskIdentifier
        guard let continuation = backgroundUploadContinuations.removeValue(forKey: taskIdentifier) else {
            return
        }

        let fileSize = backgroundUploadFileSizes.removeValue(forKey: taskIdentifier) ?? currentFileTotalBytes
        switch result {
        case .success:
            updateCurrentUploadProgress(progress: 1.0, bytesSent: fileSize, totalBytes: fileSize)
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    /// Set by `cancelCurrentTask()` and checked between files. Cancelling the in-flight
    /// upload alone isn't enough: the sync loops would move on to the next file, and
    /// could still reach the orphan-deletion phase.
    private var isCancelled = false

    private func throwIfCancelled() throws {
        if isCancelled { throw BackupServiceError.cancelled }
    }

    func cancelCurrentTask() {
        logger.info("WebDAV işlemi iptal ediliyor...")
        isCancelled = true
        currentUploadTask?.cancel()
        currentUploadTask = nil
        for (_, continuation) in backgroundUploadContinuations {
            continuation.resume(throwing: BackupServiceError.cancelled)
        }
        backgroundUploadContinuations.removeAll()
        backgroundUploadFileSizes.removeAll()
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
        options: BackupExecutionOptions = .defaults,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (filesUploaded: Int, filesSkipped: Int, filesFailed: Int, bytesTransferred: Int64, deletedFiles: Int, verifiedFiles: Int) {
        let engine = try makeSyncEngine()
        return try await engine.syncUploadDirectory(
            localPath: localPath,
            remoteBasePath: remoteBasePath,
            options: options,
            progressHandler: progressHandler
        )
    }

    private func listAllRemoteFiles(at path: String, relativeTo basePath: String = "") async throws -> [String: FileObject] {
        var allFiles: [String: FileObject] = [:]
        let files = try await listDirectory(at: path)

        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            if BackupArchive.isReserved(relativePath: relativePath) {
                continue
            }
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
        options: BackupExecutionOptions = .defaults,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> FTPService.SyncResult {
        if !options.isDryRun {
            try await ensureDirectoryExists(at: remoteBasePath)
        }

        let assets = try await photoLibraryManager.getAllAssets(mediaType: mediaType)
        var result = FTPService.SyncResult()

        guard !assets.isEmpty else {
            progressHandler(1.0)
            return result
        }

        let existingFileMap = try await listAllRemoteFiles(at: remoteBasePath)
        let processedRelativePaths = Set(assets.map { photoLibraryManager.generateFileName(for: $0) })

        try fileManager.createDirectory(at: exportRootURL(), withIntermediateDirectories: true)

        let firstPass = try await uploadPhotoAssets(
            assets,
            to: remoteBasePath,
            existingFileMap: existingFileMap,
            includeICloudAssets: includeICloudAssets,
            options: options,
            progressHandler: progressHandler,
            result: &result
        )
        var failedUploads = firstPass.failedCount
        if !options.isDryRun && !firstPass.timedOut.isEmpty {
            failedUploads += try await retryTimedOutPhotoUploads(
                firstPass.timedOut,
                existingFileMap: existingFileMap,
                includeICloudAssets: includeICloudAssets,
                options: options,
                result: &result
            )
        }

        let canDeletePhotoOrphans = failedUploads == 0 && options.permitsPhotoOrphanDeletion(
            hasFullLibraryAccess: photoLibraryManager.hasFullLibraryAccess,
            visibleAssetCount: assets.count
        )
        if !canDeletePhotoOrphans && options.deletionPolicy == .mirror {
            logger.warning("Skipping orphan photo deletion because the source snapshot is unsafe or one or more uploads failed.")
        }

        let orphans = existingFileMap.keys
            .filter { !processedRelativePaths.contains($0) && !BackupArchive.isReserved(relativePath: $0) }
            .map { relativePath in
                PhotoOrphanCleanup.Orphan(
                    relativePath: relativePath,
                    fullRemotePath: BackupArchive.safeRemotePath(basePath: remoteBasePath, relativePath: relativePath)
                )
            }
        result.deletedFiles += try await PhotoOrphanCleanup.apply(
            to: orphans,
            basePath: remoteBasePath,
            options: options,
            canDelete: canDeletePhotoOrphans,
            logger: logger,
            isCancelled: { self.isCancelled },
            deleteFile: { try await self.deleteFile(at: $0) },
            archiveFile: { try await self.archiveFile(from: $0, to: $1) }
        )

        removeExportRootIfEmpty()

        if failedUploads > 0 {
            logger.warning("⚠️ Photo sync completed with \(failedUploads) failed/timeouted uploads")
            progressHandler(1.0)
            throw BackupServiceError.fileOperationFailed
        }

        progressHandler(1.0)
        return result
    }

    /// A photo whose upload timed out in the first pass, kept for one more try.
    private struct PendingPhotoUpload {
        let asset: PHAsset
        let fileName: String
        let remotePath: String
    }

    /// First pass over the library: uploads new and changed photos and skips those already
    /// on the server at the same size. Covers the first 80% of the reported progress.
    /// - Returns: Uploads that timed out (to retry) and how many others failed.
    private func uploadPhotoAssets(
        _ assets: [PHAsset],
        to remoteBasePath: String,
        existingFileMap: [String: FileObject],
        includeICloudAssets: Bool,
        options: BackupExecutionOptions,
        progressHandler: @escaping (Double) -> Void,
        result: inout FTPService.SyncResult
    ) async throws -> (timedOut: [PendingPhotoUpload], failedCount: Int) {
        var timedOutUploads: [PendingPhotoUpload] = []
        var failedUploads = 0
        let totalAssets = assets.count
        var lastHeartbeatAt = Date()

        func reportProgress(afterAsset index: Int) {
            progressHandler(Double(index + 1) / Double(max(totalAssets, 1)) * 0.8)
        }

        for (index, asset) in assets.enumerated() {
            try throwIfCancelled()
            // Logger can't capture the inout `result`; log from a copy.
            let counts = result
            if index == 0 || (index + 1).isMultiple(of: 10) {
                logger.info("📷 WebDAV photo sync progress: \(index + 1)/\(totalAssets) (uploaded: \(counts.newFiles + counts.updatedFiles), skipped: \(counts.skippedFiles), iCloud-only: \(counts.iCloudSkippedFiles), timeout: \(counts.timedOutAssetReads), unreadable: \(counts.failedAssetReads))")
            }
            if Date().timeIntervalSince(lastHeartbeatAt) >= 30 {
                logger.info("⏳ WebDAV photo sync heartbeat: processed \(index)/\(totalAssets), transferred \(counts.totalBytes) bytes")
                lastHeartbeatAt = Date()
            }

            let fileName = photoLibraryManager.generateFileName(for: asset)
            let remotePath = remoteBasePath == "/" ? "/\(fileName)" : "\(remoteBasePath)/\(fileName)"

            // Photo filenames embed creation timestamp + PHAsset UUID prefix, so a non-empty
            // remote file with the same name is already backed up. Skipping before querying
            // PHAssetResource or exporting avoids main-thread PhotoKit XPC stalls and disk I/O.
            if let remoteFile = existingFileMap[fileName], remoteFile.size > 0 {
                result.skippedFiles += 1
                result.totalBytes += remoteFile.size
                logger.debug("⏭️ Upload fast-skipped (\(index + 1)/\(totalAssets)): \(fileName) (\(remoteFile.size) bytes)")
                reportProgress(afterAsset: index)
                continue
            }

            if UIApplication.shared.applicationState != .active {
                backgroundTaskCoordinator.begin()
            }

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
                reportProgress(afterAsset: index)
                continue
            case .timedOut:
                result.timedOutAssetReads += 1
                reportProgress(afterAsset: index)
                continue
            case .unavailable:
                result.failedAssetReads += 1
                reportProgress(afterAsset: index)
                continue
            }
            defer { try? fileManager.removeItem(at: tempURL) }

            if let remoteFile = existingFileMap[fileName], remoteFile.size == localSize {
                result.skippedFiles += 1
                result.totalBytes += localSize
                logger.debug("⏭️ Upload skipped (\(index + 1)/\(totalAssets)): \(fileName) (\(localSize) bytes)")
                reportProgress(afterAsset: index)
                continue
            }

            do {
                logger.info("⬆️ Upload starting (\(index + 1)/\(totalAssets)): \(fileName) (\(localSize) bytes)")
                if !options.isDryRun {
                    try await uploadFileAwaitingCompletion(localURL: tempURL, remotePath: remotePath) { fileProgress in
                        let assetShare = 0.8 / Double(max(totalAssets, 1))
                        let overallProgress = (Double(index) / Double(max(totalAssets, 1)) * 0.8) + (fileProgress * assetShare)
                        progressHandler(min(max(overallProgress, 0.0), 0.8))
                    }
                    if options.checksumMode == .verifyUploads {
                        try await verifyUploadChecksum(localURL: tempURL, remotePath: remotePath)
                        result.verifiedFiles += 1
                    }
                }
                logger.info("✅ Upload completed (\(index + 1)/\(totalAssets)): \(fileName)")
            } catch {
                if isUploadTimeoutError(error) {
                    timedOutUploads.append(PendingPhotoUpload(asset: asset, fileName: fileName, remotePath: remotePath))
                    logger.warning("⏱️ Upload timeout queued for retry: \(fileName)")
                } else {
                    failedUploads += 1
                    logger.error("Upload failed (continuing): \(fileName) - \(error.localizedDescription)")
                }
                reportProgress(afterAsset: index)
                continue
            }

            if existingFileMap[fileName] != nil {
                result.updatedFiles += 1
            } else {
                result.newFiles += 1
            }
            result.totalBytes += localSize
            BackupRunTally.shared.recordUpload(bytes: localSize)
            reportProgress(afterAsset: index)
        }

        return (timedOutUploads, failedUploads)
    }

    /// Second pass for uploads that timed out: exports each photo again and uploads it
    /// in the foreground with a longer timeout.
    /// - Returns: How many of them still failed.
    private func retryTimedOutPhotoUploads(
        _ uploads: [PendingPhotoUpload],
        existingFileMap: [String: FileObject],
        includeICloudAssets: Bool,
        options: BackupExecutionOptions,
        result: inout FTPService.SyncResult
    ) async throws -> Int {
        logger.info("🔁 Retrying timed out uploads: \(uploads.count)")
        var failedUploads = 0

        for item in uploads {
            try throwIfCancelled()
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
                    allowBackgroundSession: true,
                    timeoutMultiplier: 2.5
                )
                if options.checksumMode == .verifyUploads {
                    try await verifyUploadChecksum(localURL: retryTempURL, remotePath: item.remotePath)
                    result.verifiedFiles += 1
                }
                if existingFileMap[item.fileName] != nil {
                    result.updatedFiles += 1
                } else {
                    result.newFiles += 1
                }
                result.totalBytes += retrySize
                BackupRunTally.shared.recordUpload(bytes: retrySize)
            } catch {
                failedUploads += 1
                logger.error("Retry failed: \(item.fileName) - \(error.localizedDescription)")
            }
        }

        return failedUploads
    }

    /// Removes the temporary export folder once every exported photo has been cleaned up.
    private func removeExportRootIfEmpty() {
        if let remaining = try? fileManager.contentsOfDirectory(
            at: exportRootURL(),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ), remaining.isEmpty {
            try? fileManager.removeItem(at: exportRootURL())
        }
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
        ensuredRemoteDirectories.removeAll()
        backgroundTaskCoordinator.end()
        // Do not reset progress/currentFile here to avoid UI resets during transient reconnects
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
            
            guard webdavProvider != nil else { 
                self.logger.error("Connection test failed: WebDAV provider could not be initialized")
                return false 
            }
            
            self.logger.info("Successfully connected and listed root directory. Checking write permissions...")
            
            // Test file upload using direct PUT (avoids FilesProvider's 3-step parent PROPFIND + MKCOL + PUT hang on subpath WebDAV servers)
            let testFileName = "backupflow_test_\(UUID().uuidString.prefix(8)).txt"
            let testFilePath = "/\(testFileName)"
            let testContent = "BackupFlow test file".data(using: .utf8)!
            
            self.logger.info("Testing file upload to root directory...")
            do {
                let tempURL = fileManager.temporaryDirectory.appendingPathComponent(testFileName)
                try testContent.write(to: tempURL, options: .atomic)
                defer { try? fileManager.removeItem(at: tempURL) }

                let putRequest = try makeUploadRequest(remotePath: testFilePath)
                let (_, response) = try await URLSession.shared.upload(for: putRequest, fromFile: tempURL)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    throw NSError(
                        domain: "WebDAVService",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "error.webdav.upload_failed_http".localized(with: httpResponse.statusCode)]
                    )
                }
                self.logger.info("File upload successful")

                // Clean up the test file
                if let baseURL = currentBaseURL {
                    var deleteRequest = URLRequest(url: baseURL.appendingPathComponent(testFileName))
                    deleteRequest.httpMethod = "DELETE"
                    if let authHeader = putRequest.value(forHTTPHeaderField: "Authorization") {
                        deleteRequest.setValue(authHeader, forHTTPHeaderField: "Authorization")
                    }
                    _ = try? await URLSession.shared.data(for: deleteRequest)
                }
                
                self.logger.info("WebDAV connection test completed successfully!")
                return true
                
            } catch {
                // If file upload fails, still consider it a success if we could connect and list the directory
                self.logger.warning("File upload test failed, but connection was established. This might be due to read-only access.")
                return true
            }
            
        } catch {
            self.lastError = error
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
    private func normalizedRemoteDirectoryKey(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "/" : "/\(trimmed)"
    }

    private func ensureDirectoryExists(at path: String) async throws {
        let normalizedKey = normalizedRemoteDirectoryKey(path)
        guard normalizedKey != "/" else { return }
        if ensuredRemoteDirectories.contains(normalizedKey) {
            return
        }
        guard let provider = webdavProvider else {
            throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.webdav.provider_unavailable".localized])
        }
        let ops = WebDAVFileOperations(provider: provider)
        try await ops.ensureDirectoryExists(at: path, logger: logger)

        var current = ""
        for component in normalizedKey.split(separator: "/") {
            current += "/\(component)"
            ensuredRemoteDirectories.insert(current)
        }
    }

    private func makeSyncEngine() throws -> WebDAVSyncEngine {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        return WebDAVSyncEngine(
            provider: provider,
            fileManager: fileManager,
            logger: logger,
            ensureDirectoryExists: { [weak self] path in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.ensureDirectoryExists(at: path)
            },
            deleteFile: { [weak self] path in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.deleteFile(at: path)
            },
            archiveFile: { [weak self] sourcePath, destinationPath in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.archiveFile(from: sourcePath, to: destinationPath)
            },
            setCurrentFile: { [weak self] name in
                self?.currentFile = name
            },
            isCancelled: { [weak self] in
                self?.isCancelled ?? true
            },
            uploadFile: { [weak self] localURL, remotePath, progressHandler in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.uploadFileAwaitingCompletion(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
            },
            verifyUpload: { [weak self] localURL, remotePath in
                guard let self else { throw BackupServiceError.connectionFailed }
                try await self.verifyUploadChecksum(localURL: localURL, remotePath: remotePath)
            }
        )
    }

    private func verifyUploadChecksum(localURL: URL, remotePath: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }

        let temporaryURL = fileManager.temporaryDirectory
            .appendingPathComponent("backupflow-verify-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.copyItem(path: remotePath, toLocalURL: temporaryURL) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        let localChecksum = try BackupChecksum.sha256(of: localURL)
        let remoteChecksum = try BackupChecksum.sha256(of: temporaryURL)
        guard localChecksum == remoteChecksum else {
            throw BackupIntegrityError.checksumMismatch(path: remotePath)
        }
    }

    private func archiveFile(from sourcePath: String, to destinationPath: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        let parentPath = (destinationPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != "/" {
            try await ensureDirectoryExists(at: parentPath)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.moveItem(path: sourcePath, to: destinationPath, overwrite: false) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Backup Implementation
    func performBackup(
        host: String,
        port: Int,
        username: String?,
        password: String?,
        sourcePath: String,
        destinationPath: String = "/",
        isAnonymous: Bool,
        mediaType: MediaType,
        includeICloudAssets: Bool = true,
        options: BackupExecutionOptions = .defaults,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> FTPService.SyncResult {
        isCancelled = false
        isPerformingBackup = true
        uploadsRequireWiFi = options.requiresWiFi
        ensuredRemoteDirectories.removeAll()
        backgroundTaskCoordinator.onExpiration = { [weak self] in
            self?.logger.info("WebDAV UIKit background assertion expired; background URLSession and BGTask continue uninterrupted")
        }
        if UIApplication.shared.applicationState != .active && !options.isDryRun {
            backgroundTaskCoordinator.begin()
            self.isBackgroundUploading = true
        }
        defer {
            isPerformingBackup = false
            currentUploadTask = nil
            uploadsRequireWiFi = false
            ensuredRemoteDirectories.removeAll()
            backgroundTaskCoordinator.end()
            flushBackgroundURLSessionCompletionHandler()
        }
        self.logger.info("Starting backup: \(host):\(port)")
        if sourcePath == "PHOTOS_LIBRARY" {
            self.logger.info("Media type: \(mediaType == .photosOnly ? "Photos only" : "Photos and Videos")")
        } else {
            self.logger.info("Media type: Directory backup")
        }
        
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.logger.debug("Backup - Initial host: '\(cleanHost)'")
        
        // Establish connection preserving scheme and WebDAV path (e.g., https://example.com/webdav)
        self.logger.info("Backup - Connecting to WebDAV server...")
        let requestedConnection = try WebDAVConnectionBuilder.build(host: cleanHost, port: port)
        if !self.isConnected || self.currentBaseURL != requestedConnection.url {
            try await connect(host: cleanHost, port: port, username: username, password: password)
        } else {
            self.logger.info("Backup - Reusing existing WebDAV connection")
        }
        
        guard webdavProvider != nil else {
            throw NSError(domain: "WebDAVError", code: -1, userInfo: [NSLocalizedDescriptionKey: "error.webdav.provider_unavailable".localized])
        }
        
        var result = FTPService.SyncResult()
        
        let trimmedDest = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDest: String = {
            if trimmedDest.isEmpty || trimmedDest == "/" || trimmedDest == BackupFormModel.legacyDefaultWebDAVPath {
                return "/"
            }
            var p = trimmedDest.hasPrefix("/") ? trimmedDest : "/\(trimmedDest)"
            while p.count > 1 && p.hasSuffix("/") {
                p.removeLast()
            }
            // If destinationPath matches the path already embedded in the WebDAV URL, don't duplicate it
            let basePath = requestedConnection.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let destStripped = p.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !basePath.isEmpty && basePath == destStripped {
                return "/"
            }
            return p
        }()
        
        if sourcePath == "PHOTOS_LIBRARY" {
            self.logger.info("Backing up photo library...")
            // Mirror to a fixed 'photos' directory (no timestamp), with skip/update + orphan delete
            let remoteRoot = normalizedDest
            let remotePhotosBase = remoteRoot.hasSuffix("/") ? remoteRoot + "photos" : remoteRoot + "/photos"
            result = try await syncBackupPhotoLibraryDirect(
                remoteBasePath: remotePhotosBase,
                mediaType: mediaType,
                includeICloudAssets: includeICloudAssets,
                options: options,
                progressHandler: progressHandler
            )
            if !options.isDryRun {
                try await uploadManifest(syncResult: result, remoteBasePath: remotePhotosBase, options: options)
            }
            self.logger.info("Successfully synced photos to WebDAV (uploaded: \(result.newFiles), updated: \(result.updatedFiles), skipped: \(result.skippedFiles), iCloud-skipped: \(result.iCloudSkippedFiles), timeouts: \(result.timedOutAssetReads), unreadable: \(result.failedAssetReads), deleted: \(result.deletedFiles))")
        } else {
            // Directory mirror - preserve source folder name
            self.logger.info("Backing up directory (mirror): \(sourcePath)")
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let sourceFolderName = sourceURL.lastPathComponent
            let remoteRoot = normalizedDest
            let remoteDocumentsBase = remoteRoot == "/" ? "/\(sourceFolderName)" : "\(remoteRoot)/\(sourceFolderName)"
            if !options.isDryRun {
                try await ensureDirectoryExists(at: remoteDocumentsBase)
            }
            let sync = try await syncUploadDirectory(
                localPath: sourcePath,
                remoteBasePath: remoteDocumentsBase,
                options: options,
                progressHandler: progressHandler
            )
            result.newFiles = sync.filesUploaded
            result.skippedFiles = sync.filesSkipped
            result.deletedFiles = sync.deletedFiles
            result.verifiedFiles = sync.verifiedFiles
            result.totalBytes = sync.bytesTransferred
            if sync.filesFailed > 0 {
                logger.error("WebDAV directory sync failed for \(sync.filesFailed) file(s)")
                throw BackupServiceError.fileOperationFailed
            }
            if !options.isDryRun {
                try await uploadManifest(syncResult: result, remoteBasePath: remoteDocumentsBase, options: options)
            }
            self.logger.info("Successfully synced directory to WebDAV: \(sourceFolderName)/ (uploaded: \(sync.filesUploaded), skipped: \(sync.filesSkipped), deleted: \(sync.deletedFiles))")
        }
        
        return result
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
        try await uploadFileAwaitingCompletion(localURL: url, remotePath: remotePath, progressHandler: nil)
    }
}

private final class WebDAVBackgroundTaskCoordinator {
    private let lock = NSLock()
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    var onExpiration: (() -> Void)?

    func begin() {
        lock.lock()
        endLocked()
        startTaskLocked()
        lock.unlock()
    }

    func end() {
        lock.lock()
        endLocked()
        lock.unlock()
    }

    private func handleExpiration() {
        end()
        if Thread.isMainThread {
            onExpiration?()
        } else {
            DispatchQueue.main.async { [onExpiration] in
                onExpiration?()
            }
        }
    }

    private func startTaskLocked() {
        let newID = UIApplication.shared.beginBackgroundTask(withName: "WebDAVFileTransfer") { [weak self] in
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
}
