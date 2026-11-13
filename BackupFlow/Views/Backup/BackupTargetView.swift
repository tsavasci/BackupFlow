import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @Binding var sftpAuthMethod: SFTPAuthMethod
    @Binding var sftpPrivateKey: String
    @Binding var sftpKeyPassphrase: String
    @Binding var sftpKeyName: String
    @Binding var sftpPath: String

    @State private var showingKeyImporter = false
    @State private var keyImportError: String?

    // WebDAV Properties
    @Binding var webdavURL: String
    @Binding var webdavPort: String
    @Binding var webdavUsername: String
    @Binding var webdavPassword: String
    @Binding var webdavPath: String

    var body: some View {
        VStack(spacing: 14) {
            // Target Type Picker (Tabs)
            Picker("backup.target_type".localized, selection: $selectedTarget) {
                ForEach(BackupTarget.allCases) { target in
                    Label(target.displayName, systemImage: target.iconName)
                        .tag(target)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            // FTP Configuration
            if selectedTarget == .ftp {
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
            }
            // SFTP Configuration
            else if selectedTarget == .sftp {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("backup.server_address".localized, text: $sftpHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .keyboardType(.URL)

                    TextField("backup.port_sftp_default".localized, text: $sftpPort)
                        .keyboardType(.numberPad)

                    TextField("backup.username".localized, text: $sftpUsername)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.username)

                    Picker("backup.sftp_auth_method".localized, selection: $sftpAuthMethod) {
                        Text("backup.sftp_auth_password".localized).tag(SFTPAuthMethod.password)
                        Text("backup.sftp_auth_private_key".localized).tag(SFTPAuthMethod.privateKey)
                    }
                    .pickerStyle(.segmented)

                    if sftpAuthMethod == .password {
                        SecureField("backup.password".localized, text: $sftpPassword)
                            .textContentType(.password)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Button {
                                    showingKeyImporter = true
                                } label: {
                                    Label("backup.sftp_import_key".localized, systemImage: "key.fill")
                                }
                                .buttonStyle(.bordered)

                                if !sftpPrivateKey.isEmpty {
                                    let displayName = sftpKeyName.isEmpty ? "SSH" : sftpKeyName
                                    Label("backup.sftp_key_loaded".localized(with: displayName), systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.Colors.success)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            SecureField("backup.sftp_key_passphrase".localized, text: $sftpKeyPassphrase)
                                .textContentType(.password)

                            if let keyImportError {
                                Text(keyImportError)
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.Colors.error)
                            }
                        }
                        .fileImporter(
                            isPresented: $showingKeyImporter,
                            allowedContentTypes: [.data, .plainText, .item],
                            allowsMultipleSelection: false
                        ) { result in
                            handleKeyImport(result)
                        }
                    }

                    TextField("backup.destination_folder".localized, text: $sftpPath)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Text("sftp.tofu_notice".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            // WebDAV Configuration
            else {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("backup.server_url_example".localized, text: $webdavURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .keyboardType(.URL)

                    TextField("backup.port_webdav_default".localized, text: $webdavPort)
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
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func handleKeyImport(_ result: Result<[URL], Error>) {
        keyImportError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let pem = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !pem.isEmpty else {
                    keyImportError = "backup.sftp_key_import_failed".localized
                    return
                }
                sftpPrivateKey = pem
                sftpKeyName = url.lastPathComponent
            } catch {
                keyImportError = "backup.sftp_key_import_failed".localized
            }
        case .failure:
            keyImportError = "backup.sftp_key_import_failed".localized
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
        @State private var sftpAuthMethod: SFTPAuthMethod = .password
        @State private var sftpPrivateKey = ""
        @State private var sftpKeyPassphrase = ""
        @State private var sftpKeyName = ""
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
                sftpAuthMethod: $sftpAuthMethod,
                sftpPrivateKey: $sftpPrivateKey,
                sftpKeyPassphrase: $sftpKeyPassphrase,
                sftpKeyName: $sftpKeyName,
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
