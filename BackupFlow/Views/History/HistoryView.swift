import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var history: [BackupHistory]
    
    @State private var showingClearConfirmation = false
    @State private var selectedProtocol: BackupType?

    private var filteredHistory: [BackupHistory] {
        guard let selectedProtocol else { return history }
        return history.filter { $0.inferredBackupType == selectedProtocol }
    }
    
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

                // Protocol Filter Bar
                protocolFilterBar
                
                // History Items
                LazyVStack(spacing: DesignSystem.Spacing.medium) {
                    ForEach(filteredHistory, id: \.persistentModelID) { item in
                        NavigationLink {
                            HistoryDetailView(item: item)
                        } label: {
                            HistoryItemCard(item: item, onDelete: { deleteItem(item) })
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("history.item")
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.base)
            }
            .padding(.vertical, DesignSystem.Spacing.base)
        }
        .animation(DesignSystem.Animation.swift, value: selectedProtocol)
        .animation(DesignSystem.Animation.swift, value: history)
    }

    private var protocolFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.small) {
                filterChip(title: "history.filter.all".localized, backupType: nil)

                ForEach(BackupType.allCases, id: \.self) { type in
                    filterChip(title: type.rawValue, backupType: type)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.base)
        }
    }

    private func filterChip(title: String, backupType: BackupType?) -> some View {
        let isSelected = selectedProtocol == backupType
        let chipTheme = DashboardTheme.theme(for: backupType)
        let activeColor = backupType == nil ? DesignSystem.Colors.primary : chipTheme.primary

        return Button {
            selectedProtocol = backupType
        } label: {
            HStack(spacing: 6) {
                if backupType != nil {
                    Circle()
                        .fill(isSelected ? Color.white : chipTheme.primary)
                        .frame(width: 7, height: 7)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? activeColor : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? activeColor.opacity(0.2) : Color.primary.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
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
    
}

// MARK: - History Detail

/// "Backup Detail" screen, opened from the history list and the dashboard's recent backups.
struct HistoryDetailView: View {
    let item: BackupHistory

    var body: some View {
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
                LabeledContent("history.stats.status".localized, value: BackupHistory.localizedStatus(item.status))
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
                ShareLink("history.report.share_diagnostics".localized, item: BackupDiagnosticsExporter.buildReport(historyItem: item))
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
        let cardTheme = DashboardTheme.theme(for: item.inferredBackupType)
        let cornerRadius = DesignSystem.CornerRadius.large
        let isFailed = item.status.lowercased() == "failed"
        let isCancelled = item.status.lowercased() == "cancelled"
        let iconName = isFailed
            ? "exclamationmark.triangle.fill"
            : (isCancelled ? "xmark.circle.fill" : "checkmark.seal.fill")
        let iconColor: Color = isFailed ? .red : (isCancelled ? .orange : cardTheme.primary)
        let ratio = item.totalFiles > 0
            ? min(1.0, max(0.0, Double(item.filesProcessed) / Double(item.totalFiles)))
            : 0.0

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            // Header with protocol icon, title, protocol pill, chevron, timestamp and status
            HStack(alignment: .top, spacing: DesignSystem.Spacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardTheme.primary.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.small) {
                        Text(item.taskDisplayName ?? "history.unknown_task".localized)
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)

                        Spacer(minLength: 4)

                        if let backupType = item.inferredBackupType {
                            Text(backupType.rawValue)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(cardTheme.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(cardTheme.primary.opacity(0.16)))
                                .fixedSize()
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: DesignSystem.Spacing.small) {
                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(DesignSystem.Typography.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 4)

                        StatusBadge(
                            text: BackupHistory.localizedStatus(item.status),
                            style: statusStyle
                        )
                        .fixedSize()
                    }
                }
            }
            
            Divider()
                .opacity(0.5)
            
            // Stats Grid (3 equal-width columns)
            HStack(spacing: DesignSystem.Spacing.small) {
                StatItem(
                    icon: "doc.fill",
                    label: "history.item.files".localized,
                    value: "\(item.filesProcessed)/\(item.totalFiles)",
                    accentColor: cardTheme.primary
                )
                
                StatItem(
                    icon: "arrow.up.circle.fill",
                    label: "history.item.transferred".localized,
                    value: formatFileSize(item.bytesTransferred),
                    accentColor: cardTheme.primary
                )
                
                StatItem(
                    icon: "timer",
                    label: "history.item.duration".localized,
                    value: formatDuration(item.duration),
                    accentColor: cardTheme.primary
                )
            }

            if isFailed, let errorMessage = item.errorMessage, !errorMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.08))
                )
            }
            
            // Progress bar
            if item.totalFiles > 0 {
                HStack(spacing: 8) {
                    ModernProgressBar(
                        progress: ratio,
                        style: item.status == "completed" ? .success : (isFailed ? .error : .primary),
                        height: 5
                    )
                    Text("\(Int(ratio * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(DesignSystem.Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            cardTheme.primary.opacity(0.14),
                            cardTheme.secondary.opacity(0.07),
                            Color(.secondarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .bottomTrailing) {
                    if let backupType = item.inferredBackupType {
                        Text(backupType.rawValue)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(cardTheme.primary.opacity(0.06))
                            .padding(.trailing, 14)
                            .offset(y: 6)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            cardTheme.primary.opacity(0.35),
                            cardTheme.secondary.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: cardTheme.primary.opacity(0.08), radius: 8, x: 0, y: 4)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("history.delete".localized, systemImage: "trash")
            }
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
    var accentColor: Color = DesignSystem.Colors.primary
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
                .accessibilityHidden(true)
            
            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Text(value)
                .font(DesignSystem.Typography.caption1)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}
