import Foundation

// Define FileProviderError if not provided by the FilesProvider framework
enum FileProviderError: Error, Equatable {
    case authenticationRequired
    case serverError
    case fileNotFound
    case permissionDenied
    case unknown(Error)

    static func == (lhs: FileProviderError, rhs: FileProviderError) -> Bool {
        switch (lhs, rhs) {
        case (.authenticationRequired, .authenticationRequired),
             (.serverError, .serverError),
             (.fileNotFound, .fileNotFound),
             (.permissionDenied, .permissionDenied):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}
