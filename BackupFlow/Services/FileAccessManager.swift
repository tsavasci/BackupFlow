import Foundation
import os.log

/// Manages file access permissions for File Provider Storage and security scoped bookmarks
class FileAccessManager {
    static let shared = FileAccessManager()
    private let logger = Logger(subsystem: "com.example.BackupFlow", category: "FileAccessManager")
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    /// Save a security scoped bookmark for a URL
    func saveBookmark(for url: URL, key: String) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: [.isDirectoryKey],
            relativeTo: nil
        )
        
        userDefaults.set(bookmarkData, forKey: "bookmark_\(key)")
        logger.info("Saved bookmark for: \(url.lastPathComponent)")
    }
    
    /// Load a security scoped bookmark and return resolved URL
    func loadBookmark(for key: String) -> URL? {
        guard let bookmarkData = userDefaults.data(forKey: "bookmark_\(key)") else {
            logger.info("No bookmark found for key: \(key)")
            return nil
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                logger.warning("Bookmark is stale for key: \(key)")
                userDefaults.removeObject(forKey: "bookmark_\(key)")
                return nil
            }
            
            logger.info("Successfully resolved bookmark for: \(url.lastPathComponent)")
            return url
        } catch {
            logger.error("Failed to resolve bookmark for key \(key): \(error.localizedDescription)")
            userDefaults.removeObject(forKey: "bookmark_\(key)")
            return nil
        }
    }
    
    /// Check if a path needs security scoped access and attempt to start it
    func startSecurityScopedAccess(for path: String) -> (url: URL?, accessStarted: Bool) {
        // Check if this is a File Provider path
        if path.contains("File Provider Storage") {
            logger.info("🔐 Detected File Provider Storage path, attempting bookmark resolution...")
            
            // Try to load bookmark for this exact path
            if let bookmarkURL = loadBookmark(for: path) {
                logger.info("🔐 Found bookmark for path: \(bookmarkURL.path)")
                // In iOS, File Provider access is handled through Document Picker permissions
                // We don't need to explicitly start security scoped access for bookmarked URLs
                return (bookmarkURL, true)
            } else {
                logger.warning("🔐 No bookmark found for File Provider path: \(path)")
                // Fallback to direct URL - but this likely won't work for File Provider
                let url = URL(fileURLWithPath: path)
                logger.warning("🔐 Using fallback URL, access may be limited")
                return (url, false)
            }
        }
        
        // For regular file system paths, no special access needed
        return (URL(fileURLWithPath: path), false)
    }
    
    /// Stop security scoped access for a URL (iOS specific handling)
    func stopSecurityScopedAccess(for url: URL) {
        // In iOS File Provider context, we don't need to explicitly stop security scoped access
        // The access is managed through the Document Picker permissions
        logger.info("🔐 File access cleanup for: \(url.lastPathComponent)")
    }
    
    /// Try to access File Provider files using NSFileCoordinator
    func accessFileProviderFiles(at path: String, operation: (URL) throws -> Void) throws {
        let url = URL(fileURLWithPath: path)
        
        // First try bookmark resolution
        if let bookmarkURL = loadBookmark(for: path) {
            logger.info("🔐 Using bookmark URL for file operation")
            // In iOS, bookmark URLs don't need explicit security scoped access management
            try operation(bookmarkURL)
            return
        }
        
        // Fallback to NSFileCoordinator for File Provider files
        if path.contains("File Provider Storage") {
            logger.info("🔐 Using NSFileCoordinator for File Provider access")
            var coordinatorError: NSError?
            var operationError: Error?
            
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinatorError) { (coordinatedURL) in
                do {
                    try operation(coordinatedURL)
                } catch {
                    operationError = error
                }
            }
            
            if let error = coordinatorError {
                throw error
            }
            
            if let error = operationError {
                throw error
            }
        } else {
            // Regular file access
            try operation(url)
        }
    }
}