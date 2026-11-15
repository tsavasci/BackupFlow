import Foundation
import SwiftData

nonisolated enum SmartRestoreConfiguration {
    /// Plan B safety switch: when set to `false`, Smart Restore is disabled for Photo Library tasks
    /// and remains active only for Folder backup tasks.
    nonisolated(unsafe) static var isPhotoSmartRestoreEnabled: Bool = true

    /// If missing file count exceeds this threshold, candidates start unselected to prevent
    /// accidental bulk downloads when a user intentionally deleted thousands of items to free space.
    static let autoSelectMissingThreshold: Int = 200

    /// Minimum free disk headroom required above the selected download size (250 MB).
    static let minimumFreeDiskSafetyMarginBytes: Int64 = 250 * 1024 * 1024
}

/// Canonical path key using Unicode NFC normalization + locale-agnostic case folding.
/// Matches APFS and standard server path semantics without Turkish `I -> ı` distortion on ASCII names.
nonisolated struct NormalizedPathKey: Hashable, Sendable, Comparable, CustomStringConvertible {
    let rawValue: String

    init(_ path: String) {
        let sanitized = BackupArchive.sanitize(relativePath: path)
        let nfc = sanitized.precomposedStringWithCanonicalMapping
        self.rawValue = nfc.folding(options: [.caseInsensitive], locale: nil)
    }

    var description: String { rawValue }

    static func < (lhs: NormalizedPathKey, rhs: NormalizedPathKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Generates a collision-free "Keep Both" filename such as `report (Restored).pdf` or `report (Restored 2).pdf`.
    static func makeKeepBothRelativePath(
        for relativePath: String,
        existingKeys: Set<NormalizedPathKey>
    ) -> String {
        let cleanRelative = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        let nsPath = cleanRelative as NSString
        let parentDir = nsPath.deletingLastPathComponent
        let fileName = nsPath.lastPathComponent
        let ext = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension

        func buildCandidate(index: Int) -> String {
            let suffix = index == 1 ? " (Restored)" : " (Restored \(index))"
            let newFileName = ext.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(ext)"
            return parentDir.isEmpty ? newFileName : "\(parentDir)/\(newFileName)"
        }

        var attempt = 1
        while attempt < 10_000 {
            let candidate = buildCandidate(index: attempt)
            if !existingKeys.contains(NormalizedPathKey(candidate)) {
                return candidate
            }
            attempt += 1
        }
        return buildCandidate(index: Int.random(in: 10_000...99_999))
    }
}

nonisolated struct RemoteRestoreItem: Identifiable, Hashable, Sendable {
    var id: String { fullRemotePath }
    let relativePath: String
    let normalizedKey: NormalizedPathKey
    let fullRemotePath: String
    let name: String
    let size: Int64
    let modifiedDate: Date?
    var hasCaseCollisionOnServer: Bool = false

    init(
        relativePath: String,
        fullRemotePath: String,
        name: String? = nil,
        size: Int64,
        modifiedDate: Date? = nil,
        hasCaseCollisionOnServer: Bool = false
    ) {
        let cleanRelative = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        self.relativePath = cleanRelative
        self.normalizedKey = NormalizedPathKey(cleanRelative)
        self.fullRemotePath = fullRemotePath
        self.name = name ?? (cleanRelative as NSString).lastPathComponent
        self.size = size
        self.modifiedDate = modifiedDate
        self.hasCaseCollisionOnServer = hasCaseCollisionOnServer
    }
}

nonisolated enum RestoreConflictResolution: String, CaseIterable, Identifiable, Sendable {
    case skip
    case keepBoth
    case overwrite

    var id: String { rawValue }
}

nonisolated enum RestoreDiffState: Hashable, Sendable {
    case missingLocally
    case unchanged
    case ambiguous(reason: String)
    case conflict(localSize: Int64, localModifiedDate: Date?)
    case alreadyRestored
    case ignored
}

nonisolated struct SmartRestoreCandidate: Identifiable, Hashable, Sendable {
    var id: String { remoteItem.fullRemotePath }
    let remoteItem: RemoteRestoreItem
    let state: RestoreDiffState
    var isSelected: Bool
    var conflictResolution: RestoreConflictResolution
    let parsedPhotoDate: Date?

    init(
        remoteItem: RemoteRestoreItem,
        state: RestoreDiffState,
        isSelected: Bool,
        conflictResolution: RestoreConflictResolution = .skip,
        parsedPhotoDate: Date? = nil
    ) {
        self.remoteItem = remoteItem
        self.state = state
        self.isSelected = isSelected
        self.conflictResolution = conflictResolution
        self.parsedPhotoDate = parsedPhotoDate
    }
}

nonisolated struct SmartRestorePlan: Sendable {
    let taskID: UUID
    let isPhotoLibrarySource: Bool
    let remoteRootPath: String
    let totalRemoteFiles: Int
    let unchangedCount: Int
    let alreadyRestoredCount: Int
    let caseCollisionCount: Int
    let autoSelectionDisabledByThreshold: Bool
    var missingItems: [SmartRestoreCandidate]
    var ambiguousItems: [SmartRestoreCandidate]
    var conflictItems: [SmartRestoreCandidate]
    var ignoredItems: [SmartRestoreCandidate]

    var selectedItemsToRestore: [SmartRestoreCandidate] {
        let missing = missingItems.filter(\.isSelected)
        let ambiguous = ambiguousItems.filter(\.isSelected)
        let conflicts = conflictItems.filter { $0.isSelected && $0.conflictResolution != .skip }
        return missing + ambiguous + conflicts
    }

    var totalBytesToDownload: Int64 {
        selectedItemsToRestore.reduce(0) { $0 + max($1.remoteItem.size, 0) }
    }
}

/// Parses BackupFlow photo filenames formatted as `yyyyMMdd_HHmmss_<12_char_id>.<ext>`.
nonisolated struct SmartRestorePhotoDescriptor: Hashable, Sendable {
    let dateString: String
    let idFragment: String
    let fileExtension: String
    let localTimeZoneDate: Date
    let utcDate: Date
    let isVideo: Bool

    static func parse(fileNameOrRelativePath: String, timeZone: TimeZone = .current) -> SmartRestorePhotoDescriptor? {
        let fileName = (fileNameOrRelativePath as NSString).lastPathComponent
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        let isImage = RestoreService.isImageExtension(ext)
        let isVideo = RestoreService.isVideoExtension(ext)
        guard isImage || isVideo else { return nil }

        let base = (fileName as NSString).deletingPathExtension
        // Expected format: yyyyMMdd_HHmmss_<idFragment>
        // Minimum length: 8 (date) + 1 (_) + 6 (time) + 1 (_) + 1 (id) = 17 chars
        let parts = base.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let datePart = String(parts[0])
        let timePart = String(parts[1])
        guard datePart.count == 8,
              timePart.count == 6,
              datePart.allSatisfy(\.isNumber),
              timePart.allSatisfy(\.isNumber) else {
            return nil
        }

        let idFragment = parts.dropFirst(2).joined(separator: "_")
        guard !idFragment.isEmpty else { return nil }

        let stamp = "\(datePart)_\(timePart)"
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.calendar = Calendar(identifier: .gregorian)
        localFormatter.timeZone = timeZone
        localFormatter.dateFormat = "yyyyMMdd_HHmmss"

        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.calendar = Calendar(identifier: .gregorian)
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        utcFormatter.dateFormat = "yyyyMMdd_HHmmss"

        guard let localDate = localFormatter.date(from: stamp),
              let parsedUTC = utcFormatter.date(from: stamp) else {
            return nil
        }

        return SmartRestorePhotoDescriptor(
            dateString: stamp,
            idFragment: String(idFragment.prefix(12)),
            fileExtension: ext,
            localTimeZoneDate: localDate,
            utcDate: parsedUTC,
            isVideo: isVideo
        )
    }
}

// MARK: - SwiftData Models (Backward-Compatible Defaults)

@Model
final class RestoredPhotoRecord {
    var recordKey: String = ""
    var taskIDString: String = ""
    var relativePath: String = ""
    var originalFileName: String = ""
    var newLocalIdentifier: String = ""
    var remoteSize: Int64 = 0
    var restoredAt: Date = Date()

    init(
        taskID: UUID,
        relativePath: String,
        originalFileName: String,
        newLocalIdentifier: String,
        remoteSize: Int64,
        restoredAt: Date = Date()
    ) {
        let cleanRel = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        self.taskIDString = taskID.uuidString
        self.relativePath = cleanRel
        self.originalFileName = originalFileName.precomposedStringWithCanonicalMapping
        self.newLocalIdentifier = newLocalIdentifier
        self.remoteSize = remoteSize
        self.restoredAt = restoredAt
        self.recordKey = "\(taskID.uuidString)|\(NormalizedPathKey(cleanRel).rawValue)"
    }
}

@Model
final class RestoreIgnoreRecord {
    var recordKey: String = ""
    var taskIDString: String = ""
    var normalizedRelativePath: String = ""
    var relativePath: String = ""
    var ignoredAt: Date = Date()

    init(taskID: UUID, relativePath: String, ignoredAt: Date = Date()) {
        let cleanRel = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        let norm = NormalizedPathKey(cleanRel).rawValue
        self.taskIDString = taskID.uuidString
        self.normalizedRelativePath = norm
        self.relativePath = cleanRel
        self.ignoredAt = ignoredAt
        self.recordKey = "\(taskID.uuidString)|\(norm)"
    }
}

// MARK: - Fast In-Memory + SwiftData Ledger Store

nonisolated final class RestoredPhotoLedgerStore: @unchecked Sendable {
    struct Entry: Sendable, Equatable {
        let taskID: UUID
        let relativePath: String
        let originalFileName: String
        let newLocalIdentifier: String
        let remoteSize: Int64
        let restoredAt: Date
    }

    static let shared = RestoredPhotoLedgerStore()

    private let lock = NSLock()
    private var byLocalIdentifier: [String: Entry] = [:]
    private var byTaskAndPathKey: [String: Entry] = [:]
    private var ignoredByTask: [UUID: [NormalizedPathKey: String]] = [:]
    private var container: ModelContainer?

    init() {}

    private func makeCompositeKey(taskID: UUID, normalizedPath: NormalizedPathKey) -> String {
        "\(taskID.uuidString)|\(normalizedPath.rawValue)"
    }

    /// Loads persisted SwiftData records into the in-memory O(1) lookup dictionaries on startup.
    func bootstrap(container: ModelContainer) {
        lock.withLock {
            self.container = container
        }
        let context = ModelContext(container)
        do {
            let photoRecords = try context.fetch(FetchDescriptor<RestoredPhotoRecord>())
            let ignoreRecords = try context.fetch(FetchDescriptor<RestoreIgnoreRecord>())
            lock.withLock {
                byLocalIdentifier.removeAll(keepingCapacity: true)
                byTaskAndPathKey.removeAll(keepingCapacity: true)
                ignoredByTask.removeAll(keepingCapacity: true)

                for rec in photoRecords {
                    guard let taskUUID = UUID(uuidString: rec.taskIDString),
                          !rec.newLocalIdentifier.isEmpty,
                          !rec.relativePath.isEmpty else { continue }
                    let entry = Entry(
                        taskID: taskUUID,
                        relativePath: rec.relativePath,
                        originalFileName: rec.originalFileName.isEmpty
                            ? (rec.relativePath as NSString).lastPathComponent
                            : rec.originalFileName,
                        newLocalIdentifier: rec.newLocalIdentifier,
                        remoteSize: rec.remoteSize,
                        restoredAt: rec.restoredAt
                    )
                    byLocalIdentifier[rec.newLocalIdentifier] = entry
                    let key = makeCompositeKey(taskID: taskUUID, normalizedPath: NormalizedPathKey(rec.relativePath))
                    byTaskAndPathKey[key] = entry
                }

                for rec in ignoreRecords {
                    guard let taskUUID = UUID(uuidString: rec.taskIDString),
                          !rec.relativePath.isEmpty else { continue }
                    let normKey = NormalizedPathKey(rec.relativePath)
                    var map = ignoredByTask[taskUUID] ?? [:]
                    map[normKey] = rec.relativePath
                    ignoredByTask[taskUUID] = map
                }
            }
        } catch {
            debugLog("⚠️ RestoredPhotoLedgerStore bootstrap failed: \(error.localizedDescription)")
        }
    }

    /// Synchronous O(1) lookup used by `PhotoLibraryManager.generateFileName` and `generateRelativePath`
    /// so restored photos keep their original server filename and never ping-pong on subsequent backups.
    func entry(forLocalIdentifier localIdentifier: String) -> Entry? {
        lock.withLock {
            byLocalIdentifier[localIdentifier]
        }
    }

    /// Synchronous O(1) lookup used during Pass 1 of Photo Diff.
    func entry(forTaskID taskID: UUID, relativePath: String) -> Entry? {
        let key = makeCompositeKey(taskID: taskID, normalizedPath: NormalizedPathKey(relativePath))
        return lock.withLock {
            byTaskAndPathKey[key]
        }
    }

    func recordRestoredPhoto(
        taskID: UUID,
        relativePath: String,
        originalFileName: String? = nil,
        newLocalIdentifier: String,
        remoteSize: Int64,
        restoredAt: Date = Date()
    ) {
        let cleanRel = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        let fileName = (originalFileName ?? (cleanRel as NSString).lastPathComponent).precomposedStringWithCanonicalMapping
        let entry = Entry(
            taskID: taskID,
            relativePath: cleanRel,
            originalFileName: fileName,
            newLocalIdentifier: newLocalIdentifier,
            remoteSize: remoteSize,
            restoredAt: restoredAt
        )
        let compositeKey = makeCompositeKey(taskID: taskID, normalizedPath: NormalizedPathKey(cleanRel))

        let activeContainer: ModelContainer? = lock.withLock {
            byLocalIdentifier[newLocalIdentifier] = entry
            byTaskAndPathKey[compositeKey] = entry
            return container
        }

        guard let activeContainer else { return }
        let context = ModelContext(activeContainer)
        do {
            let existing = try context.fetch(
                FetchDescriptor<RestoredPhotoRecord>(
                    predicate: #Predicate { $0.recordKey == compositeKey }
                )
            )
            for item in existing {
                context.delete(item)
            }
            let record = RestoredPhotoRecord(
                taskID: taskID,
                relativePath: cleanRel,
                originalFileName: fileName,
                newLocalIdentifier: newLocalIdentifier,
                remoteSize: remoteSize,
                restoredAt: restoredAt
            )
            context.insert(record)
            try context.save()
        } catch {
            debugLog("⚠️ Failed to persist RestoredPhotoRecord: \(error.localizedDescription)")
        }
    }

    func ignoredPaths(for taskID: UUID) -> [NormalizedPathKey: String] {
        lock.withLock {
            ignoredByTask[taskID] ?? [:]
        }
    }

    func isIgnored(taskID: UUID, relativePath: String) -> Bool {
        let norm = NormalizedPathKey(relativePath)
        return lock.withLock {
            ignoredByTask[taskID]?[norm] != nil
        }
    }

    func setIgnored(_ ignored: Bool, taskID: UUID, relativePath: String) {
        let cleanRel = BackupArchive.sanitize(relativePath: relativePath).precomposedStringWithCanonicalMapping
        let normKey = NormalizedPathKey(cleanRel)
        let compositeKey = makeCompositeKey(taskID: taskID, normalizedPath: normKey)

        let activeContainer: ModelContainer? = lock.withLock {
            var map = ignoredByTask[taskID] ?? [:]
            if ignored {
                map[normKey] = cleanRel
            } else {
                map.removeValue(forKey: normKey)
            }
            ignoredByTask[taskID] = map
            return container
        }

        guard let activeContainer else { return }
        let context = ModelContext(activeContainer)
        do {
            let existing = try context.fetch(
                FetchDescriptor<RestoreIgnoreRecord>(
                    predicate: #Predicate { $0.recordKey == compositeKey }
                )
            )
            for item in existing {
                context.delete(item)
            }
            if ignored {
                let record = RestoreIgnoreRecord(taskID: taskID, relativePath: cleanRel)
                context.insert(record)
            }
            try context.save()
        } catch {
            debugLog("⚠️ Failed to update RestoreIgnoreRecord: \(error.localizedDescription)")
        }
    }

    func clearAllForTesting() {
        lock.withLock {
            byLocalIdentifier.removeAll()
            byTaskAndPathKey.removeAll()
            ignoredByTask.removeAll()
        }
    }
}
