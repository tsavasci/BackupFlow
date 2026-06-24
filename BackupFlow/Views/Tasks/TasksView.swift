import SwiftUI
import SwiftData
import Combine

private struct Brand {
    static let gradient = LinearGradient(colors: [
        Color(red: 0.15, green: 0.60, blue: 0.98), // bright blue
        Color(red: 0.59, green: 0.33, blue: 0.98)  // violet
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BackupTask.createdAt, order: .reverse) private var tasks: [BackupTask]
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: BackupTask?
    @State private var selectedTask: BackupTask?
    @State private var searchText = ""
    @State private var actionToast: String? = nil
    @State private var currentTime = Date()
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isWide: Bool { hSizeClass == .regular }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var filteredTasks: [BackupTask] {
        if searchText.isEmpty {
            return tasks
        }
        return tasks.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var nextScheduledTask: BackupTask? {
        tasks
            .filter { $0.isEnabled && !$0.isPaused && $0.nextRunTime != nil }
            .min { task1, task2 in
                (task1.nextRunTime ?? .distantFuture) < (task2.nextRunTime ?? .distantFuture)
            }
    }
    
    // MARK: - Main View
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                contentView
                    .navigationTitle("nav.tasks".localized)
                    .navigationBarTitleDisplayMode(.large)
                    .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: Text("tasks.search_prompt".localized))
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: BackupView()) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Brand.gradient)
                            }
                        }
                    }
                    .alert("tasks.delete_confirmation".localized, isPresented: $showingDeleteAlert) {
                        Button("alert.cancel".localized, role: .cancel) {}
                        Button("tasks.delete".localized, role: .destructive) {
                            if let task = taskToDelete {
                                deleteTask(task)
                            }
                        }
                    } message: {
                        Text("tasks.delete_message_full".localized)
                    }
                    .sheet(item: $selectedTask) { task in
                        NavigationView {
                            TaskDetailView(task: task)
                                .navigationTitle("task.details.title".localized)
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if let msg = actionToast {
                            Text(msg)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(radius: 8)
                                .padding(.bottom, 24)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        actionToast = nil
                                    }
                                }
                        }
                    }
                    .onReceive(timer) { time in
                        currentTime = time
                    }
            }
        }
    }
    
    private func gradientSectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(Brand.gradient)
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(Brand.gradient)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.base)
    }
    
    // MARK: - Subviews
    private var contentView: some View {
        Group {
            if tasks.isEmpty {
                ModernEmptyState(
                    icon: "plus.circle.dashed",
                    title: "tasks.no_tasks".localized,
                    description: "tasks.create_first_task".localized,
                    action: nil,
                    actionLabel: nil
                )
            } else {
                taskListView
            }
        }
    }
    
    private var taskListView: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                // Quick Stats
                if !filteredTasks.isEmpty {
                    gradientSectionHeader(title: "tasks.summary".localized, systemImage: "chart.bar.fill")
                    quickStatsView
                    nextScheduledTaskView
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Brand.gradient.opacity(0.7))
                        .frame(height: 2)
                        .padding(.horizontal, DesignSystem.Spacing.base)
                }
                
                // Task Items
                if !filteredTasks.isEmpty {
                    gradientSectionHeader(title: "nav.tasks".localized, systemImage: "list.bullet.rectangle")
                }
                if !searchText.isEmpty && filteredTasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("tasks.no_search_results".localized)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.large)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
                    .padding(.horizontal, DesignSystem.Spacing.base)
                }
                
                if isWide {
                    let columns = [GridItem(.flexible(), spacing: DesignSystem.Spacing.medium), GridItem(.flexible(), spacing: DesignSystem.Spacing.medium)]
                    LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.medium) {
                        ForEach(filteredTasks) { task in
                            TaskItemCard(
                                task: task,
                                onDelete: { selected in
                                    taskToDelete = selected
                                    showingDeleteAlert = true
                                },
                                onTogglePause: { selected in
                                    togglePause(for: selected)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                            }
                            .contextMenu {
                                Button("backup.notification.action.start".localized, systemImage: "play.fill") {
                                    runNow(task)
                                }
                                if task.frequency != .manual {
                                    Button(task.isPaused ? "task.resume.button".localized : "task.pause.button".localized, systemImage: task.isPaused ? "play.circle" : "pause.circle") {
                                        togglePause(for: task)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.base)
                    .padding(.bottom, DesignSystem.Spacing.large)
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.medium) {
                        ForEach(filteredTasks) { task in
                            TaskItemCard(
                                task: task,
                                onDelete: { selected in
                                    taskToDelete = selected
                                    showingDeleteAlert = true
                                },
                                onTogglePause: { selected in
                                    togglePause(for: selected)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTask = task
                            }
                            .contextMenu {
                                Button("backup.notification.action.start".localized, systemImage: "play.fill") {
                                    runNow(task)
                                }
                                if task.frequency != .manual {
                                    Button(task.isPaused ? "task.resume.button".localized : "task.pause.button".localized, systemImage: task.isPaused ? "play.circle" : "pause.circle") {
                                        togglePause(for: task)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.base)
                    .padding(.bottom, DesignSystem.Spacing.large)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.base)
        }
    }
    
    private var quickStatsView: some View {
        let enabledCount = filteredTasks.filter { $0.isEnabled && !$0.isPaused }.count
        let pausedCount = filteredTasks.filter { $0.isPaused }.count
        
        return HStack(spacing: DesignSystem.Spacing.medium) {
            StatCard(
                label: "tasks.active".localized,
                value: "\(enabledCount)",
                icon: "play.circle.fill",
                style: .success
            )
            
            StatCard(
                label: "task.status.paused".localized,
                value: "\(pausedCount)",
                icon: "pause.circle.fill",
                style: pausedCount > 0 ? .warning : .primary
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.base)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Brand.gradient)
    }

    @ViewBuilder
    private var nextScheduledTaskView: some View {
        if let task = nextScheduledTask, let nextRun = task.nextRunTime {
            ModernCard(
                cornerRadius: DesignSystem.CornerRadius.medium,
                padding: DesignSystem.Spacing.base
            ) {
                HStack(spacing: DesignSystem.Spacing.medium) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Brand.gradient)
                        .frame(width: 32, height: 32)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                        Text("dashboard.next_task".localized)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)

                        Text(task.displayName)
                            .font(DesignSystem.Typography.subheadline)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(timeUntilNextTask(nextRun, currentTime: currentTime))
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(nextRun.timeIntervalSince(currentTime) < -30 ? .orange : DesignSystem.Colors.primary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.base)
        }
    }
    
    // MARK: - Helper Methods
    private func runNow(_ task: BackupTask) {
        task.isEnabled = true
        task.isPaused = false
        try? modelContext.save()
        actionToast = "tasks.run_started".localized
    }
    
    private func togglePause(for task: BackupTask) {
        if task.isPaused {
            BackupScheduler.shared.resumeTask(task)
            actionToast = "tasks.resumed_toast".localized
        } else {
            BackupScheduler.shared.pauseTask(task)
            actionToast = "tasks.paused_toast".localized
        }

        try? modelContext.save()
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
    
    private func deleteButton(for task: BackupTask) -> some View {
        Button(role: .destructive) {
            taskToDelete = task
            showingDeleteAlert = true
        } label: {
            Label("tasks.swipe_delete".localized, systemImage: "trash")
        }
    }
    
    private func deleteTask(_ task: BackupTask) {
        task.removeStoredPassword()
        modelContext.delete(task)
        try? modelContext.save()
    }
}

// MARK: - Task Item Card Component

struct TaskItemCard: View {
    let task: BackupTask
    let onDelete: (BackupTask) -> Void
    let onTogglePause: (BackupTask) -> Void

    private var showsProgress: Bool {
        task.backupStatus != .idle &&
        task.backupStatus != .completed &&
        task.backupStatus != .failed &&
        task.backupStatus != .cancelled
    }

    private var currentFileDisplayName: String? {
        guard let currentFile = task.currentFile?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentFile.isEmpty,
              currentFile != "/" else {
            return nil
        }

        let fileName = URL(fileURLWithPath: currentFile).lastPathComponent
        if !fileName.isEmpty && fileName != "/" {
            return fileName
        }

        return currentFile.contains("/") ? nil : currentFile
    }
    
    var body: some View {
        ModernCard(
            cornerRadius: DesignSystem.CornerRadius.large,
            padding: DesignSystem.Spacing.base
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                // Title and Status
                HStack(spacing: DesignSystem.Spacing.medium) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                        Text(task.displayName)
                            .font(DesignSystem.Typography.headline)
                            .lineLimit(1)
                        
                        Text((task.sourcePath as NSString?)?.abbreviatingWithTildeInPath ?? "tasks.source_not_set".localized)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if task.isEnabled {
                        StatusBadge(
                            text: task.isPaused ? "task.status.paused".localized : "tasks.active".localized,
                            style: task.isPaused ? .warning : .success
                        )
                    } else {
                        StatusBadge(
                            text: "tasks.disabled".localized,
                            style: .info
                        )
                    }
                }
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Brand.gradient.opacity(0.8))
                    .frame(height: 2)
                    .opacity(0.9)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                
                // Task Details
                HStack(spacing: DesignSystem.Spacing.large) {
                    TaskDetailItem(
                        icon: "network",
                        label: task.backupType.displayName
                    )
                    
                    TaskDetailItem(
                        icon: "timer",
                        label: task.frequency == .manual ? "task.details.manual".localized : "tasks.scheduled_short".localized
                    )
                    
                    TaskDetailItem(
                        icon: "doc.on.doc",
                        label: task.mediaType.displayName
                    )
                    
                    Spacer()
                    
                    // Quick Actions
                    HStack(spacing: DesignSystem.Spacing.small) {
                        if task.frequency != .manual {
                            Button(action: { onTogglePause(task) }) {
                                Image(systemName: task.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(task.isPaused ? .green : .orange)
                                    .frame(width: 32, height: 32)
                                    .background((task.isPaused ? Color.green : Color.orange).opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { onDelete(task) }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showsProgress {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        HStack(spacing: DesignSystem.Spacing.small) {
                            Text(task.backupStatus.displayName)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(task.backupStatus.color)

                            Spacer()

                            Text("%\(Int(task.progress * 100))")
                                .font(DesignSystem.Typography.caption1.weight(.semibold))
                                .foregroundColor(task.backupStatus.color)
                        }

                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)
                            .tint(task.backupStatus.color)

                        if let currentFileDisplayName {
                            Text(currentFileDisplayName)
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .strokeBorder(Brand.gradient.opacity(0.6), lineWidth: 1)
        )
    }
}

// MARK: - Task Detail Item Component

struct TaskDetailItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Brand.gradient)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        TasksView()
            .modelContainer(for: [BackupTask.self, BackupHistory.self], inMemory: true)
    }
}
