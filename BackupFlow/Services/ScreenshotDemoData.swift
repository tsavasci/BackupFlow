#if DEBUG
import Foundation
import SwiftData

/// Sample tasks and history for App Store screenshots, enabled with the
/// `-ScreenshotDemoData` launch argument (DEBUG builds only).
///
/// The data lives in an in-memory store, so it never touches the user's real tasks,
/// and every task is scheduled in the future so nothing starts a backup.
enum ScreenshotDemoData {
    static var isEnabled: Bool {
        CommandLine.arguments.contains("-ScreenshotDemoData")
    }

    @MainActor
    static func seed(into container: ModelContainer) {
        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ days: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let tomorrowNight = calendar.date(
            bySettingHour: 2, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: 1, to: now) ?? now
        )

        let photos = BackupTask(
            sourcePath: "PHOTOS_LIBRARY",
            backupType: .webdav,
            serverHost: "https://cloud.example.com/remote.php/dav/files/",
            serverPort: 443,
            serverUsername: "family",
            destinationPath: "/Photos/iPhone",
            displayName: MediaType.photosOnly.displayName,
            frequency: .daily(time: ScheduleTime(hour: 2, minute: 0)),
            mediaType: .photosOnly,
            lastBackupDate: daysAgo(0, hour: 2, minute: 4),
            nextRunTime: tomorrowNight
        )
        let videos = BackupTask(
            sourcePath: "PHOTOS_LIBRARY",
            backupType: .sftp,
            serverHost: "nas.local",
            serverPort: 22,
            serverUsername: "backup",
            destinationPath: "/volume1/backups/iphone",
            displayName: MediaType.photosAndVideos.displayName,
            frequency: .weekly(day: 1, time: ScheduleTime(hour: 3, minute: 30)),
            mediaType: .photosAndVideos,
            lastBackupDate: daysAgo(2, hour: 3, minute: 41),
            nextRunTime: calendar.date(byAdding: .day, value: 5, to: now)
        )
        let archive = BackupTask(
            sourcePath: "PHOTOS_LIBRARY",
            backupType: .ftp,
            serverHost: "192.168.1.20",
            serverPort: 21,
            serverUsername: "archive",
            destinationPath: "/archive",
            displayName: MediaType.videosOnly.displayName,
            mediaType: .videosOnly,
            lastBackupDate: daysAgo(6, hour: 20, minute: 15)
        )
        [photos, videos, archive].forEach(context.insert)

        let runs: [(BackupTask, Date, String, Int, Int, Int64, TimeInterval)] = [
            (photos, daysAgo(0, hour: 2, minute: 4), "completed", 48, 1_236, 612_000_000, 214),
            (videos, daysAgo(2, hour: 3, minute: 41), "completed", 17, 2_904, 3_870_000_000, 1_322),
            (photos, daysAgo(1, hour: 2, minute: 3), "completed", 36, 1_188, 441_000_000, 176),
            (archive, daysAgo(6, hour: 20, minute: 15), "completed", 9, 214, 2_150_000_000, 684),
            (photos, daysAgo(2, hour: 2, minute: 5), "completed", 22, 1_152, 268_000_000, 121)
        ]
        for (task, date, status, newFiles, total, bytes, duration) in runs {
            context.insert(BackupHistory(
                timestamp: date,
                status: status,
                filesProcessed: total,
                totalFiles: total,
                bytesTransferred: bytes,
                totalBytes: bytes,
                duration: duration,
                skippedFiles: total - newFiles,
                newFiles: newFiles,
                taskDisplayName: task.displayName,
                taskSourcePath: task.sourcePath,
                taskServerHost: task.serverHost,
                taskServerPort: task.serverPort,
                taskUsername: task.serverUsername,
                taskIsAnonymous: false,
                taskMediaTypeRaw: task.mediaType.rawValue,
                task: task
            ))
        }
        try? context.save()
    }
}
#endif
