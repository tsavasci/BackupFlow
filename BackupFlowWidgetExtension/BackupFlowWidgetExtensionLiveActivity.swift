import ActivityKit
import SwiftUI
import WidgetKit

struct BackupFlowLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BackupActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(context.state.isCompleted ? .green : .blue)
                    Text(context.attributes.taskName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }

                ProgressView(value: context.state.progress)
                    .tint(context.state.isCompleted ? .green : .blue)

                HStack {
                    Text(context.state.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !context.state.fileName.isEmpty {
                        Text(context.state.fileName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.protocolName, systemImage: "externaldrive.connected.to.line.below")
                        .font(.caption2.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.weight(.bold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: context.state.progress)
                            .tint(.blue)
                        if !context.state.fileName.isEmpty {
                            Text(context.state.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isCompleted ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                    .foregroundStyle(context.state.isCompleted ? .green : .blue)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}
