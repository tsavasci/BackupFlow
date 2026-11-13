import ActivityKit
import Foundation

nonisolated struct BackupActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var progress: Double
        var fileName: String
        var statusText: String
        var isCompleted: Bool
    }

    var taskName: String
    var protocolName: String
}
