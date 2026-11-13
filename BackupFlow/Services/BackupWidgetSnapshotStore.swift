import Foundation
import WidgetKit

struct BackupWidgetSnapshot: Codable, Sendable, Equatable {
    var lastBackupDate: Date?
    var lastStatus: String
    var lastTaskName: String?
    var nextRunDate: Date?
    var nextTaskName: String?
    var activeTaskName: String?
    var activeProgress: Double
    var activeFileName: String?
    var updatedAt: Date
    var protocolName: String? = nil
    var statusDisplayText: String? = nil
    var filesSummaryText: String? = nil
    var lastErrorSummary: String? = nil
    var lastSyncLabel: String? = nil
    var nextRunLabel: String? = nil
    var openActionLabel: String? = nil
}

enum BackupWidgetSnapshotStore {
    static let appGroupID = "group.tamersavasci.BackupFlow"
    static let storageKey = "backupflow.widget.snapshot.v1"
    private static let fileName = "widget_snapshot.json"

    private static var sharedFileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func save(_ snapshot: BackupWidgetSnapshot, defaults: UserDefaults? = nil) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        if let defaults {
            defaults.set(data, forKey: storageKey)
        } else if let fileURL = sharedFileURL {
            try? data.write(to: fileURL, options: [.atomic])
        } else {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load(defaults: UserDefaults? = nil) -> BackupWidgetSnapshot? {
        let data: Data?
        if let defaults {
            data = defaults.data(forKey: storageKey)
        } else if let fileURL = sharedFileURL, let fileData = try? Data(contentsOf: fileURL) {
            data = fileData
        } else {
            data = UserDefaults.standard.data(forKey: storageKey)
        }
        guard let data else { return nil }
        return try? JSONDecoder().decode(BackupWidgetSnapshot.self, from: data)
    }

    static func clear(defaults: UserDefaults? = nil) {
        if let defaults {
            defaults.removeObject(forKey: storageKey)
        } else if let fileURL = sharedFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
