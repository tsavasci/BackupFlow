@preconcurrency import Photos
import PhotosUI
import SwiftUI
import Combine
import OSLog
import UniformTypeIdentifiers

class PhotoLibraryManager: NSObject, ObservableObject {
    static let shared = PhotoLibraryManager()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "PhotoLibrary")
    private let fileNameFormatterLock = NSLock()
    private lazy var fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var hasAccess: Bool = false

    var hasFullLibraryAccess: Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
    }
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    enum AssetFileExportResult {
        case success(url: URL, size: Int64)
        case iCloudOnly
        case timedOut
        case unavailable
    }
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.handleAuthorizationStatus(status)
                completion?(status == .authorized || status == .limited)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        handleAuthorizationStatus(status)
    }
    
    private func handleAuthorizationStatus(_ status: PHAuthorizationStatus) {
        self.authorizationStatus = status
        switch status {
        case .authorized, .limited:
            self.hasAccess = true
            logger.info("Fotoğraf kütüphanesine erişim izni verildi")
        case .denied, .restricted:
            self.hasAccess = false
            logger.warning("Fotoğraf kütüphanesine erişim reddedildi veya kısıtlandı")
        case .notDetermined:
            self.hasAccess = false
            logger.info("Fotoğraf kütüphanesi izni henüz istenmedi")
        @unknown default:
            self.hasAccess = false
            logger.error("Bilinmeyen izin durumu: \(status.rawValue)")
        }
    }
    
    // MARK: - Backup Support Methods
    func getAllAssets(mediaType: MediaType) async throws -> [PHAsset] {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        handleAuthorizationStatus(currentStatus)
        guard currentStatus == .authorized || currentStatus == .limited else {
            throw NSError(domain: "PhotoLibraryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "error.photo_library.no_access".localized])
        }
        
        let fetchOptions = PHFetchOptions()
        
        // Metadata'yı önceden yükle - performans optimizasyonu
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        fetchOptions.includeHiddenAssets = false
        
        switch mediaType {
        case .photosOnly:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        case .videosOnly:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        case .photosAndVideos:
            fetchOptions.predicate = NSPredicate(format: "mediaType = %d OR mediaType = %d", 
                                               PHAssetMediaType.image.rawValue, 
                                               PHAssetMediaType.video.rawValue)
        }
        
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        logger.info("📱 BackupFlow: \(assets.count) adet \(mediaType.displayName) bulundu")
        return assets
    }

    private func primaryResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        switch asset.mediaType {
        case .image:
            return resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) ?? resources.first
        case .video:
            return resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first
        default:
            return nil
        }
    }

    /// Reads the byte size reported by Photos metadata without exporting the asset to disk.
    /// Allows unchanged remote files to be skipped immediately during background syncs.
    func localResourceSize(for asset: PHAsset) -> Int64? {
        guard let resource = primaryResource(for: asset),
              let sizeNumber = resource.value(forKey: "fileSize") as? NSNumber else {
            return nil
        }
        let size = sizeNumber.int64Value
        return size > 0 ? size : nil
    }
    
    func exportAssetToTemporaryFile(asset: PHAsset, fileName: String, allowNetworkAccess: Bool = false) async -> AssetFileExportResult {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("backupflow_exports", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: tempRoot.path
            )
        } catch {
            logger.warning("⚠️ Geçici medya klasörü oluşturulamadı: \(error.localizedDescription)")
            return .unavailable
        }

        let safeTempName = (fileName as NSString).lastPathComponent
        let tempURL = tempRoot.appendingPathComponent(safeTempName)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        return await withCheckedContinuation { continuation in
            let resumeLock = NSLock()
            var didResume = false
            let mediaType = asset.mediaType
            let assetIdentifier = asset.localIdentifier

            func tryResume(_ result: AssetFileExportResult) -> Bool {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                if didResume { return false }
                didResume = true
                continuation.resume(returning: result)
                return true
            }

            Task {
                // Multi-GB videos (e.g. 2.4+ GB 4K recordings) need generous export time, especially in background/locked state.
                let timeout: UInt64 = mediaType == .video ? 600_000_000_000 : 90_000_000_000
                try? await Task.sleep(nanoseconds: timeout)
                if tryResume(.timedOut) {
                    try? FileManager.default.removeItem(at: tempURL)
                    self.logger.warning("⚠️ Medya dosyası dışa aktarma zaman aşımı: \(assetIdentifier.prefix(8))")
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                guard let resource = self.primaryResource(for: asset) else {
                    _ = tryResume(.unavailable)
                    return
                }

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = allowNetworkAccess

                PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { error in
                    if let error {
                        let nsError = error as NSError
                        try? FileManager.default.removeItem(at: tempURL)
                        if !allowNetworkAccess, nsError.domain == "PHPhotosErrorDomain", (nsError.code == 3164 || nsError.code == 3169) {
                            _ = tryResume(.iCloudOnly)
                        } else {
                            self.logger.warning("⚠️ Medya dosyası dışa aktarılamadı: \(error.localizedDescription)")
                            _ = tryResume(.unavailable)
                        }
                        return
                    }

                    try? FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                        ofItemAtPath: tempURL.path
                    )
                    let fileSize = Int64((try? tempURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    if fileSize > 0 {
                        if !tryResume(.success(url: tempURL, size: fileSize)) {
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                    } else {
                        try? FileManager.default.removeItem(at: tempURL)
                        _ = tryResume(.unavailable)
                    }
                }
            }
        }
    }
    
    func generateFileName(for asset: PHAsset, preserveOriginalExtension: Bool = false) -> String {
        let origExt: String? = preserveOriginalExtension ? originalFileExtension(for: asset) : nil
        return Self.formatFileName(
            creationDate: asset.creationDate ?? Date(),
            localIdentifier: asset.localIdentifier,
            mediaType: asset.mediaType,
            originalExtension: origExt,
            preserveOriginalExtension: preserveOriginalExtension,
            formatterLock: fileNameFormatterLock,
            dateFormatter: fileNameDateFormatter
        )
    }

    func generateRelativePath(
        for asset: PHAsset,
        folderStructure: PhotoFolderStructure = .flat,
        preserveOriginalExtension: Bool = false
    ) -> String {
        let creationDate = asset.creationDate ?? Date()
        let fileName = generateFileName(for: asset, preserveOriginalExtension: preserveOriginalExtension)
        if let prefix = folderStructure.subfolderPrefix(for: creationDate) {
            return "\(prefix)/\(fileName)"
        }
        return fileName
    }

    /// Reads the original file extension (e.g. `heic`, `dng`, `mov`, `png`) from asset metadata.
    private func originalFileExtension(for asset: PHAsset) -> String? {
        if let fastName = asset.value(forKey: "filename") as? String {
            let ext = (fastName as NSString).pathExtension.lowercased()
            if !ext.isEmpty { return ext }
        }
        if let resourceName = primaryResource(for: asset)?.originalFilename {
            let ext = (resourceName as NSString).pathExtension.lowercased()
            if !ext.isEmpty { return ext }
        }
        return nil
    }

    static func formatFileName(
        creationDate: Date,
        localIdentifier: String,
        mediaType: PHAssetMediaType,
        originalExtension: String? = nil,
        preserveOriginalExtension: Bool = false,
        formatterLock: NSLock? = nil,
        dateFormatter: DateFormatter? = nil
    ) -> String {
        let dateString: String
        if let lock = formatterLock, let formatter = dateFormatter {
            dateString = lock.withLock { formatter.string(from: creationDate) }
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            dateString = formatter.string(from: creationDate)
        }

        let defaultExtension: String
        if mediaType == .image {
            defaultExtension = "jpg"
        } else if mediaType == .video {
            defaultExtension = "mp4"
        } else {
            defaultExtension = "unknown"
        }

        let cleanedOriginal = originalExtension?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        let fileExtension: String
        if preserveOriginalExtension, let cleanedOriginal, !cleanedOriginal.isEmpty {
            fileExtension = cleanedOriginal
        } else {
            fileExtension = defaultExtension
        }

        let sanitizedIdentifier = localIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let idFragment = String(sanitizedIdentifier.prefix(12))

        return "\(dateString)_\(idFragment).\(fileExtension)"
    }
}
