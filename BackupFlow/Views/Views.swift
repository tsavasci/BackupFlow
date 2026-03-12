import SwiftUI

// MARK: - Liquid Theme

struct LiquidTheme {
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.95)
    static let cardCornerRadius: CGFloat = 16
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
    @Environment(\.colorScheme) private var colorScheme

    private var gradient: LinearGradient {
        switch colorScheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.06, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.92, green: 0.95, blue: 0.99),
                    Color(red: 0.95, green: 0.94, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func body(content: Content) -> some View {
        content.background(gradient.ignoresSafeArea())
    }
}

private struct LiquidCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.12)
    }

    private var fillMaterial: Material {
        colorScheme == .dark ? .regularMaterial : .ultraThinMaterial
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? LiquidTheme.subtleStroke : LiquidTheme.cardStroke,
                                lineWidth: colorScheme == .dark ? 0.8 : 1
                            )
                    )
            )
            .shadow(color: shadowColor, radius: colorScheme == .dark ? 18 : 14, x: 0, y: colorScheme == .dark ? 8 : 6)
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
    /// Applies the default navigation styling
    func withNavigationStyle() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
    }
    
    /// Applies the default background color
    func appBackground() -> some View {
        self.background(Color(.systemGroupedBackground))
    }

    /// Applies the liquid background gradient
    func liquidBackground() -> some View {
        self.modifier(LiquidBackgroundModifier())
    }

    /// Applies a liquid card style with glass effect
    func liquidCard(cornerRadius: CGFloat = LiquidTheme.cardCornerRadius) -> some View {
        self.modifier(LiquidCardModifier(cornerRadius: cornerRadius))
    }

    /// Applies a liquid list row background
    func liquidListRow(cornerRadius: CGFloat = LiquidTheme.cardCornerRadius) -> some View {
        self.modifier(LiquidListRowModifier(cornerRadius: cornerRadius))
    }

    /// Applies a liquid section header style
    func liquidSectionHeader() -> some View {
        self.font(.caption)
            .foregroundStyle(.secondary)
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
