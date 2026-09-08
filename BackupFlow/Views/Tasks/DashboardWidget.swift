import SwiftUI
import SwiftData
import Combine

struct DashboardWidget: View {
    @Query(sort: \BackupHistory.timestamp, order: .reverse) private var recentHistory: [BackupHistory]
    @Query(filter: #Predicate<BackupTask> { $0.isEnabled == true }) private var activeTasks: [BackupTask]
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Kullanıcının yerel saat dilimi - artık her ülkede çalışır! 🌍
    private let userTimeZone = TimeZone.current
    
    private var lastBackup: BackupHistory? {
        recentHistory.first
    }
    
    private var nextScheduledTask: BackupTask? {
        activeTasks.compactMap { task in
            // Skip paused tasks
            guard !task.isPaused && task.nextRunTime != nil else { return nil }
            return task
        }.min { task1, task2 in
            (task1.nextRunTime ?? Date.distantFuture) < (task2.nextRunTime ?? Date.distantFuture)
        }
    }
    
    private var isLastBackupSuccess: Bool {
        guard let backup = lastBackup else { return false }
        return backup.status == BackupStatus.completed.rawValue
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.blue)
                Text("dashboard.title".localized)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Stats Grid
            HStack(spacing: 12) {
                // Last Backup Status
                DashboardCard(
                    icon: lastBackupIcon,
                    iconColor: lastBackupColor,
                    title: "dashboard.last_backup".localized,
                    subtitle: lastBackupText
                )
                
                // Active Tasks Count  
                DashboardCard(
                    icon: "checklist",
                    iconColor: .green,
                    title: "dashboard.active_tasks".localized,
                    subtitle: "\(activeTasks.count)"
                )
            }
            
            // Next Scheduled Task
            if let nextTask = nextScheduledTask, let nextRun = nextTask.nextRunTime {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("dashboard.next_task".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(nextTask.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(timeUntilNextTask(nextRun, currentTime: currentTime))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .liquidCard(cornerRadius: 14)
        .onReceive(timer) { time in
            currentTime = time
        }
    }
    
    // MARK: - Computed Properties
    private var lastBackupIcon: String {
        guard lastBackup != nil else { return "questionmark.circle" }
        return isLastBackupSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var lastBackupColor: Color {
        guard lastBackup != nil else { return .gray }
        return isLastBackupSuccess ? .green : .red
    }
    
    private var lastBackupText: String {
        guard let backup = lastBackup else { 
            return "dashboard.never".localized
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: backup.timestamp)
    }
    
    private func timeUntilNextTask(_ nextRun: Date, currentTime: Date) -> String {
        // Kullanıcının yerel saat dilimine göre hesaplama
        let calendar = Calendar.current
        var userCalendar = calendar
        userCalendar.timeZone = userTimeZone
        
        // Şu anki zamanı al
        let now = Date()
        
        let timeInterval = nextRun.timeIntervalSince(now)
        
        // Grace period: Bildirimden gelince 30 saniye tolerans ver
        if timeInterval < -30 { // 30 saniyeden fazla gecikme varsa "overdue"
            return "dashboard.overdue".localized
        }
        
        // Küçük negatif değerler için 0 kabul et (notification gecikmesi)
        let adjustedTimeInterval = max(0, timeInterval)
        let totalSeconds = Int(adjustedTimeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours >= 1 {
            // 1 saat veya daha fazla: HH:MM formatı
            let result = String(format: "%02d:%02d", hours, minutes)
            return result
        } else {
            // 1 saatten az: MM:SS formatı
            let result = String(format: "%02d:%02d", minutes, seconds)
            return result
        }
    }
}

struct DashboardCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .liquidCard(cornerRadius: 12)
    }
}

#Preview {
    DashboardWidget()
        .modelContainer(for: [BackupTask.self, BackupHistory.self], inMemory: true)
        .padding()
}
