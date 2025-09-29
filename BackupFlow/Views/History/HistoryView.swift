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
        .onAppear {
            cleanUpInvalidHistory()
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
            ForEach(history, id: \.persistentModelID) { item in
                // Skip items with invalid task references
                if item.task == nil {
                    EmptyView()
                } else {
                    NavigationLink {
                        historyDetailView(for: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.task?.displayName ?? "Bilinmeyen Görev")
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
                            if (item.totalFiles - item.filesProcessed) > 0 {
                                Label("\(item.totalFiles - item.filesProcessed) pas geçildi", systemImage: "arrow.forward.circle")
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
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .animation(.default, value: history)
    }
    var clearHistoryButton: some View {
        Button(role: .destructive) {
            clearHistory()
        } label: {
            Label("Tümünü Sil", systemImage: "trash")
        }
        .disabled(history.isEmpty)
    }
    
    func loadHistory() {
        isLoading = true
        loadError = nil
        // SwiftData sorguları otomatik olduğu için ek iş yapılmıyor
        isLoading = false
    }
    
    func deleteItems(offsets: IndexSet) {
        for index in offsets {
            guard index < history.count else { continue }
            modelContext.delete(history[index])
        }
        try? modelContext.save()
    }
    
    func clearHistory() {
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
    
    private func cleanUpInvalidHistory() {
        let invalidEntries = history.filter { $0.task == nil }
        if !invalidEntries.isEmpty {
            for entry in invalidEntries {
                modelContext.delete(entry)
            }
            try? modelContext.save()
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
                    if task.isAnonymous {
                        Label("Anonim FTP", systemImage: "person.crop.circle.badge.questionmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !task.ftpUsername.isEmpty {
                        Label("Kullanıcı: \(task.ftpUsername)", systemImage: "person.crop.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label("Medya Türü: \(task.mediaType.displayName)", systemImage: "photo.on.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Bilinmiyor")
                        .font(.system(.body, design: .monospaced))
                }
            }
            
            Section("İstatistikler") {
                LabeledContent("Durum", value: item.status)
                LabeledContent("Yedeklenen Dosya", value: "\(item.filesProcessed)")
                LabeledContent("Toplam Dosya", value: "\(item.totalFiles)")
                if item.skippedFiles > 0 {
                    LabeledContent("Atlanan Dosya", value: "\(item.skippedFiles)")
                }
                LabeledContent("Toplam Boyut", value: formatFileSize(item.totalBytes))
                LabeledContent("Süre", value: formatDuration(item.duration))
                LabeledContent("Tarih", value: item.timestamp.formatted(date: .long, time: .standard))
            }

            if let err = item.errorMessage, !err.isEmpty {
                Section("Hata") {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Yedekleme Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

