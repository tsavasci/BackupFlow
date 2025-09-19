import SwiftUI

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