import BackgroundTasks
import Foundation
import UIKit

/// Runs user-initiated FTP/SFTP backups inside a `BGContinuedProcessingTask` (iOS 26+).
///
/// FTP and SFTP use raw sockets that iOS cannot hand off to a system transfer service
/// (unlike WebDAV's background `URLSession`), so without this the transfer stops about
/// 30 seconds after the app is backgrounded. A continued processing task keeps the app
/// running while the system shows progress in a Live Activity the user can cancel from.
@MainActor
final class ContinuedBackupRunner {
    static let shared = ContinuedBackupRunner()

    /// Must match the wildcard entry in `BGTaskSchedulerPermittedIdentifiers`.
    private static let identifierPrefix = (Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow") + ".continued."

    /// Read by the transfer services' UIKit background-task expiration handlers, which
    /// run off the main actor, so it is guarded by a lock rather than actor isolation.
    private static let runningLock = NSLock()
    nonisolated(unsafe) private static var _isRunning = false
    nonisolated static var isRunning: Bool {
        runningLock.withLock { _isRunning }
    }

    private static func setRunning(_ value: Bool) {
        runningLock.withLock { _isRunning = value }
    }

    /// Tasks waiting for the system to launch their submitted request, keyed by identifier.
    private var pendingTasks: [String: BackupTask] = [:]

    private init() {}

    /// Hands a user-initiated backup to a continued processing task.
    /// - Returns: `false` when the task can't be continued in the background (WebDAV, older iOS,
    ///   app not in the foreground, or the system declined), so the caller should run it directly.
    func start(task: BackupTask) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        // WebDAV already continues through its background URLSession.
        guard task.backupType == .ftp || task.backupType == .sftp else { return false }
        // Requests must be submitted by the foreground app in response to a user action.
        guard UIApplication.shared.applicationState == .active else { return false }

        // A fresh suffix per run: re-registering an identifier terminates the app.
        let identifier = Self.identifierPrefix + UUID().uuidString
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { bgTask in
            MainActor.assumeIsolated {
                ContinuedBackupRunner.shared.launch(bgTask)
            }
        }
        guard registered else {
            debugLog("⚠️ ContinuedBackup: Görev kaydı yapılamadı, ön planda çalıştırılacak")
            return false
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "backup.continued.title".localized,
            subtitle: task.displayName
        )
        // Start now or not at all; queuing would leave a tapped backup silently waiting.
        request.strategy = .fail

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            debugLog("⚠️ ContinuedBackup: Talep reddedildi (\(error.localizedDescription)), ön planda çalıştırılacak")
            return false
        }

        pendingTasks[identifier] = task
        debugLog("🚀 ContinuedBackup: Sürekli arka plan görevi gönderildi: \(task.displayName)")
        return true
    }

    @available(iOS 26.0, *)
    private func launch(_ bgTask: BGTask) {
        guard let bgTask = bgTask as? BGContinuedProcessingTask,
              let task = pendingTasks.removeValue(forKey: bgTask.identifier) else {
            bgTask.setTaskCompleted(success: false)
            return
        }
        Task {
            await run(bgTask, task: task)
        }
    }

    @available(iOS 26.0, *)
    private func run(_ bgTask: BGContinuedProcessingTask, task: BackupTask) async {
        Self.setRunning(true)
        defer { Self.setRunning(false) }

        let backupType = task.backupType
        // Called when the user cancels from the Live Activity or the system reclaims resources.
        bgTask.expirationHandler = {
            Task { @MainActor in
                debugLog("⏹️ ContinuedBackup: Görev sistem veya kullanıcı tarafından sonlandırıldı")
                switch backupType {
                case .ftp:
                    FTPService.shared.cancelCurrentTask()
                case .sftp:
                    SFTPService.shared.cancelCurrentTask()
                case .webdav:
                    break
                }
            }
        }

        // Mirror the task's progress into the system UI. The system terminates tasks that
        // report little or no progress first, so keep this updated throughout the run.
        let progressScale: Int64 = 1000
        bgTask.progress.totalUnitCount = progressScale
        let monitor = Task { @MainActor in
            var lastFile: String?
            while !Task.isCancelled {
                let fraction = task.progress.isFinite ? min(max(task.progress, 0), 1) : 0
                bgTask.progress.completedUnitCount = Int64(fraction * Double(progressScale))
                if let file = task.currentFile, !file.isEmpty, file != lastFile {
                    lastFile = file
                    bgTask.updateTitle(bgTask.title, subtitle: "\(task.displayName) · \(URL(fileURLWithPath: file).lastPathComponent)")
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }

        try? await BackupScheduler.shared.performBackup(task: task, bypassThrottle: true)
        monitor.cancel()

        let succeeded = task.backupStatus == .completed
        if succeeded {
            bgTask.progress.completedUnitCount = progressScale
        }
        bgTask.setTaskCompleted(success: succeeded)
        debugLog("🏁 ContinuedBackup: Görev bitti (başarılı: \(succeeded)): \(task.displayName)")
    }
}
