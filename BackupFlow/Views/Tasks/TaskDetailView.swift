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
            Section("Genel") {
                LabeledContent("Kaynak", value: URL(fileURLWithPath: task.sourcePath).lastPathComponent)
                LabeledContent("Durum", value: task.backupStatus.displayName)
                LabeledContent("Zamanlama", value: task.frequency.displayText)
                if let nextRun = task.nextRunTime {
                    LabeledContent("Sonraki Yedekleme", value: taskDateFormatter.string(from: nextRun))
                }
            }
            
            // Sunucu Bilgileri
            Section("Sunucu") {
                LabeledContent("Sunucu", value: task.ftpHost)
                LabeledContent("Port", value: String(task.ftpPort))
                LabeledContent("Kullanıcı", value: task.isAnonymous ? "Anonim" : task.ftpUsername)
            }
            
            // Son Yedeklemeler
            Section("Son Yedeklemeler") {
                if histories.isEmpty {
                    Text("Henüz yedekleme yapılmamış")
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
                Button("Kapat", action: { dismiss() })
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
            return "Manuel"
        case .daily(let time):
            return "Her gün \(String(format: "%02d:%02d", time.hour, time.minute))"
        case .weekly(let day, let time):
            let dayName = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"][day - 1]
            return "Her \(dayName) \(String(format: "%02d:%02d", time.hour, time.minute))"
        }
    }
}
