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

    private var savedServerRows: [DashboardServerRow] {
        let activeID = activeTask?.id
        return tasks.prefix(5).map { task in
            DashboardServerRow(
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

    private var recentBackupRows: [DashboardRecentBackupRow] {
        history.prefix(3).map { item in
            DashboardRecentBackupRow(
                id: item.persistentModelID,
                displayName: item.taskDisplayName,
                timestamp: item.timestamp,
                status: item.status,
                backupType: item.inferredBackupType
            )
        }
    }

    /// Resolves a row back to its live task at the moment of an action.
    private func liveTask(_ id: UUID) -> BackupTask? {
        tasks.first { $0.id == id }
    }

    @AppStorage("onboardingLastSeenVersion") private var onboardingLastSeenVersion = ""
    @State private var showOnboarding = false
    @State private var showBackupSheet = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var selectedTask: BackupTask?
    @State private var selectedHistory: BackupHistory?
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
    @State private var restoreTask: BackupTask?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Dashboard State

    private var activeTask: BackupTask? {
        tasks.first { isTaskRunning($0) }
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
            return latest.status == "completed" ? "dashboard.backup_completed".localized : BackupHistory.localizedStatus(latest.status)
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
        return latest.status == "completed" ? "dashboard.safe_synced".localized : BackupHistory.localizedStatus(latest.status)
    }

    private var dashboardTheme: DashboardTheme {
        DashboardTheme.theme(for: activeTask?.backupType)
    }

    private var statusDotColor: Color {
        if isBackingUp { return dashboardTheme.primary }
        return activeTaskCount > 0 ? .green : .secondary
    }

    private var lastSyncText: String {
        guard let date = history.first?.timestamp else { return "dashboard.never".localized }
        return DashboardFormat.date(date)
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

    private var heroSparklinePrimary: [Double] {
        let recent = Array(history.prefix(8).reversed())
        let maxFiles = Double(recent.map { max($0.filesProcessed, 1) }.max() ?? 1)
        var series = recent.map { item -> Double in
            guard item.filesProcessed > 0 else { return 0.08 }
            return min(max(0.14 + (Double(item.filesProcessed) / max(maxFiles, 1)) * 0.80, 0.12), 0.94)
        }
        if let active = activeTask {
            series.append(min(max(active.progress, 0.12), 0.96))
        }
        return series
    }

    private var heroSparklineSecondary: [Double] {
        let recent = Array(history.prefix(8).reversed())
        let maxBytes = Double(recent.map { max($0.bytesTransferred, 1) }.max() ?? 1)
        var series = recent.map { item -> Double in
            guard item.bytesTransferred > 0 else { return 0.06 }
            return min(max(0.10 + (Double(item.bytesTransferred) / max(maxBytes, 1)) * 0.72, 0.10), 0.88)
        }
        if let active = activeTask {
            series.append(min(max(active.currentFileProgress > 0 ? active.currentFileProgress : active.progress * 0.75, 0.10), 0.90))
        }
        return series
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.canvasTop,
                    DesignSystem.Colors.canvasBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(dashboardTheme.primary.opacity(0.08))
                .blur(radius: 55)
                .frame(width: 280, height: 280)
                .offset(x: -115, y: -300)

            Circle()
                .fill(dashboardTheme.secondary.opacity(0.08))
                .blur(radius: 65)
                .frame(width: 250, height: 250)
                .offset(x: 130, y: -130)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    DashboardHeader(
                        greeting: greetingText,
                        statusText: lastConnectionStatus,
                        statusColor: statusDotColor,
                        onTapHub: openPrimaryOrSetup,
                        onTapStatus: {
                            if let activeTask {
                                selectedTask = activeTask
                            } else if !tasks.isEmpty {
                                showHistory = true
                            } else {
                                showBackupSheet = true
                            }
                        },
                        onOpenSettings: { showSettings = true }
                    )

                    if isBackingUp {
                        DashboardProgressCard(
                            activeTask: activeTask,
                            progress: backupProgress,
                            message: backupMessage,
                            theme: dashboardTheme,
                            reduceMotion: reduceMotion,
                            onStop: { BackupScheduler.shared.cancelCurrentTask(for: $0) }
                        )
                    }

                    DashboardHeroCard(
                        theme: dashboardTheme,
                        lastSyncText: lastSyncText,
                        nextScheduledTask: nextScheduledTask,
                        currentTime: currentTime,
                        progress: backupProgress,
                        headline: heroHeadline,
                        subtitle: isBackingUp ? backupMessage : selectedServerName,
                        sparklinePoints: heroSparklinePrimary,
                        sparklineSecondaryPoints: heroSparklineSecondary,
                        actionIconName: heroActionIconName,
                        actionColor: heroActionColor,
                        actionAccessibilityLabel: heroActionAccessibilityLabel,
                        onAction: performHeroAction,
                        onOpenTask: { selectedTask = $0 },
                        onOpenPrimaryTask: openPrimaryOrSetup,
                        onOpenHistory: { showHistory = true }
                    )

                    DashboardHealthCard(
                        history: history,
                        tasks: tasks,
                        onOpenHistory: { showHistory = true },
                        onSelectHistory: { id in
                            selectedHistory = history.first { $0.persistentModelID == id }
                        },
                        onOpenFailedTask: { selectedTask = $0 },
                        onEmptyAction: performHeroAction
                    )

                    DashboardServersSection(
                        rows: savedServerRows,
                        theme: dashboardTheme,
                        onAdd: { showBackupSheet = true },
                        onOpen: { selectedTask = liveTask($0) },
                        onDelete: { id in
                            guard let task = liveTask(id) else { return }
                            taskToDelete = task
                            showDeleteAlert = true
                        },
                        onStart: { id in
                            if let task = liveTask(id) { startTaskNow(task) }
                        },
                        onTogglePause: { id in
                            if let task = liveTask(id) { togglePause(for: task) }
                        }
                    )

                    DashboardQuickActions(
                        theme: dashboardTheme,
                        onSync: syncActiveTasks,
                        onShowHistory: { showHistory = true },
                        onAdd: { showBackupSheet = true },
                        onRestore: tasks.isEmpty ? nil : {
                            restoreTask = tasks.first(where: { $0.isEnabled }) ?? tasks.first
                        }
                    )

                    DashboardStorageSection(
                        theme: dashboardTheme,
                        transferredSizeText: DashboardFormat.bytes(history.first?.bytesTransferred ?? 0),
                        totalSizeText: DashboardFormat.bytes(history.first?.totalBytes ?? 0),
                        storageProgress: latestHistoryProgress,
                        currentCount: currentBackupCount,
                        totalCount: totalBackupCount,
                        hasTasks: !tasks.isEmpty,
                        onTapUsed: {
                            if let latest = history.first {
                                selectedHistory = latest
                            } else {
                                openPrimaryOrSetup()
                            }
                        },
                        onTapFiles: {
                            if let target = tasks.first(where: { $0.isEnabled }) ?? tasks.first {
                                restoreTask = target
                            } else {
                                showBackupSheet = true
                            }
                        }
                    )

                    DashboardRecentBackupsSection(
                        rows: recentBackupRows,
                        theme: dashboardTheme,
                        onSeeAll: { showHistory = true },
                        onSelect: { id in
                            // Resolve the snapshot back to its live record at tap time.
                            selectedHistory = history.first { $0.persistentModelID == id }
                        },
                        onEmptyTap: performHeroAction
                    )
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
                    .background(DesignSystem.Colors.canvasTop.ignoresSafeArea(edges: .top))
                Spacer()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if onboardingLastSeenVersion != OnboardingView.currentOnboardingVersion,
               !Self.isRunningAutomatedTests {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                onboardingLastSeenVersion = OnboardingView.currentOnboardingVersion
                showOnboarding = false
            }
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
        .sheet(item: $restoreTask) { task in
            RestoreBrowserView(task: task)
        }
        .sheet(item: $selectedHistory) { item in
            NavigationStack {
                HistoryDetailView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("task.details.close".localized) { selectedHistory = nil }
                                .accessibilityIdentifier("sheet.close")
                        }
                    }
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

    // MARK: - Actions

    private func openPrimaryOrSetup() {
        if let activeTask {
            selectedTask = activeTask
        } else if let firstTask = tasks.first {
            selectedTask = firstTask
        } else {
            showBackupSheet = true
        }
    }

    private func performHeroAction() {
        if isBackingUp { return }
        if let pausedScheduledTask {
            selectedTask = pausedScheduledTask
        } else {
            // "Back up now" runs a saved task; the form only opens when none exist.
            syncActiveTasks()
        }
    }

    private func deleteTask(_ task: BackupTask) {
        BackupNotifier.shared.removeReminder(forTaskID: task.id)
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

    private func togglePause(for task: BackupTask) {
        if task.isPaused {
            BackupScheduler.shared.resumeTask(task)
        } else {
            BackupScheduler.shared.pauseTask(task)
        }

        try? modelContext.save()
    }

    // MARK: - Saved Server Text

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

    private static var isRunningAutomatedTests: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["XCTestSessionIdentifier"] != nil {
            return true
        }
        #if DEBUG
        if ScreenshotDemoData.isEnabled { return true }
        #endif
        return false
    }
}
