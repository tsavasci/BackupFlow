import SwiftUI

// Building blocks shared by the dashboard sections (DashboardSections.swift).

// MARK: - Theme

struct DashboardTheme {
    let primary: Color
    let secondary: Color

    static let webDAV = DashboardTheme(
        primary: Color(red: 0.17, green: 0.90, blue: 1.00),
        secondary: Color(red: 0.12, green: 0.48, blue: 1.00)
    )

    static let ftp = DashboardTheme(
        primary: Color(red: 1.00, green: 0.68, blue: 0.22),
        secondary: Color(red: 0.98, green: 0.44, blue: 0.14)
    )

    static let sftp = DashboardTheme(
        primary: Color(red: 0.20, green: 0.95, blue: 0.76),
        secondary: Color(red: 0.10, green: 0.72, blue: 0.88)
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

// MARK: - Cyber-Telemetry Card Surface & Visual Primitives

struct TelemetryCardModifier: ViewModifier {
    let theme: DashboardTheme
    let cornerRadius: CGFloat
    let glowOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let isHighContrast = contrast == .increased
        let borderLineWidth: CGFloat = isHighContrast ? 1.5 : 1.15

        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.cardSurfaceElevated.opacity(reduceTransparency ? 1.0 : 0.95),
                                    DesignSystem.Colors.cardSurface.opacity(reduceTransparency ? 1.0 : 0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if !reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        theme.primary.opacity(glowOpacity),
                                        Color.clear
                                    ],
                                    center: .top,
                                    startRadius: 6,
                                    endRadius: 210
                                )
                            )

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        theme.secondary.opacity(glowOpacity * 0.75),
                                        Color.clear
                                    ],
                                    center: .bottomTrailing,
                                    startRadius: 8,
                                    endRadius: 180
                                )
                            )
                    }

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(isHighContrast ? 0.95 : 0.82),
                                    DesignSystem.Colors.rimBorderMuted.opacity(isHighContrast ? 0.90 : 0.68),
                                    DesignSystem.Colors.rimBorderMuted.opacity(isHighContrast ? 0.70 : 0.45),
                                    theme.secondary.opacity(isHighContrast ? 0.85 : 0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: borderLineWidth
                        )
                }
            )
            .shadow(color: theme.primary.opacity(reduceTransparency ? 0 : 0.11), radius: 14, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 8)
    }
}

/// Critically-damped press feedback on pointer-down (per Apple Designing Fluid Interfaces).
struct TelemetryPressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.965

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 1.0),
                value: configuration.isPressed
            )
    }
}

extension View {
    func telemetryCard(
        theme: DashboardTheme = .webDAV,
        cornerRadius: CGFloat = 22,
        glowOpacity: Double = 0.15
    ) -> some View {
        self.modifier(
            TelemetryCardModifier(
                theme: theme,
                cornerRadius: cornerRadius,
                glowOpacity: glowOpacity
            )
        )
    }
}

/// Glowing 3-bar vertical telemetry indicator (`|I|`) driven by a real 0...1 metric level.
struct TelemetrySignalBars: View {
    let color: Color
    var isActive: Bool = true
    var level: Double? = nil

    private var effectiveLevel: Double {
        if let level {
            return min(max(level, 0), 1)
        }
        return isActive ? 1.0 : 0.0
    }

    var body: some View {
        let lvl = effectiveLevel
        let bar1Lit = lvl >= 0.10
        let bar2Lit = lvl >= 0.45
        let bar3Lit = lvl >= 0.80

        HStack(alignment: .center, spacing: 2.5) {
            Capsule()
                .fill(color.opacity(bar1Lit ? 0.85 : 0.22))
                .frame(width: 2.5, height: bar1Lit ? 7 : 5)
            Capsule()
                .fill(color.opacity(bar2Lit ? 1.0 : 0.25))
                .frame(width: 2.5, height: bar2Lit ? 12 : 7)
            Capsule()
                .fill(color.opacity(bar3Lit ? 0.90 : 0.22))
                .frame(width: 2.5, height: bar3Lit ? 9 : 5)
        }
        .shadow(color: lvl > 0.1 ? color.opacity(0.65) : .clear, radius: 5)
        .accessibilityHidden(true)
    }
}

/// Real-data mini dual-wave sparkline used in `DashboardHeroCard`.
/// Renders actual backup history / live progress values; shows a flat zero baseline when no runs exist.
struct TelemetrySparklineView: View {
    let theme: DashboardTheme
    let points: [Double]
    var secondaryPoints: [Double]? = nil

    private var normalizedPrimary: [Double] {
        guard !points.isEmpty else { return [0.06, 0.06, 0.06, 0.06] }
        if points.count == 1, let first = points.first {
            return [max(0.06, first * 0.5), max(0.06, first)]
        }
        return points.map { min(max($0, 0.06), 0.96) }
    }

    private var normalizedSecondary: [Double] {
        if let secondaryPoints, secondaryPoints.count == normalizedPrimary.count {
            return secondaryPoints.map { min(max($0, 0.05), 0.94) }
        }
        return normalizedPrimary.map { max(0.05, $0 * 0.68) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let primary = normalizedPrimary
            let secondary = normalizedSecondary

            ZStack {
                smoothPath(points: primary, in: CGSize(width: w, height: h), closed: true)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primary.opacity(points.isEmpty ? 0.08 : 0.30),
                                theme.secondary.opacity(points.isEmpty ? 0.04 : 0.12),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                smoothPath(points: secondary, in: CGSize(width: w, height: h), closed: false)
                    .stroke(
                        theme.secondary.opacity(points.isEmpty ? 0.35 : 0.82),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                smoothPath(points: primary, in: CGSize(width: w, height: h), closed: false)
                    .stroke(
                        LinearGradient(
                            colors: [theme.secondary, theme.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: theme.primary.opacity(points.isEmpty ? 0.25 : 0.75), radius: 5, x: 0, y: 2)
            }
        }
        .accessibilityHidden(true)
    }

    private func smoothPath(points: [Double], in size: CGSize, closed: Bool) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        let stepX = size.width / CGFloat(points.count - 1)
        let coords: [CGPoint] = points.enumerated().map { idx, val in
            let clamped = CGFloat(min(max(val, 0.05), 0.98))
            return CGPoint(
                x: CGFloat(idx) * stepX,
                y: size.height * (1.0 - clamped)
            )
        }

        path.move(to: coords[0])
        for i in 1..<coords.count {
            let prev = coords[i - 1]
            let cur = coords[i]
            let midX = (prev.x + cur.x) / 2
            path.addCurve(
                to: cur,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: cur.y)
            )
        }

        if closed, let last = coords.last, let first = coords.first {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }
        return path
    }
}

struct TelemetryChartPoint: Identifiable {
    let id: Int
    let label: String
    let title: String
    let summary: String
    let primaryValue: Double
    let secondaryValue: Double
    let onTap: (() -> Void)?
}

/// Interactive dot-matrix + dual glowing spline chart (`SYSTEM PERFORMANCE` card) driven by real `BackupHistory` runs.
struct TelemetrySplineChartView: View {
    let points: [TelemetryChartPoint]
    let theme: DashboardTheme
    let emptyTitle: String
    let emptySubtitle: String
    var onEmptyTap: (() -> Void)? = nil

    @State private var selectedIndex: Int? = nil

    private var activePoint: TelemetryChartPoint? {
        guard !points.isEmpty else { return nil }
        if let selectedIndex, points.indices.contains(selectedIndex) {
            return points[selectedIndex]
        }
        return points.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let active = activePoint {
                Button {
                    active.onTap?()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 7, height: 7)
                            .shadow(color: theme.primary.opacity(0.8), radius: 4)

                        Text(active.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(active.summary)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.mintNeon)
                            .lineLimit(1)

                        if active.onTap != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.primary)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DesignSystem.Colors.cardSurface.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(theme.primary.opacity(0.32), lineWidth: 0.8)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                let size = geo.size
                let primaryValues = points.map(\.primaryValue)
                let secondaryValues = points.map(\.secondaryValue)

                ZStack {
                    // Dot-matrix telemetry grid + vertical guide lines
                    Canvas { context, canvasSize in
                        let cols = 22
                        let rows = 7
                        let dx = canvasSize.width / CGFloat(max(cols - 1, 1))
                        let dy = canvasSize.height / CGFloat(max(rows - 1, 1))
                        let dotColor = Color.white.opacity(0.08)

                        for r in 0..<rows {
                            for c in 0..<cols {
                                let rect = CGRect(
                                    x: CGFloat(c) * dx - 0.75,
                                    y: CGFloat(r) * dy - 0.75,
                                    width: 1.5,
                                    height: 1.5
                                )
                                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                            }
                        }

                        if points.count >= 2 {
                            let guideCount = points.count
                            let guideStep = canvasSize.width / CGFloat(guideCount - 1)
                            for i in 0..<guideCount {
                                let x = CGFloat(i) * guideStep
                                var line = Path()
                                line.move(to: CGPoint(x: x, y: 4))
                                line.addLine(to: CGPoint(x: x, y: canvasSize.height))
                                let isSelected = (selectedIndex ?? (points.count - 1)) == i
                                context.stroke(
                                    line,
                                    with: .color(theme.primary.opacity(isSelected ? 0.36 : 0.12)),
                                    style: StrokeStyle(lineWidth: isSelected ? 1.1 : 0.8, dash: [2, 3])
                                )
                            }
                        }
                    }

                    if points.isEmpty {
                        Button {
                            onEmptyTap?()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(theme.primary)
                                    .accessibilityHidden(true)
                                Text(emptyTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(emptySubtitle)
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        let renderedPrimary = primaryValues.count == 1 ? [primaryValues[0], primaryValues[0]] : primaryValues
                        let renderedSecondary = secondaryValues.count == 1 ? [secondaryValues[0], secondaryValues[0]] : secondaryValues

                        // Secondary curve area fill
                        splinePath(values: renderedSecondary, in: size, closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.secondary.opacity(0.30),
                                        theme.primary.opacity(0.10),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Primary curve area fill
                        splinePath(values: renderedPrimary, in: size, closed: true)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.primary.opacity(0.24),
                                        theme.secondary.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Secondary electric-blue spline
                        splinePath(values: renderedSecondary, in: size, closed: false)
                            .stroke(
                                LinearGradient(
                                    colors: [theme.secondary, theme.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: theme.secondary.opacity(0.6), radius: 5, x: 0, y: 2)

                        // Primary luminous-cyan spline
                        splinePath(values: renderedPrimary, in: size, closed: false)
                            .stroke(
                                theme.primary,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: theme.primary.opacity(0.85), radius: 8, x: 0, y: 2)

                        // Interactive glowing node rings on the primary curve
                        let coords = nodePoints(values: primaryValues, in: size)
                        ForEach(Array(coords.enumerated()), id: \.offset) { idx, pt in
                            let isCurrent = (selectedIndex ?? (points.count - 1)) == idx
                            Button {
                                if selectedIndex == idx {
                                    points[idx].onTap?()
                                } else {
                                    selectedIndex = idx
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 30, height: 30)
                                    Circle()
                                        .fill(isCurrent ? theme.primary : DesignSystem.Colors.cardSurface)
                                        .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                                    Circle()
                                        .stroke(theme.primary, lineWidth: isCurrent ? 2.4 : 1.8)
                                        .frame(width: isCurrent ? 12 : 8, height: isCurrent ? 12 : 8)
                                        .shadow(color: theme.primary.opacity(0.95), radius: isCurrent ? 7 : 4)
                                }
                            }
                            .buttonStyle(.plain)
                            .position(pt)
                        }
                    }
                }
            }
            .frame(height: 112)

            if !points.isEmpty {
                HStack {
                    ForEach(Array(points.enumerated()), id: \.offset) { idx, pt in
                        let isSelected = (selectedIndex ?? (points.count - 1)) == idx
                        Button {
                            selectedIndex = idx
                        } label: {
                            Text(pt.label)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundStyle(isSelected ? theme.primary : DesignSystem.Colors.slateMuted)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        if idx < points.count - 1 {
                            Spacer(minLength: 2)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedIndex)
    }

    private func nodePoints(values: [Double], in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        if values.count == 1 {
            let clamped = CGFloat(min(max(values[0], 0.12), 0.90))
            return [CGPoint(x: size.width / 2, y: size.height * (1.0 - clamped))]
        }
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { idx, val in
            let clamped = CGFloat(min(max(val, 0.10), 0.90))
            return CGPoint(
                x: CGFloat(idx) * stepX,
                y: size.height * (1.0 - clamped)
            )
        }
    }

    private func splinePath(values: [Double], in size: CGSize, closed: Bool) -> Path {
        var path = Path()
        let pts = nodePoints(values: values, in: size)
        guard pts.count > 1 else { return path }

        path.move(to: pts[0])
        for i in 1..<pts.count {
            let prev = pts[i - 1]
            let cur = pts[i]
            let midX = (prev.x + cur.x) / 2
            path.addCurve(
                to: cur,
                control1: CGPoint(x: midX, y: prev.y),
                control2: CGPoint(x: midX, y: cur.y)
            )
        }

        if closed, let last = pts.last, let first = pts.first {
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }
        return path
    }
}

/// Circular glowing ring gauge (`CORE LOAD 74%` style from the reference design).
struct TelemetryRingGauge: View {
    let title: String
    let valueText: String
    let detailLine1: String
    let detailLine2: String?
    let progress: Double
    let theme: DashboardTheme
    var ringSize: CGFloat = 132
    var lineWidth: CGFloat = 11

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0.04), 1.0))
    }

    var body: some View {
        ZStack {
            // Recessed dark track
            Circle()
                .stroke(
                    DesignSystem.Colors.rimBorderMuted.opacity(0.42),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Glowing arc
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            theme.secondary,
                            theme.primary,
                            theme.secondary,
                            theme.primary
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.primary.opacity(0.65), radius: 8, x: 0, y: 0)
                .shadow(color: theme.secondary.opacity(0.45), radius: 14, x: 0, y: 0)

            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)

                Text(valueText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primary)
                    .monospacedDigit()
                    .shadow(color: theme.primary.opacity(0.45), radius: 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(detailLine1)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)

                if let detailLine2, !detailLine2.isEmpty {
                    Text(detailLine2)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.slateMuted.opacity(0.85))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
            }
            .padding(.horizontal, lineWidth + 4)
        }
        .frame(width: ringSize, height: ringSize)
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
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                TelemetrySignalBars(color: color, level: progress)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color.opacity(0.85))
                        .accessibilityHidden(true)
                }
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.slateMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            GeometryReader { geo in
                let clamped = CGFloat(min(max(progress, 0), 1))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.Colors.rimBorderMuted.opacity(0.45))
                        .frame(height: 5)
                    if clamped > 0 {
                        Capsule()
                            .fill(color)
                            .frame(width: max(geo.size.width * clamped, 6), height: 5)
                            .shadow(color: color.opacity(0.65), radius: 5)
                    }
                }
            }
            .frame(height: 5)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .telemetryCard(
            theme: DashboardTheme(primary: color, secondary: DesignSystem.Colors.electricBlue),
            cornerRadius: 20,
            glowOpacity: 0.14
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
    var isHighlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    if isHighlighted {
                        Circle()
                            .fill(theme.primary.opacity(0.16))
                            .frame(width: 40, height: 40)
                            .blur(radius: 6)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isHighlighted ? .bold : .medium))
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                        .foregroundStyle(isHighlighted ? theme.primary : DesignSystem.Colors.slateMuted)
                        .shadow(color: isHighlighted ? theme.primary.opacity(0.75) : .clear, radius: 6)
                }

                Text(title)
                    .font(.system(size: 11, weight: isHighlighted ? .semibold : .medium))
                    .foregroundStyle(isHighlighted ? .white : DesignSystem.Colors.slateMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)

                Capsule()
                    .fill(isHighlighted ? theme.primary : Color.clear)
                    .frame(width: 26, height: 3)
                    .shadow(color: isHighlighted ? theme.primary.opacity(0.9) : .clear, radius: 6)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TelemetryPressButtonStyle(scale: 0.94))
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
