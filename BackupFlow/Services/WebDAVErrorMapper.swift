import Foundation

enum WebDAVErrorMapper {
    static func mapError(_ error: Error) -> Error {
        let nsError = error as NSError

        // First try to handle as a FileProvider error
        if let fpError = error as? FileProviderError {
            switch fpError {
            case .authenticationRequired:
                return BackupServiceError.authenticationFailed
            case .serverError, .fileNotFound, .permissionDenied:
                return BackupServiceError.connectionFailed
            case .unknown(let underlyingError):
                return BackupServiceError.unknown(underlyingError)
            }
        }
        // Then try to handle as a URL error
        else if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorBadURL,
                 NSURLErrorUnsupportedURL:
                return BackupServiceError.connectionFailed
            case NSURLErrorUserAuthenticationRequired,
                 NSURLErrorUserCancelledAuthentication:
                return BackupServiceError.authenticationFailed
            case NSURLErrorCannotCreateFile,
                 NSURLErrorCannotOpenFile,
                 NSURLErrorCannotWriteToFile:
                return BackupServiceError.fileOperationFailed
            default:
                return BackupServiceError.unknown(error)
            }
        }
        // For any other error, wrap it in an unknown error
        else {
            return BackupServiceError.unknown(error)
        }
    }
}
