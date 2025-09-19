import Photos
import PhotosUI
import SwiftUI
import OSLog
import UniformTypeIdentifiers

class PhotoLibraryManager: NSObject, ObservableObject {
    static let shared = PhotoLibraryManager()
    private let logger = Logger(subsystem: "com.yedekle2.app", category: "PhotoLibrary")
    
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
        guard hasAccess else {
            logger.warning("Fotoğraf kütüphanesine erişim yok")
            completion([])
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        
        logger.info("\(assets.count) adet fotoğraf bulundu")
        completion(assets)
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
}

// MARK: - Photo Picker for SwiftUI
@available(iOS 14, *)
struct PhotoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    let onSelect: ([PHAsset]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
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
