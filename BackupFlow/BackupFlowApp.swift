import SwiftUI
import SwiftData
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Arka plan görevlerini kaydet
        BackupScheduler.shared.registerBackgroundTasks()
        
        // Bildirim izinlerini iste
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
                // İzinler alındıktan sonra ilk görevleri planla
                DispatchQueue.main.async {
                    self.scheduleInitialTasks()
                }
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    // Uygulama ilk kez başlatıldığında veya güncellendiğinde ilk yedekleme görevlerini planlar
    private func scheduleInitialTasks() {
        Task {
            // Arka plan görevlerini planla
            BackupScheduler.shared.scheduleAppRefresh()
            BackupScheduler.shared.scheduleBackgroundProcessing()
        }
    }
    
    // Arka plan URL oturumu tamamlandığında
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        BackupScheduler.shared.backgroundCompletionHandler = completionHandler
    }
    
    // Uygulama arka plana geçtiğinde
    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
            // Aktif görevleri kontrol et ve gerekirse yeniden planla
            try? await BackupScheduler.shared.checkAndRescheduleTasks()
        }
    }
    
    // Uygulama ön plana döndüğünde
    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            // Görevleri kontrol et ve güncelle
            try? await BackupScheduler.shared.refreshTaskStatuses()
        }
    }
    
    // Uygulama sonlandırılırken
    func applicationWillTerminate(_ application: UIApplication) {
        Task {
            // Aktif görevleri kaydet
            try? await BackupScheduler.shared.saveActiveTaskStates()
        }
    }
}

@main
struct Yedekle2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BackupTask.self,
            BackupHistory.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        // BackupScheduler'a shared container'ı inject et
        BackupScheduler.sharedModelContainer = sharedModelContainer
        
        // Set default appearance for navigation and tab bars
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Set tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
