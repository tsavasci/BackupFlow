import SwiftUI

// MARK: - Modern Design System

struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Primary palette
        static let primary = Color(red: 0.18, green: 0.30, blue: 0.98)

        // Status colors
        static let success = Color(red: 0.34, green: 0.84, blue: 0.40)
        static let warning = Color(red: 0.95, green: 0.77, blue: 0.06)
        static let error = Color(red: 0.91, green: 0.30, blue: 0.24)
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
