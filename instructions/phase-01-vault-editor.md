# Phase 01 — Vault, files & basic editor

> **Duration estimate:** 5 weeks (one full-time developer), 22 steps.
> **Goal:** open an existing Obsidian vault (or create one) on Windows and Android, browse it, read notes properly rendered, and
> edit and save them in Source mode without ever damaging a file. This phase builds the safe file layer (`tephra_vault`), the
> hand-written Markdown parser with source offsets (`tephra_markdown`), the reading view, the Source-mode editor behind an
> engine-independent `EditorController`, the explorer, tabs/splits/phone layout, the command registry with palette, quick switcher
> and hotkeys, attachments, and the vault picker. No index, no link resolution, no search (Phase 2).

Read `GEMINI.md` and `instructions/00-conventions.md` before you start. This file uses "per conventions §N" to point at the
contract; it never redefines it. Where this file adds to a conventions contract it only **adds** members (listed in "Contract
additions"). Where this file and the conventions disagree, the conventions win (write the conflict into `PROGRESS.md`).

Rules that apply to every step (from `GEMINI.md`): do the steps in order; after every step run the step's Verify block plus
```
dart format --output=none --set-exit-if-changed app/lib app/test packages tool
flutter analyze --fatal-infos
```
plus the tests of every package you touched; tick the step in `PROGRESS.md` with one line of notes; commit
`git add -A; git commit -m "phase 01.S: <summary>"` (for example `phase 01.4: add IoVaultFileSystem and MemoryVaultFileSystem`).
First line of every Dart file you create: `// © 2026 Tephra. All rights reserved.` Every user-visible string goes into
`app/lib/l10n/app_en.arb` (run `cd app; flutter gen-l10n; cd ..` after editing it). Use your file-writing tool, never shell
heredocs. PowerShell 5.1: chain with `;`.

---

## Before you start

### Prerequisite gate

1. Open `PROGRESS.md`. Every checkbox of the **Phase 0 exit gate** must be ticked. If one is not, stop and tell the human.
2. `git status` must be clean on `main`. Then: `git checkout -b phase-01`.
3. Run and confirm they pass before changing anything: `flutter pub get`, `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`,
   `flutter analyze --fatal-infos`, `cd app; flutter test; cd ..`, `dart test tool/test`.

### Read these Phase 0 results first and copy two values into `PROGRESS.md`

Open each file and write the answers into `PROGRESS.md` under the heading `## Phase 1 inputs` (a 4-line list). Later steps refer to
these names:

| Name in this file | Where it comes from | Allowed values |
|---|---|---|
| `ENGINE` | `docs/decisions/0001-editor-engine.md`, sentence "Tephra uses <engine> for Source mode and Live Preview." | `A` (re_editor) or `B` (TextField + `buildTextSpan`). If the file says `C` (custom render object) or there is no decision: **stop and ask the human** — this phase does not cover a custom engine. |
| `ANDROID_WATCHER` | `docs/spikes/android-storage.md`, the line "decision for Phase 1" | `native` (`DirectoryWatcher`) or `polling` (`PollingDirectoryWatcher`, 1 s). |
| `ENGINE_HOOKS` | the "API notes" section of `docs/spikes/editor.md` | copy the exact class/method names found for: typed-text entry, Enter, Tab, undo grouping, shortcut mapping, per-line `buildTextSpan` (engine A) or `buildTextSpan` override (engine B). |
| `HIGHLIGHTER` | the spike used `re_highlight` (MIT, a dependency of `re_editor`) | this phase uses `re_highlight` for code-block highlighting regardless of `ENGINE`. |

### Locations Phase 0 left for you (do not recreate)

`app/lib/core/logging.dart`, `app/lib/theme/app_theme.dart`, `app/lib/l10n/app_en.arb`, `app/lib/welcome/welcome_screen.dart`
(replaced by the vault picker in step 01.12), `tool/check_licenses.dart`, `tool/gen_bench_vault.dart`, `tool/gen_test_vaults.dart`,
`test_vaults/syntax/` (24 notes: `01-headings.md` … `23-unicode.md` plus `Folder/Nested Note.md`; attachments `sample.png`,
`sample.pdf`, `sample.mp3`, `sample.mp4`), `test_vaults/edge/` (`crlf.md`, `bom.md`, `bom-crlf.md`, `mixed-endings.md`, `empty.md`,
`only-frontmatter.md`, `no-trailing-newline.md`, `trailing-spaces.md`, `tabs.md`, `malformed-utf8.md`, `long-line.md`,
`huge-5000-lines.md`, `নোট.md`, `🌋 Volcano.md`, `Spaces in name.md`, `unicode-nfd.md`, `deep/d01/…/d12/deep-note.md`,
`.hidden/hidden-note.md`), `test_vaults/real/` (300 generated notes).

### Names that later phases rely on (the Phase 1 → Phase 2+ contract)

Phase 2 (and later) locate these by name. **Create exactly these names at exactly these paths.** If you must deviate, stop and ask.

| Item | Exact name | Path |
|---|---|---|
| Core types | `VaultPath`, `TephraException` family, `Clock`, `SystemClock`, `contentHash` | `packages/tephra_core/lib/src/` |
| Vault types | `VaultFileSystem`, `IoVaultFileSystem` (public getter `rootDir`), `MemoryVaultFileSystem`, `TextDocument`, `LineEnding`, `VaultEntry`, `VaultChange` + 4 subclasses, `TrashMode` | `packages/tephra_vault/lib/src/` |
| Parser | `MarkdownParser.parse`, `ParsedNote`, all `Md*` nodes, `BlockRef`, `TaskItem`, `TaskStatus`, `LineIndex` | `packages/tephra_markdown/lib/src/` |
| `BlockRef` fields | `String id`, `int start`, `int end` (range of the **block that owns the ID**), plus `int idStart`, `int idEnd` (the `^id` text) | |
| `TaskItem` fields | `String status` (one character; `' '` = open), `String text`, `int start`, `int end` (whole list item), plus `int statusOffset`, `int line` | |
| Reading view | `ReadingView` widget; `ReadingViewController` with `scrollToOffset(int offset)` | `app/lib/reading/reading_view.dart` |
| Editor | `EditorController` (members in step 01.18), `EditorRegistry`, `editorRegistryProvider` | `app/lib/editor/editor_controller.dart`, `app/lib/editor/editor_registry.dart`, `app/lib/editor/providers.dart` |
| Commands | `TephraCommand`, `CommandRegistry`, `commandRegistryProvider` | `app/lib/commands/` |
| Quick switcher (simple) | `QuickSwitcher` | `app/lib/commands/quick_switcher.dart` |
| Fuzzy matcher | `FuzzyMatcher` | `app/lib/commands/fuzzy_matcher.dart` |
| Attachments | `AttachmentService` (log text `Pasted image` in its naming code) | `app/lib/editor/attachment_service.dart` |
| Vault session | `VaultSession`, `vaultSessionProvider`, `vaultFsProvider` | `app/lib/vault/` |
| Settings | `VaultSettings`, `VaultSettingsStore`, `AppSettings`, `TephraJsonStore`, `.obsidian` importer `ObsidianImporter` (reads `daily-notes.json`) | `app/lib/settings/`, `app/lib/core/`, `app/lib/vault/` |
| Workspace | `WorkspaceNotifier` with `openPath`, `retargetPath`, `activeNotePathProvider`, `ViewRegistry` + `viewRegistryProvider`, `TabContent`/`FileTabContent`, `ViewKind` | `app/lib/workspace/` |

The full list of providers (name, type, meaning, file) is the **Provider index** in "Hand-off to the next phase" at the end of this
file. Create every provider named there under exactly that name.

### Contract additions made in this phase (all additive)

| Contract | Addition | Why |
|---|---|---|
| §7.1 `VaultPath` | `static VaultPath? tryParse(String raw)`, `static String? checkName(String name)` (returns an error code or null), `VaultPath.compareTo`, `==`, `hashCode`, `toString()` returns `value` | explorer name validation, safe parsing |
| §7.1 | `ManualClock` (test clock) in `tephra_core` | tests of every package control time |
| §7.1 exceptions | constructors: `InvalidPathException(String message)`, `FileNotFoundException(VaultPath path)`, `FileConflictException(VaultPath path)`, `PermissionDeniedException(String message)`, `ParseException(String message)`, `SyncException(String message)`, `CryptoException(String message)` | exact shapes |
| §7.2 `IoVaultFileSystem` | optional named constructor parameters `ignore`, `systemTrash`, `watcherMode`, `clock`, `caseInsensitive`; getter `rootDir` | settings, tests |
| §7.2 | `VaultIgnore`, `SystemTrash`, `WatcherMode`, `AtomicFileWriter` | ignore rules (§6.1), trash, Android watcher choice |
| §7.3 `MdCodeBlock` | extra field `String info` (raw info string) | CommonMark conformance |
| §7.3 `MdHeading` | extra field `bool isSetext` | conformance, outline |
| §7.3 `MdList` | no extra fields (only those of §7.3) | stated to avoid doubt |
| §7.3 | new public types `ParserOptions`, `LinkDefinition`, `EmbedSize`, `TaskStatus`, `FrontmatterSplit`, `splitFrontmatter`, `decodeFrontmatterYaml` | parser configuration and helpers |
| §7.3 `MarkdownParser` | `static ParsedNote parseWith(String text, ParserOptions options)`, `static List<MdNode> parseInline(String text)` | conformance mode; callout titles |
| §7.3 `ParsedNote` | `Map<String, LinkDefinition> linkDefinitions`, `LineIndex lines` | reference links; offsets |
| §7.3 | **No new `Md*` node classes** (later phases switch exhaustively on the sealed hierarchy) | stability |
| §7.8 | `CommandRegistry` methods in step 01.14; `TephraCommand.mobileToolbarOrder` is **not** added (the order list lives in `mobile_toolbar.dart`) | |

---

## What exists when this phase is done

- `packages/tephra_core`: `VaultPath` (with 36 named tests), exceptions, `Clock`/`SystemClock`/`ManualClock`, `contentHash`.
- `packages/tephra_vault`: `TextDocument`, `VaultIgnore`, `VaultFileSystem`, `IoVaultFileSystem` (atomic writes, safe moves incl.
  case-only rename on Windows, trash, debounced watcher with self-write suppression), `MemoryVaultFileSystem`.
- `packages/tephra_markdown`: hand-written CommonMark + GFM + Obsidian parser with UTF-16 offsets on every node, `ParsedNote`,
  `LineIndex`; CommonMark spec conformance harness (≥ 85 % overall, 100 % on 7 named sections) and ~200 Obsidian syntax tests.
- App: vault picker (open/create/recent), Android storage-permission flow, `.tephra/vault.json`, one-time read-only `.obsidian`
  import; adaptive workspace (tabs, history, splits, phone layout); explorer; command registry, palette, simple quick switcher,
  hotkey settings; reading view with goldens; Source-mode editor with highlighting, editing helpers, find & replace, autosave,
  external-change merge, conflict dialog; attachments (paste/pick); phone keyboard toolbar.
- Round-trip proof over all fixture vaults (0 changed bytes), kill-during-typing harness, typing-budget measurement.

---

## Dependencies added in this phase

Add each with the command shown (never hand-edit versions), then `flutter pub get` at the repo root and
`dart run tool/check_licenses.dart` (must exit 0). Add them in step 01.1 (all at once) so later steps never touch pubspecs.

| Package | Where | Command (directory) | Purpose | Licence |
|---|---|---|---|---|
| `crypto` | `packages/tephra_core` | `dart pub add crypto` (package dir) | SHA-256 for `contentHash` | BSD-3-Clause |
| `path`, `logging`, `watcher` | `packages/tephra_vault` | `dart pub add path logging watcher` | path joins, logging, file watching | BSD-3-Clause |
| `yaml` | `packages/tephra_markdown` | `dart pub add yaml` | decode frontmatter into Dart maps | MIT |
| `re_highlight` | `app` | `flutter pub add re_highlight` | code-block syntax highlighting (reading view) | MIT |
| `re_editor` | `app` — **only if `ENGINE` = A** | `flutter pub add re_editor` | editor engine | MIT |
| `diff_match_patch` | `app` | `flutter pub add diff_match_patch` | three-way merge on external change | Apache-2.0 |
| `url_launcher` | `app` | `flutter pub add url_launcher` | external links, open files with system app | BSD-3-Clause |
| `file_picker` | `app` | `flutter pub add file_picker` | pick vault folder, pick attachments | MIT |
| `image_picker` | `app` | `flutter pub add image_picker` | Android photo / camera | BSD-3-Clause (Apache-2.0 for some native parts; both allowed) |
| `pasteboard` | `app` | `flutter pub add pasteboard` | read an image from the Windows clipboard | MIT |
| `desktop_drop` | `app` | `flutter pub add desktop_drop` | drop files onto the editor (Windows) | MIT |
| `permission_handler` | `app` | `flutter pub add permission_handler` | All-files-access on Android | MIT |
| `device_info_plus` | `app` | `flutter pub add device_info_plus` | Android SDK level (permission choice) | BSD-3-Clause |
| `scrollable_positioned_list` | `app` | `flutter pub add scrollable_positioned_list` | reading view `ListView` with jump-to-index | BSD-3-Clause |

Dev-only inside packages: `test` (already). The CommonMark `spec.json` is downloaded once in step 01.10 (not a dependency).

**Decisions recorded here (do not revisit):**
- **Clipboard image package: `pasteboard`** (MIT, C++ only). Reason: `super_clipboard` needs a Rust toolchain that is not installed on this machine.
- **Highlighter: `re_highlight`** for code blocks in the reading view (engine independent).
- **Android SAF is deferred.** There is no `SafVaultFileSystem` in this phase. Android uses "All files access" on shared storage or the
  app-private folder. Add the line "Idea: SAF-based `VaultFileSystem` for Android without All-files-access" to `PROGRESS.md` → Ideas
  (PHASE_PLAN 1.1 mentions it; this is a recorded deviation, write it in `PROGRESS.md` → Conflicts).
- **Indent unit:** vault setting `useTab` (default `true`, Obsidian's default) and `tabSize` (default `4`).
- **Moves never emit `FileMoved` from the watcher** (a watcher cannot see moves); `FileMoved` is produced only by Tephra's own
  operations in later phases (Phase 2's `IndexingVaultFileSystem`).
- **Path validity is Windows-strict on every OS**: a vault must be openable on Windows.

---

## Steps

### 01.1 Branch, dependencies, package skeleton folders

**Purpose** Add every dependency of this phase in one go and create the empty folder structure, so later steps only add source files.

**Files**
- modify `packages/tephra_core/pubspec.yaml`, `packages/tephra_vault/pubspec.yaml`, `packages/tephra_markdown/pubspec.yaml`, `app/pubspec.yaml`
- modify `app/android/app/src/main/AndroidManifest.xml` (permissions, step 01.12 uses them)
- create (empty `.gitkeep` is **not** allowed; create the folders when you create the first file in them)
- modify `PROGRESS.md` (Phase 1 inputs, Conflicts, Ideas)

**Implementation**
1. `git checkout -b phase-01` (if not done). Write the "Phase 1 inputs" block described above into `PROGRESS.md`.
2. In each package directory run the `dart pub add` command from the dependency table (`crypto` in `tephra_core`; `path logging watcher` in
   `tephra_vault`; `yaml` in `tephra_markdown`). `tephra_vault` already depends on `tephra_core` (Phase 0); keep it.
   `tephra_markdown` depends on `tephra_core` (Phase 0).
3. In `app/` run every `flutter pub add` line of the table (skip `re_editor` unless `ENGINE` = A). Then at the repo root `flutter pub get`.
4. `dart run tool/check_licenses.dart` → exit 0. If a package reports "unknown" licence, open its `LICENSE` file in the pub cache and
   add an entry to `tool/license_overrides.json` only if the file is one of the allowed licences (the override format is documented in
   `tool/check_licenses.dart`). `image_picker`'s platform packages are BSD-3-Clause; `permission_handler_*` MIT.
5. `AndroidManifest.xml`, inside `<manifest>` and before `<application>`, add exactly:
   ```xml
   <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
   ```
   and add `android:requestLegacyExternalStorage="true"` to the `<application>` tag. Do not add the CAMERA permission (`image_picker`
   uses the camera app through an intent).
6. Create the `lib/src/` and `test/` folders of each package only when you write the first file (steps 01.2 onward). Do not touch
   `lib/<package>.dart` yet; each step adds its `export` lines.
7. Commit `phase 01.1: add phase 1 dependencies`.

**Tests** None.

**Verify** `flutter pub get` → `Got dependencies!`; `dart run tool/check_licenses.dart` → exit 0 and `THIRD_PARTY_NOTICES.md` regenerated
(commit it); `flutter analyze --fatal-infos` → `No issues found!`.

**Pitfalls**
- `flutter pub add` inside `app/` writes caret versions; do not change them.
- `device_info_plus` and `permission_handler` need no Windows code; they compile on Windows as no-ops. Never call them on Windows.
- Do not add `sqlite3`, `drift` (Phase 2) or any markdown package (`markdown`, `flutter_markdown`) — the parser is hand-written.

---

### 01.2 `tephra_core`: exceptions, clocks, `contentHash`, `VaultPath`

**Purpose** The seam types every other package uses (conventions §7.1), with exhaustive path validation.

**Files** (all under `packages/tephra_core/`)
- `lib/src/exceptions.dart`, `lib/src/clock.dart`, `lib/src/content_hash.dart`, `lib/src/vault_path.dart`
- modify `lib/tephra_core.dart` (exports)
- `test/exceptions_test.dart`, `test/clock_test.dart`, `test/content_hash_test.dart`, `test/vault_path_test.dart`

**Implementation**
1. `exceptions.dart` — exactly the conventions shapes plus these constructors (all `const` where possible):
   ```dart
   abstract class TephraException implements Exception {
     const TephraException(this.message);
     final String message;
     @override
     String toString() => '$runtimeType: $message';
   }
   class InvalidPathException extends TephraException { const InvalidPathException(super.message); }
   class FileNotFoundException extends TephraException {
     FileNotFoundException(this.path) : super('File not found: ${path.value}');
     final VaultPath path;
   }
   class FileConflictException extends TephraException {
     FileConflictException(this.path) : super('Target already exists: ${path.value}');
     final VaultPath path;
   }
   class PermissionDeniedException extends TephraException { const PermissionDeniedException(super.message); }
   class ParseException extends TephraException { const ParseException(super.message); }
   class SyncException extends TephraException { const SyncException(super.message); }
   class CryptoException extends TephraException { const CryptoException(super.message); }
   ```
   (`FileNotFoundException` and `FileConflictException` are not `const` because they interpolate.)
2. `clock.dart`: `Clock`, `SystemClock` exactly per conventions, and
   ```dart
   /// Test clock; time only moves when [advance] or [set] is called.
   final class ManualClock implements Clock {
     ManualClock(DateTime start) : _now = start;
     DateTime _now;
     @override DateTime now() => _now;
     void advance(Duration d) => _now = _now.add(d);
     void set(DateTime t) => _now = t;
   }
   ```
3. `content_hash.dart`: `String contentHash(List<int> bytes) => sha256.convert(bytes).toString();` (`package:crypto/crypto.dart`;
   `Digest.toString()` is lower-case hex, 64 characters).
4. `vault_path.dart` — `final class VaultPath implements Comparable<VaultPath>` with a private const constructor
   `const VaultPath._(this.value)`, `static const VaultPath root = VaultPath._('');`.
   **Normalisation algorithm of `factory VaultPath(String raw)`** (apply in this order, no other steps):
   1. Replace every `\` with `/`.
   2. Split on `/`. Drop every empty segment (this strips leading/trailing `/` and collapses `//`).
   3. Walk the segments with a stack: segment `.` → skip; segment `..` → if the stack is empty throw
      `InvalidPathException('Path escapes the vault root: $raw')`, else pop; any other segment → validate (step 4) then push.
   4. **Segment validation** (`_segmentError(String s)` returns a short code or null; the factory throws
      `InvalidPathException('<code>: $raw')` for the first error):
      - contains U+0000 → `nul`; contains any code unit < 0x20 (control characters) → `control`;
      - contains any of `<` `>` `:` `"` `|` `?` `*` → `invalid-char`;
      - ends with `.` or ends with a space → `trailing-dot-or-space`;
      - the part before the first `.` (the whole segment if there is no `.`), upper-cased, equals one of
        `CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9` → `reserved-name`
        (so `con.md` and `CON.tar.gz` are rejected; `CONSOLE.md`, `COM0.md`, `COM10.md` are accepted);
      - `s.length > 255` (UTF-16 units) → `too-long`.
   5. If the stack is empty after the walk → throw `InvalidPathException('Empty path: $raw')`. (Hence `''`, `'/'`, `'.'`, `'a/..'` all throw;
      the root exists only as `VaultPath.root`.)
   6. `value = stack.join('/')`.
   Members: `final String value;` `name` (text after the last `/`, `''` for root); `stem` (name without its last extension; a name
   whose only `.` is at index 0 has stem = name and extension `''`); `extension` (lower-case, no dot; `''` if none);
   `parent` (`null` for root; the root for a top-level entry); `caseKey` (`value.toLowerCase()`); `isMarkdown` (`extension == 'md'`);
   `isRoot` (`value.isEmpty`); `join(String child)` = `VaultPath(isRoot ? child : '$value/$child')` (the child may contain `..`; it
   throws if the result escapes or is empty); `withName(String newName)`: throws `InvalidPathException` if this is root, if
   `newName` contains `/` or `\`, or if `_segmentError(newName) != null`; otherwise `parent` joined with `newName`;
   `isWithin(VaultPath folder)` = `folder.isRoot ? !isRoot : value.startsWith('${folder.value}/')` (a path is **not** within itself);
   `compareTo` compares `value` by code units (`value.compareTo(other.value)`); `==`/`hashCode` on `value`; `toString()` returns `value`.
   `static VaultPath? tryParse(String raw)` returns `null` instead of throwing. `static String? checkName(String name)` returns
   `'empty'` for `''`, `'separator'` if it contains `/` or `\`, else `_segmentError(name)` (used by the explorer's rename dialog).
   No Unicode normalisation is done: `Café` (NFC) and `Café` (NFD) are different paths (document this in the class comment).
5. Export from `lib/tephra_core.dart`: `export 'src/exceptions.dart'; export 'src/clock.dart'; export 'src/content_hash.dart'; export 'src/vault_path.dart';`
   (sorted, directives_ordering lint).

**Tests** (`vault_path_test.dart`, one `test()` per numbered line; "→" means expected `value`, "throws" means `InvalidPathException`)
1. `normalises backslashes`: `'Folder\\Note.md'` → `Folder/Note.md`.
2. `strips leading and trailing slashes`: `'/Folder/Note.md/'` → `Folder/Note.md`.
3. `collapses double slashes`: `'a//b///c.md'` → `a/b/c.md`.
4. `resolves dot segments`: `'./a/./b.md'` → `a/b.md`.
5. `resolves dot-dot inside the vault`: `'a/b/../c.md'` → `a/c.md`; `'a/../b.md'` → `b.md`.
6. `rejects dot-dot escaping the root`: `'../a.md'`, `'a/../../b.md'`, `'..'` throw.
7. `rejects empty results`: `''`, `'/'`, `'.'`, `'a/..'`, `'\\'` throw.
8. `rejects NUL`: `'a\u0000b.md'` throws.
9. `rejects control characters`: `'a\tb.md'`, `'a\nb.md'` throw.
10. `rejects each Windows-invalid character`: for each of `<`, `>`, `:`, `"`, `|`, `?`, `*` → `'a${c}b.md'` throws (7 assertions).
11. `rejects reserved device names`: `'CON'`, `'con.md'`, `'Folder/NUL.txt'`, `'com1'`, `'LPT9.md'`, `'aux.tar.gz'`, `'x/PRN'` throw.
12. `accepts names that only look reserved`: `'CONSOLE.md'`, `'COM0.md'`, `'COM10.md'`, `'Cons.md'`, `'LPT.md'`, `'NULL.md'` succeed.
13. `rejects trailing dot or space`: `'Note.'`, `'Note '`, `'a /b.md'`, `'a./b.md'` throw.
14. `accepts leading dot and inner spaces`: `'.hidden'` and `'My Note.md'` succeed.
15. `segment length limit`: a 255-character name succeeds, a 256-character one throws.
16. `name stem extension`: `Folder/Note.md` → `Note.md`/`Note`/`md`; `a.tar.gz` → stem `a.tar`, ext `gz`; `README` → ext `''`;
    `.hidden` → stem `.hidden`, ext `''`; `Image.PNG` → name `Image.PNG`, ext `png`.
17. `parent chain`: `a/b/c.md` → `a/b` → `a` → root → `null`.
18. `root properties`: `VaultPath.root.value == ''`, `isRoot`, `parent == null`, `name == ''`, `extension == ''`.
19. `caseKey and case-sensitive equality`: `VaultPath('A.md') != VaultPath('a.md')` and their `caseKey` are equal.
20. `join`: `VaultPath('a').join('b/c.md')` → `a/b/c.md`; `VaultPath.root.join('x.md')` → `x.md`; `VaultPath('a/b').join('../x.md')` → `a/x.md`;
    `VaultPath('a').join('../../x')` throws.
21. `withName`: `a/b.md`.withName(`c.md`) → `a/c.md`; withName(`x/y`) throws; `VaultPath.root.withName('x')` throws; withName(`bad:name`) throws.
22. `isWithin`: `a/b/c.md` within `a` and within `a/b` → true; `a/b` within `a/b` → false; `ab/c` within `a` → false;
    any non-root within root → true; root within root → false.
23. `compareTo orders by code units`: sorting `['b.md','A.md','a.md']` → `['A.md','a.md','b.md']`.
24. `equality and hashCode`: two instances from `'a\\b'` and `'a/b'` are equal with equal `hashCode`; usable as `Map` keys.
25. `unicode names`: `'নোট.md'`, `'🌋 Volcano.md'` succeed unchanged; NFD `'Café.md'` stays NFD (`value.length == 9`).
26. `tryParse`: returns `null` for `'../x'`, a `VaultPath` for `'x'`.
27. `checkName`: `''` → `'empty'`; `'a/b'` → `'separator'`; `'ok.md'` → `null`; `'a:b'` → `'invalid-char'`; `'con'` → `'reserved-name'`.
28. `toString returns value`.
`exceptions_test.dart`: each exception's `toString()` is `'<Type>: <message>'`; `FileNotFoundException(VaultPath('a.md')).message` contains `a.md`;
all are `TephraException`. `clock_test.dart`: `ManualClock.advance(Duration(seconds: 5))` moves `now()` by exactly 5 s; `SystemClock().now()` is within
1 s of `DateTime.now()`. `content_hash_test.dart`: `contentHash(utf8.encode('abc'))` =
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`; empty list →
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; output length 64 and lower-case.

**Verify** `cd packages/tephra_core; dart test; cd ../..` → all pass (≥ 40 assertions in ≥ 28 tests). Commit `phase 01.2: add VaultPath, exceptions, clocks, contentHash`.

**Pitfalls**
- Validate **each segment after** dot-resolution only for segments that are pushed; `..` itself must never be validated as a name.
- `'CON.'`: the trailing-dot check runs before the reserved-name check; either error is acceptable, the test only asserts "throws".
- Do not lower-case in `VaultPath`; only `caseKey` lower-cases.
- `lib/tephra_core.dart` exports only `src/` files and carries a library doc comment (conventions §2).

---

### 01.3 `tephra_vault`: `TextDocument`, ignore rules, interface and models

**Purpose** Define the file-system seam and the text round-trip rule of conventions §6.2 before any I/O code exists.

**Files** (under `packages/tephra_vault/`)
- `lib/src/text_document.dart`, `lib/src/vault_entry.dart`, `lib/src/vault_change.dart`, `lib/src/trash_mode.dart`,
  `lib/src/vault_ignore.dart`, `lib/src/system_trash.dart`, `lib/src/vault_file_system.dart`
- modify `lib/tephra_vault.dart`
- `test/text_document_test.dart`, `test/vault_ignore_test.dart`

**Implementation**
1. `vault_entry.dart`: `final class VaultEntry { const VaultEntry({required this.path, required this.isFolder, required this.size, required this.modified, this.created}); ... }`
   (fields per §7.2; `size` is 0 for folders; value equality on all fields).
2. `trash_mode.dart`: `enum TrashMode { system, vaultTrash, permanent }`.
3. `vault_change.dart`: `sealed class VaultChange { const VaultChange(this.path); final VaultPath path; }` and
   `final class FileCreated`, `FileModified`, `FileDeleted` (each `const X(super.path)`), `FileMoved` (`const FileMoved(super.path, {required this.from})`,
   `final VaultPath from;` — `path` is the new path). Add `toString()` on each (`FileCreated(a.md)`) and value equality.
4. `system_trash.dart`:
   ```dart
   /// Moves an absolute path to the operating system's recycle bin. Pure Dart cannot do this, so the app supplies the implementation.
   abstract interface class SystemTrash {
     /// Returns true when the item was moved to the OS trash; false when the platform cannot (caller falls back to the vault trash).
     Future<bool> moveToTrash(String absolutePath, {required bool isFolder});
   }
   ```
5. `vault_ignore.dart`:
   ```dart
   final class VaultIgnore {
     const VaultIgnore({this.showHidden = false, this.excludedFolders = const []});
     static const Set<String> alwaysIgnoredSegments = {'.obsidian', '.tephra', '.trash', '.git', 'node_modules'};
     final bool showHidden;
     final List<VaultPath> excludedFolders;
     /// True when [path] must not appear in listings, watcher events or (later) the index.
     bool isIgnored(VaultPath path);
   }
   ```
   `isIgnored`: split `path.value` on `/`; if any segment ∈ `alwaysIgnoredSegments` (exact, case-insensitive compare on `toLowerCase()`) → true;
   if `!showHidden` and any segment starts with `.` → true; if any `excluded` has `path == excluded || path.isWithin(excluded)` comparing by `caseKey`
   → true; else false. Root is never ignored.
6. `text_document.dart` — implement exactly §7.2's shape (`const TextDocument({required this.text, this.hasBom = false, this.lineEnding = LineEnding.lf, this.malformed = false})`),
   plus `copyWith({String? text, bool? hasBom, LineEnding? lineEnding, bool? malformed})`, `==`, `hashCode`.
   **`static TextDocument decode(List<int> bytes)`:**
   1. `hasBom = bytes.length >= 3 && bytes[0]==0xEF && bytes[1]==0xBB && bytes[2]==0xBF`; `body = hasBom ? bytes.sublist(3) : bytes` (use `Uint8List.sublistView` when `bytes` is a `Uint8List`).
      The BOM is stripped **manually**; never rely on `utf8.decode` to drop it.
   2. `malformed = false; String raw; try { raw = const Utf8Decoder().convert(body); } on FormatException { malformed = true; raw = const Utf8Decoder(allowMalformed: true).convert(body); }`
      (malformed bytes become U+FFFD).
   3. Count endings in one pass over `raw`: `crlf` = number of `\r\n`; `lf` = number of `\n` not preceded by `\r`; `cr` = number of `\r` not followed by `\n`.
      `lineEnding = crlf > (lf + cr) ? LineEnding.crlf : LineEnding.lf` (ties and zero → `lf`).
   4. `text` = `raw` with every `\r\n` replaced by `\n`, then every remaining `\r` replaced by `\n` (so the in-memory text never contains `\r`).
      Fast path: if `raw` contains no `\r`, `text = raw` (no copy).
   **`List<int> encode()`:** `out = []`; if `hasBom` add `0xEF,0xBB,0xBF`; `body = lineEnding == crlf ? text.replaceAll('\n', '\r\n') : text`; add `utf8.encode(body)`.
   `encode()` does not check `malformed` (the file system refuses to write malformed documents, step 01.4). Return `Uint8List`.
7. `vault_file_system.dart`: the `VaultFileSystem` interface **exactly** as in §7.2 (same names, parameter names and defaults). Doc comments say:
   `list` returns entries sorted by `path.value` (code-unit order), excludes ignored paths, skips (with a `warning` log) entries whose names are not valid
   `VaultPath`s; `stat` returns `null` if missing; `readBytes`/`readText` throw `FileNotFoundException`; `writeBytes`/`writeText` are atomic, create parent
   folders, and `writeText` throws `PermissionDeniedException` when `doc.malformed`; `move` throws `FileConflictException` if the target exists (except a
   case-only rename of the same entry) and creates missing parent folders of the target; `delete` of a missing path is a no-op; `watch()` is a broadcast stream.
8. `lib/tephra_vault.dart`: library doc + `export` of every file above (alphabetical), including (added in later steps) `io_vault_file_system.dart`,
   `memory_vault_file_system.dart`, `atomic_file_writer.dart`, `watcher_mode.dart`.

**Tests**
`text_document_test.dart` (bytes in → expectations):
1. `empty file`: `[]` → text `''`, no BOM, `lf`, not malformed; `encode()` → `[]`.
2. `lf file`: `'a\nb\n'` → `lf`; `encode()` equals the input bytes.
3. `crlf file`: `'a\r\nb\r\n'` → text `'a\nb\n'`, `crlf`; `encode()` equals input bytes.
4. `bom file`: `EF BB BF` + `'x'` → `hasBom`, text `'x'`; `encode()` equals input.
5. `bom only`: `[0xEF,0xBB,0xBF]` → text `''`, `hasBom`; `encode()` equals input.
6. `bom and crlf`: `EF BB BF` + `'# T\r\n\r\nx\r\n'` → both flags; `encode()` equals input.
7. `mixed endings dominant`: `'line 1\nline 2\r\nline 3\nline 4\r\nline 5\n'` (3 LF, 2 CRLF) → `lf`; text has no `\r`; and `'a\r\nb\r\nc\n'` → `crlf`.
8. `tie goes to lf`: `'a\r\nb\n'` → `lf`.
9. `lone CR becomes newline`: `'a\rb'` → text `'a\nb'`, `lf`.
10. `no trailing newline preserved`: `'Last'` → text `'Last'`; `encode()` equals input (no newline added).
11. `malformed bytes`: `[0x61, 0xFF, 0x62]` → `malformed == true`, text `'a�b'`.
12. `valid multi-byte`: Bangla `'বাংলা'`, emoji `'🌋'` round-trip through `decode`/`encode` unchanged and `malformed == false`.
13. `encode applies line ending without doubling`: `TextDocument(text: 'a\nb', lineEnding: LineEnding.crlf).encode()` → bytes of `'a\r\nb'`.
14. `bom plus crlf encode`: `TextDocument(text:'a\nb', hasBom:true, lineEnding: LineEnding.crlf).encode()` = `[0xEF,0xBB,0xBF,0x61,0x0D,0x0A,0x62]`.
15. `round trip law`: for the 6 files `crlf.md`, `bom.md`, `bom-crlf.md`, `no-trailing-newline.md`, `trailing-spaces.md`, `tabs.md` in `test_vaults/edge/`
    (path from `Directory.current`: `../../test_vaults/edge`), `encode(decode(bytes)) == bytes`. `mixed-endings.md`: decode → encode equals the original
    **after** replacing every `\r\n` with `\n` in both (documented lossy case: an unedited file is never written, so this never reaches disk).
`vault_ignore_test.dart`: `.obsidian/app.json`, `a/.tephra/x`, `.trash/n.md`, `.git/config`, `node_modules/x/y.md` ignored; `.hidden/n.md` ignored when
`showHidden == false`, **not** ignored when true; `.obsidian/x` still ignored when `showHidden == true`; `Archive/Old/n.md` ignored with excluded `Archive/Old`,
`Archive/Older/n.md` not; excluded comparison is case-insensitive; root and `Note.md` not ignored.

**Verify** `cd packages/tephra_vault; dart test; cd ../..`; `dart analyze packages/tephra_vault`. Commit `phase 01.3: add TextDocument, VaultIgnore and VaultFileSystem interface`.

**Pitfalls**
- Never `String.replaceAll('\r\n', '\n')` on a 100,000-character line without the fast-path check; `long-line.md` has no `\r`.
- `Utf8Decoder` strict mode throws `FormatException` for overlong/invalid sequences; that is the malformed signal.
- `TextDocument` is a value object: no I/O.

---

### 01.4 `IoVaultFileSystem` and `MemoryVaultFileSystem`

**Purpose** Safe local file access: atomic writes, safe moves, trash, listing; plus an in-memory twin for tests.

**Files** (under `packages/tephra_vault/`)
- `lib/src/atomic_file_writer.dart`, `lib/src/io_vault_file_system.dart`, `lib/src/memory_vault_file_system.dart`, `lib/src/watcher_mode.dart`
- `test/atomic_file_writer_test.dart`, `test/io_vault_file_system_test.dart`, `test/memory_vault_file_system_test.dart`,
  `test/vault_file_system_contract.dart` (shared test body, see below)

**Implementation**
1. `watcher_mode.dart`: `enum WatcherMode { native, polling }`.
2. `atomic_file_writer.dart`:
   ```dart
   final class AtomicFileWriter {
     AtomicFileWriter({Random? random, this.retries = 5, this.retryDelay = const Duration(milliseconds: 50), this.isWindows});
     /// Writes [bytes] to [target]: temp file `.<name>.tephra-tmp-<random>` in the SAME folder → flush → close → rename over target.
     /// [beforeRename] is a test hook (simulates a crash by throwing).
     Future<void> write(File target, List<int> bytes, {Future<void> Function(File temp)? beforeRename});
   }
   ```
   `write` algorithm:
   1. `dir = target.parent`; `await dir.create(recursive: true)`.
   2. `tmp = File(p.join(dir.path, '.${p.basename(target.path)}.tephra-tmp-${_randomHex(8)}'))` (`Random.secure()` unless a `Random` is injected;
      8 lower-case hex digits).
   3. `final raf = await tmp.open(mode: FileMode.write); try { await raf.writeFrom(bytes); await raf.flush(); } finally { await raf.close(); }`
      (flush **before** close; both awaited).
   4. `await beforeRename?.call(tmp)`.
   5. `try { await tmp.rename(target.path); return; } on FileSystemException catch (e) { first = e; }`. On Windows `File.rename` replaces an existing file; it fails
      only when the target is locked (OS error 5 or 32). If the failure was **not** one of those on Windows, or if the platform is not Windows, delete `tmp`
      (ignore errors) and rethrow the exception.
   6. **Windows locked-target fallback ("delete + rename", with the delete deferred so no data is ever lost).** For `attempt` in `1..retries` (5): `await Future<void>.delayed(retryDelay)` (50 ms);
      then try: if `target` exists, `backup = '<target>.tephra-bak-<random>'` in the same folder: `await target.rename(backup)`; then `await tmp.rename(target.path)`; then delete `backup`
      (ignore delete errors) and return. If the first rename (`target → backup`) fails, `continue` (next attempt). If the second rename fails, rename `backup` back to `target`
      (if that fails too, log `severe` with both paths and keep both files), then `continue`.
   7. After the last attempt: leave `tmp` on disk (it contains the user's new data), log `severe` with its path (never its content), and throw
      `PermissionDeniedException('Could not replace <basename>: file is locked')`.
   `isWindows` defaults to `Platform.isWindows` (parameter exists so tests can force the branch).
3. `io_vault_file_system.dart`:
   ```dart
   final class IoVaultFileSystem implements VaultFileSystem {
     IoVaultFileSystem(String rootDir, {VaultIgnore ignore = const VaultIgnore(), SystemTrash? systemTrash,
         WatcherMode watcherMode = WatcherMode.native, Clock clock = const SystemClock(), bool? caseInsensitive,
         AtomicFileWriter? writer});
     String get rootDir;   // absolute, normalised with p.normalize, no trailing separator
     ...
   }
   ```
   `caseInsensitive` defaults to `Platform.isWindows`. `rootDisplayPath` returns `rootDir`. Private helper `File _file(VaultPath p)` / `Directory _dir(VaultPath p)` use
   `p.join(rootDir, ...p.value.split('/'))` (`package:path`, never string concatenation). Private `_guard<T>(VaultPath path, Future<T> Function() body)` maps
   `PathNotFoundException` → `FileNotFoundException(path)`, a `FileSystemException` whose `osError?.errorCode` is 5 (Windows access denied), 13 (EACCES) or 1 (EPERM)
   → `PermissionDeniedException(message)`, anything else rethrown.
   Methods:
   - `list`: if the folder does not exist → `[]`. `Directory.list(recursive: recursive, followLinks: false)`; for each entity compute the relative path with `p.relative(entity.path, from: rootDir)`;
     `VaultPath.tryParse(rel)` → `null` → log `warning('skipped invalid path')` (never log the name's content beyond the vault-relative name is fine: log the name) and skip;
     skip when `ignore.isIgnored(path)`; folders: `VaultEntry(path, isFolder: true, size: 0, modified: stat.modified)`; files: size + modified from `FileStat` (`entity.stat()`).
     `created`: on Windows `stat.changed` (Windows reports creation time there), otherwise `null`. Skip `Link` entities. Sort by `path.value`. Entities that vanish
     during listing (`FileSystemException`) are skipped.
   - `stat`: `FileSystemEntity.type(path, followLinks: false)`; `notFound` → `null`; else build a `VaultEntry` as above. **Does not apply ignore rules** (the app reads `.tephra/*`).
   - `readBytes`: `_guard(... File.readAsBytes())`. `readText`: `TextDocument.decode(await readBytes(path))`.
   - `writeBytes`: ensure the path is not a directory (`FileSystemEntity.isDirectory` → throw `FileConflictException`); `await _writer.write(file, bytes)`; then `_rememberSelfWrite(path, contentHash(bytes))`.
     Order matters: call `_rememberSelfWrite` **before** the rename completes is not possible; instead record it *before* starting the write (so the watcher event produced by the rename is already
     covered) and remove the record if the write throws.
   - `writeText(path, doc)`: if `doc.malformed` → `PermissionDeniedException('Refusing to overwrite a file that is not valid UTF-8')`; else `writeBytes(path, doc.encode())`.
   - `createFolder`: `Directory.create(recursive: true)`; if a **file** exists at the path → `FileConflictException`. Records self-op `created` for the path.
   - `move(from, to)`:
     1. `src = await FileSystemEntity.type(from)`; `notFound` → `FileNotFoundException(from)`.
     2. `caseOnly = from != to && from.caseKey == to.caseKey && caseInsensitive`.
     3. If not `caseOnly` and the target exists (`FileSystemEntity.type(to) != notFound`) → `FileConflictException(to)`. If `from == to` → return (no-op).
     4. `await _dir(to.parent).create(recursive: true)` (when `to.parent` is not root).
     5. If `caseOnly`: two-step rename through a temp name in the same folder: `tmpName = '.${from.name}.tephra-case-${hex8}'`; `rename(from → tmp)`; `rename(tmp → to)`;
        if the second rename fails, rename `tmp` back to `from` and rethrow. (A direct rename `note.md → Note.md` is a no-op on NTFS in some Dart versions.)
     6. Else a single `File.rename` / `Directory.rename`.
     7. Record self-ops: `_selfDeleted[from]`, `_selfCreated[to]` (for a folder: record the folder paths only; descendant events are filtered by the prefix check in `_isSelf`).
   - `delete(path, {mode = TrashMode.vaultTrash})`: `type == notFound` → return. Record self-delete. Then by `mode`:
     - `permanent`: `File.delete()` or `Directory.delete(recursive: true)`.
     - `system`: `if (systemTrash != null && await systemTrash!.moveToTrash(abs, isFolder: isFolder)) return;` else log `warning('system trash unavailable, using vault trash')` and fall through to `vaultTrash`.
     - `vaultTrash`: destination `.trash/<relative path>`: `dest = VaultPath('.trash/${path.value}')`; if `dest` exists, find the first free numeric suffix: for files
       `<stem> 1.<ext>`, `<stem> 2.<ext>` (no extension: `<name> 1`), for folders `<name> 1`, `<name> 2`, … in the same trash folder; create parent folders; then rename
       (`File.rename` / `Directory.rename`; `.trash` lives inside the vault so it is the same volume). Never overwrite anything in `.trash`.
     Android never receives a `systemTrash` (the app passes `null`), so `TrashMode.system` behaves as `vaultTrash` there.
   - `dispose`: cancel the watcher subscription and timers, close the stream controller. Idempotent.
   - `Future<int> cleanStaleTemps({Duration olderThan = const Duration(hours: 24)})`: walk the vault (own recursive walk, **including** hidden folders except `.git` and `node_modules`),
     delete files whose basename matches `^\..*\.tephra-(tmp|bak|case)-[0-9a-f]{8}$` and whose `modified` is older than `olderThan`; return the count. Called once, in the background, when a vault opens (step 01.12).
4. `memory_vault_file_system.dart`: `final class MemoryVaultFileSystem implements VaultFileSystem` with
   `MemoryVaultFileSystem({Clock clock = const SystemClock(), VaultIgnore ignore = const VaultIgnore(), bool caseInsensitive = false})`; storage `Map<VaultPath, _Node>` (file: `Uint8List` bytes + `modified`;
   folder). Same semantics as `IoVaultFileSystem` (atomicity trivial): `list` sorted and filtered, `stat` unfiltered, `FileConflictException`, trash folder `.trash/...` with the same numeric-suffix rule
   (`system` behaves as `vaultTrash`), case-only move allowed when `caseInsensitive`. Extra helpers for tests: `void putText(String path, String text)`, `void putBytes(String path, List<int> bytes)`,
   `String? textOf(String path)`, `int writeCount` (incremented by every `writeBytes`/`writeText`), `List<String> writeLog`, and `void emit(VaultChange c)` pushing onto `watch()` (which is a broadcast
   `StreamController<VaultChange>.broadcast(sync: true)`). `writeText` also refuses malformed documents. Writes via the interface do **not** emit watcher events (mirrors self-write suppression).
5. **Shared contract test** `test/vault_file_system_contract.dart`: `void runVaultFileSystemContract(String name, Future<VaultFileSystem> Function() create)`; registered by both implementation test files.
   Test names and expectations (each starts from a fresh empty vault):
   1. `write then read text`: `writeText('a.md', TextDocument(text:'hi'))` → `readText` text `'hi'`; parent folders created for `'x/y/z.md'`.
   2. `write is bytes exact`: `writeBytes('b.bin', [0,1,2,255])` → `readBytes` equal.
   3. `missing file read throws`: `readBytes('nope.md')` throws `FileNotFoundException`; `stat('nope.md')` is `null`.
   4. `list sorted and recursive`: files `b.md`, `a/c.md`, `A.md` → recursive list contains folder `a` and files; order by value: `A.md`, `a`, `a/c.md`, `b.md`;
      non-recursive list of root excludes `a/c.md`.
   5. `list hides ignored paths`: `.obsidian/app.json`, `.trash/x.md`, `.hidden/h.md` absent from `list()`, but `stat(VaultPath('.obsidian/app.json'))` is non-null.
   6. `move file`: `a.md → Sub/b.md` creates `Sub`, source gone.
   7. `move conflict`: target exists → `FileConflictException`; both files unchanged.
   8. `move folder`: `d/x.md`, `d/e/y.md` → `d2`: all descendants present under `d2`, none under `d`.
   9. `move missing source throws FileNotFoundException`.
   10. `delete vaultTrash`: `Folder/n.md` → `.trash/Folder/n.md` exists, original gone.
   11. `delete vaultTrash collision`: delete `n.md`, recreate, delete again → `.trash/n.md` and `.trash/n 1.md`; a third time → `.trash/n 2.md`.
   12. `delete permanent`: file really gone, `.trash` not created.
   13. `delete folder vaultTrash keeps structure`: `d/e/y.md` → `.trash/d/e/y.md`.
   14. `delete missing is no-op`.
   15. `delete system falls back to vault trash when no SystemTrash is provided`.
   16. `writeText refuses malformed documents`: `TextDocument(text:'x', malformed:true)` → `PermissionDeniedException`; file unchanged.
   17. `write over folder throws FileConflictException`.
   18. `createFolder then stat`: `isFolder == true`; createFolder over an existing **file** → `FileConflictException`.
   19. `stat reports size and modified`: size equals byte length; `modified` within 5 s of now (IO) or equal to the injected clock (memory).
6. IO-only tests (`io_vault_file_system_test.dart`, in a temp dir from `Directory.systemTemp.createTempSync('tephra_vault_test')`, removed in `tearDown`):
   1. `no temp files left after a successful write` (list the real folder including hidden: only the target).
   2. `unchanged bytes of other files` (write `a.md`, write `b.md`: `a.md` bytes identical).
   3. `case-only rename` (only when `caseInsensitive` forced `true` **and** `Platform.isWindows`; skip otherwise with `skip:` reason string): `note.md → Note.md`; `list` shows only `Note.md`.
   4. `list skips invalid names` (create `bad:name`-like entries only where the OS allows; on Windows skip this test with a reason).
   5. `invalid file name on disk is skipped` — create `con.txt` via `File('\\\\?\\...')` is not allowed on Windows; on non-Windows create `CON.txt` and assert it is skipped. Skip on Windows with reason.
   6. `cleanStaleTemps removes only old temp files` (create `.a.md.tephra-tmp-0a1b2c3d` with `setLastModified` 2 days ago, and a fresh one, and a normal `.hidden`; result count 1).
   7. `systemTrash is used when provided and true` (fake `SystemTrash` returning `true` records the absolute path; the file is not touched by the fake and the fs does not also move it) and
      `falls back when it returns false`.
7. `atomic_file_writer_test.dart`:
   1. `crash before rename leaves the original untouched`: write `'old'`; call `write(file, 'new', beforeRename: (_) async => throw StateError('boom'))` → throws; file still `'old'`; a `.x.tephra-tmp-*` file with `'new'` exists.
   2. `crash after flush of a brand-new file leaves no target file` (target missing, same hook) → target does not exist.
   3. `no empty file is ever visible`: run 200 sequential writes of growing content while a concurrent loop (`Timer.periodic(1 ms)`) reads the file when it exists: every observed content is a complete earlier version (lengths from the written set), never empty or partial.
   4. `temp file lives in the same folder and starts with a dot` (hook inspects `temp.parent.path == target.parent.path`, `basename` matches `^\..+\.tephra-tmp-[0-9a-f]{8}$`).
   5. `locked target fallback` (Windows only; skip elsewhere): open the target with `RandomAccessFile` in `FileMode.write` (keeps a handle), start `write` with `retryDelay: 10ms`, close the handle after 30 ms → write succeeds; content new. Another case: handle never closed → throws `PermissionDeniedException` after 5 attempts and the `tmp` file still holds the new bytes.
   6. `non-windows failure rethrows and deletes the temp` (`isWindows: false`, hook that makes the target a directory: create a directory at the target path before writing → `rename` fails → exception propagates; no `tmp` left).

**Verify** `cd packages/tephra_vault; dart test; cd ../..` (all pass on Windows; skipped tests name their reason). `dart analyze packages/tephra_vault`. Commit `phase 01.4: add IoVaultFileSystem and MemoryVaultFileSystem`.

**Pitfalls**
- Never write directly to the target file. Never `File.writeAsBytes` on a note.
- `flush()` must complete before `close()`; both must be awaited (lint `unawaited_futures` catches a missing await).
- The temp name starts with `.`, so ignore rules hide it from listings and from the (later) indexer; that is deliberate.
- `VaultPath('.trash/x')` is valid (leading dot is allowed); do not validate trash paths with the "hidden" rule.
- Do not call `Platform.isWindows` inside `MemoryVaultFileSystem`.

---

### 01.5 Watcher: debounce, merge rules, self-write suppression, Android watcher choice

**Purpose** `watch()` reports external changes (Obsidian, sync tools) within ~1 s and never reports Tephra's own writes.

**Files**
- modify `packages/tephra_vault/lib/src/io_vault_file_system.dart` (implement `watch()` and `_rememberSelfWrite`)
- `packages/tephra_vault/lib/src/change_debouncer.dart` (pure, new)
- `packages/tephra_vault/test/change_debouncer_test.dart`, `packages/tephra_vault/test/io_watch_test.dart`

**Implementation**
1. `ChangeDebouncer` (pure, no I/O, unit-testable with fake time):
   ```dart
   enum RawChangeKind { added, modified, removed }
   final class ChangeDebouncer {
     ChangeDebouncer({required this.clock, this.quiet = const Duration(milliseconds: 150), this.maxWait = const Duration(milliseconds: 500));
     void add(VaultPath path, RawChangeKind kind);
     /// Returns the merged changes when the quiet period (150 ms since the last event) or maxWait (500 ms since the first pending event) has elapsed, else null.
     List<MergedChange>? flushIfDue();
     DateTime? get nextDueAt;   // for scheduling a timer
   }
   final class MergedChange { final VaultPath path; final RawChangeKind kind; }
   ```
   Merge table per path (earlier → later in the same window): `added`+`modified` → `added`; `added`+`removed` → dropped (nothing); `modified`+`modified` → `modified`; `modified`+`removed` → `removed`;
   `removed`+`added` → `modified`; `removed`+`modified` → `modified`; `modified`+`added` → `modified`; `removed`+`removed` → `removed`; `added`+`added` → `added`. Output order: by first-seen time.
2. `watch()` in `IoVaultFileSystem`:
   - Lazy: the first listener creates the OS watcher; when the last listener cancels, the OS watcher is cancelled (`StreamController.broadcast(onListen, onCancel)`).
   - Watcher: `watcherMode == WatcherMode.polling` → `PollingDirectoryWatcher(rootDir, pollingDelay: Duration(seconds: 1))`, else `DirectoryWatcher(rootDir)` (both from `package:watcher`).
     Windows always uses `WatcherMode.native`. **The app chooses the mode** from `ANDROID_WATCHER` (step 01.12's `VaultFileSystemFactory`).
   - For each `WatchEvent`: `rel = p.relative(event.path, from: rootDir)`; `path = VaultPath.tryParse(rel)`; `null` or `ignore.isIgnored(path)` → drop; map `ChangeType.ADD/MODIFY/REMOVE` to `RawChangeKind`; `debouncer.add`.
   - A `Timer` fires at `debouncer.nextDueAt`; on firing call `flushIfDue()`; for every `MergedChange` produce a `VaultChange` after these checks:
     1. **Self-suppression**: `_isSelf(change)`: for `added`/`modified`: if `_selfWrites[path]` exists and `now < until` → read the file's bytes and compare `contentHash(bytes)` to the remembered hash; equal → drop; different → emit
        (an external tool changed it right after us). For `removed`: dropped when `_selfDeleted` has the path (or an ancestor folder of it) with `now < until`. For `added`: also dropped when `_selfCreated` has the path (or an ancestor) with `now < until`.
        Entries live **2 seconds** (`until = clock.now() + 2 s`); expired entries are purged on every flush.
     2. For `added`/`modified`: `stat`; if the file no longer exists → treat as `removed`; if it is a folder → drop (folder events are not reported).
     3. `added` → `FileCreated(path)`, `modified` → `FileModified(path)`, `removed` → `FileDeleted(path)`. **Never `FileMoved`.**
   - `_rememberSelfWrite(path, hash)`: `_selfWrites[path] = (hash, clock.now() + 2s)`; a repeated write overwrites the entry. Called by `writeBytes` **before** the atomic write starts and rolled back if it throws.
   - Watcher errors (`onError`) are logged at `warning`, and the OS watcher is recreated once after 1 s; two consecutive failures → log `severe` and keep the stream open without events.
3. `MemoryVaultFileSystem.watch()` stays manual (`emit`). `emit` applies `VaultIgnore` too.
4. Add `Duration`/`Timer` through an injectable `Clock` only for the entry lifetimes; the debounce timer itself uses `Timer` and the tests below pump real time with short `quiet`/`maxWait` constructor overrides
   (`IoVaultFileSystem` accepts a `@visibleForTesting`-free named parameter `Duration debounce = const Duration(milliseconds: 150)`; add it to the constructor).

**Tests**
`change_debouncer_test.dart` (with `ManualClock`): every row of the merge table (9 rows) → expected result; `flushIfDue` returns `null` at +149 ms and the merged list at +150 ms; continuous events every 100 ms for 600 ms flush at +500 ms (maxWait);
order is first-seen; `added+removed` leaves nothing (flush returns an empty list, not `null`, once due).
`io_watch_test.dart` (real temp dir, `debounce: Duration(milliseconds: 50)` for speed; each test waits at most 3 s with `Stream.first.timeout`):
1. `external create is reported`: write `File(<dir>/new.md)` directly with `dart:io` → `FileCreated(new.md)`.
2. `external modify is reported`: create via `dart:io`, wait for the create event, append → `FileModified`.
3. `external delete is reported` → `FileDeleted`.
4. `own writeText is not reported`: subscribe, `writeText('own.md', …)`, wait 600 ms → no events.
5. `own write followed by an external write with different content is reported` (write via fs, then immediately overwrite via `dart:io` with other bytes within 500 ms → exactly one `FileModified`).
6. `own delete and own move are not reported`.
7. `ignored paths produce no events` (`.obsidian/x.json`, `.hidden/h.md`, the writer's own `.tmp` files).
8. `burst of 20 writes yields one event per path` (20 `dart:io` appends to one file within 100 ms → exactly one `FileModified`).
9. `cancelling the last listener stops the OS watcher` (no exception on `dispose`).
10. `external pickup latency`: external modify → event within 1000 ms with the **default** 150 ms debounce (measure with `Stopwatch`; assert < 1000 ms; print the number for `PROGRESS.md`).
Polling-mode test: `WatcherMode.polling` creates, modifies, deletes → three events within 3 s each.

**Verify** `cd packages/tephra_vault; dart test; cd ../..`. On the Windows machine run the package tests 3 times to detect flakiness (watcher tests must not be flaky). Commit `phase 01.5: add debounced watcher with self-write suppression`.

**Pitfalls**
- `package:watcher` reports only files. Folder deletion arrives as one `removed` per file; that is acceptable (the explorer refreshes the parent folder on any event).
- Never emit events for the temp files of the atomic writer (they start with `.` and are ignored).
- On Android the `ANDROID_WATCHER` decision comes from the spike; do not re-measure it here.
- Read the file for the hash check **after** debounce, not on each raw event (cost).

---

### 01.6 `tephra_markdown`: AST, options, `LineIndex`, frontmatter, parser utilities

**Purpose** Everything the block and inline parsers share: the node classes (conventions §7.3), parser options, offset helpers, Unicode classification, entity decoding and frontmatter extraction.

**Files** (under `packages/tephra_markdown/`)
- `lib/src/nodes.dart`, `lib/src/parser_options.dart`, `lib/src/line_index.dart`, `lib/src/note_models.dart` (`BlockRef`, `TaskItem`, `TaskStatus`, `EmbedSize`, `LinkDefinition`, enums)
- `lib/src/frontmatter.dart`, `lib/src/util/offset_map.dart`, `lib/src/util/unicode.dart`, `lib/src/util/entities.dart`
- modify `lib/tephra_markdown.dart` (exports; the `src/block`, `src/inline`, `src/util` files stay private except those listed here)
- `test/line_index_test.dart`, `test/frontmatter_test.dart`, `test/util/offset_map_test.dart`, `test/util/unicode_test.dart`, `test/util/entities_test.dart`

**Implementation**
1. `nodes.dart`: `sealed class MdNode { MdNode(this.start, this.end); final int start; final int end; List<MdNode> get children; }`. Every concrete node is a `final class` with the constructor
   shape `X(super.start, super.end, {<its fields>, List<MdNode> children = const []})`; leaf nodes override `children` with `const []`. Nodes are immutable. **Do not add any `Md*` class beyond this list**
   (later phases switch exhaustively over the sealed type). Fields (all `final`):

   | Node | Extra fields | `children` |
   |---|---|---|
   | `MdDocument` | — | blocks (first is `MdFrontmatter` when present) |
   | `MdFrontmatter` | `String yaml` (text between the `---` lines), `int contentStart` (offset of the first character after the opening line) | none |
   | `MdHeading` | `int level`, `String? blockId`, `bool isSetext` | inlines |
   | `MdParagraph` | — | inlines |
   | `MdBlockQuote` | — | blocks |
   | `MdCallout` | `String type` (lower-cased), `String? title` (raw text after the marker, trimmed; `null` if empty), `CalloutFold fold` | blocks (body only; the marker line is not a child) |
   | `MdList` | `bool ordered`, `int startNumber`, `bool tight` | `MdListItem`s |
   | `MdListItem` | `TaskStatus? task` | blocks |
   | `MdCodeBlock` | `String? language` (first word of `info`, `null` if empty), `String info`, `String code`, `bool fenced` | none |
   | `MdMathBlock` | `String tex` | none |
   | `MdTable` | `List<TableAlign> aligns` | `MdTableRow`s (first has `header == true`) |
   | `MdTableRow` | `bool header` | `MdTableCell`s |
   | `MdTableCell` | — | inlines |
   | `MdThematicBreak` | — | none |
   | `MdHtmlBlock` | `String html` | none |
   | `MdFootnoteDefinition` | `String label` | blocks |
   | `MdCommentBlock` | `String text` | none |
   | `MdText` | `String text` (decoded: backslash escapes and entities already resolved) | none |
   | `MdEmphasis`, `MdStrong`, `MdStrikethrough`, `MdHighlight` | — | inlines |
   | `MdInlineCode` | `String code` | none |
   | `MdWikiLink` | `String target`, `String? heading`, `String? blockRef`, `String? alias`, `bool embed`, `EmbedSize? size`, `String? pdfPage` | none |
   | `MdLink` | `String url`, `String? title`, `bool image` | inlines (link text, or the alt text nodes for an image) |
   | `MdAutolink` | `String url` | none |
   | `MdTag` | `String name` (without `#`, original case) | none |
   | `MdBlockId` | `String id` | none |
   | `MdInlineMath` | `String tex` | none |
   | `MdFootnoteRef` | `String label` | none |
   | `MdInlineFootnote` | — | inlines |
   | `MdCommentInline` | `String text` | none |
   | `MdHtmlInline` | `String html` | none |
   | `MdHardBreak`, `MdSoftBreak` | — | none |

   Also in `note_models.dart`: `enum CalloutFold { none, expanded, collapsed }`, `enum TableAlign { none, left, center, right }`,
   `final class EmbedSize { const EmbedSize(this.width, [this.height]); final int width; final int? height; }`,
   `final class TaskStatus { const TaskStatus(this.char, this.offset); final String char /* exactly one Unicode code point */; final int offset /* UTF-16 offset of the char */; bool get isOpen => char == ' '; bool get isDone => char == 'x' || char == 'X'; }`,
   `final class LinkDefinition { const LinkDefinition(this.label, this.url, this.title); }`,
   `final class BlockRef { const BlockRef({required this.id, required this.start, required this.end, required this.idStart, required this.idEnd}); ... }` (fields per the contract table above),
   `final class TaskItem { const TaskItem({required this.status, required this.text, required this.start, required this.end, required this.statusOffset, required this.line}); ... }`.
   All with value equality.
2. `parser_options.dart`: `final class ParserOptions { const ParserOptions({this.obsidian = true, this.gfm = true}); static const ParserOptions commonMark = ParserOptions(obsidian: false, gfm: false); final bool obsidian; final bool gfm; }`.
   - `obsidian: false` disables: frontmatter, wikilinks/embeds, tags, `==highlight==`, `%%comments%%`, block IDs, callouts, `$` math, footnotes, task status beyond GFM's `[ ]`/`[x]`/`[X]`.
   - `gfm: false` disables: tables, `~~strikethrough~~`, task lists, extended autolinks (bare `http://`, `https://`, `www.`).
3. `line_index.dart`: `LineIndex` exactly as specified in Phase 2 step 02.3 (the contract is repeated here so Phase 1 owns it):
   ```dart
   final class LineIndex {
     LineIndex(String text);                 // records the offset of every line start (0 and each index after '\n')
     int get lineCount;                      // '' → 1; 'a\n' → 2
     int lineOf(int offset);                 // binary search; offset == text.length → last line; RangeError if < 0 or > length
     int lineStart(int line);
     int lineEnd(int line);                  // offset of the '\n' ending the line, or text.length for the last line
     String lineText(String text, int line); // without '\n'
   }
   ```
4. `util/unicode.dart`: pure functions used by flanking rules — `bool isUnicodeWhitespace(int cp)` (Unicode `Zs` category, plus tab, LF, FF, CR, and U+0085 is **not** included; `Zs` = U+0020, U+00A0, U+1680, U+2000–U+200A, U+202F, U+205F, U+3000),
   `bool isUnicodePunctuation(int cp)` (ASCII punctuation `!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~` plus any code point whose general category starts with `P` or `S` — implement with
   `RegExp(r'[\p{P}\p{S}]', unicode: true)` on the one-character string), `bool isAsciiPunctuation(int cp)`, `bool isLetterOrDigit(int cp)` (`\p{L}`, `\p{N}`, `\p{M}`), `String caseFold(String s)` (`s.toLowerCase()` then replace `ß` by `ss`;
   used for reference labels), `String normalizeLabel(String s)` (trim, collapse every whitespace run to one space, `caseFold`).
5. `util/entities.dart`: `String? decodeEntity(String name)` (without `&`/`;`), `int? parseNumericEntity(String body)`; `final Map<String, String> htmlEntities`. Content of the table: the **252 HTML 4.01 named entities** (the W3C lists `HTMLlat1`, `HTMLsymbol`,
   `HTMLspecial`: `quot amp lt gt nbsp iexcl cent … diams`; every name of those three lists, with its code point) **plus** these four used by the CommonMark examples: `HilbertSpace` → U+210B, `DifferentialD` → U+2146, `ClockwiseContourIntegral` → U+2232, `ngE` → U+2267 U+0338.
   Numeric: `#` + 1–7 decimal digits or `#x`/`#X` + 1–6 hex digits; code point 0, a surrogate (0xD800–0xDFFF) or > 0x10FFFF → U+FFFD. `&` sequences not matching the grammar stay literal.
6. `util/offset_map.dart`: maps indexes of a **virtual inline text** (what the inline parser sees) to absolute source offsets:
   ```dart
   final class OffsetMap {
     OffsetMap(); // add segments in order
     void addSegment(int srcStart, int srcEnd);            // appends text of source range [srcStart, srcEnd); between consecutive segments a virtual '\n' is inserted automatically
     String buildText(String source);                      // concatenation of segments joined by '\n'
     int toSource(int virtualIndex);                       // start-style mapping; the virtual '\n' between segments maps to the source offset of the newline that ended the previous segment (= previous segment's srcEnd)
     int toSourceEnd(int virtualIndexExclusive);           // virtualIndexExclusive == 0 ? toSource(0) : toSource(virtualIndexExclusive - 1) + 1
   }
   ```
   (binary search over segment start indexes). A trailing-space-trimmed segment still maps correctly because the map stores the exact source range of each segment.
7. `frontmatter.dart`:
   ```dart
   final class FrontmatterSplit { const FrontmatterSplit({required this.start, required this.end, required this.yaml, required this.contentStart, required this.bodyStart}); ... }
   FrontmatterSplit? splitFrontmatter(String text);
   Map<String, Object?>? decodeFrontmatterYaml(String yaml);   // null = invalid YAML; {} for empty
   ```
   `splitFrontmatter`: the first line of `text` (up to the first `\n`) must be `---` optionally followed by spaces or tabs. Then scan following lines for the first line that is exactly `---` followed only by spaces/tabs (also accept it as the **last** line without a trailing `\n`). No closing line → `null`.
   Result: `start = 0`; `end` = offset right after the closing `---` (before any trailing spaces and before the `\n`); `contentStart` = offset after the opening line's `\n`; `yaml` = `text.substring(contentStart, closingLineStart)` with its last `\n` removed (empty string if the delimiters are adjacent);
   `bodyStart` = offset after the closing line's `\n` (or `text.length`). The first line `--- x` (text after the dashes) is **not** frontmatter. A text that starts with a BOM is not special-cased (the file layer strips the BOM).
   `decodeFrontmatterYaml`: `loadYaml(yaml)` from `package:yaml`; `YamlException` → `null`; `null` result (empty/comment-only) → `{}`; a non-map top level (a scalar or list) → `null`;
   convert recursively to plain Dart (`YamlMap` → `Map<String, Object?>` with keys `toString()`; `YamlList` → `List<Object?>`; scalars as is). The YAML library does not parse dates; they stay `String`s — keep that.

**Tests**
- `line_index_test.dart`: `''` → 1 line; `'a\n'` → 2 lines, `lineStart(1) == 2`, `lineEnd(0) == 1`, `lineEnd(1) == 2`; `lineOf(0)=0`, `lineOf(1)=0` (the `\n` belongs to line 0), `lineOf(2)=1`; `lineOf(text.length)` is the last line; `lineOf(-1)` and `lineOf(length+1)` throw `RangeError`;
  `lineText('ab\ncd', 1) == 'cd'`; text with emoji (2 units) keeps UTF-16 offsets; 10,000-line text builds in < 20 ms (`Stopwatch`).
- `frontmatter_test.dart`: `'---\ntitle: T\n---\nBody'` → start 0, end 17, yaml `'title: T'`, contentStart 4, bodyStart 18; `'---\n---\nx'` → yaml `''`; `'---   \na: 1\n---  \nx'` valid; `'---\na: 1'` (no closing) → `null`; `'\n---\na: 1\n---'` → `null` (not at start);
  `'--- x\na\n---'` → `null`; `'---\na: 1\n---'` (closing at EOF, no newline) → bodyStart == text.length; decode: `'tags: [a, b]\naliases: X\nn: {k: 1}'` → map with list/string/nested map; `'a: [1'` → `null`; `''` → `{}`; `'# only comment'` → `{}`; `'- a\n- b'` → `null`; `'d: 2026-01-01'` → `{'d': '2026-01-01'}` (String).
- `offset_map_test.dart`: two segments `[0,3)` and `[6,9)` of `'abc\n> def'`-like text (build a real example with a `> ` prefix) → `buildText` = `'abc\ndef'`; `toSource(0)=0`; `toSource(3)=3` (the virtual newline); `toSource(4)=6`; `toSourceEnd(7)=9`; `toSourceEnd(3)=3`.
- `unicode_test.dart`: `isUnicodePunctuation` true for `!`, `—` (U+2014), `。`, `€` (a `S` symbol), false for `a`, `5`, space; `isUnicodeWhitespace` true for NBSP, U+3000, `\t`; `normalizeLabel('  Foo \n BAR ')` = `'foo bar'`; `caseFold('ẞ')`/`'ß'` both give `'ss'` where `ẞ.toLowerCase()` is `ß`.
- `entities_test.dart`: `decodeEntity('amp')='&'`, `'copy'='©'`, `'frac34'='¾'`, `'ngE'='≧̸'`, `'nosuch'=null`; `parseNumericEntity('#35')` = 35, `'#x41'`=65, `'#0'` → 0xFFFD, `'#xD800'` → 0xFFFD, `'#12345678'` (8 digits) → `null`; the table has exactly 252 + 4 entries (assert `htmlEntities.length == 256`).

**Verify** `cd packages/tephra_markdown; dart test; cd ../..`. Commit `phase 01.6: add Markdown AST, options, LineIndex, frontmatter and utilities`.

**Pitfalls**
- Offsets are **UTF-16 code-unit** offsets everywhere (Dart `String` indexing). Never use `runes` indexes for offsets.
- `MdText.text` is decoded content; its `[start,end)` still covers the raw source (e.g. `\*` → text `*`, range length 2).
- Never create `Md*` subclasses outside `nodes.dart`.

---

### 01.7 Block parser (CommonMark containers + GFM tables + Obsidian blocks)

**Purpose** Convert the text into the block tree with exact source ranges, collecting the raw inline content of each leaf as source segments.

**Files** (under `packages/tephra_markdown/lib/src/block/`)
- `block_node.dart` (mutable builder tree), `line_cursor.dart`, `block_parser.dart`, `block_starts.dart`, `html_block_rules.dart`, `list_rules.dart`, `table_rules.dart`, `link_definitions.dart`, `finalize.dart`
- tests: `packages/tephra_markdown/test/block/` (`block_parser_test.dart`, `list_test.dart`, `table_test.dart`, `html_block_test.dart`, `obsidian_blocks_test.dart`) and the dump helper `test/helpers/dump.dart` (defined in step 01.10; create it **now** with the grammar given in 01.10 so these tests can use it)

**Implementation** — the algorithm is the CommonMark 0.31.2 "parsing strategy" (spec appendix A: a line-by-line pass that matches open containers, then tries block starts, then adds the line to a leaf), with the additions below. Implement it yourself from the specification; do not copy another library.

1. **Input and lines.** The parser receives the note text (already `\n`-normalised; a stray `\r` is ordinary content). `lines` = the text split at `\n`; `lineStart[i]` is the offset of line `i`. A text ending in `\n` has a final empty line that is **not** processed.
2. **`LineCursor`** (per line): `lineStart`, `lineEnd` (offset of the `\n` or text length), `offset` (current absolute position), `column` (virtual column, tab stops every 4), `partialTab` (columns of a tab still unconsumed), and helpers
   `nextNonSpace` (computes `nextNonSpaceOffset`, `nextNonSpaceColumn`, `indent = nextNonSpaceColumn - column`, `blank`), `advanceOffset(count, columns:)` (supports consuming part of a tab: when only some of a tab's columns are consumed, set `partialTab`, and when
   a code block/paragraph later takes the "rest of the line", expand the remaining columns of that tab as spaces), `advanceToNextNonSpace()`.
3. **`BlockNode` (builder)**: `type` (`document, blockQuote, listItem, list, footnote, paragraph, heading, codeBlock, htmlBlock, thematicBreak, table, mathBlock, commentBlock`), `start`, `end` (absolute offsets; `end` is updated to the end of the last **non-blank** line added to the block or any descendant — blank lines never extend a block), `children`, `parent`, `isOpen`, `lastLineBlank`, plus type data:
   paragraph/heading → `List<(int start, int end)> segments` (one per source line: the content range after container prefixes and after stripping leading whitespace; trailing whitespace is kept on all but the last segment, because two trailing spaces mean a hard break);
   code/html/math/comment → `List<(int start, int end)> lines` (raw content ranges; for indented/fenced code a leading tab or spaces already stripped per the spec, with partial tabs expanded into the string you build);
   list → `ordered`, `bulletChar`/`delimiter`, `start`, `tight`; listItem → `markerOffset`, `padding` (content column), `task`; fenced code → `fenceChar`, `fenceLength`, `fenceOffset`, `info`; html → `htmlType` (1–7); heading → `level`, `isSetext`; table → `aligns`, `headerRow` data; footnote → `label`.
4. **Per-line procedure** (identical to the spec's strategy):
   1. `container = document`; for each open child chain from the root, try to **continue** the block (`continue()` rules below); the first block that does not match stops the walk; `allMatched` is true if every open block continued.
   2. If not all matched, remember `lastMatched`. Try **block starts** only when the (matched) container is not a code/html/math/comment block that needs the raw line (a fenced code block, html block, math block or comment block that continued consumes the line directly).
   3. Block-start loop (repeat until no start matches; each start creates a new block as child of the `container`, closing unmatched open blocks first): in this order — block quote; ATX heading; fenced code; **math block `$$`** (obsidian); **comment block `%%`** (obsidian); HTML block (types 1–7; type 7 cannot interrupt a paragraph); setext heading (only when the matched container's tip is a paragraph); thematic break; **footnote definition** (obsidian); list item; indented code (not when the tip is a paragraph and not when blank); **GFM table** (gfm; see 8).
      A start with `indent >= 4` is never a start except indented code.
   4. After starts: if the tip is not a paragraph and the line is not blank and the unmatched blocks include an open paragraph → **lazy continuation** (add the text to that paragraph) — only when no block start matched and `!allMatched`, and the tip is a paragraph.
      Otherwise close unmatched blocks; if the tip accepts lines (code, html, math, comment) add the line; else if the line is not blank and the tip is not a paragraph, start a paragraph; add the line to it.
   5. Update `lastLineBlank` of the containers per the spec (a blank line after an item with no content closes it; used for list looseness).
5. **`continue()` rules** (return matched / not matched / "line fully consumed, block closed"):
   - block quote: `indent <= 3` and the next non-space char is `>`: consume it and one following space or (part of) tab; else not matched.
   - list item: blank line → matched only if the item has at least one child (an item that started with a blank line and received no content is closed by the next blank line); non-blank → matched if `indent >= markerOffsetColumn + padding`, consuming `markerOffsetColumn + padding` columns; else not matched.
   - footnote definition: same as list item with `padding = 4` fixed (continuation lines need 4 spaces/one tab; blank lines continue the definition; a non-blank line with less indent ends it unless it is a lazy paragraph continuation).
   - fenced code: if `indent <= 3` and the line is a closing fence (same char, length ≥ opening, only spaces after) → close (the closing line is consumed and extends `end` to the end of the fence); else consume up to the fence's own indentation of leading spaces and match.
   - indented code: `indent >= 4` → consume 4 columns; blank → matched (blank lines inside indented code are kept; trailing blank lines are trimmed at finalisation); else not matched.
   - HTML block: types 1–5 continue until the line containing the end condition (that line is added, then the block closes); types 6–7 end at a blank line (not matched on blank).
   - paragraph: blank → not matched, else matched. Heading, thematic break: never continue. Table: a non-blank line that is not the start of another block continues the table (as a row); blank → not matched. Math block: continues until a line that contains `$$` (added, then closed). Comment block: continues until a line that contains `%%` (added, then closed).
6. **Block starts, exact conditions**
   - *Block quote*: `indent <= 3` and `>`; consume `>` and an optional space.
   - *ATX heading*: `indent <= 3`; 1–6 `#` followed by space, tab or end of line. Content = rest of the line trimmed; remove an optional closing sequence (spaces + `#`s, preceded by a space or tab, followed only by spaces). Heading `start` = offset of the first `#`; `end` = end of the line content excluding trailing spaces. Segment = the trimmed content range. `isSetext=false`.
   - *Fenced code*: `indent <= 3`; ≥ 3 backticks (info string must not contain a backtick) or ≥ 3 tildes. `info` = trimmed rest (entities/escapes in the info string are decoded only for `language`; keep `info` raw). `language` = text up to the first whitespace in `info` (or `null`). Content lines added raw; an unclosed fence runs to the end of the container.
   - *Math block (obsidian)*: `indent <= 3`, line (after indent) starts with `$$`. If the remainder of that line contains another `$$`: single-line block, `tex` = text between them trimmed; the rest of the line after the closing `$$` must be blank, else it is **not** a math block (the line is a paragraph with inline math). Otherwise the block is open: the text after the opening `$$` on the same line (trimmed, if non-empty) is the first tex line; following lines are tex lines until a line containing `$$` (text before it, trimmed, is a tex line; text after it is ignored); EOF closes it. `tex` = tex lines joined by `\n`, with leading/trailing blank lines removed. Cannot interrupt a paragraph.
   - *Comment block (obsidian)*: `indent <= 3`, the line starts with `%%` and the rest of that line does **not** contain another `%%` (otherwise it is a paragraph with an inline comment). The block spans every line through the first later line that contains `%%` (that whole line belongs to the block — documented limitation: text after the closing `%%` on that line is part of the block). An unterminated comment extends to the end of the container. `text` = the raw source between the opening `%%` and the closing `%%` (or end). Cannot interrupt a paragraph.
   - *HTML block*: the seven start conditions of the spec (1: `<script`, `<pre`, `<style`, `<textarea` case-insensitive followed by whitespace, `>` or end of line; 2: `<!--`; 3: `<?`; 4: `<!` + ASCII letter; 5: `<![CDATA[`; 6: `<` or `</` followed by one of the 62 listed block tag names (`address, article, aside, base, basefont, blockquote, body, caption, center, col, colgroup, dd, details, dialog, dir, div, dl, dt, fieldset, figcaption, figure, footer, form, frame, frameset, h1, h2, h3, h4, h5, h6, head, header, hr, html, iframe, legend, li, link, main, menu, menuitem, nav, noframes, ol, optgroup, option, p, param, search, section, summary, table, tbody, td, tfoot, th, thead, title, tr, track, ul`) followed by whitespace, `>`, `/>` or end of line; 7: a complete open or closing tag that is not one of `script, style, pre, textarea`, followed only by whitespace to the end of the line). End conditions per spec (1: a line containing `</script>`, `</pre>`, `</style>` or `</textarea>`; 2: `-->`; 3: `?>`; 4: `>`; 5: `]]>`; 6 and 7: a blank line). `html` = the block's raw text (lines joined by `\n`, without the final newline).
   - *Setext heading*: tip is a paragraph, `indent <= 3`, the line is only `=`s or only `-`s (then optional trailing spaces). The paragraph's link reference definitions are first extracted (see 9); if no content remains the line is not a heading underline. Convert the paragraph into a heading (level 1 for `=`, 2 for `-`, `isSetext=true`, `start` = paragraph start, `end` = end of the underline text); its segments are the paragraph's segments.
   - *Thematic break*: `indent <= 3`; three or more `-`, `_` or `*` (all the same char, spaces/tabs allowed between, nothing else). `-` thematic breaks take precedence over a list marker when both match (`- - -`); a setext underline takes precedence over a thematic break when a paragraph is open.
   - *Footnote definition (obsidian)*: `indent <= 3` and the line matches `^\[\^([^\s\]]+)\]:` ; `label` = group 1; consume through the colon and following spaces (up to 4 columns); the rest of the line starts the definition's first child. Cannot interrupt a paragraph. An empty definition (`[^1]:` and nothing else) is a footnote with no children.
   - *List item*: per the spec: bullet `-`, `+`, `*`; ordered = 1–9 digits + `.` or `)`; followed by a space/tab or end of line; an ordered list **can interrupt a paragraph only when its number is 1**, and **no** list item can interrupt a paragraph when its first line is blank (empty item); `padding`: spaces after the marker 1–4 → content column = marker width + spaces; ≥ 5 spaces or a blank rest → marker width + 1; a tab counts to the next stop.
     A new `list` block is opened unless the open container's last child is a list of the same type (same bullet char, or same ordered delimiter); otherwise the item joins that list. A different bullet char/delimiter starts a new list.
     **Task detection** (when the item has content on its first line and `gfm`): after the marker padding, if the remaining text matches `^\[(.)\][ \t]` (one Unicode code point in the brackets that is not `]`, a newline or an unpaired surrogate) — with `obsidian: false` only `' '`, `x`, `X` are accepted — set `task = TaskStatus(char, offset of that char)` and consume `[c]` plus the following spaces/tabs (up to the next non-space) as part of the list marker area, so the paragraph content starts after the checkbox. `- [ ]` followed by end of line, `- [ ]a`, `- []`, `- [xx]` are **not** tasks.
   - *Indented code*: `indent >= 4`, not blank, tip not a paragraph; start offset = offset after the 4-column indent.
7. **Finalisation of a block (when it closes)**
   - *Paragraph*: extract link reference definitions from the beginning of its content (9); if nothing remains, drop the paragraph from the tree. Otherwise compute its inline source (an `OffsetMap` from `segments`), set `end` to the last segment's end (last segment right-trimmed), and detect **block IDs** (10).
   - *Code block*: fenced → `code` = lines joined with `\n` plus a final `\n` if there is at least one line; indented → strip trailing blank lines, then join with `\n` + final `\n`. `MdCodeBlock.end` = end of the last non-blank content line (indented) or of the closing fence line (fenced; for an unclosed fence the end of the last line).
   - *List*: set `tight`: the list is **loose** if any two of its items are separated by a blank line, or any item directly contains two block children separated by a blank line (check `lastLineBlank` of every child but the last, per the spec's rule: an item's child ends with blank line and is followed by another child, or an item ends with a blank line and is not the last). Fenced/indented code and nested list ends do not count as "separated" when the blank is inside them (the spec's `endsWithBlankLine` recursion: a blank line at the end of a nested list's last item counts, a blank line inside a code block does not). The list's `end` = end of its last item.
   - *Block quote → callout (obsidian)*: if the quote's first child is a paragraph whose **first line** (first segment) matches `^\[!([A-Za-z0-9-]+)\]([+-])?(?:[ \t]+(.*))?$` (the whole first line, trimmed at the right), convert the quote into a callout: `type` = group 1 lower-cased; `fold` = `+` → `expanded`, `-` → `collapsed`, none → `none`; `title` = group 3 trimmed (empty → `null`; **raw text**, not parsed). The first segment is removed from the paragraph; if segments remain the paragraph (now starting at the second line) stays as the first body child, else the paragraph is dropped. The conversion applies to every block quote, nested or inside list items. `> [!note]text` (no whitespace after `]`) and `> [! note]` are not callouts.
   - *Table*, *heading*, *thematic break*, *html*, *math*, *comment*, *footnote*, *list item*: set `end` as stated above. A list item's `end` = end of its last non-blank content line; an empty item ends at the end of its marker line text.
8. **GFM tables (gfm).** Trigger: the current line is a **delimiter row** and the open tip is a paragraph whose last segment is the header row (or the line before is a plain paragraph line). Delimiter row = cells separated by `|`, each cell `:?-+:?` with optional spaces; at least one `|` in the whole row unless it has one cell with a leading/trailing `|`; leading/trailing `|` optional. Split cells with `splitTableRow(line)`:
   scan characters; a `|` preceded by an odd number of backslashes does not split; a leading and a trailing `|` (after trimming whitespace) are dropped; each cell's content range is trimmed of spaces/tabs (store the trimmed `(start,end)` source range; a cell may be empty). The header row's cell count must equal the delimiter row's cell count, else no table (the line is treated normally).
   When triggered: if the paragraph has more than one segment, split it — the earlier segments stay a paragraph (re-close it), the last segment becomes the header row; create the `table` block (`aligns` from the delimiter cells: `:-:` center, `:-` left, `-:` right, `-` none), add the header row; the delimiter row line belongs to the table (`end`). Each following non-blank line that does not start another block (block quote, ATX heading, fence, thematic break, HTML block start, list item start, math/comment/footnote start) is a body row: cells beyond the header count are dropped, missing cells are added as empty cells (range = empty at the row end). Each cell's inline content = its trimmed range as one segment. A blank line closes the table.
   `\|` inside cell content stays in the segment (the inline parser turns the escape into `|`, and inside code spans in a cell turns `\|` into `|`; it gets a flag `inTableCell` for this).
9. **Link reference definitions (all modes).** At paragraph finalisation (and before a setext conversion), repeatedly match at the start of the paragraph's virtual text: `[label]:` (label 1–999 characters, no unescaped brackets, not only whitespace), optional whitespace including at most one newline, a destination (`<...>` without newlines, or a non-empty run without spaces/control characters with balanced parentheses), optional whitespace (with at most one newline) and an optional title (`"…"`, `'…'` or `(…)`, may span lines but no blank line) followed only by whitespace to the end of its line. If the title part is invalid but the destination line is complete, the definition has no title and the title text remains paragraph content. Store `LinkDefinition(normalizeLabel(label), url (backslash escapes and entities decoded), title)` in a map; **the first definition of a label wins**. Definitions are removed from the paragraph's segments (cut at line boundaries; a definition always ends at a line end). The map is returned with the parse result (`ParsedNote.linkDefinitions`).
   Definitions are collected **for the whole document before any inline parsing** (inline parsing runs after the block phase completes), so references before the definition resolve.
10. **Block IDs (obsidian).** For a paragraph or heading, take the virtual text of the **last** segment. If it matches `(?:^|[ \t])\^([A-Za-z0-9-]+)[ \t]*$` the block has an ID: record `idStart/idEnd` (source offsets of `^id`; the match group 0 minus leading whitespace and trailing spaces), keep the `^id` inside the inline content (the inline parser emits `MdBlockId`), and set `MdHeading.blockId`.
    *Owner block* (for `BlockRef.start/end`): the heading itself; for a paragraph that is the **first** child of a list item → the list item (including nested children); for a paragraph whose entire content is the `^id` (a **standalone** ID line) → the previous sibling block (if none, the paragraph itself); otherwise the paragraph. `id` is matched and stored as written (case preserved).
11. The parser returns `BlockParseResult { BlockNode root; Map<String, LinkDefinition> definitions; FrontmatterSplit? frontmatter }`. If `obsidian` and `splitFrontmatter(text) != null`, the frontmatter lines are skipped (parsing starts at `bodyStart` with the original absolute offsets) and an `MdFrontmatter` node is the first child of the document.
12. Build step: convert the builder tree to immutable `Md*` nodes, calling the inline parser (step 01.8) for every paragraph, heading, table cell with the block's `OffsetMap`. This conversion is in `finalize.dart` and is wired in step 01.9; in this step the tests use a stub inline parser that emits one `MdText` per leaf block (covering the whole virtual text) so block structure can be tested alone. Define the inline entry point now: `List<MdNode> parseInlines(InlineSource source, InlineContext ctx)` with `InlineSource { String text; OffsetMap map; }` and `InlineContext { ParserOptions options; Map<String, LinkDefinition> definitions; bool inTableCell; }`; step 01.8 replaces the stub.

**Tests** (use the `dump()` helper of step 01.10; with the stub, paragraphs dump as `p(t"<whole text>")`; assert block shape and offsets, not inline content)
`block_parser_test.dart`: ATX levels 1–6, 7 hashes is a paragraph, `#` alone is an empty heading, closing hashes removed, `#5 bolt` is a paragraph; setext `=`/`-`; `para⏎-` is `h2`; `---` alone is `hr`; `- - -` is `hr` not a list; fenced backticks/tildes, info string `js linenos` → language `js`; unclosed fence runs to the end; indented code with trailing blank lines trimmed;
block quote with lazy continuation; nested quote `> > b`; quote then blank then quote = two quotes; HTML block types 1–7 (one case each: `<script>⏎x⏎</script>`, `<!-- c -->`, `<?x?>`, `<!DOCTYPE>`, `<![CDATA[x]]>`, `<div>⏎x⏎⏎y`, `<a href="x">⏎y`) and type 7 not interrupting a paragraph; link reference definitions (`[a]: b "c"` removed, `[a]: b⏎"c"` title on next line, invalid title keeps text, duplicate label first wins, definition cannot interrupt a paragraph);
tabs: `-→a` is an item, `→code` is indented code, `>→a`; blank-line handling in indented code.
`list_test.dart`: tight vs loose (cases from step 01.10's list rows), start numbers, `*` then `+` starts a new list, `1.` vs `1)` starts a new list, ordered list interrupts paragraph only with `1`, empty item cannot interrupt a paragraph, item content offset with 1–4 and 5 spaces, nested list by 2 spaces, nested by a tab, lazy continuation inside an item, a list inside a block quote, task detection (all cases of the tasks block in 01.10), item `end` offsets.
`table_test.dart`: all table cases of 01.10 at block level; `splitTableRow('| a \\| b | c |')` → two cells `a \| b` and `c` with exact ranges; header/delimiter count mismatch → paragraph; paragraph splitting before the header.
`html_block_test.dart`: the seven types plus end conditions.
`obsidian_blocks_test.dart`: callout conversion (type lower-casing, fold, title, nested, in list, no title, no body, `[!note]text` not a callout), math block (single-line, multi-line, unclosed, `$$a$$ tail` → paragraph), comment block (single-line comment is a paragraph; multi-line; unterminated; cannot interrupt a paragraph), footnote definition (label, continuation with 4 spaces, lazy continuation, blank + indented second paragraph, empty), frontmatter node position and `bodyStart`, block-ID owners (heading, list item, paragraph, standalone ID line owning the previous block).

**Verify** `cd packages/tephra_markdown; dart test test/block; cd ../..`; `dart analyze packages/tephra_markdown`. Commit `phase 01.7: add block parser`.

**Pitfalls**
- Container prefix characters (`>`, list indentation) are **not** part of a leaf's segments; offsets must still be absolute (always build segments from absolute line offsets).
- A partially consumed tab: when a block quote marker is followed by a tab, one column is consumed and the rest of the tab (up to 2 columns) becomes content spaces. Keep `partialTab` exactly as in the spec examples (`>→→foo` has indented code with two leading spaces).
- Do not trim trailing spaces of non-last paragraph segments (hard breaks need them); do trim the last one.
- `lastLineBlank` bookkeeping is the usual source of tight/loose bugs; implement the spec's `endsWithBlankLine` recursion, not a simplification.
- The setext underline must be checked **before** the thematic break and list item rules (`---` after a paragraph is an `h2`).
- Math/comment/footnote starts are skipped entirely when `obsidian: false`; the table start when `gfm: false`.

---

### 01.8 Inline parser

**Purpose** Turn each leaf block's virtual text into inline nodes with exact source ranges: CommonMark inlines, GFM strikethrough/extended autolinks, and Obsidian inlines.

**Files** (under `packages/tephra_markdown/lib/src/inline/`)
- `inline_parser.dart` (entry `parseInlines`), `inline_scanner.dart`, `delimiters.dart`, `brackets.dart`, `code_spans.dart`, `html_inline.dart`, `autolinks.dart`, `wikilinks.dart`, `tags.dart`, `math_inline.dart`, `footnotes_inline.dart`, `block_id_inline.dart`
- tests under `packages/tephra_markdown/test/inline/` (`emphasis_test.dart`, `links_test.dart`, `code_span_test.dart`, `escape_entity_test.dart`, `obsidian_inline_test.dart`, `autolink_test.dart`, `breaks_test.dart`)

**Implementation** — implement the CommonMark inline algorithm (spec §6 and appendix "A parsing strategy for inline content") plus extensions. Work on `source.text` (the virtual text) with an index `i`; every node's range is `[map.toSource(i0), map.toSourceEnd(i1))`.

1. **Scanner loop.** Keep a doubly linked list of working inline items (`_Item`: kind text/node/delimiter/bracket, `start`/`end` virtual indexes, content). At each position look at the character `c`:
   `\n`, `\\`, `` ` ``, `*`, `_`, `~` (gfm), `=` (obsidian), `[`, `!`, `]`, `<`, `&`, `$` (obsidian), `%` (obsidian), `#` (obsidian), `^` (obsidian), `h`/`H`/`w`/`W` at a word boundary (gfm extended autolinks). Anything else is a literal run (consume up to the next special character; text runs are one `MdText`).
   **Adjacent literal pieces must be merged into one `MdText`** (the node's text is the concatenation of decoded pieces; its range spans all of them). This is required by every expected value in the test tables.
2. **Backslash.** `\` followed by an ASCII punctuation character → literal that character (range 2 units); `\` + newline → `MdHardBreak` (range = the backslash and the newline); otherwise a literal backslash. (In table cells `\|` is the escape for `|`.)
3. **Entities.** `&name;` → `decodeEntity`, `&#N;`/`&#xH;` → `parseNumericEntity`; invalid → literal `&`. Decoded text is part of the surrounding `MdText` — and a decoded `#`, `[`, `*`, `_`, `<` or `` ` `` is **never** special (it is literal; `&#35;tag` is the text `#tag`, not a tag).
4. **Newlines.** A `\n` preceded by two or more spaces (spaces at the end of the previous line) → `MdHardBreak` (range from the first trailing space through the newline); the trailing spaces are removed from the preceding text. Otherwise `MdSoftBreak` (range = the newline; the spaces before a soft break are removed from the preceding text, one-space rule per spec: strip all trailing spaces of the preceding text node). Leading spaces of the next line are already stripped by the block parser.
5. **Code spans.** A run of `n` backticks; look ahead for the next run of exactly `n` backticks (no intervening run of exactly `n`); content = text between with each line ending turned into a space; if the content both begins and ends with a space and is not all spaces, strip one space from each side. No closing run → the opening run is literal text. In a table cell (`inTableCell`), replace `\|` with `|` in the content. Obsidian/GFM do not change code span rules. Node: `MdInlineCode(code)`.
6. **Delimiter runs** (`*`, `_`, plus `~` and `=` as extension delimiters). A run is a maximal sequence of the same char. Compute `leftFlanking`/`rightFlanking` exactly per spec using `isUnicodeWhitespace`/`isUnicodePunctuation` of the code points before and after the run (start/end of text counts as whitespace). `*`: `canOpen = leftFlanking`, `canClose = rightFlanking`. `_`: `canOpen = leftFlanking && (!rightFlanking || precededByPunctuation)`, `canClose = rightFlanking && (!leftFlanking || followedByPunctuation)`.
   `~` and `=` behave like `*` for flanking, but a run is a delimiter **only if its length is exactly 2** (otherwise literal text). `~`/`=` are skipped when `gfm`/`obsidian` is off.
   Emit a literal text item for the whole run and push a `delimiter` entry (`char`, `count`, `origCount`, `canOpen`, `canClose`, link to the text item, `active`).
   **`processEmphasis(stackBottom)`**: the spec algorithm — walk closers left to right; for each potential closer look back for the nearest opener with the same char that `canOpen`, respecting the **rule of 3** (if either side can both open and close, `(opener.origCount + closer.origCount) % 3 != 0` unless both counts are multiples of 3) and the `openers_bottom` table keyed by `(char, closer.canOpen, closer.origCount % 3)`. For `*`/`_`: use 2 delimiters (strong) if both have `count >= 2`, else 1 (emphasis); the nodes between are wrapped; remove delimiters strictly between; if the opener or closer is exhausted remove it. For `~`/`=` (count exactly 2 each): wrap into `MdStrikethrough` / `MdHighlight` consuming both; no rule of 3 for them. Unmatched delimiter text stays literal.
   `***a***` must yield `MdEmphasis(MdStrong(a))`... precisely: inner-most match uses 2 first when both have ≥ 2 → `MdStrong` is the **inner** node and `MdEmphasis` the outer (as CommonMark's `<em><strong>a</strong></em>`).
7. **Brackets and links.** `[` → push a `bracket` entry (not image); `![` → push an image bracket (consume both chars). `]` → look for the nearest bracket entry: none → literal `]`; inactive → remove it, literal `]`. Else try, in order:
   1. **inline link/image**: `](` + optional whitespace (≤ 1 newline) + destination (`<...>` or a run without spaces/controls with balanced parens, backslash escapes/entities decoded) + optional whitespace + optional title (`"…"`, `'…'`, `(…)`) + optional whitespace + `)`.
   2. **full reference** `][label]`, **collapsed** `][]`, **shortcut** `]` — label normalised with `normalizeLabel` and looked up in `ctx.definitions`; for collapsed/shortcut the label is the bracket text. A match wraps everything after the opener in `MdLink(url, title, image)`; for links, deactivate every earlier non-image bracket opener (no links inside links). Reference matching requires the label not to be only a footnote/wikilink pattern handled earlier.
   Otherwise the opener is removed and `]` is literal text. `processEmphasis` is run on the delimiters inside the link text before building the link node. For an image the children are the alt-text inline nodes.
   Text of a link/image and its url/title are decoded (escapes + entities). The `MdLink` range spans from `[`/`!` through the closing `)` or `]`.
8. **Autolinks and raw HTML.** `<` + scheme (2–32 chars, letter then letters/digits/`+.-`) + `:` + no spaces/`<`/`>` + `>` → `MdAutolink(url)`; `<` + email (spec regex) + `>` → `MdAutolink('mailto:<email>')`. Raw HTML inline per spec: open tag, closing tag, comment `<!-- … -->` (spec 0.31 rules), processing instruction `<? … ?>`, declaration `<!X … >`, CDATA → `MdHtmlInline(html)` (raw source text). Anything else: literal `<`.
9. **Extended autolinks (gfm).** At a word boundary (start of text, or the previous char is whitespace, `*`, `_`, `~`, `(`): a match of `https?://` or `www.` followed by a valid domain (`[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+`, at least one `.`), then path characters up to whitespace or `<`. Trailing punctuation `? ! . , : * _ ~ ' "` is excluded from the URL; a trailing `)` is excluded if the URL has more `)` than `(`; a trailing `;` after something that looks like `&entity` is excluded. Node `MdAutolink(url)`: `url` as written for `http(s)://`, `http://` + text for `www.`. Not performed inside link text of an enclosing bracket whose `[` is open? It **is** performed everywhere except inside code spans, existing autolinks and raw HTML. Tags and `#` inside such a URL are therefore never seen (the autolink consumes the URL first).
10. **Wikilinks and embeds (obsidian).** At `[[` or `![[`: find the closing `]]` on the same virtual line (no `\n` before it) such that the content contains neither `[[` nor `]]`. Content `inner`:
    1. Split `inner` on the first unescaped `|` **or** `\|` (a backslash-pipe is a separator and the backslash is dropped): `left`, `rest`.
    2. `left`: split at the first `#`: `target = before.trim()`, `after` = text after `#`. If `after` starts with `^` → `blockRef = after.substring(1).trim()`; else `heading = after.trim()`; a heading matching `^page=(\d+)$` (any link kind) sets `pdfPage` to the digits and leaves `heading = null`. Empty strings become `null`. `target` may be empty (`[[#Heading]]`).
    3. `rest` (everything after the first separator, other separators kept as `|`): for **embeds** only — if the last `|`-separated segment matches `^\d+(x\d+)?$` it is the size: `EmbedSize(width[, height])` and is removed from `rest`; the remaining `rest` (trimmed, non-empty) is `alias`. For non-embeds `alias = rest.trim()` (non-empty).
    4. If `target.isEmpty && heading == null && blockRef == null && pdfPage == null` → not a link (literal text). Result `MdWikiLink(embed: bang)`; range covers `!`/`[[` through `]]`. The content of a wikilink is **not** parsed further and is not subject to emphasis/tag rules.
    5. Wikilinks are recognised before the generic bracket handling; `[[` that does not resolve to a wikilink falls back to ordinary bracket handling.
11. **Highlight, comments, math, footnotes, tags, block IDs (obsidian).**
    - `==` runs are delimiters (6). `%%`: find the next `%%` in the same paragraph's virtual text (newlines allowed); content = text between → `MdCommentInline(text)` (raw); no closing `%%` → literal. Comment content is never parsed.
    - **Inline math**: at `$$` find the next `$$` (same paragraph) → `MdInlineMath(tex)` if the content is non-empty and does not start/end with whitespace; at single `$`: find the next unescaped `$` such that the char after the opening `$` is not whitespace, the char before the closing `$` is not whitespace, the closing `$` is **not followed by a digit**, and the opening `$` is not preceded by a backslash; the content is non-empty and contains no `\n` followed by an empty line (paragraph is already one block, newlines allowed). If no valid closer exists, the `$` is literal. A `\$` is an escape (literal `$`). Math content is raw (backslashes kept).
    - **Footnote reference**: `[^label]` where `label` = 1+ chars none of whitespace, `[`, `]`, `^` → `MdFootnoteRef(label)` (checked before wikilink/bracket handling). **Inline footnote**: `^[` … matching `]` (nested brackets balanced, no unescaped nesting issue) → `MdInlineFootnote` whose children are the inline-parsed content (recursive `parseInlines` over the inner range, same map).
    - **Tag**: at `#`. Conditions: the previous character (in the virtual text) does not exist, or is Unicode whitespace, or one of `( [ { " ' , ;`; the previous char is not `#`; the `#` was not produced by an entity or an escape; then match `[\p{L}\p{M}\p{N}_\-/]+` (unicode); drop trailing `/` characters; the remaining name must be non-empty and contain at least one character that is not an ASCII digit `0-9` (so `#123` and `#2024` are not tags; `#2024-q1` and `#y2k` are). → `MdTag(name)`. A `#` followed by a space (inside a paragraph) is literal.
    - **Block ID**: if the block parser flagged the block's last segment as ending in an ID (step 01.7 rule 10), then at the matching `^id` (the final `^` preceded by start/space/tab) emit `MdBlockId(id)` (range = `^id`) instead of text. The check is by position: the `InlineContext` carries `blockIdRange` (virtual indexes) or `null`.
12. **Final steps.** After the scan call `processEmphasis(null)`; remove delimiter bookkeeping; return the nodes in order. Merge adjacent text nodes again if processing left neighbours (e.g. after removing a delimiter).
13. **`MarkdownParser.parseInline(String text)`** (additive public API): builds a single-segment `OffsetMap` over `text` and calls `parseInlines` with default options and no definitions; used by the reading view for callout titles.

**Tests** use the `dump()` helper (01.10). In this step add focused unit tests (names are the first words of the case; each is one `test()`):
- `emphasis_test.dart`: `*a*`, `_a_`, `**a**`, `__a__`, `***a***` → `em(strong(t"a"))`, `snake_case_word` stays text, `a*b*c`, `2 * 3 * 4`, nested `**a *b* c**`, `*a **b** c*`, rule of 3 (`*foo**bar**baz*` → `em(t"foo",strong(t"bar"),t"baz")`), `**foo*` stays `*` + em, `==x==`, `a==b==c`, `====` is text, `~~x~~`, `~x~` is text, `==a **b** c==`, `==mark with ~~del~~==`, `\*esc\*` → text `*esc*`, unmatched `**not closed`.
- `links_test.dart`: inline link with title in all three quote styles, `<…>` destination with spaces, nested parens in destinations, image alt text children, link containing an image, no link inside a link (`[a [b](u)](v)` → text `[a `, link `b`, text `](v)`), reference links (full, collapsed, shortcut, case-insensitive label, unresolved label stays text), `[a](b` stays text, `\[a](b)` stays text.
- `code_span_test.dart`: 1, 2, 3 backticks, unmatched run literal, space stripping, all-space content kept, newline → space, code span beats emphasis (`` *a`*` ``), table-cell `\|`.
- `escape_entity_test.dart`: every ASCII punctuation escape (loop over the 32 characters → text of that char), `\a` keeps the backslash, `&amp; &lt; &#65; &#x41; &nosuch; &copy;`, decoded `#` is not a tag, decoded `*` is not emphasis.
- `obsidian_inline_test.dart` and `autolink_test.dart` and `breaks_test.dart`: the corresponding groups of 01.10 (wikilink parsing table, tags table, math table, comment table, footnote refs, autolinks incl. trailing punctuation and balanced parens, hard/soft breaks).
- Offsets: three cases per node kind (a table in `offsets_test.dart` is in 01.10).

**Verify** `cd packages/tephra_markdown; dart test; cd ../..`. Commit `phase 01.8: add inline parser`.

**Pitfalls**
- Ranges for nodes inside a paragraph that spans lines: map **both** ends through the `OffsetMap`; never add lengths to a start offset (container prefixes make lengths wrong).
- Emphasis uses the delimiter **stack**, not regex. Never run a regex over the whole text to find `*`.
- Order of attempts at `[`: footnote ref → wikilink → bracket. At `!`: `![[` embed → `![` image. At `^`: inline footnote `^[` (not `^` in a block id).
- Tags/`$`/`%%`/`==` are not recognised inside code spans, autolinks, raw HTML, wikilinks, link destinations or math.
- `~` and `=` runs of other lengths are literal text and must not interrupt a pending `*` opener.

---

### 01.9 `ParsedNote`, `MarkdownParser`, convenience lists, async parse helper

**Purpose** Public parser API of conventions §7.3: one call returns the AST and all extractions.

**Files**
- `packages/tephra_markdown/lib/src/parsed_note.dart`, `lib/src/markdown_parser.dart`, `lib/src/block/finalize.dart` (wire the real inline parser)
- `app/lib/reading/parse_service.dart`
- tests: `packages/tephra_markdown/test/parsed_note_test.dart`, `packages/tephra_markdown/test/offsets_test.dart`, `app/test/reading/parse_service_test.dart`

**Implementation**
1. `parsed_note.dart` per conventions §7.3 with these exact members (all `final`, immutable; lists unmodifiable):
   `String text; MdDocument root; Map<String, Object?> frontmatter; bool frontmatterValid; List<MdHeading> headings; List<MdWikiLink> wikiLinks; List<MdLink> links; List<String> tags; List<String> aliases; List<BlockRef> blockIds; List<TaskItem> tasks; Map<String, LinkDefinition> linkDefinitions; LineIndex lines;`
2. `markdown_parser.dart`: `abstract final class MarkdownParser { static ParsedNote parse(String text) => parseWith(text, const ParserOptions()); static ParsedNote parseWith(String text, ParserOptions options); static List<MdNode> parseInline(String text); }`.
   `parseWith`: block phase → build nodes with inlines (finalize.dart) → walk the tree once collecting:
   - `headings`: every `MdHeading` in document order (also inside quotes/callouts/lists).
   - `wikiLinks`: every `MdWikiLink` (embeds included; `embed` flag tells them apart). `links`: every `MdLink` with `image == false` **and** every image `MdLink` (the flag tells them apart) in document order, plus an `MdLink` is **not** created for `MdAutolink`s.
   - `tags`: inline `MdTag.name`s in document order, **then** the frontmatter tags; de-duplicated **by exact string, first occurrence kept**. Frontmatter tags: key `tags` (also accept `tag`) — a list of strings or a single string split on commas and whitespace; each element trimmed, a leading `#` removed, empty dropped; non-string list elements ignored.
   - `aliases`: key `aliases` (also `alias`) — list or string (split on commas only for a string); trimmed, empty dropped.
   - `blockIds`: one `BlockRef` per block ID found (rule 10 of 01.7), in document order.
   - `tasks`: one `TaskItem` per list item with `task != null`: `status = task.char`; `statusOffset = task.offset`; `start/end` = the item range; `text` = source text from the end of the checkbox (the first non-space after `[c]`) to the end of the item's **first paragraph** (trimmed; multi-line paragraph keeps its newlines as `\n`); `line = lines.lineOf(start)`.
   - `frontmatter` = decoded map (`{}` when absent or invalid); `frontmatterValid` = `true` when absent or valid, `false` when the YAML is invalid. An invalid-YAML frontmatter still yields an `MdFrontmatter` node.
   When `options.obsidian == false`, frontmatter, tags, aliases, blockIds are empty.
3. `app/lib/reading/parse_service.dart`:
   ```dart
   /// Parses a note; notes longer than [isolateThreshold] UTF-16 units are parsed in a short-lived isolate (conventions §5.6).
   final class ParseService {
     const ParseService({this.isolateThreshold = 50000});
     final int isolateThreshold;
     Future<ParsedNote> parse(String text);   // text.length <= threshold → synchronous result in a completed Future; else Isolate.run(() => MarkdownParser.parse(text))
   }
   final parseServiceProvider = Provider<ParseService>((ref) => const ParseService());
   ```
   Put the provider in `app/lib/reading/providers.dart`. (`Isolate.run` is unavailable on web; guard with `kIsWeb` → synchronous.)
4. Public exports in `lib/tephra_markdown.dart`: `nodes.dart`, `note_models.dart`, `parsed_note.dart`, `markdown_parser.dart`, `parser_options.dart`, `line_index.dart`, `frontmatter.dart` (only `splitFrontmatter`, `FrontmatterSplit`, `decodeFrontmatterYaml`), `util/unicode.dart` (`normalizeLabel`, `isUnicodePunctuation`, `isUnicodeWhitespace`), `util/entities.dart` (`decodeEntity`). Nothing else.

**Tests**
- `parsed_note_test.dart`:
  1. `headings in order incl. nested`: `# A⏎> ## B⏎- ### C` → 3 headings with levels 1,2,3.
  2. `wikilinks and embeds collected`: `[[a]] ![[b.png]] [[c#h|x]]` → 3 entries, flags `false,true,false`.
  3. `links`: `[x](u) ![i](p.png) <http://z>` → 2 `MdLink` (second `image`), autolink not in `links`.
  4. `inline tags then frontmatter tags, deduplicated`: `---⏎tags: [b, "#c"]⏎---⏎#a #b` → `[a, b, c]`.
  5. `tags as string`: `tags: "x, y z"` → `[x, y, z]`; `tag: solo` → `[solo]`.
  6. `aliases list and string`: `aliases: [A1, A2]` / `aliases: Solo`.
  7. `frontmatter map and validity`: valid → `frontmatter['title']=='T'`, `frontmatterValid`; invalid YAML (`a: [1`) → `{}` and `false`, node still present; none → valid.
  8. `block refs owners`: `Para ^p1⏎⏎- item ^i1⏎  - child⏎⏎## Head ^h1⏎⏎> quote⏎⏎^q1` → `p1` owner = the paragraph range; `i1` owner = the whole list item including `- child`; `h1` owner = the heading; `q1` (a standalone ID line after a blank line) owner = the block quote (the previous sibling block). Assert that the `idStart/idEnd` slice of each `BlockRef` equals `^p1`, `^i1`, `^h1`, `^q1`.
  9. `tasks`: `- [ ] a⏎- [x] b ^t⏎  - [/] c` → 3 tasks, statuses `' '`,`'x'`,`'/'`; `text` is `'a'`, `'b ^t'`, `'c'`; `statusOffset` points at the char; `line` values 0,1,2.
  10. `commonMark options give empty obsidian lists`.
  11. `lines index matches text` (`parsed.lines.lineCount`).
  12. `huge note parses in time`: `test_vaults/edge/huge-5000-lines.md` (read from `../../test_vaults/edge/`) parses in < 500 ms on the dev machine (`Stopwatch`; record the number in `PROGRESS.md`; the assertion threshold is 2000 ms to keep CI stable), and `long-line.md` (100,000 characters on one line) parses in < 2000 ms.
- `offsets_test.dart` (table-driven; input → `kind@start-end` for every listed node; `⏎` = newline):
  `Hello **world**` → `p@0-15 t@0-6 strong@6-15 t@8-13`; `[[Note|Alias]]` → `wiki@0-14`; `# Title` → `h1@0-7 t@2-7`; `- [ ] task` → `ul@0-10 li@0-10 p@6-10 t@6-10`; `> quote` → `bq@0-7 p@2-7`;
  `a⏎b` → `p@0-3 t@0-1 sb@1-2 t@2-3`; `` ```⏎x⏎``` `` → `code@0-9`; `- a⏎  - b` → `ul@0-9 li@0-9 p@2-3 ul@6-9 li@6-9 p@8-9`; `> [!note] T⏎> B` → `callout@0-15 p@14-15`;
  `---⏎a: 1⏎---⏎x` → `fm@0-12 p@13-14`; `|a|b|⏎|-|-|⏎|1|2|` → `table@0-17 trh@0-5 td@1-2 td@3-4 tr@12-17 td@13-14 td@15-16`; `%%x%%` → `icmt@0-5`; `#tag` → `tag@0-4`; `a  ⏎b` → `br@1-4`; `[t](u "x")` → `link@0-10`;
  `![[a.png|300]]` → `embed@0-14`; `😀 **b**` → `p@0-8 strong@3-8 t@5-6`; `$$⏎x⏎$$` → `math@0-7`; `> a⏎b` → `bq@0-5 p@2-5`; `1. a⏎2. b` → `ol@0-9 li@0-4 li@5-9`; `## H ^id` → `h2@0-8 bid@5-8`; `[^1]: n` → `fn@0-7`; `~~x~~` → `del@0-5`; `==x==` → `mark@0-5`;
  `a\\⏎b` (backslash break) → `br@1-3`; `&amp; x` → `t@0-7` (text `& x`); `\\*a\\*` → `t@0-6` (text `*a*`); `  # indented heading` (2 spaces) → `h1@2-20`.
  (These 31 offset cases are the contract Phase 2's link rewriting relies on; do not adjust ranges without telling the human.)
- `parse_service_test.dart` (app): a 10-character text returns synchronously correct result; a 60,000-character text (a repeated line) returns the same dump as `MarkdownParser.parse` computed directly (proves isolate transfer works); `isolateThreshold: 5` forces the isolate path for a small text.

**Verify** `cd packages/tephra_markdown; dart test; cd ../..`; `cd app; flutter test test/reading/parse_service_test.dart; cd ..`. Commit `phase 01.9: add ParsedNote, MarkdownParser and ParseService`.

**Pitfalls**
- `ParsedNote` must be sendable across isolates: no closures, no `Expando`, no `late` fields computed lazily with closures. Plain data only.
- `tasks[i].start/end` use the **list item** range (Phase 2 relies on it); the status char offset is separate.
- Do not mutate node lists after construction (wrap with `List.unmodifiable`).

---

### 01.10 CommonMark conformance, Obsidian syntax cases, `test_vaults/syntax`

**Purpose** Prove the parser: the official CommonMark spec examples (with a ratchet), ~200 Obsidian-syntax cases, one assertion per note of `test_vaults/syntax`, and fuzz robustness.

**Files** (under `packages/tephra_markdown/`)
- `test/fixtures/spec.json` (downloaded), `test/fixtures/commonmark_known_failures.txt`, `test/fixtures/obsidian_cases.txt` (the case table below), `test/fixtures/offset_cases.txt` (from 01.9, optional re-use)
- `test/helpers/dump.dart`, `test/helpers/commonmark_html.dart` (test-only HTML renderer)
- `test/commonmark_conformance_test.dart`, `test/obsidian_cases_test.dart`, `test/syntax_vault_test.dart`, `test/fuzz_test.dart`
- `tool/` none

**Implementation**
1. **Download the spec once** (PowerShell, from the repo root):
   `Invoke-WebRequest -Uri https://spec.commonmark.org/0.31.2/spec.json -OutFile packages\tephra_markdown\test\fixtures\spec.json`
   Check: the file is a JSON array of 652 objects with keys `markdown`, `html`, `example`, `start_line`, `end_line`, `section`. Commit it (it is test data; the licence of the spec text is CC-BY-SA, record it in `THIRD_PARTY_NOTICES.md` under a "Test data" heading: "CommonMark spec examples, © John MacFarlane, CC BY-SA 4.0" — it is not shipped in the app).
   If the download fails, stop and ask the human to place the file.
2. **`dump()` helper** (`test/helpers/dump.dart`) — `String dump(MdNode node)`; grammar (used by every expected value in this phase):
   - A node prints as `name`, then optional `{attrs}`, then optional `"text"` (leaf with text), then optional `(child,child,…)` when it has children. No spaces between children.
   - Block names: `doc fm h1…h6 p bq callout ul ol li code icode math table tr trh td hr html fn cmt`. (`icode` = indented `MdCodeBlock`, `code` = fenced; `trh` = header row.)
   - Inline names: `t"…"` (`MdText`; `\n` shown as `⏎`), `em strong del mark c"…"` (`MdInlineCode`) `wiki embed link img auto tag"…" bid"…" imath"…" fref"…" ifn icmt"…" ihtml"…" br sb`, `math"…"` for `MdMathBlock` (tex with `\n` as `⏎`).
   - Attributes (only when not default, in this order, comma separated): `callout{type=…,title=…,f=+|-}`; `ul{loose}` / `ol{start=N,loose}`; `li{task=<char or SP for space>}`; `code{lang=…}`; `table{aligns=n,l,c,r,…}`; `h2{id=blockId}`; `link{url=…,title=…}`; `img{url=…,title=…}`; `auto{url=…}`;
     `wiki{t=…,h=…,b=…,a=…,w=…,x=…,p=…}` (always includes `t=`, even when empty; `w`/`x` = size width/height, `p` = pdfPage); `embed{…}` = same keys for `embed == true`; `fn{label=…}` is printed as `fn{label=1}`.
   - Example: `[[A|B]]` → `doc(p(wiki{t=A,a=B}))`. The document node is printed as `doc(...)`; an empty document is `doc`.
   - Also `String dumpWithRanges(MdNode)`: `kind@start-end` for each node in pre-order, space separated (used by `offsets_test.dart`).
3. **Test-only HTML renderer** (`test/helpers/commonmark_html.dart`): `String renderHtml(MdDocument doc, String source)` producing the spec's reference HTML for `ParserOptions.commonMark` documents. Rules (spec's reference output): `<p>…</p>\n`; `<h1>…</h1>\n`; `<blockquote>\n…</blockquote>\n`; `<ul>\n`/`<ol>\n` (with ` start="N"` when ≠ 1), `<li>…</li>\n`; **tight lists** render a paragraph child's inline content without `<p>` (an `<li>` with a tight paragraph then nested list: `<li>text\n<ul>…</ul>\n</li>`); loose lists keep `<p>`;
   `<pre><code>…</code></pre>\n` with ` class="language-X"` for fenced blocks with a language, content HTML-escaped; `<hr />\n`; html blocks and inline html output raw; `MdText` is HTML-escaped (`& < > "` → `&amp; &lt; &gt; &quot;`); `<em>`, `<strong>`, `<code>` (escaped), `<a href="…" title="…">` with the URL percent-encoded per spec (`encode every char outside [A-Za-z0-9-._~:/?#@!$&'()*+,;=%]` as UTF-8 percent bytes, except an existing `%XX` stays), `<img src="…" alt="…" title="…" />` where `alt` is the plain-text rendering of the children; soft break → `\n`; hard break → `<br />\n`; autolinks `<a href="url">text</a>` (email: `mailto:`); empty `<li></li>` for empty items. Tight/loose and blank-line details follow the spec examples; if an example reveals a rule not listed, implement the rule from the spec text.
   The renderer reads fenced `language` from `MdCodeBlock.language`; `info` is not used.
4. **`commonmark_conformance_test.dart`**:
   - For every example: `ParserOptions.commonMark` parse of `markdown`, render, compare with `html` **exactly**. Per-section counters printed as a table.
   - `test_vaults`-style ratchet: `commonmark_known_failures.txt` lists failing examples, one per line, `<example number> <section name>` (section names exactly as in `spec.json`). After your first full run, write every failing example into it. Tests:
     1. `no new failures`: every failing example is listed in the file.
     2. `known failures list only shrinks`: every example listed in the file **still fails**; if one now passes the test fails with the message `remove example N from commonmark_known_failures.txt` (so the file can only get shorter over time).
     3. `required sections are 100 %`: for each of `ATX headings`, `Setext headings`, `Fenced code blocks`, `Thematic breaks`, `Block quotes`, `Code spans`, `Backslash escapes` — zero failures, and the known-failures file contains no line of these sections.
     4. `overall pass rate >= 85 %`: passed / 652 ≥ 0.85.
     5. `known failures file is sorted by example number and has no duplicates`.
   - Expected state at the end of this step: ≥ 85 % overall and 100 % in the seven sections. If the parser is below that, fix the **parser**, not the thresholds. Record the final number in `PROGRESS.md` ("CommonMark: X/652 (Y %), failing sections: …").
5. **`obsidian_cases_test.dart`** loads `test/fixtures/obsidian_cases.txt`: one case per line `INPUT ⇒ EXPECTED`; in `INPUT` the character `⏎` means a newline, `→` a tab, and everything else is literal (including backslashes); `EXPECTED` is the `dump()` of the parsed document. Lines starting with `#` are comments (group titles); blank lines ignored. The test names each case `<group>: <input>`. **If an expected value contradicts a rule written in steps 01.6–01.9, the rule wins: fix the expected value and write one line in `PROGRESS.md`.** Create the file with the cases below (copy them exactly):
   ```
   # wikilinks
   [[Note]] ⇒ doc(p(wiki{t=Note}))
   [[Note|Alias]] ⇒ doc(p(wiki{t=Note,a=Alias}))
   [[Note#Heading]] ⇒ doc(p(wiki{t=Note,h=Heading}))
   [[Note#Heading|Alias]] ⇒ doc(p(wiki{t=Note,h=Heading,a=Alias}))
   [[Note#^blk]] ⇒ doc(p(wiki{t=Note,b=blk}))
   [[#Heading]] ⇒ doc(p(wiki{t=,h=Heading}))
   [[#^blk]] ⇒ doc(p(wiki{t=,b=blk}))
   [[Folder/Note]] ⇒ doc(p(wiki{t=Folder/Note}))
   [[Note.md]] ⇒ doc(p(wiki{t=Note.md}))
   [[ Note ]] ⇒ doc(p(wiki{t=Note}))
   [[]] ⇒ doc(p(t"[[]]"))
   [[Note ⇒ doc(p(t"[[Note"))
   [[a]] and [[b]] ⇒ doc(p(wiki{t=a},t" and ",wiki{t=b}))
   [[Note#H1#H2]] ⇒ doc(p(wiki{t=Note,h=H1#H2}))
   [[Note|a|b]] ⇒ doc(p(wiki{t=Note,a=a|b}))
   [[Note\|Alias]] ⇒ doc(p(wiki{t=Note,a=Alias}))
   [[বাংলা নোট]] ⇒ doc(p(wiki{t=বাংলা নোট}))
   [[Note]]s ⇒ doc(p(wiki{t=Note},t"s"))
   **[[Note]]** ⇒ doc(p(strong(wiki{t=Note})))
   [[Note]]⏎[[Other]] ⇒ doc(p(wiki{t=Note},sb,wiki{t=Other}))
   [[a⏎b]] ⇒ doc(p(t"[[a",sb,t"b]]"))
   `[[Note]]` ⇒ doc(p(c"[[Note]]"))
   [[Note|]] ⇒ doc(p(wiki{t=Note}))
   [[Note#]] ⇒ doc(p(wiki{t=Note}))
   # embeds
   ![[img.png]] ⇒ doc(p(embed{t=img.png}))
   ![[img.png|300]] ⇒ doc(p(embed{t=img.png,w=300}))
   ![[img.png|300x200]] ⇒ doc(p(embed{t=img.png,w=300,x=200}))
   ![[img.png|alt text]] ⇒ doc(p(embed{t=img.png,a=alt text}))
   ![[img.png|alt|300]] ⇒ doc(p(embed{t=img.png,a=alt,w=300}))
   ![[doc.pdf#page=3]] ⇒ doc(p(embed{t=doc.pdf,p=3}))
   ![[doc.pdf#page=3|400]] ⇒ doc(p(embed{t=doc.pdf,p=3,w=400}))
   ![[Note#Heading]] ⇒ doc(p(embed{t=Note,h=Heading}))
   ![[Note#^blk]] ⇒ doc(p(embed{t=Note,b=blk}))
   ![[Note]] ⇒ doc(p(embed{t=Note}))
   ![[ ]] ⇒ doc(p(t"![[ ]]"))
   ![[a|300x]] ⇒ doc(p(embed{t=a,a=300x}))
   [[a|300]] ⇒ doc(p(wiki{t=a,a=300}))
   ![[a]] text ⇒ doc(p(embed{t=a},t" text"))
   text ![[a]] ⇒ doc(p(t"text ",embed{t=a}))
   !![[a]] ⇒ doc(p(t"!",embed{t=a}))
   ![[a ⇒ doc(p(t"![[a"))
   ![alt](img.png) ⇒ doc(p(img{url=img.png}(t"alt")))
   ![[song.mp3]] ⇒ doc(p(embed{t=song.mp3}))
   ![[Note#H|Alias]] ⇒ doc(p(embed{t=Note,h=H,a=Alias}))
   [[Note#page=2]] ⇒ doc(p(wiki{t=Note,p=2}))
   # markdown links and autolinks
   [text](http://example.com) ⇒ doc(p(link{url=http://example.com}(t"text")))
   [text](url "title") ⇒ doc(p(link{url=url,title=title}(t"text")))
   [text](<a b.md>) ⇒ doc(p(link{url=a b.md}(t"text")))
   [text](a%20b.md) ⇒ doc(p(link{url=a%20b.md}(t"text")))
   [a](b)[c](d) ⇒ doc(p(link{url=b}(t"a"),link{url=d}(t"c")))
   [a *b*](u) ⇒ doc(p(link{url=u}(t"a ",em(t"b"))))
   [ref]⏎⏎[ref]: http://x ⇒ doc(p(link{url=http://x}(t"ref")))
   [a][ref]⏎⏎[ref]: u "T" ⇒ doc(p(link{url=u,title=T}(t"a")))
   [a][]⏎⏎[a]: u ⇒ doc(p(link{url=u}(t"a")))
   [unknown] ⇒ doc(p(t"[unknown]"))
   [a](b ⇒ doc(p(t"[a](b"))
   <http://example.com> ⇒ doc(p(auto{url=http://example.com}))
   <me@example.com> ⇒ doc(p(auto{url=mailto:me@example.com}))
   https://example.com/path. ⇒ doc(p(auto{url=https://example.com/path},t"."))
   see www.example.com now ⇒ doc(p(t"see ",auto{url=http://www.example.com},t" now"))
   (https://example.com) ⇒ doc(p(t"(",auto{url=https://example.com},t")"))
   https://a.com/b_(c) ⇒ doc(p(auto{url=https://a.com/b_(c)}))
   https://example.com/#frag ⇒ doc(p(auto{url=https://example.com/#frag}))
   [link](#Heading) ⇒ doc(p(link{url=#Heading}(t"link")))
   [a](b 'single') ⇒ doc(p(link{url=b,title=single}(t"a")))
   [a]( b ) ⇒ doc(p(link{url=b}(t"a")))
   ![img](a.png "t") ⇒ doc(p(img{url=a.png,title=t}(t"img")))
   [![i](a.png)](b) ⇒ doc(p(link{url=b}(img{url=a.png}(t"i"))))
   \[not link](u) ⇒ doc(p(t"[not link](u)"))
   # tags
   #tag ⇒ doc(p(tag"tag"))
   #nested/tag ⇒ doc(p(tag"nested/tag"))
   a #tag b ⇒ doc(p(t"a ",tag"tag",t" b"))
   #123 ⇒ doc(p(t"#123"))
   #2024-q1 ⇒ doc(p(tag"2024-q1"))
   #y2k ⇒ doc(p(tag"y2k"))
   a#b ⇒ doc(p(t"a#b"))
   (#tag) ⇒ doc(p(t"(",tag"tag",t")"))
   #tag, ⇒ doc(p(tag"tag",t","))
   #tag. ⇒ doc(p(tag"tag",t"."))
   #Tag_With-Chars ⇒ doc(p(tag"Tag_With-Chars"))
   #বাংলা ⇒ doc(p(tag"বাংলা"))
   #tag/ ⇒ doc(p(tag"tag",t"/"))
   `#tag` ⇒ doc(p(c"#tag"))
   [l](http://a.com/#frag) ⇒ doc(p(link{url=http://a.com/#frag}(t"l")))
   ```⏎#tag⏎``` ⇒ doc(code)
   # Heading ⇒ doc(h1(t"Heading"))
   ## Heading #tag ⇒ doc(h2(t"Heading ",tag"tag"))
   #NotAHeading ⇒ doc(p(tag"NotAHeading"))
   ####### seven ⇒ doc(p(t"####### seven"))
   #tag1 #tag2 ⇒ doc(p(tag"tag1",t" ",tag"tag2"))
   ##tag ⇒ doc(p(t"##tag"))
   &#35;tag ⇒ doc(p(t"#tag"))
   \#tag ⇒ doc(p(t"#tag"))
   %%#tag%% ⇒ doc(p(icmt"#tag"))
   - #tag ⇒ doc(ul(li(p(tag"tag"))))
   # emphasis, strikethrough, highlight
   ==hi== ⇒ doc(p(mark(t"hi")))
   ==a **b** c== ⇒ doc(p(mark(t"a ",strong(t"b"),t" c")))
   a == b ⇒ doc(p(t"a == b"))
   ==unclosed ⇒ doc(p(t"==unclosed"))
   ~~gone~~ ⇒ doc(p(del(t"gone")))
   ~single~ ⇒ doc(p(t"~single~"))
   *a* ⇒ doc(p(em(t"a")))
   _a_ ⇒ doc(p(em(t"a")))
   **a** ⇒ doc(p(strong(t"a")))
   __a__ ⇒ doc(p(strong(t"a")))
   ***a*** ⇒ doc(p(em(strong(t"a"))))
   snake_case_word ⇒ doc(p(t"snake_case_word"))
   a*b*c ⇒ doc(p(t"a",em(t"b"),t"c"))
   **bold with *nested italic* inside** ⇒ doc(p(strong(t"bold with ",em(t"nested italic"),t" inside")))
   ==mark with ~~del~~== ⇒ doc(p(mark(t"mark with ",del(t"del"))))
   *a **b** c* ⇒ doc(p(em(t"a ",strong(t"b"),t" c")))
   2 * 3 * 4 ⇒ doc(p(t"2 * 3 * 4"))
   **not closed ⇒ doc(p(t"**not closed"))
   \*esc\* ⇒ doc(p(t"*esc*"))
   ==== ⇒ doc(p(t"===="))
   a==b==c ⇒ doc(p(t"a",mark(t"b"),t"c"))
   # inline comments
   a %%hidden%% b ⇒ doc(p(t"a ",icmt"hidden",t" b"))
   %%x%% ⇒ doc(p(icmt"x"))
   text %%a%% and %%b%% ⇒ doc(p(t"text ",icmt"a",t" and ",icmt"b"))
   **%%x%%** ⇒ doc(p(strong(icmt"x")))
   `%%x%%` ⇒ doc(p(c"%%x%%"))
   x %%a ⇒ doc(p(t"x %%a"))
   # comment blocks
   %% ⇒ doc(cmt)
   %%⏎hidden⏎%% ⇒ doc(cmt)
   %%⏎a⏎%%⏎⏎text ⇒ doc(cmt,p(t"text"))
   %%a⏎b%% c ⇒ doc(cmt)
   %%a ⇒ doc(cmt)
   # block ids
   Paragraph text ^abc ⇒ doc(p(t"Paragraph text ",bid"abc"))
   Para ^a-b-1 ⇒ doc(p(t"Para ",bid"a-b-1"))
   Para^abc ⇒ doc(p(t"Para^abc"))
   ^abc ⇒ doc(p(bid"abc"))
   ## Heading ^h1 ⇒ doc(h2{id=h1}(t"Heading ",bid"h1"))
   - item ^i1 ⇒ doc(ul(li(p(t"item ",bid"i1"))))
   Para ^bad id ⇒ doc(p(t"Para ^bad id"))
   Para ^abc  ⇒ doc(p(t"Para ",bid"abc"))
   Para ^a_b ⇒ doc(p(t"Para ^a_b"))
   > quote ^q1 ⇒ doc(bq(p(t"quote ",bid"q1")))
   Para ^ABC ⇒ doc(p(t"Para ",bid"ABC"))
   # callouts
   > [!note]⏎> Body ⇒ doc(callout{type=note}(p(t"Body")))
   > [!note] Title⏎> Body ⇒ doc(callout{type=note,title=Title}(p(t"Body")))
   > [!tip]+ Open⏎> b ⇒ doc(callout{type=tip,title=Open,f=+}(p(t"b")))
   > [!warning]- Closed⏎> b ⇒ doc(callout{type=warning,title=Closed,f=-}(p(t"b")))
   > [!WARNING] Upper ⇒ doc(callout{type=warning,title=Upper})
   > [!custom-type] T ⇒ doc(callout{type=custom-type,title=T})
   > [!note] ⇒ doc(callout{type=note})
   > [!note]+ ⇒ doc(callout{type=note,f=+})
   > [!note] Title with **bold** ⇒ doc(callout{type=note,title=Title with **bold**})
   > [!note] Outer⏎> > [!question] Inner⏎> > Body ⇒ doc(callout{type=note,title=Outer}(callout{type=question,title=Inner}(p(t"Body"))))
   > [!info] T⏎> - item⏎> - [ ] task ⇒ doc(callout{type=info,title=T}(ul(li(p(t"item")),li{task=SP}(p(t"task")))))
   > [!note]⏎> line1⏎> line2 ⇒ doc(callout{type=note}(p(t"line1",sb,t"line2")))
   > Not a callout [!note] ⇒ doc(bq(p(t"Not a callout [!note]")))
   >[!note] x ⇒ doc(callout{type=note,title=x})
   > [!note]⏎⏎> Another ⇒ doc(callout{type=note},bq(p(t"Another")))
   > [! note] x ⇒ doc(bq(p(t"[! note] x")))
   > [!note]text ⇒ doc(bq(p(t"[!note]text")))
   > [!faq]- Folded⏎> > nested quote ⇒ doc(callout{type=faq,title=Folded,f=-}(bq(p(t"nested quote"))))
   > > [!note] only inner ⇒ doc(bq(callout{type=note,title=only inner}))
   - > [!note] in list ⇒ doc(ul(li(callout{type=note,title=in list})))
   # tasks
   - [ ] a ⇒ doc(ul(li{task=SP}(p(t"a"))))
   - [x] a ⇒ doc(ul(li{task=x}(p(t"a"))))
   - [X] a ⇒ doc(ul(li{task=X}(p(t"a"))))
   - [/] a ⇒ doc(ul(li{task=/}(p(t"a"))))
   - [-] a ⇒ doc(ul(li{task=-}(p(t"a"))))
   - [>] a ⇒ doc(ul(li{task=>}(p(t"a"))))
   - [<] a ⇒ doc(ul(li{task=<}(p(t"a"))))
   - [?] a ⇒ doc(ul(li{task=?}(p(t"a"))))
   - [!] a ⇒ doc(ul(li{task=!}(p(t"a"))))
   - [ ]a ⇒ doc(ul(li(p(t"[ ]a"))))
   - [] a ⇒ doc(ul(li(p(t"[] a"))))
   1. [x] a ⇒ doc(ol(li{task=x}(p(t"a"))))
   * [ ] a⏎  * [x] b ⇒ doc(ul(li{task=SP}(p(t"a"),ul(li{task=x}(p(t"b"))))))
   - [ ] **bold** ⇒ doc(ul(li{task=SP}(p(strong(t"bold")))))
   - [xx] a ⇒ doc(ul(li(p(t"[xx] a"))))
   [ ] a ⇒ doc(p(t"[ ] a"))
   # math
   $x^2$ ⇒ doc(p(imath"x^2"))
   $$x$$ ⇒ doc(math"x")
   $$⏎x^2⏎$$ ⇒ doc(math"x^2")
   $$⏎a⏎b⏎$$ ⇒ doc(math"a⏎b")
   $5 and $10 ⇒ doc(p(t"$5 and $10"))
   $ x$ ⇒ doc(p(t"$ x$"))
   $x $ ⇒ doc(p(t"$x $"))
   cost $5. ⇒ doc(p(t"cost $5."))
   $a$ and $b$ ⇒ doc(p(imath"a",t" and ",imath"b"))
   \$x\$ ⇒ doc(p(t"$x$"))
   `$x$` ⇒ doc(p(c"$x$"))
   text $$a$$ text ⇒ doc(p(t"text ",imath"a",t" text"))
   $x ⇒ doc(p(t"$x"))
   $1,000 and $2,000 total ⇒ doc(p(t"$1,000 and $2,000 total"))
   $a$1 ⇒ doc(p(t"$a$1"))
   $$ ⇒ doc(math"")
   # footnotes
   text[^1] ⇒ doc(p(t"text",fref"1"))
   [^note]: The note. ⇒ doc(fn{label=note}(p(t"The note.")))
   [^1]: a⏎    b ⇒ doc(fn{label=1}(p(t"a",sb,t"b")))
   [^1]: a⏎⏎    second para ⇒ doc(fn{label=1}(p(t"a"),p(t"second para")))
   [^1]: a⏎next ⇒ doc(fn{label=1}(p(t"a",sb,t"next")))
   [^1]: a⏎⏎after ⇒ doc(fn{label=1}(p(t"a")),p(t"after"))
   ^[inline note] ⇒ doc(p(ifn(t"inline note")))
   text^[a *b*] ⇒ doc(p(t"text",ifn(t"a ",em(t"b"))))
   [^a b] ⇒ doc(p(t"[^a b]"))
   [^1]: ⇒ doc(fn{label=1})
   [^1] ⇒ doc(p(fref"1"))
   # frontmatter
   ---⏎title: T⏎---⏎Body ⇒ doc(fm,p(t"Body"))
   ---⏎---⏎x ⇒ doc(fm,p(t"x"))
   ⏎---⏎a: 1⏎--- ⇒ doc(hr,h2(t"a: 1"))
   ---⏎a: 1 ⇒ doc(hr,p(t"a: 1"))
   ---   ⏎a: 1⏎--- ⇒ doc(fm)
   --- x⏎a⏎--- ⇒ doc(h2(t"--- x",sb,t"a"))
   ---⏎a: 1⏎--- ⇒ doc(fm)
   # lists
   - a⏎- b ⇒ doc(ul(li(p(t"a")),li(p(t"b"))))
   1. a⏎2. b ⇒ doc(ol(li(p(t"a")),li(p(t"b"))))
   7. a⏎8. b ⇒ doc(ol{start=7}(li(p(t"a")),li(p(t"b"))))
   - a⏎⏎- b ⇒ doc(ul{loose}(li(p(t"a")),li(p(t"b"))))
   - a⏎  - b ⇒ doc(ul(li(p(t"a"),ul(li(p(t"b"))))))
   * a⏎+ b ⇒ doc(ul(li(p(t"a"))),ul(li(p(t"b"))))
   1) a⏎2) b ⇒ doc(ol(li(p(t"a")),li(p(t"b"))))
   - a⏎⏎  b ⇒ doc(ul{loose}(li(p(t"a"),p(t"b"))))
   para⏎2. x ⇒ doc(p(t"para",sb,t"2. x"))
   para⏎1. x ⇒ doc(p(t"para"),ol(li(p(t"x"))))
   para⏎- x ⇒ doc(p(t"para"),ul(li(p(t"x"))))
   para⏎- ⇒ doc(h2(t"para"))
   - a⏎b ⇒ doc(ul(li(p(t"a",sb,t"b"))))
   -→tab ⇒ doc(ul(li(p(t"tab"))))
   # code
   ```dart⏎x⏎``` ⇒ doc(code{lang=dart})
   ~~~⏎x⏎~~~ ⇒ doc(code)
       indented ⇒ doc(icode)
   ```⏎unclosed ⇒ doc(code)
   ```mermaid⏎graph⏎``` ⇒ doc(code{lang=mermaid})
   ``` js linenos⏎x⏎``` ⇒ doc(code{lang=js})
   `a` ⇒ doc(p(c"a"))
   ``a`b`` ⇒ doc(p(c"a`b"))
   ` a ` ⇒ doc(p(c"a"))
   `unclosed ⇒ doc(p(t"`unclosed"))
   `a⏎b` ⇒ doc(p(c"a b"))
   # tables
   |a|b|⏎|-|-|⏎|1|2| ⇒ doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))
   a|b⏎-|-⏎1|2 ⇒ doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))
   |a|b|⏎|:-|-:| ⇒ doc(table{aligns=l,r}(trh(td(t"a"),td(t"b"))))
   |a|b|⏎|:-:|---|⏎|1|2| ⇒ doc(table{aligns=c,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))
   |a|⏎|-|⏎|x \| y| ⇒ doc(table{aligns=n}(trh(td(t"a")),tr(td(t"x | y"))))
   |a|b|⏎|-|⏎|1|2| ⇒ doc(p(t"|a|b|",sb,t"|-|",sb,t"|1|2|"))
   |a|b|⏎|-|-|⏎|1| ⇒ doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td)))
   |a|b|⏎|-|-|⏎|1|2|3| ⇒ doc(table{aligns=n,n}(trh(td(t"a"),td(t"b")),tr(td(t"1"),td(t"2"))))
   |[[N\|A]]|⏎|-|⏎|x| ⇒ doc(table{aligns=n}(trh(td(wiki{t=N,a=A})),tr(td(t"x"))))
   |`code \| x`|⏎|-|⏎|y| ⇒ doc(table{aligns=n}(trh(td(c"code | x")),tr(td(t"y"))))
   |a|⏎|-|⏎|1|⏎text ⇒ doc(table{aligns=n}(trh(td(t"a")),tr(td(t"1")),tr(td(t"text"))))
   |a|⏎|-|⏎|1|⏎⏎text ⇒ doc(table{aligns=n}(trh(td(t"a")),tr(td(t"1"))),p(t"text"))
   para⏎|a|⏎|-|⏎|1| ⇒ doc(p(t"para"),table{aligns=n}(trh(td(t"a")),tr(td(t"1"))))
   |**b**|⏎|-|⏎|*i*| ⇒ doc(table{aligns=n}(trh(td(strong(t"b"))),tr(td(em(t"i")))))
   # blockquotes, html, breaks, escapes, headings, mixed
   > a ⇒ doc(bq(p(t"a")))
   > a⏎b ⇒ doc(bq(p(t"a",sb,t"b")))
   > > b ⇒ doc(bq(bq(p(t"b"))))
   > a⏎⏎> b ⇒ doc(bq(p(t"a")),bq(p(t"b")))
   > - x ⇒ doc(bq(ul(li(p(t"x")))))
   <div>x</div> ⇒ doc(html)
   <span>x</span> ⇒ doc(p(ihtml"<span>",t"x",ihtml"</span>"))
   <!-- c --> ⇒ doc(html)
   a <br> b ⇒ doc(p(t"a ",ihtml"<br>",t" b"))
   <3 not html ⇒ doc(p(t"<3 not html"))
   x <!-- c --> y ⇒ doc(p(t"x ",ihtml"<!-- c -->",t" y"))
   <script>⏎x⏎</script> ⇒ doc(html)
   a⏎b ⇒ doc(p(t"a",sb,t"b"))
   a  ⏎b ⇒ doc(p(t"a",br,t"b"))
   a\⏎b ⇒ doc(p(t"a",br,t"b"))
   a⏎⏎b ⇒ doc(p(t"a"),p(t"b"))
   a\ ⇒ doc(p(t"a\"))
   --- ⇒ doc(hr)
   *** ⇒ doc(hr)
   - - - ⇒ doc(hr)
   &amp; ⇒ doc(p(t"&"))
   &lt;b&gt; ⇒ doc(p(t"<b>"))
   &#65; ⇒ doc(p(t"A"))
   &#x41; ⇒ doc(p(t"A"))
   &nosuch; ⇒ doc(p(t"&nosuch;"))
   \\ ⇒ doc(p(t"\"))
   \a ⇒ doc(p(t"\a"))
   # H ⇒ doc(h1(t"H"))
   # H # ⇒ doc(h1(t"H"))
   Title⏎=== ⇒ doc(h1(t"Title"))
   Title⏎--- ⇒ doc(h2(t"Title"))
   - [[A]] ⇒ doc(ul(li(p(wiki{t=A}))))
   > [[A]] ⇒ doc(bq(p(wiki{t=A})))
   ## [[A]] ⇒ doc(h2(wiki{t=A}))
   **[[A]]** #t ==h== %%c%% $m$ [^1] ⇒ doc(p(strong(wiki{t=A}),t" ",tag"t",t" ",mark(t"h"),t" ",icmt"c",t" ",imath"m",t" ",fref"1"))
   ```
   (The group `# lists` contains a case whose input begins with spaces — `    indented` in `# code` is four literal spaces. Preserve leading/trailing spaces of `INPUT` exactly: split each line on the first ` ⇒ ` only and do not trim the input side.)
6. **`syntax_vault_test.dart`**: for each of the 24 notes of `test_vaults/syntax` (path `../../test_vaults/syntax`), parse and assert (one `test()` per note, names = file names):
   `01-headings.md`: 6 ATX + 2 setext + 2 more `##` = headings count and levels `[1,2,3,4,5,6,1,2,2,2]`; `#NotAHeadingButATag` is a paragraph with one tag; `####### Seven…` is a paragraph; the heading with `^heading-id` has `blockId == 'heading-id'` and a `BlockRef`.
   `02-paragraphs.md`: ≥ 1 hard break (backslash) and ≥ 1 soft break; `03-emphasis.md`: contains `MdHighlight`×2, `MdStrikethrough`×1, no emphasis inside `snake_case_words_stay_plain`; `04-lists.md`: ordered list with `startNumber == 7` exists, a loose list exists, a nested list of depth 3 exists;
   `05-tasks.md`: statuses in order `[' ','x','X','/','-','>','<','?','!',' ',' ',' ','x']` for the first 13 tasks and the last line `- [ ]Not a task…` is **not** a task (assert `tasks.length == 13`);
   `06-blockquotes.md`: 4 top-level quote nodes + one nested; `07-callouts.md`: 27 typed callouts with types in the documented order, then callout fold values `[none, expanded, collapsed]` for the three foldable cases, the nested callout has a child `MdCallout` of type `question`, `[!WARNING]` gives `type == 'warning'`, `custom-type` is a callout;
   `08-code.md`: fenced blocks with languages `dart`, `python`, none, plus the remaining blocks present in the file (assert `codeBlocks.length` equals the number of fences in the file computed by counting lines starting with ``` or ~~~ and halving);
   `09-tables.md`: ≥ 2 tables, at least one with alignments `[left, center, right]`, one cell containing an escaped pipe; `10-links.md`: counts of `MdLink`, `MdAutolink` (≥ 1 each) and one image; `11-wikilinks.md`: ≥ 8 wikilinks incl. one with `heading`, one with `blockRef`, one with `alias`; `Folder/Nested Note.md` parses with no error;
   `12-embeds.md`: ≥ 1 embed with `size` (width and height), one with `pdfPage`; `13-tags.md`: `tags` contains `nested/tag` and no numeric-only tag; `14-comments.md`: ≥ 1 `MdCommentInline` and ≥ 1 `MdCommentBlock`; `15-block-ids.md`: `blockIds.length ≥ 3`; `16-math.md`: ≥ 1 `MdInlineMath`, ≥ 1 `MdMathBlock`, and `$5 and $10` produces none;
   `17-footnotes.md`: ≥ 1 ref, ≥ 1 definition, ≥ 1 inline footnote; `18-frontmatter.md`: `frontmatterValid`, `frontmatter` non-empty, first child `MdFrontmatter`; `19-html.md`: ≥ 1 `MdHtmlBlock` and ≥ 1 `MdHtmlInline`; `20-thematic-breaks.md`: ≥ 3 `MdThematicBreak`; `21-escapes-entities.md`, `22-mixed.md`, `23-unicode.md`: parse without exception and the Bangla tag `#বাংলা` (if present in the file) appears in `tags`.
   Where a count in the fixture text differs from the numbers above, **count in the file** and assert the real number (the assertions are meant to detect parser regressions, not to re-validate the fixture author).
7. **`fuzz_test.dart`** (seeded; print the seed on failure per conventions §8): 2,000 random documents built from a vocabulary of fragments (`#`, `##`, `- `, `1. `, `> `, `> [!note] `, `[[`, `]]`, `![[`, `|`, `**`, `_`, `==`, `~~`, `%%`, `$`, `$$`, `` ` ``, ` ``` `, `---`, `[^1]`, `^id`, `<div>`, `\`, `&amp;`, tab, spaces, newlines, Bangla and emoji strings), 1–60 fragments each. For every document: parse does not throw; **every node satisfies `0 <= start <= end <= text.length`, children are inside the parent's range, and siblings are ordered and non-overlapping** (inline children of a paragraph may leave gaps for stripped container prefixes but never overlap); the dump of `parse(text)` equals the dump of a second parse (determinism). A second fuzz with seed 7 uses only `ParserOptions.commonMark` and compares nothing but invariants.
8. After the tests pass, update `packages/tephra_markdown/README.md` (a "Syntax supported" list and the conformance numbers).

**Tests** as above; total new test count for this package is expected to exceed 1,000 (spec examples are individual test cases).

**Verify** `cd packages/tephra_markdown; dart test; cd ../..` (the whole package, < 60 s). `dart analyze packages/tephra_markdown`. Record in `PROGRESS.md`: conformance numbers, count of Obsidian cases passing (must be all), fuzz seeds used. Commit `phase 01.10: add conformance, Obsidian cases and fuzz tests`.

**Pitfalls**
- The test-only HTML renderer lives in `test/`; never import it from `lib/`.
- Do not "fix" a conformance failure by special-casing the example text. Fix the algorithm.
- The known-failures file may only **shrink**; never add an example to make the suite green — fix the parser or report to the human.
- Treat expected values in the case table as strict; adjust only per the "rule wins" sentence and log each adjustment.

---

### 01.11 App services: JSON stores, app and vault settings, platform services, vault session providers

**Purpose** The app-level foundations every feature uses: atomic JSON files (`.tephra/*.json` and the app settings file), settings models, platform adapters (conventions §5.9) and the vault session/provider layer.

**Files** (under `app/lib/`)
- `core/uuid.dart`, `core/json_file_store.dart`, `core/providers.dart`
- `core/platform/storage_permission_service.dart`, `core/platform/system_trash_windows.dart`, `core/platform/platform_providers.dart`
- `settings/app_settings.dart`, `settings/app_settings_store.dart`, `settings/vault_settings.dart`, `settings/vault_settings_store.dart`, `settings/providers.dart`
- `vault/vault_session.dart`, `vault/vault_file_system_factory.dart`, `vault/providers.dart`
- modify `main.dart` (load app settings before `runApp`)
- tests: `app/test/helpers/test_app.dart`, `app/test/core/uuid_test.dart`, `app/test/core/json_file_store_test.dart`, `app/test/settings/app_settings_test.dart`, `app/test/settings/vault_settings_test.dart`, `app/test/core/platform/system_trash_windows_test.dart`, `app/test/vault/vault_providers_test.dart`

**Implementation**
1. `core/uuid.dart`: `String generateUuidV4([Random? random])` — 16 random bytes (`Random.secure()` by default), set version nibble (`bytes[6] = (bytes[6] & 0x0F) | 0x40`) and variant (`bytes[8] = (bytes[8] & 0x3F) | 0x80`), format `8-4-4-4-12` lower-case hex.
2. `core/json_file_store.dart` — `TephraJsonStore` (stateless helper, `const TephraJsonStore()`), used for every `.tephra/*.json`:
   ```dart
   Future<Map<String, Object?>> readMap(VaultFileSystem fs, VaultPath path);   // missing file → {}; invalid JSON or not an object → {} and Logger('settings').warning
   Future<bool> writeMap(VaultFileSystem fs, VaultPath path, Map<String, Object?> map);   // returns false (and writes nothing) when the encoded text equals the file's current text
   Future<void> update(VaultFileSystem fs, VaultPath path, void Function(Map<String, Object?> map) mutate);   // read → mutate → write
   ```
   Encoding: `JsonEncoder.withIndent('  ').convert(map)` + `'\n'`, UTF-8, LF, no BOM. `writeMap`: if the file exists and is **invalid JSON**, first copy its bytes to `<name>.bad-<yyyyMMddHHmmss>` in the same folder (so a corrupt user file is never silently destroyed), then write. Unknown keys are preserved because every update starts from the file's current map.
   Also `AppJsonFile` for files outside the vault: `AppJsonFile(File file)` with `Map<String, Object?> readSync()` (missing/invalid → `{}`) and `Future<void> write(Map<String, Object?> map)` using `AtomicFileWriter` from `tephra_vault`.
3. `core/platform/storage_permission_service.dart` (conventions §5.9):
   ```dart
   enum StorageAccess { granted, denied, permanentlyDenied, notNeeded }
   abstract interface class StoragePermissionService {
     Future<StorageAccess> status();
     Future<StorageAccess> request();           // Android: opens the system "All files access" page when needed; returns the status after the user returns
     Future<void> openSystemSettings();
   }
   final class NoopStoragePermissionService implements StoragePermissionService { /* status() → notNeeded; request() → notNeeded; openSystemSettings() → completes */ }
   final class AndroidStoragePermissionService implements StoragePermissionService { ... }
   ```
   `AndroidStoragePermissionService`: obtain the SDK level once with `DeviceInfoPlugin().androidInfo` (`version.sdkInt`). SDK ≥ 30 → `Permission.manageExternalStorage` (`status`, `request`); SDK 26–29 → `Permission.storage`. Map `PermissionStatus.granted` → `granted`, `permanentlyDenied` → `permanentlyDenied`, other → `denied`. `openSystemSettings()` → `openAppSettings()` from `permission_handler`.
   `core/platform/platform_providers.dart`: `storagePermissionServiceProvider = Provider<StoragePermissionService>((ref) => (!kIsWeb && Platform.isAndroid) ? AndroidStoragePermissionService() : const NoopStoragePermissionService())` (platform checks are allowed here — conventions §5.9).
4. `core/platform/system_trash_windows.dart`: `final class WindowsSystemTrash implements SystemTrash`. `moveToTrash(absolutePath, {required isFolder})`: `Process.run('powershell.exe', ['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-Command', script], environment: {'TEPHRA_TRASH_PATH': absolutePath}, includeParentEnvironment: true)` with `.timeout(Duration(seconds: 20))`; `script` =
   `Add-Type -AssemblyName Microsoft.VisualBasic; $p = $env:TEPHRA_TRASH_PATH; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin')` (for folders `DeleteDirectory` instead of `DeleteFile`).
   Return `exitCode == 0`; on timeout/exception log `warning` and return `false` (the vault falls back to `.trash/`). The path travels in an **environment variable** so no quoting or injection is possible.
   Provider `systemTrashProvider = Provider<SystemTrash?>((ref) => (!kIsWeb && Platform.isWindows) ? WindowsSystemTrash() : null)` in `core/providers.dart`.
5. `settings/app_settings.dart`:
   ```dart
   final class RecentVault { const RecentVault({required this.path, required this.name, required this.lastOpened}); final String path; final String name; final DateTime lastOpened; ... toJson/fromJson ... }
   final class AppSettings {
     const AppSettings({this.themeMode = 'system', this.recentVaults = const [], required this.deviceId, this.deviceName = '', this.lastVaultPath, this.recentCommands = const [], this.extra = const {}});
     final String themeMode;              // 'system' | 'light' | 'dark'
     final List<RecentVault> recentVaults; // newest first, max 12
     final String deviceId;               // uuid v4, generated on first run
     final String deviceName;             // default: Platform.localHostname (Windows) or 'Android device'; the user may edit later
     final String? lastVaultPath;         // reopened at start when it still exists
     final List<String> recentCommands;   // command ids, newest first, max 10
     final Map<String, Object?> extra;    // unknown keys, written back untouched
     AppSettings copyWith(...); factory AppSettings.fromJson(Map<String, Object?>, {required String Function() newDeviceId}); Map<String, Object?> toJson();
   }
   ```
   `settings/app_settings_store.dart`: `AppSettingsStore(AppJsonFile file)`: `AppSettings load()` (creates `deviceId` when missing and writes it back) and `Future<void> save(AppSettings s)`. The file is `<appSupportDir>/settings.json` (conventions §6.6).
   `settings/providers.dart`: `initialAppSettingsProvider = Provider<AppSettings>((ref) => throw UnimplementedError('override in main'))`, `appSettingsStoreProvider = Provider<AppSettingsStore?>((ref) => null)`, and
   `appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new)` — `build()` returns `ref.watch(initialAppSettingsProvider)`; `update(AppSettings Function(AppSettings) f)` sets state and saves via the store (fire-and-forget with error logging); helpers `addRecentVault(path, name)`, `removeRecentVault(path)`, `touchCommand(id)`.
   `core/providers.dart` re-exports `appSettingsProvider` (`export '../settings/providers.dart' show appSettingsProvider, vaultSettingsProvider;`) so both import paths named in the Provider index work.
   `main.dart`: after `setupLogging()`/`installCrashHandlers()`: `final dir = await getApplicationSupportDirectory(); final store = AppSettingsStore(AppJsonFile(File(p.join(dir.path, 'settings.json')))); final initial = store.load();` and `runApp(ProviderScope(overrides: [initialAppSettingsProvider.overrideWithValue(initial), appSettingsStoreProvider.overrideWithValue(store)], child: const TephraApp()))`. On web (`kIsWeb`) use an in-memory store (no file). Log `Logger('app').info('device ${initial.deviceId.substring(0, 8)}…')`.
6. `settings/vault_settings.dart` — `VaultSettings` (immutable, `copyWith`, `==`, `fromJson(Map<String, Object?>)`, `toJson()`); JSON keys and defaults (all keys optional on read):

   | Field / JSON key | Type | Default | Meaning |
   |---|---|---|---|
   | `attachmentFolder` | String | `'/'` | §6.7: `'/'` vault root, `'./'` note's folder, `'./sub'` subfolder of note's folder, otherwise a fixed vault-relative folder |
   | `newFileLocation` | String | `'root'` | `'root'`, `'current'` (folder of the active note), `'folder'` |
   | `newFileFolder` | String | `''` | used when `newFileLocation == 'folder'` |
   | `trashMode` | String | `'vaultTrash'` | `'system'`, `'vaultTrash'`, `'permanent'` |
   | `showHidden` | bool | `false` | show dot-folders in the explorer (never `.obsidian`/`.tephra`/`.trash`/`.git`) |
   | `useTab` | bool | `true` | indent with a tab character |
   | `tabSize` | int | `4` | spaces per indent level (also the width of a tab); clamp 2–8 |
   | `readableLineLength` | bool | `true` | reading view/editor max width 700 dp on wide screens |
   | `defaultViewMode` | String | `'reading'` | `'reading'` or `'source'`: mode of a newly opened tab |
   | `fontSize` | double | `16` | body text size; clamp 12–32 |
   | `explorerSort` | String | `'nameAsc'` | `nameAsc, nameDesc, modifiedNew, modifiedOld, createdNew, createdOld` |
   | `dailyNotes` | Map | `{}` | imported `{folder, format, template}` (used from Phase 2) |
   | `templates` | Map | `{}` | imported `{folder, dateFormat, timeFormat}` |
   | `importedFromObsidian` | bool | `false` | one-time import done |

   Invalid values fall back to the default (e.g. `tabSize: 99` → 4); unknown keys go into an `extra` map and are written back unchanged. Enumerated strings are exposed as Dart enums `NewFileLocation`, `TrashChoice` (map to `tephra_vault.TrashMode`), `ViewModeSetting`, `ExplorerSort { nameAsc, nameDesc, modifiedNew, modifiedOld, createdNew, createdOld }` (defined **here**, in `vault_settings.dart`; step 01.17 only imports it) with `fromJson`/`toJson` helpers; `VaultSettings` exposes typed getters `newFileLocationEnum`, `trashChoice`, `viewMode`, `explorerSortEnum`, and `TrashMode get trashMode => …` mapping `'system'`/`'vaultTrash'`/`'permanent'` to `tephra_vault.TrashMode` (the JSON string field is named `trashMode`; the getter is `trashModeEnum`).
   `settings/vault_settings_store.dart`: `VaultSettingsStore(VaultFileSystem fs)`: `Future<VaultSettings> load()` (reads `.tephra/settings.json` via `TephraJsonStore`) and `Future<void> save(VaultSettings s)` — saves by `update`ing the existing map with `toJson()` entries (so unknown keys survive).
   `settings/providers.dart`: `vaultSettingsProvider = NotifierProvider<VaultSettingsNotifier, VaultSettings>(...)`: `build()` returns `ref.watch(vaultSessionProvider)?.settings ?? const VaultSettings()`; `update(VaultSettings Function(VaultSettings) f)` sets state and saves (serialised: queue writes so two quick updates cannot interleave).
7. `vault/vault_session.dart`: `final class VaultSession { const VaultSession({required this.vaultId, required this.rootDir, required this.name, required this.fs, required this.settings, this.isAppPrivate = false}); final String vaultId; final String rootDir; final String name; final VaultFileSystem fs; final VaultSettings settings /* snapshot at open time; live values come from vaultSettingsProvider */; final bool isAppPrivate; }`.
   `vault/vault_file_system_factory.dart`:
   ```dart
   // Value copied from docs/spikes/android-storage.md "Phase 1 watcher" (ANDROID_WATCHER in PROGRESS.md): native or polling.
   const WatcherMode androidWatcherMode = WatcherMode.<native|polling>;
   VaultFileSystem createVaultFileSystem(String rootDir, VaultSettings settings, {SystemTrash? systemTrash});
   ```
   `createVaultFileSystem` returns `IoVaultFileSystem(rootDir, ignore: VaultIgnore(showHidden: settings.showHidden), systemTrash: systemTrash, watcherMode: (!kIsWeb && Platform.isAndroid) ? androidWatcherMode : WatcherMode.native)`. Replace `<native|polling>` by the recorded value — write exactly one of the two words.
   `vault/providers.dart`:
   | Provider | Declaration |
   |---|---|
   | `vaultSessionProvider` | `NotifierProvider<VaultSessionNotifier, VaultSession?>`; `VaultSessionNotifier` has `void set(VaultSession? s)` (disposes the previous `fs`) and `void close()`; opening logic is in step 01.12 (`VaultOpener`) |
   | `vaultFsProvider` | `Provider<VaultFileSystem>((ref) { final s = ref.watch(vaultSessionProvider); if (s == null) throw StateError('No vault is open'); return s.fs; })` |
   | `vaultChangesProvider` | `StreamProvider<VaultChange>((ref) => ref.watch(vaultFsProvider).watch())` — external changes only |
   | `vaultRevisionProvider` | `NotifierProvider<VaultRevisionNotifier, int>`: `bump()` increments. Bumped by the app after every file operation it performs and (debounced 300 ms) when `vaultChangesProvider` emits; list-like providers `ref.watch` it |
   | `vaultNameProvider` | `Provider<String>` — session name or `''` |
   `core/providers.dart` also declares `clockProvider = Provider<Clock>((ref) => const SystemClock())` and re-exports (see 5) — **all app code obtains time through `clockProvider`**.
8. `test/helpers/test_app.dart`: `Widget testApp(Widget child, {MemoryVaultFileSystem? fs, VaultSettings settings = const VaultSettings(), AppSettings? appSettings, Size size = const Size(1200, 800), List<Override> overrides = const []})` — wraps `child` in `ProviderScope` (overrides: `initialAppSettingsProvider`, `vaultSessionProvider` through `class FixedVaultSessionNotifier extends VaultSessionNotifier` returning a fixed `VaultSession(vaultId: 'test', rootDir: '/memory', name: 'Test vault', fs: fs ?? MemoryVaultFileSystem(), settings: settings)`, `clockProvider` with a `ManualClock(DateTime(2026, 10, 11, 9, 30))`) and a `MaterialApp` with the localisation delegates, `AppTheme.light()`, and a `MediaQuery` of `size`. `void setSurfaceSize(WidgetTester t, Size s)` helper (`t.view.physicalSize = s * t.view.devicePixelRatio; addTearDown(t.view.reset)`). All later widget tests use these helpers.

**Tests**
- `uuid_test.dart`: matches `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`; 1,000 values are unique; a seeded `Random(1)` gives a stable value across two calls.
- `json_file_store_test.dart` (memory fs): `readMap` of a missing file → `{}`; invalid JSON → `{}` and no throw; `update` keeps an unknown key `{"zzz": [1,2]}`; `writeMap` returns `false` and `fs.writeCount` is unchanged when the content is identical; writing over an invalid file creates `settings.json.bad-<ts>` with the old bytes (`ManualClock`-based timestamp via the fs `clock`… use the real clock and assert the name matches `^settings\.json\.bad-\d{14}$`); output ends with `\n` and uses 2-space indentation.
- `app_settings_test.dart`: `fromJson({})` generates a device id (call counter 1); unknown keys round-trip; `recentVaults` ordering/dedupe (`addRecentVault` moves an existing path to the front, max 12); `touchCommand` keeps 10 newest unique; `AppSettingsStore.load()` on a missing file creates the file with a `deviceId`.
- `vault_settings_test.dart`: `fromJson({})` equals defaults; every key round-trips; `tabSize: 99` → 4, `fontSize: 5` → 12, `trashMode: 'bogus'` → `'vaultTrash'`; unknown key preserved after `VaultSettingsStore.save`; saving two settings changes in a row leaves both changes.
- `system_trash_windows_test.dart` (Windows only, `skip:` reason otherwise): create a temp file, `moveToTrash` → returns `true` and the file no longer exists; a non-existent path → `false`.
- `vault_providers_test.dart`: `vaultFsProvider` throws `StateError` with no session; with a fixed session returns its `fs`; `vaultRevisionProvider.bump()` increments.
- Add l10n keys: none visible yet (settings screens come in 01.14).

**Verify** `cd app; flutter test test/core test/settings test/vault; cd ..` + standard checks. Commit `phase 01.11: add app services, settings and vault providers`.

**Pitfalls**
- `Platform` use is allowed only in `core/platform/*`, `vault_file_system_factory.dart` and `main.dart` (platform-only features).
- Never log vault paths with file contents; paths are fine at `info`.
- `permission_handler` must never be called on Windows (the provider guarantees it).
- Keep `initialAppSettingsProvider` throwing by default: a test that forgets the override must fail loudly.

---

### 01.12 Vault picker, create/open, recent vaults, Android permission flow, `.obsidian` import

**Purpose** The first screen the user sees: open an existing vault or create one, with safe vault bootstrap (`.tephra/vault.json`) and a one-time, read-only import of Obsidian settings.

**Files** (under `app/lib/vault/` unless noted)
- `vault_opener.dart`, `vault_creator.dart`, `vault_metadata.dart`, `obsidian_importer.dart`, `obsidian_hotkeys.dart`, `vault_gate.dart`
- `vault_picker_screen.dart`, `storage_access_screen.dart`, `create_vault_dialog.dart`, `recent_vault_tile.dart`
- modify `app/lib/app.dart` (home = `VaultGate`), delete `app/lib/welcome/` and `app/test/welcome/`, modify `app/test/app_test.dart`
- `app/lib/core/platform/` (already created), `app/lib/l10n/app_en.arb`
- tests: `app/test/vault/vault_opener_test.dart`, `vault_creator_test.dart`, `vault_metadata_test.dart`, `obsidian_importer_test.dart`, `obsidian_hotkeys_test.dart`, `vault_picker_screen_test.dart`, `storage_access_screen_test.dart`, `app/test/app_test.dart`

**Implementation**
1. `vault_metadata.dart`: `final class VaultMetadata { const VaultMetadata({required this.id, required this.createdAt, this.formatVersion = 1}); }` and
   `Future<VaultMetadata> ensureVaultMetadata(VaultFileSystem fs, Clock clock, {Random? random})`:
   read `.tephra/vault.json` with `TephraJsonStore`. Missing → create `{ "id": <uuid v4>, "createdAt": <clock.now().toUtc().toIso8601String()>, "formatVersion": 1 }`. Present with a valid string `id` → keep as is. Present but **no `id`** → add `id` (and `createdAt`, `formatVersion` if missing) keeping other keys. Present with `formatVersion` > 1 → throw `VaultTooNewException` (a `TephraException` subclass declared in this file; the UI shows `vaultTooNewMessage`). Invalid JSON → treated as missing (the bad file is preserved by `TephraJsonStore.writeMap`).
2. `vault_opener.dart`:
   ```dart
   final class VaultOpener {
     VaultOpener(this.ref);
     /// Validates [rootDir], builds the file system, ensures metadata, runs the Obsidian import once, installs the session.
     /// Throws FileNotFoundException-like StateError text only via VaultOpenException (message codes: 'missing', 'not-a-folder', 'no-access', 'too-new').
     Future<VaultSession> open(String rootDir, {bool isAppPrivate = false});
   }
   ```
   Steps of `open`: (1) `Directory(rootDir).exists()` else `VaultOpenException('missing')`; (2) read-access probe `Directory.list().first` inside try/catch → `no-access`; on Android a probe failure with permission denied → `no-access`; (3) `settingsFs = createVaultFileSystem(rootDir, const VaultSettings(), systemTrash: ref.read(systemTrashProvider))`
   (temporary, used to load settings); (4) `meta = ensureVaultMetadata(...)`; (5) if `.tephra/settings.json` does not exist: `ObsidianImporter(settingsFs).run()` (step 6); (6) `settings = await VaultSettingsStore(settingsFs).load()`; if `settings.showHidden` differs from the default, recreate the fs with the right `VaultIgnore` (dispose the first); (7) create the `VaultSession(name: p.basename(rootDir), ...)`; (8) `ref.read(vaultSessionProvider.notifier).set(session)`;
   (9) `appSettings.addRecentVault(rootDir, name)` and `lastVaultPath = rootDir`; (10) `unawaited(fs.cleanStaleTemps())` for `IoVaultFileSystem`; (11) restore the workspace (step 01.13 provides `workspaceProvider.notifier.restore()`; call it only if that method exists — it is added in 01.13, so in this step leave a `// restored in 01.13` call site as `ref.read(vaultOpenedHooksProvider)` — see below).
   Define `vaultOpenedHooksProvider = Provider<List<Future<void> Function(Ref ref)>>((ref) => const [])` in `vault/providers.dart`; step 01.13 overrides its **body** (not an override in tests) to return `[restoreWorkspace]`; the opener awaits each hook after installing the session. (Avoids a compile-time dependency of this step on 01.13.)
   `VaultOpenException(String code)`.
3. `vault_creator.dart`: `Future<String> createVault({required String parentDir, required String name})`: validate `name` with `VaultPath.checkName(name)` (error → `VaultCreateException(code)`); `dir = p.join(parentDir, name)`; if it exists and is non-empty (ignoring `.tephra`) → `VaultCreateException('not-empty')`; create it; return the path. The metadata is created by `VaultOpener.open`. Never creates sample notes.
4. `obsidian_importer.dart` — `ObsidianImporter(VaultFileSystem fs, Clock clock)`, `Future<ImportSummary> run()` (`ImportSummary { bool foundObsidian; List<String> imported; List<String> skipped; }`). **Never writes under `.obsidian/`**; reads via `fs.stat/readText` (the fs does not apply ignore rules to direct reads). If `.obsidian/` does not exist → `foundObsidian = false`, nothing written, but `.tephra/settings.json` is still created (empty map plus `importedFromObsidian: false`) so the import is not retried.
   Mapping (each source file is optional; invalid JSON → skipped with a warning):
   - `app.json` → `VaultSettings`: `attachmentFolderPath` → `attachmentFolder`; `newFileLocation` (`root|current|folder`) → `newFileLocation`; `newFileFolderPath` → `newFileFolder`; `useTab` → `useTab`; `tabSize` → `tabSize`; `readableLineLength` → `readableLineLength`;
     `trashOption`: `system` → `system`, `local` → `vaultTrash`, `none` → `permanent`; `defaultViewMode`: `preview` → `reading`, anything else (including absent when `app.json` exists) → `source`.
   - `daily-notes.json` → `dailyNotes` = the entries `folder`, `format`, `template` that are strings; `templates.json` → `templates` = `folder`, `dateFormat`, `timeFormat`.
   - `hotkeys.json` → `.tephra/hotkeys.json` through `convertObsidianHotkeys` (below), only if the target does not exist.
   - `bookmarks.json` → copy **bytes** to `.tephra/bookmarks.json`, `types.json` → `.tephra/types.json`, only if the target does not exist.
   Finally `importedFromObsidian = true` when `.obsidian/` exists. Settings are written once via `VaultSettingsStore.save`.
5. `obsidian_hotkeys.dart`: `Map<String, List<String>> convertObsidianHotkeys(Map<String, Object?> obsidianJson)` — Obsidian shape `{ "editor:toggle-bold": [ {"modifiers": ["Mod"], "key": "b"} ] }`. Command id map (anything not listed is skipped and counted):
   `editor:toggle-bold` → `editor.toggle-bold`; `editor:toggle-italics` → `editor.toggle-italic`; `editor:toggle-strikethrough` → `editor.toggle-strikethrough`; `editor:toggle-highlight` → `editor.toggle-highlight`; `editor:toggle-code` → `editor.toggle-code`; `editor:insert-link` → `editor.insert-link`;
   `editor:toggle-bullet-list` → `editor.toggle-bullet-list`; `editor:toggle-numbered-list` → `editor.toggle-numbered-list`; `editor:toggle-checklist-status` → `editor.toggle-task`; `editor:toggle-blockquote` → `editor.toggle-quote`; `editor:swap-line-up` → `editor.move-line-up`; `editor:swap-line-down` → `editor.move-line-down`;
   `editor:indent-list` → `editor.indent-list`; `editor:unindent-list` → `editor.outdent-list`; `editor:open-search` → `editor.find`; `editor:open-search-replace` → `editor.replace`; `editor:save-file` → `note.save`; `markdown:toggle-preview` → `editor.toggle-reading-view`;
   `switcher:open` → `app.open-quick-switcher`; `command-palette:open` → `app.open-command-palette`; `file-explorer:new-file` → `note.create-note`; `workspace:close` → `workspace.close-tab`; `workspace:next-tab` → `workspace.next-tab`; `workspace:previous-tab` → `workspace.previous-tab`;
   `app:go-back` → `workspace.go-back`; `app:go-forward` → `workspace.go-forward`; `workspace:split-vertical` → `workspace.split-right`; `workspace:split-horizontal` → `workspace.split-down`; `app:open-settings` → `app.open-settings`.
   Each entry → shortcut string `Ctrl+Alt+Shift+Meta+<Key>` in that modifier order; Obsidian `Mod` and `Ctrl` → `Ctrl`; `Meta` → `Meta`; `Alt`, `Shift` unchanged. Key: a single character → upper-case; `ArrowUp/ArrowDown/ArrowLeft/ArrowRight` → `Up/Down/Left/Right`; `Enter, Tab, Escape, Backspace, Delete, Home, End, PageUp, PageDown` unchanged; `' '` → `Space`; `F1`–`F12` unchanged; anything else drops that one shortcut. An empty list (explicitly unbound in Obsidian) stays `[]`. The result is written as `{ "<id>": ["Ctrl+B"] }`. (The shortcut string grammar is defined in step 01.14; this function only produces strings.)
6. `vault_gate.dart`: `VaultGate extends ConsumerStatefulWidget`: on first build, if `appSettings.lastVaultPath` is non-null, exists on disk and (Android) `storagePermissionService.status()` is `granted` or `notNeeded` or the path is inside the app-private folder → `VaultOpener.open(lastVaultPath)` showing a centered `CircularProgressIndicator`; on failure fall back to the picker and show the error. Build: `vaultSessionProvider == null` → `VaultPickerScreen`, else `WorkspaceShell` (created in 01.13; until then show `Scaffold(body: Center(child: Text(session.name)))` — replace in 01.13).
7. `vault_picker_screen.dart`: `Scaffold` with a centered `ConstrainedBox(maxWidth: 560)`; contents: logo icon + `welcomeTitle` / `welcomeSubtitle` (keep the Phase 0 strings), the buttons (keys `vaultPicker.open`, `vaultPicker.create`, and on Android `vaultPicker.createPrivate`), then the "Recent vaults" list (keys `vaultPicker.recent.<index>`).
   - **Open vault**: `FilePicker.platform.getDirectoryPath()`; `null` → nothing. On Android first run the permission flow (below), then `VaultOpener.open(path)`.
   - **Create new vault**: `CreateVaultDialog` (name `TextField` key `createVault.name`, "Location" row showing the chosen parent folder with a "Choose…" button using `getDirectoryPath()`, default location: Windows `Documents` (`Platform.environment['USERPROFILE']\Documents`), Android: none until chosen); validation via `VaultPath.checkName` (messages `createVaultNameInvalid`, `createVaultNameEmpty`); "Create" → `createVault` → `VaultOpener.open`.
   - **Android: "Create vault in app storage"** (`vaultPicker.createPrivate`, shown only when permission is not granted): `getApplicationDocumentsDirectory()/Tephra Vaults/<name>` created via the same dialog without the location row; opens with `isAppPrivate: true`. Show the hint `vaultPrivateHint`: "Notes in app storage are only visible to Tephra and are removed if you uninstall the app."
   - Recent vaults: each tile shows name, path, "last opened <relative>" (just the date `yMMMd` via `intl`); tap opens; a "⋮" menu has "Remove from list" (`removeRecentVault`; never deletes files). A path that no longer exists is shown with `vaultRecentMissing` and cannot be opened (menu only offers remove).
   - Errors from `VaultOpenException`/`VaultCreateException`/`VaultTooNewException` show an `AlertDialog` with the localised text (keys `vaultErrorMissing`, `vaultErrorNotAFolder`, `vaultErrorNoAccess`, `vaultErrorTooNew`, `vaultErrorNotEmpty`).
   - After an import that found `.obsidian`, show a one-time `SnackBar` `vaultImportedFromObsidian` ("Imported your Obsidian settings (read-only copy).").
8. **Android permission flow** — `storage_access_screen.dart`: a full-screen explanation page (pushed before opening/creating a shared-storage vault when `status != granted` and `status != notNeeded`):
   title `storageAccessTitle` ("Allow access to your files"), body `storageAccessBody` ("Tephra stores notes as plain Markdown files in a folder you choose, so other apps like Obsidian can open the same files. Android calls this “All files access”. Tephra only reads and writes inside the vault folder you pick."),
   three buttons: **Allow access** (key `storageAccess.allow`: `await service.request()`; for `permanentlyDenied` call `service.openSystemSettings()` instead; when the app resumes — use `AppLifecycleListener(onResume:)` — re-check `status()` and pop with `true` if granted), **Use app storage instead** (key `storageAccess.private`: pops with the string `'private'`), **Not now** (pops `false`). The picker acts on the result: `true` → continue opening; `'private'` → app-private create dialog; `false` → stay.
   Windows: the screen is never shown (`notNeeded`).
9. `app.dart`: `home: const VaultGate()`; `themeMode` from `appSettings.themeMode`. Remove `welcome_*` ARB keys that are no longer used except `welcomeTitle`, `welcomeSubtitle`, `welcomeOpenVault`, `welcomeCreateVault` (reused by the picker; keep their names). Delete `app/lib/welcome/` and its tests; rewrite `app/test/app_test.dart` (see tests).
10. l10n keys (add with `@key` descriptions where ambiguous): `vaultPickerRecent`, `vaultPickerCreatePrivate`, `vaultRecentMissing`, `vaultRecentRemove`, `vaultPrivateHint`, `createVaultTitle`, `createVaultName`, `createVaultLocation`, `createVaultChoose`, `createVaultCreate`, `createVaultNameEmpty`, `createVaultNameInvalid`, `vaultErrorMissing`, `vaultErrorNotAFolder`, `vaultErrorNoAccess`, `vaultErrorTooNew`, `vaultErrorNotEmpty`, `vaultImportedFromObsidian`, `storageAccessTitle`, `storageAccessBody`, `storageAccessAllow`, `storageAccessPrivate`, `storageAccessNotNow`, `commonCancel`, `commonOk`, `commonDelete`, `commonRename`, `commonCreate`, `commonClose`.

**Tests**
- `vault_metadata_test.dart` (memory fs, `ManualClock(2026-10-11 09:30 UTC)`): missing → file created with a UUID, `createdAt == '2026-10-11T09:30:00.000Z'`, `formatVersion == 1`; second call returns the same id and writes nothing (`writeCount` unchanged); file with `{"foo":1}` → id added and `foo` kept; `{"id":"x","formatVersion":2}` → throws `VaultTooNewException`; invalid JSON → new metadata and a `.bad-` copy exists.
- `vault_creator_test.dart` (real temp dir): creates folder; name `a:b` → `VaultCreateException('invalid')`; existing non-empty folder → `not-empty`; existing empty folder → ok; existing folder containing only `.tephra` → ok.
- `obsidian_importer_test.dart` (memory fs, fixture JSON strings inline): full import fills every mapped field (attachment `Attachments`, `newFileLocation: folder` + `Inbox`, `trashOption: local` → `vaultTrash`, `defaultViewMode: preview` → `reading`, daily notes `{folder: Daily, format: YYYY-MM-DD, template: T}`); no `.obsidian` → settings file created with `importedFromObsidian: false` and nothing else; `app.json` without `defaultViewMode` → `source`; existing `.tephra/bookmarks.json` is not overwritten; `bookmarks.json` bytes copied identically; **no write ever happens under `.obsidian/`** (assert `fs.writeLog` has no entry starting with `.obsidian`); invalid `app.json` → skipped, other files still imported.
- `obsidian_hotkeys_test.dart`: the example `{"editor:toggle-bold":[{"modifiers":["Mod"],"key":"b"}]}` → `{'editor.toggle-bold': ['Ctrl+B']}`; modifiers `["Mod","Shift"]`, key `ArrowUp` → `Ctrl+Shift+Up`; `["Alt","Mod"]` → `Ctrl+Alt+<key>`; unknown command skipped; unknown key dropped; `[]` stays `[]`; two shortcuts for one command both kept.
- `vault_opener_test.dart` (real temp dir + provider container with `FixedAppSettings`): opens a folder, session set, `.tephra/vault.json` exists, recent list has the vault first; opening a missing folder throws `VaultOpenException('missing')`; opening a file path → `not-a-folder`; opening twice keeps the same `vaultId`; `lastVaultPath` updated; hooks awaited (`vaultOpenedHooksProvider` overridden with a recording hook).
- `vault_picker_screen_test.dart`: shows both buttons and recents; missing recent shows `vaultRecentMissing` and tapping does nothing; remove from list updates; on a fake `StoragePermissionService` (`denied`) the Android-only button appears when `Platform` check is replaced by an injected `bool isAndroid` parameter of the screen (`VaultPickerScreen({this.isAndroid})` defaulting to the real check; tests pass `true`); `CreateVaultDialog` validates names.
- `storage_access_screen_test.dart`: three buttons exist; "Allow access" calls the fake's `request`; on resume with `granted` pops `true`; "Use app storage" pops `'private'`; "Not now" pops `false`.
- `app_test.dart`: pumping `TephraApp` with no session shows the picker (`find.byKey(Key('vaultPicker.open'))`); with `ThemeMode` from settings `dark` the brightness is dark.

**Verify** `cd app; flutter test; cd ..` + standard checks; `flutter run -d windows`: pick `test_vaults/syntax` → picker closes (placeholder session screen shows the vault name), `.tephra/vault.json` exists in the vault (then **delete the `.tephra` folder from `test_vaults/syntax` and restore with `git checkout -- test_vaults`** — fixture vaults must stay byte-exact; use a copy of the vault for manual runs: `Copy-Item -Recurse test_vaults\syntax $env:TEMP\syntax_copy`). Commit `phase 01.12: add vault picker, creation, permission flow and Obsidian import`.

**Pitfalls**
- `.tephra/` folders created inside `test_vaults/` by manual runs must never be committed: add the line `test_vaults/**/.tephra/` to `.gitignore` in this step (the generic fixtures contain no `.tephra`).
- Also create `app/lib/vault/folder_picker.dart` in this step: `Future<String?> pickFolderWithAccess(BuildContext context, WidgetRef ref)` = (Android: run the explanation screen of item 8 when `status()` is not `granted`/`notNeeded`) + `FilePicker.platform.getDirectoryPath()`; the picker screen uses it for "Open vault" and "Create new vault → Choose…"; Phase 5 reuses it. Test: with a fake permission service `denied`, the function returns `null` when the user answers "Not now" and does not call `getDirectoryPath`.
- Never create a vault inside a folder the user did not choose; never write to `.obsidian`.
- `getDirectoryPath()` on Android returns a real path only for primary shared storage; if it returns a `content://` URI or `null`, show `vaultErrorNoAccess` (SAF is deferred).
- `AppLifecycleListener.onResume` fires also on first build; guard with a `_requested` flag.

---

### 01.13 Workspace: adaptive shell, tabs, history, splits, view registry

**Purpose** The layout every feature lives in (conventions §5.8): desktop (≥ 840 dp) with sidebar, tabs, splits, status bar; phone with drawers; per-tab back/forward history; the registry that maps file types to tab views.

**Files** (under `app/lib/workspace/`)
- `view_kind.dart`, `tab_content.dart`, `view_registry.dart`, `workspace_models.dart`, `workspace_notifier.dart`, `workspace_persistence.dart`, `providers.dart`, `open_file.dart`, `sidebar_registry.dart`, `status_bar_registry.dart`, `tab_status.dart`
- `workspace_shell.dart`, `desktop_layout.dart`, `phone_layout.dart`, `tab_bar_view.dart`, `pane_view.dart`, `split_divider.dart`, `status_bar.dart`, `empty_workspace_view.dart`, `note_view.dart`, `unsupported_file_view.dart`
- modify `vault/vault_gate.dart` (show `WorkspaceShell`), `vault/providers.dart` (`vaultOpenedHooksProvider` body)
- tests: `app/test/workspace/` (`tab_content_test.dart`, `view_registry_test.dart`, `workspace_notifier_test.dart`, `workspace_persistence_test.dart`, `workspace_shell_test.dart`, `tab_bar_test.dart`)

**Implementation**
1. `view_kind.dart`:
   ```dart
   enum ViewKind { markdown, canvas, base, pdf, image, audio, video, unsupported }
   const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};
   const audioExtensions = {'mp3', 'wav', 'm4a', 'ogg', 'flac', '3gp', 'aac', 'opus'};
   const videoExtensions = {'mp4', 'webm', 'mov', 'mkv', 'ogv'};
   ViewKind viewKindFor(VaultPath path); // 'md' → markdown, 'canvas' → canvas, 'base' → base, 'pdf' → pdf, the sets above, else unsupported
   ```
2. `tab_content.dart` (same shape Phase 6 extends):
   ```dart
   sealed class TabContent { const TabContent(); Map<String, Object?> toJson(); static TabContent? fromJson(Map<String, Object?> j); }
   final class FileTabContent extends TabContent { const FileTabContent(this.path, {this.subpath}); final VaultPath path; final String? subpath; /* ==, hashCode */ }
   ```
   JSON `{"kind":"file","path":"A/B.md","subpath":"#page=3"}`; `fromJson` also accepts an entry **without** `kind` that has a `path`; an invalid path (`VaultPath.tryParse == null`) or unknown `kind` → returns `null` (the caller skips the tab and logs `warning`).
3. `workspace_models.dart`:
   ```dart
   enum ViewMode { reading, source }            // Phase 2 adds livePreview; JSON names 'reading' / 'source'
   enum SplitAxis { horizontal, vertical }      // horizontal = panes side by side
   final class TabState { const TabState({required this.id, required this.history, required this.historyIndex, required this.mode});
     final String id; final List<TabContent> history; final int historyIndex; final ViewMode mode;
     TabContent get content => history[historyIndex]; bool get canGoBack => historyIndex > 0; bool get canGoForward => historyIndex < history.length - 1; copyWith, toJson, fromJson }
   final class PaneState { const PaneState({required this.id, required this.tabs, required this.activeIndex}); ... }
   final class WorkspaceState { const WorkspaceState({this.panes = const [], this.axis = SplitAxis.horizontal, this.focusedPane = 0, this.splitRatio = 0.5, this.leftSidebarVisible = true, this.leftSidebarWidth = 280, this.rightSidebarVisible = true, this.rightSidebarWidth = 300});
     TabState? get focusedTab; ... }
   ```
   History max length 100 entries (oldest dropped). Ids: `tab-<n>` / `pane-<n>` from a counter seeded with `DateTime.now().microsecondsSinceEpoch` hash (unique within a session; ids are regenerated on restore).
4. `workspace_notifier.dart` — `WorkspaceNotifier extends Notifier<WorkspaceState>`; every method updates state synchronously and then schedules persistence (500 ms debounce, step 6). Methods (exact names; Phase 2/6 call them):
   - `void openPath(VaultPath path, {bool newTab = false, bool background = false, String? subpath})` → `openContent(FileTabContent(path, subpath: subpath), newTab: newTab, background: background)`.
   - `void openContent(TabContent content, {bool newTab = false, bool background = false})`: ensure at least one pane exists (create `pane-1` when none). Let `pane` = the focused pane.
     If `newTab == false`: (a) if a tab in `pane` has `content == this content` → activate it; (b) else if `pane` has an active tab → **navigate**: if its current content equals the target do nothing; otherwise truncate forward history, append, `historyIndex = last`, trim to 100; (c) else create a tab.
     If `newTab == true` → create a tab after the active one in the focused pane and activate it (unless `background`: add it but keep the active tab). New tabs start in `ViewMode` from `vaultSettings.defaultViewMode`. Update `recentFilesProvider` (below) for `FileTabContent`.
   - `void closeTab(String paneId, String tabId)`: remove; activeIndex = the neighbour to the right, else left; if the pane becomes empty and there are 2 panes → remove the pane (focus the other), if it is the only pane keep it empty.
   - `void activateTab(String paneId, String tabId)`, `void focusPane(String paneId)`, `void moveTab(String paneId, int from, int to)` (reorder; `to` is the index after removal), `void nextTab()`, `void previousTab()` (wrap around within the focused pane), `void goBack()`, `void goForward()` (focused tab; no-op at the ends),
     `void setMode(String tabId, ViewMode mode)`, `void toggleMode()` (focused tab, `reading ↔ source`), `void splitFocused(SplitAxis axis)` (only when there is one pane: new pane with a **copy** of the active tab (new id, same history position); focus the new pane; with two panes: just change `axis`), `void closePane(String paneId)` (merges its tabs into the other pane's end), `void setSplitRatio(double r)` (clamp 0.2–0.8), `void toggleLeftSidebar()`, `void toggleRightSidebar()`, `void setLeftSidebarWidth(double w)` (clamp 180–480), `void setRightSidebarWidth(double w)` (clamp 200–520).
   - `void retargetPath(VaultPath from, VaultPath to)`: in every history entry of every tab: a `FileTabContent` whose path equals `from` → `to` (keeping `subpath`); a path **within** `from` (folder move) → `to` joined with the remainder.
   - `void removePath(VaultPath path)` (a note or folder was deleted): drop every history entry equal to or within `path`; adjust `historyIndex` (move to the nearest remaining entry, preferring the previous one); a tab whose history becomes empty is closed.
   - `Future<void> restore()`: loads `.tephra/workspace.json` for `deviceId` (step 6), keeps only tabs whose file still exists (`fs.stat`), and sets the state; if the result has no panes, state stays empty.
5. `providers.dart`:
   | Provider | Declaration |
   |---|---|
   | `workspaceProvider` | `NotifierProvider<WorkspaceNotifier, WorkspaceState>` — tabs/panes/layout state |
   | `activeNotePathProvider` | `Provider<VaultPath?>`: the path of the focused tab's current `FileTabContent` (`null` for no tab or non-file content) |
   | `recentFilesProvider` | `NotifierProvider<RecentFilesNotifier, List<VaultPath>>` — most recent first, max 30, updated by `openContent`, persisted in `workspace.json`, restored on open |
   | `viewRegistryProvider` | `Provider<ViewRegistry>` (below) |
   | `sidebarRegistryProvider` | `NotifierProvider<SidebarRegistry, List<SidebarPanelSpec>>` |
   | `statusBarRegistryProvider` | `NotifierProvider<StatusBarRegistry, List<StatusBarItemSpec>>` |
   | `tabDirtyProvider` | `Provider.family<bool, VaultPath>` in `tab_status.dart`; for now always `false` (step 01.20 changes its body to read the live document state) |
   `open_file.dart`: `void openFile(WidgetRef ref, VaultPath path, {String? subpath, bool newTab = false}) => ref.read(workspaceProvider.notifier).openPath(path, subpath: subpath, newTab: newTab);` — **all** "open a file" call sites use this function (Phase 6 relies on it).
6. `workspace_persistence.dart`: file `.tephra/workspace.json`, shape `{ "<deviceId>": { "panes": [ { "tabs": [ {"history": [<TabContent json>…], "index": 2, "mode": "reading"} ], "active": 0 } ], "axis": "horizontal", "focused": 0, "splitRatio": 0.5, "leftSidebar": {"visible": true, "width": 280}, "rightSidebar": {"visible": true, "width": 300}, "recent": ["A.md"] } }` — other devices' entries are never touched (`TephraJsonStore.update`). Save via a 500 ms debounced `Timer` (also flushed on `dispose` of the notifier and on app pause, step 01.20). `vaultOpenedHooksProvider` body: `(ref) => [(ref) => ref.read(workspaceProvider.notifier).restore()]`.
7. `view_registry.dart`:
   ```dart
   typedef TabViewBuilder = Widget Function(BuildContext context, WidgetRef ref, TabContent content, String tabId);
   final class ViewRegistration { const ViewRegistration({required this.id, required this.extensions, required this.builder, this.title, required this.icon}); final String id; final Set<String> extensions; final TabViewBuilder builder; final String Function(TabContent, AppLocalizations)? title; final IconData icon; }
   final class ViewRegistry {
     void register(ViewRegistration r);                       // later registrations for the same extension replace earlier ones
     ViewRegistration? registrationFor(TabContent content);   // by file extension of a FileTabContent
     Widget build(BuildContext context, WidgetRef ref, TabContent content, String tabId);   // no registration → UnsupportedFileView
     String titleFor(TabContent content, AppLocalizations l10n);   // md → stem; other files → name with extension
     IconData iconFor(TabContent content);
   }
   final viewRegistryProvider = Provider<ViewRegistry>((ref) { final r = ViewRegistry(); r.register(markdownRegistration); return r; });
   ```
   `markdownRegistration`: extensions `{'md'}`, builder → `NoteView(path:, subpath:, tabId:)`, icon `Icons.description_outlined`. Later phases register `canvas`, `base`, `pdf`, images, audio/video, graph by extending the provider body (or calling `register` in their own provider).
8. `sidebar_registry.dart`: `SidebarSide { left, right }`; `final class SidebarPanelSpec { const SidebarPanelSpec({required this.id, required this.side, required this.label /* String Function(AppLocalizations) */, required this.icon, required this.builder /* Widget Function(BuildContext, WidgetRef) */, this.order = 0}); }`;
   `SidebarRegistry extends Notifier<List<SidebarPanelSpec>>` with `register(spec)` (replaces same id) and `panelsFor(SidebarSide)` sorted by `order`. The explorer registers itself on the **left** in step 01.17; Phase 2 registers backlinks/outline/tags on the **right**. The right sidebar widget is shown only when it has at least one panel; with several, a tab strip of icons selects the active one.
   `status_bar_registry.dart`: `StatusBarItemSpec { id, alignment (left/right), builder (Widget Function(BuildContext, WidgetRef)), order }`, `StatusBarRegistry` with `register`.
9. Widgets
   - `workspace_shell.dart`: `WorkspaceShell` decides with `MediaQuery.sizeOf(context).width >= 840` (conventions §5.8): `DesktopLayout` else `PhoneLayout`. Wrapped in `HotkeyHost` (created in 01.14; until then omit) and a `FocusScope`.
   - `desktop_layout.dart`: `Row`: left sidebar (width from state, collapsible; contains the registered left panels — one panel directly, several as an icon strip), draggable 6 dp divider, centre column (`Expanded`): panes + status bar below; right sidebar (only if panels registered). Dividers: `MouseRegion(cursor: SystemMouseCursors.resizeColumn)` + `GestureDetector.onHorizontalDragUpdate` adjusting widths via the notifier.
   - `pane_view.dart`: a pane = `Column(TabBarView, Expanded(active tab content))`; content built with `viewRegistry.build(...)`, each wrapped in `KeyedSubtree(key: ValueKey(tab.id))` and an `IndexedStack`-free approach: **only the active tab is built**. Tapping/pointer-down inside a pane calls `focusPane`. The focused pane shows a 2 px primary-colour top border; with one pane no border.
   - `tab_bar_view.dart` (desktop only): height 40; leading Back / Forward `IconButton`s (32 dp on desktop, the 48 dp rule applies to the phone layout only; disabled when `!canGoBack/Forward`; tooltips `workspaceBack`, `workspaceForward`); a horizontally scrolling `ReorderableListView.builder(scrollDirection: Axis.horizontal, buildDefaultDragHandles: false)` of `_TabChip`s: icon, title (`viewRegistry.titleFor`, ellipsised, max 180 dp), a dirty dot when `tabDirtyProvider(path)`, close `IconButton` (x). Interactions: left click activates; **middle click** closes (`Listener` on `onPointerDown` with `buttons == kMiddleMouseButton`); mouse drag reorders via `ReorderableDragStartListener`; right-click shows a menu: Close, Close others, Split right, Split down. Keyboard: `Ctrl+Tab` etc. come from commands (01.14).
   - `split_divider.dart`: a 6 dp divider between two panes (cursor `resizeColumn`/`resizeRow`, double-click resets to 0.5) calling `setSplitRatio`.
   - `status_bar.dart` (desktop only, 24 dp): left items then a spacer then right items from `statusBarRegistryProvider`; built-in items registered by the shell's initState: left: the active note's path; right: line/column and word count are added by the editor/reading views in later steps through the registry. (Phase 2 registers `IndexStatusItem`.)
   - `phone_layout.dart`: `Scaffold` with `AppBar` (leading menu `IconButton` opening the drawer, key `phone.menu`; title = note title; actions: Back, Forward, reading/source toggle (`editor.toggle-reading-view`), "⋮" overflow with command palette, quick switcher, settings), `drawer` = left panels (explorer), `endDrawer` = right panels (only when registered), body = the focused tab's content; `PopScope(canPop: !canGoBack, onPopInvokedWithResult: (didPop, _) { if (!didPop) goBack(); })` — Android's system Back navigates the tab history first, and exits only when history is exhausted. No tab bar on phone. `bottomNavigationBar` slot reserved for the keyboard toolbar (01.21).
   - `empty_workspace_view.dart`: centered icon and text `workspaceEmptyTitle` ("No note open") with two buttons: "Open quick switcher" (`app.open-quick-switcher`, key `empty.switcher`) and "Create new note" (`note.create-note`). (Commands exist from 01.14; until then the buttons call a TODO-free stub: render them only when `commandRegistryProvider` is available — step 01.14 completes the wiring; in this step show only the text.)
   - `note_view.dart`: `NoteView({path, subpath, tabId})`: this step: reads `fs.readText(path)` (FutureProvider.family keyed by path and `vaultRevisionProvider`) and shows the text in a `SelectableText` inside a scroll view, plus error states (`FileNotFoundException` → `noteMissing` message with a "Close tab" button; malformed → banner `noteMalformedBanner`). Steps 01.16/01.18 replace the body with reading/editor views — keep the class name and constructor.
   - `unsupported_file_view.dart`: icon, file name, size, button `openWithSystemApp` (Windows: `launchUrl(Uri.file(absPath))` from `url_launcher`; Android: the button is hidden and a text `unsupportedFileAndroid` is shown).
10. l10n keys: `workspaceBack`, `workspaceForward`, `workspaceEmptyTitle`, `tabClose`, `tabCloseOthers`, `tabSplitRight`, `tabSplitDown`, `noteMissing`, `noteMalformedBanner`, `unsupportedFileTitle`, `openWithSystemApp`, `unsupportedFileAndroid`, `sidebarExplorer`, `phoneMenu`, `modeReading`, `modeSource`, `commandToggleMode`.

**Tests**
- `tab_content_test.dart`: JSON round trip of `FileTabContent` with and without `subpath`; legacy `{"path":"A.md"}` → file; `{"kind":"bogus"}` → `null`; `{"kind":"file","path":"../x"}` → `null`; value equality.
- `view_registry_test.dart`: `viewKindFor` for `a.md`, `A.MD`, `x.canvas`, `x.base`, `doc.pdf`, `p.PNG`, `s.svg`, `song.mp3`, `clip.webm` (video), `file.xyz` (unsupported), `noext` (unsupported); `titleFor(a/Note.md)` = `Note`, `titleFor(img.png)` = `img.png`; unknown extension → `UnsupportedFileView` built; a later `register` for `md` replaces the builder.
- `workspace_notifier_test.dart` (container, memory fs): open A in empty workspace → 1 pane 1 tab; open B (no newTab) → same tab, history `[A,B]`, index 1; goBack → A, canGoForward; open C after goBack → history `[A,C]` (forward truncated); open A while tab shows C **and another tab already shows A** → that tab is activated; `newTab` creates a second tab and activates it; `background` keeps the old active tab; closeTab picks the right neighbour then the left; closing the last tab of the only pane leaves an empty pane; split → 2 panes with copied tab; closePane merges tabs; `moveTab(0, 2)` reorders; `nextTab`/`previousTab` wrap; `retargetPath('a.md','b.md')` updates history entries; `retargetPath('Folder','New')` updates `Folder/x.md` → `New/x.md`; `removePath('Folder')` removes entries and closes empty tabs; history capped at 100 (open 120 distinct notes in one tab → length 100, newest kept); `setSplitRatio(0.05)` → 0.2; default mode from settings (`defaultViewMode: source` → new tab `source`); `recentFilesProvider` ordering and cap 30; `activeNotePathProvider` follows the focused tab.
- `workspace_persistence_test.dart`: save → JSON has the device id key and keeps another device's entry untouched; restore drops missing files and keeps order/mode/index; invalid file → empty workspace, no throw; debounce: three rapid changes produce one write (`fs.writeCount` delta 1 after pumping 600 ms).
- `workspace_shell_test.dart`: 1200 dp wide → tab bar and status bar present (`find.byKey(Key('desktop.tabbar'))`), no `AppBar`; 400 dp → `AppBar` present, no tab bar; 839 dp → phone, 840 dp → desktop; Android back (`tester.binding.handlePopRoute()`) with history `[A,B]` goes to `A`; with a single history entry the pop is not consumed (`canPop`).
- `tab_bar_test.dart`: tab chips show stems; middle-click closes (`TestPointer` with `kMiddleMouseButton`); dirty dot appears when `tabDirtyProvider` is overridden to `true`; back/forward buttons enable/disable.

**Verify** `cd app; flutter test test/workspace; cd ..`; `flutter run -d windows` with a **copy** of `test_vaults/syntax` (see step 01.12's note): the placeholder shows; resize the window across 840 dp and confirm the layout flips without losing the open tab. Commit `phase 01.13: add adaptive workspace, tabs, history and view registry`.

**Pitfalls**
- Build only the active tab of each pane (a hundred open tabs must not build a hundred editors).
- Never decide the layout with `Platform`; width only (conventions §5.8).
- `goBack` must not create a new history entry; only navigation does.
- Phase 2 (`LinkRenameService`) calls `retargetPath` after a folder move — it must handle both exact and prefix matches (tested above).

---

### 01.14 Commands, palette, quick switcher, hotkeys, settings screen

**Purpose** Every user action is a command (conventions §7.8); palette, hotkeys and the phone toolbar read the registry.

**Files** (under `app/lib/commands/` unless noted)
- `tephra_command.dart`, `command_registry.dart`, `shortcut_codec.dart`, `fuzzy_matcher.dart`, `providers.dart`, `builtin_commands.dart`, `hotkey_store.dart`, `hotkey_conflicts.dart`, `hotkey_host.dart`
- `command_palette.dart`, `quick_switcher.dart`, `quick_switcher_items.dart`
- `app/lib/vault/note_creator.dart`, `app/lib/vault/new_note_location.dart`
- `app/lib/settings/settings_screen.dart`, `app/lib/settings/hotkeys_screen.dart`, `app/lib/settings/shortcut_recorder_dialog.dart`
- modify `workspace/workspace_shell.dart` (wrap in `HotkeyHost`), `workspace/empty_workspace_view.dart` (buttons)
- tests: `app/test/commands/` (`shortcut_codec_test.dart`, `fuzzy_matcher_test.dart`, `command_registry_test.dart`, `hotkey_conflicts_test.dart`, `hotkey_store_test.dart`, `command_palette_test.dart`, `quick_switcher_test.dart`, `hotkey_host_test.dart`), `app/test/vault/note_creator_test.dart`, `app/test/settings/hotkeys_screen_test.dart`, `app/test/settings/settings_screen_test.dart`

**Implementation**
1. `tephra_command.dart`: `TephraCommand` **exactly** as conventions §7.8 (fields `id, label, icon, defaultShortcuts, run, isAvailable, showInPalette, showInMobileToolbar`).
2. `command_registry.dart`:
   ```dart
   final class CommandRegistry {
     void register(TephraCommand command);          // throws StateError on a duplicate id
     TephraCommand? byId(String id);
     List<TephraCommand> get all;                   // registration order
     /// canonical shortcut string → command id, for the effective shortcuts (user overrides replace defaults per command; an override of [] unbinds the command).
     /// When two commands share a shortcut the one registered first wins (the conflict is shown in the hotkey screen).
     Map<String, String> shortcutsMap(Map<String, List<SingleActivator>> overrides);
     List<SingleActivator> effectiveShortcuts(String id, Map<String, List<SingleActivator>> overrides);
   }
   ```
   `providers.dart`: `commandRegistryProvider = Provider<CommandRegistry>((ref) { final r = CommandRegistry(); registerBuiltinCommands(r); /* later steps add: registerExplorerCommands(r); registerEditorCommands(r); */ return r; })`; `hotkeyOverridesProvider = NotifierProvider<HotkeyOverridesNotifier, Map<String, List<SingleActivator>>>` (loaded from `.tephra/hotkeys.json` when the session changes, written back on change); `recentCommandsProvider = Provider<List<String>>` reading `appSettings.recentCommands`.
3. `shortcut_codec.dart` — the string grammar `Ctrl+Alt+Shift+Meta+<Key>` (modifiers in exactly that order, `+` separated; `Ctrl` is `control: true`, `Meta` is `meta: true`; case-insensitive on read; `Mod` read as `Ctrl`):
   `SingleActivator? parseShortcut(String s)` (null if invalid) and `String formatShortcut(SingleActivator a)`. Key names (both directions): letters `A`–`Z`, digits `0`–`9`, `F1`–`F12`, `Enter, Tab, Escape, Space, Backspace, Delete, Insert, Home, End, PageUp, PageDown, Up, Down, Left, Right`, and the punctuation keys `,` `.` `/` `\` `;` `'` `[` `]` `-` `=` `` ` `` written as the character itself. A shortcut needs exactly one key and may have any modifiers. Canonical string = `formatShortcut(parseShortcut(s))`.
4. `fuzzy_matcher.dart`:
   ```dart
   abstract final class FuzzyMatcher {
     /// null = no match. Case-insensitive. Higher is better.
     static int? score(String query, String candidate);
     /// Character ranges of the greedy match (adjacent ranges merged) for bold rendering.
     static List<(int, int)> matchRanges(String query, String candidate);
   }
   ```
   Algorithm: `q` = trimmed lower-cased query, `c` = lower-cased candidate; `q` empty → `0`. Greedy left-to-right subsequence; for every matched index `ci`: `+10`; `+15` if `ci == 0` or `c[ci-1]` is a separator (space, `-`, `_`, `/`, `.`, `(`, `[`, `:`); `+8` if `ci == previousMatchIndex + 1`. If some query character is not found → `null`. Then `score -= min(20, firstMatchIndex)`; `score -= (c.length - q.length) ~/ 4`; `if (c == q) score += 100 else if (c.startsWith(q)) score += 50`.
   Required values: `score('abc','abc') = 161`; `score('abc','a-b-c') = 75`; `score('abc','xabc') = 45`; `score('xyz','abc') = null`; `score('','abc') = 0`; `matchRanges('mtg','meeting') = [(0,1),(3,4),(6,7)]`; `matchRanges('no','notes') = [(0,2)]`.
5. **Initial command list** (ids fixed; labels are l10n keys named `command<PascalId>`, English label shown; default shortcuts use Ctrl on Windows and the same activators on Android hardware keyboards). `Reg` = the step that registers it:

   | id | Label (English) | Default shortcut(s) | Reg |
   |---|---|---|---|
   | `app.open-quick-switcher` | Open quick switcher | `Ctrl+O` | 01.14 |
   | `app.open-command-palette` | Open command palette | `Ctrl+P` | 01.14 |
   | `app.open-settings` | Open settings | `Ctrl+,` | 01.14 |
   | `app.open-vault` | Open another vault… | — | 01.14 |
   | `app.toggle-left-sidebar` | Toggle left sidebar | `Ctrl+\` | 01.14 |
   | `workspace.close-tab` | Close tab | `Ctrl+W` | 01.14 |
   | `workspace.next-tab` | Next tab | `Ctrl+Tab` | 01.14 |
   | `workspace.previous-tab` | Previous tab | `Ctrl+Shift+Tab` | 01.14 |
   | `workspace.go-back` | Navigate back | `Alt+Left` | 01.14 |
   | `workspace.go-forward` | Navigate forward | `Alt+Right` | 01.14 |
   | `workspace.split-right` | Split right | — | 01.14 |
   | `workspace.split-down` | Split down | — | 01.14 |
   | `workspace.close-pane` | Close split | — | 01.14 |
   | `editor.toggle-reading-view` | Toggle reading view | `Ctrl+E` | 01.14 |
   | `note.create-note` | Create new note | `Ctrl+N` | 01.14 (opens the new note in a new tab) |
   | `note.save` | Save current note | `Ctrl+S` | 01.20 |
   | `note.rename-note` | Rename current note | `F2` | 01.17 |
   | `note.delete-note` | Delete current note | — | 01.17 |
   | `note.duplicate-note` | Duplicate current note | — | 01.17 |
   | `note.create-folder` | Create new folder | — | 01.17 |
   | `note.reveal-in-explorer` | Reveal in system explorer (Windows only) | — | 01.17 |
   | `explorer.collapse-all` | Collapse all folders | — | 01.17 |
   | `explorer.reveal-active-file` | Reveal active file in explorer | — | 01.17 |
   | `editor.toggle-bold` | Toggle bold | `Ctrl+B` | 01.19 |
   | `editor.toggle-italic` | Toggle italic | `Ctrl+I` | 01.19 |
   | `editor.toggle-strikethrough` | Toggle strikethrough | — | 01.19 |
   | `editor.toggle-highlight` | Toggle highlight | — | 01.19 |
   | `editor.toggle-code` | Toggle inline code | — | 01.19 |
   | `editor.insert-link` | Insert link | `Ctrl+K` | 01.19 |
   | `editor.toggle-bullet-list` | Toggle bullet list | — | 01.19 |
   | `editor.toggle-numbered-list` | Toggle numbered list | — | 01.19 |
   | `editor.toggle-task` | Toggle task checkbox | `Ctrl+Enter` | 01.19 |
   | `editor.toggle-quote` | Toggle quote | — | 01.19 |
   | `editor.cycle-heading` | Cycle heading level | — | 01.19 |
   | `editor.indent-list` | Indent | — (Tab is handled inside the editor) | 01.19 |
   | `editor.outdent-list` | Outdent | — (Shift+Tab inside the editor) | 01.19 |
   | `editor.undo` | Undo | `Ctrl+Z` | 01.19 |
   | `editor.redo` | Redo | `Ctrl+Y`, `Ctrl+Shift+Z` | 01.19 |
   | `editor.find` | Find in note | `Ctrl+F` | 01.19 |
   | `editor.replace` | Find and replace in note | `Ctrl+H` | 01.19 |
   | `editor.move-line-up` | Move line up | `Alt+Up` | 01.19 |
   | `editor.move-line-down` | Move line down | `Alt+Down` | 01.19 |
   | `editor.duplicate-line` | Duplicate line | `Ctrl+Shift+D` | 01.19 |
   | `editor.hide-keyboard` | Hide keyboard | — | 01.21 |
   | `editor.insert-attachment` | Insert attachment… | — | 01.21 |

   `isAvailable` rules: editor commands need an editor attached (`editorRegistry` has a controller for the active note, step 01.18 — until then `isAvailable` returns `false` for them, which is why they are registered in 01.19); `workspace.*` tab commands need ≥ 1 tab; `note.reveal-in-explorer` needs Windows and an active note; `editor.hide-keyboard` only when `MediaQuery.viewInsets.bottom > 0`.
   Declare `noteCreatorProvider = Provider<NoteCreator>((ref) => NoteCreator(ref))` in `app/lib/vault/providers.dart` and `phoneScaffoldKeyProvider` (a `Provider<GlobalKey<ScaffoldState>>` created once) in `app/lib/commands/providers.dart`. `builtin_commands.dart` registers the 01.14 rows: `app.open-quick-switcher` shows `QuickSwitcher` (`showQuickSwitcher(context)`), `app.open-command-palette` shows `CommandPalette`, `app.open-settings` pushes `SettingsScreen` (route name `/settings`), `app.open-vault` → `vaultSessionProvider.notifier.close()` (the gate shows the picker), `app.toggle-left-sidebar` → `toggleLeftSidebar` (on phone: opens the drawer via a `GlobalKey<ScaffoldState>` exposed as `phoneScaffoldKeyProvider`), the `workspace.*` commands call the notifier, `editor.toggle-reading-view` → `toggleMode()`, `note.create-note` → `ref.read(noteCreatorProvider).createUntitled(...)` then `openFile(newTab: true)` and (if the view mode is `source`) the editor autofocuses (01.18).
6. `hotkey_store.dart`: `HotkeyStore(VaultFileSystem fs)`: `Future<Map<String, List<SingleActivator>>> load()` (reads `.tephra/hotkeys.json`; invalid shortcut strings are skipped with a warning; a command id with `[]` means unbound) and `Future<void> save(Map<String, List<SingleActivator>> overrides)` (only changed ids are written; ids equal to the default are removed from the file).
   `hotkey_conflicts.dart`: `Map<String, List<String>> findHotkeyConflicts(CommandRegistry registry, Map<String, List<SingleActivator>> overrides)` → canonical shortcut → the ids (≥ 2) that use it; `List<String> conflictsFor(String shortcut, String exceptCommandId, ...)`.
7. `hotkey_host.dart`: `HotkeyHost extends ConsumerWidget` wrapping the shell with `CallbackShortcuts(bindings: {for (final e in shortcutsMap.entries) parseShortcut(e.key)!: () => _run(e.value)})`. `_run(id)`: `cmd = registry.byId(id)`; if `cmd.isAvailable?.call(ref) ?? true` → `cmd.run(ref, context)` and `appSettings.touchCommand(id)`; handled. A shortcut whose command is unavailable **does not consume the key event** (use `Shortcuts` + `Actions` with `Intent`s whose `Action.isEnabled` returns availability, so unavailable commands let the event bubble — e.g. `Ctrl+Z` in a text field). Implement with one `CommandIntent(String id)` class and `Actions({CommandIntent: CallbackAction/ Action with isEnabled})`.
8. `command_palette.dart`: `showCommandPalette(BuildContext context)` (desktop ≥ 840 dp: centered `Dialog` 560×480; narrower: full-screen dialog). `TextField` (autofocus, key `palette.query`), `ListView` of rows (key `palette.row.<id>`): label with matched ranges in bold (`FuzzyMatcher.matchRanges`), the effective shortcut(s) on the right as small chips (`formatShortcut`). Items: commands with `showInPalette && (isAvailable?.call(ref) ?? true)`. Empty query: `recentCommands` first (in order), then the rest sorted by label. Non-empty: by `FuzzyMatcher.score(query, label)` descending (null excluded), ties by label. Up/Down move the highlight (wraps), Enter runs it and closes (running **after** the dialog closed so commands that open dialogs work), Esc closes; tap runs. Row height 48 dp.
9. **Quick switcher (simple)** — `quick_switcher_items.dart`: `quickSwitcherItemsProvider = FutureProvider<List<SwitcherItem>>`: watches `vaultRevisionProvider`; `entries = await fs.list()`; items = every file whose path `isMarkdown` (`SwitcherItem { VaultPath path; String stem; String folder; String stemLower; String pathLower; }`); with the setting `switcherShowAttachments` absent in Phase 1 (notes only).
   `quick_switcher.dart`: `showQuickSwitcher(BuildContext context)`; same dialog sizing as the palette; `TextField` key `switcher.query`. Ranking per keystroke (synchronous, over the cached list): `score = max(FuzzyMatcher.score(q, stem), q.contains('/') ? (FuzzyMatcher.score(q, pathWithoutExtension) ?? -9999) - 20 : -9999)`; add `recentBoost = max(0, 50 - 5 × recentRank)` for the first 10 entries of `recentFilesProvider`; keep the top 50; ties: shorter path, then alphabetical (`compareTo`). Empty query → `recentFilesProvider` (max 50) then nothing else. Rows: stem (matched ranges bold) + folder in a lighter style. Keys: Up/Down move, **Enter** opens the highlighted note (`openFile`); **Enter with no results** or **Shift+Enter** creates a note named like the query; **Ctrl+Enter** opens in a new tab; Esc closes. Phone: tap opens; the last row `Create “<query>”` (key `switcher.create`) is shown when the query is non-empty and no stem equals it case-insensitively. Log `Logger('switcher').fine('rank ${sw.elapsedMilliseconds} ms')`.
   `note_creator.dart` — `NoteCreator(ref)`: `Future<VaultPath> createFromName(String name, {VaultPath? contextNote})`: trim; empty → `InvalidPathException`; if the name contains `/` it is a vault-relative path (folders created); else the folder comes from `resolveNewNoteFolder(settings, contextNote)` (`new_note_location.dart`: `root` → `VaultPath.root`, `current` → parent of `contextNote` (root if null), `folder` → `VaultPath(settings.newFileFolder)` falling back to root if empty/invalid); append `.md` unless the last segment already ends with `.md` (case-insensitive); validate with `VaultPath`; if the file exists → return it (caller opens it); else `fs.writeText(path, const TextDocument(text: ''))`, `vaultRevision.bump()`, return it.
   `Future<VaultPath> createUntitled({VaultPath? folder, VaultPath? contextNote})`: names `Untitled`, `Untitled 1`, `Untitled 2`, … (first free; `Untitled.md`, then `Untitled 1.md`) in the resolved folder.
10. `settings_screen.dart` (route name `/settings`, `SettingsScreen extends ConsumerWidget`; `ListView` of grouped tiles; works on phone and desktop): sections **Appearance** (theme mode dropdown `system/light/dark` → `appSettings`; font size slider 12–32 → `vaultSettings.fontSize`), **Editor** (switch `useTab`; `tabSize` dropdown 2/4/8; `readableLineLength` switch; default view mode dropdown), **Files** (attachment folder text field with helper text `settingsAttachmentFolderHelp` ("`/` = vault root, `./` = same folder as the note, `./attachments` = subfolder of the note's folder, or a folder name"); new-note location dropdown + folder text field; trash mode dropdown (hide `system` on Android); show hidden folders switch), **Hotkeys** (opens `HotkeysScreen`), **About** (app name, version from `package_info`-free constant: read `pubspec` version through `const String.fromEnvironment('TEPHRA_VERSION', defaultValue: '0.1.0')`). Every control writes through `vaultSettingsProvider.notifier.update` / `appSettingsProvider.notifier.update` immediately. Phase 7 replaces the screen and keeps the route name.
11. `hotkeys_screen.dart`: app bar "Hotkeys" with a search field (fuzzy over label and id); one row per command (`ListTile`): label, id (caption), the effective shortcuts as `InputChip`s (customised ones have a dot), conflict rows get an error-coloured icon with tooltip listing the other commands; row actions: "+" opens `ShortcutRecorderDialog` (`Focus` capturing `KeyDownEvent`; shows the live combo; ignores pure modifier presses; requires ≥ 1 modifier unless the key is `F1`–`F12`/`Escape`... `Escape` cancels the dialog instead), delete icon on a chip removes that shortcut, "Reset" restores the default. When the recorded shortcut conflicts with another command: dialog `hotkeyConflictTitle` ("Already used by {commands}") with **Replace** (remove it from the others), **Keep both**, **Cancel**. Every change saves through `HotkeyStore` and updates `hotkeyOverridesProvider` (HotkeyHost rebuilds immediately). A footer button "Reset all" (confirm) deletes `.tephra/hotkeys.json` overrides.
12. l10n: one key per command label (`command<PascalCaseId>` e.g. `commandAppOpenQuickSwitcher`), plus `palettePlaceholder`, `paletteNoResults`, `switcherPlaceholder`, `switcherCreate` (`Create “{name}”`), `switcherNoResults`, `settingsTitle`, `settingsAppearance`, `settingsEditor`, `settingsFiles`, `settingsHotkeys`, `settingsAbout`, `settingsTheme`, `settingsFontSize`, `settingsUseTab`, `settingsTabSize`, `settingsReadableLineLength`, `settingsDefaultViewMode`, `settingsAttachmentFolder`, `settingsAttachmentFolderHelp`, `settingsNewNoteLocation`, `settingsNewNoteFolder`, `settingsTrashMode`, `settingsShowHidden`, `hotkeysTitle`, `hotkeysSearch`, `hotkeysAdd`, `hotkeysReset`, `hotkeysResetAll`, `hotkeysPressKeys`, `hotkeyConflictTitle`, `hotkeyReplace`, `hotkeyKeepBoth`, `newNoteUntitled` (`Untitled`).

**Tests**
- `shortcut_codec_test.dart`: `parseShortcut('Ctrl+Shift+K')` → control+shift+`keyK`; `formatShortcut` reverses it; `parseShortcut('shift+ctrl+k')` → canonical `Ctrl+Shift+K`; `Mod+B` → `Ctrl+B`; `Ctrl+Tab`, `Alt+Left` → `Alt+Left`, `F2`, `Ctrl+,`, `Ctrl+\`, `Ctrl+Enter` round-trip; invalid (`Ctrl+`, `Ctrl+Shift`, `Ctrl+AB`, `Foo+K`, ``) → `null`; round trip for every key name in the grammar (loop).
- `fuzzy_matcher_test.dart`: the 7 required values above; ordering: `score('note','note') > score('note','notes') > score('note','a note') > score('note','n-o-t-e')`; case-insensitive; a query longer than the candidate → `null`; Bangla `score('বাং','বাংলা')` is non-null; scoring 10,000 random 20-char strings takes < 50 ms.
- `command_registry_test.dart`: duplicate id throws `StateError`; `all` keeps registration order; `shortcutsMap` with defaults; an override replaces the defaults of that command only; an override of `[]` unbinds; first-registered wins a conflict; `effectiveShortcuts` for an unknown id → `[]`.
- `hotkey_conflicts_test.dart`: two commands sharing `Ctrl+B` → one conflict entry listing both; an override resolving it → no conflict.
- `hotkey_store_test.dart`: load skips invalid strings; save writes only differing ids; default-equal ids are removed; unknown ids are preserved in the file; `[]` round-trips.
- `command_palette_test.dart` (1200 dp and 400 dp): lists commands; typing `bol` ranks `Toggle bold` first (register fake commands); Enter runs the highlighted command and closes; Esc closes; unavailable commands hidden; empty query shows recent commands first; shortcut chips shown.
- `quick_switcher_test.dart` (memory vault with 5 notes + 1 image): empty query lists recents; typing narrows; image not listed; Enter opens (workspace has the path); Ctrl+Enter new tab; no results + Enter creates `Query.md` in the new-note location and opens it; Shift+Enter with results creates; a path query `proj/pl` matches `Projects/Plan`; the `switcher.create` row on phone width; 10,000-item rank in < 50 ms (`Stopwatch`; print the value).
- `hotkey_host_test.dart`: pressing `Ctrl+P` in a pumped shell opens the palette (`sendKeyDownEvent` control + `P`); a shortcut whose command is unavailable is not handled (a `TextField` still receives `Ctrl+Z`); override changes take effect without restart.
- `note_creator_test.dart`: `createFromName('Idea')` → `Idea.md` in root; with `newFileLocation: folder`/`Inbox` → `Inbox/Idea.md` (folder created); `current` with context `A/B.md` → `A/Idea.md`; `'Projects/Plan'` → `Projects/Plan.md`; name with `.md` is not doubled; `'a:b'` → `InvalidPathException`; existing file returned without rewriting (`writeCount` unchanged); `createUntitled` ×3 → `Untitled.md`, `Untitled 1.md`, `Untitled 2.md`.
- `hotkeys_screen_test.dart`: rows listed; recording `Ctrl+Shift+K` for a command adds a chip and writes `.tephra/hotkeys.json`; recording an in-use shortcut shows the conflict dialog; Replace removes it from the other command; Reset restores defaults.
- `settings_screen_test.dart`: changing `tabSize` to 2 updates `vaultSettingsProvider` and writes `.tephra/settings.json`; theme dropdown updates `appSettings.themeMode`.

**Verify** `cd app; flutter test test/commands test/settings test/vault; cd ..`; `flutter run -d windows` (copy vault): Ctrl+P opens the palette, Ctrl+O the switcher; create a note from the switcher; hotkeys screen reachable from settings. Commit `phase 01.14: add command registry, palette, quick switcher, hotkeys and settings`.

**Pitfalls**
- Commands must **not** capture a `BuildContext` at registration time; `run` receives the live `ref`/`context`.
- The palette closes **before** running a command that shows another dialog (otherwise `showDialog` stacks under it).
- `Ctrl+Tab` may be swallowed by focus traversal; the `HotkeyHost` sits above the `FocusTraversalGroup` and the activator is matched first.
- Phase 2 replaces the switcher's data source and scoring (`FuzzyScorer`) but keeps `QuickSwitcher`, `showQuickSwitcher` and `quickSwitcherItemsProvider`'s role; do not couple the dialog to the list type beyond `SwitcherItem`.

---

### 01.15 Note documents (buffers) and the reading view: structure and block widgets

**Purpose** (a) `NoteDocument`: the single in-memory buffer of an open note with the exact text round-trip rule (conventions §6.2), shared by reading view, editor and task toggling; (b) the reading view's lazy block list and the block widgets for headings, paragraphs, lists, quotes, code, tables, rules, math, HTML and the footnote section.

**Files**
- `app/lib/editor/edit_operation.dart`
- `app/lib/vault/note_document.dart`, `app/lib/vault/note_document_store.dart`, modify `app/lib/vault/providers.dart`
- `app/lib/reading/reading_view.dart`, `reading_controller.dart`, `reading_scope.dart`, `reading_styles.dart`, `reading_blocks.dart`, `reading_code.dart`, `reading_table.dart`, `reading_footnotes.dart`, `block_lookup.dart`, `providers.dart`
- modify `app/lib/workspace/note_view.dart` (use `NoteReadingView`)
- tests: `app/test/vault/note_document_test.dart`, `note_document_store_test.dart`, `app/test/reading/block_lookup_test.dart`, `reading_blocks_test.dart`, `reading_code_test.dart`, `reading_table_test.dart`

**Implementation**
1. `edit_operation.dart`: `final class EditOperation { const EditOperation(this.start, this.end, this.replacement); final int start; final int end; final String replacement; int get deletedLength => end - start; int get delta => replacement.length - deletedLength; bool isValidFor(String text) => 0 <= start && start <= end && end <= text.length; String applyTo(String text) => text.replaceRange(start, end, replacement); }` (value equality). Phase 2's `TextEdit` is structurally identical; see "Hand-off".
2. `note_document.dart`:
   ```dart
   enum SaveState { saved, unsaved, saving, error }
   enum SaveOutcome { written, unchanged, readOnly, failed }   // step 01.20 adds `conflict`
   abstract interface class NoteEditorBinding {          // implemented by EditorController (step 01.18)
     String readText();                                  // full current text (O(n))
     void applyEdit(EditOperation op);                   // as an undoable user edit
     void replaceAll(String text, {required bool keepCursor});
   }
   final class NoteDocument extends ChangeNotifier {
     NoteDocument({required this.path, required VaultFileSystem fs, required Clock clock});
     VaultPath path;                                     // mutable only through NoteDocumentStore.retargetPath
     bool get isLoaded; bool get isMissing; bool get isReadOnly;   // isReadOnly == base.malformed
     TextDocument get base;                              // BOM / line ending / malformed of the last load or save
     String get savedText;                               // text identical to the file on disk as far as we know
     String get text;                                    // live text: from the attached editor if any (cached per revision), else the internal text
     int get revision;                                   // +1 on every text change
     SaveState get saveState; Object? get lastError;
     bool get isDirty;                                   // text != savedText (compared lazily, cached per revision)
     Future<void> load();                                // missing file → isMissing = true; other errors rethrown
     void setText(String text);                          // replaces internal text (no editor attached); revision++
     void notifyEditorChanged();                         // O(1): an attached editor changed its text; revision++, saveState = unsaved
     bool edit(EditOperation op);                        // false when read-only, not loaded or the range is invalid; goes through the attached editor when present
     Future<SaveOutcome> save();
     void attachEditor(NoteEditorBinding binding); void detachEditor(NoteEditorBinding binding);
     NoteEditorBinding? get editor;
   }
   ```
   `load()`: `doc = await fs.readText(path)`; `base = doc`; `savedText = text = doc.text`; `saveState = saved`; notify.
   `save()` (this step; step 01.20 adds conflict checks and autosave around it):
   1. If `isReadOnly` → return `readOnly` (never write a malformed file).
   2. `current = text`; if `current == savedText` → `saveState = saved`; return `unchanged` (**no write** — conventions §6.2).
   3. `saveState = saving`; `fs.writeText(path, TextDocument(text: current, hasBom: base.hasBom, lineEnding: base.lineEnding))`; on success `savedText = current`, `base = base.copyWith(text: current)`, `saveState = (text == current) ? saved : unsaved` (edits made during the write keep it `unsaved`), return `written`; on exception log `warning`, `lastError = e`, `saveState = error`, return `failed` (the buffer is untouched, `isDirty` stays true).
   The dominant line ending of a mixed file is applied by `TextDocument.encode` (documented behaviour, conventions §6.2).
3. `note_document_store.dart`: `NoteDocumentStore(VaultFileSystem fs, Clock clock)`: `NoteDocument acquire(VaultPath path)` (creates and starts `load()` on first acquire; reference-counted), `void release(VaultPath path)` (at count 0: `unawaited(doc.save())` if dirty, then dispose after the save completes), `NoteDocument? peek(VaultPath path)`, `Iterable<NoteDocument> get open`, `Future<void> flushPath(VaultPath pathOrFolder)` (saves every dirty doc equal to or within the path; used before moves), `void retargetPath(VaultPath from, VaultPath to)` (re-keys every doc equal to or within `from`, updating `doc.path`), `void discardPath(VaultPath pathOrFolder)` (drops docs without saving — used after deletes), `Future<void> flushAll()`.
   Providers in `vault/providers.dart`: `noteDocumentStoreProvider = Provider<NoteDocumentStore>` (created per session; `ref.onDispose(() => unawaited(store.flushAll()))`) and
   `noteDocumentProvider = Provider.autoDispose.family<NoteDocument, VaultPath>((ref, path) { final s = ref.watch(noteDocumentStoreProvider); final d = s.acquire(path); ref.onDispose(() => s.release(path)); return d; })`.
   Widgets observe a document with `ListenableBuilder(listenable: doc, builder: …)`.
4. **Reading view API** (`reading_view.dart`) — pure widget (no providers needed for its input), so it can be golden-tested:
   ```dart
   class ReadingView extends ConsumerStatefulWidget {
     const ReadingView({super.key, required this.path, required this.text, this.controller, this.readOnly = false, this.readableWidth = true,
         this.onToggleTask, this.onOpenWikiLink, this.onOpenUrl, this.initialOffset, this.onTopOffsetChanged});
     final VaultPath path;                 // the note's own path (resolving relative links/images)
     final String text;
     final ReadingViewController? controller;
     final bool readOnly;                  // disables task toggling (malformed files)
     final bool readableWidth;             // clamp content to 700 dp on wide screens
     final Future<void> Function(TaskItem task, String newStatus)? onToggleTask;
     final void Function(WikiLinkTap tap)? onOpenWikiLink;      // WikiLinkTap { target, heading, blockRef, newTab }
     final void Function(Uri uri)? onOpenUrl;
     final int? initialOffset;             // source offset to scroll to on first build
     final void Function(int sourceOffset)? onTopOffsetChanged;  // offset of the first visible block (throttled 200 ms)
   }
   ```
   `reading_controller.dart`: `ReadingViewController` (a plain object with `ReadingViewState? _state`): `void scrollToOffset(int offset)` (find the top-level block with `block.start <= offset` and the largest start; `ItemScrollController.jumpTo(index:)`; if the offset is inside a nested block the top-level block is used), `void scrollToHeading(String heading)` (first heading whose text, normalised by replacing `[ ] | # ^ \` with spaces, collapsing whitespace and case-folding, equals the normalised query), `void scrollToBlockRef(String id)` (case-insensitive match on `parsed.blockIds`, jump to the owner's offset), `int? get topOffset`, `ParsedNote? get parsed`.
   State flow: `ReadingViewState` keeps `ParsedNote? _parsed` and `String? _parsedText`. In `initState`/`didUpdateWidget(text changed)` it calls `ref.read(parseServiceProvider).parse(text)`; a result is applied only if `text` still equals the requested text (otherwise discarded); while parsing the previous parse stays visible; before the first result show a centered `CircularProgressIndicator` (only if parsing takes > 100 ms: use a delayed spinner).
   Build: `SelectionArea(child: ScrollablePositionedList.builder(itemCount: items.length, itemBuilder: …, itemScrollController, itemPositionsListener, padding: EdgeInsets.fromLTRB(h, 16, h, 96)))` where `items` = visible top-level blocks (see 5) + the footnote section; content is centered with `Align`/`ConstrainedBox(maxWidth: 700)` when `readableWidth` and width > 760 dp; `h` = 16 dp (phone) / 32 dp (desktop). `itemPositionsListener` → `onTopOffsetChanged` (throttle 200 ms): the first fully or partly visible index → its block's `start`.
   `reading_scope.dart`: `ReadingScope extends InheritedWidget` with `path`, `parsed`, `text`, `styles`, `footnoteNumbers`, `readOnly`, callbacks, `toggledCallouts` (a `Set<int>` of callout start offsets whose fold state was toggled; lives in the view state so lazy list rebuilds keep it) and `controller`. All block/inline builders read it via `ReadingScope.of(context)`.
5. **Visible blocks**: `root.children` minus `MdFrontmatter`, `MdCommentBlock`, and `MdHtmlBlock`s that consist only of an HTML comment (`<!--` … `-->`). `block_lookup.dart`: `int blockIndexForOffset(List<MdNode> blocks, int offset)` (binary search for the last block with `start <= offset`; `0` when before the first; `-1` for an empty list).
6. `reading_styles.dart`: `ReadingStyles.of(ThemeData theme, double fontSize)`: `body` = `bodyLarge` with `fontSize`, `height: 1.5`; `heading(level)` sizes `2.0, 1.7, 1.4, 1.2, 1.1, 1.0` × `fontSize`, weight `w700` for 1–2 and `w600` for 3–6, level 6 colour `onSurfaceVariant`; `mono` = `fontFamily: 'monospace'` with `fontFamilyFallback: ['Consolas', 'Cascadia Mono', 'Roboto Mono']`, size `0.9 × fontSize`; colours: link `colorScheme.primary`, quote border `colorScheme.outline`, code background `colorScheme.surfaceContainerHighest`, table border `colorScheme.outlineVariant`, highlight background light `Color(0xAAFFEB3B)` / dark `Color(0x66FFEB3B)`, tag background `primaryContainer` at 50 %. Block spacing: paragraph bottom margin `0.6 × fontSize`; heading top margin `0.8 × fontSize`, bottom `0.4 × fontSize`.
7. **Block widgets** (`reading_blocks.dart`; one function per node `Widget buildBlock(BuildContext context, MdNode node, {int depth = 0})`, switch exhaustive over `MdNode`; inline-only nodes at block level are impossible):
   - `MdParagraph` → `InlineText` (step 01.16) with `styles.body`; bottom margin as above. In **tight** list items a paragraph has bottom margin 2 dp.
   - `MdHeading` → `InlineText` with `styles.heading(level)`, margins as above, wrapped with `Semantics(header: true)` and a `ValueKey('h:${node.start}')`.
   - `MdBlockQuote` → `Container` with `border: Border(left: BorderSide(width: 3, color: styles.quoteBorder))`, left padding 12 dp, text colour `onSurfaceVariant`; children built recursively.
   - `MdThematicBreak` → `Divider(height: 24, thickness: 1)`.
   - `MdList` → `Column` of rows: marker column (ordered: `'${startNumber + i}.'` right-aligned in a 28 dp box; bullet by depth `0: '•'`, `1: '◦'`, `2: '▪'`, then cycling) and an `Expanded` column of the item's child blocks. Left indent 8 dp + marker box; nested lists indent by the marker box width. Task items (`MdListItem.task != null`) replace the marker by the checkbox (step 01.16). Tight lists use spacing 2 dp between items, loose lists 8 dp.
   - `MdCodeBlock` → `reading_code.dart` `CodeBlockView` (below).
   - `MdTable` → `reading_table.dart` `TableView` (below).
   - `MdMathBlock` → `Container` (primaryContainer 30 % background, radius 6, padding 12) with the TeX source in `styles.mono`, centered, horizontally scrollable; `Semantics(label: 'Math block')`. (Typeset math is Phase 6.)
   - `MdHtmlBlock` → muted monospace `Text` of `html` (never executed). Comment-only blocks are filtered out (5).
   - `MdFootnoteDefinition` → not built in place; collected by `reading_footnotes.dart`.
   - `MdFrontmatter`, `MdCommentBlock` → `SizedBox.shrink()` (they are filtered, the case exists for exhaustiveness).
   - `MdCallout` → step 01.16 (this step renders it as a plain `MdBlockQuote` using the same children so the switch compiles and the view is usable).
   Inline-node cases in the block switch are `throw StateError('inline node at block level')` guarded by `assert`.
8. `reading_code.dart`: `CodeBlockView({required MdCodeBlock node})`:
   - Container: background `styles.codeBackground`, radius 6, padding 12; a header row (only when `language != null`): the language name in a small muted label and a copy `IconButton` (24 dp icon, 48 dp tap area on phone) that copies `node.code` (strip the final `\n`) to the clipboard and shows a `SnackBar` `codeCopied`. Without a language the copy button floats top-right.
   - Body: horizontally scrollable `SingleChildScrollView` with a `SelectableText`-free `Text.rich` (selection is provided by the surrounding `SelectionArea`), `softWrap: false`, mono style.
   - **Highlighting**: `CodeHighlighter` (`reading_code.dart`) uses `re_highlight`: a single `Highlight` instance with `Highlight().registerLanguages(builtinAllLanguages)` (the all-languages map from `package:re_highlight/languages/all.dart`; confirm the exact export name in the installed package source) created lazily once. `languageId(String? lang)` maps the fence language (case-insensitive) through this alias table, then to a registered language: `js→javascript, jsx→javascript, ts→typescript, tsx→typescript, py→python, rb→ruby, sh→bash, shell→bash, zsh→bash, yml→yaml, md→markdown, c++→cpp, cs→csharp, ps1→powershell, kt→kotlin, rs→rust, golang→go, html→xml, vue→xml, svg→xml`; unknown → `null` (plain). `TextSpan highlight(String code, String? lang, ThemeData theme)`: `result = highlight.highlight(code: code, language: id)`; render with `TextSpanRenderer(baseStyle, themeMap)`; the theme map is `atomOneLightTheme`/`atomOneDarkTheme` (names from `package:re_highlight/styles/…`) chosen by `theme.brightness`. Codes longer than 20,000 characters or with `language == null` or the special languages `mermaid`, `query`, `base` (rendered by later phases; show a muted chip `codeRenderedLater` "Rendered in a later version") are **not** highlighted. Any exception inside the highlighter is caught (log `warning`) and the plain text is shown.
   - `test`: a code string with a language shows ≥ 2 differently styled spans.
9. `reading_table.dart`: `TableView({required MdTable node})`: horizontal `SingleChildScrollView` around a `Table` (`defaultColumnWidth: IntrinsicColumnWidth()`, minimum column width 48 dp via `ConstrainedBox` in cells), `TableBorder.all(color: tableBorder, width: 1)`; header row background `surfaceContainerHighest` and bold; cell padding `EdgeInsets.symmetric(horizontal: 10, vertical: 6)`; each cell is an `InlineText` with `textAlign` from `aligns[columnIndex]` (`none/left` → start, `center`, `right` → end); a row with fewer cells than columns is padded with empty cells for layout. Vertical margin 8 dp.
10. `reading_footnotes.dart`: `FootnoteIndex buildFootnoteIndex(ParsedNote parsed)` walks the AST in document order: every `MdFootnoteRef` (label) and `MdInlineFootnote` (synthetic label `inline-<start>`) gets the next number the first time its label appears (`Map<String,int> numbers`); definitions are collected from `MdFootnoteDefinition` nodes anywhere in the tree (`Map<String, MdFootnoteDefinition>`). The footnote section (last list item, only if at least one reference exists) = a `Divider` and a numbered list of the **referenced** labels in number order: number, the definition's blocks (or the inline footnote's inline children, or the muted text `footnoteMissing` for an undefined label) and a "↩" `IconButton` that calls `controller.scrollToOffset(firstReferenceOffset)`. Definitions that are never referenced are not shown (Obsidian behaviour).
11. `NoteView` (modify, `app/lib/workspace/note_view.dart`): `NoteView` now watches `noteDocumentProvider(path)`; shows loading/missing/error states; builds `NoteReadingView` for `ViewMode.reading`, and (this step) the same reading view for `source` mode as well, with a `Text('Source mode arrives in step 01.18')`-free implementation: the source branch shows `ReadingView` until 01.18 replaces it. `NoteReadingView({path, tabId})`: `ListenableBuilder(listenable: doc)` → `ReadingView(path, text: doc.text, readOnly: doc.isReadOnly, controller: …, onToggleTask: …, onOpenWikiLink: …, onOpenUrl: …)`; implementations of the three callbacks arrive in step 01.16; here they are `null`. Show the malformed banner (`noteMalformedBanner`, key `note.malformedBanner`) above the content when `doc.isReadOnly`.
12. l10n keys: `codeCopied`, `codeRenderedLater`, `footnoteMissing`, `footnotesTitle`, `readingLoading`.

**Tests**
- `note_document_test.dart` (memory fs; `fs.putBytes` for exact bytes):
  1. `load decodes flags`: CRLF+BOM bytes → `base.hasBom && base.lineEnding == crlf`, `text` has no `\r`, `isDirty == false`.
  2. `save without edit writes nothing`: `save()` → `SaveOutcome.unchanged`, `fs.writeCount == 0`, bytes identical.
  3. `edit then undo to original writes nothing`: `setText('x')` then `setText(original)` → `save()` is `unchanged`, `writeCount == 0`.
  4. `edit keeps BOM and CRLF`: `setText(original + 'z')` → save → file bytes equal `EF BB BF` + original CRLF text + `z` re-encoded; `savedText` updated; `isDirty == false`.
  5. `mixed endings use dominant on edit`: `mixed-endings.md` bytes (3 LF 2 CRLF) → edit → all endings `\n`.
  6. `malformed is read only`: bytes `[0x61,0xFF]` → `isReadOnly`, `edit(...)` returns `false`, `save()` returns `readOnly`, file bytes unchanged.
  7. `edit applies operation`: `edit(EditOperation(0,0,'# '))` → `text` starts with `# `, `revision` incremented; an invalid range returns `false` and changes nothing.
  8. `failed write keeps the buffer`: fs throwing `PermissionDeniedException` → `SaveOutcome.failed`, `saveState == error`, `isDirty == true`, `lastError` set.
  9. `missing file`: `load()` on a missing path → `isMissing == true`, no throw.
  10. `attached editor is the source of text`: a fake `NoteEditorBinding` returning `'live'` → `doc.text == 'live'`; `notifyEditorChanged()` sets `saveState == unsaved`; `edit(op)` calls `binding.applyEdit`.
  11. `empty file stays empty`: 0 bytes → text `''`; `setText('')` → `save` unchanged.
- `note_document_store_test.dart`: two `acquire`s return the same instance; `release` twice then a third `acquire` creates a new one; dirty doc is saved on last release; `retargetPath('a.md','b.md')` and folder form re-key and update `doc.path`; `flushPath('Folder')` saves dirty docs within; `discardPath` drops without writing.
- `block_lookup_test.dart`: offsets before/inside/after blocks; empty list → -1.
- `reading_blocks_test.dart` (pumps `ReadingView` at 600 dp with `testApp`): for `# H⏎⏎text` finds a `Text` for each; heading semantics `header: true`; list markers (`•`, `1.`, `7.`, nested `◦`); loose vs tight spacing (a loose list has larger vertical gaps: compare `tester.getTopLeft` differences); blockquote has a left border `DecoratedBox`/`Container` (assert by `find.byKey(Key('quote:<start>'))`—give quote containers that key); thematic break renders a `Divider`; math block text visible in mono; HTML block raw text shown; frontmatter not rendered; comment block not rendered; comment-only HTML block not rendered; footnote section appears only with references and numbers by first reference (`text[^b] [^a]` → `b` is 1).
- `reading_code_test.dart`: alias table (`js` → javascript, `unknown` → null); highlighted span count > 1 for `dart` code; `mermaid` shows the `codeRenderedLater` chip; > 20,000 chars not highlighted; copy button writes `code` without the trailing newline (mock `SystemChannels.platform` `Clipboard.setData`).
- `reading_table_test.dart`: header bold, alignment mapping (`center` cell has `TextAlign.center`), short row padded, horizontal scrolling when wider than the viewport (`SingleChildScrollView` with `scrollDirection: Axis.horizontal` found).

**Verify** `cd app; flutter test test/vault test/reading; cd ..`; run the app on Windows with a copy of `test_vaults/syntax`, open `01-headings.md` (the reading view is shown) and `08-code.md`. Commit `phase 01.15: add NoteDocument and reading view blocks`.

**Pitfalls**
- Never compare `text` to `savedText` on every build; `isDirty` is cached per `revision`.
- `Provider.autoDispose.family` for documents: the NoteView holds the provider for as long as it is mounted; when a tab navigates away the doc is released (and saved if dirty).
- `ScrollablePositionedList` needs bounded height; the reading view sits in an `Expanded`.
- Do not put per-block state (callout folds, checkboxes) in the block widgets themselves — the lazy list disposes off-screen items; keep it in `ReadingScope`.

---

### 01.16 Reading view: inline rendering, callouts, tasks, links, images/embeds, goldens

**Purpose** Complete the reading view: every inline node, callouts with folding, tappable tasks that write back, internal/external links, local images and embeds, plus the golden and semantic tests.

**Files** (under `app/lib/reading/`)
- `inline_text.dart`, `inline_builder.dart`, `callout_view.dart`, `callout_styles.dart`, `task_checkbox.dart`, `task_toggler.dart`, `reading_images.dart`, `file_chip.dart`, `simple_link_resolver.dart`, `link_actions.dart`
- modify `reading_blocks.dart` (callout/task wiring), `workspace/note_view.dart` (callbacks), `vault/providers.dart` (`vaultFilesProvider`)
- tests: `app/test/reading/` (`inline_builder_test.dart`, `callout_view_test.dart`, `task_toggler_test.dart`, `simple_link_resolver_test.dart`, `link_actions_test.dart`, `reading_images_test.dart`, `syntax_notes_semantic_test.dart`, `goldens_test.dart`) and `app/test/reading/goldens/*.png`

**Implementation**
1. **`InlineText`** (`inline_text.dart`): `StatefulWidget({required List<MdNode> nodes, required TextStyle style, TextAlign? textAlign})`. In `didChangeDependencies`/`didUpdateWidget` it calls `InlineBuilder.build(nodes, style, context)` which returns an `InlineSpan` **and** a list of `GestureRecognizer`s created for links/tags; the state disposes the previous recognizers before building new ones and in `dispose` (leaking recognizers is a bug).
2. **`InlineBuilder` rules** (one case per node; exhaustive `switch`; unknown inline nodes cannot occur):
   - `MdText` → `TextSpan(text)`.
   - `MdEmphasis` → italic; `MdStrong` → `FontWeight.w700`; `MdStrikethrough` → `TextDecoration.lineThrough`; `MdHighlight` → `backgroundColor: styles.highlight`. Styles combine through `copyWith` on the inherited style (nesting works).
   - `MdInlineCode` → mono style, `backgroundColor: codeBackground`, size 0.9 ×.
   - `MdSoftBreak` → `TextSpan(text: '\n')` (Obsidian's default: a single newline is a line break in reading view); `MdHardBreak` → `'\n'`.
   - `MdCommentInline`, `MdBlockId` → `TextSpan(text: '')` (hidden). A paragraph whose only content is hidden nodes is not built at all (the block builder checks `children.every(hidden)` and returns `SizedBox.shrink()`).
   - `MdHtmlInline` → `<br>`, `<br/>`, `<br />` (case-insensitive) → `'\n'`; every other raw inline HTML string is shown as literal muted text.
   - `MdInlineMath` → mono text with `backgroundColor: primaryContainer @ 30 %` (typeset math: Phase 6).
   - `MdTag` → `'#$name'` in `colorScheme.primary` with `backgroundColor: styles.tagBackground`; no tap action in Phase 1.
   - `MdAutolink` → link style (primary, underline), tap → `onOpenUrl(Uri.parse(url))`; display text = the source substring (`ReadingScope.text.substring(start, end)` minus `<` `>`).
   - `MdLink(image: false)` → children rendered with link style (primary; underline for external URLs, none for internal); tap → `LinkActions.openMarkdownLink(url)`.
   - `MdLink(image: true)` → `WidgetSpan(child: ReadingImage(...))` (6).
   - `MdWikiLink(embed: false)` → display text: `alias ?? (target.isEmpty ? heading ?? '^$blockRef' : target)` plus, when `alias == null`: `' > $heading'` if `heading != null && target.isNotEmpty`, `' > ^$blockRef'` if `blockRef != null && target.isNotEmpty`; link style without underline; tap → `onOpenWikiLink(WikiLinkTap(target, heading, blockRef, newTab: false))`; **secondary tap (mouse middle/right click) or Ctrl+tap** → `newTab: true` (implemented with a `Listener` + `GestureDetector` inside a `WidgetSpan`-free approach: `TapGestureRecognizer` for primary taps and `onTertiaryTapUp` for middle click; Ctrl+tap detected via `HardwareKeyboard.instance.isControlPressed`).
   - `MdWikiLink(embed: true)` → `WidgetSpan` (6).
   - `MdFootnoteRef` / `MdInlineFootnote` → superscript number `n` from `ReadingScope.footnoteNumbers` (`WidgetSpan(alignment: PlaceholderAlignment.top, child: GestureDetector(onTap: scroll to the definition's list item, child: Text('$n', style small primary)))`); unknown label → `?`.
3. **Callouts** (`callout_view.dart`, `callout_styles.dart`): `CalloutView({required MdCallout node})`. Style table (type lower-case; match is case-insensitive; types that are not listed use the `note` style):

   | Types (aliases) | Colour | Icon (Material) |
   |---|---|---|
   | `note` | `0xFF086DDD` | `Icons.edit_outlined` |
   | `abstract`, `summary`, `tldr` | `0xFF00BFBC` | `Icons.assignment_outlined` |
   | `info` | `0xFF086DDD` | `Icons.info_outline` |
   | `todo` | `0xFF086DDD` | `Icons.check_circle_outline` |
   | `tip`, `hint`, `important` | `0xFF00BFBC` | `Icons.local_fire_department_outlined` |
   | `success`, `check`, `done` | `0xFF08B94E` | `Icons.check` |
   | `question`, `help`, `faq` | `0xFFDB7800` | `Icons.help_outline` |
   | `warning`, `caution`, `attention` | `0xFFDB7800` | `Icons.warning_amber_outlined` |
   | `failure`, `fail`, `missing` | `0xFFE9314C` | `Icons.close` |
   | `danger`, `error` | `0xFFE9314C` | `Icons.bolt` |
   | `bug` | `0xFFE9314C` | `Icons.bug_report_outlined` |
   | `example` | `0xFF7852EE` | `Icons.format_list_bulleted` |
   | `quote`, `cite` | `0xFF9E9E9E` | `Icons.format_quote` |

   `CalloutStyle calloutStyleFor(String type)` returns `(color, icon)`; it is a pure function with a test for every row.
   Layout: `Container` with radius 6, background `color @ 10 %` (alpha 0.10), padding 12; title row: icon (18 dp, `color`), 8 dp gap, title (`InlineText` of `MarkdownParser.parseInline(node.title)`, bold, colour `color`) — default title when `title == null`: the type with its first letter upper-cased (`custom-type` → `Custom-type`); when the callout is foldable (`fold != none`) a trailing chevron (`Icons.expand_more` rotated) is shown and tapping the title row toggles; body = child blocks (`buildBlock` recursively; nested callouts work), separated from the title by 8 dp, hidden when collapsed.
   Fold state: initial = `fold == collapsed`; toggles are stored in `ReadingScope.toggledCallouts` (key = `node.start`); a callout with `fold == none` ignores taps. A callout without children shows only the title row. Semantics: `Semantics(label: type)` and the foldable title row is a button with `expanded` state.
4. **Tasks** (`task_checkbox.dart`, `task_toggler.dart`): in `buildBlock` for `MdListItem` with `task != null`: marker = `TaskCheckbox(status: task, onChanged)`: size 20 dp (tap area 48 dp on phone via padding); rendering by status char: `' '` → empty rounded box; `x`/`X` → checked box (primary fill, check icon) and the item text gets `TextDecoration.lineThrough` + `onSurfaceVariant` colour; `/` → box with a half-filled square; `-` → box with a minus, text struck through; `>` → box with a right arrow; `<` → left arrow; `?` → `?` glyph; `!` → `!` glyph in error colour; any other char → box showing that character in 12 dp. **Toggling**: a tap on `' '` writes `x`; on any other status writes `' '` (so `/`, `-`, `>`, … go back to open; `x`/`X` → `' '`). Disabled when `readOnly`.
   `TaskToggler`: `ReadingView.onToggleTask(task, newStatus)` → `Future<bool> toggleTask(NoteDocument doc, TaskItem task, String newStatus)`: (1) `current = doc.text`; (2) verify `task.statusOffset + task.status.length <= current.length` and `current.substring(statusOffset, statusOffset + status.length) == task.status`; if not (the note changed under the view) → return `false` and the reading view re-parses (no edit); (3) `doc.edit(EditOperation(statusOffset, statusOffset + task.status.length, newStatus))`; (4) `await doc.save()` immediately (task taps persist at once; unchanged text would not write); return `true`. This is the **only** way the reading view changes a note. The reading view works with the parse of `text`; because `TaskItem.statusOffset` is an absolute UTF-16 offset into exactly that text, the check in (2) is what protects against stale offsets.
5. **Links** (`link_actions.dart`, `simple_link_resolver.dart`):
   - `vaultFilesProvider = FutureProvider<List<VaultPath>>` (watches `vaultRevisionProvider`): every **file** from `fs.list()` (notes and attachments).
   - `SimpleLinkResolver` (pure; **Phase 1 resolution, replaced by the index-based resolver in Phase 2**): `VaultPath? resolve(String target, {required VaultPath from, required List<VaultPath> files})`:
     1. `t = target.trim().replaceAll('\\', '/')`; empty → return `from` (same note).
     2. If `t` contains `/`: exact match on `t` or `t + '.md'` by `caseKey` against `files`; then (fallback) any file whose `caseKey` equals or ends with `'/' + t.toLowerCase()` (with and without `.md` appended). Among several matches choose by rule 4.
     3. Else (no `/`): if `t` has an extension (`VaultPath` rules: last `.` not at index 0): candidates = files whose `name.toLowerCase() == t.toLowerCase()`; otherwise candidates = markdown files whose `stem.toLowerCase() == t.toLowerCase()`, then (if none) any file whose stem equals.
     4. **Shortest path wins**: fewest path segments, then shorter `value`, then `compareTo`.
     5. No candidates → `null`. (No aliases, no heading-based resolution; Phase 2.)
   - `LinkActions` (a plain class built with `ref`, `context`, `from`): `Future<void> openWikiLink(WikiLinkTap tap)`: resolve (using `vaultFilesProvider.future`); resolved → `openFile(ref, path, newTab: tap.newTab)`; then if the opened tab is in reading mode and `heading != null` → `controller.scrollToHeading`, `blockRef != null` → `scrollToBlockRef` (done after the next frame, in the destination view via a pending-jump holder `pendingJumpProvider` = `{path, heading?, blockRef?}` consumed by `NoteView` once loaded; in source mode the editor moves the caret: step 01.18 consumes the same holder). Same-note links (`target.isEmpty`) scroll within the current view. Unresolved → `SnackBar(linkNotFound(target))` with an action **Create** that calls `NoteCreator.createFromName(target, contextNote: from)` and opens the note.
   - `openMarkdownLink(String url)`: classify: if `Uri.tryParse(url)?.hasScheme == true`: schemes `http`, `https`, `mailto`, `tel` → `launchUrl(uri, mode: LaunchMode.externalApplication)`; any other scheme (`javascript`, `file`, `data`, …) → `SnackBar(linkSchemeBlocked)`, nothing launched. No scheme → an internal vault link: `decoded = decodeMarkdownPathLenient(url)` (`Uri.decodeComponent`, on error the original), split at the first `#` (`#^id` → `blockRef`, other → `heading`, empty path → same note), then try `from.parent.join(path)` as an exact file match first and finally the resolver → `openWikiLink(...)`.
   - Ctrl+click or middle-click → new tab, as described in 2.
6. **Images and embeds** (`reading_images.dart`, `file_chip.dart`):
   - `ReadingImage` for `MdLink(image: true)`: `alt` = plain text of the children; size syntax: if `alt` ends with `|<w>` or `|<w>x<h>` the numbers are the display size and the suffix is removed from the alt text. `url` rules: `http(s)://` → `Image.network` (with `errorBuilder` → file-chip-like placeholder showing the host); anything else is a vault path: decode (`Uri.decodeComponent` lenient), resolve relative to `from.parent` exact match, else `SimpleLinkResolver`; not found → a muted placeholder chip `imageNotFound(name)`.
   - Embed `MdWikiLink(embed: true)`: resolve `target` with `SimpleLinkResolver` against `vaultFilesProvider`; by extension of the **resolved** file: `png jpg jpeg gif webp bmp` → image (`size` → width/height; `alias` → `Semantics` label); `svg`, `pdf`, audio extensions, video extensions, any other extension → `FileChip` (icon by type, file name, human size from `fs.stat`; tap opens the file with the system app on Windows via `url_launcher` `launchUrl(Uri.file(absPath))`, on Android a `SnackBar` `embedOpenLater`); `md` or no extension (a note embed) → a bordered box `EmbeddedNoteBox` showing `📄 <name>` that opens the note on tap (real transclusion is Phase 2); unresolved → muted chip `embedNotFound(target)`.
   - `ReadingImageProvider`: `FutureProvider.family<Uint8List?, VaultPath>` reading `fs.readBytes`; an in-memory LRU (20 entries, max 30 MB total) keyed by `(path, modified)`; displayed with `Image.memory(bytes, cacheWidth: (min(maxWidth, 1600) * devicePixelRatio).round(), fit: BoxFit.contain, gaplessPlayback: true)`; images are limited to the content width and are never upscaled beyond their natural size; a decode error shows the `FileChip`.
7. Wire `NoteReadingView`: `onToggleTask` → `TaskToggler`, `onOpenWikiLink` → `LinkActions.openWikiLink`, `onOpenUrl` → `LinkActions.openMarkdownLink`-style external launcher (`launchUrl`), `controller` per tab (kept in the `NoteView` state).
8. l10n keys: `linkNotFound` (`"{target}" doesn't exist`), `linkCreate` (Create), `linkSchemeBlocked`, `imageNotFound`, `embedNotFound`, `embedOpenLater` ("Open this file type in a later version"), `fileChipOpen`.

**Tests**
- `inline_builder_test.dart`: each node kind → the span (find `Text.rich` and inspect `InlineSpan` tree): strong weight 700, emphasis italic, strikethrough decoration, highlight background, code mono + background, soft break → `'\n'`, hard break → `'\n'`, comment/block-id → no visible text, `<br>` → newline, tag text `#tag` with background, wikilink display `Note > Heading`, alias shown, `[[#Heading]]` shows `Heading`, footnote ref shows its number, recognizers disposed (pump an `InlineText`, replace its nodes, assert the old recognizer's `debugDisposed`/no leak by checking `dispose` was called through a counting subclass injected via `InlineBuilder.recognizerFactory`).
- `callout_view_test.dart`: `calloutStyleFor` returns the table's colour/icon for **every** listed type (27 types) and `note` style for `unknown`, case-insensitive (`WARNING`); default title `Custom-type`; foldable `+` starts expanded, `-` starts collapsed (body not found), tapping toggles; `fold == none` ignores taps; nested callout renders; toggle state survives scrolling the callout out of view and back (use a tall list).
- `task_toggler_test.dart`: toggling `- [ ] a` writes `- [x] a` (verify bytes on disk and `fs.writeCount == 1`); `x` → `' '`; `/` → `' '`; a stale offset (document edited after parse) → returns `false`, no write; read-only document → checkbox not tappable (no write); a CRLF file keeps its endings; the BOM is preserved; non-ASCII task text before the checkbox (Bangla line before it) toggles the right character (offset correctness); a task whose status char is an emoji (2 UTF-16 units) is replaced fully.
- `simple_link_resolver_test.dart` (files `Note.md`, `Folder/Note.md`, `Deep/x/y/Target.md`, `Images/pic.png`, `Folder/pic.png`, `বাংলা.md`): `Note` → `Note.md` (shortest); `note` (case) → `Note.md`; `Folder/Note` → `Folder/Note.md`; `Target` → `Deep/x/y/Target.md`; `pic.png` → `Folder/pic.png` (both candidates have 2 segments and 14 characters, so the final tie-break `compareTo` decides: `Folder/…` < `Images/…`); `y/Target` suffix → `Deep/x/y/Target.md`; `Missing` → `null`; empty → `from`; backslashes normalised; Bangla name; target with `.md` extension → `Note.md`.
- `link_actions_test.dart`: external `https://x.y` launches (fake `UrlLauncherPlatform`); `javascript:alert(1)` and `file:///c:/x` are blocked with the snackbar; `mailto:` allowed; relative `a%20b.md#Head` resolves and sets the pending jump; `#Heading` scrolls the current view; unresolved wikilink shows the snackbar with **Create**; pressing it creates the note.
- `reading_images_test.dart`: `sample.png` bytes from `test_vaults/syntax/attachments/sample.png` render an `Image`; `![alt|120x80](sample.png)` → `SizedBox` 120×80 and alt `alt`; missing image → placeholder; `![[sample.pdf]]` → `FileChip` named `sample.pdf`; `![[sample.png|50]]` width 50; `![[Folder/Nested Note]]`-style note embed → `EmbeddedNoteBox`; http image URL → `Image.network` widget present.
- `syntax_notes_semantic_test.dart`: pump `ReadingView` for each of the 24 notes of `test_vaults/syntax` (read from disk) and assert one structural fact each — `01-headings`: 9+ `Semantics(header)` nodes (count headings in the parse, assert equal); `04-lists`: a `•` marker and a `7.` marker exist; `05-tasks`: 13 `TaskCheckbox`es and the last line renders as text `[ ]Not a task…`; `07-callouts`: the number of `CalloutView`s seen equals the number of `MdCallout` nodes in the parse (walk the list by calling `controller.scrollToOffset` for each top-level callout's offset and collecting the distinct `CalloutView` keys `callout:<start>` that appear; give every `CalloutView` that key); `08-code`: `CodeBlockView` count equals the parse count; `09-tables`: a `Table` exists; `10-links`/`11-wikilinks`: a tap on the first wikilink calls `onOpenWikiLink` with the expected target; `12-embeds`: no exception, `FileChip`s for pdf/mp3/mp4; `13-tags`: tag text found; `14-comments`: comment text **not** found in the widget tree (`find.textContaining` of the comment words → none); `16-math`: mono math text found; `17-footnotes`: footnote section present; `18-frontmatter`: the YAML key text is **not** found; `19-html`: raw `<div>` text shown. Remaining notes: no exception.
- `goldens_test.dart` (tag `golden`; generated on Windows with `flutter test --update-goldens --tags golden test/reading/goldens_test.dart`; the default test font is used — do **not** load fonts): for each of the 24 syntax notes render `ReadingView` inside a `SizedBox(width: 600, height: 900)` light theme with `readableWidth: true` → `goldens/syntax_<name>.png`; additionally `07-callouts` dark theme → `goldens/syntax_07_callouts_dark.png`, `05-tasks` at 360 dp phone width → `goldens/syntax_05_tasks_phone.png`, `09-tables` at 360 dp → `goldens/syntax_09_tables_phone.png`. 27 golden files total. Commit the PNGs. Every later change that alters them must be intentional and re-generated (`--update-goldens`) with a note in `PROGRESS.md`.

**Verify** `cd app; flutter test --exclude-tags golden; flutter test --tags golden; cd ..`; manual (Windows, copy of the syntax vault): open `07-callouts.md` (fold works), `05-tasks.md` (tap a checkbox and confirm the file on disk changes exactly one character — `git diff` in the **copy** or compare bytes), `12-embeds.md` (image shows), click a wikilink to `Folder/Nested Note`. Commit `phase 01.16: complete reading view with callouts, tasks, links and images`.

**Pitfalls**
- Never launch a URL scheme other than `http`, `https`, `mailto`, `tel`.
- The task offset check in `toggleTask` must compare the exact characters; skipping it can corrupt a note if the text changed between parse and tap.
- `GestureRecognizer`s created in `build` without disposal are a memory leak — follow the `InlineText` state pattern.
- Callout bodies contain blocks: reuse `buildBlock`, do not render children inline.
- `Image.memory` without `cacheWidth` decodes full-size photos (tens of MB); always pass it.

---

### 01.17 File explorer

**Purpose** The vault tree: lazy expansion, sort modes, create, inline rename, move (drag on desktop, "Move to…" on phone), delete, duplicate, reveal in Explorer; with the notice that links are not updated yet.

**Files** (under `app/lib/explorer/` unless noted)
- `explorer_pane.dart`, `explorer_rows.dart`, `explorer_row_tile.dart`, `explorer_service.dart`, `explorer_sort.dart`, `explorer_state.dart`, `move_to_dialog.dart`, `explorer_menus.dart`, `explorer_commands.dart`, `reveal_in_system_explorer.dart`, `visible_file_types.dart`, `providers.dart`
- `app/lib/workspace/builtin_panels.dart` (new), modify `workspace/workspace_shell.dart` (call it), `commands/providers.dart` (`registerExplorerCommands`)
- tests: `app/test/explorer/` (`explorer_sort_test.dart`, `explorer_rows_test.dart`, `explorer_service_test.dart`, `explorer_pane_test.dart`, `rename_validation_test.dart`, `move_to_dialog_test.dart`, `explorer_commands_test.dart`)

**Implementation**
1. `visible_file_types.dart`: `bool isVisibleInExplorer(VaultEntry e)` — folders always; files whose extension ∈ `{md, canvas, base, pdf, png, jpg, jpeg, gif, webp, bmp, svg, mp3, wav, m4a, ogg, flac, 3gp, aac, opus, mp4, webm, mov, mkv, ogv}`. Other files are hidden. `String displayName(VaultEntry e)` — markdown files without `.md`, everything else full name. `IconData iconFor(VaultEntry e)` — folder `Icons.folder_outlined` (open: `folder_open_outlined`), `md` `description_outlined`, `canvas` `dashboard_outlined`, `base` `table_chart_outlined`, `pdf` `picture_as_pdf_outlined`, images `image_outlined`, audio `audiotrack_outlined`, video `movie_outlined`.
2. `explorer_sort.dart`: imports `ExplorerSort` from `settings/vault_settings.dart` (defined in step 01.11; do not redefine it) and provides `List<VaultEntry> sortEntries(List<VaultEntry> entries, ExplorerSort sort)`: **folders first** in every mode; within each group: name modes compare `displayName` case-insensitively with `compareTo` of the lower-cased strings ("natural" digits are **not** special-cased), ties by `path.value`; modified modes by `modified`; created modes by `created ?? modified` (Android has no creation time); ties by name ascending.
3. `explorer_state.dart`:
   | Provider | Declaration |
   |---|---|
   | `explorerExpandedProvider` | `NotifierProvider<ExplorerExpandedNotifier, Set<VaultPath>>` (`toggle`, `expand`, `expandAncestors(VaultPath)`, `collapseAll`) |
   | `explorerSelectedProvider` | `NotifierProvider<…, VaultPath?>` (single selection) |
   | `explorerRenamingProvider` | `NotifierProvider<…, VaultPath?>` — the row in inline-rename mode |
   | `explorerChildrenProvider` | `FutureProvider.autoDispose.family<List<VaultEntry>, VaultPath>`: watches `vaultRevisionProvider` and `vaultSettingsProvider.select((s) => (s.explorerSort, s.showHidden))`; `fs.list(folder: p, recursive: false)` filtered by `isVisibleInExplorer` and sorted |
   | `explorerRowsProvider` | `FutureProvider.autoDispose<List<ExplorerRow>>`: root children + the children of every expanded folder (in parallel), flattened with `flattenTree` |
   `ExplorerRow { VaultEntry entry; int depth; bool expanded; bool loading }`. `List<ExplorerRow> flattenTree(List<VaultEntry> rootEntries, Set<VaultPath> expanded, Map<VaultPath, List<VaultEntry>> childrenOf, {int depth = 0})` is **pure**: depth-first; an expanded folder with no entry in `childrenOf` yields a row with `loading: true` after the folder row. An expanded folder whose path no longer exists is ignored.
4. `explorer_service.dart` — `ExplorerService(Ref ref)` (provider `explorerServiceProvider`); every method updates the file system, then calls `ref.read(vaultRevisionProvider.notifier).bump()`:
   - `Future<VaultPath> createNote(VaultPath folder)`: `NoteCreator.createUntitled(folder: folder)`; expands `folder`; selects the note; opens it (`openFile`) and sets `explorerRenamingProvider` so its row enters inline rename.
   - `Future<VaultPath> createFolder(VaultPath parent)`: first free of `Untitled folder`, `Untitled folder 1`, … → `fs.createFolder`; expand parent; select; start rename.
   - `Future<VaultPath> rename(VaultPath from, String newName)`: `newName` trimmed; for a **file** the final name is `newName + '.' + from.extension` unless `newName` already ends with that extension (case-insensitive) — and markdown files accept a typed `.md` once; for a folder the final name is `newName`. Validate with `VaultPath.checkName` (messages `explorerNameEmpty`, `explorerNameInvalid`); `to = from.withName(finalName)`; if `to == from` → no-op; if an entry exists at `to` and `to.caseKey != from.caseKey` → throw `FileConflictException(to)` (UI: `explorerNameExists`). Then `await store.flushPath(from)` (save pending edits), `await fs.move(from, to)`, `store.retargetPath(from, to)`, `workspace.retargetPath(from, to)`, update expanded set paths (`from`-prefixed entries re-keyed), selection, bump, and show the `explorerLinksNotUpdatedNotice` snackbar.
   - `Future<VaultPath> move(VaultPath from, VaultPath targetFolder)`: `to = targetFolder.join(from.name)`; refuse (throw `StateError`, never reaches UI because the UI prevents it) when `targetFolder == from.parent`, `targetFolder == from`, or `targetFolder.isWithin(from)`; if `to` exists → `FileConflictException`; same pipeline as rename (flush, move, retarget store/workspace/expanded, bump, notice).
   - `Future<void> delete(VaultPath path)`: `mode = settings.trashChoice → TrashMode` (on Android `system` is treated as `vaultTrash` by not passing a `SystemTrash`); `await fs.delete(path, mode: mode)`; `store.discardPath(path)`; `workspace.removePath(path)`; bump. The confirmation dialog is shown by the caller.
   - `Future<VaultPath> duplicate(VaultPath path)` (files only): name = first free `<stem> 1.<ext>`, `<stem> 2.<ext>`, … (no extension: `<name> 1`); copy via `readBytes`/`writeBytes` (byte-exact, keeps BOM/CRLF); bump; select; start rename.
   - `Future<void> reveal(VaultPath path)` → `revealInSystemExplorer(absPath)` (Windows only).
   All methods are no-throw wrappers around the pure steps for tests; the **UI** catches `FileConflictException`, `InvalidPathException`, `PermissionDeniedException`, `FileNotFoundException` and shows `explorerNameExists` / `explorerNameInvalid` / `explorerPermissionDenied` / `explorerNotFound`.
   `reveal_in_system_explorer.dart`: `Future<void> revealInSystemExplorer(String absolutePath)`: `Process.run('explorer.exe', ['/select,', p.windows.normalize(absolutePath)])` — ignore the exit code (Explorer returns 1 on success); on exception log `warning`. Only called when `Platform.isWindows`.
5. `explorer_pane.dart` — `ExplorerPane extends ConsumerStatefulWidget`:
   - **Header toolbar** (key `explorer.toolbar`): New note (`Icons.note_add_outlined`, key `explorer.newNote`), New folder (`create_new_folder_outlined`, `explorer.newFolder`), Sort (`sort`, opens a menu with the six `ExplorerSort` values, a check mark on the current one; writes `vaultSettings.explorerSort`), Collapse all (`unfold_less`, `explorer.collapseAll`). Buttons are 48 dp on phone (width < 840) and 32 dp on desktop. New items are created in the **selected folder** (selected file → its parent; nothing selected → vault root).
   - **Tree**: `ListView.builder` over `explorerRowsProvider` (`AsyncValue` loading → thin progress bar; error → message with Retry). Row height: 48 dp on phone, 32 dp on desktop. Row content: indent `16 dp × depth`, chevron (folders; rotates) or a 24 dp spacer, icon, name (ellipsis), and for the row of `activeNotePathProvider` a highlighted background (`secondaryContainer`). Folder tap toggles expansion (and selects). File tap: selects and opens (`openFile`); Ctrl+click and middle click → `newTab: true`; non-note files: `launchUrl(Uri.file)` on Windows for pdf/audio/video/other, images open the same way, Android shows `embedOpenLater`; `.md` and `.canvas`/`.base` open as tabs (`ViewRegistry` decides what is built; unsupported shows `UnsupportedFileView`).
   - **Inline rename**: while `explorerRenamingProvider == entry.path`, the name cell is a `TextField` (key `explorer.renameField`) prefilled with the name **without** extension for files (the whole name for folders), all text selected, autofocus. Enter → commit; Escape → cancel; focus lost → commit if the text changed and is valid, else cancel. An invalid or conflicting name shows the error text under the field (`explorerNameInvalid` / `explorerNameExists`) and keeps editing.
   - **Context menu** (desktop: secondary click opens `showMenu` at the pointer; phone: long press opens a bottom sheet with the same entries, each 48 dp): for a note: *Open in new tab*, *New note*, *New folder*, *Rename*, *Duplicate*, *Move to…*, *Reveal in system explorer* (Windows only), *Delete*; for a folder: *New note*, *New folder*, *Rename*, *Move to…*, *Reveal in system explorer* (Windows only), *Delete*; for other files: *Rename*, *Move to…*, *Reveal* (Windows only), *Delete*. Empty area of the pane (secondary click) → *New note*, *New folder* in the root.
   - **Delete** → `AlertDialog` (`explorerDeleteTitle`: "Delete “{name}”?"), body by trash mode: `explorerDeleteBodySystem` ("It will be moved to the Recycle Bin."), `explorerDeleteBodyVault` ("It will be moved to the vault's .trash folder."), `explorerDeleteBodyPermanent` ("It will be deleted permanently. This cannot be undone."); folders add `explorerDeleteFolderExtra` ("All {count} items inside are included.") where `count` = recursive file count from `fs.list(folder, recursive: true)`; if any open note inside is dirty add `explorerDeleteUnsaved` ("Unsaved changes in open notes will be lost."). Buttons Cancel / Delete (destructive style).
   - **Move**: desktop — every row is a `Draggable<VaultPath>` (`dragAnchorStrategy: pointerDragAnchorStrategy`, feedback = a `Material` chip with the name, `childWhenDragging` at 40 % opacity) and every folder row plus the header "vault root" strip is a `DragTarget<VaultPath>` (`onWillAcceptWithDetails`: not itself, not its current parent, not a descendant); a hovering accepted drop highlights the folder (`tertiaryContainer`); hovering over a collapsed folder for 600 ms expands it; drop → `ExplorerService.move`. Phone — the *Move to…* entry opens `MoveToDialog`: a full-height dialog showing the **folder tree** (root first; folders only; lazy expansion using the same providers; the invalid targets — the item's own folder and its descendants, and its current parent — disabled with a muted style); selecting a folder enables **Move here**.
   - **Keyboard (desktop)**: the pane has a `Focus`; Up/Down move the selection; Right expands a folder / Left collapses (or selects the parent); Enter opens the selected file or toggles the folder; F2 renames; Delete opens the delete dialog.
   - **Reveal active file**: `explorerExpandedProvider.expandAncestors(path)`, select it, and scroll so the row is visible (`ScrollController.animateTo(index × rowHeight - viewportHeight / 2)`); also triggered by the command.
   - **Notice**: after a successful rename or move of a note, folder or file, a `SnackBar` (`explorerLinksNotUpdatedNotice`: "Links to “{name}” were not updated. Automatic link updates arrive in a later version.", 5 s). Phase 2 deletes this notice.
6. `builtin_panels.dart`: `void registerBuiltinPanels(WidgetRef ref)`: registers the explorer panel on the **left** (`SidebarPanelSpec(id: 'explorer', side: SidebarSide.left, label: (l) => l.sidebarExplorer, icon: Icons.folder_outlined, builder: (c, r) => const ExplorerPane())`). `WorkspaceShell` calls it once in `initState` via `WidgetsBinding.instance.addPostFrameCallback`. **Phase 2 adds its panels here** (do not register panels anywhere else).
7. `explorer_commands.dart`: `registerExplorerCommands(CommandRegistry r)`: `note.create-note` is already registered (01.14: it calls `ExplorerService.createNote` for the folder resolved by the new-note location setting, then opens it in a new tab — update its `run` to call `NoteCreator.createUntitled` + `openFile(newTab: true)` as before; keep id and shortcut); registers `note.create-folder`, `note.rename-note` (`F2`; sets `explorerRenamingProvider` for the active note after making the explorer visible: `leftSidebarVisible = true` / open drawer on phone, `expandAncestors`), `note.delete-note` (opens the same delete dialog for the active note), `note.duplicate-note`, `note.reveal-in-explorer` (`isAvailable`: Windows and an active note), `explorer.collapse-all`, `explorer.reveal-active-file`. Add `registerExplorerCommands(r)` to `commandRegistryProvider`.
8. l10n keys: `explorerNewNote`, `explorerNewFolder`, `explorerSort`, `explorerSortNameAsc`, `explorerSortNameDesc`, `explorerSortModifiedNew`, `explorerSortModifiedOld`, `explorerSortCreatedNew`, `explorerSortCreatedOld`, `explorerCollapseAll`, `explorerOpenInNewTab`, `explorerRename`, `explorerDuplicate`, `explorerMoveTo`, `explorerMoveHere`, `explorerReveal`, `explorerDelete`, `explorerDeleteTitle`, `explorerDeleteBodySystem`, `explorerDeleteBodyVault`, `explorerDeleteBodyPermanent`, `explorerDeleteFolderExtra`, `explorerDeleteUnsaved`, `explorerNameEmpty`, `explorerNameInvalid`, `explorerNameExists`, `explorerPermissionDenied`, `explorerNotFound`, `explorerLinksNotUpdatedNotice`, `explorerMoveExists`, `explorerUntitledFolder`, `explorerEmpty` ("This vault has no notes yet").

**Tests**
- `explorer_sort_test.dart`: entries `b.md`, `A.md`, `folderZ/`, `folderA/`, `10.md`, `9.md` (distinct modified/created): `nameAsc` → folders first `folderA, folderZ`, then `10, 9, A, b` (plain string order of lower-cased names: `10` < `9` < `a` < `b`); `nameDesc` reverses within groups; `modifiedNew/Old`, `createdNew/Old` ordering; `created == null` falls back to `modified`; ties by name; folders always first in all six modes.
- `explorer_rows_test.dart`: `flattenTree` with expanded `a` (children `a/b` folder expanded with a child `a/b/c.md`, and `a/x.md`) yields rows with depths `0,1,2,2? …` per DFS (assert the exact ordered list of `(path, depth)`); an expanded folder missing from `childrenOf` yields `loading`; a non-expanded folder hides children; `isVisibleInExplorer` hides `.xyz`, shows `.canvas`; `.obsidian` never appears (fs hides it); `showHidden: true` shows `.hidden` but never `.trash`.
- `rename_validation_test.dart` / `explorer_service_test.dart` (memory fs): create note → `Untitled.md` then `Untitled 1.md`, expanded + selected + renaming set; create folder naming; rename note `A.md` → `B` gives `B.md`; typing `B.md` gives `B.md` (no double extension); rename folder `F` → `G` moves children and retargets an open tab history entry `F/x.md` → `G/x.md` and the store key; rename to an existing name → `FileConflictException`; case-only rename `a.md` → `A.md` allowed (`MemoryVaultFileSystem(caseInsensitive: true)`); invalid names (`a/b`, `a:b`, `''`, `con`) rejected with the right codes; dirty buffer is flushed before the move (doc `savedText` equals the edited text after rename); `move` into a descendant is refused; `move` conflict; `duplicate` byte-exact for a CRLF+BOM file and `Name 1.md` then `Name 2.md`; `delete` with each `TrashMode` (vault trash path, collision suffix; permanent; system with a fake trash returning true/false); delete closes tabs and drops docs; the notice snackbar appears after rename and after move.
- `explorer_pane_test.dart` (1200 dp and 400 dp): toolbar buttons exist; tap folder expands (children appear), tap again collapses; tap a note opens it (workspace state); active note row highlighted; right-click shows the note menu with exactly the 8 entries (Windows reveal entry only when `Platform.isWindows` — inject `bool isWindows` parameter default real value; test both); long press on phone shows the bottom sheet; delete flow shows the correct body text for each trash mode and the unsaved warning; inline rename: Enter commits, Escape cancels, blur with valid text commits, invalid name shows error and stays; drag a note onto a folder moves it (`TestGesture`); dragging onto its own parent does nothing; hovering 600 ms over a collapsed folder expands it (`tester.pump(Duration(milliseconds: 650))`); keyboard Up/Down/Enter/F2/Delete.
- `move_to_dialog_test.dart`: lists folders only; disabled targets (current parent and descendants of a moved folder); selecting enables Move here; result path returned.
- `explorer_commands_test.dart`: all 7 commands registered with the right default shortcuts (`F2` for rename); `note.reveal-in-explorer` unavailable without an active note and on non-Windows; `explorer.reveal-active-file` expands ancestors.

**Verify** `cd app; flutter test test/explorer; cd ..`; manual (Windows, copy of the syntax vault): create, rename (inline), drag a note into `Folder`, duplicate, delete to `.trash` (check the file under `<vault>\.trash\`), reveal in Explorer opens the folder with the file selected. Commit `phase 01.17: add file explorer`.

**Pitfalls**
- Windows case-only rename goes through the temp-name path inside `fs.move` (01.4); the service must not pre-check `exists` for case-only changes (`to.caseKey == from.caseKey`).
- Always flush dirty buffers before moving or renaming; otherwise the debounced save later writes to a path that no longer exists.
- A folder move retargets **every** open document and tab inside it (prefix rule), not just the folder path.
- Never delete `.trash` contents automatically.
- `Draggable` inside a scrolling list needs `LongPressDraggable` on touch devices — on phone width use no drag at all (the *Move to…* dialog is the only move UI); decide by width ≥ 840, not by platform.

---

### 01.18 Editor: `EditorController`, engine adapter, Source mode with syntax highlighting

**Purpose** The Source-mode editor on the engine chosen in `docs/decisions/0001-editor-engine.md` (`ENGINE` in `PROGRESS.md`), behind an engine-independent `EditorController` so nothing else depends on the engine (Phase 0's hand-off calls this step "01.18"). This step delivers: the controller API Phase 2 relies on, the engine adapter, parse-driven highlighting, note view mode switching, undo/redo, focus and caret APIs. Editing helpers (auto-pair, lists, shortcuts) are step 01.19.

**Files** (under `app/lib/editor/`)
- `line_view.dart`, `editor_options.dart`, `editor_engine.dart`, `editor_controller.dart`, `editor_registry.dart`, `providers.dart`, `source_editor_view.dart`, `offset_map_utils.dart`
- `engine/re_editor_engine.dart` **(only if `ENGINE` = A)** or `engine/textfield_engine.dart` **(only if `ENGINE` = B)** — create exactly one of them
- `highlight/source_highlighter.dart`, `highlight/span_extractor.dart`, `highlight/quick_styler.dart`, `highlight/source_styles.dart`
- modify `app/lib/workspace/note_view.dart`, `app/lib/vault/note_document.dart` (add `parsed()`), `app/lib/vault/note_document_store.dart`
- tests: `app/test/editor/` (`line_view_test.dart`, `editor_controller_test.dart`, `span_extractor_test.dart`, `source_highlighter_test.dart`, `quick_styler_test.dart`, `source_editor_view_test.dart`, `editor_registry_test.dart`, `active_parsed_note_test.dart`) and `app/test/workspace/note_view_test.dart`

**Implementation**
1. `line_view.dart` — engine-independent coordinates used by every helper (pure Dart, no Flutter imports besides `TextSelection` where noted):
   ```dart
   final class LinePos { const LinePos(this.line, this.col); final int line; final int col; /* ==, hashCode, compareTo */ }   // col = UTF-16 offset inside the line
   final class EditorSelection { const EditorSelection(this.base, this.extent); final LinePos base; final LinePos extent; bool get isCollapsed; LinePos get start; LinePos get end; }
   abstract interface class LineView { int get lineCount; String lineAt(int index); }          // lines without '\n'
   final class ListLineView implements LineView { ListLineView(List<String> lines); ... }      // for tests and for text snapshots; ListLineView.fromText(String t) = t.split('\n')
   final class LineEdit { const LineEdit(this.start, this.end, this.text); final LinePos start; final LinePos end; final String text; }   // replace [start,end) by text; text may contain '\n'
   final class EditPlan { const EditPlan({this.edits = const [], required this.selection}); final List<LineEdit> edits; final EditorSelection selection; }  // edits are non-overlapping, expressed in pre-edit coordinates, applied as ONE undo step; selection is in post-edit coordinates
   int offsetOf(LineView v, LinePos p); LinePos posOf(LineView v, int offset);   // O(lines); only used off the typing path
   ```
   Test notation used by every helper test in this phase (a tiny parser `parseMarked(String)` / `renderMarked(...)` lives in `test/helpers/marked_text.dart`): `|` = collapsed caret; `⟦…⟧` = selection from `⟦` (base) to `⟧` (extent); `⏎` = newline. `applyPlan(String marked, EditPlan?)` returns the new marked text (or `null` when the plan is `null`).
2. `editor_options.dart`: `final class EditorOptions { const EditorOptions({this.useTab = true, this.tabSize = 4, this.fontSize = 16, this.readableLineLength = true, this.readOnly = false}); String get indentUnit => useTab ? '\t' : ' ' * tabSize; ... copyWith, ==}`; `editorOptionsProvider` derives it from `vaultSettingsProvider` (and `readOnly` is passed per document).
3. `editor_engine.dart` — the **only** place that knows what an engine must provide (the adapters implement it):
   ```dart
   final class EngineChange { const EngineChange({required this.start, required this.deletedLength, required this.insertedText, required this.isUndoRedo}); }   // UTF-16 offsets in the text BEFORE the change
   final class EngineInputHandlers {                      // supplied by EditorController, called by the adapter BEFORE the engine applies a user input; return true = handled (the controller already applied its own edit)
     bool Function(String typed) onTypedText;             // one or more typed characters at the current selection (typing, IME commit of plain text, but NOT paste)
     bool Function() onEnter; bool Function() onBackspace; bool Function(bool shift) onTab;
     Future<bool> Function() onPaste;                     // Ctrl+V / paste menu; true = handled (attachment); false = let the engine paste text
   }
   abstract interface class EditorEngine {
     LineView get lines;                                  // live view of the lines (no copies)
     String get text;                                     // full text, '\n'-normalised (O(n); not on the typing path)
     EditorSelection get selection;  set selection(EditorSelection s);
     void applyPlan(EditPlan plan);                       // all edits + selection as ONE undo step
     void replaceRange(int startOffset, int endOffset, String text);   // one undo step (used by EditorController.apply)
     void setText(String text, {required bool clearHistory});           // wholesale replacement (initial load / reload)
     bool get canUndo; bool get canRedo; void undo(); void redo(); void clearUndoHistory();
     Stream<EngineChange> get changes;                    // one event per text change, including undo/redo (isUndoRedo = true)
     Stream<void> get selectionChanges; Stream<bool> get focusChanges;
     void requestFocus(); bool get hasFocus;
     void reveal(int offset, {required bool center});
     Rect? caretRectGlobal();
     void setHighlighter(SourceHighlighter highlighter);  // the engine asks it for per-line ranges when it paints a line
     void repaintLines(int firstLine, int lastLine);      // after the highlighter changed
     Widget buildView(BuildContext context, EditorViewConfig config);   // config: EditorOptions, readOnly, TextStyle base, handlers, autofocus
     void dispose();
   }
   ```
   (Exactly one `EditorEngine` implementation exists in the final app; a fake `FakeEditorEngine` for tests lives in `test/helpers/fake_editor_engine.dart` — backed by a `List<String>` of lines with a naive undo stack.)
4. `editor_controller.dart` — **`EditorController` (the contract Phase 2 builds on; names fixed):**
   ```dart
   final class EditorController implements NoteEditorBinding {
     EditorController({required this.document, required EditorEngine engine, required EditorOptions options, required ParseService parseService, Clock clock = const SystemClock()});
     final NoteDocument document;
     VaultPath get path;                             // document.path (follows moves)
     String get text;                                // current buffer text, '\n'-normalised (O(n))
     TextSelection get selection;                    // UTF-16 offsets
     void select(int start, [int? end]);             // offsets; end defaults to start; clamps to [0, text.length]
     Stream<EditorEdit> get edits;                   // one event per text change: start, deletedLength, insertedText, isUndoRedo
     Stream<void> get selectionChanges;
     void apply(EditOperation op, {bool selectAfter = false});        // one undoable step; with selectAfter the caret is placed after the inserted text
     void applyEdits(List<EditOperation> ops);       // non-overlapping edits applied back-to-front as ONE undo step; the selection offsets are mapped through the edits
     bool get canUndo; bool get canRedo; void undo(); void redo();
     void replaceAll(String newText, {required bool keepCursor});     // as an undoable edit of the changed middle only; used by external-change reload/merge
     void revealOffset(int offset, {bool center = true});
     Rect? caretRectGlobal();                        // null when not laid out
     bool get isDirty;                               // document.isDirty
     bool get hasFocus; void focus();
     ParsedNote? get parsed;                         // last parse (may lag by ≤ 300 ms)
     Stream<ParsedNote> get parsedChanges;
     void updateOptions(EditorOptions o);
     Widget buildView(BuildContext context, {bool autofocus = false});
     void dispose();
   }
   final class EditorEdit { const EditorEdit({required this.start, required this.deletedLength, required this.insertedText, required this.isUndoRedo}); ... }
   ```
   **Naming note for Phase 2:** Phase 2 step 02.10 lists `applyEdits(List<TextEdit> edits)`; `TextEdit` (tephra_index, same fields `start, end, replacement`) does not exist yet, so Phase 1's parameter type is `EditOperation`. Phase 2 adapts at its call sites with `edits.map((e) => EditOperation(e.start, e.end, e.replacement)).toList()` (recorded in the Hand-off section and in `PROGRESS.md` → Conflicts).
   Behaviour:
   - Construction: `document.attachEditor(this)` (if the document already has an editor, the constructor throws `StateError`; the view checks `document.editor == null` first, see 8); registers in `EditorRegistry`; sets `engine.setText(document.text, clearHistory: true)`; subscribes: `engine.changes` → (a) `document.notifyEditorChanged()`, (b) emit `EditorEdit` on `edits`, (c) `highlighter.onEdit(change, lines)`, (d) restart the 250 ms parse timer; `engine.selectionChanges` → re-emit; `engine.focusChanges` → on blur `unawaited(document.save())` (step 01.20 relies on this; the call is already correct now).
   - `text`: `engine.text`. `selection`: `posOf` → offsets. `select`: offsets → `LinePos` via `LineView` (clamped).
   - `apply(op)`: `engine.replaceRange(op.start, op.end, op.replacement)`; with `selectAfter` the caret moves to `op.start + op.replacement.length`.
   - `applyEdits(ops)`: validate against `text` (`isValidFor`, non-overlap — sort by start; overlap → `ArgumentError`); convert to one `EditPlan` of `LineEdit`s (pre-edit coordinates) with the selection mapped through the edits: each selection offset `o`: `o ≤ edit.start` unaffected; `o ≥ edit.end` shifted by `delta`; inside the deleted range → `edit.start + min(o - edit.start, edit.replacement.length)`; `engine.applyPlan(plan)`.
   - `replaceAll(newText, keepCursor)`: if `newText == text` → nothing. `prefix`/`suffix` = longest common prefix/suffix (suffix limited so prefix + suffix ≤ min length); the single edit `EditOperation(prefix, oldLen - suffix, newText.substring(prefix, newLen - suffix))` is applied via `applyEdits` (one undo step) and, when `keepCursor`, selection offsets map as: `o ≤ prefix` → `o`; `o ≥ oldLen - suffix` → `o + (newLen - oldLen)`; otherwise `prefix + min(o - prefix, middleLen)`. `keepCursor == false` → caret to 0. The vertical scroll position is preserved by the engine (re-reveal the caret only if it left the viewport).
   - `undo()/redo()`: engine; `edits` events carry `isUndoRedo: true`.
   - Parse loop: after 250 ms without changes: `parsed = await parseService.parse(text)` — `document.parsed()` is used instead so the parse is shared (6); result applied to the highlighter only when `document.revision` still equals the revision at request time; then `parsedChanges.add`.
   - `dispose()`: cancel timers/subscriptions, `document.detachEditor(this)`, unregister from the registry, close streams, `engine.dispose()`.
   - Public API must not expose the engine type. `EditorController` is the only class outside `engine/` and `source_editor_view.dart` that touches `EditorEngine`.
5. `editor_registry.dart`: `final class EditorRegistry extends ChangeNotifier { void register(EditorController c); void unregister(EditorController c); EditorController? controllerFor(VaultPath path); Iterable<EditorController> get all; }` (paths follow `document.path`, so lookups work after a rename). `providers.dart`:
   | Provider | Declaration |
   |---|---|
   | `editorRegistryProvider` | `Provider<EditorRegistry>` (one per vault session) |
   | `editorOptionsProvider` | `Provider<EditorOptions>` derived from `vaultSettingsProvider` |
   | `activeEditorProvider` | `Provider<EditorController?>`: `registry.controllerFor(activeNotePath)`; rebuilds when the registry notifies (`registry.addListener(ref.invalidateSelf)` removed in `ref.onDispose`) |
   | `activeParsedNoteProvider` | `NotifierProvider<ActiveParsedNoteNotifier, ParsedNote?>` — the parse of the focused note, re-parsed 300 ms after the last change; `null` when no note is focused or before the first parse. Implementation: `build()` watches `activeNotePathProvider`; acquires `noteDocumentProvider(path)`; adds a listener to the document that restarts a 300 ms timer; on fire `state = await doc.parsed()` if `doc.revision` is unchanged; disposes the listener/timer in `ref.onDispose`. Reading view and editor share the memoised `doc.parsed()` |
   | `pendingJumpProvider` | `NotifierProvider<PendingJumpNotifier, PendingJump?>` — `PendingJump { VaultPath path; String? heading; String? blockRef; int? offset }` set by link navigation and consumed (set to `null`) by whichever view of that path is built next |
6. `NoteDocument.parsed()` (add to `note_document.dart`): `Future<ParsedNote> parsed()` memoised per `revision` (`_parsedRevision`, `_parsedFuture`), uses `ParseService`; a newer revision invalidates the memo. `NoteDocument` receives the `ParseService` through its constructor (default `const ParseService()`), set by `NoteDocumentStore`.
7. **Highlighting** (`highlight/`):
   - `source_styles.dart`: `enum SourceToken { text, headingMarker, heading1, heading2, heading3, heading4, heading5, heading6, strong, emphasis, strikethrough, highlight, emphasisMarker, inlineCode, codeBlock, codeFence, wikiBracket, wikiTarget, linkText, linkUrl, autolink, tag, blockId, comment, quoteMarker, quote, listMarker, taskBox, html, mathInline, mathBlock, frontmatter, footnote, tableBorder, tableHeader, thematicBreak, calloutMarker, findMatch, findCurrent }` and `TextStyle styleFor(SourceToken t, ThemeData theme, TextStyle base)`: headings `w700` coloured `colorScheme.primary` (h1–h2) / `onSurface` (h3–h6), sizes unchanged (Source mode keeps one size); `headingMarker`, `emphasisMarker`, `wikiBracket`, `linkUrl`, `blockId`, `quoteMarker`, `codeFence`, `tableBorder`, `thematicBreak`, `comment`, `html`, `frontmatter` → `onSurfaceVariant` at 70 % opacity (comment also italic); `strong` w700; `emphasis` italic; `strikethrough` line-through; `highlight` background highlight colour; `inlineCode`/`codeBlock`/`mathInline`/`mathBlock` → monospace family with `codeBackground`; `wikiTarget`/`linkText`/`autolink`/`footnote` → `primary`; `tag` → `primary` + tag background; `listMarker` → `primary` w700; `taskBox` → `primary`; `calloutMarker` → `tertiary` w700; `findMatch` background `tertiaryContainer`, `findCurrent` background `tertiary` at 55 %.
   - `span_extractor.dart`: `List<StyledSpan> extractSpans(ParsedNote parsed)` with `StyledSpan { int start; int end; SourceToken token; }` (document offsets), **pre-order** (outer spans first, inner later), using only the AST ranges:
     frontmatter → one `frontmatter` span; `MdHeading`: ATX → `headingMarker` for the `#` run (+ the following space), whole node `heading<level>`; setext → whole node `heading<level>` and the underline line `headingMarker`;
     `MdStrong`/`MdEmphasis`/`MdStrikethrough`/`MdHighlight`: whole node token + `emphasisMarker` for the first and last `m` chars (`m` = 2 for strong, `~~`, `==`; 1 for emphasis; if the node text starts with `***` treat as nested — nodes already nest so each node's own marker length applies);
     `MdInlineCode` whole `inlineCode` (+ `emphasisMarker` on the backtick runs: run length = count of leading backticks); `MdWikiLink` whole `wikiTarget`, `emphasisMarker`-like `wikiBracket` on the leading `![[`/`[[` and trailing `]]`; `MdLink` whole `linkText`, `linkUrl` on the part after the last child's end (the `](…)` tail) or after `[` end for reference links, image `!` as `wikiBracket`; `MdAutolink` `autolink`; `MdTag` `tag`; `MdBlockId` `blockId`; `MdInlineMath` `mathInline`; `MdFootnoteRef`/`MdInlineFootnote` `footnote`; `MdCommentInline`/`MdCommentBlock` `comment`; `MdHtmlInline`/`MdHtmlBlock` `html`;
     `MdCodeBlock`: whole `codeBlock`; for fenced blocks the first and last lines `codeFence`; `MdMathBlock` `mathBlock`; `MdThematicBreak` `thematicBreak`; `MdBlockQuote`/`MdCallout`: for each source line inside the node range, the leading run of `>` characters and spaces `quoteMarker`; a callout's first-line `[!type]±` `calloutMarker`; `MdListItem`: from the item start to the first child start (marker and spaces; for tasks up to the checkbox) `listMarker`, and the `[c]` box `taskBox` (range `statusOffset-1 .. statusOffset+len+1`); `MdTable`: every unescaped `|` in the table's lines `tableBorder`, header row cells `tableHeader`, the delimiter row `tableBorder`; `MdFootnoteDefinition`: `[^label]:` `footnote`.
   - `source_highlighter.dart`: holds `List<List<RangeStyle>> _lines` (per line, sorted, non-overlapping runs in line-relative columns) and a `Set<int> _dirtyLines`, plus `List<OverlayRange> _overlays` (find matches, set by step 01.19). API:
     `void applyParse(ParsedNote parsed, {required int revision})`: converts `extractSpans(parsed)` into per-line runs: for each span split at line boundaries using `parsed.lines` (`LineIndex`); runs are produced by an event sweep over span boundaries so that overlapping spans yield **merged** styles (outer first, inner overrides: store the **list of tokens** per run in order; `styleFor` merges them with `TextStyle.merge`); clears `_dirtyLines`.
     `void onEdit(EngineChange e, LineView lines)`: splice `_lines`: compute first changed line `L0` and old/new line counts from the change (`deletedLength`/`insertedText` newline counts and the start position); remove the old lines' entries and insert empty entries for new lines; mark every touched line dirty.
     `TextSpan spanFor(int line, String lineText, TextStyle base, ThemeData theme)`: if the line is dirty or has no entry → `QuickStyler.style(lineText)` runs (below); else the stored runs; overlays are layered on top; output is a `TextSpan(style: base, children: [...])` with one child per run; results are cached per `(line, lineText.hashCode, revision)` and the cache is cleared when the theme changes.
     `String? lineKind(int line)`: `'code'` when the stored runs of the line contain `codeBlock`/`mathBlock`/`frontmatter` (used by auto-pair to disable itself inside code).
   - `quick_styler.dart`: `List<RangeStyle> QuickStyler.style(String line)` — a **line-local** regex styler used only for dirty lines until the next parse (≤ 300 ms): `^(#{1,6})(\s)` → marker + heading; `` `[^`]+` `` → inline code; `\*\*[^*]+\*\*` → strong; `(?<![*\w])\*[^*\s][^*]*\*` → emphasis; `\[\[[^\]]+\]\]` → wikilink; `(?<![\w/])#[\p{L}\p{N}_/-]*[\p{L}_/-][\p{L}\p{N}_/-]*` → tag; `==[^=]+==` → highlight; `^\s*([-*+]|\d{1,9}[.)])\s` → list marker; `^\s*>+` → quote marker. Output must be consistent with the final parse for these simple cases (tested).
8. **View** (`source_editor_view.dart`): `SourceEditorView({required VaultPath path, required String tabId, ...})` (`ConsumerStatefulWidget`):
   - `initState`: `doc = ref.read(noteDocumentProvider(path))`; if `doc.editor != null` (the note is already being edited in another tab/pane) → show `ReadingView` of `doc.text` under a banner (key `note.openElsewhere`, text `noteOpenElsewhere`: "This note is being edited in another tab.") and rebuild into the editor when `doc.editor` becomes `null` (listen to `doc`).
   - Otherwise: wait for `doc.isLoaded`; create the engine adapter (the one file of `engine/`), the `EditorController` (`parseService` from `parseServiceProvider`), call `controller.buildView(context, autofocus: autofocus)`; the engine view is wrapped in a `Center` + `ConstrainedBox(maxWidth: 760)` when `options.readableLineLength` and the width > 840 dp, with horizontal padding 16 (phone) / 32 (desktop) and bottom padding 96; keyboard-avoiding is handled by the scaffold (`resizeToAvoidBottomInset: true`).
   - `didUpdateWidget` / settings changes → `controller.updateOptions`. `dispose` → `controller.dispose()`.
   - Read-only (malformed UTF-8): the adapter is built with `readOnly: true` and the banner `noteMalformedBanner` stays visible (01.15).
   - `pendingJumpProvider`: after load, if a jump for this path exists: `heading` → find the first heading in `await doc.parsed()` whose normalised text equals the normalised query → `select(h.start)` + `revealOffset(h.start)`; `blockRef` → the matching `BlockRef` → its owner `start`; `offset` → that offset; then clear it.
   - Autofocus: `autofocus` is true when the tab was just created by `note.create-note`/quick-switcher create (a one-shot `NotifierProvider<…, bool>` named `focusEditorOnOpenProvider` in `editor/providers.dart`; in this step update `note.create-note` and the quick switcher's create action to set it to `true` before opening the note, and the view resets it to `false` after consuming it) — otherwise the editor does not steal focus from the explorer.
   `NoteView` (modify): mode `reading` → `NoteReadingView`, mode `source` → `SourceEditorView`; both under a `KeyedSubtree(key: ValueKey('${tab.id}:${mode.name}'))`. When the mode changes the **position** is carried over: the old view reports its offset (reading: `topOffset`; source: caret offset) through callbacks into `NoteView` state `_lastOffset`, which the new view receives as `initialOffset` (reading) / initial `select`+`revealOffset` (source).
9. **Engine adapter — `ENGINE` = A (`re_editor`)** (`engine/re_editor_engine.dart`, `class ReEditorEngine implements EditorEngine`). The class and method names below are the expected `re_editor` API; **check each against `ENGINE_HOOKS` (docs/spikes/editor.md "API notes") and the installed package source (`re_editor-<version>/lib/`) and use the real name where it differs — the behaviour contract is binding, the identifier spelling is not.**
   1. Controller: `class TephraCodeController extends CodeLineEditingController`, created with `CodeLineEditingController.fromText(text, CodeLineOptions(indentSize: options.tabSize, lineBreak: TextLineBreak.lf))` so `text` and `codeLines` use `\n`. Override `buildTextSpan({context, index, textSpan, style})` to return `highlighter.spanFor(index, textSpan.toPlainText(), style, Theme.of(context))` (this is the per-line hook the spike exercised).
   2. Intercepting user input: override `applyNewLine()` → `if (handlers.onEnter()) return; super.applyNewLine();`; `applyIndent()` → `if (handlers.onTab(false)) return; super.applyIndent();`; `applyOutdent()` → `if (handlers.onTab(true)) return; super.applyOutdent();`; the typed-text entry (`edit(TextEditingValue)` or the method `ENGINE_HOOKS` names): when the new value differs from the old one by exactly one inserted run **with no deleted text other than the current selection** and the inserted run is not a newline and the change is not a composing (IME) update (`value.composing.isValid && !value.composing.isCollapsed` → never intercept), call `handlers.onTypedText(run)` first; the backspace entry (`deleteBackward()` or the named hook) → `if (selection.isCollapsed && handlers.onBackspace()) return; super…`. Paste: wrap the engine's paste action (`CodeShortcutPasteIntent` override in `shortcutOverrideActions`) with `handlers.onPaste()`; if it returns `false`, call the original.
   3. Undo grouping: `applyPlan(plan)` converts each `LineEdit` to the controller's line/offset edit API and runs all of them inside the engine's revocable-operation helper (`runRevocableOp(() { … })`, per `ENGINE_HOOKS`) so Ctrl+Z reverts the whole plan; then sets `selection = CodeLineSelection(baseIndex, baseOffset, extentIndex, extentOffset)` from `plan.selection`. `replaceRange(startOffset, endOffset, text)` converts offsets via `posOf` and does the same inside one revocable op.
   4. Change stream: the controller notifies without a diff. The adapter keeps `List<String> _prev` (the line strings after the previous notification; copying references is O(lines) and cheap), and on every `addListener` callback computes `EngineChange` by comparing with the current `codeLines` — first differing line from the top, first differing line from the bottom (identity compare first, then `==`), the deleted/inserted text between them, and `start` = sum of previous line lengths + 1 each + the column of the first differing character; ignores notifications where the text is identical (pure selection moves → `selectionChanges`). `isUndoRedo` is true while `undo()`/`redo()` run (flag set around the calls).
   4b. `text` = `controller.text`; `lines` = a `LineView` over `controller.codeLines` (`lineAt(i) = codeLines[i].text`); `selection` ↔ `CodeLineSelection`.
   5. View: `CodeEditor(controller: …, wordWrap: true, readOnly: config.readOnly, autofocus: config.autofocus, focusNode: _focus, scrollController: _scroll, chunkAnalyzer: const NonCodeChunkAnalyzer(), indicatorBuilder: null, style: CodeEditorStyle(fontSize: options.fontSize, fontHeight: 1.5, textColor: …, backgroundColor: Colors.transparent, selectionColor: primary @ 30 %, cursorColor: primary), shortcutsActivatorsBuilder: _NoCommandShortcuts(), shortcutOverrideActions: {...})`. **`_NoCommandShortcuts`** keeps the engine's navigation/selection/copy/cut/select-all/delete shortcuts but returns `null` for every activator that corresponds to a registry command (undo, redo, find, bold, italic, link, save, tab-related) so those key events bubble up to `HotkeyHost` and run **commands** (step 01.14/01.19) instead of engine behaviour. The engine's own find UI is not used (no `findBuilder`).
   6. Focus: `_focus` is a `FocusNode`; `focusChanges` is derived from it. `reveal(offset)` → `controller.makeCursorVisible()` after moving the selection (or the scroll API per `ENGINE_HOOKS`); `caretRectGlobal()` → the engine's caret rectangle API if it exists, else `null` (documented limitation: then Phase 2's autocomplete popup anchors to the editor's top-left; write the limitation into `PROGRESS.md` if you cannot find a caret-rect API).
   7. `dispose`: dispose the controller, scroll controller and focus node.
9b. **Engine adapter — `ENGINE` = B (`TextField` + `buildTextSpan`)** (`engine/textfield_engine.dart`):
   1. `class TephraTextController extends TextEditingController` overriding `buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing})` to build one `TextSpan` whose children are `highlighter.spanFor(line, lineText, …)` for every line joined by `'\n'` spans (only lines intersecting the viewport are styled richly — keep a `visibleLineRange` set by the view from the scroll offset and line-height estimate; other lines use the base style) and ignoring `withComposing` only when the composing region is valid (then delegate to `super` for that line so IME composition underline keeps working).
   2. `LineStarts` cache (`List<int>`) rebuilt lazily when `value.text` changes (O(n) integer scan) to convert offsets ↔ `LinePos`; `lines` is a `LineView` over a lazily split `List<String>` rebuilt on change (O(n); acceptable only if the typing benchmark of 01.22 passes — if it does not, stop and ask the human: engine B cannot meet the 5,000-line budget without per-line rendering).
   3. Input interception: a `TextInputFormatter` (`formatEditUpdate(old, new)`) detects a typed run (single insertion at the old selection, composing region invalid) and backspace; it calls the handlers; when handled it returns the value produced by the handler's plan (the formatter must **not** call `applyPlan` re-entrantly: the handlers return the plan and the formatter applies it to a `TextEditingValue`); Enter: `CallbackShortcuts` for `LogicalKeyboardKey.enter` (not with Ctrl/Shift) → `handlers.onEnter`; Tab/Shift+Tab: `Shortcuts` + `Actions` replacing `NextFocusIntent`; paste: `Actions` override of `PasteTextIntent` calling `handlers.onPaste()`.
   4. Undo: `UndoHistoryController` of the `TextField` (Ctrl+Z/Y are commands, they call `undoController.undo()/redo()`); `applyPlan` sets `controller.value` once (one history entry). `changes` come from comparing `value.text` before/after with the same prefix/suffix diff as engine A.
   5. View: `TextField(controller:, undoController:, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: null, style: base, readOnly:, focusNode:, scrollController:, inputFormatters: […], contextMenuBuilder: default, keyboardType: TextInputType.multiline)`.
10. `FakeEditorEngine` + `EditorController` unit tests do not need Flutter widgets; `SourceEditorView` tests use the **real** engine on the Windows test host (the engine widgets are pumpable in `flutter test`).
11. l10n keys: `noteOpenElsewhere`, `editorReadOnlyHint`, `modeReadingTooltip`, `modeSourceTooltip`.

**Tests**
- `line_view_test.dart`: `offsetOf`/`posOf` round trip over `'a\nbc\n\nd'` for every offset; emoji line; `ListLineView.fromText('')` has 1 line; `parseMarked`/`renderMarked` round trip for `a⟦b⏎c⟧d`, `|`, `⟦⟧`.
- `editor_controller_test.dart` (with `FakeEditorEngine` and a memory-fs `NoteDocument`): construction attaches to the document (`doc.editor == controller`, registry has it); `apply(EditOperation(0,0,'# '))` changes `text`, emits one `EditorEdit(start 0, deletedLength 0, insertedText '# ', isUndoRedo false)` and `doc.revision` increments and `doc.saveState == unsaved`; `applyEdits` with two edits is **one** undo step (`undo()` restores the original); overlapping edits throw `ArgumentError`; selection mapping through edits (selection after an insertion before it shifts, inside a deleted range clamps); `undo`/`redo` emit `isUndoRedo: true`; `replaceAll` changes only the middle (assert the single emitted edit's `start`/`deletedLength`) and maps the cursor (before change stays, after change shifts, inside clamps); `replaceAll(keepCursor: false)` → caret 0; `select(5)` beyond length clamps; `dispose` detaches (`doc.editor == null`) and unregisters; a second controller on the same document throws `StateError`; **edit then undo to original then `doc.save()` writes nothing**; blur (`FakeEditorEngine.setFocus(false)`) triggers `doc.save()` (fs writeCount 1 when dirty, 0 when clean).
- `span_extractor_test.dart`: for each of: `# H`, `Setext⏎===`, `**b**`, `*i*`, `~~s~~`, `==h==`, `` `c` ``, `[[A|B]]`, `![[a.png]]`, `[t](u)`, `<http://x>`, `#tag`, `text ^id`, `$x$`, `[^1]`, `%%c%%`, `<b>`, a fenced block, a math block, `---`, a quote, a callout, a task item, a table, a footnote definition, frontmatter → the exact ordered `(start, end, token)` list (write them in the test; the order is the pre-order of the AST, and for each node its own token first, then its marker spans: `**b**` → `[(0,5,strong),(0,2,emphasisMarker),(3,5,emphasisMarker)]`; `# H` → `[(0,3,heading1),(0,2,headingMarker)]`).
- `source_highlighter_test.dart`: `applyParse` then `spanFor` for a multi-line fenced block gives `codeBlock` on every line and `codeFence` on the first/last; a bold word inside a heading merges `heading1`+`strong`; stale revision (`applyParse` with an older revision) is ignored; `onEdit` inserting a line shifts later lines' runs down by one; an edited line is dirty (uses `QuickStyler`) until the next `applyParse`; overlays layer above; `lineKind` is `code` inside fences.
- `quick_styler_test.dart`: each regex case from 7 yields the same tokens that `extractSpans` yields for the same single-line input (loop over 12 samples and compare token sets).
- `source_editor_view_test.dart` (real engine, 1200 dp and 400 dp): loads text into the editor (`find.textContaining('# Heading')`); typing a character with `tester.enterText`/`sendKeyEvent` marks the document dirty; the second view of a document that already has an editor shows the `note.openElsewhere` banner and switches to the editor after the first is disposed; read-only document → typing does nothing; `pendingJump` heading moves the caret to the heading's offset; options change (`tabSize`) does not rebuild the document text.
- `editor_registry_test.dart`: register/unregister notify listeners; `controllerFor` follows a path change after `store.retargetPath`.
- `active_parsed_note_test.dart`: with a focused note the provider yields its parse after 300 ms; editing the document re-parses (headings count changes); switching the focused tab switches the parse; no focused note → `null`.
- `note_view_test.dart`: toggling mode keeps the position (`ReadingView.initialOffset` receives the editor caret offset); `reading` ↔ `source` keeps the same `NoteDocument` instance; an unsaved edit survives a mode toggle; a missing file shows the missing state.

**Verify** `cd app; flutter test test/editor test/workspace; cd ..` + standard checks; `flutter run -d windows` with a copy of the syntax vault: open `01-headings.md`, press Ctrl+E → Source mode with coloured syntax; type; Ctrl+E back → the reading view shows the edit; the tab dot shows while unsaved (dirty dot arrives in 01.20). Commit `phase 01.18: add EditorController, engine adapter and Source mode`.

**Pitfalls**
- Nothing outside `engine/` and `source_editor_view.dart` may import `package:re_editor` (or reference `TextField` as the engine). A lint-like test: `app/test/editor/engine_isolation_test.dart` greps `app/lib` for `package:re_editor` and asserts that only `app/lib/editor/engine/*.dart` contain it (for engine A; for engine B assert no other file defines a `TephraTextController`).
- The typing path (`onTypedText`, `onEnter`, …) must not call `engine.text`; use `LineView` only.
- Never call `document.save()` from a change listener (autosave is timer-based, step 01.20); blur is the only immediate save.
- Do not log note text.

---

### 01.19 Editing helpers, shortcuts, commands, find & replace

**Purpose** The editing behaviours of Source mode as pure, fully tested functions over `LineView`, wired into the controller and into the command registry; plus find & replace.

**Files** (under `app/lib/editor/`)
- `helpers/auto_pair.dart`, `helpers/list_continuation.dart`, `helpers/indentation.dart`, `helpers/inline_format.dart`, `helpers/block_format.dart`, `helpers/line_moves.dart`, `helpers/list_patterns.dart`, `helpers/word_at.dart`
- `editor_input_handlers.dart` (wires the helpers into `EngineInputHandlers`), `editor_commands.dart`
- `find/find_options.dart`, `find/find_engine.dart`, `find/find_controller.dart`, `find/find_bar.dart`
- modify `editor_controller.dart` (handlers, `runCommand`-style methods), `highlight/source_highlighter.dart` (overlays), `commands/providers.dart` (`registerEditorCommands`)
- tests: `app/test/editor/helpers/` (`auto_pair_test.dart`, `list_continuation_test.dart`, `indentation_test.dart`, `inline_format_test.dart`, `block_format_test.dart`, `line_moves_test.dart`), `app/test/editor/find_engine_test.dart`, `find_bar_test.dart`, `editor_commands_test.dart`, `editor_shortcuts_test.dart`, `test/helpers/marked_text.dart` (from 01.18)

**Implementation** — every helper is a **pure function** returning `EditPlan?` (`null` = "not handled, let the engine do its default"). All use the marked-text notation of 01.18 in their tests. "Line" = one `\n`-delimited line; `prev`/`next` = the characters immediately before/after the selection **on the same line** (`null` at a line edge); "word character" = `\p{L}`, `\p{N}`, `\p{M}` or `_`.

1. `list_patterns.dart`: `ListLine? parseListLine(String line)` with the regex `^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(?:\[(.)\]([ \t]+))?` → `ListLine { String indent; String marker; bool ordered; int number; String delimiter; String gap; String? taskChar; String? taskGap; int contentStart }` (`contentStart` = end of the match; `taskChar` is one code point). A line that is only a marker (`-`, `1.`) with no following space is **not** a list line. `-` followed by tab counts (the gap is the tab).
2. **Auto-pair** (`auto_pair.dart`) — table: `(`→`)`, `[`→`]`, `{`→`}`, `"`→`"`, `` ` ``→`` ` ``, `*`→`*`, `_`→`_` (no `'`, no `$`, no `~`, no `=`):
   ```dart
   final class AutoPairTracker { void add(LinePos closerPos); bool contains(LinePos p); void remove(LinePos p); void onEdit(LineEdit e); void prune(LineView v); void clear(); }
   EditPlan? autoPairOnType(LineView v, EditorSelection sel, String typed, AutoPairTracker t, {bool disabled = false});
   EditPlan? autoPairOnBackspace(LineView v, EditorSelection sel, AutoPairTracker t, {bool disabled = false});
   ```
   Rules in order for a **single typed character** `c` (anything longer, or `disabled`, → `null`):
   - **R1 wrap**: selection non-empty and `c` is one of the seven opening characters → insert `c` at the start and its closer at the end; the selection afterwards covers the original text (shifted by 1 on the start line, by 1 on the end position if on the same line).
   - **R2 skip-over**: selection empty, `c ∈ {')', ']', '}', '"', '`', '*', '_'}`, `next == c` and `t.contains(position of next)` → no edits, caret +1, `t.remove(...)`.
   - **R3 auto-close**: selection empty, `c` is an opening character, and `next` is `null`, whitespace, or one of `) ] } , . ; : ! ?`; for the symmetric characters (`"`, `` ` ``, `*`, `_`) additionally `prev` is `null`, whitespace, or one of `( [ { > , ; :`. Edit: insert `c` + closer at the caret; caret between them; `t.add(position of the inserted closer)`.
   - **R4**: otherwise `null`.
   - **Backspace**: selection empty, `prev` is an opening character, `next` is its closer, and `t.contains(position of next)` → delete both characters; `t.remove`. Otherwise `null`.
   `AutoPairTracker.onEdit(LineEdit)` is called by the controller for **every** engine change (map each tracked position through the edit: positions before the edit unchanged; after it on the same line shifted by the column delta; on later lines shifted by the line delta; inside the replaced range removed); `prune` drops entries whose character is no longer a closer. `disabled` is true when `highlighter.lineKind(line) == 'code'` or the editor is read-only.
   Tests (`input ⇒ output`, `typed` in brackets; `—` = not handled/`null`):
   ```
   |  [type (]  ⇒ (|)
   a|  [type (]  ⇒ a(|)
   |b  [type (]  ⇒ —
   ⟦ab⟧  [type (]  ⇒ (⟦ab⟧)
   ⟦ab⟧  [type *]  ⇒ *⟦ab⟧*
   ⟦ab⟧  [type "]  ⇒ "⟦ab⟧"
   |  [type *]  ⇒ *|*
   x |  [type *]  ⇒ x *|*
   a|  [type *]  ⇒ —
   snake|  [type _]  ⇒ —
   |  [type `]  ⇒ `|`
   (|) tracked  [type )]  ⇒ ()|
   (|) untracked  [type )]  ⇒ —
   "|" tracked  [type "]  ⇒ ""|
   *|* tracked  [type *]  ⇒ **|
   don|  [type ']  ⇒ —
   |  [type $]  ⇒ —
   |  [type ~]  ⇒ —
   (|  [type [] ⇒ ([|]
   a (|  [type (]  ⇒ a ((|)
   [|] tracked  [backspace]  ⇒ |
   [|] untracked  [backspace]  ⇒ —
   a(|) tracked  [backspace]  ⇒ a|
   (|  [backspace]  ⇒ —
   |  [type (]  disabled ⇒ —
   |  [type ab]  ⇒ —
   ```
   (`tracked` means the closer's position is in the tracker, set up by the test; in `(|  [type []` the caret is at the end of the line, so `next` is `null` and `[` pairs.) Plus tracker tests: `onEdit` shifts a tracked closer when text is inserted before it on the same line, when a line is inserted above, removes it when its character is deleted; `prune` drops stale entries.
3. **Enter continues lists** (`list_continuation.dart`): `EditPlan? listContinuationOnEnter(LineView v, EditorSelection sel, {int scanLimit = 500})`:
   - Not handled (`null`) unless the selection is empty and the caret line is a list line (`parseListLine`) and `col >= contentStart`.
   - **Empty item** (the text after `contentStart` is blank): replace the whole line (`col 0` … end of line) with `''`; caret at column 0 (the list ends).
   - Otherwise split at the caret: `before = line[0:col]`, `after = line[col:].trimLeft()` (leading spaces of the moved text removed; the replaced range is `[col, endOfLine]`). New line text = `'\n' + indent + nextMarker + gap + (task ? '[ ] ' with the original taskGap : '') + after`. `nextMarker`: bullet → the same character; ordered → `(number + 1)` + original delimiter. A task always continues as an **open** task (`[ ] `) whatever the previous status. Caret after the new prefix.
   - **Renumbering** (ordered lists only): starting at the line below the caret line with `expected = number + 2`: skip blank lines and lines whose indent is **longer** than the item's indent; a line that is an ordered list line with the **same indent string** and the same delimiter and whose number equals `expected - 1` is rewritten with `expected` (`expected++`); stop at the first other line; examine at most `scanLimit` lines. The renumber edits are extra `LineEdit`s of the same plan (non-overlapping, later lines).
   Tests:
   ```
   - a|  ⇒ - a⏎- |
   - a|b  ⇒ - a⏎- |b
   * a|  ⇒ * a⏎* |
   + a|  ⇒ + a⏎+ |
   1. a|  ⇒ 1. a⏎2. |
   9. a|  ⇒ 9. a⏎10. |
   1) a|  ⇒ 1) a⏎2) |
   1. a|⏎2. b⏎3. c  ⇒ 1. a⏎2. |⏎3. b⏎4. c
   1. a|⏎   - sub⏎2. b  ⇒ 1. a⏎2. |⏎   - sub⏎3. b
   1. a|⏎2. b⏎5. c  ⇒ 1. a⏎2. |⏎3. b⏎5. c
   - [ ] a|  ⇒ - [ ] a⏎- [ ] |
   - [x] a|  ⇒ - [ ] a⏎- [ ] |
   - [/] a|  ⇒ - [ ] a⏎- [ ] |
     - a|  ⇒   - a⏎  - |
   →- a|  ⇒ →- a⏎→- |
   -→a|  ⇒ -→a⏎-→|
   - |  ⇒ |
   1. |  ⇒ |
   ··- [ ] |  ⇒ |            (·· = two spaces)
   - a|  with a selection ⟦a⟧ ⇒ —
   a|  ⇒ —
   -a|  ⇒ —
   ---|  ⇒ —
   |- a  ⇒ —                  (caret before the marker)
   - |a  ⇒ - ⏎- |a           (caret exactly at contentStart: the part before stays as an empty bullet line)
   ```
   (`→` = tab; `·` = space in the notation where trailing/leading spaces must be visible.)
4. **Tab / Shift+Tab** (`indentation.dart`): `EditPlan? indentOnTab(LineView v, EditorSelection sel, EditorOptions o, {required bool shift})`:
   - Affected lines: `start.line … end.line`; if the selection spans more than one line and `end.col == 0`, the last line is **excluded**. A single caret line is "affected" for list lines and for Shift+Tab.
   - **Tab** (not shift): if more than one line is affected **or** the caret line is a list line → insert `o.indentUnit` at column 0 of every affected **non-blank** line; selection positions with `col >= 1` on affected lines shift by `unit.length`; a position at column 0 stays at column 0. Otherwise (a plain-text caret or a selection inside one line) → replace the selection with `o.indentUnit` (caret after it).
   - **Shift+Tab**: on every affected line remove one indent step: if the line starts with `\t` remove it, else remove `min(leadingSpaces, o.tabSize)` spaces; lines without indentation are unchanged. Positions on the line move left by the removed count (not below column 0). If nothing changed the plan has **no edits** but is still returned (the key is consumed).
   Tests (`useTab=true,tabSize=4` unless noted; `→` tab):
   ```
   - a|  [tab]  ⇒ →- a|
   a|  [tab]  ⇒ a→|
   ⟦a⏎b⟧  [tab]  ⇒ ⟦→a⏎→b⟧
   ⟦a⏎⟧b  [tab]  ⇒ ⟦→a⏎⟧b
   ⟦a⏎→b⟧  [tab]  ⇒ ⟦→a⏎→→b⟧
   ⟦a⏎⏎b⟧  [tab]  ⇒ ⟦→a⏎⏎→b⟧           (blank line skipped)
   →- a|  [shift-tab]  ⇒ - a|
   ····- a|  [shift-tab]  ⇒ - a|
   ··- a|  [shift-tab]  ⇒ - a|
   - a|  [shift-tab]  ⇒ - a|            (handled, no edit)
   ⟦→a⏎→b⟧  [shift-tab]  ⇒ ⟦a⏎b⟧
   - a|  [tab, useTab=false, tabSize=4]  ⇒ ····- a|
   a|  [tab, useTab=false, tabSize=2]  ⇒ a··|
   ```
5. **Inline formatting toggles** (`inline_format.dart`): `enum InlineFormat { bold, italic, strikethrough, highlight, code }` with markers `**`, `*`, `~~`, `==`, `` ` ``; `EditPlan? toggleInlineFormat(LineView v, EditorSelection sel, InlineFormat f)`; `EditPlan? insertLink(LineView v, EditorSelection sel)`.
   Algorithm for `toggleInlineFormat`:
   1. **Range**: non-empty selection → the selection (may span lines). Empty selection → the **word** around the caret on its line (`word_at.dart`: expand left and right over word characters; a caret at a word boundary touching a word counts as inside it); if there is no word, insert `marker marker` at the caret with the caret between and return.
   2. **Detect "already formatted" and unwrap** (single-line ranges only; multi-line ranges are always wrapped): let `runBefore` / `runAfter` be the number of consecutive marker-character repetitions immediately before the range start / after its end (for `**`, `*` → characters `*`; for `~~` → `~`; for `==` → `=`; for `` ` `` → `` ` ``).
      - bold: wrapped if `min(runBefore, runAfter) >= 2`; remove **2** on each side.
      - italic: wrapped if `min(runBefore, runAfter)` is **1 or 3** (odd ≥ 1); remove **1** on each side.
      - strikethrough / highlight: wrapped if `min(runBefore, runAfter) >= 2`; remove 2.
      - code: wrapped if `min(...) >= 1`; remove 1.
      - **inner** form (explicit non-empty selection only): if the selected text itself starts and ends with the marker run with the same rules (e.g. selection `**hello**` for bold) → replace the selection by its content minus the markers.
   3. Otherwise **wrap**: insert the marker before the start and after the end. The selection afterwards covers the original range (shifted by the marker length); for the word-at-caret case the caret keeps its position inside the word (shifted/unshifted accordingly).
   `insertLink`: non-empty selection that matches `^https?://\S+$` → `[](url)` with the caret inside `[]`; non-empty other selection → `[text](|)` with the caret inside the parentheses; empty selection → `[|]()`.
   Tests:
   ```
   hel|lo  [bold]  ⇒ **hel|lo**
   **hel|lo**  [bold]  ⇒ hel|lo
   ⟦hello⟧  [bold]  ⇒ **⟦hello⟧**
   **⟦hello⟧**  [bold]  ⇒ ⟦hello⟧
   ⟦**hello**⟧  [bold]  ⇒ ⟦hello⟧
   |  [bold]  ⇒ **|**
   a | b  [bold]  ⇒ a **|** b
   a |b  [bold]  ⇒ a **|b**
   hello|  [bold]  ⇒ **hello|**
   *hel|lo*  [italic]  ⇒ hel|lo
   hel|lo  [italic]  ⇒ *hel|lo*
   **hel|lo**  [italic]  ⇒ ***hel|lo***
   ***hel|lo***  [italic]  ⇒ **hel|lo**
   ***hel|lo***  [bold]  ⇒ *hel|lo*
   ⟦a⏎b⟧  [bold]  ⇒ **⟦a⏎b⟧**
   ⟦x⟧  [highlight]  ⇒ ==⟦x⟧==
   ==⟦x⟧==  [highlight]  ⇒ ⟦x⟧
   ⟦x⟧  [strikethrough]  ⇒ ~~⟦x⟧~~
   ⟦code⟧  [code]  ⇒ `⟦code⟧`
   `⟦code⟧`  [code]  ⇒ ⟦code⟧
   ⟦text⟧  [link]  ⇒ [text](|)
   ⟦https://a.com⟧  [link]  ⇒ [|](https://a.com)
   |  [link]  ⇒ [|]()
   ```
6. **Block formatting** (`block_format.dart`): `EditPlan? toggleBulletList(v, sel)`, `toggleNumberedList`, `toggleQuote`, `cycleHeading`, `toggleTaskStatus`. Affected lines as in rule 4 (last line excluded when the selection is multi-line and ends at column 0). Blank lines are skipped when several lines are affected; a single blank caret line is processed.
   - **bullet**: if every non-blank affected line is already a bullet list line (marker `-`, `*`, `+`, tasks included) → remove the marker, its gap and a task box (`[c] `) from each; else → each non-blank line that is not a bullet gets `- ` inserted after its indentation, **ordered list lines are converted** (their marker replaced by `- `), bullets stay.
   - **numbered**: if every non-blank affected line is an ordered list line → remove marker + gap; else number the non-blank affected lines `1. 2. 3.` in order (after indentation; existing list markers replaced).
   - **quote**: if every non-blank affected line starts with `>` (after optional indent) → remove one `> ` (or `>`) from each; else insert `> ` at column 0 of each (blank lines in a multi-line range get `>`).
   - **cycleHeading** (caret/extent line only): no heading → `# `; `#`×n (n < 6) followed by a space → `#`×(n+1); `######` → remove the heading marker.
   - **toggleTaskStatus** (Ctrl+Enter): per affected line: not a list line (non-blank) → insert `- [ ] ` after the indentation; list line without a task box → insert `[ ] ` after marker+gap; task with status `x`/`X` → `' '`; any other status (including `' '`, `/`, `-`, …) → `x`. A single blank caret line gets `- [ ] `.
   Caret rule: positions on a changed line shift by the inserted/removed prefix length; for removals a caret inside the removed prefix moves to the end of the remaining indentation.
   Tests:
   ```
   a|  [bullet]  ⇒ - a|
   - a|  [bullet]  ⇒ a|
   - [ ] a|  [bullet]  ⇒ a|
   1. a|  [bullet]  ⇒ - a|
   ⟦a⏎b⟧  [bullet]  ⇒ ⟦- a⏎- b⟧
   ⟦- a⏎b⟧  [bullet]  ⇒ ⟦- a⏎- b⟧
   ⟦a⏎b⟧  [numbered]  ⇒ ⟦1. a⏎2. b⟧
   1. a|  [numbered]  ⇒ a|
   - a|  [numbered]  ⇒ 1. a|
   a|  [quote]  ⇒ > a|
   > a|  [quote]  ⇒ a|
   ⟦a⏎⏎b⟧  [quote]  ⇒ ⟦> a⏎>⏎> b⟧
   a|  [heading]  ⇒ # a|
   ### a|  [heading]  ⇒ #### a|
   ###### a|  [heading]  ⇒ a|
   #a|  [heading]  ⇒ # #a|
   a|  [task]  ⇒ - [ ] a|
   - a|  [task]  ⇒ - [ ] a|
   - [ ] a|  [task]  ⇒ - [x] a|
   - [x] a|  [task]  ⇒ - [ ] a|
   - [/] a|  [task]  ⇒ - [x] a|
   |  [task]  ⇒ - [ ] |
   ⟦a⏎b⟧  [task]  ⇒ ⟦- [ ] a⏎- [ ] b⟧
   ```
7. **Line moves** (`line_moves.dart`): `EditPlan? moveLinesUp(v, sel)`, `moveLinesDown`, `duplicateLines`. Affected lines as in rule 4. `moveLinesUp`: if the first affected line is line 0 → `EditPlan(edits: [], selection: sel)` (consumed no-op); else replace the region `[start of the line above, end of the last affected line]` by `block + '\n' + above`; the selection moves up by one line (columns unchanged). `moveLinesDown` symmetrical (no-op when the last affected line is the last line of the document). `duplicateLines`: insert `'\n' + block` after the last affected line; the selection moves to the duplicated block (collapsed caret: same column on the new line).
   ```
   a⏎b|  [up]  ⇒ b|⏎a
   a|⏎b  [down]  ⇒ b⏎a|
   a|⏎b  [up]  ⇒ a|⏎b            (no-op)
   a⏎b|  [down]  ⇒ a⏎b|          (no-op)
   ⟦a⏎b⟧⏎c  [down]  ⇒ c⏎⟦a⏎b⟧
   a|  [duplicate]  ⇒ a⏎a|
   ⟦a⏎b⟧  [duplicate]  ⇒ a⏎b⏎⟦a⏎b⟧
   a|b  [duplicate]  ⇒ ab⏎a|b
   ```
8. **Wiring** (`editor_input_handlers.dart`): `EngineInputHandlers buildHandlers(EditorController c)`:
   - `onTypedText(typed)`: `autoPairOnType(...)` (`tracker`, `disabled` from `highlighter.lineKind`); plan → `c.engine.applyPlan(plan)` → `true`.
   - `onEnter()`: `listContinuationOnEnter` → apply → `true` (otherwise `false`).
   - `onBackspace()`: `autoPairOnBackspace`.
   - `onTab(shift)`: `indentOnTab(..., shift: shift)` → apply → `true` (always handled when the selection is inside the editor; this stops focus traversal on Tab).
   - `onPaste()`: the attachment hook of step 01.21 (returns `false` until then).
   Every `EngineChange` is also fed to `tracker.onEdit` (convert `EngineChange` to a `LineEdit` using the lines before the change — the controller keeps the previous `LineView` snapshot info it needs: the start `LinePos` and the replaced text — compute it in the adapter and pass it as part of `EngineChange` (add `final LinePos startPos; final LinePos endPos;` to `EngineChange` in this step; update both adapters and `FakeEditorEngine`).
9. **Editor commands** (`editor_commands.dart`): `registerEditorCommands(CommandRegistry r)` registers every `editor.*` row of the 01.14 table marked "01.19", with the default shortcuts listed there. Each `run` obtains `final c = ref.read(activeEditorProvider); if (c == null) return;` then:
   `editor.toggle-bold|italic|strikethrough|highlight|code` → `toggleInlineFormat`; `editor.insert-link` → `insertLink`; `editor.toggle-bullet-list|numbered-list|quote|task`, `editor.cycle-heading` → block helpers; `editor.indent-list` / `editor.outdent-list` → `indentOnTab(shift: false/true)` but **forcing list indentation of the caret line** (for the toolbar: `forceLine: true` parameter that treats the caret line as affected even when it is not a list line); `editor.undo` / `editor.redo` → `c.undo()/redo()`; `editor.find` / `editor.replace` → `c.findController.open(replace: false/true)`; `editor.move-line-up|down`, `editor.duplicate-line` → line helpers. `isAvailable: (ref) => ref.read(activeEditorProvider) != null` (and `canUndo`/`canRedo` for undo/redo). Add `registerEditorCommands(r)` to `commandRegistryProvider`. Mobile toolbar flags: bold, italic, cycle-heading, bullet, numbered, task, link, code, quote, undo, redo, indent, outdent have `showInMobileToolbar: true`; icons as in step 01.21.
   `EditorController` gets a method `void runPlan(EditPlan? plan)` (applies a non-null plan with `engine.applyPlan`) and a getter `LineView get lines` for these commands.
   All editor shortcuts (Ctrl+B, Ctrl+I, Ctrl+K, Ctrl+Z, …) are **commands**, not engine shortcuts: the engine adapter's `_NoCommandShortcuts` (01.18) lets the keys bubble to `HotkeyHost`, which runs the command **only when `isAvailable`**; therefore in Source mode `Ctrl+Z`, `Ctrl+Y`, `Ctrl+Shift+Z` run `editor.undo/redo`. `Ctrl+S` runs `note.save` (01.20).
10. **Find & replace** (`find/`):
    - `find_options.dart`: `FindOptions { String query; bool matchCase; bool wholeWord; bool regex; }`.
    - `find_engine.dart` (pure): `FindResult findAll(String text, FindOptions o, {int limit = 10000})` → `FindResult { List<FindMatch> matches (start, end, groups); bool truncated; String? error }`. Plain query → `RegExp.escape`; whole word wraps the pattern in `(?<![\p{L}\p{N}\p{M}_])(?:…)(?![\p{L}\p{N}\p{M}_])` (unicode); `matchCase == false` → case-insensitive; invalid regex → `error` set, no matches; empty query → no matches; zero-length regex matches are skipped. `String expandReplacement(FindMatch m, String template, {required bool regex})`: with `regex` the template supports `$1`…`$9` and `$$` (literal `$`); without `regex` the template is literal. `List<EditOperation> replaceAllOps(...)` builds the non-overlapping operations.
    - `find_controller.dart`: `FindController(EditorController c)` with `ValueListenable<FindState>` (`options`, `matches`, `currentIndex`, `replaceText`, `isOpen`, `showReplace`, `error`); `open({bool replace = false})` (prefills the query with the selection if it is a single line of ≤ 100 chars); `setQuery/setOptions` (re-search debounced 100 ms against `c.text`); `next()/previous()` (wraps; selects the match and reveals it; the **first** `next` after typing selects the first match at or after the caret); `replaceCurrent()` (applies one op, re-searches, moves to the next match); `replaceAll()` (one `applyEdits` call → one undo step; a snackbar `findReplacedCount` with the count); `close()` (clears overlays, returns focus to the editor). The controller sets the highlighter overlays (`findMatch` for all, `findCurrent` for the current one) in offsets→lines.
    - `find_bar.dart`: a compact bar above the editor (inside `SourceEditorView`): query `TextField` (key `find.query`), match counter `3 of 12` (or `No results`, or the error text), buttons Previous (`find.prev`), Next (`find.next`), option toggles `Aa` (`find.matchCase`), `\b` whole word (`find.wholeWord`), `.*` regex (`find.regex`), close (`find.close`); when `showReplace`: second row with the replacement field (`find.replace`) and buttons Replace (`find.replaceOne`), Replace all (`find.replaceAll`). Keys: Enter = next, Shift+Enter = previous, Esc = close, F3/Shift+F3 next/previous; Ctrl+F while open focuses the query field and selects its text; Ctrl+H opens the replace row. On phone the bar stacks into two rows and uses 48 dp buttons.
    - Overlay support in `SourceHighlighter`: `void setOverlays(List<OverlayRange> overlays)` (document offsets + token), converted with `posOf`; repaint only the affected lines (`engine.repaintLines`).
11. l10n keys: `findQueryHint`, `findReplaceHint`, `findNoResults`, `findCounter` (`{current} of {total}`), `findInvalidRegex`, `findReplacedCount`, `findMatchCase`, `findWholeWord`, `findRegex`, `findNext`, `findPrevious`, `findClose`, `findReplaceOne`, `findReplaceAll`.

**Tests** (besides the helper tables above, each of which becomes one `test()` per row group in the named files)
- `find_engine_test.dart`: plain search case-insensitive/sensitive; whole word (`cat` in `concatenate cat` → 1 match); regex `a(b+)` with `$1` replacement; `$$` literal; invalid regex `(` → `error` set; zero-length regex `x*` skipped; Unicode (`বাংলা`, emoji) offsets are UTF-16 correct; truncation at the limit; 5,000-line huge note search < 50 ms (`Stopwatch`; record).
- `find_bar_test.dart` (real engine): Ctrl+F opens the bar (command), typing a query shows `1 of N`, Enter advances and wraps, Shift+Enter goes back, toggles change the count, Replace all changes the document and one Ctrl+Z restores it entirely, Esc closes and clears highlights, Ctrl+H shows the replace row, invalid regex shows the error, the selection prefill.
- `editor_commands_test.dart`: every `editor.*` command exists with the exact default shortcuts from the table (assert id → shortcut strings); unavailable without an editor; with a `FakeEditorEngine` controller registered each command changes the text as in the helper tables (one case each); `editor.undo`/`redo` call the controller; the registry has **no shortcut conflicts** among defaults (`findHotkeyConflicts` empty).
- `editor_shortcuts_test.dart` (real engine, 1200 dp): pump the shell with a source-mode tab; `Ctrl+B` with `⟦word⟧` selected wraps in `**`; `Ctrl+Z` undoes; `Ctrl+Shift+D` duplicates the line; `Alt+Up` moves the line; typing `(` inserts `()`; Enter in `- a` continues the list; Tab indents; `Ctrl+Enter` toggles the task; **IME safety**: a composing `TextEditingValue` update (composing range valid) is never intercepted (unit-test the adapter's interception predicate with composing values — typed run inside a composing region → `false`); typing 200 characters (`I'm`, `snake_case`, `**bold**`, `(a)`) produces exactly the expected text.

**Verify** `cd app; flutter test test/editor; cd ..` + standard checks; manual on Windows (copy vault, Source mode): type `**bold**`, `(parens)`, `- a⏎b⏎` list behaviour, Tab/Shift+Tab, Alt+Up/Down, Ctrl+Shift+D, Ctrl+F/H. Commit `phase 01.19: add editing helpers, editor commands and find & replace`.

**Pitfalls**
- Helpers return plans in **pre-edit** coordinates with a **post-edit** selection; the adapter must apply all `LineEdit`s back-to-front inside one undo group.
- Never intercept a composing IME update (CJK/Bangla/Gboard suggestions); only intercept when the composing range is invalid/collapsed.
- `Tab` must be consumed by the editor (indent) and never move focus; `Shift+Tab` likewise.
- Auto-pair state (`tracker`) must be cleared on `setText`/`replaceAll`.
- Find highlights are overlays, never edits; closing the bar clears them.

---

### 01.20 Autosave, save indicator, external changes, three-way merge, conflict dialog

**Purpose** Never lose edits and never miss an external change: debounced autosave (1000 ms) + blur + app-pause saves, an always-visible save state, silent reload when the note is clean, a three-way merge when it is dirty, and a conflict dialog when the merge is not clean.

**Files**
- modify `app/lib/vault/note_document.dart`, `app/lib/vault/note_document_store.dart`, `app/lib/vault/providers.dart`, `app/lib/workspace/tab_status.dart`, `app/lib/workspace/workspace_shell.dart`, `app/lib/workspace/note_view.dart`
- create `app/lib/vault/three_way_merge.dart`, `app/lib/vault/conflict_resolution.dart`, `app/lib/vault/autosave_host.dart`, `app/lib/editor/conflict_dialog.dart`, `app/lib/editor/save_state_indicator.dart`, `app/lib/editor/note_banners.dart`
- modify `app/lib/commands/builtin_commands.dart` or `app/lib/editor/editor_commands.dart` (register `note.save`)
- tests: `app/test/vault/three_way_merge_test.dart`, `note_document_autosave_test.dart`, `note_document_external_test.dart`, `conflict_resolution_test.dart`, `autosave_host_test.dart`, `app/test/editor/conflict_dialog_test.dart`, `save_state_indicator_test.dart`, `app/test/vault/external_pickup_test.dart`

**Implementation**
1. **`NoteDocument` changes** (keep the public API of 01.15; additions only):
   - Constructor gains `Duration autosaveDelay = const Duration(milliseconds: 1000)`.
   - `load()` now reads **bytes** (`fs.readBytes`) and decodes with `TextDocument.decode`; it records `_diskHash = contentHash(bytes)` and `_diskStat = await fs.stat(path)` (`size`, `modified`).
   - **Autosave**: every change (`setText`, `edit`, `notifyEditorChanged`, `replaceAll` via the editor) restarts a `Timer(autosaveDelay)`; when it fires → `save()`. A pending timer is cancelled by an explicit `save()`. No timer while `isReadOnly`, while a conflict is pending, or while `isDeletedOnDisk` (until the user chooses).
   - `save({bool force = false})` — the full algorithm (replaces the 01.15 version):
     1. `isReadOnly` → `readOnly`. A pending conflict → `conflict` (`SaveOutcome.conflict` is added to the enum).
     2. **External-change guard**: `st = await fs.stat(path)`; if `st != null && _diskStat != null && (st.size != _diskStat.size || st.modified != _diskStat.modified)` → `await onExternalChange()` first (below); if a conflict became pending → return `conflict`; if after the merge/reload the document is no longer dirty → return `unchanged`.
     3. `current = text`; if `!force && current == savedText` → `saveState = saved`, return `unchanged` (**no write**, conventions §6.2).
     4. `saveState = saving`; `bytes = TextDocument(text: current, hasBom: base.hasBom, lineEnding: base.lineEnding).encode()`; `await fs.writeBytes(path, bytes)` (atomic); on success `_diskHash = contentHash(bytes)`, `_diskStat = await fs.stat(path)`, `savedText = current`, `base = base.copyWith(text: current)`, `isDeletedOnDisk = false`, `saveState = (text == current) ? saved : unsaved` and the autosave timer is restarted if still unsaved; on exception log `warning`, `lastError`, `saveState = error`, return `failed` (a retry happens at the next change, on blur, or when the user taps the indicator).
   - **External change**: `Future<void> onExternalChange()` (called by the store for `FileCreated`/`FileModified` of this path, and by `save()` step 2):
     1. If a save is in flight (`saveState == saving`) → set `_recheck = true` and return; `save()` calls `onExternalChange()` again after finishing when `_recheck` is set.
     2. `bytes = await fs.readBytes(path)` (`FileNotFoundException` → `onExternalDelete()` and return); `hash = contentHash(bytes)`; if `hash == _diskHash` → update `_diskStat` and return (we know this content).
     3. `theirs = TextDocument.decode(bytes)`. If `theirs.malformed` → set `base = theirs` (read-only banner appears), `_diskHash = hash`, keep the buffer untouched and return (never merge into or overwrite a malformed file).
     4. If `theirs.text == savedText` (only BOM/line-ending changed outside) → `base = theirs`, `_diskHash = hash`, return.
     5. **Not dirty** (`!isDirty`): reload silently: `base = theirs; savedText = theirs.text; _diskHash = hash;` then `editor != null ? editor.replaceAll(theirs.text, keepCursor: true) : text = theirs.text`; `revision++`; `saveState = saved`; `isDeletedOnDisk = false`; notify; bump `vaultRevision` (through a callback `onDiskChanged`).
        If an editor is attached, the **undo history is cleared** after the reload (`engine.clearUndoHistory()` via `NoteEditorBinding.replaceAll(..., clearHistory: true)` — add the optional parameter `bool clearHistory = false` to the binding and to `EditorController.replaceAll`).
     6. **Dirty**: `result = threeWayMerge(base: savedText, mine: text, theirs: theirs.text)`; if `result.clean`: `savedText = theirs.text; base = theirs; _diskHash = hash;` apply `result.text` through the editor (`replaceAll(result.text, keepCursor: true)`, one undoable step) or `text = result.text`; the document stays dirty (it differs from disk) and autosave writes the merged text; log `info('merged external change')`.
        Else: set `pendingConflict = MergeConflict(mine: text, theirs: theirs, theirsHash: hash)` and notify (the UI shows the dialog; autosave is suspended).
   - `Future<void> onExternalDelete()`: `isDeletedOnDisk = true`; keep the buffer; notify. (The banner offers **Close tab** and **Recreate file**; a clean deleted note shows the same banner. `save(force: true)` recreates the file.) A later `FileCreated` for the same path calls `onExternalChange()` again, which runs the normal reload/merge with `base = savedText`.
   - `Future<void> resolveConflict(ConflictChoice choice)` — see 3.
   - `bool get isDeletedOnDisk; MergeConflict? get pendingConflict;`
2. **Store** (`NoteDocumentStore`): constructor takes the `VaultFileSystem`; `void start()` subscribes to `fs.watch()` (cancelled in `dispose`); for `FileCreated`/`FileModified(path)` → `peek(path)?.onExternalChange()` (unawaited with error logging); `FileDeleted(path)` → `peek(path)?.onExternalDelete()`; events for paths inside a folder that was deleted/moved are ignored (the explorer handles moves). `ValueListenable<int> get stateVersion` is bumped whenever any document's `saveState`, `isDeletedOnDisk` or conflict changes (documents call `store._onDocChanged()` through a callback).
   `NoteDocumentStore.flushAll()` saves every dirty document (`Future.wait`) and then calls `workspace persistence flush` through an optional callback `onFlushed`.
   `noteDocumentStoreProvider` calls `store.start()` and passes `ParseService`.
3. **Three-way merge** (`three_way_merge.dart`):
   ```dart
   final class MergeResult { const MergeResult({required this.clean, required this.text}); final bool clean; final String text; }
   MergeResult threeWayMerge({required String base, required String mine, required String theirs});
   ```
   Algorithm (package `diff_match_patch`, Apache-2.0; **confirm the exact member names in the installed package source** — the expected Dart names are `DiffMatchPatch()`, `diffTimeout`, `matchThreshold`, `matchDistance`, `patchDeleteThreshold`, `patch_make(a, b)` and `patch_apply(patches, text)` returning `[String, List<bool>]`):
   1. `mine == theirs` → clean, text `mine`. `mine == base` → clean, `theirs`. `theirs == base` → clean, `mine`.
   2. If `base.length + mine.length + theirs.length > 3_000_000` → not clean (too big to merge safely).
   3. `dmp = DiffMatchPatch(); dmp.diffTimeout = 1.0 (seconds); dmp.matchThreshold = 0.001; dmp.matchDistance = 1000000000; dmp.patchDeleteThreshold = 0.0;` (effect required: a patch applies **only** where its surrounding context matches **exactly**, wherever that context now sits in `theirs`; no fuzzy application).
   4. `patches = dmp.patch_make(base, mine); result = dmp.patch_apply(patches, theirs); merged = result[0]; applied = result[1]`.
   5. Clean iff `applied.every((a) => a)` **and** `merged.length <= 4 * max(mine.length, theirs.length)`; otherwise `clean: false, text: mine`.
   6. Safety net: a clean merge is additionally accepted only if `merged != theirs || mine == theirs` is consistent with step 1 (i.e. if `mine != base` then `merged` must differ from `theirs`), otherwise → not clean.
   Every outcome is deterministic; log `fine` with the lengths only (never the text).
4. **`ConflictChoice { keepMine, takeTheirs, keepBoth }`** and `conflict_resolution.dart`: `Future<void> resolveConflict(NoteDocument doc, ConflictChoice choice, {required VaultFileSystem fs, required Clock clock})`:
   - **keepMine**: `savedText = theirs.text; base = theirs; _diskHash = theirsHash;` the buffer stays; the document is dirty and the next save overwrites the disk version; clear the conflict; `save()` immediately.
   - **takeTheirs**: first write a **recovery copy** of the user's version: `.tephra/cache/recovery/<yyyyMMddHHmmss>-<file name>` (`clock.now()`, local time; created with `fs.writeText`, ignore errors but log `warning`); then `savedText = theirs.text; base = theirs; _diskHash = theirsHash`; editor → `replaceAll(theirs.text, keepCursor: true, clearHistory: true)` or `text = theirs.text`; clear the conflict; `saveState = saved`.
   - **keepBoth**: write the user's version as a new note in the same folder named `<stem> (conflict YYYY-MM-DD HH-mm).md` (format `DateFormat('yyyy-MM-dd HH-mm')` of `clock.now()`; e.g. `Note (conflict 2026-10-11 09-30).md`; if the name exists append ` 2`, ` 3`, … before `.md`); then behave as **takeTheirs** (no recovery copy needed). Bump `vaultRevision`.
   After any choice: `pendingConflict = null`, `saveState` recomputed, notify, autosave re-enabled.
5. **UI**:
   - `conflict_dialog.dart`: `showConflictDialog(BuildContext, NoteDocument)` — non-dismissible `AlertDialog`: title `conflictTitle` ("“{name}” changed on disk"), body `conflictBody` ("You have unsaved changes and this note was also changed outside Tephra. Choose which version to keep. Nothing is lost: the version you do not keep is saved as a copy."), buttons **Keep mine** (key `conflict.mine`), **Take theirs** (`conflict.theirs`), **Keep both** (`conflict.both`). `NoteView` shows it (once per conflict) when `doc.pendingConflict` becomes non-null.
   - `note_banners.dart`: `DeletedOnDiskBanner` (`noteDeletedBanner`: "This note was deleted outside Tephra." + buttons **Close tab** (`workspace.closeTab`) and **Recreate file** (`doc.save(force: true)`)), shown above the content when `doc.isDeletedOnDisk`.
   - `save_state_indicator.dart`: `SaveStateIndicator({required NoteDocument doc})`: small row: `Icons.check_circle_outline` + `saveStateSaved` ("Saved"); `Icons.edit_outlined` + `saveStateUnsaved` ("Unsaved changes"); a 14 dp `CircularProgressIndicator` + `saveStateSaving` ("Saving…"); `Icons.error_outline` (error colour) + `saveStateError` ("Couldn't save — tap to retry"; tap → `doc.save()`). Desktop: registered in the status bar registry (right, order 100, id `status.save`, shown only when the focused tab is a note); phone: shown as the app-bar subtitle line under the title (`phone_layout.dart` reads `activeNotePathProvider` + `noteDocumentProvider`).
   - `tabDirtyProvider` (workspace/tab_status.dart): `Provider.family<bool, VaultPath>`: watches `noteDocumentStoreProvider`, subscribes to `store.stateVersion` (`ref.invalidateSelf` on change, removed in `ref.onDispose`), returns `store.peek(path)?.saveState` is `unsaved`, `saving` or `error`.
6. **Lifecycle and shortcuts**:
   - `autosave_host.dart`: `AutosaveHost extends ConsumerStatefulWidget` wrapping the shell: `AppLifecycleListener(onInactive: flush, onHide: flush, onPause: flush, onDetach: flush)` where `flush` = `store.flushAll()` + `workspace persistence flush`; also flushes on `didChangeMetrics`-free events only (no timers). On Windows `onInactive` fires when the window loses focus; saving then is intended.
   - Editor blur: already calls `document.save()` (01.18).
   - Tab close / navigation away: `release` saves (01.15). Vault close (`vaultSessionProvider.notifier.close()`): `await store.flushAll()` **before** the file system is disposed (update `VaultSessionNotifier.close/set` to await the flush: make them `Future<void>`).
   - Command `note.save` (`Ctrl+S`, `isAvailable`: an active note): `doc.save()`; no snackbar on success; on failure show `SnackBar(saveFailed)`.
7. **Tab strip & status**: the dirty dot (01.13) now works; the desktop status bar shows the indicator; phone shows it under the title.
8. l10n keys: `conflictTitle`, `conflictBody`, `conflictKeepMine`, `conflictTakeTheirs`, `conflictKeepBoth`, `noteDeletedBanner`, `noteRecreate`, `saveStateSaved`, `saveStateUnsaved`, `saveStateSaving`, `saveStateError`, `saveFailed`.

**Tests**
- `three_way_merge_test.dart`:
  1. `identical edits` → clean; `mine == base` → theirs; `theirs == base` → mine.
  2. `non-overlapping edits merge`: base = 20 lines `L1…L20`; mine changes `L2` → `L2 mine`; theirs changes `L18` → `L18 theirs` → clean; text contains both; other lines unchanged.
  3. `theirs inserts lines above` (shifts the context): theirs prepends 3 lines, mine edits `L10` → clean and contains both.
  4. `same line, different edits` → not clean, `text == mine`.
  5. `one-character context difference` (theirs changed a char **inside** mine's patch context line) → not clean (no fuzzy application).
  6. `append vs prepend` → clean.
  7. `Unicode` (Bangla, emoji) base/mine/theirs merge cleanly with correct text.
  8. `too large` (> 3,000,000 combined chars) → not clean without calling dmp.
  9. `5,000-line note` (generated like Phase 0's huge note) with edits at lines 100 and 4,900 merges in < 500 ms (print the value).
  10. `result deterministic` (run twice → equal).
- `note_document_autosave_test.dart` (`testWidgets` + `tester.pump`, memory fs): an edit followed by 999 ms → no write; at 1,000 ms → exactly one write; ten edits 100 ms apart → one write 1,000 ms after the last; edit + `save()` before the timer → one write and the timer is cancelled (no second write); undo-to-original before the timer → **no write** at all; read-only never writes; blur (`FakeEditorEngine`) saves immediately; `flushAll` saves every dirty doc; a failing fs → `saveState == error`, a later edit retries and succeeds; vault close flushes first.
- `note_document_external_test.dart` (memory fs; `fs.emit(FileModified(path))` + `putText`): clean doc reloads silently and `revision` increments; editor attached → `replaceAll` called with `keepCursor: true` and the undo history cleared; dirty doc + non-overlapping external change → merged text, still dirty, then autosave writes the merged text (bytes on disk contain both edits); dirty + overlapping change → `pendingConflict` set, no write happens while pending, `save()` returns `conflict`; external change identical to what we wrote → ignored (hash equal); BOM/ending-only change → base flags updated, text untouched; external change to a malformed file → read-only banner, buffer untouched; `FileDeleted` → `isDeletedOnDisk`, buffer kept; re-creation → reload/merge; `Recreate file` writes the buffer; **stat guard**: modify the file without emitting a watcher event, then `save()` → the external change is noticed before writing (merge or conflict) and the external edit is never overwritten silently.
- `conflict_resolution_test.dart`: keepMine → disk gets mine on next save; takeTheirs → doc text = theirs, recovery file exists at `.tephra/cache/recovery/20261011093000-Note.md` with `ManualClock(2026-10-11 09:30:00)`; keepBoth → `Note (conflict 2026-10-11 09-30).md` created with mine, doc text = theirs; second conflict in the same minute → `… 2.md`; after any choice autosave works again.
- `conflict_dialog_test.dart`: three buttons; pressing each calls the right resolution; not dismissible (barrier tap does nothing).
- `autosave_host_test.dart`: simulate `AppLifecycleState.paused`/`inactive`/`hidden` (`tester.binding.handleAppLifecycleStateChanged`) → dirty docs saved immediately.
- `save_state_indicator_test.dart`: four states render the right text/icon; tap on error retries.
- `external_pickup_test.dart` (**real** `IoVaultFileSystem` on a temp dir, default 150 ms debounce): open a note through the store, modify the file with `dart:io`, assert `doc.text` equals the new text within **1,000 ms** (measure with a `Stopwatch`, print it; exit-gate item).

**Verify** `cd app; flutter test test/vault test/editor test/workspace; cd ..`; manual on Windows (copy of the syntax vault, open a note in Source mode): (1) edit the file in Notepad and save → the editor updates within a second with the caret kept; (2) type in the editor, wait 1 s → the dirty dot disappears and the file changes on disk; (3) type, then edit the file elsewhere (non-overlapping) → merged; overlapping → the dialog. Commit `phase 01.20: add autosave, external change handling, merge and conflict dialog`.

**Pitfalls**
- Never write while a conflict is pending; never discard the user's version without saving a copy.
- The stat guard exists because Android watchers can miss events; do not remove it.
- Do not call `onExternalChange` for our own writes: the file system suppresses them, and the hash check is the second line of defence.
- `replaceAll(..., clearHistory: true)` only for reloads of a clean document; merges keep the undo history (one undoable step).

---

### 01.21 Attachments (paste, drop, pick) and the phone keyboard toolbar

**Purpose** Insert images and files into notes per conventions §6.7 and make editing comfortable on a phone.

**Files**
- `app/lib/editor/attachment_service.dart`, `app/lib/editor/attachment_paths.dart`, `app/lib/editor/image_type.dart`, `app/lib/editor/attachment_actions.dart`, `app/lib/editor/editor_drop_target.dart`
- `app/lib/editor/mobile_toolbar.dart`
- modify `editor_input_handlers.dart` (`onPaste`), `source_editor_view.dart` (drop target), `workspace/phone_layout.dart` (toolbar slot), `editor/editor_commands.dart` (`editor.hide-keyboard`, `editor.insert-attachment`), `editor/providers.dart` (`attachmentServiceProvider`)
- tests: `app/test/editor/attachment_service_test.dart`, `attachment_paths_test.dart`, `image_type_test.dart`, `attachment_actions_test.dart`, `mobile_toolbar_test.dart`, `paste_handler_test.dart`

**Implementation**
1. `image_type.dart`: `String? detectImageExtension(List<int> bytes)`: PNG (`89 50 4E 47 0D 0A 1A 0A`) → `png`; JPEG (`FF D8 FF`) → `jpg`; GIF (`GIF87a`/`GIF89a`) → `gif`; WebP (`RIFF` at 0 and `WEBP` at 8) → `webp`; BMP (`42 4D`) → `bmp`; otherwise `null`.
2. `attachment_paths.dart`: `VaultPath attachmentFolderFor(VaultPath note, String setting)`:
   - `'/'` → `VaultPath.root`; `'./'` → `note.parent ?? root`; a setting starting with `'./'` followed by more text (`'./files'`) → `(note.parent ?? root).join('files')`; anything else → `VaultPath.tryParse(setting)` (a fixed vault-relative folder) and, if it cannot be parsed (invalid), **fall back to the root** with a `warning` log.
   `String sanitizeAttachmentName(String name)`: replace each character that `VaultPath.checkName` rejects (`< > : " | ? * / \` and control characters) by `_`; trim trailing dots and spaces; if the result is empty or reserved → `attachment`; limit to 200 characters keeping the extension.
   `String pastedImageName(DateTime t, String ext)` → `Pasted image yyyyMMddHHmmss.<ext>` (local time; zero-padded), e.g. `Pasted image 20261011093000.png` (conventions §6.7).
3. `attachment_service.dart`:
   ```dart
   final class AttachmentService {
     AttachmentService(this.ref);
     /// Saves [bytes] next to/under the folder chosen by settings and returns the saved path. Never overwrites: a taken name gets " 1", " 2", … before the extension.
     Future<VaultPath> save({required VaultPath note, required List<int> bytes, required String fileName});
     Future<VaultPath> savePastedImage({required VaultPath note, required List<int> bytes});   // detects the extension (default png), names it `Pasted image <ts>.<ext>`
     /// The text inserted into the note for [saved]: `![[name.ext]]`, or `![[folder/name.ext]]` when another file with the same name exists elsewhere in the vault.
     Future<String> embedTextFor(VaultPath saved);
     static const int maxBytes = 200 * 1024 * 1024;   // larger files are refused with AttachmentTooLargeException
   }
   ```
   Uses `vaultSettingsProvider.attachmentFolder`, `clockProvider`, `vaultFsProvider`, `vaultFilesProvider`; creates the folder (`fs.createFolder`), writes with `fs.writeBytes`, bumps `vaultRevision`. `AttachmentTooLargeException extends TephraException`. Provider `attachmentServiceProvider`.
4. `attachment_actions.dart`:
   - `Future<void> insertAttachmentsInto(EditorController c, WidgetRef ref, List<AttachmentInput> inputs)` (`AttachmentInput { List<int> bytes; String fileName; bool isImage; }`): for each input → `save`/`savePastedImage` → embed text; inserts the embeds (joined with `\n` when several; one per line) at the caret as **one** edit (`c.apply(EditOperation(selStart, selEnd, text), selectAfter: true)`, replacing a non-empty selection); errors are collected and shown in one `SnackBar` (`attachmentFailed`, `attachmentTooLarge`).
   - **Windows paste** (`onPaste` handler): only when `!kIsWeb && Platform.isWindows`: `files = await Pasteboard.files()` (copied files from Explorer) non-empty → each file read from disk → inputs (`isImage` by extension); else `image = await Pasteboard.image` non-null → one `savePastedImage` input; else return `false` so the engine pastes text. Returns `true` when attachments were handled. (Android has no paste-image path: use the picker below.)
   - **Drop (Windows)**: `EditorDropTarget` wraps the editor view with `DropTarget(onDragDone: (d) …)` from `desktop_drop` (only on Windows; elsewhere returns the child); each dropped file → input; shows a translucent overlay (`attachmentDropHint`) while dragging over.
   - **Pick**: command `editor.insert-attachment`: Android → a bottom sheet with three 56 dp rows: **Photo library** (`ImagePicker().pickImage(source: ImageSource.gallery)`), **Take photo** (`ImageSource.camera`), **File** (`FilePicker.platform.pickFiles(allowMultiple: true)`); picked images become `savePastedImage` inputs (the temporary file is read with `XFile.readAsBytes`), files keep their sanitised original name; Windows → `FilePicker.platform.pickFiles(allowMultiple: true)` only. A user cancel does nothing. Files larger than 200 MB → `attachmentTooLarge`.
5. `mobile_toolbar.dart`: `MobileToolbar extends ConsumerWidget` (key `mobile.toolbar`), height 48 dp + safe-area inset, background `surfaceContainer`, top divider. Layout: a horizontally scrollable `ListView` of `IconButton`s (each **48 × 48 dp**) for the commands (in this exact order; each id must exist in the registry, `showInMobileToolbar == true`): `editor.toggle-bold` (`Icons.format_bold`), `editor.toggle-italic` (`format_italic`), `editor.cycle-heading` (`title`), `editor.toggle-bullet-list` (`format_list_bulleted`), `editor.toggle-numbered-list` (`format_list_numbered`), `editor.toggle-task` (`check_box_outlined`), `editor.insert-link` (`link`), `editor.toggle-code` (`code`), `editor.toggle-quote` (`format_quote`), `editor.insert-attachment` (`attach_file`), `editor.undo` (`undo`, disabled when `!canUndo`), `editor.redo` (`redo`, disabled when `!canRedo`), `editor.outdent-list` (`format_indent_decrease`), `editor.indent-list` (`format_indent_increase`); and, pinned at the right end outside the scroll area, `editor.hide-keyboard` (`keyboard_hide`). Tooltips = command labels. Each button runs `command.run(ref, context)`; commands that are unavailable are hidden. **Buttons do not take focus** (`ExcludeFocus` / `focusNode.skipTraversal`, `onPressed` runs without moving focus) so the keyboard stays open.
   Visibility: shown by `PhoneLayout` (width < 840) as the last child of the body `Column` when the focused tab is in `ViewMode.source`, an editor is attached to the note and `MediaQuery.viewInsets.bottom > 0` **or** the editor `hasFocus`. Desktop never shows it.
   `editor.hide-keyboard` (`isAvailable`: `MediaQuery.viewInsets.bottom > 0`) → `FocusManager.instance.primaryFocus?.unfocus()` (the blur saves the note) — register it, with `editor.insert-attachment`, in `registerEditorCommands`; mark `showInMobileToolbar: true` on `editor.insert-attachment` and `editor.hide-keyboard`.
6. l10n keys: `attachmentDropHint`, `attachmentFailed`, `attachmentTooLarge`, `attachmentPickPhoto`, `attachmentTakePhoto`, `attachmentPickFile`, `toolbarMore`.

**Tests**
- `image_type_test.dart`: signatures for the five formats (use bytes of `test_vaults/syntax/attachments/sample.png` for PNG and handmade headers for the others); random bytes → `null`.
- `attachment_paths_test.dart`: `'/'`, `'./'`, `'./sub'`, `'Attachments'`, `'bad:folder'` (fallback root), note in root vs `A/B/n.md`; `sanitizeAttachmentName('a:b?.png')` = `a_b_.png`, `'con'` → `attachment`, trailing dot trimmed; `pastedImageName(DateTime(2026,10,11,9,30,5), 'png')` = `Pasted image 20261011093005.png`.
- `attachment_service_test.dart` (memory fs + `ManualClock(2026-10-11 09:30:00)`): `savePastedImage` with PNG bytes → `Pasted image 20261011093000.png` in the configured folder, bytes identical; a second call the same second → `Pasted image 20261011093000 1.png`; folder created for `Attachments`; `./attachments` relative to the note; embed text `![[Pasted image 20261011093000.png]]`; **ambiguity**: when another `Pasted image 20261011093000.png` exists in a different folder → `![[Folder/Pasted image 20261011093000.png]]`; > 200 MB (use a fake length via a list subclass with `length` override) → `AttachmentTooLargeException`; no overwrite of an existing file.
- `paste_handler_test.dart` (fake `Pasteboard` via a thin interface `ClipboardImageSource` injected into `attachment_actions.dart` with the real `Pasteboard` as default): image available → one attachment inserted at the caret as one undoable edit (`undo()` removes the embed text; the file stays); files list → several embeds on separate lines; nothing available → returns `false` (text paste continues); disabled on non-Windows.
- `attachment_actions_test.dart`: inserting replaces a non-empty selection; two inputs → two lines; a failing input reports an error and the successful ones are still inserted; Android sheet shows three rows (inject `isAndroid`); cancel does nothing.
- `mobile_toolbar_test.dart`: at 400 dp the toolbar renders buttons in the exact order above with 48 dp targets (`tester.getSize`), hides unavailable commands, undo/redo disabled with no history, tapping bold calls the command and the editor **keeps focus**, `editor.hide-keyboard` pinned at the right end; at 1200 dp it is not shown; not shown in reading mode.

**Verify** `cd app; flutter test test/editor; cd ..`; manual: Windows — copy an image in Explorer/Snipping Tool → Ctrl+V in Source mode inserts `![[Pasted image …png]]` and the file appears in the configured folder; drag a file onto the editor; Android (device or emulator) — toolbar above the keyboard, attach from gallery. Commit `phase 01.21: add attachments and the phone keyboard toolbar`.

**Pitfalls**
- Never overwrite an existing attachment; never save pasted data to the process temp folder only.
- `Pasteboard` is called only on Windows (guard with `Platform.isWindows` inside `core/platform`-style code; keep the check in `attachment_actions.dart`).
- The toolbar must not steal focus; use `Listener`/`InkWell` with `excludeFromSemantics: false` but `canRequestFocus: false`.
- Re-check that a successfully inserted embed counts as dirty and autosaves.

---

### 01.22 Round-trip proof, crash safety, performance budget, demo and exit gate

**Purpose** Prove the phase's promises with numbers: 0 changed bytes across the fixture vaults, no data loss when the process is killed, typing within budget on the phone, external edits picked up in < 1 s.

**Files**
- `tool/roundtrip_check.dart`, `tool/kill_writer.dart`, `tool/kill_test.dart`, `tool/src/roundtrip.dart`
- `tool/test/roundtrip_test.dart`
- `app/test/roundtrip/roundtrip_test.dart`, `app/test/roundtrip/recording_fs.dart`, `app/test/roundtrip/vault_parse_test.dart`
- `app/lib/dev/huge_note.dart`, `app/lib/dev/typing_benchmark.dart`, `app/lib/dev/dev_commands.dart`
- `app/test/dev/huge_note_test.dart`
- modify `README.md` (Phase 1 features), `PROGRESS.md` (numbers), `.github/workflows/ci.yml` only if golden tests are not excluded (see below)

**Implementation**
1. `tool/src/roundtrip.dart` + `tool/roundtrip_check.dart <vaultDir>…` (pure Dart, uses `tephra_core`, `tephra_vault`, `tephra_markdown` only): for every file with extension `md` under each directory (`IoVaultFileSystem.list(recursive: true)` with `VaultIgnore(showHidden: true)` so `.hidden` notes are included; the tool is read-only): `bytes = readBytes`; `doc = TextDocument.decode(bytes)`;
   (a) **codec law**: `doc.malformed` → counted as `malformed` (skipped); else if the file has no mixed endings (`bytes` contains no lone `\n` **and** CRLF together; compute with the same counters as `decode`): `doc.encode()` must equal `bytes` → else a **changed** record; mixed files: `encode` differs only in line endings (compare after normalising `\r\n`→`\n` on both) → counted `mixed-normalised`;
   (b) **parse safety**: `MarkdownParser.parse(doc.text)` does not throw and satisfies the range invariants of the fuzz test (reuse a small `checkInvariants` copy);
   Output: one summary line per vault `vault=<dir> files=<n> notes=<m> unchanged=<k> mixed=<j> malformed=<q> changed=<c> parseErrors=<e>` and exit code `1` if `changed > 0` or `parseErrors > 0`. `tool/test/roundtrip_test.dart` runs it on a temp vault built from the edge fixtures and asserts exit status and the summary text; also asserts that a deliberately re-encoded file (flip CRLF to LF in a copy) is detected as `changed`.
2. `app/test/roundtrip/roundtrip_test.dart` — runs on **copies** of `test_vaults/syntax`, `test_vaults/edge`, `test_vaults/real` (copy to a temp dir per test group with `Directory` recursion; fixture files are never modified) through the real stack (`IoVaultFileSystem` wrapped by `RecordingVaultFileSystem` from `recording_fs.dart`, which counts `writeBytes`/`writeText`/`move`/`delete` calls and logs paths; `NoteDocumentStore`):
   1. `open + save without edit writes nothing`: for **every** `.md` (including `.hidden/` and `deep/…`): `acquire`, await load, `save()` → outcome `unchanged` or `readOnly`; total writes == 0; file bytes **and** `modified` timestamps identical to the copy source.
   2. `open + edit + undo-to-original + save writes nothing`: `setText(orig + 'x')` then `setText(orig)` → `save()` → `unchanged`; 0 writes.
   3. `open + edit + save keeps BOM and line endings`: for the non-malformed files: `edit(EditOperation(0, 0, 'Z'))` → `save()` → `written`; the new bytes equal `TextDocument(text: 'Z' + orig, hasBom: sameBom, lineEnding: expectedEnding).encode()` where `expectedEnding` is the dominant ending (`mixed-endings.md` → `lf`); `decode(newBytes)` has the same `hasBom`; the original file is intact until the write (the write is atomic: assert no `.tephra-tmp-` file remains in the folder).
   4. `malformed-utf8.md`: `isReadOnly`, `edit` returns `false`, `save` returns `readOnly`, bytes unchanged.
   5. `empty.md` and `only-frontmatter.md` and `no-trailing-newline.md`: edit + save adds exactly the inserted character and **does not add a trailing newline** to `no-trailing-newline.md`.
   6. Names: notes with Bangla, emoji, spaces and NFD names open and save (path round trip through `VaultPath` and the file system).
   The assertion summary line printed by the test: `ROUNDTRIP files=<n> writes_without_edit=0 changed_bytes=0`. **Exit gate item "0 changed bytes" = this test and `dart run tool/roundtrip_check.dart test_vaults/syntax test_vaults/edge test_vaults/real` both pass.**
3. `app/test/roundtrip/vault_parse_test.dart`: parse every `.md` of the three vaults (`real/` 300 notes) with the full parser; invariants hold; total time printed; every syntax note renders in `ReadingView` without exceptions (24 pumps).
4. `app/test/dev/huge_note_test.dart`: `app/lib/dev/huge_note.dart` contains `String generateHugeNote()` copied **verbatim** from `tool/src/huge_note.dart` (Phase 0 step 00.13); the test asserts that its output equals the bytes of `test_vaults/edge/huge-5000-lines.md` decoded as UTF-8.
5. **Crash-safety harness (kill during writing, ×20).** `tool/kill_writer.dart <dir>`: pure Dart; opens an `IoVaultFileSystem` on `<dir>`, and loops forever: version `n = 1, 2, 3, …`: builds a note text of 5,000 lines whose first line is `VERSION n` and whose last line is `END n` (middle lines `line i of n`), `writeText('Note.md', …)`, then prints `ACK n` to stdout and flushes. `tool/kill_test.dart` (CLI, `--rounds 20`, default 20): for each round (seeded `Random(round)`): start `dart run tool/kill_writer.dart <tempdir>` (precompile once with `dart compile exe` into the temp folder for fast start), wait for `ACK` lines, kill the process (`Process.kill(ProcessSignal.sigkill)`; on Windows `taskkill /F /PID`) after a random 50–800 ms **after the first ACK**; then verify: `Note.md` exists, decodes, has `VERSION n` on the first line and `END n` on the last line for the **same** `n`, `n >= lastAckedVersion` (the file is never older than the last acknowledged write) and `n <= lastAcked + 1`, and no zero-byte or partial content; leftover `.Note.md.tephra-tmp-*` files are allowed but are removed by `IoVaultFileSystem.cleanStaleTemps(olderThan: Duration.zero)` and the test checks that this call deletes exactly those. Prints `KILL round=<r> acked=<a> found=<n> ok` per round and a final `KILL 20/20 ok`. Exit code 1 on any failure.
6. **Kill during typing on the real app (×20, manual + semi-automatic).** Add `app/lib/dev/dev_commands.dart` (registered only when `const bool.fromEnvironment('TEPHRA_DEV')` is true, ids `dev.run-typing-benchmark`, `dev.type-and-wait`): `dev.type-and-wait` opens a scratch note `__kill_test.md` in a **real vault folder the human selects**, and types the line `K<n>` plus a newline into the editor every 200 ms via `EditorController.apply` for 60 s (n increments). Procedure (written into `PROGRESS.md` and run by the human or by you with `adb` on the phone / `taskkill` on Windows): start typing, after a random 1–10 s kill the app (`adb shell am force-stop com.tephra.app` / `taskkill /F /IM tephra.exe`), restart, open the note and check: file is not corrupt, it contains every line up to the **last autosave** (autosave delay 1 s ⇒ at most the last ~1.2 s of typing may be missing; **the loss window must be ≤ 1.5 s** — compare the last `K<n>` with the typed count printed in the log), the note decodes without `malformed`. Repeat 20 times on Windows and 20 times on the phone (or write "phone not verified on device"). Record `PROGRESS.md`: `kill-typing windows 20/20, android 20/20|not verified`.
7. **Typing budget (16 ms per keystroke on the 5,000-line note, on the phone).** `app/lib/dev/typing_benchmark.dart`: `TypingBenchmarkScreen` (route pushed by `dev.run-typing-benchmark`): builds a `NoteDocument` over a `MemoryVaultFileSystem` containing `generateHugeNote()` (so no vault file is touched), shows the real `SourceEditorView` for it, and runs: (a) place the caret at the start of line 2,500 (`controller.select(offsetOfLine(2499))`); (b) register `SchedulerBinding.instance.addTimingsCallback`; (c) insert 500 characters from the string `'The quick brown fox jumps over the lazy dog. '` (cycling) **one character per frame** through `controller.apply(EditOperation(off, off, ch), selectAfter: true)` followed by `await SchedulerBinding.instance.endOfFrame` (this exercises the engine change stream, highlighter splice, document notification and repaint, i.e. everything that runs per keystroke except the platform IME); (d) after the last character wait 1 s, remove the callback, compute `FrameTiming.buildDuration`/`rasterDuration` statistics: count, p50, p90, p95, p99, max of `max(build, raster)` in ms and the number of frames over 16.0 ms; (e) scroll benchmark: animate the editor scroll from top to bottom in 5 s and report frames, fps, p95. Print `PERF typing p50=.. p90=.. p95=.. p99=.. max=.. over16=.. | scroll fps=.. p95=..` and show the numbers in a dialog. Also print `PERF parse-5000-lines <ms>` (parse of the same text on the UI isolate for reference) and `PERF highlight-visible-lines <µs per line>` (average `spanFor` cost for 40 consecutive dirty lines).
   **Gate**: run `flutter run --profile -d <phone> --dart-define=TEPHRA_DEV=true`, execute the benchmark 3 times, take the median run: `p95 <= 16.0 ms`. Also run it on Windows (profile) — must also be ≤ 16.0 ms. If the phone number is more than 25 % over budget after one reasonable optimisation attempt (for example: build per-line `TextSpan`s lazily only for visible lines, cache `TextSpan`s per `(line, revision)`, avoid `engine.text` on the typing path, lower the highlighter's repaint range to the changed lines), **stop and ask the human** (GEMINI.md §5). No phone connected → record "typing budget not verified on device" and tell the human; Windows numbers are still recorded.
8. **CI**: Phase 1 adds no CI jobs. Check `.github/workflows/ci.yml`: the app test step must be `flutter test --exclude-tags golden` (goldens are generated on Windows; the CI runner may differ). If it is `flutter test` without the exclusion, change it (this is the only CI edit allowed) and run the exact command locally.
9. Update `README.md` (feature list: vault picker, reading view, Source editor; `## Install`/`## Run` unchanged), `PROGRESS.md`: tick all 22 steps, fill the exit-gate evidence (below), list **Conflicts** and **Ideas** (SAF vault, blockquote/callout Enter continuation, drag-and-drop between panes, explorer expansion persistence, Live Preview — Phase 2).
10. Remove nothing from `test_vaults/` and confirm `git status` shows no modification under it (`git status --porcelain test_vaults` empty).

**Tests** as listed in 1–5 and 7 (the typing benchmark is a measured run, not a unit test; its helper `percentile(List<double>, p)` has a unit test: `percentile([1,2,3,4,5], 50) == 3`, `percentile([...100 values], 95)` picks the nearest-rank value).

**Verify** run, in order, and record outputs in `PROGRESS.md`:
```
dart run tool/roundtrip_check.dart test_vaults/syntax test_vaults/edge test_vaults/real
dart run tool/kill_test.dart --rounds 20
cd app; flutter test; cd ..
cd packages/tephra_core; dart test; cd ../tephra_vault; dart test; cd ../tephra_markdown; dart test; cd ../..
dart test tool/test
dart format --output=none --set-exit-if-changed app/lib app/test packages tool
flutter analyze --fatal-infos
dart run tool/check_licenses.dart
```
and the device runs of items 6 and 7. Commit `phase 01.22: add round-trip, crash and performance proofs`.

**Pitfalls**
- The round-trip test must run on copies; a test that writes into `test_vaults/` is a bug (check `git status`).
- Timestamps comparison: use `stat.modified` from the copy **before** and **after**; copying with `File.copy` preserves content but not necessarily mtime — compare each copy against **its own** pre-test mtime.
- Debug-mode timings are 3–10× slower: **never** record debug numbers as gate evidence.
- `kill_test` must kill the writer **process**, not the Dart VM of the harness; use the PID of the child.

---

## Demo script

Perform in order; steps marked **[human]** need a person at the device or in Obsidian — if you cannot operate the GUI yourself, ask the human and record what they report. Use a **copy** of a real vault (or `test_vaults/real`) for the demo; never the fixtures in place.

1. `cd app; flutter run -d windows`. **Expected:** the vault picker ("Welcome to Tephra", Open vault, Create new vault). Choose **Create new vault** → name `Demo` in `%TEMP%` → the workspace opens empty ("No note open").
2. Press `Ctrl+N`. **Expected:** `Untitled.md` appears in the explorer in rename mode; type `First` + Enter → `First.md`, opened in a new tab in Source mode with the caret in the editor.
3. Type `# Hello` Enter, `- [ ] task one` Enter (the next line already starts with `- [ ] `), `- [ ] task two` Enter Enter (the empty item ends the list), then `> [!tip] Title` Enter `> Body`, then `Ctrl+B` on a selected word, a `[[Other note]]`, `#demo`, `$x^2$`. **Expected:** syntax colouring while typing; auto-pairs; the tab shows a dot, which disappears about a second after you stop typing.
4. Press `Ctrl+E`. **Expected:** reading view: heading, two checkboxes, a tip callout (with icon/colour), bold text, a link, a tag, mono math. Click the first checkbox. **Expected:** it ticks and the file on disk changes (open it in Notepad: `- [x] task one`).
5. Click the `[[Other note]]` link. **Expected:** a snackbar "“Other note” doesn't exist" with **Create**; press it → `Other note.md` is created and opened.
6. `Ctrl+O` (quick switcher), type `fir` → `First` is found; Enter opens it. `Ctrl+P` (command palette), type `bold` → "Toggle bold" with its shortcut.
7. Source mode: copy an image (for example from the Snipping Tool) and press `Ctrl+V`. **Expected:** `![[Pasted image YYYYMMDDHHmmss.png]]` is inserted, the file exists in the vault root (default `attachmentFolder` `/`), and in reading view the image shows.
8. In Notepad, edit `First.md` (add a line at the end) and save while the note is open and **unmodified** in Tephra. **Expected:** the line appears in Tephra within 1 s, caret/scroll unchanged. Now type a character in Tephra, edit the same file's first line in Notepad and save → **merged** (both changes), no dialog. Edit the **same** line in both → the conflict dialog; choose **Keep both** → a note `First (conflict YYYY-MM-DD HH-mm).md` appears in the explorer.
9. Explorer: rename `First` → `Second` (inline), drag `Second.md` into a new folder `Folder`, duplicate it, delete the duplicate (it goes to `Demo\.trash\Folder\…`), "Reveal in system explorer" opens Windows Explorer with the file selected. **Expected:** after each rename/move a snackbar says links were not updated.
10. Resize the window below 840 dp. **Expected:** phone layout (app bar, drawer for the explorer, no tab bar); above 840 dp the desktop layout returns with the same note open.
11. Close the app (force-quit while typing once). Reopen. **Expected:** the last vault opens, the same tabs are restored, and the text typed up to ~1 s before the kill is present.
12. **[human]** Open the `Demo` vault in Obsidian. **Expected:** all notes, the callout, the task states, the embed and the tag appear identically; `.tephra/` is ignored by Obsidian; edit a note in Obsidian and see it update in Tephra within a second.
13. **[human]** Phone (Android device or emulator): `adb install -r app\build\app\outputs\flutter-apk\app-debug.apk` (build with `flutter build apk --debug`), open the app → picker; **Open vault** → the explanation screen → allow All files access → choose a vault folder; open a note, tap **edit** (mode toggle), the keyboard toolbar appears above the keyboard; use bold, list, task, undo; attach a photo; leave the app (home button) and reopen → text intact. Repeat step 8 using `adb shell "echo external >> /sdcard/Documents/<vault>/<note>.md"`.
14. `dart run tool/roundtrip_check.dart test_vaults/syntax test_vaults/edge test_vaults/real` → `changed=0` for every vault. `dart run tool/kill_test.dart --rounds 20` → `KILL 20/20 ok`.
15. Typing benchmark on the phone (profile mode, 5,000-line note): numbers recorded.

---

## Exit gate

Tick each in `PROGRESS.md` with the evidence (command output or numbers). A gate item that needs a device you do not have is written as "not verified on device" and reported to the human.

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

---

## Hand-off to the next phase

Phase 2 relies on exactly these (names, paths and behaviours are fixed; Phase 2's own inventory table maps to them):

- **Core and vault:** `VaultPath`, exceptions, `Clock`/`ManualClock`, `contentHash`; `VaultFileSystem`, `IoVaultFileSystem` (getter `rootDir`; constructor named parameters `ignore`, `systemTrash`, `watcherMode`, `clock`, `caseInsensitive`, `debounce`, `writer`), `MemoryVaultFileSystem` (`writeCount`, `writeLog`, `emit`), `TextDocument`, `VaultIgnore` (`excludedFolders` is where Phase 2's setting goes: `createVaultFileSystem` in `app/lib/vault/vault_file_system_factory.dart` and `VaultOpener.open` in `app/lib/vault/vault_opener.dart` are the **only** places where the file system is built — Phase 2 wraps it in `IndexingVaultFileSystem` there so `VaultSession.fs`, `vaultFsProvider`, `NoteDocumentStore`, the explorer and the attachment service all see the wrapper).
- **Parser:** `MarkdownParser.parse/parseWith/parseInline`, `ParsedNote` (all fields listed in 01.9), `BlockRef` (`id, start, end, idStart, idEnd`), `TaskItem` (`status, text, start, end, statusOffset, line`), `TaskStatus`, `LineIndex`, `ParserOptions`. **Do not add `Md*` classes.**
- **Editor:** `EditorController` (members in 01.18: `text`, `selection`, `select`, `edits` → `EditorEdit{start, deletedLength, insertedText, isUndoRedo}`, `apply`, `applyEdits(List<EditOperation>)`, `undo/redo`, `replaceAll`, `revealOffset`, `caretRectGlobal`, `isDirty`, `path`, `focus`), `EditorRegistry.controllerFor(path)`/`all`, `activeEditorProvider`, `pendingJumpProvider`, `ReadingViewController.scrollToOffset/scrollToHeading/scrollToBlockRef`, `NoteDocument`/`NoteDocumentStore` (`flushPath`, `retargetPath`, `discardPath`, `peek`, `open`), highlighter overlays (`SourceHighlighter.setOverlays`) for Phase 2's search highlights.
- **Workspace:** `WorkspaceNotifier.openPath/openContent/retargetPath/removePath/goBack/goForward/toggleMode`, `openFile(ref, path, {subpath, newTab})`, `ViewRegistry` (`register`), `SidebarRegistry`/`registerBuiltinPanels` (`app/lib/workspace/builtin_panels.dart` — **the one place** Phase 2 registers its right-sidebar panels), `StatusBarRegistry` (Phase 2's `IndexStatusItem`), `ViewMode` (Phase 2 adds `livePreview`).
- **Replace/upgrade in Phase 2:** the explorer notice `explorerLinksNotUpdatedNotice` (delete), `SimpleLinkResolver` + `LinkActions.openWikiLink` (replace by `LinkNavigator`), the quick switcher data source and scoring (`FuzzyMatcher` → `FuzzyScorer`; keep `QuickSwitcher`, `showQuickSwitcher`, `SwitcherItem`), explorer rename/move calls (`ExplorerService.rename/move` → `LinkRenameService.renameOrMove`), `FuzzyMatcher` remains for the command palette.
- **Android/other phases:** `StoragePermissionService`, `pickFolderWithAccess` (`app/lib/vault/folder_picker.dart`: permission explanation + `getDirectoryPath`, reusable by Phase 5), `AttachmentService` (`save`, `savePastedImage`, `embedTextFor`), `TephraJsonStore`, `AppJsonFile`, the explorer context-menu builder `buildExplorerMenuEntries` in `explorer_menus.dart` (Phase 5/6 add entries there).
- `test_vaults/` stays byte-exact; `tool/roundtrip_check.dart` and the 27 golden files are regression guards for every later phase (Phase 6.4 and 7 intentionally regenerate goldens and must say so in `PROGRESS.md`).
- `scrollable_positioned_list` is already a dependency (Phase 2 step 02.13 must not add it again).

### Provider index (everything Phase 1 defines; names are final)

| Provider | File | Type and meaning |
|---|---|---|
| `initialAppSettingsProvider` | `app/lib/settings/providers.dart` | `Provider<AppSettings>` — loaded in `main()`; always overridden |
| `appSettingsStoreProvider` | `app/lib/settings/providers.dart` | `Provider<AppSettingsStore?>` — persistence of app settings (null in tests/web) |
| `appSettingsProvider` | `app/lib/settings/providers.dart` (re-exported by `app/lib/core/providers.dart`) | `NotifierProvider<AppSettingsNotifier, AppSettings>` — app-level `<appSupportDir>/settings.json` (theme, recent vaults, device id/name, last vault, recent commands) |
| `vaultSettingsProvider` | `app/lib/settings/providers.dart` | `NotifierProvider<VaultSettingsNotifier, VaultSettings>` — `.tephra/settings.json` of the open vault, editable via `update` |
| `clockProvider` | `app/lib/core/providers.dart` | `Provider<Clock>` — all app time goes through it |
| `systemTrashProvider` | `app/lib/core/providers.dart` | `Provider<SystemTrash?>` — Windows recycle-bin implementation, `null` elsewhere |
| `storagePermissionServiceProvider` | `app/lib/core/platform/platform_providers.dart` | `Provider<StoragePermissionService>` — Android All-files-access; no-op elsewhere |
| `vaultSessionProvider` | `app/lib/vault/providers.dart` | `NotifierProvider<VaultSessionNotifier, VaultSession?>` — the open vault session: root path, `vaultId`, `VaultFileSystem`, settings snapshot; `null` when no vault is open |
| `vaultFsProvider` | `app/lib/vault/providers.dart` | `Provider<VaultFileSystem>` — file system of the open vault (throws `StateError` if none) |
| `vaultChangesProvider` | `app/lib/vault/providers.dart` | `StreamProvider<VaultChange>` — external changes from `fs.watch()` |
| `vaultRevisionProvider` | `app/lib/vault/providers.dart` | `NotifierProvider<VaultRevisionNotifier, int>` — bumped after app file operations and external changes; list-like providers watch it |
| `vaultNameProvider` | `app/lib/vault/providers.dart` | `Provider<String>` — display name of the open vault |
| `vaultOpenedHooksProvider` | `app/lib/vault/providers.dart` | `Provider<List<Future<void> Function(Ref)>>` — hooks awaited after a vault opens (workspace restore; Phase 2 adds index start) |
| `vaultFilesProvider` | `app/lib/vault/providers.dart` | `FutureProvider<List<VaultPath>>` — every file in the vault (rebuilds on `vaultRevisionProvider`) |
| `noteCreatorProvider` | `app/lib/vault/providers.dart` | `Provider<NoteCreator>` — creates notes (`createFromName`, `createUntitled`) per the new-note-location setting |
| `noteDocumentStoreProvider` | `app/lib/vault/providers.dart` | `Provider<NoteDocumentStore>` — open note buffers, autosave, external-change dispatch |
| `noteDocumentProvider` | `app/lib/vault/providers.dart` | `Provider.autoDispose.family<NoteDocument, VaultPath>` — the shared buffer of one open note (acquire/release) |
| `parseServiceProvider` | `app/lib/reading/providers.dart` | `Provider<ParseService>` — sync ≤ 50,000 chars, `Isolate.run` above |
| `commandRegistryProvider` | `app/lib/commands/providers.dart` | `Provider<CommandRegistry>` — conventions §7.8; palette, hotkeys and the mobile toolbar read it |
| `hotkeyOverridesProvider` | `app/lib/commands/providers.dart` | `NotifierProvider<…, Map<String, List<SingleActivator>>>` — user shortcuts from `.tephra/hotkeys.json` |
| `recentCommandsProvider` | `app/lib/commands/providers.dart` | `Provider<List<String>>` — recently run command ids |
| `quickSwitcherItemsProvider` | `app/lib/commands/quick_switcher_items.dart` | `FutureProvider<List<SwitcherItem>>` — cached note list for the switcher |
| `phoneScaffoldKeyProvider` | `app/lib/commands/providers.dart` | `Provider<GlobalKey<ScaffoldState>>` — lets commands open the phone drawer |
| `workspaceProvider` | `app/lib/workspace/providers.dart` | `NotifierProvider<WorkspaceNotifier, WorkspaceState>` — panes, tabs, per-tab history, split, sidebars; persisted in `.tephra/workspace.json` |
| `activeNotePathProvider` | `app/lib/workspace/providers.dart` | `Provider<VaultPath?>` — path of the focused tab's note |
| `recentFilesProvider` | `app/lib/workspace/providers.dart` | `NotifierProvider<…, List<VaultPath>>` — most recently opened notes, newest first |
| `viewRegistryProvider` | `app/lib/workspace/providers.dart` | `Provider<ViewRegistry>` — maps file extensions/view types to tab view builders (later phases register `.canvas`, `.base`, `.pdf`, images, graph) |
| `sidebarRegistryProvider` | `app/lib/workspace/providers.dart` | `NotifierProvider<SidebarRegistry, List<SidebarPanelSpec>>` — left/right sidebar panels |
| `statusBarRegistryProvider` | `app/lib/workspace/providers.dart` | `NotifierProvider<StatusBarRegistry, List<StatusBarItemSpec>>` — desktop status bar items |
| `tabDirtyProvider` | `app/lib/workspace/tab_status.dart` | `Provider.family<bool, VaultPath>` — note has unsaved/saving/error state (tab dot) |
| `editorRegistryProvider` | `app/lib/editor/providers.dart` | `Provider<EditorRegistry>` — open `EditorController`s by path |
| `editorOptionsProvider` | `app/lib/editor/providers.dart` | `Provider<EditorOptions>` — indent unit, tab size, font size from vault settings |
| `activeEditorProvider` | `app/lib/editor/providers.dart` | `Provider<EditorController?>` — editor of the focused note (source mode) |
| `activeParsedNoteProvider` | `app/lib/editor/providers.dart` | `NotifierProvider<ActiveParsedNoteNotifier, ParsedNote?>` — parse of the focused note, re-parsed 300 ms after the last change |
| `pendingJumpProvider` | `app/lib/editor/providers.dart` | `NotifierProvider<…, PendingJump?>` — heading/block/offset to reveal when a note view opens |
| `focusEditorOnOpenProvider` | `app/lib/editor/providers.dart` | `NotifierProvider<…, bool>` — one-shot: autofocus the editor of a just-created note |
| `attachmentServiceProvider` | `app/lib/editor/providers.dart` | `Provider<AttachmentService>` — saves pasted/dropped/picked files per §6.7 |
| `explorerExpandedProvider`, `explorerSelectedProvider`, `explorerRenamingProvider` | `app/lib/explorer/explorer_state.dart` | `NotifierProvider`s — expanded folders, selected path, row in rename mode |
| `explorerChildrenProvider`, `explorerRowsProvider` | `app/lib/explorer/explorer_state.dart` | `FutureProvider`s — sorted children of a folder; flattened visible tree |
| `explorerServiceProvider` | `app/lib/explorer/providers.dart` | `Provider<ExplorerService>` — create/rename/move/delete/duplicate/reveal |

(Every provider named in Phase 2–8 as coming from Phase 1 — `vaultSessionProvider`, `vaultFsProvider`, `vaultSettingsProvider`, `appSettingsProvider`, `workspaceProvider`, `activeNotePathProvider`, `activeParsedNoteProvider`, `commandRegistryProvider`, `viewRegistryProvider` — is in the table above under exactly that name; Phase 2's `editorRegistry` is `editorRegistryProvider`.)

### Conflicts found while writing this phase (also copy them into `PROGRESS.md` → Conflicts)

1. `docs/plan/PHASE_PLAN.md` 1.1 lists a `SafVaultFileSystem` fallback; this phase defers SAF (human decision) — Android uses All-files-access or the app-private folder. Phase 4 step 04.x mentions `fsKind: saf`; only `io` exists.
2. `PHASE_PLAN.md` 1.3 says "build on the `markdown` package"; the conventions (§7.3) require a hand-written parser — the conventions win.
3. Phase 2 step 02.10 lists `EditorController.applyEdits(List<TextEdit>)` with `TextEdit` from `tephra_index`; Phase 1 cannot depend on it, so `applyEdits` takes `List<EditOperation>` (same fields). Phase 2 adapts its call sites.
4. Phase 6 step 06.2 creates `ViewKind`, `TabContent`, `ViewRegistry` and `viewRegistryProvider` "unless Phase 1 already has equivalents": Phase 1 **does** (same names and shapes, `FileTabContent` only); Phase 6 must extend them, not recreate them.
5. Phase 2 (inventory item 17 and step 02.3) assumes `LineIndex` may be missing; Phase 1 defines it in `tephra_markdown` (Phase 2 step 02.3 must skip creating it).
6. Phase 6 table lists `super_clipboard`; Phase 1 chose `pasteboard` (no Rust toolchain on this machine).
