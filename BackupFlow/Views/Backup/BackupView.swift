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

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = BackupViewModel()
    
    var body: some View {
        Form {
            SourceSection(viewModel: viewModel)
            
            TargetSection(viewModel: viewModel)
            
            SchedulingSection(viewModel: viewModel)
            
            if viewModel.isLocalServer() {
                NetworkSection(viewModel: viewModel)
            }
            
            SaveSection(viewModel: viewModel)
        }
        .navigationTitle("backup.new_backup".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("backup.clear".localized) {
                    viewModel.resetForm()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingDocumentPicker) {
            DocumentPicker(url: $viewModel.selectedURL) {
                viewModel.showingDocumentPicker = false
            }
        }
        .alert("backup.info_title".localized, isPresented: $viewModel.showingSaveAlert) {
            Button("backup.ok".localized, role: .cancel) {}
        } message: {
            Text(viewModel.saveAlertMessage)
        }
        .alert("backup.first_start_prompt_title".localized, isPresented: $viewModel.showingFirstBackupPrompt) {
            Button("backup.notification.action.start".localized) {
                guard let taskToStart = viewModel.firstBackupTaskToStart else { return }
                Task {
                    try? await BackupScheduler.shared.performBackup(task: taskToStart)
                }
            }
            Button("backup.first_start_prompt_later".localized, role: .cancel) {}
        } message: {
            Text("backup.first_start_prompt_message".localized)
        }
    }
}

// MARK: - Subviews

private struct SourceSection: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section(header: Text("backup.source_section".localized)) {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: {
                    viewModel.isPhotoLibrarySelected = true
                    viewModel.selectedURL = nil
                    requestPhotoLibraryAccess()
                }) {
                    HStack {
                        Image(systemName: viewModel.isPhotoLibrarySelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.isPhotoLibrarySelected ? .blue : .gray)
                        Text("backup.photos_option".localized)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if viewModel.isPhotoLibrarySelected {
                    MediaSelectionView(viewModel: viewModel)
                }
                
                OrDivider()
                
                FolderSelectionView(viewModel: viewModel)
            }
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PhotoLibraryManager.shared.requestAuthorization { granted in
            if !granted {
                DispatchQueue.main.async {
                    viewModel.showingPhotoLibraryDeniedAlert = true
                }
            }
        }
    }
}

private struct MediaSelectionView: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("backup.media_type_caption".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(MediaType.allCases) { mediaType in
                Button(action: { viewModel.selectedMediaType = mediaType }) {
                    HStack {
                        Image(systemName: viewModel.selectedMediaType == mediaType ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(viewModel.selectedMediaType == mediaType ? .blue : .gray)
                        Image(systemName: mediaType.systemImageName)
                            .foregroundColor(.blue)
                        Text(mediaType.displayName)
                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.leading, 24)
        .padding(.top, 8)
    }
}

private struct OrDivider: View {
    var body: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
            Text("backup.or".localized).font(.caption).foregroundColor(.gray).padding(.horizontal, 8)
            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 4)
    }
}

private struct FolderSelectionView: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        HStack {
            Image(systemName: !viewModel.isPhotoLibrarySelected && viewModel.selectedURL != nil ? "checkmark.circle.fill" : "circle")
                .foregroundColor(!viewModel.isPhotoLibrarySelected && viewModel.selectedURL != nil ? .blue : .gray)
            
            Button {
                viewModel.isPhotoLibrarySelected = false
                viewModel.showingDocumentPicker = true
            } label: {
                if let url = viewModel.selectedURL {
                    Text(url.lastPathComponent).foregroundColor(.blue)
                } else {
                    Text("backup.folder_select".localized).foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
        }
    }
}

private struct TargetSection: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section {
            BackupTargetView(
                selectedTarget: $viewModel.selectedTarget,
                ftpHost: $viewModel.ftpHost,
                ftpPort: $viewModel.ftpPort,
                ftpUsername: $viewModel.ftpUsername,
                ftpPassword: $viewModel.ftpPassword,
                destinationPath: $viewModel.destinationPath,
                isAnonymous: $viewModel.isAnonymous,
                sftpHost: $viewModel.sftpHost,
                sftpPort: $viewModel.sftpPort,
                sftpUsername: $viewModel.sftpUsername,
                sftpPassword: $viewModel.sftpPassword,
                sftpPath: $viewModel.sftpPath,
                webdavURL: $viewModel.webdavURL,
                webdavPort: $viewModel.webdavPort,
                webdavUsername: $viewModel.webdavUsername,
                webdavPassword: $viewModel.webdavPassword,
                webdavPath: $viewModel.webdavPath
            )
            
            Button {
                Task { await viewModel.testConnection() }
            } label: {
                Text("backup.test_connection".localized)
            }
            .disabled(viewModel.isTestingConnection || !viewModel.isValidConnectionSettings())
            
            if viewModel.isTestingConnection {
                ProgressView()
            }
            
            if let message = viewModel.connectionStatus.message, !message.isEmpty {
                HStack {
                    Image(systemName: viewModel.connectionStatus.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(viewModel.connectionStatus.isSuccess ? .green : .red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(viewModel.connectionStatus.isSuccess ? .green : .red)
                }
            }
        }
    }
}

private struct SchedulingSection: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section(header: Text("backup.scheduling".localized)) {
            Picker("backup.frequency".localized, selection: $viewModel.frequencyType) {
                Text("backup.frequency.manual".localized).tag(BackupFrequency.manual)
                Text("backup.frequency.daily".localized).tag(BackupFrequency.daily(time: viewModel.selectedTime))
                Text("backup.frequency.weekly".localized).tag(BackupFrequency.weekly(day: viewModel.selectedDay, time: viewModel.selectedTime))
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if case .daily = viewModel.frequencyType {
                TimePicker(time: $viewModel.selectedTime)
            } else if case .weekly = viewModel.frequencyType {
                TimePicker(time: $viewModel.selectedTime)
                DayPicker(selectedDay: $viewModel.selectedDay)
            }
        }
    }
}

private struct NetworkSection: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section(header: Text("backup.network_settings".localized)) {
            Toggle("backup.allow_cellular".localized, isOn: $viewModel.allowCellularForLocalServer)
            
            Text(viewModel.allowCellularForLocalServer ? "backup.allow_cellular_warning".localized : "backup.wifi_only_info".localized)
                .font(.caption)
                .foregroundColor(viewModel.allowCellularForLocalServer ? .orange : .secondary)
        }
    }
}

private struct SaveSection: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section {
            Button(action: {
                Task { await viewModel.saveTask(modelContext: modelContext) }
            }) {
                HStack {
                    Spacer()
                    Text("backup.save_task".localized).fontWeight(.semibold)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
        }
    }
}
