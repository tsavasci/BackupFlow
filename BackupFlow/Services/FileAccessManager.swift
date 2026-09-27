import Foundation
import os.log

/// Manages file access permissions for File Provider Storage and security scoped bookmarks
class FileAccessManager {
    static let shared = FileAccessManager()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "FileAccessManager")
    private let userDefaults = UserDefaults.standard
    
    private var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        return [.minimalBookmark]
    }
    
    private var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        return []
    }
    
    private init() {}
    
    /// Save a security scoped bookmark for a URL
    func saveBookmark(for url: URL, key: String) throws {
        let bookmarkData = try url.bookmarkData(
            options: bookmarkCreationOptions,
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
                options: bookmarkResolutionOptions,
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
    
    /// Try to access File Provider files using NSFileCoordinator
    func accessFileProviderFiles(at path: String, operation: (URL) throws -> Void) throws {
        let url = URL(fileURLWithPath: path)
        
        // First try bookmark resolution
        if let bookmarkURL = loadBookmark(for: path) {
            logger.info("🔐 Using bookmark URL for file operation")
            // In iOS, bookmark URLs don't need explicit security scoped access management
            let started = bookmarkURL.startAccessingSecurityScopedResource()
            defer {
                if started {
                    bookmarkURL.stopAccessingSecurityScopedResource()
                }
            }
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
