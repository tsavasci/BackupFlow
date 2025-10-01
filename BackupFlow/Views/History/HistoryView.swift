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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(history, id: \.persistentModelID) { item in
                    if item.task == nil {
                        EmptyView()
                    } else {
                        NavigationLink {
                            historyDetailView(for: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                // Başlık ve durum
                                HStack {
                                    Text(item.task?.displayName ?? "Bilinmeyen Görev")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(item.status == "completed" ? "Tamamlandı" : item.status.capitalized)
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
                                        Label("\(item.skippedFiles) atlandı", systemImage: "doc.badge.clock")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    if item.deletedFiles > 0 {
                                        Label("\(item.deletedFiles) silindi", systemImage: "trash")
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
                                Label("Sil", systemImage: "trash")
                            }
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
                if item.deletedFiles > 0 {
                    LabeledContent("Silinen Dosya", value: "\(item.deletedFiles)")
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

