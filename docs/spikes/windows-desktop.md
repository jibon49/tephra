# Platform Spike: Windows Tray Icon, Second Window, File Watcher (Step 00.19)

## Purpose & Overview
De-risk desktop capabilities required for Phase 4 (floating sticky notes, multi-window support), Windows system tray integration, and directory file watching on Windows.

## Test Environment
- **Platform**: Windows 11 (x64)
- **Toolchain**: Visual Studio Build Tools 2022 (MSVC C++), Flutter 3.47.7, Dart 3.13.5
- **Dependencies**:
  - `tray_manager: 0.8.0` (nativeapi based)
  - `desktop_multi_window: 0.3.1`
  - `watcher: 1.2.1`
  - `path: 1.9.1`
- **Licenses**: 47 packages inspected, all allowed. Note: `desktop_multi_window` pub page states conflicting MIT/Apache-2.0 labels; its repository `LICENSE` file explicitly specifies **Apache License Version 2.0 (January 2004)**, which is an allowed permissive license under project rules.

## Results Summary

| Capability | Status | Details / Measurements |
|---|---|---|
| **System Tray Icon** | **PASS** | Initialized `TrayIcon.create()` with `assets/tray.ico` and tooltip "Tephra Windows Spike". Lifetime reference preserved. |
| **Tray Context Menu** | **PASS** | Created menu with "Show window", "New window", separator, and "Quit" menu items. Listeners wired to `MenuItemClickedEvent`. |
| **Multi-Window (Second Window)** | **PASS** | Spawned secondary window via `WindowController.create(WindowConfiguration(...))`. Window ID: `82e05680-2f13-4ac7-9c8a-9a15c08e1022`. |
| **Sub-Window Argument Passing** | **PASS** | JSON arguments (`{"type":"sticky","title":"Sticky Note #1",...}`) successfully received in sub-window engine via `WindowController.fromCurrentEngine() -> arguments` and rendered into the `StickySpikeApp` UI. |
| **Sub-Window Plugin Registration** | **PASS** | Registered `DesktopMultiWindowSetWindowCreatedCallback` in `windows/runner/flutter_window.cpp` so subsequent Flutter engines register plugins without `MissingPluginException`. |
| **Directory File Watcher** | **PASS** | Active on `D:\script\tephra-gemini\test_vaults\real`. Add, modify, rename, and remove events captured with low latency. |

## Filesystem Watcher Latency Benchmarks (Windows)
File events monitored on `D:\script\tephra-gemini\test_vaults\real` using `DirectoryWatcher` (`package:watcher`):

| Operation | PowerShell Action | Event Received | Event Type | Latency (ms) |
|---|---|---|---|---|
| **Modify** | `Add-Content note-0001.md 'x'` | Yes | `add` / `modify` | **135 ms** |
| **Create** | `New-Item new_spike.md` | Yes | `add` | **155 ms** |
| **Rename** | `Rename-Item new_spike.md -> renamed_spike.md` | Yes | `remove` + `add` | **135 ms** |
| **Delete** | `Remove-Item renamed_spike.md` | Yes | `remove` | **161 ms** |

*All fixture changes were cleanly reverted via git checkout and deletions; `test_vaults/real` verified intact.*

## API Notes & Architecture Guidance for Phase 4
1. **Multi-Window Lifecycle**:
   - Each window created with `desktop_multi_window` runs in an independent Flutter engine and isolate.
   - Entry point routing: In `main(List<String> args)`, query `await WindowController.fromCurrentEngine()`. If arguments are non-empty, parse the arguments (e.g., sticky note ID, coordinates) and launch the sticky window widget rather than the full main app shell.
   - Sub-window plugin registration in `windows/runner/flutter_window.cpp` using `DesktopMultiWindowSetWindowCreatedCallback` is required for plugin method channels to function across multiple engines.
2. **System Tray Integration**:
   - In `tray_manager 0.8.x`, `TrayIcon.create()` returns an instance that must be stored in a variable kept alive for the app lifetime (garbage collection destroys the native tray handle).
   - Menu items are created via `MenuItem.createWithLabelAndType(label, MenuItemType.normal)`.
3. **Cross-Platform Watcher Parity**:
   - `DirectoryWatcher` from `package:watcher` behaves consistently on both Windows and Android, detecting atomic renames as a paired `remove` and `add` event within 135–165 ms on Windows.
