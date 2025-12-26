import Foundation
import SwiftData
import SwiftUI

/// Backup connection types
enum BackupType: String, Codable, CaseIterable, Identifiable {
    case ftp
    case webdav
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .ftp: return "FTP"
        case .webdav: return "WebDAV"
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .ftp: return 21
        case .webdav: return 443
        }
    }
}

enum BackupStatus: String, Codable, CaseIterable, Identifiable {
    case idle
    case preparing
    case scanning
    case uploading
    case completed
    case failed
    case cancelled
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .idle: return "backup.status.idle".localized
        case .preparing: return "backup.status.preparing".localized
        case .scanning: return "backup.status.scanning".localized
        case .uploading: return "backup.status.uploading".localized
        case .completed: return "backup.status.completed".localized
        case .failed: return "backup.status.failed".localized
        case .cancelled: return "backup.status.cancelled".localized
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .preparing, .scanning, .uploading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
}

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case photosOnly = "photos"
    case videosOnly = "videos" 
    case photosAndVideos = "both"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .photosOnly: return "media_type.photos_only".localized
        case .videosOnly: return "media_type.videos_only".localized
        case .photosAndVideos: return "media_type.photos_and_videos".localized
        }
    }
    
    var includesPhotos: Bool {
        self == .photosOnly || self == .photosAndVideos
    }
    
    var includesVideos: Bool {
        self == .videosOnly || self == .photosAndVideos
    }
    
    var systemImageName: String {
        switch self {
        case .photosOnly: return "photo"
        case .videosOnly: return "video"
        case .photosAndVideos: return "photo.stack"
        }
    }
}

nonisolated struct ScheduleTime: Codable, Equatable, Sendable {
    var hour: Int
    var minute: Int
    
    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }
    
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

nonisolated enum BackupFrequency: Codable, Equatable, Hashable, Identifiable, CaseIterable, @unchecked Sendable {
    case manual
    case daily(time: ScheduleTime)
    case weekly(day: Int, time: ScheduleTime) // 1: Sunday, 2: Monday, ..., 7: Saturday
    
    // For Picker compatibility
    static var allCases: [BackupFrequency] {
        let defaultTime = ScheduleTime(hour: 0, minute: 0)
        return [
            .manual,
            .daily(time: defaultTime),
            .weekly(day: 1, time: defaultTime) // Default to Sunday
        ]
    }
    
    // For Picker selection
    var tag: String {
        switch self {
        case .manual: return "manual"
        case .daily: return "daily"
        case .weekly: return "weekly"
        }
    }
    
    // For creating from tag
    static func from(tag: String, time: ScheduleTime = ScheduleTime(hour: 0, minute: 0)) -> BackupFrequency {
        switch tag {
        case "daily": return .daily(time: time)
        case "weekly": return .weekly(day: 1, time: time)
        default: return .manual
        }
    }
    
    var id: String {
        switch self {
        case .manual: return "manual"
        case .daily(let time): return "daily-\(time.hour)-\(time.minute)"
        case .weekly(let day, let time): return "weekly-\(day)-\(time.hour)-\(time.minute)"
        }
    }
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .manual:
            hasher.combine(0)
        case .daily(let time):
            hasher.combine(1)
            hasher.combine(time.hour)
            hasher.combine(time.minute)
        case .weekly(let day, let time):
            hasher.combine(2)
            hasher.combine(day)
            hasher.combine(time.hour)
            hasher.combine(time.minute)
        }
    }
    
    var displayName: String {
        switch self {
        case .manual: return "backup.frequency.manual".localized
        case .daily: return "backup.frequency.daily".localized
        case .weekly: return "backup.frequency.weekly".localized
        }
    }
    
    var scheduledTime: ScheduleTime? {
        switch self {
        case .daily(let time), .weekly(_, let time): return time
        case .manual: return nil
        }
    }
}

/// Represents a backup task that can be scheduled and executed
@Model
final class BackupTask: Identifiable, Hashable {
    // MARK: - Properties
    @Attribute(.unique) var id: UUID
    var sourcePath: String?
    var nextRunTime: Date?
    var createdAt: Date
    var lastBackupDate: Date?
    var displayName: String
    var isEnabled: Bool
    var isPaused: Bool
    var backupStatus: BackupStatus
    var progress: Double
    var currentFile: String?
    var lastError: String?
    
    // Network policy
    var allowCellularForLocalServer: Bool = false // Yeni özellik
    
    // Backup type (FTP or WebDAV)
    var backupType: BackupType
    
    // Server configuration
    var serverHost: String
    var serverPort: Int
    var serverUsername: String
    var serverPassword: String
    var destinationPath: String
    
    // Media type to backup
    var mediaType: MediaType
    
    // Scheduling
    var frequency: BackupFrequency
    var scheduledTime: ScheduleTime?
    var scheduledWeekday: Int? // 1: Sunday, 2: Monday, ..., 7: Saturday
    
    // MARK: - Computed Properties
    
    /// Legacy FTP host (for backward compatibility)
    var ftpHost: String {
        get { serverHost }
        set { serverHost = newValue }
    }
    
    /// Legacy FTP port (for backward compatibility)
    var ftpPort: Int {
        get { serverPort }
        set { serverPort = newValue }
    }
    
    /// Legacy FTP username (for backward compatibility)
    var ftpUsername: String {
        get { serverUsername }
        set { serverUsername = newValue }
    }
    
    /// Legacy FTP password (for backward compatibility)
    var ftpPassword: String {
        get { serverPassword }
        set { serverPassword = newValue }
    }
    
    /// Whether the connection is anonymous (no username/password)
    var isAnonymous: Bool {
        return serverUsername.isEmpty && serverPassword.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        sourcePath: String,
        backupType: BackupType = .ftp,
        serverHost: String = "",
        serverPort: Int = 21,
        serverUsername: String = "",
        serverPassword: String = "",
        destinationPath: String = "",
        displayName: String = "",
        isEnabled: Bool = true,
        isPaused: Bool = false,
        frequency: BackupFrequency = .manual,
        scheduledTime: ScheduleTime? = nil,
        scheduledWeekday: Int? = nil,
        mediaType: MediaType = .photosOnly,
        allowCellularForLocalServer: Bool = false,
        lastBackupDate: Date? = nil,
        nextRunTime: Date? = nil
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.backupType = backupType
        self.serverHost = serverHost
        self.serverPort = serverPort > 0 ? serverPort : backupType.defaultPort
        self.serverUsername = serverUsername
        self.serverPassword = serverPassword
        self.destinationPath = destinationPath
        self.displayName = displayName.isEmpty ? "Yeni Yedekleme" : displayName
        self.isEnabled = isEnabled
        self.isPaused = isPaused
        self.frequency = frequency
        self.scheduledTime = scheduledTime
        self.scheduledWeekday = scheduledWeekday
        self.mediaType = mediaType
        self.allowCellularForLocalServer = allowCellularForLocalServer
        self.createdAt = Date()
        self.lastBackupDate = lastBackupDate
        self.nextRunTime = nextRunTime
        self.backupStatus = .idle
        self.progress = 0.0
        self.currentFile = nil
        self.lastError = nil
    }
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: BackupTask, rhs: BackupTask) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Model
final class BackupHistory: Identifiable {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var status: String
    var filesProcessed: Int
    var totalFiles: Int
    var bytesTransferred: Int64
    var totalBytes: Int64
    var errorMessage: String?
    var duration: TimeInterval
    var skippedFiles: Int = 0
    var deletedFiles: Int = 0
    
    // Relationship to the task that created this history entry
    @Relationship var task: BackupTask?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        status: String,
        filesProcessed: Int = 0,
        totalFiles: Int = 0,
        bytesTransferred: Int64 = 0,
        totalBytes: Int64 = 0,
        errorMessage: String? = nil,
        duration: TimeInterval = 0,
        skippedFiles: Int = 0,
        deletedFiles: Int = 0,
        task: BackupTask? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.status = status
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.errorMessage = errorMessage
        self.duration = duration
        self.skippedFiles = skippedFiles
        self.deletedFiles = deletedFiles
        self.task = task
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytesTransferred)
    }
    
    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    var progress: Double {
        totalBytes > 0 ? Double(bytesTransferred) / Double(totalBytes) : 0.0
    }
    
    var progressPercentage: String {
        String(format: "%.1f%%", progress * 100)
    }
    
    var filesProcessedText: String {
        "\(filesProcessed) / \(totalFiles) dosya"
    }
    
    var isSuccess: Bool {
        errorMessage == nil && status == "completed"
    }
    
    var statusIcon: String {
        if status == "completed" {
            return "checkmark.circle.fill"
        } else if status == "failed" || status == "cancelled" {
            return "xmark.circle.fill"
        } else {
            return "arrow.clockwise.circle.fill"
        }
    }
    
    var statusColor: Color {
        if status == "completed" {
            return .green
        } else if status == "failed" || status == "cancelled" {
            return .red
        } else {
            return .blue
        }
    }
}
