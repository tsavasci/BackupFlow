import Foundation
import Photos

// MARK: - File Size Formatting
extension Int64 {
    /// Returns the byte count as a human-readable string (e.g., "10 MB", "1.2 GB")
    var bytesFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}

// MARK: - PHAsset Array Helper
extension Array where Element == PHAsset {
    /// Creates an array of PHAsset from PHFetchResult
    /// - Parameters:
    ///   - fetchResult: The PHFetchResult containing PHAssets
    ///   - indexSet: The indexes of the assets to retrieve
    /// - Returns: An array of PHAsset objects
    static func assets(from fetchResult: PHFetchResult<PHAsset>, at indexSet: IndexSet) -> [PHAsset] {
        var result: [PHAsset] = []
        indexSet.forEach { index in
            guard index < fetchResult.count else { return }
            result.append(fetchResult.object(at: index))
        }
        return result
    }
}
