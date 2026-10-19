# BackupFlow for Android — Complete Application Spec & AI Implementation Roadmap

> **Purpose of this Document:**
> This `roadmap.md` is a complete architectural blueprint, feature specification, data model mapping, and step-by-step development roadmap designed for an AI Coding Agent in **Android Studio** to build the 1:1 Android counterpart of the **BackupFlow** iOS application.

---

## 1. Product Overview

**BackupFlow** is a privacy-first, cloud-free automated file and photo/video backup application. It backs up local device folders and the device Photo/Video Library directly to user-owned servers (NAS devices like Synology, QNAP, TrueNAS, Nextcloud, ownCloud, or Linux/Windows servers) using **FTP**, **SFTP (SSH)**, and **WebDAV (HTTP/HTTPS)** protocols.

### Core Value Proposition
- **100% Private / Zero Third-Party Cloud:** Direct device-to-server transfer over local Wi-Fi or VPN/remote network.
- **Multi-Protocol Support:** FTP (with Passive/Active & UTF-8 support), SFTP (SSHv2 with TOFU host key pinning), and WebDAV (HTTPS default with self-signed certificate TOFU pinning).
- **Flexible Sources:**
  1. **Media Library:** Photos only, Videos only, or Photos & Videos (`MediaStore` on Android).
  2. **Document / Folder Tree:** Any local or cloud-provider folder selected by the user (`Storage Access Framework` / DocumentTree on Android).
- **Smart Sync & Deletion Policies:**
  1. **Append-Only (Safe Default):** Never deletes files on the remote server; only uploads new or modified files.
  2. **Mirror:** Deletes remote orphan files that no longer exist on the device (with strict safety guards so an empty/revoked photo library permission never wipes remote photos).
  3. **Archive:** Instead of deleting remote orphans, moves them to `.backupflow_archive/<yyyyMMdd-HHmmss-uuid>/<relativePath>`.
- **Dry-Run Preview:** Before running a manual backup, users can preview exact counts of *New*, *Updated*, *Skipped*, and *Deleted/Archived* files and total bytes without mutating the remote server.
- **Incremental Checkpoints & Resume:** Tracks uploaded files in a checkpoint store so interrupted backups resume without re-uploading completed files.
- **Upload Integrity Verification:** Optional SHA-256 / remote size verification after upload (`verifyUploads`) and remote `.backupflow_manifest.json` generation.
- **Smart Scheduling & Preconditions:** Manual, Daily, Weekly, Monthly, or Interval (every N hours) scheduling with guards for **Wi-Fi Only**, **Charging/External Power**, **Minimum Battery Level (%)**, and **Allowed Time Window** (e.g., 23:00–06:00).

---

## 2. iOS-to-Android Technology & Architecture Mapping

Use modern Android Jetpack & Kotlin idioms (2026 standards):

| Layer / Feature | iOS Implementation | Android Target Stack |
| :--- | :--- | :--- |
| **Language & Concurrency** | Swift 6 + `async/await` + Actors | **Kotlin 2.x** + **Coroutines** + **Flow** |
| **UI Framework** | SwiftUI (`LiquidGlass` / modern cards) | **Jetpack Compose** + **Material 3** (Dynamic Color + Glassmorphic card surfaces) |
| **Dependency Injection** | Singletons / Environment | **Hilt (Dagger)** or **Koin** |
| **Local Database** | SwiftData (`@Model BackupTask`, `BackupHistory`) | **Room Database** (`TaskEntity`, `HistoryEntity` with ForeignKey & Cascade) |
| **Preferences** | `@AppStorage` / `UserDefaults` | **Jetpack DataStore (Preferences)** |
| **Credential Storage** | iOS Keychain (`BackupCredentialStore`) | **Android Keystore** + `EncryptedSharedPreferences` / Tink |
| **SSH Host Key & TLS Pinning** | `SFTPHostKeyStore` & `WebDAVCertificateStore` | Keystore-backed TOFU (Trust-On-First-Use) SHA-256 fingerprint store |
| **Background Scheduling** | `BGTaskScheduler` (`BGProcessingTask`, `BGAppRefreshTask`) | **WorkManager** (`PeriodicWorkRequest` + `OneTimeWorkRequest` with `Constraints`) |
| **Foreground / Live Progress** | `BGContinuedProcessingTask` + Live Activity | **ForegroundService** (`FOREGROUND_SERVICE_TYPE_DATA_SYNC`) + Ongoing Progress Notification |
| **Photo & Video Access** | `PhotoKit` (`PHAsset`, `PHImageManager`) | **MediaStore** (`MediaStore.Images`, `MediaStore.Video`) + Android 14+ Selected Photos Access |
| **Folder / File Access** | `UIDocumentPicker` + Security-Scoped Bookmarks | **Storage Access Framework (SAF)** (`OpenDocumentTree` + `takePersistableUriPermission`) |
| **FTP Client** | `FilesProvider` + custom socket engine | **Apache Commons Net** (`FTPClient` / `FTPSClient`) |
| **SFTP Client** | `Citadel` (`swift-nio-ssh`) | **SSHJ** (`com.hierynomus:sshj`) |
| **WebDAV Client** | `URLSession` + XML `PROPFIND` parser | **OkHttp 4/5** + **Sardine-Android** (or custom OkHttp `PROPFIND`/`PUT`/`MOVE`/`DELETE` engine) |
| **Network Monitoring** | `NWPathMonitor` | `ConnectivityManager.NetworkCallback` (`TRANSPORT_WIFI`, `TRANSPORT_CELLULAR`, `TRANSPORT_VPN`) |

---

## 3. Core Data Models (Room Schema Specification)

### 3.1. Enumerations

```kotlin
enum class BackupType(val defaultPort: Int) {
    FTP(21),
    SFTP(22),
    WEBDAV(443)
}

enum class BackupStatus {
    IDLE,
    PREPARING,
    SCANNING,
    UPLOADING,
    COMPLETED,
    FAILED,
    CANCELLED
}

enum class BackupDeletionPolicy {
    APPEND_ONLY, // Default for new tasks
    MIRROR,
    ARCHIVE
}

enum class BackupChecksumMode {
    OFF,           // Default
    VERIFY_UPLOADS // SHA-256 & remote size verification + manifest upload
}

enum class BackupFailureCategory {
    NETWORK,
    AUTH,
    PERMISSION,
    SERVER,
    QUOTA,
    CLOUD_ONLY,
    CERTIFICATE,
    CANCELLED,
    UNKNOWN
}

enum class MediaType {
    PHOTOS_ONLY,
    VIDEOS_ONLY,
    PHOTOS_AND_VIDEOS
}

enum class FrequencyType {
    MANUAL,
    DAILY,
    WEEKLY,
    MONTHLY,
    INTERVAL_HOURS
}
```

### 3.2. `BackupTaskEntity` (Room Table: `backup_tasks`)

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `UUID` (PrimaryKey) | `UUID.randomUUID()` | Unique task identifier |
| `displayName` | `String` | `"Backup Task"` | User-visible task name |
| `sourcePath` | `String` | — | `"PHOTOS_LIBRARY"` or SAF Tree URI string (`content://...`) |
| `backupType` | `BackupType` | `FTP` | `FTP`, `SFTP`, or `WEBDAV` |
| `serverHost` | `String` | `""` | IP, hostname, or URL |
| `serverPort` | `Int` | `21/22/443` | Target port |
| `serverUsername` | `String` | `""` | Username (empty if anonymous FTP) |
| `credentialKeyRef` | `String` | `"keychain:<uuid>"` | Reference key; actual password lives in Encrypted Store |
| `destinationPath` | `String` | `"/"` | Remote base folder path |
| `mediaType` | `MediaType` | `PHOTOS_ONLY` | Used when `sourcePath == "PHOTOS_LIBRARY"` |
| `isEnabled` | `Boolean` | `true` | Whether schedule is active |
| `isPaused` | `Boolean` | `false` | Temporarily pauses scheduled execution |
| `frequencyType` | `FrequencyType` | `MANUAL` | Schedule mode |
| `scheduledHour` | `Int?` | `0` | Hour (`0..23`) for daily/weekly/monthly |
| `scheduledMinute` | `Int?` | `0` | Minute (`0..59`) |
| `scheduledWeekday` | `Int?` | `1` | `1` (Sunday) .. `7` (Saturday) |
| `scheduledMonthDay` | `Int?` | `1` | `1..31` |
| `intervalHours` | `Int?` | `6` | Used when `frequencyType == INTERVAL_HOURS` |
| `deletionPolicy` | `BackupDeletionPolicy` | `APPEND_ONLY` | Orphan handling policy |
| `checksumMode` | `BackupChecksumMode` | `OFF` | Upload verification mode |
| `requiresWiFi` | `Boolean` | `false` | Block/wait if not on Wi-Fi |
| `requiresExternalPower` | `Boolean` | `false` | Require charger connected |
| `allowCellularForLocalServer` | `Boolean` | `false` | Allow cellular when reaching local/VPN subnet |
| `includeCloudAssets` | `Boolean` | `true` | Whether to request cloud-backed media |
| `allowedStartHour` / `Minute` | `Int?` | `null` | Start of allowed execution time window |
| `allowedEndHour` / `Minute` | `Int?` | `null` | End of allowed execution time window |
| `wifiWaitDeadline` | `Long?` | `null` | Epoch millis deadline while waiting for Wi-Fi |
| `createdAt` | `Long` | `now()` | Creation timestamp |
| `lastBackupDate` | `Long?` | `null` | Last successful backup timestamp |
| `nextRunTime` | `Long?` | `null` | Calculated next execution timestamp |
| `backupStatus` | `BackupStatus` | `IDLE` | Live status |
| `progress` | `Double` | `0.0` | Overall progress (`0.0..1.0`) |
| `currentFile` | `String?` | `null` | Name of file currently uploading |
| `currentFileProgress` | `Double` | `0.0` | Current file progress (`0.0..1.0`) |
| `currentFileBytesTransferred`| `Long` | `0` | Current file transferred bytes |
| `currentFileTotalBytes` | `Long` | `0` | Current file total bytes |
| `transferSpeedBytesPerSec` | `Double` | `0.0` | Live transfer speed |
| `lastError` | `String?` | `null` | Last failure message |
| `lastFailureCategory` | `BackupFailureCategory?`| `null` | Categorized failure reason |
| `consecutiveFailureCount` | `Int` | `0` | Incremented on failure, reset on success |

### 3.3. `BackupHistoryEntity` (Room Table: `backup_history`)

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | `UUID` (PrimaryKey) | Unique history record ID |
| `taskId` | `UUID?` | Foreign key to `BackupTaskEntity.id` (`ON DELETE SET NULL`) |
| `timestamp` | `Long` | Execution finish/record time |
| `status` | `String` | `"completed"`, `"failed"`, `"cancelled"`, `"interrupted"`, `"deferred"` |
| `filesProcessed` | `Int` | Uploaded + updated count |
| `totalFiles` | `Int` | Total candidate files |
| `newFiles` | `Int` | Newly uploaded files |
| `updatedFiles` | `Int` | Overwritten/updated files |
| `skippedFiles` | `Int` | Unchanged files skipped |
| `deletedFiles` | `Int` | Remote orphans deleted (or archived) |
| `verifiedFiles` | `Int` | Files verified via checksum/size |
| `bytesTransferred` | `Long` | Total bytes uploaded in this run |
| `totalBytes` | `Long` | Total bytes across scanned set |
| `durationSeconds` | `Double` | Elapsed execution time |
| `errorMessage` | `String?` | Error message if failed/deferred |
| `failureCategory` | `BackupFailureCategory?` | Categorized reason |
| `previewSummarySnapshot` | `String?` | Snapshot string (`new=X;updated=Y;skipped=Z;deleted=W;bytes=B;policy=P`) |
| `taskDisplayName` | `String?` | Denormalized snapshot of task name (survives task deletion) |
| `taskSourcePath` | `String?` | Denormalized snapshot of source path |
| `taskServerHost` | `String?` | Denormalized snapshot of host |
| `taskServerPort` | `Int?` | Denormalized snapshot of port |
| `taskUsername` | `String?` | Denormalized snapshot of username |
| `taskIsAnonymous` | `Boolean?` | Denormalized snapshot of anonymous flag |
| `taskMediaTypeRaw` | `String?` | Denormalized snapshot of media type |

---

## 4. Critical Business Logic & Security Rules

The Android port **must** preserve these exact behaviors from the iOS codebase:

### 4.1. Path Traversal & Archive Rules (`BackupArchive`)
- **Reserved Names:**
  - `.backupflow_archive` (Directory where archived orphans are moved)
  - `.backupflow_manifest.json` (Upload manifest file)
  - Sync engines **must ignore** any remote file/folder matching or inside `.backupflow_archive` or `.backupflow_manifest.json` when scanning for orphans!
- **Path Sanitization (`sanitize` & `safeRemotePath`):**
  - Strip all empty segments, `.` segments, and `..` segments from any `relativePath` before joining with `basePath`.
  - Archive destination format: `<basePath>/.backupflow_archive/<yyyyMMdd-HHmmss-uuid8>/<sanitizedRelativePath>`.

### 4.2. Photo Library Orphan Deletion Safety Guard
- In `MIRROR` mode, when backing up `PHOTOS_LIBRARY`, **never** delete remote orphan photos unless:
  1. The app has **Full Photo/Video Library Access** (not Android 14's partial/selected photos access `READ_MEDIA_VISUAL_USER_SELECTED` alone), **AND**
  2. `visibleAssetCount > 0` (prevents wiping the user's NAS if the OS returns 0 assets due to a permission glitch).

### 4.3. Security Architecture (Mandatory)
1. **Transport Security:**
   - WebDAV connections default to `https://` unless the user explicitly prefixes `http://` or uses port `80`.
   - Android `network_security_config.xml` must disallow cleartext traffic to public internet domains while allowing local networking (RFC1918 private LAN IPs / `.local` mDNS) for user NAS servers.
2. **TOFU (Trust-On-First-Use) Certificate & SSH Host Key Pinning:**
   - **SFTP (`SFTPHostKeyStore`):** Compute SHA-256 fingerprint of server's SSH public key (`SHA256:<base64>`). On first connection to `host:port`, store in encrypted preferences. On subsequent connections, if fingerprint mismatches, abort immediately with `BackupFailureCategory.CERTIFICATE` (`changedHostKey`) to prevent MITM attacks.
   - **WebDAV (`WebDAVCertificateStore`):** For self-signed NAS TLS certificates, compute SHA-256 fingerprint of the leaf `X509Certificate`. Pin on first connection per `host:port`, verify on subsequent connections, and reject mismatches.
3. **Memory Hygiene:**
   - Never keep plaintext passwords in singleton service fields after `disconnect()` or backup completion. Clear credential references immediately in `finally` blocks.

### 4.4. Sync Engine Algorithm (FTP / SFTP / WebDAV)
Each protocol shares a unified 4-stage pipeline:
1. **Stage 1 — Scan Source & Remote:**
   - Collect local files (`relativePath -> LocalFileMetadata(uri, size, lastModified)`) or MediaStore assets (`IMG_yyyyMMdd_HHmmss_<id>.ext`).
   - Recursively list remote directory (`relativePath -> RemoteFileMetadata(name, path, size, modifiedDate)`).
2. **Stage 2 — Compare & Upload:**
   - Skip files present in the run's resume checkpoint if they already exist remotely.
   - Compare `local.size == remote.size` (and filename). If identical -> increment `skippedFiles`.
   - If not in remote -> `newFiles`; if size differs -> `updatedFiles`.
   - If `isDryRun == true`: do **not** create remote directories or upload; only tally counts and bytes.
   - If `isDryRun == false`: ensure parent directories exist, stream upload with live byte progress and transfer speed calculation (`TransferProgressSource`).
   - If `checksumMode == VERIFY_UPLOADS`: compute local SHA-256, verify remote file size (and re-read stream if supported), and append entry to `.backupflow_manifest.json`.
   - Record uploaded `relativePath` into persistent checkpoint store so interrupted runs can resume.
3. **Stage 3 — Orphan Cleanup (only if `failedUploads == 0`):**
   - Find remote files not in `localRelativePaths` and not `BackupArchive.isReserved(relativePath)`.
   - Apply `deletionPolicy`:
     - `APPEND_ONLY`: Do nothing.
     - `MIRROR`: Delete remote file (or increment `deletedFiles` in dry-run).
     - `ARCHIVE`: Move/rename remote file to `BackupArchive.destinationPath(...)`.
4. **Stage 4 — Finalize:**
   - Upload `.backupflow_manifest.json` if `VERIFY_UPLOADS` is enabled.
   - Clear resume checkpoint on clean completion.
   - Clean up temporary exported media files (`TemporaryStorageMaintenance`).

---

## 5. UI / UX Screens & Navigation Structure

The app uses a clean, modern single-dashboard navigation flow with modal sheets / full-screen destinations:

1. **Main Dashboard (`MainTabView` / `DashboardScreen`):**
   - **Hero Status Card:** Shows overall state (`"Ready to Sync"`, `"Safe & Synced"`, `"Backing Up Now..."`, or error status), circular/linear progress indicator, active transfer speed, current filename, and quick Play/Pause/Cancel button.
   - **Saved Servers / Tasks Section:** Up to 5 cards on dashboard (with "See All"), showing protocol badge/watermark (`FTP`, `SFTP`, `WebDAV`), `host:port/path`, schedule badge, last backup relative time, and quick actions:
     - **Run Now**
     - **Dry-Run Preview**
     - **Edit Task**
     - **Delete Task**
   - **Recent Backups Section:** Last 3 backup history rows with status pill (`Completed`, `Failed`, `Cancelled`, `Deferred`) and tap-to-view details.
   - **Top Bar Actions:** Add Task (`+`), History button, Settings button.
2. **Add / Edit Backup Task Screen (`BackupView` + `BackupFormSections`):**
   - **Source Picker:** Toggle between *Photo Library* (`Photos Only`, `Videos Only`, `Photos & Videos`, `Include Cloud Assets`) and *Folder Picker* (SAF DocumentTree).
   - **Protocol Selector:** Segmented control for `FTP`, `SFTP`, `WebDAV`.
   - **Server Credentials Form:** Host, Port (auto-populated default), Username, Password (with visibility toggle), Anonymous toggle (FTP), Remote Destination Path, **"Test Connection"** button (shows SSH/TLS fingerprint trust status), and **"Browse Remote Folder"** button (`RemoteFolderPicker` modal sheet).
   - **Schedule Section:** Manual, Daily (time picker), Weekly (day of week + time), Monthly (day of month + time), Interval (every N hours).
   - **Sync & Safety Policy Section:** Deletion policy (`Append Only`, `Mirror`, `Archive`), Checksum verification toggle.
   - **Execution Conditions Section:** Require Wi-Fi, Require Charging, Allow Cellular for Local/VPN Server, Allowed Time Window (Start Time – End Time).
3. **Remote Folder Picker Sheet (`RemoteFolderPicker`):**
   - Connects live to FTP/SFTP/WebDAV server, lists directories, supports navigating into subfolders, going to parent folder (`..`), and selecting `"Use This Folder"`.
4. **Dry-Run Preview Sheet (`BackupPreviewSheet`):**
   - Executes `previewBackup(task)` (`isDryRun = true`) and displays a summary breakdown: New files, Updated files, Skipped files, Files to be Deleted/Archived, Total transfer size, and a **"Start Backup Now"** confirmation button.
5. **Task Detail & History Detail Screens (`TaskDetailView`, `HistoryView`):**
   - Full list of past runs filtered by status, detailed metrics per run (duration, speed, new/updated/skipped/deleted/verified counts, failure category badge, and full error message).
6. **Settings Screen (`SettingsView` & `BatterySettingsView`):**
   - **History Retention:** 7 days, 30 days, 90 days, Unlimited (auto-pruned by `HistoryRetentionManager`).
   - **Global External Power Requirement** toggle.
   - **Battery Settings Screen:** Live battery level & charging state card + slider/picker for Minimum Battery Level threshold (default `30%`).
   - **In-App Language Picker:** System default + 12 supported languages (`ar`, `de`, `en`, `es`, `fr`, `hi`, `ja`, `ko`, `pt`, `ru`, `tr`, `zh`) using Android `AppCompatDelegate.setApplicationLocales`.
   - **About & Reset:** Version/Build info, Rate App (Play In-App Review API), Contact Support (`mailto:`), and **"Reset All Data"** (disabled while a backup is running; wipes Room DB, Keystore credentials, pinned keys, and preferences).

---

## 6. Phased Implementation Roadmap for Android Studio AI

Follow these phases sequentially. After each phase, ensure the project compiles cleanly and unit tests pass before moving to the next phase.

### Phase 1: Project Setup, Architecture & Core Data Layer
- [ ] **1.1. Gradle & Dependencies Setup:**
  - Configure Kotlin 2.x, Compose BOM, Material 3, Room, DataStore, WorkManager, Hilt, Coroutines, Serialization (`kotlinx-serialization-json`).
  - Add networking libraries: `commons-net:commons-net:3.11.1` (FTP), `com.hierynomus:sshj:0.38.0` + `bouncycastle` (SFTP), `com.squareup.okhttp3:okhttp:4.12.0` (WebDAV).
- [ ] **1.2. Domain Models & Room Database:**
  - Implement all enums (`BackupType`, `BackupStatus`, `BackupDeletionPolicy`, `BackupChecksumMode`, `BackupFailureCategory`, `MediaType`, `FrequencyType`).
  - Implement `BackupTaskEntity`, `BackupHistoryEntity`, `TaskDao`, `HistoryDao`, and `BackupFlowDatabase`.
  - Implement `HistoryRetentionManager` to prune history records older than `keepHistoryDays` (`7`, `30`, `90`, or `0 = unlimited`).
- [ ] **1.3. Security & Credential Stores:**
  - Implement `BackupCredentialStore` using Android Keystore / `EncryptedSharedPreferences` keyed by task UUID.
  - Implement `SFTPHostKeyStore` and `WebDAVCertificateStore` with thread-safe TOFU validation (`validate(fingerprint, host, port)` returning `isNew` or throwing `ChangedKeyException`) and `storedFingerprint(host, port)`.
  - Configure `res/xml/network_security_config.xml` (HTTPS default, cleartext allowed only for local networks/user-configured HTTP).
- [ ] **1.4. `BackupArchive` & `BackupChecksum` Utilities:**
  - Implement `BackupArchive.sanitize(relativePath)`, `BackupArchive.safeRemotePath(basePath, relativePath)`, `BackupArchive.isReserved(relativePath)`, and `BackupArchive.destinationPath(...)`.
  - Implement `BackupChecksum.sha256Hex(file/uri)` streaming 64 KB chunks.
  - Write unit tests for path traversal sanitization (`../../etc/passwd` -> `etc/passwd`), reserved path detection, and SHA-256 hashing.

---

### Phase 2: Protocol Services (FTP, SFTP, WebDAV) & Unified Sync Engine
- [ ] **2.1. Connection Builders & Error Mappers:**
  - Implement `WebDAVConnectionBuilder` (defaults to `https` unless `http://` or port `80` is specified).
  - Implement `FTPConnectionBuilder` and unified error mappers (`FTPErrorMapper`, `WebDAVErrorMapper`, `SFTPErrorClassifier`) mapping exceptions to `BackupFailureCategory`.
- [ ] **2.2. FTP Service (`FTPService` + `FTPSyncEngine`):**
  - Implement connect, disconnect (clearing credentials from memory), passive mode, UTF-8 (`OPTS UTF8 ON`), recursive directory listing, recursive `MKD`, streaming file upload with progress callback, `DELE`, and `RNFR`/`RNTO` for archive moves.
- [ ] **2.3. SFTP Service (`SFTPService` + `SFTPSyncEngine`):**
  - Implement SSHJ connection with modern cipher suites, custom `HostKeyVerifier` backed by `SFTPHostKeyStore`, disconnect with immediate password memory purge, recursive SFTP directory listing, streaming upload, delete, and rename/archive.
- [ ] **2.4. WebDAV Service (`WebDAVService` + `WebDAVSyncEngine`):**
  - Implement OkHttp client with custom `X509TrustManager` backed by `WebDAVCertificateStore` for self-signed certs.
  - Implement `PROPFIND` (Depth: 1 & recursive) XML parsing, `MKCOL` directory creation, streaming `PUT` upload with progress `RequestBody`, `DELETE`, and `MOVE` (with `Destination` header) for archiving.
- [ ] **2.5. Sync Engine & Orphan Cleanup (`PhotoOrphanCleanup`):**
  - Implement the 4-stage sync algorithm supporting `APPEND_ONLY`, `MIRROR`, and `ARCHIVE` policies, `isDryRun` preview mode, `VERIFY_UPLOADS` with `.backupflow_manifest.json` upload, and per-task resume checkpoints.
  - Write unit tests verifying dry-run never mutates remote state and `APPEND_ONLY` never reports deletes.

---

### Phase 3: Local File Providers, MediaStore & Device Monitors
- [ ] **3.1. Media Library Manager (`PhotoLibraryManager`):**
  - Query `MediaStore.Images` and `MediaStore.Video` filtered by `MediaType` (`PHOTOS_ONLY`, `VIDEOS_ONLY`, `PHOTOS_AND_VIDEOS`).
  - Detect full access vs. Android 14+ partial access (`READ_MEDIA_VISUAL_USER_SELECTED`) so `permitsPhotoOrphanDeletion` works identically to iOS.
  - Stream media `ContentResolver.openInputStream(uri)` or stage to `cacheDir/backupflow_exports` and clean up via `TemporaryStorageMaintenance`.
- [ ] **3.2. SAF Folder Access Manager (`FileAccessManager`):**
  - Persist folder permissions via `contentResolver.takePersistableUriPermission(treeUri, FLAG_GRANT_READ_URI_PERMISSION)`.
  - Recursively traverse `DocumentFile.fromTreeUri(...)` to build `localFileMap` with relative paths.
- [ ] **3.3. Battery & Network Monitors (`BatteryManager`, `NetworkMonitor`):**
  - Monitor battery percentage and charging state via `BatteryManager` / `ACTION_BATTERY_CHANGED`; enforce `minimumBatteryLevel` (default 30%) unless charging/full.
  - Monitor active network type (`WIFI`, `CELLULAR`, `VPN`, `NONE`) via `ConnectivityManager`.

---

### Phase 4: Scheduler, Background Execution & Notifications
- [ ] **4.1. `BackupScheduler` & Precondition Engine:**
  - Implement precondition checks in exact order:
    1. Wi-Fi requirement (if not on Wi-Fi, set `wifiWaitDeadline` and wait for network callback, or prompt user if manual run).
    2. Battery threshold, External Power requirement, and Allowed Time Window (`allowedStartTime`..`allowedEndTime`). If blocked, record `"deferred"` history entry and reschedule in +15 minutes.
    3. Re-entrancy guard & minimum run interval throttle.
  - Calculate `nextRunTime` for `DAILY`, `WEEKLY`, `MONTHLY`, and `INTERVAL_HOURS`.
- [ ] **4.2. WorkManager & Foreground Service (`ContinuedBackupRunner` equivalent):**
  - Create `BackupWorker : CoroutineWorker` for scheduled background runs and `BackupForegroundService` (with `FOREGROUND_SERVICE_TYPE_DATA_SYNC`) for user-initiated or long-running transfers.
  - Show an ongoing progress notification with live file name, percentage, transfer speed, and a **"Cancel"** action button (`PendingIntent`).
- [ ] **4.3. Notifications (`BackupNotifier`):**
  - Create Notification Channels: `backup_progress` (Low importance, ongoing), `backup_results` (Default importance, completion/failure alerts), and `backup_reminders` (Scheduled backup reminders).

---

### Phase 5: Jetpack Compose UI, Localization & Polish
- [ ] **5.1. Design System (`DesignSystem.kt`):**
  - Primary Brand Color: `#2E4CFA` (`rgb(0.18, 0.30, 0.98)`), Success: `#57D666`, Warning: `#F2C40F`, Error: `#E84D3D`.
  - Translucent / elevated card surfaces (`CornerRadius = 16.dp`, subtle shadow), status pills, and smooth progress animations respecting system Reduced Motion settings.
- [ ] **5.2. Screens Implementation:**
  - Build `DashboardScreen` (Hero card, Saved Servers list, Recent Backups list, Wi-Fi override confirmation dialog).
  - Build `BackupTaskFormScreen` (Source picker, FTP/SFTP/WebDAV tabs, Test Connection with TOFU fingerprint dialog, `RemoteFolderPickerSheet`, Schedule & Policy sections).
  - Build `BackupPreviewBottomSheet` (Dry-run loading state, New/Updated/Skipped/Deleted counters, total bytes, and "Start Backup" CTA).
  - Build `TaskDetailScreen` and `HistoryScreen` (filterable history list + detail sheet).
  - Build `SettingsScreen` and `BatterySettingsScreen` (History retention, external power toggle, battery threshold slider, language selector, Reset All Data with active-backup lock).
- [ ] **5.3. 12-Language Localization (`res/values-<lang>/strings.xml`):**
  - Port all string keys from `BackupFlow/Localizable.strings/*` for:
    - `values` (`en`), `values-tr` (`tr`), `values-de` (`de`), `values-es` (`es`), `values-fr` (`fr`), `values-ar` (`ar` - RTL support), `values-hi` (`hi`), `values-ja` (`ja`), `values-ko` (`ko`), `values-pt` (`pt`), `values-ru` (`ru`), `values-zh` (`zh`).
  - Configure `LocaleConfig` and per-app language preferences.

---

### Phase 6: Testing & Verification Matrix
- [ ] **6.1. Unit Tests (`src/test/java`):**
  - Default task options (`APPEND_ONLY`, `checksumMode = OFF`).
  - Dry-run options preserve task policies and never allow remote mutations.
  - Photo orphan deletion requires full media access + `visibleAssetCount > 0`.
  - SHA-256 file checksum calculation.
  - `BackupArchive` path traversal sanitization (`../../` stripping), `safeRemotePath`, and reserved path detection.
  - `WebDAVConnectionBuilder` defaults to HTTPS except for explicit `http://` or port `80`.
  - `WebDAVCertificateStore` & `SFTPHostKeyStore` TOFU pin, match, and mismatch error throwing.
  - `SFTPService` credential memory purge on disconnect.
- [ ] **6.2. Instrumented / Compose UI Tests (`src/androidTest/java`):**
  - Empty backup form disables the Save button until required server/source fields are valid.
  - Settings screen opens and closes cleanly; Reset All Data is disabled while `isProcessing == true`.
  - Room DAO CRUD and cascade behavior when deleting tasks vs. preserving denormalized history snapshots.
