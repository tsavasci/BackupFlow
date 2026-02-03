import UIKit
import BackgroundTasks
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register BGTask identifiers and handlers
        registerBackgroundTasks()
        // Prepare notifications (categories and permission prompt if needed)
        setupNotifications()
        // Schedule initial background tasks
        BackupScheduler.shared.scheduleAppRefresh()
        BackupScheduler.shared.scheduleProcessingTask()
        return true
    }

    // UIScene support if the app uses scenes
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - BGTask Registration
    private func registerBackgroundTasks() {
        let bundleId = Bundle.main.bundleIdentifier ?? "tamersavasci.BackupFlow"
        let refreshId = bundleId + ".backupTask"
        let processingId = bundleId + ".processing"

        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshId, using: nil) { task in
            // BGAppRefreshTask
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingId, using: nil) { task in
            // BGProcessingTask
            self.handleProcessing(task: task as! BGProcessingTask)
        }
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleNextAfterCompletion(for: task.identifier)

        Task {
            let success = await BackupScheduler.shared.executeBackgroundTask()
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            // If the task expires, mark as not successful
        }
    }

    private func handleProcessing(task: BGProcessingTask) {
        // Ensure processing tasks have required capabilities
        task.expirationHandler = {
            // Handle expiration if needed
        }

        Task {
            let success = await BackupScheduler.shared.executeBackgroundTask()
            task.setTaskCompleted(success: success)
            // Always re-schedule to keep cadence
            BackupScheduler.shared.scheduleProcessingTask()
        }
    }

    private func scheduleNextAfterCompletion(for identifier: String) {
        // Re-schedule on completion to maintain cadence
        if identifier.hasSuffix(".backupTask") {
            BackupScheduler.shared.scheduleAppRefresh()
        } else if identifier.hasSuffix(".processing") {
            BackupScheduler.shared.scheduleProcessingTask()
        }
    }

    // MARK: - Background URLSession bridging
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Bridge completion to WebDAVService so it can call back when finished
        WebDAVService.shared.setBackgroundURLSessionCompletionHandler(completionHandler)
    }

    // MARK: - Notifications setup
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }

        // Register categories used in BackupScheduler
        let startAction = UNNotificationAction(identifier: "START_BACKUP_ACTION", title: "backup.notification.action.start".localized, options: [.foreground])
        let cancelAction = UNNotificationAction(identifier: "CANCEL_BACKUP_ACTION", title: "backup.notification.action.cancel".localized, options: [])
        let category = UNNotificationCategory(identifier: "SCHEDULED_BACKUP", actions: [startAction, cancelAction], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }
}

// Provide String.localized helper if not already available
private extension String {
    var localized: String { NSLocalizedString(self, comment: "") }
}
