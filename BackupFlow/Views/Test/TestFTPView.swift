import SwiftUI
import UserNotifications

#if DEBUG
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
            Section(header: Text("ftp.test.connection_info".localized)) {
                HStack {
                    Text("ftp.test.server_address".localized)
                    TextField("192.168.1.1", text: $ftpHost)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Text("ftp.test.port".localized)
                    TextField("21", text: $ftpPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    Text("ftp.test.username".localized)
                    TextField("task.details.anonymous".localized, text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                HStack {
                    Text("ftp.test.password".localized)
                    SecureField("", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Section(header: Text("ftp.test.connection_test".localized)) {
                Text("ftp.test.description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: startTest) {
                    HStack {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("ftp.test.start_test".localized)
                        Spacer()
                    }
                }
                .disabled(isTesting || ftpHost.isEmpty)
                
                if let result = testResult {
                    Text(result)
                        .foregroundColor(result.contains("✓") ? .green : (result.contains("✗") ? .red : .primary))
                        .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("ftp.test.results".localized)) {
                Text("ftp.test.success_info".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("ftp.test.error_info".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("ftp.test.title".localized)
        .alert("ftp.test.completed".localized, isPresented: $showAlert) {
            Button("alert.ok".localized) {}
        } message: {
            if let result = testResult {
                Text(result)
            } else {
                Text("ftp.test.completed_message".localized)
            }
        }
    }
    
    private func startTest() {
        Task {
            isTesting = true
            testResult = nil
            
            // Validate port
            guard let port = Int(ftpPort), port > 0, port <= 65535 else {
                await MainActor.run {
                    testResult = "ftp.test.invalid_port".localized
                    isTesting = false
                }
                return
            }
            
            // Show initial notification
            let content = UNMutableNotificationContent()
            content.title = "ftp.test.starting".localized
            content.body = "ftp.test.starting_message".localized
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
            
            // Wait a second to show notification
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            do {
                _ = try await FTPService.shared.testConnection(host: ftpHost, port: port, username: username, password: password)
                
                await MainActor.run {
                    testResult = "ftp.test.success".localized
                    isTesting = false
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    testResult = "ftp.test.failed".localized + " " + error.localizedDescription
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
#endif
