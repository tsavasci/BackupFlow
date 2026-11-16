import SwiftData
import SwiftUI

// Sections of the dashboard (MainTabView), top to bottom. They only display what they are
// given; anything that changes the dashboard's state is passed in as a closure.

// MARK: - Header

struct DashboardHeader: View {
    let greeting: String
    let statusText: String
    let statusColor: Color
    var onTapHub: (() -> Void)? = nil
    var onTapStatus: (() -> Void)? = nil
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onTapHub?()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.28),
                                    DesignSystem.Colors.cardSurface
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 23
                            )
                        )
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary,
                                    DesignSystem.Colors.electricBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.65), radius: 8)

                    Image(systemName: "externaldrive.connected.to.line.below.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.6), radius: 4)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(greeting)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.slateMuted.opacity(0.5))

                    Button {
                        onTapStatus?()
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 7, height: 7)
                                .shadow(color: statusColor.opacity(0.85), radius: 4)

                            Text(statusText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.slateMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.92))
                                .overlay(
                                    Capsule()
                                        .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.75), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onTapHub?()
                } label: {
                    Text("dashboard.backup_hub".localized)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.5), radius: 4)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                DesignSystem.Colors.primary.opacity(0.65),
                                                DesignSystem.Colors.rimBorderMuted.opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .accessibilityHidden(true)
            }
            .buttonStyle(TelemetryPressButtonStyle(scale: 0.92))
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
                HStack(spacing: 8) {
                    TelemetrySignalBars(color: theme.primary, level: max(progress, 0.25))
                    Text("dashboard.backup_in_progress".localized.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                }
                Spacer()
                Text(DashboardFormat.percent(progress))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .shadow(color: theme.primary.opacity(0.5), radius: 5)
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
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let activeTask, activeTask.transferSpeedBytesPerSecond > 1 {
                    Text("dashboard.speed_per_second".localized(with: DashboardFormat.bytes(Int64(activeTask.transferSpeedBytesPerSecond))))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.mintNeon)
                }
            }

            if let activeTask,
               activeTask.backupStatus == .uploading,
               activeTask.currentFileTotalBytes >= Self.largeFileProgressThresholdBytes {
                currentFileProgressView(for: activeTask)
            }
        }
        .padding(16)
        .telemetryCard(theme: theme, cornerRadius: 22, glowOpacity: 0.22)
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
            .foregroundStyle(DesignSystem.Colors.slateMuted)
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
                ? "dashboard.speed_per_second".localized(with: DashboardFormat.bytes(Int64(activeTaskValue(task.transferSpeedBytesPerSecond))))
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

    private func activeTaskValue(_ value: Double) -> Double {
        value
    }
}

// MARK: - Hero (TOTAL DATA STREAM Telemetry Card)

struct DashboardHeroCard: View {
    let theme: DashboardTheme
    let lastSyncText: String
    /// Shown as a countdown in the corner; the progress percentage is shown when nil.
    let nextScheduledTask: BackupTask?
    let currentTime: Date
    let progress: Double
    let headline: String
    let subtitle: String
    let sparklinePoints: [Double]
    let sparklineSecondaryPoints: [Double]
    let actionIconName: String
    let actionColor: Color
    let actionAccessibilityLabel: String
    let onAction: () -> Void
    var onOpenTask: ((BackupTask) -> Void)? = nil
    var onOpenPrimaryTask: (() -> Void)? = nil
    var onOpenHistory: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top micro-header row
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onOpenHistory?()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("dashboard.last_sync".localized.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(DesignSystem.Colors.slateMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(theme.primary.opacity(0.8))
                                .accessibilityHidden(true)
                        }

                        Text(lastSyncText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.slateMuted.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                if let task = nextScheduledTask, let nextRun = task.nextRunTime {
                    Button {
                        onOpenTask?(task)
                    } label: {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("dashboard.next_task".localized.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .tracking(0.6)
                                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.primary)
                                    .accessibilityHidden(true)
                            }
                            Text(DashboardFormat.timeUntil(nextRun, from: currentTime))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.primary)
                                .monospacedDigit()
                                .shadow(color: theme.primary.opacity(0.55), radius: 6)
                                .lineLimit(1)
                            Text(task.displayName)
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.slateMuted)
                                .lineLimit(1)
                        }
                        .multilineTextAlignment(.trailing)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                } else {
                    Button {
                        onOpenHistory?()
                    } label: {
                        HStack(spacing: 6) {
                            Text(DashboardFormat.percent(progress))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.primary)
                                .monospacedDigit()
                            TelemetrySignalBars(color: theme.primary, level: progress)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Massive luminous cyan headline + server subtitle (tappable to open primary task or setup)
            Button {
                onOpenPrimaryTask?()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    theme.primary,
                                    Color.white.opacity(0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: theme.primary.opacity(0.45), radius: 10, x: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.mintNeon)
                            .accessibilityHidden(true)

                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DesignSystem.Colors.mintNeon)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Bottom row: Real-data dual-wave sparkline + neon action button
            HStack(alignment: .center, spacing: 12) {
                Button {
                    onOpenHistory?()
                } label: {
                    TelemetrySparklineView(
                        theme: theme,
                        points: sparklinePoints,
                        secondaryPoints: sparklineSecondaryPoints
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onAction) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.primary.opacity(0.26),
                                        theme.secondary.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [theme.primary, theme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.6
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: theme.primary.opacity(0.65), radius: 8)

                        Image(systemName: actionIconName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .shadow(color: theme.primary.opacity(0.7), radius: 4)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(TelemetryPressButtonStyle(scale: 0.92))
                .accessibilityLabel(actionAccessibilityLabel)
                .layoutPriority(1)
            }
        }
        .padding(20)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
    }
}

// MARK: - Health (SYSTEM PERFORMANCE Spline + CORE LOAD Ring Bento)

struct DashboardHealthCard: View {
    let history: [BackupHistory]
    let tasks: [BackupTask]
    var onOpenHistory: (() -> Void)? = nil
    var onSelectHistory: ((PersistentIdentifier) -> Void)? = nil
    var onOpenFailedTask: ((BackupTask) -> Void)? = nil
    var onEmptyAction: (() -> Void)? = nil

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        let completed = history.filter { $0.status == "completed" }.count
        let failed = history.filter { $0.status == "failed" }.count
        let total = max(completed + failed, 1)
        let successRate = Int((Double(completed) / Double(total)) * 100)
        let consecutiveFailures = tasks.map(\.consecutiveFailureCount).max() ?? 0
        let hasRuns = completed + failed > 0
        let averageDuration = history.isEmpty ? 0 : history.reduce(0) { $0 + $1.duration } / Double(history.count)
        let theme = DashboardTheme.webDAV
        let failedTask = tasks.first { $0.consecutiveFailureCount > 0 }
        let latestCompleted = history.first { $0.status == "completed" }

        VStack(alignment: .leading, spacing: 16) {
            // 1. SYSTEM PERFORMANCE Spline Telemetry Card (100% real BackupHistory data)
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("dashboard.health.title".localized.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                    Spacer()
                    if let onOpenHistory {
                        Button(action: onOpenHistory) {
                            HStack(spacing: 4) {
                                Text("dashboard.see_all".localized)
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .accessibilityHidden(true)
                            }
                            .foregroundStyle(theme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                TelemetrySplineChartView(
                    points: chartPoints,
                    theme: theme,
                    emptyTitle: "dashboard.no_backups_yet".localized,
                    emptySubtitle: "dashboard.start_backup_to_create_history".localized,
                    onEmptyTap: onEmptyAction
                )

                ViewThatFits(in: .horizontal) {
                    HStack {
                        if let lastSuccess = latestCompleted {
                            Button {
                                onSelectHistory?(lastSuccess.persistentModelID)
                            } label: {
                                Text("dashboard.health.last_success".localized(with: DashboardFormat.date(lastSuccess.timestamp)))
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 8)
                        Text("dashboard.health.average_duration".localized(with: DashboardFormat.duration(averageDuration)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let lastSuccess = latestCompleted {
                            Button {
                                onSelectHistory?(lastSuccess.persistentModelID)
                            } label: {
                                Text("dashboard.health.last_success".localized(with: DashboardFormat.date(lastSuccess.timestamp)))
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("dashboard.health.average_duration".localized(with: DashboardFormat.duration(averageDuration)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(18)
            .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.18)

            // 2. Side-by-Side Bento: CORE LOAD Circular Ring Gauge + Interactive Telemetry Breakdown
            HStack(spacing: 10) {
                // Left: CORE LOAD Ring Card (tappable to open HistoryView)
                Button {
                    onOpenHistory?()
                } label: {
                    VStack {
                        TelemetryRingGauge(
                            title: "dashboard.health.success".localized,
                            valueText: "\(successRate)%",
                            detailLine1: "dashboard.health.runs".localized(with: completed, completed + failed),
                            detailLine2: nil,
                            progress: hasRuns ? Double(successRate) / 100.0 : 0.04,
                            theme: theme,
                            ringSize: 114,
                            lineWidth: 10
                        )
                    }
                    .padding(12)
                    .frame(width: 142)
                    .frame(maxHeight: .infinity)
                    .telemetryCard(theme: theme, cornerRadius: 22, glowOpacity: 0.18)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(TelemetryPressButtonStyle())

                // Right: Active Telemetry Metrics Card (each row is an interactive button)
                VStack(alignment: .leading, spacing: 10) {
                    Text("dashboard.health.title".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    telemetryMetricRow(
                        label: "dashboard.health.success".localized,
                        bracketValue: "\(successRate)%",
                        valueColor: DesignSystem.Colors.mintNeon,
                        barColor: theme.primary,
                        level: hasRuns ? Double(successRate) / 100.0 : 0.0,
                        action: {
                            if let latestCompleted {
                                onSelectHistory?(latestCompleted.persistentModelID)
                            } else {
                                onOpenHistory?()
                            }
                        }
                    )

                    Divider()
                        .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.45))

                    telemetryMetricRow(
                        label: "dashboard.health.failures".localized,
                        bracketValue: "\(consecutiveFailures)",
                        valueColor: consecutiveFailures == 0 ? theme.primary : DesignSystem.Colors.error,
                        barColor: consecutiveFailures == 0 ? theme.primary : DesignSystem.Colors.error,
                        level: !hasRuns ? 0.0 : (consecutiveFailures == 0 ? 1.0 : 0.65),
                        action: {
                            if let failedTask {
                                onOpenFailedTask?(failedTask)
                            } else {
                                onOpenHistory?()
                            }
                        }
                    )

                    Divider()
                        .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.45))

                    telemetryMetricRow(
                        label: "history.stats.duration".localized,
                        bracketValue: DashboardFormat.duration(averageDuration),
                        valueColor: theme.primary,
                        barColor: theme.secondary,
                        level: hasRuns ? min(max(averageDuration / 60.0, 0.25), 1.0) : 0.0,
                        action: {
                            if let first = history.first {
                                onSelectHistory?(first.persistentModelID)
                            } else {
                                onOpenHistory?()
                            }
                        }
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .telemetryCard(theme: theme, cornerRadius: 22, glowOpacity: 0.15)
            }
        }
    }

    private func telemetryMetricRow(
        label: String,
        bracketValue: String,
        valueColor: Color,
        barColor: Color,
        level: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)

                Text("[\(bracketValue)]")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .fixedSize()

                Spacer(minLength: 2)

                TelemetrySignalBars(color: barColor, level: level)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var chartPoints: [TelemetryChartPoint] {
        let recent = Array(history.prefix(6).reversed())
        guard !recent.isEmpty else { return [] }

        let maxFiles = Double(recent.map { max($0.filesProcessed, 1) }.max() ?? 1)
        let maxBytes = Double(recent.map { max($0.bytesTransferred, 1) }.max() ?? 1)

        return recent.enumerated().map { idx, item in
            let filesRatio = Double(max(item.filesProcessed, 0)) / max(maxFiles, 1)
            let bytesRatio = Double(max(item.bytesTransferred, 0)) / max(maxBytes, 1)
            let pVal = item.filesProcessed > 0 ? min(max(0.18 + filesRatio * 0.72, 0.16), 0.90) : 0.12
            let sVal = item.bytesTransferred > 0 ? min(max(0.14 + bytesRatio * 0.68, 0.12), 0.84) : 0.10
            let modelID = item.persistentModelID

            return TelemetryChartPoint(
                id: idx,
                label: Self.hourFormatter.string(from: item.timestamp),
                title: item.taskDisplayName ?? "dashboard.backup".localized,
                summary: "\(item.filesProcessed) • \(DashboardFormat.bytes(item.bytesTransferred)) • \(DashboardFormat.duration(item.duration))",
                primaryValue: pVal,
                secondaryValue: sVal,
                onTap: {
                    onSelectHistory?(modelID)
                }
            )
        }
    }
}

// MARK: - Saved Servers (Active Modules Style)

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.saved_servers".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                Spacer()
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .accessibilityHidden(true)
                        Text("dashboard.add".localized)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primary.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(theme.primary.opacity(0.45), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dashboard.add")
            }

            if rows.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.primary)
                            .accessibilityHidden(true)
                        Text("dashboard.no_saved_servers".localized)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        serverRow(row)
                    }
                }
            }
        }
        .padding(18)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.16)
    }

    private func serverRow(_ row: DashboardServerRow) -> some View {
        let taskTheme = DashboardTheme.theme(for: row.backupType)
        let signalLevel: Double = row.isActive ? 1.0 : (row.isPaused ? 0.15 : (row.lastBackupDate != nil ? 0.82 : 0.50))

        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 6) {
                    Text("[\(row.watermark)]")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(taskTheme.primary)
                        .shadow(color: taskTheme.primary.opacity(0.45), radius: 3)
                        .fixedSize()

                    TelemetrySignalBars(color: taskTheme.primary, level: signalLevel)

                    Text("dashboard.destination_format".localized(with: row.destinationText))
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let lastUsed = row.lastBackupDate {
                    Text("dashboard.used_date".localized(with: DashboardFormat.date(lastUsed)))
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.slateMuted.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 0) {
                Button {
                    onStart(row.id)
                } label: {
                    Image(systemName: row.isActive ? "bolt.horizontal.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.mintNeon)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("backup.notification.action.start".localized)

                Button {
                    onOpen(row.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(taskTheme.primary)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("task.details.title".localized)
                .accessibilityIdentifier("dashboard.server_details")

                Button {
                    onDelete(row.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.error)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("tasks.delete".localized)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            taskTheme.primary.opacity(row.isActive ? 0.22 : 0.10),
                            DesignSystem.Colors.cardSurface.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            taskTheme.primary.opacity(row.isActive ? 0.78 : 0.42),
                            DesignSystem.Colors.rimBorderMuted.opacity(0.45),
                            taskTheme.secondary.opacity(row.isActive ? 0.55 : 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: row.isActive ? 1.3 : 0.9
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onOpen(row.id)
        }
        .accessibilityAddTraits(.isButton)
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

// MARK: - Quick Actions (Floating Dark-Glass Bottom Dock)

struct DashboardQuickActions: View {
    let theme: DashboardTheme
    let onSync: () -> Void
    let onShowHistory: () -> Void
    let onAdd: () -> Void
    var onRestore: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            DashboardActionButton(
                icon: "chart.bar.xaxis",
                title: "dashboard.action.sync".localized,
                theme: theme,
                isHighlighted: true,
                action: onSync
            )
            DashboardActionButton(
                icon: "clock.arrow.circlepath",
                title: "nav.history".localized,
                theme: theme,
                isHighlighted: false,
                action: onShowHistory
            )
            .accessibilityIdentifier("dashboard.history")

            if let onRestore {
                DashboardActionButton(
                    icon: "arrow.down.doc",
                    title: "restore.action".localized,
                    theme: theme,
                    isHighlighted: false,
                    action: onRestore
                )
            }
            DashboardActionButton(
                icon: "plus.circle",
                title: "dashboard.add".localized,
                theme: theme,
                isHighlighted: false,
                action: onAdd
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .telemetryCard(theme: theme, cornerRadius: 26, glowOpacity: 0.20)
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
    var onTapUsed: (() -> Void)? = nil
    var onTapFiles: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.storage_overview".localized.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(DesignSystem.Colors.slateMuted)

            HStack(spacing: 12) {
                DashboardInfoCard(
                    title: "dashboard.used".localized,
                    value: transferredSizeText,
                    subtitle: "dashboard.of_value".localized(with: totalSizeText),
                    color: theme.primary,
                    progress: storageProgress,
                    action: onTapUsed
                )
                DashboardInfoCard(
                    title: "dashboard.files".localized,
                    value: "\(currentCount)/\(totalCount)",
                    subtitle: hasTasks ? "dashboard.selected".localized : "dashboard.items_ready".localized,
                    color: theme.secondary,
                    progress: Double(currentCount) / Double(max(totalCount, 1)),
                    action: onTapFiles
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
    let backupType: BackupType?
}

struct DashboardRecentBackupsSection: View {
    let rows: [DashboardRecentBackupRow]
    let theme: DashboardTheme
    let onSeeAll: () -> Void
    let onSelect: (PersistentIdentifier) -> Void
    var onEmptyTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.recent_backups".localized.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                Spacer()
                Button("dashboard.see_all".localized, action: onSeeAll)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primary)
            }

            VStack(spacing: 10) {
                if rows.isEmpty {
                    Button {
                        (onEmptyTap ?? onSeeAll)()
                    } label: {
                        emptyState
                    }
                    .buttonStyle(.plain)
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.primary.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(theme.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.no_backups_yet".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("dashboard.start_backup_to_create_history".localized)
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primary)
        }
        .padding(14)
        .telemetryCard(theme: theme, cornerRadius: 20, glowOpacity: 0.12)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recentRow(_ record: DashboardRecentBackupRow) -> some View {
        let rowTheme = DashboardTheme.theme(for: record.backupType)
        let isFailed = record.status == "failed"
        let isCancelled = record.status == "cancelled"
        let statusColor: Color = isFailed ? DesignSystem.Colors.error : (isCancelled ? DesignSystem.Colors.warning : DesignSystem.Colors.mintNeon)
        let iconName = isFailed
            ? "exclamationmark.triangle.fill"
            : (isCancelled ? "xmark.circle.fill" : "checkmark.seal.fill")
        let iconColor: Color = isFailed ? DesignSystem.Colors.error : (isCancelled ? DesignSystem.Colors.warning : rowTheme.primary)
        let level: Double = isFailed ? 0.20 : (isCancelled ? 0.55 : 1.0)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowTheme.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(rowTheme.primary.opacity(0.4), lineWidth: 0.8)
                    )
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .shadow(color: iconColor.opacity(0.5), radius: 4)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(record.displayName ?? "dashboard.backup".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if let backupType = record.backupType {
                        Text("[\(backupType.rawValue)]")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(rowTheme.primary)
                            .fixedSize()
                    }

                    Spacer(minLength: 4)

                    TelemetrySignalBars(color: statusColor, level: level)
                }

                HStack(spacing: 8) {
                    Text(DashboardFormat.date(record.timestamp))
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(BackupHistory.localizedStatus(record.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .fixedSize()
                }
            }
        }
        .padding(14)
        .telemetryCard(theme: rowTheme, cornerRadius: 18, glowOpacity: 0.14)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
