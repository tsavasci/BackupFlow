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

    private var theme: DashboardTheme {
        DashboardTheme.theme(for: task.backupType)
    }

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
            ZStack {
                ambientBackground

                VStack(spacing: 0) {
                    if restoreService.isDownloading {
                        downloadProgressBanner
                    }

                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                if isSmartRestoreAvailable {
                                    smartRestoreEntryCard
                                }
                                pathNavigationToolbar
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        Section {
                            if isLoading {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(theme.primary)
                                    Text("restore.loading".localized)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 10)
                                .liquidListRow()
                            } else if let errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(DesignSystem.Colors.error)
                                        .accessibilityHidden(true)
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.error)
                                        .textSelection(.enabled)
                                }
                                .padding(.vertical, 6)
                                .liquidListRow()
                            } else if filteredEntries.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.badge.questionmark")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                    Text("restore.empty_folder".localized)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .liquidListRow()
                            } else {
                                ForEach(filteredEntries) { entry in
                                    rowView(for: entry)
                                        .liquidListRow(cornerRadius: 14)
                                }
                            }
                        }

                        if let statusMessage {
                            Section {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DesignSystem.Colors.success)
                                        .accessibilityHidden(true)
                                    Text(statusMessage)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(DesignSystem.Colors.success)
                                }
                                .liquidListRow()
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "restore.search_prompt".localized)

                    bottomActionBar
                }
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
                SmartRestoreSheetView(task: task)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Surface & Header Components

    private var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignSystem.Colors.canvasTop,
                    DesignSystem.Colors.canvasBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(theme.primary.opacity(0.09))
                .blur(radius: 60)
                .frame(width: 260, height: 260)
                .offset(x: -120, y: -260)

            Circle()
                .fill(theme.secondary.opacity(0.09))
                .blur(radius: 65)
                .frame(width: 240, height: 240)
                .offset(x: 130, y: -150)
        }
    }

    private var smartRestoreEntryCard: some View {
        Button {
            showingSmartRestoreSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        theme.primary.opacity(0.28),
                                        DesignSystem.Colors.cardSurface
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 22
                                )
                            )
                            .frame(width: 44, height: 44)

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [theme.primary, theme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.6
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: theme.primary.opacity(0.6), radius: 6)

                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(theme.primary)
                            .shadow(color: theme.primary.opacity(0.6), radius: 4)
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("smart_restore.open_button".localized)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("[\(task.backupType.rawValue)]")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(theme.primary)
                        }
                        Text("smart_restore.open_subtitle".localized)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: 8) {
                        TelemetrySignalBars(color: theme.primary, level: isLoading ? 0.35 : 1.0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .frame(width: 28, height: 28)
                            .background(theme.primary.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(16)
            .telemetryCard(theme: theme, cornerRadius: 20, glowOpacity: 0.20)
        }
        .buttonStyle(TelemetryPressButtonStyle())
    }

    private var pathNavigationToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)

                Text(currentPath)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

                Text("[\(filteredEntries.count)]")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.primary)

                TelemetrySignalBars(
                    color: theme.primary,
                    level: isLoading ? 0.25 : (filteredEntries.isEmpty ? 0.10 : 1.0)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.75), lineWidth: 1)
                    )
            )

            if !pathHistory.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        navigateBack()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.caption2.weight(.bold))
                                .accessibilityHidden(true)
                            Text("common.back".localized)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(.white)
                        .background(DesignSystem.Colors.cardSurfaceElevated, in: Capsule())
                        .overlay(Capsule().stroke(DesignSystem.Colors.rimBorderMuted, lineWidth: 0.9))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(theme.primary.opacity(0.14))
                            .frame(width: 34, height: 34)
                        Image(systemName: "folder.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primary)
                            .accessibilityHidden(true)
                    }
                    .accessibilityHidden(true)

                    Text(entry.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                        .foregroundStyle(isSelected ? theme.primary : .secondary.opacity(0.6))
                        .accessibilityHidden(true)

                    fileIconBadge(forExtension: ext)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(Self.byteFormatter.string(fromByteCount: entry.size))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func fileIconBadge(forExtension ext: String) -> some View {
        let isImage = RestoreService.isImageExtension(ext)
        let isVideo = RestoreService.isVideoExtension(ext)
        let symbol = isImage ? "photo.fill" : (isVideo ? "film.fill" : "doc.text.fill")
        let tint: Color = isImage ? DesignSystem.Colors.accentAqua : (isVideo ? theme.secondary : .secondary)

        return ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: 32, height: 32)
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private var downloadProgressBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(restoreService.currentFileName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(restoreService.completedCount)/\(restoreService.totalCount)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Button("common.cancel".localized, role: .cancel) {
                    restoreService.cancelDownload()
                }
                .font(.caption.weight(.semibold))
            }
            ModernProgressBar(progress: restoreService.progress, style: .primary, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .accessibilityHidden(true)
                        Text("restore.download_selected".localized(with: selectedFiles.count))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: isDisabled
                                ? [Color.secondary.opacity(0.18), Color.secondary.opacity(0.18)]
                                : [theme.primary, theme.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .foregroundStyle(isDisabled ? Color.secondary : Color.white)
                    .shadow(color: theme.primary.opacity(isDisabled ? 0 : 0.22), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)

                if !exportedURLs.isEmpty {
                    ShareLink(items: exportedURLs) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityHidden(true)
                            Text("restore.export_files".localized)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .foregroundStyle(theme.primary)
                        .background(theme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.cardSurface.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primary.opacity(0.55),
                            DesignSystem.Colors.rimBorderMuted.opacity(0.6),
                            theme.secondary.opacity(0.45)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
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
