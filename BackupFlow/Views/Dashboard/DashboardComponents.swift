import SwiftUI

// Building blocks shared by the dashboard sections (DashboardSections.swift).

// MARK: - Theme

struct DashboardTheme {
    let primary: Color
    let secondary: Color

    static let webDAV = DashboardTheme(
        primary: Color(red: 0.18, green: 0.30, blue: 0.98),
        secondary: Color(red: 0.52, green: 0.31, blue: 0.98)
    )

    static let ftp = DashboardTheme(
        primary: Color(red: 0.95, green: 0.42, blue: 0.10),
        secondary: Color(red: 1.00, green: 0.66, blue: 0.20)
    )

    static let sftp = DashboardTheme(
        primary: Color(red: 0.05, green: 0.58, blue: 0.34),
        secondary: Color(red: 0.18, green: 0.74, blue: 0.45)
    )

    static func theme(for backupType: BackupType?) -> DashboardTheme {
        switch backupType {
        case .ftp:
            return .ftp
        case .sftp:
            return .sftp
        case .webdav, .none:
            return .webDAV
        }
    }
}

// MARK: - Formatting

/// Text formats used on the dashboard. Other screens keep their own formats on purpose
/// (e.g. they spell out "Zero KB"), so these are not shared app-wide.
enum DashboardFormat {
    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        }
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        }
        return String(format: "%.1fh", seconds / 3600)
    }

    static func bytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        // Keep "0 KB" numeric instead of the spelled-out "Zero KB".
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }

    /// A 0...1 progress value as a whole percentage, e.g. "42%".
    static func percent(_ progress: Double) -> String {
        "\(Int(min(max(progress, 0), 1) * 100))%"
    }

    /// Countdown to the next run as "HH:MM" (an hour or more away) or "MM:SS".
    static func timeUntil(_ nextRun: Date, from currentTime: Date) -> String {
        let timeInterval = nextRun.timeIntervalSince(currentTime)

        if timeInterval < -30 {
            return "dashboard.overdue".localized
        }

        let totalSeconds = Int(max(0, timeInterval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours >= 1 {
            return String(format: "%02d:%02d", hours, minutes)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Info Card

struct DashboardInfoCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(value: progress, total: 1.0)
            .tint(color)
            .scaleEffect(x: 1, y: 1.2, anchor: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Controls

/// The dashboard draws its own opaque status-bar strip, so the system's
/// blurred top edge effect (iOS 26+) is redundant there.
struct HideTopScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

struct DashboardActionButton: View {
    let icon: String
    let title: String
    let theme: DashboardTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                    .background(
                        LinearGradient(
                            colors: [theme.primary.opacity(0.15), theme.secondary.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Progress Bars

struct AnimatedDashboardProgressBar: View {
    let progress: Double
    let theme: DashboardTheme
    let reduceMotion: Bool
    @State private var phase: CGFloat = -1

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            let progressWidth = max(geometry.size.width * clampedProgress, 0)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(theme.primary.opacity(0.1))
                    .frame(height: 8)

                if progressWidth > 0 {
                    ZStack {
                        LinearGradient(
                            colors: [
                                theme.primary,
                                theme.secondary,
                                theme.primary,
                                theme.secondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(progressWidth * 2.4, 160), height: 8)
                        .offset(x: reduceMotion ? 0 : phase * max(progressWidth, 1))
                    }
                    .frame(width: progressWidth, height: 8, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 999))
                    .animation(DesignSystem.Animation.swift, value: progressWidth)
                }
            }
        }
        .frame(height: 8)
        .onAppear {
            guard !reduceMotion else { return }
            phase = -1
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 0
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                phase = 0
            } else {
                phase = -1
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 0
                }
            }
        }
    }
}

struct MiniTransferProgressBar: View {
    let progress: Double?
    let theme: DashboardTheme
    let reduceMotion: Bool
    @State private var phase: CGFloat = -1

    private var clampedProgress: CGFloat? {
        guard let progress else { return nil }
        return CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.primary.opacity(0.08))
                    .frame(height: 4)

                if let clampedProgress {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.primary, theme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * clampedProgress, 4), height: 4)
                        .animation(DesignSystem.Animation.swift, value: clampedProgress)
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.primary.opacity(0.25), theme.secondary, theme.primary.opacity(0.25)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * 0.34, 48), height: 4)
                        .offset(x: reduceMotion ? 0 : phase * geometry.size.width)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 4)
        .onAppear {
            guard !reduceMotion, clampedProgress == nil else { return }
            phase = -0.35
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                phase = 0
            } else if clampedProgress == nil {
                phase = -0.35
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}
