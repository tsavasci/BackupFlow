import Foundation

/// Whether a local source file can be read right now without waiting on iCloud.
///
/// A file in iCloud Drive that isn't downloaded to the device makes a read block until
/// iCloud fetches it, which in the background can take minutes or never finish. The
/// backup then reports no progress and iOS ends its continued processing task. Instead,
/// such a file starts downloading and is skipped this run; the next run uploads it.
enum LocalFileAvailability {
    /// Returns `true` when `url` can be read now. For an iCloud file that isn't on the
    /// device yet, starts its download and returns `false`.
    static func isReadableNow(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else {
            return true // Not an iCloud item, so it's a regular local file.
        }
        guard status == .notDownloaded else { return true }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        return false
    }
}
