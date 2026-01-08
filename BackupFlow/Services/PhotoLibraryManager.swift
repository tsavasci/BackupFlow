@preconcurrency import Photos
import PhotosUI
import SwiftUI
import Combine
import OSLog
import UniformTypeIdentifiers

class PhotoLibraryManager: NSObject, ObservableObject {
    static let shared = PhotoLibraryManager()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "PhotoLibrary")
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var hasAccess: Bool = false
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.handleAuthorizationStatus(status)
                    completion?(status == .authorized || status == .limited)
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.handleAuthorizationStatus(status)
                    completion?(status == .authorized)
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            handleAuthorizationStatus(status)
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            handleAuthorizationStatus(status)
        }
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
    
    func fetchAllPhotos(completion: @escaping ([PHAsset]) -> Void) {
        fetchAllMedia(includePhotos: true, includeVideos: false, completion: completion)
    }
    
    func fetchAllVideos(completion: @escaping ([PHAsset]) -> Void) {
        fetchAllMedia(includePhotos: false, includeVideos: true, completion: completion)
    }
    
    func fetchAllMedia(includePhotos: Bool = true, includeVideos: Bool = true, completion: @escaping ([PHAsset]) -> Void) {
        guard hasAccess else {
            logger.warning("Fotoğraf kütüphanesine erişim yok")
            completion([])
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        var allAssets: [PHAsset] = []
        
        // Fetch photos if requested
        if includePhotos {
            let photoFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            photoFetchResult.enumerateObjects { (asset, _, _) in
                allAssets.append(asset)
            }
        }
        
        // Fetch videos if requested  
        if includeVideos {
            let videoFetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions)
            videoFetchResult.enumerateObjects { (asset, _, _) in
                allAssets.append(asset)
            }
        }
        
        // Sort by creation date (newest first)
        allAssets.sort { (asset1, asset2) in
            guard let date1 = asset1.creationDate, let date2 = asset2.creationDate else {
                return false
            }
            return date1 > date2
        }
        
        logger.info("\(allAssets.count) adet medya dosyası bulundu (fotoğraf: \(includePhotos), video: \(includeVideos))")
        completion(allAssets)
    }
    
    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { (success, error) in
            DispatchQueue.main.async {
                if success {
                    self.logger.info("Fotoğraf başarıyla kaydedildi")
                } else if let error = error {
                    self.logger.error("Fotoğraf kaydedilemedi: \(error.localizedDescription)")
                }
                completion(success, error)
            }
        }
    }
    
    // MARK: - Backup Support Methods
    func getAllAssets(mediaType: MediaType) async throws -> [PHAsset] {
        guard hasAccess else {
            throw NSError(domain: "PhotoLibraryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fotoğraf kütüphanesine erişim izni yok"])
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
    
    func getAssetData(asset: PHAsset) async throws -> Data? {
        return await withCheckedContinuation { continuation in
            // FIGSANDBOX uyarılarını azaltmak için opportunistic delivery kullan
            // .highQualityFormat iCloud'dan indirme zorlayabilir - foreground/background geçişlerde sorun oluşturabilir
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            // iCloud Sync Problemi: isNetworkAccessAllowed = true sadece gerekli durumlarda
            // Yerel olmayan varlıklar için iCloud'dan indirmek performans sorunlarına neden olabilir
            options.isNetworkAccessAllowed = false // Önce yerel varlıkları dene
            options.deliveryMode = .fastFormat // highQualityFormat yerine fastFormat kullan
            options.resizeMode = .none
            options.version = .current // Edited version yerine current version al
            
            if asset.mediaType == .image {
                // PHImageRequestOptions'ı main thread'de kullan
                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, orientation, info in
                    // Eğer yerel varlık bulunamazsa, iCloud'dan indir (opsiyonel)
                    if let data = data {
                        self.logger.debug("✓ Fotoğraf verisi yerel olarak alındı: \(asset.localIdentifier.prefix(8))")
                        continuation.resume(returning: data)
                    } else if let isInCloud = info?[PHImageResultIsInCloudKey] as? NSNumber, isInCloud.boolValue {
                        self.logger.warning("⚠️ Fotoğraf iCloud'da - yerel indirme başlatılmıyor (ağ erişimi devre dışı)")
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            } else if asset.mediaType == .video {
                let videoOptions = PHVideoRequestOptions()
                videoOptions.isNetworkAccessAllowed = false // Video da aynı şekilde yerel varlıktan başla
                videoOptions.deliveryMode = .fastFormat // highQualityFormat yerine
                videoOptions.version = .current
                
                // PHVideoRequestOptions'ı main thread'de kullan
                PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, info in
                    // For videos, we would need to export the asset to data
                    // This is a simplified version - real implementation would export video
                    if avAsset != nil {
                        self.logger.debug("✓ Video varlığı yerel olarak alındı: \(asset.localIdentifier.prefix(8))")
                    } else if let isInCloud = info?[PHImageResultIsInCloudKey] as? NSNumber, isInCloud.boolValue {
                        self.logger.warning("⚠️ Video iCloud'da - yerel indirme başlatılmıyor (ağ erişimi devre dışı)")
                    }
                    continuation.resume(returning: nil)
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    func generateFileName(for asset: PHAsset) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        
        let date = asset.creationDate ?? Date()
        let dateString = dateFormatter.string(from: date)
        
        let fileExtension: String
        if asset.mediaType == .image {
            fileExtension = "jpg"
        } else if asset.mediaType == .video {
            fileExtension = "mp4"
        } else {
            fileExtension = "unknown"
        }
        
        return "\(dateString)_\(asset.localIdentifier.prefix(8)).\(fileExtension)"
    }
}

// MARK: - Photo Picker for SwiftUI
@available(iOS 14, *)
struct PhotoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    let onSelect: ([PHAsset]) -> Void
    let includePhotos: Bool
    let includeVideos: Bool
    
    init(onSelect: @escaping ([PHAsset]) -> Void, includePhotos: Bool = true, includeVideos: Bool = false) {
        self.onSelect = onSelect
        self.includePhotos = includePhotos
        self.includeVideos = includeVideos
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        
        // Set filter based on what media types to include
        if includePhotos && includeVideos {
            configuration.filter = PHPickerFilter.any(of: [.images, .videos])
        } else if includePhotos {
            configuration.filter = .images
        } else if includeVideos {
            configuration.filter = .videos
        } else {
            configuration.filter = .images // Default fallback
        }
        
        configuration.selectionLimit = 0 // 0 means unlimited
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard !results.isEmpty else {
                parent.onSelect([])
                return
            }
            
            var assets: [PHAsset] = []
            let group = DispatchGroup()
            
            for result in results {
                group.enter()
                
                // Get the PHAsset for the selected photo
                if let assetId = result.assetIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                    if let asset = fetchResult.firstObject {
                        assets.append(asset)
                    }
                    group.leave()
                } else {
                    // Fallback for when assetIdentifier is not available
                    result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                        if let _ = object as? UIImage {
                            // We can't get the PHAsset directly, so we'll create a temporary one
                            // This is a limitation - we can't get the original PHAsset without the identifier
                            // In a real app, you might want to handle this case differently
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.onSelect(assets)
            }
        }
    }
}
