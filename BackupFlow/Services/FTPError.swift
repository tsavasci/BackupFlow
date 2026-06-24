import Foundation

enum FTPError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case authenticationFailed
    case fileOperationFailed
    case invalidResponse
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "error.ftp.invalid_url".localized
        case .connectionFailed:
            return "error.ftp.connection_failed".localized
        case .authenticationFailed:
            return "error.ftp.authentication_failed".localized
        case .fileOperationFailed:
            return "error.ftp.file_operation_failed".localized
        case .invalidResponse:
            return "error.ftp.invalid_response".localized
        case .unknown(let error):
            return "error.unexpected_with_detail".localized(with: error.localizedDescription)
        }
    }
}
