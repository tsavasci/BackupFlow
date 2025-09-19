//
//  ContentView.swift
//  Yedekle2
//
//  Created by Gözde Savaşcı on 13.07.2025.
//

import SwiftUI
import SwiftData
import FilesProvider

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BackupTask.self, BackupHistory.self], inMemory: true)
}

// MARK: - Sample Data for Preview
#if DEBUG
extension ModelContainer {
    @MainActor
    static func createSampleContainer() async -> ModelContainer {
        do {
            let schema = Schema([
                BackupTask.self,
                BackupHistory.self
            ])
            
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Create sample tasks
            let task1 = BackupTask(
                sourcePath: "/Users/username/Documents",
                ftpHost: "ftp.example.com",
                ftpPort: 21,
                ftpUsername: "user1",
                ftpPassword: "password1",
                isAnonymous: false,
                displayName: "Documents",
                isEnabled: true,
                frequency: .daily(time: ScheduleTime(hour: 9, minute: 30))
            )
            
            let task2 = BackupTask(
                sourcePath: "/Users/username/Pictures",
                ftpHost: "backup.server.com",
                ftpPort: 21,
                ftpUsername: "anonymous",
                ftpPassword: "",
                isAnonymous: true,
                displayName: "Pictures",
                isEnabled: true,
                frequency: .weekly(day: 2, time: ScheduleTime(hour: 20, minute: 0))
            )
            
            // Create sample history with proper relationships
            let history1 = BackupHistory(
                status: "completed",
                filesProcessed: 42,
                totalFiles: 42,
                bytesTransferred: 1024 * 1024 * 15, // 15 MB
                totalBytes: 1024 * 1024 * 15, // 15 MB
                duration: 5.2,
                task: task1
            )
            
            let history2 = BackupHistory(
                status: "completed",
                filesProcessed: 125,
                totalFiles: 128,
                bytesTransferred: 1024 * 1024 * 240, // 240 MB
                totalBytes: 1024 * 1024 * 245, // 245 MB
                duration: 23.1,
                task: task2
            )
            
            // Insert sample data on the main actor
            await MainActor.run {
                container.mainContext.insert(task1)
                container.mainContext.insert(task2)
                container.mainContext.insert(history1)
                container.mainContext.insert(history2)
            }
            
            return container
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
}
#endif
