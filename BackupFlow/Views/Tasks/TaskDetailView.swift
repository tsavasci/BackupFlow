import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let task: BackupTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var histories: [BackupHistory] = []
    @State private var isLoading = true
    @State private var showingEdit = false
    
    init(task: BackupTask) {
        self.task = task
    }
    
    private static let taskDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter
    }()
    
    var body: some View {
        List {
            // Genel Bilgiler
            Section("task.details.general".localized) {
                LabeledContent(
                    "task.details.source".localized,
                    value: task.sourcePath == "PHOTOS_LIBRARY"
                        ? "backup.photos_option".localized
                        : URL(fileURLWithPath: task.sourcePath ?? "").lastPathComponent
                )
                LabeledContent("task.details.status".localized, value: task.backupStatus.displayName)
                LabeledContent("task.details.schedule".localized, value: task.frequency.displayText)
                LabeledContent("backup.deletion_policy".localized, value: task.deletionPolicy.displayName)
                LabeledContent("backup.checksum".localized, value: task.checksumMode.displayName)
                if task.requiresWiFi {
                    LabeledContent("task.details.network".localized, value: "backup.require_wifi".localized)
                }
                if task.requiresExternalPower {
                    LabeledContent("task.details.power".localized, value: "backup.require_external_power".localized)
                }
                if let category = task.lastFailureCategory {
                    LabeledContent("task.details.last_failure".localized, value: category.displayName)
                }
                if let nextRun = task.nextRunTime {
                    LabeledContent("task.details.next_backup".localized, value: Self.taskDateFormatter.string(from: nextRun))
                }
            }
            .liquidListRow()
            
            // Sunucu Bilgileri
            Section("task.details.server_section".localized) {
                LabeledContent("task.details.server".localized, value: task.ftpHost)
                LabeledContent("task.details.port".localized, value: String(task.ftpPort))
                LabeledContent("task.details.user".localized, value: task.isAnonymous ? "task.details.anonymous".localized : task.ftpUsername)
            }
            .liquidListRow()
            
            // Son Yedeklemeler
            Section("task.details.recent_backups".localized) {
                if isLoading {
                    ProgressView()
                } else if histories.isEmpty {
                    Text("task.details.no_backups".localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(histories) { history in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(Self.taskDateFormatter.string(from: history.timestamp))
                                    .font(.subheadline)
                                Spacer()
                                Text(localizedHistoryStatus(history.status))
                                    .font(.caption)
                                    .foregroundStyle(history.status == BackupStatus.completed.rawValue ? .green : .red)
                            }
                            
                            if history.status == BackupStatus.completed.rawValue {
                                Text("\(history.totalFiles)\("task.details.files_size".localized)\(Self.fileSizeFormatter.string(fromByteCount: history.totalBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("task.details.duration_prefix".localized + formatDuration(history.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .liquidListRow()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("common.edit".localized) {
                    showingEdit = true
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("task.details.close".localized, action: { dismiss() })
                    .accessibilityIdentifier("sheet.close")
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                BackupView(editingTask: task)
            }
        }
        .scrollContentBackground(.hidden)
        .liquidBackground()
        .onAppear {
            loadHistories()
        }
    }
    
    private func loadHistories() {
        let taskId = task.id
        let descriptor = FetchDescriptor<BackupHistory>(
            predicate: #Predicate<BackupHistory> { history in
                history.task?.id == taskId
            },
            sortBy: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]
        )
        
        do {
            histories = try modelContext.fetch(descriptor)
        } catch {
            debugLog("Histories yükleme hatası: \(error)")
        }
        isLoading = false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)\("task.details.minutes_short".localized)\(seconds)\("task.details.seconds_short".localized)"
        } else {
            return "\(seconds)\("task.details.seconds_short".localized)"
        }
    }

    private func localizedHistoryStatus(_ status: String) -> String {
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

extension BackupFrequency {
    var displayText: String {
        switch self {
        case .manual:
            return "task.details.manual".localized
        case .daily(let time):
            return "task.details.daily_prefix".localized + String(format: "%02d:%02d", time.hour, time.minute)
        case .weekly(let day, let time):
            let dayNames = [
                "day.names.sunday".localized,
                "day.names.monday".localized,
                "day.names.tuesday".localized,
                "day.names.wednesday".localized,
                "day.names.thursday".localized,
                "day.names.friday".localized,
                "day.names.saturday".localized
            ]
            let dayName = (day >= 1 && day <= 7) ? dayNames[day - 1] : ""
            return "task.details.weekly_prefix".localized + dayName + " " + String(format: "%02d:%02d", time.hour, time.minute)
        case .monthly(let day, let time):
            return "task.details.monthly_format".localized(with: day, String(format: "%02d:%02d", time.hour, time.minute))
        case .intervalHours(let hours):
            return "task.details.interval_hours_format".localized(with: hours)
        }
    }
}
