import SwiftData
import SwiftUI
import Combine

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BackupTask.createdAt, order: .reverse) private var queriedTasks: [BackupTask]
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var queriedHistory: [BackupHistory]

    // "Reset all data" deletes models while this view is still on screen under the
    // Settings sheet. Until the queries refetch they can still hand back those deleted,
    // detached models, and reading any attribute of one crashes SwiftData.
    private var tasks: [BackupTask] { queriedTasks.filter { $0.isLiveInContext } }
    private var history: [BackupHistory] { queriedHistory.filter { $0.isLiveInContext } }

    @AppStorage("onboardingLastSeenVersion") private var onboardingLastSeenVersion = ""
    @State private var router = Router()
    @State private var showOnboarding = false
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

    // MARK: - Derived Home State

    private var activeTask: BackupTask? {
        tasks.first { isTaskRunning($0) }
    }

    private var nextScheduledTask: BackupTask? {
        tasks
            .filter { $0.isEnabled && !$0.isPaused && $0.nextRunTime != nil }
            .min { ($0.nextRunTime ?? .distantFuture) < ($1.nextRunTime ?? .distantFuture) }
    }

    private var failedTaskCount: Int {
        tasks.filter { $0.backupStatus == .failed }.count
    }

    private var homeStatusKind: HomeStatusKind {
        if activeTask != nil { return .running }
        if failedTaskCount > 0 || history.first?.status == "failed" { return .failed }
        if tasks.isEmpty { return .idle }
        return .ok
    }

    private var homeStatusTitle: String {
        if activeTask != nil { return "home.status.backing_up".localized }
        if failedTaskCount > 0 || history.first?.status == "failed" { return "home.status.attention".localized }
        if tasks.isEmpty { return "home.status.no_tasks".localized }
        if history.isEmpty { return "home.status.ready".localized }
        return "home.status.up_to_date".localized
    }

    private var homeStatusSummary: String {
        let lastText = history.first.map { Self.formatShortTimestamp($0.timestamp, relativeTo: currentTime) } ?? "—"
        let nextText = nextScheduledTask?.nextRunTime.map { Self.formatShortTimestamp($0, relativeTo: currentTime) } ?? "—"
        let errorCount = failedTaskCount > 0 ? failedTaskCount : (history.first?.status == "failed" ? 1 : 0)
        return "home.status.summary".localized(with: lastText, nextText, errorCount)
    }

    private var homeDays: [DayTotal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: currentTime)
        let windowStart = cal.date(byAdding: .day, value: -13, to: today) ?? today

        var totalsByDay: [Date: Double] = [:]
        for item in history where item.timestamp >= windowStart {
            let day = cal.startOfDay(for: item.timestamp)
            totalsByDay[day, default: 0] += Double(max(0, item.bytesTransferred)) / 1_000_000_000.0
        }

        return (0..<14).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -13 + offset, to: today) else { return nil }
            return DayTotal(day: day, gb: totalsByDay[day] ?? 0)
        }
    }

    private var homeTasks: [TaskItem] {
        tasks.map { task in
            TaskItem(
                id: task.id,
                name: task.displayName,
                proto: protocolLabel(for: task.backupType),
                host: hostLabel(for: task),
                lastRun: task.lastBackupDate.map { Self.formatRelative($0, relativeTo: currentTime) } ?? "—",
                summary: summaryLabel(for: task),
                state: runState(for: task),
                isPaused: task.isPaused,
                isScheduled: task.frequency != .manual
            )
        }
    }

    // MARK: - Body

    var body: some View {
        TabView {
            BackupHomeView(
                tasks: homeTasks,
                days: homeDays,
                statusKind: homeStatusKind,
                statusTitle: homeStatusTitle,
                statusSummary: homeStatusSummary,
                onSelectTask: { id in
                    selectedTask = liveTask(id)
                },
                onRunTask: { id in
                    if let task = liveTask(id) {
                        startTaskNow(task)
                    }
                },
                onStopTask: { id in
                    if let task = liveTask(id) {
                        BackupScheduler.shared.cancelCurrentTask(for: task)
                    }
                },
                onTogglePause: { id in
                    if let task = liveTask(id) {
                        togglePause(for: task)
                    }
                },
                onDeleteTask: { id in
                    guard let task = liveTask(id) else { return }
                    taskToDelete = task
                    showDeleteAlert = true
                }
            )
            .tabItem {
                Label("tab.tasks".localized, systemImage: "list.bullet")
            }

            HistoryView(showsCloseButton: false)
                .tabItem {
                    Label("tab.history".localized, systemImage: "clock")
                }

            RestoreView(tasks: homeTasks) { id in
                restoreTask = liveTask(id)
            }
            .tabItem {
                Label("tab.restore".localized, systemImage: "arrow.down.circle")
            }
        }
        .environment(router)
        .tint(BF.accent)
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
        .sheet(isPresented: $router.showNew) {
            NavigationStack {
                BackupView()
            }
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
        }
        .sheet(item: $selectedTask) { task in
            if task.isLiveInContext {
                NavigationStack {
                    TaskDetailView(task: task)
                        .navigationTitle("task.details.title".localized)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(item: $restoreTask) { task in
            if task.isLiveInContext {
                SmartRestoreView(task: task)
            }
        }
        .sheet(item: $selectedHistory) { item in
            if item.isLiveInContext {
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
        }
        .sheet(item: $previewTask) { task in
            if task.isLiveInContext {
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
            guard let taskID, let task = tasks.first(where: { $0.id == taskID }) else { return }
            wifiConfirmationTask = task
            BackupScheduler.shared.wifiConfirmationTaskID = nil
        }
        .onReceive(timer) { time in
            currentTime = time
        }
        .onReceive(BackupScheduler.shared.$requestedDetailTaskID) { taskID in
            guard let taskID, let task = tasks.first(where: { $0.id == taskID }) else { return }
            selectedTask = task
            BackupScheduler.shared.requestedDetailTaskID = nil
        }
    }

    // MARK: - Mapping Helpers

    private func liveTask(_ id: UUID) -> BackupTask? {
        tasks.first { $0.id == id }
    }

    private func isTaskRunning(_ task: BackupTask) -> Bool {
        task.backupStatus == .preparing ||
        task.backupStatus == .scanning ||
        task.backupStatus == .uploading
    }

    private func runState(for task: BackupTask) -> RunState {
        if isTaskRunning(task) {
            let progress = min(max(task.progress, 0), 1)
            let fileName = task.currentFile.map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? task.backupStatus.displayName
            let speed = task.transferSpeedBytesPerSecond > 0
                ? "\(DashboardFormat.bytes(Int64(task.transferSpeedBytesPerSecond)))/s"
                : "—"
            let eta: String = {
                if task.transferSpeedBytesPerSecond > 0,
                   task.currentFileTotalBytes > task.currentFileBytesTransferred {
                    let remaining = Double(task.currentFileTotalBytes - task.currentFileBytesTransferred)
                        / task.transferSpeedBytesPerSecond
                    return DashboardFormat.duration(remaining)
                }
                return "—"
            }()
            return .running(progress: progress, file: fileName, speed: speed, eta: eta)
        }
        if task.backupStatus == .failed {
            return .failed
        }
        if task.lastBackupDate != nil {
            return .ok
        }
        return .idle
    }

    private func protocolLabel(for backupType: BackupType) -> String {
        switch backupType {
        case .ftp: return "FTP"
        case .sftp: return "SFTP"
        case .webdav: return "WebDAV"
        }
    }

    private func hostLabel(for task: BackupTask) -> String {
        if task.backupType == .webdav {
            let parsedHost = URL(string: task.serverHost)?.host ?? task.serverHost
            let clean = parsedHost.isEmpty ? task.serverHost : parsedHost
            if task.serverPort > 0 && task.serverPort != 443 && task.serverPort != 80 {
                return "\(clean):\(task.serverPort)"
            }
            return clean
        }
        return "\(task.serverHost):\(task.serverPort)"
    }

    private func summaryLabel(for task: BackupTask) -> String {
        guard let latest = history.first(where: { $0.belongs(to: task) }) else {
            return "—"
        }
        let filesText = "\(latest.filesProcessed.formatted()) \("home.files_unit".localized)"
        let sizeText = DashboardFormat.bytes(latest.bytesTransferred)
        let durationText = DashboardFormat.duration(latest.duration)
        return "\(filesText) · \(sizeText) · \(durationText)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static func formatShortTimestamp(_ date: Date, relativeTo now: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) || abs(date.timeIntervalSince(now)) < 86_400 {
            return timeFormatter.string(from: date)
        }
        return shortDateTimeFormatter.string(from: date)
    }

    private static func formatRelative(_ date: Date, relativeTo now: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    // MARK: - Actions

    private func deleteTask(_ task: BackupTask) {
        guard task.isLiveInContext else {
            taskToDelete = nil
            return
        }
        let targetPersistentID = task.persistentModelID
        taskToDelete = nil
        if selectedTask?.persistentModelID == targetPersistentID { selectedTask = nil }
        if restoreTask?.persistentModelID == targetPersistentID { restoreTask = nil }
        if previewTask?.persistentModelID == targetPersistentID { clearPreview() }
        if wifiConfirmationTask?.persistentModelID == targetPersistentID { wifiConfirmationTask = nil }

        BackupScheduler.shared.prepareTaskForDeletion(task)
        task.removeStoredPassword()

        // Nullify the one-way relationship on any BackupHistory referencing this task
        // while `task` is still alive in the store, so SQLite sets ZTASK = NULL instead
        // of leaving a dangling foreign key.
        for item in queriedHistory where item.isLiveInContext && item.task?.persistentModelID == targetPersistentID {
            item.task = nil
        }

        modelContext.delete(task)
        try? modelContext.save()
        BackupScheduler.shared.scheduleProcessingTask()
    }

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
        let ignoreWiFiRequirement = previewIgnoresWiFi
        clearPreview()
        BackupScheduler.shared.startUserInitiatedBackup(task: task, ignoreWiFiRequirement: ignoreWiFiRequirement)
    }

    private func togglePause(for task: BackupTask) {
        if task.isPaused {
            BackupScheduler.shared.resumeTask(task)
        } else {
            BackupScheduler.shared.pauseTask(task)
        }
        try? modelContext.save()
    }

    private func clearPreview() {
        previewTask = nil
        previewIgnoresWiFi = false
        previewResult = nil
        previewError = nil
        isPreviewLoading = false
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
