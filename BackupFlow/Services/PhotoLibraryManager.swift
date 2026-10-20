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
        } catch {
            logger.warning("⚠️ Geçici medya klasörü oluşturulamadı: \(error.localizedDescription)")
            return .unavailable
        }

        let tempURL = tempRoot.appendingPathComponent(fileName)
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
                let timeout: UInt64 = mediaType == .video ? 90_000_000_000 : 45_000_000_000
                try? await Task.sleep(nanoseconds: timeout)
                if tryResume(.timedOut) {
                    try? FileManager.default.removeItem(at: tempURL)
                    self.logger.warning("⚠️ Medya dosyası dışa aktarma zaman aşımı: \(assetIdentifier.prefix(8))")
                }
            }

            DispatchQueue.global(qos: .utility).async {
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
    
    func generateFileName(for asset: PHAsset) -> String {
        let date = asset.creationDate ?? Date()
        let dateString = fileNameFormatterLock.withLock {
            fileNameDateFormatter.string(from: date)
        }
        
        let fileExtension: String
        if asset.mediaType == .image {
            fileExtension = "jpg"
        } else if asset.mediaType == .video {
            fileExtension = "mp4"
        } else {
            fileExtension = "unknown"
        }
        
        let rawIdentifier = asset.localIdentifier
        let sanitizedIdentifier = rawIdentifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let idFragment = String(sanitizedIdentifier.prefix(12))
        
        return "\(dateString)_\(idFragment).\(fileExtension)"
    }
}
