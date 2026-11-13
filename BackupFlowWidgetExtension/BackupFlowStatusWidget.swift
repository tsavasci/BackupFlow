import SwiftUI
import WidgetKit

struct BackupStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: BackupWidgetSnapshot?
}

struct BackupStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> BackupStatusEntry {
        BackupStatusEntry(
            date: Date(),
            snapshot: BackupWidgetSnapshot(
                lastBackupDate: Date().addingTimeInterval(-1800),
                lastStatus: "completed",
                lastTaskName: WidgetStrings.placeholderTask,
                nextRunDate: Date().addingTimeInterval(3600 * 6),
                nextTaskName: WidgetStrings.placeholderTask,
                activeTaskName: nil,
                activeProgress: 1.0,
                activeFileName: nil,
                updatedAt: Date(),
                protocolName: "WebDAV",
                statusDisplayText: WidgetStrings.statusCompleted,
                filesSummaryText: WidgetStrings.placeholderSummary,
                lastErrorSummary: nil,
                lastSyncLabel: WidgetStrings.lastSync,
                nextRunLabel: WidgetStrings.nextRun,
                openActionLabel: WidgetStrings.openAction
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BackupStatusEntry) -> Void) {
        completion(BackupStatusEntry(date: Date(), snapshot: BackupWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BackupStatusEntry>) -> Void) {
        let entry = BackupStatusEntry(date: Date(), snapshot: BackupWidgetSnapshotStore.load())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct BackupFlowStatusWidget: Widget {
    let kind = "BackupFlowStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BackupStatusProvider()) { entry in
            BackupStatusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(snapshot: entry.snapshot)
                }
        }
        .configurationDisplayName(LocalizedStringKey("widget.gallery.title"))
        .description(LocalizedStringKey("widget.gallery.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

private enum WidgetStrings {
    static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static var empty: String { localized("widget.empty") }
    static var backupDefault: String { localized("widget.backup_default") }
    static var placeholderTask: String { localized("widget.placeholder.task") }
    static var placeholderSummary: String { localized("widget.placeholder.summary") }
    static var statusCompleted: String { localized("widget.status.completed") }
    static var statusFailed: String { localized("widget.status.failed") }
    static var statusCancelled: String { localized("widget.status.cancelled") }
    static var statusRunning: String { localized("widget.status.running") }
    static var lastSync: String { localized("widget.label.last_sync") }
    static var nextRun: String { localized("widget.label.next_run") }
    static var openAction: String { localized("widget.action.open") }

    static func localizedStatus(for snapshot: BackupWidgetSnapshot) -> String {
        if let text = snapshot.statusDisplayText, !text.isEmpty {
            return text
        }
        switch snapshot.lastStatus {
        case "completed": return statusCompleted
        case "failed": return statusFailed
        case "cancelled": return statusCancelled
        case "running": return statusRunning
        default: return snapshot.lastStatus.capitalized
        }
    }
}

private struct WidgetProtocolColors {
    let primary: Color
    let secondary: Color

    static func forProtocol(_ name: String?) -> WidgetProtocolColors {
        switch name?.uppercased() {
        case "FTP":
            return WidgetProtocolColors(
                primary: Color(red: 0.95, green: 0.42, blue: 0.10),
                secondary: Color(red: 1.00, green: 0.66, blue: 0.20)
            )
        case "SFTP":
            return WidgetProtocolColors(
                primary: Color(red: 0.05, green: 0.58, blue: 0.34),
                secondary: Color(red: 0.18, green: 0.74, blue: 0.45)
            )
        default:
            return WidgetProtocolColors(
                primary: Color(red: 0.18, green: 0.30, blue: 0.98),
                secondary: Color(red: 0.52, green: 0.31, blue: 0.98)
            )
        }
    }
}

private struct WidgetBackgroundView: View {
    let snapshot: BackupWidgetSnapshot?

    var body: some View {
        let colors = WidgetProtocolColors.forProtocol(snapshot?.protocolName)
        LinearGradient(
            colors: [
                colors.primary.opacity(0.14),
                colors.secondary.opacity(0.06),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BackupStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BackupStatusEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryCircular:
            accessoryCircularView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        let colors = WidgetProtocolColors.forProtocol(entry.snapshot?.protocolName)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: statusIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(colors: colors))

                Text("BackupFlow")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let proto = entry.snapshot?.protocolName, !proto.isEmpty {
                    Text(proto)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(colors.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(colors.primary.opacity(0.15)))
                        .fixedSize()
                }
            }

            if let snapshot = entry.snapshot {
                Text(snapshot.activeTaskName ?? snapshot.lastTaskName ?? WidgetStrings.backupDefault)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 2)

                if snapshot.lastStatus == "running" {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: clampedProgress(snapshot.activeProgress))
                            .tint(colors.primary)
                        HStack {
                            Text("\(Int(clampedProgress(snapshot.activeProgress) * 100))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(colors.primary)
                            Spacer(minLength: 4)
                            if let file = snapshot.activeFileName, !file.isEmpty {
                                Text(file)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                } else if snapshot.lastStatus == "failed" {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WidgetStrings.localizedStatus(for: snapshot))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        if let error = snapshot.lastErrorSummary, !error.isEmpty {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if let summary = snapshot.filesSummaryText, !summary.isEmpty {
                            Text(summary)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        HStack(spacing: 4) {
                            if let lastDate = snapshot.lastBackupDate {
                                Text(lastDate, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let nextDate = snapshot.nextRunDate {
                                Spacer(minLength: 2)
                                Label {
                                    Text(nextDate, style: .time)
                                } icon: {
                                    Image(systemName: "clock")
                                }
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            }
                        }
                    }
                }
            } else {
                Spacer()
                Text(WidgetStrings.empty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        let colors = WidgetProtocolColors.forProtocol(entry.snapshot?.protocolName)

        return Group {
            if let snapshot = entry.snapshot {
                HStack(spacing: 14) {
                    // Left column: Protocol, status, task name & progress/summary
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let proto = snapshot.protocolName, !proto.isEmpty {
                                Text(proto)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(colors.primary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(colors.primary.opacity(0.16)))
                                    .fixedSize()
                            }

                            Label(
                                WidgetStrings.localizedStatus(for: snapshot),
                                systemImage: statusIcon
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(statusColor(colors: colors))
                            .lineLimit(1)
                        }

                        Text(snapshot.activeTaskName ?? snapshot.lastTaskName ?? WidgetStrings.backupDefault)
                            .font(.headline.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 2)

                        if snapshot.lastStatus == "running" {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    ProgressView(value: clampedProgress(snapshot.activeProgress))
                                        .tint(colors.primary)
                                    Text("\(Int(clampedProgress(snapshot.activeProgress) * 100))%")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(colors.primary)
                                }
                                if let file = snapshot.activeFileName, !file.isEmpty {
                                    Text(file)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        } else if snapshot.lastStatus == "failed",
                                  let error = snapshot.lastErrorSummary,
                                  !error.isEmpty {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        } else if let summary = snapshot.filesSummaryText, !summary.isEmpty {
                            Text(summary)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Divider()
                        .opacity(0.45)

                    // Right column: Schedule & Open Action
                    VStack(alignment: .leading, spacing: 8) {
                        if let lastDate = snapshot.lastBackupDate {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(snapshot.lastSyncLabel ?? WidgetStrings.lastSync)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(lastDate, style: .relative)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }

                        if let nextDate = snapshot.nextRunDate {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(snapshot.nextRunLabel ?? WidgetStrings.nextRun)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(nextDate, style: .time)
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 2)

                        if let url = URL(string: "backupflow://dashboard") {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                    Text(snapshot.openActionLabel ?? WidgetStrings.openAction)
                                        .lineLimit(1)
                                }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(Capsule().fill(colors.primary))
                            }
                        }
                    }
                    .frame(width: 112, alignment: .topLeading)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill.badge.plus")
                        .font(.title2)
                        .foregroundStyle(colors.primary)
                    Text(WidgetStrings.empty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Lock Screen Widgets

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let snapshot = entry.snapshot {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                    Text(snapshot.activeTaskName ?? snapshot.lastTaskName ?? "BackupFlow")
                        .font(.headline)
                        .lineLimit(1)
                }
                if snapshot.lastStatus == "running" {
                    ProgressView(value: clampedProgress(snapshot.activeProgress))
                    Text("\(Int(clampedProgress(snapshot.activeProgress) * 100))% • \(snapshot.protocolName ?? "")")
                        .font(.caption2.monospacedDigit())
                } else {
                    Text(WidgetStrings.localizedStatus(for: snapshot))
                        .font(.caption)
                    if let nextDate = snapshot.nextRunDate {
                        Text(nextDate, style: .time)
                            .font(.caption2.monospacedDigit())
                    }
                }
            } else {
                Text("BackupFlow")
                    .font(.headline)
                Text(WidgetStrings.empty)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        ZStack {
            if let snapshot = entry.snapshot, snapshot.lastStatus == "running" {
                Gauge(value: clampedProgress(snapshot.activeProgress)) {
                    Image(systemName: "arrow.up.circle.fill")
                } currentValueLabel: {
                    Text("\(Int(clampedProgress(snapshot.activeProgress) * 100))")
                        .font(.caption2.monospacedDigit())
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                AccessoryWidgetBackground()
                Image(systemName: statusIcon)
                    .font(.title3)
            }
        }
    }

    // MARK: - Helpers

    private func clampedProgress(_ value: Double) -> Double {
        guard !value.isNaN, !value.isInfinite else { return 0 }
        return max(0, min(1, value))
    }

    private var statusIcon: String {
        switch entry.snapshot?.lastStatus {
        case "completed": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.triangle.fill"
        case "cancelled": return "xmark.circle.fill"
        case "running": return "arrow.triangle.2.circlepath.circle.fill"
        default: return "externaldrive.fill"
        }
    }

    private func statusColor(colors: WidgetProtocolColors) -> Color {
        switch entry.snapshot?.lastStatus {
        case "completed": return .green
        case "failed": return .red
        case "cancelled": return .orange
        case "running": return colors.primary
        default: return .secondary
        }
    }
}
