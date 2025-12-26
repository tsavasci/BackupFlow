import SwiftUI
import SwiftData

struct TaskDetailView: View {
    let task: BackupTask
    @Environment(\.dismiss) private var dismiss
    @Query private var histories: [BackupHistory]
    
    init(task: BackupTask) {
        self.task = task
        let taskId = task.id
        let descriptor = FetchDescriptor<BackupHistory>(
            predicate: #Predicate<BackupHistory> { history in
                history.task?.id == taskId
            },
            sortBy: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]
        )
        _histories = Query(descriptor, animation: .default)
    }
    
    private var taskDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale.current  // Kullanıcının locale'i
        formatter.timeZone = TimeZone.current  // Kullanıcının timezone'u
        return formatter
    }()
    
    private var fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter
    }()
    
    var body: some View {
        List {
            // Genel Bilgiler
            Section("task.general".localized) {
                LabeledContent("task.source".localized, value: URL(fileURLWithPath: task.sourcePath ?? "").lastPathComponent)
                LabeledContent("task.status".localized, value: task.backupStatus.displayName)
                LabeledContent("task.schedule".localized, value: task.frequency.displayText)
                if let nextRun = task.nextRunTime {
                    LabeledContent("task.next_run".localized, value: taskDateFormatter.string(from: nextRun))
                }
            }
            
            // Sunucu Bilgileri
            Section("task.server_section".localized) {
                LabeledContent("task.server".localized, value: task.ftpHost)
                LabeledContent("task.port".localized, value: String(task.ftpPort))
                LabeledContent("task.user".localized, value: task.isAnonymous ? "task.anonymous".localized : task.ftpUsername)
            }
            
            // Son Yedeklemeler
            Section("task.recent_backups".localized) {
                if histories.isEmpty {
                    Text("task.no_backups".localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(histories) { history in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(taskDateFormatter.string(from: history.timestamp))
                                    .font(.subheadline)
                                Spacer()
                                Text(history.status)
                                    .font(.caption)
                                    .foregroundStyle(history.status.lowercased() == "completed" ? .green : .red)
                            }
                            
                            if history.status.lowercased() == "completed" {
                                Text("\(history.totalFiles) dosya, \(fileSizeFormatter.string(fromByteCount: history.totalBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text("Süre: \(formatDuration(history.duration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.close".localized, action: { dismiss() })
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes) dk \(seconds) sn"
        } else {
            return "\(seconds) sn"
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
        }
    }
}
