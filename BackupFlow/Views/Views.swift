import SwiftUI

// MARK: - Liquid Theme

struct LiquidTheme {
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.95)
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.97, blue: 0.99),
            Color(red: 0.92, green: 0.95, blue: 0.99),
            Color(red: 0.95, green: 0.94, blue: 0.99)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowColor = Color.black.opacity(0.12)
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowOffset = CGSize(width: 0, height: 6)
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
        self.background(
            LiquidTheme.backgroundGradient
                .ignoresSafeArea()
        )
    }

    /// Applies a liquid card style with glass effect
    func liquidCard(cornerRadius: CGFloat = LiquidTheme.cardCornerRadius) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LiquidTheme.cardStroke, lineWidth: 1)
                )
        )
        .shadow(
            color: LiquidTheme.cardShadowColor,
            radius: LiquidTheme.cardShadowRadius,
            x: LiquidTheme.cardShadowOffset.width,
            y: LiquidTheme.cardShadowOffset.height
        )
    }

    /// Applies a liquid list row background
    func liquidListRow(cornerRadius: CGFloat = LiquidTheme.cardCornerRadius) -> some View {
        self.listRowBackground(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LiquidTheme.subtleStroke, lineWidth: 0.8)
                )
        )
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
