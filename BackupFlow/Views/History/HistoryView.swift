import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var history: [BackupHistory]
    
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                historyContent
                    .navigationTitle("history.title".localized)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("task.details.close".localized) { dismiss() }
                                .accessibilityIdentifier("sheet.close")
                        }
                        ToolbarItem(placement: .navigationBarTrailing) { clearHistoryButton }
                    }
            }
        }
        .alert("history.clear_confirmation".localized, isPresented: $showingClearConfirmation) {
            Button("alert.cancel".localized, role: .cancel) {}
            Button("history.delete_all".localized, role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("history.clear_confirmation_message".localized)
        }
    }
    
    @ViewBuilder
    private var historyContent: some View {
        if history.isEmpty {
            ModernEmptyState(
                icon: "clock.arrow.circlepath",
                title: "history.no_history".localized,
                description: "history.empty_description".localized
            )
        } else {
            historyListView
        }
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
                        .accessibilityIdentifier("history.item")
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
            }
            .padding(.vertical, DesignSystem.Spacing.base)
        }
        .animation(DesignSystem.Animation.swift, value: history)
    }
    
    private var summaryStatsView: some View {
        let completedCount = history.filter { $0.status == "completed" }.count
        let failedCount = history.filter { $0.status == "failed" }.count
        let totalSize = history.reduce(0) { $0 + $1.bytesTransferred }
        
        return VStack(spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                StatCard(
                    label: "history.summary.completed".localized,
                    value: "\(completedCount)",
                    icon: "checkmark.circle.fill",
                    style: .success
                )
                
                StatCard(
                    label: "history.summary.failed".localized,
                    value: "\(failedCount)",
                    icon: "xmark.circle.fill",
                    style: failedCount > 0 ? .error : .primary
                )
            }
            
            HStack {
                StatCard(
                    label: "history.summary.transferred".localized,
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
            showingClearConfirmation = true
        } label: {
            Image(systemName: "trash.fill")
        }
        .accessibilityLabel("history.delete_all".localized)
        .disabled(history.isEmpty)
    }
    
    private func deleteItem(_ item: BackupHistory) {
        withAnimation(DesignSystem.Animation.swift) {
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
    
    private func clearHistory() {
        do {
            try modelContext.delete(model: BackupHistory.self)
            try modelContext.save()
        } catch {
            debugLog("Geçmiş temizlenirken hata oluştu: \(error)")
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "history.duration.seconds".localized(with: String(format: "%.0f", seconds))
        } else if seconds < 3600 {
            return "history.duration.minutes".localized(with: String(format: "%.1f", seconds / 60))
        } else {
            return "history.duration.hours".localized(with: String(format: "%.1f", seconds / 3600))
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
        case "deferred":
            return "backup.status.deferred".localized
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
                Text(item.taskSourcePath == "PHOTOS_LIBRARY"
                     ? "backup.photos_option".localized
                     : item.taskSourcePath ?? "history.unknown".localized)
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

            Section("history.report.section".localized) {
                ShareLink("history.report.share_json".localized, item: reportJSON(for: item))
                ShareLink("history.report.share_csv".localized, item: reportCSV(for: item))
            }
            .liquidListRow()
        }
        .navigationTitle("history.backup_detail".localized)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .liquidBackground()
    }

    private func reportJSON(for item: BackupHistory) -> String {
        """
        {
          "id": "\(item.id.uuidString)",
          "task": "\(item.taskDisplayName ?? "")",
          "status": "\(item.status)",
          "failureCategory": "\(item.failureCategory?.rawValue ?? "")",
          "timestamp": "\(ISO8601DateFormatter().string(from: item.timestamp))",
          "filesProcessed": \(item.filesProcessed),
          "newFiles": \(item.newFiles),
          "updatedFiles": \(item.updatedFiles),
          "skippedFiles": \(item.skippedFiles),
          "deletedFiles": \(item.deletedFiles),
          "verifiedFiles": \(item.verifiedFiles),
          "totalBytes": \(item.totalBytes),
          "duration": \(item.duration)
        }
        """
    }

    private func reportCSV(for item: BackupHistory) -> String {
        let values = [
            item.id.uuidString,
            item.taskDisplayName ?? "",
            item.status,
            item.failureCategory?.rawValue ?? "",
            ISO8601DateFormatter().string(from: item.timestamp),
            "\(item.filesProcessed)",
            "\(item.newFiles)",
            "\(item.updatedFiles)",
            "\(item.skippedFiles)",
            "\(item.deletedFiles)",
            "\(item.verifiedFiles)",
            "\(item.totalBytes)",
            "\(item.duration)"
        ]
        let escaped = values.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        return "id,task,status,failureCategory,timestamp,filesProcessed,newFiles,updatedFiles,skippedFiles,deletedFiles,verifiedFiles,totalBytes,duration\n\(escaped)"
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
                        label: "history.item.files".localized,
                        value: "\(item.filesProcessed)/\(item.totalFiles)"
                    )
                    
                    StatItem(
                        icon: "arrow.up.circle.fill",
                        label: "history.item.transferred".localized,
                        value: formatFileSize(item.bytesTransferred)
                    )
                    
                    StatItem(
                        icon: "timer",
                        label: "history.item.duration".localized,
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
            return "history.duration.short_seconds".localized(with: String(format: "%.0f", seconds))
        } else if seconds < 3600 {
            return "history.duration.short_minutes".localized(with: String(format: "%.1f", seconds / 60))
        } else {
            return "history.duration.short_hours".localized(with: String(format: "%.1f", seconds / 3600))
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
