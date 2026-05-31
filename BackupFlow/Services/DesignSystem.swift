import SwiftUI

// MARK: - Modern Design System

struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Primary palette
        static let primary = Color(red: 0.20, green: 0.45, blue: 0.95)
        static let primaryLight = Color(red: 0.35, green: 0.60, blue: 0.98)
        static let primaryDark = Color(red: 0.10, green: 0.30, blue: 0.80)
        
        // Status colors
        static let success = Color(red: 0.34, green: 0.84, blue: 0.40)
        static let successLight = Color(red: 0.50, green: 0.92, blue: 0.55)
        static let warning = Color(red: 0.95, green: 0.77, blue: 0.06)
        static let warningLight = Color(red: 0.98, green: 0.87, blue: 0.30)
        static let error = Color(red: 0.91, green: 0.30, blue: 0.24)
        static let errorLight = Color(red: 0.95, green: 0.50, blue: 0.45)
        
        // Semantic colors
        static let disabled = Color.gray.opacity(0.5)
        static let border = Color.gray.opacity(0.2)
        
        // Gradients
        static let primaryGradient = LinearGradient(
            gradient: Gradient(colors: [primaryLight, primary]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let successGradient = LinearGradient(
            gradient: Gradient(colors: [successLight, success]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 15, weight: .medium, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
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
        static let xxLarge: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20
        static let pill: CGFloat = 24
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let medium = Shadow(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let large = Shadow(
            color: Color.black.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let elevation = Shadow(
            color: Color.black.opacity(0.20),
            radius: 24,
            x: 0,
            y: 12
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
        static let swift = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bounce = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
    }
    
    // MARK: - Dimensions
    struct Dimensions {
        static let buttonHeight: CGFloat = 48
        static let smallButtonHeight: CGFloat = 40
        static let iconSize: CGFloat = 24
        static let tabBarHeight: CGFloat = 49
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
    func withShadow(_ shadow: DesignSystem.Shadow) -> some View {
        self.modifier(ShadowModifier(shadow: shadow))
    }
    
    func withSmallShadow() -> some View {
        self.modifier(ShadowModifier(shadow: DesignSystem.Shadows.small))
    }
    
    func withMediumShadow() -> some View {
        self.modifier(ShadowModifier(shadow: DesignSystem.Shadows.medium))
    }
    
    func withLargeShadow() -> some View {
        self.modifier(ShadowModifier(shadow: DesignSystem.Shadows.large))
    }
}

// MARK: - Shimmer Animation

struct ShimmerModifier: ViewModifier {
    @State private var isShimmering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isShimmering ? 400 : -400)
                .animation(
                    SwiftUI.Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: isShimmering
                )
            )
            .onAppear {
                isShimmering = true
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Blur View Modifier

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
    }
}

extension View {
    func blurred(_ radius: CGFloat = 3) -> some View {
        self.modifier(BlurModifier(radius: radius))
    }
}
