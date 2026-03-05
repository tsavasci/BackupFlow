import SwiftUI
import SwiftData
import Photos
import UniformTypeIdentifiers

@MainActor
class BackupViewModel: ObservableObject {
    // MARK: - Constants
    static let defaultFTPHost = "192.168.1.1"
    static let defaultWebDAVPath = "/remote.php/dav/files/"

    // MARK: - Source State
    @Published var selectedURL: URL?
    @Published var isPhotoLibrarySelected = false
    @Published var selectedMediaType: MediaType = .photosOnly

    // MARK: - Target State
    @Published var selectedTarget: BackupTarget = .ftp

    // FTP Settings
    @Published var ftpHost = defaultFTPHost
    @Published var ftpPort = "21"
    @Published var ftpUsername = ""
    @Published var ftpPassword = ""
    @Published var isAnonymous = false
    @Published var destinationPath = "/"

    // SFTP Settings
    @Published var sftpHost = ""
    @Published var sftpPort = "22"
    @Published var sftpUsername = ""
    @Published var sftpPassword = ""
    @Published var sftpPath = ""

    // WebDAV Settings
    @Published var webdavURL = ""
    @Published var webdavPort = "443"
    @Published var webdavUsername = ""
    @Published var webdavPassword = ""
    @Published var webdavPath = defaultWebDAVPath

    // MARK: - Scheduling State
    @Published var frequencyType: BackupFrequency = .manual
    @Published var selectedTime = ScheduleTime(hour: 0, minute: 0)
    @Published var selectedDay = 1
    @Published var allowCellularForLocalServer = false

    // MARK: - UI State
    @Published var showingDocumentPicker = false
    @Published var showingSaveAlert = false
    @Published var showingPhotoLibraryDeniedAlert = false
    @Published var saveAlertMessage = ""
    @Published var isTestingConnection = false
    @Published var connectionStatus: ConnectionStatus = .idle
    @Published var showingFirstBackupPrompt = false
    @Published var showingSFTPHostKeyAlert = false
    @Published var sftpHostKeyAlertMessage = ""
    
    var lastAlertAt: Date?
    var lastTestTapAt: Date?
    var firstBackupTaskToStart: BackupTask?

    // MARK: - Helper Methods
    
    func isLocalServer() -> Bool {
        let host: String
        switch selectedTarget {
        case .ftp: host = ftpHost
        case .sftp: host = sftpHost
        case .webdav: host = webdavURL
        }
        
        let hostname: String
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            hostname = URL(string: host)?.host ?? host
        } else {
            hostname = host
        }
        
        let localPatterns = ["^192\\.168\\.", "^10\\.", "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.", "^127\\.", "localhost"]
        return localPatterns.contains { hostname.range(of: $0, options: .regularExpression) != nil }
    }
    
    func isValidConnectionSettings() -> Bool {
        switch selectedTarget {
        case .ftp: return !ftpHost.isEmpty && (isAnonymous || (!ftpUsername.isEmpty && !ftpPassword.isEmpty))
        case .sftp: return !sftpHost.isEmpty && !sftpUsername.isEmpty && !sftpPassword.isEmpty
        case .webdav: return !webdavURL.isEmpty && !webdavUsername.isEmpty
        }
    }

    func resetForm() {
        selectedURL = nil
        isPhotoLibrarySelected = false
        selectedMediaType = .photosOnly
        ftpHost = Self.defaultFTPHost
        ftpPort = "21"
        ftpUsername = ""
        ftpPassword = ""
        isAnonymous = false
        destinationPath = "/"
        sftpHost = ""
        sftpPort = "22"
        sftpUsername = ""
        sftpPassword = ""
        sftpPath = ""
        webdavURL = ""
        webdavPort = "443"
        webdavUsername = ""
        webdavPassword = ""
        webdavPath = Self.defaultWebDAVPath
        frequencyType = .manual
        selectedTime = ScheduleTime(hour: 0, minute: 0)
        selectedDay = 1
        connectionStatus = .idle
        saveAlertMessage = ""
    }

    func testConnection() async {
        if isTestingConnection { return }
        let now = Date()
        if let last = lastTestTapAt, now.timeIntervalSince(last) < 2 { return }
        lastTestTapAt = now

        guard isValidConnectionSettings() else {
            let errorMessage = selectedTarget == .ftp ? "backup.fill_required_fields".localized :
                (selectedTarget == .sftp ? "backup.fill_required_fields".localized : "backup.webdav_credentials_required".localized)
            connectionStatus = .failure(errorMessage)
            return
        }
        
        isTestingConnection = true
        connectionStatus = .testing("backup.testing_network".localized)
        
        do {
            switch selectedTarget {
            case .ftp:
                try await FTPService.shared.connect(host: ftpHost, port: Int(ftpPort) ?? 21, username: isAnonymous ? nil : ftpUsername, password: isAnonymous ? nil : ftpPassword)
                connectionStatus = .success("backup.connection_success_ftp".localized)
            case .sftp:
                let result = try await SFTPService.shared.testConnection(host: sftpHost, port: Int(sftpPort) ?? 22, username: sftpUsername, password: sftpPassword)
                connectionStatus = .success("backup.connection_success_sftp".localized)
                if result.isNewHostKey, let fingerprint = result.fingerprint {
                    sftpHostKeyAlertMessage = String(format: "sftp.hostkey_message".localized, fingerprint)
                    showingSFTPHostKeyAlert = true
                }
            case .webdav:
                let (host, port) = parseWebDAVURL(webdavURL, portOverride: webdavPort)
                let isConnected = await WebDAVService.shared.testConnection(host: host, port: port, username: webdavUsername, password: webdavPassword)
                if isConnected {
                    connectionStatus = .success("backup.connection_success_webdav".localized)
                } else {
                    throw NSError(domain: "WebDAV Error", code: -1, userInfo: [NSLocalizedDescriptionKey: WebDAVService.shared.lastError?.localizedDescription ?? "backup.connection_error".localized])
                }
            }
        } catch {
            connectionStatus = .failure(String(format: "backup.connection_error".localized, error.localizedDescription))
        }
        isTestingConnection = false
    }

    func saveTask(modelContext: ModelContext) async {
        guard isPhotoLibrarySelected || selectedURL != nil else {
            showAlert(message: "backup.source_required".localized)
            return
        }
        
        if isPhotoLibrarySelected {
            let status = PHPhotoLibrary.authorizationStatus()
            guard status == .authorized || status == .limited else {
                showAlert(message: "backup.photo_permission_required".localized)
                return
            }
        }
        
        let sourcePath = isPhotoLibrarySelected ? "PHOTOS_LIBRARY" : (selectedURL?.path ?? "")
        let displayNameValue = isPhotoLibrarySelected ? selectedMediaType.displayName : (selectedURL?.lastPathComponent ?? "backup.default_task_name".localized)
        
        let task = BackupTask(
            sourcePath: sourcePath,
            backupType: selectedTarget == .ftp ? .ftp : (selectedTarget == .sftp ? .sftp : .webdav),
            serverHost: selectedTarget == .ftp ? ftpHost : (selectedTarget == .sftp ? sftpHost : webdavURL),
            serverPort: Int(selectedTarget == .ftp ? ftpPort : (selectedTarget == .sftp ? sftpPort : webdavPort)) ?? 21,
            serverUsername: selectedTarget == .ftp ? (isAnonymous ? "" : ftpUsername) : (selectedTarget == .sftp ? sftpUsername : webdavUsername),
            serverPassword: selectedTarget == .ftp ? (isAnonymous ? "" : ftpPassword) : (selectedTarget == .sftp ? sftpPassword : webdavPassword),
            destinationPath: selectedTarget == .ftp ? destinationPath : (selectedTarget == .sftp ? sftpPath : webdavPath),
            displayName: displayNameValue,
            frequency: frequencyType,
            scheduledTime: frequencyType != .manual ? selectedTime : nil,
            scheduledWeekday: {
                if case .weekly(let day, _) = frequencyType { return day }
                return nil
            }(),
            mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
            allowCellularForLocalServer: allowCellularForLocalServer
        )

        modelContext.insert(task)
        do {
            try modelContext.save()
            saveAlertMessage = "tasks.save_success".localized
            if frequency != .manual {
                try? await BackupScheduler.shared.scheduleBackup(task: task)
                saveAlertMessage += " " + "tasks.scheduled".localized
            }
            resetForm()
            showAlert(message: saveAlertMessage)
        } catch {
            showAlert(message: "tasks.save_error_detail".localized(with: error.localizedDescription))
        }
    }

    private func showAlert(message: String) {
        let now = Date()
        if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
        lastAlertAt = now
        saveAlertMessage = message
        showingSaveAlert = true
    }

    private func parseWebDAVURL(_ urlString: String, portOverride: String) -> (host: String, port: Int) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let overridePort = Int(portOverride)
        guard !trimmed.isEmpty else { return ("", overridePort ?? 443) }
        let lowerTrimmed = trimmed.lowercased()
        let hasScheme = lowerTrimmed.hasPrefix("http://") || lowerTrimmed.hasPrefix("https://")
        let schemeFromPort = (overridePort == 5005 || overridePort == 80) ? "http" : "https"
        let withScheme = hasScheme ? trimmed : "\(schemeFromPort)://\(trimmed)"
        if let components = URLComponents(string: withScheme) {
            let host = components.host ?? trimmed
            let port = components.port ?? overridePort ?? (components.scheme == "http" ? 80 : 443)
            return ("\(components.scheme ?? schemeFromPort)://\(host)\(components.path)", port)
        }
        return (trimmed, overridePort ?? 443)
    }
}
