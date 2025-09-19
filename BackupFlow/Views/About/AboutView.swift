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
                
                Text("Sürüm \(appVersion) (Yapı \(buildNumber))")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(icon: "info.circle", title: "Hakkında", description: "BackupFlow, önemli dosyalarınızı esnek zamanlama seçenekleriyle FTP sunucularına kolayca yedeklemenize yardımcı olur.")
                    
                    InfoRow(icon: "doc.text", title: "Lisans", description: "Bu uygulama MIT Lisansı altında sağlanmaktadır.")
                    
                    InfoRow(icon: "envelope", title: "İletişim", description: "destek@example.com")
                }
                .padding()
                
                Spacer(minLength: 60) // Tab bar için minimum boşluk
                
                VStack(spacing: 8) {
                    Text("© \(Calendar.current.component(.year, from: Date())) BackupFlow")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Tüm hakları saklıdır")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40) // Tab bar için extra padding
            }
            .padding()
        }
        .navigationTitle("Hakkında")
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
