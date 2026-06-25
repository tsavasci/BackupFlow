import XCTest
@testable import BackupFlow

final class BackupFlowTests: XCTestCase {
    func testExecutionOptionsDefaultToMirrorAndNoChecksum() throws {
        let task = BackupTask(sourcePath: "/tmp/source")

        let options = BackupExecutionOptions.forTask(task)

        XCTAssertFalse(options.isDryRun)
        XCTAssertEqual(options.deletionPolicy, .mirror)
        XCTAssertEqual(options.checksumMode, .off)
        XCTAssertFalse(options.requiresWiFi)
        XCTAssertFalse(options.requiresExternalPower)
    }

    func testDryRunOptionsPreserveTaskPolicies() throws {
        let task = BackupTask(
            sourcePath: "/tmp/source",
            deletionPolicy: .appendOnly,
            checksumMode: .verifyUploads,
            requiresExternalPower: true,
            requiresWiFi: true
        )

        let options = BackupExecutionOptions.forTask(task, isDryRun: true)

        XCTAssertTrue(options.isDryRun)
        XCTAssertEqual(options.deletionPolicy, .appendOnly)
        XCTAssertEqual(options.checksumMode, .verifyUploads)
        XCTAssertTrue(options.requiresWiFi)
        XCTAssertTrue(options.requiresExternalPower)
    }

    func testPreviewSummarySnapshotContainsCountsAndPolicy() throws {
        let result = FTPSyncResult(
            newFiles: 2,
            updatedFiles: 1,
            skippedFiles: 3,
            deletedFiles: 4,
            totalBytes: 1024
        )

        let preview = BackupPreviewResult.fromSyncResult(result, deletionPolicy: .mirror)

        XCTAssertEqual(preview.totalChanges, 7)
        XCTAssertTrue(preview.summarySnapshot.contains("new=2"))
        XCTAssertTrue(preview.summarySnapshot.contains("deleted=4"))
        XCTAssertTrue(preview.summarySnapshot.contains("policy=mirror"))
    }
}
