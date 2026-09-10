import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Photos
#if canImport(UIKit)
import UIKit
#endif

enum PhotoLibraryPermission {
    case notDetermined
    case authorized
    case denied

    var isGranted: Bool {
        return self == .authorized
    }
}

enum ConnectionStatus: Equatable {
    case idle
    case testing(String)
    case success(String)
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .testing(let message):
            return message
        case .success(let message):
            return message
        case .failure(let error):
            return error
        }
    }
}

enum FrequencyType: String, CaseIterable, Identifiable {
    case manual
    case daily
    case weekly
    case monthly
    case intervalHours

    var id: String { String(describing: self) }

    var displayName: String {
        switch self {
        case .manual:
            return "backup.manual".localized
        case .daily:
            return "backup.daily".localized
        case .weekly:
            return "backup.weekly".localized
        case .monthly:
            return "backup.monthly".localized
        case .intervalHours:
            return "backup.interval".localized
        }
    }
}

struct TimePicker: View {
    @Binding var time: ScheduleTime

    var body: some View {
        VStack(alignment: .leading) {
            Text("backup.select_time".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Picker("backup.hour".localized, selection: $time.hour) {
                    ForEach(0..<24, id: \ .self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                .clipped()

                Text(":")
                    .font(.title2)
                    .padding(.horizontal, -10)

                Picker("backup.minute".localized, selection: $time.minute) {
                    ForEach(0..<60, id: \ .self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 80)
                .clipped()
            }
            .frame(height: 100)
        }
        .padding(.vertical, 8)
    }
}

struct DayPicker: View {
    @Binding var selectedDay: Int // 1: Sunday, 2: Monday, ..., 7: Saturday

    private var days: [(Int, String)] {
        [
            (1, "day.names.sunday".localized),
            (2, "day.names.monday".localized),
            (3, "day.names.tuesday".localized),
            (4, "day.names.wednesday".localized),
            (5, "day.names.thursday".localized),
            (6, "day.names.friday".localized),
            (7, "day.names.saturday".localized)
        ]
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("backup.select_day".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("backup.day".localized, selection: $selectedDay) {
                ForEach(days, id: \.0) { day, name in
                    Text(name).tag(day)
                }
            }
            .frame(height: 100)
            .clipped()
        }
        .padding(.vertical, 8)
    }
}

struct BackupView: View {
    // Varsayılan ayarlar
    private static let defaultFTPHost = "192.168.1.1"
    private static let defaultWebDAVPath = "/remote.php/dav/files/"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let editingTask: BackupTask?

    @State private var selectedURL: URL?
    @State private var isPhotoLibrarySelected = false
    @State private var selectedMediaType: MediaType = .photosOnly
    @State private var includeICloudAssets = true

    // Hedef seçimi
    @State private var selectedTarget: BackupTarget = .ftp

    // FTP ayarları
    @State private var ftpHost = defaultFTPHost
    @State private var ftpPort = "21"
    @State private var ftpUsername = ""
    @State private var ftpPassword = ""
    @State private var isAnonymous = false
    @State private var destinationPath = "/"

    // SFTP ayarları
    @State private var sftpHost = ""
    @State private var sftpPort = "22"
    @State private var sftpUsername = ""
    @State private var sftpPassword = ""
    @State private var sftpPath = ""

    // WebDAV ayarları
    @State private var webdavURL = ""
    @State private var webdavPort = "443"
    @State private var webdavUsername = ""
    @State private var webdavPassword = ""
    @State private var webdavPath = defaultWebDAVPath

    @State private var frequencyType: FrequencyType = .manual
    @State private var selectedTime = ScheduleTime(hour: 0, minute: 0)
    @State private var selectedDay = 1 // 1: Sunday, 2: Monday, ..., 7: Saturday
    @State private var selectedMonthDay = 1
    @State private var intervalHours = 6
    @State private var allowCellularForLocalServer = false // Network policy
    @State private var deletionPolicy: BackupDeletionPolicy = .mirror
    @State private var checksumMode: BackupChecksumMode = .off
    @State private var requiresWiFi = false
    @State private var requiresExternalPower = false
    @State private var useAllowedWindow = false
    @State private var allowedStartTime = ScheduleTime(hour: 23, minute: 0)
    @State private var allowedEndTime = ScheduleTime(hour: 6, minute: 0)

    @State private var showingDocumentPicker = false
    @State private var showingSaveAlert = false
    @State private var showingPhotoLibraryDeniedAlert = false
    @State private var saveAlertMessage = ""
    @State private var lastAlertAt: Date? = nil
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var lastTestTapAt: Date? = nil
    @State private var showingFirstBackupPrompt = false
    @State private var firstBackupTaskToStart: BackupTask? = nil
    @State private var startingToast: String? = nil
    @State private var showingSFTPHostKeyAlert = false
    @State private var sftpHostKeyAlertMessage = ""
    @State private var showingRemoteFolderPicker = false

    init(editingTask: BackupTask? = nil) {
        self.editingTask = editingTask

        guard let task = editingTask else { return }

        _selectedURL = State(initialValue: task.sourcePath == "PHOTOS_LIBRARY" ? nil : URL(fileURLWithPath: task.sourcePath ?? ""))
        _isPhotoLibrarySelected = State(initialValue: task.sourcePath == "PHOTOS_LIBRARY")
        _selectedMediaType = State(initialValue: task.mediaType)
        _includeICloudAssets = State(initialValue: task.includeICloudAssets)
        _selectedTarget = State(initialValue: {
            switch task.backupType {
            case .ftp: return .ftp
            case .sftp: return .sftp
            case .webdav: return .webdav
            }
        }())
        _ftpHost = State(initialValue: task.backupType == .ftp ? task.serverHost : Self.defaultFTPHost)
        _ftpPort = State(initialValue: task.backupType == .ftp ? "\(task.serverPort)" : "21")
        _ftpUsername = State(initialValue: task.backupType == .ftp ? task.serverUsername : "")
        _isAnonymous = State(initialValue: task.backupType == .ftp && task.isAnonymous)
        _destinationPath = State(initialValue: task.backupType == .ftp ? task.destinationPath : "/")
        _sftpHost = State(initialValue: task.backupType == .sftp ? task.serverHost : "")
        _sftpPort = State(initialValue: task.backupType == .sftp ? "\(task.serverPort)" : "22")
        _sftpUsername = State(initialValue: task.backupType == .sftp ? task.serverUsername : "")
        _sftpPath = State(initialValue: task.backupType == .sftp ? task.destinationPath : "")
        _webdavURL = State(initialValue: task.backupType == .webdav ? task.serverHost : "")
        _webdavPort = State(initialValue: task.backupType == .webdav ? "\(task.serverPort)" : "443")
        _webdavUsername = State(initialValue: task.backupType == .webdav ? task.serverUsername : "")
        _webdavPath = State(initialValue: task.backupType == .webdav ? task.destinationPath : Self.defaultWebDAVPath)
        _allowCellularForLocalServer = State(initialValue: task.allowCellularForLocalServer)
        _deletionPolicy = State(initialValue: task.deletionPolicy)
        _checksumMode = State(initialValue: task.checksumMode)
        _requiresWiFi = State(initialValue: task.requiresWiFi)
        _requiresExternalPower = State(initialValue: task.requiresExternalPower)
        _useAllowedWindow = State(initialValue: task.allowedStartTime != nil && task.allowedEndTime != nil)
        _allowedStartTime = State(initialValue: task.allowedStartTime ?? ScheduleTime(hour: 23, minute: 0))
        _allowedEndTime = State(initialValue: task.allowedEndTime ?? ScheduleTime(hour: 6, minute: 0))

        switch task.frequency {
        case .manual:
            _frequencyType = State(initialValue: .manual)
        case .daily(let time):
            _frequencyType = State(initialValue: .daily)
            _selectedTime = State(initialValue: time)
        case .weekly(let day, let time):
            _frequencyType = State(initialValue: .weekly)
            _selectedDay = State(initialValue: day)
            _selectedTime = State(initialValue: time)
        case .monthly(let day, let time):
            _frequencyType = State(initialValue: .monthly)
            _selectedMonthDay = State(initialValue: day)
            _selectedTime = State(initialValue: time)
        case .intervalHours(let hours):
            _frequencyType = State(initialValue: .intervalHours)
            _intervalHours = State(initialValue: hours)
        }
    }

    var body: some View {
        let targetTheme = BackupSetupTheme.theme(for: selectedTarget)

        return ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    targetTheme.primary.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("backup.new_backup".localized)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(selectedTarget.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }

                            Spacer()

                            Image(systemName: selectedTarget.iconName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(.white.opacity(0.16))
                                .clipShape(Circle())
                        }

                        HStack(spacing: 10) {
                            Image(systemName: isPhotoLibrarySelected ? selectedMediaType.systemImageName : "folder.fill")
                                .font(.callout.weight(.semibold))
                            Text(isPhotoLibrarySelected ? selectedMediaType.displayName : (selectedURL?.lastPathComponent ?? "backup.source_section".localized))
                                .font(.callout.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [targetTheme.primary, targetTheme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Text(selectedTarget.rawValue)
                            .font(.system(size: 66, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.12))
                            .padding(.trailing, 18)
                            .offset(y: 14)
                            .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                    BackupSetupCard(
                        title: "backup.source_section".localized,
                        icon: "photo.on.rectangle.angled",
                        theme: targetTheme
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            Button {
                                isPhotoLibrarySelected = true
                                selectedURL = nil
                                requestPhotoLibraryAccess()
                            } label: {
                                BackupChoiceRow(
                                    icon: "photo.on.rectangle.angled",
                                    title: "backup.photos_option".localized,
                                    subtitle: selectedMediaType.displayName,
                                    isSelected: isPhotoLibrarySelected,
                                    theme: targetTheme
                                )
                            }
                            .buttonStyle(.plain)

                            if isPhotoLibrarySelected {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("backup.media_type_caption".localized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    ForEach(MediaType.allCases) { mediaType in
                                        Button {
                                            selectedMediaType = mediaType
                                        } label: {
                                            BackupChoiceRow(
                                                icon: mediaType.systemImageName,
                                                title: mediaType.displayName,
                                                subtitle: nil,
                                                isSelected: selectedMediaType == mediaType,
                                                theme: targetTheme
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Toggle("backup.photo_backup_include_icloud".localized, isOn: $includeICloudAssets)
                                        .tint(targetTheme.primary)
                                        .padding(.top, 2)

                                    Text("backup.photo_backup_include_icloud_hint".localized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(targetTheme.primary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            HStack {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.secondary.opacity(0.16))
                                Text("backup.or".localized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.secondary.opacity(0.16))
                            }

                            Button {
                                isPhotoLibrarySelected = false
                                showingDocumentPicker = true
                            } label: {
                                BackupChoiceRow(
                                    icon: "folder.fill",
                                    title: selectedURL?.lastPathComponent ?? "backup.folder_select".localized,
                                    subtitle: selectedURL?.path,
                                    isSelected: !isPhotoLibrarySelected && selectedURL != nil,
                                    theme: targetTheme
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    BackupSetupCard(
                        title: "backup.target_type".localized,
                        icon: selectedTarget.iconName,
                        theme: targetTheme
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
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

                            Button {
                                Task {
                                    let now = Date()
                                    if let last = lastTestTapAt, now.timeIntervalSince(last) < 2 { return }
                                    lastTestTapAt = now
                                    await testConnection()
                                }
                            } label: {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text("backup.test_connection".localized)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isValidConnectionSettings() ? targetTheme.primary : Color.secondary.opacity(0.22))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isTestingConnection || !isValidConnectionSettings() || (lastTestTapAt != nil && Date().timeIntervalSince(lastTestTapAt!) < 2))

                            if let message = connectionStatus.message, !message.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    Text(message)
                                        .font(.caption)
                                }
                                .foregroundStyle(connectionStatus.isSuccess ? .green : .red)
                                .transition(.opacity)
                            }

                            Button {
                                showingRemoteFolderPicker = true
                            } label: {
                                Label("backup.remote_folder.browse".localized, systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!isValidConnectionSettings())
                        }
                    }

                    BackupSetupCard(
                        title: "backup.scheduling".localized,
                        icon: "clock.arrow.circlepath",
                        theme: targetTheme
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("backup.frequency".localized, selection: $frequencyType) {
                                ForEach(FrequencyType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)

                            if frequencyType == .daily || frequencyType == .weekly {
                                TimePicker(time: $selectedTime)
                            }

                            if frequencyType == .weekly {
                                DayPicker(selectedDay: $selectedDay)
                            }

                            if frequencyType == .monthly {
                                Stepper("backup.month_day".localized(with: selectedMonthDay), value: $selectedMonthDay, in: 1...31)
                                TimePicker(time: $selectedTime)
                            }

                            if frequencyType == .intervalHours {
                                Stepper("backup.every_hours".localized(with: intervalHours), value: $intervalHours, in: 1...24)
                            }
                        }
                    }

                    BackupSetupCard(
                        title: "backup.behavior".localized,
                        icon: "slider.horizontal.3",
                        theme: targetTheme
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("backup.deletion_policy".localized, selection: $deletionPolicy) {
                                ForEach(BackupDeletionPolicy.allCases) { policy in
                                    Text(policy.displayName).tag(policy)
                                }
                            }

                            Picker("backup.checksum".localized, selection: $checksumMode) {
                                ForEach(BackupChecksumMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }

                            Toggle("backup.require_wifi".localized, isOn: $requiresWiFi)
                                .tint(targetTheme.primary)

                            Toggle("backup.require_external_power".localized, isOn: $requiresExternalPower)
                                .tint(targetTheme.primary)

                            Toggle("backup.use_allowed_time_window".localized, isOn: $useAllowedWindow)
                                .tint(targetTheme.primary)

                            if useAllowedWindow {
                                TimePicker(time: $allowedStartTime)
                                TimePicker(time: $allowedEndTime)
                            }

                            if deletionPolicy == .archive {
                                Text("backup.archive_policy_warning".localized)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if isLocalServer() {
                        BackupSetupCard(
                            title: "backup.network_settings".localized,
                            icon: "antenna.radiowaves.left.and.right",
                            theme: targetTheme
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("backup.allow_cellular".localized, isOn: $allowCellularForLocalServer)
                                    .tint(targetTheme.primary)

                                Text(allowCellularForLocalServer ? "backup.allow_cellular_warning".localized : "backup.wifi_only_info".localized)
                                    .font(.caption)
                                    .foregroundStyle(allowCellularForLocalServer ? .orange : .secondary)
                            }
                        }
                    }

                    Button {
                        Task {
                            await saveTask()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("backup.save_task".localized)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [targetTheme.primary, targetTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: targetTheme.primary.opacity(0.22), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = startingToast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.bottom, 60)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: startingToast)
        .navigationTitle("backup.new_backup".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("backup.clear".localized) {
                    resetForm()
                    showingSaveAlert = false
                }
            }
        }
        .onChange(of: showingDocumentPicker) { _, newValue in
            if newValue {
                // prevent re-present within 1s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if showingDocumentPicker { showingDocumentPicker = true }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(url: $selectedURL) {
                showingDocumentPicker = false
            }
        }
        .alert("backup.info_title".localized, isPresented: $showingSaveAlert) {
            Button("backup.ok".localized, role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        .alert(
            "backup.first_start_prompt_title".localized,
            isPresented: $showingFirstBackupPrompt
        ) {
            Button("backup.notification.action.start".localized) {
                guard let taskToStart = firstBackupTaskToStart else { return }
                Task {
                    try? await BackupScheduler.shared.performBackup(task: taskToStart)
                }
                firstBackupTaskToStart = nil
            }
            Button("backup.first_start_prompt_later".localized, role: .cancel) {
                firstBackupTaskToStart = nil
            }
        } message: {
            Text("backup.first_start_prompt_message".localized)
        }
        .alert("sftp.hostkey_title".localized, isPresented: $showingSFTPHostKeyAlert) {
            Button("backup.ok".localized, role: .cancel) {}
        } message: {
            Text(sftpHostKeyAlertMessage)
        }
        .sheet(isPresented: $showingRemoteFolderPicker) {
            let config = remoteFolderConfig()
            RemoteFolderPicker(
                target: selectedTarget,
                host: config.host,
                port: config.port,
                username: config.username,
                password: config.password
            ) { selectedPath in
                switch selectedTarget {
                case .ftp:
                    destinationPath = selectedPath
                case .sftp:
                    sftpPath = selectedPath
                case .webdav:
                    webdavPath = selectedPath
                }
            }
        }

        func isLocalServer() -> Bool {
            let host: String
            switch selectedTarget {
            case .ftp:
                host = ftpHost
            case .sftp:
                host = sftpHost
            case .webdav:
                host = webdavURL
            }

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

        func isValidConnectionSettings() -> Bool {
            switch selectedTarget {
            case .ftp:
                return !ftpHost.isEmpty && (isAnonymous || (!ftpUsername.isEmpty && !ftpPassword.isEmpty))
            case .sftp:
                return !sftpHost.isEmpty && !sftpUsername.isEmpty && !sftpPassword.isEmpty
            case .webdav:
                return !webdavURL.isEmpty && !webdavUsername.isEmpty
            }
        }

        func remoteFolderConfig() -> (host: String, port: Int, username: String?, password: String?) {
            switch selectedTarget {
            case .ftp:
                return (ftpHost, Int(ftpPort) ?? 21, isAnonymous ? nil : ftpUsername, isAnonymous ? nil : ftpPassword)
            case .sftp:
                return (sftpHost, Int(sftpPort) ?? 22, sftpUsername, sftpPassword)
            case .webdav:
                let parsed = parseWebDAVURL(webdavURL, portOverride: webdavPort)
                return (parsed.host, parsed.port, webdavUsername, webdavPassword)
            }
        }

        func testConnection() async {
            if isTestingConnection { return }

            guard isValidConnectionSettings() else {
                let errorMessage = selectedTarget == .ftp ?
                "backup.fill_required_fields".localized :
                (selectedTarget == .sftp ? "backup.fill_required_fields".localized : "backup.webdav_credentials_required".localized)
                connectionStatus = .failure(errorMessage)
                return
            }

            isTestingConnection = true
            connectionStatus = .testing("backup.testing_network".localized)

            do {
                switch selectedTarget {
                case .ftp:
                    let ftpService = FTPService.shared
                    let port = Int(ftpPort) ?? 21

                    // İlk kurulumda ağ izni bildirimi göster
                    connectionStatus = .testing("backup.connection_testing".localized)

                    try await ftpService.connect(
                        host: ftpHost,
                        port: port,
                        username: isAnonymous ? nil : ftpUsername,
                        password: isAnonymous ? nil : ftpPassword
                    )

                    connectionStatus = .success("backup.connection_success_ftp".localized)

                case .sftp:
                    let sftpService = SFTPService.shared
                    let port = Int(sftpPort) ?? 22

                    connectionStatus = .testing("backup.connection_testing".localized)

                    let result = try await sftpService.testConnection(
                        host: sftpHost,
                        port: port,
                        username: sftpUsername,
                        password: sftpPassword
                    )

                    connectionStatus = .success("backup.connection_success_sftp".localized)
                    if result.isNewHostKey, let fingerprint = result.fingerprint {
                        sftpHostKeyAlertMessage = String(format: "sftp.hostkey_message".localized, fingerprint)
                        showingSFTPHostKeyAlert = true
                    }

                case .webdav:
                    // Extract host and port from webdavURL
                    let (host, port) = parseWebDAVURL(webdavURL, portOverride: webdavPort)

                    // İlk kurulumda ağ izni bildirimi göster
                    connectionStatus = .testing("backup.connection_testing".localized)

                    // Test WebDAV connection
                    let webDAVService = WebDAVService.shared
                    let isConnected = await webDAVService.testConnection(
                        host: host,
                        port: port,
                        username: webdavUsername,
                        password: webdavPassword
                    )

                    if isConnected {
                        connectionStatus = .success("backup.connection_success_webdav".localized)
                    } else {
                        let errorMessage = webDAVService.lastError?.localizedDescription ?? "backup.connection_error".localized
                        throw NSError(domain: "WebDAV Error", code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    }
                }
            } catch let error as FTPError {
                connectionStatus = .failure(String(format: "backup.connection_error_ftp".localized, error.localizedDescription))
            } catch {
                connectionStatus = .failure(String(format: "backup.connection_error".localized, error.localizedDescription))
            }

            isTestingConnection = false
        }

        func requestPhotoLibraryAccess() {
            let photoLibraryManager = PhotoLibraryManager.shared
            if photoLibraryManager.authorizationStatus == .notDetermined {
                photoLibraryManager.requestAuthorization { granted in
                    if !granted {
                        DispatchQueue.main.async {
                            self.showingPhotoLibraryDeniedAlert = true
                        }
                    }
                }
            } else if photoLibraryManager.authorizationStatus != .authorized && photoLibraryManager.authorizationStatus != .limited {
                showingPhotoLibraryDeniedAlert = true
            }
        }

        func saveTask() async {
            // Check if either folder or photo library is selected
            guard isPhotoLibrarySelected || selectedURL != nil else {
                saveAlertMessage = "backup.source_required".localized
                let now = Date()
                if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                lastAlertAt = now
                showingSaveAlert = true
                return
            }

            // If photo library is selected, check permission
            if isPhotoLibrarySelected {
                let status = PHPhotoLibrary.authorizationStatus()
                guard status == .authorized || status == .limited else {
                    saveAlertMessage = "backup.photo_permission_required".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }
            }

            // Check folder access if a folder is selected
            if !isPhotoLibrarySelected, let sourceURL = selectedURL {
                guard sourceURL.startAccessingSecurityScopedResource() else {
                    saveAlertMessage = "backup.invalid_folder".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }

                // We need to verify the URL is accessible
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory)

                // Stop accessing the resource
                sourceURL.stopAccessingSecurityScopedResource()

                // Check if the path exists and is a directory
                guard exists && isDirectory.boolValue else {
                    saveAlertMessage = "backup.invalid_folder".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }
            }

            // Create the frequency based on the selected type
            let frequency: BackupFrequency = {
                switch frequencyType {
                case .manual:
                    return BackupFrequency.manual
                case .daily:
                    let time = ScheduleTime(hour: selectedTime.hour, minute: selectedTime.minute)
                    return BackupFrequency.daily(time: time)
                case .weekly:
                    let time = ScheduleTime(hour: selectedTime.hour, minute: selectedTime.minute)
                    return BackupFrequency.weekly(day: selectedDay, time: time)
                case .monthly:
                    let time = ScheduleTime(hour: selectedTime.hour, minute: selectedTime.minute)
                    return BackupFrequency.monthly(day: selectedMonthDay, time: time)
                case .intervalHours:
                    return BackupFrequency.intervalHours(intervalHours)
                }
            }()

            // Determine source path and display name based on selection
            let sourcePath = isPhotoLibrarySelected ? "PHOTOS_LIBRARY" : (selectedURL?.path ?? "")
            let displayNameValue = isPhotoLibrarySelected ? selectedMediaType.displayName : (selectedURL?.lastPathComponent ?? "backup.default_task_name".localized)

            // Check for existing tasks with the same configuration
            let hostToCheck: String
            let destPathToCheck: String
            switch selectedTarget {
            case .ftp:
                hostToCheck = ftpHost.lowercased()
                destPathToCheck = destinationPath
            case .sftp:
                hostToCheck = sftpHost.lowercased()
                destPathToCheck = sftpPath
            case .webdav:
                hostToCheck = webdavURL.lowercased()
                destPathToCheck = webdavPath
            }
            var isFirstTask = false

            do {
                let allTasks = try modelContext.fetch(FetchDescriptor<BackupTask>())
                isFirstTask = allTasks.isEmpty
                let backupType: BackupType
                let portToCheck: Int
                switch selectedTarget {
                case .ftp:
                    backupType = .ftp
                    portToCheck = Int(ftpPort) ?? 21
                case .sftp:
                    backupType = .sftp
                    portToCheck = Int(sftpPort) ?? 22
                case .webdav:
                    backupType = .webdav
                    portToCheck = Int(webdavPort) ?? 443
                }

                let hasDuplicate = allTasks.contains { task in
                    if let editingTask, task.id == editingTask.id { return false }
                    let isSameSource = (task.sourcePath ?? "") == sourcePath
                    let isSameType = task.backupType == backupType
                    let isSameHost = task.serverHost.lowercased() == hostToCheck
                    let isSamePort = task.serverPort == portToCheck
                    let isSameDest = task.destinationPath == destPathToCheck

                    return isSameSource && isSameType && isSameHost && isSamePort && isSameDest
                }

                if hasDuplicate {
                    saveAlertMessage = "tasks.duplicate_error".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }
            } catch {
                debugLog("Görev kontrolü sırasında hata oluştu: \(error.localizedDescription)")
            }

            let task: BackupTask

            switch selectedTarget {
            case .ftp:
                guard !ftpHost.isEmpty else {
                    saveAlertMessage = "backup.fill_required_fields".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }

                let port = Int(ftpPort) ?? 21

                task = BackupTask(
                    sourcePath: sourcePath,
                    backupType: .ftp,
                    serverHost: ftpHost,
                    serverPort: port,
                    serverUsername: isAnonymous ? "" : ftpUsername,
                    serverPassword: isAnonymous ? "" : ftpPassword,
                    destinationPath: destinationPath,
                    displayName: displayNameValue,
                    isEnabled: true,
                    isPaused: false,
                    frequency: frequency,
                    scheduledTime: (frequencyType == .daily || frequencyType == .weekly || frequencyType == .monthly) ? selectedTime : nil,
                    scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
                    mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
                    allowCellularForLocalServer: allowCellularForLocalServer,
                    includeICloudAssets: isPhotoLibrarySelected ? includeICloudAssets : false,
                    deletionPolicy: deletionPolicy,
                    checksumMode: checksumMode,
                    allowedStartTime: useAllowedWindow ? allowedStartTime : nil,
                    allowedEndTime: useAllowedWindow ? allowedEndTime : nil,
                    requiresExternalPower: requiresExternalPower,
                    requiresWiFi: requiresWiFi
                )

            case .sftp:
                guard !sftpHost.isEmpty else {
                    saveAlertMessage = "backup.fill_required_fields".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }

                let port = Int(sftpPort) ?? 22

                task = BackupTask(
                    sourcePath: sourcePath,
                    backupType: .sftp,
                    serverHost: sftpHost,
                    serverPort: port,
                    serverUsername: sftpUsername,
                    serverPassword: sftpPassword,
                    destinationPath: sftpPath,
                    displayName: displayNameValue,
                    isEnabled: true,
                    isPaused: false,
                    frequency: frequency,
                    scheduledTime: (frequencyType == .daily || frequencyType == .weekly || frequencyType == .monthly) ? selectedTime : nil,
                    scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
                    mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
                    allowCellularForLocalServer: allowCellularForLocalServer,
                    includeICloudAssets: isPhotoLibrarySelected ? includeICloudAssets : false,
                    deletionPolicy: deletionPolicy,
                    checksumMode: checksumMode,
                    allowedStartTime: useAllowedWindow ? allowedStartTime : nil,
                    allowedEndTime: useAllowedWindow ? allowedEndTime : nil,
                    requiresExternalPower: requiresExternalPower,
                    requiresWiFi: requiresWiFi
                )

            case .webdav:
                guard !webdavURL.isEmpty else {
                    saveAlertMessage = "backup.webdav_credentials_required".localized
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                    return
                }

                task = BackupTask(
                    sourcePath: sourcePath,
                    backupType: .webdav,
                    serverHost: webdavURL,
                    serverPort: Int(webdavPort) ?? 443,
                    serverUsername: webdavUsername,
                    serverPassword: webdavPassword,
                    destinationPath: webdavPath,
                    displayName: displayNameValue,
                    isEnabled: true,
                    isPaused: false,
                    frequency: frequency,
                    scheduledTime: (frequencyType == .daily || frequencyType == .weekly || frequencyType == .monthly) ? selectedTime : nil,
                    scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
                    mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
                    allowCellularForLocalServer: allowCellularForLocalServer,
                    includeICloudAssets: isPhotoLibrarySelected ? includeICloudAssets : false,
                    deletionPolicy: deletionPolicy,
                    checksumMode: checksumMode,
                    allowedStartTime: useAllowedWindow ? allowedStartTime : nil,
                    allowedEndTime: useAllowedWindow ? allowedEndTime : nil,
                    requiresExternalPower: requiresExternalPower,
                    requiresWiFi: requiresWiFi
                )
            }

            let taskToSave: BackupTask
            if let editingTask {
                copyTaskFields(from: task, to: editingTask)
                task.removeStoredPassword()
                taskToSave = editingTask
            } else {
                modelContext.insert(task)
                taskToSave = task
            }

            do {
                try modelContext.save()
                debugLog("✅ BackupFlow: Görev başarıyla kaydedildi - \(displayNameValue)")
                saveAlertMessage = "tasks.save_success".localized

                // Schedule the backup if frequency is set
                if taskToSave.frequency != .manual {
                    do {
                        try await BackupScheduler.shared.scheduleBackup(task: taskToSave)
                        saveAlertMessage += " " + "tasks.scheduled".localized
                    } catch {
                        saveAlertMessage += " " + "tasks.schedule_error_detail".localized(with: error.localizedDescription)
                    }
                } else {
                    // Manual task: still schedule processing to allow future background checks
                    BackupScheduler.shared.scheduleProcessingTask()
                }

                // Reset form
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

                let isNewFTPOrSFTP = editingTask == nil && (selectedTarget == .ftp || selectedTarget == .sftp)

                if isNewFTPOrSFTP {
                    let taskToRun = taskToSave
                    startingToast = "tasks.run_started".localized
                    Task {
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        dismiss()
                        try? await BackupScheduler.shared.performBackup(task: taskToRun, bypassThrottle: true)
                    }
                } else if isFirstTask {
                    firstBackupTaskToStart = taskToSave
                    showingFirstBackupPrompt = true
                } else {
                    let now = Date()
                    if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                    lastAlertAt = now
                    showingSaveAlert = true
                }
            } catch {
                saveAlertMessage = "tasks.save_error_detail".localized(with: error.localizedDescription)
                let now = Date()
                if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                lastAlertAt = now
                showingSaveAlert = true
            }
        }

        // MARK: - WebDAV Helper

        func parseWebDAVURL(_ urlString: String, portOverride: String) -> (host: String, port: Int) {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            let overridePort = Int(portOverride)
            guard !trimmed.isEmpty else { return ("", overridePort ?? 443) }

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
                let normalizedPath = (path.isEmpty || path == "/") ? "" : path
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
            let normalizedPath = (path.isEmpty || path == "/") ? "" : path
            let hostForConnect = "\(scheme)://\(host)\(normalizedPath)"
            return (hostForConnect, port)
        }

        // MARK: - Helper Methods

        func copyTaskFields(from source: BackupTask, to target: BackupTask) {
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
            target.deletionPolicy = source.deletionPolicy
            target.checksumMode = source.checksumMode
            target.allowedStartTime = source.allowedStartTime
            target.allowedEndTime = source.allowedEndTime
            target.requiresExternalPower = source.requiresExternalPower
            target.requiresWiFi = source.requiresWiFi
            target.nextRunTime = nil
        }

        func resetForm() {
            selectedURL = nil
            isPhotoLibrarySelected = false
            selectedMediaType = .photosOnly
            includeICloudAssets = true
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
            deletionPolicy = .mirror
            checksumMode = .off
            requiresWiFi = false
            requiresExternalPower = false
            useAllowedWindow = false
            allowedStartTime = ScheduleTime(hour: 23, minute: 0)
            allowedEndTime = ScheduleTime(hour: 6, minute: 0)
            connectionStatus = .idle
            saveAlertMessage = ""
        }
    }
}

private struct BackupSetupTheme {
    let primary: Color
    let secondary: Color

    static func theme(for target: BackupTarget) -> BackupSetupTheme {
        switch target {
        case .ftp:
            return BackupSetupTheme(
                primary: Color(red: 0.95, green: 0.42, blue: 0.10),
                secondary: Color(red: 1.00, green: 0.66, blue: 0.20)
            )
        case .sftp:
            return BackupSetupTheme(
                primary: Color(red: 0.05, green: 0.58, blue: 0.34),
                secondary: Color(red: 0.18, green: 0.74, blue: 0.45)
            )
        case .webdav:
            return BackupSetupTheme(
                primary: Color(red: 0.18, green: 0.30, blue: 0.98),
                secondary: Color(red: 0.52, green: 0.31, blue: 0.98)
            )
        }
    }
}

private struct BackupSetupCard<Content: View>: View {
    let title: String
    let icon: String
    let theme: BackupSetupTheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 34, height: 34)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.headline.weight(.semibold))

                Spacer()
            }

            content
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [theme.primary.opacity(0.22), theme.secondary.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

private struct BackupChoiceRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let theme: BackupSetupTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(isSelected ? .white : theme.primary)
                .frame(width: 42, height: 42)
                .background(isSelected ? theme.primary : theme.primary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? theme.primary : .secondary.opacity(0.5))
        }
        .padding(12)
        .background(isSelected ? theme.primary.opacity(0.08) : Color(.secondarySystemBackground).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
