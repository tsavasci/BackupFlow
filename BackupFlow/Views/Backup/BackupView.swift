import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Photos

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
    
    var id: String { String(describing: self) }
    
    var displayName: String {
        switch self {
        case .manual:
            return "backup.manual".localized
        case .daily:
            return "backup.daily".localized
        case .weekly:
            return "backup.weekly".localized
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
    
    @State private var selectedURL: URL?
    @State private var isPhotoLibrarySelected = false
    @State private var selectedMediaType: MediaType = .photosOnly
    
    // Hedef seçimi
    @State private var selectedTarget: BackupTarget = .ftp
    
    // FTP ayarları
    @State private var ftpHost = defaultFTPHost
    @State private var ftpPort = "21"
    @State private var ftpUsername = ""
    @State private var ftpPassword = ""
    @State private var isAnonymous = false
    @State private var destinationPath = "/"
    
    // WebDAV ayarları
    @State private var webdavURL = ""
    @State private var webdavUsername = ""
    @State private var webdavPassword = ""
    @State private var webdavPath = defaultWebDAVPath
    
    @State private var frequencyType: FrequencyType = .manual
    @State private var selectedTime = ScheduleTime(hour: 0, minute: 0)
    @State private var selectedDay = 1 // 1: Sunday, 2: Monday, ..., 7: Saturday
    @State private var allowCellularForLocalServer = false // Network policy
    
    @State private var showingDocumentPicker = false
    @State private var showingSaveAlert = false
    @State private var showingPhotoLibraryDeniedAlert = false
    @State private var saveAlertMessage = ""
    @State private var lastAlertAt: Date? = nil
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var lastTestTapAt: Date? = nil
    
    var body: some View {
        return Form {
            Section(header: Text("backup.source_section".localized)) {
                VStack(alignment: .leading, spacing: 16) {
                    // Photo Library Option
                    Button(action: {
                        isPhotoLibrarySelected = true
                        selectedURL = nil
                        requestPhotoLibraryAccess()
                    }) {
                        HStack {
                            Image(systemName: isPhotoLibrarySelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isPhotoLibrarySelected ? .blue : .gray)
                            Text("backup.photos_option".localized)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Media Type Selection (only when photo library is selected)
                    if isPhotoLibrarySelected {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("backup.media_type_caption".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(MediaType.allCases) { mediaType in
                                Button(action: {
                                    selectedMediaType = mediaType
                                }) {
                                    HStack {
                                        Image(systemName: selectedMediaType == mediaType ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedMediaType == mediaType ? .blue : .gray)
                                        Image(systemName: mediaType.systemImageName)
                                            .foregroundColor(.blue)
                                        Text(mediaType.displayName)
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.leading, 24)
                        .padding(.top, 8)
                    }
                    
                    // Or Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("backup.or".localized)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.vertical, 4)
                    
                    // Folder Selection Option
                    HStack {
                        Image(systemName: !isPhotoLibrarySelected && selectedURL != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(!isPhotoLibrarySelected && selectedURL != nil ? .blue : .gray)
                        
                        Button {
                            isPhotoLibrarySelected = false
                            showingDocumentPicker = true
                        } label: {
                            if let url = selectedURL {
                                Text(url.lastPathComponent)
                                    .foregroundColor(.blue)
                            } else {
                                Text("backup.folder_select".localized)
                                    .foregroundColor(.gray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                
                // Backup Target Selection (FTP/WebDAV)
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
                
                Button {
                    Task {
                        let now = Date()
                        if let last = lastTestTapAt, now.timeIntervalSince(last) < 2 { return }
                        lastTestTapAt = now
                        await testConnection()
                    }
                } label: {
                    Text("backup.test_connection".localized)
                }
                .disabled(isTestingConnection || !isValidConnectionSettings() || (lastTestTapAt != nil && Date().timeIntervalSince(lastTestTapAt!) < 2))
                
                if isTestingConnection {
                    ProgressView()
                }
                
                if let message = connectionStatus.message, !message.isEmpty {
                    HStack {
                        Image(systemName: connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(connectionStatus.isSuccess ? .green : .red)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(connectionStatus.isSuccess ? .green : .red)
                    }
                    .transition(.opacity)
                }
            }
            
            Section(header: Text("backup.scheduling".localized)) {
                Picker("backup.frequency".localized, selection: $frequencyType) {
                    ForEach(FrequencyType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if frequencyType == .daily || frequencyType == .weekly {
                    TimePicker(time: $selectedTime)
                }
                
                if frequencyType == .weekly {
                    DayPicker(selectedDay: $selectedDay)
                }
            }
            
            // Network ayarları (sadece local server için)
            if isLocalServer() {
                Section(header: Text("backup.network_settings".localized)) {
                    Toggle("backup.allow_cellular".localized, isOn: $allowCellularForLocalServer)
                    
                    if allowCellularForLocalServer {
                        Text("backup.allow_cellular_warning".localized)
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("backup.wifi_only_info".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await saveTask()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text("backup.save_task".localized)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
            }
        }
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
        
        func isLocalServer() -> Bool {
            let host = selectedTarget == .ftp ? ftpHost : webdavURL
            
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
            case .webdav:
                return !webdavURL.isEmpty && !webdavUsername.isEmpty
            }
        }
        
        func testConnection() async {
            if isTestingConnection { return }

            guard isValidConnectionSettings() else {
                let errorMessage = selectedTarget == .ftp ?
                "backup.fill_required_fields".localized :
                "backup.webdav_credentials_required".localized
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
                    
                case .webdav:
                    // Extract host and port from webdavURL
                    let (host, port) = parseWebDAVURL(webdavURL)
                    
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
                }
            }()
            
            // Determine source path and display name based on selection
            let sourcePath = isPhotoLibrarySelected ? "PHOTOS_LIBRARY" : (selectedURL?.path ?? "")
            let displayNameValue = isPhotoLibrarySelected ? selectedMediaType.displayName : (selectedURL?.lastPathComponent ?? "Yeni Yedekleme")
            
            // Check for existing tasks with the same configuration
            let hostToCheck = selectedTarget == .ftp ? ftpHost.lowercased() : webdavURL.lowercased()
            let destPathToCheck = selectedTarget == .ftp ? destinationPath : webdavPath
            
            do {
                let allTasks = try modelContext.fetch(FetchDescriptor<BackupTask>())
                let backupType: BackupType = selectedTarget == .ftp ? .ftp : .webdav
                let portToCheck = selectedTarget == .ftp ? (Int(ftpPort) ?? 21) : 443

                let hasDuplicate = allTasks.contains { task in
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
                print("Görev kontrolü sırasında hata oluştu: \(error.localizedDescription)")
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
                    scheduledTime: (frequencyType == .daily || frequencyType == .weekly) ? selectedTime : nil,
                    scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
                    mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
                    allowCellularForLocalServer: allowCellularForLocalServer
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
                    serverPort: 443, // Default HTTPS port for WebDAV
                    serverUsername: webdavUsername,
                    serverPassword: webdavPassword,
                    destinationPath: webdavPath,
                    displayName: displayNameValue,
                    isEnabled: true,
                    isPaused: false,
                    frequency: frequency,
                    scheduledTime: (frequencyType == .daily || frequencyType == .weekly) ? selectedTime : nil,
                    scheduledWeekday: (frequencyType == .weekly) ? selectedDay : nil,
                    mediaType: isPhotoLibrarySelected ? selectedMediaType : .photosOnly,
                    allowCellularForLocalServer: allowCellularForLocalServer
                )
            }
            
            modelContext.insert(task)
            
            do {
                try modelContext.save()
                print("✅ BackupFlow: Görev başarıyla kaydedildi - \(displayNameValue)")
                saveAlertMessage = "Görev başarıyla kaydedildi"
                
                // Schedule the backup if frequency is set
                if task.frequency != .manual {
                    do {
                        try await BackupScheduler.shared.scheduleBackup(task: task)
                        saveAlertMessage += " ve planlandı"
                    } catch {
                        saveAlertMessage += ", ancak planlama sırasında hata oluştu: \(error.localizedDescription)"
                    }
                }
                
                // Reset form
                selectedURL = nil
                ftpHost = Self.defaultFTPHost
                ftpPort = "21"
                ftpUsername = ""
                ftpPassword = ""
                isAnonymous = false
                
                let now = Date()
                if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                lastAlertAt = now
                showingSaveAlert = true
            } catch {
                saveAlertMessage = "Görev kaydedilirken hata oluştu: \(error.localizedDescription)"
                let now = Date()
                if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
                lastAlertAt = now
                showingSaveAlert = true
            }
        }
        
        // MARK: - WebDAV Helper
        
        func parseWebDAVURL(_ urlString: String) -> (host: String, port: Int) {
            var host = urlString
            var port = 443 // Default HTTPS port
            
            // Remove http:// or https:// prefix if exists
            if let range = host.range(of: "https://") {
                host.removeSubrange(range)
            } else if let range = host.range(of: "http://") {
                host.removeSubrange(range)
                port = 80 // Default HTTP port
            }
            
            // Check for custom port
            if let portRange = host.range(of: ":") {
                let portString = String(host[portRange.upperBound...])
                if let customPort = Int(portString) {
                    port = customPort
                    host = String(host[..<portRange.lowerBound])
                }
            }
            
            // Remove trailing slashes
            host = host.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            return (host, port)
        }
        
        // MARK: - Helper Methods
        
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
            frequencyType = .manual
            selectedTime = ScheduleTime(hour: 0, minute: 0)
            selectedDay = 1
            connectionStatus = .idle
            saveAlertMessage = ""
        }
    }
}
