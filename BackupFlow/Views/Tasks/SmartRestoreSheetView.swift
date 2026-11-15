import SwiftUI

struct SmartRestoreSheetView: View {
    let task: BackupTask

    @Environment(\.dismiss) private var dismiss
    @State private var coordinator = SmartRestoreCoordinator()
    @State private var searchText: String = ""
    @State private var isDateFilterEnabled: Bool = false
    @State private var filterStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var filterEndDate: Date = Date()
    @State private var isConflictsExpanded: Bool = false
    @State private var isAmbiguousExpanded: Bool = false
    @State private var isIgnoredExpanded: Bool = false
    @State private var showingFolderPicker: Bool = false
    @State private var reauthorizedFolderURL: URL?

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private var theme: DashboardTheme {
        DashboardTheme.theme(for: task.backupType)
    }

    private var accentColor: Color {
        theme.primary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch coordinator.phase {
                case .idle, .scanning:
                    scanningView
                case .preview:
                    previewContentView
                case .restoring(let completed, let total, let currentFile):
                    restoringView(completed: completed, total: total, currentFile: currentFile)
                case .completed(let restored, let skipped, let failed, let bytesRestored):
                    completedView(restored: restored, skipped: skipped, failed: failed, bytesRestored: bytesRestored)
                case .failed(let message, let needsFolderReauth):
                    failedView(message: message, needsFolderReauth: needsFolderReauth)
                }
            }
            .navigationTitle("smart_restore.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.details.close".localized) {
                        coordinator.cancel()
                        dismiss()
                    }
                }
                if case .preview = coordinator.phase {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            coordinator.startScan(for: task)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFolderPicker) {
                DocumentPicker(
                    url: $reauthorizedFolderURL,
                    onDismiss: {
                        showingFolderPicker = false
                        if let newURL = reauthorizedFolderURL {
                            task.sourcePath = newURL.path
                            coordinator.startScan(for: task)
                        }
                    }
                )
                .ignoresSafeArea()
            }
            .task {
                if case .idle = coordinator.phase {
                    coordinator.startScan(for: task)
                }
            }
        }
    }

    // MARK: - Phase Views

    private var scanningView: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(accentColor)

            Text("smart_restore.scanning.title".localized)
                .font(.headline)

            if case .scanning(let count, let folder) = coordinator.phase {
                Text("smart_restore.scanning.progress".localized(with: count, folder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func restoringView(completed: Int, total: Int, currentFile: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            let fraction = total > 0 ? Double(completed) / Double(total) : 0
            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(accentColor)
                .padding(.horizontal, 32)

            Text("\(completed) / \(total)")
                .font(.title3.weight(.bold))
                .monospacedDigit()

            if !currentFile.isEmpty {
                Text(currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }

            if task.backupType == .ftp || task.backupType == .sftp {
                Label("smart_restore.notice.keep_foreground".localized, systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }

            Button(role: .destructive) {
                coordinator.cancel()
            } label: {
                Label("common.cancel".localized, systemImage: "xmark.circle.fill")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func completedView(restored: Int, skipped: Int, failed: Int, bytesRestored: Int64) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(failed == 0 ? DesignSystem.Colors.success : DesignSystem.Colors.warning)

            Text("smart_restore.completed.title".localized)
                .font(.title3.weight(.bold))

            let formattedSize = Self.byteFormatter.string(fromByteCount: bytesRestored)
            Text("smart_restore.completed.summary".localized(with: restored, formattedSize, skipped, failed))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                if failed > 0 {
                    Button {
                        coordinator.startScan(for: task)
                    } label: {
                        Label("smart_restore.retry".localized, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    dismiss()
                } label: {
                    Text("backup.ok".localized)
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(message: String, needsFolderReauth: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 46))
                .foregroundStyle(DesignSystem.Colors.error)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                if needsFolderReauth {
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("smart_restore.reauthorize_folder".localized, systemImage: "folder.badge.gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                }

                Button {
                    coordinator.startScan(for: task)
                } label: {
                    Label("smart_restore.retry".localized, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContentView: some View {
        if let plan = coordinator.plan {
            VStack(spacing: 0) {
                List {
                    summarySection(plan: plan)
                    noticesSection(plan: plan)
                    dateFilterSection(plan: plan)
                    missingItemsSection(plan: plan)

                    if !plan.ambiguousItems.isEmpty {
                        ambiguousItemsSection(plan: plan)
                    }
                    if !plan.conflictItems.isEmpty {
                        conflictItemsSection(plan: plan)
                    }
                    if !plan.ignoredItems.isEmpty {
                        ignoredItemsSection(plan: plan)
                    }
                }
                .searchable(text: $searchText, prompt: "restore.search_prompt".localized)

                bottomConfirmBar(plan: plan)
            }
        }
    }

    private func summarySection(plan: SmartRestorePlan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    summaryPill(
                        title: "smart_restore.stat.total".localized,
                        count: plan.totalRemoteFiles,
                        color: .secondary
                    )
                    summaryPill(
                        title: "smart_restore.stat.intact".localized,
                        count: plan.unchangedCount + plan.alreadyRestoredCount,
                        color: DesignSystem.Colors.success
                    )
                    summaryPill(
                        title: "smart_restore.stat.missing".localized,
                        count: plan.missingItems.count,
                        color: accentColor
                    )
                }

                if !plan.ambiguousItems.isEmpty || !plan.conflictItems.isEmpty {
                    HStack(spacing: 10) {
                        if !plan.ambiguousItems.isEmpty {
                            summaryPill(
                                title: "smart_restore.stat.ambiguous".localized,
                                count: plan.ambiguousItems.count,
                                color: DesignSystem.Colors.warning
                            )
                        }
                        if !plan.conflictItems.isEmpty {
                            summaryPill(
                                title: "smart_restore.stat.conflicts".localized,
                                count: plan.conflictItems.count,
                                color: DesignSystem.Colors.warning
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(plan.remoteRootPath)
                .textSelection(.enabled)
        }
    }

    private func summaryPill(title: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func noticesSection(plan: SmartRestorePlan) -> some View {
        if plan.autoSelectionDisabledByThreshold || plan.isPhotoLibrarySource || plan.caseCollisionCount > 0 {
            Section {
                if plan.autoSelectionDisabledByThreshold {
                    Label(
                        "smart_restore.notice.threshold_exceeded".localized(with: SmartRestoreConfiguration.autoSelectMissingThreshold),
                        systemImage: "hand.raised.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.warning)
                }

                if plan.isPhotoLibrarySource {
                    Label("smart_restore.notice.recently_deleted".localized, systemImage: "trash.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if plan.caseCollisionCount > 0 {
                    Label(
                        "smart_restore.notice.case_collision".localized(with: plan.caseCollisionCount),
                        systemImage: "textformat.abc"
                    )
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.warning)
                }
            }
        }
    }

    @ViewBuilder
    private func dateFilterSection(plan: SmartRestorePlan) -> some View {
        if !plan.missingItems.isEmpty {
            Section {
                Toggle("smart_restore.filter.date_range".localized, isOn: $isDateFilterEnabled)
                if isDateFilterEnabled {
                    DatePicker(
                        "smart_restore.filter.from".localized,
                        selection: $filterStartDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "smart_restore.filter.to".localized,
                        selection: $filterEndDate,
                        displayedComponents: .date
                    )
                }

                HStack(spacing: 10) {
                    Button("smart_restore.select_visible".localized) {
                        setSelectionForVisibleMissing(selected: true)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    Button("smart_restore.deselect_visible".localized) {
                        setSelectionForVisibleMissing(selected: false)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }

    private func missingItemsSection(plan: SmartRestorePlan) -> some View {
        let visible = filteredCandidates(from: plan.missingItems)
        return Section {
            if visible.isEmpty {
                Text("smart_restore.missing.empty".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visible) { candidate in
                    missingRow(candidate: candidate)
                }
            }
        } header: {
            Text("\("smart_restore.section.missing".localized) (\(visible.count))")
                .monospacedDigit()
        }
    }

    private func ambiguousItemsSection(plan: SmartRestorePlan) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $isAmbiguousExpanded,
                content: {
                    Text("smart_restore.ambiguous.hint".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(filteredCandidates(from: plan.ambiguousItems)) { candidate in
                        ambiguousRow(candidate: candidate)
                    }
                },
                label: {
                    Label(
                        "\("smart_restore.section.ambiguous".localized) (\(plan.ambiguousItems.count))",
                        systemImage: "questionmark.circle"
                    )
                    .monospacedDigit()
                }
            )
        }
    }

    private func conflictItemsSection(plan: SmartRestorePlan) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $isConflictsExpanded,
                content: {
                    HStack {
                        Text("smart_restore.conflict.apply_all".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            ForEach(RestoreConflictResolution.allCases) { res in
                                Button(resolutionTitle(res)) {
                                    applyConflictResolutionToAll(res)
                                }
                            }
                        } label: {
                            Label("smart_restore.conflict.bulk_menu".localized, systemImage: "slider.horizontal.3")
                                .font(.caption)
                        }
                    }

                    ForEach(filteredCandidates(from: plan.conflictItems)) { candidate in
                        conflictRow(candidate: candidate)
                    }
                },
                label: {
                    Label(
                        "\("smart_restore.section.conflicts".localized) (\(plan.conflictItems.count))",
                        systemImage: "exclamationmark.triangle"
                    )
                    .monospacedDigit()
                }
            )
        }
    }

    private func ignoredItemsSection(plan: SmartRestorePlan) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $isIgnoredExpanded,
                content: {
                    ForEach(plan.ignoredItems) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.remoteItem.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(candidate.remoteItem.relativePath)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("smart_restore.unignore".localized) {
                                coordinator.unignoreCandidate(candidate)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                },
                label: {
                    Label(
                        "\("smart_restore.section.ignored".localized) (\(plan.ignoredItems.count))",
                        systemImage: "eye.slash"
                    )
                    .monospacedDigit()
                }
            )
        }
    }

    // MARK: - Row Builders

    private func missingRow(candidate: SmartRestoreCandidate) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleMissingSelection(id: candidate.id)
            } label: {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(candidate.isSelected ? accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.remoteItem.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(candidate.remoteItem.relativePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(Self.byteFormatter.string(fromByteCount: candidate.remoteItem.size))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .swipeActions(edge: .trailing) {
            Button {
                coordinator.ignoreCandidate(candidate)
            } label: {
                Label("smart_restore.ignore".localized, systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }

    private func ambiguousRow(candidate: SmartRestoreCandidate) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleAmbiguousSelection(id: candidate.id)
            } label: {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(candidate.isSelected ? DesignSystem.Colors.warning : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.remoteItem.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(Self.byteFormatter.string(fromByteCount: candidate.remoteItem.size))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .swipeActions(edge: .trailing) {
            Button {
                coordinator.ignoreCandidate(candidate)
            } label: {
                Label("smart_restore.ignore".localized, systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }

    private func conflictRow(candidate: SmartRestoreCandidate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(candidate.remoteItem.relativePath)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Picker("", selection: Binding(
                    get: { candidate.conflictResolution },
                    set: { updateConflictResolution(id: candidate.id, resolution: $0) }
                )) {
                    ForEach(RestoreConflictResolution.allCases) { res in
                        Text(resolutionTitle(res)).tag(res)
                    }
                }
                .pickerStyle(.menu)
            }

            if case .conflict(let localSize, _) = candidate.state {
                let remoteStr = Self.byteFormatter.string(fromByteCount: candidate.remoteItem.size)
                let localStr = Self.byteFormatter.string(fromByteCount: localSize)
                Text("smart_restore.conflict.sizes".localized(with: remoteStr, localStr))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func bottomConfirmBar(plan: SmartRestorePlan) -> some View {
        let selected = plan.selectedItemsToRestore
        let totalSizeStr = Self.byteFormatter.string(fromByteCount: plan.totalBytesToDownload)

        return VStack(spacing: 8) {
            Divider()
            VStack(spacing: 6) {
                Text("smart_restore.confirm.safe_note".localized(with: selected.count, totalSizeStr))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)

                Button {
                    coordinator.executeSelectedRestore(for: task)
                } label: {
                    Label(
                        "smart_restore.confirm.button".localized(with: selected.count, totalSizeStr),
                        systemImage: "arrow.down.doc.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers & Mutations

    private func resolutionTitle(_ resolution: RestoreConflictResolution) -> String {
        switch resolution {
        case .skip:
            return "smart_restore.conflict.skip".localized
        case .keepBoth:
            return "smart_restore.conflict.keep_both".localized
        case .overwrite:
            return "smart_restore.conflict.overwrite".localized
        }
    }

    private func filteredCandidates(from items: [SmartRestoreCandidate]) -> [SmartRestoreCandidate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let startOfDay = Calendar.current.startOfDay(for: filterStartDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: filterEndDate)) ?? filterEndDate

        return items.filter { item in
            if !trimmed.isEmpty &&
                !item.remoteItem.relativePath.localizedCaseInsensitiveContains(trimmed) {
                return false
            }
            if isDateFilterEnabled {
                let itemDate = item.parsedPhotoDate ?? item.remoteItem.modifiedDate
                guard let itemDate else { return true }
                return itemDate >= startOfDay && itemDate < endOfDay
            }
            return true
        }
    }

    private func setSelectionForVisibleMissing(selected: Bool) {
        guard var currentPlan = coordinator.plan else { return }
        let visibleIDs = Set(filteredCandidates(from: currentPlan.missingItems).map(\.id))
        for idx in currentPlan.missingItems.indices where visibleIDs.contains(currentPlan.missingItems[idx].id) {
            currentPlan.missingItems[idx].isSelected = selected
        }
        coordinator.plan = currentPlan
    }

    private func toggleMissingSelection(id: String) {
        guard var currentPlan = coordinator.plan,
              let idx = currentPlan.missingItems.firstIndex(where: { $0.id == id }) else { return }
        currentPlan.missingItems[idx].isSelected.toggle()
        coordinator.plan = currentPlan
    }

    private func toggleAmbiguousSelection(id: String) {
        guard var currentPlan = coordinator.plan,
              let idx = currentPlan.ambiguousItems.firstIndex(where: { $0.id == id }) else { return }
        currentPlan.ambiguousItems[idx].isSelected.toggle()
        coordinator.plan = currentPlan
    }

    private func updateConflictResolution(id: String, resolution: RestoreConflictResolution) {
        guard var currentPlan = coordinator.plan,
              let idx = currentPlan.conflictItems.firstIndex(where: { $0.id == id }) else { return }
        currentPlan.conflictItems[idx].conflictResolution = resolution
        currentPlan.conflictItems[idx].isSelected = (resolution != .skip)
        coordinator.plan = currentPlan
    }

    private func applyConflictResolutionToAll(_ resolution: RestoreConflictResolution) {
        guard var currentPlan = coordinator.plan else { return }
        for idx in currentPlan.conflictItems.indices {
            currentPlan.conflictItems[idx].conflictResolution = resolution
            currentPlan.conflictItems[idx].isSelected = (resolution != .skip)
        }
        coordinator.plan = currentPlan
    }
}
