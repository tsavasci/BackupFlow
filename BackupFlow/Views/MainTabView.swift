import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // BackupView'ı çağırmadan önce NavigationStack'e bir referans vererek belirsizliği giderin
            NavigationStack {
                BackupView()
            }
            .tabItem {
                Label("nav.backup".localized, systemImage: "externaldrive.fill")
            }
            
            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("nav.tasks".localized, systemImage: "checklist")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("nav.history".localized, systemImage: "clock.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("nav.settings".localized, systemImage: "gearshape.fill")
            }
            
            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("nav.about".localized, systemImage: "info.circle.fill")
            }
        }
        .accentColor(.blue)
    }
}
