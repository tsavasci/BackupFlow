import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Photos
import UIKit

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

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let editingTask: BackupTask?

    @State private var form: BackupFormModel

    @State private var showingDocumentPicker = false
    @State private var showingSaveAlert = false
    @State private var closeAfterSaveAlert = false
    @State private var showingPhotoLibraryDeniedAlert = false
    @State private var saveAlertMessage = ""
    @State private var lastAlertAt: Date? = nil
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var lastTestTapAt: Date? = nil
    @State private var showingStartPrompt = false
    @State private var backupTaskToStart: BackupTask? = nil
    @State private var showingSFTPHostKeyAlert = false
    @State private var sftpHostKeyAlertMessage = ""
    @State private var showingRemoteFolderPicker = false
    @State private var showingLocalServerDiscovery = false
    @State private var showingKeyImporter = false
    @State private var keyImportError: String?

    private var screenTitle: String {
        editingTask == nil ? "backup.new_backup".localized : "common.edit".localized
    }

    /// The connection test button stays disabled for 2 seconds after a tap.
    private var isTestTapThrottled: Bool {
        guard let lastTestTapAt else { return false }
        return Date().timeIntervalSince(lastTestTapAt) < 2
    }

    init(editingTask: BackupTask? = nil) {
        self.editingTask = editingTask
        _form = State(initialValue: BackupFormModel(editingTask: editingTask))
    }

    var body: some View {
        Form {
            sourceSection
            targetSection
            scheduleSection
            behaviorSection
        }
        .scrollContentBackground(.hidden)
        .background(BF.bg)
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("alert.cancel".localized) { dismiss() }
                    .accessibilityIdentifier("sheet.close")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("form.save".localized) {
                    Task { await saveTask() }
                }
                .disabled(!form.canSave)
                .fontWeight(.semibold)
                .accessibilityIdentifier("backup.save")
            }
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(
                url: $form.selectedURL,
                onDismiss: {
                    showingDocumentPicker = false
                },
                onError: { message in
                    saveAlertMessage = message
                    closeAfterSaveAlert = false
                    showingSaveAlert = true
                }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showingKeyImporter,
            allowedContentTypes: [.data, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            handleKeyImport(result)
        }
        .alert("backup.info_title".localized, isPresented: $showingSaveAlert) {
            Button("backup.ok".localized, role: .cancel) {
                if closeAfterSaveAlert {
                    closeAfterSaveAlert = false
                    dismiss()
                }
            }
        } message: {
            Text(saveAlertMessage)
        }
        .alert("backup.photo_permission_required".localized, isPresented: $showingPhotoLibraryDeniedAlert) {
            Button("backup.ok".localized, role: .cancel) {}
        }
        .alert(
            "backup.start_prompt_title".localized,
            isPresented: $showingStartPrompt,
            presenting: backupTaskToStart
        ) { taskToStart in
            Button("backup.notification.action.start".localized) {
                BackupScheduler.shared.startUserInitiatedBackup(
                    task: taskToStart,
                    ignoreWiFiRequirement: BackupScheduler.shared.needsWiFiConfirmation(for: taskToStart)
                )
                backupTaskToStart = nil
                dismiss()
            }
            .accessibilityIdentifier("backup.start_now")
            Button("backup.start_prompt_later".localized, role: .cancel) {
                backupTaskToStart = nil
                dismiss()
            }
            .accessibilityIdentifier("backup.start_later")
        } message: { taskToStart in
            let mirrorWarning = taskToStart.deletionPolicy == .mirror ? "\n\n" + "backup.mirror_policy_warning".localized : ""
            let wifiWarning = BackupScheduler.shared.needsWiFiConfirmation(for: taskToStart) ? "\n\n" + "backup.wifi_confirm.message".localized : ""
            Text("backup.start_prompt_message".localized + mirrorWarning + wifiWarning)
        }
        .alert("sftp.hostkey_title".localized, isPresented: $showingSFTPHostKeyAlert) {
            Button("backup.ok".localized, role: .cancel) {}
        } message: {
            Text(sftpHostKeyAlertMessage)
        }
        .sheet(isPresented: $showingLocalServerDiscovery) {
            LocalServerDiscoverySheet(
                onSelectDiscovered: { server, host, port in
                    form.applyDiscoveredServer(server, host: host, port: port)
                    connectionStatus = .idle
                },
                onSelectSavedProfile: { profile in
                    form.applySavedProfile(profile)
                    connectionStatus = .idle
                }
            )
        }
        .sheet(isPresented: $showingRemoteFolderPicker) {
            let config = form.remoteFolderConfig
            RemoteFolderPicker(
                target: form.selectedTarget,
                host: config.host,
                port: config.port,
                username: config.username,
                password: config.password,
                privateKey: config.privateKey,
                passphrase: config.passphrase
            ) { selectedPath in
                switch form.selectedTarget {
                case .ftp:
                    form.destinationPath = selectedPath
                case .sftp:
                    form.sftpPath = selectedPath
                case .webdav:
                    form.webdavPath = selectedPath
                }
            }
        }
    }

    // MARK: - Kaynak

    private var sourceSection: some View {
        Section {
            TextField("form.name_optional".localized, text: $form.customName)

            Picker("backup.source_section".localized, selection: $form.isPhotoLibrarySelected) {
                Text("backup.photos_option".localized).tag(true)
                Text("backup.folder_select".localized).tag(false)
            }
            .onChange(of: form.isPhotoLibrarySelected) { _, isPhotos in
                if isPhotos {
                    requestPhotoLibraryAccess()
                }
            }

            if form.isPhotoLibrarySelected {
                Picker("form.scope".localized, selection: $form.selectedMediaType) {
                    ForEach(MediaType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }

                Toggle("backup.photo_backup_include_icloud".localized, isOn: $form.includeICloudAssets)

                Picker("backup.photo_folder_structure".localized, selection: $form.photoFolderStructure) {
                    ForEach(PhotoFolderStructure.allCases) { structure in
                        Text(structure.displayName).tag(structure)
                    }
                }

                Toggle("backup.preserve_original_format".localized, isOn: $form.preserveOriginalPhotoFormat)
            } else {
                Button {
                    showingDocumentPicker = true
                } label: {
                    LabeledContent("backup.folder_select".localized) {
                        Text(form.selectedURL?.lastPathComponent ?? "form.choose".localized)
                            .foregroundStyle(form.selectedURL == nil ? BF.accent : .secondary)
                    }
                }
            }
        } header: {
            sectionLabel("backup.source_section".localized.uppercased())
        }
        .listRowBackground(BF.surface)
    }

    // MARK: - Hedef

    private var targetSection: some View {
        Section {
            Picker("backup.target_type".localized, selection: $form.selectedTarget) {
                ForEach(BackupTarget.allCases) { target in
                    Text(target.displayName).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .onChange(of: form.selectedTarget) { _, _ in
                connectionStatus = .idle
            }

            Button {
                showingLocalServerDiscovery = true
            } label: {
                Label("backup.scan_network".localized, systemImage: "dot.radiowaves.left.and.right")
            }

            switch form.selectedTarget {
            case .ftp:
                ftpFields
            case .sftp:
                sftpFields
            case .webdav:
                webdavFields
            }

            Button {
                Task {
                    let now = Date()
                    if let last = lastTestTapAt, now.timeIntervalSince(last) < 2 { return }
                    lastTestTapAt = now
                    await testConnection()
                }
            } label: {
                HStack {
                    Text("backup.test_connection".localized)
                    Spacer()
                    testResult
                }
            }
            .disabled(isTestingConnection || !form.hasValidConnectionSettings || isTestTapThrottled)

            Button("backup.remote_folder.browse".localized) {
                showingRemoteFolderPicker = true
            }
            .disabled(!form.hasValidConnectionSettings)
        } header: {
            sectionLabel("backup.target_type".localized.uppercased())
        }
        .listRowBackground(BF.surface)
    }

    @ViewBuilder
    private var ftpFields: some View {
        LabeledContent("form.server".localized) {
            TextField("192.168.1.20", text: $form.ftpHost)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }

        LabeledContent("form.port".localized) {
            TextField("21", text: $form.ftpPort)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .keyboardType(.numberPad)
        }

        Toggle("backup.anonymous_login".localized, isOn: $form.isAnonymous)

        if !form.isAnonymous {
            LabeledContent("backup.username".localized) {
                TextField("backup.username".localized, text: $form.ftpUsername)
                    .multilineTextAlignment(.trailing)
                    .font(BF.mono)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            LabeledContent("backup.password".localized) {
                SecureField("backup.password".localized, text: $form.ftpPassword)
                    .multilineTextAlignment(.trailing)
            }
        }

        LabeledContent("form.remote_path".localized) {
            TextField("/", text: $form.destinationPath)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var sftpFields: some View {
        LabeledContent("form.server".localized) {
            TextField("192.168.1.20", text: $form.sftpHost)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }

        LabeledContent("form.port".localized) {
            TextField("22", text: $form.sftpPort)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .keyboardType(.numberPad)
        }

        Picker("backup.sftp_auth_method".localized, selection: $form.sftpAuthMethod) {
            ForEach(SFTPAuthMethod.allCases) { method in
                Text(method.displayName).tag(method)
            }
        }

        LabeledContent("backup.username".localized) {
            TextField("backup.username".localized, text: $form.sftpUsername)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        if form.sftpAuthMethod == .password {
            LabeledContent("backup.password".localized) {
                SecureField("backup.password".localized, text: $form.sftpPassword)
                    .multilineTextAlignment(.trailing)
            }
        } else {
            Button {
                showingKeyImporter = true
            } label: {
                LabeledContent("backup.sftp_import_key".localized) {
                    Text(form.sftpKeyName.isEmpty ? "form.choose".localized : form.sftpKeyName)
                        .foregroundStyle(form.sftpKeyName.isEmpty ? BF.accent : BF.ok)
                        .font(BF.monoSmall)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            LabeledContent("backup.sftp_key_passphrase".localized) {
                SecureField("backup.password".localized, text: $form.sftpKeyPassphrase)
                    .multilineTextAlignment(.trailing)
            }

            if let keyImportError {
                Text(keyImportError)
                    .font(BF.monoSmall)
                    .foregroundStyle(BF.fail)
            }
        }

        LabeledContent("form.remote_path".localized) {
            TextField("/", text: $form.sftpPath)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var webdavFields: some View {
        LabeledContent("form.server".localized) {
            TextField("https://cloud.example.com/remote.php/dav/files/", text: $form.webdavURL)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }

        LabeledContent("form.port".localized) {
            TextField("443", text: $form.webdavPort)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .keyboardType(.numberPad)
        }

        LabeledContent("backup.username".localized) {
            TextField("backup.username".localized, text: $form.webdavUsername)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }

        LabeledContent("backup.password".localized) {
            SecureField("backup.password".localized, text: $form.webdavPassword)
                .multilineTextAlignment(.trailing)
        }

        LabeledContent("form.remote_path".localized) {
            TextField("/", text: $form.webdavPath)
                .multilineTextAlignment(.trailing)
                .font(BF.mono)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var testResult: some View {
        switch connectionStatus {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success(let message):
            Text(message)
                .font(BF.monoSmall)
                .foregroundStyle(BF.ok)
                .lineLimit(1)
        case .failure(let message):
            Text(message)
                .font(BF.monoSmall)
                .foregroundStyle(BF.fail)
                .lineLimit(1)
        }
    }

    // MARK: - Zamanlama

    private var scheduleSection: some View {
        Section {
            Picker("backup.frequency".localized, selection: $form.frequencyType) {
                ForEach(FrequencyType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            switch form.frequencyType {
            case .manual:
                EmptyView()
            case .intervalHours:
                Stepper(
                    "backup.every_hours".localized(with: form.intervalHours),
                    value: $form.intervalHours,
                    in: 1...48
                )
            case .daily:
                DatePicker("backup.hour".localized, selection: scheduleTimeBinding($form.selectedTime), displayedComponents: .hourAndMinute)
            case .weekly:
                Picker("backup.day".localized, selection: $form.selectedDay) {
                    ForEach(weekdays, id: \.0) { day, name in
                        Text(name).tag(day)
                    }
                }
                DatePicker("backup.hour".localized, selection: scheduleTimeBinding($form.selectedTime), displayedComponents: .hourAndMinute)
            case .monthly:
                Stepper("backup.month_day".localized(with: form.selectedMonthDay), value: $form.selectedMonthDay, in: 1...31)
                DatePicker("backup.hour".localized, selection: scheduleTimeBinding($form.selectedTime), displayedComponents: .hourAndMinute)
            }
        } header: {
            sectionLabel("backup.scheduling".localized.uppercased())
        }
        .listRowBackground(BF.surface)
    }

    // MARK: - Davranış

    private var behaviorSection: some View {
        Section {
            Picker("backup.deletion_policy".localized, selection: $form.deletionPolicy) {
                ForEach(BackupDeletionPolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }

            Toggle("form.checksum_verify".localized, isOn: Binding(
                get: { form.checksumMode == .verifyUploads },
                set: { form.checksumMode = $0 ? .verifyUploads : .off }
            ))

            Toggle("backup.require_wifi".localized, isOn: $form.requiresWiFi)
            Toggle("backup.require_external_power".localized, isOn: $form.requiresExternalPower)

            if form.isLocalServer {
                Toggle("backup.allow_cellular".localized, isOn: $form.allowCellularForLocalServer)
            }

            Toggle("backup.use_allowed_time_window".localized, isOn: $form.useAllowedWindow)

            if form.useAllowedWindow {
                DatePicker("form.window_start".localized, selection: scheduleTimeBinding($form.allowedStartTime), displayedComponents: .hourAndMinute)
                DatePicker("form.window_end".localized, selection: scheduleTimeBinding($form.allowedEndTime), displayedComponents: .hourAndMinute)
            }
        } header: {
            sectionLabel("backup.behavior".localized.uppercased())
        } footer: {
            Text(deletionPolicyFooter)
        }
        .listRowBackground(BF.surface)
    }

    private var deletionPolicyFooter: String {
        switch form.deletionPolicy {
        case .appendOnly:
            return "form.append_only_footer".localized
        case .mirror:
            return "backup.mirror_policy_warning".localized
        case .archive:
            return "backup.archive_policy_warning".localized
        }
    }

    private var weekdays: [(Int, String)] {
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

    private func scheduleTimeBinding(_ time: Binding<ScheduleTime>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: time.wrappedValue.hour, minute: time.wrappedValue.minute)) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                time.wrappedValue.hour = components.hour ?? 0
                time.wrappedValue.minute = components.minute ?? 0
            }
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(BF.monoSmall)
            .textCase(nil)
    }

    // MARK: - Actions

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
                guard let content = String(data: data, encoding: .utf8), !content.isEmpty else {
                    keyImportError = "backup.sftp_key_import_failed".localized
                    return
                }
                form.sftpPrivateKey = content
                form.sftpKeyName = url.lastPathComponent
            } catch {
                keyImportError = "backup.sftp_key_import_failed".localized
            }
        case .failure:
            keyImportError = "backup.sftp_key_import_failed".localized
        }
    }

    private func testConnection() async {
        if isTestingConnection { return }

        guard form.hasValidConnectionSettings else {
            connectionStatus = .failure(form.incompleteSettingsMessage)
            return
        }

        isTestingConnection = true
        connectionStatus = .testing("backup.connection_testing".localized)

        let result = await form.testConnection()
        connectionStatus = result.status
        if let fingerprint = result.newSFTPHostKeyFingerprint {
            sftpHostKeyAlertMessage = String(format: "sftp.hostkey_message".localized, fingerprint)
            showingSFTPHostKeyAlert = true
        }

        isTestingConnection = false
    }

    private func requestPhotoLibraryAccess() {
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

    private func saveTask() async {
        if let message = form.sourceValidationError() {
            showSaveAlert(message)
            return
        }
        if hasDuplicateTask() {
            showSaveAlert("tasks.duplicate_error".localized)
            return
        }
        if let message = form.missingHostMessage {
            showSaveAlert(message)
            return
        }

        let task = form.makeTask()
        let taskToSave: BackupTask
        if let editingTask {
            BackupFormModel.copyTaskFields(from: task, to: editingTask)
            task.removeStoredPassword()
            taskToSave = editingTask
        } else {
            modelContext.insert(task)
            taskToSave = task
        }

        do {
            try modelContext.save()
            debugLog("✅ BackupFlow: Görev başarıyla kaydedildi - \(task.displayName)")
            saveAlertMessage = "tasks.save_success".localized

            if taskToSave.frequency != .manual {
                do {
                    try await BackupScheduler.shared.scheduleBackup(task: taskToSave)
                    saveAlertMessage += " " + "tasks.scheduled".localized
                } catch {
                    saveAlertMessage += " " + "tasks.schedule_error_detail".localized(with: error.localizedDescription)
                }
            } else {
                BackupScheduler.shared.scheduleProcessingTask()
            }

            form.clearConnectionFieldsAfterSave()

            if editingTask == nil {
                backupTaskToStart = taskToSave
                showingStartPrompt = true
            } else {
                showSaveAlert(saveAlertMessage, closeAfterDismiss: true)
            }
        } catch {
            showSaveAlert("tasks.save_error_detail".localized(with: error.localizedDescription))
        }
    }

    private func hasDuplicateTask() -> Bool {
        do {
            let allTasks = try modelContext.fetch(FetchDescriptor<BackupTask>())
            return allTasks.contains { task in
                if let editingTask, task.id == editingTask.id { return false }
                return form.describesSameBackup(as: task)
            }
        } catch {
            debugLog("Görev kontrolü sırasında hata oluştu: \(error.localizedDescription)")
            return false
        }
    }

    private func showSaveAlert(_ message: String, closeAfterDismiss: Bool = false) {
        saveAlertMessage = message
        let now = Date()
        if let last = lastAlertAt, now.timeIntervalSince(last) < 1 { return }
        lastAlertAt = now
        if closeAfterDismiss {
            closeAfterSaveAlert = true
        }
        showingSaveAlert = true
    }
}
