import Foundation
import SwiftData
import SwiftUI

/// Backup connection types
enum BackupType: String, Codable, CaseIterable, Identifiable {
    case ftp
    case sftp
    case webdav
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .ftp: return "backup.protocol.ftp".localized
        case .sftp: return "backup.protocol.sftp".localized
        case .webdav: return "backup.protocol.webdav".localized
        }
    }
    
    var defaultPort: Int {
        switch self {
        case .ftp: return 21
        case .sftp: return 22
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

enum BackupDeletionPolicy: String, Codable, CaseIterable, Identifiable {
    case mirror
    case appendOnly
    case archive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mirror: return "backup.deletion_policy.mirror".localized
        case .appendOnly: return "backup.deletion_policy.append_only".localized
        case .archive: return "backup.deletion_policy.archive".localized
        }
    }
}

enum BackupChecksumMode: String, Codable, CaseIterable, Identifiable {
    case off
    case verifyUploads

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "backup.checksum.off".localized
        case .verifyUploads: return "backup.checksum.verify_uploads".localized
        }
    }
}

enum BackupFailureCategory: String, Codable, CaseIterable, Identifiable {
    case network
    case auth
    case permission
    case server
    case quota
    case iCloud
    case certificate
    case cancelled
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .network: return "backup.failure.network".localized
        case .auth: return "backup.failure.auth".localized
        case .permission: return "backup.failure.permission".localized
        case .server: return "backup.failure.server".localized
        case .quota: return "backup.failure.quota".localized
        case .iCloud: return "backup.failure.icloud".localized
        case .certificate: return "backup.failure.certificate".localized
        case .cancelled: return "backup.failure.cancelled".localized
        case .unknown: return "backup.failure.unknown".localized
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
    case monthly(day: Int, time: ScheduleTime)
    case intervalHours(Int)
    
    // For Picker compatibility
    static var allCases: [BackupFrequency] {
        let defaultTime = ScheduleTime(hour: 0, minute: 0)
        return [
            .manual,
            .daily(time: defaultTime),
            .weekly(day: 1, time: defaultTime), // Default to Sunday
            .monthly(day: 1, time: defaultTime),
            .intervalHours(6)
        ]
    }
    
    // For Picker selection
    var tag: String {
        switch self {
        case .manual: return "manual"
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .intervalHours: return "intervalHours"
        }
    }
    
    // For creating from tag
    static func from(tag: String, time: ScheduleTime = ScheduleTime(hour: 0, minute: 0)) -> BackupFrequency {
        switch tag {
        case "daily": return .daily(time: time)
        case "weekly": return .weekly(day: 1, time: time)
        case "monthly": return .monthly(day: 1, time: time)
        case "intervalHours": return .intervalHours(6)
        default: return .manual
        }
    }
    
    var id: String {
        switch self {
        case .manual: return "manual"
        case .daily(let time): return "daily-\(time.hour)-\(time.minute)"
        case .weekly(let day, let time): return "weekly-\(day)-\(time.hour)-\(time.minute)"
        case .monthly(let day, let time): return "monthly-\(day)-\(time.hour)-\(time.minute)"
        case .intervalHours(let hours): return "interval-\(hours)"
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
        case .monthly(let day, let time):
            hasher.combine(3)
            hasher.combine(day)
            hasher.combine(time.hour)
            hasher.combine(time.minute)
        case .intervalHours(let hours):
            hasher.combine(4)
            hasher.combine(hours)
        }
    }
    
    var displayName: String {
        switch self {
        case .manual: return "backup.frequency.manual".localized
        case .daily: return "backup.frequency.daily".localized
        case .weekly: return "backup.frequency.weekly".localized
        case .monthly: return "backup.frequency.monthly".localized
        case .intervalHours: return "backup.frequency.interval_hours".localized
        }
    }
    
    var scheduledTime: ScheduleTime? {
        switch self {
        case .daily(let time), .weekly(_, let time), .monthly(_, let time): return time
        case .manual: return nil
        case .intervalHours: return nil
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
    var currentFileProgress: Double = 0.0
    var currentFileBytesTransferred: Int64 = 0
    var currentFileTotalBytes: Int64 = 0
    var transferSpeedBytesPerSecond: Double = 0.0
    var lastError: String?
    var lastFailureCategoryRaw: String?
    var consecutiveFailureCountValue: Int?
    
    // Network policy
    var allowCellularForLocalServer: Bool = false // Yeni özellik
    var includeICloudAssets: Bool = true
    var deletionPolicyRaw: String?
    var checksumModeRaw: String?
    var allowedStartTime: ScheduleTime?
    var allowedEndTime: ScheduleTime?
    var requiresExternalPowerValue: Bool?
    var requiresWiFiValue: Bool?
    /// Set while a scheduled run waits for Wi-Fi: the time after which this
    /// occurrence is skipped and the task moves on to its next regular run.
    var wifiWaitDeadline: Date?

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

    @Transient
    var lastFailureCategory: BackupFailureCategory? {
        get {
            guard let rawValue = lastFailureCategoryRaw else { return nil }
            return BackupFailureCategory(rawValue: rawValue)
        }
        set { lastFailureCategoryRaw = newValue?.rawValue }
    }

    @Transient
    var consecutiveFailureCount: Int {
        get { consecutiveFailureCountValue ?? 0 }
        set { consecutiveFailureCountValue = newValue }
    }

    @Transient
    var deletionPolicy: BackupDeletionPolicy {
        get { BackupDeletionPolicy(rawValue: deletionPolicyRaw ?? "") ?? .mirror }
        set { deletionPolicyRaw = newValue.rawValue }
    }

    @Transient
    var checksumMode: BackupChecksumMode {
        get { BackupChecksumMode(rawValue: checksumModeRaw ?? "") ?? .off }
        set { checksumModeRaw = newValue.rawValue }
    }

    @Transient
    var requiresExternalPower: Bool {
        get { requiresExternalPowerValue ?? false }
        set { requiresExternalPowerValue = newValue }
    }

    @Transient
    var requiresWiFi: Bool {
        get { requiresWiFiValue ?? false }
        set { requiresWiFiValue = newValue }
    }
    
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
        get { resolvedServerPassword }
        set { saveServerPassword(newValue) }
    }
    
    /// Whether the connection is anonymous (no username/password)
    var isAnonymous: Bool {
        return serverUsername.isEmpty && resolvedServerPassword.isEmpty
    }

    var resolvedServerPassword: String {
        if BackupCredentialStore.shared.isReference(serverPassword) {
            return BackupCredentialStore.shared.password(for: id) ?? ""
        }

        return serverPassword
    }

    func saveServerPassword(_ password: String) {
        if password.isEmpty {
            BackupCredentialStore.shared.deletePassword(for: id)
            serverPassword = ""
            return
        }

        BackupCredentialStore.shared.savePassword(password, for: id)
        serverPassword = BackupCredentialStore.shared.reference(for: id)
    }

    func migratePasswordToKeychainIfNeeded() {
        guard !serverPassword.isEmpty, !BackupCredentialStore.shared.isReference(serverPassword) else { return }
        saveServerPassword(serverPassword)
    }

    func removeStoredPassword() {
        BackupCredentialStore.shared.deletePassword(for: id)
        serverPassword = ""
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
        includeICloudAssets: Bool = true,
        deletionPolicy: BackupDeletionPolicy = .appendOnly,
        checksumMode: BackupChecksumMode = .off,
        allowedStartTime: ScheduleTime? = nil,
        allowedEndTime: ScheduleTime? = nil,
        requiresExternalPower: Bool = false,
        requiresWiFi: Bool = false,
        lastBackupDate: Date? = nil,
        nextRunTime: Date? = nil
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.backupType = backupType
        self.serverHost = serverHost
        self.serverPort = serverPort > 0 ? serverPort : backupType.defaultPort
        self.serverUsername = serverUsername
        self.serverPassword = ""
        self.destinationPath = destinationPath
        self.displayName = displayName.isEmpty ? "backup.default_task_name".localized : displayName
        self.isEnabled = isEnabled
        self.isPaused = isPaused
        self.frequency = frequency
        self.scheduledTime = scheduledTime
        self.scheduledWeekday = scheduledWeekday
        self.mediaType = mediaType
        self.allowCellularForLocalServer = allowCellularForLocalServer
        self.includeICloudAssets = includeICloudAssets
        self.deletionPolicyRaw = deletionPolicy.rawValue
        self.checksumModeRaw = checksumMode.rawValue
        self.allowedStartTime = allowedStartTime
        self.allowedEndTime = allowedEndTime
        self.requiresExternalPowerValue = requiresExternalPower
        self.requiresWiFiValue = requiresWiFi
        self.createdAt = Date()
        self.lastBackupDate = lastBackupDate
        self.nextRunTime = nextRunTime
        self.backupStatus = .idle
        self.progress = 0.0
        self.currentFile = nil
        self.currentFileProgress = 0.0
        self.currentFileBytesTransferred = 0
        self.currentFileTotalBytes = 0
        self.transferSpeedBytesPerSecond = 0.0
        self.lastError = nil
        self.lastFailureCategoryRaw = nil
        self.consecutiveFailureCountValue = 0
        self.saveServerPassword(serverPassword)
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
    var newFilesValue: Int?
    var updatedFilesValue: Int?
    var verifiedFilesValue: Int?
    var failureCategoryRaw: String?
    var previewSummarySnapshot: String?
    var taskDisplayName: String?
    var taskSourcePath: String?
    var taskServerHost: String?
    var taskServerPort: Int?
    var taskUsername: String?
    var taskIsAnonymous: Bool?
    var taskMediaTypeRaw: String?
    
    // Relationship to the task that created this history entry
    @Relationship var task: BackupTask?

    @Transient
    var newFiles: Int {
        get { newFilesValue ?? 0 }
        set { newFilesValue = newValue }
    }

    @Transient
    var updatedFiles: Int {
        get { updatedFilesValue ?? 0 }
        set { updatedFilesValue = newValue }
    }

    @Transient
    var verifiedFiles: Int {
        get { verifiedFilesValue ?? 0 }
        set { verifiedFilesValue = newValue }
    }

    @Transient
    var failureCategory: BackupFailureCategory? {
        get {
            guard let rawValue = failureCategoryRaw else { return nil }
            return BackupFailureCategory(rawValue: rawValue)
        }
        set { failureCategoryRaw = newValue?.rawValue }
    }
    
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
        newFiles: Int = 0,
        updatedFiles: Int = 0,
        verifiedFiles: Int = 0,
        failureCategory: BackupFailureCategory? = nil,
        previewSummarySnapshot: String? = nil,
        taskDisplayName: String? = nil,
        taskSourcePath: String? = nil,
        taskServerHost: String? = nil,
        taskServerPort: Int? = nil,
        taskUsername: String? = nil,
        taskIsAnonymous: Bool? = nil,
        taskMediaTypeRaw: String? = nil,
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
        self.newFilesValue = newFiles
        self.updatedFilesValue = updatedFiles
        self.verifiedFilesValue = verifiedFiles
        self.failureCategoryRaw = failureCategory?.rawValue
        self.previewSummarySnapshot = previewSummarySnapshot
        self.taskDisplayName = taskDisplayName
        self.taskSourcePath = taskSourcePath
        self.taskServerHost = taskServerHost
        self.taskServerPort = taskServerPort
        self.taskUsername = taskUsername
        self.taskIsAnonymous = taskIsAnonymous
        self.taskMediaTypeRaw = taskMediaTypeRaw
        self.task = task
    }
}

extension BackupHistory {
    /// User-facing name for a stored `status` value such as "completed" or "failed".
    /// Takes the raw string so plain-value row snapshots can use it too.
    static func localizedStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "completed":
            return "backup.status.completed".localized
        case "failed":
            return "backup.status.failed".localized
        case "cancelled":
            return "backup.status.cancelled".localized
        case "interrupted":
            return "backup.status.interrupted".localized
        case "deferred":
            return "backup.status.deferred".localized
        case "uploading":
            return "backup.status.uploading".localized
        case "scanning":
            return "backup.status.scanning".localized
        case "preparing":
            return "backup.status.preparing".localized
        default:
            return status.capitalized
        }
    }
}
