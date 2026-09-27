import SwiftUI

// MARK: - Modern Design System

struct DesignSystem {
    // MARK: - Colors
    struct Colors {
        // Primary palette
        static let primary = Color(red: 0.18, green: 0.30, blue: 0.98)
        static let primaryLight = Color(red: 0.15, green: 0.60, blue: 0.98)
        static let primaryDark = Color(red: 0.12, green: 0.24, blue: 0.82)
        static let secondary = Color(red: 0.52, green: 0.31, blue: 0.98)
        
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
            gradient: Gradient(colors: [primary, secondary]),
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
            color: Color.black.opacity(0.05),
            radius: 3,
            x: 0,
            y: 2
        )
        
        static let medium = Shadow(
            color: Color.black.opacity(0.06),
            radius: 5,
            x: 0,
            y: 2
        )
        
        static let large = Shadow(
            color: Color.black.opacity(0.08),
            radius: 10,
            x: 0,
            y: 4
        )
        
        static let elevation = Shadow(
            color: Color.black.opacity(0.10),
            radius: 12,
            x: 0,
            y: 6
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
        static let smooth = SwiftUI.Animation.easeOut(duration: 0.22)
        static let spring = SwiftUI.Animation.spring(response: 0.24, dampingFraction: 0.88)
        static let bounce = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.82)
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
    
    func withSmallShadow() -> some View {
        self.modifier(ShadowModifier(shadow: DesignSystem.Shadows.small))
    }
    
}

// MARK: - Shimmer Animation

extension View {
}

// MARK: - Blur View Modifier

extension View {
}
