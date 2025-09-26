import Foundation
import FilesProvider

/// Factory class to create backup service instances
enum BackupServiceFactory {
    /// Creates and returns the appropriate backup service based on the backup type
    /// - Parameter type: Type of backup service to create
    /// - Returns: An instance of a service that conforms to BackupServiceProtocol
    static func createService(for type: BackupType) -> any BackupServiceProtocol {
        switch type {
        case .ftp:
            return FTPService.shared
        case .webdav:
            return WebDAVService.shared
        }
    }
    
    /// Creates a service based on an existing backup task
    /// - Parameter task: The backup task containing the configuration
    /// - Returns: A configured backup service instance
    static func service(for task: BackupTask) -> any BackupServiceProtocol {
        let service = createService(for: task.backupType)
        // Note: The service will be connected when needed, not here
        return service
    }
}
