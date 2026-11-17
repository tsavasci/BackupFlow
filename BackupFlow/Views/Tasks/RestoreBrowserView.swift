import SwiftUI

struct RestoreBrowserView: View {
    let task: BackupTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showingSmartRestoreSheet = false

    private var isSmartRestoreAvailable: Bool {
        task.sourcePath != "PHOTOS_LIBRARY" || SmartRestoreConfiguration.isPhotoSmartRestoreEnabled
    }

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if restoreService.isDownloading {
                    downloadProgressBanner
                }

                List {
                    Section {
                        if isSmartRestoreAvailable {
                            Button {
                                showingSmartRestoreSheet = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("smart_restore.open_button".localized)
                                            .font(.body.weight(.medium))
                                        Text("smart_restore.open_subtitle".localized)
                                            .font(BF.monoSmall)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                                .padding(.vertical, 4)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            }
                            .listRowBackground(BF.surface)
                            .listRowSeparatorTint(BF.line)
                        }

                        pathNavigationToolbar
                            .listRowBackground(BF.bg)
                            .listRowSeparatorTint(BF.line)
                    }

                    Section {
                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(BF.accent)
                                Text("restore.loading".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(BF.bg)
                        } else if let errorMessage {
                            Text(errorMessage)
                                .font(BF.monoSmall)
                                .foregroundStyle(BF.fail)
                                .textSelection(.enabled)
                                .padding(.vertical, 6)
                                .listRowBackground(BF.bg)
                        } else if filteredEntries.isEmpty {
                            Text("restore.empty_folder".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .listRowBackground(BF.bg)
                        } else {
                            ForEach(filteredEntries) { entry in
                                rowView(for: entry)
                                    .listRowBackground(BF.bg)
                                    .listRowSeparatorTint(BF.line)
                            }
                        }
                    }

                    if let statusMessage {
                        Section {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(BF.ok)
                                    .frame(width: 8, height: 8)
                                    .accessibilityHidden(true)
                                Text(statusMessage)
                                    .font(BF.monoSmall)
                                    .foregroundStyle(BF.ok)
                            }
                            .listRowBackground(BF.bg)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(BF.bg)
                .searchable(text: $searchText, prompt: "restore.search_prompt".localized)

                bottomActionBar
            }
            .background(BF.bg)
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
                            .accessibilityHidden(true)
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
            .sheet(isPresented: $showingSmartRestoreSheet, onDismiss: {
                Task { await connectAndLoad() }
            }) {
                SmartRestoreView(task: task)
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Path & Row Components

    private var pathNavigationToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !pathHistory.isEmpty {
                    Button {
                        navigateBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                    }
                    .tint(BF.accent)
                }

                Text(currentPath)
                    .font(BF.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

                Text("\(filteredEntries.count)")
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func rowView(for entry: RestoreService.RemoteEntry) -> some View {
        if entry.isDirectory {
            Button {
                navigate(to: entry.path, pushHistory: true)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(BF.accent)
                        .accessibilityHidden(true)

                    Text(entry.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
        } else {
            let isSelected = selectedIDs.contains(entry.id)
            let ext = (entry.name as NSString).pathExtension
            Button {
                if isSelected {
                    selectedIDs.remove(entry.id)
                } else {
                    selectedIDs.insert(entry.id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? BF.accent : .secondary)
                        .accessibilityHidden(true)

                    Image(systemName: fileSymbol(forExtension: ext))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(Self.byteFormatter.string(fromByteCount: entry.size))
                            .font(BF.monoSmall)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
        }
    }

    private func fileSymbol(forExtension ext: String) -> String {
        if RestoreService.isImageExtension(ext) { return "photo" }
        if RestoreService.isVideoExtension(ext) { return "film" }
        return "doc"
    }

    private var downloadProgressBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(restoreService.currentFileName)
                    .font(BF.monoSmall)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(restoreService.completedCount)/\(restoreService.totalCount)")
                    .font(BF.monoSmall)
                    .monospacedDigit()
                Button("common.cancel".localized, role: .cancel) {
                    restoreService.cancelDownload()
                }
                .font(.caption.weight(.semibold))
            }
            ProgressView(value: restoreService.progress)
                .tint(BF.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var bottomActionBar: some View {
        let isDisabled = selectedFiles.isEmpty || restoreService.isDownloading
        return VStack(spacing: 10) {
            Picker("restore.destination".localized, selection: $destination) {
                Text("restore.destination.files".localized).tag(RestoreService.RestoreDestination.files)
                Text("restore.destination.photos".localized).tag(RestoreService.RestoreDestination.photos)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button {
                    Task { await startRestore() }
                } label: {
                    Text("restore.download_selected".localized(with: selectedFiles.count))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isDisabled)

                if !exportedURLs.isEmpty {
                    ShareLink(items: exportedURLs) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Networking Actions

    private func connectAndLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            try await restoreService.connect(for: task)
            if pathHistory.isEmpty {
                let snapshot = SmartRestoreTaskSnapshot(task: task)
                let client = RemoteRestoreClientFactory.makeClient(for: snapshot)
                if let resolvedRoot = try? await client.resolveEffectiveBackupRoot(), !resolvedRoot.isEmpty {
                    currentPath = resolvedRoot
                }
            }
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
