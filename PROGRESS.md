# PROGRESS

Single source of truth for where the build is. Gemini updates this file after **every** step (see GEMINI.md §3).

Format rules:
- Tick a step `[x]` only when its Verify block passed, format + analyze are clean, tests pass, and it is committed.
- After each ticked step add an indented line: `- notes: <what was built, anything surprising, commit hash>`.
- Exit-gate items record measured numbers where the item asks for them (e.g. `- [x] Search < 200 ms — measured 120 ms`).
- Things not verified on a real Android device are marked `(not verified on device)`.
- Anything blocked: write `BLOCKED: <reason>` under the step and stop (GEMINI.md §5).

## Current status

- Current phase: **01**
- Current step: **01.2**
- Last gate passed: **00**

## Phase 00 — Foundation

Instructions: `instructions/phase-00-foundation.md`

### Steps

- [x] 00.1 Verify the machine
  - notes: Flutter 3.47.7 stable, Dart 3.13.5, flutter doctor fully green, Windows desktop available, created Android emulator tephra_api36 (Android 36 x86_64), real phone not connected.
- [x] 00.2 Git repository, ignore and attribute files
  - notes: git repo initialized on main, core.autocrlf false, .gitignore and .gitattributes created, branched to phase-00 (commit e2b6e57).
- [x] 00.3 Workspace root: pubspec and analysis options
  - notes: root pubspec.yaml with 8 workspace members and dependencies, analysis_options.yaml with strict analyzer and linter rules.
- [x] 00.4 Create the Flutter app and set its identity
  - notes: Flutter app created, identity com.tephra.app / Tephra configured on Android, Windows, and Web, pubspec set up for workspace.
- [x] 00.5 Create the seven packages
  - notes: created 7 pure-Dart packages with exact workspace dependency graph, verified no stray linter or template files.
- [x] 00.6 First resolve, analyze and format baseline
  - notes: workspace resolves cleanly with single root lockfile, all dependencies added to app, analyze clean, format clean.
- [x] 00.7 App shell: logging, crash handlers, theme, localisation, welcome screen
  - notes: logging with file rotation and crash handlers, theme, l10n, welcome screen with widget tests, verified Windows launch and file logging.
- [x] 00.8 Licence checker and third-party notices
  - notes: license classifier with 12 tests, check_licenses tool created, verified 85 packages all allowed, generated THIRD_PARTY_NOTICES.md.
- [x] 00.9 Dev preview entry point and README
  - notes: created tool/dev.dart with LAN IP detection, README.md with Install/Run blocks, verified web server on port 8093 and 8097 override.
- [x] 00.10 Register in Dev Launcher
  - notes: registered project tephra-gemini as "Tephra (Gemini build)" on port 8093 (auto-start off), verified startup and HTTP 200 in Dev Launcher.
- [x] 00.11 CI workflow (verified locally)
  - notes: created .github/workflows/ci.yml; CI verified locally by running the same commands; not yet run on GitHub (no remote); gitleaks-action note recorded.
- [x] 00.12 Fixture vault: `test_vaults/syntax/`
  - notes: created test_vaults/README.md and 24 syntax notes byte-exact without BOM, LF line endings.
- [x] 00.13 Fixture vault: `test_vaults/edge/` and generated attachments
  - notes: created png_writer, huge_note, gen_test_vaults script, test_vaults_test with 5 tests passing, generated edge vault and attachments.
- [x] 00.14 Benchmark vault generator and `test_vaults/real/`
  - notes: created bench_generator and gen_bench_vault CLI, bench_generator_test with 6 tests passing, generated real/ (300 notes, committed) and bench/ (10,000 notes in 43.8s, git-ignored).
- [x] 00.15 First Android and Windows builds, run on devices
  - notes: flutter build windows --debug and flutter build apk --debug both succeeded; verified running on Windows and on Android emulator tephra_api36 (label "Tephra", welcome screen, tephra.log logging confirmed); not verified on physical device.
- [x] 00.16 Editor spike (the key decision)
  - notes: Built standalone spike with re_editor (A) and TextField (B). Profile measurements on Windows on 5,000-line note: A typing build p95=12.12ms (passes H2), scroll=62.0 FPS; B typing build p95=155,058ms (fails H2). Android emulator debug measured A build p95=319ms, scroll=1.2 FPS (marked emulator/debug — not valid for the gate; physical device not connected). Soft S1 (WidgetSpan inline) fails for A due to direct ParagraphBuilder use (overlay approach required for Live Preview). Created docs/spikes/editor.md and docs/decisions/0001-editor-engine.md accepting re_editor.
- [x] 00.17 Platform spike: drift + SQLite FTS5
  - notes: Built standalone spike docs/spikes/drift_spike with drift 2.35.2 and drift_flutter 0.3.1 (SQLite 3.53.4 with ENABLE_FTS5 verified). Windows profile benchmark on 10,000 notes: unicode61 insert 12.2s, trigram insert 21.8s; all query medians between 1.65ms and 8.83ms (passes < 50ms budget by 5x-25x). Android emulator debug measured queries 112-300ms (marked emulator/debug — not valid for the gate; physical device not connected). Trigram substring search on Bangla matched 106 records in 2.22ms median. Created docs/spikes/drift-fts5.md.
- [x] 00.18 Platform spike: Android shared storage and file watching
  - notes: Built standalone spike docs/spikes/android_storage_spike. Verified MANAGE_EXTERNAL_STORAGE grant on Android 16 (API 36) emulator. Verified atomic write and read in /storage/emulated/0/Documents/TestVault/hello.md. Benchmarked all 3 watcher variants against external modifications (modify, add, remove) via ADB shell: DirectoryWatcher latencies 655-996ms (passes < 1s budget), Directory.watch (dart:io) latencies 22-56ms, PollingDirectoryWatcher latencies 57-417ms. Selected DirectoryWatcher (package:watcher) for Phase 1. Created docs/spikes/android-storage.md.
- [x] 00.19 Platform spike: Windows tray icon, second window, file watcher
  - notes: Built standalone spike docs/spikes/windows_desktop_spike with tray_manager 0.8.0, desktop_multi_window 0.3.1, and watcher 1.2.1. Tray icon initialized with context menu. Spawned secondary window (StickySpikeApp) with JSON arguments. Registered sub-window plugin callback in windows/runner/flutter_window.cpp. Benchmarked DirectoryWatcher on test_vaults/real: modify 135ms, create 155ms, rename 135ms, delete 161ms. Created docs/spikes/windows-desktop.md.

### Exit gate

- [x] `flutter analyze --fatal-infos` → `No issues found!` and `dart format --output=none --set-exit-if-changed app/lib app/test packages tool` exits 0.
- [x] `dart test tool/test` (23 passed) and `cd app; flutter test` (10 passed) pass.
- [x] `dart run tool/check_licenses.dart` exits 0 (85 allowed, 0 not allowed) and `THIRD_PARTY_NOTICES.md` is committed.
- [x] `.github/workflows/ci.yml` exists; every command it runs was executed locally and passed (GitHub run pending until the human creates the private repository).
- [x] `flutter build apk --debug` (55.8s) and `flutter build windows --release` (87.4s) both succeed locally.
- [x] Placeholder app runs on Windows and on the Android emulator; (not verified on device).
- [x] `docs/decisions/0001-editor-engine.md` exists, names the chosen engine (re_editor), Windows typing p95 = 12.12 ms; Android emulator debug measured 319 ms (marked emulator/debug — not valid for the gate; not verified on device).
- [x] `docs/spikes/drift-fts5.md`: FTS5 present; Windows profile query medians 1.65–8.83 ms; Android emulator debug measured 112–300 ms (marked emulator/debug — not valid for the gate; not verified on device).
- [x] `docs/spikes/android-storage.md`: All-files-access granted, read/write in `Documents/TestVault` works, and DirectoryWatcher selected for Phase 1.
- [x] `docs/spikes/windows-desktop.md` exists with tray (PASS), second-window (PASS, arguments passed), and watcher results (135–161 ms).
- [x] `test_vaults/syntax` (24 notes + 4 attachments), `test_vaults/edge` (generated) and `test_vaults/real` (300 notes) are committed; `test_vaults/bench` is generated and ignored.
- [x] Project "Tephra (Gemini build)" is registered in Dev Launcher (auto-start off), starts, and its log shows `Local: http://localhost:8093/`.
- [x] `phase-00` merged into `main` with `git merge --no-ff phase-00`, tagged `v0.00.0`, and the human has been told the results.

### Phase notes

- Phase 00 complete. Workspace, packages, tooling, test vaults, and all 4 platform spikes (editor engine, SQLite FTS5, Android storage, Windows multi-window/tray) de-risked and documented. All Exit Gate checks verified locally.

## Phase 01 — Vault, files & basic editor

Instructions: `instructions/phase-01-vault-editor.md`

## Phase 1 inputs

- `ENGINE`: `A` (`re_editor`)
- `ANDROID_WATCHER`: `native` (`DirectoryWatcher`)
- `ENGINE_HOOKS`: typed-text entry: `CodeLineEditingController.edit(TextEditingValue value)`; Enter: `CodeLineEditingController.applyNewLine()`; Tab: `CodeLineEditingController.applyIndent()` / `applyOutdent()`; undo grouping: `CodeLineEditingController.runRevocableOp(VoidCallback op)`; shortcut mapping: `CodeShortcutsActivatorsBuilder` / `CodeEditor.shortcutOverrideActions`; per-line `buildTextSpan`: `buildTextSpan({required BuildContext context, required int index, required TextSpan textSpan, required TextStyle style})`
- `HIGHLIGHTER`: `re_highlight`

### Steps

- [x] 01.1 Branch, dependencies, package skeleton folders
  - notes: Added Phase 1 dependencies to tephra_core, tephra_vault, tephra_markdown, and app; added Android storage permissions and requestLegacyExternalStorage; updated license classifier for MPL-2.0; verified 139 allowed packages.
- [ ] 01.2 `tephra_core`: exceptions, clocks, `contentHash`, `VaultPath`
- [ ] 01.3 `tephra_vault`: `TextDocument`, ignore rules, interface and models
- [ ] 01.4 `IoVaultFileSystem` and `MemoryVaultFileSystem`
- [ ] 01.5 Watcher: debounce, merge rules, self-write suppression, Android watcher choice
- [ ] 01.6 `tephra_markdown`: AST, options, `LineIndex`, frontmatter, parser utilities
- [ ] 01.7 Block parser (CommonMark containers + GFM tables + Obsidian blocks)
- [ ] 01.8 Inline parser
- [ ] 01.9 `ParsedNote`, `MarkdownParser`, convenience lists, async parse helper
- [ ] 01.10 CommonMark conformance, Obsidian syntax cases, `test_vaults/syntax`
- [ ] 01.11 App services: JSON stores, app and vault settings, platform services, vault session providers
- [ ] 01.12 Vault picker, create/open, recent vaults, Android permission flow, `.obsidian` import
- [ ] 01.13 Workspace: adaptive shell, tabs, history, splits, view registry
- [ ] 01.14 Commands, palette, quick switcher, hotkeys, settings screen
- [ ] 01.15 Note documents (buffers) and the reading view: structure and block widgets
- [ ] 01.16 Reading view: inline rendering, callouts, tasks, links, images/embeds, goldens
- [ ] 01.17 File explorer
- [ ] 01.18 Editor: `EditorController`, engine adapter, Source mode with syntax highlighting
- [ ] 01.19 Editing helpers, shortcuts, commands, find & replace
- [ ] 01.20 Autosave, save indicator, external changes, three-way merge, conflict dialog
- [ ] 01.21 Attachments (paste, drop, pick) and the phone keyboard toolbar
- [ ] 01.22 Round-trip proof, crash safety, performance budget, demo and exit gate

### Exit gate

- [ ] All 15 demo steps pass on Windows; steps 13 and 15 pass on Android (or "not verified on device" is recorded and the human informed). **(PHASE_PLAN: all demo steps pass on Android and Windows)**
- [ ] **Round-trip, 0 changed bytes:** `dart run tool/roundtrip_check.dart test_vaults/syntax test_vaults/edge test_vaults/real` reports `changed=0 parseErrors=0` for all three vaults, and `cd app; flutter test test/roundtrip` passes (`ROUNDTRIP … writes_without_edit=0 changed_bytes=0`).
- [ ] **Every syntax element renders correctly in reading view:** `flutter test test/reading` passes — the 24 semantic note tests and the 27 golden images in `app/test/reading/goldens/` — and the golden files are committed.
- [ ] **Parser:** `cd packages/tephra_markdown; dart test` passes; CommonMark conformance ≥ 85 % overall (number recorded), **100 %** in ATX headings, Setext headings, Fenced code blocks, Thematic breaks, Block quotes, Code spans and Backslash escapes; the Obsidian case table (~200 rows) passes; fuzz tests pass; the 31 offset cases pass; notes over 50,000 characters parse through `Isolate.run` (`ParseService`).
- [ ] **File layer:** `cd packages/tephra_vault; dart test` passes 3 times in a row (watcher tests are not flaky); the atomic-write crash tests pass; `dart test packages/tephra_core` passes with ≥ 28 `VaultPath` tests.
- [ ] **Typing budget:** Source mode, 5,000-line note (`huge-5000-lines.md` content), profile build on the **phone**: typing `max(build, raster)` p95 ≤ **16.0 ms** (median of 3 runs; numbers in `PROGRESS.md`); the Windows profile number is recorded and also ≤ 16.0 ms.
- [ ] **External edit pickup < 1 s:** `external_pickup_test` prints < 1000 ms on Windows; on the phone the `adb shell echo >>` edit appears in the open note in < 1 s (`ANDROID_WATCHER` choice recorded).
- [ ] **No data loss on kill:** `dart run tool/kill_test.dart --rounds 20` → `KILL 20/20 ok`; the kill-during-typing procedure ran 20 times on Windows (20/20) and 20 times on the phone (20/20 or "not verified on device"); loss window ≤ 1.5 s.
- [ ] `flutter analyze --fatal-infos` → `No issues found!`; `dart format --output=none --set-exit-if-changed app/lib app/test packages tool` exits 0; `cd app; flutter test --exclude-tags golden` and `flutter test --tags golden` pass; `dart test tool/test` passes; every package's `dart test` passes.
- [ ] `dart run tool/check_licenses.dart` exits 0 (new packages: `crypto`, `watcher`, `yaml`, `re_highlight`, `re_editor` (engine A only), `diff_match_patch`, `url_launcher`, `file_picker`, `image_picker`, `pasteboard`, `desktop_drop`, `permission_handler`, `device_info_plus`, `scrollable_positioned_list`); `THIRD_PARTY_NOTICES.md` regenerated and committed, including the "Test data" note for the CommonMark spec.
- [ ] `flutter build apk --debug` and `flutter build windows --release` both succeed.
- [ ] Android: the explanation screen, "All files access" grant and the app-private fallback work on a device/emulator (or "not verified on device"); read/write/watch in the shared vault folder works.
- [ ] Obsidian interop: the `Demo` vault opens in Obsidian unchanged and vice versa (**[human]**; recorded) and `git status --porcelain test_vaults` is empty.
- [ ] `PROGRESS.md` lists all 22 steps ticked, the "Phase 1 inputs", Conflicts and Ideas sections, and the numbers above.
- [ ] `phase-01` merged into `main` with `git merge --no-ff phase-01`, tagged `v0.01.0`, and the human told the results. **Stop; wait for "continue".**

### Phase notes

-

## Phase 02 — Links, index, search & Live Preview (MVP)

Instructions: `instructions/phase-02-links-index-search.md`

### Steps

- [ ] 02.1 Add drift + sqlite3 and prove FTS5, trigram and Bangla tokenisation
- [ ] 02.2 Index schema: drift tables, FTS tables, indices, migrations, database open + recovery
- [ ] 02.3 Index models and `LineIndex`
- [ ] 02.4 Note extraction: `ParsedNote` → index rows
- [ ] 02.5 Link resolver, `NameTable`, heading and block matching
- [ ] 02.6 `IndexerCore`: full index, reconcile, incremental updates, dirty targets (in-process)
- [ ] 02.7 `NoteIndex` facade, queries and the worker isolate
- [ ] 02.8 Index consistency fuzz test
- [ ] 02.9 App integration: index lifecycle, indexing file-system decorator, progress, `Rebuild index`, link settings
- [ ] 02.10 Link formatting and link navigation (open, create on click)
- [ ] 02.11 Rename/move link maintenance as one undoable operation
- [ ] 02.12 Backlinks and outgoing-links panes (linked + unlinked mentions)
- [ ] 02.13 Outline pane (headings tree, jump, drag sections on desktop)
- [ ] 02.14 Embeds and transclusion in reading view; page preview
- [ ] 02.15 Search query parser (`tephra_search`)
- [ ] 02.16 Search engine: SQL/FTS compilation, verification, streaming, sorting, cancellation
- [ ] 02.17 Search UI, search history, copy results, in-note highlights, ` ```query ` blocks
- [ ] 02.18 Tags pane and bookmarks
- [ ] 02.19 Fuzzy scorer and index-backed quick switcher
- [ ] 02.20 Editor autocomplete core: popup, `[[` and `![[` links, headings, blocks, aliases
- [ ] 02.21 Autocomplete for tags and frontmatter keys and values
- [ ] 02.22 Date formatting, template engine, and the slash command menu
- [ ] 02.23 Live Preview I: decoration model, incremental engine and inline widgets
- [ ] 02.24 Live Preview II: editor adapter, reveal on the caret, mode toggle (Ctrl+Shift+E), default mode
- [ ] 02.25 Folding of headings and list items with persisted fold state
- [ ] 02.26 Properties editor (typed widgets, type registry, `yaml_edit`)
- [ ] 02.27 Daily notes, templates and the unique note creator
- [ ] 02.28 Web preview guard, performance harness, bench vault with demo pack, recorded budgets

### Exit gate

- [ ] Steps 02.1–02.28 are ticked and each has its commit `phase 02.S: …` (`git log --oneline` shows 28 commits plus any `phase 02.0` fix).
- [ ] At the repo root: `dart format --output=none --set-exit-if-changed app/lib app/test packages tool` exits 0; `flutter analyze --fatal-infos` reports **0 issues**; `dart test` passes in every `packages/tephra_*` directory and in `tool/`; `flutter test` passes in `app/`.
- [ ] `dart run tool/check_licenses.dart` exits 0 (new direct dependencies: `drift`, `sqlite3`, `drift_dev`, `build_runner`, `yaml_edit`, `yaml`, `intl`, and `url_launcher` / `scrollable_positioned_list` if they were not already present — all permissive) and `THIRD_PARTY_NOTICES.md` is regenerated and committed.
- [ ] **Demo script** (above) passes on Windows **and** on a real Android phone; every "Expected" line observed. (Anything not verified on a device is written as "not verified on device" and reported to the human.)
- [ ] **Search parity:** `search_parity_test.dart` passes for all 44 queries (Q1–Q44) on `test_vaults/search`; in addition the human opened `test_vaults/search` in Obsidian and ran queries Q1–Q30 there: the result sets are identical, or every difference is listed in `PROGRESS.md` with an explanation the human accepted.
- [ ] **Index fuzz:** `cd packages/tephra_index; dart test --tags fuzz` passes — 3 seeds × 10,000 operations, **0 differences** between the incremental index and a fresh rebuild; the run time is recorded.
- [ ] **Link maintenance:** link resolver matrix (step 02.5), `rename_planner_test`, `rename_500_test` (500 notes, 2,000 links updated, all untouched bytes identical, < 5 s) and `vault_undo_test` pass.
- [ ] **Live Preview:** the engine equivalence test (`live_preview_engine_test`) (incremental == full recompute over 500 random edits per syntax note), the invariant "decorated line length == source line length", and `live_preview_no_write_test` (0 writes) pass; the IME manual checks of step 02.24 were done on Windows and Android and are recorded; the engine (A/B), the widget mode (W1 or documented styled-source fallback) and `kLpHideMode` per platform are written in `PROGRESS.md`.
- [ ] **Properties:** `frontmatter_editor_test` passes; opening the edited vault in Obsidian shows the same properties, and the YAML of untouched properties (order, comments, quotes) is unchanged; the "yaml_edit limits" list in `PROGRESS.md` is empty or accepted by the human.
- [ ] **Budgets (conventions §10) — numbers recorded for each, measured in `--profile` on the 10k bench vault:**
- [ ] cold start → editable note: Android **< 2.5 s**, Windows **< 1.5 s** (median of 5)
- [ ] first full index of 10,000 notes: Android **< 60 s**, Windows **< 20 s**, with `ui.index.frame.p95 ≤ 16.0 ms` during indexing
- [ ] typing in the 5,000-line note: **< 16 ms** per keystroke (`max(build, raster)` p95) in Source mode **and** in Live Preview, Windows and Android
- [ ] plain-text search over 10,000 notes: p95 **< 200 ms** (first 20 results; total time for queries with ≤ 200 matches)
- [ ] quick switcher ranking: p95 **< 50 ms**
- [ ] memory with the 10,000-note vault open: Android **< 350 MB**, Windows **< 500 MB** (RSS)
- [ ] release APK size: each ABI **< 40,000,000 bytes**
- [ ] **Data safety:** the Phase 1 round-trip test (open + save every fixture note without edits writes **0 bytes** changed) still passes over `syntax`, `edge`, `real`, `search`; the Live Preview no-write test passes; a rename/undo cycle leaves every touched file byte-identical.
- [ ] **Web preview:** `dart run tool/dev.dart` starts from the Dev Launcher (project "Tephra (Gemini build)": `POST /api/projects/<id>/start`, then `GET /api/logs/<id>/<label>` shows the `Local:` and `Network:` lines) and the page loads with the web empty state for index panes.
- [ ] **One week of daily use:** the human used Tephra as the main notes app for 7 days on both devices. Procedure: before day 1 copy the vault folder to a backup folder; during the week keep a list in `PROGRESS.md` of the notes you intentionally edited or deleted; at the end compare with `robocopy <vault> <backup-copy-of-baseline> /L /E /NJH /NJS /NDL` (list-only) — every listed difference must be an intentional change or a file in `.tephra/`; no note text was lost or corrupted; no blocking bug remained open (non-blocking bugs are listed). Write the dates and the result.
- [ ] `PROGRESS.md` contains: the Phase 1 inventory table (step "What exists from Phase 1"), the engine/widget decisions, the performance table, every deviation under "Conflicts" (including the shortcut decision of step 02.24) and every idea under "Ideas".
- [ ] **Merge and tag:** `git checkout main`, `git merge --no-ff phase-02 -m "phase 02: links, index, search and live preview (MVP)"`, `git tag v0.02.0`. Then **stop** and report to the human (what was built, gate results with numbers, anything "not verified on device"). Wait for "continue" before Phase 3.

### Phase notes

-

## Phase 03 — Sync & backup via Google Drive (Beta)

Instructions: `instructions/phase-03-sync-drive.md`

### Steps

- [ ] 03.1 `tephra_sync` package skeleton, dependencies and exceptions
- [ ] 03.2 Core models, the `SyncProvider` contract and `MemorySyncProvider`
- [ ] 03.3 Sync state database (drift) and device identity
- [ ] 03.4 Crypto: KDF, master key, key wrapping, object envelope, recovery key
- [ ] 03.5 FastCDC chunking and the blob store (dedup, verify)
- [ ] 03.6 Remote vault header (`vault.json`), `RemoteVaultManager` and device files
- [ ] 03.7 Hybrid logical clock, journals, remote history and snapshots
- [ ] 03.8 Local scanner, path rules, case sensitivity, Windows names
- [ ] 03.9 Three-way merge (Markdown, plain text, `.tephra` JSON) and conflict naming
- [ ] 03.10 The planner (pure function): decision table, renames, case conflicts, delete guard
- [ ] 03.11 The executor and `SyncEngine.syncOnce` (crash-safe, idempotent, resumable)
- [ ] 03.12 Multi-device simulator and the fuzz test
- [ ] 03.13 Human-prerequisite gate and OAuth configuration loading
- [ ] 03.14 Google authentication: Android (`google_sign_in` 7) and Windows (loopback + PKCE)
- [ ] 03.15 Fake Drive server, `DriveSyncProvider`, retries and fault injection
- [ ] 03.16 Sync runtime: worker isolate, triggers, polling, editor guard, offline queue, bandwidth
- [ ] 03.17 Android background sync (WorkManager) and Windows tray / keep-running
- [ ] 03.18 Sync UI 1: the setup wizard
- [ ] 03.19 Sync UI 2: status indicator, sync panel, sync log, settings, devices
- [ ] 03.20 Conflicts screen with diff view and resolution actions
- [ ] 03.21 Version history: local snapshots, remote versions, history screen, recently deleted
- [ ] 03.22 Backup mode: manifests, schedule, retention, backup-only mode
- [ ] 03.23 Garbage collection (mark-and-sweep with leases), backup verification, restore
- [ ] 03.24 Nightly CI, live contract, format document, real-device test procedure

### Exit gate

- [ ] All steps 03.1–03.24 ticked; `flutter analyze --fatal-infos` 0 issues; every package's tests and `flutter test` pass; `dart run tool/check_licenses.dart` passes; `git check-ignore secrets/google_oauth.json` prints the path.
- [ ] Fuzz test: 100k operations, 0 lost content, convergence every run — nightly job green for **7 consecutive nights** (record seeds and durations).
- [ ] Crypto known-answer tests pass (AES-GCM, HKDF, Argon2id RFC 9106) and the frozen envelope/chunking golden constants are unchanged.
- [ ] Provider contract suite passes for `MemorySyncProvider`, `DriveSyncProvider` on the fake server, and the live Drive test account (nightly).
- [ ] Demo script passes on a real phone and the PC with a real Google account.
- [ ] A save on one device appears on the other within **60 s** when both apps are open (10 runs each direction; record median and max).
- [ ] Sync recovers by itself after: network loss mid-upload, Drive rate limiting, expired/revoked token (after the user taps Reconnect, without re-entering the vault password), Drive storage full (with a clear warning) — real-device procedure items 4–7.
- [ ] Android background sync works with the app closed for 24 h; Tephra battery use < 2%/day (record the percentage).
- [ ] With encryption on, the downloaded Drive folder contains no readable note text and no note file names (real-device item 9; the vault name in `vault.json` / folder name is allowed by design).
- [ ] Argon2id unlock time on the phone recorded (floor parameters) and ≤ 5 s.
- [ ] Performance budgets of conventions §10 still met with sync enabled and idle (cold start, typing latency, search); no dropped frames while a 500-file sync runs.
- [ ] `dart run tool/dev.dart` (web preview) still starts and shows "Sync is not available in the web preview" in the sync settings.
- [ ] Beta build installed on the human's phone and PC and used daily for **2 weeks** with no data loss (daily notes in `PROGRESS.md`; record whether weekly reconnects happened because of the Testing-mode 7-day token limit).
- [ ] `docs/decisions/sync-format-v1.md` and `docs/testing/sync-real-device.md` committed.
- [ ] Merge `phase-03` into `main` with `--no-ff`, tag `v0.03.0`, stop and report to the human.

### Phase notes

-

## Phase 04 — Sticky notes & quick capture

Instructions: `instructions/phase-04-stickies-capture.md`

### Steps

- [ ] 04.1 Dependencies, settings keys and platform-service skeletons
- [ ] 04.2 Sticky model and frontmatter patching (round-trip safe)
- [ ] 04.3 Sticky repository: listing, creating, updating, archiving folder rules
- [ ] 04.4 Sticky commands and editor integration
- [ ] 04.5 Sticky mini renderer and sticky card
- [ ] 04.6 Sticky board data: JSON Canvas file, colour mapping and reconciliation
- [ ] 04.7 Sticky board screen (both platforms)
- [ ] 04.8 Windows multi-window foundation and the sticky message protocol
- [ ] 04.9 StickyHub (main window, single writer) and the sticky window app
- [ ] 04.10 Geometry per monitor, restore at start, show/hide all, start with Windows
- [ ] 04.11 Global hotkey and tray menu (Windows)
- [ ] 04.12 Reminders (both platforms), headless config, deep links
- [ ] 04.13 Android home-screen widgets (single sticky, sticky stack)
- [ ] 04.14 Android floating sticky bubble (draw over other apps)
- [ ] 04.15 Capture screen and share-to-Tephra (Android)
- [ ] 04.16 Quick Settings tile, persistent quick-note notification, quick-capture widget, app shortcuts (Android)
- [ ] 04.17 Auto-archive expired stickies, phase integration, demo

### Exit gate

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

### Phase notes

-

## Phase 05 — Import & export

Instructions: `instructions/phase-05-import-export.md`

### Steps

- [ ] 05.1 tephra_io API types, sources and registry
- [ ] 05.2 Helpers I: safe names, frontmatter builder, dates, CSV parser, Markdown escaping
- [ ] 05.3 Helpers II: import context, note writer, attachment writer (hash de-dup), link rewriting, simple link resolver
- [ ] 05.4 HTML → Markdown converter
- [ ] 05.5 Import runner (isolate, progress, cancellation) and the snapshot harness
- [ ] 05.6 Importer 1: Obsidian vault (merge into the current vault)
- [ ] 05.7 Importer 2: plain Markdown and text folders
- [ ] 05.8 Importers 3, 10, 11: HTML files, Apple Notes (HTML), OneNote (HTML)
- [ ] 05.9 Importer 4: Notion export (Markdown & CSV zip)
- [ ] 05.10 Importer 5: Evernote `.enex`
- [ ] 05.11 Importer 6: Google Keep (Takeout JSON)
- [ ] 05.12 Importer 7: Bear (Markdown export and TextBundle)
- [ ] 05.13 Importer 8: Roam Research JSON (and the daily-note naming helper)
- [ ] 05.14 Importer 9: Logseq graph (Markdown)
- [ ] 05.15 Importer 12: CSV (one note per row, with a column-mapping step)
- [ ] 05.16 Exporters I: zip, encrypted `.tephra-backup`, and the restore importer
- [ ] 05.17 Exporters II: shared export context, portable Markdown, self-contained HTML
- [ ] 05.18 Exporter III: PDF (from our AST, bundled fonts)
- [ ] 05.19 Exporter IV: DOCX (WordprocessingML with `archive` + `xml`)
- [ ] 05.20 App services: save-as, share sheet, staging, font cache, providers, commands
- [ ] 05.21 Import wizard and export dialog (desktop and phone layouts)
- [ ] 05.22 Integration, registry completeness, licences and notices

### Exit gate

- [ ] `dart test` in `packages/tephra_io` is green; the integration test of 05.22 shows **0 crashes** across the importer fixtures: Obsidian, Markdown/text, HTML, Apple Notes, OneNote, Notion, Evernote, Google Keep, Bear (Markdown, TextBundle, `.textpack`, `.bear2bk`), Roam, Logseq, CSV, Tephra backup — each finished with an `ImportFinished` and the **expected report** (note count, attachment count and exact warning strings as in the fixtures' snapshots).
- [ ] The 1,000-note synthetic Notion export (`tool/gen_notion_export.dart <dir> 1000`) imports in **< 2 minutes on Windows** (`dart test -t bench`; record the seconds) and **every generated wikilink resolves** to an existing file (asserted by the bench test).
- [ ] Every imported/exported Markdown file parses with `MarkdownParser`, frontmatter is valid, and no produced file name is illegal on Windows.
- [ ] `Syntax test.md` exports: **PDF** (structural tests green — header/trailer, page count equals page-tree `/Count`, MediaBox A4/Letter, fonts embedded, outlines, text-hook contains the expected strings and not the comment; manual visual check recorded), **DOCX** (structural tests green: every part present, all XML well formed, relationships/content types/styles/numbering resolve, 6 headings, table 3×3, image EMU sizes; manual open in Word/LibreOffice recorded without a repair prompt), **HTML** (no scripts, no external requests, image inlined; manual browser check), **portable Markdown** (relative links, embeds inlined, depth ≤ 5 with cycle and missing-target markers), and **zip** + **`.tephra-backup`** round-trip byte-identical.
- [ ] Wrong password, tampered and truncated `.tephra-backup` files are rejected with `CryptoException` (tests green).
- [ ] Import wizard and export dialog work on the desktop layout (≥ 840 dp) and the phone layout (< 840 dp): widget tests green; Windows "Save as…" manually verified; Android share sheet manually verified **or** recorded as "not verified on device".
- [ ] `flutter analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`, `flutter test` (app) and `dart run tool/check_licenses.dart` all pass; fonts listed under "Bundled fonts" in `THIRD_PARTY_NOTICES.md`.
- [ ] `PROGRESS.md` updated (all steps 05.1–05.22 ticked, performance number, discovered APIs, "not verified on device" notes).
- [ ] `git checkout main; git merge --no-ff phase-05; git tag v0.05.0` — then **stop** and report to the human (GEMINI.md §3.5). The tag is `v0.05.0` (format `v0.NN.0`, GEMINI.md §3 and conventions §9).

### Phase notes

-

## Phase 06 — Visual views

Instructions: `instructions/phase-06-visual-views.md`

### Steps

- [ ] 06.1 Inventory, dependencies and WebView spike
- [ ] 06.2 View registry and new tab kinds
- [ ] 06.3 Index queries for graph and bases
- [ ] 06.4 Graph settings and graph model builder
- [ ] 06.5 Force simulation with a Barnes–Hut quadtree
- [ ] 06.6 Layout worker isolate and position streaming
- [ ] 06.7 Graph viewport and painter
- [ ] 06.8 Graph interactions: hit testing, pan/zoom, drag, hover, open
- [ ] 06.9 Global graph tab and settings panel
- [ ] 06.10 Local graph
- [ ] 06.11 Graph performance measurement and tuning
- [ ] 06.12 JSON Canvas codec (byte-exact, lossless)
- [ ] 06.13 Canvas document controller: operations, undo/redo, saving
- [ ] 06.14 Canvas rendering
- [ ] 06.15 Canvas editing and input
- [ ] 06.16 Bases document model with lossless YAML edits
- [ ] 06.17 Bases expression language
- [ ] 06.18 Bases query execution
- [ ] 06.19 Bases UI: table, cards, inline edits, embedded blocks
- [ ] 06.20 Math rendering and code-block upgrades
- [ ] 06.21 Mermaid diagrams (offline, cached)
- [ ] 06.22 PDF viewer, deep links and page embeds
- [ ] 06.23 Image viewer, audio/video players and media embeds
- [ ] 06.24 Slides

### Exit gate

- [ ] Every step 06.1–06.24 is ticked, with tests passing: `flutter analyze --fatal-infos` clean, `dart format` clean, all package
- [ ] **Graph budget (Windows):** 10k-note bench vault, `graph_perf_test` in profile mode: average frame ≤ 16.7 ms and p90 ≤ 20 ms; mean
- [ ] **Graph budget (Android phone):** same test on the real phone: average frame ≤ 33.3 ms and p90 ≤ 40 ms; mean tick ≤ 60 ms. Device
- [ ] **Canvas round-trip:** every `test_vaults/syntax/canvas/*.canvas` fixture and at least 3 canvases created in Obsidian open and close
- [ ] **Canvas compatibility:** a canvas created and edited in Tephra (all four node types, edges with labels, colours, a group) opens in
- [ ] **Base round-trip:** every `test_vaults/syntax/bases/*.base` fixture and at least 2 Obsidian-made bases open and close with **0
- [ ] **Mermaid offline:** `mermaid_render_test` passes on Windows and on the phone with networking disabled.
- [ ] **Math offline:** the syntax vault math note renders on both platforms (golden test + manual), invalid TeX shows the error box.
- [ ] PDF `#page=N` links and embeds, search, outline, thumbnails, copy text and last-page memory work on both platforms.
- [ ] Image viewer, audio and video playback (tab + embed) work on both platforms (formats tried recorded).
- [ ] Slides work on both platforms (keyboard on Windows, swipe on the phone).
- [ ] `dart run tool/check_licenses.dart` passes; `THIRD_PARTY_NOTICES.md` lists every new package and Mermaid.
- [ ] The Phase 1 round-trip test (all fixture vaults, 0 changed bytes) and the Phase 2 performance budgets still pass.
- [ ] Demo script 1–11 passes on Windows and Android.

### Phase notes

-

## Phase 07 — Remaining parity & polish

Instructions: `instructions/phase-07-parity-polish.md`

### Steps

- [ ] 07.1 Settings registry and storage
- [ ] 07.2 Settings screens
- [ ] 07.3 Theme engine: tokens, JSON themes, bundled themes
- [ ] 07.4 Theme editor and Obsidian theme import
- [ ] 07.5 Custom fonts, accent colour, interface zoom
- [ ] 07.6 Note composer: merge and extract
- [ ] 07.7 Format converter
- [ ] 07.8 Word and character count
- [ ] 07.9 Random note and audio recorder
- [ ] 07.10 File recovery and footnotes view
- [ ] 07.11 Web viewer (Windows)
- [ ] 07.12 Tabs: tab groups, pinned tabs, stacked tabs, session restore
- [ ] 07.13 Saved workspaces, linked panes, pop-out windows
- [ ] 07.14 Editor overlay decorations and multi-cursor (desktop)
- [ ] 07.15 Vim mode (desktop)
- [ ] 07.16 Spell check (Android and Windows)
- [ ] 07.17 RTL text, paste HTML as Markdown, block drag handle
- [ ] 07.18 Accessibility: semantics, list alternatives, keyboard navigation, contrast, text scaling
- [ ] 07.19 Polish: empty states, motion, plain-language errors, command reachability
- [ ] 07.20 Onboarding: the "Tephra Guide" vault

### Exit gate

- [ ] `docs/accessibility-audit.md` complete: every flow of 07.18 E passed with TalkBack (Android phone, real device or "not verified on device" noted) and with Narrator and keyboard-only (Windows); no unexplained failures.
- [ ] Contrast test passes for all four bundled themes; text-scale goldens (1.0 / 1.5 / 2.0) pass; no RenderFlex overflow at 200%.
- [ ] Every command reachable (`command_reachability_test.dart` green; allowlists printed and justified in `PROGRESS.md`).
- [ ] Every panel in 07.19 A.2 shows its empty state; no user-visible string comes from `toString()`.
- [ ] Guide vault installs on first run on both platforms; every link in it resolves.
- [ ] Source-rule tests pass (no raw `Color(0x` outside `app/lib/theme/`, no raw animation durations, no `IconButton` without a tooltip, no error text from exceptions).
- [ ] `dart run tool/check_licenses.dart` passes (new packages: `record` BSD-3-Clause; `win32` BSD-3-Clause; `ffi` BSD-3-Clause if added).
- [ ] No data-loss regression: the Phase 1 text round-trip test, the Phase 2 rename-with-links test and the note-composer undo test are green; pop-out editing test (manual) shows no lost edits.
- [ ] Cold start → editable note: Android < 2.5 s, Windows < 1.5 s (custom fonts and theme loading included).
- [ ] Typing latency, 5,000-line note: < 16 ms p95 — measured **four** ways: plain; spell check on; vim mode on (Windows); two extra carets (Windows).
- [ ] Plain-text search 10k notes < 200 ms; quick switcher < 50 ms; first full index unchanged from Phase 6's numbers (±10%).
- [ ] Memory with the 10k-note vault: Android < 350 MB, Windows < 500 MB (with spell check and the web viewer tab open on Windows).
- [ ] Release APK size < 40 MB per ABI (the guide vault and theme assets included).
- [ ] Theme switch applies in < 300 ms with a 5,000-line note open (measure with `Stopwatch` around the provider change to the next frame).
- [ ] `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`, `flutter analyze --fatal-infos`, all package tests, `flutter test` in `app/` (including `--tags golden` on Windows) pass.
- [ ] `PROGRESS.md` updated: Name map, contract additions (below), decisions (spell check APIs, multi-cursor at controller level, decoration mechanism), numbers, "not verified on device" items.
- [ ] `git checkout main`, then `git merge --no-ff phase-07`.
- [ ] `git tag v0.07.0`.
- [ ] Stop and report to the human: what was built, gate results with numbers, items not verified on a device, and the contract additions below.

### Phase notes

-

## Phase 08 — Advanced extras

Instructions: `instructions/phase-08-advanced-extras.md`

### Steps

- [ ] 08.1 Create `packages/tephra_ai`
- [ ] 08.2 SSE parser
- [ ] 08.3 Claude client — requests, streaming, usage
- [ ] 08.4 Errors, retries, rate limiting, cancellation
- [ ] 08.5 Model catalog and cost
- [ ] 08.6 Prompt templates with golden tests
- [ ] 08.7 App: AI settings, key storage, usage ledger
- [ ] 08.8 Outbound preview and the AI request gateway
- [ ] 08.9 Selection actions
- [ ] 08.10 Note chunker
- [ ] 08.11 Unigram (XLM-R) tokenizer
- [ ] 08.12 Embedding interfaces, e5 helpers and Voyage
- [ ] 08.13 Vector store and in-memory vector index
- [ ] 08.14 Semantic indexer
- [ ] 08.15 App: model download manager and ONNX embedder
- [ ] 08.16 App: embedding worker isolate and semantic service
- [ ] 08.17 Related notes panel
- [ ] 08.18 Semantic mode in the search panel
- [ ] 08.19 Retriever, citations and the Ask-your-vault service
- [ ] 08.20 Ask-your-vault panel
- [ ] 08.21 Suggest tags and links
- [ ] 08.22 Generate flashcards from a note
- [ ] 08.23 Block 8a check
- [ ] 08.24 Tasks metadata parser
- [ ] 08.25 Task edit service: toggle, done date, recurrence
- [ ] 08.26 Tasks dashboard
- [ ] 08.27 Task reminders
- [ ] 08.28 DQL lexer and parser
- [ ] 08.29 Query dataset: note rows and task rows
- [ ] 08.30 DQL compiler and executor
- [ ] 08.31 Query block rendering
- [ ] 08.32 Kanban parser and serializer
- [ ] 08.33 Kanban board view
- [ ] 08.34 Flashcard parser, SM-2 and state store
- [ ] 08.35 Review screen and statistics
- [ ] 08.36 Block 8b check (Obsidian plugin compatibility)
- [ ] 08.37 Attachment text in the index and in search
- [ ] 08.38 OCR interface and Android ML Kit engine
- [ ] 08.39 Windows OCR FFI plugin (`tephra_win_ocr`)
- [ ] 08.40 OCR queue, OCR cache and PDF handling
- [ ] 08.41 whisper.cpp plugin: vendoring and native build
- [ ] 08.42 Transcription service, Dart bindings and model download
- [ ] 08.43 Voice notes and transcript insertion
- [ ] 08.44 Sketch model and file I/O
- [ ] 08.45 Sketch editor
- [ ] 08.46 Sketch embedding and tap-to-edit
- [ ] 08.47 Block 8c check
- [ ] 08.48 TENC codec
- [ ] 08.49 Encrypted-areas registry and unlock sessions
- [ ] 08.50 Encrypt and decrypt flows
- [ ] 08.51 Working with encrypted notes: explorer, editor, search, sync
- [ ] 08.52 App lock
- [ ] 08.53 Block 8d check
- [ ] 08.54 Phase 8 wrap-up: budgets, size, docs

### Exit gate

- [ ] **8a:** every Ask-your-vault answer in the 7-question test cites at least one source note with a valid `[[…]]` link, and out-of-vault questions reply "I could not find this in your notes." (both platforms).
- [ ] **8a:** semantic search and Related notes work fully offline with the local model (airplane mode / Wi-Fi off), both platforms.
- [ ] **8a:** no AI request is sent without a user action; with "Always confirm" on, every request shows the preview first; the API key and note text never appear in logs.
- [ ] **8a:** 401, 429 (with `retry-after`), 529 and network errors each produce the specified plain-language message (unit tests green).
- [ ] **8b:** the 10 queries in `queries.md` give the same rows in Tephra and in Obsidian Dataview, except documented unsupported features.
- [ ] **8b:** Kanban boards written by Tephra open as boards in the Obsidian Kanban plugin, and plugin-written boards round-trip byte-for-byte through Tephra when unchanged.
- [ ] **8b:** Tasks completion adds `✅ YYYY-MM-DD` and simple recurrences create the next task exactly like the Tasks plugin for the fixture tasks.
- [ ] **8b:** SM-2 unit tests green; review screen usable with keyboard only (Windows) and touch (Android).
- [ ] **8c:** text in photos (Latin script) and in scanned/text PDFs is found by search on both platforms; Bangla OCR limitation documented.
- [ ] **8c:** a 1-minute voice note is transcribed on-device on both platforms; real-time factors recorded.
- [ ] **8c:** sketches with stylus pressure save as `.sketch.json` + `.sketch.png`, render in Obsidian as the PNG, and reopen for editing in Tephra.
- [ ] **8d:** no plaintext of encrypted notes on disk, in the index, vectors DB, OCR cache or logs (search check = 0 matches).
- [ ] **8d:** auto-lock, wrong-password handling, tamper detection and recovery key all verified on both platforms.
- [ ] **8d:** app lock works with PIN and biometrics on Android and with Windows Hello on Windows.
- [ ] All conventions §10 performance budgets still met (numbers recorded in `PROGRESS.md`); release APK per ABI < 40 MB **or** the overrun reported to the human with a size breakdown.
- [ ] `flutter analyze --fatal-infos` clean, all tests green, `dart run tool/check_licenses.dart` passes.

### Phase notes

-

## Phase 09 — Release hardening → v1.0 (direct download: signed APK + Windows installer, in-app updates)

Instructions: `instructions/phase-09-release.md`

### Steps

- [ ] 09.1 Branch, versioning rules, changelog, release-readiness CI
- [ ] 09.2 Crash reporting core: reporter interface, scrubber, local crash log
- [ ] 09.3 Crash reporting UI: first-run consent, Settings → Privacy, About
- [ ] 09.4 Performance re-profiling on the 4 GB Android phone and the Windows PC
- [ ] 09.5 APK size: split per ABI, obfuscation, R8, resource shrinking, icon tree-shaking
- [ ] 09.6 Security review (code, permissions, network, storage) — written result
- [ ] 09.7 Licence review and third-party notices
- [ ] 09.8 Data-safety drills A: disk full, corrupted index, corrupted sync state
- [ ] 09.9 Data-safety drills B: kill during sync, corrupted remote data
- [ ] 09.10 Android release signing (keystore, `key.properties`, Gradle wiring, backup)
- [ ] 09.11 Windows release build, bundled runtime, Inno Setup installer
- [ ] 09.12 Portable zip and optional Authenticode signing
- [ ] 09.13 The release tool `tool/release.dart`: build, verify, checksum, manifest
- [ ] 09.14 Updater core: manifest, signature, version policy, download
- [ ] 09.15 Android in-app install: platform channel, FileProvider, permission
- [ ] 09.16 Windows in-app install, About page "Check for updates", update UI
- [ ] 09.17 Distribution: download page, checksums, releases-only repository or static site
- [ ] 09.18 Legal templates: privacy policy and EULA (for human and lawyer review)
- [ ] 09.19 User guide vault, FAQ, Obsidian migration guide
- [ ] 09.20 Beta, update-path test, release candidate, final gate, v1.0.0

### Exit gate

- [ ] Steps 09.1–09.20 ticked; `flutter analyze --fatal-infos` 0 issues; every package's tests, `flutter test --exclude-tags golden` and `dart test tool/test` pass; `dart run tool/check_licenses.dart` passes; hygiene tests green.
- [ ] **Beta:** 2 weeks with ≥ 10 users (or the human's own heavy daily use on phone + PC) with **no data-loss report**; `beta-report.md` written; Sentry crash-free sessions ≥ **99.5%** for the final release candidate when ≥ 100 sessions were recorded (otherwise: zero unresolved crash groups with more than one occurrence, and the report says how many sessions were seen).
- [ ] **Performance:** every conventions §10 budget met on the 4 GB phone and Windows (numbers in `perf-v1.0.md`), no jank during idle sync or a 500-file sync, unsaved text survives process death.
- [ ] **Size:** release APK < 40 MB per ABI (`size-v1.0.md`), or the human's written approval line `SIZE-APPROVED 1.0.0` in `PROGRESS.md`.
- [ ] **Security and licences:** `security-review.md`, `permissions.md`, `licence-review.md` complete with no open "fail"; the permission list equals the shipped APK's; `THIRD_PARTY_NOTICES.md` regenerated and shown in the About page.
- [ ] **Data-safety drills** D1–D5 all pass with logged evidence; the 1,000-seed crash-point drill and the 200-iteration real-kill drill have 0 failures; corrupted index auto-rebuilds; corrupted remote journal is quarantined and reported with the three user actions working.
- [ ] **Crash reporting:** off until the user opts in (verified by network inspection: no request to `*.ingest.sentry.io` before consent); on-event JSON contains no note text, paths, names, user, IP or breadcrumbs (09.3 verify), and the setting can be turned off at once.
- [ ] **Signing and artifacts:** signed APKs (3 ABI + universal), Windows installer, portable zip, `SHA256SUMS.txt`, `manifest.json` + `manifest.json.sig`, symbols archived; every APK's certificate SHA-256 equals `signing-cert.md`; the installer runs on a clean Windows machine/Sandbox with no runtime error; keystore and update-signing-key backups ticked in `KEY_BACKUP.md`.
- [ ] **Updates:** in-app update from the previous release verified on **both** platforms (Android keeps data and signature continuity; Windows silent upgrade relaunches); tampered file and bad signature both refused; automatic check runs at most once per day.
- [ ] **Distribution:** download page + privacy policy + EULA published at the chosen hosting; manifest URL recorded and stable; Google OAuth consent screen points at the privacy policy; templates have no `{{PLACEHOLDER}}` left (H7 done).
- [ ] **Docs:** user-guide vault shipped and tested, FAQ ≥ 25 Q&As, Obsidian migration guide present; `CHANGELOG.md` final.
- [ ] `PROGRESS.md` updated; `git checkout main; git merge --no-ff phase-09; git tag v1.0.0`; stop and report to the human.

### Phase notes

-

## Phase 10 — Tephra Cloud: our own online backup & sync → v2.0

Instructions: `instructions/phase-10-tephra-cloud.md`

### Steps

- [ ] 10.1 `server/` package skeleton, workspace, dependencies, shared key validation
- [ ] 10.2 Configuration, logging, process lifecycle, `/health`, Dev Launcher
- [ ] 10.3 Database: schema, migrations, data access layer
- [ ] 10.4 Blob storage backends (local disk and S3-compatible)
- [ ] 10.5 Passwords, access tokens, sessions, refresh rotation
- [ ] 10.6 Email: sender, templates, verification and reset tokens, HTML pages
- [ ] 10.7 Auth API endpoints and middleware pipeline
- [ ] 10.8 Vault and object endpoints (the `SyncProvider` over HTTP)
- [ ] 10.9 Change feed with epoch, and the WebSocket event hub
- [ ] 10.10 Quotas and plans, rate limiting, size and time limits, metrics
- [ ] 10.11 Retention, background jobs, account deletion
- [ ] 10.12 Admin CLI `tephra-admin`
- [ ] 10.13 Client: `TephraCloudSyncProvider`, auth client, token source, events client
- [ ] 10.14 Contract suite, fuzz simulator and data-safety drills against a real test server
- [ ] 10.15 App: provider factory, wizard provider choice, sign-up / sign-in / verify / forgot-password
- [ ] 10.16 App: account, storage usage and devices screens
- [ ] 10.17 Migration engine: copy key-for-key, verify, switch (pure Dart)
- [ ] 10.18 Migration UI, other devices, Drive mirror, emergency return
- [ ] 10.19 Container image, docker-compose with Caddy (automatic HTTPS), staging beside production
- [ ] 10.20 VPS runbook, hardening, off-site backups, monitoring, **restore drill**
- [ ] 10.21 Self-hosting: Windows `.exe`, Linux binaries, Docker image, Tailscale / Cloudflare Tunnel guide, CI
- [ ] 10.22 Legal: Terms of Service, privacy update, self-host licence, account deletion and data requests
- [ ] 10.23 Load test (100 concurrent devices), soak agent, staging deployment
- [ ] 10.24 Real-device checks, frozen API document, v2.0 release

### Exit gate

- [ ] Steps 10.1–10.24 ticked; `flutter analyze --fatal-infos` 0 issues; `dart test` in every package **and** `server/`; `flutter test --exclude-tags golden`; `dart test tool/test`; `dart run tool/check_licenses.dart` passes (no AGPL/GPL anywhere; MinIO **server** not used).
- [ ] **Provider contract:** `runSyncProviderContract` passes for `TephraCloudSyncProvider` against the real test server (plus the cloud-specific extra tests).
- [ ] **Fuzz and data-safety on Tephra Cloud:** cloud fuzz (default and the local 20,000-op run) 0 lost content, convergence every run; nightly green for **7 consecutive nights** (record seeds); the 1,000-seed crash-point drill, the 200-iteration real-kill drill (`--provider cloud`), the corrupted-remote tests (server-side storage corruption) and the server-crash test (SIGKILL during PUT) all pass (`docs/ops/data-safety-cloud.md`).
- [ ] **Speed:** a save on one device appears on the other **≤ 3 s** in all 20 runs per direction on real devices (min/median/p95/max recorded); the automated loopback test p95 < 1.0 s.
- [ ] **Migration:** the 10,000-note encrypted Drive vault moves to Tephra Cloud with **zero differences** (history equality, plan equality, content sample, object counts equal), the post-switch cycle has 0 actions, the second device switches without re-downloading, Drive is untouched (marker/mirror only), and the migration report is recorded.
- [ ] **Backups:** daily restic backup running 7/7 days; **restore drill passed** (record RTO ≤ 2 h, RPO ≤ 24 h, `verify-storage --deep` exit 0, `restore_check` 0 differences, `bump-epoch` done).
- [ ] **Staging soak:** 7 days with no unexplained `SEVERE` log lines, 0 invariant failures, RSS within +10% of day 1, planned restart and SIGKILL recovered automatically, backups 7/7, uptime ≥ 99.9% excluding induced restarts (`docs/ops/soak-staging.md`).
- [ ] **Load:** 100 concurrent devices meet every target of 10.23 (error rate < 0.1%, p95 latencies, push p95 < 1 s, 0 undelivered, no RSS growth) in the three recorded runs.
- [ ] **Security:** Argon2id parameters as specified (hash time recorded), refresh-token rotation + reuse detection + 30-s grace verified by tests and the real two-process check, rate limits verified, `nmap` shows only 22/80/443, SSL Labs A or better, `/metrics` protected, the readable-data check finds **zero** note words/names in the server data, the privacy policy lists the metadata the server can see.
- [ ] **Email and accounts:** verification, reset, change-password, account deletion (grace, purge, mail) work on staging with real SMTP; the vault password is never affected by account-password changes.
- [ ] **Self-hosting:** Windows zip, Linux x64/arm64 tarballs and Docker image built and smoke-tested on clean environments; the guide with Tailscale and Cloudflare Tunnel is complete; the release app refuses `http://` servers.
- [ ] **Legal:** Terms of Service, privacy update, self-host licence published, no `{{PLACEHOLDER}}` left, retention numbers in text equal the code constants (test green).
- [ ] **Dev Launcher:** `server` registered as a second process of "Tephra (Gemini build)" (`autoStart: false`), starts on `PORT` 8094 with the `Local:`/`Network:` lines, and the web preview (`dart run tool/dev.dart`, port 8093) still works.
- [ ] `docs/decisions/cloud-api-v1.md` committed; v2.0.0 released through the Phase 9 channel; `git checkout main; git merge --no-ff phase-10; git tag v2.0.0`; stop and report to the human.

### Phase notes

-

## Phase 11 — Ecosystem: stores, collaboration spike, web clipper, plugins, more platforms, static sites

Instructions: `instructions/phase-11-ecosystem.md`

### Steps

- [ ] 11.1 Build flavors and the `TEPHRA_DIST` switch (do this first)
- [ ] 11.2 Android App Bundle, Play App Signing, target API, native symbols
- [ ] 11.3 "All files access" declaration, SAF contingency, other permission declarations
- [ ] 11.4 Data safety form, privacy, account deletion page, listing, assets
- [ ] 11.5 Closed testing → production
- [ ] 11.6 MSIX package
- [ ] 11.7 Store listing, certification and submission
- [ ] 11.8 Criteria and candidate survey
- [ ] 11.9 Prototype and benchmarks (throw-away package, reusable code)
- [ ] 11.10 Design document: keys, protocol, file integration, rollout plan
- [ ] 11.11 Inbox on Tephra Cloud (server + sealed-box crypto + app consumer)
- [ ] 11.12 The browser extension (Manifest V3)
- [ ] 11.13 `tephra://clip` handler (desktop and Android), installer registration, confirmation UX
- [ ] 11.14 Runtime spike: choose the JS engine and the isolation model
- [ ] 11.15 Plugin manifest, permission model, API surface (specification)
- [ ] 11.16 Plugin host: runtime, bridge, permission enforcement, limits
- [ ] 11.17 Plugin manager UI, sample plugins, developer documentation
- [ ] 11.18 Platform folders, dependency/platform audit, platform services
- [ ] 11.19 Linux (tar.gz + .deb, secure storage, tray, inotify)
- [ ] 11.20 macOS (Developer ID, notarization, DMG, sandbox decision)
- [ ] 11.21 iOS (TestFlight)
- [ ] 11.22 (Item F) common smoke test, performance and release wiring
- [ ] 11.23 Exporter core: selection, rendering, links, backlinks, privacy rules
- [ ] 11.24 Search index, graph data, site assets, preview server, wizard, incremental builds, guides

### Exit gate

- [ ] `play` and `direct` flavors build; `play` has no `REQUEST_INSTALL_PACKAGES` and no reachable updater code (hygiene tests green); the direct in-app update still works (09.15 manual test repeated); `release.dart` uses the flavor paths.
- [ ] Signed `.aab` validates with `bundletool`, targets the **currently required API level**, passes the smoke test from a `bundletool`-installed build; signing path (1 or 2) recorded with fingerprints.
- [ ] "All files access" declaration text + demo video accepted by Play, **or** the SAF contingency decision recorded and its gate passed.
- [ ] Data safety answers derived from the real data flows and consistent with the privacy policy (consistency test green); account-deletion web page works end to end on staging and production; listing, graphics and content rating complete.
- [ ] Closed test ran with ≥ 12 opted-in testers for 14 continuous days (if the account type requires it); production release live with a staged rollout; Android vitals crash and ANR rates within Play's "bad behaviour" thresholds for 7 days.
- [ ] `.msix` built with the exact Partner Center identity, installs and runs on a clean Windows 10/11 machine; **WACK passes**; no updater in the Store build; app data location behaviour documented and the "reconnect sync" path tested.
- [ ] Certification passed and the app is live (or in a published state the human accepts); listing complete with screenshots.
- [ ] `docs/spikes/crdt/` has criteria, evidence-based candidate evaluation with licence checks, a pure-Dart prototype whose property tests pass (3 and 5 replicas × 10,000 ops, no interleaving, idempotent apply, external-edit absorption `apply(diff_to_ops(a,b)) == b` for 2,000 pairs) and benchmarks at or better than the targets (or a documented re-scoring that picked another candidate).
- [ ] `design.md` answers all eight questions (key sharing, transport, persistence interplay, scope, threats, rollout) and `docs/decisions/collaboration.md` carries the human's `APPROVED` line. **No collaboration code ships.**
- [ ] Inbox crypto passes the frozen vectors in Dart **and** in the extension (cross-language known-answer test); the server cannot decrypt (a test asserts the stored bytes contain no plaintext marker); inbox limits, TTL and rate limits tested.
- [ ] The extension clips a page and a selection to a vault on Chrome **and** Edge; the resulting note has correct frontmatter, readable Markdown, absolute links, appears on two devices **byte-identical**, and syncs; fixture conversion snapshots reviewed; `npm audit --omit=dev` clean of high/critical.
- [ ] `tephra://clip` always asks for confirmation, writes only under the clipping folder, enforces size limits, and survives the hostile-link tests on Windows and Android; the Windows installer registers the protocol and the uninstaller removes it.
- [ ] Runtime decision record approved; API spec approved (`APPROVED` lines); host implements the spec exactly (spec-vs-guide test green).
- [ ] Every permission row has allow/deny tests; all sandbox-escape fixtures fail to reach host power; an infinite loop is killed within 2.5 s and the plugin is disabled after 3 strikes; paths cannot escape the vault or reach `.obsidian/`/`.tephra/`; zip-slip and oversize packages are rejected.
- [ ] Three sample plugins install and run on Windows and Android; plugins are off per vault by default; plugin files are never in a vault and never synced; no plugin runs when the app is locked.
- [ ] `docs/release/platform-audit.md` complete; every unsupported plugin has a replacement or a hidden/no-op feature; CI builds Linux and macOS/iOS (no-codesign) green.
- [ ] **Linux:** `.deb` and tarball install on a clean Ubuntu 24.04 and pass the smoke list on X11 and Wayland; hotkeys hidden on Wayland; inotify fallback works.
- [ ] **macOS:** DMG notarized and stapled; `spctl` accepts both app and DMG on a second Mac after a browser download; smoke list passes (Apple silicon at minimum).
- [ ] **iOS:** TestFlight build installed on a real iPhone; smoke list passes including external-folder bookmarks and Cloud/Drive sync; export-compliance decision recorded by the human.
- [ ] Performance budgets (conventions §10) met on one real device per platform; updater behaviour correct per distribution (Linux: opens download page; macOS: DMG; iOS: none); the signed manifest additions verify in the app.
- [ ] Privacy tests green: the sentinel unpublished title and every excluded note's text appear in **no** output file; encrypted/hidden/`.tephra` content absent; no raw note HTML becomes live HTML; attachments referenced only by unpublished notes are not copied.
- [ ] Link checker reports 0 broken internal links on the fixture and on a real vault copy (excluding links the report lists as broken in the source); output is deterministic (two builds identical); the incremental writer never touches foreign files.
- [ ] Search finds expected notes, graph renders (≤ 3,000 nodes; local graph above), backlinks correct, dark mode and mobile layout work, pages readable without JS; the 10k-note vault builds in < 60 s and the output size is recorded; no external requests in any generated page.
- [ ] Deployed once to a free static host and viewed on the phone.

### Phase notes

-

## Conflicts

- Phase 1: SAF-based `VaultFileSystem` for Android is deferred. Android uses "All files access" (`MANAGE_EXTERNAL_STORAGE`) on shared storage or the app-private folder. (Deviation from PHASE_PLAN 1.1).

## Ideas (not in scope — do not build without the human's approval)

- Idea: SAF-based `VaultFileSystem` for Android without All-files-access.
