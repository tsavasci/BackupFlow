import FilesProvider
import SwiftUI

struct RemoteFolderPicker: View {
    let target: BackupTarget
    let host: String
    let port: Int
    let username: String?
    let password: String?
    var privateKey: String? = nil
    var passphrase: String? = nil
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentPath = "/"
    @State private var folders: [FileObject] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } else {
                    Section(currentPath) {
                        Button("backup.remote_folder.use_this".localized) {
                            onSelect(currentPath)
                            dismiss()
                        }

                        if currentPath != "/" {
                            Button("backup.remote_folder.parent".localized) {
                                currentPath = parentPath(for: currentPath)
                                load()
                            }
                        }
                    }

                    ForEach(folders, id: \.path) { folder in
                        Button {
                            currentPath = childPath(named: folder.name)
                            load()
                        } label: {
                            Label(folder.name, systemImage: "folder")
                        }
                    }
                }
            }
            .navigationTitle("backup.remote_folder.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("task.details.close".localized) { dismiss() }
                }
            }
            .task {
                await connectAndLoad()
            }
        }
    }

    private func connectAndLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            switch target {
            case .ftp:
                try await FTPService.shared.connect(host: host, port: port, username: username, password: password)
            case .sftp:
                try await SFTPService.shared.connect(
                    host: host,
                    port: port,
                    username: username,
                    password: password,
                    privateKey: privateKey,
                    passphrase: passphrase
                )
            case .webdav:
                try await WebDAVService.shared.connect(host: host, port: port, username: username, password: password)
            }
            try await loadFolders()
        } catch {
            errorMessage = error.localizedDescription
            folders = []
        }
        isLoading = false
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await loadFolders()
            } catch {
                errorMessage = error.localizedDescription
                folders = []
            }
            isLoading = false
        }
    }

    private func loadFolders() async throws {
        let items: [FileObject]
        switch target {
        case .ftp:
            items = try await FTPService.shared.listDirectory(at: currentPath)
        case .sftp:
            items = try await SFTPService.shared.listDirectory(at: currentPath)
        case .webdav:
            items = try await WebDAVService.shared.listDirectory(at: currentPath)
        }
        folders = items.filter(\.isDirectory).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func childPath(named name: String) -> String {
        currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
    }

    private func parentPath(for path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }
}
