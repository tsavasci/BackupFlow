import SwiftUI

struct OnboardingView: View {
    static let currentOnboardingVersion = "6.7"

    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private struct Slide: Identifiable {
        let id: Int
        let badge: String
        let title: String
        let subtitle: String
        let theme: DashboardTheme
        let kind: SlideKind
    }

    private enum SlideKind {
        case telemetryCockpit
        case smartRestore
        case directBrowser
        case securityAndBackground
    }

    private var slides: [Slide] {
        [
            Slide(
                id: 0,
                badge: "onboarding.slide1.badge".localized,
                title: "onboarding.slide1.title".localized,
                subtitle: "onboarding.slide1.subtitle".localized,
                theme: .webDAV,
                kind: .telemetryCockpit
            ),
            Slide(
                id: 1,
                badge: "onboarding.slide2.badge".localized,
                title: "onboarding.slide2.title".localized,
                subtitle: "onboarding.slide2.subtitle".localized,
                theme: .sftp,
                kind: .smartRestore
            ),
            Slide(
                id: 2,
                badge: "onboarding.slide3.badge".localized,
                title: "onboarding.slide3.title".localized,
                subtitle: "onboarding.slide3.subtitle".localized,
                theme: .ftp,
                kind: .directBrowser
            ),
            Slide(
                id: 3,
                badge: "onboarding.slide4.badge".localized,
                title: "onboarding.slide4.title".localized,
                subtitle: "onboarding.slide4.subtitle".localized,
                theme: .webDAV,
                kind: .securityAndBackground
            )
        ]
    }

    private var activeTheme: DashboardTheme {
        slides[safe: currentPage]?.theme ?? .webDAV
    }

    var body: some View {
        ZStack {
            // Deep obsidian Cyber-Telemetry background
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
                .fill(activeTheme.primary.opacity(0.11))
                .blur(radius: 65)
                .frame(width: 280, height: 280)
                .offset(x: -110, y: -240)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: currentPage)

            Circle()
                .fill(activeTheme.secondary.opacity(0.10))
                .blur(radius: 70)
                .frame(width: 260, height: 260)
                .offset(x: 120, y: -80)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: currentPage)

            VStack(spacing: 0) {
                // Top bar: Version telemetry pill + Skip button
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(activeTheme.primary)
                            .frame(width: 7, height: 7)
                            .shadow(color: activeTheme.primary.opacity(0.85), radius: 4)

                        Text("BackupFlow v\(Self.currentOnboardingVersion)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.slateMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.75), lineWidth: 1)
                            )
                    )

                    Spacer()

                    if currentPage < slides.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("onboarding.skip".localized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DesignSystem.Colors.slateMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.skip")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Paged slides
                TabView(selection: $currentPage) {
                    ForEach(slides) { slide in
                        slideView(for: slide)
                            .tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom Cyber-Telemetry Dock: Page indicators + Action button
                VStack(spacing: 18) {
                    HStack(spacing: 8) {
                        ForEach(slides) { slide in
                            let isSelected = slide.id == currentPage
                            Button {
                                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 1.0)) {
                                    currentPage = slide.id
                                }
                            } label: {
                                Capsule()
                                    .fill(isSelected ? activeTheme.primary : DesignSystem.Colors.slateMuted.opacity(0.3))
                                    .frame(width: isSelected ? 26 : 8, height: 7)
                                    .shadow(color: isSelected ? activeTheme.primary.opacity(0.7) : .clear, radius: 5)
                                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.78), value: currentPage)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(slide.title)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }

                    Button {
                        if currentPage < slides.count - 1 {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 1.0)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(
                                currentPage < slides.count - 1
                                    ? "onboarding.next".localized
                                    : "onboarding.get_started".localized
                            )
                            .font(.headline.weight(.bold))

                            Image(systemName: currentPage < slides.count - 1 ? "arrow.right" : "checkmark.circle.fill")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(Color(red: 0.03, green: 0.06, blue: 0.11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            activeTheme.primary,
                                            DesignSystem.Colors.mintNeon
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: activeTheme.primary.opacity(0.45), radius: 12, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(TelemetryPressButtonStyle())
                    .accessibilityIdentifier("onboarding.primary_button")
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: currentPage)
    }

    private func completeOnboarding() {
        onFinish()
    }

    // MARK: - Slide Content

    private func slideView(for slide: Slide) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 8)

                // Interactive/Visual Telemetry Hero Preview
                slideIllustration(for: slide)
                    .padding(.horizontal, 20)

                // Badge + Title + Description
                VStack(spacing: 12) {
                    Text(slide.badge.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(slide.theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(slide.theme.primary.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .stroke(slide.theme.primary.opacity(0.45), lineWidth: 0.9)
                                )
                        )

                    Text(slide.title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 20)

                    Text(slide.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func slideIllustration(for slide: Slide) -> some View {
        switch slide.kind {
        case .telemetryCockpit:
            telemetryCockpitCard(theme: slide.theme)
        case .smartRestore:
            smartRestoreCard(theme: slide.theme)
        case .directBrowser:
            directBrowserCard(theme: slide.theme)
        case .securityAndBackground:
            securityAndBackgroundCard(theme: slide.theme)
        }
    }

    // MARK: - Slide 1 Visual: Cyber-Telemetry Cockpit

    private func telemetryCockpitCard(theme: DashboardTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.primary)
                    Text("dashboard.backup_hub".localized.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                }
                Spacer()
                TelemetrySignalBars(color: theme.primary, level: 1.0)
            }

            HStack(spacing: 12) {
                TelemetryRingGauge(
                    title: "dashboard.health.success".localized,
                    valueText: "100%",
                    detailLine1: "WebDAV • SFTP • FTP",
                    detailLine2: nil,
                    progress: 1.0,
                    theme: theme,
                    ringSize: 108,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 10) {
                    protocolPreviewRow(name: "WebDAV", status: "HTTPS", color: DashboardTheme.webDAV.primary, level: 1.0)
                    Divider().overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.4))
                    protocolPreviewRow(name: "SFTP", status: "SSH-2", color: DashboardTheme.sftp.primary, level: 0.9)
                    Divider().overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.4))
                    protocolPreviewRow(name: "FTP", status: "LAN", color: DashboardTheme.ftp.primary, level: 0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TelemetrySparklineView(
                theme: theme,
                points: [0.22, 0.48, 0.36, 0.72, 0.58, 0.88, 0.94],
                secondaryPoints: [0.15, 0.32, 0.26, 0.54, 0.44, 0.68, 0.78]
            )
            .frame(height: 36)
        }
        .padding(18)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
    }

    private func protocolPreviewRow(name: String, status: String, color: Color, level: Double) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("[\(status)]")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .fixedSize()
            Spacer(minLength: 2)
            TelemetrySignalBars(color: color, level: level)
        }
    }

    // MARK: - Slide 2 Visual: Smart Restore & Diff Engine

    private func smartRestoreCard(theme: DashboardTheme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.primary)
                    Text("smart_restore.title".localized.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(DesignSystem.Colors.slateMuted)
                        .lineLimit(1)
                }
                Spacer()
                Text("[SHA-256]")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.primary)
            }

            HStack(spacing: 12) {
                TelemetryRingGauge(
                    title: "smart_restore.stat.intact".localized,
                    valueText: "96%",
                    detailLine1: "512 / 532",
                    detailLine2: nil,
                    progress: 0.96,
                    theme: theme,
                    ringSize: 108,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 10) {
                    protocolPreviewRow(
                        name: "smart_restore.stat.intact".localized,
                        status: "512",
                        color: DesignSystem.Colors.mintNeon,
                        level: 0.96
                    )
                    Divider().overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.4))
                    protocolPreviewRow(
                        name: "smart_restore.stat.missing".localized,
                        status: "20",
                        color: theme.primary,
                        level: 0.45
                    )
                    Divider().overlay(DesignSystem.Colors.rimBorderMuted.opacity(0.4))
                    protocolPreviewRow(
                        name: "smart_restore.stat.conflicts".localized,
                        status: "0",
                        color: DesignSystem.Colors.warning,
                        level: 0.0
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.mintNeon)
                Text("onboarding.slide2.highlight".localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.6), lineWidth: 0.8)
                    )
            )
        }
        .padding(18)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
    }

    // MARK: - Slide 3 Visual: Remote Browser & Dual Restore Destination

    private func directBrowserCard(theme: DashboardTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.primary)
                Text("/NAS/Photos/2026")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(1)
                Spacer()
                Text("[3]")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.primary)
                TelemetrySignalBars(color: theme.primary, level: 1.0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.95))
            )

            browserPreviewItem(
                icon: "photo.fill",
                name: "IMG_2026_0842.HEIC",
                size: "3.4 MB",
                color: DesignSystem.Colors.primary
            )
            browserPreviewItem(
                icon: "film.fill",
                name: "MOV_2026_0843.MOV",
                size: "48.2 MB",
                color: DesignSystem.Colors.mintNeon
            )

            HStack(spacing: 10) {
                destinationBadge(icon: "photo.on.rectangle.angled", title: "restore.destination.photos".localized, color: theme.primary)
                destinationBadge(icon: "folder.fill", title: "restore.destination.files".localized, color: DesignSystem.Colors.mintNeon)
            }
        }
        .padding(18)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
    }

    private func browserPreviewItem(icon: String, name: String, size: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }

            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text(size)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DesignSystem.Colors.slateMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.5), lineWidth: 0.8)
                )
        )
    }

    private func destinationBadge(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.45), lineWidth: 0.9)
                )
        )
    }

    // MARK: - Slide 4 Visual: Privacy, TOFU & Background Sync

    private func securityAndBackgroundCard(theme: DashboardTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            securityFeatureRow(
                icon: "lock.shield.fill",
                title: "onboarding.slide4.item1.title".localized,
                subtitle: "onboarding.slide4.item1.subtitle".localized,
                color: DesignSystem.Colors.primary
            )
            securityFeatureRow(
                icon: "arrow.clockwise.icloud.fill",
                title: "onboarding.slide4.item2.title".localized,
                subtitle: "onboarding.slide4.item2.subtitle".localized,
                color: DesignSystem.Colors.mintNeon
            )
            securityFeatureRow(
                icon: "externaldrive.badge.checkmark",
                title: "onboarding.slide4.item3.title".localized,
                subtitle: "onboarding.slide4.item3.subtitle".localized,
                color: DesignSystem.Colors.electricBlue
            )
        }
        .padding(18)
        .telemetryCard(theme: theme, cornerRadius: 24, glowOpacity: 0.22)
    }

    private func securityFeatureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(color.opacity(0.45), lineWidth: 0.9)
                    )
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.slateMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)

            TelemetrySignalBars(color: color, level: 1.0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DesignSystem.Colors.cardSurfaceElevated.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignSystem.Colors.rimBorderMuted.opacity(0.5), lineWidth: 0.8)
                )
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
