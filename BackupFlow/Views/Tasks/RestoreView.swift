import Observation
import SwiftUI

@Observable
final class Router {
    var showNew = false
    var showSettings = false
}

struct RestoreView: View {
    let tasks: [TaskItem]
    let onSelectTask: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    Text("home.tasks.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                        .listRowBackground(BF.bg)
                        .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(tasks) { task in
                            Button {
                                onSelectTask(task.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.name)
                                        .font(.body.weight(.medium))
                                    HStack(spacing: 6) {
                                        Text(task.proto)
                                            .foregroundStyle(BF.protocolColor(task.proto))
                                        Text(task.host)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(BF.mono)
                                    .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .foregroundStyle(.primary)
                                .contentShape(Rectangle())
                            }
                            .listRowBackground(BF.bg)
                            .listRowSeparatorTint(BF.line)
                        }
                    } header: {
                        Text("restore.select_source_header".localized)
                            .font(BF.monoSmall)
                            .textCase(nil)
                    } footer: {
                        Text("restore.select_source_footer".localized)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(BF.bg)
            .navigationTitle("tab.restore".localized)
        }
        .tint(BF.accent)
        .preferredColorScheme(.dark)
    }
}
