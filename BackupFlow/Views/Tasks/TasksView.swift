import SwiftUI
import SwiftData

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
    @State private var searchText = ""
    @State private var actionToast: String? = nil
    
    private var filteredTasks: [BackupTask] {
        if searchText.isEmpty {
            return tasks
        }
        return tasks.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
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
                    .overlay(alignment: .bottom) {
                        if let msg = actionToast {
                            Text(msg)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .shadow(radius: 8)
                                .padding(.bottom, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        withAnimation(.easeInOut) { actionToast = nil }
                                    }
                                }
                        }
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
                    description: "Yeni bir yedekleme görevi oluşturmaya başlamak için + düğmesine tıklayın",
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
                // Search and Filter
                HStack(spacing: DesignSystem.Spacing.small) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Brand.gradient)
                    
                    TextField("Görev ara...", text: $searchText)
                        .font(DesignSystem.Typography.body)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
                .padding(.vertical, DesignSystem.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous)
                        .fill(Color.gray.opacity(0.05))
                )
                .padding(.horizontal, DesignSystem.Spacing.base)
                
                // Quick Stats
                if !filteredTasks.isEmpty {
                    gradientSectionHeader(title: "Özet", systemImage: "chart.bar.fill")
                    quickStatsView
                }
                
                // Task Items
                if !filteredTasks.isEmpty {
                    gradientSectionHeader(title: "Görevler", systemImage: "list.bullet.rectangle")
                }
                LazyVStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(filteredTasks) { task in
                        NavigationLink(destination: BackupView()) {
                            TaskItemCard(
                                task: task,
                                onDelete: { selected in
                                    taskToDelete = selected
                                    showingDeleteAlert = true
                                }
                            )
                        }
                        .contextMenu {
                            Button("Şimdi çalıştır", systemImage: "play.fill") {
                                runNow(task)
                            }
                            Button("İptal et", systemImage: "xmark.circle") {
                                cancelTaskRun(task)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
                .padding(.bottom, DesignSystem.Spacing.large)
            }
            .padding(.vertical, DesignSystem.Spacing.base)
        }
        .animation(.easeInOut(duration: 0.3), value: filteredTasks)
    }
    
    private var quickStatsView: some View {
        let enabledCount = filteredTasks.filter { $0.isEnabled && !$0.isPaused }.count
        let pausedCount = filteredTasks.filter { $0.isPaused }.count
        
        return HStack(spacing: DesignSystem.Spacing.medium) {
            StatCard(
                label: "Aktif",
                value: "\(enabledCount)",
                icon: "play.circle.fill",
                style: .success
            )
            
            StatCard(
                label: "Duraklatılmış",
                value: "\(pausedCount)",
                icon: "pause.circle.fill",
                style: pausedCount > 0 ? .warning : .primary
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.base)
    }
    
    // MARK: - Helper Methods
    private func runNow(_ task: BackupTask) {
        withAnimation {
            task.isEnabled = true
            task.isPaused = false
            try? modelContext.save()
            actionToast = "Görev başlatıldı"
        }
    }
    
    private func cancelTaskRun(_ task: BackupTask) {
        withAnimation {
            task.isPaused = true
            try? modelContext.save()
            actionToast = "Görev iptal edildi"
        }
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
        withAnimation {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
}

// MARK: - Task Item Card Component

struct TaskItemCard: View {
    let task: BackupTask
    let onDelete: (BackupTask) -> Void
    
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
                        
                        Text((task.sourcePath as NSString?)?.abbreviatingWithTildeInPath ?? "Not set")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if task.isEnabled {
                        StatusBadge(
                            text: task.isPaused ? "Duraklatılmış" : "Aktif",
                            style: task.isPaused ? .warning : .success
                        )
                    } else {
                        StatusBadge(
                            text: "Devre Dışı",
                            style: .info
                        )
                    }
                }
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                
                // Task Details
                HStack(spacing: DesignSystem.Spacing.large) {
                    TaskDetailItem(
                        icon: "network",
                        label: task.backupType == .ftp ? "FTP" : task.backupType == .webdav ? "WebDAV" : "SFTP"
                    )
                    
                    TaskDetailItem(
                        icon: "timer",
                        label: task.frequency == .manual ? "Manuel" : "Planlı"
                    )
                    
                    TaskDetailItem(
                        icon: "doc.on.doc",
                        label: task.mediaType.displayName
                    )
                    
                    Spacer()
                    
                    // Quick Actions
                    HStack(spacing: DesignSystem.Spacing.small) {
                        Button(action: { onDelete(task) }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
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

