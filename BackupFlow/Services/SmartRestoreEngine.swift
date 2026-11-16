import Foundation
import Observation
@preconcurrency import Photos
import SwiftData
import UIKit

enum SmartRestoreError: LocalizedError, Equatable {
    case taskBusyWithBackup
    case photoSmartRestoreDisabled
    case photoAccessLimited
    case photoAccessDenied
    case folderAccessUnavailable(path: String)
    case folderWriteProbeFailed(path: String)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .taskBusyWithBackup:
            return "smart_restore.error.task_busy".localized
        case .photoSmartRestoreDisabled:
            return "smart_restore.error.photo_disabled".localized
        case .photoAccessLimited:
            return "smart_restore.error.photo_limited".localized
        case .photoAccessDenied:
            return "error.photo_library.no_access".localized
        case .folderAccessUnavailable:
            return "smart_restore.error.folder_access".localized
        case .folderWriteProbeFailed:
            return "smart_restore.error.folder_readonly".localized
        case .insufficientDiskSpace(let required, let available):
            let reqStr = ByteCountFormatter.string(fromByteCount: required, countStyle: .file)
            let availStr = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "smart_restore.error.disk_space".localized(with: reqStr, availStr)
        }
    }
}

nonisolated struct SmartRestoreExecutionResult: Sendable {
    let restoredCount: Int
    let skippedCount: Int
    let failedFiles: [String]
    let bytesRestored: Int64
}

nonisolated struct LocalFolderFileSnapshot: Sendable, Hashable {
    let relativePath: String
    let normalizedKey: NormalizedPathKey
    let size: Int64
    let modifiedDate: Date?
    let isCloudEvicted: Bool

    init(
        relativePath: String,
        size: Int64,
        modifiedDate: Date? = nil,
        isCloudEvicted: Bool = false
    ) {
        let clean = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        self.relativePath = clean
        self.normalizedKey = NormalizedPathKey(clean)
        self.size = size
        self.modifiedDate = modifiedDate
        self.isCloudEvicted = isCloudEvicted
    }
}

// MARK: - Background Diff & Execution Engine (Non-MainActor)

nonisolated enum SmartRestoreEngine {

    // MARK:Staging Directory

    static func stagingDirectory(for taskID: UUID) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let staging = appSupport
            .appendingPathComponent("RestoreStaging", isDirectory: true)
            .appendingPathComponent(taskID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: staging.path
        )
        return staging
    }

    static func cleanupStagingDirectory(for taskID: UUID) {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let staging = appSupport
            .appendingPathComponent("RestoreStaging", isDirectory: true)
            .appendingPathComponent(taskID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: staging)
    }

    // MARK: Disk Space & Folder Probe

    static func availableDiskBytes() -> Int64? {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let capacity = values.volumeAvailableCapacityForImportantUsage,
           capacity > 0 {
            return capacity
        }
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let capacity = values.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    static func validateDiskSpace(forDownloadBytes downloadBytes: Int64) throws {
        guard downloadBytes > 0, let available = availableDiskBytes() else { return }
        let requiredWithMargin = downloadBytes + SmartRestoreConfiguration.minimumFreeDiskSafetyMarginBytes
        if available < requiredWithMargin {
            throw SmartRestoreError.insufficientDiskSpace(
                requiredBytes: requiredWithMargin,
                availableBytes: available
            )
        }
    }

    /// Resolves the security-scoped folder URL and performs a real write probe to catch read-only File Providers early.
    static func resolveAndProbeWritableFolder(sourcePath: String) throws -> URL {
        let trimmed = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "PHOTOS_LIBRARY" else {
            throw SmartRestoreError.folderAccessUnavailable(path: sourcePath)
        }

        let resolvedURL: URL = {
            if let bookmarked = FileAccessManager.shared.loadBookmark(for: trimmed) {
                return bookmarked
            }
            return URL(fileURLWithPath: trimmed)
        }()

        let scoped = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw SmartRestoreError.folderAccessUnavailable(path: trimmed)
        }

        let probeName = ".backupflow_write_probe_\(UUID().uuidString.prefix(8))"
        let probeURL = resolvedURL.appendingPathComponent(probeName)
        do {
            try Data("ok".utf8).write(to: probeURL, options: .atomic)
            try? FileManager.default.removeItem(at: probeURL)
        } catch {
            try? FileManager.default.removeItem(at: probeURL)
            throw SmartRestoreError.folderWriteProbeFailed(path: trimmed)
        }

        return resolvedURL
    }

    // MARK: Remote Recursive BFS Inventory

    static func scanRemoteInventory(
        client: any RemoteStorageClient,
        rootPath: String,
        includeArchive: Bool = false,
        onProgress: (@Sendable (Int, String) -> Void)? = nil
    ) async throws -> [RemoteRestoreItem] {
        let normalizedRoot: String = {
            let trimmed = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "/" }
            return trimmed
        }()

        var queue: [(remotePath: String, relativePrefix: String)] = [(normalizedRoot, "")]
        var visitedDirs = Set<String>()
        var rawItems: [RemoteRestoreItem] = []

        while !queue.isEmpty {
            try Task.checkCancellation()
            let current = queue.removeFirst()
            guard visitedDirs.insert(current.remotePath).inserted else { continue }

            onProgress?(rawItems.count, current.relativePrefix.isEmpty ? normalizedRoot : current.relativePrefix)
            let entries = try await client.listDirectory(at: current.remotePath)

            for entry in entries {
                try Task.checkCancellation()
                if entry.name.hasPrefix(".backupflow_write_probe_") || entry.name == ".DS_Store" {
                    continue
                }
                let relativePath = current.relativePrefix.isEmpty
                    ? entry.name
                    : "\(current.relativePrefix)/\(entry.name)"
                let cleanRelative = BackupArchive.sanitize(relativePath: relativePath)
                guard !cleanRelative.isEmpty else { continue }

                if !includeArchive && BackupArchive.isReserved(relativePath: cleanRelative) {
                    continue
                }
                if cleanRelative == BackupArchive.manifestName {
                    continue
                }

                if entry.isDirectory {
                    queue.append((entry.fullPath, cleanRelative))
                } else {
                    rawItems.append(
                        RemoteRestoreItem(
                            relativePath: cleanRelative,
                            fullRemotePath: entry.fullPath,
                            name: entry.name,
                            size: entry.size,
                            modifiedDate: entry.modifiedDate
                        )
                    )
                }
            }
        }

        return markCaseCollisions(in: rawItems)
    }

    /// Detects files on a case-sensitive remote server that collide under `NormalizedPathKey`
    /// (e.g. `Report.pdf` and `report.pdf`) so neither file is silently dropped.
    static func markCaseCollisions(in items: [RemoteRestoreItem]) -> [RemoteRestoreItem] {
        var counts: [NormalizedPathKey: Int] = [:]
        for item in items {
            counts[item.normalizedKey, default: 0] += 1
        }
        return items.map { item in
            var copy = item
            copy.hasCaseCollisionOnServer = (counts[item.normalizedKey] ?? 0) > 1
            return copy
        }
    }

    // MARK: Local Folder Inventory (With iCloud Evicted File Protection)

    static func scanLocalFolderInventory(rootURL: URL) throws -> [NormalizedPathKey: LocalFolderFileSnapshot] {
        let scoped = rootURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .isHiddenKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            throw SmartRestoreError.folderAccessUnavailable(path: rootURL.path)
        }

        let rootStandardPath = rootURL.standardizedFileURL.path
        let prefixCount = rootStandardPath == "/" ? 1 : rootStandardPath.count + 1
        var inventory: [NormalizedPathKey: LocalFolderFileSnapshot] = [:]

        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let fileName = fileURL.lastPathComponent

            if fileName == ".DS_Store" || fileName.hasPrefix(".backupflow_") {
                if values?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let isICloudPlaceholder = fileName.hasPrefix(".") && fileName.lowercased().hasSuffix(".icloud")
            if values?.isHidden == true && !isICloudPlaceholder {
                if values?.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            if values?.isDirectory == true {
                continue
            }

            let fullStandardPath = fileURL.standardizedFileURL.path
            guard fullStandardPath.count > prefixCount else { continue }
            var relativePath = String(fullStandardPath.dropFirst(prefixCount)).precomposedStringWithCanonicalMapping

            if isICloudPlaceholder {
                relativePath = unwrapICloudPlaceholderRelativePath(relativePath)
            }

            let isUbiquitous = values?.isUbiquitousItem == true
            let downloadStatus = values?.ubiquitousItemDownloadingStatus
            let isEvicted = isICloudPlaceholder || (isUbiquitous && downloadStatus == .notDownloaded)
            let size = Int64(values?.fileSize ?? 0)
            let modified = values?.contentModificationDate

            let snapshot = LocalFolderFileSnapshot(
                relativePath: relativePath,
                size: size,
                modifiedDate: modified,
                isCloudEvicted: isEvicted
            )
            // Prefer non-placeholder metadata if both placeholder and materialized entry appear
            if let existing = inventory[snapshot.normalizedKey], !existing.isCloudEvicted {
                continue
            }
            inventory[snapshot.normalizedKey] = snapshot
        }

        return inventory
    }

    /// Fallback helper that converts `sub/.report.pdf.icloud` -> `sub/report.pdf`.
    static func unwrapICloudPlaceholderRelativePath(_ relativePath: String) -> String {
        let nsPath = relativePath as NSString
        let parent = nsPath.deletingLastPathComponent
        var name = nsPath.lastPathComponent
        if name.hasPrefix(".") {
            name.removeFirst()
        }
        if name.lowercased().hasSuffix(".icloud") {
            name = String(name.dropLast(".icloud".count))
        }
        return parent.isEmpty ? name : "\(parent)/\(name)"
    }

    // MARK: Folder Diff Calculation

    static func computeFolderDiff(
        taskID: UUID,
        remoteRootPath: String,
        remoteItems: [RemoteRestoreItem],
        localItems: [NormalizedPathKey: LocalFolderFileSnapshot],
        ignoredKeys: Set<NormalizedPathKey>,
        autoSelectThreshold: Int = SmartRestoreConfiguration.autoSelectMissingThreshold
    ) -> SmartRestorePlan {
        let markedRemotes = markCaseCollisions(in: remoteItems)
        var unchangedCount = 0
        var caseCollisionCount = 0
        var missingCandidates: [SmartRestoreCandidate] = []
        var conflictCandidates: [SmartRestoreCandidate] = []
        var ignoredCandidates: [SmartRestoreCandidate] = []

        for remote in markedRemotes {
            if remote.hasCaseCollisionOnServer {
                caseCollisionCount += 1
            }

            if ignoredKeys.contains(remote.normalizedKey) {
                ignoredCandidates.append(
                    SmartRestoreCandidate(
                        remoteItem: remote,
                        state: .ignored,
                        isSelected: false
                    )
                )
                continue
            }

            if let local = localItems[remote.normalizedKey] {
                if remote.hasCaseCollisionOnServer {
                    conflictCandidates.append(
                        SmartRestoreCandidate(
                            remoteItem: remote,
                            state: .conflict(localSize: local.size, localModifiedDate: local.modifiedDate),
                            isSelected: false,
                            conflictResolution: .skip
                        )
                    )
                } else if local.isCloudEvicted && local.size == 0 {
                    // Evicted iCloud Drive item without local size: treat as present locally (unchanged)
                    unchangedCount += 1
                } else if local.size == remote.size {
                    unchangedCount += 1
                } else {
                    conflictCandidates.append(
                        SmartRestoreCandidate(
                            remoteItem: remote,
                            state: .conflict(localSize: local.size, localModifiedDate: local.modifiedDate),
                            isSelected: false,
                            conflictResolution: .skip
                        )
                    )
                }
            } else {
                missingCandidates.append(
                    SmartRestoreCandidate(
                        remoteItem: remote,
                        state: .missingLocally,
                        isSelected: true
                    )
                )
            }
        }

        let exceedsThreshold = missingCandidates.count > autoSelectThreshold
        if exceedsThreshold {
            for idx in missingCandidates.indices {
                missingCandidates[idx].isSelected = false
            }
        }

        return SmartRestorePlan(
            taskID: taskID,
            isPhotoLibrarySource: false,
            remoteRootPath: remoteRootPath,
            totalRemoteFiles: markedRemotes.count,
            unchangedCount: unchangedCount,
            alreadyRestoredCount: 0,
            caseCollisionCount: caseCollisionCount,
            autoSelectionDisabledByThreshold: exceedsThreshold,
            missingItems: missingCandidates,
            ambiguousItems: [],
            conflictItems: conflictCandidates,
            ignoredItems: ignoredCandidates
        )
    }

    // MARK: Two-Pass Photo Library Diff Calculation

    static func computePhotoDiff(
        taskID: UUID,
        remoteRootPath: String,
        remoteItems: [RemoteRestoreItem],
        localAssets: [LocalPhotoAssetSnapshot],
        authorizationStatus: PHAuthorizationStatus,
        ledgerStore: RestoredPhotoLedgerStore = .shared,
        timeZone: TimeZone = .current,
        autoSelectThreshold: Int = SmartRestoreConfiguration.autoSelectMissingThreshold
    ) throws -> SmartRestorePlan {
        guard SmartRestoreConfiguration.isPhotoSmartRestoreEnabled else {
            throw SmartRestoreError.photoSmartRestoreDisabled
        }
        switch authorizationStatus {
        case .authorized:
            break
        case .limited:
            throw SmartRestoreError.photoAccessLimited
        default:
            throw SmartRestoreError.photoAccessDenied
        }

        let markedRemotes = markCaseCollisions(in: remoteItems)
        let ignoredKeys = Set(ledgerStore.ignoredPaths(for: taskID).keys)

        // Index local assets by full localIdentifier and by 12-char idFragment
        var assetsByFullID: [String: LocalPhotoAssetSnapshot] = [:]
        var assetsByFragment: [String: [LocalPhotoAssetSnapshot]] = [:]
        for asset in localAssets {
            assetsByFullID[asset.localIdentifier] = asset
            let fragmentKey = asset.idFragment.lowercased()
            assetsByFragment[fragmentKey, default: []].append(asset)
        }

        var consumedAssetIDs = Set<String>()
        var unchangedCount = 0
        var alreadyRestoredCount = 0
        var ignoredCandidates: [SmartRestoreCandidate] = []
        var missingCandidates: [SmartRestoreCandidate] = []
        var ambiguousCandidates: [SmartRestoreCandidate] = []

        struct UnmatchedRemotePhoto {
            let item: RemoteRestoreItem
            let descriptor: SmartRestorePhotoDescriptor?
        }

        var pass2Queue: [UnmatchedRemotePhoto] = []

        // PASS 1: Exact Identity Match (RestoredPhotoLedger + 12-char idFragment) across ALL remote files first.
        // Ensures Pass 2 date/size matching never steals an asset belonging to another file's exact ID.
        for remote in markedRemotes {
            if ignoredKeys.contains(remote.normalizedKey) {
                ignoredCandidates.append(
                    SmartRestoreCandidate(
                        remoteItem: remote,
                        state: .ignored,
                        isSelected: false
                    )
                )
                continue
            }

            if let ledgerEntry = ledgerStore.entry(forTaskID: taskID, relativePath: remote.relativePath),
               let matchedAsset = assetsByFullID[ledgerEntry.newLocalIdentifier],
               !consumedAssetIDs.contains(matchedAsset.localIdentifier) {
                consumedAssetIDs.insert(matchedAsset.localIdentifier)
                alreadyRestoredCount += 1
                continue
            }

            let descriptor = SmartRestorePhotoDescriptor.parse(
                fileNameOrRelativePath: remote.relativePath,
                timeZone: timeZone
            )

            if let descriptor {
                let fragmentKey = descriptor.idFragment.lowercased()
                if let fragmentCandidates = assetsByFragment[fragmentKey],
                   let exactAsset = fragmentCandidates.first(where: { !consumedAssetIDs.contains($0.localIdentifier) }) {
                    consumedAssetIDs.insert(exactAsset.localIdentifier)
                    unchangedCount += 1
                    continue
                }
            }

            pass2Queue.append(UnmatchedRemotePhoto(item: remote, descriptor: descriptor))
        }

        // PASS 2: Date (±2s) + MediaType + Size Disambiguation on remaining unmatched remote files.
        // Group parseable items by their timestamp string (`yyyyMMdd_HHmmss` + mediaType) to handle bursts safely.
        var burstGroups: [String: [UnmatchedRemotePhoto]] = [:]
        var unparseableRemotes: [UnmatchedRemotePhoto] = []

        for entry in pass2Queue {
            if let desc = entry.descriptor {
                let groupKey = "\(desc.dateString)|\(desc.isVideo ? "V" : "I")"
                burstGroups[groupKey, default: []].append(entry)
            } else {
                unparseableRemotes.append(entry)
            }
        }

        let sortedGroupKeys = burstGroups.keys.sorted()
        let dateTolerance: TimeInterval = 2.0

        for groupKey in sortedGroupKeys {
            guard let group = burstGroups[groupKey], let sampleDesc = group.first?.descriptor else { continue }

            // Try local TimeZone candidates first; only fall back to UTC if local TimeZone yields 0 unconsumed assets.
            let localTZCandidates = localAssets.filter { asset in
                guard !consumedAssetIDs.contains(asset.localIdentifier),
                      asset.isVideo == sampleDesc.isVideo,
                      let assetDate = asset.creationDate else { return false }
                return abs(assetDate.timeIntervalSince(sampleDesc.localTimeZoneDate)) <= dateTolerance
            }

            let candidatePool: [LocalPhotoAssetSnapshot]
            if !localTZCandidates.isEmpty {
                candidatePool = localTZCandidates
            } else {
                candidatePool = localAssets.filter { asset in
                    guard !consumedAssetIDs.contains(asset.localIdentifier),
                          asset.isVideo == sampleDesc.isVideo,
                          let assetDate = asset.creationDate else { return false }
                    return abs(assetDate.timeIntervalSince(sampleDesc.utcDate)) <= dateTolerance
                }
            }

            // If no local asset exists in this timestamp window at all, every remote file in the group is missing locally.
            if candidatePool.isEmpty {
                for remoteEntry in group {
                    missingCandidates.append(
                        SmartRestoreCandidate(
                            remoteItem: remoteEntry.item,
                            state: .missingLocally,
                            isSelected: true,
                            parsedPhotoDate: remoteEntry.descriptor?.localTimeZoneDate
                        )
                    )
                }
                continue
            }

            // Step 2a: Match by exact size first within the burst group.
            // To avoid random pairing when two burst photos share the exact same byte size,
            // only pair when sizes match.
            var remainingGroupRemotes: [UnmatchedRemotePhoto] = []
            var availableGroupAssets = candidatePool

            for remoteEntry in group {
                let targetSize = remoteEntry.item.size
                if targetSize > 0,
                   let matchIndex = availableGroupAssets.firstIndex(where: { $0.resourceSize == targetSize }) {
                    let matchedAsset = availableGroupAssets.remove(at: matchIndex)
                    consumedAssetIDs.insert(matchedAsset.localIdentifier)
                    unchangedCount += 1
                    ledgerStore.recordRestoredPhoto(
                        taskID: taskID,
                        relativePath: remoteEntry.item.relativePath,
                        originalFileName: remoteEntry.item.name,
                        newLocalIdentifier: matchedAsset.localIdentifier,
                        remoteSize: remoteEntry.item.size
                    )
                } else {
                    remainingGroupRemotes.append(remoteEntry)
                }
            }

            guard !remainingGroupRemotes.isEmpty else { continue }

            // Step 2b: Handle remaining unmatched remotes in this timestamp group.
            if availableGroupAssets.isEmpty {
                // Every local asset in this second was already 1-1 paired by exact byte size!
                // Therefore the remaining remote files in this burst are genuinely missing locally.
                for remoteEntry in remainingGroupRemotes {
                    missingCandidates.append(
                        SmartRestoreCandidate(
                            remoteItem: remoteEntry.item,
                            state: .missingLocally,
                            isSelected: true,
                            parsedPhotoDate: remoteEntry.descriptor?.localTimeZoneDate
                        )
                    )
                }
            } else {
                // Local assets exist at the same second, but byte sizes differ or are nil (e.g. iCloud optimized,
                // edited photo, HEIC<->JPEG, or indistinguishable burst). Mark as `.ambiguous` instead of guessing!
                for a in availableGroupAssets {
                    consumedAssetIDs.insert(a.localIdentifier)
                }
                for remoteEntry in remainingGroupRemotes {
                    ambiguousCandidates.append(
                        SmartRestoreCandidate(
                            remoteItem: remoteEntry.item,
                            state: .ambiguous(reason: "smart_restore.ambiguous.reason".localized),
                            isSelected: false,
                            parsedPhotoDate: remoteEntry.descriptor?.localTimeZoneDate
                        )
                    )
                }
            }
        }

        for remoteEntry in unparseableRemotes {
            missingCandidates.append(
                SmartRestoreCandidate(
                    remoteItem: remoteEntry.item,
                    state: .missingLocally,
                    isSelected: true,
                    parsedPhotoDate: remoteEntry.item.modifiedDate
                )
            )
        }

        let exceedsThreshold = missingCandidates.count > autoSelectThreshold
        if exceedsThreshold {
            for idx in missingCandidates.indices {
                missingCandidates[idx].isSelected = false
            }
        }

        return SmartRestorePlan(
            taskID: taskID,
            isPhotoLibrarySource: true,
            remoteRootPath: remoteRootPath,
            totalRemoteFiles: markedRemotes.count,
            unchangedCount: unchangedCount,
            alreadyRestoredCount: alreadyRestoredCount,
            caseCollisionCount: markedRemotes.filter(\.hasCaseCollisionOnServer).count,
            autoSelectionDisabledByThreshold: exceedsThreshold,
            missingItems: missingCandidates,
            ambiguousItems: ambiguousCandidates,
            conflictItems: [],
            ignoredItems: ignoredCandidates
        )
    }

    // MARK: Atomic Execution (Folder & Photo Library)

    static func executeRestorePlan(
        snapshot: SmartRestoreTaskSnapshot,
        plan: SmartRestorePlan,
        client: any RemoteStorageClient,
        photoProvider: (any PhotoLibraryInventoryProviding)? = nil,
        ledgerStore: RestoredPhotoLedgerStore = .shared,
        onProgress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async throws -> SmartRestoreExecutionResult {
        let selected = plan.selectedItemsToRestore
        guard !selected.isEmpty else {
            return SmartRestoreExecutionResult(restoredCount: 0, skippedCount: 0, failedFiles: [], bytesRestored: 0)
        }

        try validateDiskSpace(forDownloadBytes: plan.totalBytesToDownload)
        let stagingDir = try stagingDirectory(for: snapshot.id)

        try await client.connect()
        do {
            let result: SmartRestoreExecutionResult
            if snapshot.isPhotoLibrarySource {
                let resolvedPhotoProvider: any PhotoLibraryInventoryProviding
                if let photoProvider {
                    resolvedPhotoProvider = photoProvider
                } else {
                    resolvedPhotoProvider = await MainActor.run { PhotoLibraryManager.shared }
                }
                result = try await executePhotoRestore(
                    snapshot: snapshot,
                    candidates: selected,
                    stagingDir: stagingDir,
                    client: client,
                    photoProvider: resolvedPhotoProvider,
                    ledgerStore: ledgerStore,
                    onProgress: onProgress
                )
            } else {
                result = try await executeFolderRestore(
                    snapshot: snapshot,
                    candidates: selected,
                    stagingDir: stagingDir,
                    client: client,
                    onProgress: onProgress
                )
            }
            await client.disconnect()
            return result
        } catch {
            await client.disconnect()
            throw error
        }
    }

    private static func executeFolderRestore(
        snapshot: SmartRestoreTaskSnapshot,
        candidates: [SmartRestoreCandidate],
        stagingDir: URL,
        client: any RemoteStorageClient,
        onProgress: (@Sendable (Int, Int, String) -> Void)?
    ) async throws -> SmartRestoreExecutionResult {
        let rootURL = try resolveAndProbeWritableFolder(sourcePath: snapshot.sourcePath)
        let scoped = rootURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                rootURL.stopAccessingSecurityScopedResource()
            }
        }

        var localInventory = (try? scanLocalFolderInventory(rootURL: rootURL)) ?? [:]
        var existingKeys = Set(localInventory.keys)

        var restoredCount = 0
        var skippedCount = 0
        var failedFiles: [String] = []
        var bytesRestored: Int64 = 0
        let total = candidates.count

        for (index, candidate) in candidates.enumerated() {
            try Task.checkCancellation()
            let remote = candidate.remoteItem
            onProgress?(index, total, remote.name)

            // Crash/Resume fingerprint check: if already materialized on disk with matching size, skip download
            if case .missingLocally = candidate.state,
               let existingLocal = localInventory[remote.normalizedKey],
               existingLocal.size == remote.size,
               remote.size > 0 {
                skippedCount += 1
                continue
            }

            let targetRelativePath: String
            switch candidate.state {
            case .conflict:
                switch candidate.conflictResolution {
                case .skip:
                    skippedCount += 1
                    continue
                case .keepBoth:
                    targetRelativePath = NormalizedPathKey.makeKeepBothRelativePath(
                        for: remote.relativePath,
                        existingKeys: existingKeys
                    )
                case .overwrite:
                    targetRelativePath = remote.relativePath
                }
            default:
                if remote.hasCaseCollisionOnServer && existingKeys.contains(remote.normalizedKey) {
                    targetRelativePath = NormalizedPathKey.makeKeepBothRelativePath(
                        for: remote.relativePath,
                        existingKeys: existingKeys
                    )
                } else {
                    targetRelativePath = remote.relativePath
                }
            }

            let partURL = stagingDir.appendingPathComponent("\(UUID().uuidString).part")
            defer { try? FileManager.default.removeItem(at: partURL) }

            do {
                try await client.downloadFile(remotePath: remote.fullRemotePath, to: partURL, resumeOffset: 0)
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: partURL.path
                )

                try commitStagedFileToFolder(
                    stagedFileURL: partURL,
                    rootFolderURL: rootURL,
                    targetRelativePath: targetRelativePath,
                    remoteModifiedDate: remote.modifiedDate
                )

                existingKeys.insert(NormalizedPathKey(targetRelativePath))
                localInventory[NormalizedPathKey(targetRelativePath)] = LocalFolderFileSnapshot(
                    relativePath: targetRelativePath,
                    size: remote.size,
                    modifiedDate: remote.modifiedDate
                )
                restoredCount += 1
                bytesRestored += max(remote.size, 0)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedFiles.append(remote.relativePath)
                debugLog("❌ SmartRestore folder write failed for \(remote.relativePath): \(error.localizedDescription)")
            }

            onProgress?(index + 1, total, remote.name)
        }

        cleanupStagingDirectory(for: snapshot.id)
        return SmartRestoreExecutionResult(
            restoredCount: restoredCount,
            skippedCount: skippedCount,
            failedFiles: failedFiles,
            bytesRestored: bytesRestored
        )
    }

    /// Used by both production folder restore and crash-recovery unit tests.
    static func commitStagedFileToFolder(
        stagedFileURL: URL,
        rootFolderURL: URL,
        targetRelativePath: String,
        remoteModifiedDate: Date?
    ) throws {
        let cleanRelative = BackupArchive.sanitize(relativePath: targetRelativePath).precomposedStringWithCanonicalMapping
        let destinationURL = rootFolderURL.appendingPathComponent(cleanRelative)
        let parentURL = destinationURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)

        var coordinatorError: NSError?
        var moveError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(writingItemAt: destinationURL, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    _ = try FileManager.default.replaceItemAt(coordinatedURL, withItemAt: stagedFileURL)
                } else {
                    try FileManager.default.moveItem(at: stagedFileURL, to: coordinatedURL)
                }
                if let remoteModifiedDate {
                    try? FileManager.default.setAttributes(
                        [.modificationDate: remoteModifiedDate],
                        ofItemAtPath: coordinatedURL.path
                    )
                }
            } catch {
                moveError = error
            }
        }

        if let moveError { throw moveError }
        if let coordinatorError { throw coordinatorError }
    }

    private static func executePhotoRestore(
        snapshot: SmartRestoreTaskSnapshot,
        candidates: [SmartRestoreCandidate],
        stagingDir: URL,
        client: any RemoteStorageClient,
        photoProvider: any PhotoLibraryInventoryProviding,
        ledgerStore: RestoredPhotoLedgerStore,
        onProgress: (@Sendable (Int, Int, String) -> Void)?
    ) async throws -> SmartRestoreExecutionResult {
        let existingSnapshots = (try? await photoProvider.fetchAssetSnapshots(mediaType: snapshot.mediaType)) ?? []
        var knownAssetIDs = Set(existingSnapshots.map(\.localIdentifier))

        var restoredCount = 0
        var skippedCount = 0
        var failedFiles: [String] = []
        var bytesRestored: Int64 = 0
        let total = candidates.count

        for (index, candidate) in candidates.enumerated() {
            try Task.checkCancellation()
            let remote = candidate.remoteItem
            onProgress?(index, total, remote.name)

            // Crash/Resume guard: check if already recorded in ledger or materialized in library
            if let existingEntry = ledgerStore.entry(forTaskID: snapshot.id, relativePath: remote.relativePath),
               knownAssetIDs.contains(existingEntry.newLocalIdentifier) {
                skippedCount += 1
                continue
            }

            let descriptor = SmartRestorePhotoDescriptor.parse(fileNameOrRelativePath: remote.relativePath)
            if let descriptor,
               existingSnapshots.contains(where: {
                   $0.idFragment.caseInsensitiveCompare(descriptor.idFragment) == .orderedSame
               }) {
                skippedCount += 1
                continue
            }

            let ext = (remote.name as NSString).pathExtension
            let stagedURL = stagingDir.appendingPathComponent("\(UUID().uuidString).\(ext.isEmpty ? "dat" : ext)")
            defer { try? FileManager.default.removeItem(at: stagedURL) }

            do {
                try await client.downloadFile(remotePath: remote.fullRemotePath, to: stagedURL, resumeOffset: 0)
                try? FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: stagedURL.path
                )

                let creationDate = descriptor?.localTimeZoneDate ?? remote.modifiedDate
                let isVideo = RestoreService.isVideoExtension(ext)
                let newAssetID = try await insertAssetIntoPhotoLibrary(
                    stagedFileURL: stagedURL,
                    originalFilename: remote.name,
                    creationDate: creationDate,
                    isVideo: isVideo
                )

                if let newAssetID, !newAssetID.isEmpty {
                    knownAssetIDs.insert(newAssetID)
                    ledgerStore.recordRestoredPhoto(
                        taskID: snapshot.id,
                        relativePath: remote.relativePath,
                        originalFileName: remote.name,
                        newLocalIdentifier: newAssetID,
                        remoteSize: remote.size
                    )
                }

                restoredCount += 1
                bytesRestored += max(remote.size, 0)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedFiles.append(remote.relativePath)
                debugLog("❌ SmartRestore photo import failed for \(remote.relativePath): \(error.localizedDescription)")
            }

            onProgress?(index + 1, total, remote.name)
        }

        cleanupStagingDirectory(for: snapshot.id)
        return SmartRestoreExecutionResult(
            restoredCount: restoredCount,
            skippedCount: skippedCount,
            failedFiles: failedFiles,
            bytesRestored: bytesRestored
        )
    }

    private static func insertAssetIntoPhotoLibrary(
        stagedFileURL: URL,
        originalFilename: String,
        creationDate: Date?,
        isVideo: Bool
    ) async throws -> String? {
        nonisolated(unsafe) var placeholderID: String?
        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            if let creationDate {
                creationRequest.creationDate = creationDate
            }
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = originalFilename
            options.shouldMoveFile = true
            let resourceType: PHAssetResourceType = isVideo ? .video : .photo
            creationRequest.addResource(with: resourceType, fileURL: stagedFileURL, options: options)
            placeholderID = creationRequest.placeholderForCreatedAsset?.localIdentifier
        }
        return placeholderID
    }
}

// MARK: - MainActor Observable Coordinator for SwiftUI

@MainActor
@Observable
final class SmartRestoreCoordinator {
    enum Phase: Equatable {
        case idle
        case scanning(scannedCount: Int, currentPath: String)
        case preview
        case restoring(completed: Int, total: Int, currentFile: String)
        case completed(restored: Int, skipped: Int, failed: Int, bytesRestored: Int64)
        case failed(message: String, needsFolderReauthorization: Bool)
    }

    private(set) var phase: Phase = .idle
    var plan: SmartRestorePlan?
    var includeArchiveInScan: Bool = false

    private var activeTask: Task<Void, Never>?

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        if case .restoring = phase {
            phase = .preview
        } else if case .scanning = phase {
            phase = .idle
        }
    }

    func startScan(for task: BackupTask) {
        activeTask?.cancel()
        let snapshot = SmartRestoreTaskSnapshot(task: task)

        if BackupScheduler.shared.runningTaskIDs.contains(snapshot.id) ||
            SmartRestoreTaskLock.shared.isRestoreActive(for: snapshot.id) {
            phase = .failed(message: SmartRestoreError.taskBusyWithBackup.localizedDescription, needsFolderReauthorization: false)
            return
        }

        phase = .scanning(scannedCount: 0, currentPath: snapshot.destinationPath)
        let includeArchive = includeArchiveInScan

        activeTask = Task {
            guard SmartRestoreTaskLock.shared.acquireRestoreLock(for: snapshot.id) else {
                self.phase = .failed(message: SmartRestoreError.taskBusyWithBackup.localizedDescription, needsFolderReauthorization: false)
                return
            }
            defer {
                SmartRestoreTaskLock.shared.releaseRestoreLock(for: snapshot.id)
            }

            do {
                let computedPlan = try await Task.detached(priority: .userInitiated) {
                    try await Self.performBackgroundScanAndDiff(
                        snapshot: snapshot,
                        includeArchive: includeArchive
                    ) { count, folder in
                        Task { @MainActor in
                            if case .scanning = self.phase {
                                self.phase = .scanning(scannedCount: count, currentPath: folder)
                            }
                        }
                    }
                }.value

                try Task.checkCancellation()
                self.plan = computedPlan
                self.phase = .preview
            } catch is CancellationError {
                self.phase = .idle
            } catch let restoreError as SmartRestoreError {
                let needsFolderAuth: Bool
                switch restoreError {
                case .folderAccessUnavailable, .folderWriteProbeFailed:
                    needsFolderAuth = true
                default:
                    needsFolderAuth = false
                }
                self.phase = .failed(
                    message: restoreError.localizedDescription,
                    needsFolderReauthorization: needsFolderAuth
                )
            } catch {
                self.phase = .failed(
                    message: error.localizedDescription,
                    needsFolderReauthorization: false
                )
            }
        }
    }

    func executeSelectedRestore(for task: BackupTask) {
        guard let currentPlan = plan else { return }
        activeTask?.cancel()
        let snapshot = SmartRestoreTaskSnapshot(task: task)
        let selectedItems = currentPlan.selectedItemsToRestore
        guard !selectedItems.isEmpty else { return }

        if BackupScheduler.shared.runningTaskIDs.contains(snapshot.id) ||
            SmartRestoreTaskLock.shared.isRestoreActive(for: snapshot.id) {
            phase = .failed(message: SmartRestoreError.taskBusyWithBackup.localizedDescription, needsFolderReauthorization: false)
            return
        }

        phase = .restoring(completed: 0, total: selectedItems.count, currentFile: selectedItems.first?.remoteItem.name ?? "")
        UIApplication.shared.isIdleTimerDisabled = true

        activeTask = Task {
            defer {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            guard SmartRestoreTaskLock.shared.acquireRestoreLock(for: snapshot.id) else {
                self.phase = .failed(message: SmartRestoreError.taskBusyWithBackup.localizedDescription, needsFolderReauthorization: false)
                return
            }
            defer {
                SmartRestoreTaskLock.shared.releaseRestoreLock(for: snapshot.id)
            }

            var bgTaskID: UIBackgroundTaskIdentifier = .invalid
            bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "SmartRestore") {
                if bgTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                    bgTaskID = .invalid
                }
            }
            defer {
                if bgTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                    bgTaskID = .invalid
                }
            }

            do {
                let client = RemoteRestoreClientFactory.makeClient(for: snapshot)
                let result = try await Task.detached(priority: .userInitiated) {
                    try await SmartRestoreEngine.executeRestorePlan(
                        snapshot: snapshot,
                        plan: currentPlan,
                        client: client
                    ) { completed, total, fileName in
                        Task { @MainActor in
                            if case .restoring = self.phase {
                                self.phase = .restoring(completed: completed, total: total, currentFile: fileName)
                            }
                        }
                    }
                }.value

                self.phase = .completed(
                    restored: result.restoredCount,
                    skipped: result.skippedCount,
                    failed: result.failedFiles.count,
                    bytesRestored: result.bytesRestored
                )
            } catch is CancellationError {
                self.phase = .preview
            } catch {
                self.phase = .failed(
                    message: error.localizedDescription,
                    needsFolderReauthorization: false
                )
            }
        }
    }

    func ignoreCandidate(_ candidate: SmartRestoreCandidate) {
        guard var currentPlan = plan else { return }
        RestoredPhotoLedgerStore.shared.setIgnored(
            true,
            taskID: currentPlan.taskID,
            relativePath: candidate.remoteItem.relativePath
        )
        currentPlan.missingItems.removeAll { $0.id == candidate.id }
        currentPlan.ambiguousItems.removeAll { $0.id == candidate.id }
        currentPlan.conflictItems.removeAll { $0.id == candidate.id }

        let ignoredItem = SmartRestoreCandidate(
            remoteItem: candidate.remoteItem,
            state: .ignored,
            isSelected: false
        )
        currentPlan.ignoredItems.append(ignoredItem)
        plan = currentPlan
    }

    func unignoreCandidate(_ candidate: SmartRestoreCandidate) {
        guard var currentPlan = plan else { return }
        RestoredPhotoLedgerStore.shared.setIgnored(
            false,
            taskID: currentPlan.taskID,
            relativePath: candidate.remoteItem.relativePath
        )
        currentPlan.ignoredItems.removeAll { $0.id == candidate.id }
        let restoredCandidate = SmartRestoreCandidate(
            remoteItem: candidate.remoteItem,
            state: .missingLocally,
            isSelected: !currentPlan.autoSelectionDisabledByThreshold,
            parsedPhotoDate: SmartRestorePhotoDescriptor.parse(fileNameOrRelativePath: candidate.remoteItem.relativePath)?.localTimeZoneDate
        )
        currentPlan.missingItems.append(restoredCandidate)
        plan = currentPlan
    }

    private nonisolated static func performBackgroundScanAndDiff(
        snapshot: SmartRestoreTaskSnapshot,
        includeArchive: Bool,
        onProgress: @Sendable @escaping (Int, String) -> Void
    ) async throws -> SmartRestorePlan {
        // 1. Preflight local destination before spending network I/O
        let resolvedLocalFolderURL: URL?
        let photoAuthStatus: PHAuthorizationStatus

        if snapshot.isPhotoLibrarySource {
            guard SmartRestoreConfiguration.isPhotoSmartRestoreEnabled else {
                throw SmartRestoreError.photoSmartRestoreDisabled
            }
            let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if currentStatus == .notDetermined {
                photoAuthStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            } else {
                photoAuthStatus = currentStatus
            }
            if photoAuthStatus == .limited {
                throw SmartRestoreError.photoAccessLimited
            }
            guard photoAuthStatus == .authorized else {
                throw SmartRestoreError.photoAccessDenied
            }
            resolvedLocalFolderURL = nil
        } else {
            resolvedLocalFolderURL = try SmartRestoreEngine.resolveAndProbeWritableFolder(sourcePath: snapshot.sourcePath)
            photoAuthStatus = .notDetermined
        }

        // 2. Connect & scan remote inventory via protocol-agnostic adapter
        let client = RemoteRestoreClientFactory.makeClient(for: snapshot)
        try await client.connect()
        let effectiveRoot: String
        let remoteItems: [RemoteRestoreItem]
        do {
            effectiveRoot = try await client.resolveEffectiveBackupRoot()
            remoteItems = try await SmartRestoreEngine.scanRemoteInventory(
                client: client,
                rootPath: effectiveRoot,
                includeArchive: includeArchive,
                onProgress: onProgress
            )
            await client.disconnect()
        } catch {
            await client.disconnect()
            throw error
        }

        try Task.checkCancellation()

        // 3. Diff against local inventory
        if snapshot.isPhotoLibrarySource {
            let localAssets = try await PhotoLibraryManager.shared.fetchAssetSnapshots(mediaType: snapshot.mediaType)
            return try SmartRestoreEngine.computePhotoDiff(
                taskID: snapshot.id,
                remoteRootPath: effectiveRoot,
                remoteItems: remoteItems,
                localAssets: localAssets,
                authorizationStatus: photoAuthStatus
            )
        } else if let resolvedLocalFolderURL {
            let localInventory = try SmartRestoreEngine.scanLocalFolderInventory(rootURL: resolvedLocalFolderURL)
            let ignoredKeys = Set(RestoredPhotoLedgerStore.shared.ignoredPaths(for: snapshot.id).keys)
            return SmartRestoreEngine.computeFolderDiff(
                taskID: snapshot.id,
                remoteRootPath: effectiveRoot,
                remoteItems: remoteItems,
                localItems: localInventory,
                ignoredKeys: ignoredKeys
            )
        } else {
            throw SmartRestoreError.folderAccessUnavailable(path: snapshot.sourcePath)
        }
    }
}
