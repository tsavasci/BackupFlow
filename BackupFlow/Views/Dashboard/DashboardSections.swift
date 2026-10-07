import SwiftData
import SwiftUI

// Sections of the dashboard (MainTabView), top to bottom. They only display what they are
// given; anything that changes the dashboard's state is passed in as a closure.

// MARK: - Header

struct DashboardHeader: View {
    let greeting: String
    let statusText: String
    let statusColor: Color
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("dashboard.backup_hub".localized)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            HStack(spacing: 8) {
                Capsule()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("settings.title".localized)
            .accessibilityIdentifier("dashboard.settings")
        }
    }
}

// MARK: - Backup Progress

/// Shown while a backup runs: overall progress, speed, and the current file when it is large.
struct DashboardProgressCard: View {
    let activeTask: BackupTask?
    let progress: Double
    let message: String
    let theme: DashboardTheme
    let reduceMotion: Bool
    let onStop: (BackupTask) -> Void

    /// Files at least this big get their own progress bar.
    private static let largeFileProgressThresholdBytes: Int64 = 50 * 1024 * 1024

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("dashboard.backup_in_progress".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(DashboardFormat.percent(progress))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primary)
                if let activeTask {
                    Button(role: .destructive) {
                        onStop(activeTask)
                    } label: {
                        Label("backup.stop".localized, systemImage: "stop.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("dashboard.stop_backup")
                }
            }

            AnimatedDashboardProgressBar(
                progress: progress,
                theme: theme,
                reduceMotion: reduceMotion
            )

            HStack(alignment: .firstTextBaseline) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let activeTask, activeTask.transferSpeedBytesPerSecond > 1 {
                    Text("dashboard.speed_per_second".localized(with: DashboardFormat.bytes(Int64(activeTask.transferSpeedBytesPerSecond))))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let activeTask,
               activeTask.backupStatus == .uploading,
               activeTask.currentFileTotalBytes >= Self.largeFileProgressThresholdBytes {
                currentFileProgressView(for: activeTask)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func currentFileProgressView(for task: BackupTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MiniTransferProgressBar(
                progress: task.currentFileProgress > 0 ? task.currentFileProgress : nil,
                theme: DashboardTheme.theme(for: task.backupType),
                reduceMotion: reduceMotion
            )

            HStack(spacing: 6) {
                Text(currentFileDisplayName(for: task))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let detail = currentFileDetail(for: task) {
                    Text(detail)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func currentFileDisplayName(for task: BackupTask) -> String {
        guard let currentFile = task.currentFile?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentFile.isEmpty,
              currentFile != "/" else {
            return "backup.current_file.uploading".localized
        }

        let fileName = URL(fileURLWithPath: currentFile).lastPathComponent
        if !fileName.isEmpty && fileName != "/" {
            return fileName
        }

        return currentFile
    }

    private func currentFileDetail(for task: BackupTask) -> String? {
        if task.currentFileTotalBytes > 0 {
            let transferred = DashboardFormat.bytes(task.currentFileBytesTransferred)
            let total = DashboardFormat.bytes(task.currentFileTotalBytes)
            let percent = DashboardFormat.percent(task.currentFileProgress)
            let speed = task.transferSpeedBytesPerSecond > 1
                ? "dashboard.speed_per_second".localized(with: DashboardFormat.bytes(Int64(task.transferSpeedBytesPerSecond)))
                : nil

            if let speed {
                return "dashboard.transfer_detail_with_speed".localized(with: transferred, total, speed, percent)
            }
            return "dashboard.transfer_detail".localized(with: transferred, total, percent)
        }

        if task.currentFileProgress > 0 {
            return DashboardFormat.percent(task.currentFileProgress)
        }

        return nil
    }
}

// MARK: - Hero

struct DashboardHeroCard: View {
    let theme: DashboardTheme
    let lastSyncText: String
    /// Shown as a countdown in the corner; the progress percentage is shown when nil.
    let nextScheduledTask: BackupTask?
    let currentTime: Date
    let progress: Double
    let headline: String
    let subtitle: String
    let actionIconName: String
    let actionColor: Color
    let actionAccessibilityLabel: String
    let onAction: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primary,
                            theme.secondary,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 140, height: 140)
                .offset(x: 95, y: -50)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 80, height: 80)
                .offset(x: -110, y: 60)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("dashboard.last_sync".localized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(lastSyncText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let task = nextScheduledTask, let nextRun = task.nextRunTime {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("dashboard.next_task".localized)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                            Text(DashboardFormat.timeUntil(nextRun, from: currentTime))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(task.displayName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)
                        }
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 132, alignment: .trailing)
                        .accessibilityElement(children: .combine)
                    } else {
                        Text(DashboardFormat.percent(progress))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)

                    Button(action: onAction) {
                        Image(systemName: actionIconName)
                            .font(.headline.weight(.bold))
                            .frame(width: 48, height: 48)
                            .background(actionColor.opacity(0.92))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(actionAccessibilityLabel)
                    .layoutPriority(1)
                }
            }
            .padding(24)
        }
        .frame(height: 230)
    }
}

// MARK: - Health

struct DashboardHealthCard: View {
    let history: [BackupHistory]
    let tasks: [BackupTask]

    var body: some View {
        let completed = history.filter { $0.status == "completed" }.count
        let failed = history.filter { $0.status == "failed" }.count
        let total = max(completed + failed, 1)
        let successRate = Int((Double(completed) / Double(total)) * 100)
        let consecutiveFailures = tasks.map(\.consecutiveFailureCount).max() ?? 0
        // With no runs yet, show neutral, empty bars instead of a "healthy" state.
        let hasRuns = completed + failed > 0
        let averageDuration = history.isEmpty ? 0 : history.reduce(0) { $0 + $1.duration } / Double(history.count)

        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.health.title".localized)
                .font(.headline.weight(.semibold))

            HStack(spacing: 12) {
                DashboardInfoCard(
                    title: "dashboard.health.success".localized,
                    value: "\(successRate)%",
                    subtitle: "dashboard.health.runs".localized(with: completed, completed + failed),
                    color: !hasRuns ? .secondary : (successRate >= 80 ? .green : .orange),
                    progress: Double(successRate) / 100.0
                )
                DashboardInfoCard(
                    title: "dashboard.health.failures".localized,
                    value: "\(consecutiveFailures)",
                    subtitle: "dashboard.health.consecutive".localized,
                    color: !hasRuns ? .secondary : (consecutiveFailures == 0 ? .green : .red),
                    progress: !hasRuns ? 0 : (consecutiveFailures == 0 ? 1 : 0.35)
                )
            }

            if let lastSuccess = history.first(where: { $0.status == "completed" }) {
                Text("dashboard.health.last_success".localized(with: DashboardFormat.date(lastSuccess.timestamp)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("dashboard.health.average_duration".localized(with: DashboardFormat.duration(averageDuration)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Saved Servers

/// Plain-value copy of a task for a saved-server row. After a reset SwiftUI renders
/// each row once more with its previous element (and reads its id to diff), so rows
/// must not hold the model itself: a snapshot never touches the deleted task.
struct DashboardServerRow: Identifiable {
    let id: UUID
    let displayName: String
    let backupType: BackupType
    let destinationText: String
    let watermark: String
    let lastBackupDate: Date?
    let isScheduled: Bool
    let isPaused: Bool
    let isActive: Bool
}

struct DashboardServersSection: View {
    let rows: [DashboardServerRow]
    let theme: DashboardTheme
    let onAdd: () -> Void
    let onOpen: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onStart: (UUID) -> Void
    let onTogglePause: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("dashboard.saved_servers".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("dashboard.add".localized, action: onAdd)
                    .accessibilityIdentifier("dashboard.add")
                    .font(.subheadline)
                    .foregroundStyle(theme.primary)
            }

            if rows.isEmpty {
                Text("dashboard.no_saved_servers".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        serverRow(row)
                    }
                }
            }
        }
    }

    private func serverRow(_ row: DashboardServerRow) -> some View {
        let taskTheme = DashboardTheme.theme(for: row.backupType)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("dashboard.destination_format".localized(with: row.destinationText))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let lastUsed = row.lastBackupDate {
                    Text("dashboard.used_date".localized(with: DashboardFormat.date(lastUsed)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    onOpen(row.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.caption2)
                        .foregroundStyle(taskTheme.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("task.details.title".localized)
                .accessibilityIdentifier("dashboard.server_details")

                Button {
                    onDelete(row.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("tasks.delete".localized)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            taskTheme.primary.opacity(row.isActive ? 0.34 : 0.24),
                            taskTheme.secondary.opacity(row.isActive ? 0.26 : 0.18),
                            Color(.systemBackground).opacity(0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .bottomTrailing) {
                    Text(row.watermark)
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundStyle(taskTheme.primary.opacity(row.isActive ? 0.24 : 0.16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .padding(.trailing, 18)
                        .offset(y: 10)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            taskTheme.primary.opacity(row.isActive ? 0.62 : 0.38),
                            taskTheme.secondary.opacity(row.isActive ? 0.48 : 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: row.isActive ? 1.2 : 0.8
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onOpen(row.id)
        }
        .contextMenu {
            Button {
                onStart(row.id)
            } label: {
                Label("backup.notification.action.start".localized, systemImage: "play.fill")
            }

            if row.isScheduled {
                Button {
                    onTogglePause(row.id)
                } label: {
                    Label(
                        row.isPaused ? "task.resume.button".localized : "task.pause.button".localized,
                        systemImage: row.isPaused ? "play.circle" : "pause.fill"
                    )
                }
            }
        }
    }
}

// MARK: - Quick Actions

struct DashboardQuickActions: View {
    let theme: DashboardTheme
    let onSync: () -> Void
    let onShowHistory: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DashboardActionButton(icon: "arrow.triangle.2.circlepath", title: "dashboard.action.sync".localized, theme: theme, action: onSync)
            DashboardActionButton(icon: "clock.arrow.circlepath", title: "nav.history".localized, theme: theme, action: onShowHistory)
                .accessibilityIdentifier("dashboard.history")
            DashboardActionButton(icon: "plus.circle.fill", title: "dashboard.add".localized, theme: theme, action: onAdd)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Storage

struct DashboardStorageSection: View {
    let theme: DashboardTheme
    let transferredSizeText: String
    let totalSizeText: String
    let storageProgress: Double
    let currentCount: Int
    let totalCount: Int
    let hasTasks: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.storage_overview".localized)
                .font(.headline.weight(.semibold))

            HStack(spacing: 12) {
                DashboardInfoCard(
                    title: "dashboard.used".localized,
                    value: transferredSizeText,
                    subtitle: "dashboard.of_value".localized(with: totalSizeText),
                    color: theme.primary,
                    progress: storageProgress
                )
                DashboardInfoCard(
                    title: "dashboard.files".localized,
                    value: "\(currentCount)/\(totalCount)",
                    subtitle: hasTasks ? "dashboard.selected".localized : "dashboard.items_ready".localized,
                    color: theme.secondary,
                    progress: Double(currentCount) / Double(max(totalCount, 1))
                )
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Recent Backups

/// Same reasoning as `DashboardServerRow`: "reset all data" deletes history too.
struct DashboardRecentBackupRow: Identifiable {
    let id: PersistentIdentifier
    let displayName: String?
    let timestamp: Date
    let status: String
}

struct DashboardRecentBackupsSection: View {
    let rows: [DashboardRecentBackupRow]
    let theme: DashboardTheme
    let onSeeAll: () -> Void
    let onSelect: (PersistentIdentifier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.recent_backups".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("dashboard.see_all".localized, action: onSeeAll)
                    .font(.subheadline)
                    .foregroundStyle(theme.primary)
            }

            VStack(spacing: 12) {
                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(rows) { record in
                        Button {
                            onSelect(record.id)
                        } label: {
                            recentRow(record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("dashboard.recent_backup")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(theme.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.no_backups_yet".localized)
                    .font(.subheadline.weight(.semibold))
                Text("dashboard.start_backup_to_create_history".localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground).opacity(0.55))
        )
    }

    private func recentRow(_ record: DashboardRecentBackupRow) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: record.status == "failed" ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(record.status == "failed" ? .red : theme.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.displayName ?? "dashboard.backup".localized)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(DashboardFormat.date(record.timestamp))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(BackupHistory.localizedStatus(record.status))
                .font(.caption.weight(.semibold))
                .foregroundStyle(record.status == "failed" ? .red : .green)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground).opacity(0.55))
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
