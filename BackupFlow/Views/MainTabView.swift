import SwiftData
import SwiftUI
import Combine

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \BackupTask.createdAt, order: .reverse) private var queriedTasks: [BackupTask]
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var queriedHistory: [BackupHistory]

    // "Reset all data" deletes models while this view is still on screen under the
    // Settings sheet. Until the queries refetch they can still hand back those deleted,
    // detached models, and reading any attribute of one crashes SwiftData.
    private var tasks: [BackupTask] { queriedTasks.filter { $0.modelContext != nil } }
    private var history: [BackupHistory] { queriedHistory.filter { $0.modelContext != nil } }

    /// Plain-value copy of a task for a saved-server row. After a reset SwiftUI renders
    /// each row once more with its previous element (and reads its id to diff), so rows
    /// must not hold the model itself: a snapshot never touches the deleted task.
    private struct SavedServerRow: Identifiable {
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

    private var savedServerRows: [SavedServerRow] {
        let activeID = activeTask?.id
        return tasks.prefix(5).map { task in
            SavedServerRow(
                id: task.id,
                displayName: task.displayName,
                backupType: task.backupType,
                destinationText: serverDestinationText(for: task),
                watermark: serverProtocolWatermark(for: task),
                lastBackupDate: task.lastBackupDate,
                isScheduled: task.frequency != .manual,
                isPaused: task.isPaused,
                isActive: task.id == activeID
            )
        }
    }

    /// Same reasoning as `SavedServerRow`: "reset all data" deletes history too.
    private struct RecentBackupRow: Identifiable {
        let id: PersistentIdentifier
        let displayName: String?
        let timestamp: Date
        let status: String
    }

    private var recentBackupRows: [RecentBackupRow] {
        history.prefix(3).map {
            RecentBackupRow(id: $0.persistentModelID, displayName: $0.taskDisplayName, timestamp: $0.timestamp, status: $0.status)
        }
    }

    /// Resolves a row back to its live task at the moment of an action.
    private func liveTask(_ id: UUID) -> BackupTask? {
        tasks.first { $0.id == id }
    }

    @State private var showBackupSheet = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var selectedTask: BackupTask?
    @State private var taskToDelete: BackupTask?
    @State private var showDeleteAlert = false
    @State private var currentTime = Date()
    @State private var previewTask: BackupTask?
    @State private var previewResult: BackupPreviewResult?
    @State private var previewError: String?
    @State private var isPreviewLoading = false
    /// The previewed run was confirmed to start without Wi-Fi.
    @State private var previewIgnoresWiFi = false
    /// A Wi-Fi-only task the user tried to start while not on Wi-Fi.
    @State private var wifiConfirmationTask: BackupTask?
    private static let largeFileProgressThresholdBytes: Int64 = 50 * 1024 * 1024
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activeTask: BackupTask? {
        tasks.first {
            $0.backupStatus == .preparing ||
            $0.backupStatus == .scanning ||
            $0.backupStatus == .uploading
        }
    }

    private var isBackingUp: Bool {
        activeTask != nil
    }

    private var backupProgress: Double {
        activeTask?.progress ?? latestHistoryProgress
    }

    private var latestHistoryProgress: Double {
        guard let item = history.first, item.totalFiles > 0 else { return 0 }
        return Double(item.filesProcessed) / Double(item.totalFiles)
    }

    private var backupMessage: String {
        if let task = activeTask {
            if let currentFile = task.currentFile, !currentFile.isEmpty {
                return "backup.current_file.uploading_file".localized(with: URL(fileURLWithPath: currentFile).lastPathComponent)
            }
            return task.backupStatus.displayName
        }

        if let latest = history.first {
            return latest.status == "completed" ? "dashboard.backup_completed".localized : localizedStatus(latest.status)
        }

        return "dashboard.ready_to_sync".localized
    }

    private var lastConnectionStatus: String {
        if isBackingUp { return "dashboard.status.syncing".localized }
        if activeTaskCount == 1 { return "dashboard.status.active_task_count_one".localized(with: activeTaskCount) }
        return "dashboard.status.active_task_count_many".localized(with: activeTaskCount)
    }

    private var activeTaskCount: Int {
        tasks.filter { $0.isEnabled && !$0.isPaused }.count
    }

    private var nextScheduledTask: BackupTask? {
        tasks
            .filter { $0.isEnabled && !$0.isPaused && $0.nextRunTime != nil }
            .min { task1, task2 in
                (task1.nextRunTime ?? .distantFuture) < (task2.nextRunTime ?? .distantFuture)
            }
    }

    private var pausedScheduledTask: BackupTask? {
        tasks.first { task in
            task.isEnabled && task.isPaused && task.frequency != .manual
        }
    }

    private var heroActionIconName: String {
        pausedScheduledTask == nil ? "play.fill" : "pause.fill"
    }

    private var heroActionColor: Color {
        pausedScheduledTask == nil ? .green : .orange
    }

    private var heroActionAccessibilityLabel: String {
        pausedScheduledTask == nil ? "dashboard.backup_now".localized : "task.status.paused".localized
    }

    private var selectedServerName: String {
        tasks.first.map { "\($0.serverHost):\($0.serverPort)" } ?? "dashboard.no_server_selected".localized
    }

    private var currentBackupCount: Int {
        activeTask.map { Int($0.progress * 100) } ?? (history.first?.filesProcessed ?? 0)
    }

    private var totalBackupCount: Int {
        activeTask != nil ? 100 : (history.first?.totalFiles ?? 0)
    }

    /// Hero headline: avoid claiming "safe & synced" before any backup has run
    /// or when the latest run did not complete.
    private var heroHeadline: String {
        if isBackingUp { return "dashboard.backing_up_now".localized }
        guard let latest = history.first else { return "dashboard.ready_to_sync".localized }
        return latest.status == "completed" ? "dashboard.safe_synced".localized : localizedStatus(latest.status)
    }

    private var dashboardTheme: DashboardTheme {
        DashboardTheme.theme(for: activeTask?.backupType)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.94),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 40)
                .fill(dashboardTheme.primary.opacity(0.03))
                .blur(radius: 40)
                .frame(width: 260, height: 260)
                .offset(x: -110, y: -300)

            RoundedRectangle(cornerRadius: 40)
                .fill(dashboardTheme.secondary.opacity(0.04))
                .blur(radius: 50)
                .frame(width: 220, height: 220)
                .offset(x: 130, y: -140)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerView
                    if isBackingUp {
                        backupProgressCard
                    }
                    heroBackupCard
                    healthOverviewCard
                    savedServersSection
                    quickActions
                    statsSection
                    recentBackupsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 48)
            }
            .modifier(HideTopScrollEdgeEffect())

            // Opaque strip behind the status bar so scrolled content doesn't collide
            // with it: a zero-height view at the top of the safe area whose background
            // extends up into it. A sibling layer so the scroll edge effect can't cover it.
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
                Spacer()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .sheet(isPresented: $showBackupSheet) {
            NavigationStack {
                BackupView()
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(item: $selectedTask) { task in
            NavigationStack {
                TaskDetailView(task: task)
                    .navigationTitle("task.details.title".localized)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(item: $previewTask) { task in
            BackupPreviewSheet(
                taskName: task.displayName,
                result: previewResult,
                isLoading: isPreviewLoading,
                errorMessage: previewError,
                onConfirm: {
                    startPreviewedTask(task)
                },
                onCancel: {
                    clearPreview()
                }
            )
        }
        .alert("tasks.delete_confirmation".localized, isPresented: $showDeleteAlert) {
            Button("alert.cancel".localized, role: .cancel) {}
            Button("tasks.delete".localized, role: .destructive) {
                if let taskToDelete {
                    deleteTask(taskToDelete)
                }
            }
        } message: {
            Text("tasks.delete_message_full".localized)
        }
        .alert(
            "backup.wifi_confirm.title".localized,
            isPresented: Binding(
                get: { wifiConfirmationTask != nil },
                set: { if !$0 { wifiConfirmationTask = nil } }
            ),
            presenting: wifiConfirmationTask
        ) { task in
            Button("backup.wifi_confirm.start_anyway".localized) {
                startTaskNow(task, ignoreWiFiRequirement: true)
            }
            Button("alert.cancel".localized, role: .cancel) {}
        } message: { _ in
            Text("backup.wifi_confirm.message".localized)
        }
        .onReceive(BackupScheduler.shared.$wifiConfirmationTaskID) { taskID in
            // A reminder's "Start" reached a Wi-Fi-only task while not on Wi-Fi.
            guard let taskID, let task = tasks.first(where: { $0.id == taskID }) else { return }
            wifiConfirmationTask = task
            BackupScheduler.shared.wifiConfirmationTaskID = nil
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .onReceive(BackupScheduler.shared.$requestedDetailTaskID) { taskID in
            // A notification's "Details" action asked to open this task.
            guard let taskID, let task = tasks.first(where: { $0.id == taskID }) else { return }
            selectedTask = task
            BackupScheduler.shared.requestedDetailTaskID = nil
        }
    }

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
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
                    .fill(statusDotColor)
                    .frame(width: 10, height: 10)

                Text(lastConnectionStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Button {
                showSettings = true
            } label: {
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

    private var backupProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("dashboard.backup_in_progress".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(Int(min(max(backupProgress, 0), 1) * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(dashboardTheme.primary)
                if let activeTask {
                    Button(role: .destructive) {
                        BackupScheduler.shared.cancelCurrentTask(for: activeTask)
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
                progress: backupProgress,
                theme: dashboardTheme,
                reduceMotion: reduceMotion
            )

            HStack(alignment: .firstTextBaseline) {
                Text(backupMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let activeTask, activeTask.transferSpeedBytesPerSecond > 1 {
                    Text("dashboard.speed_per_second".localized(with: formatBytes(Int64(activeTask.transferSpeedBytesPerSecond))))
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

    private var heroBackupCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            dashboardTheme.primary,
                            dashboardTheme.secondary,
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
                            Text(timeUntilNextTask(nextRun, currentTime: currentTime))
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
                        Text("\(Int(min(max(backupProgress, 0), 1) * 100))%")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(heroHeadline)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)
                        Text(isBackingUp ? backupMessage : selectedServerName)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)

                    Button {
                        if isBackingUp { return }
                        if let pausedScheduledTask {
                            selectedTask = pausedScheduledTask
                        } else {
                            // "Back up now" runs a saved task; the form only opens when none exist.
                            syncActiveTasks()
                        }
                    } label: {
                        Image(systemName: heroActionIconName)
                            .font(.headline.weight(.bold))
                            .frame(width: 48, height: 48)
                            .background(heroActionColor.opacity(0.92))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(heroActionAccessibilityLabel)
                    .layoutPriority(1)
                }
            }
            .padding(24)
        }
        .frame(height: 230)
    }

    private var savedServersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("dashboard.saved_servers".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("dashboard.add".localized) {
                    showBackupSheet = true
                }
                .accessibilityIdentifier("dashboard.add")
                .font(.subheadline)
                .foregroundStyle(dashboardTheme.primary)
            }

            if tasks.isEmpty {
                Text("dashboard.no_saved_servers".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(savedServerRows) { row in
                        let taskTheme = DashboardTheme.theme(for: row.backupType)
                        HStack(alignment: .top, spacing: 12) {
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
                                    Text("dashboard.used_date".localized(with: formatDate(lastUsed)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button {
                                    selectedTask = liveTask(row.id)
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
                                    guard let task = liveTask(row.id) else { return }
                                    taskToDelete = task
                                    showDeleteAlert = true
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
                            selectedTask = liveTask(row.id)
                        }
                        .contextMenu {
                            Button {
                                if let task = liveTask(row.id) { startTaskNow(task) }
                            } label: {
                                Label("backup.notification.action.start".localized, systemImage: "play.fill")
                            }

                            if row.isScheduled {
                                Button {
                                    if let task = liveTask(row.id) { togglePause(for: task) }
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
            }
        }
    }

    private var healthOverviewCard: some View {
        let completed = history.filter { $0.status == "completed" }.count
        let failed = history.filter { $0.status == "failed" }.count
        let total = max(completed + failed, 1)
        let successRate = Int((Double(completed) / Double(total)) * 100)
        let consecutiveFailures = tasks.map(\.consecutiveFailureCount).max() ?? 0
        // With no runs yet, show neutral, empty bars instead of a "healthy" state.
        let hasRuns = completed + failed > 0
        let averageDuration = history.isEmpty ? 0 : history.reduce(0) { $0 + $1.duration } / Double(history.count)

        return VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.health.title".localized)
                .font(.headline.weight(.semibold))

            HStack(spacing: 12) {
                infoCard(
                    title: "dashboard.health.success".localized,
                    value: "\(successRate)%",
                    subtitle: "dashboard.health.runs".localized(with: completed, completed + failed),
                    color: !hasRuns ? .secondary : (successRate >= 80 ? .green : .orange),
                    progress: Double(successRate) / 100.0
                )
                infoCard(
                    title: "dashboard.health.failures".localized,
                    value: "\(consecutiveFailures)",
                    subtitle: "dashboard.health.consecutive".localized,
                    color: !hasRuns ? .secondary : (consecutiveFailures == 0 ? .green : .red),
                    progress: !hasRuns ? 0 : (consecutiveFailures == 0 ? 1 : 0.35)
                )
            }

            if let lastSuccess = history.first(where: { $0.status == "completed" }) {
                Text("dashboard.health.last_success".localized(with: formatDate(lastSuccess.timestamp)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("dashboard.health.average_duration".localized(with: formatDuration(averageDuration)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            DashboardActionButton(icon: "arrow.triangle.2.circlepath", title: "dashboard.action.sync".localized, theme: dashboardTheme) {
                syncActiveTasks()
            }
            DashboardActionButton(icon: "clock.arrow.circlepath", title: "nav.history".localized, theme: dashboardTheme) {
                showHistory = true
            }
            .accessibilityIdentifier("dashboard.history")
            DashboardActionButton(icon: "plus.circle.fill", title: "dashboard.add".localized, theme: dashboardTheme) {
                showBackupSheet = true
            }
        }
        .padding(.vertical, 2)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.storage_overview".localized)
                .font(.headline.weight(.semibold))

            HStack(spacing: 12) {
                infoCard(
                    title: "dashboard.used".localized,
                    value: transferredSizeText,
                    subtitle: "dashboard.of_value".localized(with: totalSizeText),
                    color: dashboardTheme.primary,
                    progress: latestHistoryProgress
                )
                infoCard(
                    title: "dashboard.files".localized,
                    value: "\(currentBackupCount)/\(totalBackupCount)",
                    subtitle: tasks.isEmpty ? "dashboard.items_ready".localized : "dashboard.selected".localized,
                    color: dashboardTheme.secondary,
                    progress: Double(currentBackupCount) / Double(max(totalBackupCount, 1))
                )
            }
        }
        .padding(.top, 2)
    }

    private var recentBackupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("dashboard.recent_backups".localized)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("dashboard.see_all".localized) {
                    showHistory = true
                }
                .font(.subheadline)
                .foregroundStyle(dashboardTheme.primary)
            }

            VStack(spacing: 12) {
                if history.isEmpty {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(dashboardTheme.primary.opacity(0.1))
                                .frame(width: 48, height: 48)
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(dashboardTheme.primary)
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
                } else {
                    ForEach(recentBackupRows) { record in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(dashboardTheme.primary.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: record.status == "failed" ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                    .foregroundStyle(record.status == "failed" ? .red : dashboardTheme.primary)
                            }
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.displayName ?? "dashboard.backup".localized)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(formatDate(record.timestamp))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(localizedStatus(record.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(record.status == "failed" ? .red : .green)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(.systemBackground).opacity(0.55))
                        )
                    }
                }
            }
        }
    }

    private var statusDotColor: Color {
        if isBackingUp { return dashboardTheme.primary }
        return activeTaskCount > 0 ? .green : .secondary
    }

    private var lastSyncText: String {
        guard let date = history.first?.timestamp else { return "dashboard.never".localized }
        return formatDate(date)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "dashboard.greeting.morning".localized
        case 12..<17:
            return "dashboard.greeting.afternoon".localized
        case 17..<22:
            return "dashboard.greeting.evening".localized
        default:
            return "dashboard.greeting.night".localized
        }
    }

    private var transferredSizeText: String {
        formatBytes(history.first?.bytesTransferred ?? 0)
    }

    private var totalSizeText: String {
        formatBytes(history.first?.totalBytes ?? 0)
    }

    private func infoCard(title: String, value: String, subtitle: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(value: progress, total: 1.0)
            .tint(color)
            .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func deleteTask(_ task: BackupTask) {
        BackupScheduler.shared.removeReminder(forTaskID: task.id)
        task.removeStoredPassword()
        modelContext.delete(task)
        try? modelContext.save()
        taskToDelete = nil
    }

    private func isTaskRunning(_ task: BackupTask) -> Bool {
        task.backupStatus == .preparing ||
        task.backupStatus == .scanning ||
        task.backupStatus == .uploading
    }

    /// - Parameter ignoreWiFiRequirement: The user already agreed to start without Wi-Fi.
    private func startTaskNow(_ task: BackupTask, ignoreWiFiRequirement: Bool = false) {
        if !ignoreWiFiRequirement, BackupScheduler.shared.needsWiFiConfirmation(for: task) {
            wifiConfirmationTask = task
            return
        }

        guard task.backupType != .ftp && task.backupType != .sftp else {
            BackupScheduler.shared.startUserInitiatedBackup(task: task, ignoreWiFiRequirement: ignoreWiFiRequirement)
            return
        }

        previewIgnoresWiFi = ignoreWiFiRequirement
        previewTask = task
        previewResult = nil
        previewError = nil
        isPreviewLoading = true
        Task {
            do {
                previewResult = try await BackupScheduler.shared.previewBackup(task: task)
            } catch {
                previewError = error.localizedDescription
            }
            isPreviewLoading = false
        }
    }

    private func startPreviewedTask(_ task: BackupTask) {
        if task.isPaused {
            BackupScheduler.shared.resumeTask(task)
        }
        let ignoreWiFiRequirement = previewIgnoresWiFi
        clearPreview()
        BackupScheduler.shared.startUserInitiatedBackup(task: task, ignoreWiFiRequirement: ignoreWiFiRequirement)
    }

    private func clearPreview() {
        previewTask = nil
        previewIgnoresWiFi = false
        previewResult = nil
        previewError = nil
        isPreviewLoading = false
    }

    private func syncActiveTasks() {
        let runnableTasks = tasks.filter { $0.isEnabled && !$0.isPaused }
        guard !runnableTasks.isEmpty else {
            showBackupSheet = true
            return
        }

        if let firstRunnable = runnableTasks.first(where: { !isTaskRunning($0) }) {
            startTaskNow(firstRunnable)
        }
    }

    private func serverDestinationText(for task: BackupTask) -> String {
        let path = task.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.isEmpty || path == "/" else { return path }

        switch task.backupType {
        case .sftp:
            return "dashboard.destination.auto".localized(with: fallbackDestinationName(for: task))
        case .ftp, .webdav:
            return "dashboard.destination.root".localized
        }
    }

    private func serverProtocolWatermark(for task: BackupTask) -> String {
        switch task.backupType {
        case .ftp:
            return "FTP"
        case .sftp:
            return "SFTP"
        case .webdav:
            return "WebDAV"
        }
    }

    private func fallbackDestinationName(for task: BackupTask) -> String {
        guard let sourcePath = task.sourcePath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourcePath.isEmpty else {
            return "backup"
        }

        if sourcePath == "PHOTOS_LIBRARY" {
            return "photos"
        }

        let name = URL(fileURLWithPath: sourcePath).lastPathComponent
        return name.isEmpty ? "backup" : name
    }

    private func togglePause(for task: BackupTask) {
        if task.isPaused {
            BackupScheduler.shared.resumeTask(task)
        } else {
            BackupScheduler.shared.pauseTask(task)
        }

        try? modelContext.save()
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
            let transferred = formatBytes(task.currentFileBytesTransferred)
            let total = formatBytes(task.currentFileTotalBytes)
            let percent = "\(Int(min(max(task.currentFileProgress, 0), 1) * 100))%"
            let speed = task.transferSpeedBytesPerSecond > 1
                ? "dashboard.speed_per_second".localized(with: formatBytes(Int64(task.transferSpeedBytesPerSecond)))
                : nil

            if let speed {
                return "dashboard.transfer_detail_with_speed".localized(with: transferred, total, speed, percent)
            }
            return "dashboard.transfer_detail".localized(with: transferred, total, percent)
        }

        if task.currentFileProgress > 0 {
            return "\(Int(min(max(task.currentFileProgress, 0), 1) * 100))%"
        }

        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        }
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        }
        return String(format: "%.1fh", seconds / 3600)
    }

    private func timeUntilNextTask(_ nextRun: Date, currentTime: Date) -> String {
        let timeInterval = nextRun.timeIntervalSince(currentTime)

        if timeInterval < -30 {
            return "dashboard.overdue".localized
        }

        let totalSeconds = Int(max(0, timeInterval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours >= 1 {
            return String(format: "%02d:%02d", hours, minutes)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        // Keep "0 KB" numeric instead of the spelled-out "Zero KB".
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }

    private func localizedStatus(_ status: String) -> String {
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
            return status
        }
    }
}

private struct DashboardTheme {
    let primary: Color
    let secondary: Color

    static let webDAV = DashboardTheme(
        primary: Color(red: 0.18, green: 0.30, blue: 0.98),
        secondary: Color(red: 0.52, green: 0.31, blue: 0.98)
    )

    static let ftp = DashboardTheme(
        primary: Color(red: 0.95, green: 0.42, blue: 0.10),
        secondary: Color(red: 1.00, green: 0.66, blue: 0.20)
    )

    static let sftp = DashboardTheme(
        primary: Color(red: 0.05, green: 0.58, blue: 0.34),
        secondary: Color(red: 0.18, green: 0.74, blue: 0.45)
    )

    static func theme(for backupType: BackupType?) -> DashboardTheme {
        switch backupType {
        case .ftp:
            return .ftp
        case .sftp:
            return .sftp
        case .webdav, .none:
            return .webDAV
        }
    }
}

/// The dashboard draws its own opaque status-bar strip, so the system's
/// blurred top edge effect (iOS 26+) is redundant there.
private struct HideTopScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

private struct DashboardActionButton: View {
    let icon: String
    let title: String
    let theme: DashboardTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.15), theme.secondary.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct AnimatedDashboardProgressBar: View {
    let progress: Double
    let theme: DashboardTheme
    let reduceMotion: Bool
    @State private var phase: CGFloat = -1

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            let progressWidth = max(geometry.size.width * clampedProgress, 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(theme.primary.opacity(0.1))
                    .frame(height: 8)

                if progressWidth > 0 {
                    ZStack {
                        LinearGradient(
                            colors: [
                                theme.primary,
                                theme.secondary,
                                theme.primary,
                                theme.secondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(progressWidth * 2.4, 160), height: 8)
                        .offset(x: reduceMotion ? 0 : phase * max(progressWidth, 1))
                    }
                    .frame(width: progressWidth, height: 8, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                    .animation(DesignSystem.Animation.swift, value: progressWidth)
                }
            }
        }
        .frame(height: 8)
        .onAppear {
            guard !reduceMotion else { return }
            phase = -1
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 0
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                phase = 0
            } else {
                phase = -1
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 0
                }
            }
        }
    }
}

private struct MiniTransferProgressBar: View {
    let progress: Double?
    let theme: DashboardTheme
    let reduceMotion: Bool
    @State private var phase: CGFloat = -1

    private var clampedProgress: CGFloat? {
        guard let progress else { return nil }
        return CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.primary.opacity(0.08))
                    .frame(height: 4)

                if let clampedProgress {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.primary, theme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * clampedProgress, 4), height: 4)
                        .animation(DesignSystem.Animation.swift, value: clampedProgress)
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.primary.opacity(0.25), theme.secondary, theme.primary.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * 0.34, 48), height: 4)
                        .offset(x: reduceMotion ? 0 : phase * geometry.size.width)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 4)
        .onAppear {
            guard !reduceMotion, clampedProgress == nil else { return }
            phase = -0.35
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                phase = 0
            } else if clampedProgress == nil {
                phase = -0.35
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}
