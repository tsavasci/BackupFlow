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
    
    // SFTP Properties
    @Binding var sftpHost: String
    @Binding var sftpPort: String
    @Binding var sftpUsername: String
    @Binding var sftpPassword: String
    @Binding var sftpPath: String
    
    // WebDAV Properties
    @Binding var webdavURL: String
    @Binding var webdavPort: String
    @Binding var webdavUsername: String
    @Binding var webdavPassword: String
    @Binding var webdavPath: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Target Type Picker (Tabs)
            Picker("backup.target_type".localized, selection: $selectedTarget) {
                ForEach(BackupTarget.allCases) { target in
                    Label(target.displayName, systemImage: target.iconName)
                        .tag(target)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // FTP Configuration
            if selectedTarget == .ftp {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("backup.server_address".localized, text: $ftpHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                        
                        TextField("backup.port_default".localized, text: $ftpPort)
                            .keyboardType(.numberPad)
                        
                        Toggle("backup.anonymous_login".localized, isOn: $isAnonymous)
                        
                        if !isAnonymous {
                            TextField("backup.username".localized, text: $ftpUsername)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textContentType(.username)
                            
                            SecureField("backup.password".localized, text: $ftpPassword)
                                .textContentType(.password)
                        }
                        
                        TextField("backup.destination_folder".localized, text: $destinationPath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding()
                }
                .padding(.horizontal)
            } 
            // SFTP Configuration
            else if selectedTarget == .sftp {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("backup.server_address".localized, text: $sftpHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                        
                        TextField("backup.port_default".localized, text: $sftpPort)
                            .keyboardType(.numberPad)
                        
                        TextField("backup.username".localized, text: $sftpUsername)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.username)

                        SecureField("backup.password".localized, text: $sftpPassword)
                            .textContentType(.password)
                        
                        TextField("backup.destination_folder".localized, text: $sftpPath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Text("sftp.tofu_notice".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            // WebDAV Configuration
            else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("backup.server_url_example".localized, text: $webdavURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .keyboardType(.URL)

                        TextField("backup.port_default".localized, text: $webdavPort)
                            .keyboardType(.numberPad)
                        
                        TextField("backup.username".localized, text: $webdavUsername)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.username)
                        
                        SecureField("backup.password".localized, text: $webdavPassword)
                            .textContentType(.password)
                        
                        TextField("backup.destination_folder_optional".localized, text: $webdavPath)
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
        
        @State private var sftpHost = ""
        @State private var sftpPort = "22"
        @State private var sftpUsername = ""
        @State private var sftpPassword = ""
        @State private var sftpPath = ""
        
        @State private var webdavURL = ""
        @State private var webdavPort = "443"
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
                sftpHost: $sftpHost,
                sftpPort: $sftpPort,
                sftpUsername: $sftpUsername,
                sftpPassword: $sftpPassword,
                sftpPath: $sftpPath,
                webdavURL: $webdavURL,
                webdavPort: $webdavPort,
                webdavUsername: $webdavUsername,
                webdavPassword: $webdavPassword,
                webdavPath: $webdavPath
            )
            .padding()
        }
    }
}
