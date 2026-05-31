import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var history: [BackupHistory]
    
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var selectedFilterStatus: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                historyContent
                    .navigationTitle("history.title".localized)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) { clearHistoryButton }
                        #else
                        ToolbarItem { clearHistoryButton }
                        #endif
                    }
            }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    @ViewBuilder
    private var historyContent: some View {
        if isLoading {
            ModernLoadingView()
        } else if let error = loadError {
            errorView(error: error)
        } else if history.isEmpty {
            ModernEmptyState(
                icon: "clock.arrow.circlepath",
                title: "history.no_history".localized,
                description: "Başlattığınız yedeklemelerin geçmişi burada gösterilecek",
                action: nil,
                actionLabel: nil
            )
        } else {
            historyListView
        }
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("history.error_occurred".localized)
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ModernButton(
                title: "history.retry".localized,
                icon: "arrow.clockwise",
                style: .primary,
                action: loadHistory
            )
            .padding(.horizontal, DesignSystem.Spacing.base)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.base)
    }
    
    private var historyListView: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.large) {
                // Summary Stats
                summaryStatsView
                
                // History Items
                LazyVStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(history, id: \.persistentModelID) { item in
                        NavigationLink {
                            historyDetailView(for: item)
                        } label: {
                            HistoryItemCard(item: item, onDelete: { deleteItem(item) })
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
            }
            .padding(.vertical, DesignSystem.Spacing.base)
        }
        .animation(.easeInOut(duration: 0.3), value: history)
    }
    
    private var summaryStatsView: some View {
        let completedCount = history.filter { $0.status == "completed" }.count
        let failedCount = history.filter { $0.status == "failed" }.count
        let totalSize = history.reduce(0) { $0 + $1.bytesTransferred }
        
        return VStack(spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                StatCard(
                    label: "Tamamlanan",
                    value: "\(completedCount)",
                    icon: "checkmark.circle.fill",
                    style: .success
                )
                
                StatCard(
                    label: "Başarısız",
                    value: "\(failedCount)",
                    icon: "xmark.circle.fill",
                    style: failedCount > 0 ? .error : .primary
                )
            }
            
            HStack {
                StatCard(
                    label: "Aktarılan",
                    value: formatFileSize(totalSize),
                    icon: "arrow.up.circle.fill",
                    style: .primary
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.base)
    }
    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            clearHistory()
        } label: {
            Image(systemName: "trash.fill")
        }
        .disabled(history.isEmpty)
    }
    
    private func loadHistory() {
        isLoading = true
        loadError = nil
        // SwiftData sorguları otomatik olduğu için ek iş yapılmıyor
        isLoading = false
    }
    
    private func deleteItem(_ item: BackupHistory) {
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            guard index < history.count else { continue }
            modelContext.delete(history[index])
        }
        try? modelContext.save()
    }
    
    private func clearHistory() {
        isLoading = true
        do {
            try modelContext.delete(model: BackupHistory.self)
            try modelContext.save()
        } catch {
            print("Geçmiş temizlenirken hata oluştu: \(error)")
        }
        isLoading = false
        loadHistory()
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0f saniye", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1f dakika", seconds / 60)
        } else {
            return String(format: "%.1f saat", seconds / 3600)
        }
    }

    private func localizedHistoryStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "completed":
            return "backup.status.completed".localized
        case "failed":
            return "backup.status.failed".localized
        case "cancelled":
            return "backup.status.cancelled".localized
        case "interrupted":
            return "backup.status.interrupted".localized
        case "uploading":
            return "backup.status.uploading".localized
        case "scanning":
            return "backup.status.scanning".localized
        case "preparing":
            return "backup.status.preparing".localized
        default:
            return status.capitalized
        }
    }
    
    private func historyDetailView(for item: BackupHistory) -> some View {
        List {
            Section("history.source".localized) {
                Text(item.taskSourcePath ?? "history.unknown".localized)
                    .font(.system(.body, design: .monospaced))
            }
            .liquidListRow()
            
            Section("history.destination".localized) {
                if let host = item.taskServerHost, let port = item.taskServerPort {
                    Text("\(host):\(port)")
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("history.unknown".localized)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .liquidListRow()
            
            Section("history.stats_section".localized) {
                LabeledContent("history.stats.status".localized, value: localizedHistoryStatus(item.status))
                LabeledContent("history.stats.files_processed".localized, value: "\(item.filesProcessed)")
                LabeledContent("history.stats.total_files".localized, value: "\(item.totalFiles)")
                if item.skippedFiles > 0 {
                    LabeledContent("history.files.skipped".localized, value: "\(item.skippedFiles)")
                }
                if item.deletedFiles > 0 {
                    LabeledContent("history.files.deleted".localized, value: "\(item.deletedFiles)")
                }
                LabeledContent("history.stats.total_size".localized, value: formatFileSize(item.totalBytes))
                LabeledContent("history.stats.duration".localized, value: formatDuration(item.duration))
                LabeledContent("history.stats.date".localized, value: item.timestamp.formatted(date: .long, time: .standard))
            }
            .liquidListRow()

            if let err = item.errorMessage, !err.isEmpty {
                Section("alert.error".localized) {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                .liquidListRow()
            }
        }
        .navigationTitle("history.backup_detail".localized)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .liquidBackground()
    }
}

// MARK: - History Item Card Component

struct HistoryItemCard: View {
    let item: BackupHistory
    let onDelete: () -> Void
    
    var statusStyle: StatusBadge.BadgeStyle {
        switch item.status.lowercased() {
        case "completed":
            return .success
        case "failed":
            return .error
        default:
            return .info
        }
    }
    
    var body: some View {
        ModernCard(
            cornerRadius: DesignSystem.CornerRadius.large,
            padding: DesignSystem.Spacing.base
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                // Header with title and status
                HStack(spacing: DesignSystem.Spacing.medium) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                        Text(item.taskDisplayName ?? "history.unknown_task".localized)
                            .font(DesignSystem.Typography.headline)
                            .lineLimit(1)
                        
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    StatusBadge(
                        text: localizedHistoryStatus(item.status),
                        style: statusStyle
                    )
                }
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                
                // Stats Grid
                HStack(spacing: DesignSystem.Spacing.medium) {
                    StatItem(
                        icon: "doc.fill",
                        label: "Dosyalar",
                        value: "\(item.filesProcessed)/\(item.totalFiles)"
                    )
                    
                    StatItem(
                        icon: "arrow.up.circle.fill",
                        label: "Aktarılan",
                        value: formatFileSize(item.bytesTransferred)
                    )
                    
                    StatItem(
                        icon: "timer",
                        label: "Süre",
                        value: formatDuration(item.duration)
                    )
                    
                    Spacer()
                }
                
                // Progress bar
                if item.totalFiles > 0 {
                    ModernProgressBar(
                        progress: Double(item.filesProcessed) / Double(item.totalFiles),
                        style: item.status == "completed" ? .success : .primary,
                        height: 6
                    )
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("history.delete".localized, systemImage: "trash")
            }
        }
    }
    
    private func localizedHistoryStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "completed":
            return "Tamamlandı"
        case "failed":
            return "Başarısız"
        case "cancelled":
            return "İptal Edildi"
        default:
            return status.capitalized
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1fm", seconds / 60)
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
}

// MARK: - Stat Item Component

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
    }
}
