import Charts
import SwiftUI

// MARK: - Design Tokens

enum BF {
    static let bg      = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let surface = Color(red: 0.094, green: 0.106, blue: 0.125)
    static let line    = Color.white.opacity(0.08)
    static let ok      = Color(red: 0.30, green: 0.78, blue: 0.50)
    static let fail    = Color(red: 0.93, green: 0.36, blue: 0.33)
    static let accent  = Color(red: 0.42, green: 0.62, blue: 1.00)
    static let radius: CGFloat = 8

    static let protoSFTP   = Color(red: 0.18, green: 0.58, blue: 0.36)
    static let protoWebDAV = Color(red: 0.48, green: 0.46, blue: 0.96)
    static let protoFTP    = Color(red: 0.96, green: 0.58, blue: 0.22)

    static func protocolColor(_ proto: String) -> Color {
        switch proto.uppercased() {
        case "SFTP": return protoSFTP
        case "WEBDAV": return protoWebDAV
        case "FTP": return protoFTP
        default: return .secondary
        }
    }

    static let mono      = Font.system(.footnote, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
}

// MARK: - Presentation Models

enum RunState: Equatable {
    case ok
    case failed
    case running(progress: Double, file: String, speed: String, eta: String)
    case idle
}

enum HomeStatusKind {
    case ok
    case running
    case failed
    case idle

    var color: Color {
        switch self {
        case .ok: return BF.ok
        case .running: return BF.accent
        case .failed: return BF.fail
        case .idle: return .gray
        }
    }
}

struct TaskItem: Identifiable {
    let id: UUID
    let name: String
    let proto: String
    let host: String
    let lastRun: String
    let summary: String
    let state: RunState
    var isPaused: Bool = false
    var isScheduled: Bool = true

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
}

struct DayTotal: Identifiable {
    var id: Date { day }
    let day: Date
    let gb: Double
}

// MARK: - Home View

struct BackupHomeView: View {
    @Environment(Router.self) private var router: Router?

    let tasks: [TaskItem]
    let days: [DayTotal]
    let statusKind: HomeStatusKind
    let statusTitle: String
    let statusSummary: String

    var onOpenSettings: () -> Void = {}
    var onAddTask: () -> Void = {}
    let onSelectTask: (UUID) -> Void
    let onRunTask: (UUID) -> Void
    let onStopTask: (UUID) -> Void
    var onTogglePause: (UUID) -> Void = { _ in }
    let onDeleteTask: (UUID) -> Void

    @State private var pauseHapticTrigger = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statusHeader
                }
                .listRowBackground(BF.bg)
                .listRowSeparator(.hidden)

                Section {
                    transferChart
                } header: {
                    sectionLabel("home.chart.header".localized)
                }
                .listRowBackground(BF.bg)
                .listRowSeparator(.hidden)

                Section {
                    if tasks.isEmpty {
                        emptyTasksRow
                    } else {
                        ForEach(tasks) { task in
                            Button {
                                onSelectTask(task.id)
                            } label: {
                                TaskRow(task: task)
                                    .foregroundStyle(.primary)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("dashboard.server_details")
                            .listRowBackground(BF.bg)
                            .listRowSeparatorTint(BF.line)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if task.isRunning {
                                    Button("home.action.stop".localized, role: .destructive) {
                                        onStopTask(task.id)
                                    }
                                    .tint(BF.fail)
                                } else {
                                    Button("home.action.run".localized) {
                                        onRunTask(task.id)
                                    }
                                    .tint(BF.accent)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("tasks.delete".localized, role: .destructive) {
                                    onDeleteTask(task.id)
                                }
                                Button("home.action.edit".localized) {
                                    onSelectTask(task.id)
                                }
                                .tint(.gray)
                            }
                            .contextMenu {
                                if task.isRunning {
                                    Button(role: .destructive) {
                                        onStopTask(task.id)
                                    } label: {
                                        Label("home.action.stop".localized, systemImage: "stop.fill")
                                    }
                                } else {
                                    Button {
                                        onRunTask(task.id)
                                    } label: {
                                        Label("backup.notification.action.start".localized, systemImage: "play.fill")
                                    }
                                }

                                if task.isScheduled {
                                    Button {
                                        pauseHapticTrigger += 1
                                        onTogglePause(task.id)
                                    } label: {
                                        Label(
                                            task.isPaused ? "task.resume.button".localized : "task.pause.button".localized,
                                            systemImage: task.isPaused ? "play.circle" : "pause.circle"
                                        )
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    sectionLabel("home.tasks.header".localized)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BF.bg)
            .navigationTitle("home.title".localized)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let router {
                            router.showSettings = true
                        } else {
                            onOpenSettings()
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("settings.title".localized)
                    .accessibilityIdentifier("dashboard.settings")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let router {
                            router.showNew = true
                        } else {
                            onAddTask()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("home.tasks.add_first".localized)
                    .accessibilityIdentifier("dashboard.add")
                }
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .light), trigger: pauseHapticTrigger)
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusKind.color)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.headline)
            }
            Text(statusSummary)
                .font(BF.mono)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var transferChart: some View {
        Chart(days) { d in
            BarMark(
                x: .value("home.chart.day".localized, d.day, unit: .day),
                y: .value("GB", d.gb)
            )
            .foregroundStyle(BF.accent)
            .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(BF.monoSmall)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(BF.line)
                AxisValueLabel().font(BF.monoSmall)
            }
        }
        .frame(height: 140)
        .padding(12)
        .background(BF.surface, in: RoundedRectangle(cornerRadius: BF.radius))
        .overlay(RoundedRectangle(cornerRadius: BF.radius).stroke(BF.line))
    }

    private var emptyTasksRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("home.tasks.empty".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("home.tasks.add_first".localized, action: onAddTask)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BF.accent)
        }
        .padding(.vertical, 12)
        .listRowBackground(BF.bg)
        .listRowSeparator(.hidden)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BF.monoSmall)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskItem

    @State private var pauseHapticTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                statusDot
                Text(task.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(task.lastRun)
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Text(task.proto)
                    .foregroundStyle(BF.protocolColor(task.proto))
                Text(task.host)
                    .foregroundStyle(.secondary)
            }
            .font(BF.mono)
            .lineLimit(1)

            switch task.state {
            case .running(let progress, let file, let speed, let eta):
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(BF.accent)
                    Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                        .font(BF.monoSmall)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text("\(file)  \(speed)  ~\(eta)")
                    .font(BF.monoSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .failed:
                Text("home.task.last_run_failed".localized)
                    .font(BF.monoSmall)
                    .foregroundStyle(BF.fail)
            case .ok, .idle:
                if task.isPaused {
                    Text(task.summary == "—" ? "task.status.paused".localized : "\("task.status.paused".localized) · \(task.summary)")
                        .font(BF.monoSmall)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(task.summary)
                        .font(BF.monoSmall)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusAccessibilityText)
    }

    private var statusAccessibilityText: String {
        if case .running = task.state { return "backup.status.uploading".localized }
        if task.isPaused { return "task.status.paused".localized }
        switch task.state {
        case .ok: return "backup.status.completed".localized
        case .failed: return "backup.status.failed".localized
        case .running: return "backup.status.uploading".localized
        case .idle: return "backup.status.idle".localized
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        let color: Color = {
            if case .running = task.state { return BF.accent }
            if task.isPaused { return .gray }
            switch task.state {
            case .ok: return BF.ok
            case .failed: return BF.fail
            case .running: return BF.accent
            case .idle: return .gray
            }
        }()
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

#Preview {
    let cal = Calendar.current
    let days = (0..<14).map { i in
        DayTotal(
            day: cal.date(byAdding: .day, value: -13 + i, to: .now)!,
            gb: [0, 0.44, 0.61, 0, 0, 0.21, 0, 0, 0.38, 0, 0, 0.44, 0.61, 0][i]
        )
    }
    return BackupHomeView(
        tasks: [
            TaskItem(
                id: UUID(),
                name: "Yalnızca Fotoğraflar",
                proto: "WebDAV",
                host: "cloud.example.com",
                lastRun: "2 sa önce",
                summary: "1.236 dosya · 612 MB · 3,6 dk",
                state: .ok
            ),
            TaskItem(
                id: UUID(),
                name: "Fotoğraflar ve Videolar",
                proto: "SFTP",
                host: "192.168.1.20:22",
                lastRun: "dün",
                summary: "214 dosya · 2,15 GB · 11 dk",
                state: .running(
                    progress: 0.42,
                    file: "IMG_4821.HEIC",
                    speed: "8,2 MB/s",
                    eta: "2 dk"
                )
            ),
            TaskItem(
                id: UUID(),
                name: "Yalnızca Videolar",
                proto: "FTP",
                host: "192.168.1.20:21",
                lastRun: "6 gün önce",
                summary: "—",
                state: .idle
            )
        ],
        days: days,
        statusKind: .ok,
        statusTitle: "Her şey güncel",
        statusSummary: "son 02:04  ·  sonraki 03:22  ·  0 hata",
        onSelectTask: { _ in },
        onRunTask: { _ in },
        onStopTask: { _ in },
        onDeleteTask: { _ in }
    )
}
