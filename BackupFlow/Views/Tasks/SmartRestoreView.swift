import SwiftUI
import UIKit

// MARK: - Models

enum FileKind: Hashable, CaseIterable {
    case photo
    case video
    case other

    var localizedTitle: String {
        switch self {
        case .photo: return "sr.kind.photo".localized
        case .video: return "sr.kind.video".localized
        case .other: return "sr.kind.other".localized
        }
    }

    static func classify(fileName: String) -> FileKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if RestoreService.isImageExtension(ext) { return .photo }
        if RestoreService.isVideoExtension(ext) { return .video }
        return .other
    }
}

struct MissingFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let size: Int64
    let kind: FileKind
}

struct RestorePlan {
    var missing: [MissingFile]
    var presentCount: Int
    var remoteTotal: Int

    var bytes: Int64 { missing.reduce(0) { $0 + $1.size } }
    func count(_ kind: FileKind) -> Int { missing.filter { $0.kind == kind }.count }
}

// MARK: - Service Contract

@MainActor
protocol SmartRestoreServicing {
    /// Compares target manifest against local source and returns only missing files.
    func scan(progress: @escaping (Double) -> Void) async throws -> RestorePlan
    /// Restores the plan. RestoredPhotoLedgerStore deduplicates previously restored photos.
    func restore(_ plan: RestorePlan, progress: @escaping (Int, String) -> Void) async throws
}

// MARK: - Live Service Adapter

@MainActor
final class LiveSmartRestoreService: SmartRestoreServicing {
    private let snapshot: SmartRestoreTaskSnapshot
    private var lastComputedPlan: SmartRestorePlan?

    init(task: BackupTask) {
        self.snapshot = SmartRestoreTaskSnapshot(task: task)
    }

    func scan(progress: @escaping (Double) -> Void) async throws -> RestorePlan {
        if BackupScheduler.shared.runningTaskIDs.contains(snapshot.id) ||
            SmartRestoreTaskLock.shared.isRestoreActive(for: snapshot.id) {
            throw SmartRestoreError.taskBusyWithBackup
        }

        guard SmartRestoreTaskLock.shared.acquireRestoreLock(for: snapshot.id) else {
            throw SmartRestoreError.taskBusyWithBackup
        }
        defer {
            SmartRestoreTaskLock.shared.releaseRestoreLock(for: snapshot.id)
        }

        progress(0.1)
        let snapshot = self.snapshot
        let computedPlan = try await Task.detached(priority: .userInitiated) {
            try await SmartRestoreCoordinator.performBackgroundScanAndDiff(
                snapshot: snapshot,
                includeArchive: false
            ) { scannedCount, _ in
                Task { @MainActor in
                    let estimated = min(0.9, 0.15 + Double(scannedCount) / 1000.0 * 0.75)
                    progress(estimated)
                }
            }
        }.value

        try Task.checkCancellation()
        progress(1.0)
        self.lastComputedPlan = computedPlan

        let missingFiles = computedPlan.missingItems.map { candidate in
            MissingFile(
                name: candidate.remoteItem.name,
                size: max(candidate.remoteItem.size, 0),
                kind: FileKind.classify(fileName: candidate.remoteItem.name)
            )
        }

        return RestorePlan(
            missing: missingFiles,
            presentCount: computedPlan.unchangedCount + computedPlan.alreadyRestoredCount,
            remoteTotal: computedPlan.totalRemoteFiles
        )
    }

    func restore(_ plan: RestorePlan, progress: @escaping (Int, String) -> Void) async throws {
        guard var computedPlan = lastComputedPlan else { return }
        if BackupScheduler.shared.runningTaskIDs.contains(snapshot.id) ||
            SmartRestoreTaskLock.shared.isRestoreActive(for: snapshot.id) {
            throw SmartRestoreError.taskBusyWithBackup
        }

        guard SmartRestoreTaskLock.shared.acquireRestoreLock(for: snapshot.id) else {
            throw SmartRestoreError.taskBusyWithBackup
        }
        defer {
            SmartRestoreTaskLock.shared.releaseRestoreLock(for: snapshot.id)
        }

        // Ensure all missing items are selected for execution when invoked from SmartRestoreView
        computedPlan.missingItems = computedPlan.missingItems.map { item in
            var copy = item
            copy.isSelected = true
            return copy
        }

        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = false
        }

        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "SmartRestore") {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }

        let snapshot = self.snapshot
        let planToRun = computedPlan
        let client = RemoteRestoreClientFactory.makeClient(for: snapshot)
        _ = try await Task.detached(priority: .userInitiated) {
            try await SmartRestoreEngine.executeRestorePlan(
                snapshot: snapshot,
                plan: planToRun,
                client: client
            ) { completed, _, fileName in
                Task { @MainActor in
                    progress(completed, fileName)
                }
            }
        }.value
    }
}

// MARK: - State Machine

@MainActor @Observable
final class SmartRestoreModel {
    enum Phase {
        case idle
        case scanning(Double)
        case ready(RestorePlan)
        case restoring(done: Int, total: Int, file: String)
        case done(restored: Int, bytes: Int64)
        case failed(String)
    }

    var phase: Phase = .idle
    private let service: SmartRestoreServicing
    private var job: Task<Void, Never>?

    init(service: SmartRestoreServicing) {
        self.service = service
    }

    func scan() {
        job?.cancel()
        phase = .scanning(0)
        job = Task { [weak self] in
            guard let self else { return }
            do {
                let plan = try await service.scan { [weak self] p in
                    self?.phase = .scanning(p)
                }
                phase = .ready(plan)
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func start(_ plan: RestorePlan) {
        job?.cancel()
        let total = plan.missing.count
        phase = .restoring(done: 0, total: total, file: "")
        job = Task { [weak self] in
            guard let self else { return }
            do {
                try await service.restore(plan) { [weak self] done, file in
                    self?.phase = .restoring(done: done, total: total, file: file)
                }
                phase = .done(restored: total, bytes: plan.bytes)
            } catch is CancellationError {
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        job?.cancel()
        job = nil
    }
}

// MARK: - View

struct SmartRestoreView: View {
    let taskName: String
    let targetText: String
    let photoRestoreEnabled: Bool

    @State private var model: SmartRestoreModel
    @State private var doneHapticTrigger = 0
    @State private var failHapticTrigger = 0
    @Environment(\.dismiss) private var dismiss

    init(
        taskName: String,
        targetText: String,
        photoRestoreEnabled: Bool,
        service: SmartRestoreServicing
    ) {
        self.taskName = taskName
        self.targetText = targetText
        self.photoRestoreEnabled = photoRestoreEnabled
        _model = State(initialValue: SmartRestoreModel(service: service))
    }

    init(task: BackupTask) {
        let proto: String = {
            switch task.backupType {
            case .ftp: return "FTP"
            case .sftp: return "SFTP"
            case .webdav: return "WebDAV"
            }
        }()
        let host: String = {
            if task.backupType == .webdav {
                return URL(string: task.serverHost)?.host ?? task.serverHost
            }
            return "\(task.serverHost):\(task.serverPort)"
        }()
        let enabled = task.sourcePath != "PHOTOS_LIBRARY" || SmartRestoreConfiguration.isPhotoSmartRestoreEnabled
        self.init(
            taskName: task.displayName,
            targetText: "\(proto)  \(host)",
            photoRestoreEnabled: enabled,
            service: LiveSmartRestoreService(task: task)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("sr.label.task".localized) {
                        Text(taskName)
                    }
                    LabeledContent("sr.label.target".localized) {
                        Text(targetText).font(BF.mono)
                    }
                } header: {
                    sectionLabel("sr.section.backup".localized)
                }
                .listRowBackground(BF.surface)

                switch model.phase {
                case .idle:
                    idleSections
                case .scanning(let progress):
                    scanningSection(progress)
                case .ready(let plan):
                    readySections(plan)
                case .restoring(let done, let total, let file):
                    restoringSection(done, total, file)
                case .done(let restored, let bytes):
                    doneSection(restored, bytes)
                case .failed(let message):
                    failedSection(message)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BF.bg)
            .navigationTitle("sr.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.details.close".localized) { dismiss() }
                        .disabled(isBusy)
                        .accessibilityIdentifier("sheet.close")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task {
                if case .idle = model.phase {
                    model.scan()
                }
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
        .onChange(of: phaseHapticKey) { _, newKey in
            if newKey == "done" {
                doneHapticTrigger += 1
            } else if newKey == "failed" {
                failHapticTrigger += 1
            }
        }
        .sensoryFeedback(.success, trigger: doneHapticTrigger)
        .sensoryFeedback(.error, trigger: failHapticTrigger)
    }

    private var phaseHapticKey: String {
        switch model.phase {
        case .done: return "done"
        case .failed: return "failed"
        default: return ""
        }
    }

    private var isBusy: Bool {
        switch model.phase {
        case .scanning, .restoring: return true
        default: return false
        }
    }

    // MARK: Phases

    @ViewBuilder
    private var idleSections: some View {
        Section {
            Button("sr.action.start_scan".localized) { model.scan() }
        } footer: {
            explainer
        }
        .listRowBackground(BF.surface)
    }

    private func scanningSection(_ progress: Double) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress)
                    .tint(BF.accent)
                Text("sr.scanning_progress".localized(with: Int(progress * 100)))
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            sectionLabel("sr.section.comparison".localized)
        }
        .listRowBackground(BF.surface)
    }

    @ViewBuilder
    private func readySections(_ plan: RestorePlan) -> some View {
        Section {
            monoRow("sr.label.remote_total".localized, plan.remoteTotal.formatted())
            monoRow("sr.label.present_count".localized, plan.presentCount.formatted())
            LabeledContent("sr.label.missing".localized) {
                Text(plan.missing.count.formatted())
                    .font(BF.mono)
                    .monospacedDigit()
                    .foregroundStyle(plan.missing.isEmpty ? .secondary : BF.accent)
            }
            monoRow(
                "sr.label.restore_size".localized,
                ByteCountFormatter.string(fromByteCount: plan.bytes, countStyle: .file)
            )
        } header: {
            sectionLabel("sr.section.comparison".localized)
        } footer: {
            explainer
        }
        .listRowBackground(BF.surface)

        if !plan.missing.isEmpty {
            Section {
                ForEach(FileKind.allCases, id: \.self) { kind in
                    if plan.count(kind) > 0 {
                        monoRow(kind.localizedTitle, plan.count(kind).formatted())
                    }
                }
                NavigationLink("sr.action.see_files".localized) {
                    MissingFilesList(files: plan.missing)
                }
            } header: {
                sectionLabel("sr.section.missing_files".localized)
            }
            .listRowBackground(BF.surface)
        }

        if !photoRestoreEnabled {
            Section {
                Text("sr.photo_disabled".localized)
                    .font(BF.mono)
                    .foregroundStyle(BF.fail)
            }
            .listRowBackground(BF.surface)
        }
    }

    private func restoringSection(_ done: Int, _ total: Int, _ file: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(BF.accent)
                Text("\(done) / \(total)")
                    .font(BF.mono)
                    .monospacedDigit()
                Text(file.isEmpty ? " " : file)
                    .font(BF.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        } header: {
            sectionLabel("sr.section.restoring".localized)
        }
        .listRowBackground(BF.surface)
    }

    private func doneSection(_ count: Int, _ bytes: Int64) -> some View {
        Section {
            HStack(spacing: 8) {
                Circle()
                    .fill(BF.ok)
                    .frame(width: 8, height: 8)
                Text("sr.done.title".localized)
                    .font(.headline)
            }
            Text("sr.done.summary".localized(with: count, ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))
                .font(BF.mono)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } header: {
            sectionLabel("sr.section.result".localized)
        }
        .listRowBackground(BF.surface)
    }

    private func failedSection(_ message: String) -> some View {
        Section {
            Text(message)
                .font(BF.mono)
                .foregroundStyle(BF.fail)
            Button("sr.action.retry".localized) { model.scan() }
        } header: {
            sectionLabel("alert.error".localized.uppercased())
        }
        .listRowBackground(BF.surface)
    }

    // MARK: Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        switch model.phase {
        case .ready(let plan):
            bar {
                Button {
                    model.start(plan)
                } label: {
                    Text(
                        plan.missing.isEmpty
                            ? "sr.action.no_missing".localized
                            : "sr.action.restore_count".localized(with: plan.missing.count)
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(plan.missing.isEmpty || !photoRestoreEnabled)
            }
        case .scanning, .restoring:
            bar {
                Button("alert.cancel".localized, role: .cancel) { model.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        case .done:
            bar {
                Button { dismiss() } label: {
                    Text("settings.done".localized).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        default:
            EmptyView()
        }
    }

    private func bar<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
    }

    // MARK: Helpers

    private var explainer: some View {
        Text("sr.explainer".localized)
    }

    private func monoRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(BF.mono)
                .monospacedDigit()
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BF.monoSmall)
            .textCase(nil)
    }
}

// MARK: - Missing Files List

struct MissingFilesList: View {
    let files: [MissingFile]

    var body: some View {
        List(files) { file in
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(BF.mono)
                    .lineLimit(1)
                Text("\(file.kind.localizedTitle) · \(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))")
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(BF.bg)
            .listRowSeparatorTint(BF.line)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BF.bg)
        .navigationTitle("sr.missing_files.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview Mock Service

@MainActor
struct MockRestoreService: SmartRestoreServicing {
    func scan(progress: @escaping (Double) -> Void) async throws -> RestorePlan {
        for i in 1...10 {
            try await Task.sleep(for: .milliseconds(120))
            progress(Double(i) / 10)
        }
        let files = (1...48).map {
            MissingFile(
                name: "20260314_0212\(String(format: "%02d", $0))_A1B2C3D4E5F6.HEIC",
                size: 12_800_000,
                kind: $0 % 6 == 0 ? .video : .photo
            )
        }
        return RestorePlan(missing: files, presentCount: 1188, remoteTotal: 1236)
    }

    func restore(_ plan: RestorePlan, progress: @escaping (Int, String) -> Void) async throws {
        for (i, file) in plan.missing.enumerated() {
            try await Task.sleep(for: .milliseconds(80))
            progress(i + 1, file.name)
        }
    }
}

#Preview {
    SmartRestoreView(
        taskName: "Yalnızca Fotoğraflar",
        targetText: "WebDAV  cloud.example.com",
        photoRestoreEnabled: true,
        service: MockRestoreService()
    )
}
