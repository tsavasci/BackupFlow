import ActivityKit
import Foundation

@MainActor
final class BackupLiveActivityManager {
    static let shared = BackupLiveActivityManager()

    private var currentActivity: Activity<BackupActivityAttributes>?
    private var lastUpdateAt: Date = .distantPast
    private var lastReportedProgress: Double = -1

    private init() {}

    func start(taskName: String, protocolName: String, statusText: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            await endAllStaleActivities()
            let attributes = BackupActivityAttributes(
                taskName: taskName,
                protocolName: protocolName
            )
            let initialState = BackupActivityAttributes.ContentState(
                progress: 0,
                fileName: "",
                statusText: statusText,
                isCompleted: false
            )
            let content = ActivityContent(state: initialState, staleDate: nil)
            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                lastUpdateAt = Date()
                lastReportedProgress = 0
            } catch {
                debugLog("⚠️ Live Activity start failed: \(error.localizedDescription)")
            }
        }
    }

    func update(progress: Double, fileName: String, statusText: String) {
        guard let activity = currentActivity else { return }
        let clamped = progress.isNaN || progress.isInfinite ? 0.0 : max(0.0, min(1.0, progress))
        let now = Date()
        let delta = abs(clamped - lastReportedProgress)
        guard now.timeIntervalSince(lastUpdateAt) >= 0.5 || delta >= 0.02 else { return }

        lastUpdateAt = now
        lastReportedProgress = clamped

        let state = BackupActivityAttributes.ContentState(
            progress: clamped,
            fileName: fileName,
            statusText: statusText,
            isCompleted: false
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(statusText: String, success: Bool) {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        lastReportedProgress = -1

        let finalState = BackupActivityAttributes.ContentState(
            progress: success ? 1.0 : 0.0,
            fileName: "",
            statusText: statusText,
            isCompleted: true
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(4))
            )
        }
    }

    private func endAllStaleActivities() async {
        for activity in Activity<BackupActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
