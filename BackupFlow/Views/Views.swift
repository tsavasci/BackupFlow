import SwiftUI

// MARK: - App Surface Theme

struct LiquidTheme {
    static let cardCornerRadius: CGFloat = 18
    static let cardStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.65),
            Color.white.opacity(0.25),
            Color.white.opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let subtleStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.35),
            Color.white.opacity(0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct LiquidBackgroundModifier: ViewModifier {
    // systemBackground adapts to light/dark mode on its own.
    private let gradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.systemBackground).opacity(0.94)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    func body(content: Content) -> some View {
        content.background(gradient.ignoresSafeArea())
    }
}

private struct LiquidListRowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.listRowBackground(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? LiquidTheme.subtleStroke : LiquidTheme.cardStroke,
                            lineWidth: colorScheme == .dark ? 0.8 : 0.9
                        )
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
