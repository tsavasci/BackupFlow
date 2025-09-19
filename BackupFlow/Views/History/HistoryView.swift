import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BackupHistory.timestamp, order: .reverse) private var history: [BackupHistory]
    
    @State private var isLoading = false
    @State private var loadError: Error?
    
    var body: some View {
        NavigationStack {
            historyContent
                .navigationTitle("Yedek Geçmişi")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        clearHistoryButton
                    }
                }
        }
        .onAppear(perform: loadHistory)
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
        ProgressView("Yükleniyor...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: Error) -> some View {
        VStack(spacing: 12) {
            Text("Hata Oluştu: \(error.localizedDescription)")
                .multilineTextAlignment(.center)
                .foregroundColor(.red)
            Button("Tekrar Dene") {
                loadHistory()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "Yedek Geçmişi Yok",
            systemImage: "clock.arrow.circlepath"
        )
    }
    
    private var historyListView: some View {
        List {
            ForEach(history) { item in
                NavigationLink {
                    historyDetailView(for: item)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.task?.sourcePath.components(separatedBy: "/").last ?? "Bilinmeyen")
                                .font(.headline)
                            Spacer()
                            Text(item.status)
                                .font(.caption)
                                .padding(4)
                                .background(item.status == "completed" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .foregroundStyle(item.status == "completed" ? .green : .red)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        HStack(spacing: 12) {
                            Label("\(item.totalFiles) dosya", systemImage: "doc")
                            let skippedCount = item.totalFiles - item.filesProcessed
                            if skippedCount > 0 {
                                Label("\(skippedCount) pas geçildi", systemImage: "arrow.forward.circle")
                            }
                            Label(formatFileSize(item.totalBytes), systemImage: "folder")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                            if item.status.lowercased() == "completed" {
                                Text("•")
                                Text(formatDuration(item.duration))
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .animation(.default, value: history)
    }
    
    private var clearHistoryButton: some View {
        Button(role: .destructive) {
            clearHistory()
        } label: {
            Label("Tümünü Sil", systemImage: "trash")
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
            modelContext.delete(history[index])
        }
    }
    
    private func clearHistory() {
        isLoading = true
        do {
            try modelContext.delete(model: BackupHistory.self)
        } catch {
            loadError = error
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
            return String(format: "%.1f saniye", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1f dakika", seconds / 60)
        } else {
            return String(format: "%.1f saat", seconds / 3600)
        }
    }
    
    private func historyDetailView(for item: BackupHistory) -> some View {
        List {
            Section("Kaynak") {
                Text(item.task?.sourcePath ?? "Bilinmiyor")
                    .font(.system(.body, design: .monospaced))
            }
            
            Section("Hedef") {
                if let task = item.task {
                    Text("\(task.ftpHost):\(task.ftpPort)")
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("Bilinmiyor")
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            Section("İstatistikler") {
                LabeledContent("Durum", value: item.status)
                LabeledContent("Yedeklenen Dosya", value: "\(item.filesProcessed)")
                LabeledContent("Toplam Dosya", value: "\(item.totalFiles)")
                let skippedCount = item.totalFiles - item.filesProcessed
                if skippedCount > 0 {
                    LabeledContent("Pas Geçilen Dosya", value: "\(skippedCount)")
                }
                LabeledContent("Toplam Boyut", value: formatFileSize(item.totalBytes))
                LabeledContent("Süre", value: formatDuration(item.duration))
                LabeledContent("Tarih", value: item.timestamp.formatted(date: .long, time: .standard))
            }
        }
        .navigationTitle("Yedekleme Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

