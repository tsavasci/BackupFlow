import SwiftUI

struct SmartRestoreSheetView: View {
    let task: BackupTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
            ZStack {
                ambientBackground

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
                                .accessibilityHidden(true)
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Ambient Surface

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
                .blur(radius: 65)
                .frame(width: 260, height: 260)
                .offset(x: -115, y: -270)

            Circle()
                .fill(theme.secondary.opacity(0.10))
                .blur(radius: 70)
                .frame(width: 240, height: 240)
                .offset(x: 125, y: -140)
        }
    }

    // MARK: - Phase State Cards

    private var scanningView: some View {
        VStack {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [theme.primary.opacity(0.28), DesignSystem.Colors.cardSurface],
                                center: .center,
                                startRadius: 4,
                                endRadius: 36
                            )
                        )
                        .frame(width: 72, height: 72)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [theme.primary, theme.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: theme.primary.opacity(0.65), radius: 8)

                    ProgressView()
                        .controlSize(.large)
                        .tint(accentColor)
                }

                VStack(spacing: 6) {
                    Text("smart_restore.scanning.title".localized)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    if case .scanning(let count, let folder) = coordinator.phase {
                        Text("smart_restore.scanning.progress".localized(with: count, folder))
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func restoringView(completed: Int, total: Int, currentFile: String) -> some View {
        let fraction = total > 0 ? Double(completed) / Double(total) : 0
        let percentText = "\(Int(min(max(fraction, 0), 1) * 100))%"
        return VStack {
            Spacer()
            VStack(spacing: 20) {
                TelemetryRingGauge(
                    title: "restore.title".localized,
                    valueText: percentText,
                    detailLine1: "\(completed) / \(total)",
                    detailLine2: nil,
                    progress: fraction,
                    theme: theme,
                    ringSize: 136,
                    lineWidth: 11
                )

                if !currentFile.isEmpty {
                    Text(currentFile)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if task.backupType == .ftp || task.backupType == .sftp {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.caption2.weight(.semibold))
                            .accessibilityHidden(true)
                        Text("smart_restore.notice.keep_foreground".localized)
                            .font(.caption2)
                    }
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .multilineTextAlignment(.center)
                }

                Button(role: .destructive) {
                    coordinator.cancel()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .accessibilityHidden(true)
                        Text("common.cancel".localized)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .foregroundStyle(DesignSystem.Colors.error)
                    .background(DesignSystem.Colors.error.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(DesignSystem.Colors.error.opacity(0.4), lineWidth: 0.9))
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .frame(maxWidth: 350)
            .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func completedView(restored: Int, skipped: Int, failed: Int, bytesRestored: Int64) -> some View {
        let statusColor = failed == 0 ? DesignSystem.Colors.mintNeon : DesignSystem.Colors.warning
        let formattedSize = Self.byteFormatter.string(fromByteCount: bytesRestored)

        return VStack {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 68, height: 68)
                    Circle()
                        .stroke(statusColor.opacity(0.65), lineWidth: 1.6)
                        .frame(width: 68, height: 68)
                        .shadow(color: statusColor.opacity(0.6), radius: 8)
                    Image(systemName: failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(statusColor)
                        .accessibilityHidden(true)
                }

                Text("smart_restore.completed.title".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("smart_restore.completed.summary".localized(with: restored, formattedSize, skipped, failed))
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    if failed > 0 {
                        Button {
                            coordinator.startScan(for: task)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .accessibilityHidden(true)
                                Text("smart_restore.retry".localized)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .foregroundStyle(.white)
                            .background(DesignSystem.Colors.cardSurfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(DesignSystem.Colors.rimBorderMuted, lineWidth: 0.9)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("backup.ok".localized)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [theme.primary, theme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .foregroundStyle(.white)
                            .shadow(color: theme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 350)
            .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.20)
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func failedView(message: String, needsFolderReauth: Bool) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.error.opacity(0.16))
                        .frame(width: 64, height: 64)
                    Circle()
                        .stroke(DesignSystem.Colors.error.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.error)
                        .accessibilityHidden(true)
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    if needsFolderReauth {
                        Button {
                            showingFolderPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.gearshape")
                                    .accessibilityHidden(true)
                                Text("smart_restore.reauthorize_folder".localized)
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [theme.primary, theme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        coordinator.startScan(for: task)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .accessibilityHidden(true)
                            Text("smart_restore.retry".localized)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(DesignSystem.Colors.cardSurfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DesignSystem.Colors.rimBorderMuted, lineWidth: 0.9)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(26)
            .frame(maxWidth: 350)
            .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.18)
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContentView: some View {
        if let plan = coordinator.plan {
            VStack(spacing: 0) {
                List {
                    diffOverviewSection(plan: plan)
                    noticesSection(plan: plan)
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
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "restore.search_prompt".localized)

                bottomConfirmBar(plan: plan)
            }
        }
    }

    private func diffOverviewSection(plan: SmartRestorePlan) -> some View {
        let intactCount = plan.unchangedCount + plan.alreadyRestoredCount
        let missingCount = plan.missingItems.count
        let total = max(plan.totalRemoteFiles, 1)

        let intactRatio = Double(intactCount) / Double(total)
        let intactPercent = Int(min(max(intactRatio, 0), 1) * 100)

        return Section {
            VStack(alignment: .leading, spacing: 14) {
                // Server path header pill
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.primary)
                        .accessibilityHidden(true)
                    Text(plan.remoteRootPath)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Text("[\(plan.totalRemoteFiles)]")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(theme.primary)
                    Button {
                        coordinator.startScan(for: task)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.primary)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                }

                // Side-by-side Bento: CORE LOAD style Ring Gauge + Active Modules breakdown
                let visibleMissing = filteredCandidates(from: plan.missingItems)
                let allVisibleMissingSelected = !visibleMissing.isEmpty && visibleMissing.allSatisfy(\.isSelected)

                HStack(spacing: 12) {
                    Button {
                        if !visibleMissing.isEmpty {
                            setSelectionForVisibleMissing(selected: !allVisibleMissingSelected)
                        }
                    } label: {
                        TelemetryRingGauge(
                            title: "smart_restore.stat.intact".localized,
                            valueText: "\(intactPercent)%",
                            detailLine1: "\(intactCount)/\(plan.totalRemoteFiles)",
                            detailLine2: nil,
                            progress: intactRatio,
                            theme: theme,
                            ringSize: 112,
                            lineWidth: 10
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        telemetryDiffRow(
                            title: "smart_restore.stat.intact".localized,
                            count: intactCount,
                            total: total,
                            color: DesignSystem.Colors.mintNeon,
                            action: nil
                        )

                        Divider()
                            .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.45))

                        telemetryDiffRow(
                            title: "smart_restore.stat.missing".localized,
                            count: missingCount,
                            total: total,
                            color: theme.primary,
                            action: visibleMissing.isEmpty ? nil : {
                                setSelectionForVisibleMissing(selected: !allVisibleMissingSelected)
                            }
                        )

                        if !plan.ambiguousItems.isEmpty {
                            Divider()
                                .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.45))

                            telemetryDiffRow(
                                title: "smart_restore.stat.ambiguous".localized,
                                count: plan.ambiguousItems.count,
                                total: total,
                                color: DesignSystem.Colors.warning,
                                action: {
                                    withAnimation(reduceMotion ? nil : DesignSystem.Animation.swift) {
                                        isAmbiguousExpanded.toggle()
                                    }
                                }
                            )
                        }

                        if !plan.conflictItems.isEmpty {
                            Divider()
                                .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.45))

                            telemetryDiffRow(
                                title: "smart_restore.stat.conflicts".localized,
                                count: plan.conflictItems.count,
                                total: total,
                                color: DesignSystem.Colors.warning,
                                action: {
                                    withAnimation(reduceMotion ? nil : DesignSystem.Animation.swift) {
                                        isConflictsExpanded.toggle()
                                    }
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Compact date filter bar when missing items exist
                if !plan.missingItems.isEmpty {
                    Divider()
                        .overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.5))

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("smart_restore.filter.date_range".localized, systemImage: "calendar")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DesignSystem.Colors.slateMuted)
                            Spacer()
                            Toggle("", isOn: $isDateFilterEnabled.animation(reduceMotion ? nil : DesignSystem.Animation.swift))
                                .labelsHidden()
                                .tint(theme.primary)
                                .scaleEffect(0.85)
                        }

                        if isDateFilterEnabled {
                            HStack(spacing: 10) {
                                DatePicker(
                                    "smart_restore.filter.from".localized,
                                    selection: $filterStartDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .controlSize(.small)

                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                                    .accessibilityHidden(true)

                                DatePicker(
                                    "smart_restore.filter.to".localized,
                                    selection: $filterEndDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .controlSize(.small)

                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(16)
            .telemetryCard(theme: theme, cornerRadius: 22, glowOpacity: 0.20)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func telemetryDiffRow(
        title: String,
        count: Int,
        total: Int,
        color: Color,
        action: (() -> Void)?
    ) -> some View {
        let level = count == 0 ? 0.0 : max(0.22, Double(count) / Double(max(total, 1)))
        let rowContent = HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)

            Text("[\(count)]")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.45), radius: 4)
                .fixedSize()

            Spacer(minLength: 2)

            TelemetrySignalBars(color: color, level: level)
        }
        .contentShape(Rectangle())

        return Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    @ViewBuilder
    private func noticesSection(plan: SmartRestorePlan) -> some View {
        if plan.autoSelectionDisabledByThreshold || plan.isPhotoLibrarySource || plan.caseCollisionCount > 0 {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if plan.autoSelectionDisabledByThreshold {
                        calloutRow(
                            icon: "hand.raised.fill",
                            text: "smart_restore.notice.threshold_exceeded".localized(with: SmartRestoreConfiguration.autoSelectMissingThreshold),
                            tint: DesignSystem.Colors.warning
                        )
                    }

                    if plan.isPhotoLibrarySource {
                        calloutRow(
                            icon: "trash.slash",
                            text: "smart_restore.notice.recently_deleted".localized,
                            tint: theme.secondary
                        )
                    }

                    if plan.caseCollisionCount > 0 {
                        calloutRow(
                            icon: "textformat.abc",
                            text: "smart_restore.notice.case_collision".localized(with: plan.caseCollisionCount),
                            tint: DesignSystem.Colors.warning
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func calloutRow(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            Text(text)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.slateMuted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.36), lineWidth: 0.9)
                )
        )
    }

    private func missingItemsSection(plan: SmartRestorePlan) -> some View {
        let visible = filteredCandidates(from: plan.missingItems)
        return Section {
            if visible.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DesignSystem.Colors.success)
                        .accessibilityHidden(true)
                    Text("smart_restore.missing.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .liquidListRow(cornerRadius: 14)
            } else {
                ForEach(visible) { candidate in
                    missingRow(candidate: candidate)
                        .liquidListRow(cornerRadius: 14)
                }
            }
        } header: {
            HStack {
                Text("\("smart_restore.section.missing".localized) (\(visible.count))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()

                Spacer()

                if !visible.isEmpty {
                    HStack(spacing: 6) {
                        Button {
                            setSelectionForVisibleMissing(selected: true)
                        } label: {
                            Text("smart_restore.select_visible".localized)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(theme.primary)
                                .background(theme.primary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            setSelectionForVisibleMissing(selected: false)
                        } label: {
                            Text("smart_restore.deselect_visible".localized)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(.secondary)
                                .background(Color.primary.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .textCase(nil)
                }
            }
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
                        .padding(.vertical, 2)

                    ForEach(filteredCandidates(from: plan.ambiguousItems)) { candidate in
                        ambiguousRow(candidate: candidate)
                    }
                },
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .accessibilityHidden(true)
                        Text("\("smart_restore.section.ambiguous".localized) (\(plan.ambiguousItems.count))")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                }
            )
            .liquidListRow(cornerRadius: 14)
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
                            HStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.3")
                                    .accessibilityHidden(true)
                                Text("smart_restore.conflict.bulk_menu".localized)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(theme.primary.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, 4)

                    ForEach(filteredCandidates(from: plan.conflictItems)) { candidate in
                        conflictRow(candidate: candidate)
                    }
                },
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .accessibilityHidden(true)
                        Text("\("smart_restore.section.conflicts".localized) (\(plan.conflictItems.count))")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                }
            )
            .liquidListRow(cornerRadius: 14)
        }
    }

    private func ignoredItemsSection(plan: SmartRestorePlan) -> some View {
        Section {
            DisclosureGroup(
                isExpanded: $isIgnoredExpanded,
                content: {
                    ForEach(plan.ignoredItems) { candidate in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.remoteItem.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if candidate.remoteItem.relativePath != candidate.remoteItem.name {
                                    Text(candidate.remoteItem.relativePath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button {
                                coordinator.unignoreCandidate(candidate)
                            } label: {
                                Text("smart_restore.unignore".localized)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .foregroundStyle(theme.primary)
                                    .background(theme.primary.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                },
                label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("\("smart_restore.section.ignored".localized) (\(plan.ignoredItems.count))")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                }
            )
            .liquidListRow(cornerRadius: 14)
        }
    }

    // MARK: - Row Builders

    private func missingRow(candidate: SmartRestoreCandidate) -> some View {
        let ext = (candidate.remoteItem.name as NSString).pathExtension
        return Button {
            toggleMissingSelection(id: candidate.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(candidate.isSelected ? accentColor : .secondary.opacity(0.55))
                    .font(.title3)
                    .accessibilityHidden(true)

                fileTypeBadge(forExtension: ext)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.remoteItem.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    subtitleText(for: candidate)
                }

                Spacer(minLength: 4)

                Text(Self.byteFormatter.string(fromByteCount: candidate.remoteItem.size))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05), in: Capsule())
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                coordinator.ignoreCandidate(candidate)
            } label: {
                Label("smart_restore.ignore".localized, systemImage: "eye.slash")
            }
            .tint(.gray)
        }
    }

    @ViewBuilder
    private func subtitleText(for candidate: SmartRestoreCandidate) -> some View {
        if candidate.remoteItem.relativePath != candidate.remoteItem.name {
            Text(candidate.remoteItem.relativePath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        } else if let date = candidate.parsedPhotoDate ?? candidate.remoteItem.modifiedDate {
            Text(Self.shortDateFormatter.string(from: date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func fileTypeBadge(forExtension ext: String) -> some View {
        let isImage = RestoreService.isImageExtension(ext)
        let isVideo = RestoreService.isVideoExtension(ext)
        let symbol = isImage ? "photo.fill" : (isVideo ? "film.fill" : "doc.text.fill")
        let tint: Color = isImage ? DesignSystem.Colors.accentAqua : (isVideo ? theme.secondary : theme.primary)

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

    private func ambiguousRow(candidate: SmartRestoreCandidate) -> some View {
        Button {
            toggleAmbiguousSelection(id: candidate.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(candidate.isSelected ? DesignSystem.Colors.warning : .secondary.opacity(0.55))
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.remoteItem.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(Self.byteFormatter.string(fromByteCount: candidate.remoteItem.size))
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
                    .font(.subheadline.weight(.medium))
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
                .tint(theme.primary)
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
        .padding(.vertical, 2)
    }

    private func bottomConfirmBar(plan: SmartRestorePlan) -> some View {
        let selected = plan.selectedItemsToRestore
        let isDisabled = selected.isEmpty
        let totalSizeStr = Self.byteFormatter.string(fromByteCount: plan.totalBytesToDownload)

        return VStack(spacing: 8) {
            Text("smart_restore.confirm.safe_note".localized(with: selected.count, totalSizeStr))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.center)

            Button {
                coordinator.executeSelectedRestore(for: task)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc.fill")
                        .accessibilityHidden(true)
                    Text("smart_restore.confirm.button".localized(with: selected.count, totalSizeStr))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: isDisabled
                            ? [Color.secondary.opacity(0.18), Color.secondary.opacity(0.18)]
                            : [theme.primary, theme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(isDisabled ? Color.secondary : Color.white)
                .shadow(color: theme.primary.opacity(isDisabled ? 0 : 0.24), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
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
