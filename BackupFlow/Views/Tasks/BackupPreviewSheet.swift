import SwiftUI

struct BackupPreviewSheet: View {
    let taskName: String
    let result: BackupPreviewResult?
    let isLoading: Bool
    let errorMessage: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var formattedBytes: String {
        guard let result else { return "" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: result.totalBytes)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("backup.preview.loading".localized)
                        }
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    } else if let result {
                        LabeledContent("backup.preview.new_files".localized, value: "\(result.newFiles)")
                        LabeledContent("backup.preview.updated_files".localized, value: "\(result.updatedFiles)")
                        LabeledContent("backup.preview.skipped_files".localized, value: "\(result.skippedFiles)")
                        LabeledContent("backup.preview.files_to_delete".localized, value: "\(result.deletedFiles)")
                        LabeledContent("backup.preview.total_size".localized, value: formattedBytes)
                        LabeledContent("backup.deletion_policy".localized, value: result.deletionPolicy.displayName)
                    }
                } header: {
                    Text(taskName)
                }

                if let result, result.deletedFiles > 0 {
                    Section {
                        Text("backup.preview.mirror_delete_warning".localized)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("backup.preview.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("alert.cancel".localized, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("backup.notification.action.start".localized) {
                        onConfirm()
                    }
                    .disabled(isLoading || result == nil)
                }
            }
        }
    }
}
