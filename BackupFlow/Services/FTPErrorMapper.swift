import Foundation

enum FTPErrorMapper {
    static func map(_ error: Error) -> FTPError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return .connectionFailed
            case .userAuthenticationRequired:
                return .authenticationFailed
            case .fileDoesNotExist:
                return .fileOperationFailed
            default:
                return .fileOperationFailed
            }
        }
        return .unknown(error)
    }
}
