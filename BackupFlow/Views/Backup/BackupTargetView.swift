import SwiftUI
import SwiftData

struct BackupTargetView: View {
    @Binding var selectedTarget: BackupTarget
    
    // FTP Properties
    @Binding var ftpHost: String
    @Binding var ftpPort: String
    @Binding var ftpUsername: String
    @Binding var ftpPassword: String
    @Binding var destinationPath: String
    @Binding var isAnonymous: Bool
    
    // WebDAV Properties
    @Binding var webdavURL: String
    @Binding var webdavUsername: String
    @Binding var webdavPassword: String
    @Binding var webdavPath: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Target Type Picker (Tabs)
            Picker("Hedef Türü", selection: $selectedTarget) {
                ForEach(BackupTarget.allCases) { target in
                    Label(target.rawValue, systemImage: target.iconName)
                        .tag(target)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // FTP Configuration
            if selectedTarget == .ftp {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Sunucu Adresi", text: $ftpHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                        
                        TextField("Port (Varsayılan: 21)", text: $ftpPort)
                            .keyboardType(.numberPad)
                        
                        Toggle("Anonim Giriş", isOn: $isAnonymous)
                        
                        if !isAnonymous {
                            TextField("Kullanıcı Adı", text: $ftpUsername)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.username)
                            
                            SecureField("Şifre", text: $ftpPassword)
                                .textContentType(.password)
                        }
                        
                        TextField("Hedef Klasör", text: $destinationPath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                }
                .padding(.horizontal)
            } 
            // WebDAV Configuration
            else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Sunucu URL (örn: https://example.com/dav)", text: $webdavURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                        
                        TextField("Kullanıcı Adı", text: $webdavUsername)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.username)
                        
                        SecureField("Şifre", text: $webdavPassword)
                            .textContentType(.password)
                        
                        TextField("Hedef Klasör (isteğe bağlı)", text: $webdavPath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
    }
}

struct BackupTargetView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        @State private var selectedTarget: BackupTarget = .ftp
        @State private var ftpHost = ""
        @State private var ftpPort = "21"
        @State private var ftpUsername = ""
        @State private var ftpPassword = ""
        @State private var destinationPath = "/backup"
        @State private var isAnonymous = false
        
        @State private var webdavURL = ""
        @State private var webdavUsername = ""
        @State private var webdavPassword = ""
        @State private var webdavPath = "/remote.php/dav/files/"
        
        var body: some View {
            BackupTargetView(
                selectedTarget: $selectedTarget,
                ftpHost: $ftpHost,
                ftpPort: $ftpPort,
                ftpUsername: $ftpUsername,
                ftpPassword: $ftpPassword,
                destinationPath: $destinationPath,
                isAnonymous: $isAnonymous,
                webdavURL: $webdavURL,
                webdavUsername: $webdavUsername,
                webdavPassword: $webdavPassword,
                webdavPath: $webdavPath
            )
            .padding()
        }
    }
}
