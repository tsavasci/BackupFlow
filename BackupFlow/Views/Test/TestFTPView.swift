import SwiftUI
import UserNotifications

struct TestFTPView: View {
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var showAlert = false
    @State private var ftpHost = "192.168.1.1"
    @State private var ftpPort = "21"
    @State private var username = "anonymous"
    @State private var password = ""
    
    var body: some View {
        Form {
            Section(header: Text("FTP Bağlantı Bilgileri")) {
                HStack {
                    Text("Sunucu Adresi:")
                    TextField("192.168.1.1", text: $ftpHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Text("Port:")
                    TextField("21", text: $ftpPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("Kullanıcı Adı:")
                    TextField("anonymous", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Text("Şifre:")
                    SecureField("", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Section(header: Text("FTP Bağlantı Testi")) {
                Text("Bu test, FTP sunucusuna bağlanıp küçük bir test dosyası yükleyecektir.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: startTest) {
                    HStack {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("Testi Başlat")
                        Spacer()
                    }
                }
                .disabled(isTesting || ftpHost.isEmpty)
                
                if let result = testResult {
                    Text(result)
                        .foregroundColor(result.contains("başarılı") ? .green : .red)
                        .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("Test Sonuçları")) {
                Text("• Başarılı bir test, FTP sunucusuna bağlanabildiğinizi ve dosya yükleyebildiğinizi gösterir.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Hata alırsanız, FTP ayarlarınızı ve internet bağlantınızı kontrol edin.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("FTP Testi")
        .alert("Test Tamamlandı", isPresented: $showAlert) {
            Button("Tamam") {}
        } message: {
            if let result = testResult {
                Text(result)
            } else {
                Text("Test tamamlandı.")
            }
        }
    }
    
    private func startTest() {
        Task {
            isTesting = true
            testResult = nil
            
            let scheduler = BackupScheduler.shared
            
            // Validate port
            guard let port = Int(ftpPort), port > 0, port <= 65535 else {
                await MainActor.run {
                    testResult = "✗ Hatalı port numarası. 1-65535 arasında bir değer girin."
                    isTesting = false
                }
                return
            }
            
            // Show notification
            let content = UNMutableNotificationContent()
            content.title = "Test Başlatılıyor"
            content.body = "FTP bağlantı testi başlatılıyor..."
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
            
            // Wait a second to show notification
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            do {
                try await scheduler.testFTPUpload(host: ftpHost, port: port, username: username, password: password)
                
                await MainActor.run {
                    testResult = "✓ Test başarılı! FTP sunucusuna bağlanıp dosya yükleyebildiniz."
                    isTesting = false
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    testResult = "✗ Test başarısız: \(error.localizedDescription)"
                    isTesting = false
                    showAlert = true
                }
            }
        }
    }
}

struct TestFTPView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TestFTPView()
        }
    }
}
