import Foundation
import BackgroundTasks
import OSLog
import SwiftUI
import SwiftData
import Combine
import UserNotifications
import UniformTypeIdentifiers
import Photos

@MainActor
final class BackupScheduler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    // MARK: - Singleton & Properties
    static let shared = BackupScheduler()
    
    // Shared ModelContainer - uygulamadan inject edilecek
    static var sharedModelContainer: ModelContainer?
    
    private let logger = Logger(subsystem: "com.backupflow.app", category: "BackupScheduler")
    private let appGroupID: String
    private let backgroundSessionIdentifier: String
    
    // Background URLSession
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()
    
    // Timers keyed by BackupTask.id
    @MainActor private var scheduledTimers: [UUID: Timer] = [:]
    
    private lazy var turkeyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.locale = Locale(identifier: "tr_TR")
        return f
    }()
    
    private struct TaskIdentifiers {
        static func refresh(_ bundle: String) -> String { bundle + ".refresh" }
        static func processing(_ bundle: String) -> String { bundle + ".processing" }
    }
    
    private let maxRetryAttempts = 3
    private var retryCount: [UUID: Int] = [:]
    private var lastScheduledTime: Date?
    
    @Published private(set) var isProcessing = false
    private var hasRegisteredBackgroundTasks = false
    
    private let ftpService = FTPService.shared
    private let photoLibraryManager = PhotoLibraryManager.shared
    private let defaultFTPHost = "192.168.1.1"
    private let fileManager = FileManager.default
    
    // Computed identifiers (fallbacks if bundle id missing)
    private var bundleID: String { Bundle.main.bundleIdentifier ?? "com.backupflow.app" }
    private var taskIdentifierRefresh: String { TaskIdentifiers.refresh(bundleID) }
    private var taskIdentifierProcessing: String { TaskIdentifiers.processing(bundleID) }
    
    // Background completion handler for URLSession
    public var backgroundCompletionHandler: (() -> Void)? = nil
    
    // MARK: - Init / Deinit
    private override init() {
        // safe appGroup and background identifier
        let b = Bundle.main.bundleIdentifier ?? "com.BackupFlow.app"
        // App Group ID'sini entitlements dosyasındaki ile eşleştir
        self.appGroupID = "group.tsavasci.BackupFlow"
        self.backgroundSessionIdentifier = b + ".background"
        super.init()
        setupNotifications()
        // Register background tasks (it's safe to call at app launch)
        registerBackgroundTasks()
    }
    
    deinit {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    
    // MARK: - Background Task Registration
    public func registerBackgroundTasks() {
        guard !hasRegisteredBackgroundTasks else {
            logger.info("Görevler zaten kayıtlı")
            return
        }
        
        BGTaskScheduler.shared.cancelAllTaskRequests()
        
        let refreshID = taskIdentifierRefresh
        let processingID = taskIdentifierProcessing
        
        let refreshSuccess = BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) { [weak self] task in
            guard let self = self else { task.setTaskCompleted(success: false); return }
            guard let appRefreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            self.handleAppRefresh(appRefreshTask)
        }
        
        let processingSuccess = BGTaskScheduler.shared.register(forTaskWithIdentifier: processingID, using: nil) { [weak self] task in
            guard let self = self else { task.setTaskCompleted(success: false); return }
            guard let processingTask = task as? BGProcessingTask else { task.setTaskCompleted(success: false); return }
            self.handleBackgroundProcessing(processingTask)
        }
        
        if refreshSuccess && processingSuccess {
            hasRegisteredBackgroundTasks = true
            print("✅ BackupFlow: Background görevler başarıyla kaydedildi")
            logger.info("Görevler başarıyla kaydedildi")
        } else {
            print("❌ BackupFlow: Background görev kayıtları başarısız - refresh: \(refreshSuccess), processing: \(processingSuccess)")
            logger.error("Görev kayıtları başarısız")
        }
    }
    
    // MARK: - Scheduling
    public func scheduleAppRefresh(for date: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifierRefresh)
        let target = date ?? Date().addingTimeInterval(60)
        request.earliestBeginDate = target
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Yenileme görevi planlandı (Türkiye): \(self.turkeyDateFormatter.string(from: target))")
        } catch {
            logger.error("Yenileme görevi planlanamadı: \(error.localizedDescription)")
        }
    }
    
    public func scheduleBackgroundProcessing(for date: Date? = nil) {
        let request = BGProcessingTaskRequest(identifier: taskIdentifierProcessing)
        let target = date ?? Date().addingTimeInterval(60)
        request.earliestBeginDate = target
        request.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("İşleme görevi planlandı (Türkiye): \(self.turkeyDateFormatter.string(from: target))")
        } catch {
            logger.error("İşleme görevi planlanamadı: \(error.localizedDescription)")
        }
    }
    
    // Schedule a specific BackupTask using a Timer (for in-app scheduling)
    func scheduleBackup(task: BackupTask) async throws {
        print("🚀 BackupFlow: scheduleBackup başlatıldı - Görev: \(task.displayName)")
        task.isEnabled = true
        updateNextRunTime(for: task)
        
        // Invalidate old timer
        scheduledTimers[task.id]?.invalidate()
        scheduledTimers[task.id] = nil
        
        guard let nextRun = task.nextRunTime else {
            print("📝 BackupFlow: Manuel görev kaydedildi - \(task.displayName)")
            logger.info("Manuel görev kaydedildi: \(task.displayName)")
            return
        }
        
        let taskId = task.id
        let displayName = task.displayName
        print("⏰ BackupFlow: Zamanlayıcı kurulacak - Görev: \(displayName), Sonraki çalışma: \(nextRun)")
        
        let timer = Timer(fire: nextRun, interval: 0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🎬 BackupFlow: Zamanlayıcı tetiklendi - Görev: \(displayName)")
            Task { @MainActor in
                do {
                    let container = try self.getModelContainer()
                    let context = ModelContext(container)
                    
                    // Context'i refresh et
                    try context.save() // Pending changes'i temizle
                    
                    let descriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { t in
                        t.id == taskId
                    })
                    let results = try context.fetch(descriptor)
                    print("🔍 BackupFlow: Görev arama sonucu - ID: \(taskId), Bulunan: \(results.count)")
                    
                    if results.isEmpty {
                        // Alternatif arama: displayName ile
                        print("⚠️ BackupFlow: ID ile bulunamadı, displayName ile aranıyor: \(displayName)")
                        let nameDescriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { t in
                            t.displayName == displayName
                        })
                        let nameResults = try context.fetch(nameDescriptor)
                        
                        if let taskByName = nameResults.first {
                            print("✅ BackupFlow: Görev displayName ile bulundu: \(taskByName.displayName)")
                            self.logger.info("Görev displayName ile bulundu: \(taskByName.displayName)")
                            try await self.performBackup(task: taskByName)
                            try await self.scheduleBackup(task: taskByName)
                            return
                        }
                        
                        print("❌ BackupFlow: Görev bulunamadı - ID: \(taskId), Name: \(displayName)")
                        self.logger.error("Görev bulunamadı: ID=\(taskId), Name=\(displayName)")
                        
                        // Debug: Mevcut tüm görevleri listele
                        let allTasks = try context.fetch(FetchDescriptor<BackupTask>())
                        print("📋 BackupFlow: Mevcut görevler (\(allTasks.count)):")
                        self.logger.info("Mevcut görevler (\(allTasks.count)):")
                        for task in allTasks {
                            print("   - \(task.displayName) (ID: \(task.id))")
                            self.logger.info("  - \(task.displayName) (ID: \(task.id))")
                        }
                        return
                    }
                    
                    guard let reloaded = results.first else {
                        print("❌ BackupFlow: Görev yüklenemedi: \(taskId)")
                        self.logger.error("Görev bulunamadı: \(taskId)")
                        return
                    }
                    
                    print("🎯 BackupFlow: Görev bulundu, yedekleme başlatılacak: \(reloaded.displayName)")
                    try await self.performBackup(task: reloaded)
                    try await self.scheduleBackup(task: reloaded)
                } catch {
                    print("💥 BackupFlow: Yedekleme hatası: \(error.localizedDescription)")
                    self.logger.error("Yedekleme hatası: \(error.localizedDescription)")
                }
            }
        }
        
        scheduledTimers[task.id] = timer
        RunLoop.main.add(timer, forMode: .common)
        print("✅ BackupFlow: Görev planlandı - \(displayName), Sonraki çalışma (Türkiye): \(self.turkeyDateFormatter.string(from: nextRun))")
        logger.info("Yedekleme görevi planlandı: \(displayName) - Sonraki çalışma (Türkiye): \(self.turkeyDateFormatter.string(from: nextRun))")
    }
    
    private func scheduleNextTasks(for task: BackupTask) async throws {
        guard let nextRun = task.nextRunTime else { return }
        if let last = lastScheduledTime, Date().timeIntervalSince(last) < 60 { return }
        let timeInterval = nextRun.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        scheduleAppRefresh(for: nextRun)
        scheduleBackgroundProcessing(for: nextRun)
        lastScheduledTime = Date()
        logger.info("Görevler planlandı (Türkiye): \(self.turkeyDateFormatter.string(from: nextRun))")
    }
    
    // MARK: - Next run calculation
    private func updateNextRunTime(for task: BackupTask) {
        guard task.frequency != .manual else { return }
        let calendar = Calendar.current
        let now = Date()
        switch task.frequency {
        case .daily(let time):
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = time.hour
            components.minute = time.minute
            if var nextDate = calendar.date(from: components) {
                if nextDate <= now { nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate }
                task.nextRunTime = nextDate
                logger.info("Sonraki çalışma zamanı (Türkiye): \(self.turkeyDateFormatter.string(from: nextDate))")
            }
        case .weekly(let day, let time):
            var components = DateComponents()
            components.weekday = day
            components.hour = time.hour
            components.minute = time.minute
            if let nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) {
                task.nextRunTime = nextDate
                logger.info("Sonraki çalışma zamanı (Türkiye): \(self.turkeyDateFormatter.string(from: nextDate))")
            }
        case .manual:
            break
        }
    }
    
    // MARK: - Task Handlers
    func handleAppRefresh(_ task: BGAppRefreshTask) {
        logger.info("Yenileme görevi başladı")
        task.expirationHandler = { [weak self] in
            self?.logger.warning("Yenileme görevi zaman aşımına uğradı")
            task.setTaskCompleted(success: false)
        }
        Task {
            do {
                let container = try getModelContainer()
                let context = ModelContext(container)
                try await performScheduledBackups(context: context)
                task.setTaskCompleted(success: true)
                logger.info("Yenileme görevi başarıyla tamamlandı")
            } catch {
                logger.error("Yenileme görevi başarısız: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    func handleBackgroundProcessing(_ task: BGProcessingTask) {
        logger.info("İşleme görevi başladı")
        task.expirationHandler = { [weak self] in
            self?.logger.warning("İşleme görevi zaman aşımına uğradı")
            task.setTaskCompleted(success: false)
        }
        Task {
            do {
                let container = try getModelContainer()
                let context = ModelContext(container)
                try await performScheduledBackups(context: context)
                task.setTaskCompleted(success: true)
                logger.info("İşleme görevi başarıyla tamamlandı")
            } catch {
                logger.error("İşleme görevi başarısız: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Perform backups
    private func performScheduledBackups(context: ModelContext) async throws {
        let now = Date()
        
        // Context'i refresh et
        try context.save() // Pending changes'i temizle
        
        let descriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { task in
            task.isEnabled && (task.nextRunTime == nil || task.nextRunTime! <= now)
        })
        let tasks = try context.fetch(descriptor)
        logger.info("Yedeklenecek görev sayısı: \(tasks.count)")
        
        if tasks.isEmpty {
            // Debug: Tüm görevleri listele
            let allTasks = try context.fetch(FetchDescriptor<BackupTask>())
            logger.info("Toplam görev sayısı: \(allTasks.count)")
            for task in allTasks {
                let nextRunStr = task.nextRunTime?.formatted() ?? "nil"
                logger.info("  - \(task.displayName): enabled=\(task.isEnabled), nextRun=\(nextRunStr)")
            }
        }
        
        for task in tasks {
            do { try await performBackup(task: task) }
            catch {
                logger.error("Yedekleme başarısız: \(task.displayName) - \(error.localizedDescription)")
                // Continue with next task instead of throwing to attempt other tasks
            }
        }
    }
    
    func performBackup(task: BackupTask) async throws {
        print("🚀 BackupFlow: performBackup başlatıldı - Görev: \(task.displayName)")
        let container = try getModelContainer()
        let context = ModelContext(container)
        let startTime = Date()
        
        // Task'ı doğru context'e yeniden attach edelim
        let taskId = task.id
        let taskDescriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { t in
            t.id == taskId
        })
        let tasks = try context.fetch(taskDescriptor)
        guard let contextTask = tasks.first else {
            print("❌ BackupFlow: Görev context'te bulunamadı: \(task.id)")
            logger.error("Perform backup: Görev context'te bulunamadı: \(task.id)")
            throw BackupError.invalidSourceURL
        }
        
        print("🔄 BackupFlow: Backup başlatılıyor: \(contextTask.displayName)")
        logger.info("Backup başlatılıyor: \(contextTask.displayName)")
        contextTask.backupStatus = .preparing
        contextTask.progress = 0
        contextTask.currentFile = nil
        contextTask.lastError = nil
        try context.save()
        
        // FTP bağlantısını kur
        guard !contextTask.ftpHost.isEmpty else {
            print("❌ BackupFlow: FTP sunucu adresi boş")
            contextTask.backupStatus = .failed
            contextTask.lastError = "FTP sunucu adresi gerekli"
            try context.save()
            throw BackupError.invalidSourceURL
        }
        
        do {
            print("📡 BackupFlow: FTP bağlantısı kuruluyor: \(contextTask.ftpHost):\(contextTask.ftpPort)")
            logger.info("FTP bağlantısı kuruluyor: \(contextTask.ftpHost):\(contextTask.ftpPort)")
            try await ftpService.connect(host: contextTask.ftpHost, port: contextTask.ftpPort, username: contextTask.ftpUsername, password: contextTask.ftpPassword)
            print("✅ BackupFlow: FTP bağlantısı başarılı")
            logger.info("FTP bağlantısı başarılı")
            
            // Görev ID bazlı klasör adı
            let remoteDirectory = "backup_\(contextTask.id.uuidString)"
            print("📁 BackupFlow: Hedef klasör: \(remoteDirectory)")
            
            // Check if we're backing up photos or a directory
            if contextTask.sourcePath == "PHOTOS_LIBRARY" {
                print("📷 BackupFlow: Fotoğraf kütüphanesi yedeklemesi başlatılıyor")
                try await performSynchronizedPhotoLibraryBackup(task: contextTask, context: context, remoteDirectory: remoteDirectory, startTime: startTime)
                return
            }
            
            // Handle directory backup
            print("📁 BackupFlow: Klasör yedeklemesi başlatılıyor: \(contextTask.sourcePath)")
            try await performSynchronizedDirectoryBackup(task: contextTask, context: context, remoteDirectory: remoteDirectory, startTime: startTime)
            
        } catch {
            let errorMessage = error.localizedDescription
            logger.error("Yedekleme hatası (\(contextTask.displayName)): \(errorMessage)")
            
            contextTask.backupStatus = .failed
            contextTask.lastError = errorMessage
            try? context.save()
            
            // Hata tipine göre daha spesifik mesajlar
            if errorMessage.contains("Network is down") || errorMessage.contains("network connection was lost") {
                await sendNotification(title: "Ağ Bağlantı Hatası", body: "FTP sunucusuna bağlanılamıyor. Ağ bağlantınızı kontrol edin.")
            } else if errorMessage.contains("authentication") || errorMessage.contains("login") {
                await sendNotification(title: "Kimlik Doğrulama Hatası", body: "FTP kullanıcı adı veya şifrenizi kontrol edin.")
            } else {
                await sendNotification(title: "Yedekleme Başarısız", body: "\(contextTask.displayName) yedeklemesi başarısız oldu: \(errorMessage)")
            }
            
            throw error
        }
    }
    
    // MARK: - Synchronized Photo Library Backup
    
    private func performSynchronizedPhotoLibraryBackup(task: BackupTask, context: ModelContext, remoteDirectory: String, startTime: Date) async throws {
        // Request photo library access if not already granted
        if photoLibraryManager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                photoLibraryManager.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
        
        guard photoLibraryManager.hasAccess else {
            task.backupStatus = .failed
            task.lastError = "Fotoğraf kütüphanesine erişim izni verilmedi"
            try context.save()
            throw BackupError.permissionDenied
        }
        
        task.backupStatus = .scanning
        try context.save()
        
        // Fetch all photos
        let assets: [PHAsset] = await withCheckedContinuation { continuation in
            photoLibraryManager.fetchAllPhotos { assets in
                continuation.resume(returning: assets)
            }
        }
        
        logger.info("\(assets.count) adet fotoğraf bulundu")
        
        guard !assets.isEmpty else {
            task.backupStatus = .completed
            task.progress = 1.0
            task.lastBackupDate = Date()
            try context.save()
            return
        }
        
        // FTP üzerindeki hedef dizini oluştur
        try await ftpService.createDirectory(at: remoteDirectory)
        
        // FTP'deki mevcut dosyaları listele
        let existingFiles = try await ftpService.listFiles(in: remoteDirectory)
        logger.info("FTP'de \(existingFiles.count) mevcut dosya bulundu")
        
        // Yerel fotoğraflardan dosya bilgilerini topla
        var localPhotos: [(asset: PHAsset, fileName: String, estimatedSize: Int64)] = []
        
        for asset in assets {
            let fileName = "\(asset.localIdentifier.replacingOccurrences(of: "/", with: "_")).jpg"
            // Tahmini dosya boyutu (gerçek boyut upload sırasında hesaplanacak)
            let estimatedSize = Int64(asset.pixelWidth * asset.pixelHeight * 3 / 2) // Ortalama JPEG sıkıştırma oranı
            localPhotos.append((asset: asset, fileName: fileName, estimatedSize: estimatedSize))
        }
        
        // Senkronizasyon: FTP'de olup yerel galeriden silinen dosyaları bul ve sil
        let localFileNames = Set(localPhotos.map { $0.fileName })
        let filesToDelete = existingFiles.filter { !localFileNames.contains($0.name) }
        
        logger.info("\(filesToDelete.count) dosya FTP'den silinecek")
        for fileToDelete in filesToDelete {
            let remotePath = "\(remoteDirectory)/\(fileToDelete.name)"
            logger.info("Siliniyor: \(fileToDelete.name)")
            try await ftpService.deleteFile(at: remotePath)
        }
        
        // Upload edilecek dosyaları belirle (yeni veya değişmiş olanlar)
        var photosToUpload: [(asset: PHAsset, fileName: String)] = []
        
        for localPhoto in localPhotos {
            // Aynı isim ve boyutta dosya var mı kontrol et
            let existingFile = existingFiles.first { $0.name == localPhoto.fileName }
            
            if existingFile != nil {
                // Boyut kontrolü (tam boyut upload sırasında kontrol edilecek)
                logger.info("Dosya zaten var, boyut kontrolü yapılacak: \(localPhoto.fileName)")
                // Şu an için tüm dosyaları yükle listesine ekle, boyut kontrolü upload sırasında yapılacak
                photosToUpload.append((asset: localPhoto.asset, fileName: localPhoto.fileName))
            } else {
                // Yeni dosya
                logger.info("Yeni dosya: \(localPhoto.fileName)")
                photosToUpload.append((asset: localPhoto.asset, fileName: localPhoto.fileName))
            }
        }
        
        logger.info("\(photosToUpload.count) fotoğraf işlenecek")
        
        task.backupStatus = .uploading
        try context.save()
        
        // Create a temporary directory for the photo backup
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("PhotoBackup_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            // Clean up temporary directory
            try? fileManager.removeItem(at: tempDir)
        }
        
        var uploadedCount = 0
        var skippedCount = 0
        var totalBytes: Int64 = 0
        
        // Upload each photo
        for (index, photoInfo) in photosToUpload.enumerated() {
            guard task.backupStatus != .cancelled else { break }
            
            let asset = photoInfo.asset
            let fileName = photoInfo.fileName
            let localURL = tempDir.appendingPathComponent(fileName)
            let remotePath = "\(remoteDirectory)/\(fileName)"
            
            // Update progress
            let progress = Double(index) / Double(photosToUpload.count)
            await MainActor.run {
                task.progress = progress
                task.currentFile = fileName
                try? context.save()
            }
            
            // Request image data
            let imageData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    guard let imageData = data else {
                        continuation.resume(throwing: NSError(domain: "PhotoLibraryError", code: -1, 
                                          userInfo: [NSLocalizedDescriptionKey: "Fotoğraf verisi alınamadı: \(fileName)"]))
                        return
                    }
                    continuation.resume(returning: imageData)
                }
            }
            
            // Save to temp file
            try imageData.write(to: localURL)
            let actualSize = Int64(imageData.count)
            
            // Boyut kontrolü yap - aynı boyutta dosya var mı?
            if let existingFile = existingFiles.first(where: { $0.name == fileName }) {
                if existingFile.size == actualSize {
                    logger.info("Dosya atlanıyor (aynı boyut): \(fileName) (\(actualSize) bytes)")
                    try? fileManager.removeItem(at: localURL)
                    skippedCount += 1
                    continue
                }
            }
            
            // Upload to FTP
            do {
                try await ftpService.uploadFile(localURL: localURL, remotePath: remotePath)
                logger.info("Fotoğraf yüklendi: \(fileName) (\(actualSize) bytes)")
                uploadedCount += 1
                totalBytes += actualSize
            } catch {
                logger.error("Fotoğraf yüklenemedi: \(fileName) - \(error.localizedDescription)")
                throw error
            }
            
            // Clean up temp file
            try? fileManager.removeItem(at: localURL)
        }
        
        // Backup tamamlandı
        let duration = Date().timeIntervalSince(startTime)
        task.backupStatus = .completed
        task.progress = 1.0
        task.currentFile = nil
        task.lastBackupDate = Date()
        updateNextRunTime(for: task)
        
        let history = BackupHistory(
            timestamp: Date(),
            status: "completed", 
            filesProcessed: uploadedCount,
            totalFiles: localPhotos.count,
            bytesTransferred: totalBytes,
            totalBytes: totalBytes,
            duration: duration,
            task: task
        )
        context.insert(history)
        try context.save()
        
        logger.info("Fotoğraf yedekleme tamamlandı: \(uploadedCount) yüklendi, \(skippedCount) atlandı, \(filesToDelete.count) silindi")
        await sendNotification(title: "Fotoğraf Yedekleme Tamamlandı", 
                             body: "\(uploadedCount) fotoğraf yüklendi, \(skippedCount) atlandı")
    }
    
    // MARK: - Synchronized Directory Backup
    
    private func performSynchronizedDirectoryBackup(task: BackupTask, context: ModelContext, remoteDirectory: String, startTime: Date) async throws {
        guard !task.sourcePath.isEmpty else {
            task.backupStatus = .failed
            task.lastError = "Kaynak klasör seçilmemiş"
            try context.save()
            throw BackupError.invalidSourceURL
        }
        
        let sourceURL = URL(fileURLWithPath: task.sourcePath)
        
        // Check if the file exists, is accessible, and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            task.backupStatus = .failed
            task.lastError = "Kaynak klasör bulunamadı"
            try context.save()
            throw BackupError.invalidSourceURL
        }
        
        guard isDirectory.boolValue else {
            task.backupStatus = .failed
            task.lastError = "Seçilen yol bir klasör değil"
            try context.save()
            throw BackupError.invalidSourceURL
        }
        
        guard sourceURL.startAccessingSecurityScopedResource() else {
            task.backupStatus = .failed
            task.lastError = "Dosya erişim izni alınamadı"
            try context.save()
            throw BackupError.invalidSourceURL
        }
        defer { sourceURL.stopAccessingSecurityScopedResource() }
        
        task.backupStatus = .scanning
        try context.save()
        
        // Yerel dosyaları tara
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey])
        var localFiles: [(relativePath: String, size: Int64)] = []
        var totalSize: Int64 = 0
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if resourceValues.isRegularFile == true {
                let size = Int64(resourceValues.fileSize ?? 0)
                let relativePath = fileURL.path.replacingOccurrences(of: sourceURL.path, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                localFiles.append((relativePath: relativePath, size: size))
                totalSize += size
            }
        }
        
        logger.info("\(localFiles.count) yerel dosya bulundu, toplam boyut: \(totalSize) bytes")
        
        // FTP üzerindeki hedef dizini oluştur
        try await ftpService.createDirectory(at: remoteDirectory)
        
        // FTP'deki mevcut dosyaları listele
        let existingFiles = try await ftpService.listFiles(in: remoteDirectory)
        logger.info("FTP'de \(existingFiles.count) mevcut dosya bulundu")
        
        // Senkronizasyon: FTP'de olup yerel klasörden silinen dosyaları bul ve sil
        let localFileNames = Set(localFiles.map { $0.relativePath })
        let filesToDelete = existingFiles.filter { !localFileNames.contains($0.name) }
        
        logger.info("\(filesToDelete.count) dosya FTP'den silinecek")
        for fileToDelete in filesToDelete {
            let remotePath = "\(remoteDirectory)/\(fileToDelete.name)"
            logger.info("Siliniyor: \(fileToDelete.name)")
            try await ftpService.deleteFile(at: remotePath)
        }
        
        // Upload edilecek dosyaları belirle (yeni veya değişmiş olanlar)
        var filesToUpload: [(relativePath: String, size: Int64)] = []
        
        for localFile in localFiles {
            // Aynı isim ve boyutta dosya var mı kontrol et
            let existingFile = existingFiles.first { $0.name == localFile.relativePath }
            
            if let existing = existingFile {
                if existing.size != localFile.size {
                    logger.info("Dosya boyutu farklı, yüklenecek: \(localFile.relativePath) (Yerel: \(localFile.size), FTP: \(existing.size))")
                    filesToUpload.append(localFile)
                } else {
                    logger.info("Dosya atlanıyor (aynı boyut): \(localFile.relativePath)")
                }
            } else {
                logger.info("Yeni dosya: \(localFile.relativePath)")
                filesToUpload.append(localFile)
            }
        }
        
        logger.info("\(filesToUpload.count) dosya yüklenecek")
        
        task.backupStatus = .uploading
        try context.save()
        
        var uploadedCount = 0
        var uploadedBytes: Int64 = 0
        
        // Upload each file
        for (index, fileInfo) in filesToUpload.enumerated() {
            guard task.backupStatus != .cancelled else { break }
            
            let localFileURL = sourceURL.appendingPathComponent(fileInfo.relativePath)
            let remotePath = "\(remoteDirectory)/\(fileInfo.relativePath)"
            
            // Update progress
            let progress = Double(index) / Double(filesToUpload.count)
            await MainActor.run {
                task.progress = progress
                task.currentFile = fileInfo.relativePath
                try? context.save()
            }
            
            // Upload file
            do {
                try await ftpService.uploadFile(localURL: localFileURL, remotePath: remotePath)
                logger.info("Dosya yüklendi: \(fileInfo.relativePath) (\(fileInfo.size) bytes)")
                uploadedCount += 1
                uploadedBytes += fileInfo.size
            } catch {
                logger.error("Dosya yüklenemedi: \(fileInfo.relativePath) - \(error.localizedDescription)")
                throw error
            }
        }
        
        // Backup tamamlandı
        let duration = Date().timeIntervalSince(startTime)
        task.backupStatus = .completed
        task.progress = 1.0
        task.currentFile = nil
        task.lastBackupDate = Date()
        updateNextRunTime(for: task)
        
        let skippedCount = localFiles.count - uploadedCount
        
        let history = BackupHistory(
            timestamp: Date(),
            status: "completed", 
            filesProcessed: uploadedCount,
            totalFiles: localFiles.count,
            bytesTransferred: uploadedBytes,
            totalBytes: totalSize,
            duration: duration,
            task: task
        )
        context.insert(history)
        try context.save()
        
        logger.info("Dizin yedekleme tamamlandı: \(uploadedCount) yüklendi, \(skippedCount) atlandı, \(filesToDelete.count) silindi")
        await sendNotification(title: "Yedekleme Tamamlandı", 
                             body: "\(uploadedCount) dosya yüklendi, \(skippedCount) atlandı")
    }
    
    // MARK: - Helpers
    private func getModelContainer() throws -> ModelContainer {
        // Öncelikle shared container'ı kullanmaya çalış
        if let sharedContainer = Self.sharedModelContainer {
            logger.info("Shared ModelContainer kullanılıyor")
            return sharedContainer
        }
        
        // Fallback: Kendi container'ımızı oluştur
        logger.warning("Shared container yok, yeni container oluşturuluyor")
        return try createNewModelContainer()
    }
    
    private func createNewModelContainer() throws -> ModelContainer {
        let fileManager = FileManager.default
        
        // 1. Try to get the App Group container URL
        var containerURL: URL
        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            containerURL = appGroupURL
            logger.info("App Group container bulundu: \(containerURL.path)")
        } else {
            // Fallback to app's documents directory if App Group is not available
            logger.warning("App Group container bulunamadı, Documents klasörü kullanılacak")
            containerURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
        // 2. Create the Application Support directory if it doesn't exist
        let appSupportURL = containerURL.appendingPathComponent("Library/Application Support")
        
        do {
            // 3. Create the directory structure with proper permissions
            // Always try to create the directory structure to ensure it exists
            logger.info("Application Support dizini kontrol ediliyor: \(appSupportURL.path)")
            try fileManager.createDirectory(
                at: appSupportURL,
                withIntermediateDirectories: true,
                attributes: [
                    .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
                    .posixPermissions: 0o755  // Daha esnek izinler
                ]
            )
            logger.info("Application Support dizini hazırlandı: \(appSupportURL.path)")
            
            // 4. Set up the model configuration with explicit URL
            let storeURL = appSupportURL.appendingPathComponent("BackupFlow.sqlite")
            
            // 5. Create model configuration
            let configuration = ModelConfiguration(url: storeURL)
            
            // 6. Try to create the container
            do {
                let container = try ModelContainer(
                    for: BackupTask.self, 
                    BackupHistory.self,
                    configurations: configuration
                )
                
                // Enable automatic save
                container.mainContext.autosaveEnabled = true
                
                logger.info("Model container başarıyla oluşturuldu: \(storeURL.path)")
                return container
                
            } catch {
                // If creation fails, try to recover
                logger.error("Model container oluşturulamadı: \(error.localizedDescription)")
                
                // If store file exists, try to remove it
                if fileManager.fileExists(atPath: storeURL.path) {
                    logger.warning("Hatalı store dosyası siliniyor: \(storeURL.path)")
                    try fileManager.removeItem(at: storeURL)
                    
                    // Try one more time with a fresh store
                    logger.info("Yeni bir store ile tekrar deneniyor...")
                    let container = try ModelContainer(
                        for: BackupTask.self,
                        BackupHistory.self,
                        configurations: configuration
                    )
                    logger.info("Model container başarıyla oluşturuldu (yeniden deneme sonrası)")
                    return container
                }
                
                throw error
            }
        } catch {
            logger.error("Model container oluşturma hatası: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error { self?.logger.error("Bildirim hatası: \(error.localizedDescription)") }
            else { self?.logger.info("Bildirim izni: \(granted)") }
        }
    }
    
    private func sendNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        logger.info("Bildirim gönderildi: \(title)")
    }
    
    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in completionHandler([.banner, .sound]) }
    }
    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in completionHandler() }
    }
    
    // MARK: - Directory stats
    private func calculateDirectoryStats(url: URL) async throws -> (Int, Int64) {
        var fileCount = 0
        var totalSize: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isDirectoryKey]
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        for fileURL in contents {
            let resourceValues = try fileURL.resourceValues(forKeys: keys)
            if resourceValues.isDirectory == true {
                let (subCount, subSize) = try await calculateDirectoryStats(url: fileURL)
                fileCount += subCount
                totalSize += subSize
            } else {
                fileCount += 1
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        return (fileCount, totalSize)
    }
    
    // MARK: - Task management
    func cancelCurrentTask(for task: BackupTask) {
        scheduledTimers[task.id]?.invalidate()
        scheduledTimers[task.id] = nil
        task.backupStatus = .cancelled
        logger.info("Görev iptal edildi: \(task.displayName)")
    }
    
    func refreshTaskStatuses() async throws {
        let container = try getModelContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<BackupTask>()
        let tasks = try context.fetch(descriptor)
        for task in tasks {
            if task.backupStatus == .uploading || task.backupStatus == .preparing || task.backupStatus == .scanning {
                task.backupStatus = .idle
                task.progress = 0
                task.currentFile = nil
            }
        }
        try context.save()
    }
    
    func checkAndRescheduleTasks() async throws {
        let container = try getModelContainer()
        let context = ModelContext(container)
        let now = Date()
        let descriptor = FetchDescriptor<BackupTask>(predicate: #Predicate<BackupTask> { task in
            task.isEnabled && task.nextRunTime != nil && task.nextRunTime! <= now
        })
        let tasks = try context.fetch(descriptor)
        for task in tasks {
            if task.backupStatus != .uploading && task.backupStatus != .preparing && task.backupStatus != .scanning {
                try await scheduleBackup(task: task)
            }
        }
        scheduleAppRefresh()
        scheduleBackgroundProcessing()
    }
    
    func saveActiveTaskStates() async throws {
        let container = try getModelContainer()
        let context = ModelContext(container)
        let allTasks = try context.fetch(FetchDescriptor<BackupTask>())
        let activeTasks = allTasks.filter { t in t.backupStatus == .uploading || t.backupStatus == .preparing || t.backupStatus == .scanning }
        for task in activeTasks {
            task.lastError = "Uygulama kapatıldığı için işlem yarıda kesildi"
            task.backupStatus = .failed
            task.progress = 0
            task.currentFile = nil
        }
        try context.save()
    }
    
    func testFTPUpload() async throws {
        guard !isProcessing else { throw BackupError.alreadyInProgress }
        isProcessing = true
        defer { isProcessing = false }
        logger.info("FTP test yüklemesi başlatılıyor...")
        let tempDir = FileManager.default.temporaryDirectory
        let testFileName = "test_backup_\(UUID().uuidString.prefix(8)).txt"
        let testFileURL = tempDir.appendingPathComponent(testFileName)
        do {
            let dummyData = Data(repeating: 0x41, count: 200 * 1024)
            try dummyData.write(to: testFileURL)
            try await ftpService.connect(host: defaultFTPHost, port: 21, username: "anonymous", password: "")
            try? await ftpService.createDirectory(at: "test_uploads")
            let remotePath = "test_uploads/\(testFileName)"
            try await ftpService.uploadFile(localURL: testFileURL, remotePath: remotePath) { progress in
                self.logger.info("Test yükleme ilerlemesi: \(Int(progress * 100))%")
            }
            try FileManager.default.removeItem(at: testFileURL)
            logger.info("FTP test yüklemesi başarılı")
            await sendNotification(title: "FTP Testi Başarılı", body: "Test dosyası başarıyla yüklendi!")
        } catch {
            logger.error("FTP test hatası: \(error.localizedDescription)")
            await sendNotification(title: "FTP Testi Başarısız", body: "Hata: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - URLSession Delegate

extension BackupScheduler: URLSessionDelegate, URLSessionTaskDelegate {
    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error { self.logger.error("FTP yükleme hatası: \(error.localizedDescription)") }
            else { self.logger.info("FTP yükleme başarılı") }
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Task { @MainActor in if let error = error { self.logger.error("URLSession hatası: \(error.localizedDescription)") } }
    }
    
    nonisolated public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            if let completionHandler = self.backgroundCompletionHandler { completionHandler(); self.backgroundCompletionHandler = nil }
        }
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case alreadyInProgress
    case invalidSourceURL
    case appGroupNotFound
    case ftpError(String)
    case permissionDenied
    var errorDescription: String? {
        switch self {
        case .alreadyInProgress: return "Başka bir yedekleme işlemi devam ediyor"
        case .invalidSourceURL: return "Kaynak klasör bulunamadı"
        case .appGroupNotFound: return "App Group erişimi sağlanamadı"
        case .ftpError(let m): return "FTP hatası: \(m)"
        case .permissionDenied: return "İzin reddedildi"
        }
    }
}

