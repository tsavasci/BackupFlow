import SwiftData
import SwiftUI

struct HistoryView: View {
    var showsCloseButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var queriedHistory: [BackupHistory]

    @State private var showingClearConfirmation = false
    @State private var selectedProtocol: BackupType?

    private var history: [BackupHistory] {
        queriedHistory.filter { $0.modelContext != nil }
    }

    private var filteredHistory: [BackupHistory] {
        guard let selectedProtocol else { return history }
        return history.filter { $0.inferredBackupType == selectedProtocol }
    }

    private var groupedHistory: [(day: Date, items: [BackupHistory])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { cal.startOfDay(for: $0.timestamp) }
        return grouped.keys
            .sorted(by: >)
            .map { day in
                (day, (grouped[day] ?? []).sorted { $0.timestamp > $1.timestamp })
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    emptyRow
                } else {
                    Section {
                        summaryHeader
                        Picker("backup.target_type".localized, selection: $selectedProtocol) {
                            Text("history.filter.all".localized).tag(BackupType?.none)
                            ForEach(BackupType.allCases) { type in
                                Text(protocolLabel(for: type)).tag(BackupType?.some(type))
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(BF.bg)
                    .listRowSeparator(.hidden)

                    ForEach(groupedHistory, id: \.day) { group in
                        Section {
                            ForEach(group.items, id: \.persistentModelID) { item in
                                NavigationLink {
                                    HistoryDetailView(item: item)
                                } label: {
                                    HistoryRow(item: item)
                                }
                                .accessibilityIdentifier("history.item")
                                .listRowBackground(BF.bg)
                                .listRowSeparatorTint(BF.line)
                                .swipeActions(edge: .trailing) {
                                    Button("history.delete".localized, role: .destructive) {
                                        deleteItem(item)
                                    }
                                }
                            }
                        } header: {
                            Text(group.day.formatted(.dateTime.day().month(.wide).year()))
                                .font(BF.monoSmall)
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BF.bg)
            .navigationTitle("history.title".localized)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("task.details.close".localized) { dismiss() }
                            .accessibilityIdentifier("sheet.close")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(history.isEmpty)
                    .accessibilityLabel("history.delete_all".localized)
                }
            }
            .confirmationDialog(
                "history.clear_confirmation".localized,
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("history.delete_all".localized, role: .destructive) {
                    clearHistory()
                }
            } message: {
                Text("history.clear_confirmation_message".localized)
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
    }

    private var summaryHeader: some View {
        let completed = filteredHistory.filter { $0.status == "completed" }.count
        let failed = filteredHistory.count - completed
        let totalBytes = filteredHistory.reduce(Int64(0)) { $0 + $1.bytesTransferred }
        let sizeText = DashboardFormat.bytes(totalBytes)
        return Text("\(completed) \("history.summary.completed".localized.lowercased())  ·  \(failed) \("history.summary.failed".localized.lowercased())  ·  \(sizeText)")
            .font(BF.mono)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("history.no_history".localized)
                .font(.body.weight(.medium))
            Text("history.empty_description".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .listRowBackground(BF.bg)
        .listRowSeparator(.hidden)
    }

    private func protocolLabel(for type: BackupType) -> String {
        switch type {
        case .ftp: return "FTP"
        case .sftp: return "SFTP"
        case .webdav: return "WebDAV"
        }
    }

    private func deleteItem(_ item: BackupHistory) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func clearHistory() {
        for item in history {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let item: BackupHistory

    private var isSuccess: Bool {
        item.status == "completed"
    }

    private var protocolLabel: String {
        switch item.inferredBackupType {
        case .ftp: return "FTP"
        case .sftp: return "SFTP"
        case .webdav: return "WebDAV"
        case .none: return "—"
        }
    }

    private var summaryText: String {
        let filesText = "\(item.filesProcessed.formatted()) \("home.files_unit".localized)"
        let sizeText = DashboardFormat.bytes(item.bytesTransferred)
        let durationText = DashboardFormat.duration(item.duration)
        return "\(filesText) · \(sizeText) · \(durationText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Circle()
                    .fill(isSuccess ? BF.ok : BF.fail)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(item.taskDisplayName ?? "history.unknown_task".localized)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(protocolLabel)
                .font(BF.monoSmall)
                .foregroundStyle(BF.protocolColor(protocolLabel))

            if isSuccess {
                Text(summaryText)
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(item.errorMessage ?? BackupHistory.localizedStatus(item.status))
                    .font(BF.monoSmall)
                    .foregroundStyle(BF.fail)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityValue(BackupHistory.localizedStatus(item.status))
    }
}

// MARK: - History Detail

struct HistoryDetailView: View {
    let item: BackupHistory

    private var isSuccess: Bool {
        item.status == "completed"
    }

    private var sourceText: String {
        item.taskSourcePath == "PHOTOS_LIBRARY"
            ? "backup.photos_option".localized
            : (item.taskSourcePath ?? "history.unknown".localized)
    }

    private var destinationText: String {
        if let host = item.taskServerHost, let port = item.taskServerPort {
            return "\(host):\(port)"
        }
        return "history.unknown".localized
    }

    var body: some View {
        Form {
            Section {
                monoRow("history.source".localized, sourceText)
                monoRow("history.destination".localized, destinationText)
            } header: {
                sectionLabel("history.destination".localized.uppercased())
            }
            .listRowBackground(BF.surface)

            Section {
                LabeledContent("history.stats.status".localized) {
                    Text(BackupHistory.localizedStatus(item.status))
                        .foregroundStyle(isSuccess ? BF.ok : BF.fail)
                }
                monoRow("history.stats.files_processed".localized, "\(item.filesProcessed.formatted()) / \(item.totalFiles.formatted())")
                if item.skippedFiles > 0 {
                    monoRow("history.files.skipped".localized, item.skippedFiles.formatted())
                }
                if item.deletedFiles > 0 {
                    monoRow("history.files.deleted".localized, item.deletedFiles.formatted())
                }
                monoRow("history.stats.total_size".localized, DashboardFormat.bytes(item.bytesTransferred))
                monoRow("history.stats.duration".localized, DashboardFormat.duration(item.duration))
                monoRow("history.stats.date".localized, item.timestamp.formatted(date: .abbreviated, time: .standard))
            } header: {
                sectionLabel("history.stats_section".localized.uppercased())
            }
            .listRowBackground(BF.surface)

            if let err = item.errorMessage, !err.isEmpty, !isSuccess {
                Section {
                    Text(err)
                        .font(BF.mono)
                        .foregroundStyle(BF.fail)
                        .textSelection(.enabled)
                } header: {
                    sectionLabel("alert.error".localized.uppercased())
                }
                .listRowBackground(BF.surface)
            }

            Section {
                ShareLink(item: reportJSON(for: item)) {
                    Label("history.report.share_json".localized, systemImage: "square.and.arrow.up")
                }
                ShareLink(item: reportCSV(for: item)) {
                    Label("history.report.share_csv".localized, systemImage: "square.and.arrow.up")
                }
                ShareLink(item: BackupDiagnosticsExporter.buildReport(historyItem: item)) {
                    Label("history.report.share_diagnostics".localized, systemImage: "square.and.arrow.up")
                }
            } header: {
                sectionLabel("history.report.section".localized.uppercased())
            }
            .listRowBackground(BF.surface)
        }
        .scrollContentBackground(.hidden)
        .background(BF.bg)
        .navigationTitle(item.taskDisplayName ?? "history.backup_detail".localized)
        .navigationBarTitleDisplayMode(.inline)
        .tint(BF.accent)
        .preferredColorScheme(.dark)
    }

    private func monoRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(BF.mono)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BF.monoSmall)
            .textCase(nil)
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
