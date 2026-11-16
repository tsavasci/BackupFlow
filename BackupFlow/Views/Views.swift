import SwiftUI

// MARK: - App Surface Theme

struct LiquidTheme {
    static let cardCornerRadius: CGFloat = 20
    static let cardStroke = LinearGradient(
        colors: [
            DesignSystem.Colors.primary.opacity(0.65),
            DesignSystem.Colors.rimBorderMuted.opacity(0.65),
            DesignSystem.Colors.electricBlue.opacity(0.45)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let subtleStroke = LinearGradient(
        colors: [
            DesignSystem.Colors.primary.opacity(0.42),
            DesignSystem.Colors.rimBorderMuted.opacity(0.45),
            DesignSystem.Colors.electricBlue.opacity(0.28)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct LiquidBackgroundModifier: ViewModifier {
    private let gradient = LinearGradient(
        colors: [
            DesignSystem.Colors.canvasTop,
            DesignSystem.Colors.canvasBottom
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    gradient
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.primary.opacity(0.08),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 340
                    )
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.electricBlue.opacity(0.07),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 20,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
    }
}

private struct LiquidListRowModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.listRowBackground(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.cardSurfaceElevated.opacity(0.92),
                            DesignSystem.Colors.cardSurface.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LiquidTheme.subtleStroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - View Modifiers

extension View {
    
    /// Applies the liquid background gradient
    func liquidBackground() -> some View {
        self.modifier(LiquidBackgroundModifier())
    }

    /// Applies a liquid list row background
    func liquidListRow(cornerRadius: CGFloat = LiquidTheme.cardCornerRadius) -> some View {
        self.modifier(LiquidListRowModifier(cornerRadius: cornerRadius))
    }

}

// MARK: - Preview Providers

#if DEBUG
struct PreviewWrapper: View {
    var body: some View {
        MainTabView()
    }
}

struct PreviewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
}
#endif
