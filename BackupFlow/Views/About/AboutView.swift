import SwiftUI

struct AboutView: View {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "externaldrive.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("BackupFlow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(String(format: "about.version_build".localized, appVersion, buildNumber))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(icon: "info.circle", title: "about.title".localized, description: "about.description".localized)
                        .padding()
                        .liquidCard(cornerRadius: 14)
                    
                    InfoRow(icon: "doc.text", title: "about.license".localized, description: "about.license_description".localized)
                        .padding()
                        .liquidCard(cornerRadius: 14)
                    
                    Button(action: {
                        openSupportEmail()
                    }) {
                        InfoRow(icon: "envelope", title: "about.contact".localized, description: "tamersavasci@icloud.com")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    .liquidCard(cornerRadius: 14)
                }
                .padding()
                
                Spacer(minLength: 60) // Tab bar için minimum boşluk
                
                VStack(spacing: 8) {
                    Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) BackupFlow")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("about.rights_reserved".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40) // Tab bar için extra padding
            }
            .padding()
        }
        .navigationTitle("about.title".localized)
        .liquidBackground()
    }
    
    private func openSupportEmail() {
        let email = "tamersavasci@icloud.com"
        let subject = "BackupFlow Support Request"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let deviceModel = UIDevice.current.model
        let iosVersion = UIDevice.current.systemVersion
        
        let body = """
        
        
        ---
        App Version: \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
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
            // Mail app yoksa, email adresini clipboard'a kopyala
            UIPasteboard.general.string = email
            print("📋 BackupFlow: Email adresi kopyalandı: \(email)")
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}
