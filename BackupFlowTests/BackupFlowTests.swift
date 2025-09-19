import XCTest
@testable import Yedekle2

@MainActor
final class Yedekle2Tests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testBackupTaskCreation() throws {
        let task = BackupTask(
            sourcePath: "/test/path",
            ftpHost: "ftp.example.com",
            ftpPort: 21,
            ftpUsername: "test",
            ftpPassword: "password",
            isAnonymous: false,
            displayName: "Test Backup",
            isEnabled: true,
            frequency: .daily(time: ScheduleTime(hour: 10, minute: 30))
        )
        
        XCTAssertNotNil(task.id)
        XCTAssertEqual(task.sourcePath, "/test/path")
        XCTAssertEqual(task.ftpHost, "ftp.example.com")
        XCTAssertEqual(task.displayName, "Test Backup")
        XCTAssertEqual(task.backupStatus, .idle)
        XCTAssertEqual(task.progress, 0)
    }
    
    func testScheduleTimeValidation() {
        let validTime = ScheduleTime(hour: 23, minute: 59)
        XCTAssertEqual(validTime.hour, 23)
        XCTAssertEqual(validTime.minute, 59)
        
        let overflowTime = ScheduleTime(hour: 24, minute: 60)
        XCTAssertEqual(overflowTime.hour, 23)  // Should be capped at 23
        XCTAssertEqual(overflowTime.minute, 59)  // Should be capped at 59
    }
    
    // MARK: - FTP Service Tests
    
    @MainActor
    func testAnonymousFTPConnection() async throws {
        let service = FTPService.shared
        
        // Test anonymous connection
        do {
            try await service.connect(
                host: "192.168.1.1",
                port: 21,
                username: nil,  // Anonim bağlantı için nil
                password: nil   // Anonim bağlantı için nil
            )
            XCTAssertTrue(true, "Anonim FTP bağlantısı başarılı")
        } catch {
            XCTFail("Anonim FTP bağlantısı başarısız: \(error)")
        }
    }
    
    @MainActor
    func testFileUploadAndSkipping() async throws {
        let service = FTPService.shared
        
        // Test için geçici dizin ve dosya oluştur
        let tempDir = FileManager.default.temporaryDirectory
        let testFolder = tempDir.appendingPathComponent("test_yedekle2_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testFolder, withIntermediateDirectories: true)
        
        // Test dosyaları oluştur
        let testFile1 = testFolder.appendingPathComponent("test1.txt")
        let testFile2 = testFolder.appendingPathComponent("test2.txt")
        let testFile3 = testFolder.appendingPathComponent("test3.txt")
        
        try "Test içerik 1".write(to: testFile1, atomically: true, encoding: .utf8)
        try "Test içerik 2".write(to: testFile2, atomically: true, encoding: .utf8)
        try "Test içerik 3".write(to: testFile3, atomically: true, encoding: .utf8)
        
        do {
            // Anonim FTP'ye bağlan
            try await service.connect(
                host: "192.168.1.1",
                port: 21,
                username: nil,
                password: nil
            )
            
            // İlk yükleme - hiç dosya atlanmamalı
            let remotePath = "test_backup_\(UUID().uuidString)"
            var skippedCount = try await service.uploadDirectory(
                localURL: testFolder,
                remotePath: remotePath
            )
            XCTAssertEqual(skippedCount, 0, "İlk yüklemede atlanan dosya olmamalı")
            
            // İkinci yükleme - tüm dosyalar atlanmalı
            skippedCount = try await service.uploadDirectory(
                localURL: testFolder,
                remotePath: remotePath
            )
            XCTAssertEqual(skippedCount, 3, "İkinci yüklemede tüm dosyalar atlanmalı")
            
            // Bir dosyayı değiştir
            try "Değiştirilmiş içerik".write(to: testFile2, atomically: true, encoding: .utf8)
            
            // Üçüncü yükleme - sadece değişen dosya yüklenmeli
            skippedCount = try await service.uploadDirectory(
                localURL: testFolder,
                remotePath: remotePath
            )
            XCTAssertEqual(skippedCount, 2, "Üçüncü yüklemede değişmeyen dosyalar atlanmalı")
            
        } catch {
            XCTFail("Dosya yükleme testi başarısız: \(error)")
        }
        
        // Temizlik
        try? FileManager.default.removeItem(at: testFolder)
    }
    
    // MARK: - Backup Scheduler Tests
    
    @MainActor
    func testNextRunTimeCalculation() async throws {
        let task = BackupTask(
            sourcePath: "/test/path",
            ftpHost: "ftp.example.com",
            ftpPort: 21,
            ftpUsername: "test",
            ftpPassword: "password",
            isAnonymous: false,
            displayName: "Test Backup",
            isEnabled: true,
            frequency: .daily(time: ScheduleTime(hour: 10, minute: 30))
        )
        
        try await BackupScheduler.shared.scheduleBackup(task: task)
        
        XCTAssertNotNil(task.nextRunTime)
        if let nextRun = task.nextRunTime {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: nextRun)
            XCTAssertEqual(components.hour, 10)
            XCTAssertEqual(components.minute, 30)
        }
    }
    
    // MARK: - Backup History Tests
    
    func testBackupHistoryCreation() {
        let history = BackupHistory(
            timestamp: Date(),
            status: "Completed",
            sourcePath: "/test/path",
            destinationPath: "backup/test",
            fileCount: 10,
            totalSize: 1024 * 1024, // 1MB
            duration: 5.0,
            skippedCount: 3
        )
        
        XCTAssertNotNil(history.id)
        XCTAssertEqual(history.status, "Completed")
        XCTAssertEqual(history.fileCount, 10)
        XCTAssertEqual(history.skippedCount, 3)
        XCTAssertEqual(history.duration, 5.0)
    }
}
