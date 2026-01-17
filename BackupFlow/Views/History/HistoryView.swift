import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\BackupHistory.timestamp, order: .reverse)]) private var history: [BackupHistory]
    
    @State private var isLoading = false
    @State private var loadError: Error?
    
    var body: some View {
        NavigationStack {
            historyContent
                .navigationTitle("history.title".localized)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) { clearHistoryButton }
                    #else
                    ToolbarItem { clearHistoryButton }
                    #endif
                }
        }
        .onAppear {
            loadHistory()
        }
    }
    
    @ViewBuilder
    private var historyContent: some View {
        if isLoading {
            loadingView
        } else if let error = loadError {
            errorView(error: error)
        } else if history.isEmpty {
            emptyView
        } else {
            historyListView
        }
    }
    
    private var loadingView: some View {
        ProgressView("history.loading".localized)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Text(String(format: "history.error_occurred".localized, error.localizedDescription))
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
            Button("history.retry".localized) {
                loadHistory()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "history.no_history".localized,
            systemImage: "clock.arrow.circlepath"
        )
    }
    
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(history, id: \.persistentModelID) { item in
                    NavigationLink {
                        historyDetailView(for: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            // Başlık ve durum
                            HStack {
                                Text(item.taskDisplayName ?? "history.unknown_task".localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(localizedHistoryStatus(item.status))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.status == "completed" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                    .foregroundStyle(item.status == "completed" ? .green : .red)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            // İstatistikler - İlk satır
                            HStack(spacing: 16) {
                                Label("\(item.filesProcessed)/\(item.totalFiles)", systemImage: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(item.filesProcessed > 0 ? .primary : .secondary)
                                
                                if item.skippedFiles > 0 {
                                    Label("\(item.skippedFiles) \("history.files.skipped".localized)", systemImage: "doc.badge.clock")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                if item.deletedFiles > 0 {
                                    Label("\(item.deletedFiles) \("history.files.deleted".localized)", systemImage: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                
                                Spacer()
                            }
                            
                            // İstatistikler - İkinci satır
                            HStack(spacing: 16) {
                                Label(formatFileSize(item.bytesTransferred), systemImage: "arrow.up.circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if item.status.lowercased() == "completed" {
                                    Text("•")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatDuration(item.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .contextMenu {
                        Button(role: .destructive) {
                            if let index = history.firstIndex(where: { $0.persistentModelID == item.persistentModelID }) {
                                deleteItems(offsets: IndexSet([index]))
                            }
                        } label: {
                            Label("history.delete".localized, systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .animation(.default, value: history)
    }
    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            clearHistory()
        } label: {
            Label("history.delete_all".localized, systemImage: "trash")
        }
        .disabled(history.isEmpty)
    }
    
    private func loadHistory() {
        isLoading = true
        loadError = nil
        // SwiftData sorguları otomatik olduğu için ek iş yapılmıyor
        isLoading = false
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
            return String(format: "history.duration.seconds".localized, seconds)
        } else if seconds < 3600 {
            return String(format: "history.duration.minutes".localized, seconds / 60)
        } else {
            return String(format: "history.duration.hours".localized, seconds / 3600)
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
            
            Section("history.destination".localized) {
                if let host = item.taskServerHost, let port = item.taskServerPort {
                    Text("\(host):\(port)")
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("history.unknown".localized)
                        .font(.system(.body, design: .monospaced))
                }
                if item.taskIsAnonymous == true {
                    Label("history.anonymous_ftp".localized, systemImage: "person.crop.circle.badge.questionmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let username = item.taskUsername, !username.isEmpty {
                    Label(String(format: "history.user_prefix".localized, username), systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let mediaType = item.taskMediaType {
                    Label(String(format: "history.media_type_prefix".localized, mediaType.displayName), systemImage: "photo.on.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
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

            if let err = item.errorMessage, !err.isEmpty {
                Section("alert.error".localized) {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("history.backup_detail".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
