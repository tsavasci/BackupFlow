import Foundation
import OSLog
import SwiftData

@MainActor
enum HistoryRetentionManager {
    private static let logger = Logger(subsystem: "com.backupflow.app", category: "HistoryRetention")
    private static let retentionKey = "keepHistoryDays"

    static func pruneIfNeeded(context: ModelContext) {
        let keepDays = UserDefaults.standard.integer(forKey: retentionKey)
        guard keepDays > 0 else { return }

        let cutoff = Date().addingTimeInterval(-Double(keepDays) * 24 * 60 * 60)
        let descriptor = FetchDescriptor<BackupHistory>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )

        do {
            let items = try context.fetch(descriptor)
            guard !items.isEmpty else { return }
            for item in items {
                context.delete(item)
            }
            try context.save()
            logger.info("Pruned \(items.count) history records older than \(keepDays) days.")
        } catch {
            logger.error("Failed to prune history records: \(error.localizedDescription)")
        }
    }

    static func pruneIfNeeded(container: ModelContainer) {
        let context = ModelContext(container)
        pruneIfNeeded(context: context)
    }
}
