import Foundation

/// A transfer service whose current-file progress is mirrored onto the running task.
/// BackupScheduler reads these after each progress callback; see `makeProgressHandler`.
@MainActor
protocol TransferProgressSource: AnyObject {
    var currentFile: String { get }
    /// Progress of the current file, 0...1.
    var progress: Double { get }
    var currentFileBytesTransferred: Int64 { get }
    var currentFileTotalBytes: Int64 { get }
    var transferSpeedBytesPerSecond: Double { get }
}

extension FTPService: TransferProgressSource {}
extension SFTPService: TransferProgressSource {}
extension WebDAVService: TransferProgressSource {}
