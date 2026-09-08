#if canImport(FilesProvider)

import Foundation
import FilesProvider
import OSLog
import Network
import Combine
#if canImport(UIKit)
import UIKit
#endif

// Key objects for associated objects
private struct AssociatedKeys {
    static let progressHandler = NSObject()
    static let isObserving = NSObject()
}

final class FTPService: NSObject, @unchecked Sendable, BackupServiceProtocol {
    static let shared = FTPService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "FTPService")
    private let isVerboseLoggingEnabled = false
#if canImport(UIKit)
    private let backgroundTaskCoordinator = FTPBackgroundTaskCoordinator()
#endif
    
    private func normalizedRemotePath(_ path: String) -> String {
        var p = path.replacingOccurrences(of: "\\", with: "/")
        if !p.hasPrefix("/") { p = "/" + p }
        // Collapse duplicate slashes
        while p.contains("//") { p = p.replacingOccurrences(of: "//", with: "/") }
        return p
    }
    
    // MARK: - BackupServiceProtocol Properties
    @Published private(set) var isConnected = false
    @Published private(set) var networkPermissionGranted = false
    private(set) var lastError: Error?
    
    // FTP uses a foreground URLSession stream internally. These values only describe
    // the current iOS execution window; they do not represent a persistent session.
    @Published private(set) var isBackgroundUploading = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    @Published private(set) var currentFileBytesTransferred: Int64 = 0
    @Published private(set) var currentFileTotalBytes: Int64 = 0
    @Published private(set) var transferSpeedBytesPerSecond: Double = 0
    private var lastProgressSample: (date: Date, bytes: Int64)?
    
    private let networkMonitor = FTPNetworkMonitor()
    private var lastLoggedNetworkStatus: NWPath.Status?
    private var fastPhotoNameSkipEnabled: Bool {
        if UserDefaults.standard.object(forKey: "FTPFastPhotoNameSkipEnabled") == nil {
            // Name-only matching can silently skip a changed photo.
            return false
        }
        return UserDefaults.standard.bool(forKey: "FTPFastPhotoNameSkipEnabled")
    }

    private let lock = NSLock()
    private let cancellationLock = NSLock()
    private var _ftpProvider: FTPFileProvider?
    private var _currentTask: Progress?
    private var _currentTransferID: UUID?
    private var _backgroundExpirationRequested = false

    private var ftpProvider: FTPFileProvider? {
        get { lock.withLock { _ftpProvider } }
        set { lock.withLock { _ftpProvider = newValue } }
    }

    private var currentTask: Progress? {
        get { lock.withLock { _currentTask } }
        set {
            lock.lock()
            _currentTask = newValue
            lock.unlock()
        }
    }

    private var _isCancelled = false
    private var isCancelled: Bool {
        get { cancellationLock.withLock { _isCancelled } }
        set { cancellationLock.withLock { _isCancelled = newValue } }
    }
    private let partialFileMarker = ".backupflow-partial-"
    
    private func maskedURLString(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        if comps.user != nil { comps.user = "***" }
        if comps.password != nil { comps.password = "***" }
        return comps.string ?? url.absoluteString
    }

    override private init() {
        super.init()
        setupNetworkMonitoring()
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
                self.logger.info("FTP: Ağ bağlantısı kullanılabilir")
            } else {
                let statusString = FTPNetworkMonitor.statusString(status)
                self.logger.warning("FTP: Ağ bağlantısı kullanılamıyor: \(statusString)")
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

        self.logger.info("FTP: Ağ izni bekleniyor... (İlk bağlantı için iOS izin isteyebilir)")
        
        // 10 saniye kadar bekle
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 saniye
            
            if networkPermissionGranted {
                self.logger.info("FTP: Ağ izni alındı (\(i). saniyede)")
                return
            }
            
            if i == 5 {
                self.logger.warning("FTP: Ağ izni hala bekleniyor... Kullanıcı pop-up'ı görmüş olabilir")
            }
        }
        
        // Hala ağ yoksa hata fırlat
        if !networkPermissionGranted {
            throw NSError(
                domain: "FTPError",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "error.network.local_permission_required".localized]
            )
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(Progress.fractionCompleted),
              let progress = object as? Progress else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        let handlerKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.progressHandler).toOpaque())

        var handler: ((Double) -> Void)?
        lock.lock()
        handler = objc_getAssociatedObject(progress, handlerKey) as? ((Double) -> Void)
        lock.unlock()

        if let handler = handler {
            DispatchQueue.main.async {
                handler(progress.fractionCompleted)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateCurrentUploadProgress(progress: progress.fractionCompleted)
        }

        if progress.isFinished || progress.isCancelled {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                objc_sync_enter(progress)
                defer { objc_sync_exit(progress) }

                let observingKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.isObserving).toOpaque())

                if objc_getAssociatedObject(progress, observingKey) as? Bool == true {
                    progress.removeObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted))

                    objc_setAssociatedObject(progress, handlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    objc_setAssociatedObject(progress, observingKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
        }
    }

    func cancelCurrentTask() {
        cancelCurrentTask(reason: "user")
    }

    func cancelForBackgroundExpiration() {
        lock.withLock { _backgroundExpirationRequested = true }
        cancelCurrentTask(reason: "background-expiration")
    }

    func consumeBackgroundExpiration() -> Bool {
        lock.withLock {
            let wasRequested = _backgroundExpirationRequested
            _backgroundExpirationRequested = false
            return wasRequested
        }
    }

#if canImport(UIKit)
    /// FTP cannot survive process termination. The background flag must be set at
    /// BGTask entry too, before a transfer has created a current Progress object.
    @MainActor
    func updateBackgroundMode(isBackground: Bool) {
        let appInBackground = UIApplication.shared.applicationState != .active
        let shouldUseBackgroundMode = isBackground || appInBackground

        guard shouldUseBackgroundMode else {
            backgroundTaskCoordinator.end()
            self.isBackgroundUploading = false
            return
        }

        if currentTask != nil || isBackground || appInBackground {
            backgroundTaskCoordinator.begin()
        }

        self.isBackgroundUploading = true
    }
#endif

    private func cancelCurrentTask(reason: String) {
        if reason != "background-expiration" {
            lock.withLock { _backgroundExpirationRequested = false }
        }
        logger.info("FTP işlemi iptal ediliyor...")
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
        lock.withLock { _currentTransferID = nil }
        logger.info("FTP transfer cancellation requested: \(reason, privacy: .public)")
        Task { @MainActor in
            self.currentFile = "backup.status.cancelled".localized
            self.progress = 0.0
        }
    }

    @MainActor
    private func prepareCurrentUpload(localURL: URL) {
        currentFile = localURL.lastPathComponent
        progress = 0
        currentFileBytesTransferred = 0
        currentFileTotalBytes = Int64((try? localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        transferSpeedBytesPerSecond = 0
        lastProgressSample = (Date(), 0)
    }

    @MainActor
    private func updateCurrentUploadProgress(progress: Double) {
        let safeProgress = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
        let estimatedBytes = currentFileTotalBytes > 0 ? Int64(Double(currentFileTotalBytes) * safeProgress) : 0
        let now = Date()

        if let sample = lastProgressSample {
            let elapsed = now.timeIntervalSince(sample.date)
            let delta = estimatedBytes - sample.bytes
            if elapsed > 0.35, delta >= 0 {
                transferSpeedBytesPerSecond = Double(delta) / elapsed
                lastProgressSample = (now, estimatedBytes)
            }
        } else {
            lastProgressSample = (now, estimatedBytes)
        }

        self.progress = safeProgress
        currentFileBytesTransferred = estimatedBytes
    }

    func testConnection(host: String, port: Int, username: String? = nil, password: String? = nil) async throws -> Bool {
        do {
            // Önce ağ iznini bekle
            try await waitForNetworkPermission()
            
            guard let serverURL = URL(string: host.hasPrefix("ftp://") ? host : "ftp://\(host)") else {
                throw FTPError.invalidURL
            }

            let credential = username.flatMap { un in
                password.map { pw in
                    URLCredential(user: un, password: pw, persistence: .forSession)
                }
            }

            guard let testProvider = FTPFileProvider(baseURL: serverURL, credential: credential) else {
                throw FTPError.connectionFailed
            }
            
            // Try to force passive mode if supported by FilesProvider
            if testProvider.responds(to: Selector(("setPassiveMode:"))) {
                testProvider.setValue(true, forKey: "passiveMode")
                logger.info("FTP: PASV modu etkinleştirildi")
            }
            // Prefer EPSV if supported
            if testProvider.responds(to: Selector(("setUseEPSV:"))) {
                testProvider.setValue(true, forKey: "useEPSV")
                logger.info("FTP: EPSV kullanımı etkinleştirildi")
            }
            
            logger.info("Test FTP provider configured with standard stream session")

            return try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    return try await withCheckedThrowingContinuation { continuation in
                        testProvider.contentsOfDirectory(path: "/") { _, error in
                            Task { @MainActor in
                                if let error = error {
                                    let mappedError = FTPErrorMapper.map(error)
                                    continuation.resume(throwing: mappedError)
                                } else {
                                    continuation.resume(returning: true)
                                }
                            }
                        }
                    }
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    throw NSError(domain: "FTPErrorDomain", code: -1001, userInfo: [
                        NSLocalizedDescriptionKey: "error.connection.timeout".localized
                    ])
                }

                for try await result in group {
                    group.cancelAll()
                    return result
                }

                throw FTPError.connectionFailed
            }
        } catch {
            throw mapError(error)
        }
    }

    func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        
        if _currentTask != nil {
            _currentTask?.cancel()
            _currentTask = nil
        }
        
        if _ftpProvider != nil {
            _ftpProvider = nil
        }
        
        // Clear background session state
        Task { @MainActor in
            self.isBackgroundUploading = false
            self.progress = 0.0
            self.currentFile = ""
        }
        
        isCancelled = false
    }
    
    // MARK: - BackupServiceProtocol Methods
    
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        let connectionInfo = try FTPConnectionBuilder.build(host: host, port: port)
        debugLog("📡 BackupFlow: FTPService - Bağlantı başlatılıyor: \(connectionInfo.displayHost):\(port)")
        
        // Önce ağ iznini bekle
        try await waitForNetworkPermission()
        
        // Önce mevcut bağlantıyı temizle
        disconnect()
        
        if connectionInfo.host.isEmpty {
            debugLog("❌ BackupFlow: FTP sunucu adresi boş")
            logger.error("FTP sunucu adresi boş olamaz")
            throw FTPError.invalidURL
        }
        
        // Retry mantığı ile bağlantı kurma
        var lastError: Error?
        let retryPolicy = FTPRetryPolicy()
        let maxRetries = retryPolicy.maxAttempts
        
        for attempt in 1...maxRetries {
            do {
                try await performConnection(host: host, port: port, username: username, password: password, attempt: attempt)
                debugLog("✅ BackupFlow: FTP bağlantısı başarıyla kuruldu!")
                return // Başarılı, fonksiyondan çık
            } catch {
                lastError = error
                logger.warning("FTP bağlantı denemesi \(attempt)/\(maxRetries) başarısız: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    let delaySeconds = retryPolicy.delayForAttempt(attempt)
                    logger.info("\(String(format: "%.1f", delaySeconds)) saniye bekleniyor...")
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }
        
        // Tüm denemeler başarısız
        throw lastError ?? FTPError.connectionFailed
    }
    
    private func performConnection(host: String, port: Int, username: String?, password: String?, attempt: Int) async throws {
        // Kullanıcı adı boşsa anonim giriş yap
        guard let username = username, !username.isEmpty else {
            logger.info("Kullanıcı adı belirtilmedi, anonim giriş yapılıyor (Deneme \(attempt))")
            // Anonim giriş için kullanıcı adı ve şifreyi ayarla
            let anonymousUsername = "anonymous"
            let anonymousPassword = ""
            
            // URL'i oluştur
            let cleanHost = host.replacingOccurrences(of: "ftp://", with: "")
                               .replacingOccurrences(of: "://", with: "")
                               .replacingOccurrences(of: "@", with: "")
            
            var components = URLComponents()
            components.scheme = "ftp"
            components.host = cleanHost
            components.port = port
            components.user = anonymousUsername
            
            guard let serverURL = components.url else {
                logger.error("Geçersiz FTP URL'i: \(components.debugDescription)")
                throw FTPError.invalidURL
            }
            
            logger.info("Anonim FTP bağlantısı başlatılıyor (Deneme \(attempt)): \(self.maskedURLString(serverURL))")
            
            let credential = URLCredential(user: anonymousUsername,
                                         password: anonymousPassword,
                                         persistence: .forSession)
            
            guard let provider = FTPFileProvider(baseURL: serverURL, credential: credential) else {
                logger.error("FTP sağlayıcısı oluşturulamadı")
                throw FTPError.connectionFailed
            }
            
            // Try to force passive mode if supported by FilesProvider
            if provider.responds(to: Selector(("setPassiveMode:"))) {
                provider.setValue(true, forKey: "passiveMode")
                logger.info("FTP: PASV modu etkinleştirildi")
            }
            // Prefer EPSV if supported
            if provider.responds(to: Selector(("setUseEPSV:"))) {
                provider.setValue(true, forKey: "useEPSV")
                logger.info("FTP: EPSV kullanımı etkinleştirildi")
            }
            
            // FTPFileProvider uses a non-persistent stream session on iOS. Do not
            // weaken TLS validation or claim background-session support here.
            logger.info("FTP provider configured with standard stream session")
            
            // Bağlantıyı test et
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                provider.contentsOfDirectory(path: "/") { contents, error in
                    if let error = error {
                        self.logger.error("Anonim FTP bağlantı hatası: \(error.localizedDescription)")
                        continuation.resume(throwing: self.mapError(error))
                    } else {
                        self.ftpProvider = provider
                        self.logger.info("Anonim FTP bağlantısı başarılı")
                        continuation.resume(returning: ())
                    }
                }
            }
            return
        }
        
        // Sunucu adresini temizle
        let cleanHost = host.replacingOccurrences(of: "ftp://", with: "")
                           .replacingOccurrences(of: "://", with: "")
                           .replacingOccurrences(of: "@", with: "")
        
        // URL'i oluştur
        var components = URLComponents()
        components.scheme = "ftp"
        components.host = cleanHost
        components.port = port
        components.user = username
        components.password = password
        
        guard let serverURL = components.url else {
            logger.error("Geçersiz FTP URL'i: \(components.debugDescription)")
            throw FTPError.invalidURL
        }
        
        logger.info("FTP bağlantısı başlatılıyor: \(self.maskedURLString(serverURL))")
        
        // Kimlik bilgilerini hazırla
        let credential: URLCredential? = {
            // Kullanıcı adı boş değilse verilen bilgileri kullan
            if !username.isEmpty {
                return URLCredential(user: username,
                                   password: password ?? "",
                                   persistence: .forSession)
            }
            // Aksi halde anonim giriş için kimlik bilgisi kullan
            return URLCredential(user: "anonymous",
                               password: "",
                               persistence: .forSession)
        }()
        
        // FTP sağlayıcısını oluştur
        guard let provider = FTPFileProvider(baseURL: serverURL, credential: credential) else {
            logger.error("FTP sağlayıcısı oluşturulamadı")
            throw FTPError.connectionFailed
        }
        
        // Try to force passive mode if supported by FilesProvider
        if provider.responds(to: Selector(("setPassiveMode:"))) {
            provider.setValue(true, forKey: "passiveMode")
            logger.info("FTP: PASV modu etkinleştirildi")
        }
        // Prefer EPSV if supported
        if provider.responds(to: Selector(("setUseEPSV:"))) {
            provider.setValue(true, forKey: "useEPSV")
            logger.info("FTP: EPSV kullanımı etkinleştirildi")
        }
        
        // FTPFileProvider uses a non-persistent stream session on iOS. Do not
        // weaken TLS validation or claim background-session support here.
        logger.info("FTP provider configured with standard stream session")
        
        // Bağlantıyı test et
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.contentsOfDirectory(path: "/") { contents, error in
                if let error = error {
                    self.logger.error("FTP bağlantı hatası: \(error.localizedDescription)")
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    self.ftpProvider = provider
                    self.logger.info("FTP bağlantısı başarılı")
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func mapError(_ error: Error) -> FTPError {
        return FTPErrorMapper.map(error)
    }

    private func cleanupTask(_ task: Progress) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            objc_sync_enter(task)
            defer { objc_sync_exit(task) }

            let handlerKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.progressHandler).toOpaque())
            let observingKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.isObserving).toOpaque())

            if objc_getAssociatedObject(task, observingKey) as? Bool == true {
                task.removeObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted))
                objc_setAssociatedObject(task, handlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                objc_setAssociatedObject(task, observingKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

    // Hedef klasördeki dosya bilgilerini alır
    private func getRemoteFileInfo(at path: String) async throws -> Int64? {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            ftp.attributesOfItem(path: path) { attributes, error in
                if let error = error {
                    if (error as? URLError)?.code == .fileDoesNotExist {
                        continuation.resume(returning: nil)
                    } else {
                        if self.isVerboseLoggingEnabled {
                            self.logger.warning("Dizin kontrolü sırasında hata: \(error.localizedDescription)")
                        }
                        continuation.resume(throwing: self.mapError(error))
                    }
                } else if let attributes = attributes {
                    continuation.resume(returning: attributes.size)
                } else {
                    if self.isVerboseLoggingEnabled {
                        self.logger.warning("Dosya bilgisi alınamadı: \(path)")
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // Dosya değişip değişmediğini kontrol eder
    private func shouldUploadFile(localURL: URL, remotePath: String) async throws -> Bool {
        let localAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let localSize = (localAttributes[.size] as? NSNumber)?.int64Value ?? 0
        
        if let remoteSize = try await getRemoteFileInfo(at: remotePath) {
            // Boyut aynı ise dosyayı atlayabiliriz
            if remoteSize == localSize {
                logger.info("Dosya zaten var ve aynı boyutta (\(localSize) bytes), atlanıyor: \(remotePath)")
                return false
            }
            logger.info("Dosya boyutu farklı (Yerel: \(localSize) bytes, Uzak: \(remoteSize) bytes), yüklenecek: \(remotePath)")
            return true
        }
        
        // Hedef dosya yoksa yüklenmeli
        logger.info("Yeni dosya, yüklenecek: \(remotePath)")
        return true
    }

    func uploadDirectory(localURL: URL, remotePath: String = "", skipExisting: Bool = true, progressHandler: ((Double) -> Void)? = nil) async throws -> Int {
        guard !isCancelled else {
            logger.info("İşlem iptal edildiği için dosya yükleme iptal edildi")
            throw FTPError.fileOperationFailed
        }
        
        guard ftpProvider != nil else {
            logger.error("FTP bağlantısı kurulamamış")
            throw FTPError.connectionFailed
        }
        
        // Mevcut görevi iptal et
        currentTask?.cancel()
        isCancelled = false
        
        if isVerboseLoggingEnabled {
            logger.info("Dosyalar yükleniyor: \(localURL.path)")
        }
        
        let fileManager = FileManager.default
        var skippedCount = 0
        
        do {
            let enumerator = fileManager.enumerator(at: localURL, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
            var totalSize: Int64 = 0
            var files: [(URL, Int64)] = []
            
            // Önce tüm dosyaları ve boyutları topla
            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                if resourceValues.isRegularFile == true {
                    let size = Int64(resourceValues.fileSize ?? 0)
                    files.append((fileURL, size))
                    totalSize += size
                }
            }
            
            guard !files.isEmpty else {
                logger.warning("Yüklenecek dosya bulunamadı")
                return 0
            }
            
            logger.info("Toplam \(files.count) dosya bulundu, toplam boyut: \(totalSize) byte")
            
            // İlerleme için progress nesnesi oluştur
            let overallProgress = Progress(totalUnitCount: totalSize)
            let skipStart = CFAbsoluteTimeGetCurrent()
            var remoteDirCache: [String: [String: Int64]] = [:]
            self.currentTask = overallProgress
            var processedSize: Int64 = 0
            
            // Her dosyayı işle
            for (fileURL, fileSize) in files {
                guard !isCancelled else {
                    logger.info("İşlem iptal edildi")
                    throw FTPError.fileOperationFailed
                }
                
                if Task.isCancelled {
                    logger.info("İşlem iptal edildi (Task cancelled)")
                    throw FTPError.fileOperationFailed
                }
                
                // Dosyanın FTP'deki hedef yolunu oluştur
                // Kaynak URL'den baz klasörü çıkar
                let relativePath = fileURL.path.replacingOccurrences(of: localURL.path, with: "")
                let base = normalizedRemotePath(remotePath)
                let rel = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                let targetPath = base == "/" ? "/" + rel : base + "/" + rel
                
                let parentPath = (targetPath as NSString).deletingLastPathComponent
                
                if skipExisting {
                    // Fast skip using cached remote directory listing
                    self.logger.debug("FTP LIST check for parent: \(parentPath)")
                    if remoteDirCache[parentPath] == nil {
                        self.logger.info("FTP LIST cache miss: \(parentPath)")
                        do {
                            let list = try await listFiles(in: parentPath)
                            var dict: [String: Int64] = [:]
                            for (name, size) in list {
                                dict[name] = size
                            }
                            self.logger.info("FTP LIST loaded \(dict.count) files for \(parentPath)")
                            remoteDirCache[parentPath] = dict
                        } catch {
                            self.logger.warning("FTP LIST failed for \(parentPath); proceeding without size hints")
                            remoteDirCache[parentPath] = [:]
                        }
                    } else {
                        self.logger.debug("FTP LIST cache hit: \(parentPath) (\(remoteDirCache[parentPath]?.count ?? 0) files)")
                    }
                    if let cachedFiles = remoteDirCache[parentPath] {
                        let fileName = (targetPath as NSString).lastPathComponent
                        let tenMB: Int64 = 10 * 1024 * 1024

                        if fileSize > tenMB {
                            // For files >10MB: skip if a file with the same name exists (ignore size)
                            if cachedFiles[fileName] != nil {
                                logger.info("Dosya adı zaten mevcut (>10MB, isim bazlı skip), atlanıyor: \(targetPath)")
                                processedSize += fileSize
                                overallProgress.completedUnitCount = processedSize
                                skippedCount += 1
                                if let handler = progressHandler {
                                    await MainActor.run { handler(Double(processedSize) / Double(totalSize)) }
                                }
                                continue
                            }
                        } else {
                            // For files <=10MB: require both name and size to match
                            if let cachedSize = cachedFiles[fileName], cachedSize == fileSize {
                                logger.info("Dosya zaten var ve aynı boyutta (<=10MB, isim+boyut), atlanıyor: \(targetPath)")
                                processedSize += fileSize
                                overallProgress.completedUnitCount = processedSize
                                skippedCount += 1
                                if let handler = progressHandler {
                                    await MainActor.run { handler(Double(processedSize) / Double(totalSize)) }
                                }
                                continue
                            }
                        }
                    }
                }
                
                // Only ensure remote directory exists if we actually need to upload
                if !parentPath.isEmpty && parentPath != "/" {
                    do {
                        try await createDirectory(at: parentPath)
                    } catch {
                        let nsError = error as NSError
                        if (nsError.domain == NSURLErrorDomain && nsError.code == -3000) || (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteFileExistsError) {
                            self.logger.info("FTP: Directory already exists or not creatable (non-fatal): \(parentPath)")
                        } else {
                            throw error
                        }
                    }
                }
                
                logger.info("Yükleniyor: \(relativePath)")
                
                try await uploadFile(localURL: fileURL, remotePath: targetPath) { _ in
                    // Dosya bazlı ilerleme bilgisi
                }
                
                processedSize += fileSize
                overallProgress.completedUnitCount = processedSize
                
                if let handler = progressHandler {
                    await MainActor.run { handler(Double(processedSize) / Double(totalSize)) }
                }
            }
            let skipElapsed = CFAbsoluteTimeGetCurrent() - skipStart
            self.logger.info("FTP: Skip decision pass completed in \(String(format: "%.3f", skipElapsed))s for \(files.count) files")
        } catch {
            logger.error("Yükleme hatası: \(error.localizedDescription)")
            throw error
        }
        
        return skippedCount
    }

    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard !isCancelled else {
            debugLog("🛑 BackupFlow: İşlem iptal edildiği için yükleme iptal edildi")
            logger.info("İşlem iptal edildiği için yükleme iptal edildi")
            throw BackupServiceError.cancelled
        }
        
        guard let ftp = ftpProvider else {
            debugLog("❌ BackupFlow: FTP bağlantısı kurulamamış")
            logger.error("FTP bağlantısı kurulamamış")
            throw FTPError.connectionFailed
        }

        if Task.isCancelled {
            logger.info("İşlem iptal edildi (Task cancelled) - yükleme başlamadan")
            throw BackupServiceError.cancelled
        }
        
        let finalPath = normalizedRemotePath(remotePath)
        let temporaryPath = temporaryRemotePath(for: finalPath)

        // A sync is sequential, but a defensive cancellation prevents an older
        // stream from writing after a new upload has taken ownership.
        if let existing = currentTask, !existing.isCancelled && !existing.isFinished {
            existing.cancel()
        }

        try await uploadRawFile(
            ftp: ftp,
            localURL: localURL,
            remotePath: temporaryPath,
            progressHandler: progressHandler
        )

        guard !isCancelled, !Task.isCancelled else {
            try? await deleteFile(at: temporaryPath)
            throw BackupServiceError.cancelled
        }

        do {
            try await moveFile(from: temporaryPath, to: finalPath)
        } catch {
            // The uploaded temp file is intentionally retained for this run's
            // cleanup pass if the server rejects the final rename.
            throw error
        }
    }

    private func uploadRawFile(
        ftp: FTPFileProvider,
        localURL: URL,
        remotePath: String,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let transferID = UUID()

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: FTPError.connectionFailed)
                return
            }

            Task { @MainActor in
                self.prepareCurrentUpload(localURL: localURL)
            }

            guard !self.isCancelled, !Task.isCancelled else {
                continuation.resume(throwing: BackupServiceError.cancelled)
                return
            }

            self.lock.withLock { self._currentTransferID = transferID }

            let transferProgress = ftp.copyItem(localFile: localURL, to: remotePath) { [weak self] error in
                guard let self else {
                    continuation.resume(throwing: FTPError.connectionFailed)
                    return
                }

                let isCurrentTransfer = self.lock.withLock { self._currentTransferID == transferID }
                guard isCurrentTransfer else {
                    return
                }

                let activeProgress = self.currentTask
                if let task = activeProgress {
                    self.cleanupTask(task)
                }
                self.currentTask = nil
                self.lock.withLock { self._currentTransferID = nil }

                if Task.isCancelled || self.isCancelled || activeProgress?.isCancelled == true {
                    Task { @MainActor in
                        self.currentFile = "backup.status.cancelled".localized
                        self.progress = 0.0
                    }
                    continuation.resume(throwing: BackupServiceError.cancelled)
                    return
                }

                if let error {
                    debugLog("❌ BackupFlow: Dosya yükleme hatası: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.currentFile = "backup.current_file.error".localized(with: error.localizedDescription)
                        self.progress = 0.0
                    }
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    progressHandler?(1.0)
                    Task { @MainActor in
                        self.currentFile = "backup.current_file.completed_file".localized(with: localURL.lastPathComponent)
                        self.progress = 1.0
                    }
                    continuation.resume(returning: ())
                }
            }

            guard let transferProgress else {
                self.lock.withLock { self._currentTransferID = nil }
                continuation.resume(throwing: FTPError.fileOperationFailed)
                return
            }

            if let progressHandler {
                let handlerKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.progressHandler).toOpaque())
                objc_setAssociatedObject(transferProgress, handlerKey, progressHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                DispatchQueue.main.async {
                    let observingKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.isObserving).toOpaque())
                    transferProgress.addObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted), options: [.new], context: nil)
                    objc_setAssociatedObject(transferProgress, observingKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }

            self.currentTask = transferProgress
        }
    }

    func downloadFile(remotePath: String, localURL: URL, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }

        if isCancelled || Task.isCancelled {
            throw FTPError.fileOperationFailed
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: FTPError.connectionFailed)
                return
            }

            if let currentTask = self.currentTask {
                self.cleanupTask(currentTask)
            }

            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 0

            if let progressHandler = progressHandler {
                let handlerKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.progressHandler).toOpaque())
                objc_setAssociatedObject(progress, handlerKey, progressHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                DispatchQueue.main.async {
                    let observingKey = UnsafeRawPointer(Unmanaged.passUnretained(AssociatedKeys.isObserving).toOpaque())
                    progress.addObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted), options: [.new], context: nil)
                    objc_setAssociatedObject(progress, observingKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }

            self.currentTask = progress

            if self.isCancelled || Task.isCancelled {
                continuation.resume(throwing: FTPError.fileOperationFailed)
                return
            }

            ftp.copyItem(path: remotePath, toLocalURL: localURL) { [weak self] error in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.connectionFailed)
                    return
                }

                if let task = self.currentTask {
                    self.cleanupTask(task)
                    self.currentTask = nil
                }

                if Task.isCancelled || self.isCancelled {
                    continuation.resume(throwing: FTPError.fileOperationFailed)
                    return
                }

                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    progress.completedUnitCount = 100
                    progressHandler?(1.0)
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func createDirectory(at path: String) async throws {
        guard let ftp = ftpProvider else {
            logger.error("Dizin oluşturulamadı: FTP bağlantısı yok")
            throw FTPError.connectionFailed
        }
        let path = normalizedRemotePath(path)
        let ops = FTPFileOperations(
            provider: ftp,
            logger: logger,
            isVerboseLoggingEnabled: isVerboseLoggingEnabled,
            isCancelled: { [weak self] in self?.isCancelled ?? false },
            mapError: { [weak self] error in self?.mapError(error) ?? .unknown(error) }
        )
        try await ops.createDirectory(at: path)
    }

    func directoryExists(_ path: String) async throws -> Bool? {
        guard let ftp = ftpProvider else {
            logger.error("Dizin kontrolü yapılamadı: FTP bağlantısı yok")
            throw FTPError.connectionFailed
        }
        let path = normalizedRemotePath(path)
        let ops = FTPFileOperations(
            provider: ftp,
            logger: logger,
            isVerboseLoggingEnabled: isVerboseLoggingEnabled,
            isCancelled: { [weak self] in self?.isCancelled ?? false },
            mapError: { [weak self] error in self?.mapError(error) ?? .unknown(error) }
        )
        return try await ops.directoryExists(path)
    }

    func listDirectory(at path: String) async throws -> [FileObject] {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        let path = normalizedRemotePath(path)
        let ops = FTPFileOperations(
            provider: ftp,
            logger: logger,
            isVerboseLoggingEnabled: isVerboseLoggingEnabled,
            isCancelled: { [weak self] in self?.isCancelled ?? false },
            mapError: { [weak self] error in self?.mapError(error) ?? .unknown(error) }
        )
        return try await ops.listDirectory(at: path)
    }
    
    // Belirli bir klasördeki dosyaları listele (sadece dosyalar, alt klasörler değil)
    func listFiles(in directory: String) async throws -> [(name: String, size: Int64)] {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        
        logger.info("FTP klasörü listeleniyor: \(directory)")
        
        return try await withCheckedThrowingContinuation { continuation in
            ftp.contentsOfDirectory(path: directory) { files, error in
                if let error = error {
                    // Klasör yoksa boş liste döndür
                    if (error as? URLError)?.code == .fileDoesNotExist {
                        self.logger.info("FTP klasörü bulunamadı: \(directory)")
                        continuation.resume(returning: [])
                    } else {
                        self.logger.error("FTP klasör listeleme hatası: \(error.localizedDescription)")
                        continuation.resume(throwing: self.mapError(error))
                    }
                } else {
                    // Sadece dosyaları filtrele ve isim + boyut çiftlerini döndür
                    let fileList = files.compactMap { file -> (String, Int64)? in
                        guard !file.isDirectory else { return nil }
                        return (file.name, file.size)
                    }
                    self.logger.info("FTP klasöründe \(fileList.count) dosya bulundu")
                    continuation.resume(returning: fileList)
                }
            }
        }
    }
    
    // MARK: - Enhanced File Management for Mirror Sync
    typealias SyncResult = FTPSyncResult
    
    /// Helper function to upload exported photo/video files.
    private func uploadPhotoFile(localURL: URL, remotePath: String, fileName: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        // Update current file being processed
        Task { @MainActor in
            self.currentFile = "backup.current_file.uploading_file".localized(with: fileName)
        }
        
        try await uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
    }
    
    /// Enhanced directory sync with full mirror functionality (upload new, skip identical, delete orphans)
    private func syncUploadDirectory(
        localURL: URL,
        remotePath: String = "",
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> SyncResult {
        let engine = try makeSyncEngine()
        return try await engine.syncUploadDirectory(
            localURL: localURL,
            remotePath: remotePath,
            options: options,
            progressHandler: progressHandler
        )
    }

    private func makeSyncEngine() throws -> FTPSyncEngine {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        return FTPSyncEngine(
            provider: ftp,
            logger: logger,
            isVerboseLoggingEnabled: isVerboseLoggingEnabled,
            fastPhotoNameSkipEnabled: fastPhotoNameSkipEnabled,
            isCancelled: { [weak self] in self?.isCancelled ?? false },
            createDirectory: { [weak self] path in
                guard let self else { throw FTPError.connectionFailed }
                try await self.createDirectory(at: path)
            },
            deleteFile: { [weak self] path in
                guard let self else { throw FTPError.connectionFailed }
                try await self.deleteFile(at: path)
            },
            archiveFile: { [weak self] sourcePath, destinationPath in
                guard let self else { throw FTPError.connectionFailed }
                try await self.archiveFile(from: sourcePath, to: destinationPath)
            },
            uploadFile: { [weak self] localURL, remotePath, progressHandler in
                guard let self else { throw FTPError.connectionFailed }
                try await self.uploadFile(localURL: localURL, remotePath: remotePath, progressHandler: progressHandler)
            },
            verifyUpload: { [weak self] localURL, remotePath in
                guard let self else { throw FTPError.connectionFailed }
                try await self.verifyUploadChecksum(localURL: localURL, remotePath: remotePath)
            },
            setCurrentFile: { [weak self] name in
                Task { @MainActor in
                    self?.currentFile = name
                }
            },
            formatBytes: { [weak self] bytes in
                return self?.formatBytes(bytes) ?? "\(bytes)"
            },
            mapError: { [weak self] error in
                return self?.mapError(error) ?? .unknown(error)
            },
            uploadPhotoFile: { [weak self] localURL, remotePath, fileName in
                guard let self else { throw FTPError.connectionFailed }
                try await self.uploadPhotoFile(localURL: localURL, remotePath: remotePath, fileName: fileName)
            }
        )
    }

    private func verifyUploadChecksum(localURL: URL, remotePath: String) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backupflow-verify-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ftp.copyItem(path: remotePath, toLocalURL: temporaryURL) { [weak self] error in
                if let error {
                    continuation.resume(throwing: self?.mapError(error) ?? FTPError.unknown(error))
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
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        let parentPath = (destinationPath as NSString).deletingLastPathComponent
        if !parentPath.isEmpty && parentPath != "/" {
            try await createDirectory(at: parentPath)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ftp.moveItem(path: sourcePath, to: destinationPath, overwrite: false) { [weak self] error in
                if let error {
                    continuation.resume(throwing: self?.mapError(error) ?? FTPError.unknown(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ftp.moveItem(path: sourcePath, to: destinationPath, overwrite: true) { [weak self] error in
                if let error {
                    continuation.resume(throwing: self?.mapError(error) ?? FTPError.unknown(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func temporaryRemotePath(for finalPath: String) -> String {
        let normalized = normalizedRemotePath(finalPath)
        return normalized + partialFileMarker + UUID().uuidString
    }

    private func cleanupStaleTemporaryFiles(at rootPath: String) async {
        guard let ftp = ftpProvider else { return }

        func visit(_ path: String) async {
            let entries: [FileObject]
            do {
                entries = try await withCheckedThrowingContinuation { continuation in
                    ftp.contentsOfDirectory(path: path) { files, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: files)
                        }
                    }
                }
            } catch {
                return
            }

            for entry in entries {
                guard !isCancelled else { return }
                let childPath = normalizedRemotePath(path + "/" + entry.name)
                if entry.isDirectory {
                    await visit(childPath)
                } else if entry.name.contains(partialFileMarker) {
                    do {
                        try await deleteFile(at: childPath)
                        logger.info("Removed stale FTP partial file: \(childPath, privacy: .public)")
                    } catch {
                        logger.warning("Could not remove stale FTP partial file: \(childPath, privacy: .public)")
                    }
                }
            }
        }

        await visit(normalizedRemotePath(rootPath))
    }
    
    // FTP sunucusundan dosya sil
    func deleteFile(at path: String) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        
        let path = normalizedRemotePath(path)
        
        logger.info("FTP dosyası siliniyor: \(path)")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ftp.removeItem(path: path) { error in
                if let error = error {
                    self.logger.error("FTP dosya silme hatası: \(error.localizedDescription)")
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    self.logger.info("FTP dosyası başarıyla silindi: \(path)")
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    // MARK: - Backup Operations
    func performBackup(
        host: String, 
        port: Int, 
        username: String, 
        password: String, 
        sourcePath: String, 
        isAnonymous: Bool,
        mediaType: MediaType,
        includeICloudAssets: Bool = true,
        options: BackupExecutionOptions = .defaults,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> SyncResult {
        
        debugLog("📡 BackupFlow: FTP senkronize yedekleme başlatılıyor - \(host):\(port)")
        
        let startedInBackground: Bool = {
            #if canImport(UIKit)
            return UIApplication.shared.applicationState != .active
            #else
            return false
            #endif
        }()
#if canImport(UIKit)
        backgroundTaskCoordinator.onExpiration = { [weak self] in
            self?.logger.warning("FTP background time expired, cancelling transfer")
            self?.cancelCurrentTask()
        }
        let shouldProtectBackgroundTransfer = startedInBackground && !options.isDryRun
        if shouldProtectBackgroundTransfer {
            backgroundTaskCoordinator.begin()
            logger.info("📱 FTP background task protection enabled for transfer")
        }
        defer {
            if shouldProtectBackgroundTransfer {
                backgroundTaskCoordinator.end()
            }
            Task { @MainActor in
                self.isBackgroundUploading = false
            }
        }
#endif
        if sourcePath == "PHOTOS_LIBRARY" || !sourcePath.isEmpty {
            await MainActor.run {
                self.currentFile = "backup.current_file.preparing".localized
            }
        }

        // Connect to FTP server
        let actualUsername = isAnonymous ? nil : username
        let actualPassword = isAnonymous ? nil : password

        try await connect(host: host, port: port, username: actualUsername, password: actualPassword)

        if startedInBackground {
            await MainActor.run {
                self.isBackgroundUploading = true
            }
            self.logger.info("📱 FTP is running in a limited iOS background window")
        } else {
            await MainActor.run {
                self.isBackgroundUploading = false
            }
        }
        
        let syncResult: SyncResult
        let shouldSkipRemotePreparation = options.shouldSkipRemotePreparation
        
        if sourcePath == "PHOTOS_LIBRARY" {
            // Photo library sync backup
            if shouldSkipRemotePreparation {
                logger.info("Preview mode: skipping FTP remote directory preparation for photo library")
            } else {
                try? await createDirectory(at: "photos")
                await cleanupStaleTemporaryFiles(at: "photos")
            }
            let engine = try makeSyncEngine()
            syncResult = try await engine.syncBackupPhotoLibrary(
                mediaType: mediaType,
                includeICloudAssets: includeICloudAssets,
                options: options,
                progressHandler: progressHandler
            )
            if !options.isDryRun {
                try await uploadManifest(syncResult: syncResult, remoteBasePath: "photos", options: options)
            }
        } else {
            // Directory sync backup - preserve source folder name
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let sourceFolderName = sourceURL.lastPathComponent
            let safeRemoteBase = normalizedRemotePath("/" + sourceFolderName)
            if shouldSkipRemotePreparation {
                logger.info("Preview mode: skipping FTP remote directory preparation for \(safeRemoteBase)")
            } else {
                try? await createDirectory(at: safeRemoteBase)
                await cleanupStaleTemporaryFiles(at: safeRemoteBase)
            }
            syncResult = try await syncUploadDirectory(localURL: sourceURL, remotePath: safeRemoteBase, options: options, progressHandler: progressHandler)
            if !options.isDryRun {
                try await uploadManifest(syncResult: syncResult, remoteBasePath: safeRemoteBase, options: options)
            }
        }
        
        // Print detailed report
        debugLog("✅ BackupFlow: FTP senkronize yedekleme tamamlandı")
        debugLog("   📊 Yedekleme Raporu:")
        debugLog("   📤 Yeni dosya kopyalandı: \(syncResult.newFiles)")
        debugLog("   🔄 Dosya güncellendi: \(syncResult.updatedFiles)")
        debugLog("   ⏭ Aynı dosya pas geçildi: \(syncResult.skippedFiles)")
        debugLog("   ☁️ iCloud-only atlanan: \(syncResult.iCloudSkippedFiles)")
        debugLog("   ⏱️ Okuma zaman aşımı: \(syncResult.timedOutAssetReads)")
        debugLog("   ⚠️ Okunamayan asset: \(syncResult.failedAssetReads)")
        debugLog("   🗑 Dosya silindi: \(syncResult.deletedFiles)")
        debugLog("   📈 Toplam işlenen: \(syncResult.totalProcessed)")
        debugLog("   💾 Toplam boyut: \(formatBytes(syncResult.totalBytes))")
        
        return syncResult
    }

    private func uploadManifest(syncResult: SyncResult, remoteBasePath: String, options: BackupExecutionOptions) async throws {
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
    
    /// Byte sayısını okunabilir formata çevirir
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#else

import Foundation

@MainActor
final class FTPService: ObservableObject {
    static let shared = FTPService()
    private init() {}
}

#endif

#if canImport(UIKit)
private final class FTPBackgroundTaskCoordinator {
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
        onExpiration?()
        end()
    }

    private func startTaskLocked() {
        let newID = UIApplication.shared.beginBackgroundTask(withName: "FTPFileTransfer") { [weak self] in
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
#endif
