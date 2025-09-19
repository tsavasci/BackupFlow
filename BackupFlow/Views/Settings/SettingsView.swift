import SwiftUI

struct SettingsView: View {
    @State private var isTesting = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoStartBackup") private var autoStartBackup = true
    @AppStorage("keepHistoryDays") private var keepHistoryDays = 30
    
    var body: some View {
        Form {
            Section(header: Text("Genel")) {
                Toggle("Bildirimleri Etkinleştir", isOn: $notificationsEnabled)
                Toggle("Başlangıçta Otomatik Başlat", isOn: $autoStartBackup)
                
                Picker("Geçmişi Saklama Süresi (Gün)", selection: $keepHistoryDays) {
                    Text("7 Gün").tag(7)
                    Text("30 Gün").tag(30)
                    Text("90 Gün").tag(90)
                    Text("Süresiz").tag(0)
                }
            }
            
            Section(header: Text("Hakkında")) {
                HStack {
                    Text("Sürüm")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    // TODO: Open app review page
                }) {
                    Text("Uygulamayı Değerlendir")
                }
                
                Button(action: {
                    // TODO: Open support email
                }) {
                    Text("Destekle İletişime Geç")
                }
            }
            
            Section(header: Text("Geliştirici Ayarları")) {
                NavigationLink(destination: TestFTPView()) {
                    Label("FTP Bağlantı Testi", systemImage: "network")
                }
            }
            
            Section {
                Button(role: .destructive) {
                    // TODO: Clear all data
                } label: {
                    HStack {
                        Spacer()
                        Text("Tüm Verileri Sıfırla")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Ayarlar")
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
