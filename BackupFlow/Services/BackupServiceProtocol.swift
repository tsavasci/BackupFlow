import Foundation
import FilesProvider

/// Common protocol for all backup services (FTP, WebDAV, etc.)
protocol BackupServiceProtocol: AnyObject {
    /// Connects to the backup server
    /// - Parameters:
    ///   - host: Server hostname or IP address
    ///   - port: Server port
    ///   - username: Username for authentication (nil for anonymous)
    ///   - password: Password for authentication
    func connect(host: String, port: Int, username: String?, password: String?) async throws
    
    /// Uploads a file to the server
    /// - Parameters:
    ///   - localURL: Local file URL to upload
    ///   - remotePath: Destination path on the server
    ///   - progressHandler: Optional progress handler (0.0 to 1.0)
    func uploadFile(localURL: URL, remotePath: String, progressHandler: ((Double) -> Void)?) async throws
    
    /// Creates a directory on the server
    /// - Parameter path: Directory path to create
    func createDirectory(at path: String) async throws
    
    /// Lists contents of a directory
    /// - Parameter path: Directory path to list
    /// - Returns: Array of file objects
    func listDirectory(at path: String) async throws -> [FileObject]
    
    /// Deletes a file or directory on the server
    /// - Parameter path: Path to delete
    func deleteFile(at path: String) async throws
    
    /// Disconnects from the server
    func disconnect()
    
    /// Current connection status
    var isConnected: Bool { get }
    
    /// Last error that occurred (if any)
    var lastError: Error? { get }
}

// MARK: - Common Errors
enum BackupServiceError: Error, LocalizedError {
    case connectionFailed
    case authenticationFailed
    case fileOperationFailed
    case invalidResponse
    case cancelled
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "backup.error.connection_failed".localized
        case .authenticationFailed:
            return "backup.error.authentication_failed".localized
        case .fileOperationFailed:
            return "backup.error.file_operation_failed".localized
        case .invalidResponse:
            return "backup.error.invalid_response".localized
        case .cancelled:
            return "backup.error.cancelled".localized
        case .unknown(let error):
            return String(format: "backup.error.unexpected".localized, error.localizedDescription)
        }
    }
}
