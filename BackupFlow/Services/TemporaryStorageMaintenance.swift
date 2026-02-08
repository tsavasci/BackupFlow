import Foundation
import OSLog

enum TemporaryStorageMaintenance {
    private static let logger = Logger(subsystem: "com.backupflow.app", category: "TempStorage")
    private static let exportRootName = "backupflow_exports"
    private static let defaultMaxAge: TimeInterval = 2 * 60 * 60
    private static let allowedMediaExtensions: Set<String> = ["jpg", "jpeg", "mp4", "mov", "heic", "png"]

    static func cleanupStaleFiles(maxAge: TimeInterval = defaultMaxAge, fileManager: FileManager = .default) {
        let tempRoot = fileManager.temporaryDirectory
        let cutoff = Date().addingTimeInterval(-maxAge)

        cleanupExportRoot(tempRoot: tempRoot, cutoff: cutoff, fileManager: fileManager)
        cleanupLegacyWebDAVStaging(tempRoot: tempRoot, cutoff: cutoff, fileManager: fileManager)
    }

    private static func cleanupExportRoot(tempRoot: URL, cutoff: Date, fileManager: FileManager) {
        let exportRoot = tempRoot.appendingPathComponent(exportRootName, isDirectory: true)
        guard fileManager.fileExists(atPath: exportRoot.path) else { return }

        do {
            let items = try fileManager.contentsOfDirectory(
                at: exportRoot,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for item in items where isStale(item, cutoff: cutoff) {
                try? fileManager.removeItem(at: item)
            }

            let remaining = try fileManager.contentsOfDirectory(
                at: exportRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            if remaining.isEmpty {
                try? fileManager.removeItem(at: exportRoot)
            }
        } catch {
            logger.error("Failed cleaning export root: \(error.localizedDescription)")
        }
    }

    private static func cleanupLegacyWebDAVStaging(tempRoot: URL, cutoff: Date, fileManager: FileManager) {
        do {
            let items = try fileManager.contentsOfDirectory(
                at: tempRoot,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for item in items {
                guard isUUIDLike(item.lastPathComponent) else { continue }
                guard isLikelyLegacyMediaStagingDirectory(item, fileManager: fileManager) else { continue }
                try? fileManager.removeItem(at: item)
            }
        } catch {
            logger.error("Failed cleaning legacy staging folders: \(error.localizedDescription)")
        }
    }

    private static func isStale(_ url: URL, cutoff: Date) -> Bool {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let modifiedAt = values?.contentModificationDate ?? values?.creationDate ?? .distantPast
        return modifiedAt < cutoff
    }

    private static func isUUIDLike(_ name: String) -> Bool {
        UUID(uuidString: name) != nil
    }

    private static func isLikelyLegacyMediaStagingDirectory(_ directoryURL: URL, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        var fileCount = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                return false
            }

            let ext = fileURL.pathExtension.lowercased()
            if !allowedMediaExtensions.contains(ext) {
                return false
            }
            fileCount += 1
        }

        return fileCount > 0
    }
}
