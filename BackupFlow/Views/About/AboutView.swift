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
                            title: "Hakkında",
                            icon: "info.circle.fill",
                            content: {
                                Text("BackupFlow, dosyalarınızı FTP, SFTP ve WebDAV sunucularına otomatik olarak yedeklemek için tasarlanmıştır. Güvenli, hızlı ve güvenilir yedekleme çözümü.")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                            }
                        )
                        
                        // Features Section
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                            HStack(spacing: DesignSystem.Spacing.small) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("Özellikler")
                                    .font(DesignSystem.Typography.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                                FeatureRow(icon: "shield.fill", text: "Güvenli şifreleme ve bağlantı")
                                FeatureRow(icon: "clock.fill", text: "Otomatik zamanlanmış yedeklemeler")
                                FeatureRow(icon: "bolt.fill", text: "Hızlı ve etkili dosya senkronizasyonu")
                                FeatureRow(icon: "globe", text: "FTP, SFTP ve WebDAV desteği")
                                FeatureRow(icon: "checkmark.circle.fill", text: "Akıllı dosya filtreleme")
                                FeatureRow(icon: "chart.bar.fill", text: "Detaylı geçmiş ve istatistikler")
                            }
                        }
                        .padding(DesignSystem.Spacing.base)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous)
                                .fill(Color.gray.opacity(0.05))
                        )
                        
                        // Support Section
                        SectionCard(
                            title: "Destek",
                            icon: "envelope.circle.fill",
                            content: {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.medium) {
                                    Text("Sorularınız veya önerileriniz mi var? Bize iletişim kurabilirsiniz.")
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
                            title: "Lisans",
                            icon: "doc.text.fill",
                            content: {
                                Text("BackupFlow, MIT Lisansı altında dağıtılmaktadır. Yazılımı özgürce kullanabilir, değiştirebilir ve dağıtabilirsiniz.")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                            }
                        )
                        
                        // Footer
                        VStack(spacing: DesignSystem.Spacing.small) {
                            Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) BackupFlow")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(.secondary)
                            
                            Text("Tüm hakları saklıdır.")
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
        let subject = "BackupFlow Destek İsteği"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        
        let body = """
        
        
        ---
        Uygulama Sürümü: \(appVersion) (\(buildNumber))
        Cihaz: \(deviceModel)
        iOS: \(iosVersion)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoURL = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"
        
        guard let url = URL(string: mailtoURL) else {
            print("❌ BackupFlow: Geçersiz email URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            print("📧 BackupFlow: Destek email'i açılıyor")
        } else {
            UIPasteboard.general.string = email
            print("📋 BackupFlow: Email adresi kopyalandı: \(email)")
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
