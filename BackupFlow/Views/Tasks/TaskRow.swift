import SwiftUI
import SwiftData
import UserNotifications

struct TaskRow: View {
    @Bindable var task: BackupTask
    let onDelete: (BackupTask) -> Void

    @State private var showCancelAlert = false
    @State private var showDetailsSheet = false
    @State private var showErrorSheet = false

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
    
    init(task: BackupTask, onDelete: @escaping (BackupTask) -> Void) {
        self.task = task
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Satır: Görev adı ve aksiyon butonları
            HStack(alignment: .top) {
                // Görev adı (tüm genişliği kaplar)
                VStack(alignment: .leading, spacing: 4) {
                    if (task.sourcePath ?? "") == "PHOTOS_LIBRARY" {
                        Image(systemName: task.mediaType.systemImageName)
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    Text(task.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .padding(.trailing, 8)
                }
                
                Spacer()
                
                // Pause/Play Button (sağ üstte sabit)
                if task.frequency != .manual {
                    Button(action: {
                        togglePauseResume()
                    }) {
                        Image(systemName: task.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(task.isPaused ? .green : .orange)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // 2. Satır: Durum ve protokol rozeti
            HStack(spacing: 8) {
                if task.backupStatus != .idle {
                    Text(task.backupStatus.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.backupStatus.color.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(task.backupStatus.color)
                }
                
                // Protokol rozeti
                switch task.backupType {
                case .webdav:
                    Text(task.backupType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                case .ftp:
                    Text(task.backupType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.25))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                case .sftp:
                    Text(task.backupType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                // Pause/Resume badge
                if task.isPaused {
                    Text("task.status.paused".localized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // İlerleme yüzdesi (sağ üstte)
                if task.backupStatus == .uploading {
                    Text("\(Int(task.progress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.accentColor)
                }
            }
            
            // Yedekleme Zamanlaması
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text(task.frequency.displayText)
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "clock")
                }
                if let nextRun = task.nextRunTime {
                    Text("\("tasks.next_run".localized): \(Self.taskDateFormatter.string(from: nextRun))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sunucu Bilgisi
            Label {
                Text("\(task.ftpHost):\(task.ftpPort)")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "network")
            }
            
            Divider()
            
            // Son Yedekleme Bilgileri
            if let lastBackup = task.lastBackupDate {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.last_backup".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Self.taskDateFormatter.string(from: lastBackup))
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Button {
                        showDetailsSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            // İlerleme ve Hata Durumu
            if task.backupStatus != .idle && task.backupStatus != .completed && task.backupStatus != .failed && task.backupStatus != .cancelled {
                VStack(spacing: 4) {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                        .tint(task.backupStatus.color)
                    
                    HStack(alignment: .firstTextBaseline) {
                        if let currentFile = task.currentFile {
                            Text(URL(fileURLWithPath: currentFile).lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if task.backupStatus == .uploading && task.transferSpeedBytesPerSecond > 1 {
                            Text("dashboard.speed_per_second".localized(with: Self.fileSizeFormatter.string(fromByteCount: Int64(task.transferSpeedBytesPerSecond))))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            
            if let lastError = task.lastError, task.backupStatus == .failed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(String(format: "history.error_occurred".localized, lastError))
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showErrorSheet = true
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            showDetailsSheet = true
        }
        .liquidCard(cornerRadius: 14)
        .padding(.vertical, 4)
        .sheet(isPresented: $showDetailsSheet) {
            NavigationView {
                TaskDetailView(task: task)
                    .navigationTitle("task.details.title".localized)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showErrorSheet) {
            NavigationView {
                ScrollView {
                    if let lastError = task.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .padding()
                    } else {
                        Text("error.unexpected".localized(with: ""))
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                }
                .navigationTitle("alert.error".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close".localized) {
                            showErrorSheet = false
                        }
                    }
                }
            }
        }
        .contextMenu {
            if task.backupStatus == .idle || task.backupStatus == .completed || task.backupStatus == .failed || task.backupStatus == .cancelled {
                Button(action: {
                    Task {
                        try? await BackupScheduler.shared.performBackup(task: task)
                    }
                }) {
                    Label("backup.notification.action.start".localized, systemImage: "play.fill")
                }
            }
            
            // Pause/Resume options for scheduled tasks
            if task.frequency != .manual {
                if task.isPaused {
                    Button(action: {
                        resumeTask()
                    }) {
                        Label("task.resume.button".localized, systemImage: "play.circle")
                    }
                } else {
                    Button(action: {
                        pauseTask()
                    }) {
                        Label("task.pause.button".localized, systemImage: "pause.circle")
                    }
                }
            }
            
            if task.backupStatus == .uploading || task.backupStatus == .scanning || task.backupStatus == .preparing {
                Button(role: .destructive, action: {
                    showCancelAlert = true
                }) {
                    Label("backup.cancel_backup_title".localized, systemImage: "xmark.circle.fill")
                }
            }
        }
        .alert("backup.cancel_backup_title".localized, isPresented: $showCancelAlert) {
            Button("alert.cancel".localized, role: .cancel) {}
            Button("backup.cancel_backup_confirm".localized, role: .destructive) {
                task.backupStatus = .cancelled
                BackupScheduler.shared.cancelCurrentTask(for: task)
            }
        } message: {
            Text("backup.cancel_backup_message".localized)
        }
    }
    
    // MARK: - Pause/Resume Functions
    private func togglePauseResume() {
        if task.isPaused {
            resumeTask()
        } else {
            pauseTask()
        }
    }
    
    private func pauseTask() {
        task.isPaused = true
        BackupScheduler.shared.pauseTask(task)
        
        // Send notification
        let content = UNMutableNotificationContent()
        content.title = "task.paused.notification.title".localized
        content.body = String(format: "task.paused.notification.body".localized, task.displayName)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "task-paused-\(task.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func resumeTask() {
        task.isPaused = false
        BackupScheduler.shared.resumeTask(task)
        
        // Send notification
        let content = UNMutableNotificationContent()
        content.title = "task.resumed.notification.title".localized
        content.body = String(format: "task.resumed.notification.body".localized, task.displayName)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "task-resumed-\(task.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
