import SwiftUI

// MARK: - Modern Card

struct ModernCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    let backgroundColor: Color?
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    init(
        cornerRadius: CGFloat = DesignSystem.CornerRadius.large,
        padding: CGFloat = DesignSystem.Spacing.base,
        backgroundColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor ?? Color(.systemBackground).opacity(colorScheme == .dark ? 0.68 : 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.34),
                                lineWidth: 1
                            )
                    )
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .withSmallShadow()
    }
}

// MARK: - Modern Progress Bar

struct ModernProgressBar: View {
    let progress: Double
    let style: ProgressStyle
    let height: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.gray.opacity(0.1))
                
                // Progress
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(style.color)
                    .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .stroke(style.color.opacity(0.5), lineWidth: 1)
                            .frame(width: geometry.size.width * CGFloat(min(max(progress, 0), 1)))
                    )
                    .animation(DesignSystem.Animation.swift, value: progress)
            }
        }
        .frame(height: height)
    }
    
    enum ProgressStyle {
        case primary
        case success
        case warning
        case error
        
        var color: Color {
            switch self {
            case .primary: return DesignSystem.Colors.primary
            case .success: return DesignSystem.Colors.success
            case .warning: return DesignSystem.Colors.warning
            case .error: return DesignSystem.Colors.error
            }
        }
    }
}

// MARK: - Modern Empty State

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.5))
                .padding(.top, DesignSystem.Spacing.xLarge)
            
            VStack(spacing: DesignSystem.Spacing.medium) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.base)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let style: BadgeStyle
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignSystem.Spacing.small)
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
            .foregroundColor(style.foregroundColor)
            .background(style.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small, style: .continuous))
    }
    
    enum BadgeStyle {
        case success
        case warning
        case error
        case info
        
        var backgroundColor: Color {
            switch self {
            case .success: return DesignSystem.Colors.success.opacity(0.15)
            case .warning: return DesignSystem.Colors.warning.opacity(0.15)
            case .error: return DesignSystem.Colors.error.opacity(0.15)
            case .info: return DesignSystem.Colors.primary.opacity(0.15)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .success: return DesignSystem.Colors.success
            case .warning: return DesignSystem.Colors.warning
            case .error: return DesignSystem.Colors.error
            case .info: return DesignSystem.Colors.primary
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let style: StatStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(style.color)
                
                Text(label)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(value)
                .font(DesignSystem.Typography.title3)
                .fontWeight(.bold)
        }
        .padding(DesignSystem.Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .fill(style.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .stroke(style.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    enum StatStyle {
        case primary
        case success
        case warning
        case error
        
        var color: Color {
            switch self {
            case .primary: return DesignSystem.Colors.primary
            case .success: return DesignSystem.Colors.success
            case .warning: return DesignSystem.Colors.warning
            case .error: return DesignSystem.Colors.error
            }
        }
    }
}
