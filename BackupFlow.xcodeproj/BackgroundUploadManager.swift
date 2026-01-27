import Foundation
import OSLog
import SwiftData

struct UploadMeta: Codable {
    let taskId: String?
    let remotePath: String
    let localFileName: String
    let enqueuedAt: Date?
}

@MainActor
final class BackgroundUploadManager {
    static let shared = BackgroundUploadManager()
    private let logger = Logger(subsystem: "com.backupflow.app", category: "BackgroundUploadManager")

    // Active backup task id (best-effort, for when app is alive)
    private var activeBackupTaskId: UUID? {
        get {
            if let s = UserDefaults.standard.string(forKey: "ActiveBackupTaskId"), let id = UUID(uuidString: s) {
                return id
            }
            return nil
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "ActiveBackupTaskId")
            } else {
                UserDefaults.standard.removeObject(forKey: "ActiveBackupTaskId")
            }
        }
    }

    private init() {}

    func setActiveBackupTaskId(_ id: UUID?) {
        activeBackupTaskId = id
        if let id = id {
            logger.info("Set active backup task id: \(id.uuidString)")
        } else {
            logger.info("Cleared active backup task id")
        }
    }

    // MARK: - Event Handling
    func handleTaskProgress(task: URLSessionTask, totalBytesSent: Int64, totalBytesExpected: Int64) {
        // Backend only: we can log telemetry or aggregate if needed
        let percent = totalBytesExpected > 0 ? Double(totalBytesSent) / Double(totalBytesExpected) : 0.0
        logger.debug("Progress for task(\(task.taskIdentifier)): \(Int(percent * 100))%")
    }

    func handleTaskCompletion(task: URLSessionTask, error: Error?) {
        // Parse taskDescription -> UploadMeta
        let meta = parseMeta(from: task.taskDescription)
        let status = (error == nil) ? "completed" : "failed"
        let errorMessage = error?.localizedDescription

        logger.info("Background task completed (id=\(task.taskIdentifier)) status=\(status) desc=\(task.taskDescription ?? "-")")

        // Persist to SwiftData History (best-effort)
        persistHistory(meta: meta, status: status, errorMessage: errorMessage, expectedBytes: task.countOfBytesExpectedToSend)
    }

    // MARK: - Helpers
    private func parseMeta(from description: String?) -> UploadMeta? {
        guard let desc = description, !desc.isEmpty else { return nil }

        // Try JSON first
        if let data = desc.data(using: .utf8), let m = try? JSONDecoder().decode(UploadMeta.self, from: data) {
            return m
        }
        // Legacy fallback: "WebDAVUpload:REMOTE_PATH"
        if desc.hasPrefix("WebDAVUpload:") {
            let path = String(desc.dropFirst("WebDAVUpload:".count))
            return UploadMeta(taskId: activeBackupTaskId?.uuidString, remotePath: path, localFileName: URL(fileURLWithPath: path).lastPathComponent, enqueuedAt: nil)
        }
        return nil
    }

    private func persistHistory(meta: UploadMeta?, status: String, errorMessage: String?, expectedBytes: Int64) {
        guard let container = BackupScheduler.sharedModelContainer else {
            logger.error("No ModelContainer available for history persistence")
            return
        }
        let context = ModelContext(container)

        // Try to resolve the task by id
        var linkedTask: BackupTask? = nil
        if let taskIdString = meta?.taskId, let uuid = UUID(uuidString: taskIdString) {
            do {
                let tasks = try context.fetch(FetchDescriptor<BackupTask>())
                linkedTask = tasks.first(where: { $0.id == uuid })
            } catch {
                logger.error("Failed to fetch tasks for linking: \(error.localizedDescription)")
            }
        }

        // Build a minimal history record
        let duration: TimeInterval = {
            if let enq = meta?.enqueuedAt { return Date().timeIntervalSince(enq) }
            return 0
        }()
        let bytes: Int64 = expectedBytes > 0 ? expectedBytes : 0

        let history = BackupHistory(
            id: UUID(),
            timestamp: Date(),
            status: status,
            filesProcessed: 1,
            totalFiles: 1,
            bytesTransferred: bytes,
            totalBytes: bytes,
            errorMessage: errorMessage,
            duration: duration,
            skippedFiles: 0,
            deletedFiles: 0,
            taskDisplayName: linkedTask?.displayName,
            taskSourcePath: linkedTask?.sourcePath,
            taskServerHost: linkedTask?.serverHost,
            taskServerPort: linkedTask?.serverPort,
            taskUsername: linkedTask?.serverUsername,
            taskIsAnonymous: linkedTask?.isAnonymous,
            taskMediaTypeRaw: linkedTask?.mediaType.rawValue,
            task: linkedTask
        )

        context.insert(history)
        do {
            try context.save()
            HistoryRetentionManager.pruneIfNeeded(context: context)
            logger.info("Persisted background upload history (status=\(status))")
        } catch {
            logger.error("Failed to save background upload history: \(error.localizedDescription)")
        }
    }
}
