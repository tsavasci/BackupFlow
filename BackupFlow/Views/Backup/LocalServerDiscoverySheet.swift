import SwiftData
import SwiftUI

struct SavedServerProfile: Identifiable, Hashable {
    let id: String
    let taskID: UUID
    let title: String
    let target: BackupTarget
    let host: String
    let port: Int
    let username: String
    let destinationPath: String
    let sftpAuthMethod: SFTPAuthMethod
    let sftpKeyName: String
}

struct LocalServerDiscoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BackupTask.createdAt, order: .reverse) private var queriedTasks: [BackupTask]

    @State private var discovery = LocalServerDiscoveryService()
    @State private var resolvingID: String?

    let onSelectDiscovered: (LocalServerDiscoveryService.DiscoveredServer, String, Int) -> Void
    let onSelectSavedProfile: (SavedServerProfile) -> Void

    private var savedProfiles: [SavedServerProfile] {
        var seen = Set<String>()
        var profiles: [SavedServerProfile] = []
        for task in queriedTasks where task.modelContext != nil {
            let target: BackupTarget = switch task.backupType {
            case .ftp: .ftp
            case .sftp: .sftp
            case .webdav: .webdav
            }
            let key = "\(task.backupType.rawValue)|\(task.serverHost)|\(task.serverPort)|\(task.serverUsername)"
            guard !task.serverHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seen.insert(key).inserted else { continue }
            profiles.append(
                SavedServerProfile(
                    id: key,
                    taskID: task.id,
                    title: task.displayName.isEmpty ? task.serverHost : task.displayName,
                    target: target,
                    host: task.serverHost,
                    port: task.serverPort,
                    username: task.serverUsername,
                    destinationPath: task.destinationPath,
                    sftpAuthMethod: task.sftpAuthMethod,
                    sftpKeyName: task.sftpKeyName ?? ""
                )
            )
        }
        return profiles
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if discovery.discoveredServers.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("backup.discovery.searching".localized)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(discovery.discoveredServers) { server in
                            Button {
                                Task {
                                    resolvingID = server.id
                                    let resolved = await discovery.resolve(server)
                                    resolvingID = nil
                                    onSelectDiscovered(server, resolved.host, resolved.port)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: server.target.iconName)
                                        .foregroundStyle(DesignSystem.Colors.primary)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\(server.target.rawValue) • \(server.serviceType) • :\(server.defaultPort)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if resolvingID == server.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .disabled(resolvingID != nil)
                        }
                    }

                    if let error = discovery.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.error)
                    }
                } header: {
                    Text("backup.discovery.local_devices".localized)
                } footer: {
                    Text("backup.discovery.footer".localized)
                }

                if !savedProfiles.isEmpty {
                    Section("backup.discovery.saved_profiles".localized) {
                        ForEach(savedProfiles) { profile in
                            Button {
                                onSelectSavedProfile(profile)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: profile.target.iconName)
                                        .foregroundStyle(Color.secondary)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text("\(profile.target.rawValue) • \(profile.host):\(profile.port)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.down.doc")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("backup.discovery.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.details.close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        discovery.startDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                discovery.startDiscovery()
            }
            .onDisappear {
                discovery.stopDiscovery()
            }
        }
    }
}
