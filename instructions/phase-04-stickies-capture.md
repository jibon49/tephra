# Phase 04 — Sticky notes & quick capture

> **Duration:** 3 weeks (17 steps).
> **Goal:** stickies that feel native on each device, built on normal Markdown notes so they sync for free:
> a sticky board on both platforms, floating always-on-top sticky windows with a tray menu and a global hotkey on Windows,
> home-screen widgets, a floating bubble, a Quick Settings tile and share-to-Tephra on Android, and reminder notifications on both.

Read `GEMINI.md` and `instructions/00-conventions.md` again before you start. This file never redefines a contract;
when it says "conventions §X" it means that section of `00-conventions.md`, and that section wins over anything here.

---

## Before you start

### Prerequisite gate (all must be true; otherwise stop and tell the human)

1. `PROGRESS.md` shows every Phase 3 step and every Phase 3 exit-gate item checked, and tag `v0.03.0` exists:
   ```powershell
   git tag --list v0.03.0
   ```
   prints `v0.03.0`.
2. `git status` is clean on `main`.
3. These commands succeed from the repo root:
   ```powershell
   flutter pub get
   dart format --output=none --set-exit-if-changed app/lib app/test packages tool
   flutter analyze --fatal-infos
   cd app; flutter test; cd ..
   ```
4. A real Android phone (Android 12 or newer) is connected (`flutter devices` lists it). Several steps (widgets, overlay, exact alarms,
   share intent, Quick Settings tile) can only be verified on a device. If no phone is connected, stop and ask the human.
5. Create the branch: `git checkout -b phase-04`.

### What already exists (built in Phases 0–3)

| Area | What you can use |
|---|---|
| `tephra_core` | `VaultPath`, `TephraException` family, `Clock`/`SystemClock`, `contentHash` (conventions §7.1) |
| `tephra_vault` | `VaultFileSystem` with atomic writes, `watch()` (debounced, excludes our own writes), `IoVaultFileSystem`, `MemoryVaultFileSystem`, `TextDocument` (BOM + line-ending preserving) (§7.2) |
| `tephra_markdown` | Hand-written parser with UTF-16 source offsets: `MarkdownParser.parse(text)` → `ParsedNote` (incl. `MdFrontmatter(yaml, contentStart)`, decoded `frontmatter` map, `tasks`) (§7.3) |
| `tephra_index` | `NoteIndex` (drift + FTS5), link resolver, backlinks (§7.4) |
| `tephra_search` | `SearchParser.parse`, `SearchEngine.run` including `[prop:value]` operators (§7.5) |
| `tephra_sync` | Google Drive sync engine, three-way Markdown merge, conflict-copy naming `Note (conflict YYYY-MM-DD HH-mm DeviceName).md`, history, backups (§7.6) |
| App | Reading view renderer (AST → widgets), Source + Live Preview editor behind the app-side `EditorController`, open-document/autosave layer, command registry + palette (§7.8), properties editor using `yaml_edit`, daily notes + templates service, rename/move service that updates links, vault settings (`.tephra/settings.json`), app settings (`<appSupportDir>/settings.json` with device id + device name), sync status UI, possibly a Windows tray icon from Phase 3.4 |

### Discovery task (do this first, before step 04.1; no code changes)

The earlier phase files fixed the *contracts* but not every app-internal class name. Find the real names now and write them into
`PROGRESS.md` under a heading `### Phase 4 — discovered APIs`, one line each. Use the Grep tool (or `git grep`) on `app/lib` and `packages`:

| What to find | Search for | Write down |
|---|---|---|
| Vault file system provider for the open vault | `Provider<VaultFileSystem` | provider name + file |
| `NoteIndex` provider | `Provider<NoteIndex` or `NoteIndex.open` | provider name + file |
| `SearchEngine` provider | `SearchEngine(` | provider name + file |
| Vault settings model + provider | `settings.json` in `app/lib` | class name, provider, how a new key is added |
| App settings model (device id, device name) | `deviceId` | class name, provider |
| Open-document registry / autosave layer (the thing the editor saves through) | `autosave`, `class .*Document`, `EditorController` | class names; the method to get the current text of an open note; the method to replace it from outside |
| Rename/move service that updates links | `rename`, `updateLinks` | class + method signature |
| Daily notes service (path for "today", create from template) | `daily` | class + methods |
| Attachment saving service (§6.7 naming) | `Pasted image` | class + method |
| Phase 3 three-way merge function | `merge3`, `threeWay`, `diff_match_patch` in `packages/tephra_sync` | function signature + return type |
| Conflict-copy name function | `conflict` in `packages/tephra_sync` | function signature |
| Sync "cycle finished" event | `SyncStatus`, `Stream<Sync` | stream/provider name |
| Existing platform services | files in `app/lib/core/platform/` | which of the §5.9 interfaces exist already (Phase 3 may have created `TrayService`, `WindowService`, `NotificationService`) |
| How properties `[key:value]` are matched for booleans | `[prop` in `packages/tephra_search` | whether `[tephra-sticky:true]` matches a YAML boolean `true` |

Everywhere this file says "the open-document layer", "the rename service", "the daily notes service", "the merge function",
"the vault fs provider" (and so on), use the real names you wrote down. If any of these does not exist, stop and tell the human —
do not build a second copy of a Phase 1–3 feature.

---

## What exists when done

- Any note can be a sticky through the frontmatter keys of conventions §6.5; stickies live in `Stickies/` by default.
- Commands `sticky.new`, `sticky.pin-note`, `sticky.unpin`, `sticky.set-color`, `sticky.lock`, `sticky.set-reminder`,
  `sticky.set-expiry`, `sticky.open-window`, `sticky.show-all`, `sticky.hide-all`, `sticky.board`, `capture.quick-note`.
- A sticky board screen on both platforms, backed by `Stickies/Sticky board.canvas` (JSON Canvas 1.0) that Obsidian opens.
- Windows: frameless floating sticky windows (one Flutter engine each), main window as the single writer, always-on-top, collapse,
  colour menu, per-monitor positions in `.tephra/stickies.json`, restore at start, optional start with Windows, `Ctrl+Alt+N` global hotkey,
  tray menu (New sticky, Show all, Hide all, Open Tephra, Quit).
- Android: single-sticky widget (with tappable checkboxes), sticky-stack widget, quick-capture widget, floating sticky bubble,
  Quick Settings tile, optional persistent "Quick note" notification with inline reply, share-to-Tephra, app shortcuts.
- Reminder notifications for `sticky-remind` on both platforms (exact alarms on Android, toasts on Windows), DST-correct.
- Expired stickies auto-archive to `Stickies/Archive/`.
- Tag `v0.04.0`.

---

## Dependencies

Add each with `flutter pub add <name>` from `app/` (they are app-only; none goes into `packages/`). After adding, run
`dart run tool/check_licenses.dart` and confirm it passes. **Before writing code against any package, open its README in the pub cache
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<name>-<version>\README.md`) and check the current API** — the signatures below were checked on
2026-10-11 and may have moved. If the README differs from this file, follow the README and note the difference in `PROGRESS.md`.

| Package | Checked version | Licence | Platforms used | Purpose |
|---|---|---|---|---|
| `desktop_multi_window` | 0.3.1 | Apache-2.0 (LICENSE file; README says MIT — both allowed) | Windows | one Flutter engine per sticky window, `WindowController`, `WindowMethodChannel` |
| `window_manager` | latest (or the version already in the app) | MIT | Windows | frameless, always-on-top, bounds, drag, resize |
| `screen_retriever` | 0.3.0 | MIT | Windows | monitor list + work areas |
| `hotkey_manager` | 0.2.3 | MIT | Windows | system-wide `Ctrl+Alt+N` |
| `tray_manager` | 0.8.0 (or the version Phase 3 added) | MIT | Windows | tray icon + menu |
| `win32_registry` | 3.0.3 | BSD-3-Clause | Windows | "Start with Windows" (HKCU Run key) |
| `home_widget` | 0.10.0 | BSD-3-Clause | Android | widget data + updates + interactivity callback |
| `flutter_overlay_window` | 0.5.0 | MIT | Android | floating sticky bubble |
| `flutter_local_notifications` | 22.3.1 | BSD-3-Clause | Android + Windows | reminders, persistent quick-note notification |
| `timezone` | latest | BSD-2-Clause | both | `TZDateTime`, tz database |
| `flutter_timezone` | 5.1.1 | Apache-2.0 | both | local IANA zone name |
| `receive_sharing_intent` | 1.9.0 | Apache-2.0 | Android | share-to-Tephra |
| `quick_actions` | latest | BSD-3-Clause | Android | launcher app shortcuts |
| `app_links` | 7.2.2 | Apache-2.0 | Android | receive `tephra://` deep links (tile, shortcuts) |
| `yaml_edit`, `yaml` | already present | BSD-3-Clause | both | frontmatter edits |

Decisions taken here (do not revisit):
- **`window_manager` in sub-windows:** `desktop_multi_window`'s README recommends a fork of `window_manager`
  (`git: url: https://github.com/boyan01/window_manager.git, path: packages/window_manager, ref: 6fae92d21b4c80ce1b8f71c1190d7970cf722bd4`, MIT).
  Use the pub.dev `window_manager` first. Only if the multi-window check in step 04.8 fails (calls in a sticky window throw
  `MissingPluginException` or move the main window instead), switch to that fork as a `dependency_overrides` entry in the root `pubspec.yaml`,
  make sure `tool/check_licenses.dart` handles git dependencies (it must read the LICENSE file from the git cache), and record it in `PROGRESS.md`.
- **Start with Windows** uses `win32_registry` directly (not `launch_at_startup`), because we need a command-line argument (`--autostart`)
  and full control over the value.
- **No `permission_handler`:** notification, exact-alarm and overlay permissions are requested through `flutter_local_notifications` and
  `flutter_overlay_window`, which already expose them.
- **No home-widget configuration activity:** a new single-sticky widget shows "Tap to choose a sticky", which opens the app's picker.

---

## Steps

Every step ends with the standard checks from `GEMINI.md` §3 (format, analyze, tests of touched packages), a tick in `PROGRESS.md`,
and a commit `phase 04.S: <summary>`. The "Verify" blocks list only the step-specific extra checks.

Shared names used by many steps (create them where the step says, then reuse — never duplicate):

| Name | File | Created in |
|---|---|---|
| `StickyColor` | `app/lib/stickies/model/sticky_color.dart` | 04.2 |
| `StickyMeta` | `app/lib/stickies/model/sticky_meta.dart` | 04.2 |
| `StickyPatch`, `applyStickyPatch` | `app/lib/stickies/model/sticky_frontmatter.dart` | 04.2 |
| `toggleTaskAtLine` | `app/lib/stickies/model/task_toggle.dart` | 04.2 |
| `Sticky` (path + meta + text + hash) | `app/lib/stickies/model/sticky.dart` | 04.3 |
| `StickyRepository` | `app/lib/stickies/data/sticky_repository.dart` | 04.3 |
| `StickyFileWriter` | `app/lib/stickies/data/sticky_file_writer.dart` | 04.3 |
| `HeadlessConfig` | `app/lib/core/headless_config.dart` | 04.12 |
| `DeepLink`, `DeepLinkRouter` | `app/lib/core/deep_links/` | 04.12 |

---

### 04.1 — Dependencies, settings keys and platform-service skeletons

**Purpose.** Add every Phase 4 package once, define the new settings, and create the platform-service interfaces with no-op implementations so later steps only fill them in.

**Files.**
- `app/pubspec.yaml` (dependencies)
- the vault settings model found in the discovery task (add fields)
- the app settings model found in the discovery task (add fields)
- `app/lib/core/platform/notification_service.dart` (create or extend)
- `app/lib/core/platform/global_hotkey_service.dart`
- `app/lib/core/platform/tray_service.dart` (create or extend)
- `app/lib/core/platform/window_service.dart` (create or extend)
- `app/lib/core/platform/home_widget_service.dart`
- `app/lib/core/platform/overlay_service.dart`
- `app/lib/core/platform/share_intent_service.dart` (new interface, see "Conventions gaps" in the hand-off)
- `app/lib/core/platform/app_shortcut_service.dart` (new interface)
- `app/lib/core/providers.dart` (providers selecting implementations)
- `app/lib/l10n/app_en.arb`
- `app/test/core/platform/platform_providers_test.dart`

**Implementation.**
1. Add the packages from the Dependencies table (`flutter pub add desktop_multi_window window_manager screen_retriever hotkey_manager tray_manager win32_registry home_widget flutter_overlay_window flutter_local_notifications timezone flutter_timezone receive_sharing_intent quick_actions app_links`). Skip any already present. Run `flutter pub get` at the repo root, then `dart run tool/check_licenses.dart`.
2. Vault settings (stored in `.tephra/settings.json`, synced, shared by all devices). Add these fields with these JSON keys and defaults:
   | Field | JSON key | Type | Default |
   |---|---|---|---|
   | `stickyFolder` | `stickies.folder` | String (vault-relative folder) | `"Stickies"` |
   | `stickyDefaultColor` | `stickies.defaultColor` | String | `"yellow"` |
   | `shareTarget` | `capture.shareTarget` | `"newNote"` \| `"dailyNote"` | `"dailyNote"` |
   | `quickCaptureTarget` | `capture.quickTarget` | `"dailyNote"` \| `"inbox"` | `"dailyNote"` |
   | `inboxNotePath` | `capture.inboxPath` | String (vault path) | `"Inbox.md"` |
   Unknown keys in the file must still be preserved when settings are written (they already are if Phase 1 followed conventions; check it).
3. App settings (stored in `<appSupportDir>/settings.json`, per device, never synced). Add:
   | Field | JSON key | Type | Default |
   |---|---|---|---|
   | `stickiesRestoreOnStart` | `stickies.restoreOnStart` | bool | `true` |
   | `stickiesHiddenAll` | `stickies.hiddenAll` | bool | `false` |
   | `stickiesMaxWindows` | `stickies.maxWindows` | int | `20` |
   | `stickyHotkey` | `stickies.hotkey` | String | `"Ctrl+Alt+N"` |
   | `startWithWindows` | `app.startWithWindows` | bool | `false` |
   | `keepRunningInTray` | `app.keepRunningInTray` | bool | `true` (keep Phase 3's key if it already exists) |
   | `quickNoteNotification` | `capture.persistentNotification` | bool | `false` |
   | `remindersEnabled` | `reminders.enabled` | bool | `true` |
4. Platform-service interfaces (conventions §5.9). Each file has an `abstract interface class`, a `Noop…` implementation, and the real implementation stub (methods throw `UnimplementedError` until their step). Signatures:
   ```dart
   abstract interface class NotificationService {
     Future<void> init();                                    // idempotent
     Future<NotificationPermissionState> permissionState();  // notifications + exact alarms
     Future<bool> requestNotificationPermission();           // Android 13+ POST_NOTIFICATIONS; true elsewhere
     Future<bool> requestExactAlarmPermission();             // Android 12+ SCHEDULE_EXACT_ALARM; true elsewhere
     Future<void> schedule(ScheduledReminder reminder);      // replaces any with the same id
     Future<void> cancel(int id);
     Future<void> showQuickNoteNotification();               // Android persistent notification (no-op on Windows)
     Future<void> hideQuickNoteNotification();
     Stream<String> get taps;                                // payload strings of tapped notifications (app running)
     Future<String?> launchPayload();                        // payload that launched the app, or null
   }
   final class NotificationPermissionState {
     const NotificationPermissionState({required this.notifications, required this.exactAlarms});
     final bool notifications; final bool exactAlarms;
   }
   final class ScheduledReminder {
     const ScheduledReminder({required this.id, required this.at, required this.title, required this.body, required this.payload});
     final int id; final DateTime at /* UTC instant */; final String title; final String body; final String payload;
   }

   abstract interface class GlobalHotkeyService {
     Future<void> register(String accelerator, void Function() onPressed);   // accelerator like 'Ctrl+Alt+N'
     Future<void> unregisterAll();
   }

   enum TrayAction { newSticky, showAllStickies, hideAllStickies, openTephra, quit }
   abstract interface class TrayService {
     Future<void> init({required String tooltip});
     Future<void> setMenu(List<TrayAction> actions);
     Stream<TrayAction> get actions;
     Future<void> dispose();
   }

   abstract interface class WindowService {
     Future<void> showMainWindow();      // show + focus, restore if minimised
     Future<void> hideMainWindow();      // hide to tray
     Future<bool> isLaunchAtStartupEnabled();
     Future<void> setLaunchAtStartup(bool enabled);
   }

   abstract interface class HomeWidgetService {
     Future<void> saveJson(String key, Map<String, Object?> json);
     Future<Map<String, Object?>?> readJson(String key);
     Future<void> updateStickyWidgets();       // asks Android to redraw the single-sticky widgets
     Future<void> updateStackWidgets();
     Future<void> updateCaptureWidgets();
     Future<List<int>> installedStickyWidgetIds();
     Stream<Uri> get widgetLaunches;           // URIs from widget taps that opened/resumed the app
     Future<Uri?> initialWidgetLaunch();
   }

   abstract interface class OverlayService {
     Future<bool> hasPermission();
     Future<bool> requestPermission();
     Future<void> showBubble(String stickyPath);
     Future<void> closeBubble();
     Future<bool> isActive();
     Future<void> send(Map<String, Object?> message);    // to the overlay engine (JSON)
     Stream<Map<String, Object?>> get messages;          // from the overlay engine
   }

   abstract interface class ShareIntentService {
     Future<List<SharedItem>> initialShare();             // share that launched the app
     Stream<List<SharedItem>> get shares;                 // shares while running
     Future<void> markHandled();
   }
   sealed class SharedItem { const SharedItem(); }
   final class SharedText extends SharedItem { const SharedText(this.text); final String text; }
   final class SharedFile extends SharedItem { const SharedFile({required this.path, required this.mimeType}); final String path; final String? mimeType; }

   abstract interface class AppShortcutService {
     Future<void> init(void Function(String shortcutId) onShortcut);   // ids: 'new-note', 'daily', 'new-sticky'
   }
   ```
5. In `app/lib/core/providers.dart` add one `Provider` per service. Selection rule (the only place with platform checks):
   `Platform.isWindows` → Windows implementation for `NotificationService`, `GlobalHotkeyService`, `TrayService`, `WindowService`; Noop for the rest.
   `Platform.isAndroid` → Android implementation for `NotificationService`, `HomeWidgetService`, `OverlayService`, `ShareIntentService`, `AppShortcutService`; Noop for the rest.
   `kIsWeb` (dev preview) → all Noop. Check `kIsWeb` **before** touching `Platform` (it throws on web).
6. Add l10n keys now for every user string named in this file's steps as you reach them; at minimum in this step:
   `stickyCommandNew`, `stickyCommandPinNote`, `stickyCommandUnpin`, `stickyCommandSetColor`, `stickyCommandLock`, `stickyCommandSetReminder`,
   `stickyCommandSetExpiry`, `stickyCommandOpenWindow`, `stickyCommandShowAll`, `stickyCommandHideAll`, `stickyCommandBoard`, `captureCommandQuickNote`,
   `stickyColorYellow`, `stickyColorPink`, `stickyColorBlue`, `stickyColorGreen`, `stickyColorPurple`, `stickyColorGray`, `stickyColorCustom`.

**Tests.** `platform_providers_test.dart`:
- `noop services never throw` — call every method of every `Noop…` service; expect no exception and empty/false results.
- `settings defaults` — decode an empty settings JSON `{}` with the vault and app settings models; expect every default in the tables above.
- `settings preserve unknown keys` — decode `{"x.unknown": 5, "stickies.folder": "Notes/Sticky"}`, re-encode, expect `x.unknown` still `5` and folder `Notes/Sticky`.

**Verify.**
```powershell
dart run tool/check_licenses.dart
cd app; flutter test test/core/platform/platform_providers_test.dart; cd ..
cd app; flutter build windows --debug; cd ..
cd app; flutter build apk --debug; cd ..
```
Success: licence check passes; tests pass; both builds succeed (plugins compile on both platforms even though unused).

**Pitfalls.**
- `flutter_local_notifications` on Android needs core library desugaring. Follow its README "Gradle setup" section exactly
  (`isCoreLibraryDesugaringEnabled = true` in `compileOptions` and the `coreLibraryDesugaring(...)` dependency in `app/android/app/build.gradle.kts`).
- `desktop_multi_window` and `hotkey_manager` add Windows-only native code; the Android build must still succeed. If a package breaks the
  Android build, stop and report — do not remove it silently.
- Do not call any real plugin method in this step.

---

### 04.2 — Sticky model and frontmatter patching (round-trip safe)

**Purpose.** Parse and write the six sticky keys of conventions §6.5 without changing a single byte of the note body or of untouched YAML.

**Files.**
- `app/lib/stickies/model/sticky_color.dart`
- `app/lib/stickies/model/sticky_meta.dart`
- `app/lib/stickies/model/sticky_frontmatter.dart`
- `app/lib/stickies/model/task_toggle.dart`
- `app/test/stickies/model/sticky_color_test.dart`
- `app/test/stickies/model/sticky_meta_test.dart`
- `app/test/stickies/model/sticky_frontmatter_test.dart`
- `app/test/stickies/model/task_toggle_test.dart`

**Implementation.**
1. `StickyColor` — sealed:
   ```dart
   sealed class StickyColor { const StickyColor(); 
     static StickyColor parse(Object? raw);   // never throws; invalid → StickyColor.fallback (yellow)
     String get yamlValue;                    // 'yellow' … or '#RRGGBB' (upper-case hex)
     int get argb;                            // card background, 0xFFRRGGBB
     int get textArgb;                        // 0xFF1F1F1F if luminance(argb) > 0.45, else 0xFFFFFFFF
     static const StickyColor fallback = NamedStickyColor.yellow; }
   enum StickyColorName { yellow, pink, blue, green, purple, gray }
   final class NamedStickyColor extends StickyColor { ... final StickyColorName name; static const yellow = NamedStickyColor(StickyColorName.yellow); }
   final class HexStickyColor extends StickyColor { ... final int rgb; }
   ```
   Fixed ARGB values (light card colours, use exactly these):
   | Name | argb |
   |---|---|
   | yellow | `0xFFFFF3A3` |
   | pink | `0xFFFFC7DD` |
   | blue | `0xFFBFE3FF` |
   | green | `0xFFC8F2C2` |
   | purple | `0xFFE0CCFF` |
   | gray | `0xFFE3E3E3` |
   Parsing rules: trim; lower-case names match; `#RGB` is expanded to `#RRGGBB`; `#RRGGBB` (any case) accepted; anything else → fallback.
   Luminance = relative luminance per WCAG (sRGB linearisation) of the RGB part.
2. `StickyMeta` — immutable value with `copyWith`, `==`, `hashCode`:
   ```dart
   final class StickyMeta {
     const StickyMeta({required this.isSticky, this.color = StickyColor.fallback, this.pinned = false,
       this.remind, this.expire, this.locked = false});
     final bool isSticky; final StickyColor color; final bool pinned;
     final LocalDateTime? remind;   // wall-clock, no zone
     final LocalDate? expire;
     final bool locked;
     static StickyMeta fromFrontmatter(Map<String, Object?> fm);   // never throws
   }
   final class LocalDateTime { const LocalDateTime(this.year, this.month, this.day, this.hour, this.minute); ...
     static LocalDateTime? tryParse(String s); String format(); }     // format() → 'YYYY-MM-DDTHH:mm'
   final class LocalDate { const LocalDate(this.year, this.month, this.day); ... static LocalDate? tryParse(String s); String format(); }
   ```
   Parsing rules for `fromFrontmatter`:
   - `isSticky`: `true` if `tephra-sticky` is the bool `true` or a string equal (case-insensitive, trimmed) to `true`/`yes`. Otherwise `false`.
   - `color`: `StickyColor.parse(fm['sticky-color'])`; missing → fallback.
   - `pinned`, `locked`: same truthiness rule as `isSticky`.
   - `remind`: accept a string in `YYYY-MM-DDTHH:mm`, `YYYY-MM-DDTHH:mm:ss`, `YYYY-MM-DD HH:mm` (seconds are dropped); a `DateTime` object (if the YAML library produced one) → its local fields. Invalid → `null` and a `Logger('stickies.model').warning` without the note text.
   - `expire`: `YYYY-MM-DD` string or a `DateTime`; invalid → `null`.
   - Validate ranges (month 1–12, day valid for month incl. leap years, hour 0–23, minute 0–59).
3. `StickyPatch` + `applyStickyPatch` — a patch lists only the keys to change:
   ```dart
   final class StickyPatch {
     const StickyPatch({this.sticky, this.color, this.pinned, this.remind, this.expire, this.locked, this.removeAll = false});
     final bool? sticky;                       // true → set 'tephra-sticky: true'; false → remove key
     final StickyColor? color;                 // set
     final bool? pinned; final bool? locked;   // true → set true; false → REMOVE the key (defaults are not written)
     final Optional<LocalDateTime>? remind;    // Optional.of(x) → set; Optional.none() → remove; null → untouched
     final Optional<LocalDate>? expire;
     final bool removeAll;                     // remove all six keys (unpin); other fields ignored
   }
   final class Optional<T> { const Optional.of(T this.value) : isPresent = true; const Optional.none() : value = null, isPresent = false; final T? value; final bool isPresent; }
   String applyStickyPatch(String noteText, StickyPatch patch);
   ```
   Algorithm (text is the in-memory `\n`-normalised text; the caller writes it back through `TextDocument` so BOM/CRLF are re-applied):
   1. `final parsed = MarkdownParser.parse(noteText);` Find the `MdFrontmatter` node (first child of the document, if any).
   2. **No frontmatter and the patch only removes keys** → return `noteText` unchanged (identical `String`).
   3. **No frontmatter and the patch sets keys** → build `yaml` text yourself, one line per set key in this fixed order:
      `tephra-sticky`, `sticky-color`, `sticky-pinned`, `sticky-remind`, `sticky-expire`, `sticky-locked`. Return
      `'---\n' + yaml + '---\n' + noteText`. Value formatting: bools `true`; colour names plain (`yellow`); hex colours single-quoted (`'#FFAA00'`,
      because `#` would start a YAML comment); `sticky-remind: 2026-10-12T09:00` and `sticky-expire: 2026-10-20` plain.
   4. **Frontmatter exists** → `final yamlText = frontmatter.yaml;` (the text between the `---` lines, ending with `\n` unless empty).
      Create `YamlEditor(yamlText)`. If the YAML root is not a map (invalid/empty YAML that is not `{}`): if `yamlText.trim().isEmpty`,
      treat like step 3 but keep the original delimiter lines; otherwise throw `ParseException('frontmatter is not a map')` — the caller shows
      "This note's properties can't be edited automatically" and changes nothing.
      For each key in the fixed order: set → `editor.update([key], value)` (use the same formatting rules: pass a `String` for colours and dates;
      for hex colours use `editor.update` and then check the produced text contains `'#` quoting — `yaml_edit` quotes it itself; the test asserts it);
      remove → if the key exists `editor.remove([key])`.
   5. New yaml = `editor.toString()`. If the new yaml equals `yamlText` → return `noteText` unchanged.
   6. If the new yaml is empty or only whitespace **and** `removeAll`/removals emptied it → remove the whole frontmatter block:
      return `noteText.substring(frontmatter.contentStart)`. (This makes "pin then unpin" of a note that had no frontmatter byte-identical.)
   7. Otherwise splice: `noteText.substring(0, yamlStart) + newYaml + noteText.substring(yamlEnd)` where `yamlStart`/`yamlEnd` are the offsets of
      the YAML text inside the delimiters. Take them from the parser node (`MdFrontmatter.start` + length of the first `---\n` line, and
      `contentStart` − length of the closing `---\n` line). The body (`noteText.substring(frontmatter.contentStart)`) must be copied, never rebuilt.
   8. Make sure the new yaml ends with `\n` before the closing `---`.
4. `toggleTaskAtLine` (used by widgets, board, overlay, sticky windows):
   ```dart
   /// Toggles the task checkbox on 0-based [line] of [text]. Returns null if that line is not a task line.
   String? toggleTaskAtLine(String text, int line);
   ```
   A task line matches `^(\s*(?:[-*+]|\d+[.)])\s+)\[([^\]])\](.*)$`. Status ` ` → `x`; any other single char → ` `. Only the one character
   inside the brackets changes; every other character of the text is preserved.

**Tests.**
- `sticky_color_test.dart`: `parses names case-insensitively` (`'Pink'` → pink); `expands #abc` (`'#abc'` → yamlValue `'#AABBCC'`); `invalid falls back` (`'teal'`, `42`, `null` → yellow);
  `text colour contrast` (yellow → `0xFF1F1F1F`, `#000080` → `0xFFFFFFFF`).
- `sticky_meta_test.dart`: `full keys` (all six keys set → every field), `string booleans` (`'TRUE'`, `'yes'`), `remind formats` (three accepted formats, `2026-02-30T10:00` → null),
  `DateTime values` (map containing `DateTime(2026,10,12,9,0)` → remind 2026-10-12T09:00), `missing keys → defaults`.
- `sticky_frontmatter_test.dart` (the round-trip tests — use exact strings and compare with `equals`):
  - `adds frontmatter to a plain note`: `'Call the printer guy\n- [ ] toner\n'` + patch(sticky: true, color: yellow) →
    `'---\ntephra-sticky: true\nsticky-color: yellow\n---\nCall the printer guy\n- [ ] toner\n'`.
  - `pin then unpin restores plain note exactly`: apply set patch, then `removeAll` → identical to the original string.
  - `existing frontmatter keeps formatting`: original `'---\ntitle:   "My  note"   # keep\ntags: [a, b]\n---\nBody **x**\n'`;
    set sticky + pink → `title` line and `tags` line unchanged byte-for-byte, two new lines appended inside the block, body unchanged;
    then `removeAll` → identical to the original.
  - `hex colour is quoted`: set `#ffaa00` → frontmatter contains `sticky-color: '#FFAA00'` (or `"#FFAA00"` — accept either quote style, assert the value re-parses to `#FFAA00`).
  - `remind set and cleared`: set → `sticky-remind: 2026-10-12T09:00`; `Optional.none()` → key gone, rest identical.
  - `pinned false removes the key`.
  - `no-op patch returns identical string` (`identical(result, input)` is `true`).
  - `CRLF + BOM file round trip`: build bytes with BOM + `\r\n`, decode with `TextDocument.decode`, patch + unpatch, `encode()` → bytes identical to the input bytes.
  - `body bytes untouched` (property-style): for 50 generated bodies (seeded `Random(4)`: unicode, `---` lines inside the body, code fences, empty body),
    `applyStickyPatch(text, set).substring(newContentStart) == originalBody`.
  - `non-map frontmatter throws ParseException` (`'---\n- a\n- b\n---\nx'`).
- `task_toggle_test.dart`: `toggles [ ] to [x]`, `toggles [/] to [ ]`, `ordered list task`, `non-task line returns null`, `line out of range returns null`, `other lines unchanged`.

**Verify.**
```powershell
cd app; flutter test test/stickies/model; cd ..
```
Success: all tests pass.

**Pitfalls.**
- Never re-serialise the whole frontmatter with `yaml`/`json`; only `yaml_edit` edits or the step-3 builder.
- `yaml_edit` may throw on unusual YAML (flow maps with comments, anchors). Catch `YamlException`/`ArgumentError` and rethrow as `ParseException`.
- Do not trim or normalise the body. Do not add a trailing newline to the body.

---

### 04.3 — Sticky repository: listing, creating, updating, archiving folder rules

**Purpose.** One app service that knows every sticky in the open vault, creates stickies, applies patches, and emits change events. Everything else (board, windows, widgets, reminders) reads from it.

**Files.**
- `app/lib/stickies/model/sticky.dart`
- `app/lib/stickies/model/sticky_naming.dart`
- `app/lib/stickies/data/sticky_repository.dart`
- `app/lib/stickies/data/sticky_file_writer.dart`
- `app/lib/stickies/providers.dart`
- `app/test/stickies/data/sticky_repository_test.dart`
- `app/test/stickies/model/sticky_naming_test.dart`
- `app/test/stickies/data/sticky_file_writer_test.dart`

**Implementation.**
1. `Sticky`:
   ```dart
   final class Sticky {
     const Sticky({required this.path, required this.meta, required this.text, required this.hash, required this.modified});
     final VaultPath path; final StickyMeta meta;
     final String text;      // full in-memory note text ('\n'-normalised)
     final String hash;      // contentHash of the file bytes as read
     final DateTime modified;
     String get title;       // path.stem
     String get body;        // text after frontmatter (uses MarkdownParser)
     List<String> get tags;  // ParsedNote.tags
   }
   ```
2. `sticky_naming.dart`:
   ```dart
   /// 'Sticky 2026-10-11 093005.md' in [folder]; adds ' 1', ' 2', … before '.md' if taken (case-insensitive).
   VaultPath newStickyPath(VaultPath folder, DateTime localNow, bool Function(VaultPath) exists);
   ```
   Format: `Sticky YYYY-MM-DD HHmmss.md`, zero-padded, 24-hour, local time from the injected `Clock`.
3. `StickyFileWriter` — the one place that writes a sticky when the caller is **not** the main app's open-document layer
   (headless widget callback, overlay fallback, notification reply):
   ```dart
   final class StickyFileWriter {
     StickyFileWriter(this.fs);
     final VaultFileSystem fs;
     /// Writes [newText] only if the file's current contentHash equals [expectedHash]. Returns the new hash, or null if the
     /// file changed meanwhile (nothing written). Preserves BOM and line ending of the current file.
     Future<String?> writeIfUnchanged(VaultPath path, String expectedHash, String newText);
     /// Appends [block] to the end of the note (adds '\n' first if the note does not end with '\n'); creates the note if missing.
     Future<void> append(VaultPath path, String block);
   }
   ```
4. `StickyRepository` (one instance per open vault, owned by a provider; `dispose()` cancels subscriptions):
   ```dart
   final class StickyRepository {
     StickyRepository({required VaultFileSystem fs, required SearchEngine search, required StickySettingsView settings,
       required OpenNoteBridge openNotes, required Clock clock});
     Future<void> start();                                  // initial load + subscribe to fs.watch()
     List<Sticky> get all;                                  // active stickies (not under '<folder>/Archive/'), sorted by modified desc
     List<Sticky> get archived;
     Sticky? byPath(VaultPath path);
     Stream<StickyChange> get changes;                      // broadcast
     Future<Sticky> create({String body = '', StickyColor? color});   // in settings.stickyFolder
     Future<void> patch(VaultPath path, StickyPatch patch);           // pin/unpin/colour/lock/remind/expire
     Future<void> setText(VaultPath path, String newText);           // through the open-document layer if open, else atomic write
     Future<void> refresh(VaultPath path);                           // re-read one file
     Future<void> dispose();
   }
   sealed class StickyChange { const StickyChange(this.path); final VaultPath path; }
   final class StickyAdded extends StickyChange { ... }  final class StickyUpdated extends StickyChange { ... }
   final class StickyRemoved extends StickyChange { ... }   // deleted, unpinned, or moved to Archive
   final class StickyMoved extends StickyChange { const StickyMoved(super.path, this.from); final VaultPath from; }
   ```
   `OpenNoteBridge` (in `app/lib/stickies/data/open_note_bridge.dart`) wraps the open-document layer found in the discovery task:
   ```dart
   abstract interface class OpenNoteBridge {
     String? openText(VaultPath path);                       // current in-memory text if the note is open in any tab, else null
     Future<void> applyText(VaultPath path, String text);    // replaces the open document's text (undoable) and lets autosave write it
     Stream<VaultPath> get edited;                           // emits (debounced 300 ms) when an open note's text changes from typing
   }
   ```
   Implement `AppOpenNoteBridge` over the real layer in this step and a `FakeOpenNoteBridge` in `app/test/stickies/fakes.dart`.
5. Listing algorithm (`start()` and on every relevant watch event):
   1. Run `search.run(SearchParser.parse('[tephra-sticky:true]'))` and collect paths. If the discovery task showed that a YAML boolean does not
      match `true`, use the query string that does (for example `[tephra-sticky]` plus the `StickyMeta` filter below) and note it in `PROGRESS.md`.
   2. For each path, read the file (`fs.readBytes`, decode with `TextDocument.decode`), parse, build `StickyMeta.fromFrontmatter`; keep only
      `meta.isSticky == true` (the search is a candidate filter, `StickyMeta` is the truth).
   3. Classify: path inside `<stickyFolder>/Archive/` → `archived`; else `all`.
   4. Incremental updates: on `FileCreated`/`FileModified` of a `.md` file → re-read that file only and emit Added/Updated/Removed by comparing with
      the previous state; on `FileDeleted` → Removed; on `FileMoved` → Moved (or Removed if it moved into Archive).
   5. The watch stream excludes the app's own writes (conventions §7.2), so after every write the repository performs (`create`, `patch`, `setText`)
      it calls `refresh(path)` itself.
6. `create`: compute `newStickyPath(folder, clock.now(), exists)`, text = `applyStickyPatch(body, StickyPatch(sticky: true, color: color ?? defaultColor))`,
   `fs.writeText(path, TextDocument(text: text))`, `refresh(path)`, return the sticky. The folder is created by `writeText` (atomic writes create parents).
7. `patch`: read current text (prefer `openNotes.openText(path)`, else from disk); `newText = applyStickyPatch(current, patch)`; if unchanged do nothing;
   otherwise `setText`.
8. `setText`: if `openNotes.openText(path) != null` → `openNotes.applyText(path, newText)` (the editor's autosave writes it, so the editor never sees
   a stale buffer); else `fs.writeText(path, TextDocument(text: newText, hasBom: old.hasBom, lineEnding: old.lineEnding))`. Then `refresh(path)`.
9. `stickiesProvider` = `NotifierProvider<StickiesNotifier, StickiesState>` exposing `all`, `archived`, and `byColor`/`byTag` getters; it listens to
   `repository.changes`. `stickyRepositoryProvider` = `Provider<StickyRepository>` that is recreated when the vault changes.

**Tests.** Use `MemoryVaultFileSystem`, a `FakeSearchEngine` (returns paths whose text contains `tephra-sticky: true`), `FakeOpenNoteBridge`, a fixed `Clock` (2026-10-11 09:30:05).
- `sticky_naming_test.dart`: `basic name` → `Stickies/Sticky 2026-10-11 093005.md`; `collision adds suffix 1 then 2`; `case-insensitive collision`.
- `sticky_repository_test.dart`:
  - `loads only real stickies` — three notes: one sticky, one with `tephra-sticky: false`, one normal → `all.length == 1`.
  - `archive folder is separate` — sticky in `Stickies/Archive/` → `archived.length == 1`, `all` empty.
  - `create writes file and emits StickyAdded` — expect file text `'---\ntephra-sticky: true\nsticky-color: yellow\n---\n'` and one `StickyAdded`.
  - `patch colour through open document` — note open in `FakeOpenNoteBridge` → `applyText` called once, file on disk not written by the repository.
  - `patch on closed note writes file`.
  - `unpin emits StickyRemoved and keeps body` — body bytes identical.
  - `external edit emits StickyUpdated` — modify file via a second handle + push a `FileModified` event.
  - `deleted file emits StickyRemoved`.
- `sticky_file_writer_test.dart`: `writes when hash matches`, `returns null and writes nothing when hash differs`, `append adds newline when missing`, `append creates missing note`, `CRLF preserved`.

**Verify.**
```powershell
cd app; flutter test test/stickies; cd ..
```

**Pitfalls.**
- Do not query the drift database directly from the app; go through `SearchEngine` (contract §7.5) — the index schema is internal to `tephra_index`.
- Reading every sticky file on start is fine (expect < 500 stickies); do it with `Future.wait` in batches of 32, not all at once.
- Never log note text.

---

### 04.4 — Sticky commands and editor integration

**Purpose.** Every sticky action is a command (conventions §7.8) available in the palette, plus a small sticky banner in the editor and lock = read-only.

**Files.**
- `app/lib/stickies/commands/sticky_commands.dart`
- `app/lib/stickies/ui/sticky_color_picker.dart`
- `app/lib/stickies/ui/sticky_reminder_dialog.dart`
- `app/lib/stickies/ui/sticky_expiry_dialog.dart`
- `app/lib/stickies/ui/sticky_note_banner.dart`
- the editor host widget found in the discovery task (insert banner + read-only flag)
- `app/lib/l10n/app_en.arb`
- `app/test/stickies/commands/sticky_commands_test.dart`
- `app/test/stickies/ui/sticky_color_picker_test.dart`

**Implementation.**
1. Register these commands at app start (same place other features register theirs):
   | id | Label key | Default shortcut (Windows) | Available when | Action |
   |---|---|---|---|---|
   | `sticky.new` | `stickyCommandNew` | `Ctrl+Shift+N` only if free (check the registry for conflicts; if taken, none) | vault open | `repository.create()`; on desktop layout open it in a floating window (Windows) — otherwise open it in the editor |
   | `sticky.pin-note` | `stickyCommandPinNote` | none | active note is Markdown and not a sticky | `patch(StickyPatch(sticky: true, color: defaultColor))` — the note stays where it is |
   | `sticky.unpin` | `stickyCommandUnpin` | none | active note is a sticky | `patch(StickyPatch(removeAll: true))`; closes its floating window/bubble |
   | `sticky.set-color` | `stickyCommandSetColor` | none | active note is a sticky | show `StickyColorPicker`; `patch(color: picked)` |
   | `sticky.lock` | `stickyCommandLock` | none | active note is a sticky | toggle: `patch(locked: !meta.locked)` |
   | `sticky.set-reminder` | `stickyCommandSetReminder` | none | active note is a sticky | `StickyReminderDialog` → `patch(remind: …)` |
   | `sticky.set-expiry` | `stickyCommandSetExpiry` | none | active note is a sticky | `StickyExpiryDialog` → `patch(expire: …)` |
   | `sticky.open-window` | `stickyCommandOpenWindow` | none | active note is a sticky, and Windows or Android | Windows: `StickyHub.open(path)` (04.9); Android: `OverlayService.showBubble(path)` (04.14) |
   | `sticky.show-all` | `stickyCommandShowAll` | none | Windows only | `StickyHub.showAll()` |
   | `sticky.hide-all` | `stickyCommandHideAll` | none | Windows only | `StickyHub.hideAll()` |
   | `sticky.board` | `stickyCommandBoard` | none | vault open | open the board screen (04.7) |
   | `capture.quick-note` | `captureCommandQuickNote` | none | vault open | open the capture screen (04.15) |
   "Active note" = the note in the focused tab (use the existing active-tab provider). Commands whose step is not built yet are registered with
   `isAvailable: (_) => false` and switched on in their step — this keeps ids stable.
2. `StickyColorPicker` — dialog with six round swatches (48 dp, labelled by the l10n colour names for screen readers), a "Custom" swatch that opens
   a hex text field (validates `#RRGGBB`), returns `StickyColor?`.
3. `StickyReminderDialog` — date picker + time picker (Material `showDatePicker`/`showTimePicker`), quick chips "In 10 minutes", "In 1 hour",
   "Tomorrow 09:00", and "Remove reminder". Returns `Optional<LocalDateTime>?` (null = cancelled). Times are wall-clock local.
4. `StickyExpiryDialog` — date picker + "Remove expiry". Returns `Optional<LocalDate>?`.
5. `StickyNoteBanner` — a 32 dp strip shown above the properties block when the active note is a sticky: colour dot (tap → colour picker),
   lock icon (tap → toggle), reminder chip showing the local time (tap → dialog), expiry chip. It reads `stickiesProvider`.
6. Lock = read-only: when `meta.locked`, the editor host passes its existing read-only flag (Phase 1 uses it for malformed UTF-8 files; reuse it) and the
   reading view disables task toggling. Changing frontmatter via the banner and `sticky.lock` still works while locked (they are explicit actions).

**Tests.**
- `sticky_commands_test.dart` (widget test with a `ProviderScope` overriding the repository with an in-memory one): `all twelve ids registered`,
  `pin-note unavailable on a sticky`, `unpin available on a sticky`, `lock toggles meta.locked`, `set-color applies picked colour` (drive the dialog by tapping the pink swatch).
- `sticky_color_picker_test.dart`: `custom hex validates` (`#12GG45` shows error, `#1234AB` returns hex colour), `semantics labels present`.

**Verify.**
```powershell
cd app; flutter test test/stickies; cd ..
cd app; flutter run -d windows; cd ..
```
Manual on Windows: open a normal note → palette → "Pin note as sticky" → banner appears and the file starts with `tephra-sticky: true`;
"Lock" → typing is blocked; "Unpin" → file bytes identical to before pinning (compare with `git diff --no-index` against a copy).

**Pitfalls.**
- Do not add `sticky.*` frontmatter outside `applyStickyPatch`.
- Keep the palette labels in l10n; ids are never translated.

---

### 04.5 — Sticky mini renderer and sticky card

**Purpose.** One lightweight renderer for sticky content, used by board cards, floating windows and the Android bubble (all of which may run in engines without vault/index providers).

**Files.**
- `app/lib/stickies/ui/sticky_mini_renderer.dart`
- `app/lib/stickies/ui/sticky_card.dart`
- `app/test/stickies/ui/sticky_mini_renderer_test.dart`
- `app/test/stickies/ui/goldens/` (golden PNGs)

**Implementation.**
1. Decision: we do **not** reuse the full reading-view renderer here, because sticky windows and the bubble run in separate Flutter engines that have
   no vault, index or link resolver. `StickyMiniRenderer` depends only on `tephra_markdown`.
   ```dart
   class StickyMiniRenderer extends StatelessWidget {
     const StickyMiniRenderer({super.key, required this.text, required this.textColor, this.onToggleTask, this.maxBlocks});
     final String text;                          // full note text (frontmatter is skipped)
     final Color textColor;
     final void Function(int line)? onToggleTask; // 0-based source line; null → checkboxes not tappable (locked)
     final int? maxBlocks;                        // card previews limit the block count
   }
   ```
2. Supported block nodes and their rendering (everything else falls back to its source text in a plain `Text`):
   | Node | Rendering |
   |---|---|
   | `MdHeading` | bold text, size 18/16/15/14/14/14 for levels 1–6 |
   | `MdParagraph` | `Text.rich` of inline spans |
   | `MdList` / `MdListItem` | bullet `•` or `n.` prefix, 16 dp indent per level; task items show a 20 dp checkbox (`Checkbox` scaled) |
   | `MdBlockQuote`, `MdCallout` | left border 3 dp, 8 dp padding; callout shows its title (or type) in bold |
   | `MdCodeBlock` | monospace, light translucent background |
   | `MdThematicBreak` | `Divider` |
   | `MdTable` | rows as text with ` | ` separators (no grid) |
   Inline spans: `MdStrong` bold, `MdEmphasis` italic, `MdStrikethrough` line-through, `MdHighlight` yellow-ish background `0x66FFEB3B`,
   `MdInlineCode` monospace, `MdWikiLink` → alias or target text underlined (not tappable), embeds `![[x]]` → `🖼 x` for images and `📄 x` otherwise,
   `MdLink` → link text underlined, `MdTag` → `#name` in bold, `MdCommentInline`/`MdCommentBlock` → hidden, math → source text.
3. Line numbers for task toggling: compute the 0-based line of `MdListItem.start` by counting `\n` in `text.substring(0, start)`; pass it to `onToggleTask`.
4. `StickyCard`:
   ```dart
   class StickyCard extends StatelessWidget {
     const StickyCard({super.key, required this.title, required this.text, required this.color, this.locked = false,
       this.pinned = false, this.remind, this.onToggleTask, this.onTap, this.onDoubleTap, this.maxBlocks = 12, this.selected = false});
   }
   ```
   Rounded 8 dp, background `color.argb`, elevation 2 (4 when `selected`), header row: title (bold, ellipsis), icons for pinned (`push_pin`), locked (`lock`),
   reminder (`alarm`), body = `StickyMiniRenderer` clipped with a bottom fade when content overflows.

**Tests.** `sticky_mini_renderer_test.dart`:
- `renders heading paragraph and task` — find texts and one `Checkbox`.
- `tap checkbox reports source line` — text `'---\ntephra-sticky: true\n---\n# T\n- [ ] a\n- [x] b\n'`; tapping the first checkbox calls `onToggleTask(4)`.
- `locked has no tappable checkbox` (`onToggleTask` null → tapping does nothing).
- `frontmatter is not shown`.
- `comments hidden`.
- Golden `sticky_card_yellow.png` and `sticky_card_hex_dark.png` (`@Tags(['golden'])`).

**Verify.**
```powershell
cd app; flutter test test/stickies/ui; cd ..
```

**Pitfalls.** Keep parsing off the build path for long notes: memoise the parsed note by `text` identity inside a `StatefulWidget` (`didUpdateWidget` re-parses only when `text` changes).

---

### 04.6 — Sticky board data: JSON Canvas file, colour mapping and reconciliation

**Purpose.** Store the board as a valid JSON Canvas 1.0 file that Obsidian opens, and keep it in step with the set of stickies.

**Files.**
- `app/lib/stickies/board/canvas_document.dart`
- `app/lib/stickies/board/board_color_map.dart`
- `app/lib/stickies/board/board_reconciler.dart`
- `app/lib/stickies/board/board_layout.dart`
- `app/test/stickies/board/canvas_document_test.dart`
- `app/test/stickies/board/board_reconciler_test.dart`
- `app/test/stickies/board/board_layout_test.dart`

**Implementation.**
1. Board file path: `<stickyFolder>/Sticky board.canvas` (default `Stickies/Sticky board.canvas`).
2. `CanvasDocument` — minimal JSON Canvas 1.0 model that **preserves unknown data** (Phase 6 builds the full canvas editor on top of the same rule):
   ```dart
   final class CanvasDocument {
     CanvasDocument({required this.nodes, required this.edges, Map<String, Object?>? extra});
     final List<CanvasNode> nodes; final List<Map<String, Object?>> edges;   // edges kept as raw maps (board never edits them)
     final Map<String, Object?> extra;                                        // unknown top-level keys
     static CanvasDocument parse(String json);    // throws ParseException on invalid JSON or a non-object root
     String encode();                             // JSON with 2-space indent ('\t' is also valid; use 2 spaces), trailing '\n'
   }
   final class CanvasNode {
     // Known fields: id, type ('text'|'file'|'link'|'group'), x, y, width, height (ints), color (String?), file (String?, for type 'file').
     // Everything else in the node object is kept in [extra] and written back unchanged, in its original key order after the known keys.
     ...
   }
   ```
   Encoding order of node keys: `id`, `type`, `file` (if any), `x`, `y`, `width`, `height`, `color` (if any), then `extra` keys in original order.
   Numbers: JSON Canvas uses integers for x/y/width/height; round doubles with `round()` when writing.
3. Colour mapping (`board_color_map.dart`). JSON Canvas preset colours are the strings `"1"` red, `"2"` orange, `"3"` yellow, `"4"` green, `"5"` cyan, `"6"` purple, or a hex string.
   | Our colour (§6.5) | Canvas `color` written | Canvas `color` read → our colour |
   |---|---|---|
   | `yellow` | `"3"` | `"3"` → yellow |
   | `pink` | `"1"` | `"1"` → pink, `"2"` → pink |
   | `blue` | `"5"` | `"5"` → blue |
   | `green` | `"4"` | `"4"` → green |
   | `purple` | `"6"` | `"6"` → purple |
   | `gray` | key omitted | missing → gray |
   | `#RRGGBB` | `"#RRGGBB"` | `"#rrggbb"` → hex |
   The note's frontmatter is the source of truth for colour. The canvas `color` is a mirror so Obsidian shows the same colour; it is rewritten
   from the note whenever the board saves. Reading the canvas colour is only used for nodes whose note cannot be read.
4. Node ids for new nodes: 16 lower-case hex chars from `Random.secure()` (JSON Canvas ids are arbitrary strings; Obsidian uses 16 hex chars).
5. `BoardReconciler`:
   ```dart
   final class BoardReconcileResult { final CanvasDocument doc; final bool changed; }
   BoardReconcileResult reconcileBoard(CanvasDocument doc, List<Sticky> stickies, {required Random random});
   ```
   Rules, in order:
   1. Index file nodes by `file` (vault path string, compare by `caseKey`).
   2. For each file node whose `file` is not an active sticky (missing, unpinned, or archived) → remove it. Never remove `text`, `link`, `group`
      nodes or file nodes pointing outside the sticky set **that are not `.md`** (images placed on the board by the user in Obsidian stay).
      File nodes pointing to a `.md` note that is not a sticky are removed only if that note sits inside `<stickyFolder>/` (a user may have dropped
      other notes on the board in Obsidian; leave those alone).
   3. For each active sticky without a node → add a file node 260 × 220 at the next free grid slot: columns of 280 px, rows of 240 px, starting at the
      right of the current bounding box (`maxX + 40`, `minY`), filling 5 rows per column. Empty board → start at (0, 0).
   4. For each sticky node set `color` from the note (mapping above); if different, mark changed.
   5. Edges whose `fromNode` or `toNode` was removed are removed too (JSON Canvas would be invalid otherwise).
   6. `changed` is true if any node/edge was added, removed or modified.
6. `board_layout.dart` — auto-layout modes (pure functions returning new positions, never touching ids):
   ```dart
   enum BoardLayoutMode { free, byColor, byTag }
   Map<String, Offset> layoutBoard(List<CanvasNode> stickyNodes, Map<String, Sticky> stickyByPath, BoardLayoutMode mode);
   ```
   - `byColor`: one column per colour in the order yellow, pink, blue, green, purple, gray, then hex colours sorted by value; within a column sort by
     sticky modified desc; column x = index × 300, y step 240.
   - `byTag`: group key = first tag of the sticky (lower-case) or `""` (no tag) last; groups sorted alphabetically; same column layout.
   - `free`: returns the current positions.

**Tests.**
- `canvas_document_test.dart`: `round trip keeps unknown keys` (node with `"styleAttributes": {"x":1}` and top-level `"metadata": {...}` survive encode);
  `parse Obsidian sample` (write a small hand-made canvas: one text node, one file node, one group, one edge → parse → encode → parse gives equal objects);
  `invalid json throws ParseException`; `doubles are rounded`.
- `board_reconciler_test.dart`: `adds missing sticky`, `removes unpinned sticky node and its edges`, `keeps text and image nodes`,
  `keeps non-sticky note outside sticky folder`, `colour mirrored from note` (`pink` → `"1"`, `gray` → no key, hex kept),
  `unchanged board reports changed false` (second reconcile of the result).
- `board_layout_test.dart`: `byColor column order`, `byTag groups with untagged last`, `free returns same positions`.

**Verify.**
```powershell
cd app; flutter test test/stickies/board; cd ..
```

**Pitfalls.** Paths in canvas `file` fields are vault-relative with forward slashes and the `.md` extension (exactly what Obsidian writes).

---

### 04.7 — Sticky board screen (both platforms)

**Purpose.** The endless board UI: zoom/pan, drag cards, auto-layout, inline quick edit, create by double-click/double-tap, live updates.

**Files.**
- `app/lib/stickies/board/board_controller.dart`
- `app/lib/stickies/board/sticky_board_screen.dart`
- `app/lib/stickies/board/board_quick_editor.dart`
- `app/lib/stickies/providers.dart` (add board providers)
- `app/test/stickies/board/board_controller_test.dart`
- `app/test/stickies/board/sticky_board_screen_test.dart`

**Implementation.**
1. `BoardController` (`Notifier<BoardState>`): owns the `CanvasDocument`, loads it from the board file (missing → empty document), runs
   `reconcileBoard` on load and on every `StickyChange`, and saves the canvas **only when `changed`**, debounced 1 s, through `fs.writeText`.
   If the board file exists but fails to parse → do not overwrite it; show an error banner "The board file could not be read" with a button
   "Create a new board" that renames the broken file to `Sticky board (broken YYYY-MM-DD HHmm).canvas` first.
   External change of the board file (watch event; e.g. sync or Obsidian) → reload + reconcile.
2. `StickyBoardScreen`:
   - `InteractiveViewer` with `constrained: false`, `boundaryMargin: EdgeInsets.all(double.infinity)`, `minScale: 0.2`, `maxScale: 2.5`, a 20 000 × 20 000
     logical-pixel child `Stack` whose origin is offset so canvas (0,0) sits at the child centre (canvas coordinates can be negative).
   - Each sticky node → `Positioned` `StickyCard` (`maxBlocks: 12`). Non-sticky nodes (text/link/group/other files) are drawn as simple grey outlined
     boxes with their label so the user sees them, but they cannot be edited here (Phase 6).
   - Drag: `GestureDetector.onPanUpdate` on the card moves it by `delta / scale` (read the scale from the `TransformationController`);
     on pan end, update the node x/y (rounded) and schedule the debounced save. On phone layout, start dragging only after a long-press
     (`LongPressDraggable`-like: use `onLongPressMoveUpdate`) so one-finger pans move the board.
   - Double-click (desktop) / double-tap (phone) on empty board space → `repository.create()` and add its node at that canvas position
     (convert with `TransformationController.toScene`), then open the quick editor for it.
   - Tap on a card → select; double-click/double-tap on a card → `BoardQuickEditor`.
   - Toolbar (app bar actions): layout mode menu (Free / By colour / By tag), "Zoom to fit", "New sticky", "Open board in canvas" (disabled until Phase 6).
     Choosing By colour/By tag applies `layoutBoard` once, saves, and shows a snackbar with "Undo" (restores the previous positions); the mode returns to Free afterwards.
   - Checkbox taps on cards → `toggleTaskAtLine` + `repository.setText`; disabled when locked.
3. `BoardQuickEditor` — a dialog (phone: full-height bottom sheet) with a multiline `TextField` on the note **body** (frontmatter not shown),
   colour picker button and lock toggle. Save on close or after 1 s idle: new text = frontmatter part unchanged + edited body, through `repository.setText`.
   Locked sticky → read-only text with a "Locked" label.
4. Live updates: the controller listens to `stickiesProvider`; Added → node appears; Removed → node disappears; Updated → card text/colour updates.

**Tests.**
- `board_controller_test.dart`: `load creates board file on first change`, `does not save when nothing changed` (count writes = 0 after a no-op reconcile),
  `broken board file is never overwritten`, `drag end saves once after debounce` (fake async), `sticky added elsewhere appears` (emit `StickyAdded`).
- `sticky_board_screen_test.dart`: `double tap on empty space creates sticky`, `layout by colour then undo restores positions`, `checkbox toggle writes note`.

**Verify.**
```powershell
cd app; flutter test test/stickies/board; cd ..
cd app; flutter run -d windows; cd ..
```
Manual (Windows and Android): open the board, create three stickies by double-click/double-tap, drag them, choose "By colour", undo, close the app,
reopen → positions kept. Open the vault in Obsidian → `Stickies/Sticky board.canvas` shows the same notes as cards in the same colours.

**Pitfalls.**
- Do not rebuild the whole `Stack` on every drag frame: keep the dragged card's offset in local state and commit on pan end.
- `InteractiveViewer` and card drags compete for gestures; the long-press rule on phone layout avoids that.

---

### 04.8 — Windows multi-window foundation and the sticky message protocol

**Purpose.** Run a second Flutter engine per sticky window and define a typed, versioned message protocol between sticky windows and the main window.

**Background (read this; it explains every later Windows decision).** With `desktop_multi_window`, every window is a separate Flutter engine
with its own Dart isolate. Isolates share no memory: a sticky window has no Riverpod container of the main window, no `NoteIndex`, no vault service.
Windows talk only by messages. If two engines both wrote the same note file we would have two writers racing; therefore **the main window is the
single writer**: a sticky window never touches the vault. It sends edits to the main window; the main window writes (through the open-document
layer when the note is open in a tab, otherwise atomically) and broadcasts the result back.

**Files.**
- `app/windows/runner/flutter_window.cpp` (plugin registration for new engines)
- `app/lib/main.dart` (branch to the sticky-window entry)
- `app/lib/stickies/windows/sticky_window_main.dart`
- `app/lib/stickies/windows/window_bus.dart`
- `app/lib/stickies/windows/sticky_protocol.dart`
- `app/test/stickies/windows/sticky_protocol_test.dart`
- `app/test/stickies/windows/fake_window_bus.dart`

**Implementation.**
1. Native setup (copy the pattern from the `desktop_multi_window` README "Windows" section, which you must open first): in
   `app/windows/runner/flutter_window.cpp`, include `"desktop_multi_window/desktop_multi_window_plugin.h"` and, in `FlutterWindow::OnCreate()` right after
   `RegisterPlugins(flutter_controller_->engine());`, call `DesktopMultiWindowSetWindowCreatedCallback(...)` with a lambda that casts the controller to
   `flutter::FlutterViewController*` and calls `RegisterPlugins(controller->engine())`. This registers every plugin in each new sticky engine.
2. `main.dart` branch (keep `main.dart` a bootstrap only, conventions §2): at the very start of `main()`, after `WidgetsFlutterBinding.ensureInitialized()`:
   ```dart
   if (!kIsWeb && Platform.isWindows) {
     final controller = await WindowController.fromCurrentEngine();
     final args = StickyWindowArgs.tryDecode(controller.arguments);   // null for the main window ('' arguments)
     if (args != null) { await runStickyWindow(controller, args); return; }
   }
   ```
   `runStickyWindow` lives in `sticky_window_main.dart` (filled in 04.9; in this step it shows a placeholder `MaterialApp` with the sticky path).
3. Window arguments (JSON string in `WindowConfiguration.arguments`):
   ```dart
   final class StickyWindowArgs {
     const StickyWindowArgs({required this.mainWindowId, required this.path, required this.protocolVersion});
     final String mainWindowId; final String path; final int protocolVersion;   // protocolVersion = 1
     String encode();   // {"kind":"tephra-sticky","v":1,"main":"<id>","path":"Stickies/x.md"}
     static StickyWindowArgs? tryDecode(String raw);   // null unless kind == 'tephra-sticky'
   }
   ```
4. `WindowBus` — the only abstraction over `desktop_multi_window` messaging, so protocol logic is testable with a fake:
   ```dart
   abstract interface class WindowBus {
     String get selfId;
     Future<void> send(String toWindowId, StickyMessage message);          // throws WindowGoneException if the target is closed
     Stream<(String fromWindowId, StickyMessage message)> get incoming;
     Future<String> createStickyWindow(StickyWindowArgs args);             // returns new window id (main window only)
     Stream<Set<String>> get openWindowIds;                                // ids of all live windows, emitted on every change
     Future<void> dispose();
   }
   ```
   `DesktopWindowBus` implementation:
   - Receiving: `(await WindowController.fromCurrentEngine()).setWindowMethodHandler((call) async { ... })`. Method name is always `'tephra.sticky'`;
     `call.arguments` is a `Map` with `from` (window id) and `msg` (the message JSON). Decode and add to `incoming`. Return `null`.
   - Sending: find the target with `WindowController.getAll()` (cache the list; refresh on `onWindowsChanged`), then
     `target.invokeMethod('tephra.sticky', {'from': selfId, 'msg': message.toJson()})`. Catch the plugin's errors and rethrow `WindowGoneException`.
   - Creating: `WindowController.create(WindowConfiguration(arguments: args.encode(), hiddenAtLaunch: true))` → `controller.windowId`.
   - `openWindowIds`: on each `onWindowsChanged` event call `WindowController.getAll()` and emit the set of `windowId`s.
   (If the README you open shows different names than `setWindowMethodHandler`/`invokeMethod`/`getAll`/`create`, use the README's and note it.)
5. `sticky_protocol.dart` — protocol v1. Every message is a JSON object `{"v":1,"type":"<type>", ...fields}`. A receiver ignores (and logs at `fine`)
   messages with an unknown `type` or `v != 1`.
   ```dart
   sealed class StickyMessage { const StickyMessage(); Map<String, Object?> toJson(); static StickyMessage? fromJson(Map<String, Object?> json); }
   ```
   | Type | Direction | Fields | Meaning |
   |---|---|---|---|
   | `ready` | sticky → main | `path` | window engine started and listens |
   | `open` | main → sticky | `path`, `text`, `hash`, `color` (yamlValue), `pinned`, `locked`, `collapsed`, `title` | full state; also sent after `ready` |
   | `update` | main → sticky | `path`, `text`, `hash`, `color`, `pinned`, `locked`, `title` | note changed (written by main, edited in a main tab, synced, renamed) |
   | `contentChanged` | sticky → main | `path`, `text`, `baseHash` | user edited text; `baseHash` = hash of the last `open`/`update` text the window applied |
   | `save` | sticky → main | `path` | flush now (window losing focus or closing); main replies `saved` |
   | `saved` | main → sticky | `path`, `hash` | everything received so far is on disk |
   | `setColor` | sticky → main | `path`, `color` | colour menu |
   | `setPinned` | sticky → main | `path`, `pinned` | always-on-top toggle (writes `sticky-pinned`) |
   | `setLocked` | sticky → main | `path`, `locked` | lock toggle |
   | `positionChanged` | sticky → main | `path`, `x`, `y`, `w`, `h`, `screen`, `collapsed` | geometry after move/resize/collapse (debounced 500 ms in the window) |
   | `close` | sticky → main | `path` | user closed the window (after `saved`) |
   | `closeRequest` | main → sticky | `path`, `reason` (`hideAll` \| `unpinned` \| `deleted` \| `quit`) | window must flush and close itself |
   | `openInMain` | sticky → main | `path` | "Open in Tephra" menu item |
   | `newSticky` | sticky → main | — | "+" button in a sticky window |
   Coordinates (`x`, `y`, `w`, `h`) are logical pixels; `x`/`y` are relative to the top-left of the `screen`'s work area (see 04.10).

**Tests.** `sticky_protocol_test.dart`:
- `every message round-trips through JSON` (one case per type, `fromJson(toJson())` equals original).
- `unknown type returns null`, `wrong version returns null`, `missing field returns null` (never throws).
- `args encode/decode` and `main window args '' decode to null`.
- `FakeWindowBus delivers in order` — `fake_window_bus.dart` provides `FakeWindowNetwork` that creates connected `FakeWindowBus` instances
  (main + N stickies) delivering messages asynchronously (`scheduleMicrotask`) in send order, and can "close" a window (later sends throw `WindowGoneException`).

**Verify.**
```powershell
cd app; flutter test test/stickies/windows; cd ..
cd app; flutter run -d windows; cd ..
```
Manual multi-window check (decides the `window_manager` fork question from the Dependencies section): add a temporary debug command
`debug.open-test-window` that creates a sticky window for any sticky; in the new window call `windowManager.ensureInitialized()`, `setAsFrameless()`,
`setAlwaysOnTop(true)`, `setSize(Size(300, 260))`. Success: a second small frameless window appears, stays on top, the main window is unchanged, and
the placeholder shows the sticky path. Remove the debug command before committing.

**Pitfalls.**
- Every engine runs `main()`. Anything before the branch (logging setup is fine) runs in every sticky window too — do not open the vault, the index,
  the tray or hotkeys before the branch.
- Each sticky window costs a full engine (roughly 40–80 MB RAM). That is why `stickies.maxWindows` (default 20) exists.
- Message arguments must be plain JSON types (`Map<String, Object?>`, `List`, `String`, `num`, `bool`, `null`).

---

### 04.9 — StickyHub (main window, single writer) and the sticky window app

**Purpose.** The main-window service that opens/closes sticky windows and applies their edits, and the small app that runs inside each sticky window.

**Files.**
- `app/lib/stickies/windows/sticky_hub.dart`
- `app/lib/stickies/windows/text_merger.dart`
- `app/lib/stickies/windows/sticky_window_main.dart` (replace placeholder)
- `app/lib/stickies/windows/sticky_window_app.dart`
- `app/lib/stickies/windows/sticky_window_controller.dart`
- `app/test/stickies/windows/sticky_hub_test.dart`
- `app/test/stickies/windows/sticky_window_controller_test.dart`

**Implementation.**
1. `TextMerger` wraps the Phase 3 merge function:
   ```dart
   sealed class MergeOutcome { const MergeOutcome(); }
   final class MergeClean extends MergeOutcome { const MergeClean(this.text); final String text; }
   final class MergeConflict extends MergeOutcome { const MergeConflict(); }
   abstract interface class TextMerger { MergeOutcome merge({required String base, required String local, required String remote}); }
   ```
   `SyncTextMerger` adapts the real function; tests use it too (it is pure Dart).
2. `StickyHub` (main window only; `Provider`, created only when `Platform.isWindows`):
   ```dart
   final class StickyHub {
     StickyHub({required WindowBus bus, required StickyRepository repo, required OpenNoteBridge openNotes,
       required TextMerger merger, required StickyPositionsStore positions /* 04.10 */, required ConflictCopyNamer conflictNamer, required Clock clock});
     Future<void> start();                     // listen to bus.incoming, repo.changes, openNotes.edited
     Future<void> open(VaultPath path);        // one window per path: focus the existing one instead of opening a second
     Future<void> closeWindow(VaultPath path, {required String reason});
     Future<void> showAll();                   // 04.10
     Future<void> hideAll();                   // 04.10
     Future<void> closeAllForQuit();           // sends closeRequest(quit) to all, waits up to 2 s for the windows to disappear
     Set<VaultPath> get openPaths;
   }
   ```
   State per open window: `windowId`, `path`, `sentHistory` (a `LinkedHashMap<String hash, String text>` of the last 20 texts sent to that window),
   `lastPosition`.
3. Hub message handling (the single-writer algorithm):
   - `ready` → send `open` with the current sticky state (`repo.byPath`; prefer `openNotes.openText(path)` as text if open in a tab). Record in `sentHistory`.
   - `contentChanged(path, text, baseHash)`:
     1. `current` = `openNotes.openText(path)` ?? text read from disk; `currentHash` = `contentHash(utf8.encode(current))` computed on the
        `\n`-normalised text (use the same hashing for everything the hub sends; it is a protocol hash, not the file-bytes hash).
     2. If `currentHash == baseHash` → `repo.setText(path, text)`.
     3. Else, if `sentHistory[baseHash]` exists → `merger.merge(base: sentHistory[baseHash], local: text, remote: current)`:
        `MergeClean(m)` → `repo.setText(path, m)`; `MergeConflict` → write a conflict copy containing `current` next to the note with the Phase 3
        conflict-copy name (device name from app settings), then `repo.setText(path, text)` (the sticky's typing wins in the file; the other version is kept, never lost).
     4. Else (unknown base) → treat as `MergeConflict` (step 3's conflict branch).
     5. Send `update` with the text now in the note and its hash; add to `sentHistory`.
   - `save` → ensure every pending `contentChanged` for that path has been processed (process messages per path sequentially with a `Future` chain), then reply `saved`.
   - `setColor` / `setPinned` / `setLocked` → `repo.patch(...)`; the resulting `StickyUpdated` triggers `update`.
   - `positionChanged` → `positions.save(path, geometry)` (04.10).
   - `close` → forget the window; remove its geometry entry (04.10 semantics: closing one window means "stop floating this sticky").
   - A window that disappears without sending `close` (after `closeRequest(hideAll|quit)`, or a crash) is detected through `WindowController.onWindowsChanged`
     (via the bus) → forget the window but **keep** its geometry entry.
   - `openInMain` → `WindowService.showMainWindow()` and open the note in a tab.
   - `newSticky` → `repo.create()` then `open(newPath)`.
   - `repo.changes`: Updated → if the path has a window and the new text/meta differs from the last sent → `update`; Removed → `closeRequest(unpinned or deleted)`;
     Moved → close the old window and open a new one for the new path (rename).
   - `openNotes.edited(path)` (typing in a main tab) → if a window is open for it → `update` with `openNotes.openText(path)`.
4. Sticky window app (`runStickyWindow(controller, args)`):
   - `windowManager.ensureInitialized()`; `WindowOptions(size: Size(300, 260), minimumSize: Size(180, 36), titleBarStyle: TitleBarStyle.hidden, skipTaskbar: true, backgroundColor: Colors.transparent)`;
     `setAsFrameless()`; position is applied when `open` arrives (04.10).
   - Own `ProviderScope` with only sticky-window providers; `DesktopWindowBus` as bus; sends `ready` once the handler is registered.
   - `StickyWindowController` (pure Dart logic, testable) holds: `path`, `appliedText`, `appliedHash`, `localText`, `dirty`, `pendingSend`, `meta`.
     Rules:
     - On `open`/`update`: if `!dirty` → `localText = text`; always set `appliedText/appliedHash`. If `dirty` → keep `localText`, set `appliedHash` to the
       new hash and schedule a send (the main window merges; the window never merges).
     - On local typing: `localText = value; dirty = true;` debounce 500 ms → send `contentChanged(path, localText, appliedHash)`, then `dirty = false` unless typing continued.
     - On focus loss: flush the debounce and send `save`.
     - On close button: flush, send `save`, wait for `saved` (timeout 2 s), send `close`, then `windowManager.close()`.
     - On `closeRequest`: flush, send `save`, wait for `saved` (timeout 2 s), then:
       `reason` is `hideAll` or `quit` → do **not** send `close` (the geometry entry must stay so the window can come back; see 04.10), just `windowManager.close()`;
       `reason` is `unpinned` or `deleted` → send `close` (the hub removes the geometry entry), then `windowManager.close()`.
       The hub's `closeAllForQuit()` therefore waits until every window id is absent from `bus.openWindowIds` (max 2 s), not for a `close` message. `FakeWindowBus` must emit `openWindowIds` when a fake window closes.
   - UI (`StickyWindowApp`): background = sticky colour; custom title bar 32 dp: drag area (`DragToMoveArea` from `window_manager`, or `onPanStart: windowManager.startDragging`),
     title text, buttons: pin (always-on-top toggle: `windowManager.setAlwaysOnTop(v)` and send `setPinned`), colour menu (six colours + "Custom…"),
     collapse/expand (collapsed = height 32 dp: store the expanded height, `windowManager.setSize(Size(w, 32))`), "⋯" menu (Lock/Unlock, Open in Tephra, New sticky, Close),
     close `×`. Body: `StickyMiniRenderer` in view mode; click into the body (or press `Enter`) → edit mode with a borderless multiline `TextField` on the
     **body** part; `Esc` or focus loss → view mode. Edits recombine `frontmatter part + body` before sending. Locked → no edit mode, checkboxes not tappable.
     Resize: frameless windows need explicit edges — wrap content in `DragToResizeArea` (window_manager) or 6 px edge `MouseRegion`s calling `windowManager.startResizing(ResizeEdge.x)`.
   - `pinned` from the note controls always-on-top on open/update (`setAlwaysOnTop(meta.pinned)`).

**Tests.** With `FakeWindowNetwork`, `MemoryVaultFileSystem`, fake repo/open-notes, `SyncTextMerger`:
- `sticky_hub_test.dart`:
  - `ready is answered with open`.
  - `edit in sticky writes once and broadcasts update` — after `contentChanged` with matching hash: one write, window receives `update` with new hash.
  - `edit while note open in main tab goes through openNotes` — `applyText` called, no direct fs write.
  - `main tab edit reaches window` — `openNotes.edited` → window gets `update`.
  - `concurrent edits merge` — base `'a\nb\nc\n'`; main tab changes line 1, sticky changes line 3 (stale baseHash) → file `'A\nb\nC\n'`.
  - `conflicting edits keep both` — both change line 2 → file has the sticky's text, a conflict-copy file holds the main version.
  - `unknown base hash keeps both`.
  - `save answers saved after pending edits` — send two `contentChanged` then `save`; `saved` arrives after both writes.
  - `one window per path` — `open` twice → one `createStickyWindow` call.
  - `unpin closes window` — `StickyRemoved` → `closeRequest(unpinned)`.
  - `rename reopens window` — `StickyMoved` → old closed, new opened.
  - `window gone is tolerated` — fake closes a window; hub forgets it without throwing.
- `sticky_window_controller_test.dart`: `debounces typing into one contentChanged`, `update while clean replaces text`, `update while dirty keeps local text and resends with new base`,
  `close waits for saved`, `locked blocks editing`.

**Verify.**
```powershell
cd app; flutter test test/stickies/windows; cd ..
cd app; flutter run -d windows; cd ..
```
Manual (record results in `PROGRESS.md`): open a sticky in a floating window and the same note in a main tab; type in each alternately for one minute;
both always show the same text within 1 s; the file on disk equals the visible text; no conflict copies appear when editing different lines.

**Pitfalls.**
- Never call `fs.write*` from the sticky window engine — it has no vault. Code review check: `app/lib/stickies/windows/sticky_window_*.dart` must not import `tephra_vault`.
- Process hub messages for the same path strictly in order (one `Future` chain per path); different paths may run concurrently.
- Cursor position on `update` while clean: keep the selection offset clamped to the new text length.

---

### 04.10 — Geometry per monitor, restore at start, show/hide all, start with Windows

**Purpose.** Floating stickies reopen where they were on this device, survive a missing monitor, can be hidden/shown together, and optionally start with Windows.

**Files.**
- `app/lib/stickies/data/sticky_positions_store.dart`
- `app/lib/stickies/windows/screen_key.dart`
- `app/lib/stickies/windows/sticky_window_geometry.dart`
- `app/lib/stickies/windows/sticky_hub.dart` (showAll/hideAll/restore)
- `app/lib/core/platform/window_service.dart` (Windows implementation incl. Run key)
- `app/lib/main.dart` (read `--autostart`)
- `app/test/stickies/data/sticky_positions_store_test.dart`
- `app/test/stickies/windows/sticky_window_geometry_test.dart`

**Implementation.**
1. `.tephra/stickies.json` exactly per conventions §6.6: `{ "<deviceId>": { "<vaultPath>": {"x":…, "y":…, "w":…, "h":…, "screen":"…", "collapsed":false} } }`.
   - `deviceId` from app settings. Entries of other devices are preserved byte-for-byte in meaning (decode → modify own section → encode).
   - Why not in the note: positions are per device and per screen; putting them in frontmatter would change the note on every drag, sync those
     changes to the phone, and create merge conflicts between devices with different screens.
   - Encoding: pretty JSON, 2-space indent, keys sorted (device ids sorted, paths sorted, fields in the order x, y, w, h, screen, collapsed), trailing `\n`.
     Sorted, one-field-per-line output keeps the Phase 3 line merge conflict-free when two devices change their own sections.
   - Writes are debounced 1 s and only happen when the encoded text changed.
   ```dart
   final class StickyGeometry { const StickyGeometry({required this.x, required this.y, required this.w, required this.h, required this.screen, this.collapsed = false}); ... }
   final class StickyPositionsStore {
     StickyPositionsStore({required VaultFileSystem fs, required String deviceId});
     Future<void> load();
     Map<VaultPath, StickyGeometry> get mine;
     Future<void> save(VaultPath path, StickyGeometry g);
     Future<void> remove(VaultPath path);
     Future<void> rename(VaultPath from, VaultPath to);
     Future<void> flush();
   }
   ```
   Malformed file → log a warning, keep it untouched on disk, treat as empty, and do not write until the user moves a window (then write the file
   with only well-formed sections that could be decoded plus ours; keep the broken original as `.tephra/stickies.json.bak`).
2. Screen key (`screen_key.dart`). `screen_retriever` display ids can change across reconnects, so store a stable key:
   `screen = "<display name>|<width>x<height>"` using the display's full size in logical pixels (e.g. `DELL U2720Q|2560x1440`).
3. Geometry math (`sticky_window_geometry.dart`, pure):
   ```dart
   final class ScreenInfo { const ScreenInfo({required this.key, required this.name, required this.workArea /* Rect, global logical px */, required this.isPrimary}); ... }
   StickyGeometry toStored(Rect windowGlobal, List<ScreenInfo> screens, {required bool collapsed});   // screen = the one containing the window centre (fallback: largest overlap, then primary)
   Rect toGlobal(StickyGeometry g, List<ScreenInfo> screens);
   ```
   `toGlobal` rules: find screen by exact key; else by same name; else primary. `rect = Rect.fromLTWH(work.left + g.x, work.top + g.y, g.w, g.h)`.
   Clamp so the window is fully visible in that work area: width/height limited to the work area size, then `left` clamped to
   `[work.left, work.right - w]`, `top` to `[work.top, work.bottom - h]`. A collapsed window uses height 32 for clamping.
4. Hub additions:
   - `open(path)`: geometry = `positions.mine[path]` → `toGlobal`, else cascade: first free slot starting at primary work-area top-right minus (320, −40),
     each next one offset (−24, +24). Send the bounds inside `open` via `windowManager.setBounds` in the window (the window applies them before `show()`).
   - `showAll()`: set `stickiesHiddenAll = false`; open a window for every active sticky (`repo.all`, modified desc), skipping already open ones,
     up to `stickiesMaxWindows`; if more exist, show a snackbar/toast "Showing 20 of N stickies".
   - `hideAll()`: set `stickiesHiddenAll = true`; send `closeRequest(hideAll)` to every window (windows close their engines to free memory but their geometry entries stay).
   - `restoreOnStart()` (called after the vault is open): if `stickiesRestoreOnStart && !stickiesHiddenAll` → open windows for every path in `positions.mine`
     that is still an active sticky (entries for missing/non-sticky paths are removed).
   - Semantics summary (show this table in the settings screen help text too):
     | Action | Windows | Geometry entries |
     |---|---|---|
     | Close one window (×) | closes | removed for that sticky |
     | Hide all | all close | kept; `hiddenAll = true` |
     | Show all | open for all active stickies (max N) | created/updated |
     | App start | reopen kept entries unless `hiddenAll` | unchanged |
5. Start with Windows (`WindowsWindowService.setLaunchAtStartup`), using `win32_registry` (check its API reference for the exact open/set/delete calls):
   key `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`, value name `Tephra`, `REG_SZ` data `"<Platform.resolvedExecutable>" --autostart`
   (the path in double quotes). Disable → delete the value (ignore "not found"). `isLaunchAtStartupEnabled` → value exists and its data starts with the
   quoted current executable path. Settings screen (Windows only): switch "Start Tephra with Windows" (`settingsStartWithWindows`).
6. `--autostart`: `main()` receives `List<String> args`; when it contains `--autostart`, the main window starts hidden (`windowManager.hide()` after init,
   tray icon visible) and the hub restores stickies. Without it the main window shows normally.

**Tests.**
- `sticky_positions_store_test.dart`: `keeps other devices`, `sorted stable encoding` (exact expected string), `no write when unchanged`, `rename moves entry`, `malformed file is backed up and not overwritten until save`.
- `sticky_window_geometry_test.dart`: `restores on same screen`, `falls back to same name with different size`, `missing monitor falls back to primary and clamps`
  (stored x 3000 on a 1920-wide primary → left = 1920 − w), `window larger than work area shrinks`, `collapsed uses 32 px height`, `toStored picks screen containing centre`.

**Verify.**
```powershell
cd app; flutter test test/stickies; cd ..
cd app; flutter build windows --release; cd ..
```
Manual: open three floating stickies on two monitors (or one monitor if only one exists — then simulate by editing `screen` to an unknown key in
`stickies.json`); quit; start the release build → all three reopen at the same places (unknown key → clamped onto the primary monitor).
Turn on "Start Tephra with Windows", sign out and in → Tephra starts hidden in the tray with the stickies restored. Check `regedit` shows the `Tephra` value.

**Pitfalls.**
- Logical vs physical pixels: `screen_retriever` and `window_manager` both use logical pixels; never multiply by the scale factor yourself.
- Do not write `stickies.json` on every mouse move; only on the window's debounced `positionChanged`.

---

### 04.11 — Global hotkey and tray menu (Windows)

**Purpose.** `Ctrl+Alt+N` creates a sticky from anywhere; the tray menu controls stickies and the app.

**Files.**
- `app/lib/core/platform/global_hotkey_service.dart` (Windows implementation)
- `app/lib/core/platform/tray_service.dart` (Windows implementation; extend Phase 3's if it exists)
- `app/lib/stickies/windows/sticky_desktop_integration.dart`
- `app/assets/tray/tray_icon.ico` (reuse Phase 3's tray icon if it exists)
- `app/test/stickies/windows/accelerator_test.dart`
- `app/test/stickies/windows/sticky_desktop_integration_test.dart`

**Implementation.**
1. Accelerator parsing (pure, `app/lib/stickies/windows/accelerator.dart`): `Accelerator.parse('Ctrl+Alt+N')` → modifiers {control, alt} + key `N`.
   Accept `Ctrl`, `Control`, `Alt`, `Shift`, `Win`/`Meta`, keys `A`–`Z`, `0`–`9`, `F1`–`F12`; case-insensitive; reject a key without at least one of Ctrl/Alt/Win.
2. `WindowsGlobalHotkeyService.register`: build `HotKey(key: PhysicalKeyboardKey.keyN, modifiers: [HotKeyModifier.control, HotKeyModifier.alt], scope: HotKeyScope.system)`
   (map parsed keys to `PhysicalKeyboardKey`), call `hotKeyManager.register(hotKey, keyDownHandler: (_) => onPressed())`. Call `hotKeyManager.unregisterAll()`
   once at startup before registering (hot restart leaves stale registrations). If registration fails (another app owns the combination), show a
   one-time notice "Ctrl+Alt+N is used by another app; change it in Settings → Stickies" and continue.
3. `WindowsTrayService`: icon + tooltip "Tephra"; menu items in this order, labels from l10n: New sticky (`trayNewSticky`), Show all stickies (`trayShowAllStickies`),
   Hide all stickies (`trayHideAllStickies`), separator, Open Tephra (`trayOpenTephra`), separator, Quit (`trayQuit`). Left click on the icon = Open Tephra;
   right click = menu. If Phase 3 already has tray items (sync status, Sync now), keep them and insert the sticky items at the top.
   Use the API the installed `tray_manager` README marks as current (0.8 moved the old API to `legacy.dart`; prefer the non-legacy API; if Phase 3 used
   the legacy one, keep it consistent and note it).
4. `StickyDesktopIntegration` (started after the vault opens, Windows only) wires: hotkey → `repo.create()` → `hub.open(path)` → focus the new window
   in edit mode (send `open` with a flag field `"focusEdit": true` — add this optional field to the `open` message in `sticky_protocol.dart`, default false, and a test);
   tray actions → `repo.create()+hub.open`, `hub.showAll()`, `hub.hideAll()`, `WindowService.showMainWindow()`, quit (= `hub.closeAllForQuit()`, flush positions,
   flush the open-document layer, then exit through the existing app-exit path).
5. Main window close (×): if `keepRunningInTray` → hide main window (stickies stay), else quit as above. If Phase 3 implemented this already, reuse it.
6. Settings → Stickies (Windows): hotkey field (records a key combination; validates with `Accelerator.parse`), "Restore stickies at start", "Maximum floating stickies".

**Tests.**
- `accelerator_test.dart`: `parses Ctrl+Alt+N`, `case-insensitive`, `rejects N alone`, `rejects unknown key`, `F5 with Ctrl ok`.
- `sticky_desktop_integration_test.dart` (fakes for hotkey/tray/hub/repo): `hotkey creates and opens sticky`, `tray show/hide call hub`, `quit flushes before exit` (order of calls asserted).

**Verify.**
```powershell
cd app; flutter test test/stickies/windows; cd ..
cd app; flutter run -d windows --release; cd ..
```
Manual: focus another app (Notepad), press `Ctrl+Alt+N` → a new sticky window appears focused in edit mode; type; tray → Hide all → all windows go;
Show all → they return; Quit → app exits and `stickies.json` contains the geometry.

**Pitfalls.** Global hotkeys must only be registered in the main engine; never in sticky windows.

---

### 04.12 — Reminders (both platforms), headless config, deep links

**Purpose.** `sticky-remind` fires a notification at the right local time even if the app is closed, tapping it opens the sticky; plus the
shared deep-link and headless plumbing used by all Android capture features.

**Files.**
- `app/lib/core/headless_config.dart`
- `app/lib/core/deep_links/deep_link.dart`
- `app/lib/core/deep_links/deep_link_router.dart`
- `app/lib/stickies/reminders/reminder_time.dart`
- `app/lib/stickies/reminders/reminder_ids.dart`
- `app/lib/stickies/reminders/reminder_scheduler.dart`
- `app/lib/core/platform/notification_service.dart` (Android + Windows implementation)
- `app/lib/settings/` reminders section (in the existing settings screen structure)
- `app/android/app/src/main/AndroidManifest.xml`
- `app/test/stickies/reminders/reminder_time_test.dart`
- `app/test/stickies/reminders/reminder_scheduler_test.dart`
- `app/test/core/deep_links/deep_link_test.dart`
- `app/test/core/headless_config_test.dart`

**Implementation.**
1. `DeepLink` — URI scheme `tephra://` (all parameters URL-encoded with `Uri` APIs, never by hand):
   | URI | Meaning |
   |---|---|
   | `tephra://open?vault=<vaultId>&path=<vaultPath>` | open the note |
   | `tephra://capture?vault=<vaultId>` | open the capture screen (04.15) |
   | `tephra://new-sticky?vault=<vaultId>` | create a sticky and open it |
   | `tephra://daily?vault=<vaultId>` | open today's daily note |
   | `tephra://board?vault=<vaultId>` | open the sticky board |
   | `tephra://widget-config?widgetId=<n>` | choose a sticky for a single-sticky widget (04.13) |
   `vault` is optional; missing → current vault.
   ```dart
   sealed class DeepLink { static DeepLink? parse(Uri uri); Uri toUri(); }   // OpenNoteLink, CaptureLink, NewStickyLink, DailyLink, BoardLink, WidgetConfigLink
   ```
2. `DeepLinkRouter` (app, `Provider`): consumes links from `app_links` (`AppLinks().uriLinkStream`, Android only), `HomeWidgetService.widgetLaunches` +
   `initialWidgetLaunch`, `NotificationService.taps` + `launchPayload`, and `AppShortcutService`. If `vault` differs from the open vault: open it if it is in the
   recent-vaults list, else show "This note belongs to a vault that is not on this device". Routes, one per link type:
   `OpenNoteLink` → open the note in a new tab (phone: push the editor screen); `CaptureLink` → open the quick-capture sheet;
   `NewStickyLink` → run command `sticky.new`; `DailyLink` → open today's daily note (create from template if missing);
   `BoardLink` → run command `sticky.board`; `WidgetConfigLink` → open the widget sticky picker (04.13) for that widget id.
   Links that arrive before the vault is open are queued and handled after it opens.
3. `HeadlessConfig` — a small JSON file that background isolates (widget callback, notification reply, overlay fallback) read because they have no Riverpod state:
   path `<getApplicationSupportDirectory()>/headless.json`:
   ```json
   {"v":1,"vaultId":"…","vaultRoot":"C:\\…  or /storage/emulated/0/Documents/MyVault","fsKind":"io",
    "stickyFolder":"Stickies","dailyNote":{"folder":"Daily","format":"YYYY-MM-DD","template":"Templates/Daily.md"},
    "quickTarget":"dailyNote","inboxPath":"Inbox.md","deviceName":"Pixel 8"}
   ```
   Written (atomically, via `File.rename` of a temp file) whenever the vault opens or a relevant setting changes. `fsKind` is `io` for `IoVaultFileSystem`
   and `saf` for the Phase 1 SAF fallback; headless writers only work for `io` (for `saf` they open the app instead). Fill `dailyNote` with whatever the
   Phase 2 daily-notes settings contain (use their real field names; this JSON shape is ours and internal).
4. `reminder_time.dart` — DST-correct conversion of a wall-clock `LocalDateTime` to a UTC instant in an IANA zone:
   ```dart
   /// Returns the UTC instant for wall-clock [t] in [location].
   /// Gap (time does not exist, spring forward): shift forward by the gap length (02:30 → 03:30 on a 1-hour gap).
   /// Overlap (time exists twice, fall back): the earlier instant (the first occurrence).
   DateTime resolveWallTime(LocalDateTime t, tz.Location location);
   ```
   Algorithm (do not rely on `TZDateTime`'s constructor for gaps/overlaps; implement exactly this):
   1. `n = DateTime.utc(t.year, t.month, t.day, t.hour, t.minute).millisecondsSinceEpoch` (the wall time read as if it were UTC).
   2. `oBefore = location.timeZone(n - 86400000).offset`, `oAfter = location.timeZone(n + 86400000).offset` (milliseconds; check the `timezone`
      package API name — it is `Location.timeZone(int millisecondsSinceEpoch)` returning `TimeZone` with `offset` in ms in current versions).
   3. Candidates: for each distinct `o` in `{oBefore, oAfter}`: `u = n - o`; valid if `location.timeZone(u).offset == o`.
   4. If one or more valid → return the smallest `u` as `DateTime.fromMillisecondsSinceEpoch(u, isUtc: true)`.
   5. If none valid (gap) → return `n - oBefore` (lands after the transition, i.e. shifted forward by the gap).
5. Local zone: at startup `tz.initializeTimeZones()` (from `package:timezone/data/latest_all.dart`), then
   `final name = (await FlutterTimezone.getLocalTimezone()).identifier;` (check the field name in the README) and `tz.setLocalLocation(tz.getLocation(name))`;
   unknown name → `UTC` + warning.
6. `reminder_ids.dart`: `int reminderId(String vaultId, VaultPath path)` = FNV-1a 32-bit over UTF-8 of `'$vaultId\n${path.value}'`, then `& 0x7FFFFFFF`.
7. `ReminderScheduler` (app `Provider`, per open vault):
   ```dart
   final class ReminderScheduler {
     ReminderScheduler({required NotificationService notifications, required StickyRepository repo, required String vaultId,
       required tz.Location location, required Clock clock, required ReminderLedger ledger});
     Future<void> reconcile();   // desired vs scheduled
   }
   ```
   - Desired set: every active sticky with `meta.remind != null`, instant = `resolveWallTime(remind, location)`, instant in the future (more than 5 s from now)
     and less than 366 days ahead. Title = sticky title; body = first non-empty body line, max 120 chars (shown in the OS notification only); payload =
     `DeepLink OpenNoteLink(vaultId, path).toUri().toString()`.
   - `ReminderLedger` = `<appSupportDir>/reminders.json` `{ "<vaultId>": { "<id>": {"path": "...", "at": "<UTC ISO>"} } }` — what we scheduled last time
     (needed because Windows cannot list pending scheduled toasts for unpackaged apps).
   - Reconcile: cancel ids in the ledger not desired or with a different `at`; schedule desired ids that are new or changed; save the ledger.
   - Triggers: app start (after vault open), every `StickyChange` with a remind/path change (debounced 2 s), sync cycle finished (Phase 3 event),
     timezone change (on app resume re-read the local zone; if changed → reconcile), settings `reminders.enabled` toggled (off → cancel all in ledger).
   - Boot: on Android, `flutter_local_notifications` persists scheduled notifications and reschedules them after reboot itself through its
     `ScheduledNotificationBootReceiver` (manifest entries below); our `reconcile()` on the next app start then catches anything changed by sync.
8. `NotificationService` implementations (check the plugin README "Initialisation", "Scheduling", "Windows" sections before coding):
   - Shared: `FlutterLocalNotificationsPlugin().initialize(InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_tephra'),
     windows: WindowsInitializationSettings(appName: 'Tephra', appUserModelId: 'com.tephra.app', guid: 'b6f1c7e2-4a8d-4f3e-9c51-2d7a6e0f9b13')),
     onDidReceiveNotificationResponse: (r) => _taps.add(r.payload ?? ''), onDidReceiveBackgroundNotificationResponse: quickNoteReplyHandler /* 04.16 */)`.
     The GUID is a fixed, non-secret identifier for Tephra's toast activator; never change it after release.
   - `launchPayload()` → `getNotificationAppLaunchDetails()`; if `didNotificationLaunchApp` → its response payload.
   - `schedule(r)`: `zonedSchedule(id: r.id, title: r.title, body: r.body, scheduledDate: tz.TZDateTime.from(r.at, tz.UTC), notificationDetails: details,
     androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle, payload: r.payload)`
     (named parameters as in plugin 22.x; adapt to the README if they differ).
     Android channel: id `reminders`, name l10n `notificationChannelReminders`, importance high. Windows: default toast details.
     `exact` = result of `canScheduleExactNotifications()` on the Android implementation (true on Windows).
   - `requestNotificationPermission` (Android 13+): `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()`.
   - `requestExactAlarmPermission` (Android 12+): `…requestExactAlarmsPermission()` (opens the system "Alarms & reminders" page).
9. Android exact-alarm rules you must respect (decision: we declare only `SCHEDULE_EXACT_ALARM`, not `USE_EXACT_ALARM`, because `USE_EXACT_ALARM` is
   restricted on Google Play to alarm/calendar apps and we plan a store release later):
   | Android | Behaviour |
   |---|---|
   | 8–11 (API 26–30) | no permission needed for exact alarms |
   | 12 (API 31–32) | `SCHEDULE_EXACT_ALARM` granted at install, user can revoke |
   | 13 (API 33) | `POST_NOTIFICATIONS` runtime permission needed to show anything; `SCHEDULE_EXACT_ALARM` still pre-granted for apps targeting ≤ 32 only — we target higher, so assume it may be denied |
   | 14+ (API 34+) | `SCHEDULE_EXACT_ALARM` denied by default for new installs targeting 33+; must ask the user (system settings page) |
   If exact alarms are not allowed, schedule inexact (may fire minutes late) and show a banner in Settings → Reminders and in the reminder dialog:
   "Reminders may be late. Allow 'Alarms & reminders' for Tephra." with a button calling `requestExactAlarmPermission()`. After returning to the app
   (`AppLifecycleState.resumed`), re-check and `reconcile()` (rescheduling with the exact mode).
10. Manifest additions (`app/android/app/src/main/AndroidManifest.xml`; copy the receiver entries verbatim from the plugin README for the installed version):
    ```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <!-- inside <application> -->
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
      </intent-filter>
    </receiver>
    ```
    Add a monochrome status-bar icon `app/android/app/src/main/res/drawable/ic_stat_tephra.xml` (24 dp vector, white on transparent: a simple note shape).
11. Settings → Reminders: switch "Reminders" (`remindersEnabled`), status rows "Notifications: allowed/blocked" and "Exact timing: allowed/limited" with buttons.
    On Android 13+, the first time the user sets a reminder, call `requestNotificationPermission()` before scheduling.

**Tests.**
- `reminder_time_test.dart` (call `tz.initializeTimeZones()` in `setUpAll`):
  - `Asia/Dhaka plain time` — 2026-10-12T09:00 → `2026-10-12T03:00:00Z`.
  - `New York spring-forward gap` — 2026-03-08T02:30 in `America/New_York` → `2026-03-08T07:30:00Z` (= 03:30 EDT).
  - `New York fall-back overlap picks first` — 2026-11-01T01:30 → `2026-11-01T05:30:00Z` (EDT occurrence).
  - `London summer time` — 2026-07-01T09:00 in `Europe/London` → `2026-07-01T08:00:00Z`.
  - `Sydney southern DST` — 2026-10-04T02:30 in `Australia/Sydney` (gap) → `2026-10-03T16:30:00Z` (= 03:30 AEDT).
  - `UTC identity`.
- `reminder_scheduler_test.dart` (fake `NotificationService` recording calls, fixed clock 2026-10-11T09:30 local Dhaka, in-memory ledger):
  - `schedules future reminders only` (past and > 366 days skipped).
  - `reconcile is idempotent` (second run → zero calls).
  - `changed time cancels then schedules`.
  - `unpinned sticky cancels reminder`.
  - `renamed sticky gets new id and old id is cancelled`.
  - `disabled setting cancels all`.
  - `payload is an open deep link` (parses back to `OpenNoteLink` with the path).
- `deep_link_test.dart`: one round-trip per link type; `path with spaces and Bangla characters` (`Stickies/কাজ 1.md`); `unknown host returns null`; `missing vault is allowed`.
- `headless_config_test.dart`: `round trip`, `unknown version returns null`, `atomic write leaves no temp file`.

**Verify.**
```powershell
cd app; flutter test test/stickies/reminders test/core; cd ..
cd app; flutter run -d windows; cd ..
cd app; flutter run -d <android-device-id> --release; cd ..
```
Manual Windows: set a sticky reminder 2 minutes ahead → toast appears on time → click it → Tephra opens the sticky. Repeat with Tephra fully quit
(tray → Quit) — record in `PROGRESS.md` whether the scheduled toast still fires with the app closed. **Decision rule:** if it does not fire with the
app closed, keep scheduling via `zonedSchedule` (it works while the app runs in the tray, which is the default) and add a note to `PROGRESS.md`
"Windows reminders require Tephra running in the tray"; do not build another mechanism.
Manual Android (release build): set a reminder 3 minutes ahead, swipe Tephra away from recents → notification fires within 1 minute of the time
(exact alarms allowed). Deny "Alarms & reminders" → banner appears. Reboot the phone with a reminder 5 minutes ahead (do not open Tephra) → it fires.

**Pitfalls.**
- Never store `TZDateTime` in the ledger; store UTC ISO strings.
- Android notification ids must fit in 32-bit signed ints (hence `& 0x7FFFFFFF`).
- Background notification handlers must be top-level functions annotated `@pragma('vm:entry-point')`.

---

### 04.13 — Android home-screen widgets (single sticky, sticky stack)

**Purpose.** A resizable single-sticky widget with tappable checkboxes and a sticky-stack widget, refreshed whenever stickies change (including after sync).

**Files** (all paths under `app/android/app/src/main/` unless they start with `app/lib` or `app/test`):
- `kotlin/com/tephra/app/WidgetRender.kt` (shared helpers)
- `kotlin/com/tephra/app/StickyWidgetProvider.kt`
- `kotlin/com/tephra/app/StickyStackWidgetProvider.kt`
- `res/layout/widget_sticky.xml`
- `res/layout/widget_sticky_stack.xml`
- `res/drawable/widget_bg.xml`
- `res/xml/sticky_widget_info.xml`
- `res/xml/sticky_stack_widget_info.xml`
- `res/values/widget_strings.xml`
- `AndroidManifest.xml` (receivers)
- `app/lib/stickies/android/widget_lines.dart`
- `app/lib/stickies/android/widget_data.dart`
- `app/lib/stickies/android/sticky_widget_sync.dart`
- `app/lib/stickies/android/widget_callback.dart`
- `app/lib/core/platform/home_widget_service.dart` (Android implementation)
- `app/lib/stickies/ui/widget_sticky_picker_screen.dart`
- `app/test/stickies/android/widget_lines_test.dart`
- `app/test/stickies/android/widget_data_test.dart`
- `app/test/stickies/android/widget_callback_test.dart`

**Implementation.**
1. Decisions (RemoteViews limits): Android widgets cannot host Flutter, an `EditText`, or real `CheckBox`es before API 31. Therefore:
   - The single-sticky widget shows a title and up to **10 fixed `TextView` rows** (`line_0` … `line_9`). Task rows show `☐ ` or `☑ ` before the text;
     each task row gets its own click `PendingIntent` that toggles that line. Non-task rows open the note.
   - The stack widget shows up to **6 fixed rows** (`item_0` … `item_5`), each a coloured strip with title + one-line preview, plus a "+N more" footer
     that opens the board. No `ListView`/`RemoteViewsService` (fixed rows are simpler and reliable).
   - Background colour: an `ImageView` (`@+id/bg`) with the rounded `widget_bg.xml` shape, tinted via `setInt(R.id.bg, "setColorFilter", argb)`.
2. `widget_lines.dart` (pure):
   ```dart
   final class WidgetLine { const WidgetLine({required this.text, required this.kind, this.checked = false, required this.sourceLine}); ... }
   enum WidgetLineKind { text, task, heading, bullet }
   List<WidgetLine> widgetLinesFromMarkdown(String noteText, {int maxLines = 10});
   ```
   Rules: skip frontmatter; one `WidgetLine` per block, list item or task (nested items flattened, indented with two spaces per level);
   plain text of inline nodes (bold/italic markers removed, wikilinks → alias or target, links → text, embeds → `[image]`/`[file]`, comments dropped);
   headings `kind: heading`; bullets prefixed `• `; empty blocks skipped; code blocks → first line only; each line truncated to 200 chars; stop at `maxLines`.
   `sourceLine` = 0-based line in `noteText` of the block/item start.
3. `widget_data.dart` — JSON stored with `HomeWidget.saveWidgetData<String>(key, jsonEncode(map))` (one key per widget):
   - Single widget, key `sticky_widget_<appWidgetId>`:
     ```json
     {"v":1,"configured":true,"vaultId":"…","path":"Stickies/Sticky 2026-10-11 093005.md","title":"Sticky 2026-10-11 093005",
      "bg":4294964131,"fg":4280229663,"locked":false,"hash":"<protocol hash of text>","more":3,
      "lines":[{"t":"Call the printer guy","k":"text","c":false,"l":4},{"t":"ask about toner","k":"task","c":false,"l":5}]}
     ```
     Unconfigured widget: `{"v":1,"configured":false}`. Missing note: `{"v":1,"configured":true,"missing":true,"path":"…"}`.
   - Stack, key `sticky_stack` (shared by all stack widgets): `{"v":1,"vaultId":"…","total":9,"items":[{"path":"…","title":"…","bg":…,"fg":…,"preview":"first line"}]}` (max 6, modified desc).
   - Map key `sticky_widget_paths`: `{"<appWidgetId>":"<path>"}` — which sticky each single widget shows (written by the picker).
   ```dart
   Map<String, Object?> stickyWidgetJson(Sticky? s, {required String vaultId, required bool configured});
   Map<String, Object?> stackWidgetJson(List<Sticky> active, {required String vaultId});
   ```
4. Kotlin (check `home_widget`'s Android docs and its source in the pub cache for the exact class names — expected:
   `es.antonborri.home_widget.HomeWidgetProvider` with
   `override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences)`,
   `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri)`, `HomeWidgetBackgroundIntent.getBroadcast(context, Uri)`):
   - `StickyWidgetProvider : HomeWidgetProvider()` — for each id: read `widgetData.getString("sticky_widget_$id", null)`, parse with `org.json.JSONObject`.
     Not configured → title "Tap to choose a sticky" (`R.string.widget_choose_sticky`), whole widget click → launch `tephra://widget-config?widgetId=$id`.
     Missing → "Sticky not found". Otherwise set title, tint, text colours, rows: for `i in 0..9` set text or `View.GONE`; task row click →
     `HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("tephra-widget://toggle?widgetId=$id&line=${l}&hash=${hash}"))`
     (skip when `locked`); other rows and title → `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("tephra://open?vault=$vaultId&path=${Uri.encode(path)}"))`.
     `more > 0` → footer "+$more more lines".
   - `StickyStackWidgetProvider : HomeWidgetProvider()` — reads `sticky_stack`, fills `item_0..item_5` (tint strip, title, preview), each click opens its note;
     footer "+N more" / header click → `tephra://board?vault=…`. Empty → "No stickies yet — tap to create" → `tephra://new-sticky`.
   - `WidgetRender.kt` holds the shared JSON parsing and row-filling helpers.
   - `onDeleted(context, appWidgetIds)` in `StickyWidgetProvider`: remove `sticky_widget_$id` keys from `widgetData` (the Dart side also cleans up stale ids on refresh).
5. Layouts: `widget_sticky.xml` = `FrameLayout` (`@+id/root`) → `ImageView @+id/bg` (match_parent, `src=@drawable/widget_bg`, `scaleType=fitXY`) + vertical `LinearLayout`
   with `TextView @+id/title` (bold, 15sp, single line), ten `TextView`s `@+id/line_0`…`@+id/line_9` (13sp, maxLines 2, ellipsize end), `TextView @+id/more` (11sp).
   `widget_sticky_stack.xml` = same frame + header `TextView @+id/header` ("Stickies") + six row `LinearLayout`s `@+id/item_0`…`@+id/item_5`, each with
   `ImageView @+id/item_N_color` (8 dp wide strip), `TextView @+id/item_N_title`, `TextView @+id/item_N_preview`, + `TextView @+id/footer`.
   `widget_bg.xml` = `<shape android:shape="rectangle">` with `solid #FFFFFFFF` and `corners android:radius="16dp"`.
6. Provider info: `sticky_widget_info.xml`: `minWidth 110dp`, `minHeight 110dp`, `targetCellWidth 2`, `targetCellHeight 2`, `resizeMode="horizontal|vertical"`,
   `widgetCategory="home_screen"`, `updatePeriodMillis="0"` (we push updates), `initialLayout="@layout/widget_sticky"`, `description="@string/widget_sticky_description"`.
   `sticky_stack_widget_info.xml`: same with `minWidth 180dp`, `minHeight 180dp`, `targetCellWidth 3`, `targetCellHeight 3`, `initialLayout="@layout/widget_sticky_stack"`.
7. Manifest receivers (inside `<application>`; plus the `home_widget` background receiver from its interactivity docs):
   ```xml
   <receiver android:name=".StickyWidgetProvider" android:exported="true" android:label="@string/widget_sticky_label">
     <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
     <meta-data android:name="android.appwidget.provider" android:resource="@xml/sticky_widget_info"/>
   </receiver>
   <receiver android:name=".StickyStackWidgetProvider" android:exported="true" android:label="@string/widget_stack_label">
     <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
     <meta-data android:name="android.appwidget.provider" android:resource="@xml/sticky_stack_widget_info"/>
   </receiver>
   <receiver android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver" android:exported="true">
     <intent-filter><action android:name="es.antonborri.home_widget.action.BACKGROUND"/></intent-filter>
   </receiver>
   ```
   (Since `home_widget` 0.8.1 the `HomeWidgetBackgroundService` entry is not needed; add it only if the installed version's docs say so.)
8. `AndroidHomeWidgetService`: `saveJson` → `HomeWidget.saveWidgetData<String>`; `updateStickyWidgets` → `HomeWidget.updateWidget(qualifiedAndroidName: 'com.tephra.app.StickyWidgetProvider')`;
   stack → `…StickyStackWidgetProvider`; `installedStickyWidgetIds` → `HomeWidget.getInstalledWidgets()` filtered by provider class (check the `HomeWidgetInfo` field names);
   `widgetLaunches` → `HomeWidget.widgetClicked`; `initialWidgetLaunch` → `HomeWidget.initiallyLaunchedFromHomeWidget()`.
9. `StickyWidgetSync` (app `Provider`, Android only): listens to `repo.changes` and the Phase 3 sync-finished event; debounced 1 s; recomputes the JSON for every
   installed single widget (path from `sticky_widget_paths`) and the stack; writes only keys whose JSON changed; calls the two `update…` methods; removes keys
   of widget ids no longer installed. Also runs once on app start and on `AppLifecycleState.paused` (so the widget is fresh when the user goes home).
10. Widget picker: `tephra://widget-config?widgetId=N` → `WidgetStickyPickerScreen` (list of active stickies as `StickyCard`s + "New sticky") → writes
    `sticky_widget_paths[N]`, recomputes, updates, then `SystemNavigator.pop()` when the app was launched by the link (so the user returns to the home screen).
11. Interactivity callback (`widget_callback.dart`), registered once at app start with `HomeWidget.registerInteractivityCallback(stickyWidgetCallback)`:
    ```dart
    @pragma('vm:entry-point')
    Future<void> stickyWidgetCallback(Uri? uri) async { ... }
    ```
    Runs in a background isolate (the app may not be running). Steps: `WidgetsFlutterBinding.ensureInitialized()`; `DartPluginRegistrant.ensureInitialized()`;
    read `HeadlessConfig` (missing or `fsKind != io` → do nothing); parse `widgetId`, `line`, `hash`; path from `sticky_widget_paths`;
    `fs = IoVaultFileSystem(config.vaultRoot)`; read text; if the protocol hash of the text ≠ `hash` → only refresh the widget JSON (the note changed since the widget was drawn; never toggle a stale line);
    else `newText = toggleTaskAtLine(text, line)`; null → refresh only; else `StickyFileWriter(fs).writeIfUnchanged(path, fileHash, newText)` (file-bytes hash read just before);
    recompute the widget JSON from the new text; save; `updateStickyWidgets()`; `fs.dispose()`.
    Keep the toggle logic in a pure function `Future<WidgetToggleResult> handleWidgetToggle(VaultFileSystem fs, String path, int line, String hash)` so it is unit-testable.
    If the main app is running, its watcher sees the external write and the repository/editor reload as for any external edit.

**Tests.**
- `widget_lines_test.dart`: `skips frontmatter`, `tasks carry checked state and source line`, `nested bullets indented`, `inline markup stripped` (`**a** [[B|bee]] ![[x.png]]` → `a bee [image]`),
  `stops at maxLines`, `comment hidden`, `Bangla text intact`.
- `widget_data_test.dart`: `single widget json matches golden map` (exact `equals` on the map), `unconfigured json`, `missing note json`, `stack limited to 6 with total`, `colours are argb ints`.
- `widget_callback_test.dart` (on `MemoryVaultFileSystem`): `toggles line when hash matches`, `stale hash does not toggle`, `non-task line does nothing`, `file changed between read and write is not overwritten`.

**Verify.**
```powershell
cd app; flutter test test/stickies/android; cd ..
cd app; flutter build apk --debug; cd ..
cd app; flutter run -d <android-device-id>; cd ..
```
Manual on the phone: add both widgets from the launcher; choose a sticky for the single widget; tick a checkbox in the widget → the note file changes
(check in Tephra and on the PC after sync); edit the sticky on the PC → after sync the widget updates within 1 minute (open/close Tephra once if the
phone is in Doze). Resize the single widget. Reboot the phone → widgets still show content.

**Pitfalls.**
- Each `PendingIntent` must be distinct: the URIs differ per row (widgetId + line), which makes them distinct; do not reuse one URI for several rows.
- Keep JSON small (< 16 KB per key).
- The background callback must not touch Riverpod or any UI.

---

### 04.14 — Android floating sticky bubble (draw over other apps)

**Purpose.** One sticky can float over other apps as a bubble that expands into a mini editor.

**Files.**
- `app/lib/main.dart` (the `overlayMain` entry point must be declared here)
- `app/lib/stickies/android/overlay_app.dart`
- `app/lib/stickies/android/overlay_protocol.dart`
- `app/lib/stickies/android/overlay_bridge.dart` (main-app side)
- `app/lib/core/platform/overlay_service.dart` (Android implementation)
- `app/android/app/src/main/AndroidManifest.xml`
- `app/test/stickies/android/overlay_protocol_test.dart`
- `app/test/stickies/android/overlay_bridge_test.dart`

**Implementation.**
1. Entry point: `flutter_overlay_window` starts a separate engine at the Dart function `overlayMain` in the **root library** (`lib/main.dart`):
   ```dart
   @pragma('vm:entry-point')
   void overlayMain() => runOverlayApp();   // defined in stickies/android/overlay_app.dart
   ```
2. Manifest: add exactly what the plugin README lists for the installed version — at least `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, the special-use
   foreground-service permission required on Android 14+, and the plugin's `OverlayService` `<service>` entry with its `foregroundServiceType`.
3. Permission flow (`AndroidOverlayService`): `hasPermission` → `FlutterOverlayWindow.isPermissionGranted()`; `requestPermission` → first show our explanation
   dialog ("Tephra needs 'Display over other apps' to float a sticky. You can turn it off any time."), then `FlutterOverlayWindow.requestPermission()`.
4. Protocol (`overlay_protocol.dart`): same idea as 04.8, JSON over `FlutterOverlayWindow.shareData` / `overlayListener`:
   `{"v":1,"type":"open","path","text","hash","color","locked"}` (main → overlay), `update` (main → overlay), `contentChanged {path,text,baseHash}` (overlay → main),
   `ack {path,hash}` (main → overlay, reply to each `contentChanged`), `close {path}` (overlay → main), `ping`/`pong`.
5. Writer rule: **the main app engine is the writer**. The overlay sends `contentChanged` and waits up to 1.5 s for `ack`. If no `ack` arrives (the main
   engine was destroyed while the overlay service kept running), the overlay itself writes with `StickyFileWriter.writeIfUnchanged` using `HeadlessConfig`
   (only `fsKind == io`; for `saf` it keeps the text and shows "Open Tephra to save"). On a hash mismatch it writes a conflict copy of its own text
   (Phase 3 naming) instead of overwriting.
6. `OverlayBridge` (main app side, Android only) — same handling as the hub's `contentChanged` branch (reuse the `TextMerger` logic by extracting the hub's
   apply algorithm into a shared `StickyEditApplier` class in `app/lib/stickies/data/sticky_edit_applier.dart`; the hub from 04.9 must use it too — refactor
   and keep the hub tests green).
7. Overlay UI (`overlay_app.dart`):
   - Collapsed: 56 dp circle in the sticky colour with a note icon. `showOverlay(height: 56dp-in-px, width: same, enableDrag: false, flag: OverlayFlag.defaultFlag,
     positionGravity: PositionGravity.auto)` — drag is implemented by us so we know where it ends: `GestureDetector.onPanUpdate` → `FlutterOverlayWindow.moveOverlay(...)`.
     Drag end within 120 px of the bottom edge → close the bubble (show a "×" target at the bottom while dragging).
   - Tap → expanded: `resizeOverlay(300, 420, true)` and `updateFlag(OverlayFlag.focusPointer)` (needed so the text field gets the keyboard); header with
     title, collapse button, "Open in Tephra" (launches `tephra://open?...` via the main activity) and close; body = `StickyMiniRenderer` / `TextField` edit mode
     exactly like the Windows sticky window (body-only editing, checkboxes, locked rules).
   - Collapse → `updateFlag(OverlayFlag.defaultFlag)` and resize back to 56 dp.
8. Commands: `sticky.open-window` on Android → `OverlayService.showBubble(path)` (one bubble at a time; showing another replaces the first after flushing it).

**Tests.**
- `overlay_protocol_test.dart`: round trip of every message; unknown/old messages ignored.
- `overlay_bridge_test.dart`: `contentChanged is applied and acked`, `stale base merges via StickyEditApplier`, `close forgets bubble`.
- An overlay-side unit test for the writer fallback: `no ack within timeout writes via StickyFileWriter` and `hash mismatch writes conflict copy` (use fake timers and `MemoryVaultFileSystem`).

**Verify.**
```powershell
cd app; flutter test test/stickies/android; cd ..
cd app; flutter run -d <android-device-id>; cd ..
```
Manual: grant the permission, float a sticky, go to Chrome, expand the bubble, type and tick a checkbox, collapse, drag to the bottom to dismiss;
open Tephra → the note contains the edits. Force-stop Tephra's activity (swipe away) with the bubble open, type in the bubble → note still saved.

**Pitfalls.** Without `OverlayFlag.focusPointer` the keyboard never opens; with it, touches outside the overlay may be swallowed — only use it while expanded.

---

### 04.15 — Capture screen and share-to-Tephra (Android)

**Purpose.** Receive text, links, images and files from other apps into a new note or today's daily note; a capture screen reused by the tile, widget and shortcut.

**Files.**
- `app/lib/capture/capture_service.dart`
- `app/lib/capture/capture_screen.dart`
- `app/lib/capture/share_intake.dart`
- `app/lib/capture/providers.dart`
- `app/lib/core/platform/share_intent_service.dart` (Android implementation)
- `app/android/app/src/main/AndroidManifest.xml` (intent filters, `launchMode`)
- `app/test/capture/capture_service_test.dart`
- `app/test/capture/share_intake_test.dart`

**Implementation.**
1. Manifest, on `MainActivity`: set `android:launchMode="singleTask"` (required by `receive_sharing_intent` so shares reuse the running activity) and add:
   ```xml
   <intent-filter>
     <action android:name="android.intent.action.SEND"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <data android:mimeType="text/plain"/>
   </intent-filter>
   <intent-filter>
     <action android:name="android.intent.action.SEND"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <data android:mimeType="image/*"/>
   </intent-filter>
   <intent-filter>
     <action android:name="android.intent.action.SEND"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <data android:mimeType="*/*"/>
   </intent-filter>
   <intent-filter>
     <action android:name="android.intent.action.SEND_MULTIPLE"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <data android:mimeType="*/*"/>
   </intent-filter>
   <intent-filter>
     <action android:name="android.intent.action.VIEW"/>
     <category android:name="android.intent.category.DEFAULT"/>
     <category android:name="android.intent.category.BROWSABLE"/>
     <data android:scheme="tephra"/>
   </intent-filter>
   ```
   (The last filter is for `app_links` deep links from the Quick Settings tile and shortcuts.)
2. `AndroidShareIntentService` maps `receive_sharing_intent` (`ReceiveSharingIntent.instance.getInitialMedia()`, `getMediaStream()`, `reset()`; check the
   `SharedMediaFile` fields and `SharedMediaType` values in the API reference) to `SharedItem`s: type text/url → `SharedText(path-or-message)`;
   image/video/file → `SharedFile(path, mimeType)`. Call `markHandled()` (→ `reset()`) after processing the initial share.
3. `share_intake.dart` (pure): builds a `CaptureDraft` from shared items:
   ```dart
   final class CaptureDraft { const CaptureDraft({required this.text, required this.files, this.title}); final String text; final List<SharedFile> files; final String? title; }
   CaptureDraft draftFromShare(List<SharedItem> items);
   ```
   Rules: texts joined with `\n\n`; a text that is a single URL (`^https?://\S+$`) becomes `<url>` on its own line (Obsidian autolink); title = first 60 chars of the
   first text line with characters invalid in file names removed, or `Shared YYYY-MM-DD HHmm` when there is no text.
4. `CaptureService`:
   ```dart
   final class CaptureService {
     Future<VaultPath> saveAsNewNote(CaptureDraft d);         // new note in the vault's new-note location, name = title (unique suffix " 1"…)
     Future<VaultPath> appendToDailyNote(CaptureDraft d);     // today's daily note via the daily-notes service (created from template if missing)
     Future<VaultPath> appendToInbox(CaptureDraft d);         // settings.inboxPath (created if missing)
   }
   ```
   Appended block format: `\n- HH:mm ` + first line of text, following lines indented by two spaces, then one line per attachment `  ![[name.ext]]`.
   New-note format: text, blank line, one `![[name.ext]]` per attachment.
   Attachments: copy each `SharedFile` into the vault with the existing Phase 1 attachment service (conventions §6.7 folder rule relative to the target note,
   Obsidian naming for images `Pasted image YYYYMMDDHHmmss.ext`, original file name for other files with a unique suffix). Delete nothing from the source.
5. `CaptureScreen` (route `/capture`, phone layout full screen, desktop layout dialog): multiline text field prefilled with the draft text, attachment chips,
   a segmented control "Daily note / New note / Inbox" defaulting to `shareTarget` (share) or `quickCaptureTarget` (quick capture), Save button.
   After saving from a share or a tile launch: show a snackbar "Saved to <note>" with "Open", and if the app was launched only for the capture, `SystemNavigator.pop()` after 1.5 s.
6. Wiring: on start and on each share → `CaptureScreen` with `draftFromShare(items)`; `CaptureLink` (`tephra://capture`) → empty draft with `quickCaptureTarget`.
7. If no vault is open (first run), show "Open or create a vault first" and keep the shared items in memory until a vault opens.

**Tests.**
- `share_intake_test.dart`: `single url becomes autolink`, `multiple texts joined`, `files only uses date title`, `title strips invalid chars`, `long title cut at 60`.
- `capture_service_test.dart` (fake daily-notes service + attachment service + `MemoryVaultFileSystem`): `append to existing daily note keeps previous bytes` (prefix identical),
  `creates daily note from template when missing`, `new note name collision adds suffix`, `attachment embed lines added`, `inbox created when missing`.

**Verify.**
```powershell
cd app; flutter test test/capture; cd ..
cd app; flutter run -d <android-device-id>; cd ..
```
Manual: in Chrome, Share → Tephra on a web page → capture screen shows the URL → Save → today's daily note ends with `- HH:mm <https://…>`.
Share a photo from Gallery → new note with `![[Pasted image ….jpg]]` and the image in the attachment folder. Share two files at once (SEND_MULTIPLE).

**Pitfalls.** Shared file paths point to a cache copy made by the plugin; copy the bytes immediately, the cache can be cleared later.

---

### 04.16 — Quick Settings tile, persistent quick-note notification, quick-capture widget, app shortcuts (Android)

**Purpose.** Capture from anywhere on the phone in one or two taps.

**Files.**
- `app/android/app/src/main/kotlin/com/tephra/app/QuickNoteTileService.kt`
- `app/android/app/src/main/kotlin/com/tephra/app/QuickCaptureWidgetProvider.kt`
- `app/android/app/src/main/res/layout/widget_quick_capture.xml`
- `app/android/app/src/main/res/xml/quick_capture_widget_info.xml`
- `app/android/app/src/main/res/drawable/ic_tile_note.xml`
- `app/android/app/src/main/AndroidManifest.xml`
- `app/lib/capture/quick_note_reply.dart`
- `app/lib/core/platform/app_shortcut_service.dart` (Android implementation)
- `app/lib/core/platform/notification_service.dart` (persistent notification)
- `app/test/capture/quick_note_reply_test.dart`

**Implementation.**
1. Quick Settings tile `QuickNoteTileService : TileService()`:
   - `onStartListening()` → `qsTile.state = Tile.STATE_INACTIVE; qsTile.updateTile()`.
   - `onClick()` → intent `Intent(Intent.ACTION_VIEW, Uri.parse("tephra://capture"), this, MainActivity::class.java)` with `FLAG_ACTIVITY_NEW_TASK`;
     on API 34+ call `startActivityAndCollapse(PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))`;
     below 34 call the deprecated `startActivityAndCollapse(intent)` (annotate with `@Suppress("DEPRECATION")` and a comment).
   - Manifest:
     ```xml
     <service android:name=".QuickNoteTileService" android:exported="true" android:label="@string/tile_quick_note"
              android:icon="@drawable/ic_tile_note" android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
       <intent-filter><action android:name="android.service.quicksettings.action.QS_TILE"/></intent-filter>
     </service>
     ```
2. Quick-capture widget (decision: RemoteViews cannot contain a text input, so the widget is a one-line "Quick note…" bar that opens the capture screen):
   `QuickCaptureWidgetProvider : HomeWidgetProvider()`; layout `widget_quick_capture.xml` = rounded bar with a pencil icon and the text "Quick note…" plus a small
   "Today" button (opens `tephra://daily`); bar click → `HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("tephra://capture"))`.
   Info xml: `minWidth 180dp`, `minHeight 40dp`, `targetCellWidth 4`, `targetCellHeight 1`, `resizeMode="horizontal"`. Receiver entry like 04.13.
3. Persistent "Quick note" notification (setting `capture.persistentNotification`, off by default; Android only):
   ongoing notification on channel `quick_note` (importance low, no sound), id `900001`, title "Quick note", action `AndroidNotificationAction('quick_note_reply', l10n reply label,
   inputs: [AndroidNotificationActionInput(label: 'Type a note')], showsUserInterface: false)` and tapping the notification body opens `tephra://capture`.
   Show it on app start when the setting is on; on Android 14+ ongoing notifications can be dismissed by the user — that is fine; re-show it on next app start.
4. `quick_note_reply.dart`:
   ```dart
   @pragma('vm:entry-point')
   void quickNoteReplyHandler(NotificationResponse r) { ... }   // passed as onDidReceiveBackgroundNotificationResponse (04.12)
   Future<VaultPath?> appendQuickNote(VaultFileSystem fs, HeadlessConfig cfg, String text, DateTime now);   // pure-ish, testable
   ```
   If `r.actionId == 'quick_note_reply'` and `r.input` is non-empty: read `HeadlessConfig` (needs `fsKind == io`), target = today's daily note path computed
   from `cfg.dailyNote` (folder + format; if the note does not exist, create it **without** the template — the template engine is not available headless — and log it)
   or `cfg.inboxPath`; append `\n- HH:mm <text>` with `StickyFileWriter.append`. Then re-show the notification (Android clears the reply UI otherwise).
   Extract the daily-note path formatting used here into a pure function shared with the Phase 2 daily-notes service if that service does not already expose one
   (do not duplicate the format logic; refactor the service to call the shared function).
5. App shortcuts (`AndroidAppShortcutService` over `quick_actions`): `QuickActions().setShortcutItems([ShortcutItem(type: 'new-note', localizedTitle: l10n.shortcutNewNote, icon: 'ic_shortcut_note'),
   ShortcutItem(type: 'daily', localizedTitle: l10n.shortcutTodaysNote, icon: 'ic_shortcut_daily'), ShortcutItem(type: 'new-sticky', localizedTitle: l10n.shortcutNewSticky, icon: 'ic_shortcut_sticky')])`
   and `initialize((type) => onShortcut(type))`. Add the three icons as vector drawables `res/drawable/ic_shortcut_note.xml`, `ic_shortcut_daily.xml`, `ic_shortcut_sticky.xml`.
   Route: `new-note` → the existing "new note" command, `daily` → `DailyLink`, `new-sticky` → `NewStickyLink`.
6. Strings in `res/values/widget_strings.xml`: `tile_quick_note` "Quick note", `widget_quick_capture_label` "Tephra quick note", `widget_sticky_label` "Tephra sticky",
   `widget_stack_label` "Tephra stickies", `widget_choose_sticky` "Tap to choose a sticky", `widget_sticky_description`, `widget_stack_description`.
   (Android resource strings are the one place outside `app_en.arb` where user text lives, because Kotlin cannot read ARB; keep them in this one file.)

**Tests.** `quick_note_reply_test.dart` (`MemoryVaultFileSystem`, fixed time 2026-10-11 14:05): `appends to existing daily note`, `creates daily note without template`, `inbox target`,
`saf config does nothing`, `multi-line reply indented`.

**Verify.**
```powershell
cd app; flutter test test/capture; cd ..
cd app; flutter run -d <android-device-id>; cd ..
```
Manual: add the "Quick note" tile to Quick Settings → tap → capture screen opens over the current app → save → returns. Turn on the persistent notification →
reply "buy milk" from the shade with Tephra swiped away → today's daily note ends with `- 14:05 buy milk`. Long-press the launcher icon → three shortcuts work.
Add the quick-capture widget → tap → capture screen.

**Pitfalls.** `onDidReceiveBackgroundNotificationResponse` runs in its own isolate; call `DartPluginRegistrant.ensureInitialized()` first and never use Riverpod there.

---

### 04.17 — Auto-archive expired stickies, phase integration, demo

**Purpose.** Expired stickies move to `Stickies/Archive/` automatically; finish the phase with docs and the demo.

**Files.**
- `app/lib/stickies/data/sticky_archiver.dart`
- `app/lib/stickies/providers.dart`
- `app/test/stickies/data/sticky_archiver_test.dart`
- `README.md` (feature list line), `PROGRESS.md`

**Implementation.**
1. `StickyArchiver`:
   ```dart
   final class StickyArchiver {
     StickyArchiver({required StickyRepository repo, required RenameService rename /* the Phase 2 link-updating move service */, required Clock clock, required String stickyFolder});
     Future<List<VaultPath>> archiveExpired();   // returns moved paths
   }
   ```
   A sticky is expired when `meta.expire != null` and `expire < today` (local date from the clock; a sticky expiring today stays until tomorrow).
   Target = `<stickyFolder>/Archive/<name>`; on name collision add ` 1`, ` 2` before `.md`. Move with the Phase 2 rename/move service so links to it update.
   Frontmatter is not changed (the folder alone marks it archived; unarchiving = moving it back out, which the user can do in the explorer).
   Close its floating window/bubble (handled by `StickyMoved`/`StickyRemoved`), cancel its reminder (handled by the scheduler reconcile).
2. Triggers: after the vault opens (after the first sticky load), on `AppLifecycleState.resumed`, and a `Timer` that fires at the next local midnight + 1 minute and then every 24 h.
   Show a snackbar "Archived N expired stickies" with "Show" (opens the archive folder in the explorer) when N > 0.
3. Phase integration checks: every command registered in 04.4 is now available on its platforms (`isAvailable` real); remove all temporary debug code;
   update `README.md` feature list; add to `THIRD_PARTY_NOTICES.md` (regenerate with the licence tool).

**Tests.** `sticky_archiver_test.dart`: `expired yesterday moves`, `expiring today stays`, `no expiry stays`, `collision adds suffix`, `uses rename service` (fake records the call), `already archived ignored`.

**Verify.**
```powershell
dart format --output=none --set-exit-if-changed app/lib app/test packages tool
flutter analyze --fatal-infos
cd app; flutter test; cd ..
dart run tool/check_licenses.dart
cd app; flutter build windows --release; cd ..
cd app; flutter build apk --release; cd ..
```
All green; then run the demo script below on the real phone and PC.

**Pitfalls.** Never archive while the vault is still loading (the repository's `start()` must have completed).

---

## Demo script

Run with the release builds on the Windows PC and the real Android phone, both signed in to the same Drive-synced vault (Phase 3).
Record each line's result (pass/fail + notes) in `PROGRESS.md`.

1. PC: focus Notepad, press `Ctrl+Alt+N` → a new floating sticky appears in edit mode. Type `Call the printer guy`, Enter, `- [ ] ask about toner`.
2. PC: click the pin button → the window stays on top of Notepad when Notepad is clicked.
3. PC: "⋯" → set colour pink; in the main window run `sticky.set-reminder` → "In 10 minutes" replaced by a custom time 2 minutes ahead.
4. PC: wait → a Windows toast "Sticky …" appears on time → click it → Tephra opens that sticky.
5. PC: Sync now (or wait ≤ 60 s). Phone: the single-sticky widget (configured to this sticky beforehand, or configure it now) shows the title, the text and `☐ ask about toner` on a pink background.
6. Phone: tap `☐ ask about toner` in the widget → it becomes `☑`. Wait for sync → PC floating sticky shows `- [x] ask about toner` within 60 s.
7. Phone: in Chrome, share a web page → Tephra → Save (Daily note) → after sync the PC shows the link appended to today's daily note.
8. PC: open the sticky board → the pink sticky is a card; drag it; "By colour" → cards group; Undo.
9. Open the vault in Obsidian on the PC → `Stickies/Sticky board.canvas` shows the cards in the same colours.
10. PC: quit Tephra from the tray, restart it → the floating sticky reopens at the same place (on the same monitor).
11. Phone: reboot → widgets still show their stickies; a reminder set 5 minutes ahead before the reboot fires with Tephra not opened.

## Exit gate

- [ ] Demo script lines 1–11 pass on a real Windows PC and a real Android phone (results recorded in `PROGRESS.md`).
- [ ] Stickies survive reboot on both platforms: Windows floating windows restore with their positions (incl. missing-monitor clamp test); Android widgets show content after reboot.
- [ ] Reminders fire on time on Android with the app killed (swiped away) — within 1 minute with exact alarms allowed; behaviour with exact alarms denied documented.
- [ ] Windows reminder behaviour with the app fully quit recorded (fires, or the "requires tray" note is in `PROGRESS.md`).
- [ ] Sticky round-trip tests pass: pin/unpin leaves note bytes identical (LF, CRLF, BOM, existing frontmatter).
- [ ] Multi-window consistency tests (`sticky_hub_test.dart`) pass, and the 1-minute manual alternate-typing test produced identical text in both windows and on disk.
- [ ] Widget update after a remote change verified on the phone (edit on PC → widget updates after sync).
- [ ] `Stickies/Sticky board.canvas` opens in Obsidian and shows the stickies.
- [ ] `flutter analyze --fatal-infos` clean, `dart format` clean, all package and app tests pass, licence check passes.
- [ ] Phase 2 performance budgets still met (re-run the Phase 2 measurements; record numbers).
- [ ] `phase-04` merged into `main` with `--no-ff`, tagged `v0.04.0`.

## Hand-off

Record in `PROGRESS.md` and report to the human:
- The discovered API names table (from "Before you start").
- Whether the `window_manager` fork was needed.
- Windows reminder behaviour with the app quit.
- Exact-alarm behaviour per Android version tested.
- Known limitations: one floating bubble at a time on Android; widget checkbox toggling and notification replies work only for vaults opened with
  "All files access" (`fsKind: io`), SAF vaults open the app instead; headless daily-note creation skips the template; each Windows floating sticky is a full Flutter engine (memory).
- Conventions gaps to raise with the human (do not edit the conventions yourself):
  1. §5.9 lists the platform services; this phase adds two more interfaces of the same kind, `ShareIntentService` and `AppShortcutService`.
  2. §6.6 `.tephra/stickies.json` has no field to mark a window hidden; "Hide all" is stored per device as the app setting `stickies.hiddenAll` instead.
  3. The `screen` field in §6.6 stores a composite key `"<display name>|<W>x<H>"` because display ids are not stable across reconnects.
  4. `NoteIndex` (§7.4) has no property query; stickies are found through `SearchEngine` with `[tephra-sticky:true]`.
- Phase 5 (import & export) uses `tephra_io` and does not depend on anything from this phase.
