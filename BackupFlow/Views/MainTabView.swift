import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // BackupView'ı çağırmadan önce NavigationStack'e bir referans vererek belirsizliği giderin
            NavigationStack {
                BackupView()
            }
            .tabItem {
                Label("Yedekle", systemImage: "externaldrive.fill")
            }
            
            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label("Görevler", systemImage: "checklist")
            }
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Geçmiş", systemImage: "clock.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Ayarlar", systemImage: "gearshape.fill")
            }
            
            NavigationStack {
                AboutView()
            }
            .tabItem {
                Label("Hakkında", systemImage: "info.circle.fill")
            }
        }
        .accentColor(.blue)
    }
}
