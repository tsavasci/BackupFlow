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
        let targetTheme = BackupSetupTheme.theme(for: form.selectedTarget)

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
                    BackupSetupHeader(title: screenTitle, form: form, theme: targetTheme)

                    BackupSourceSection(
                        form: form,
                        theme: targetTheme,
                        onChoosePhotos: requestPhotoLibraryAccess,
                        onChooseFolder: { showingDocumentPicker = true }
                    )

                    BackupTargetSection(
                        form: form,
                        theme: targetTheme,
                        hasValidConnectionSettings: form.hasValidConnectionSettings,
                        isTestingConnection: isTestingConnection,
                        isTestButtonDisabled: isTestingConnection || !form.hasValidConnectionSettings || isTestTapThrottled,
                        connectionStatus: connectionStatus,
                        onTestConnection: {
                            Task {
                                let now = Date()
                                if let last = lastTestTapAt, now.timeIntervalSince(last) < 2 { return }
                                lastTestTapAt = now
                                await testConnection()
                            }
                        },
                        onBrowseRemoteFolder: { showingRemoteFolderPicker = true }
                    )

                    BackupScheduleSection(form: form, theme: targetTheme)

                    BackupBehaviorSection(form: form, theme: targetTheme)

                    if form.isLocalServer {
                        BackupNetworkSection(form: form, theme: targetTheme)
                    }

                    BackupSaveButton(theme: targetTheme, isEnabled: form.canSave) {
                        Task {
                            await saveTask()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("task.details.close".localized) { dismiss() }
                    .accessibilityIdentifier("sheet.close")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("backup.clear".localized) {
                    resetForm()
                    showingSaveAlert = false
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(url: $form.selectedURL) {
                showingDocumentPicker = false
            }
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
        .alert(
            "backup.start_prompt_title".localized,
            isPresented: $showingStartPrompt,
            presenting: backupTaskToStart
        ) { taskToStart in
            Button("backup.notification.action.start".localized) {
                // The message below already warned about the missing Wi-Fi, so tapping
                // Start is the confirmation.
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
        .sheet(isPresented: $showingRemoteFolderPicker) {
            let config = form.remoteFolderConfig
            RemoteFolderPicker(
                target: form.selectedTarget,
                host: config.host,
                port: config.port,
                username: config.username,
                password: config.password
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

    // MARK: - Actions

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
        // Every check runs before the task is built, since building it stores the password.
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

            form.clearConnectionFieldsAfterSave()

            if editingTask == nil {
                // A new task never starts on its own: the first run can upload, and under
                // the mirror policy delete, many remote files, so ask first.
                backupTaskToStart = taskToSave
                showingStartPrompt = true
            } else {
                // The edit is saved; confirming the alert returns to the task.
                showSaveAlert(saveAlertMessage, closeAfterDismiss: true)
            }
        } catch {
            showSaveAlert("tasks.save_error_detail".localized(with: error.localizedDescription))
        }
    }

    /// Whether another task already backs up the same source to the same server folder.
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

    /// Shows the info alert; repeats within a second (double taps) only update the message.
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

    private func resetForm() {
        form.reset()
        connectionStatus = .idle
        saveAlertMessage = ""
    }
}
