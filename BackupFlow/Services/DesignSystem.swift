import SwiftUI

// MARK: - Modern Design System

struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Cyber-Telemetry Dark Glass palette (modeled after the dark obsidian + luminous cyan reference)
        static let canvasTop = Color(red: 0.055, green: 0.078, blue: 0.110)        // #0E141C
        static let canvasBottom = Color(red: 0.078, green: 0.110, blue: 0.157)     // #141C28
        static let cardSurface = Color(red: 0.098, green: 0.137, blue: 0.192)      // #192331
        static let cardSurfaceElevated = Color(red: 0.122, green: 0.169, blue: 0.235) // #1F2B3C
        static let rimBorderMuted = Color(red: 0.165, green: 0.235, blue: 0.325)   // #2A3C53
        static let slateMuted = Color(red: 0.56, green: 0.65, blue: 0.76)          // #8FA6C2

        // Luminous accents
        static let primary = Color(red: 0.17, green: 0.90, blue: 1.00)             // #2CE5FF Luminous Cyan
        static let accentAqua = Color(red: 0.17, green: 0.90, blue: 1.00)          // #2CE5FF
        static let electricBlue = Color(red: 0.12, green: 0.48, blue: 1.00)        // #1E7BFF Electric Ocean Blue
        static let mintNeon = Color(red: 0.22, green: 0.95, blue: 0.78)            // #38F2C6 Mint Telemetry
        static let slateSurface = Color(red: 0.098, green: 0.137, blue: 0.192)

        // Status colors
        static let success = Color(red: 0.20, green: 0.92, blue: 0.68)
        static let warning = Color(red: 1.00, green: 0.68, blue: 0.20)
        static let error = Color(red: 1.00, green: 0.36, blue: 0.36)
    }

    // MARK: - Typography
    struct Typography {
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }

    // MARK: - Spacing
    struct Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let base: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let large: CGFloat = 16
    }

    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(
            color: Color.black.opacity(0.05),
            radius: 3,
            x: 0,
            y: 2
        )
    }

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - Animation Timing
    struct Animation {
        static let swift = SwiftUI.Animation.easeOut(duration: 0.16)
    }
}

// MARK: - Shadow View Modifier

struct ShadowModifier: ViewModifier {
    let shadow: DesignSystem.Shadow

    func body(content: Content) -> some View {
        content
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension View {

    func withSmallShadow() -> some View {
        self.modifier(ShadowModifier(shadow: DesignSystem.Shadows.small))
    }

}
