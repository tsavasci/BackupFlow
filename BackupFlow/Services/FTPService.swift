#if canImport(FilesProvider)

import Foundation
import FilesProvider
import OSLog
import Photos
import Combine
import Network
#if canImport(UIKit)
import UIKit
#endif

enum FTPError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case authenticationFailed
    case fileOperationFailed
    case invalidResponse
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Geçersiz FTP sunucu adresi"
        case .connectionFailed:
            return "FTP sunucusuna bağlanılamadı"
        case .authenticationFailed:
            return "Kimlik doğrulama başarısız. Kullanıcı adı ve şifrenizi kontrol edin"
        case .fileOperationFailed:
            return "Dosya işlemi başarısız oldu"
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        case .unknown(let error):
            return "Beklenmeyen bir hata oluştu: \(error.localizedDescription)"
        }
    }
}

// Key objects for associated objects
private struct AssociatedKeys {
    static let progressHandler = NSObject()
    static let isObserving = NSObject()
}

@MainActor
final class FTPService: NSObject, @unchecked Sendable, BackupServiceProtocol {
    static let shared = FTPService()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "FTPService")
    
    // MARK: - BackupServiceProtocol Properties
    @Published private(set) var isConnected = false
    @Published private(set) var networkPermissionGranted = false
    private(set) var lastError: Error?
    
    // Background session state tracking
    @Published private(set) var isBackgroundUploading = false
    private var backgroundSessionIdentifier: String?
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentFile: String = ""
    
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "FTPNetworkMonitor")

    private let lock = NSLock()
    private var _ftpProvider: FTPFileProvider?
    private var _currentTask: Progress?

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
    
    private var isCancelled = false

    override private init() {
        super.init()
        setupNetworkMonitoring()
    }
    
    // MARK: - Network Permission Management
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkPermissionGranted = path.status == .satisfied
                if path.status == .satisfied {
                    self?.logger.info("FTP: Ağ bağlantısı kullanılabilir")
                } else {
                    let statusString = self?.networkStatusString(path.status) ?? "bilinmeyen"
                    self?.logger.warning("FTP: Ağ bağlantısı kullanılamıyor: \(statusString)")
                }
            }
        }
        networkMonitor?.start(queue: networkQueue)
    }
    
    private func networkStatusString(_ status: NWPath.Status) -> String {
        switch status {
        case .satisfied:
            return "satisfied"
        case .unsatisfied:
            return "unsatisfied"
        case .requiresConnection:
            return "requiresConnection"
        @unknown default:
            return "unknown"
        }
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
                userInfo: [NSLocalizedDescriptionKey: "Ağ bağlantısı için izin gerekli. Lütfen Ayarlar > Gizlilik ve Güvenlik > Yerel Ağ'dan uygulamaya izin verin."]
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
        logger.info("FTP işlemi iptal ediliyor...")
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
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
            
            // Configure test provider based on app state
            let isBackgroundMode: Bool = {
                #if canImport(UIKit)
                return UIApplication.shared.applicationState != .active
                #else
                return false
                #endif
            }()
            if isBackgroundMode {
                testProvider.serverTrustPolicy = .disableEvaluation
                logger.info("⏱️ Test FTP provider configured for background mode")
            } else {
                logger.info("⏱️ Test FTP provider configured for foreground mode")
            }

            return try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    return try await withCheckedThrowingContinuation { continuation in
                        testProvider.contentsOfDirectory(path: "/") { _, error in
                            Task { @MainActor in
                                if let error = error {
                                    let mappedError = FTPService.mapErrorStatic(error)
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
                        NSLocalizedDescriptionKey: "Connection timed out"
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
            self.backgroundSessionIdentifier = nil
            self.progress = 0.0
            self.currentFile = ""
        }
        
        isCancelled = false
    }
    
    // MARK: - BackupServiceProtocol Methods
    
    func connect(host: String, port: Int, username: String?, password: String?) async throws {
        print("📡 BackupFlow: FTPService - Bağlantı başlatılıyor: \(host):\(port)")
        
        // Önce ağ iznini bekle
        try await waitForNetworkPermission()
        
        // Önce mevcut bağlantıyı temizle
        disconnect()
        
        // FTP parametrelerini kontrol et
        guard !host.isEmpty else {
            print("❌ BackupFlow: FTP sunucu adresi boş")
            logger.error("FTP sunucu adresi boş olamaz")
            throw FTPError.invalidURL
        }
        
        // IP adresi veya hostname kontrolü
        let hostParts = host.split(separator: ".")
        if hostParts.count != 4 {
            print("❌ BackupFlow: Geçersiz IP adresi formatı: \(host)")
            logger.error("Geçersiz IP adresi formatı: \(host)")
            throw FTPError.invalidURL
        }
        
        // Port kontrolü
        guard port > 0 && port < 65536 else {
            print("❌ BackupFlow: Geçersiz port numarası: \(port)")
            logger.error("Geçersiz port numarası: \(port)")
            throw FTPError.invalidURL
        }
        
        // Retry mantığı ile bağlantı kurma
        var lastError: Error?
        let maxRetries = 3
        let retryDelay: UInt64 = 2_000_000_000 // 2 saniye
        
        for attempt in 1...maxRetries {
            do {
                try await performConnection(host: host, port: port, username: username, password: password, attempt: attempt)
                print("✅ BackupFlow: FTP bağlantısı başarıyla kuruldu!")
                return // Başarılı, fonksiyondan çık
            } catch {
                lastError = error
                logger.warning("FTP bağlantı denemesi \(attempt)/\(maxRetries) başarısız: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    logger.info("\(retryDelay / 1_000_000_000) saniye bekleniyor...")
                    try await Task.sleep(nanoseconds: retryDelay)
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
            
            logger.info("Anonim FTP bağlantısı başlatılıyor (Deneme \(attempt)): \(serverURL.absoluteString)")
            
            let credential = URLCredential(user: anonymousUsername,
                                         password: anonymousPassword,
                                         persistence: .forSession)
            
            guard let provider = FTPFileProvider(baseURL: serverURL, credential: credential) else {
                logger.error("FTP sağlayıcısı oluşturulamadı")
                throw FTPError.connectionFailed
            }
            
            // Configure provider based on app state
            let isBackgroundMode: Bool = {
                #if canImport(UIKit)
                return UIApplication.shared.applicationState != .active
                #else
                return false
                #endif
            }()
            if isBackgroundMode {
                // Background mode: Provider will use background session internally
                provider.serverTrustPolicy = .disableEvaluation // More permissive for background
                logger.info("⏱️ Anonymous FTP provider configured for background mode")
            } else {
                // Foreground mode: Use default configuration
                logger.info("⏱️ Anonymous FTP provider configured for foreground mode")
            }
            
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
        
        logger.info("FTP bağlantısı başlatılıyor: \(serverURL.absoluteString)")
        
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
        
        // Configure provider based on app state
        let isBackgroundMode: Bool = {
            #if canImport(UIKit)
            return UIApplication.shared.applicationState != .active
            #else
            return false
            #endif
        }()
        if isBackgroundMode {
            // Background mode: Provider will use background session internally
            provider.serverTrustPolicy = .disableEvaluation // More permissive for background
            logger.info("⏱️ FTP provider configured for background mode")
        } else {
            // Foreground mode: Use default configuration
            logger.info("⏱️ FTP provider configured for foreground mode")
        }
        
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
        return FTPService.mapErrorStatic(error)
    }
    
    private static func mapErrorStatic(_ error: Error) -> FTPError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return .connectionFailed
            case .userAuthenticationRequired:
                return .authenticationFailed
            case .fileDoesNotExist:
                return .fileOperationFailed
            default:
                return .fileOperationFailed
            }
        }
        return .unknown(error)
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
                        continuation.resume(throwing: self.mapError(error))
                    }
                } else if let attributes = attributes {
                    continuation.resume(returning: attributes.size)
                } else {
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
        
        logger.info("Dosyalar yükleniyor: \(localURL.path)")
        
        let fileManager = FileManager.default
        var skippedCount = 0
        
        // Sadece doğrudan dosyaları topla
        logger.info("Dosyalar yükleniyor: \(localURL.path)")
        
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
            self.currentTask = overallProgress
            var processedSize: Int64 = 0
            
            // Her dosyayı işle
            for (fileURL, fileSize) in files {
                guard !isCancelled else {
                    logger.info("İşlem iptal edildi")
                    throw FTPError.fileOperationFailed
                }
                
                // Dosyanın FTP'deki hedef yolunu oluştur
                // Kaynak URL'den baz klasörü çıkar
                let relativePath = fileURL.path.replacingOccurrences(of: localURL.path, with: "")
                let targetPath = remotePath + relativePath
                
                if skipExisting {
                    if let remoteSize = try? await getRemoteFileInfo(at: targetPath),
                       remoteSize == fileSize {
                        logger.info("Dosya zaten var ve aynı boyutta (\(fileSize) bytes), atlanıyor: \(targetPath)")
                        processedSize += fileSize
                        overallProgress.completedUnitCount = processedSize
                        skippedCount += 1
                        if let handler = progressHandler {
                            await MainActor.run { handler(Double(processedSize) / Double(totalSize)) }
                        }
                        continue
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
            
        } catch {
            logger.error("Yükleme hatası: \(error.localizedDescription)")
            throw error
        }
        
        return skippedCount
    }

    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard !isCancelled else {
            print("🛑 BackupFlow: İşlem iptal edildiği için yükleme iptal edildi")
            logger.info("İşlem iptal edildiği için yükleme iptal edildi")
            throw FTPError.fileOperationFailed
        }
        
        guard let ftp = ftpProvider else {
            print("❌ BackupFlow: FTP bağlantısı kurulamamış")
            logger.error("FTP bağlantısı kurulamamış")
            throw FTPError.connectionFailed
        }
        
        // Log timeout configuration for background/foreground mode
        let isBackgroundMode: Bool = {
            #if canImport(UIKit)
            return UIApplication.shared.applicationState != .active
            #else
            return false
            #endif
        }()
        if isBackgroundMode {
            logger.info("⏱️ FTP using background mode (longer timeouts expected)")
        } else {
            logger.info("⏱️ FTP using foreground mode (normal timeouts)")
        }
        
        // Mevcut görevi iptal et
        currentTask?.cancel()
        
        // Bu fonksiyon artık sadece yükleme yapar, dizin kontrolü veya oluşturma yapmaz.
        // logger.info("Dosya yükleniyor: \(localURL.lastPathComponent) -> \(remotePath)")

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

            ftp.copyItem(localFile: localURL, to: remotePath) { [weak self] error in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.connectionFailed)
                    return
                }

                if let task = self.currentTask {
                    self.cleanupTask(task)
                    self.currentTask = nil
                }

                if let error = error {
                    print("❌ BackupFlow: Dosya yükleme hatası: \(error.localizedDescription)")
                    // Clear progress state on error
                    Task { @MainActor in
                        self.currentFile = "Hata: \(error.localizedDescription)"
                        self.progress = 0.0
                    }
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    print("✅ BackupFlow: Dosya başarıyla yüklendi: \(remotePath)")
                    // Update progress state on success
                    Task { @MainActor in
                        self.currentFile = "Tamamlandı: \(localURL.lastPathComponent)"
                        self.progress = 1.0
                    }
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func downloadFile(remotePath: String, localURL: URL, progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
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

            ftp.copyItem(path: remotePath, toLocalURL: localURL) { [weak self] error in
                guard let self = self else {
                    continuation.resume(throwing: FTPError.connectionFailed)
                    return
                }

                if let task = self.currentTask {
                    self.cleanupTask(task)
                    self.currentTask = nil
                }

                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume(returning: ())
                }
            }

            progress.completedUnitCount = 100
        }
    }

func createDirectory(at path: String) async throws {
        guard !isCancelled else {
            logger.info("İşlem iptal edildiği için dizin oluşturma iptal edildi")
            throw FTPError.fileOperationFailed
        }
        
        guard let ftp = ftpProvider else {
            logger.error("Dizin oluşturulamadı: FTP bağlantısı yok")
            throw FTPError.connectionFailed
        }
        
        // Check if the directory already exists first
        if let exists = try? await directoryExists(path), exists == true {
            logger.info("Dizin zaten mevcut: \(path)")
            return
        }
        
        logger.info("Dizin oluşturuluyor: \(path)")
        
        // Split the path into components and create each directory one by one
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        var currentPath = ""
        
        for component in components {
            currentPath += "/" + component
            
            // Check if current path exists
            if let exists = try? await directoryExists(currentPath), exists == true {
                logger.debug("Ara dizin zaten mevcut: \(currentPath)")
                continue
            }
            
            logger.debug("Ara dizin oluşturuluyor: \(currentPath)")
            
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    ftp.create(folder: currentPath, at: "/") { (error: Error?) in
                        if let error = error {
                            // If directory creation fails, it might be because it was created by another process
                            // or due to permission issues, but we'll still try to continue
                            self.logger.warning("Dizin oluşturulurken hata: \(error.localizedDescription). Yine de devam ediliyor...")
                            continuation.resume()
                        } else {
                            self.logger.debug("Dizin başarıyla oluşturuldu: \(currentPath)")
                            continuation.resume()
                        }
                    }
                }
            } catch {
                logger.error("Dizin oluşturulurken beklenmeyen hata: \(error.localizedDescription)")
                // Continue to next component instead of throwing, to be more resilient
            }
        }
        
        // Final check to make sure the directory was actually created
        if let exists = try? await directoryExists(path), exists == true {
            logger.info("Dizin başarıyla oluşturuldu: \(path)")
            return
        } else {
            logger.error("Dizin oluşturulamadı: \(path)")
            throw FTPError.fileOperationFailed
        }
    }

    func directoryExists(_ path: String) async throws -> Bool? {
        guard !path.isEmpty else {
            // Root path always exists
            logger.debug("Kök dizin kontrol ediliyor: Her zaman mevcut kabul ediliyor")
            return true
        }
        
        guard let ftp = ftpProvider else {
            logger.error("Dizin kontrolü yapılamadı: FTP bağlantısı yok")
            throw FTPError.connectionFailed
        }
        
        logger.debug("Dizin kontrol ediliyor: \(path)")
        
        return try await withCheckedThrowingContinuation { continuation in
            ftp.attributesOfItem(path: path) { file, error in
                if let error = error as? URLError, error.code == .fileDoesNotExist {
                    self.logger.debug("Dizin bulunamadı: \(path)")
                    continuation.resume(returning: false)
                } else if let error = error {
                    // For anonymous FTP, some servers might return permission denied instead of file not found
                    if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorNoPermissionsToReadFile {
                        self.logger.warning("Dizin erişim izni yok, mevcut olarak kabul ediliyor: \(path) - \(error.localizedDescription)")
                        continuation.resume(returning: true)
                    } else {
                        self.logger.warning("Dizin kontrolü sırasında hata: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                    }
                } else if let file = file {
                    self.logger.debug("Dizin kontrolü: \(path) - \(file.isDirectory == true ? "Dizin olarak mevcut" : "Dosya olarak mevcut")")
                    continuation.resume(returning: file.isDirectory)
                } else {
                    self.logger.warning("Dosya bilgisi alınamadı: \(path)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

func listDirectory(at path: String) async throws -> [FileObject] {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            ftp.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    continuation.resume(throwing: self.mapError(error))
                } else {
                    continuation.resume(returning: files)
                }
            }
        }
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
    
    /// Recursive function to list all files in a directory with their relative paths
    private func listAllFiles(at path: String, relativeTo basePath: String = "") async throws -> [String: FileObject] {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        
        var allFiles: [String: FileObject] = [:]
        
        let files = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileObject], Error>) in
            ftp.contentsOfDirectory(path: path) { files, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: files)
                }
            }
        }
        
        for file in files {
            let relativePath = basePath.isEmpty ? file.name : "\(basePath)/\(file.name)"
            
            if file.isDirectory {
                // Recursively list subdirectory
                let subdirPath = path == "/" ? "/\(file.name)" : "\(path)/\(file.name)"
                let subFiles = try await listAllFiles(at: subdirPath, relativeTo: relativePath)
                allFiles.merge(subFiles) { _, new in new }
            } else {
                allFiles[relativePath] = file
            }
        }
        
        return allFiles
    }
    
    /// Helper function to collect local files with their relative paths
    private func collectLocalFiles(from localPath: String) throws -> [String: URL] {
        var fileMap: [String: URL] = [:]
        
        self.logger.info("🔍 Collecting files from: \(localPath)")
        
        // Use FileAccessManager for File Provider files
        do {
            try FileAccessManager.shared.accessFileProviderFiles(at: localPath) { coordinatedURL in
                self.logger.info("📂 Accessing coordinated URL: \(coordinatedURL.path)")
                
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: coordinatedURL.path, isDirectory: &isDirectory)
                
                self.logger.info("📂 Directory exists: \(exists), isDirectory: \(isDirectory.boolValue)")
                
                guard exists && isDirectory.boolValue else {
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Directory does not exist or is not accessible"])
                }
                
                // Try to read directory contents
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: coordinatedURL.path)
                    self.logger.info("📁 Directory contents count: \(contents.count)")
                    if contents.isEmpty {
                        self.logger.warning("⚠️ Directory is empty: \(coordinatedURL.path)")
                    } else {
                        self.logger.info("📄 Directory contents: \(contents.prefix(5).joined(separator: ", "))\(contents.count > 5 ? "..." : "")")
                    }
                } catch {
                    self.logger.error("❌ Could not read directory contents: \(error.localizedDescription)")
                    throw error
                }
                
                guard let enumerator = FileManager.default.enumerator(
                    at: coordinatedURL,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    self.logger.error("❌ Could not create file enumerator for: \(coordinatedURL.path)")
                    throw NSError(domain: "FTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not enumerate directory"])
                }
                
                var fileCount = 0
                for case let fileURL as URL in enumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if resourceValues.isDirectory != true {
                            // This is a file, not a directory
                            let relativePath = String(fileURL.path.dropFirst(coordinatedURL.path.count + 1))
                            fileMap[relativePath] = fileURL
                            fileCount += 1
                            
                            if fileCount <= 5 {
                                self.logger.info("📄 Found file: \(relativePath)")
                            }
                        }
                    } catch {
                        self.logger.warning("⚠️ Could not get resource values for: \(fileURL.path) - \(error.localizedDescription)")
                    }
                }
                
                self.logger.info("📊 Total files collected: \(fileMap.count)")
            }
        } catch {
            self.logger.error("❌ Failed to access files: \(error.localizedDescription)")
            throw error
        }
        
        return fileMap
    }
    
    /// Enhanced file comparison with size and name matching
    private func compareFileEnhanced(fileName: String, localSize: Int64, existingFiles: [String: FileObject]) -> FileComparisonResult {
        guard let remoteFile = existingFiles[fileName] else {
            return .new
        }
        
        // Compare both size and name
        return (localSize == remoteFile.size && fileName == remoteFile.name) ? .unchanged : .updated
    }
    
    /// Senkronizasyon sonuç raporu
    struct SyncResult {
        var newFiles: Int = 0          // Yeni kopyalanan
        var updatedFiles: Int = 0      // Güncellenen 
        var skippedFiles: Int = 0      // Pas geçilen (aynı)
        var deletedFiles: Int = 0      // Silinen
        var totalBytes: Int64 = 0      // Toplam işlenen byte
        
        var totalProcessed: Int {
            return newFiles + updatedFiles + skippedFiles
        }
    }
    
    /// Dosya karşılaştırma sonucu
    private enum FileComparisonResult {
        case new           // Hedefte yok, kopyalanacak
        case updated       // Hedefte var ama farklı boyut, güncellenecek
        case unchanged     // Hedefte var ve aynı boyut, pas geçilecek
    }
    
    /// Photo library için senkronize yedekleme
    private func syncBackupPhotoLibrary(mediaType: MediaType, progressHandler: ((Double) -> Void)? = nil) async throws -> SyncResult {
        let photoManager = PhotoLibraryManager.shared
        var result = SyncResult()
        
        // Get photos based on media type
        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count
        
        print("📸 BackupFlow: \(totalCount) medya dosyası bulundu")
        
        // Create photos directory if it doesn't exist
        let photosDir = "photos"
        do {
            try await createDirectory(at: photosDir)
            print("📁 BackupFlow: Photos klasörü hazır: \(photosDir)")
        } catch {
            print("⚠️ BackupFlow: Photos klasörü oluşturma hatası (devam edilecek): \(error)")
        }
        
        // Get all existing files on FTP using enhanced listing
        let existingFileMap = try await listAllFiles(at: photosDir)
        logger.info("Found \(existingFileMap.count) existing photo files on FTP")
        
        // Process local assets
        for (index, asset) in assets.enumerated() {
            guard !isCancelled else { break }
            
            // Generate simple filename without special characters
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = asset.creationDate ?? Date()
            let dateString = dateFormatter.string(from: date)
            
            let fileExtension = asset.mediaType == .image ? "jpg" : "mp4"
            let safeFileName = "\(dateString)_\(String(index + 1).padding(toLength: 3, withPad: "0", startingAt: 0)).\(fileExtension)"
            
            // Get photo data to check size
            guard let data = try await photoManager.getAssetData(asset: asset) else {
                print("⚠️ BackupFlow: Asset verisi alınamadı: \(asset.localIdentifier)")
                continue
            }
            
            let localSize = Int64(data.count)
            let remotePath = "\(photosDir)/\(safeFileName)"
            
            // Enhanced comparison with size and name matching
            let comparisonResult = compareFileEnhanced(
                fileName: safeFileName,
                localSize: localSize,
                existingFiles: existingFileMap
            )
            
            switch comparisonResult {
            case .unchanged:
                result.skippedFiles += 1
                result.totalBytes += localSize
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Atlandı: \(safeFileName)"
                }
                print("⏭ BackupFlow: Aynı dosya pas geçildi: \(safeFileName) (\(formatBytes(localSize)))")
                
            case .new:
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Yükleniyor: \(safeFileName)"
                }
                try await uploadPhotoData(data: data, remotePath: remotePath, fileName: safeFileName)
                result.newFiles += 1
                result.totalBytes += localSize
                print("📤 BackupFlow: Yeni dosya yüklendi: \(safeFileName) (\(formatBytes(localSize)))")
                
            case .updated:
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Güncelleniyor: \(safeFileName)"
                }
                try await uploadPhotoData(data: data, remotePath: remotePath, fileName: safeFileName)
                result.updatedFiles += 1
                result.totalBytes += localSize
                print("🔄 BackupFlow: Güncellenmiş dosya yüklendi: \(safeFileName) (\(formatBytes(localSize)))")
            }
            
            // Update progress
            let progress = Double(index + 1) / Double(totalCount)
            progressHandler?(progress)
        }
        
        // Delete orphaned files (files on FTP that don't exist locally)
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
                    try await deleteFile(at: fullRemotePath)
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
    
    /// Helper function to upload photo data
    private func uploadPhotoData(data: Data, remotePath: String, fileName: String, progressHandler: ((Double) -> Void)? = nil) async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        // Update current file being processed
        Task { @MainActor in
            self.currentFile = "Yükleniyor: \(fileName)"
        }
        
        try await uploadFile(localURL: tempURL, remotePath: remotePath, progressHandler: progressHandler)
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    /// Dosya karşılaştırma fonksiyonu
    private func compareFile(fileName: String, localSize: Int64, existingFiles: [String: Int64]) -> FileComparisonResult {
        guard let remoteSize = existingFiles[fileName] else {
            return .new
        }
        
        return localSize == remoteSize ? .unchanged : .updated
    }
    
    /// Enhanced directory sync with full mirror functionality (upload new, skip identical, delete orphans)
    private func syncUploadDirectory(localURL: URL, remotePath: String = "", progressHandler: ((Double) -> Void)? = nil) async throws -> SyncResult {
        guard !isCancelled else {
            throw FTPError.fileOperationFailed
        }
        
        guard ftpProvider != nil else {
            throw FTPError.connectionFailed
        }
        
        var result = SyncResult()
        let localPath = localURL.path
        
        logger.info("Starting enhanced mirror sync: \(localPath) -> \(remotePath)")
        
        // Create remote directory if needed
        if !remotePath.isEmpty {
            try await createDirectory(at: remotePath)
        }
        
        // Collect local files recursively with their relative paths
        let localFileMap = try collectLocalFiles(from: localPath)
        let totalFiles = localFileMap.count
        
        logger.info("Found \(totalFiles) local files to sync")
        
        // Get all remote files with their relative paths
        let remoteBasePath = remotePath.isEmpty ? "/" : remotePath
        let remoteFileMap = try await listAllFiles(at: remoteBasePath)
        
        logger.info("Found \(remoteFileMap.count) remote files")
        
        var uploadedCount = 0, skippedCount = 0, failedCount = 0, deletedCount = 0
        var transferredBytes: Int64 = 0
        
        // Phase 1: Upload/update files from local to remote (80% of progress)
        for (index, (relativePath, localFileURL)) in localFileMap.enumerated() {
            guard !isCancelled else { break }
            
            let targetPath = remotePath.isEmpty ? relativePath : "\(remotePath)/\(relativePath)"
            
            // Ensure parent directories exist
            let parentPath = (targetPath as NSString).deletingLastPathComponent
            if !parentPath.isEmpty && parentPath != "/" {
                try await createDirectory(at: parentPath)
            }
            
            let resourceValues = try localFileURL.resourceValues(forKeys: [.fileSizeKey])
            let localSize = Int64(resourceValues.fileSize ?? 0)
            let fileName = localFileURL.lastPathComponent
            
            // Check if remote file exists and compare size and name
            let comparisonResult = compareFileEnhanced(
                fileName: fileName,
                localSize: localSize,
                existingFiles: remoteFileMap
            )
            
            switch comparisonResult {
            case .unchanged:
                result.skippedFiles += 1
                result.totalBytes += localSize
                skippedCount += 1
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Atlandı: \(fileName)"
                }
                logger.debug("Skipping identical file: \(relativePath) (\(ByteCountFormatter.string(fromByteCount: localSize, countStyle: .file)))")
                
            case .new:
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Yükleniyor: \(fileName)"
                }
                try await uploadFile(localURL: localFileURL, remotePath: targetPath, progressHandler: nil)
                result.newFiles += 1
                result.totalBytes += localSize
                transferredBytes += localSize
                uploadedCount += 1
                logger.debug("Successfully uploaded new file: \(relativePath)")
                
            case .updated:
                // Update current file status
                Task { @MainActor in
                    self.currentFile = "Güncelleniyor: \(fileName)"
                }
                try await uploadFile(localURL: localFileURL, remotePath: targetPath, progressHandler: nil)
                result.updatedFiles += 1
                result.totalBytes += localSize
                transferredBytes += localSize
                uploadedCount += 1
                logger.debug("Successfully updated file: \(relativePath)")
            }
            
            // Update progress
            let progress = Double(index + 1) / Double(max(totalFiles, 1)) * 0.8
            progressHandler?(progress)
        }
        
        // Phase 2: Delete orphaned files from remote (80-100% of progress)
        logger.info("Checking for orphaned files to delete...")
        let localRelativePaths = Set(localFileMap.keys)
        
        for (remotePath, _) in remoteFileMap {
            if !localRelativePaths.contains(remotePath) {
                // This remote file doesn't exist in local - delete it
                let fullRemotePath = remoteBasePath == "/" ? "/\(remotePath)" : "\(remoteBasePath)/\(remotePath)"
                
                do {
                    logger.info("Deleting orphaned file: \(remotePath)")
                    try await deleteFile(at: fullRemotePath)
                    result.deletedFiles += 1
                    deletedCount += 1
                    logger.debug("Successfully deleted orphaned file: \(remotePath)")
                } catch {
                    logger.error("Failed to delete orphaned file \(remotePath): \(error.localizedDescription)")
                }
            }
        }
        
        progressHandler?(1.0) // 100% complete
        
        // Print detailed sync report
        print("✅ BackupFlow: FTP enhanced mirror sync completed")
        print("   📊 Sync Report:")
        print("   📤 New files uploaded: \(result.newFiles)")
        print("   🔄 Files updated: \(result.updatedFiles)")
        print("   ⏭ Files skipped (identical): \(result.skippedFiles)")
        print("   🗑 Orphaned files deleted: \(result.deletedFiles)")
        print("   ❌ Failed operations: \(failedCount)")
        print("   💾 Total data transferred: \(formatBytes(transferredBytes))")
        
        logger.info("Enhanced mirror sync completed - Uploaded: \(uploadedCount), Skipped: \(skippedCount), Failed: \(failedCount), Deleted: \(deletedCount)")
        
        return result
    }
    
    // FTP sunucusundan dosya sil
func deleteFile(at path: String) async throws {
        guard let ftp = ftpProvider else {
            throw FTPError.connectionFailed
        }
        
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
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> SyncResult {
        
        print("📡 BackupFlow: FTP senkronize yedekleme başlatılıyor - \(host):\(port)")
        
        // Check if we're in background mode
        let isBackgroundMode: Bool = {
            #if canImport(UIKit)
            return UIApplication.shared.applicationState != .active
            #else
            return false
            #endif
        }()
        if isBackgroundMode {
            // Background mode: Set up for background session
            let backgroundId = "BackupFlow.FTP.Background.\(UUID().uuidString)"
            self.backgroundSessionIdentifier = backgroundId
            self.isBackgroundUploading = true
            self.logger.info("📱 Background FTP session created: \(backgroundId)")
        } else {
            self.isBackgroundUploading = false
        }
        
        // Connect to FTP server
        let actualUsername = isAnonymous ? nil : username
        let actualPassword = isAnonymous ? nil : password
        
        try await connect(host: host, port: port, username: actualUsername, password: actualPassword)
        
        let syncResult: SyncResult
        
        if sourcePath == "PHOTOS_LIBRARY" {
            // Photo library sync backup
            syncResult = try await syncBackupPhotoLibrary(mediaType: mediaType, progressHandler: progressHandler)
        } else {
            // Directory sync backup - preserve source folder name
            let sourceURL = URL(fileURLWithPath: sourcePath)
            let sourceFolderName = sourceURL.lastPathComponent
            syncResult = try await syncUploadDirectory(localURL: sourceURL, remotePath: sourceFolderName, progressHandler: progressHandler)
        }
        
        // Print detailed report
        print("✅ BackupFlow: FTP senkronize yedekleme tamamlandı")
        print("   📊 Yedekleme Raporu:")
        print("   📤 Yeni dosya kopyalandı: \(syncResult.newFiles)")
        print("   🔄 Dosya güncellendi: \(syncResult.updatedFiles)")
        print("   ⏭ Aynı dosya pas geçildi: \(syncResult.skippedFiles)")
        print("   🗑 Dosya silindi: \(syncResult.deletedFiles)")
        print("   📈 Toplam işlenen: \(syncResult.totalProcessed)")
        print("   💾 Toplam boyut: \(formatBytes(syncResult.totalBytes))")
        
        return syncResult
    }
    
    private func backupPhotoLibrary(mediaType: MediaType, progressHandler: ((Double) -> Void)? = nil) async throws {
        let photoManager = PhotoLibraryManager.shared
        
        // Get photos based on media type
        let assets = try await photoManager.getAllAssets(mediaType: mediaType)
        let totalCount = assets.count
        
        print("📸 BackupFlow: \(totalCount) medya dosyası bulundu")
        
        // Create photos directory if it doesn't exist
        let photosDir = "photos"
        do {
            try await createDirectory(at: photosDir)
            print("📁 BackupFlow: Photos klasörü hazır: \(photosDir)")
        } catch {
            print("⚠️ BackupFlow: Photos klasörü oluşturma hatası (devam edilecek): \(error)")
        }
        
        for (index, asset) in assets.enumerated() {
            // Get photo data
            guard let data = try await photoManager.getAssetData(asset: asset) else {
                print("⚠️ BackupFlow: Asset verisi alınamadı: \(asset.localIdentifier)")
                continue
            }
            
            // Generate simple filename without special characters
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let date = asset.creationDate ?? Date()
            let dateString = dateFormatter.string(from: date)
            
            let fileExtension = asset.mediaType == .image ? "jpg" : "mp4"
            let safeFileName = "\(dateString)_\(String(index + 1).padding(toLength: 3, withPad: "0", startingAt: 0)).\(fileExtension)"
            let remotePath = "\(photosDir)/\(safeFileName)"
            
            // Upload to FTP
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeFileName)
            try data.write(to: tempURL)
            
            try await uploadFile(localURL: tempURL, remotePath: remotePath) { fileProgress in
                let overallProgress = (Double(index) + fileProgress) / Double(totalCount)
                progressHandler?(overallProgress)
            }
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
            // Update progress
            let progress = Double(index + 1) / Double(totalCount)
            progressHandler?(progress)
            
            print("✅ BackupFlow: Yüklendi: \(safeFileName) (\(index + 1)/\(totalCount))")
        }
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

