import Foundation
import SwiftData
import SwiftUI

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
        case .idle: return "Hazır"
        case .preparing: return "Hazırlanıyor..."
        case .scanning: return "Dosyalar taranıyor..."
        case .uploading: return "Yükleniyor..."
        case .completed: return "Tamamlandı"
        case .failed: return "Hata oluştu"
        case .cancelled: return "İptal edildi"
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
        case .manual: return "Manuel"
        case .daily: return "Günlük"
        case .weekly: return "Haftalık"
        }
    }
    
    var scheduledTime: ScheduleTime? {
        switch self {
        case .daily(let time), .weekly(_, let time): return time
        case .manual: return nil
        }
    }
}

@Model
final class BackupTask: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var sourcePath: String
    var nextRunTime: Date?
    var ftpHost: String
    var ftpPort: Int
    var ftpUsername: String
    var ftpPassword: String
    var isAnonymous: Bool
    var displayName: String
    var isEnabled: Bool
    var frequency: BackupFrequency
    var createdAt: Date
    var lastBackupDate: Date?
    
    // Yeni eklenen özellikler
    var backupStatus: BackupStatus
    var progress: Double
    var currentFile: String?
    var lastError: String?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade) var history: [BackupHistory] = []
    
    // MARK: - Initialization
    init(
        sourcePath: String,
        ftpHost: String,
        ftpPort: Int,
        ftpUsername: String,
        ftpPassword: String,
        isAnonymous: Bool = false,
        displayName: String,
        isEnabled: Bool = true,
        frequency: BackupFrequency = .manual,
        lastBackupDate: Date? = nil,
        nextRunTime: Date? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.ftpHost = ftpHost
        self.ftpPort = ftpPort
        self.ftpUsername = ftpUsername
        self.ftpPassword = ftpPassword
        self.isAnonymous = isAnonymous
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.frequency = frequency
        self.createdAt = Date()
        self.lastBackupDate = lastBackupDate
        self.nextRunTime = nextRunTime
        self.backupStatus = .idle
        self.progress = 0.0
        self.currentFile = nil
        self.lastError = nil
    }
    
    // Hashable conformance for using in navigation link
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BackupTask, rhs: BackupTask) -> Bool {
        lhs.id == rhs.id
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
    
    // Relationship to parent task - simplified to avoid circular reference
    var task: BackupTask?
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalBytes))
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    var statusColor: Color {
        switch status.lowercased() {
        case "completed":
            return .green
        case "failed":
            return .red
        case "in progress", "uploading", "downloading":
            return .blue
        case "cancelled":
            return .orange
        default:
            return .gray
        }
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
        self.task = task
    }
}
