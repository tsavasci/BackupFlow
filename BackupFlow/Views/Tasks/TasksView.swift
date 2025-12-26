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
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: BackupView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("tasks.delete_confirmation".localized, isPresented: $showingDeleteAlert) {
                Button("alert.cancel".localized, role: .cancel) {}
                Button("tasks.delete".localized, role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
            } message: {
                Text("tasks.delete_message_full".localized)
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
            "tasks.no_tasks".localized,
            systemImage: "plus.circle",
            description: Text("tasks.create_first_task".localized)
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
    }
    
    private func deleteButton(for task: BackupTask) -> some View {
        Button(role: .destructive) {
            taskToDelete = task
            showingDeleteAlert = true
        } label: {
            Label("tasks.swipe_delete".localized, systemImage: "trash")
        }
    }
    
    // MARK: - Helper Methods
    private func deleteTask(_ task: BackupTask) {
        withAnimation {
            modelContext.delete(task)
        }
    }
}

#Preview {
    NavigationView {
        TasksView()
            .modelContainer(for: [BackupTask.self, BackupHistory.self], inMemory: true)
    }
}
