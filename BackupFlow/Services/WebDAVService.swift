import Foundation
import FilesProvider
import OSLog
import Combine
import Photos
import AVFoundation

// Define FileProviderError if not provided by the FilesProvider framework
enum FileProviderError: Error, Equatable {
    case authenticationRequired
    case serverError
    case fileNotFound
    case permissionDenied
    case unknown(Error)
    
    static func == (lhs: FileProviderError, rhs: FileProviderError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationRequired, .authenticationRequired),
             (.serverError, .serverError),
             (.fileNotFound, .fileNotFound),
             (.permissionDenied, .permissionDenied):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}

@MainActor
final class WebDAVService: NSObject, BackupServiceProtocol, FileProviderDelegate, URLSessionDelegate, URLSessionTaskDelegate {
    // MARK: - Properties
    static let shared = WebDAVService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "WebDAVService")
    private let fileManager = FileManager.default
    private let photoLibraryManager = PhotoLibraryManager.shared
    
    private var webdavProvider: WebDAVFileProvider?
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()
    
    @Published private(set) var isConnected = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    private(set) var lastError: Error?
    
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
        self.logger.debug("Progress: \(operation.description) - \(percent)%")
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Error Handling
    private func mapError(_ error: Error) -> Error {
        let nsError = error as NSError
        
        // First try to handle as a FileProvider error
        if let fpError = error as? FileProviderError {
            switch fpError {
            case .authenticationRequired:
                return BackupServiceError.authenticationFailed
            case .serverError, .fileNotFound, .permissionDenied:
                return BackupServiceError.connectionFailed
            case .unknown(let underlyingError):
                return BackupServiceError.unknown(underlyingError)
            }
        }
        // Then try to handle as a URL error
        else if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorBadURL,
                 NSURLErrorUnsupportedURL:
                return BackupServiceError.connectionFailed
            case NSURLErrorUserAuthenticationRequired,
                 NSURLErrorUserCancelledAuthentication:
                return BackupServiceError.authenticationFailed
            case NSURLErrorCannotCreateFile,
                 NSURLErrorCannotOpenFile,
                 NSURLErrorCannotWriteToFile:
                return BackupServiceError.fileOperationFailed
            default:
                return BackupServiceError.unknown(error)
            }
        }
        // For any other error, wrap it in an unknown error
        else {
            return BackupServiceError.unknown(error)
        }
    }
    
    // MARK: - BackupServiceProtocol
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        self.logger.info("Starting WebDAV connection: \(host):\(port)")
        
        // Clean and validate the host string
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var webdavPath = "/webdav" // Default WebDAV path
        
        self.logger.debug("Initial host: '\(host)'")
        
        // Extract WebDAV path if present (e.g., example.com/webdav)
        if let pathRange = cleanHost.range(of: "/") {
            webdavPath = String(cleanHost[pathRange.lowerBound...])
            cleanHost = String(cleanHost[..<pathRange.lowerBound])
            self.logger.info("Extracted WebDAV path: '\(webdavPath)'")
            self.logger.debug("Cleaned host: '\(cleanHost)'")
        } else {
            self.logger.info("Using default WebDAV path: '\(webdavPath)'")
        }
        
        // Remove any URL scheme if present
        if let schemeRange = cleanHost.range(of: "://") {
            cleanHost = String(cleanHost[schemeRange.upperBound...])
            self.logger.debug("Removed URL scheme, new host: '\(cleanHost)'")
        }
        
        // Remove any trailing slashes from host
        cleanHost = cleanHost.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.logger.debug("Removed trailing slashes, final host: '\(cleanHost)'")
        
        // Validate host format
        guard !cleanHost.isEmpty else {
            let error = NSError(
                domain: "WebDAVError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid server address. Please enter a valid address."]
            )
            self.logger.error("\(error.localizedDescription)")
            throw error
        }
        
        // Determine the appropriate scheme (http/https) based on port
        let useHTTPS = (port == 443 || port == 8443 || port == 4433 || port == 4430)
        let scheme = useHTTPS ? "https" : "http"
        self.logger.info("Determined scheme: \(scheme) (Port: \(port))")
        
        // Configure URLSession with custom configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 1
        
        // Configure the default URL cache
        URLCache.shared = URLCache(
            memoryCapacity: 0,
            diskCapacity: 0,
            diskPath: nil
        )
        
        // For testing only - configure TLS settings
        #if DEBUG
        if #available(iOS 14.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
            config.tlsMaximumSupportedProtocolVersion = .TLSv13
        } else {
            config.tlsMinimumSupportedProtocol = .tlsProtocol12
            config.tlsMaximumSupportedProtocol = .tlsProtocol13
        }
        #endif
        
        // Build the URL components
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = cleanHost
        
        // Only add port if it's not the default for the scheme
        if (scheme == "http" && port != 80) || (scheme == "https" && port != 443) {
            urlComponents.port = port
        }
        
        // Clean and set the WebDAV path
        var cleanWebDAVPath = webdavPath
        while cleanWebDAVPath.hasPrefix("/") {
            cleanWebDAVPath = String(cleanWebDAVPath.dropFirst())
        }
        
        if !cleanWebDAVPath.isEmpty {
            urlComponents.path = "/" + cleanWebDAVPath
            self.logger.info("Set WebDAV path: '\(urlComponents.path)'")
        } else {
            urlComponents.path = "/"
            self.logger.info("Using root path: '/'")
        }
        
        // Ensure the URL ends with a slash for WebDAV
        if !urlComponents.path.hasSuffix("/") {
            urlComponents.path += "/"
        }
        
        guard let url = urlComponents.url else {
            let error = NSError(
                domain: "WebDAVError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL created. Please check the server address."]
            )
            self.logger.error("\(error.localizedDescription) - \(urlComponents.string ?? "")")
            throw error
        }
        
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
        - Scheme: \(scheme)
        - Host: \(cleanHost)
        - Port: \(port)
        - Path: \(url.path)
        - Timeout: 30s/60s
        - Pipelining: \(config.httpShouldUsePipelining ? "On" : "Off")
        - Max Connections: \(config.httpMaximumConnectionsPerHost)
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
        self.isConnected = false
        
        // Test the connection
        self.logger.info("Testing WebDAV connection...")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.contentsOfDirectory(path: "/") { files, error in
                if let error = error {
                    self.logger.error("Connection test failed: \(error.localizedDescription)")
                    
                    // Provide more specific error information
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
                                // Check if it's an HTTP 405 error (Method Not Allowed)
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
                    continuation.resume(throwing: detailedError)
                } else {
                    self.logger.info("Successfully connected. Found \(files.count) items.")
                    self.isConnected = true
                    continuation.resume()
                }
            }
        }
    }
    
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        
        do {
            let data = try Data(contentsOf: localURL)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                provider.writeContents(path: remotePath, contents: data, atomically: true, overwrite: true) { error in
                    if let error = error {
                        self.lastError = error
                        continuation.resume(throwing: self.mapError(error))
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            self.lastError = error
            throw mapError(error)
        }
    }
    
    func createDirectory(at path: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        
        // Extract the directory name and parent path
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        guard !pathComponents.isEmpty else {
            // If path is empty or just "/", nothing to create
            return
        }
        
        let directoryName = pathComponents.last!
        let parentPath = "/" + pathComponents.dropLast().joined(separator: "/")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.create(folder: directoryName, at: parentPath) { error in
                if let error = error {
                    // If the error is that the directory already exists, we can ignore it
                    if (error as NSError).code != 516 { // 516 is the error code for file already exists
                        self.lastError = error
                        continuation.resume(throwing: self.mapError(error))
                        return
                    }
                }
                continuation.resume()
            }
        }
    }
    
    func listDirectory(at path: String) async throws -> [FileObject] {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileObject], Error>) in
            provider.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    self.lastError = error
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume(returning: files)
                }
            }
        }
    }
    
    func deleteFile(at path: String) async throws {
        guard let provider = webdavProvider else {
            throw BackupServiceError.connectionFailed
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.removeItem(path: path) { error in
                if let error = error {
                    self.lastError = error
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func disconnect() {
        webdavProvider = nil
        isConnected = false
        lastError = nil
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
                provider.contentsOfDirectory(path: "/") { files, error in
                    if let error = error {
                        self.logger.error("Failed to list root directory: \(error.localizedDescription)")
                        if let nsError = error as NSError? {
                            self.logger.error("   - Domain: \(nsError.domain)")
                            self.logger.error("   - Code: \(nsError.code)")
                        }
                        continuation.resume(throwing: error)
                        return
                    }
                    self.logger.info("Successfully listed root directory. Found \(files.count) items.")
                    continuation.resume()
                }
            }
            
            // Test file upload
            let testFileName = "backupflow_test_\(UUID().uuidString.prefix(8)).txt"
            let testFilePath = "/\(testFileName)"
            let testContent = "BackupFlow test file".data(using: .utf8)!
            
            self.logger.info("Testing file upload to root directory...")
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
                            continuation.resume(throwing: error)
                            return
                        }
                        self.logger.info("File upload successful")
                        
                        // Clean up the test file
                        provider.removeItem(path: testFilePath) { _ in }
                        continuation.resume()
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
        
        // Check if directory already exists
        let exists = await withCheckedContinuation { continuation in
            provider.attributesOfItem(path: path) { _, error in
                if error == nil {
                    self.logger.info("Directory already exists: \(path)")
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
        
        // Create directory if it doesn't exist
        if !exists {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var components = path.components(separatedBy: "/").filter { !$0.isEmpty }
                var currentPath = ""
                
                func createNextDirectory() {
                    guard !components.isEmpty else {
                        self.logger.info("All directories created successfully")
                        continuation.resume()
                        return
                    }
                    
                    let component = components.removeFirst()
                    currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                    
                    provider.attributesOfItem(path: currentPath) { _, error in
                        if error == nil {
                            self.logger.info("Directory already exists: \(currentPath)")
                            createNextDirectory()
                        } else {
                            self.logger.info("Creating directory: \(currentPath)")
                            let parentPath = (currentPath as NSString).deletingLastPathComponent
                            let folderName = (currentPath as NSString).lastPathComponent
                            
                            provider.create(folder: folderName, at: parentPath, completionHandler: { error in
                                if let error = error {
                                    self.logger.error("Could not create directory: \(currentPath) - \(error.localizedDescription)")
                                    continuation.resume(throwing: error)
                                } else {
                                    self.logger.info("Directory created successfully: \(currentPath)")
                                    createNextDirectory()
                                }
                            })
                        }
                    }
                }
                
                createNextDirectory()
            }
        }
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
        let fetchResult: PHFetchResult<PHAsset>
        
        switch mediaType {
        case .photosOnly: 
            fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        case .videosOnly: 
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
            
            let resource = PHAssetResource.assetResources(for: asset).first
            let originalFilename = resource?.originalFilename ?? "\(Int(Date().timeIntervalSince1970))"
            let ext = URL(fileURLWithPath: originalFilename).pathExtension.lowercased()
            let uniqueFilename = "\(UUID().uuidString).\(ext)"
            let fileURL = destination.appendingPathComponent(uniqueFilename)
            
            if fileManager.fileExists(atPath: fileURL.path) { 
                saved += 1
                continue 
            }
            
            if asset.mediaType == .image {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    imageManager.requestImageDataAndOrientation(for: asset, options: nil) { data, _, _, _ in
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
            } else if asset.mediaType == .video {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let options = PHVideoRequestOptions()
                    options.isNetworkAccessAllowed = true
                    
                    imageManager.requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetHighestQuality) { exportSession, _ in
                        guard let exportSession = exportSession else { 
                            continuation.resume()
                            return 
                        }
                        
                        exportSession.outputURL = fileURL
                        exportSession.outputFileType = .mp4
                        
                        exportSession.exportAsynchronously {
                            if exportSession.status == .completed { 
                                saved += 1 
                            } else if let error = exportSession.error {
                                self.logger.error("Failed to export video: \(error.localizedDescription)")
                            }
                            continuation.resume()
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
        self.logger.info("Media type: \(mediaType == .photosOnly ? "Photos only" : "Photos and Videos")")
        
        // Clean and validate the host string
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var webdavPath = "/"
        
        self.logger.debug("Backup - Initial host: '\(host)'")
        
        // Extract WebDAV path if present (e.g., example.com/webdav)
        if let pathRange = cleanHost.range(of: "/") {
            webdavPath = String(cleanHost[pathRange.lowerBound...])
            cleanHost = String(cleanHost[..<pathRange.lowerBound])
            self.logger.info("Backup - Extracted WebDAV path: '\(webdavPath)'")
            self.logger.debug("Backup - Cleaned host: '\(cleanHost)'")
        }
        
        // Establish connection
        self.logger.info("Backup - Connecting to WebDAV server...")
        try await connect(host: cleanHost, port: port, username: username, password: password)
        
        // Check and create target directory
        let targetPath = webdavPath + "backup/" + Date().ISO8601Format().replacingOccurrences(of: ":", with: "-")
        self.logger.info("Backup - Target directory: \(targetPath)")
        try await ensureDirectoryExists(at: targetPath)
        
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
            
            // Upload the files from temp directory to WebDAV
            let uploadResult = try await uploadDirectory(
                localPath: tempDir.path,
                remotePath: targetPath,
                progressHandler: { p in
                    progressHandler(0.5 + p * 0.5)
                }
            )
            
            result.newFiles = uploadResult.filesUploaded
            result.skippedFiles = uploadResult.filesSkipped + uploadResult.filesFailed
            result.totalBytes = uploadResult.bytesTransferred
            
            if uploadResult.filesFailed > 0 {
                self.logger.error("Failed to upload \(uploadResult.filesFailed) files")
            }
            
            self.logger.info("Successfully uploaded \(uploadResult.filesUploaded) files to WebDAV")
            
        } else {
            // For non-photo library backups
            self.logger.info("Backing up directory: \(sourcePath)")
            let uploadResult = try await uploadDirectory(
                localPath: sourcePath,
                remotePath: targetPath,
                progressHandler: progressHandler
            )
            
            result.newFiles = uploadResult.filesUploaded
            result.skippedFiles = uploadResult.filesSkipped + uploadResult.filesFailed
            result.totalBytes = uploadResult.bytesTransferred
            
            if uploadResult.filesFailed > 0 {
                self.logger.error("Failed to upload \(uploadResult.filesFailed) files")
            }
            
            self.logger.info("Successfully uploaded \(uploadResult.filesUploaded) files to WebDAV")
        }
        
        return result
    }
    }
