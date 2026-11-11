import Foundation
import Observation
import Photos

/// Editable fields of the backup setup form, kept apart from the view's alert and sheet state.
@MainActor
@Observable
final class BackupFormModel {
    // Varsayılan ayarlar
    static let defaultFTPHost = ""
    static let defaultWebDAVPath = "/"
    static let legacyDefaultWebDAVPath = "/remote.php/dav/files/"

    // Kaynak
    var selectedURL: URL?
    var isPhotoLibrarySelected = false
    var selectedMediaType: MediaType = .photosOnly
    var includeICloudAssets = true
    var photoFolderStructure: PhotoFolderStructure = .flat
    var preserveOriginalPhotoFormat = false

    // Hedef seçimi
    var selectedTarget: BackupTarget = .ftp

    // FTP ayarları
    var ftpHost = defaultFTPHost
    var ftpPort = "21"
    var ftpUsername = ""
    var ftpPassword = ""
    var isAnonymous = false
    var destinationPath = "/"

    // SFTP ayarları
    var sftpHost = ""
    var sftpPort = "22"
    var sftpUsername = ""
    var sftpPassword = ""
    var sftpPath = ""

    // WebDAV ayarları
    var webdavURL = ""
    var webdavPort = "443"
    var webdavUsername = ""
    var webdavPassword = ""
    var webdavPath = defaultWebDAVPath

    // Zamanlama
    var frequencyType: FrequencyType = .manual
    var selectedTime = ScheduleTime(hour: 0, minute: 0)
    var selectedDay = 1 // 1: Sunday, 2: Monday, ..., 7: Saturday
    var selectedMonthDay = 1
    var intervalHours = 6

    // Davranış
    var allowCellularForLocalServer = false // Network policy
    // Never delete remote files unless the user opts into mirroring.
    var deletionPolicy: BackupDeletionPolicy = .appendOnly
    var checksumMode: BackupChecksumMode = .off
    var requiresWiFi = false
    var requiresExternalPower = false
    var useAllowedWindow = false
    var allowedStartTime = ScheduleTime(hour: 23, minute: 0)
    var allowedEndTime = ScheduleTime(hour: 6, minute: 0)

    /// Starts with defaults, or with the values of `task` when editing.
    init(editingTask task: BackupTask? = nil) {
        guard let task else { return }

        selectedURL = task.sourcePath == "PHOTOS_LIBRARY" ? nil : URL(fileURLWithPath: task.sourcePath ?? "")
        isPhotoLibrarySelected = task.sourcePath == "PHOTOS_LIBRARY"
        selectedMediaType = task.mediaType
        includeICloudAssets = task.includeICloudAssets
        photoFolderStructure = task.photoFolderStructure
        preserveOriginalPhotoFormat = task.preserveOriginalPhotoFormat
        switch task.backupType {
        case .ftp: selectedTarget = .ftp
        case .sftp: selectedTarget = .sftp
        case .webdav: selectedTarget = .webdav
        }

        // Only the task's own protocol is filled in; the other tabs keep their defaults.
        switch task.backupType {
        case .ftp:
            ftpHost = task.serverHost
            ftpPort = "\(task.serverPort)"
            ftpUsername = task.serverUsername
            isAnonymous = task.isAnonymous
            destinationPath = task.destinationPath
        case .sftp:
            sftpHost = task.serverHost
            sftpPort = "\(task.serverPort)"
            sftpUsername = task.serverUsername
            sftpPath = task.destinationPath
        case .webdav:
            webdavURL = task.serverHost
            webdavPort = "\(task.serverPort)"
            webdavUsername = task.serverUsername
            webdavPath = task.destinationPath
        }

        allowCellularForLocalServer = task.allowCellularForLocalServer
        deletionPolicy = task.deletionPolicy
        checksumMode = task.checksumMode
        requiresWiFi = task.requiresWiFi
        requiresExternalPower = task.requiresExternalPower
        useAllowedWindow = task.allowedStartTime != nil && task.allowedEndTime != nil
        allowedStartTime = task.allowedStartTime ?? ScheduleTime(hour: 23, minute: 0)
        allowedEndTime = task.allowedEndTime ?? ScheduleTime(hour: 6, minute: 0)

        switch task.frequency {
        case .manual:
            frequencyType = .manual
        case .daily(let time):
            frequencyType = .daily
            selectedTime = time
        case .weekly(let day, let time):
            frequencyType = .weekly
            selectedDay = day
            selectedTime = time
        case .monthly(let day, let time):
            frequencyType = .monthly
            selectedMonthDay = day
            selectedTime = time
        case .intervalHours(let hours):
            frequencyType = .intervalHours
            intervalHours = hours
        }
    }

    /// Clears the form for a new entry. The chosen target and the cellular
    /// setting are kept, as the form's Clear button always has.
    func reset() {
        selectedURL = nil
        isPhotoLibrarySelected = false
        selectedMediaType = .photosOnly
        includeICloudAssets = true
        photoFolderStructure = .flat
        preserveOriginalPhotoFormat = false
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
        selectedMonthDay = 1
        intervalHours = 6
        deletionPolicy = .appendOnly
        checksumMode = .off
        requiresWiFi = false
        requiresExternalPower = false
        useAllowedWindow = false
        allowedStartTime = ScheduleTime(hour: 23, minute: 0)
        allowedEndTime = ScheduleTime(hour: 6, minute: 0)
    }

    /// Clears the connection fields after a successful save; the rest of the form is kept.
    func clearConnectionFieldsAfterSave() {
        selectedURL = nil
        ftpHost = Self.defaultFTPHost
        ftpPort = "21"
        ftpUsername = ""
        ftpPassword = ""
        isAnonymous = false
        sftpHost = ""
        sftpPort = "22"
        sftpUsername = ""
        sftpPassword = ""
        sftpPath = ""
    }
}

// MARK: - Selected Server

extension BackupFormModel {
    /// Connection values of the currently selected target.
    struct ServerSettings {
        let backupType: BackupType
        let host: String
        let port: Int
        let username: String
        let password: String
        let destinationPath: String
    }

    var server: ServerSettings {
        switch selectedTarget {
        case .ftp:
            return ServerSettings(
                backupType: .ftp,
                host: ftpHost,
                port: Int(ftpPort) ?? 21,
                username: isAnonymous ? "" : ftpUsername,
                password: isAnonymous ? "" : ftpPassword,
                destinationPath: destinationPath
            )
        case .sftp:
            return ServerSettings(
                backupType: .sftp,
                host: sftpHost,
                port: Int(sftpPort) ?? 22,
                username: sftpUsername,
                password: sftpPassword,
                destinationPath: sftpPath
            )
        case .webdav:
            let parsed = Self.parseWebDAVURL(webdavURL, portOverride: webdavPort, fallbackPath: webdavPath)
            return ServerSettings(
                backupType: .webdav,
                host: parsed.host,
                port: parsed.port,
                username: webdavUsername,
                password: webdavPassword,
                destinationPath: webdavPath
            )
        }
    }

    /// Whether the selected server is on the local network (private IP ranges or localhost).
    var isLocalServer: Bool {
        let host = server.host

        // Extract hostname from URL if it's a full URL
        let hostname: String
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            hostname = URL(string: host)?.host ?? host
        } else {
            hostname = host
        }

        // Local IP ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x, localhost
        let localPatterns = [
            "^192\\.168\\.",
            "^10\\.",
            "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",
            "^127\\.",
            "localhost"
        ]

        return localPatterns.contains { pattern in
            hostname.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Minimum input before saving is offered. Credentials are validated when saving
    /// because stored passwords stay in the Keychain and are blank when editing.
    var canSave: Bool {
        let hasSource = isPhotoLibrarySelected || selectedURL != nil
        return hasSource && !server.host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Whether enough is filled in to try connecting to the server.
    var hasValidConnectionSettings: Bool {
        switch selectedTarget {
        case .ftp:
            return !ftpHost.isEmpty && (isAnonymous || (!ftpUsername.isEmpty && !ftpPassword.isEmpty))
        case .sftp:
            return !sftpHost.isEmpty && !sftpUsername.isEmpty && !sftpPassword.isEmpty
        case .webdav:
            return !webdavURL.isEmpty && !webdavUsername.isEmpty
        }
    }

    /// Message shown when the connection settings are incomplete.
    var incompleteSettingsMessage: String {
        selectedTarget == .webdav
            ? "backup.webdav_credentials_required".localized
            : "backup.fill_required_fields".localized
    }

    /// Server values for browsing remote folders; WebDAV addresses are normalized first.
    var remoteFolderConfig: (host: String, port: Int, username: String?, password: String?) {
        switch selectedTarget {
        case .ftp:
            return (ftpHost, Int(ftpPort) ?? 21, isAnonymous ? nil : ftpUsername, isAnonymous ? nil : ftpPassword)
        case .sftp:
            return (sftpHost, Int(sftpPort) ?? 22, sftpUsername, sftpPassword)
        case .webdav:
            let parsed = Self.parseWebDAVURL(webdavURL, portOverride: webdavPort, fallbackPath: webdavPath)
            return (parsed.host, parsed.port, webdavUsername, webdavPassword)
        }
    }

    /// Turns a user-entered WebDAV address into a `scheme://host/path` string and a port.
    /// Without a scheme, ports 80/5005 mean http and anything else https.
    static func parseWebDAVURL(_ urlString: String, portOverride: String, fallbackPath: String = "") -> (host: String, port: Int) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let overridePort = Int(portOverride)
        guard !trimmed.isEmpty else { return ("", overridePort ?? 443) }

        let cleanedFallback: String = {
            let f = fallbackPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if f.isEmpty || f == "/" || f == Self.legacyDefaultWebDAVPath { return "" }
            return f.hasPrefix("/") ? f : "/\(f)"
        }()

        let lowerTrimmed = trimmed.lowercased()
        let hasScheme = lowerTrimmed.hasPrefix("http://") || lowerTrimmed.hasPrefix("https://")
        let schemeFromPort: String = {
            if let p = overridePort, p == 5005 || p == 80 { return "http" }
            if let p = overridePort, p == 5006 || p == 443 { return "https" }
            return "https"
        }()

        let withScheme = hasScheme ? trimmed : "\(schemeFromPort)://\(trimmed)"

        if let components = URLComponents(string: withScheme) {
            let scheme = components.scheme?.lowercased() ?? schemeFromPort
            let host = components.host ?? trimmed
            let port: Int = components.port ?? overridePort ?? (scheme == "http" ? 80 : 443)
            let path = components.path
            let normalizedPath = (path.isEmpty || path == "/") ? cleanedFallback : path
            let hostForConnect = "\(scheme)://\(host)\(normalizedPath)"
            return (hostForConnect, port)
        }

        // Fallback: strip path then parse host:port
        var host = trimmed
        var path = ""
        if let slashIndex = host.firstIndex(of: "/") {
            path = String(host[slashIndex...])
            host = String(host[..<slashIndex])
        }
        var port = overridePort ?? 443
        if let portRange = host.range(of: ":") {
            let portString = String(host[portRange.upperBound...])
            if let customPort = Int(portString) {
                port = customPort
                host = String(host[..<portRange.lowerBound])
            }
        }
        let scheme = (port == 5005 || port == 80) ? "http" : "https"
        let normalizedPath = (path.isEmpty || path == "/") ? cleanedFallback : path
        let hostForConnect = "\(scheme)://\(host)\(normalizedPath)"
        return (hostForConnect, port)
    }
}

// MARK: - Connection Test

extension BackupFormModel {
    struct ConnectionTestResult {
        let status: ConnectionStatus
        /// Set when an SFTP server presented a host key that was not known before.
        let newSFTPHostKeyFingerprint: String?
    }

    /// Connects to the selected server once with the entered credentials.
    func testConnection() async -> ConnectionTestResult {
        do {
            switch selectedTarget {
            case .ftp:
                try await FTPService.shared.connect(
                    host: ftpHost,
                    port: Int(ftpPort) ?? 21,
                    username: isAnonymous ? nil : ftpUsername,
                    password: isAnonymous ? nil : ftpPassword
                )
                return ConnectionTestResult(status: .success("backup.connection_success_ftp".localized), newSFTPHostKeyFingerprint: nil)

            case .sftp:
                let result = try await SFTPService.shared.testConnection(
                    host: sftpHost,
                    port: Int(sftpPort) ?? 22,
                    username: sftpUsername,
                    password: sftpPassword
                )
                return ConnectionTestResult(
                    status: .success("backup.connection_success_sftp".localized),
                    newSFTPHostKeyFingerprint: result.isNewHostKey ? result.fingerprint : nil
                )

            case .webdav:
                let (host, port) = Self.parseWebDAVURL(webdavURL, portOverride: webdavPort, fallbackPath: webdavPath)
                let webDAVService = WebDAVService.shared
                let isConnected = await webDAVService.testConnection(
                    host: host,
                    port: port,
                    username: webdavUsername,
                    password: webdavPassword
                )
                guard isConnected else {
                    let errorMessage = webDAVService.lastError?.localizedDescription ?? "backup.connection_error".localized
                    throw NSError(domain: "WebDAV Error", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return ConnectionTestResult(status: .success("backup.connection_success_webdav".localized), newSFTPHostKeyFingerprint: nil)
            }
        } catch let error as FTPError {
            return ConnectionTestResult(status: .failure(String(format: "backup.connection_error_ftp".localized, error.localizedDescription)), newSFTPHostKeyFingerprint: nil)
        } catch {
            return ConnectionTestResult(status: .failure(String(format: "backup.connection_error".localized, error.localizedDescription)), newSFTPHostKeyFingerprint: nil)
        }
    }
}

// MARK: - Saving

extension BackupFormModel {
    /// Checks that a source is chosen and readable.
    /// - Returns: The message to show, or `nil` if the source is usable.
    func sourceValidationError() -> String? {
        guard isPhotoLibrarySelected || selectedURL != nil else {
            return "backup.source_required".localized
        }

        if isPhotoLibrarySelected {
            let status = PHPhotoLibrary.authorizationStatus()
            guard status == .authorized || status == .limited else {
                return "backup.photo_permission_required".localized
            }
        }

        if !isPhotoLibrarySelected, let sourceURL = selectedURL {
            guard sourceURL.startAccessingSecurityScopedResource() else {
                return "backup.invalid_folder".localized
            }
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)
            sourceURL.stopAccessingSecurityScopedResource()

            guard exists && isDirectory.boolValue else {
                return "backup.invalid_folder".localized
            }
        }

        return nil
    }

    /// Message to show when the selected server has no host, or `nil` if one is entered.
    var missingHostMessage: String? {
        server.host.isEmpty ? incompleteSettingsMessage : nil
    }

    var sourcePath: String {
        isPhotoLibrarySelected ? "PHOTOS_LIBRARY" : (selectedURL?.path ?? "")
    }

    var taskDisplayName: String {
        isPhotoLibrarySelected ? selectedMediaType.displayName : (selectedURL?.lastPathComponent ?? "backup.default_task_name".localized)
    }

    var frequency: BackupFrequency {
        let time = ScheduleTime(hour: selectedTime.hour, minute: selectedTime.minute)
        switch frequencyType {
        case .manual: return .manual
        case .daily: return .daily(time: time)
        case .weekly: return .weekly(day: selectedDay, time: time)
        case .monthly: return .monthly(day: selectedMonthDay, time: time)
        case .intervalHours: return .intervalHours(intervalHours)
        }
    }

    /// Whether `task` backs up the same source to the same server folder as this form.
    func describesSameBackup(as task: BackupTask) -> Bool {
        let server = server
        return (task.sourcePath ?? "") == sourcePath
            && task.backupType == server.backupType
            && task.serverHost.lowercased() == server.host.lowercased()
            && task.serverPort == server.port
            && task.destinationPath == server.destinationPath
    }

    /// Builds a task from the form. Creating it stores the entered password in the Keychain.
    func makeTask() -> BackupTask {
        let server = server
        return BackupTask(
            sourcePath: sourcePath,
            backupType: server.backupType,
            serverHost: server.host,
            serverPort: server.port,
            serverUsername: server.username,
            serverPassword: server.password,
            destinationPath: server.destinationPath,
            displayName: taskDisplayName,
            isEnabled: true,
            isPaused: false,
            frequency: frequency,
            scheduledTime: (frequencyType == .daily || frequencyType == .weekly || frequencyType == .monthly) ? selectedTime : nil,
            scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
            mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
            allowCellularForLocalServer: allowCellularForLocalServer,
            includeICloudAssets: isPhotoLibrarySelected ? includeICloudAssets : false,
            photoFolderStructure: isPhotoLibrarySelected ? photoFolderStructure : .flat,
            preserveOriginalPhotoFormat: isPhotoLibrarySelected ? preserveOriginalPhotoFormat : false,
            deletionPolicy: deletionPolicy,
            checksumMode: checksumMode,
            allowedStartTime: useAllowedWindow ? allowedStartTime : nil,
            allowedEndTime: useAllowedWindow ? allowedEndTime : nil,
            requiresExternalPower: requiresExternalPower,
            requiresWiFi: requiresWiFi
        )
    }

    /// Copies the editable settings of `source` onto an existing task.
    static func copyTaskFields(from source: BackupTask, to target: BackupTask) {
        target.sourcePath = source.sourcePath
        target.backupType = source.backupType
        target.serverHost = source.serverHost
        target.serverPort = source.serverPort
        target.serverUsername = source.serverUsername
        if !source.resolvedServerPassword.isEmpty {
            target.saveServerPassword(source.resolvedServerPassword)
        }
        target.destinationPath = source.destinationPath
        target.displayName = source.displayName
        target.frequency = source.frequency
        target.scheduledTime = source.scheduledTime
        target.scheduledWeekday = source.scheduledWeekday
        target.mediaType = source.mediaType
        target.allowCellularForLocalServer = source.allowCellularForLocalServer
        target.includeICloudAssets = source.includeICloudAssets
        target.photoFolderStructure = source.photoFolderStructure
        target.preserveOriginalPhotoFormat = source.preserveOriginalPhotoFormat
        target.deletionPolicy = source.deletionPolicy
        target.checksumMode = source.checksumMode
        target.allowedStartTime = source.allowedStartTime
        target.allowedEndTime = source.allowedEndTime
        target.requiresExternalPower = source.requiresExternalPower
        target.requiresWiFi = source.requiresWiFi
        target.nextRunTime = nil
    }
}
