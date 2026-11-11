import SwiftUI

// Building blocks of the backup setup screen (BackupView). Each section edits the shared
// BackupFormModel; anything that needs the screen's own state is passed in as a closure.

// MARK: - Header

struct BackupSetupHeader: View {
    let title: String
    let form: BackupFormModel
    let theme: BackupSetupTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    Text(form.selectedTarget.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Image(systemName: form.selectedTarget.iconName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.16))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }

            HStack(spacing: 10) {
                Image(systemName: form.isPhotoLibrarySelected ? form.selectedMediaType.systemImageName : "folder.fill")
                    .font(.callout.weight(.semibold))
                    .accessibilityHidden(true)
                Text(form.isPhotoLibrarySelected ? form.selectedMediaType.displayName : (form.selectedURL?.lastPathComponent ?? "backup.source_section".localized))
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
                        colors: [theme.primary, theme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .bottomTrailing) {
            Text(form.selectedTarget.rawValue)
                .font(.system(size: 66, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.12))
                .padding(.trailing, 18)
                .offset(y: 14)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

// MARK: - Source

struct BackupSourceSection: View {
    @Bindable var form: BackupFormModel
    let theme: BackupSetupTheme
    /// Called after the photo library is chosen, to ask for access if needed.
    let onChoosePhotos: () -> Void
    /// Called after a folder source is chosen, to present the document picker.
    let onChooseFolder: () -> Void

    var body: some View {
        BackupSetupCard(
            title: "backup.source_section".localized,
            icon: "photo.on.rectangle.angled",
            theme: theme
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    form.isPhotoLibrarySelected = true
                    form.selectedURL = nil
                    onChoosePhotos()
                } label: {
                    BackupChoiceRow(
                        icon: "photo.on.rectangle.angled",
                        title: "backup.photos_option".localized,
                        subtitle: form.selectedMediaType.displayName,
                        isSelected: form.isPhotoLibrarySelected,
                        theme: theme
                    )
                }
                .buttonStyle(.plain)

                if form.isPhotoLibrarySelected {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("backup.media_type_caption".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(MediaType.allCases) { mediaType in
                            Button {
                                form.selectedMediaType = mediaType
                            } label: {
                                BackupChoiceRow(
                                    icon: mediaType.systemImageName,
                                    title: mediaType.displayName,
                                    subtitle: nil,
                                    isSelected: form.selectedMediaType == mediaType,
                                    theme: theme
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle("backup.photo_backup_include_icloud".localized, isOn: $form.includeICloudAssets)
                            .tint(theme.primary)
                            .padding(.top, 2)

                        Text("backup.photo_backup_include_icloud_hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()
                            .padding(.vertical, 2)

                        HStack {
                            Text("backup.photo_folder_structure".localized)
                                .font(.subheadline)
                                .accessibilityHidden(true)
                            Spacer()
                            Picker("backup.photo_folder_structure".localized, selection: $form.photoFolderStructure) {
                                ForEach(PhotoFolderStructure.allCases) { structure in
                                    Text(structure.displayName).tag(structure)
                                }
                            }
                            .labelsHidden()
                        }

                        Toggle("backup.preserve_original_format".localized, isOn: $form.preserveOriginalPhotoFormat)
                            .tint(theme.primary)

                        Text("backup.preserve_original_format_hint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(theme.primary.opacity(0.06))
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
                    form.isPhotoLibrarySelected = false
                    onChooseFolder()
                } label: {
                    BackupChoiceRow(
                        icon: "folder.fill",
                        title: form.selectedURL?.lastPathComponent ?? "backup.folder_select".localized,
                        subtitle: form.selectedURL?.path,
                        isSelected: !form.isPhotoLibrarySelected && form.selectedURL != nil,
                        theme: theme
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Target

struct BackupTargetSection: View {
    @Bindable var form: BackupFormModel
    let theme: BackupSetupTheme
    let hasValidConnectionSettings: Bool
    let isTestingConnection: Bool
    let isTestButtonDisabled: Bool
    let connectionStatus: ConnectionStatus
    let onTestConnection: () -> Void
    let onBrowseRemoteFolder: () -> Void

    var body: some View {
        BackupSetupCard(
            title: "backup.target_type".localized,
            icon: form.selectedTarget.iconName,
            theme: theme
        ) {
            VStack(alignment: .leading, spacing: 12) {
                BackupTargetView(
                    selectedTarget: $form.selectedTarget,
                    ftpHost: $form.ftpHost,
                    ftpPort: $form.ftpPort,
                    ftpUsername: $form.ftpUsername,
                    ftpPassword: $form.ftpPassword,
                    destinationPath: $form.destinationPath,
                    isAnonymous: $form.isAnonymous,
                    sftpHost: $form.sftpHost,
                    sftpPort: $form.sftpPort,
                    sftpUsername: $form.sftpUsername,
                    sftpPassword: $form.sftpPassword,
                    sftpPath: $form.sftpPath,
                    webdavURL: $form.webdavURL,
                    webdavPort: $form.webdavPort,
                    webdavUsername: $form.webdavUsername,
                    webdavPassword: $form.webdavPassword,
                    webdavPath: $form.webdavPath
                )

                Button(action: onTestConnection) {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "network")
                                .accessibilityHidden(true)
                        }
                        Text("backup.test_connection".localized)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(hasValidConnectionSettings ? theme.primary : Color.secondary.opacity(0.22))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isTestButtonDisabled)

                if let message = connectionStatus.message, !message.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: connectionStatus.isTesting ? "hourglass" : (connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"))
                            .accessibilityHidden(true)
                        Text(message)
                            .font(.caption)
                    }
                    .foregroundStyle(connectionStatus.isTesting ? .secondary : (connectionStatus.isSuccess ? Color.green : Color.red))
                    .transition(.opacity)
                }

                Button(action: onBrowseRemoteFolder) {
                    Label("backup.remote_folder.browse".localized, systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!hasValidConnectionSettings)
            }
        }
    }
}

// MARK: - Schedule

struct BackupScheduleSection: View {
    @Bindable var form: BackupFormModel
    let theme: BackupSetupTheme

    var body: some View {
        BackupSetupCard(
            title: "backup.scheduling".localized,
            icon: "clock.arrow.circlepath",
            theme: theme
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("backup.frequency".localized, selection: $form.frequencyType) {
                    ForEach(FrequencyType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if form.frequencyType == .daily || form.frequencyType == .weekly {
                    TimePicker(time: $form.selectedTime)
                }

                if form.frequencyType == .weekly {
                    DayPicker(selectedDay: $form.selectedDay)
                }

                if form.frequencyType == .monthly {
                    Stepper("backup.month_day".localized(with: form.selectedMonthDay), value: $form.selectedMonthDay, in: 1...31)
                    TimePicker(time: $form.selectedTime)
                }

                if form.frequencyType == .intervalHours {
                    Stepper("backup.every_hours".localized(with: form.intervalHours), value: $form.intervalHours, in: 1...24)
                }
            }
        }
    }
}

// MARK: - Behavior

struct BackupBehaviorSection: View {
    @Bindable var form: BackupFormModel
    let theme: BackupSetupTheme

    var body: some View {
        BackupSetupCard(
            title: "backup.behavior".localized,
            icon: "slider.horizontal.3",
            theme: theme
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Menu pickers outside a Form show only the value, so draw the label
                // beside them; the picker itself still carries it for VoiceOver.
                HStack {
                    Text("backup.deletion_policy".localized)
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("backup.deletion_policy".localized, selection: $form.deletionPolicy) {
                        ForEach(BackupDeletionPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .labelsHidden()
                }

                HStack {
                    Text("backup.checksum".localized)
                        .accessibilityHidden(true)
                    Spacer()
                    Picker("backup.checksum".localized, selection: $form.checksumMode) {
                        ForEach(BackupChecksumMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                }

                Toggle("backup.require_wifi".localized, isOn: $form.requiresWiFi)
                    .tint(theme.primary)

                Toggle("backup.require_external_power".localized, isOn: $form.requiresExternalPower)
                    .tint(theme.primary)

                Toggle("backup.use_allowed_time_window".localized, isOn: $form.useAllowedWindow)
                    .tint(theme.primary)

                if form.useAllowedWindow {
                    TimePicker(time: $form.allowedStartTime)
                    TimePicker(time: $form.allowedEndTime)
                }

                if form.deletionPolicy == .archive {
                    Text("backup.archive_policy_warning".localized)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if form.deletionPolicy == .mirror {
                    Text("backup.mirror_policy_warning".localized)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Network

/// Shown only for servers on the local network.
struct BackupNetworkSection: View {
    @Bindable var form: BackupFormModel
    let theme: BackupSetupTheme

    var body: some View {
        BackupSetupCard(
            title: "backup.network_settings".localized,
            icon: "antenna.radiowaves.left.and.right",
            theme: theme
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("backup.allow_cellular".localized, isOn: $form.allowCellularForLocalServer)
                    .tint(theme.primary)

                Text(form.allowCellularForLocalServer ? "backup.allow_cellular_warning".localized : "backup.wifi_only_info".localized)
                    .font(.caption)
                    .foregroundStyle(form.allowCellularForLocalServer ? .orange : .secondary)
            }
        }
    }
}

// MARK: - Save

struct BackupSaveButton: View {
    let theme: BackupSetupTheme
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityHidden(true)
                Text("backup.save_task".localized)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [theme.primary, theme.secondary]
                        : [Color.secondary.opacity(0.22), Color.secondary.opacity(0.22)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: theme.primary.opacity(isEnabled ? 0.22 : 0), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("backup.save")
    }
}

// MARK: - Shared Styling

struct BackupSetupTheme {
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
                    .accessibilityHidden(true)

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
                .accessibilityHidden(true)

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
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .padding(12)
        .background(isSelected ? theme.primary.opacity(0.08) : Color(.secondarySystemBackground).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
