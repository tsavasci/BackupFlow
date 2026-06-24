import SwiftUI

struct AboutView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    @State private var showContactAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.large) {
                        // App Logo and Title
                        VStack(spacing: DesignSystem.Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.primaryGradient)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, DesignSystem.Spacing.xLarge)
                            
                            Text("BackupFlow")
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                            
                            Text(String(format: "v%@ (%@)", appVersion, buildNumber))
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // About Section
                        SectionCard(
                            title: "about.section.about".localized,
                            icon: "info.circle.fill",
                            content: {
                                Text("about.description".localized)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                            }
                        )
                        
                        // Features Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                            HStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("about.features.title".localized)
                                    .font(DesignSystem.Typography.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                FeatureRow(icon: "shield.fill", text: "about.feature.security".localized)
                                FeatureRow(icon: "clock.fill", text: "about.feature.scheduled".localized)
                                FeatureRow(icon: "bolt.fill", text: "about.feature.fast_sync".localized)
                                FeatureRow(icon: "globe", text: "about.feature.protocols".localized)
                                FeatureRow(icon: "checkmark.circle.fill", text: "about.feature.smart_filtering".localized)
                                FeatureRow(icon: "chart.bar.fill", text: "about.feature.history_stats".localized)
                            }
                        }
                        .padding(DesignSystem.Spacing.base)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(Color.gray.opacity(0.05))
                        )
                        
                        // Support Section
                        SectionCard(
                            title: "about.section.support".localized,
                            icon: "envelope.circle.fill",
                            content: {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                                    Text("about.support.description".localized)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: { openSupportEmail() }) {
                                        HStack(spacing: DesignSystem.Spacing.small) {
                                            Image(systemName: "envelope.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("tamersavasci@icloud.com")
                                                .font(DesignSystem.Typography.callout)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(DesignSystem.Spacing.base)
                                        .background(DesignSystem.Colors.primary.opacity(0.1))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium, style: .continuous))
                                    }
                                }
                            }
                        )
                        
                        // License Section
                        SectionCard(
                            title: "about.section.license".localized,
                            icon: "doc.text.fill",
                            content: {
                                Text("about.license.description".localized)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                            }
                        )
                        
                        // Footer
                        VStack(spacing: DesignSystem.Spacing.small) {
                            Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) BackupFlow")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                            
                            Text("about.rights_reserved".localized)
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, DesignSystem.Spacing.xLarge)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.base)
                    .padding(.vertical, DesignSystem.Spacing.base)
                }
                .navigationTitle("about.title".localized)
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }
    
    private func openSupportEmail() {
        let email = "tamersavasci@icloud.com"
        let subject = "about.support.email_subject".localized
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        
        let body = """
        
        
        ---
        \("about.support.email_app_version".localized): \(appVersion) (\(buildNumber))
        \("about.support.email_device".localized): \(deviceModel)
        iOS: \(iosVersion)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else {
            debugLog("❌ BackupFlow: Geçersiz email URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            debugLog("📧 BackupFlow: Destek email'i açılıyor")
        } else {
            UIPasteboard.general.string = email
            debugLog("📋 BackupFlow: Email adresi kopyalandı: \(email)")
        }
    }
}

// MARK: - Section Card Component

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: icon)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(DesignSystem.Typography.headline)
                
                Spacer()
            }
            
            content
        }
        .padding(DesignSystem.Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
