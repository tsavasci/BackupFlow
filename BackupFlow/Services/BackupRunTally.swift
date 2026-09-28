import Foundation

/// Counts what a backup run actually uploaded, independently of the sync result.
///
/// The sync engines return their result only when a run finishes, so a cancelled or
/// failed run used to record "0 files" even after uploading some. The engines report
/// each upload here as it happens; the scheduler reads the tally when writing history.
/// Skipped files aren't counted, so "transferred" no longer includes files that were
/// already on the server.
final class BackupRunTally: @unchecked Sendable {
    static let shared = BackupRunTally()

    private let lock = NSLock()
    private var _uploadedFiles = 0
    private var _uploadedBytes: Int64 = 0

    var uploadedFiles: Int { lock.withLock { _uploadedFiles } }
    var uploadedBytes: Int64 { lock.withLock { _uploadedBytes } }

    func reset() {
        lock.withLock {
            _uploadedFiles = 0
            _uploadedBytes = 0
        }
    }

    func recordUpload(bytes: Int64) {
        lock.withLock {
            _uploadedFiles += 1
            _uploadedBytes += max(bytes, 0)
        }
    }
}
