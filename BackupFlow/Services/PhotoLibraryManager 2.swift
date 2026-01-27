import Photos
import AVFoundation

func exportVideoAsset(_ asset: PHAsset, to fileURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true

    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
        guard let avAsset = avAsset else {
            completion(.failure(NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAsset not found"])))
            return
        }
        Task {
            do {
                guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
                    completion(.failure(NSError(domain: "ExportError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])))
                    return
                }
                try await exportSession.export(to: fileURL, as: AVFileType.mp4)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
