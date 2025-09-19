import SwiftUI
import SwiftData

struct TaskRow: View {
    @State var task: BackupTask
    let onDelete: (BackupTask) -> Void
    
    @State private var showCancelAlert = false
    @State private var showDetailsSheet = false
    
    private var taskDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        return formatter
    }()
    
    private var fileSizeFormatter: ByteCountFormatter = {
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
            // Başlık ve Durum
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(task.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        if task.backupStatus != .idle {
                            Text(task.backupStatus.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(task.backupStatus.color.opacity(0.2))
                                .cornerRadius(4)
                                .foregroundColor(task.backupStatus.color)
                        }
                    }
                }
                Spacer()
                if task.backupStatus == .uploading {
                    Text("(\(Int(task.progress * 100))%)")
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
                    Text("Sonraki: \(taskDateFormatter.string(from: nextRun))")
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
                        Text("Son Yedekleme")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(taskDateFormatter.string(from: lastBackup))
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
                    
                    if let currentFile = task.currentFile {
                        Text(URL(fileURLWithPath: currentFile).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            if let lastError = task.lastError, task.backupStatus == .failed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Hata: \(lastError)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.vertical, 4)
        .sheet(isPresented: $showDetailsSheet) {
            NavigationView {
                TaskDetailView(task: task)
                    .navigationTitle("Görev Detayları")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .contextMenu {
            if task.backupStatus == .idle || task.backupStatus == .completed || task.backupStatus == .failed || task.backupStatus == .cancelled {
                Button(action: {
                    Task {
                        try? await BackupScheduler.shared.performBackup(task: task)
                    }
                }) {
                    Label("Yedeklemeyi Başlat", systemImage: "play.fill")
                }
            }
            
            if task.backupStatus == .uploading || task.backupStatus == .scanning || task.backupStatus == .preparing {
                Button(role: .destructive, action: {
                    task.backupStatus = .cancelled
                    showCancelAlert = true
                }) {
                    Label("Yedeklemeyi İptal Et", systemImage: "xmark.circle.fill")
                }
            }
        }
        .alert("Yedeklemeyi İptal Et", isPresented: $showCancelAlert) {
            Button("İptal", role: .cancel) {}
            Button("İptal Et", role: .destructive) {
                BackupScheduler.shared.cancelCurrentTask(for: task)
            }
        } message: {
            Text("Bu yedekleme işlemini durdurmak istediğinizden emin misiniz?")
        }
        .onChange(of: showCancelAlert) { oldValue, newValue in
            if !newValue {
                if task.backupStatus == .cancelled {
                    BackupScheduler.shared.cancelCurrentTask(for: task)
                }
            }
        }
    }
}
