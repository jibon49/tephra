# 00 — Conventions & Contracts (authoritative)

Every phase file builds on this document. When a phase file says "per conventions", it means this file.
**Do not change anything here without asking the human.**

---

## 1. Product facts you must keep in mind

- Name **Tephra**. Android application id / Windows identity: **`com.tephra.app`**. Display name: `Tephra`.
- Targets: **Android** (min SDK 26, compile/target = Flutter defaults) and **Windows 10/11 x64**. Web is only a dev preview.
- Distribution (v1): direct-download signed APK and Windows `.exe` installer. Stores later.
- Sync v1: user's own **Google Drive**. v2: our own hosted **Tephra Cloud** server.
- Closed-source for now; keep every dependency permissive (MIT/BSD/Apache-2.0/zlib/MPL-2.0/Unlicense).
- Copyright header (first line of every Dart file you create): `// © 2026 Tephra. All rights reserved.`

---

## 2. Repository layout (exact)

```
tephra-gemini/                    ← repo root, Dart pub workspace root
  GEMINI.md  AGENTS.md  PROGRESS.md  README.md  THIRD_PARTY_NOTICES.md
  pubspec.yaml                    ← workspace root (name: tephra_workspace)
  analysis_options.yaml           ← shared lints for every package
  .gitignore
  .github/workflows/ci.yml
  app/                            ← Flutter app (package name: tephra)
    pubspec.yaml  l10n.yaml
    lib/
      main.dart                   ← bootstrap only (logging, crash handlers, ProviderScope)
      app.dart                    ← MaterialApp / router root
      core/                       ← app-wide services: logging, settings, platform adapters, providers.dart
      l10n/                       ← app_en.arb (+ generated app_localizations*.dart)
      theme/                      ← AppTheme, theme models
      commands/                   ← command registry, palette, hotkeys
      vault/                      ← vault picker, vault session providers
      workspace/                  ← shell layouts (phone / desktop), tabs, splits, panes
      editor/                     ← source + live preview editor, toolbar, autocomplete
      reading/                    ← reading view renderer (AST → widgets)
      explorer/  search/  links/  outline/  tags/  bookmarks/  properties/
      sync_ui/  stickies/  capture/  import_export/  graph/  canvas/  bases/  media/
      settings/
    test/                         ← mirrors lib/ structure
    integration_test/
  packages/
    tephra_core/      tephra_markdown/  tephra_vault/   tephra_index/
    tephra_search/    tephra_sync/      tephra_io/
    (later: tephra_ai/ in Phase 8)
  server/                         ← Phase 10 only (Tephra Cloud, Dart shelf)
  tool/                           ← dev.dart, check_licenses.dart, gen_bench_vault.dart, ...
  test_vaults/                    ← fixture vaults (bench/ is generated + git-ignored)
  docs/                           ← plan/, spikes/, decisions/
  secrets/                        ← git-ignored
```

Each package follows standard Dart layout:
```
packages/tephra_x/
  pubspec.yaml        (resolution: workspace)
  README.md
  lib/tephra_x.dart   ← public API: only `export 'src/...';` lines + library doc comment
  lib/src/...         ← implementation (private to the package)
  test/...            ← `*_test.dart`, mirrors lib/src
```

## 3. Package dependency rules (who may import whom)

```
tephra_core        ← (nothing)
tephra_markdown    ← core
tephra_vault       ← core
tephra_index       ← core, markdown, vault
tephra_search      ← core, markdown, index
tephra_sync        ← core, vault
tephra_io          ← core, markdown, vault
tephra_ai (Ph. 8)  ← core, markdown, index
app                ← all packages
server (Ph. 10)    ← core, sync
```
- Arrows only point down this list. **No cycles.** No package imports `package:flutter`.
- Packages export a deliberately small public API through `lib/tephra_x.dart`. The app never imports `package:tephra_x/src/...`.

## 4. Workspace & pubspec rules

- Root `pubspec.yaml` lists every member under `workspace:`; every member has `resolution: workspace`.
- SDK constraint everywhere: `sdk: ^3.13.0`. Flutter app also has `flutter: sdk: flutter`.
- Run `flutter pub get` **at the repo root** (one lockfile, one `.dart_tool/package_config.json` for all members).
- Shared dev dependency at root: `flutter_lints`. Packages add `test` as a dev dependency.
- Add dependencies with `flutter pub add <pkg>` (app) or `dart pub add <pkg>` (package dir) so you get a current, compatible version.
  Then run `dart run tool/check_licenses.dart`.
- Versions known to resolve together on this machine (Flutter 3.47.7): `flutter_riverpod ^3.4.3`, `logging ^1.3.0`, `path ^1.9.1`,
  `path_provider ^2.1.6`, `intl ^0.20.3`, `flutter_lints ^6.0.0`, `test ^1.25.6`.

## 5. Coding rules

### 5.1 Style
- `dart format` default style. Single quotes. Trailing commas (lint enforces).
- Files `snake_case.dart`; types `UpperCamelCase`; members `lowerCamelCase`; constants `lowerCamelCase`.
- One main public type per file; file named after it (`vault_path.dart` → `VaultPath`).
- Doc comments (`///`) on every public type and member in packages. Explain *why*, not *what*, in inline comments; keep them rare.

### 5.2 Analysis (root `analysis_options.yaml`)
Include `package:flutter_lints/flutter.yaml`; enable `strict-casts`, `strict-inference`, `strict-raw-types`;
make `unused_import` and `missing_return` errors; enable at least: `always_declare_return_types, avoid_dynamic_calls, avoid_print,
avoid_slow_async_io, cancel_subscriptions, close_sinks, directives_ordering, prefer_final_fields, prefer_final_locals,
prefer_single_quotes, require_trailing_commas, sort_constructors_first, throw_in_finally, unawaited_futures, use_super_parameters`.
Exclude `**/*.g.dart`, `**/build/**`, `test_vaults/**`. (Do **not** enable `unnecessary_await_in_return`; it is deprecated.)

### 5.3 Models
- Immutable: `final` fields, `const` constructors where possible, `copyWith`, and value equality (`==`/`hashCode`) written by hand
  or with `Object.hash`. No code generation for models (no freezed/json_serializable) — keeps the build simple.
- JSON: hand-written `fromJson(Map<String, Object?>)` / `toJson()`; cast immediately, never pass `dynamic` around.
- Prefer `sealed class` hierarchies + `switch` exhaustiveness for variants (AST nodes, results, sync actions, changes).

### 5.4 Errors
- Packages throw subclasses of `TephraException` (from `tephra_core`) for expected failures; never throw strings.
- `Result`-style returns are not used; use exceptions + typed catch at the boundary (providers/UI).
- UI shows errors with plain-language messages from l10n; technical details go to the log.

### 5.5 Logging
- `package:logging`. One `Logger('<area>')` per file/class (`Logger('vault.fs')`, `Logger('index')`, `Logger('sync.drive')`).
- Levels: `fine` (debug detail), `info` (lifecycle), `warning` (recovered problems), `severe` (failures).
- Never log note contents, passwords, tokens or keys.

### 5.6 Async & isolates
- Long work (parse > 1 file, indexing, search over many files, graph layout, sync, import/export, encryption of many files)
  runs off the UI isolate: `Isolate.run` for one-shot work, a long-lived worker isolate for the indexer/sync engine.
- UI never awaits more than ~16 ms of synchronous work.
- Every `StreamSubscription` is cancelled; every `StreamController`/`IOSink` closed (lints enforce).

### 5.7 State management (app)
- **Riverpod 3** (`flutter_riverpod`), **no code generation** (no riverpod_generator).
- Use `Provider` for services, `NotifierProvider` / `AsyncNotifierProvider` for state, `.family` for per-id state (e.g. per-tab, per-note).
- Each feature folder has a `providers.dart` declaring its providers. App-wide service providers live in `app/lib/core/providers.dart`.
- Widgets are `ConsumerWidget` / `ConsumerStatefulWidget`. Keep business logic in notifiers or packages, not in widgets.
- Tests override providers with `ProviderScope(overrides: [...])`.

### 5.8 Adaptive layout
- **Breakpoint:** width ≥ **840 dp** → *desktop layout* (sidebars, tabs, splits, status bar). Below → *phone layout*
  (single pane, swipe-in drawers, bottom keyboard toolbar). Tablets in landscape get desktop layout automatically.
- Decide with `MediaQuery.sizeOf(context).width`, never with `Platform`.
- Input: support mouse + keyboard shortcuts and touch everywhere. Hover-only features need a long-press equivalent.
- Minimum touch target 48 dp on phone layout.

### 5.9 Platform-specific code
- Wrap platform-only features behind an interface in `app/lib/core/platform/` with a no-op implementation for unsupported platforms:
  `TrayService`, `GlobalHotkeyService`, `WindowService`, `HomeWidgetService`, `OverlayService`, `NotificationService`,
  `StoragePermissionService`. Pick the implementation in a provider using `Platform.isWindows` / `Platform.isAndroid`.

### 5.10 Localisation
- `flutter_localizations` + `intl`, ARB in `app/lib/l10n/app_en.arb`, `l10n.yaml` with `nullable-getter: false`, `generate: true`.
- Keys are `lowerCamelCase` and descriptive (`explorerNewNote`, `syncErrorDriveFull`). Add an `@key` description for anything ambiguous.
- English only for now; the structure must allow Bangla (`app_bn.arb`) later — so never concatenate translated fragments.

---

## 6. File-format contract (Obsidian compatibility)

### 6.1 Vault
- A vault is a folder. Notes: `*.md`, UTF-8. Attachments: any other file. Canvas: `*.canvas` (JSON Canvas 1.0). Bases: `*.base` (YAML).
- Ignored by Tephra's indexer and explorer: `.obsidian/`, `.tephra/`, `.trash/`, `.git/`, `node_modules/`, any path segment starting with `.`
  (unless user setting says show hidden), plus the user's "excluded folders" setting.
- Tephra writes its own data **only** in `<vault>/.tephra/`. It **never writes** to `.obsidian/` (read-only import of settings).

### 6.2 Text round-trip rule
- Read: decode UTF-8 (malformed bytes → `allowMalformed: true`, and mark the file read-only in the UI to avoid damaging it).
  Record whether there was a BOM and the dominant line ending (`\n` or `\r\n`). In memory, text is normalised to `\n`.
- Write: only if the in-memory text differs from what was loaded. Re-apply BOM and line ending.
- Files with **mixed** line endings: in-memory normalised; when saved after an edit, the dominant ending is used (acceptable);
  an unedited file is never written. The round-trip test asserts: open + save-without-edit writes nothing; open + edit + undo-to-original
  + save writes nothing.

### 6.3 Markdown syntax that must be supported (parser + renderer)
CommonMark + GFM (tables, task lists, strikethrough `~~`, autolinks) + Obsidian:
`[[Target]]`, `[[Target|Alias]]`, `[[Target#Heading]]`, `[[Target#Heading|Alias]]`, `[[Target#^blockid]]`, `[[#Heading]]` (same note),
embeds `![[...]]` with optional `|300`, `|300x200`, `#page=3`; `#tag`, `#nested/tag` (not in code, not in URLs, not pure numbers like `#123`);
`==highlight==`; `%%comment%%` inline and multi-line; block IDs `^id` at end of a block (`[A-Za-z0-9-]+`);
callouts `> [!type] Title`, `> [!type]+`, `> [!type]-` (fold), nested callouts; task status any single char `[ ]`, `[x]`, `[/]`, `[-]`, `[>]`…;
math `$inline$` (no space after opening/before closing `$`), `$$block$$`; footnotes `[^1]` + `[^1]: text`, inline `^[text]`;
fenced code with language; ` ```mermaid `, ` ```query `, ` ```base `, ` ```tephra-button ` blocks (rendered specially in later phases; `tephra-button` is Tephra-only and shows as a plain code block in Obsidian); HTML blocks/inline (rendered as text or minimal subset, never executed).

### 6.4 Frontmatter / properties
- YAML between a first line `---` and the next `---` line, only at the very start of the file.
- Edits go through `yaml_edit` so untouched keys keep their formatting, comments and order.
- Standard keys: `tags` (list or string), `aliases` (list or string), `cssclasses`. Property types registry stored in `.tephra/types.json`
  (same shape as Obsidian's `.obsidian/types.json`, imported from it on first open).

### 6.5 Tephra-owned frontmatter keys (the only ones Tephra adds)
| Key | Type | Meaning |
|---|---|---|
| `tephra-sticky` | bool | Note is a sticky |
| `sticky-color` | string | `yellow`/`pink`/`blue`/`green`/`purple`/`gray` or `#RRGGBB` |
| `sticky-pinned` | bool | Always on top (Windows floating window) |
| `sticky-remind` | datetime `YYYY-MM-DDTHH:mm` | Reminder time |
| `sticky-expire` | date `YYYY-MM-DD` | Auto-archive after |
| `sticky-locked` | bool | Read-only |

### 6.6 `.tephra/` folder contents (per vault)
| File | Content |
|---|---|
| `.tephra/vault.json` | `{ "id": "<uuid v4>", "createdAt": ISO, "formatVersion": 1 }` |
| `.tephra/settings.json` | vault-level settings (attachment folder, new-note location, link format, daily notes, templates incl. `templates.askOnNewNote` and `templates.folderDefaults`, excluded folders, …) |
| `.tephra/hotkeys.json` | user hotkey overrides `{ "<commandId>": ["Ctrl+Shift+K", ...] }` |
| `.tephra/bookmarks.json` | same structure as Obsidian `bookmarks.json` (`items: [{type, title?, path?, subpath?, query?, items?}]`) |
| `.tephra/types.json` | property types `{ "types": { "<key>": "text|multitext|number|checkbox|date|datetime|aliases|tags" } }` |
| `.tephra/workspace.json` | open tabs/layout per device id |
| `.tephra/stickies.json` | per-device sticky window positions `{ "<deviceId>": { "<vaultPath>": {x,y,w,h,screen,collapsed} } }` |
| `.tephra/history/` | local snapshots (Phase 3) |
| `.tephra/cache/` | rebuildable caches (never synced) |
App-level settings (not per vault): `<appSupportDir>/settings.json` (theme, recent vaults, device id, device name).
The SQLite index lives in `<appSupportDir>/index/<vaultId>.sqlite` — **not** inside the vault (it would sync and conflict).

### 6.7 Attachments
Pasted/dropped files are saved per the vault setting (`attachmentFolder`: `"/"` vault root, `"./"` same folder as note, `"./sub"` subfolder
of note's folder, or `"Attachments"` fixed folder) with Obsidian naming `Pasted image YYYYMMDDHHmmss.png`; insert `![[name.png]]`.

---

## 7. Core contracts (Dart signatures — implement exactly these names)

These are the seams between packages. Implementation details are in the phase files; the **names, shapes and semantics here are fixed**.

### 7.1 `tephra_core`
```dart
/// Normalised vault-relative path: forward slashes, no leading/trailing slash, no `.`/`..` segments.
/// Comparison is case-sensitive; [caseKey] is the lower-case form used for case-insensitive lookups (Windows).
final class VaultPath implements Comparable<VaultPath> {
  factory VaultPath(String raw);           // normalises; throws InvalidPathException for '..' escaping or empty
  static const VaultPath root;             // the vault root (value == '')
  String get value;                        // 'Folder/Note.md'
  String get name;                         // 'Note.md'
  String get stem;                         // 'Note'
  String get extension;                    // 'md' (lower-case, no dot; '' if none)
  VaultPath? get parent;                   // null for root
  String get caseKey;                      // value.toLowerCase()
  bool get isMarkdown;                     // extension == 'md'
  bool get isRoot;
  VaultPath join(String child);
  VaultPath withName(String newName);
  bool isWithin(VaultPath folder);
}

/// Base of every expected failure. Not sealed/final: other packages extend these classes
/// (e.g. tephra_search's SearchSyntaxException extends ParseException).
abstract class TephraException implements Exception { const TephraException(this.message); final String message;
  @override String toString() => '$runtimeType: $message'; }
class InvalidPathException extends TephraException { ... }
class FileNotFoundException extends TephraException { final VaultPath path; ... }
class FileConflictException extends TephraException { final VaultPath path; ... }   // target exists
class PermissionDeniedException extends TephraException { ... }
class ParseException extends TephraException { ... }
class SyncException extends TephraException { ... }                                 // subclassed in tephra_sync
class CryptoException extends TephraException { ... }

/// Clock abstraction so tests control time.
abstract interface class Clock { DateTime now(); }
final class SystemClock implements Clock { const SystemClock(); DateTime now() => DateTime.now(); }

/// Content hash used by index and sync (lower-case hex SHA-256 of the raw file bytes).
String contentHash(List<int> bytes);   // uses package:crypto
```

### 7.2 `tephra_vault`
```dart
enum LineEnding { lf, crlf }
final class TextDocument {               // a decoded text file
  const TextDocument({required this.text, this.hasBom = false, this.lineEnding = LineEnding.lf, this.malformed = false});
  final String text;                     // normalised to '\n'
  final bool hasBom; final LineEnding lineEnding; final bool malformed;
  List<int> encode();                    // re-applies BOM + line ending
  static TextDocument decode(List<int> bytes);
}
final class VaultEntry {
  final VaultPath path; final bool isFolder; final int size; final DateTime modified; final DateTime? created;
}
enum TrashMode { system, vaultTrash, permanent }   // vaultTrash = move into '<vault>/.trash/'
sealed class VaultChange { final VaultPath path; }
final class FileCreated extends VaultChange {}  final class FileModified extends VaultChange {}
final class FileDeleted extends VaultChange {}  final class FileMoved extends VaultChange { final VaultPath from; }

abstract interface class VaultFileSystem {
  String get rootDisplayPath;                                  // for UI only
  Future<List<VaultEntry>> list({VaultPath folder = VaultPath.root, bool recursive = true});
  Future<VaultEntry?> stat(VaultPath path);
  Future<List<int>> readBytes(VaultPath path);
  Future<TextDocument> readText(VaultPath path);
  Future<void> writeBytes(VaultPath path, List<int> bytes);    // atomic; creates parent folders
  Future<void> writeText(VaultPath path, TextDocument doc);    // atomic
  Future<void> createFolder(VaultPath path);
  Future<void> move(VaultPath from, VaultPath to);             // file or folder; throws FileConflictException if target exists
  Future<void> delete(VaultPath path, {TrashMode mode = TrashMode.vaultTrash});
  Stream<VaultChange> watch();                                 // debounced (~150 ms), excludes our own writes
  Future<void> dispose();
}
final class IoVaultFileSystem implements VaultFileSystem { IoVaultFileSystem(String rootDir); ... }      // Windows + Android shared storage
final class MemoryVaultFileSystem implements VaultFileSystem { MemoryVaultFileSystem({bool caseInsensitive = false}); ... } // tests; caseInsensitive simulates Windows
```

### 7.3 `tephra_markdown`
```dart
/// Every node carries its source range [start, end) as UTF-16 offsets into the note text (same indexing as Dart String).
sealed class MdNode { MdNode(this.start, this.end); final int start; final int end; List<MdNode> get children; }
// Block nodes:
final class MdDocument, MdFrontmatter(String yaml, int contentStart), MdHeading(int level, String? blockId), MdParagraph,
  MdBlockQuote, MdCallout(String type, String? title, CalloutFold fold), MdList(bool ordered, int startNumber, bool tight),
  MdListItem(TaskStatus? task /* char or null */), MdCodeBlock(String? language, String code, bool fenced),
  MdMathBlock(String tex), MdTable(List<TableAlign> aligns), MdTableRow(bool header), MdTableCell,
  MdThematicBreak, MdHtmlBlock(String html), MdFootnoteDefinition(String label), MdCommentBlock(String text)
// Inline nodes:
final class MdText(String text), MdEmphasis, MdStrong, MdStrikethrough, MdHighlight, MdInlineCode(String code),
  MdWikiLink(String target, String? heading, String? blockRef, String? alias, bool embed, EmbedSize? size, String? pdfPage),
  MdLink(String url, String? title, bool image), MdAutolink(String url), MdTag(String name /* without '#' */),
  MdBlockId(String id), MdInlineMath(String tex), MdFootnoteRef(String label), MdInlineFootnote, MdCommentInline(String text),
  MdHtmlInline(String html), MdHardBreak, MdSoftBreak
enum CalloutFold { none, expanded, collapsed }
enum TableAlign { none, left, center, right }

final class ParsedNote {
  final String text; final MdDocument root;
  final Map<String, Object?> frontmatter;      // decoded YAML (empty if none / invalid)
  final bool frontmatterValid;
  // Convenience extractions (computed once by the parser):
  final List<MdHeading> headings; final List<MdWikiLink> wikiLinks; final List<MdLink> links;
  final List<String> tags;                     // inline + frontmatter tags, without '#', original case
  final List<String> aliases; final List<BlockRef> blockIds; final List<TaskItem> tasks;
}
abstract final class MarkdownParser { static ParsedNote parse(String text); }
```
Parser is **hand-written** in `tephra_markdown` (the `markdown` pub package does not give source offsets). Details in Phase 1.

### 7.4 `tephra_index` (drift + SQLite FTS5)
```dart
final class NoteIndex {                                   // one per open vault
  static Future<NoteIndex> open(String dbFile, VaultFileSystem fs, {Clock clock});
  Stream<IndexProgress> get progress;                     // full-index progress
  Future<void> reconcile();                               // startup: compare mtime/size/hash, reindex changed
  Future<void> onChange(VaultChange change);              // incremental
  Future<void> rebuild();
  // Queries:
  Future<List<NoteSummary>> allNotes();
  Future<NoteSummary?> note(VaultPath path);
  Future<VaultPath?> resolveLink(String target, {required VaultPath from});   // Obsidian resolution rules
  Future<List<LinkRecord>> backlinks(VaultPath target);
  Future<List<UnlinkedMention>> unlinkedMentions(VaultPath target);
  Future<List<LinkRecord>> outgoing(VaultPath source);
  Future<List<TagCount>> tags();
  Future<List<HeadingRecord>> headings(VaultPath path);
  Future<List<TaskRecord>> tasks({bool? done});
  Future<List<FtsHit>> fullText(String ftsQuery, {int limit = 200});
  Future<void> close();
}
```

### 7.5 `tephra_search`
```dart
sealed class SearchExpr { }                              // And, Or, Not, Term, Phrase, Regex, Operator(file:, path:, tag:, line:, block:, section:, task:, task-todo:, task-done:, match-case:, ignore-case:, [prop], [prop:value])
abstract final class SearchParser { static SearchExpr parse(String query); }        // throws SearchSyntaxException (extends ParseException)
final class SearchEngine { SearchEngine(NoteIndex index, VaultFileSystem fs); Stream<SearchResult> run(SearchExpr expr, {CancelToken? cancel}); }
final class SearchResult { final VaultPath path; final List<SearchMatch> matches; }       // matches have line, start, end, snippet
```

### 7.6 `tephra_sync`
```dart
abstract interface class SyncProvider {                  // Google Drive (v1), Tephra Cloud (v2), Memory (tests)
  String get id;                                         // 'gdrive', 'tephra-cloud', 'memory'
  Future<void> connect();                                // auth / open
  Future<List<RemoteObject>> list(String prefix);
  Future<List<int>> get(String key);
  Future<void> put(String key, List<int> bytes);         // create or replace; keys are opaque strings
  Future<void> delete(String key);
  Future<RemoteChanges> changesSince(String? cursor);    // returns changed keys + new cursor
  Future<Quota?> quota();
}
// Remote layout (both providers): 'blobs/<sha256-of-ciphertext>' (immutable), 'journals/<deviceId>/<seq>.json.enc' (append-only),
// 'snapshots/<deviceId>/<seq>.json.enc', 'backups/<timestamp>/manifest.json.enc', 'vault.json' (public header: format version, KDF params, wrapped key),
// 'devices/<deviceId>.json.enc' and 'devices/<deviceId>.revoked.json.enc', 'locks/gc-<deviceId>.json.enc' and 'locks/gc-state.json.enc'
// (one lease file per device: Drive has no compare-and-swap). "History" is not a prefix: it is old journal entries + retained blobs.
// RemoteObject, RemoteChanges (with cursorWasReset) and Quota are defined in Phase 3 step 03.2; Phase 10 reuses them unchanged.
final class SyncEngine { ... }      // planner + executor; details in Phase 3
sealed class SyncAction { }        // Upload, Download, Merge, ConflictCopy, DeleteLocal, DeleteRemote, RenameLocal, RenameRemote
```

### 7.7 `tephra_io`
```dart
abstract interface class Importer { String get id; String get label; Future<ImportPreview> preview(ImportSource src);
  Stream<ImportProgress> run(ImportSource src, VaultFileSystem target, VaultPath targetFolder); }
abstract interface class Exporter { String get id; String get label; String get fileExtension;
  Future<void> export(ExportRequest req, ExportSink sink); }
final class ImportReport { final int notes; final int attachments; final List<String> warnings; }
```

### 7.8 App: commands
```dart
final class TephraCommand {
  const TephraCommand({required this.id, required this.label, this.icon, this.defaultShortcuts = const [],
    required this.run, this.isAvailable, this.showInPalette = true, this.showInMobileToolbar = false});
  final String id;                                   // 'editor.toggle-bold', 'app.open-quick-switcher' (area.verb-noun)
  final String Function(AppLocalizations l10n) label;
  final IconData? icon;
  final List<SingleActivator> defaultShortcuts;      // Ctrl on Windows; same activators used on Android hardware keyboards
  final void Function(WidgetRef ref, BuildContext context) run;
  final bool Function(WidgetRef ref)? isAvailable;
  final bool showInPalette; final bool showInMobileToolbar;
}
final commandRegistryProvider = Provider<CommandRegistry>(...);   // register / byId / all / shortcutsMap
```
Every user action that exists as a button must also be a command (palette, hotkeys and mobile toolbar all read the registry).

---

## 8. Testing conventions

- Packages: `dart test` (run from package dir). App: `flutter test` (from `app/`). Integration: `flutter test integration_test` on a device.
- Test files mirror source: `lib/src/vault_path.dart` → `test/vault_path_test.dart`.
- Fixture vaults live in `test_vaults/`: `syntax/` (one note per syntax element), `edge/` (unicode names, CRLF, BOM, huge note, empty files,
  deep folders), `real/` (copy of a real Obsidian vault — ask the human for one, or use a generated realistic vault), `bench/`
  (generated by `tool/gen_bench_vault.dart`, git-ignored).
- Golden tests for rendering: `matchesGoldenFile('goldens/<name>.png')`, generated on Windows; mark them `@Tags(['golden'])`.
- Time: inject `Clock`. Randomness: inject `Random(seed)`; fuzz tests print their seed on failure.
- Every bug fixed gets a regression test.

## 9. Git conventions

- Branches `phase-NN`; commits `phase NN.S: <imperative summary>`; merge to `main` with `--no-ff` at the gate; tag `v0.NN.0`.
- Never commit `build/`, `.dart_tool/`, `secrets/`, keystores, `test_vaults/bench/`.
- Never force-push or rewrite `main`.

## 10. Performance budgets (checked from Phase 2's gate on)

Mid-range Android phone (6 GB RAM) and a normal Windows laptop, 10k-note bench vault:

| Metric | Budget |
|---|---|
| Cold start → editable note (after first index) | Android < 2.5 s, Windows < 1.5 s |
| First full index of 10k notes (background, UI usable) | Android < 60 s, Windows < 20 s |
| Typing latency, 5,000-line note | < 16 ms per keystroke |
| Plain-text search, 10k notes | < 200 ms |
| Quick switcher results | < 50 ms |
| Memory with 10k-note vault | Android < 350 MB, Windows < 500 MB |
| Release APK size (per ABI) | < 40 MB |

Measure with `Stopwatch` in a `--profile` build (not debug). Record numbers in `PROGRESS.md`.

## 11. Dev Launcher (the human's standing rule)

The project must be runnable from Dev Launcher (`http://127.0.0.1:7799`, code at `D:\script\dev-launcher`, read its README):
- `README.md` has a `## Install` section (`flutter pub get`) and a `## Run` section with the start command in a fenced block:
  `dart run tool/dev.dart`.
- `tool/dev.dart` reads `PORT` with default **8093** (`int.parse(Platform.environment['PORT'] ?? '8093')`), runs
  `flutter run -d web-server --web-hostname 0.0.0.0 --web-port <PORT>` in `app/` with inherited stdio, and first prints
  `Local: http://localhost:<PORT>/` and `Network: http://<lan-ip>:<PORT>/`. One long-running process, logs to stdout, no extra windows.
- Avoid ports 3000, 4000, 5432, 5433, 8000, 8765, 8800, 7799, 7800, and **8091/8092** (used by the other build).
- Register via the API, never by editing `projects.json`: `POST /api/inspect` with `{ "path": "D:\\script\\tephra-gemini" }`,
  review the proposal, then `POST /api/projects` with the proposal and `autoStart: false`; start with `POST /api/projects/<id>/start`
  and check `GET /api/logs/<id>/<label>`. Name it **"Tephra (Gemini build)"**.
- Phase 10's server uses `PORT` default **8094** and is registered as a second process of the same project.
