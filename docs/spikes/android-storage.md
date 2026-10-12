# Platform Spike: Android Shared Storage and File Watching (Step 00.18)

## Purpose & Overview
Evaluate Android shared storage access ("All files access" / `MANAGE_EXTERNAL_STORAGE`), atomic read/write in `/storage/emulated/0/Documents/TestVault`, and file watcher event detection across three watcher implementations on Android 11+ (API 30+).

## Test Environment
- **Device**: Android Emulator (`tephra_api36`), x86_64 architecture.
- **Android OS**: Android 16 (API 36).
- **Target Folder**: `/storage/emulated/0/Documents/TestVault` (symlinked as `/sdcard/Documents/TestVault`).
- **Dependencies**: `permission_handler: 11.3.1`, `watcher: 1.2.1`, `path: 1.9.1`.
- **License Check**: 38 packages inspected, 0 disallowed.

## Permission Flow Description
1. **Initial State**:
   - Querying `Permission.manageExternalStorage.status` returns `PermissionStatus.denied`.
2. **Request Flow**:
   - Invoking `Permission.manageExternalStorage.request()` automatically triggers an Intent opening the Android System Settings page titled **"All files access"** for `android_storage_spike` (`com.tephra.spike.android_storage_spike`).
   - The settings screen displays:
     - Header: "All files access" with application icon and version 1.0.0.
     - Switch: "Allow access to manage all files" (initially toggled OFF).
     - Informational description: *"Allow this app to read, modify and delete all files on this device or any connected storage volumes. If granted, app may access files without your explicit knowledge."*
3. **Grant and Return**:
   - Toggling the switch turns it ON (highlighted pill).
   - Pressing the system Back button (`KEYCODE_BACK`) returns focus to the application.
   - The permission status immediately transitions to `PermissionStatus.granted`.

## Atomic Read & Write Verification
- Created vault directory `/storage/emulated/0/Documents/TestVault/`.
- Performed atomic write of `hello.md` using the project's contract: write to temporary file `hello.md.tmp` -> `flush: true` -> atomic filesystem rename to `hello.md`.
- Read back content directly from `/storage/emulated/0/Documents/TestVault/hello.md`.
- Verified content byte-exact match (`Matches: true`).

## Watcher Evaluation Results
External filesystem modifications were applied via ADB shell commands with millisecond timestamps (`date +%s%3N`):
1. **Modify**: `echo external >> /sdcard/Documents/TestVault/hello.md`
2. **Add**: `echo new > /sdcard/Documents/TestVault/new.md`
3. **Remove**: `rm /sdcard/Documents/TestVault/new.md`

### Benchmark Table (Variant × Operation)
All measurements on Android 16 emulator (marked `emulator/debug`):

| Watcher Implementation | Operation | Event Received | Event Type Reported | Measured Latency | Budget (< 1000 ms) |
|---|---|---|---|---|---|
| **`DirectoryWatcher` (package:watcher)** | Modify | Yes | `modify` | **655 ms** | Pass |
| | Add | Yes | `add` | **831 ms** | Pass |
| | Remove | Yes | `remove` | **996 ms** | Pass |
| **`Directory.watch` (dart:io inotify)** | Modify | Yes | `modify` | **56 ms** | Pass |
| | Add | Yes | `create` (+ modify) | **22 ms** | Pass |
| | Remove | Yes | `delete` | **39 ms** | Pass |
| **`PollingDirectoryWatcher` (1s delay)** | Modify | Yes | `modify` | **57 ms** | Pass |
| | Add | Yes | `add` | **417 ms** | Pass |
| | Remove | Yes | `remove` | **88 ms** | Pass |

## Observations & Analysis
1. **`DirectoryWatcher` (`package:watcher`)**:
   - On Android/Linux, `DirectoryWatcher` utilizes native event notifications with debounce/aggregation logic.
   - All three event types (`add`, `modify`, `remove`) were captured consistently within the 1-second budget (655 ms – 996 ms).
2. **`Directory.watch` (`dart:io`)**:
   - Uses native Linux `inotify` directly.
   - Latencies are nearly instantaneous (22 ms – 56 ms).
   - However, standard `dart:io` `Directory.watch` does not debounce or synthesize high-level events (e.g. multiple modify events per write).
3. **`PollingDirectoryWatcher`**:
   - Polling at 1-second intervals provides guaranteed delivery across non-standard filesystems, but generates recurring periodic disk stats.

## Decision for Phase 1
**Use `DirectoryWatcher` (`package:watcher`) on Android.**
- **Rationale**: `DirectoryWatcher` successfully captured all add, modify, and remove events within the required 1-second budget on Android shared storage (`/storage/emulated/0/Documents/`), while providing unified cross-platform event normalization (`WatchEvent` with `ChangeType.ADD`, `MODIFY`, `REMOVE`).
- Fallback recommendation: If a device or network storage mount fails to produce native events during initialization or health-check, fallback to `PollingDirectoryWatcher(pollingDelay: Duration(seconds: 1))` is trivial to configure.
