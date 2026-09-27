import Foundation

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
