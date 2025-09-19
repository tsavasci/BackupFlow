import Foundation
import FilesProvider
import OSLog

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
final class FTPService: NSObject, @unchecked Sendable {
    static let shared = FTPService()
    private let logger = Logger(subsystem: "com.example.Yedekle2", category: "FTPService")

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

            return try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    return try await withCheckedThrowingContinuation { continuation in
                        testProvider.contentsOfDirectory(path: "/") { [weak self] _, error in
                            Task { @MainActor in
                                if let error = error {
                                    continuation.resume(throwing: self?.mapError(error) ?? FTPError.unknown(error))
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

    private func disconnect() {
        lock.lock()
        defer { lock.unlock() }
        
        if _currentTask != nil {
            _currentTask?.cancel()
            _currentTask = nil
        }
        
        if _ftpProvider != nil {
            _ftpProvider = nil
        }
        isCancelled = false
    }
    
    func connect(host: String, port: Int, username: String? = nil, password: String? = nil) async throws {
        // Önce mevcut bağlantıyı temizle
        disconnect()
        
        // FTP parametrelerini kontrol et
        guard !host.isEmpty else {
            logger.error("FTP sunucu adresi boş olamaz")
            throw FTPError.invalidURL
        }
        
        // IP adresi veya hostname kontrolü
        let hostParts = host.split(separator: ".")
        if hostParts.count != 4 {
            logger.error("Geçersiz IP adresi formatı: \(host)")
            throw FTPError.invalidURL
        }
        
        // Port kontrolü
        guard port > 0 && port < 65536 else {
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
        }        // Bağlantıyı test et
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
                        logger.info("Dosya atlanıyor (zaten var): \(relativePath)")
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
            logger.info("İşlem iptal edildiği için yükleme iptal edildi")
            throw FTPError.fileOperationFailed
        }
        
        guard let ftp = ftpProvider else {
            logger.error("FTP bağlantısı kurulamamış")
            throw FTPError.connectionFailed
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
                    continuation.resume(throwing: self.mapError(error))
                } else {
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
}

