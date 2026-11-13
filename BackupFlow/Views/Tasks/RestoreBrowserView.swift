import SwiftUI

struct RestoreBrowserView: View {
    let task: BackupTask

    @Environment(\.dismiss) private var dismiss
    @State private var restoreService = RestoreService()
    @State private var currentPath: String = "/"
    @State private var pathHistory: [String] = []
    @State private var entries: [RestoreService.RemoteEntry] = []
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""
    @State private var destination: RestoreService.RestoreDestination = .files
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var exportedURLs: [URL] = []
    @State private var tempDirectoryToCleanup: URL?

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private var filteredEntries: [RestoreService.RemoteEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var selectedFiles: [RestoreService.RemoteEntry] {
        entries.filter { !$0.isDirectory && selectedIDs.contains($0.id) }
    }

    private var archiveRoot: String {
        RestoreService.archiveRootPath(for: task.destinationPath)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if restoreService.isDownloading {
                    downloadProgressBanner
                }

                List {
                    Section {
                        HStack(spacing: 8) {
                            if !pathHistory.isEmpty {
                                Button {
                                    navigateBack()
                                } label: {
                                    Label("common.back".localized, systemImage: "chevron.left")
                                }
                                .buttonStyle(.bordered)
                            }

                            Button {
                                navigate(to: archiveRoot, pushHistory: true)
                            } label: {
                                Label("restore.open_archive".localized, systemImage: "archivebox")
                            }
                            .buttonStyle(.bordered)
                        }
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(currentPath)
                            .textSelection(.enabled)
                    }

                    if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("restore.loading".localized)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.error)
                            .textSelection(.enabled)
                    } else if filteredEntries.isEmpty {
                        Text("restore.empty_folder".localized)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredEntries) { entry in
                            rowView(for: entry)
                        }
                    }

                    if let statusMessage {
                        Section {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(DesignSystem.Colors.success)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "restore.search_prompt".localized)

                bottomActionBar
            }
            .navigationTitle("restore.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.details.close".localized) {
                        restoreService.cancelDownload()
                        cleanupTempDirectory()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reloadCurrentDirectory() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || restoreService.isDownloading)
                }
            }
            .task {
                let startPath = task.destinationPath.isEmpty ? "/" : task.destinationPath
                currentPath = startPath
                await connectAndLoad()
            }
            .onDisappear {
                cleanupTempDirectory()
            }
        }
    }

    @ViewBuilder
    private func rowView(for entry: RestoreService.RemoteEntry) -> some View {
        if entry.isDirectory {
            Button {
                navigate(to: entry.path, pushHistory: true)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .accessibilityHidden(true)
                    Text(entry.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        } else {
            let isSelected = selectedIDs.contains(entry.id)
            Button {
                if isSelected {
                    selectedIDs.remove(entry.id)
                } else {
                    selectedIDs.insert(entry.id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DesignSystem.Colors.primary : .secondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(Self.byteFormatter.string(fromByteCount: entry.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var downloadProgressBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(restoreService.currentFileName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text("\(restoreService.completedCount)/\(restoreService.totalCount)")
                    .font(.caption)
                    .monospacedDigit()
                Button("common.cancel".localized, role: .cancel) {
                    restoreService.cancelDownload()
                }
                .font(.caption.weight(.semibold))
            }
            ProgressView(value: restoreService.progress)
                .tint(DesignSystem.Colors.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Picker("restore.destination".localized, selection: $destination) {
                Text("restore.destination.files".localized).tag(RestoreService.RestoreDestination.files)
                Text("restore.destination.photos".localized).tag(RestoreService.RestoreDestination.photos)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button {
                    Task { await startRestore() }
                } label: {
                    Label(
                        "restore.download_selected".localized(with: selectedFiles.count),
                        systemImage: "arrow.down.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty || restoreService.isDownloading)

                if !exportedURLs.isEmpty {
                    ShareLink(items: exportedURLs) {
                        Label("restore.export_files".localized, systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func connectAndLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            try await restoreService.connect(for: task)
            entries = try await restoreService.listDirectory(task: task, path: currentPath)
        } catch {
            errorMessage = error.localizedDescription
            entries = []
        }
        isLoading = false
    }

    private func reloadCurrentDirectory() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await restoreService.listDirectory(task: task, path: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func navigate(to path: String, pushHistory: Bool) {
        if pushHistory {
            pathHistory.append(currentPath)
        }
        currentPath = path
        selectedIDs.removeAll()
        Task { await reloadCurrentDirectory() }
    }

    private func navigateBack() {
        guard let previous = pathHistory.popLast() else { return }
        currentPath = previous
        selectedIDs.removeAll()
        Task { await reloadCurrentDirectory() }
    }

    private func startRestore() async {
        errorMessage = nil
        statusMessage = nil
        cleanupTempDirectory()
        exportedURLs = []

        do {
            let result = try await restoreService.downloadFiles(
                task: task,
                entries: selectedFiles,
                destination: destination
            )
            tempDirectoryToCleanup = result.tempDirectory

            if destination == .files {
                exportedURLs = result.downloadedURLs
                statusMessage = "restore.ready_to_export".localized(with: result.downloadedURLs.count)
            } else {
                statusMessage = "restore.saved_to_photos".localized(with: result.savedToPhotosCount)
            }

            if result.failedCount > 0 {
                errorMessage = "restore.partial_failures".localized(with: result.failedCount)
            }
        } catch is CancellationError {
            // User cancelled
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanupTempDirectory() {
        if let dir = tempDirectoryToCleanup {
            try? FileManager.default.removeItem(at: dir)
            tempDirectoryToCleanup = nil
        }
    }
}
