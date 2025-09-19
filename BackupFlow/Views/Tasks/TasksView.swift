import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BackupTask.createdAt, order: .reverse) private var tasks: [BackupTask]
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: BackupTask?
    
    // MARK: - Main View
    var body: some View {
        contentView
            .navigationTitle("nav.tasks".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Debug") {
                        testTimer()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: BackupView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Görevi Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
            } message: {
                Text("Bu görevi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
            }
    }
    
    // MARK: - Subviews
    private var contentView: some View {
        Group {
            if tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "Görev Yok",
            systemImage: "plus.circle",
            description: Text("Başlamak için ilk yedekleme görevinizi oluşturun.")
        )
    }
    
    private var taskListView: some View {
        List {
            Section {
                DashboardWidget()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            Section("tasks.your_tasks".localized) {
                ForEach(tasks) { task in
                    TaskRow(task: task, onDelete: { self.taskToDelete = $0 })
                        .swipeActions(edge: .trailing) { deleteButton(for: task) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear {
            // Debug: Mevcut görevleri logla
            print("📋 TasksView: Toplam görev sayısı: \(tasks.count)")
            for task in tasks {
                let nextRunStr = task.nextRunTime?.formatted() ?? "nil"
                print("  - \(task.displayName) (ID: \(task.id.uuidString.prefix(8))): enabled=\(task.isEnabled), nextRun=\(nextRunStr)")
            }
            
            // Debug: Active timer'ları kontrol et
            BackupScheduler.shared.debugActiveTimers()
        }
    }
    
    private func deleteButton(for task: BackupTask) -> some View {
        Button(role: .destructive) {
            taskToDelete = task
            showingDeleteAlert = true
        } label: {
            Label("Sil", systemImage: "trash")
        }
    }
    
    // MARK: - Helper Methods
    private func deleteTask(_ task: BackupTask) {
        withAnimation {
            modelContext.delete(task)
        }
    }
    
    // Test timer function
    private func testTimer() {
        print("🧪 BackupFlow: Test timer başlatılıyor - 10 saniye sonra tetiklenecek")
        
        let fireDate = Date().addingTimeInterval(10) // 10 saniye sonra
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { _ in
            print("🎉 BackupFlow: TEST TIMER TETRİKLENDİ! - \(Date())")
            
            // Bildirim gönder
            let content = UNMutableNotificationContent()
            content.title = "Timer Test"
            content.body = "10 saniyelik test timer başarıyla tetiklendi!"
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "test-timer", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
        
        RunLoop.main.add(timer, forMode: .common)
        print("✅ BackupFlow: Test timer kuruldu - Fire date: \(fireDate)")
    }
}

#Preview {
    NavigationView {
        TasksView()
            .modelContainer(for: [BackupTask.self, BackupHistory.self], inMemory: true)
    }
}
