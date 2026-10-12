# Phase 05 — Import & export

> **Duration:** 3 weeks (22 steps: 05.1–05.22).
> **Goal:** make it easy to move into Tephra from other apps (Obsidian, Markdown/text folders, HTML, Notion, Evernote, Google Keep, Bear,
> Roam, Logseq, Apple Notes, OneNote, CSV) and to get anything out (zip, encrypted backup, PDF, HTML, DOCX, portable Markdown),
> with every importer writing Obsidian-compatible Markdown and a report of what it could not convert.

Read `GEMINI.md` and `instructions/00-conventions.md` again before you start. This file never redefines a contract; "conventions §X" means
that section of `00-conventions.md`, and that section wins over anything here. The `tephra_io` contract is conventions §7.7 — the names
`Importer`, `Exporter`, `ImportReport`, `ImportPreview`, `ImportProgress`, `ImportSource`, `ExportRequest`, `ExportSink` and the method shapes there are fixed;
this phase defines the fields of the types §7.7 only names.

---

## Before you start

### Prerequisite gate (all must be true; otherwise stop and tell the human)

1. `PROGRESS.md` shows every Phase 4 step and exit-gate item checked, and `git tag --list v0.04.0` prints `v0.04.0`.
2. `git status` is clean on `main`.
3. From the repo root these succeed:
   ```powershell
   flutter pub get
   dart format --output=none --set-exit-if-changed app/lib app/test packages tool
   flutter analyze --fatal-infos
   cd packages/tephra_io; dart test; cd ../..
   cd app; flutter test; cd ..
   ```
4. Create the branch: `git checkout -b phase-05`.

### What already exists (Phases 0–4)

| Area | What you can use |
|---|---|
| `tephra_core` | `VaultPath`, `TephraException` + subclasses (`ParseException`, `FileConflictException`, `CryptoException`, …), `Clock`, `contentHash` (§7.1) |
| `tephra_vault` | `VaultFileSystem` (atomic `writeBytes`/`writeText`, `list`, `stat`, `move`, `delete`), `IoVaultFileSystem`, `MemoryVaultFileSystem`, `TextDocument` (§7.2) |
| `tephra_markdown` | `MarkdownParser.parse` → `ParsedNote` with an AST whose every node has UTF-16 source offsets; node classes listed in §7.3 |
| `tephra_index`, `tephra_search` | app-side only for this phase (`tephra_io` must not import them, §3) |
| `tephra_io` | an empty package skeleton from Phase 0 (`pubspec.yaml`, `lib/tephra_io.dart`, maybe a placeholder test) |
| App | reading view, editor, explorer (with context menus), command registry + palette (§7.8), properties type registry (`.tephra/types.json`), vault settings incl. attachment folder (§6.7), Phase 1 folder picker for Android shared storage, daily-notes settings, Phase 4 stickies |

### Discovery task (before step 05.1; no code changes)

Find and write into `PROGRESS.md` under `### Phase 5 — discovered APIs`:
- the `tephra_io` skeleton files that exist;
- the app's vault-fs provider, `NoteIndex` provider and properties-type registry (class + method to add a type);
- the explorer context-menu extension point (how Phase 1 adds "Rename", "Delete" to the menu);
- the Phase 1 Android folder picker widget (class name) and the "All files access" check;
- whether `tool/check_licenses.dart` has a manual override table (needed for `html`, whose pub.dev page shows licence "unknown" although its LICENSE file is MIT).

---

## What exists when done

- `packages/tephra_io` (pure Dart) with: import framework (sources, preview, isolate runner with progress + cancel, report), shared helpers
  (HTML→Markdown, safe file names, attachment de-dup, frontmatter builder, link rewriting, simple link resolver, CSV parser), twelve importers
  plus the Tephra-backup restore importer, and exporters: zip, encrypted `.tephra-backup`, PDF, HTML, DOCX, portable Markdown.
- Fixture-based snapshot tests for every importer and exporter under `packages/tephra_io/test/fixtures/<source>/`.
- App: Import wizard and Export dialog on both layouts; commands `io.import`, `io.export-note`, `io.export-folder`, `io.export-vault`;
  explorer context-menu entries; Android share sheet and Windows "Save as…".
- Tag `v0.05.0` (format `v0.NN.0` of GEMINI.md §3 and conventions §9; some earlier phase files wrote the un-padded `v0.03.0`/`v0.04.0` — if `git tag --list` shows the un-padded form, note it in `PROGRESS.md`; the tag you create now is `v0.05.0`).

---

## Dependencies

Add to `packages/tephra_io` with `dart pub add <name>` (run inside `packages/tephra_io`), and to `app/` with `flutter pub add <name>`.
Run `dart run tool/check_licenses.dart` after adding. **Before coding against a package, open its README/API docs from the pub cache
(`%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\<name>-<version>\`) and check the current API**; signatures below were checked on 2026-10-11. If the
README differs, follow the README and note it in `PROGRESS.md`.

| Package | Where | Checked version | Licence | Purpose |
|---|---|---|---|---|
| `archive` | tephra_io | 4.x (latest) | MIT | read/write zip (`ZipDecoder`, `ZipEncoder`, `InputFileStream`, `OutputFileStream`); DOCX container |
| `html` | tephra_io | 0.15.x | permissive (pub.dev may show "unknown": open the LICENSE file in the pub cache, identify it — BSD-3-Clause or MIT, both allowed — and add a manual override `html: <that licence>` to the licence tool's override table) | HTML parsing for the HTML→Markdown converter |
| `xml` | tephra_io | latest | MIT | ENEX parsing; DOCX XML building/inspection |
| `pdf` | tephra_io | latest | Apache-2.0 | PDF generation (pure Dart) |
| `cryptography` | tephra_io | already used by Phase 3 (same version) | Apache-2.0 | AES-256-GCM + Argon2id for `.tephra-backup` |
| `crypto` | tephra_io | already in core | BSD-3-Clause | MD5 (Evernote resource hashes) |
| `path` | tephra_io | ^1.9.1 | BSD-3-Clause | path joins for real directories |
| `share_plus` | app | latest | BSD-3-Clause | Android share sheet |
| `file_picker` | app | already added in Phase 1/3 (MIT) — **reuse it, do not add `file_selector`** | MIT | open file / pick folder / "Save as…" (`saveFile`). Only if the discovery task shows that Phase 1 chose `file_selector` (BSD-3-Clause) instead, use that package's `getSaveLocation`/`openFile`/`getDirectoryPath` and record it; never have both. |

Fonts (assets, not Dart packages; licence **OFL-1.1**, acceptable for bundled fonts): Noto Sans (Regular, Bold, Italic, BoldItalic), Noto Sans Mono
(Regular, Bold), Noto Sans Bengali (Regular, Bold). Add OFL-1.1 to the licence tool **as an allowed asset licence only** (a separate `allowedAssetLicences`
list used for files under `app/assets/fonts/`), never to the Dart-package allowlist. See step 05.18.

Decisions taken here (do not revisit):
- **CSV parsing is our own** small RFC 4180 parser (no `csv` package): the format is tiny, and the `csv` package's API changed in v8.
- **Encrypted zip:** `archive`'s `ZipEncoder(password:)` does not document which cipher it writes (traditional ZipCrypto is weak). We therefore do **not**
  produce password-protected `.zip` files. "Encrypted export" produces our own container `.tephra-backup` (AES-256-GCM, Argon2id key), which only
  Tephra can open (restore importer in 05.16). Plain export produces a normal `.zip`.
- **Bear:** supported formats = (a) Bear's "Markdown" export (a folder or zip of `.md` files with an assets folder) and (b) **TextBundle**: `.textbundle` folders
  (`info.json` + `text.md` + `assets/`), `.textpack` files (a zip of one TextBundle) and `.bear2bk` backups, which are treated as a zip that contains many
  `*.textbundle/` folders (the layout is not officially documented; the importer finds bundles by their `info.json` + `text.*` files wherever they are
  in the archive, so it tolerates extra wrapper folders). Anything else inside a `.bear2bk` is skipped with a warning. See step 05.12.
- **Apple Notes:** supported format = folders of exported `.html` files (as produced by Apple Notes exporter tools). PDF exports are not imported.
- **OneNote:** supported format = `.html`/`.htm` files exported from OneNote (or converted from its "Web page" export). `.mht`, `.docx`, `.onepkg` are not imported → warning.
- **Imported links** are written as wikilinks with the full vault path and the original text as alias: `[[Imported/Notion 2026-10-11 0930/Projects/Roadmap|Roadmap]]`.
  Full paths make links unambiguous even when the vault already has notes with the same names.
- **Imported attachments** go to one folder per import: `<targetFolder>/Attachments/`, embedded with full vault paths `![[<targetFolder>/Attachments/image.png]]`.
- **PDF export** uses the `pdf` package rendering our AST (not screenshots). Known limitation: `pdf` does not do OpenType shaping for complex scripts, so
  Bengali conjuncts and vowel signs may render incorrectly; Bengali text must not crash and must stay present (tested), and the limitation is reported.

---

## Shared conventions for this phase

- Package-internal layout (`packages/tephra_io/lib/src/`):
  ```
  api/          import_source.dart  import_preview.dart  import_progress.dart  import_report.dart  importer.dart
                exporter.dart  export_request.dart  export_sink.dart  link_resolver.dart  registry.dart
  runtime/      import_runner.dart  export_runner.dart  import_context.dart  note_writer.dart  attachment_writer.dart
  util/         safe_names.dart  frontmatter_builder.dart  dates.dart  csv_parser.dart  link_rewriter.dart  simple_link_resolver.dart
                image_size.dart  markdown_escape.dart  text_detect.dart
  html/         html_to_markdown.dart  html_rules.dart  inline_style.dart
  importers/    obsidian_importer.dart  markdown_folder_importer.dart  html_importer.dart  notion_importer.dart  evernote_importer.dart
                keep_importer.dart  bear_importer.dart  roam_importer.dart  logseq_importer.dart  apple_notes_importer.dart
                onenote_importer.dart  csv_importer.dart  tephra_backup_importer.dart
  exporters/    zip_exporter.dart  backup_exporter.dart  backup_format.dart  markdown_exporter.dart  html_exporter.dart  html_template.dart
                pdf_exporter.dart  pdf_fonts.dart  docx_exporter.dart  docx_parts.dart
  ```
- `lib/tephra_io.dart` exports only the public API: everything in `api/`, `runtime/import_runner.dart`, `runtime/export_runner.dart`, the importer and
  exporter classes, `HtmlToMarkdown`, `SimpleLinkResolver`, `safeFileName`, `PdfFontSet`.
- Tests mirror `lib/src` under `test/`. Fixtures under `test/fixtures/<source>/input/` and expected output under `test/fixtures/<source>/expected/`.
- Every importer is deterministic given a `Clock` and the source; tests use `FixedClock(DateTime(2026, 10, 11, 9, 30))` and the default target folder
  `Imported/<Label> 2026-10-11 0930`, but most fixture tests pass an explicit target folder `Import` to keep snapshots short.
- Warnings are plain English strings `"<source path>: <message>"` (they are shown to the user verbatim in the report; the UI does not translate them —
  this is the one exception to l10n, because messages are generated inside the pure-Dart package; the report screen title and buttons are localised).
- Logging: `Logger('io.<area>')`, never log note content.

---

## Steps

Every step ends with the standard checks from `GEMINI.md` §3, a tick in `PROGRESS.md`, and a commit `phase 05.S: <summary>`.
"Verify" blocks list only step-specific commands. In `packages/tephra_io` run tests with `dart test` from that directory.

---

### 05.1 — tephra_io API types, sources and registry

**Purpose.** Fill in the §7.7 contract with concrete types every importer/exporter uses.

**Files.**
- `packages/tephra_io/pubspec.yaml`
- `packages/tephra_io/lib/tephra_io.dart`
- `packages/tephra_io/lib/src/api/*.dart` (all files listed under `api/` above)
- `packages/tephra_io/test/api/import_source_test.dart`
- `packages/tephra_io/test/api/registry_test.dart`
- `packages/tephra_io/test/support/fixture_bytes.dart`
- `packages/tephra_io/test/support/fixtures.dart`

**Implementation.**
1. Add dependencies: `dart pub add archive html xml pdf cryptography crypto path` in `packages/tephra_io`; `tephra_core`, `tephra_markdown`, `tephra_vault`
   as workspace path dependencies (they may already be listed). Dev: `test`.
2. `ImportSource` and specs (`api/import_source.dart`):
   ```dart
   /// A read-only tree of files to import from. Paths are relative, '/'-separated, never start with '/', never contain '..'.
   abstract interface class ImportSource {
     String get displayName;                  // e.g. 'Export-1234.zip'
     ImportSourceSpec get spec;               // sendable description (used to reopen the source in an isolate)
     Future<List<SourceEntry>> list();        // files only, sorted by path (ordinal), no directories
     Future<List<int>> read(String path);     // throws FileNotFoundException(VaultPath(path)) if missing
     Future<void> close();
   }
   final class SourceEntry {
     const SourceEntry({required this.path, required this.size, this.modified});
     final String path; final int size; final DateTime? modified;
     String get name;        // last segment
     String get stem;        // name without the last extension
     String get extension;   // lower-case, no dot, '' if none
     String get dir;         // '' for top level
   }
   sealed class ImportSourceSpec {
     const ImportSourceSpec();
     Map<String, Object?> toJson();
     static ImportSourceSpec fromJson(Map<String, Object?> json);
     Future<ImportSource> open();
   }
   final class DirectorySourceSpec extends ImportSourceSpec { const DirectorySourceSpec(this.directory); final String directory; ... }   // a real folder
   final class ZipSourceSpec extends ImportSourceSpec { const ZipSourceSpec(this.zipFile); final String zipFile; ... }                 // a .zip file
   final class FilesSourceSpec extends ImportSourceSpec { const FilesSourceSpec(this.files); final List<String> files; ... }           // one or more loose files; entries are their base names
   final class MemorySourceSpec extends ImportSourceSpec { const MemorySourceSpec(this.name, this.files); final String name; final Map<String, List<int>> files; ... }  // tests
   ```
   Rules:
   - `DirectoryImportSource`: lists recursively with `dart:io` (`Directory.list(recursive: true, followLinks: false)`), skips nothing (importers decide what to skip),
     converts separators to `/`.
   - `ZipImportSource`: opens with `ZipDecoder().decodeStream(InputFileStream(zipFile))` (check the archive 4 API), lists file entries (not directories);
     **zip-slip protection**: normalise each entry name (backslashes → `/`), drop entries that are absolute, contain `..` segments, or are empty → warning
     collected in `ZipImportSource.skippedEntries`; ignore `__MACOSX/` entries and `.DS_Store` files.
     **Nested zips:** if, after ignoring those, every remaining entry ends with `.zip`, open each inner zip from memory and expose their entries merged
     (prefix-free; on a duplicate path keep the first and record it in `skippedEntries`). Notion exports large workspaces this way.
   - `FilesImportSource`: entries are the base names; duplicate base names get ` (2)` before the extension.
   - `MemoryImportSource`: entries = map keys, sorted.
3. `ImportPreview` (`api/import_preview.dart`):
   ```dart
   final class ImportPreview {
     const ImportPreview({required this.notes, required this.attachments, this.skipped = 0, this.warnings = const [],
       this.sampleTitles = const [], this.columns = const []});
     final int notes; final int attachments; final int skipped;
     final List<String> warnings; final List<String> sampleTitles;   // first 10 note titles
     final List<String> columns;                                      // CSV importer only: header names
   }
   ```
4. `ImportProgress` (`api/import_progress.dart`):
   ```dart
   sealed class ImportProgress { const ImportProgress(); }
   final class ImportStarted extends ImportProgress { const ImportStarted(this.total); final int total; }          // planned items
   final class ImportItemDone extends ImportProgress { const ImportItemDone(this.done, this.total, this.item); final int done; final int total; final String item; }
   final class ImportWarning extends ImportProgress { const ImportWarning(this.message); final String message; }
   final class ImportFinished extends ImportProgress { const ImportFinished(this.report, this.created); final ImportReport report; final List<VaultPath> created; }
   ```
   Every `run` stream ends with exactly one `ImportFinished` unless cancelled or failed (a thrown `TephraException` ends the stream with an error).
5. `ImportReport` exactly per §7.7: `final class ImportReport { const ImportReport({required this.notes, required this.attachments, required this.warnings}); final int notes; final int attachments; final List<String> warnings; }`
   plus `toJson`/`fromJson` (needed to cross the isolate boundary).
6. `Importer` per §7.7: `String get id; String get label; Future<ImportPreview> preview(ImportSource src); Stream<ImportProgress> run(ImportSource src, VaultFileSystem target, VaultPath targetFolder);`
   Options are constructor parameters of each importer class (for example `ObsidianImporter({ConflictPolicy policy = ConflictPolicy.keepBoth})`), with
   `Map<String, Object?> get options` returning them as JSON so the runner can recreate the importer in an isolate.
   **Cancellation:** each `run` is an `async*` generator; when the listener cancels the subscription, the generator stops at its next `yield`. Importers
   `yield` after every note (an `ImportItemDone`), so cancellation takes effect within one note. Each note/attachment write is atomic, so no half-written files remain;
   files already written stay (the UI reports "Cancelled after N notes").
7. `Exporter` per §7.7: `String get id; String get label; String get fileExtension; Future<void> export(ExportRequest req, ExportSink sink);`
   ```dart
   final class ExportRequest {
     const ExportRequest({required this.fs, required this.paths, required this.resolver, this.onWarning, this.onProgress, this.clock = const SystemClock()});
     final VaultFileSystem fs;
     final List<VaultPath> paths;                 // notes and/or folders to export; VaultPath.root = whole vault
     final LinkResolver resolver;
     final void Function(String warning)? onWarning;
     final void Function(int done, int total)? onProgress;
     final Clock clock;
   }
   abstract interface class ExportSink {
     Future<void> writeFile(String relativePath, List<int> bytes);   // atomic; creates folders
     String? localPathFor(String relativePath);                      // real file path when the sink is a directory, else null
   }
   final class DirectoryExportSink implements ExportSink { DirectoryExportSink(this.directory); final String directory; ... }   // temp file + rename
   final class MemoryExportSink implements ExportSink { final Map<String, List<int>> files = {}; ... }
   ```
8. `LinkResolver` (`api/link_resolver.dart`):
   ```dart
   abstract interface class LinkResolver { Future<VaultPath?> resolve(String target, {required VaultPath from}); }
   ```
   `SimpleLinkResolver` (implemented in 05.3) is the pure implementation; the app may pass an adapter over `NoteIndex.resolveLink` when exporting on the UI side.
9. `registry.dart`:
   ```dart
   abstract final class IoRegistry {
     static const importerIds = ['obsidian','markdown','html','notion','evernote','keep','bear','roam','logseq','apple-notes','onenote','csv','tephra-backup'];
     static const exporterIds = ['zip','tephra-backup','pdf','html','docx','markdown'];
     static Importer createImporter(String id, Map<String, Object?> options);   // throws ArgumentError for unknown id
     static Exporter createExporter(String id, Map<String, Object?> options);
   }
   ```
   Until an importer/exporter exists, `create*` throws `UnimplementedError` for its id (each later step wires its class in).
10. Test support:
   - `test/support/fixture_bytes.dart` — two tiny PNG images as constants (use these exact bytes; their hashes are used in fixtures):
     ```dart
     /// 1×1 green PNG, 69 bytes. MD5 ee76702403cd15dbc71587365494cbe5.
     const tinyPngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
     /// 1×1 blue PNG, 69 bytes. MD5 6c0cf0948e03090bd23e53d44953fbfe.
     const tinyPng2Base64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC';
     List<int> get tinyPng => base64Decode(tinyPngBase64);
     List<int> get tinyPng2 => base64Decode(tinyPng2Base64);
     ```
     Add a test `fixture bytes have the documented md5` (uses `package:crypto`), so a typo is caught immediately.
   - `test/support/fixtures.dart`:
     ```dart
     /// Loads test/fixtures/<name>/input/ into a MemorySourceSpec. Text files are read as-is. A file named 'binaries.json' in the input
     /// folder maps relative paths to 'tinyPng' | 'tinyPng2'; those binary files are added and binaries.json itself is not part of the source.
     Future<MemorySourceSpec> loadFixtureSource(String name);
     /// Same, but returns the files packed into an in-memory zip (archive ZipEncoder), written to a temp file → ZipSourceSpec.
     Future<ZipSourceSpec> loadFixtureAsZip(String name, {String? wrapInZipNamed});   // wrapInZipNamed → zip inside a zip (Notion multi-part)
     /// Compares every file of [fs] under [folder] with test/fixtures/<name>/expected/ (byte-exact; expected text files use '\n').
     /// With environment TEPHRA_UPDATE_SNAPSHOTS=1 it rewrites expected/ instead and fails the test with "snapshots updated — review them".
     Future<void> expectMatchesSnapshot(MemoryVaultFileSystem fs, VaultPath folder, String name);
     ```
     Binary files in `expected/` are never committed: `expected/binaries.json` lists expected binary outputs as `{"Import/Attachments/image.png": "tinyPng"}` and the comparer checks them by content.
     **Snapshot discipline:** after generating snapshots, open every expected file and check it against the mapping rules of the step by reading it;
     only commit snapshots you have reviewed. Every importer test also has explicit `expect` assertions for its key rules (listed per step), so a wrong snapshot cannot hide a bug.

**Tests.**
- `import_source_test.dart`: `memory source lists sorted`, `directory source uses forward slashes` (temp dir with nested folders), `zip source lists files only`,
  `zip slip entries are skipped` (build a zip with entries `../evil.md`, `/abs.md`, `ok.md` → only `ok.md`, two skipped), `__MACOSX ignored`,
  `nested zips are expanded` (outer zip with `Part-1.zip` + `Part-2.zip`), `files source dedups base names`, `spec json round trip` (all four specs), `read missing throws FileNotFoundException`.
- `registry_test.dart`: `ids are unique`, `unknown id throws ArgumentError`.
- `fixture_bytes_test.dart`: md5 check above.

**Verify.**
```powershell
cd packages/tephra_io; dart test; cd ../..
dart run tool/check_licenses.dart
```

**Pitfalls.**
- `tephra_io` must not import `package:flutter`, `tephra_index` or `tephra_search` (conventions §3). `dart:io` is allowed.
- `archive` 4 changed many names from 3.x (for example `InputFileStream` lives in `package:archive/archive_io.dart`). Use the 4.x README.

---

### 05.2 — Helpers I: safe names, frontmatter builder, dates, CSV parser, Markdown escaping

**Purpose.** Small pure functions used by every importer.

**Files.**
- `packages/tephra_io/lib/src/util/safe_names.dart`
- `packages/tephra_io/lib/src/util/frontmatter_builder.dart`
- `packages/tephra_io/lib/src/util/dates.dart`
- `packages/tephra_io/lib/src/util/csv_parser.dart`
- `packages/tephra_io/lib/src/util/markdown_escape.dart`
- `packages/tephra_io/lib/src/util/text_detect.dart`
- matching tests under `packages/tephra_io/test/util/`

**Implementation.**
1. `safeFileName(String raw, {int maxLength = 200})` → a file **stem** (no extension) safe on Windows, Android and in Obsidian links. Apply in this order:
   1. Unicode NFC is not available in pure Dart without a package — skip normalisation; keep characters as given.
   2. Replace control characters U+0000–U+001F and U+007F with a space.
   3. Replace each of `\ / : * ? " < > |` with `-`.
   4. Obsidian link-breaking characters: `[` → `(`, `]` → `)`, `#` → removed, `^` → removed.
   5. Collapse runs of whitespace into one space; trim.
   6. Strip trailing dots and spaces repeatedly (Windows forbids them), and leading dots (would create hidden files).
   7. Windows reserved names: if the result (case-insensitive) equals `CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, or starts with one of them followed by `.`, append `_`.
   8. Empty → `Untitled`.
   9. Truncate to `maxLength` UTF-16 code units without splitting a surrogate pair (if the cut would land between a high and low surrogate, cut one earlier); then repeat step 6.
   The caller adds the extension; `NoteWriter` makes sure stem + `.` + extension ≤ 200 + extension length (stems are cut at 200 minus 1 minus the extension length when needed).
2. `uniqueName(String stem, String ext, bool Function(String nameLowerCase) taken)` → `"$stem.$ext"`, else `"$stem 1.$ext"`, `"$stem 2.$ext"`, … (case-insensitive check).
3. `FrontmatterBuilder` — builds a new frontmatter block (for new notes only; existing frontmatter is never rebuilt):
   ```dart
   final class FrontmatterBuilder {
     void set(String key, Object? value);   // String, num, bool, List<String>, LocalDateTimeValue, LocalDateValue; null → ignored
     bool get isEmpty;
     String build();                        // '---\n...---\n' or '' when empty
   }
   ```
   Key order = insertion order. Scalars: `bool` → `true`/`false`; `num` → `toString()`; dates → `2026-10-11` / `2026-10-11T09:30:00`;
   strings → plain if they match `^[A-Za-z0-9 _.,/()\-+]*[A-Za-z0-9_.)\-+]$` and are not one of `true false yes no null ~` (case-insensitive) and do not look like a number;
   otherwise double-quoted with `\` and `"` escaped and control chars as `\n`, `\t`, `\uXXXX`. Empty string → `""`.
   Lists → block style:
   ```yaml
   tags:
     - work
     - project/alpha
   ```
   Empty list → `key: []`. Keys that are not plain (`^[A-Za-z0-9_\-]+$`) are double-quoted.
   Tags: callers pass tags already cleaned by `cleanTag` (below).
4. `cleanTag(String raw)` → Obsidian tag text without `#`: trim, remove a leading `#`, replace whitespace runs with `-`, remove characters not allowed in
   Obsidian tags (allowed: letters, digits, `_`, `-`, `/`, and any non-ASCII letter), collapse `//`, trim `/` at ends; if the result is all digits, prefix `t`; empty → `null`.
5. `dates.dart`: `LocalDateTimeValue`/`LocalDateValue` (immutable wrappers with `format()`), `formatLocal(DateTime instant)` → `YYYY-MM-DDTHH:mm:ss` in the local time zone
   (`instant.toLocal()`), `parseEnexDate('20261011T093000Z')` → UTC `DateTime`, `fromMicros(int usec)` (Keep), `fromMillis(int ms)` (Roam).
   Frontmatter keys used by all importers for dates: `created` and `updated`, type datetime (written as `2026-10-11T09:30:00`, local time).
6. `csv_parser.dart` (RFC 4180 plus common variations):
   ```dart
   final class CsvTable { final List<String> header; final List<List<String>> rows; }
   CsvTable parseCsv(String text, {String? delimiter});   // delimiter auto-detected when null
   ```
   Rules: strip a leading UTF-8 BOM (U+FEFF); delimiter detection = among `,`, `;`, `\t`, the one occurring most often in the first line outside quotes (ties → `,`);
   fields may be quoted with `"`; inside quotes `""` is a literal quote and newlines (`\n`, `\r\n`, `\r`) are part of the field; outside quotes `\r\n`, `\n`, `\r` end a record;
   a trailing empty line is ignored; rows shorter than the header are padded with `''`, longer rows keep extra cells under generated headers `Column N`;
   duplicate header names get ` 2`, ` 3`; empty header names become `Column N`.
7. `markdown_escape.dart`: `escapeMarkdownText(String s, {bool atLineStart = false, bool inTable = false})` escapes `\`, `*`, `_`, `` ` ``, `[`, `]`, `<`, `>` (only `>` at line start),
   `#` at line start, `-`/`+` at line start followed by a space, `\d+[.)]` at line start (escape the `.`/`)`), `|` when `inTable`, `==` → `\=\=`, `%%` → `\%\%`, `$` → `\$`.
8. `text_detect.dart`: `bool looksLikeUtf8Text(List<int> bytes)` (no NUL bytes in the first 8 KB and decodes with `utf8.decode(allowMalformed: false)`), `String decodeText(List<int> bytes)`
   (UTF-8 with BOM stripped; if malformed → `latin1.decode` and the caller adds a warning "not UTF-8, decoded as Latin-1"), `String normaliseNewlines(String s)` (`\r\n`/`\r` → `\n`).

**Tests** (one file per helper):
- `safe_names_test.dart`: `invalid chars replaced` (`'a:b*c?'` → `'a-b-c-'`… then trailing `-` kept: expect `'a-b-c-'`), `brackets and hash` (`'Q1 [draft] #2'` → `'Q1 (draft) 2'`),
  `trailing dots and spaces` (`'Note. . '` → `'Note'`), `reserved names` (`'con'` → `'con_'`, `'LPT1.txt'` → `'LPT1.txt_'`), `empty` → `Untitled`, `long name cut at 200`,
  `surrogate pair not split` (199 `a` + `'😀'` → 199 `a`), `bangla kept` (`'কাজের তালিকা'` unchanged), `control chars`.
- `unique_name_test.dart`: `first free`, `suffix 1 and 2`, `case-insensitive`.
- `frontmatter_builder_test.dart`: exact expected strings for: plain string, string needing quotes (`'a: b'`, `'yes'`, `'123'`, `'#x'`), bool, number, list, empty list, dates, quoted key, `isEmpty` → `''`.
- `clean_tag_test.dart`: `'#My Tag'` → `'My-Tag'`, `'a//b/'` → `'a/b'`, `'2026'` → `'t2026'`, `'বাংলা'` kept, `'!!!'` → null.
- `dates_test.dart`: enex date parse; Keep micros; formatLocal with a fixed offset (run the assertion through `DateTime.utc(...).toLocal()` to stay zone-independent).
- `csv_parser_test.dart`: `simple`, `quoted comma`, `escaped quotes`, `multiline field`, `CRLF`, `semicolon detected`, `tab detected`, `BOM stripped`, `short and long rows`, `duplicate headers`, `trailing newline`.
- `markdown_escape_test.dart`: one case per rule.

**Verify.** `cd packages/tephra_io; dart test test/util; cd ../..`

**Pitfalls.** Do not use `intl` in `tephra_io` (not needed; keep the package light). Do not call `DateTime.now()`; use the injected `Clock`.

---

### 05.3 — Helpers II: import context, note writer, attachment writer (hash de-dup), link rewriting, simple link resolver

**Purpose.** The machinery that plans file names before writing (so links can be rewritten), de-duplicates attachments, and resolves links.

**Files.**
- `packages/tephra_io/lib/src/runtime/import_context.dart`
- `packages/tephra_io/lib/src/runtime/note_writer.dart`
- `packages/tephra_io/lib/src/runtime/attachment_writer.dart`
- `packages/tephra_io/lib/src/util/link_rewriter.dart`
- `packages/tephra_io/lib/src/util/simple_link_resolver.dart`
- `packages/tephra_io/lib/src/util/image_size.dart`
- tests: `test/runtime/note_writer_test.dart`, `test/runtime/attachment_writer_test.dart`, `test/util/link_rewriter_test.dart`, `test/util/simple_link_resolver_test.dart`, `test/util/image_size_test.dart`

**Implementation.**
1. `ImportContext` (one per run):
   ```dart
   final class ImportContext {
     ImportContext({required this.target, required this.targetFolder, required this.clock});
     final VaultFileSystem target; final VaultPath targetFolder; final Clock clock;
     late final NoteWriter notes = NoteWriter(this);
     late final AttachmentWriter attachments = AttachmentWriter(this);
     final List<String> warnings = [];
     final List<VaultPath> created = [];
     int noteCount = 0; int attachmentCount = 0;
     void warn(String sourcePath, String message);   // adds '$sourcePath: $message'
     ImportReport report();
   }
   ```
2. `NoteWriter` — two phases:
   ```dart
   final class NoteWriter {
     /// Reserves a unique vault path for a note. [folder] is relative to targetFolder ('' = targetFolder itself; '/'-separated, each segment
     /// passed through safeFileName). [title] → safeFileName(title) + '.md'. Collisions are checked against files already in the target vault
     /// (one fs.list(targetFolder) at the start, cached) AND paths reserved in this run, case-insensitively. Returns the reserved path.
     Future<VaultPath> reserve(String folder, String title, {String extension = 'md'});
     /// Writes the note text (frontmatter + body) at a reserved path. Ensures exactly one trailing '\n'. Counts the note, records it in created.
     Future<void> write(VaultPath path, String markdown, {FrontmatterBuilder? frontmatter});
   }
   ```
   Importers first `reserve` every note (pass 1), store `source id/path → VaultPath` in a `Map`, then convert and `write` (pass 2).
3. `AttachmentWriter`:
   ```dart
   final class AttachmentWriter {
     /// Saves [bytes] under '<targetFolder>/Attachments/<safe name>'. Same content (sha256 via contentHash) in this run → returns the path already written.
     /// If a file with the chosen name already exists in the vault with identical content → reuses it (no write). Otherwise picks a unique name.
     Future<VaultPath> save(List<int> bytes, String suggestedName, {String? mimeType});
     /// The embed text for a saved attachment: '![[<full vault path>]]'.
     String embed(VaultPath path, {int? width});   // width → '![[path|300]]'
   }
   ```
   `suggestedName` → stem via `safeFileName`, extension from the name; if none, from `mimeType` (`image/png` → `png`, `image/jpeg` → `jpg`, `image/gif` → `gif`,
   `image/webp` → `webp`, `image/svg+xml` → `svg`, `application/pdf` → `pdf`, `audio/mpeg` → `mp3`, `audio/mp4` → `m4a`, `video/mp4` → `mp4`, anything else → `bin`);
   empty stem → `attachment`.
4. `LinkRewriter` — rewrites link targets in Markdown text using parser offsets (never regex over the whole note):
   ```dart
   typedef LinkTargetMap = String? Function(String target);   // returns the new vault path WITHOUT '.md' for notes (with extension for files), or null = keep
   String rewriteLinks(String markdown, LinkTargetMap map, {bool convertMarkdownLinksToWikilinks = true});
   ```
   Algorithm: parse with `MarkdownParser.parse`; collect `MdWikiLink` and `MdLink` (non-image and image) nodes; for each, compute the target:
   wikilink → `target` field; Markdown link → `Uri.decodeFull(url)` when the URL has no scheme (`^[a-zA-Z][a-zA-Z0-9+.-]*:` means external → skip) and is not `#…`;
   strip a `#fragment` and keep it aside. Call `map(target)`; null → leave the node untouched. Otherwise produce:
   - wikilink: `[[<new>#<heading or ^block>|<alias>]]` keeping `embed` (`!`), heading/blockRef and alias from the original;
   - Markdown link (when `convertMarkdownLinksToWikilinks`): `[[<new>#<fragment as heading>|<link text>]]`; image link → `![[<new>]]`; if the link text equals the
     new path's last segment, the alias is still written (simpler, always correct).
   Replace node ranges from the end of the text to the start so earlier offsets stay valid. Text outside link nodes is copied unchanged.
5. `SimpleLinkResolver implements LinkResolver`:
   ```dart
   final class SimpleLinkResolver implements LinkResolver {
     SimpleLinkResolver(Iterable<VaultPath> files);
     static Future<SimpleLinkResolver> fromFileSystem(VaultFileSystem fs);
   }
   ```
   Resolution of `target` from note `from`: strip `#…` and `|…`; if the target has no extension, try it with `.md` first, then as-is.
   (1) exact vault path match (case-insensitive); (2) relative to `from`'s folder (for `./x`, `../x`, and Markdown-style relative links); (3) if the target contains `/`,
   files whose path ends with `/<target>` (case-insensitive); (4) files whose name equals the target's name (case-insensitive). Several candidates → prefer one in
   `from`'s folder, then the shortest path, then ordinal order. None → `null`. Aliases are not considered (documented limitation; exports run without the index).
6. `image_size.dart`: `ImageSize? readImageSize(List<int> bytes)` for PNG (IHDR width/height big-endian at bytes 16–23), JPEG (scan markers for SOF0–SOF3, SOF5–SOF7,
   SOF9–SOF11, SOF13–SOF15; height at +3, width at +5), GIF (little-endian at 6–9). Unknown → null.

**Tests.**
- `note_writer_test.dart`: `reserve avoids existing vault file`, `reserve avoids earlier reservation case-insensitively`, `folder segments sanitised` (`'a:b/c'` → `Import/a-b/c/…`),
  `write adds single trailing newline`, `frontmatter prepended`, `counts and created list`.
- `attachment_writer_test.dart`: `same bytes twice → one file`, `different bytes same name → name 1`, `existing identical file reused (no write)`,
  `extension from mime`, `embed format` (`![[Import/Attachments/image.png]]`, with width `|300`).
- `link_rewriter_test.dart`: `wikilink target replaced keeping alias and heading`, `embed keeps bang`, `markdown link to wikilink` (`[Roadmap](Roadmap%20abc.md)` → `[[Import/Roadmap|Roadmap]]`),
  `markdown image to embed`, `external links untouched`, `anchor-only link untouched`, `unknown target untouched`, `text outside links byte-identical`, `links inside code not touched`.
- `simple_link_resolver_test.dart`: exact path, relative `../`, name match, duplicate names prefer same folder then shortest, attachment with extension, missing → null.
- `image_size_test.dart`: tiny PNG → 1×1; a hand-built minimal JPEG header (bytes listed in the test) → width/height; GIF header; garbage → null.

**Verify.** `cd packages/tephra_io; dart test test/runtime test/util; cd ../..`

**Pitfalls.** `reserve` must be called for all notes before any `write` that rewrites links; otherwise links point to names that may later change.

---

### 05.4 — HTML → Markdown converter

**Purpose.** One converter used by the HTML, Evernote, Apple Notes, OneNote and Keep importers (and nothing else should parse HTML).

**Files.**
- `packages/tephra_io/lib/src/html/html_to_markdown.dart`
- `packages/tephra_io/lib/src/html/html_rules.dart`
- `packages/tephra_io/lib/src/html/inline_style.dart`
- `packages/tephra_io/test/html/html_to_markdown_test.dart`
- `packages/tephra_io/test/html/cases/` (pairs `<name>.html` + `<name>.md`)

**Implementation.**
1. API:
   ```dart
   final class HtmlConvertOptions {
     const HtmlConvertOptions({this.rewriteImage, this.rewriteLink, this.baseIndent = '\t'});
     /// Returns the Markdown for an <img>; null → default '![alt](src)'.
     final Future<String?> Function(String src, String alt)? rewriteImage;
     /// Returns a replacement for a link: a full Markdown/wikilink string, or null → default '[text](href)'.
     final Future<String?> Function(String href, String text)? rewriteLink;
     final String baseIndent;   // indentation unit for nested lists (Obsidian default: tab)
   }
   final class HtmlConvertResult { final String markdown; final String? title /* <title> text */; final List<String> warnings; }
   abstract final class HtmlToMarkdown { static Future<HtmlConvertResult> convert(String html, {HtmlConvertOptions options = const HtmlConvertOptions()}); }
   ```
   Parse with `package:html` (`parse(html)` for documents, `parseFragment` when there is no `<html>`/`<body>`); walk `document.body` recursively.
2. Block model: the walker produces a list of blocks; each block is rendered then joined with exactly one blank line (`\n\n`) between blocks; output ends with a single `\n`;
   runs of 3+ newlines are reduced to 2; trailing spaces on lines are removed (except inside code blocks).
3. Element → Markdown mapping (implement every row; elements not listed are "transparent": their children are converted in place):
   | HTML | Markdown |
   |---|---|
   | `h1`…`h6` | `#`…`######` + space + inline content (one line; inner `<br>` → space) |
   | `p` | paragraph of inline content |
   | `div`, `section`, `article`, `main`, `header`, `footer`, `aside`, `nav`, `body`, `center` | block container: if it contains only inline content → paragraph; if it contains blocks → its children are blocks (no extra wrapper) |
   | `br` | in paragraphs: `\n` (Obsidian shows a line break); in table cells and headings: `<br>` / space |
   | `strong`, `b` | `**x**` (skip if content is only whitespace) |
   | `em`, `i`, `cite`, `dfn` | `*x*` |
   | `del`, `s`, `strike` | `~~x~~` |
   | `mark` | `==x==` |
   | `u`, `ins` | `<u>x</u>` (kept as inline HTML; Obsidian renders it) |
   | `sup`, `sub` | `<sup>x</sup>`, `<sub>x</sub>` |
   | `code` (inline, not inside `pre`) | backtick span; use N+1 backticks where N is the longest backtick run inside; pad with a space if content starts/ends with a backtick |
   | `pre` (optionally containing `code class="language-x"` or `lang-x`) | fenced block with the language; fence = max(3, longest backtick run + 1) backticks; content = text with whitespace preserved; trailing newline trimmed |
   | `a href` | `[text](href)`; href with spaces/parentheses → `<href>` form inside the parentheses; `text` empty → use href; text == href → `<href>` autolink; `href` starting `#` → plain text; `javascript:` → plain text + warning; `rewriteLink` is consulted first |
   | `img` | `rewriteImage(src, alt)` or `![alt](src)`; missing `src` → skipped + warning; `data:` URIs: passed to `rewriteImage` (importers save them as attachments) |
   | `ul`, `ol` | list; `ol start="n"` → numbering from n; items `- ` / `n. `; nesting adds one `baseIndent` per level; tight list unless an item contains more than one block (then loose: blank line between items) |
   | `li` | list item; continuation lines indented to the item content; nested lists inside `li` become nested lists |
   | `li` whose first non-whitespace child is `input[type=checkbox]` | task item `- [ ] ` / `- [x] ` (`checked` attribute present → `x`) |
   | `input[type=checkbox]` as the first child of a `p`/`div` block (not in a list) | the block becomes a task item `- [ ] text` / `- [x] text` (consecutive such blocks form one list) |
   | `blockquote` | each line prefixed `> `; nested blockquotes `> > `; blank lines inside → `>` |
   | `hr` | `---` |
   | `table` | GFM table (rules below) |
   | `figure` + `figcaption` | the image, then the caption as an italic paragraph |
   | `details` + `summary` | callout `> [!note]- <summary text>` with the remaining content prefixed `> ` |
   | `dl` / `dt` / `dd` | `dt` → bold paragraph; `dd` → paragraph |
   | `iframe src` | `[<src host> embed](src)` link + warning "iframe converted to link" |
   | `video src`, `audio src` | link `[video](src)` / `[audio](src)` (importers may rewrite to embeds) |
   | `script`, `style`, `head`, `title`, `meta`, `link`, `noscript`, `template`, `object`, `embed`, `svg`, `canvas`, `form`, `button`, `select`, `textarea` | dropped (`title` text is returned in `HtmlConvertResult.title`); `object`/`embed`/`svg`/`canvas` add a warning |
   | `span` and any element with a `style` attribute | inline style rules below, then its children |
   | `font` | transparent |
4. Inline styles (`inline_style.dart`): parse `style` into declarations (`;`-separated `prop: value`, case-insensitive). `font-weight: bold|bolder|600|700|800|900` → strong;
   `font-style: italic` → emphasis; `text-decoration` containing `line-through` → strike; `text-decoration` containing `underline` → `<u>`;
   `background-color` that is not white/transparent/`inherit` (`#fff`, `#ffffff`, `white`, `rgb(255, 255, 255)`, `transparent`) → highlight `==x==`;
   Evernote's `--en-highlight` custom property → highlight. Several apply → nest in the order strong(em(del(mark(text)))).
5. Tables: header = the first row inside `thead`, else the first `tr`; column count = max cells in any row (respecting `colspan`: a cell with `colspan=n` fills n columns,
   the extra ones empty); cells are rendered as inline content on one line: block children joined with `<br>`, lists flattened to `• item<br>`, `|` escaped as `\|`;
   nested tables → their text joined with spaces + warning "nested table flattened"; separator row `| --- |` with alignment from `align`/`style="text-align:…"` of header cells
   (`:---`, `:---:`, `---:`); a table with zero rows is dropped.
6. Text nodes: decode entities (the parser does it), collapse whitespace runs to one space outside `pre`, escape with `escapeMarkdownText` (respect `atLineStart` and `inTable`),
   non-breaking spaces (U+00A0) → normal spaces (Apple Notes and Evernote use them heavily).
7. Async: `rewriteImage`/`rewriteLink` are async (they write attachments); the walker is an `async` recursive function. Keep it simple: await each call in document order.

**Tests.**
- `html_to_markdown_test.dart` loads every pair from `test/html/cases/` and compares output byte-exact. Create these case pairs by hand (HTML input and the expected Markdown you derive from the table):
  `headings`, `paragraphs_br`, `inline_formatting` (strong/em/del/mark/u/sup/sub), `inline_code_backticks` (content containing a backtick), `pre_with_language`,
  `links` (normal, autolink, anchor, javascript, spaces in href), `images` (alt, missing src), `nested_lists` (3 levels, ordered start=3), `loose_list`,
  `task_list_li` (checked/unchecked), `task_divs` (Evernote-style divs with checkbox), `blockquote_nested`, `hr`, `table_basic` (thead, alignment),
  `table_colspan`, `table_pipes_and_br`, `table_nested_flattened` (and its warning), `figure`, `details_callout`, `dl`, `styles_span` (bold/italic/strike/highlight via style),
  `nbsp_and_entities`, `script_style_dropped`, `escape_specials` (text `*not bold* [x] # hash 1. one`), `bangla_text`.
- Extra direct tests: `rewriteImage is called with data uri`, `title returned`, `output ends with one newline`.

**Verify.** `cd packages/tephra_io; dart test test/html; cd ../..`

**Pitfalls.** Do not convert HTML with regular expressions. Do not let empty inline wrappers produce `****` or `**` with no content.

---

### 05.5 — Import runner (isolate, progress, cancellation) and the snapshot harness

**Purpose.** Run any importer off the UI isolate with a progress stream and cancellation; finish the test harness.

**Files.**
- `packages/tephra_io/lib/src/runtime/import_runner.dart`
- `packages/tephra_io/lib/src/runtime/export_runner.dart`
- `packages/tephra_io/test/runtime/import_runner_test.dart`
- `packages/tephra_io/test/support/fixtures.dart` (complete it)
- `packages/tephra_io/test/support/fake_importer.dart`

**Implementation.**
1. `ImportJob` (sendable): `{importerId, options (JSON map), source (ImportSourceSpec JSON), vaultRoot (String), targetFolder (String)}`.
2. `ImportRunner`:
   ```dart
   final class ImportRunner {
     /// Spawns an isolate that opens IoVaultFileSystem(vaultRoot), recreates the importer via IoRegistry, opens the source from its spec,
     /// and forwards every ImportProgress to the returned stream. Cancelling the subscription sends 'cancel' to the isolate, which cancels its
     /// subscription to importer.run(...) (stopping at the next yield), closes the source and the fs, and exits.
     static Stream<ImportProgress> runInIsolate(ImportJob job);
     /// Same contract without an isolate (tests, small imports, and MemoryVaultFileSystem targets).
     static Stream<ImportProgress> runInline(Importer importer, ImportSource src, VaultFileSystem target, VaultPath targetFolder);
     /// Preview in an isolate (previews of big zips also take time).
     static Future<ImportPreview> previewInIsolate(String importerId, Map<String, Object?> options, ImportSourceSpec source);
   }
   ```
   Messages across the isolate boundary are JSON maps (`{"type":"started","total":n}`, `{"type":"item","done":…}`, `{"type":"warning",…}`, `{"type":"finished","report":{…},"created":[…]}`,
   `{"type":"error","kind":"<exception class>","message":"…"}`). Errors are rethrown on the main side as the matching `TephraException` subclass when known, else `ImportFailedException`
   (define `final class ImportFailedException extends TephraException` in `api/importer.dart`).
   Progress events are throttled to at most one `ImportItemDone` per 50 ms (always forward the last one and every warning).
3. `ExportJob`/`ExportRunner.runInIsolate(job)` with the same pattern: `{exporterId, options, vaultRoot, paths, outDirectory}`; inside the isolate the resolver is
   `SimpleLinkResolver.fromFileSystem(fs)` and the sink is `DirectoryExportSink(outDirectory)`. Returns `Stream<ExportEvent>` (`ExportProgress(done,total)`,
   `ExportWarning(message)`, `ExportFinished(files: List<String> relative output paths, warnings)`).
4. `FakeImporter` for tests: writes N notes `Note i.md` yielding after each, optional failure at item k.
5. Complete `fixtures.dart` (05.1 signatures) including the `TEPHRA_UPDATE_SNAPSHOTS` behaviour.

**Tests.** `import_runner_test.dart`:
- `inline run reports progress and finishes` (FakeImporter 5 notes → events Started(5), 5 × ItemDone, Finished with notes 5).
- `isolate run writes to a real temp vault` (temp dir, FakeImporter 3 notes, then read files with `dart:io`).
- `cancel stops early` (FakeImporter 1000 notes with a 1 ms delay per note; cancel after the 10th event; wait 200 ms; fewer than 1000 files exist; no `.tmp` files left).
- `error is rethrown as ImportFailedException` (failure at item 2).
- `progress is throttled` (1000 fast notes → fewer than 1000 ItemDone events, last one has done == 1000).
- `export runner writes into directory`.

**Verify.** `cd packages/tephra_io; dart test test/runtime; cd ../..`

**Pitfalls.** Isolates cannot send closures or open file handles — only the JSON job. `MemoryVaultFileSystem` cannot be used with `runInIsolate`; tests for isolates use temp directories.

---

### 05.6 — Importer 1: Obsidian vault (merge into the current vault)

**Purpose.** Bring another Obsidian vault (folder or zip) into the open vault, never overwriting silently.

**Files.**
- `packages/tephra_io/lib/src/importers/obsidian_importer.dart`
- `packages/tephra_io/test/importers/obsidian_importer_test.dart`
- `packages/tephra_io/test/fixtures/obsidian/input/…`, `…/expected/…`

**Implementation.**
1. `ObsidianImporter({ConflictPolicy policy = ConflictPolicy.keepBoth})`, id `obsidian`, label "Obsidian vault".
   `enum ConflictPolicy { keepBoth, skip, overwrite }`.
2. Source detection for preview: warning "No .obsidian folder found — importing as a folder of notes" when there is no `.obsidian/` (still allowed).
3. Copied: every file except paths with a segment starting with `.` (this skips `.obsidian/`, `.trash/`, `.git/`, `.tephra/`) and `node_modules/`.
   Notes = `.md`; everything else (including `.canvas`, `.base`, images, PDFs) = attachments, but **kept at their relative paths** (not moved to `Attachments/`) — an Obsidian vault is already in the right shape.
   The default target folder for this importer is the vault root (`VaultPath.root`); the user may choose a subfolder.
4. Per file, destination = `targetFolder/<relative path>`:
   - not existing → write bytes unchanged (byte-for-byte copy; do not decode/re-encode notes).
   - existing with identical bytes (`contentHash`) → skip silently (counted in preview `skipped`).
   - existing and different:
     - `keepBoth` → reserve `<name> 1.<ext>` (via `uniqueName`) and record `oldPath → newPath` in a rename map;
     - `skip` → skip + warning "exists, skipped";
     - `overwrite` → `target.delete(path, mode: TrashMode.vaultTrash)` first (so the old version is recoverable), then write + warning "replaced (old version in .trash)".
5. Links after `keepBoth` renames: for every imported `.md` note whose text contains a link to a renamed file, run `rewriteLinks` with a map that only answers for renamed
   targets (resolve each link target with a `SimpleLinkResolver` built over the **source** file list relative to the note; if it resolves to a renamed source file, return the
   new vault path). Notes without affected links are copied byte-for-byte (do not run them through the rewriter).
   Also rewrite `.canvas` files' `"file"` fields that point to renamed files (parse JSON, change only those strings, re-encode with the same indentation the file used: detect `\t` vs 2 spaces).
6. When `targetFolder` is not the root, links between imported notes that used vault-absolute paths (`[[Folder/Note]]`) would break: rewrite targets containing `/` that resolve
   in the source to the new prefixed path. Shortest-name links (`[[Note]]`) are left alone; add one summary warning listing up to 20 note names that also exist elsewhere in the
   destination vault ("may now resolve to a different note").
7. Obsidian settings are not imported (Tephra never writes `.obsidian/` and the current vault keeps its own settings); add an info warning "Settings in .obsidian/ were not imported".

**Fixture** `test/fixtures/obsidian/input/`:
- `.obsidian/app.json` (`{"attachmentFolderPath":"assets"}`), `.trash/old.md` (must not be imported)
- `Welcome.md` — text with `[[Projects/Alpha]]`, `[[Ideas]]`, `![[assets/image.png]]`, a callout and a task
- `Ideas.md` — **conflicts** with the destination (different content)
- `Same.md` — identical to a destination file (skipped)
- `Projects/Alpha.md` — frontmatter with `tags: [p]`, links `[[Ideas|my ideas]]`
- `Board.canvas` — one file node `"file":"Ideas.md"`, one text node
- `assets/image.png` (binaries.json → tinyPng)
Destination prepared in the test: `Ideas.md` (different text) and `Same.md` (same text).
Expected (policy keepBoth, target root): `Ideas 1.md` created; `Welcome.md` link `[[Ideas]]` → `[[Ideas 1|Ideas]]`; `Projects/Alpha.md` link → `[[Ideas 1|my ideas]]`;
`Board.canvas` file node → `Ideas 1.md`; `Same.md` untouched; `.trash/old.md` absent.

**Tests.** `obsidian_importer_test.dart`: `snapshot keepBoth`, `skip policy keeps destination and warns`, `overwrite moves old to .trash`, `unaffected notes are byte-identical copies`
(compare bytes with the source), `dot folders skipped`, `into subfolder rewrites path links`, `preview counts notes attachments skipped`.

**Verify.** `cd packages/tephra_io; dart test test/importers/obsidian_importer_test.dart; cd ../..`

**Pitfalls.** Never decode and re-encode a note that does not need link changes — CRLF/BOM must survive exactly.

---

### 05.7 — Importer 2: plain Markdown and text folders

**Purpose.** Import a folder (or zip) of `.md`, `.markdown`, `.txt` files, keeping the folder structure.

**Files.**
- `packages/tephra_io/lib/src/importers/markdown_folder_importer.dart`
- `packages/tephra_io/test/importers/markdown_folder_importer_test.dart`
- `packages/tephra_io/test/fixtures/markdown/input/…`, `expected/…`

**Implementation.**
1. `MarkdownFolderImporter()`, id `markdown`, label "Markdown or text files".
2. Notes: extensions `md`, `markdown`, `mdown`, `mkd` → `.md` (same stem); `txt` → `.md` (content unchanged except: decode with `decodeText`, normalise newlines to `\n`; no Markdown escaping —
   plain text is valid Markdown, and escaping would change how users' text looks in Obsidian's source mode).
3. Attachments: images (`png jpg jpeg gif webp svg bmp`), `pdf`, audio (`mp3 m4a wav ogg flac`), video (`mp4 webm mov`) → copied keeping their relative paths under the target folder
   (Markdown folders reference images relatively, so they must stay where the notes expect them). Other files → skipped + warning "unsupported file type".
4. Folder structure kept; each segment sanitised with `safeFileName`; names that changed are recorded in a rename map and relative Markdown links (`[x](sub/a%20b.md)`, `![](img/a.png)`)
   in notes are rewritten with `rewriteLinks` (resolving relative to the note in the source, mapping to the new vault path). Links that did not change are left alone.
5. Hidden files/folders (segment starting with `.`) skipped.
6. Dates: none added (file times are not reliable after copying).

**Fixture** `markdown/input/`: `Readme.md` (links `[Guide](docs/User%20Guide.md)`, `![logo](img/logo.png)`), `docs/User Guide.md`, `docs/notes.txt` (plain text with `*stars*` and a CRLF line ending),
`docs/Bad:Name?.md` (→ `Bad-Name-.md`; `Readme.md` also links to it as `[bad](docs/Bad:Name%3F.md)` → rewritten), `img/logo.png` (tinyPng), `.hidden/x.md` (skipped), `data.bin` (skipped + warning).

**Tests.** `snapshot`, `txt becomes md with LF`, `invalid names sanitised and links follow`, `unchanged links untouched`, `hidden skipped`, `unsupported warned`.

**Verify.** `cd packages/tephra_io; dart test test/importers/markdown_folder_importer_test.dart; cd ../..`

---

### 05.8 — Importers 3, 10, 11: HTML files, Apple Notes (HTML), OneNote (HTML)

**Purpose.** Convert HTML documents to notes; Apple Notes and OneNote are HTML variants with small differences. (They are implemented together here because
they share one class; the wizard still lists them in the conventional order.)

**Files.**
- `packages/tephra_io/lib/src/importers/html_importer.dart`
- `packages/tephra_io/lib/src/importers/apple_notes_importer.dart`
- `packages/tephra_io/lib/src/importers/onenote_importer.dart`
- tests + fixtures for `html`, `apple-notes`, `onenote`

**Implementation.**
1. `HtmlImporter({HtmlFlavor flavor = HtmlFlavor.generic})`, id `html`, label "HTML files". `enum HtmlFlavor { generic, appleNotes, oneNote }`.
   `AppleNotesImporter` (id `apple-notes`, label "Apple Notes (HTML export)") and `OneNoteImporter` (id `onenote`, label "OneNote (HTML export)") are thin classes delegating to `HtmlImporter` with their flavor.
2. Notes = `.html`/`.htm` files. Folder structure kept (sanitised). Other files are attachments **only if referenced** by an imported HTML file (copied via `AttachmentWriter`); unreferenced files are skipped silently.
   OneNote flavor: `.mht`, `.mhtml`, `.docx`, `.one`, `.onepkg` files → warning "OneNote format not supported; export pages as HTML".
3. Title: generic → `<title>` text, else the first `h1`, else the file stem. Apple Notes → the first non-empty line of the body (Apple Notes has no title element; the first line is the title)
   and that first line is removed from the body if it is a heading or a single-line block. OneNote → `<title>`, else stem.
4. Conversion: `HtmlToMarkdown.convert` with
   - `rewriteImage(src, alt)`: `data:` URI → decode base64 → `AttachmentWriter.save(bytes, 'image.<ext from mime>')` → embed; relative `src` (decode `%xx`, resolve against the HTML file's folder in the source) → if the file exists in the source → save → embed; else warning "missing image" and keep `![alt](src)`; `http(s)` → keep `![alt](src)`.
   - `rewriteLink(href, text)`: relative link to another imported `.html` → wikilink to its reserved note path `[[<path>|text]]`; relative link to another existing file → save as attachment → `[[<path>|text]]`; else null.
5. Apple Notes flavor specifics: `<div><br></div>` → blank line (handled by normal rules); attachments folders named `<note> Attachments/` are common — handled by relative resolution.
   OneNote flavor specifics: OneNote exports position content with absolutely positioned `div`s; ignore `style` positioning (only inline-style rules from 05.4 apply) and output the blocks in document order.
6. Dates: none.

**Fixtures.**
- `html/input/`: `page.html` (title, h1, nested list, table, inline styles, `<img src="images/pic.png">`, `<img src="data:image/png;base64,<tinyPng2Base64>">`, link to `other.html`),
  `other.html` (simple), `images/pic.png` (tinyPng), `unused.png` (tinyPng2). Expected: `unused.png` is not copied as a file of its own (unreferenced);
  the data-URI image (same bytes as `unused.png`) is saved once as `Import/Attachments/image.png`; `images/pic.png` is saved as `Import/Attachments/pic.png`.
- `apple-notes/input/`: `Notes/Shopping.html` (first div line "Shopping", checklist rendered as `<ul><li><input type="checkbox" checked>Milk</li>…`), `Notes/Work/Meeting.html` with nbsp-heavy text and an image in `Meeting Attachments/photo.png`.
- `onenote/input/`: `Notebook/Section/Page 1.html` (absolutely positioned divs with a table and a list), `Notebook/Section/Page 2.mht` (→ warning).

**Tests.** `html snapshot`, `data uri saved as attachment`, `link between pages becomes wikilink`, `missing image warned`, `apple title from first line and removed from body`,
`apple checklist becomes tasks`, `onenote mht warned`, `onenote positioned divs in order`.

**Verify.** `cd packages/tephra_io; dart test test/importers; cd ../..`

---

### 05.9 — Importer 4: Notion export (Markdown & CSV zip)

**Purpose.** Import a Notion "Export → Markdown & CSV" zip: strip the 32-hex ids from names, keep nested pages as folders, fix relative links and
percent-encoding, turn each database (CSV) into one note per row with properties and a minimal `.base` table view.

**Files.**
- `packages/tephra_io/lib/src/importers/notion_importer.dart`
- `packages/tephra_io/lib/src/util/property_inference.dart` (new; also used by the CSV importer in 05.15)
- `packages/tephra_io/lib/src/util/base_file_builder.dart` (new; also used by the CSV importer)
- `packages/tephra_io/lib/src/util/link_rewriter.dart` (extend: optional external-link map, see item 8)
- `packages/tephra_io/lib/src/util/dates.dart` (extend: `utcOffset`, see item 9)
- `packages/tephra_io/lib/src/importers/notion_markdown_fixes.dart` (new; callouts and toggles)
- `tool/gen_notion_export.dart` (new; benchmark generator, item 12)
- tests: `test/importers/notion_importer_test.dart`, `test/importers/notion_markdown_fixes_test.dart`, `test/util/property_inference_test.dart`,
  `test/util/base_file_builder_test.dart`, `test/bench/notion_bench_test.dart`; fixture `test/fixtures/notion/`

**Implementation.**
1. Class `NotionImporter({Clock clock = const SystemClock(), Duration? utcOffset})`, id `notion`, label "Notion (Markdown & CSV export)".
   `options` → `{"utcOffsetMinutes": int?}`. Wire it into `IoRegistry.createImporter`.
2. **Id stripping** (`String stripNotionId(String nameWithoutExtension)`): if the name matches `^(.*?)[ _-]*([0-9a-f]{32})(_all)?$` (case-insensitive hex),
   return group 1 trimmed; otherwise return the name unchanged. Examples: `Roadmap 1123456789abcdef0123456789abcdef` → `Roadmap`;
   `Tasks 3123456789abcdef0123456789abcdef_all` → `Tasks`; `Plain name` → `Plain name`. The id itself is returned by `String? notionIdOf(String name)`.
   Apply to **every** path segment (folders and file stems). Keep the extension separately.
3. **Classify source entries** (pass 1, one `src.list()`):
   - `.md` → page. `.csv` → database table. Any other extension → attachment. Entries named `index.html` or `*.html` while there is no `.md`/`.csv` at all →
     stop with `ImportFailedException('This looks like a Notion HTML export. Export again as "Markdown & CSV".')`.
   - For two CSVs of one database, `X <id>_all.csv` and `X <id>.csv`: use the `_all.csv` (it has every column, including hidden ones) and ignore the other
     (one info warning "<path>: using the _all.csv version").
   - Keep a map `idToSource: Map<String id, String sourcePath>` for pages and databases, used for `notion.so` links (item 8).
4. **Page titles and paths.** For each page read the text (`decodeText`, `normaliseNewlines`). Title = the text of the first line if it starts with `# ` (the page title,
   which Notion always writes), else `stripNotionId(stem)`. Destination folder = the source directory with every segment passed through `stripNotionId` then
   `safeFileName` (nested pages therefore become folders named after their parent page; the parent page note itself stays **next to** its folder:
   `Home.md` + `Home/Roadmap.md`). `NoteWriter.reserve(folder, title)` for all pages and database rows before converting anything (pass 1), storing
   `sourcePath → VaultPath` in `pageMap`.
5. **Databases.** For each CSV `D` (parsed with `parseCsv`, header = first row; the **first column is the title column**, Notion always puts "Name" first):
   - `dbFolder` = the CSV's directory + `stripNotionId(csvStem)` (each segment sanitised as above). The row pages Notion exported live in a **source folder** with the
     same stripped name in the same source directory (match by id when both names carry the same 32-hex id, else by stripped name, case-insensitive).
   - For each row: the row page = the `.md` file in that source folder whose title (item 4) equals the row's title cell (exact, then case-insensitive). Mark such pages
     as "database rows" so they are not imported twice. Rows without a page (empty rows) get a note with no body. Pages in the source folder that match no row are
     imported as normal pages into `dbFolder` (properties parsed from their header, item 6).
   - Row notes are reserved in `dbFolder`; title cell empty → `Untitled`.
   - Column types: compute `PropertyColumn` per column with `inferColumn` (item 7) over **all** rows of that CSV.
   - Frontmatter per row from the CSV cells (empty cells are skipped), in header order, excluding the title column. Key = header text, except a header equal to `Tags`/`tags`
     (case-insensitive) → key `tags` with `cleanTag` applied to each item. Values converted by the column kind (item 7).
   - Body = the row page's body after item 6 (the property header lines removed); with no page, empty.
   - A `.base` file next to the folder: `<parent>/<dbName>.base` (reserved with `NoteWriter.reserve(folder, dbName, extension: 'base')`), content from
     `buildBaseFile(folderPath: dbFolderVaultPath, columns: [...])` (item 10). A link in a page to the CSV (`…/Tasks%203123….csv`) resolves to this `.base` path.
6. **Page body fixes** (`notion_markdown_fixes.dart`, pure functions over `String`, all line-based and aware of fenced code blocks: lines between ``` fences are never touched):
   1. Remove the first line when it is `# <title>` and the next line is empty (the title becomes the file name). If the page is a database row, then also remove
      the **property header**: the lines immediately after that blank line while each matches `^[^:\n]{1,80}: ?.*$` (a Notion property line), up to and including the blank line that ends them.
      When no CSV row matched, the header lines become the frontmatter (all values strings; `Tags` → `tags` list split on `, `).
   2. `<aside>` … `</aside>` (Notion callout) → a callout: first non-empty inner line starts with an emoji → the emoji decides the type and is removed:
      `💡`→`tip`, `⚠️`/`⚠`→`warning`, `❗`/`❌`→`danger`, `❓`→`question`, `✅`→`success`, `📌`/`ℹ️`→`info`, any other or none → `note`.
      Output `> [!type]` then every inner line prefixed `> ` (the first inner line is the callout body, not a title; empty inner lines → `>`).
   3. `<details>` / `<summary>text</summary>` … `</details>` (toggle) → `> [!note]- text`, inner lines prefixed `> `. Nested toggles: keep a depth stack; depth n lines get n times `> `.
      Notion writes the inner content as Markdown, so it is kept as is.
   4. A line that is only `<br>` or `<br/>` → empty line. Other HTML is left unchanged.
   5. Notion writes table cells and lists as standard Markdown; no change.
7. **Property inference** (`property_inference.dart`, shared):
   ```dart
   enum PropertyKind { text, number, checkbox, date, datetime, list, relation }
   final class PropertyColumn { final String header; final PropertyKind kind; }
   PropertyColumn inferColumn(String header, List<String> values, {bool notionDates = true});   // values = all cells of the column
   Object? convertCell(PropertyColumn c, String cell, {required String? Function(String sourceUrl) resolveRelation, Duration? utcOffset});
   ```
   Decision on the **non-empty** values (empty cells never decide; if there are no non-empty values → `text`). First matching rule wins:
   1. every value is `Yes` or `No` (also `true`/`false`, case-insensitive) → `checkbox` (bool);
   2. every value matches `^-?\d+(\.\d+)?$` → `number` (int when no `.`, else double);
   3. every value is a Notion date `^(January|…|December) \d{1,2}, \d{4}$` (full month names) → `date` → `YYYY-MM-DD`; every value also has ` h:mm AM|PM` → `datetime`
      (`YYYY-MM-DDTHH:mm:00`, 12-hour → 24-hour; the time is already local, `utcOffset` is **not** applied); a column mixing both, or containing a range (`→`) → `text`;
      with `notionDates: false` (CSV importer) the accepted patterns are ISO `YYYY-MM-DD` (date) and `YYYY-MM-DD[T ]HH:mm(:ss)?` (datetime) instead;
   4. every non-empty value matches `^.+? \(.+?\.md\)(, .+? \(.+?\.md\))*$` (Notion relation: `Title (url.md)`) → `relation`; each item is converted to the link text
      `"[[<mapped vault path without .md>|<Title>]]"` using `resolveRelation(Uri.decodeFull(url))`; an unresolved item stays as its plain Title; result = `List<String>`;
   5. the header lower-cased is `tags`, `tag`, `labels`, `categories` or `category`, **or** (at least 2 non-empty values contain `, ` and every item after splitting on `, ` is
      ≤ 30 chars and the number of distinct items ≤ 20) → `list` (items trimmed; empty items dropped);
   6. otherwise `text` (string, the cell unchanged).
8. **Links in page bodies.** After the fixes, build per-page `LinkTargetMap`: take the decoded target, if it contains `://` or starts with `#` → not handled here;
   else resolve it relative to the page's **source** directory (`p.posix.normalize(p.posix.join(dir, target))`), look it up in `pageMap` (exact, then case-insensitive),
   in `attachmentMap` (item 11), or in `dbBaseMap` (CSV source path → `.base` path); return the vault path without `.md` for notes, with extension for files. Then call `rewriteLinks`.
   Extend `rewriteLinks` (05.3) with an optional named parameter `LinkTargetMap? mapExternal`: for links whose URL has a scheme, the raw URL is passed to `mapExternal`
   (same return meaning; `null` = untouched). Notion passes a function that, for `https://www.notion.so/...` / `https://notion.so/...` URLs whose last 32 hex characters
   (before `?`/`#`) appear in `idToSource`, returns the mapped path; other `notion.so` URLs are untouched and counted (one summary warning at the end of the run:
   "<N> links point to Notion pages that were not part of the export"). Add tests for `mapExternal` to `link_rewriter_test.dart` (`external mapped`, `external null untouched`).
9. **Dates helper change.** Extend `formatLocal(DateTime instant, {Duration? utcOffset})` from 05.2: with `utcOffset` non-null it formats `instant.toUtc().add(utcOffset)`;
   null → device local time. Add the test `format with fixed offset`. (Every importer that writes dates takes `Duration? utcOffset` so snapshot tests are zone-independent.)
10. **`.base` file** (`base_file_builder.dart`): `String buildBaseFile({required String folderPath, required List<String> propertyKeys, String viewName = 'Table'})`.
    Output, exactly (here for `Import/Tasks`, keys `Status`, `Due date`):
    ```yaml
    filters:
      and:
        - 'file.inFolder("Import/Tasks")'
    views:
      - type: table
        name: Table
        order:
          - file.name
          - note.Status
          - note["Due date"]
    ```
    Rules: 2-space indent, `\n` newlines, trailing newline; the filter string is single-quoted YAML (`'` doubled), inside it `"` and `\` are escaped with a backslash;
    property id = `note.<key>` when the key matches `^[A-Za-z_][A-Za-z0-9_]*$`, else `note["<key with \ and " escaped>"]`; ids containing `"` or `[` are emitted as single-quoted
    YAML scalars. Before coding, read Obsidian's "Bases syntax" help page (the Phase 6 file `phase-06-visual-views.md` §"Bases syntax subset" lists the same subset);
    if the help page differs, follow it and record the difference in `PROGRESS.md`. No `sort`, no `formulas`.
11. **Attachments:** every non-`.md`, non-`.csv` source entry is saved with `AttachmentWriter.save(bytes, name)` where `name` is the file name (ids are not stripped from attachment names
    unless the name matches the id pattern; images are normally called `image.png`, `Untitled.png`); `attachmentMap[sourcePath] = vaultPath`. Identical bytes collapse to one file (05.3).
12. **Progress and speed.** Yield one `ImportItemDone` per note written (databases: per row). Never `list` the vault more than once. Read each source file once.
    Parse each note once (`rewriteLinks` parses). The target is **< 2 minutes for 1,000 notes on Windows** (exit gate); use `tool/gen_notion_export.dart <outDir> <count>` which writes
    a synthetic export: `count` pages across `count/50` nested folders, each page 2 KB of text, 3 links to other pages (percent-encoded with ids), 1 `notion.so` link,
    every 10th page has an image (`tinyPng` bytes, alternating 2 images), plus 2 databases of `count/10` rows each. The bench test (`@Tags(['bench'])`, run with `dart test -t bench`, excluded
    from normal runs via `dart_test.yaml` `tags: { bench: { skip: "run with -t bench" } }`) imports it with `ImportRunner.runInIsolate` into a temp vault, asserts the
    elapsed time and that every `[[...]]` produced by the importer resolves to an existing file (read all notes, parse with `MarkdownParser`, check each wikilink target path).
13. Preview: counts pages + rows as notes, attachments, warnings (HTML export, unresolved CSV, `_all` pick), `sampleTitles`.

**Fixture** `test/fixtures/notion/input/` (use ids `0123…`: `H = 0123456789abcdef0123456789abcdef`, `R = 1123456789abcdef0123456789abcdef`, `D = 2123456789abcdef0123456789abcdef`,
`T = 3123456789abcdef0123456789abcdef`, `W = 4123456789abcdef0123456789abcdef`, `S = 5123456789abcdef0123456789abcdef`; `binaries.json` maps the image):
- `Home H.md` (file name with a real space then the id):
  ```
  # Home

  Welcome. See [Roadmap](Home%20H/Roadmap%20R.md) and the [Tasks table](Tasks%20T.csv).
  A page that is not exported: [Other](https://www.notion.so/Other-9923456789abcdef0123456789abcdef).
  An exported page by URL: [Deep](https://www.notion.so/Deep-D?pvs=4).

  <aside>
  💡 Remember the milk
  </aside>

  ![image.png](Home%20H/image.png)
  ```
  (replace `H`, `R`, `D`, … by the actual 32-hex strings when writing the file.)
- `Home H/Roadmap R.md`: `# Roadmap`, blank, `Back to [Home](../Home%20H.md).`, blank, `<details>`, `<summary>Why?</summary>`, blank, `Because.`, blank, `</details>`.
- `Home H/image.png` (tinyPng).
- `Home H/Roadmap R/Deep D.md`: `# Deep` + `Deep text.`
- `Tasks T.csv`: header `Name,Status,Due,Done,Tags,Estimate,Project`; rows
  `Write spec,In progress,"October 11, 2026",Yes,"a, b",3,"Roadmap (Home%20H/Roadmap%20R.md)"`,
  `Ship it,Not started,"October 15, 2026",No,b,5,` and `Empty row,,,,,,`.
- `Tasks T/Write spec W.md`: `# Write spec`, blank, `Status: In progress`, `Due: October 11, 2026`, `Done: Yes`, `Tags: a, b`, `Estimate: 3`, blank, `Spec body with [home](../Home%20H.md).`
- `Tasks T/Ship it S.md`: `# Ship it`, blank, `Status: Not started`, blank, `Body.`
Expected under `Import/` (target folder `Import`): `Home.md`, `Home/Roadmap.md`, `Home/Roadmap/Deep.md`, `Tasks/Write spec.md`, `Tasks/Ship it.md`, `Tasks/Empty row.md`, `Tasks.base`,
`Attachments/image.png`. Key expectations:
- `Home.md`: links `[[Import/Home/Roadmap|Roadmap]]`, `[[Import/Tasks.base|Tasks table]]`, `[[Import/Home/Roadmap/Deep|Deep]]`; the unexported notion.so link unchanged; callout
  `> [!tip]` / `> Remember the milk`; `![[Import/Attachments/image.png]]`. One warning: "1 links point to Notion pages that were not part of the export" (message text exactly:
  `1 links point to Notion pages that were not part of the export`, prefixed with the source name `Notion export: `).
- `Home/Roadmap.md`: `[[Import/Home|Home]]`, `> [!note]- Why?` then `> Because.`
- `Tasks/Write spec.md` frontmatter exactly:
  ```
  ---
  Status: In progress
  Due: 2026-10-11
  Done: true
  tags:
    - a
    - b
  Estimate: 3
  Project:
    - "[[Import/Home/Roadmap|Roadmap]]"
  ---
  ```
  followed by a blank line and `Spec body with [[Import/Home|home]].`
- `Tasks/Empty row.md`: no non-empty cells besides the title and no body, so there is no frontmatter; the file content is exactly `
`.
- `Tasks.base` exactly as in item 10 with folder `Import/Tasks` and keys `Status`, `Due`, `Done`, `tags`, `Estimate`, `Project`.

**Tests.**
- `notion_importer_test.dart`: `snapshot from directory source`, `snapshot from zip`, `snapshot from nested part zips` (`loadFixtureAsZip(wrapInZipNamed: 'Part-1.zip')`),
  `ids stripped from names` (unit: `stripNotionId` table incl. `_all`, no id, id only), `html export refused`, `rows without page become notes`, `row pages not imported twice`,
  `duplicate titles get numbers`, `notion.so link to exported page rewritten`, `unresolved notion links counted once`, `percent-encoded links resolved` (name with `%2C`, `%26`, unicode `%E0%A6%AC`),
  `case-insensitive match on unicode names`, `attachments deduplicated`.
- `notion_markdown_fixes_test.dart`: one case per rule in item 6, including `aside inside code fence untouched`, `nested toggles`.
- `property_inference_test.dart`: one case per rule and kind, mixed date/datetime → text, ISO mode (`notionDates: false`), relations with two items, tag heuristic with 2 rows vs 1 row, 12-hour conversion (`12:05 AM` → `00:05`, `12:30 PM` → `12:30`).
- `base_file_builder_test.dart`: exact output for simple keys, a key with a space, a key with a quote, a folder with a quote.
- `notion_bench_test.dart`: item 12.

**Verify.**
```powershell
cd packages/tephra_io; dart test test/importers/notion_importer_test.dart test/importers/notion_markdown_fixes_test.dart test/util; cd ../..
cd packages/tephra_io; dart test -t bench test/bench/notion_bench_test.dart; cd ../..
```

**Pitfalls.**
- Notion file names can be truncated and its links may use a different Unicode normalisation (NFD from macOS) than the file names in the zip; Dart cannot normalise, so lookups fall back to a case-insensitive
  comparison, then to matching by the 32-hex id (links carry the id too). Implement the id fallback: if `pageMap` has no exact hit, extract `notionIdOf` from the link's last segment and use `idToSource`.
- The first CSV column is the title only in Notion exports; the CSV importer (05.15) lets the user choose.
- Do not regex over whole notes for link fixing; only `rewriteLinks` (parser offsets) and the line-based fixes above.
- Frontmatter keys come from user data: always go through `FrontmatterBuilder` (quoting), never string concatenation.

---

### 05.10 — Importer 5: Evernote `.enex`

**Purpose.** Convert Evernote export files: ENML → Markdown through the HTML converter, resources (base64) → attachments matched by MD5, to-dos → tasks,
tags and dates → frontmatter, notebook from the file name.

**Files.**
- `packages/tephra_io/lib/src/importers/evernote_importer.dart`
- `packages/tephra_io/lib/src/importers/enml_to_dom.dart` (new)
- `packages/tephra_io/lib/src/html/html_to_markdown.dart` (extend: `convertElement`)
- tests: `test/importers/evernote_importer_test.dart`, `test/importers/enml_to_dom_test.dart`; fixture `test/fixtures/evernote/`

**Implementation.**
1. Dependencies already added in 05.1 (`xml`, `crypto`, `html`). Imports: `package:xml/xml_events.dart` (streaming) and `package:xml/xml.dart`.
2. `EvernoteImporter({Clock clock = const SystemClock(), Duration? utcOffset})`, id `evernote`, label "Evernote (.enex)". `options` → `{"utcOffsetMinutes": int?}`. Wire it into `IoRegistry`.
3. Notes source = every entry with extension `enex` (any folder). Others ignored silently. **Notebook** = the file name without extension (`Work.enex` → `Work`); notes go to folder
   `<notebook>/` (safe name) and get the frontmatter key `notebook: Work`. Two `.enex` files with the same stem → folders made unique by `uniqueName`.
4. **Streaming parse** (a notebook can have thousands of notes): decode the bytes in 64 KiB chunks through `utf8.decoder` (allowMalformed) into a `Stream<String>`, then
   `.toXmlEvents().normalizeEvents().selectSubtreeEvents((e) => e.name == 'note').toXmlNodes().flatten()` and handle each `XmlElement` named `note` one at a time
   (check the `xml` README for the current event API names; if different, adapt and note it in `PROGRESS.md`). Only one note's DOM is alive at a time.
   Files over 300 MiB add the warning `<file>: very large file, memory use will be high`; the whole file is still held once as bytes (documented limitation of `ImportSource.read`).
5. Two-pass is **not** needed here (Evernote notes link to each other only through `evernote:///` or `https://www.evernote.com/shard/...` URLs, which are left unchanged with
   one summary warning `<N> links to other Evernote notes were kept as web links`). Reserve the path of a note right before converting it.
6. Per `note` element read children: `title` (text, default `Untitled`), `created`, `updated` (`parseEnexDate`), `tag` (repeated), `note-attributes` (`author`, `source-url`, `latitude`, `longitude`),
   `content` (CDATA text = ENML), `resource` (repeated: `data` base64 — remove all whitespace before `base64Decode`; `mime`; `resource-attributes/file-name`; `width`).
7. **Resources:** for each resource decode bytes, `hash = md5(bytes)` as lower-case hex; `resources[hash] = ResourceInfo(bytes, mime, fileName, width)`. Missing/invalid base64 → warning
   `<file>: note "<title>": resource could not be decoded` and skip it. File name = `file-name` if present, else `Resource-<first 8 hash chars>.<ext from mime>` (mime→ext table of 05.3).
   Saved lazily with `AttachmentWriter.save` the first time it is referenced (or at the end, item 11).
8. **ENML → DOM** (`enml_to_dom.dart`): `Future<dom.Element> enmlToDom(String enml, ResolveMedia resolveMedia, List<String> warnings)` where
   `typedef ResolveMedia = Future<String?> Function(String hash, String mime, int? width)` returns the Markdown text for an `en-media`.
   Pre-clean: replace the named entities `&nbsp; &copy; &reg; &hellip; &mdash; &ndash; &lsquo; &rsquo; &ldquo; &rdquo; &bull; &trade; &euro; &times;` by numeric references
   (`&#160; &#169; &#174; &#8230; &#8212; &#8211; &#8216; &#8217; &#8220; &#8221; &#8226; &#8482; &#8364; &#215;`) because XML has no HTML entities. Parse with `XmlDocument.parse`;
   on `XmlException` fall back to `parse(enml)` from `package:html` (it tolerates HTML) and add the warning `note "<title>": ENML was not valid XML, converted as HTML`.
   Build an `html` DOM (`dom.Element(...)`, `dom.Text`) by walking the XML tree of `<en-note>` (do **not** serialise to a string and re-parse: HTML5 parsing treats `<div/>` as an open tag):
   | ENML | DOM output |
   |---|---|
   | `en-note` | `div` |
   | `en-todo checked="true"` | `input` with `type=checkbox` and `checked` |
   | `en-todo` (unchecked) | `input type=checkbox` |
   | `en-media hash=… type=…` | the Markdown text from `resolveMedia(hash, type, width)` inserted as a `dom.Text` **marked raw** — implement raw insertion as a `span` with attribute `data-raw-md="1"` whose text the converter emits unescaped (add this rule to `HtmlToMarkdown`: a `span[data-raw-md]` outputs its text content verbatim) |
   | `en-crypt` | text `[encrypted text]` + warning `note "<title>": encrypted text could not be imported` |
   | `div` whose `style` contains `-en-codeblock:true` | `pre` containing the text of its descendant lines joined with `\n` (each child `div`/`br` is a line) |
   | any other element | an element of the same tag name with the attributes `style href src alt colspan rowspan align start class checked` copied (others dropped) and converted children |
   Text and CDATA nodes → `dom.Text`.
9. `HtmlToMarkdown` additions (05.4 file): `static Future<HtmlConvertResult> convertElement(dom.Element root, {HtmlConvertOptions options})` containing the walker (the existing `convert(html)` parses and calls it with `document.body`);
   the `data-raw-md` rule above; a test `convertElement works on a hand-built DOM` and `data-raw-md emitted verbatim` in `html_to_markdown_test.dart`.
10. **`resolveMedia` rules.** `resources[hash]` missing → warning `note "<title>": media <first 8 hash chars> not found in resources` and output `*(missing attachment)*`.
    Found: `path = await attachments.save(bytes, fileName, mimeType: mime)`; images (`image/*`), `application/pdf`, `audio/*`, `video/*` → `attachments.embed(path, width: width)` (width only for images and only when `> 0`);
    any other mime → `[[<path>|<file name>]]`. Record the hash as used.
11. **Unreferenced resources:** after converting the body, for every resource whose hash was not used, append (separated by one blank line from the body, one line each, in document order) the same embed/link text. No warning.
12. **Body assembly:** `body = convertElement(...).markdown`; the note title is **not** repeated. Notes with empty body and no resources are still created (empty body).
13. **Frontmatter** (in this order, skipping empties): `created` (`formatLocal(parseEnexDate(...), utcOffset:)`), `updated`, `tags` (`cleanTag` each, de-duplicate keeping order, drop nulls), `notebook`,
    `source` (`source-url` text), `author`, `latitude`, `longitude` (numbers; only when both present).
14. `ImportItemDone` per note; `ImportFinished` at the end. Preview counts notes by streaming the same way but without decoding resources' base64 (count `<resource>` elements as attachments).

**Fixture** `test/fixtures/evernote/input/Work.enex` (write it by hand; wrap `<content>` in CDATA with the standard `<?xml ...?><!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">` header; `H1`/`H2` below are `tinyPngBase64`/`tinyPng2Base64`):
- Note 1 title `Meeting notes`; created `20261011T093000Z`, updated `20261012T101500Z`; tags `work` and `Project X`; `source-url` `https://example.com/a`; content:
  `<div><b>Agenda</b> for <i>today</i></div><div><en-todo checked="true"/>Done item</div><div><en-todo/>Open item</div><ul><li><div>One</div></li><li><div>Two</div></li></ul><table><tbody><tr><td>A</td><td>B</td></tr><tr><td>1</td><td>2</td></tr></tbody></table><div style="-en-codeblock:true; --en-codeblock:true;"><div>let x = 1;</div><div>print(x);</div></div><div><a href="https://example.com">link</a></div><div><en-media hash="ee76702403cd15dbc71587365494cbe5" type="image/png" width="100"/></div>`
  and one resource (`H1`, `image/png`, no file name). Expected: tasks `- [x] Done item`, `- [ ] Open item`; a table of 2 rows (first row header); a fenced block `let x = 1;\nprint(x);`; the image embed is `![[Import/Attachments/Resource-ee767024.png|100]]`.
- Note 2 title `Photo only`; created `20261011T093000Z`; no tags; content `<div><en-media hash="6c0cf0948e03090bd23e53d44953fbfe" type="image/png"/></div>`; resources: `H2` with file name `shot.png`, and a second, unreferenced resource (`text/plain`, file name `notes.txt`, base64 of `hi`). Expected: `![[Import/Attachments/shot.png]]` then, after a blank line, `[[Import/Attachments/notes.txt|notes.txt]]`.
- Note 3 title `Entities`; content `<div>A&nbsp;B &copy; 2026</div>` (named entities are invalid XML on purpose); expected body `A B © 2026`, no fallback warning (pre-clean handles it).
- Note 4 title `Broken`; content is `<div>unclosed <b>bold</div>` (not well-formed XML) → fallback to HTML, warning, body `unclosed **bold**`.
Expected tree: `Import/Work/Meeting notes.md`, `Photo only.md`, `Entities.md`, `Broken.md`, `Import/Attachments/Resource-ee767024.png`, `shot.png`, `notes.txt`. Use `utcOffset: Duration.zero` in tests; `Meeting notes` frontmatter:
```
---
created: 2026-10-11T09:30:00
updated: 2026-10-12T10:15:00
tags:
  - work
  - Project-X
notebook: Work
source: "https://example.com/a"
---
```

**Tests.** `evernote_importer_test.dart`: `snapshot`, `md5 matching maps hash to the right resource` (two resources, swapped order), `unreferenced resource appended`, `todo becomes task`, `tags cleaned and deduplicated`,
`dates with offset` (`utcOffset: Duration(hours: 6)` → `2026-10-11T15:30:00`), `notebook from file name and folder`, `missing media hash warns`, `invalid xml falls back to html`, `two enex files two folders`, `cancel mid-stream stops`
(use a 200-note generated enex built in the test). `enml_to_dom_test.dart`: each row of the table in item 8.

**Verify.** `cd packages/tephra_io; dart test test/importers/evernote_importer_test.dart test/importers/enml_to_dom_test.dart test/html; cd ../..`

**Pitfalls.** Evernote `<created>` values are UTC (`Z`); never treat them as local. `base64Decode` fails on whitespace/newlines: strip them first. Never log note text. `en-media` without `type` → use the resource's mime.

---

### 05.11 — Importer 6: Google Keep (Takeout JSON)

**Purpose.** Convert notes from a Google Takeout "Keep" export (a zip, a folder, or loose `.json` files).

**Files.**
- `packages/tephra_io/lib/src/importers/keep_importer.dart`
- `packages/tephra_io/test/importers/keep_importer_test.dart`; fixture `test/fixtures/keep/`

**Implementation.**
1. `KeepImporter({Clock clock = const SystemClock(), Duration? utcOffset, bool asStickies = false})`, id `keep`, label "Google Keep (Takeout)". `options` → `{"utcOffsetMinutes": int?, "asStickies": bool}`. Wire into `IoRegistry`.
2. Candidate notes = entries with extension `json`. Parse with `jsonDecode`; a parse error or a non-object → warning `<path>: not a valid Keep note, skipped`. A JSON object is a Keep note when it has the key `isTrashed` **or** `createdTimestampUsec`
   **or** `textContent` **or** `listContent`; other JSON files are ignored silently. `.html` copies, `Labels.txt` and everything else are ignored silently except attachments (item 7).
3. Skip `isTrashed == true` (count them; after the loop one warning `<N> trashed notes were skipped`, none if 0). Preview: `skipped` = trashed count.
4. **Folder:** `isArchived == true` → `Archive/`, else the target folder itself. Notes are written flat (Keep has no folders); labels are tags.
5. **Title:** `title` trimmed; empty → the first non-empty line of `textContent` (or first list item text) cut at 60 characters (at a word boundary when possible); still empty → `Keep note <n>` (n = order of appearance, 1-based, per run).
6. **Body**, in this order, joined with one blank line:
   1. `textContent` with newlines normalised (not escaped; plain text, like `.txt` in 05.7);
   2. `listContent` → one line per item: `- [ ] text` or `- [x] text` (`isChecked`); items with empty text skipped; order as in the file;
   3. attachments (item 7), one embed per line;
   4. `annotations` (web link cards) → one line each `[<title or url>](<url>)`; entries without `url` skipped.
7. **Attachments:** `attachments[]: {filePath, mimetype}`. `filePath` is relative to the folder of the JSON file. Read it from the source; missing → warning `<path>: attachment <filePath> not found`. Save with `AttachmentWriter.save(bytes, name, mimeType:)`;
   embed with `attachments.embed(path)` for images, audio and video mime types, else `[[<path>|<name>]]`. Audio recorded by Keep is `.3gp`; embed it anyway.
8. **Frontmatter** (in order, skipping empties): `created` from `createdTimestampUsec` (`fromMicros`), `updated` from `userEditedTimestampUsec`, `tags` (`labels[].name` → `cleanTag`, de-duplicate), `color` (lower-case of `color` unless `DEFAULT` or absent), `pinned: true` when `isPinned`.
   With `asStickies: true` also `tephra-sticky: true`; `sticky-color` from this table (conventions §6.5 names): `YELLOW→yellow`, `GREEN→green`, `BLUE→blue`, `PURPLE→purple`, `PINK→pink`, `GRAY→gray`, `RED→#F28B82`, `ORANGE→#FBBC04`, `TEAL→#A7FFEB`,
   `CERULEAN→#CBF0F8`, `BROWN→#E6C9A8`, `DEFAULT`/unknown → key omitted; and `sticky-pinned: true` when `isPinned`. The `color`/`pinned` keys are still written.
9. Name collisions are handled by `NoteWriter.reserve`. One `ImportItemDone` per written note.

**Fixture** `test/fixtures/keep/input/Takeout/Keep/` (times: `2026-10-11T09:30:00Z` = `1791711000000000` µs, `2026-10-12T10:15:00Z` = `1791800100000000` µs):
- `Groceries.json`: `{"title":"Groceries","color":"YELLOW","isPinned":true,"isArchived":false,"isTrashed":false,"listContent":[{"text":"Milk","isChecked":true},{"text":"Eggs","isChecked":false},{"text":"","isChecked":false}],"labels":[{"name":"Home"},{"name":"errands list"}],"createdTimestampUsec":1791711000000000,"userEditedTimestampUsec":1791800100000000}`
- `Idea.json`: `{"title":"Idea","color":"DEFAULT","isTrashed":false,"isArchived":false,"isPinned":false,"textContent":"Line one\nLine two","attachments":[{"filePath":"idea.png","mimetype":"image/png"},{"filePath":"gone.png","mimetype":"image/png"}],"annotations":[{"title":"Example","url":"https://example.com"}],"createdTimestampUsec":1791711000000000,"userEditedTimestampUsec":1791711000000000}`
- `Old.json`: archived note (`"isArchived":true`, `textContent":"old"`, title `Old`).
- `Gone.json`: `"isTrashed":true`.
- `Untitled.json`: no title, `textContent":"First line of an untitled note\nsecond"`.
- `broken.json`: the text `{ not json`.
- `Labels.txt`, `Idea.html` (ignored), `idea.png` (tinyPng).
Expected (offset `Duration.zero`, `asStickies: false`): `Import/Groceries.md`:
```
---
created: 2026-10-11T09:30:00
updated: 2026-10-12T10:15:00
tags:
  - Home
  - errands-list
color: yellow
pinned: true
---

- [x] Milk
- [ ] Eggs
```
`Import/Idea.md` = frontmatter `created`, `updated` + `Line one\nLine two`, blank, `![[Import/Attachments/idea.png]]`, blank, `[Example](https://example.com)`; `Import/Archive/Old.md`; `Import/First line of an untitled note.md`; `Gone` absent; warnings:
`Takeout/Keep/Idea.json: attachment gone.png not found`, `Takeout/Keep/broken.json: not a valid Keep note, skipped`, `Keep export: 1 trashed notes were skipped`.

**Tests.** `snapshot`, `asStickies adds sticky keys` (Groceries → `tephra-sticky: true`, `sticky-color: yellow`, `sticky-pinned: true`; a RED note → `#F28B82`), `trashed skipped and counted`, `archived goes to Archive`, `title falls back to first line`, `zip source with Takeout prefix`, `loose json files source` (FilesSourceSpec: attachments missing → warnings), `list items with empty text skipped`.

**Verify.** `cd packages/tephra_io; dart test test/importers/keep_importer_test.dart; cd ../..`

**Pitfalls.** Keep timestamps are microseconds, not milliseconds. Do not Markdown-escape text. `labels` can be absent.

---

### 05.12 — Importer 7: Bear (Markdown export and TextBundle)

**Purpose.** Import Bear notes from a Markdown export folder/zip or from TextBundle packages (`.textbundle`, `.textpack`, `.bear2bk`).

**Decision.** Supported inputs (see "Decisions taken here"): (a) a folder or zip with `.md`/`.markdown` files and attachment folders; (b) TextBundle: directories ending `.textbundle` (`info.json`, `text.md|text.markdown|text.txt`, `assets/`),
`.textpack` files (zip of one bundle) and `.bear2bk` files (zip of many bundles). The wizard lets the user pick a folder, a `.zip`, a `.textpack` or a `.bear2bk`; the latter two are opened with `ZipSourceSpec` (any zip file regardless of extension).

**Files.**
- `packages/tephra_io/lib/src/importers/bear_importer.dart`
- `packages/tephra_io/lib/src/importers/bear_syntax.dart` (new; pure text conversions)
- tests: `test/importers/bear_importer_test.dart`, `test/importers/bear_syntax_test.dart`; fixture `test/fixtures/bear/`

**Implementation.**
1. `BearImporter({Clock clock = const SystemClock(), Duration? utcOffset})`, id `bear`, label "Bear (Markdown / TextBundle)". `options` → `{"utcOffsetMinutes": int?}`. Wire into `IoRegistry`.
2. **Find units.** A *unit* = one note: `BearUnit({title, text, baseDir, folder, info})`. Algorithm over `src.list()`:
   1. **Nested packs:** entries ending `.textpack` or `.bear2bk` (case-insensitive) are opened in memory with `ZipDecoder` and their files are added to the entry list under the prefix `<entry path>!/` (zip-slip rules of 05.1 apply; skipped ones → warning).
   2. **TextBundles:** a directory `D` (path prefix) is a bundle when its name ends with `.textbundle` **or** it directly contains `info.json` and one of `text.md`, `text.markdown`, `text.txt`. The text file = the first existing of those three in that order. `baseDir = D` (links like `assets/x.png` are relative to it). `info` = decoded `info.json`
      (parse errors → warning, ignored). Created/updated: if `info['net.shinyfrog.bear']` is an object, use its `creationDate` / `modificationDate` when they parse with `DateTime.tryParse` (ISO 8601). Skip when `info['net.shinyfrog.bear']['trashed'] == true` (counted, summary warning `<N> trashed notes were skipped`); `archived == true` → folder `Archive`.
   3. **Markdown export:** every remaining `.md`/`.markdown` file that is not inside a bundle is a unit; `baseDir` = its directory; `folder` = its directory (sanitised) so exported subfolders survive.
   4. Attachments inside a bundle (`assets/…`) are saved only when referenced. In a Markdown export, **every referenced relative file** is saved (images, PDFs, other); unreferenced files are ignored with no warning.
   5. Anything else (not text, not info, not referenced) is ignored; for `.bear2bk` roots, entries that are neither part of a bundle nor an `.md` file add one summary warning `<N> unknown files in the backup were skipped`.
3. **Title:** the first line `# Title` of the text if present (Bear's note title), else the bundle/file stem. Remove that first line from the body when it equals the title (case-insensitive) and the next line is empty or the end. Folder-less units → target folder.
4. **Syntax conversions** (`bear_syntax.dart`: `String convertBearSyntax(String text, {required BearLinkLookup lookup})`), line-based, skipping fenced code blocks and inline code spans (a small scanner: toggles on lines that start with ``` and on backtick pairs inside a line):
   1. **Multi-word tags** `#multi word tag#` → `#multi-word-tag` (`cleanTag`): find a `#` at a token start (line start or after whitespace) whose next char is not whitespace or `#`, then the next `#` on the same line; the text between has length 2–60, **contains a space**, does not start or end with a space and contains no `#`;
      the closing `#` must be followed by whitespace, punctuation `.,;:!?)` or end of line. `# Heading` and `Issue #1 and #2` are therefore untouched.
   2. **Highlights** `::text::` → `==text==` (non-greedy, same line, at least one non-space char inside).
   3. **Heading links** `[[Note/Heading]]` → `[[Note#Heading]]` only when `lookup.noteExists('Note/Heading')` is false and `lookup.noteExists('Note')` is true (Bear uses `/` between note and heading).
   4. Everything else is kept (`#tag`, `#nested/tag`, `- [ ]`, `[[Note]]`, tables).
5. **Links and images:** after syntax conversion run `rewriteLinks` with a map built per unit: relative targets are decoded, resolved against the unit's `baseDir` in the source; if they hit a unit → that note's vault path; if they hit a file in the source → saved attachment path; else untouched.
   `[[Note]]` wikilinks to other Bear notes: map note titles (case-insensitive) → reserved paths and rewrite to `[[<path>|Note]]`; unknown titles untouched. Reserve all notes first (pass 1), convert after (pass 2).
6. **Frontmatter:** `created`/`updated` when present (from `info`), nothing else. Tags stay inline in the body.
7. Preview counts units; warnings as above.

**Fixture** `test/fixtures/bear/`:
- `input-md/` (Markdown export): `Ideas.md` (`# Ideas`, blank, `#work #multi word tag# ::important:: and [[Plans/Phase 1]]`, blank, `![](Ideas.assets/pic.png)`), `Plans.md` (`# Plans`), `Ideas.assets/pic.png` (tinyPng), `Sub/Deep.md` (`# Deep` + a `[[Ideas]]` link), `Issue.md` (`# Issue` + `See issue #1 and #2`).
- `input-tb/` (TextBundle): `Trip.textbundle/info.json` = `{"version":2,"type":"net.daringfireball.markdown","net.shinyfrog.bear":{"creationDate":"2026-10-11T09:30:00Z","modificationDate":"2026-10-12T10:15:00Z"}}`,
  `Trip.textbundle/text.md` (`# Trip`, blank, `Pack ![](assets/map.png)`), `Trip.textbundle/assets/map.png` (tinyPng2), `Old.textbundle/info.json` with `"trashed":true` and `text.md`, `Old.textbundle/text.md`.
- A test builds `input-tb` into a zip named `backup.bear2bk` wrapped in a `Backup/` prefix folder, and also a `.textpack` containing only `Trip.textbundle`.
Expected (`input-md`, target `Import`): `Import/Ideas.md` body `#work #multi-word-tag ==important== and [[Import/Plans#Phase 1|Plans]]` (step 4.3 first turns `[[Plans/Phase 1]]` into `[[Plans#Phase 1]]` because no note is titled `Plans/Phase 1` but one is titled `Plans`; the link rewrite then maps `Plans` to its path, keeps the heading and uses the alias `Plans`),
`![[Import/Attachments/pic.png]]`; `Import/Plans.md` (empty body); `Import/Sub/Deep.md` with `[[Import/Ideas|Ideas]]`; `Import/Issue.md` body unchanged (`See issue #1 and #2`).
`input-tb`: `Import/Trip.md` with frontmatter `created`/`updated` (offset zero) and body `Pack ![[Import/Attachments/map.png]]`; `Old` absent; warning `Bear export: 1 trashed notes were skipped`.

**Tests.** `bear_syntax_test.dart`: each rule incl. `# Heading untouched`, `#1 and #2 untouched`, `code span untouched`, `fenced block untouched`, `heading link only when full name missing`.
`bear_importer_test.dart`: `markdown export snapshot`, `textbundle folder snapshot`, `textpack zip`, `bear2bk with wrapper folder`, `trashed skipped`, `unknown files warned once`, `title line removed only when equal`.

**Verify.** `cd packages/tephra_io; dart test test/importers/bear_importer_test.dart test/importers/bear_syntax_test.dart; cd ../..`

**Pitfalls.** Bear's real `.bear2bk` layout is not public: if the human can provide a real file, add it as a private fixture (not committed) and note the real layout in `PROGRESS.md`. The importer must never guess dates from file times.

---

### 05.13 — Importer 8: Roam Research JSON (and the daily-note naming helper)

**Purpose.** Convert a Roam JSON export to notes: pages → notes, blocks → nested lists, block references → `^id` anchors, `{{[[TODO]]}}`/`{{[[DONE]]}}` → tasks, with daily pages renamed by a configurable daily-note format.

**Files.**
- `packages/tephra_io/lib/src/util/daily_note_format.dart` (new; reused by Logseq in 05.14)
- `packages/tephra_io/lib/src/importers/roam_importer.dart`
- `packages/tephra_io/lib/src/importers/roam_syntax.dart` (new; block-text conversions)
- tests: `test/util/daily_note_format_test.dart`, `test/importers/roam_importer_test.dart`, `test/importers/roam_syntax_test.dart`; fixture `test/fixtures/roam/`

**Implementation.**
1. **`DailyNoteFormat`** (moment-style tokens, the same syntax as the vault setting `dailyNotes.format`, default `YYYY-MM-DD`):
   ```dart
   final class DailyNoteFormat {
     const DailyNoteFormat(this.pattern);
     final String pattern;
     String format(DateTime date);                       // uses y/m/d only
     DateTime? parse(String text);                       // null when it does not match
     static String fromJavaPattern(String java);         // Logseq/Java tokens → moment tokens (see item 2)
   }
   ```
   Tokens (longest match first): `YYYY` year, `YY` 2-digit year, `MMMM` full month name (English), `MMM` 3-letter month, `MM` 2-digit month, `M` month, `DD` 2-digit day, `D` day, `Do` day with ordinal (`1st 2nd 3rd 4th … 11th 12th 13th … 21st 22nd 23rd 24th … 31st`),
   `dddd` full weekday, `ddd` 3-letter weekday. Text in `[square brackets]` is literal; any other character is literal. `parse` builds a regular expression from the pattern (month names matched case-insensitively, `Do` = `\d{1,2}(?:st|nd|rd|th)`) and validates the result with `DateTime(y,m,d)` round-trip (rejects 31 February).
   Patterns lacking year, month or day tokens → `parse` returns null always; `format` still works.
2. `fromJavaPattern`: `yyyy`→`YYYY`, `yy`→`YY`, `MMMM`/`MMM`/`MM` unchanged, `M` unchanged, `dd`→`DD`, `d`→`D`, `do`→`Do`, `EEEE`→`dddd`, `EEE`→`ddd`; other letters inside quotes `'…'` → `[…]`; other characters unchanged.
3. `RoamImporter({Clock clock = const SystemClock(), Duration? utcOffset, String dailyFormat = 'YYYY-MM-DD', String dailyFolder = 'Daily', String roamTitleFormat = 'MMMM Do, YYYY', bool dailyAsDailyNotes = true})`,
   id `roam`, label "Roam Research (JSON)". `options` → the five fields. The wizard (05.21) pre-fills `dailyFormat`/`dailyFolder` from the vault's daily-notes settings. Wire into `IoRegistry`.
4. **Input:** the source's `.json` entries (a `.zip` is fine); each file must decode to a JSON **array** of page objects `{title, uid?, "create-time"?, "edit-time"?, children?: [block]}`; blocks `{string, uid, "create-time"?, "edit-time"?, heading?: 1|2|3, children?}`.
   Not an array → warning `<path>: not a Roam export, skipped`. Preview: pages = notes.
5. **Pass 1 (collect):** for every page → `RoamPage`. A page is a **daily page** when `dailyAsDailyNotes` and `DailyNoteFormat(roamTitleFormat).parse(title) != null`. Destination: daily → folder `dailyFolder`, title `DailyNoteFormat(dailyFormat).format(date)`;
   others → folder `` (target root), title = page title through `safeFileName` (a `/` in a Roam namespace title becomes `-`; the original title is kept in a `titleToPath` key). `NoteWriter.reserve` all pages first. `titleToPath[lowercase(roamTitle)] = path`.
   Walk all blocks recursively: `blockOwner[uid] = (page path, block)`; scan every `string` for `((uid))` (`\(\(([A-Za-z0-9_-]{6,12})\)\)`) → `referenced.add(uid)`.
6. **Block ids:** `anchorId(uid) = uid.replaceAll('_', '-')` (Obsidian ids allow `[A-Za-z0-9-]`). Only blocks in `referenced` get `^<anchorId>` appended. A reference to an unknown uid stays `((uid))` and adds a warning `<page>: block reference ((uid)) not found in the export` (one per uid per page).
7. **Block → text** (`roam_syntax.dart`: `String convertRoamBlock(String s, RoamLookup lookup, {required String currentPagePath})`). Split the string into code segments (inline `` `…` `` and fenced ``` blocks) and normal segments; code segments are untouched; on normal segments apply, **in this order**:
   1. `{{[[embed]]: ((uid))}}` and `{{embed: ((uid))}}` → `![[<owner path>#^<anchor>]]` (same page → `![[#^<anchor>]]`);
   2. `[alias](((uid)))` → `[[<owner path>#^<anchor>|alias]]`;
   3. `[alias]([[Page]])` → `[[Page|alias]]` (page link resolved later);
   4. `((uid))` → `[[<owner path>#^<anchor>]]` (same page → `[[#^<anchor>]]`);
   5. `#[[Multi Word]]` → `[[Multi Word]]`; `#tag` and `#nested-tag` untouched; `[[Page]]` untouched here;
   6. `^^text^^` → `==text==`; `__text__` → `*text*` (`**bold**`, `~~strike~~`, links untouched);
   7. `{{[[TODO]]}}`/`{{TODO}}` at the **start** of the block → marks the block as a task `[ ]`; `{{[[DONE]]}}`/`{{DONE}}` → task `[x]`; the marker (and one following space) is removed from the text;
   8. other `{{...}}` macros stay unchanged; collect their names (`{{[[table]]}}` → `table`) into a set → one warning per page `<page>: Roam macros not converted: table, query`.
8. **Page text.** Blocks become nested list items, one tab per depth level: `- <text>` (`- [ ] <text>` / `- [x] <text>` for tasks; `- ## <text>` for `heading: 2`, `#`×heading for 1–3). Multi-line block strings: continuation lines are indented by the item's indent plus two spaces.
   The `^anchor` goes at the end of the **last** line of the block's own text. A page without blocks gets an empty body. After assembling the page text call `rewriteLinks` with a map: `[[Title]]` where `titleToPath[lowercase(Title)]` exists → `<path>` and the rewriter writes `[[<path>|Title]]`; `[[Title#^id]]`
   targets that are already full paths (contain `/` and resolve to a reserved path) are left alone; unknown titles untouched. (Add to `rewriteLinks` tests: `alias added when the new target differs from the original text` — if not already covered.)
9. **Frontmatter** per page: `created` (`fromMillis(create-time)`), `updated` (`edit-time`), skipping missing values. Daily pages additionally get `aliases: [<original Roam title>]` (e.g. `October 11th, 2026`) so that `[[October 11th, 2026]]` typed later still finds the note.
10. One `ImportItemDone` per page.

**Fixture** `test/fixtures/roam/input/export.json` (options in the test: `dailyFormat: 'YYYY-MM-DD'`, `dailyFolder: 'Daily'`, `utcOffset: Duration.zero`; ms values `1791711000000` and `1791800100000`):
```json
[
 {"title":"Project Alpha","uid":"pageAlpha1","create-time":1791711000000,"edit-time":1791800100000,"children":[
   {"string":"Overview","uid":"blk000001","heading":2,"children":[
     {"string":"{{[[TODO]]}} write spec ^^now^^","uid":"blk000002"},
     {"string":"{{[[DONE]]}} ship __v1__","uid":"blk000003"}]},
   {"string":"See ((blk000009)) and #[[Multi Word]] and #tag and [[October 11th, 2026]] and [[Missing Page]]","uid":"blk000004","children":[
     {"string":"line one\nline two","uid":"blk000005"}]},
   {"string":"{{[[table]]}}","uid":"blk000006"},
   {"string":"bad ref ((zzzzzzzzz))","uid":"blk000007"}]},
 {"title":"October 11th, 2026","uid":"10-11-2026","children":[
   {"string":"Daily thought","uid":"blk000009"}]},
 {"title":"Orphan","uid":"orph00001"}
]
```
Expected: `Import/Project Alpha.md`:
```
---
created: 2026-10-11T09:30:00
updated: 2026-10-12T10:15:00
---

- ## Overview
	- [ ] write spec ==now==
	- [x] ship *v1*
- See [[Import/Daily/2026-10-11#^blk000009]] and [[Multi Word]] and #tag and [[Import/Daily/2026-10-11|October 11th, 2026]] and [[Missing Page]]
	- line one
	  line two
- {{[[table]]}}
- bad ref ((zzzzzzzzz))
```
(the page-level tab characters are real tabs; the continuation line is a tab plus two spaces); `Import/Daily/2026-10-11.md` has frontmatter `aliases:` list `October 11th, 2026` and body `- Daily thought ^blk000009`; `Import/Orphan.md` is `\n`.
Warnings: `Project Alpha: block reference ((zzzzzzzzz)) not found in the export`, `Project Alpha: Roam macros not converted: table`.

**Tests.** `daily_note_format_test.dart`: format/parse `YYYY-MM-DD`, `MMMM Do, YYYY` (all ordinal edge cases 1, 2, 3, 11, 12, 13, 21, 22, 23, 31), `[Week] ddd`, invalid date `February 31st, 2026` → null, `fromJavaPattern('MMM do, yyyy')` → `MMM Do, YYYY`, `fromJavaPattern("yyyy_MM_dd")`.
`roam_syntax_test.dart`: each of the eight rules, code span untouched, nested fence untouched. `roam_importer_test.dart`: `snapshot`, `daily naming option off keeps title`, `custom daily format and folder` (`dailyFormat: 'MMMM Do, YYYY'`, `dailyFolder: ''`), `referenced blocks only get ids`, `underscore in uid replaced`, `not an array warned`, `zip with two json files`.

**Verify.** `cd packages/tephra_io; dart test test/util/daily_note_format_test.dart test/importers/roam_importer_test.dart test/importers/roam_syntax_test.dart; cd ../..`

**Pitfalls.** Do not regex over the whole page: convert block by block. Roam `edit-time` values are milliseconds. A page title containing `/`, `:` or `?` must be sanitised, but links must still find it through `titleToPath` (keyed by the **original** title).

---

### 05.14 — Importer 9: Logseq graph (Markdown)

**Purpose.** Import a Logseq graph folder: `pages/`, `journals/`, `assets/`, with `key:: value` properties, `TODO/DONE/NOW/LATER` markers, block ids and references.

**Files.**
- `packages/tephra_io/lib/src/importers/logseq_importer.dart`
- `packages/tephra_io/lib/src/importers/logseq_syntax.dart` (new)
- tests: `test/importers/logseq_importer_test.dart`, `test/importers/logseq_syntax_test.dart`; fixture `test/fixtures/logseq/`

**Implementation.**
1. `LogseqImporter({Clock clock = const SystemClock(), String dailyFormat = 'YYYY-MM-DD', String dailyFolder = 'Daily'})`, id `logseq`, label "Logseq (Markdown graph)". `options` → `{"dailyFormat":…, "dailyFolder":…}`. Wire into `IoRegistry`. (No dates are written, so no `utcOffset`.)
2. **Graph detection:** entries under `pages/` and `journals/` (the graph may be nested one level in a zip: detect the folder that contains `pages` or `journals` and use it as root; prefix-free otherwise). Without either folder: treat the root as `pages/` and add the warning `No pages/ or journals/ folder found, importing every .md file as a page`.
3. **Config:** read `logseq/config.edn` if present with two tiny regular expressions on its text (EDN is not parsed): `:journal/page-title-format\s+"([^"]+)"` (default `MMM do, yyyy`) and `:journal/file-name-format\s+"([^"]+)"` (default `yyyy_MM_dd`). Convert both with `DailyNoteFormat.fromJavaPattern`. Use `DailyNoteFormat(fileFormat).parse(<journal file stem>)` to get each journal date; a file that does not parse → imported as a normal page + warning.
4. **Skipped with warnings:** `*.org` (`org-mode pages are not supported`), `whiteboards/*` and `*.edn` outside `logseq/` (`whiteboards are not supported`), `draws/*` (`drawings are not supported`). Skipped silently: everything under `logseq/`, hidden paths, `.DS_Store`.
5. **Titles and destinations:**
   - Journals → folder `dailyFolder`, name `DailyNoteFormat(dailyFormat).format(date)`; link title (for `[[Oct 11th, 2026]]`) = `DailyNoteFormat(titleFormat).format(date)` → `titleToPath`.
   - Pages → title = page property `title::` if present, else the file stem with `___` → `/`, `%2F` → `/`, and the legacy dot form `a.b` → `a/b` **only** when the page has no `title::` and `config.edn` contains `:file/name-format :legacy`... — to stay simple: handle `___` and `%2F` only; dots are kept. The safe file name replaces `/` with `-`; `titleToPath[lowercase(title)]` keeps the original title with slashes.
   Reserve all pages and journals first.
6. **Page properties:** the leading lines of the file that match `^([A-Za-z0-9_-]+):: ?(.*)$` before the first bullet line; **or**, if the first bullet block consists only of property lines (`- key:: value` then indented `key:: value` lines), that block. Those lines are removed from the body and become frontmatter:
   `title` → not written (it is the file name); `tags` → `tags` list (split on `,`, strip `[[`, `]]` and `#`, `cleanTag`); `alias`/`aliases` → `aliases` list (split on `,`, strip `[[ ]]`); `public`, `filters`, `collapsed`, `id` → dropped;
   all other keys → written with their name as is; value: `true`/`false` → bool, `^-?\d+(\.\d+)?$` → number, a value containing `,` or several `[[..]]` → list of strings split on `,` (each trimmed), otherwise a string (`[[Page]]` stays the string `"[[Page]]"` — the builder quotes it).
7. **Block conversions** (`logseq_syntax.dart`, line-based over the remaining text; fenced code blocks and `{{renderer ...}}` lines untouched):
   1. **Indentation:** detect the indent unit of the file (first indented bullet: `\t`, 2 or 4 spaces); rewrite the leading whitespace of every line to tabs (one tab per unit; continuation lines of a block keep their extra spaces after the tabs).
   2. **Task markers** at the start of a bullet's text (after `- `): `TODO ` → `[ ] `, `LATER ` → `[ ] `, `WAITING ` → `[ ] `, `NOW ` → `[/] `, `DOING ` → `[/] `, `IN-PROGRESS ` → `[/] `, `DONE ` → `[x] `, `CANCELED `/`CANCELLED ` → `[-] `. Lines `SCHEDULED: <…>`/`DEADLINE: <…>` and `:LOGBOOK:` drawers are kept unchanged (limitation, listed in the hand-off).
      A priority tag `[#A]` is kept in the text.
   3. **Block properties** inside a block (indented `key:: value` lines): `id:: <uuid>` → removed and the uuid recorded as the block's anchor, appended as ` ^<uuid>` at the end of that block's **first** line; `collapsed:: true|false` → removed; every other property line is **kept inline unchanged**.
      Page-level and block-level `id::` are both collected in pass 1 (`blockOwner[uuid] = page path`).
   4. `((uuid))` → `[[<owner path>#^<uuid>]]` (same page → `[[#^<uuid>]]`); `{{embed ((uuid))}}` → `![[<owner path>#^<uuid>]]`; `{{embed [[Page]]}}` → `![[Page]]`; unknown uuid → left as is + warning `<page>: block reference ((uuid)) not found`.
   5. `#[[Multi Word]]` → `[[Multi Word]]`; `#tag` and `[[Page]]` untouched here; `[[Page]]` is mapped afterwards with `rewriteLinks` and `titleToPath` exactly like Roam (05.13 item 8).
   6. Images/files: Markdown links with relative targets (`../assets/pic.png`) → resolve against the page's source folder; existing file → `AttachmentWriter.save` → `rewriteLinks` produces `![[<path>]]`; `{{video …}}`/`{{youtube …}}` unchanged.
8. Frontmatter + body written with `NoteWriter.write`; one `ImportItemDone` per page/journal. Preview counts pages and journals.

**Fixture** `test/fixtures/logseq/input/` (`binaries.json` for the image; options `dailyFormat 'YYYY-MM-DD'`, `dailyFolder 'Daily'`):
- `logseq/config.edn`: `{:journal/page-title-format "MMM do, yyyy" :journal/file-name-format "yyyy_MM_dd" :preferred-format :markdown}`
- `logseq/bak/x.md` (ignored silently)
- `pages/Project.md` (a tab is written `⇥` here; use real tabs in the file):
  ```
  title:: Project
  tags:: work, [[active]]
  alias:: Proj, P
  status:: open
  priority:: 2

  - TODO write the spec
  - NOW doing it
  ⇥- DONE nested done
  - LATER later
  - Referenced block
    id:: 65010000-0000-4000-8000-000000000001
    collapsed:: true
    owner:: me
  - See ((65010000-0000-4000-8000-000000000001)) and #[[Multi Word]] and [[Oct 11th, 2026]]
  - ![pic](../assets/pic.png)
  ```
- `pages/a___b.md`: `- namespace page` (title `a/b` → file `a-b.md`).
- `journals/2026_10_11.md`: `- Met with [[Project]]` and `- ref ((65010000-0000-4000-8000-000000000001))`.
- `assets/pic.png` (tinyPng), `whiteboards/w.edn` (warn), `pages/old.org` (warn).
Expected: `Import/Project.md`:
```
---
tags:
  - work
  - active
aliases:
  - Proj
  - P
status: open
priority: 2
---

- [ ] write the spec
- [/] doing it
	- [x] nested done
- [ ] later
- Referenced block ^65010000-0000-4000-8000-000000000001
  owner:: me
- See [[#^65010000-0000-4000-8000-000000000001]] and [[Multi Word]] and [[Import/Daily/2026-10-11|Oct 11th, 2026]]
- ![[Import/Attachments/pic.png]]
```
`Import/a-b.md` = `- namespace page`; `Import/Daily/2026-10-11.md` = `- Met with [[Import/Project|Project]]` / `- ref [[Import/Project#^65010000-0000-4000-8000-000000000001]]`.
Warnings: `whiteboards/w.edn: whiteboards are not supported`, `pages/old.org: org-mode pages are not supported`.

**Tests.** `logseq_syntax_test.dart`: every item-7 rule; indentation from 4 spaces and from tabs; priority kept; `SCHEDULED` kept. `logseq_importer_test.dart`: `snapshot`, `journal format from config`, `journal with unparsable name becomes page`, `first block of properties becomes frontmatter`, `unknown block ref warned`, `zip with graph folder prefix`, `no pages folder warned`.

**Verify.** `cd packages/tephra_io; dart test test/importers/logseq_importer_test.dart test/importers/logseq_syntax_test.dart; cd ../..`

**Pitfalls.** `[[#^id]]` is only valid within the same note; across notes always use the full path. Logseq property keys are case-insensitive in the app but kept as written here. Do not touch lines inside `#+BEGIN_SRC`-style blocks or fences.

---

### 05.15 — Importer 12: CSV (one note per row, with a column-mapping step)

**Purpose.** Turn any CSV into notes: the user chooses the title column, the body column and which columns become properties.

**Files.**
- `packages/tephra_io/lib/src/importers/csv_importer.dart`
- tests: `test/importers/csv_importer_test.dart`; fixture `test/fixtures/csv/`

**Implementation.**
1. Mapping model (JSON-serialisable, used by the wizard and by `options`):
   ```dart
   final class CsvMapping {
     const CsvMapping({this.titleColumn, this.bodyColumn, this.skipColumns = const [], this.kinds = const {}, this.delimiter, this.listSeparator = ',', this.createBase = false});
     final String? titleColumn;               // header name; null → suggested
     final String? bodyColumn;                // header name; null → no body
     final List<String> skipColumns;          // header names not imported
     final Map<String, String> kinds;         // header → 'text'|'number'|'checkbox'|'date'|'datetime'|'list'|'auto' (default auto)
     final String? delimiter;                 // null = auto-detect (05.2)
     final String listSeparator;              // used for kind 'list'
     final bool createBase;                   // also write '<stem>.base' with a table view
     Map<String, Object?> toJson();  static CsvMapping fromJson(Map<String, Object?> json);
     static CsvMapping suggest(CsvTable table);
   }
   ```
   `suggest`: `titleColumn` = the first header matching `^(title|name|subject|summary|heading)$` (case-insensitive), else the first header; `bodyColumn` = the first header matching `^(body|content|notes?|description|text|details)$`, else null; everything else default.
2. `CsvImporter({Clock clock = const SystemClock(), CsvMapping? mapping})`, id `csv`, label "CSV (one note per row)". `options` → `{"mapping": mapping?.toJson()}`. Wire into `IoRegistry`.
   `preview`: parses the **first** CSV of the source; returns `notes` = total rows over all CSVs, `columns` = the header names of the first CSV (the wizard uses them for the mapping step), `sampleTitles` from the effective mapping (`mapping ?? suggest`).
   **Wizard flow:** create the importer with `mapping: null` → `preview` → show mapping UI (05.21) → create a new importer with the chosen mapping → `preview` again → run.
3. Source: every entry with extension `csv` (also `tsv`, delimiter auto-detected). Several CSVs → each gets its own folder `<csv stem>/` (via `safeFileName`); a single CSV also gets its folder. Text via `decodeText` (BOM stripped; a Latin-1 fallback adds a warning). A header name in the mapping that does not exist in a file → warning `<file>: column "<name>" not found, using the suggested mapping` and that CSV uses `suggest`.
4. **Row → note:**
   - Title = the title cell trimmed; empty → `Row <n>` (n = 1-based row number in the file).
   - Body = the body cell with newlines normalised (not escaped); empty → empty.
   - Properties: every other non-skipped column, in header order, empty cells skipped. Column kind = `kinds[header]` if set and not `auto`, else `inferColumn(header, values, notionDates: false)` (05.9) — no `relation` kind (a relation-looking column is `text`). For `list` columns the cell is split by `listSeparator` (or by `, `) and trimmed. A header equal to `tags` (case-insensitive) is always `list`, key `tags`, items through `cleanTag`.
   - Conversion by kind: `number` int/double, `checkbox` bool (`yes/true/1` → true; `no/false/0` → false), `date` normalised to `YYYY-MM-DD`, `datetime` to `YYYY-MM-DDTHH:mm:ss`; a cell that fails the kind's parser keeps its text and adds one warning per column `<file>: column "<name>": <n> values could not be converted`.
   - Frontmatter via `FrontmatterBuilder`; body after one blank line.
5. `createBase: true` → also write `<folder>.base` next to the folder (`NoteWriter.reserve('', stem, extension: 'base')`, content `buildBaseFile(folderPath: <vault path of the folder>, propertyKeys: [...])` from 05.9).
6. Reserve all row notes of a CSV before writing; `ImportItemDone` per row. Very large CSVs (> 50,000 rows): preview adds the warning `Large file: this may take several minutes`.

**Fixture** `test/fixtures/csv/input/contacts.csv` (UTF-8 **with BOM**, `;`-free comma file, CRLF line endings):
```
Name,Company,Notes,Age,Active,Joined,Tags
Ada Lovelace,Analytical Engines,"First programmer.
Wrote the first ""algorithm"".",36,yes,2026-01-05,"math, computing"
Alan Turing,Bletchley,Cryptanalyst,41,no,2026-02-10,computing
,Nowhere,,,,,
```
`mapping`: `titleColumn: 'Name'`, `bodyColumn: 'Notes'`, `createBase: true`. Expected under `Import/contacts/`: `Ada Lovelace.md`:
```
---
Company: Analytical Engines
Age: 36
Active: true
Joined: 2026-01-05
tags:
  - math
  - computing
---

First programmer.
Wrote the first "algorithm".
```
`Alan Turing.md` (Active false, tags `computing`, body `Cryptanalyst`), `Row 3.md` (frontmatter `Company: Nowhere`, empty body), `Import/contacts.base` listing `file.name`, `note.Company`, `note.Age`, `note.Active`, `note.Joined`, `note.tags`.
A second fixture file `semicolon.csv` (`a;b` header, delimiter detected) is used by a unit test only.

**Tests.** `snapshot with mapping`, `suggest picks title and body`, `skip columns`, `kind override` (force `Age` to text), `bad number warns once per column`, `multiline quoted cell`, `empty title becomes Row n`, `missing mapped column falls back`, `two csv files two folders`, `tsv detected`, `preview returns columns`, `mapping json round trip`.

**Verify.** `cd packages/tephra_io; dart test test/importers/csv_importer_test.dart; cd ../..`

**Pitfalls.** Excel on Windows writes `;` delimiters and Windows-1252 text in some locales: the Latin-1 fallback and delimiter detection exist for that. Never treat the first CSV column as the title unless it is the mapping's choice or the suggestion.

---

### 05.16 — Exporters I: zip, encrypted `.tephra-backup`, and the restore importer

**Decision (do not revisit).** Plain export → standard `.zip` (Deflate, UTF-8 names, readable by Windows Explorer, Android and every unzip tool). **Encrypted export → our own container `.tephra-backup`** (header + AES-256-GCM chunks, key from Argon2id, both from the `cryptography` package), because `archive` cannot write AES-encrypted zips (its zip password support is the weak legacy ZipCrypto, which we refuse to offer).
`.tephra-backup` can be opened only by Tephra (restore importer below). The export dialog says so in plain words.

**Purpose.** Vault/folder/notes → zip; encrypted backup; restore importer; plus the shared export plumbing used by all exporters in 05.16–05.19.

**Files.**
- `packages/tephra_io/lib/src/exporters/export_collect.dart` (new; shared file collection and naming)
- `packages/tephra_io/lib/src/exporters/zip_exporter.dart`
- `packages/tephra_io/lib/src/exporters/backup_format.dart`
- `packages/tephra_io/lib/src/exporters/backup_exporter.dart`
- `packages/tephra_io/lib/src/importers/tephra_backup_importer.dart`
- `packages/tephra_io/lib/src/api/export_sink.dart` (finish `DirectoryExportSink`, `MemoryExportSink` if not complete)
- tests: `test/exporters/export_collect_test.dart`, `zip_exporter_test.dart`, `backup_format_test.dart`, `backup_exporter_test.dart`, `test/importers/tephra_backup_importer_test.dart`

**Implementation.**
1. **Collection** (`export_collect.dart`):
   ```dart
   final class ExportFile { const ExportFile(this.vaultPath, this.outPath); final VaultPath vaultPath; final String outPath; }   // outPath: '/'-separated, relative to the export root
   Future<List<ExportFile>> collectExportFiles(ExportRequest req);      // all files (not folders), notes and attachments, sorted by outPath (ordinal)
   String exportBaseName(ExportRequest req);                            // see rules
   ```
   Rules: each path in `req.paths` is expanded — a file stays itself, a folder is expanded recursively with `fs.list(folder: p, recursive: true)`; `VaultPath.root` = the whole vault. Any file with a path segment starting with `.` or equal to `node_modules` is skipped
   (so `.obsidian/`, `.tephra/`, `.trash/`, `.git/` never leave the device). Duplicates (a file reachable twice) are kept once.
   `outPath`: when **exactly one** path was requested, `outPath` = vault path relative to that path's **parent** (a single note → just its file name; a single folder `Projects` → `Projects/...`; the root → vault-relative paths); with several requested paths, `outPath` = the vault-relative path.
   `exportBaseName`: one path → its `stem` (a folder → its name; the root → `Vault`); several → `Tephra export`. File names written by exporters: `<base> <YYYY-MM-DD>.<ext>` (date from `req.clock`), name passed through `safeFileName` (extension excluded).
   An empty collection → `ExportFailedException('Nothing to export')` (define `final class ExportFailedException extends TephraException` in `api/exporter.dart`).
2. **ZipExporter** (`ZipExporter()`, id `zip`, label "Zip archive", extension `zip`):
   - `Archive()`; for each `ExportFile` (progress after each): `ArchiveFile(name, size, bytes)`, with the modified time from `fs.stat` (`ArchiveFile.lastModTime` / `mtime` seconds — check the archive 4 field name), Deflate for files > 64 bytes except already-compressed extensions
     (`png jpg jpeg gif webp zip mp3 m4a mp4 mov webm pdf docx xlsx`) which are **stored** (compression level 0). Names are UTF-8; verify the language-encoding flag (general-purpose bit 11, `0x0800`) is set for non-ASCII names in the output
     (test below); if `archive` does not set it, set it by patching the local header and central-directory flags after encoding (bytes 6–7 of each local header, bytes 8–9 of each central header) — implement only if the test fails.
   - Output `ZipEncoder().encode(archive)` (check the 4.x API: it may return `List<int>?`) → `sink.writeFile('<base> <date>.zip', bytes)`. Memory note: the whole zip is in memory; above **300 MiB** total input call `req.onWarning('Large export: it may use a lot of memory')`; above **1.5 GiB** throw `ExportFailedException('Too large to export as one file; export folders separately')`.
   - `options` → `{}`. Wire into `IoRegistry.createExporter`.
3. **Backup format** (`backup_format.dart`, frozen — version 1):
   ```
   offset  size  field
   0       4     magic 'TPHB' (0x54 0x50 0x48 0x42)
   4       1     formatVersion = 1
   5       1     flags = 0x01 (bit 0: payload is encrypted; other bits must be 0)
   6       4     headerLength (uint32, big-endian)
   10      N     header JSON, UTF-8 (N = headerLength, ≤ 65536)
   10+N    …     chunk records until end of file
   chunk record: uint32 BE sealedLength | nonce (12 bytes) | ciphertext (sealedLength − 28 bytes) | GCM tag (16 bytes)
   ```
   Header JSON: `{"app":"tephra","format":"tephra-backup","version":1,"createdAt":"<ISO UTC>","vaultName":"<string>","fileCount":<int>,"totalBytes":<int>,"chunkSize":1048576,"cipher":"aes-256-gcm","kdf":{"alg":"argon2id","version":19,"memoryKiB":65536,"iterations":3,"parallelism":1,"salt":"<base64 16 bytes>"}}`.
   The payload (plaintext) is a standard zip made exactly like `ZipExporter` (same collection rules) plus a first entry `manifest.json` = `{"format":"tephra-backup","version":1,"createdAt":…,"files":[{"path":…,"size":…}]}`.
   The plaintext is cut into pieces of `chunkSize` bytes (the last may be shorter, never empty unless the payload is empty — then one empty chunk). Chunk `i` is sealed with **AES-256-GCM**, key = Argon2id(password UTF-8, salt, params from the header, 32 bytes), a fresh random 12-byte nonce, and
   **AAD** = `headerBytes ‖ uint32BE(i) ‖ finalFlag` where `finalFlag` is one byte, `0x01` for the last chunk, else `0x00` (this detects reordering, truncation and header tampering). `sealedLength` = 12 + ciphertext length + 16.
   ```dart
   final class BackupKdfParams { const BackupKdfParams({this.memoryKiB = 65536, this.iterations = 3, this.parallelism = 1}); ... static const standard = BackupKdfParams(); }
   abstract final class BackupFormat {
     static Future<void> write(List<int> plaintext, {required String password, required Map<String, Object?> headerFields, BackupKdfParams kdf, Random? random, required void Function(List<int>) add});
     static Future<BackupHeader> readHeader(List<int> bytes);                      // validates magic/version/flags/length, parses JSON
     static Future<List<int>> decrypt(List<int> bytes, {required String password});  // returns the zip bytes; throws CryptoException
   }
   ```
   Validation on read: magic ≠ `TPHB` → `CryptoException('Not a Tephra backup file')`; version > 1 → `CryptoException('This backup was created by a newer version of Tephra')`; bits other than bit 0 set, `headerLength` > 65536,
   `memoryKiB` > 262144, `iterations` > 10, `parallelism` > 4 or < 1, salt not 16 bytes → `CryptoException('Unsupported or damaged backup')`. An AES-GCM authentication failure → `CryptoException('Wrong password or damaged backup')` (the two cannot be told apart; say so).
   Use `Argon2id(memory: memoryKiB, parallelism:, iterations:, hashLength: 32)`, `AesGcm.with256bits()` — same classes Phase 3 uses (`phase-03-sync-drive.md` §crypto); `tephra_io` may not import `tephra_sync`, so it depends on `cryptography` directly (same version as Phase 3). `Random.secure()` default; tests inject a seeded `Random`.
   Never log the password or the key. The password is passed in memory only (an `ExportJob` option; never written to disk or `PROGRESS.md`).
4. **BackupExporter** (`BackupExporter({required String password, BackupKdfParams kdf = BackupKdfParams.standard, Random? random})`, id `tephra-backup`, label "Encrypted backup", extension `tephra-backup`): empty password → `CryptoException('A password is required')`;
   password shorter than 8 characters → `ExportFailedException('Use at least 8 characters')` (UI enforces the same). Steps: collect files, build the zip plaintext as above (report progress while reading files; progress for the encryption phase is one step per chunk), derive the key **once**, seal chunks, write `<base> <date>.tephra-backup`.
   `options` → `{"password": "...", "memoryKiB": …, "iterations": …, "parallelism": …}`. Wire into `IoRegistry`. `vaultName` = `exportBaseName(req)`.
5. **TephraBackupImporter** (`TephraBackupImporter({required String password, ConflictPolicy policy = ConflictPolicy.keepBoth, Clock clock = const SystemClock()})`, id `tephra-backup`, label "Tephra backup (.tephra-backup)"):
   - Source: a single entry with extension `tephra-backup` (else `ImportFailedException('Choose a .tephra-backup file')`).
   - `preview`: `readHeader`, then verify the password by decrypting **only chunk 0** (add a helper `BackupFormat.verifyPassword`) → wrong password throws `CryptoException`; returns `ImportPreview(notes: fileCount, attachments: 0, warnings: ['Created <createdAt>'], sampleTitles: [vaultName])`
     (the preview does not know the note/attachment split; the `.md` count is computed after decryption in `run`).
   - `run`: `BackupFormat.decrypt` → zip bytes → a `MemoryImportSource` of the zip entries (zip-slip rules of 05.1; `manifest.json` is excluded) → delegate to `ObsidianImporter(policy: policy)` (byte-for-byte copy, conflicts handled by the policy) and forward its progress, replacing the final report's counts with its counts.
     Default target folder = the vault root (like the Obsidian importer; the wizard may choose a subfolder).
   - `options` → `{"password": "...", "policy": "keepBoth|skip|overwrite"}`. Wire into `IoRegistry`.

**Tests.**
- `export_collect_test.dart` (use `MemoryVaultFileSystem` filled with the export fixture vault of 05.17 or a small inline vault): `single note outPath`, `single folder prefix`, `root`, `several paths use vault paths`, `hidden and node_modules skipped`, `duplicates once`, `empty throws`, `base name rules`.
- `zip_exporter_test.dart`: `round trip` (export then decode with `ZipDecoder`; names and bytes equal), `unicode names` (Bangla file name; check bit 0x0800 in the local header bytes), `png stored, md deflated` (compare `compressionType`/sizes), `progress reported`, `empty vault throws`.
- `backup_format_test.dart` (use `BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1)` for speed): `round trip small`, `round trip 2.5 MiB multi-chunk` (3 chunks; deterministic `Random(1)` payload), `wrong password`, `flipped byte in ciphertext`, `flipped byte in header`, `truncated file` (last chunk removed), `chunks swapped`, `bad magic`, `newer version`, `excessive kdf params rejected`, `header length too large`, `empty payload`.
- `backup_exporter_test.dart`: `exports a vault and restores into another memory vault byte-identically`, `password too short`, `output name` (`<base> 2026-10-11.tephra-backup` with a `FixedClock`), `password not in header` (search the header bytes for the password).
- `tephra_backup_importer_test.dart`: `restore into root`, `restore into subfolder`, `keepBoth conflict`, `wrong password in preview`, `not a backup file`.

**Verify.**
```powershell
cd packages/tephra_io; dart test test/exporters test/importers/tephra_backup_importer_test.dart; cd ../..
```

**Pitfalls.** Argon2id in pure Dart takes seconds at 64 MiB; it already runs inside the export/import isolate (05.5) but the UI must show a "Protecting…" spinner. Never reuse a nonce: generate a fresh one per chunk. Do not put `.tephra/` in backups (settings are not part of a backup; the hand-off lists this).

---

### 05.17 — Exporters II: shared export context, portable Markdown, self-contained HTML

**Purpose.** Resolve links and embeds for all text exporters once, then write the two text exporters (portable Markdown and HTML). PDF and DOCX reuse the same context in 05.18–05.19.

**Files.**
- `packages/tephra_io/lib/src/exporters/export_context.dart` (new)
- `packages/tephra_io/lib/src/exporters/edit_list.dart` (new)
- `packages/tephra_io/lib/src/exporters/markdown_exporter.dart`
- `packages/tephra_io/lib/src/exporters/html_exporter.dart`
- `packages/tephra_io/lib/src/exporters/html_template.dart`
- `packages/tephra_io/lib/src/exporters/html_render.dart` (new; AST → HTML string)
- tests: `test/exporters/export_context_test.dart`, `markdown_exporter_test.dart`, `html_exporter_test.dart`, `test/exporters/edit_list_test.dart`
- fixture vault `packages/tephra_io/test/fixtures/export/vault/` (below) and loader `test/support/export_vault.dart` (`MemoryVaultFileSystem exportVault()`: loads every file of that folder; `binaries.json` convention as in 05.1)

**The export fixture vault** (used by 05.16–05.19; create exactly):
- `Syntax test.md`:
  ````markdown
  ---
  title: Syntax test
  tags: [export, demo]
  aliases: [Syntax]
  status: draft
  ---
  # Heading 1
  ## Heading 2
  ### Heading 3
  #### Heading 4
  ##### Heading 5
  ###### Heading 6

  A paragraph with **bold**, *italic*, ~~strike~~, ==highlight==, `inline code`, a [web link](https://example.com), a [[Linked note]], an alias [[Linked note|the alias]], a section link [[Linked note#Section A]], a same-note link [[#Heading 2]], a #tag and a footnote.[^1] %%hidden comment%%

  - bullet one
    - nested bullet
      - third level
  - bullet two

  3. ordered three
  4. ordered four
     1. nested ordered

  - [ ] open task
  - [x] done task
  - [/] in progress task

  | Left | Center | Right |
  |:-----|:------:|------:|
  | a    | b      | c     |
  | 1    | 2      | 3     |

  ```python
  def hello():
      print("hi")
  ```

  > A quote
  > > nested quote

  > [!warning] Careful
  > Callout body with a [[Linked note]].

  > [!note]- Folded callout
  > Hidden by default.

  Inline math $E = mc^2$ and block math:

  $$
  \int_0^1 x^2 dx = \tfrac{1}{3}
  $$

  ---

  Embedded note:

  ![[Embedded note]]

  Embedded section: ![[Linked note#Section B]]

  Embedded block: ![[Linked note#^blk1]]

  Image: ![[images/pic.png|100]]

  Cycle: ![[Cycle A]]

  Missing: ![[No such note]]

  Bengali: বাংলা ভাষায় একটি বাক্য।

  A block with an id. ^para1

  [^1]: The footnote text.
  ````
- `Linked note.md`: `# Linked note`, blank, `Intro of the linked note.`, blank, `## Section A`, blank, `A text.`, blank, `## Section B`, blank, `B text. ^blk1`, blank, `More B text.`
- `Embedded note.md`: frontmatter `tags: [embedded]` then `Embedded body line. ![[Embedded child]]`
- `Embedded child.md`: `Child text.`
- `Cycle A.md`: `A ![[Cycle B]]`; `Cycle B.md`: `B ![[Cycle A]]`
- `Sub/Nested.md`: `Back to [[Syntax test]] and [[Linked note]].`
- `images/pic.png` (tinyPng; `binaries.json` at the vault folder root lists it)
- `.obsidian/app.json` (`{}`; must never be exported)

**Implementation.**
1. **`EditList`** (`edit_list.dart`): collects non-overlapping text edits and applies them. API: `void replace(int start, int end, String text)`, `void insert(int offset, String text)`, `String apply(String source)`.
   `apply` sorts by `start` descending (ties: insertions before replacements ending at the same offset), asserts that no two edits overlap (throws `StateError` — a programmer error caught by tests), and splices. Used by the Markdown exporter and by anything that edits note text by offsets.
2. **`ExportContext`** (`export_context.dart`), one per export run:
   ```dart
   final class ExportContext {
     ExportContext(this.req);
     final ExportRequest req;
     Future<ParsedNote?> parse(VaultPath path);                 // readText → MarkdownParser.parse, cached by path; null (+ warning) when unreadable
     Future<VaultPath?> resolve(String target, {required VaultPath from});  // req.resolver, cached by (target, from)
     Future<List<int>?> readBytes(VaultPath p);                 // cached for files < 1 MiB
     Future<ResolvedEmbed> resolveEmbed(MdWikiLink link, {required VaultPath from, required int depth, required Set<VaultPath> stack});
     void warn(String message);                                 // forwards to req.onWarning, de-duplicates identical messages
     static const int maxEmbedDepth = 5;
   }
   sealed class ResolvedEmbed { const ResolvedEmbed(); }
   final class NoteEmbed extends ResolvedEmbed { final VaultPath path; final String text; final ParsedNote parsed; final String displayName; }   // text = the embedded fragment (no frontmatter); parsed = MarkdownParser.parse(text)
   final class ImageEmbed extends ResolvedEmbed { final VaultPath path; final List<int> bytes; final int? width; final int? height; }              // width/height from the |300x200 size, not the pixels
   final class FileEmbed extends ResolvedEmbed { final VaultPath path; }                                                                              // pdf/audio/video/other attachments
   final class MissingEmbed extends ResolvedEmbed { final String target; }
   final class EmbedLimit extends ResolvedEmbed { final VaultPath path; final bool cycle; }                                                           // depth > 5 or the path is already in [stack]
   ```
   `resolveEmbed` rules: `resolve(link.target, from: from)`; null → `MissingEmbed` + `warn('<from>: embed target "<target>" not found')`. Path in `stack` → `EmbedLimit(cycle: true)` + `warn('<from>: embed cycle at <path>')`; `depth >= maxEmbedDepth` →
   `EmbedLimit(cycle: false)` + `warn('<from>: embeds nested deeper than 5 levels, linked instead')`. Extension in `png jpg jpeg gif webp bmp svg` → `ImageEmbed` (size from `link.size`); `md` → note fragment:
   no heading/block → the whole text after the frontmatter (`MdFrontmatter.contentStart`, or 0); `heading` → from the matching heading (case-insensitive, first match) to the next heading of the same or a higher level (smaller or equal number), or the end; a missing heading → `MissingEmbed` + warning;
   `blockRef` → the smallest `MdListItem` or top-level block (direct child of `MdDocument` or `MdBlockQuote`) that contains the `MdBlockId` with that id, source range text, with the trailing ` ^id` removed; not found → `MissingEmbed` + warning. Any other extension → `FileEmbed`.
   `displayName` = file stem. The fragment text is trimmed of leading/trailing blank lines.
3. **Markdown exporter** (`MarkdownExporter({bool keepFrontmatter = true})`, id `markdown`, label "Portable Markdown", `fileExtension` `'zip'`; the produced file names are authoritative, the UI uses them):
   Per exported note `N` (`outPath` from `collectExportFiles`) run `portableMarkdown(text, from: N.vaultPath, outDir: dirname(N.outPath), ctx, depth: 0, stack: {N})` which parses with `MarkdownParser.parse` and builds an `EditList` (edits are offsets into `text`):
   1. **Wikilinks (non-embed)** `[[T#H|A]]` → `[display](url#slug)`: `display` = alias, else `stem(T)` + (` > H` when a heading is given). `resolve` → `VaultPath p`; `url` = relative path from `outDir` to the **output path of p** (same `outPath` rule: p must be among the exported files; if p exists in the vault but is not exported,
      include it as an extra output file only when `includeLinkedNotes` is true — **not implemented in v1**; instead produce plain text `display` and the warning `<from>: link to <p> points outside the export, left as text`), each segment `Uri.encodeComponent` plus `(`→`%28`, `)`→`%29` (so `Linked note.md` → `Linked%20note.md`);
      `slug(H)` = lower-case, spaces → `-`, remove every character that is not a letter, digit, `-` or `_`; a block ref `#^id` → no fragment. `[[#Heading]]` → `[Heading](#slug)`. Unresolved → plain `display` text + warning `<from>: unresolved link [[T]]`.
   2. **Embeds** `![[…]]` via `resolveEmbed(link, from, depth, stack)`: `NoteEmbed` → replace the embed with `\n\n` + `portableMarkdown(embed.text, from: embed.path, outDir: <outer outDir>, depth: depth + 1, stack: stack ∪ {embed.path})` + `\n\n`, then collapse the surrounding blank lines
      (so an embed on its own line stays its own block); `ImageEmbed` → `![](<url>)` (size dropped), the image file is added to the output set; `FileEmbed` → `[<file name>](<url>)` + output; `MissingEmbed` → `*[missing: <target>]*`; `EmbedLimit` → a normal link `[<name>](<url>)` (or plain text when not exported).
      `![](relative.png)` standard images and `[](file.pdf)` links with relative URLs also add those files to the output set when they resolve inside the vault (URL decoded first).
   3. **Obsidian-only syntax:** `MdHighlight` → replace its two `==` delimiters with `<mark>` / `</mark>` (two small edits); `MdCommentInline`/`MdCommentBlock` → removed (plus one following newline for block comments); `MdBlockId` → removed together with the single space before it;
      `MdCallout` → the marker `[!type]±` plus one following space is replaced by `**<Title or Capitalised type>**` when no title was given, or by `**` when a title follows and a closing `**` is **inserted** at the end of the first line (`> **Careful**`); the `+`/`-` fold marks disappear.
   4. Everything else (tags, math, footnotes, tables, code) is unchanged. Frontmatter is kept unless `keepFrontmatter` is false (then removed with the blank line after it).
   Output: all converted notes + attachments (copied unchanged) at their `outPath` in a **zip** `<base> <date>.zip` (via the same zip builder as `ZipExporter`; refactor a shared `buildZip(Map<String, List<int>>)`) — except when the export has exactly one note and no attachments: then the single file `<note stem> <date>.md` is written (no zip).
   Warnings for dropped features are not needed (comments/ids are silent); `options` → `{"keepFrontmatter": bool}`. Wire into `IoRegistry`.
4. **HTML exporter** (`HtmlExporter({bool includeProperties = false, int maxInlineBytes = 5242880})`, id `html`, label "HTML (self-contained)", `fileExtension` `'html'`; multi-note output is a zip, as for Markdown: one note → `<stem> <date>.html`; several → a zip with one `.html` per note at its `outPath` (extension `.html`) and an `index.html` listing every note as a link):
   - `html_render.dart`: `Future<String> renderBody(ParsedNote note, VaultPath from, ExportContext ctx, HtmlOutputPaths paths, int depth, Set<VaultPath> stack)`; `html_template.dart`: `String wrapPage({required String title, required String body, String? propertiesHtml})` = `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" ...><title>…</title><style>…</style></head><body><article class="note">…</article></body></html>`
     with one inline stylesheet (system font stack plus `"Noto Sans Bengali"`, max-width 46rem, tables bordered, `pre` scroll, callouts coloured by type, `prefers-color-scheme: dark` variant). **No scripts, no external requests.**
   - **Node → HTML mapping** (all text escaped with `&amp; &lt; &gt; &quot;`):
     | Node | HTML |
     |---|---|
     | `MdHeading(level)` | `<hN id="slug">…</hN>` (ids de-duplicated with `-1`, `-2`) |
     | `MdParagraph` | `<p>…</p>` |
     | `MdBlockQuote` | `<blockquote>…</blockquote>` |
     | `MdCallout(type,title,fold)` | `fold == none`: `<div class="callout callout-<type>"><div class="callout-title">Title</div><div class="callout-body">…</div></div>`; folded: `<details class="callout callout-<type>" [open]><summary>Title</summary>…</details>` (`expanded` → `open`); title default = capitalised type |
     | `MdList` / `MdListItem` | `<ul>`/`<ol start="n">` / `<li>`; tight lists render items' paragraphs without `<p>`; a task item: `<li class="task"><input type="checkbox" disabled [checked]> …</li>`; status chars other than space → `checked` for `x`/`X`, `data-status="<char>"` for others |
     | `MdCodeBlock` | `<pre><code class="language-x">…</code></pre>` (escaped; no highlighting) |
     | `MdMathBlock` | `<div class="math">TEX</div>` (source shown; no JavaScript) |
     | `MdTable` | `<table><thead>…</thead><tbody>…</tbody></table>`, `style="text-align:…"` per column |
     | `MdThematicBreak` | `<hr>` |
     | `MdHtmlBlock` / `MdHtmlInline` | the HTML **text only** (tags stripped with `package:html`), never raw HTML (no script can run) |
     | `MdFootnoteRef` / definitions | `<sup><a href="#fn-label" id="fnref-label">n</a></sup>`; definitions collected into `<section class="footnotes"><ol>…</ol></section>` at the end |
     | `MdCommentBlock` / `MdCommentInline` / `MdBlockId` | nothing |
     | `MdText`, `MdSoftBreak` (→ `<br>` ), `MdHardBreak` (`<br>`) | text / line break |
     | `MdEmphasis`, `MdStrong`, `MdStrikethrough`, `MdHighlight`, `MdInlineCode` | `<em>`, `<strong>`, `<del>`, `<mark>`, `<code>` |
     | `MdInlineMath` | `<span class="math">TEX</span>` |
     | `MdLink` | `<a href="url">` (URL `javascript:` → text only); images with a relative URL → inlined (below) |
     | `MdAutolink` | `<a href="url">url</a>` |
     | `MdTag` | `<span class="tag">#name</span>` |
     | `MdWikiLink` (non-embed) | resolved & exported → `<a href="<relative .html path>#slug">display</a>` (single-note export: the note is not in the file, so links to other notes become `<span class="unlinked">display</span>`); unresolved → `<span class="unresolved">display</span>` + warning |
     | `MdWikiLink` embed | `NoteEmbed` → `<div class="embed"><div class="embed-title">name</div>…rendered fragment…</div>` (depth ≤ 5); `ImageEmbed` → `<img src="data:<mime>;base64,…" alt="name" [width] [height]>`; `FileEmbed`/over `maxInlineBytes` images → `<span class="unlinked">name</span>` + warning `<from>: <name> is too large to inline`; `MissingEmbed` → `<span class="unresolved">missing: target</span>`; `EmbedLimit` → link/text |
     | `MdFrontmatter` | nothing in the body; with `includeProperties` a `<table class="properties">` of the YAML map (list values joined by `, `) before the body |
     Image mime by extension (`png image/png`, `jpg/jpeg image/jpeg`, `gif`, `webp`, `bmp image/bmp`, `svg image/svg+xml`).
   - `options` → `{"includeProperties": bool, "maxInlineBytes": int}`. Wire into `IoRegistry`.

**Tests.**
- `edit_list_test.dart`: `replace and insert`, `descending application keeps offsets`, `insertion before replacement at same offset`, `overlap throws`.
- `export_context_test.dart`: `whole note embed strips frontmatter`, `heading section stops at same level`, `heading section includes deeper headings`, `block embed finds list item or paragraph and strips id`, `cycle detected`, `depth 5 limit` (build a chain of 7 notes), `missing target warns once`, `image size from link`, `file embed for pdf`.
- `markdown_exporter_test.dart` (input = the fixture vault, export `Syntax test.md` alone and compare with `expected/markdown/Syntax test.md` — a snapshot, plus explicit asserts):
  `wikilink becomes relative link` (`[Linked note](Linked%20note.md)` — the linked notes are not exported when exporting one note, so expect plain text `Linked note` and the warning; **also** a test that exports the whole vault root where the same text becomes `[Linked note](Linked%20note.md)` and `Sub/Nested.md` links `[Syntax test](../Syntax%20test.md)`),
  `alias and heading display` (`[the alias](...)`, `[Linked note > Section A](Linked%20note.md#section-a)`), `same-note heading link` (`[Heading 2](#heading-2)`), `embed inlined recursively` (`Embedded body line. Child text.`), `section and block embeds`, `cycle becomes link and warns`, `missing embed marker`,
  `image embed becomes markdown image and file is exported` (`![](images/pic.png)` and the zip contains `images/pic.png`), `highlight to mark`, `comment removed`, `block id removed`, `callout header` (`> **Careful**`, `> **Folded callout**`), `frontmatter kept / removed`, `unchanged text identical` (a paragraph without special syntax is byte-identical), `no .obsidian in zip`, `single note without attachments writes a .md`.
  Snapshot discipline of 05.1 applies: open and review the expected file.
- `html_exporter_test.dart`: `snapshot of Syntax test` (compare with `expected/html/Syntax test.html` whose **images are the real base64**), `no script tags and no external urls` (assert no `<script`, no `src="http`, no `href="http` except `https://example.com`), `escaping` (a note with `<script>alert(1)</script>` in text and in an HTML block → shown as text), `img data uri decodes to tinyPng`,
  `callout fold uses details`, `task list checkboxes`, `table alignment styles`, `properties table optional`, `bengali text kept`, `multi-note export has index.html and relative links`, `large image not inlined`, `heading ids unique`.

**Verify.** `cd packages/tephra_io; dart test test/exporters; cd ../..`

**Pitfalls.** All edits are offsets into the **original** text; never apply an edit and re-parse in the middle of one pass. Percent-encoding must use `Uri.encodeComponent` per segment, never on the whole path (it would encode `/`). Escape everything that comes from notes in HTML; never emit raw user HTML.

---

### 05.18 — Exporter III: PDF (from our AST, bundled fonts)

**Purpose.** Note(s) → PDF with the `pdf` package (Apache-2.0), rendering the same AST the reading view uses (not screenshots).

**Files.**
- `packages/tephra_io/lib/src/exporters/pdf_exporter.dart`
- `packages/tephra_io/lib/src/exporters/pdf_fonts.dart`
- `packages/tephra_io/lib/src/exporters/pdf_render.dart` (new; AST → widgets)
- `packages/tephra_io/lib/src/exporters/export_properties.dart` (new; shared: frontmatter map → ordered `List<(String key, String value)>`; list values joined with `, `, bool/num/date as text; used by 05.18 and 05.19)
- `app/assets/fonts/` (new): `NotoSans-Regular.ttf`, `NotoSans-Bold.ttf`, `NotoSans-Italic.ttf`, `NotoSans-BoldItalic.ttf`, `NotoSansMono-Regular.ttf`, `NotoSansMono-Bold.ttf`, `NotoSansBengali-Regular.ttf`, `NotoSansBengali-Bold.ttf`, `OFL.txt`, `README.md` (source URL and date of each file)
- `app/pubspec.yaml` (declare the eight font files under `flutter: assets:` — plain assets, **not** a `fonts:` section)
- `tool/check_licenses.dart` (extend; item 8)
- tests: `test/exporters/pdf_exporter_test.dart`, `test/exporters/pdf_fonts_test.dart`, `test/support/repo_root.dart`

**Implementation.**
1. **Fonts.** Download the eight **static TrueType** files from the official Noto repository (`https://github.com/notofonts/notofonts.github.io`, folders `fonts/NotoSans/…`, `fonts/NotoSansMono/…`, `fonts/NotoSansBengali/…`; also available via `https://fonts.google.com/noto`). Requirements: static (not variable) `.ttf`
   (the file starts with bytes `00 01 00 00`), the exact file names above (rename if needed), and the OFL text copied to `OFL.txt`. If the machine cannot download them, stop and tell the human (GEMINI.md §5). Record sizes and source URLs in `app/assets/fonts/README.md`.
   `pdf` cannot use CFF-flavoured `.otf` or variable fonts.
2. **`PdfFontSet`** (`pdf_fonts.dart`, exported):
   ```dart
   final class PdfFontSet {
     const PdfFontSet({required this.regular, required this.bold, required this.italic, required this.boldItalic, required this.mono, required this.monoBold, required this.bengali, required this.bengaliBold});   // Uint8List fields
     static Future<PdfFontSet> fromDirectory(String directory);   // reads the eight file names above; a missing file → ExportFailedException('Font file missing: <name>')
   }
   ```
   `ExportJob` options carry only the **directory path** (isolates cannot share loaded assets): the app copies the assets to `<appSupportDir>/fonts/` (05.20) and passes that path in `options['fontDirectory']`.
3. **`PdfExporter`** (id `pdf`, label "PDF", extension `pdf`):
   ```dart
   // Defined in packages/tephra_io/lib/src/api/export_request.dart (exported; shared with the DOCX exporter in 05.19):
   enum PdfPageSize { a4, letter }
   final class PdfExporter implements Exporter {
     PdfExporter({required this.fontDirectory, this.pageSize = PdfPageSize.a4, this.marginMm = 20, this.showTitle = true, this.header = true, this.footer = true,
       this.pageNumbers = true, this.includeProperties = false, this.baseFontSize = 11, this.compress = true, this.onTextRun});
     final void Function(String text)? onTextRun;   // test hook: called with every string drawn
   }
   ```
   `marginMm` is clamped to 10–40. `options` → all fields except `onTextRun`. Wire into `IoRegistry` (`fontDirectory` is required: missing → `ArgumentError`).
4. **Document:** `pw.Document(compress: compress)` with theme `pw.ThemeData.withFont(base: regular, bold: bold, italic: italic, boldItalic: boldItalic, fontFallback: [bengali, bengaliBold])`. Bold text needs the bold Bengali face: in `TextStyle` for bold runs set `fontFallback: [bengaliBold]`
   (check the `pdf` README for `fontFallback` on `TextStyle`/`ThemeData`; if the API differs, adapt and note it). Notes are rendered in **path order** (as collected by `collectExportFiles`, `.md` files only; other files ignored). Each note is one `pw.MultiPage(pageFormat: A4 or letter with margins, maxPages: 10000, header:, footer:, build:)`
   (`maxPages` default is 20 — always override). Multiple notes → one PDF, each note starting on a new page; file name `<base> <date>.pdf`.
   Header (when `header`): left = note title (stem), right = export date `YYYY-MM-DD`, small grey text, thin line below. Footer (when `footer` or `pageNumbers`): centre `Page <context.pageNumber> of <context.pagesCount>` when `pageNumbers`. Title (when `showTitle`): the stem as a 24 pt bold heading at the top (`pw.Header(level: 0)`), followed by the properties table when `includeProperties`.
5. **Node → widget mapping** (`pdf_render.dart`; sizes relative to `baseFontSize` = `b`):
   | Node | Widgets |
   |---|---|
   | `MdHeading(n)` | `pw.Header(level: n-1, child: pw.Text(…, style: bold, fontSize: b × [1.8, 1.5, 1.3, 1.15, 1.05, 1.0][n-1]))` with spacing 12 before / 6 after (creates PDF outline entries) |
   | `MdParagraph` | `pw.RichText(text: pw.TextSpan(children: inlineSpans))` + 6 pt spacing |
   | `MdBlockQuote` | each child block wrapped in `pw.Container(padding: left 10, decoration: left border 2 pt grey)` (one container **per child**, never one wrapper, so long quotes can break across pages); nested quotes add another 10 pt |
   | `MdCallout` | like a quote but the left border colour by type (`note` blue, `info` blue, `tip` green, `success` green, `warning` orange, `danger`/`error`/`bug` red, `question` purple, others grey), light background tint, title in bold as the first child; `fold` ignored (content always shown) |
   | `MdList`, `MdListItem` | per item `pw.Row(crossAxisAlignment: start, children: [pw.SizedBox(width: 16 × (depth+1)… marker), pw.Expanded(child: pw.Column(children: item blocks))])`; marker: bullets `•` (levels 0 and 2) / `–` (level 1), ordered `n.` (start number + index), task: an 8×8 pt bordered `pw.Container` containing `x` when status is `x`/`X`, `/` for `/`, `-` for `-`, empty otherwise; nested lists indent 14 pt per level |
   | `MdCodeBlock` | split into chunks of 40 lines; each chunk `pw.Container(color: grey 100, padding 6, child: pw.Text(chunk, style: mono 9 pt))`; the language (if any) as a small grey label above the first chunk; tabs → 4 spaces |
   | `MdMathBlock`, `MdInlineMath` | monospace text of the TeX source (limitation: no typesetting) |
   | `MdTable` | `pw.Table(border: all grey 0.5, columnWidths: pw.FlexColumnWidth for every column, children: rows)`; header row bold with grey background; cell = inline spans; alignment per column (`pw.Alignment.centerLeft/center/centerRight`); cell padding 4 |
   | `MdThematicBreak` | `pw.Divider(thickness: 0.5)` |
   | `MdHtmlBlock`, `MdHtmlInline` | text extracted with `package:html` (tags dropped) as a paragraph / span |
   | `MdFootnoteDefinition` | collected; rendered at the end of the note after a divider and the small heading `Footnotes`, each as `n. text` |
   | `MdCommentBlock`, `MdCommentInline`, `MdBlockId`, `MdFrontmatter` | nothing in the body (frontmatter shown only through `includeProperties`, as a two-column table `key`/`value` with grey header) |
   | `MdText` | `pw.TextSpan(text)` |
   | `MdEmphasis`, `MdStrong`, `MdStrikethrough` | `italic`, `bold`, `decoration: pw.TextDecoration.lineThrough` |
   | `MdHighlight` | yellow background if `TextStyle` supports a background in the installed `pdf` version, else bold (record which in `PROGRESS.md`) |
   | `MdInlineCode` | mono font, 0.9 × size, grey 200 background if supported |
   | `MdLink`, `MdAutolink` | blue + underline, wrapped in `pw.UrlLink(destination: url)` via `pw.WidgetSpan`; relative URLs → plain text |
   | `MdWikiLink` (non-embed) | target is a note in this PDF → `pw.Link(destination: 'note:<vaultPath>')` (every note's title carries `pw.Anchor(name: 'note:<vaultPath>')`); else underlined text only; display text as in 05.17 |
   | `MdTag` | text `#tag` in a dark green colour |
   | `MdFootnoteRef` | superscript: size 0.7 × and `baseline` offset of 4 pt, text `[n]` (n by order of first reference) |
   | `MdSoftBreak`, `MdHardBreak` | `\n` (Obsidian's default shows soft breaks as line breaks) |
   | embeds | `NoteEmbed` → the fragment rendered with the same functions inside a left-border container per child (depth ≤ 5, via `ExportContext`); `ImageEmbed` → `pw.Image(pw.MemoryImage(bytes), width: w, height: h, fit: contain)` scaled (below); `FileEmbed` → text `[file: <name>]`; `MissingEmbed` → italic `[missing: target]`; `EmbedLimit` → text name |
   **Images:** the usable width `W` = page width − 2 × margin. Natural size from `readImageSize` (05.3) in px → pt (`× 0.75`). Requested `|w` or `|wxh` (px) → pt. Final width = min(requested or natural, `W`); height keeps the aspect ratio and is capped at the page content height − 40; an image not decodable by `pdf`
   (`MemoryImage` accepts PNG and JPEG; for gif/webp/bmp the `pdf` package decodes through the `image` package — check the README) → on any exception write the placeholder `[image: <name>]` and the warning `<note>: image <name> could not be rendered`; SVG → `pw.SvgImage(svg: utf8 text)` with the same sizing.
6. **Text hook:** every drawn string (headings, spans, cells, headers, footers) is also passed to `onTextRun` (tests collect them). Missing glyphs (emoji, rare scripts) make the `pdf` package log a warning; add the single export warning `Some characters (for example emoji) cannot be shown in PDF` when a heuristic scan of the note text finds a code point ≥ U+1F300 (emoji planes).
   **Known limitation (documented in the wizard and hand-off):** `pdf` does no OpenType shaping, so Bengali conjuncts and some vowel signs can look wrong; the text is present and the export must never crash.
7. **Licence tool** (`tool/check_licenses.dart`): at the top add a doc comment block `Bundled fonts under app/assets/fonts are assets, not Dart packages; they are licensed under OFL-1.1, reviewed by hand, and listed in THIRD_PARTY_NOTICES.md under "Bundled fonts".`
   Add `const allowedAssetLicences = ['OFL-1.1'];` and a check that `app/assets/fonts/OFL.txt` exists and that every `*.ttf` there is named in the hard-coded `bundledFonts` list (name, source URL, licence); the tool prints the list into the generated notices file in a section `Bundled fonts`. The Dart-package allowlist is **not** changed.
8. `repo_root.dart` (test support): walks up from `Directory.current` until a `pubspec.yaml` containing `workspace:` is found; tests use `p.join(root, 'app', 'assets', 'fonts')` as `fontDirectory`.

**Tests.** (`pdf_exporter_test.dart`, all with `compress: false`, A4 unless stated)
- `valid pdf structure`: bytes start with `%PDF-`, end (after trimming whitespace) with `%%EOF`.
- `page size a4 and letter`: the first `/MediaBox` is `[0 0 595.27… 841.89…]` for A4 (match with a tolerance regex `\[0 0 595\.2\d* 841\.8\d*\]`) and `[0 0 612 792]` for Letter.
- `page count`: export a generated note of 300 paragraphs of 60 words → the count of `/Type /Page` objects (not `/Pages`) equals the `/Count` value in the page tree and is ≥ 4; a one-line note → exactly 1 page; two notes → page count ≥ 2 (new page per note).
- `margins change pagination`: the same long note with `marginMm: 40` has more pages than with `10`.
- `text presence` (via `onTextRun`): the `Syntax test.md` export contains `Heading 1`, `bold`, `Careful`, `A text.`-style strings from embeds (`Embedded body line.`, `Child text.`), `Left`/`Center`/`Right`, `def hello():`, the Bengali sentence, `The footnote text.`; and does **not** contain `hidden comment` or `^para1`.
- `properties optional`: with `includeProperties: true` runs contain `status` and `draft`; false → not.
- `fonts embedded`: the PDF text contains `/FontFile2` and a `/BaseFont` that includes `NotoSans`; the Bengali export contains `NotoSansBengali` in a `/BaseFont`.
- `outlines`: `/Type /Outlines` present for a note with headings.
- `header footer toggles`: with `footer: false, pageNumbers: false`, no run starts with `Page `.
- `image scaled`: a note embedding `images/pic.png` → no exception, a `/Subtype /Image` object present; with `|100` also fine; with a corrupt image file (bytes `abc`) → placeholder run `[image: …]` and one warning.
- `cycle and missing embeds do not crash`.
- `huge code block splits across pages` (500-line block → ≥ 2 pages, no `TooManyPagesException`).
- `pdf_fonts_test.dart`: `fromDirectory loads eight fonts`, `missing font throws ExportFailedException`.
Manual (record in `PROGRESS.md`): open the `Syntax test` PDF in a PDF viewer on Windows; headings, list nesting, table, callout, image, footnote look right; the Bengali sentence is present (may be mis-shaped).

**Verify.**
```powershell
cd packages/tephra_io; dart test test/exporters/pdf_exporter_test.dart test/exporters/pdf_fonts_test.dart; cd ../..
dart run tool/check_licenses.dart
```

**Pitfalls.** `MultiPage` throws if one widget is taller than a page: that is why code, quotes and callouts are split per child/chunk. `maxPages` default is 20. Variable fonts silently render wrong; use static files. Never read the font assets from `package:flutter` inside `tephra_io` (pure Dart).

---

### 05.19 — Exporter IV: DOCX (WordprocessingML with `archive` + `xml`)

**Purpose.** Note(s) → a `.docx` that opens in Word, LibreOffice and Google Docs, with headings, lists, tables, hyperlinks and images.

**Files.**
- `packages/tephra_io/lib/src/exporters/docx_exporter.dart`
- `packages/tephra_io/lib/src/exporters/docx_parts.dart` (static parts: content types, rels, styles, numbering, header/footer builders)
- `packages/tephra_io/lib/src/exporters/docx_render.dart` (new; AST → `w:` XML)
- tests: `test/exporters/docx_exporter_test.dart`, `test/support/docx_inspect.dart` (unzip + parse helper)

**Implementation.**
1. `DocxExporter({PdfPageSize pageSize = PdfPageSize.a4, int marginMm = 20, bool header = true, bool footer = true, bool pageNumbers = true, bool includeProperties = false, bool showTitle = true})`, id `docx`, label "Word document (.docx)", extension `docx`.
   (`PdfPageSize` is the enum defined in 05.18.) `options` → all fields. Wire into `IoRegistry`.
2. **Package parts** (all written with `ZipEncoder`; `[Content_Types].xml` is the **first** entry; every XML part starts with `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`):
   | Part | Content |
   |---|---|
   | `[Content_Types].xml` | `Default` for `rels` (`application/vnd.openxmlformats-package.relationships+xml`), `xml` (`application/xml`), `png`, `jpeg`, `jpg`, `gif`, `bmp`; `Override` for `/word/document.xml` (`application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml`), `/word/styles.xml` (`…wordprocessingml.styles+xml`), `/word/numbering.xml` (`…wordprocessingml.numbering+xml`), `/word/header1.xml` (`…wordprocessingml.header+xml`), `/word/footer1.xml` (`…wordprocessingml.footer+xml`), `/docProps/core.xml` (`application/vnd.openxmlformats-package.core-properties+xml`), `/docProps/app.xml` (`application/vnd.openxmlformats-officedocument.extended-properties+xml`) |
   | `_rels/.rels` | relationships `rId1` → `word/document.xml` (type `…/officeDocument`), `rId2` → `docProps/core.xml` (`http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties`), `rId3` → `docProps/app.xml` (`…/extended-properties`) |
   | `word/document.xml` | root `w:document` declaring `xmlns:w`, `xmlns:r`, `xmlns:wp`, `xmlns:a`, `xmlns:pic`; one `w:body`; ends with `w:sectPr` |
   | `word/styles.xml` | see item 3 |
   | `word/numbering.xml` | see item 5 |
   | `word/_rels/document.xml.rels` | `rIdStyles` → `styles.xml`, `rIdNumbering` → `numbering.xml`, `rIdHeader1` → `header1.xml`, `rIdFooter1` → `footer1.xml`, one `rIdImgN` per image → `media/imageN.<ext>`, one `rIdLinkN` per external URL (`TargetMode="External"`) |
   | `word/header1.xml`, `word/footer1.xml` | header: the export title (first note stem) right-aligned grey 9 pt; footer: centred `Page <PAGE field> of <NUMPAGES field>` using `w:fldSimple w:instr="PAGE"` / `"NUMPAGES"`; written only when the option is on (and the `sectPr` references omitted otherwise, together with their rels/overrides) |
   | `word/media/imageN.png|jpeg|gif|bmp` | the image bytes unchanged (webp/svg → placeholder text + warning `<note>: image <name> not supported in DOCX`) |
   | `docProps/core.xml` | `dc:title` (base name), `dc:creator` `Tephra`, `dcterms:created`/`modified` (`req.clock`, `W3CDTF` with `xsi:type`) |
   | `docProps/app.xml` | `Application` = `Tephra` |
   Build every XML part with `XmlBuilder` from `package:xml` (never string concatenation of user text) and `toXmlString()`; remove characters illegal in XML 1.0 from all text first: `U+0000–U+0008`, `U+000B`, `U+000C`, `U+000E–U+001F`, `U+FFFE`, `U+FFFF` (Word refuses the file otherwise).
3. **Styles** (`styles.xml`): `w:docDefaults` run default font `Calibri` (`w:rFonts w:ascii w:hAnsi="Calibri" w:cs="Nirmala UI" w:eastAsia="Calibri"`), size `22` (11 pt) and `w:szCs 22`, language `en-US` / bidi `bn-BD` (Bengali is a complex script in Word and uses the `cs` font), paragraph spacing after 120.
   Paragraph styles (id → name, based on): `Normal`; `Heading1`…`Heading6` (`Heading N`, based on Normal, next Normal, `w:outlineLvl` 0–5, bold, sizes in half-points 40, 34, 30, 26, 24, 22, spacing before 240 / after 80, `w:keepNext`); `Title` (size 52); `ListParagraph` (indent left 720); `Quote` (left indent 720, left border 12 grey, italic off);
   `Callout` (based on Quote, light grey shading `F2F2F2`); `CodeBlock` (font `Consolas`/`cs Nirmala UI`, size 19, shading `F5F5F5`, spacing 0 after, `w:contextualSpacing`); `Header`, `Footer` (size 18, grey). Character styles: `Code` (Consolas, shading `EDEDED`), `Hyperlink` (colour `0563C1`, underline single), `Tag` (colour `2E7D32`).
   Table style `TableGrid` (single borders 4 in `A6A6A6`). Style ids are exactly these strings; `document.xml` refers to them by `w:pStyle`/`w:rStyle`/`w:tblStyle`.
4. **Node → WordprocessingML mapping** (`docx_render.dart`; helpers `p(styleId, runs, {ind, numId, ilvl, jc})`, `r(text, {b,i,strike,highlight,code,color,superscript})`):
   | Node | WordprocessingML |
   |---|---|
   | note start | `<w:bookmarkStart w:id="n" w:name="tephra_<n>"/>` around the title paragraph (style `Title`) when `showTitle`; else around the first paragraph; before every note after the first: `<w:p><w:r><w:br w:type="page"/></w:r></w:p>` |
   | `MdHeading(n)` | `<w:p><w:pPr><w:pStyle w:val="HeadingN"/></w:pPr>` + bookmark `tephra_<id>` + runs |
   | `MdParagraph` | `<w:p>` + runs (`<w:pPr><w:pStyle w:val="Normal"/></w:pPr>` optional) |
   | `MdText` | `<w:r><w:t xml:space="preserve">text</w:t></w:r>` |
   | `MdStrong`/`MdEmphasis`/`MdStrikethrough`/`MdHighlight` | run properties `<w:b/><w:bCs/>` / `<w:i/><w:iCs/>` / `<w:strike/>` / `<w:highlight w:val="yellow"/>` (nested inline nodes accumulate run properties) |
   | `MdInlineCode` | `<w:rPr><w:rStyle w:val="Code"/></w:rPr>` |
   | `MdSoftBreak`/`MdHardBreak` | `<w:r><w:br/></w:r>` |
   | `MdLink`/`MdAutolink` (external) | `<w:hyperlink r:id="rIdLinkN"><w:r><w:rPr><w:rStyle w:val="Hyperlink"/></w:rPr><w:t>text</w:t></w:r></w:hyperlink>` |
   | `MdWikiLink` (non-embed) to an exported note/heading | `<w:hyperlink w:anchor="tephra_<id>" w:history="1">` with the `Hyperlink` run style; otherwise plain text; display text as in 05.17 |
   | `MdTag` | run with style `Tag`, text `#tag` |
   | `MdFootnoteRef` | run with `<w:vertAlign w:val="superscript"/>`, text `[n]`; definitions at the end after a paragraph `Footnotes` (style `Heading3`) as `n. text` paragraphs |
   | `MdCodeBlock` | one paragraph per line, style `CodeBlock`, runs with `xml:space="preserve"`, tabs → `<w:tab/>`; empty line → empty paragraph; a language label line (style `CodeBlock`, grey colour) first when present |
   | `MdMathBlock`, `MdInlineMath` | code style with the TeX source |
   | `MdBlockQuote` | children paragraphs with style `Quote`; each nesting level adds `<w:ind w:left="720×(level+1)"/>` |
   | `MdCallout` | first paragraph style `Callout` with the bold title (capitalised type when none); body paragraphs style `Callout`; the left border colour per type (`<w:pBdr><w:left w:val="single" w:sz="18" w:space="4" w:color="RRGGBB"/></w:pBdr>`: `note`/`info` `2F6DB5`, `tip`/`success` `2E7D32`, `warning` `E07B00`, `danger`/`error`/`bug` `C62828`, `question` `7B1FA2`, others `757575`) |
   | `MdList` + `MdListItem` | the first paragraph of an item: style `ListParagraph` with `<w:numPr><w:ilvl w:val="L"/><w:numId w:val="N"/></w:numPr>` (`L` = nesting depth, max 8); further blocks of the item: same style without `numPr`, indent matching the level; tasks: no numbering, a leading run `☐ `/`☑ ` (font `Segoe UI Symbol`) and indent `720 + 360 × depth` |
   | `MdTable` | `<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="5000" w:type="pct"/></w:tblPr><w:tblGrid>` with equal `w:gridCol` widths; each row `<w:tr>`, the header row has `<w:trPr><w:tblHeader/></w:trPr>` and cells shaded `D9E2F3` with bold runs; cell `<w:tc><w:tcPr><w:tcW w:w=".." w:type="dxa"/></w:tcPr><w:p>…</w:p></w:tc>` — **every cell contains at least one `w:p`**; column alignment → `<w:jc w:val="left|center|right"/>` |
   | `MdThematicBreak` | `<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="6" w:space="1" w:color="999999"/></w:pBdr></w:pPr></w:p>` |
   | `MdHtmlBlock`/`MdHtmlInline` | extracted text only |
   | `MdCommentBlock`/`MdCommentInline`/`MdBlockId` | nothing |
   | `MdFrontmatter` | with `includeProperties`: a two-column table (key bold) before the body; else nothing |
   | embeds | `NoteEmbed` → the fragment's blocks inline, each paragraph with extra indent 360 (depth ≤ 5); `ImageEmbed` → drawing (below); `FileEmbed` → `[file: name]`; `MissingEmbed` → italic `[missing: target]`; `EmbedLimit` → name text |
   **Drawing** (inline image): `<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx=".." cy=".."/><wp:docPr id="N" name="Image N"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="image N.png"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="rIdImgN"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx=".." cy=".."/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>`.
   Size in EMU: px × 9525; natural size from `readImageSize` (05.3; unknown → 300×200 px), requested `|w`/`|wxh` px override; the width is capped to the content width (page width − margins) in EMU and the height scales with the same ratio. `docPr id` values are unique across the document starting at 1.
5. **Numbering** (`numbering.xml`): `abstractNum 0` = bullets, 9 levels, `w:numFmt bullet`, `w:lvlText` `•`, `◦`, `▪` repeating, `w:pPr/w:ind left=720×(L+1) hanging=360`, font `Calibri` (the glyph is plain Unicode; do not use the Symbol font); `abstractNum 1` = decimal, 9 levels with formats `decimal`, `lowerLetter`, `lowerRoman` repeating and `%1.` style texts, same indents.
   `w:num w:numId="1"` → abstractNum 0 (shared by all bullet lists). Every **ordered** list gets its own `w:num` with the next free id (2, 3, …) → abstractNum 1 with `<w:lvlOverride w:ilvl="0"><w:startOverride w:val="<start>"/></w:lvlOverride>` (restarts numbering at the list's start number); nested ordered lists use the same numId with `ilvl` = depth. Generate `numbering.xml` **after** rendering (the number of `w:num` is known only then).
6. **Section properties:** `<w:sectPr>` with header/footer references (when on), `<w:pgSz w:w="11906" w:h="16838"/>` for A4, `w:w="12240" w:h="15840"` for Letter, `<w:pgMar w:top w:right w:bottom w:left>` = `marginMm × 56.6929` rounded (twips), `w:header="708" w:footer="708"`.
7. **Bookmarks:** ids are unique integers starting at 0; names `tephra_<n>` (≤ 40 chars, `[A-Za-z0-9_]`). A map `anchorFor(vaultPath, headingSlug?)` is filled while rendering; a wikilink rendered **before** its target exists is resolved in a second pass: render notes first to a structure that stores `AnchorRef` placeholders, then substitute names (or simply pre-assign anchors for every note and every heading in a first parse-only pass — choose the pre-assignment pass; it is simpler).
8. Output: `<base> <date>.docx`; `options` as in item 1.

**Tests.** `docx_inspect.dart` (support): `Future<DocxPackage> openDocx(List<int> bytes)` → `files: Map<String, List<int>>`, `xml(String part)` → `XmlDocument` (throws if not well-formed), `rels(String part)`.
`docx_exporter_test.dart` (input = fixture vault, `Syntax test.md`):
- `package has required parts`: all parts of the table in item 2 exist (header/footer when on); `[Content_Types].xml` is the first zip entry.
- `all xml parts are well formed`: `XmlDocument.parse` succeeds on every `.xml` and `.rels` part.
- `content types cover every part`: each part has an `Override` or a `Default` for its extension.
- `relationships resolve`: every `Target` in `_rels/.rels` and `word/_rels/document.xml.rels` (internal ones) exists in the package; every `r:id`/`r:embed` used in `document.xml` has a relationship; hyperlink relationships have `TargetMode="External"`.
- `styles used exist`: every `w:pStyle`, `w:rStyle`, `w:tblStyle` value in `document.xml` is defined in `styles.xml`.
- `headings`: exactly 7 paragraphs use `Heading1`…`Heading6`: the six headings of the note plus the `## Section B` heading, which the section embed includes (05.17 `resolveEmbed` starts the fragment at the heading line); one each of `Heading1`, `Heading3`, `Heading4`, `Heading5`, `Heading6` and two `Heading2`.
- `lists use numbering`: bullet paragraphs reference `numId 1`; the ordered list references a `numId` ≥ 2 whose `w:num` has `startOverride` 3; `numbering.xml` defines every referenced `numId`.
- `table structure`: one `w:tbl` with 3 rows, each with 3 `w:tc`, first row has `w:tblHeader`, alignment `center` on column 2 cells.
- `hyperlinks`: the external link has a relationship with target `https://example.com`; wikilinks to `Linked note` are plain text when only one note is exported, and `w:hyperlink w:anchor` to an existing bookmark when the vault root is exported.
- `images`: one `word/media/image1.png` equal to `tinyPng`; `wp:extent cx` = 100 × 9525 (the `|100` size), `cy` = 100 × 9525 (1×1 px source scaled to a width of 100 → height 100 keeping the 1:1 ratio).
- `code block lines`: two paragraphs with style `CodeBlock` for `def hello():` and `    print("hi")` (leading spaces preserved with `xml:space="preserve"`).
- `bengali text present` in `document.xml`; `cs` font set in styles.
- `no illegal xml chars`: a note containing `\u0001` and `\u000B` exports and parses.
- `page size`: A4 → `w:pgSz w:w="11906"`, Letter → `12240`; margin 20 mm → `1134` twips.
- `bookmark ids unique`; `docPr ids unique`.
- `comment and block id not present` in `document.xml` text.
Manual (record in `PROGRESS.md`): open the `Syntax test` DOCX in Word (or LibreOffice/Google Docs if Word is unavailable): no "unreadable content" prompt, headings navigable in the navigation pane, nested lists, table header repeats, image visible, hyperlinks clickable.

**Verify.** `cd packages/tephra_io; dart test test/exporters/docx_exporter_test.dart; cd ../..`

**Pitfalls.** Word is strict: element order inside `w:pPr`/`w:rPr` follows the schema (`pStyle`, `keepNext`, `numPr`, `pBdr`, `shd`, `ind`, `jc` for `pPr`; `rStyle`, `rFonts`, `b`, `bCs`, `i`, `iCs`, `strike`, `color`, `sz`, `highlight`, `vertAlign` for `rPr`) — emit them in that order. A table cell without a paragraph corrupts the file. Never put more than one `w:sectPr` at the end of the body. Do not reuse a `w:bookmarkStart` id.

---

### 05.20 — App services: save-as, share sheet, staging, font cache, providers, commands

**Purpose.** Connect `tephra_io` to the app: the runners, file pickers, "Save as…" on Windows, the share sheet on Android, staging for storage that is not a real folder, and the four commands. The wizards come in 05.21.

**Files.**
- `app/lib/import_export/providers.dart`
- `app/lib/core/platform/file_save_service.dart` (interface + no-op implementation, conventions §5.9) and `app/lib/core/platform/file_save_service_io.dart` (Windows and Android implementations)
- `app/lib/import_export/importer_catalog.dart`
- `app/lib/import_export/source_stager.dart`
- `app/lib/import_export/export_font_cache.dart`
- `app/lib/import_export/import_export_service.dart`
- `app/lib/commands/io_commands.dart` and its registration in the command registry
- `app/lib/explorer/…` (context-menu entries: use the extension point recorded in the discovery task)
- `app/lib/core/providers.dart` (add `fileSaveServiceProvider`)
- `app/lib/l10n/app_en.arb` (keys in 05.21 table, commands' labels now)
- tests under `app/test/import_export/`

**Implementation.**
1. Dependencies: `flutter pub add share_plus` in `app/`; `file_picker` is already there (see Dependencies table). Run `dart run tool/check_licenses.dart`. **Read the installed `share_plus` and `file_picker` READMEs first**: `share_plus` 10+ uses `SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: …))`; older versions use `Share.shareXFiles`. Use the one that exists and note it in `PROGRESS.md`.
2. `FileSaveService` (conventions §5.9 pattern: interface + implementations chosen in `fileSaveServiceProvider` by `Platform.isWindows` / `Platform.isAndroid`; a no-op/throwing implementation elsewhere so tests and web previews compile):
   ```dart
   abstract interface class FileSaveService {
     bool get canSaveAs;                                      // Windows: true; Android: true for files < 100 MiB
     bool get canShare;                                       // Android: true; Windows: false
     Future<String?> saveAs(String suggestedName, String sourceFilePath);   // returns the saved path/uri or null when cancelled
     Future<void> share(List<String> filePaths, {String? subject});
     Future<void> showInFolder(String path);                  // Windows: explorer /select,<path> via Process.run; Android: no-op
   }
   ```
   Windows `saveAs`: `FilePicker.platform.saveFile(dialogTitle:, fileName: suggestedName, type: FileType.custom, allowedExtensions: [ext])`, then copy the temp file to the chosen path (`File.copy`; add the extension when the user omitted it; refuse to overwrite silently — the system dialog already confirms).
   Android `saveAs`: `FilePicker.platform.saveFile(fileName:, bytes: <file bytes>)` (Android requires the bytes; the platform writes through SAF) for files < 100 MiB, else returns null and the UI offers only Share. `share`: `share_plus` with the real MIME type (`pdf application/pdf`, `docx application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `zip application/zip`, `html text/html`, `md text/markdown`, `tephra-backup application/octet-stream`).
   Files to share must be under the app's cache directory (`getTemporaryDirectory()`), which the plugin exposes through its FileProvider.
3. `importer_catalog.dart`: `ImporterDescriptor { String id; String Function(AppLocalizations) label; String Function(AppLocalizations) help; IconData icon; List<PickKind> pick; List<String> extensions; bool needsPassword; }` and `const importerCatalog` in the conventional order:
   Obsidian vault (`folder`, `zip`), Markdown or text (`folder`, `files: md markdown txt`, `zip`), HTML (`folder`, `files: html htm`, `zip`), Notion (`zip`), Evernote (`files: enex`), Google Keep (`zip`, `files: json`, `folder`), Bear (`folder`, `zip`, `files: textpack bear2bk`), Roam (`files: json`, `zip`),
   Logseq (`folder`, `zip`), Apple Notes (`folder`, `zip`), OneNote (`folder`, `zip`), CSV (`files: csv tsv`), Tephra backup (`files: tephra-backup`, `needsPassword`). `enum PickKind { folder, zip, files }`. Help texts (l10n) say in one sentence how to export from the source app; Bear's help mentions TextBundle / Markdown export and `.bear2bk`;
   Notion's mentions "Export → Markdown & CSV, include subpages".
4. `SourceStager`: turns the user's pick into an `ImportSourceSpec`:
   - zip → `ZipSourceSpec(path)` (a `.bear2bk`/`.textpack` too); files → `FilesSourceSpec(paths)`; folder with a real path → `DirectorySourceSpec(path)`.
   - If the Phase 1 folder picker returned a SAF tree (no real path), copy the tree into `<tempDir>/import-src-<timestamp>/` through the Phase 1 SAF `VaultFileSystem` (`list` + `readBytes`, progress callback) and return `DirectorySourceSpec(thatTempDir)`; `cleanup()` deletes the temp folder after the import ends (also on cancel/failure).
   - `file_picker` on Android returns cache copies for files; delete those in `cleanup()` too.
5. `ExportFontCache`: `Future<String> ensureFonts()` copies the eight font assets (`rootBundle.load`) to `<appSupportDir>/fonts/` when missing or when the size differs, returns the directory (idempotent; runs only for PDF).
6. `ImportExportService` (Riverpod provider; business logic out of widgets):
   ```dart
   final class ImportExportService {
     Stream<ImportProgress> runImport({required String importerId, required Map<String, Object?> options, required ImportSourceSpec source, required VaultPath targetFolder});
     Future<ImportPreview> preview({required String importerId, required Map<String, Object?> options, required ImportSourceSpec source});
     Stream<ExportEvent> runExport({required String exporterId, required Map<String, Object?> options, required List<VaultPath> paths});   // writes into a temp folder, last event ExportFinished(files)
     String defaultImportFolder(String importerId);   // 'Imported/<Label> yyyy-MM-dd HHmm' using the app clock; '' for obsidian and tephra-backup
   }
   ```
   - Vault kind `io` (real folder): `ImportRunner.runInIsolate` / `ExportRunner.runInIsolate` with `vaultRoot` = the vault folder.
   - Vault kind `saf` (Android fallback; the isolate cannot use the platform channel): **import** runs in the isolate against a temp `IoVaultFileSystem` folder `<tempDir>/import-out-<ts>/`, and when it finishes the service copies every produced file into the vault through the app's vault file system (progress `Copying <n>/<m>`),
     never overwriting: if the destination exists the file is written as `<name> (imported).<ext>` and a warning is added. The Obsidian importer's skip/overwrite policies are disabled for `saf` vaults (the options UI hides them and the hint says why).
     **Export** first stages the whole vault (all non-hidden files) into `<tempDir>/export-src-<ts>/` (progress "Preparing…"), then runs in the isolate on that folder.
   - Export output goes to `<tempDir>/tephra-export-<ts>/`; `ExportFinished.files` are relative to it. The temp folder is deleted when the dialog closes (after Save/Share).
   - Notes opened in the editor with unsaved changes are saved before an export (call the existing "save all" action; if none exists, flush the open tabs' pending writes — record the name used).
   - After a successful import the service asks the index to reconcile (call the existing `NoteIndex.reconcile()` through its provider) and opens nothing automatically.
7. **Commands** (§7.8; labels from l10n; none has a default shortcut except where free):
   - `io.import` — "Import…": opens the import wizard (05.21); palette on; also reachable from the vault menu/settings entry that Phase 1 provides.
   - `io.export-note` — "Export current note…": available when a note tab is active (`isAvailable`); opens the export dialog with that note.
   - `io.export-folder` — "Export folder…": opens a folder choice (the explorer's selected folder if any, else a picker dialog listing folders) then the dialog.
   - `io.export-vault` — "Export vault…": dialog with `VaultPath.root`.
   Explorer context menu: on a note: **Export…**; on a folder: **Export…** and **Import here…** (wizard with the target folder preset). Mobile toolbar: none.
8. Add the l10n keys for the commands now (`ioCommandImport`, `ioCommandExportNote`, `ioCommandExportFolder`, `ioCommandExportVault`, `explorerExport`, `explorerImportHere`) and the importer catalog labels/help (`ioImporter<Id>Label`, `ioImporter<Id>Help` for the thirteen ids: Obsidian, Markdown, Html, Notion, Evernote, Keep, Bear, Roam, Logseq, AppleNotes, OneNote, Csv, TephraBackup).

**Tests.**
- `file_save_service_test.dart`: with a fake `FilePicker` platform and a temp dir: `windows saveAs copies file and appends extension`, `cancelled returns null`, `android refuses over 100 MiB` (the size check is a pure function; test it), `mime type table`.
- `import_export_service_test.dart` (fake runner seam: the service takes `ImportRunner`-like functions as constructor parameters for tests): `io vault uses isolate runner with vault root`, `saf vault stages out and copies without overwriting` (a fake SAF fs backed by `MemoryVaultFileSystem`), `default import folder format` (with a fixed clock: `Imported/Notion 2026-10-11 0930`), `temp folders cleaned on cancel`, `reconcile called after import`.
- `source_stager_test.dart`: zip/files/folder specs; `saf tree is copied to temp and cleaned up`.
- `io_commands_test.dart`: command ids exist in the registry, `io.export-note` unavailable without an active note.
- `importer_catalog_test.dart`: every id in `IoRegistry.importerIds` has exactly one descriptor, same order.

**Verify.**
```powershell
cd app; flutter test test/import_export; cd ..
flutter analyze --fatal-infos
dart run tool/check_licenses.dart
```

**Pitfalls.** The isolate cannot use `MethodChannel`s: anything platform-specific (SAF, share) stays on the main isolate. Temp folders can be large — always delete them. Passwords travel in the job map only; never log the job.

---

### 05.21 — Import wizard and export dialog (desktop and phone layouts)

**Purpose.** The user interface for 05.1–05.20 on both layouts (conventions §5.8: breakpoint 840 dp, decided with `MediaQuery.sizeOf`, never `Platform`).

**Files.**
- `app/lib/import_export/import_wizard.dart` (state machine + route/dialog host)
- `app/lib/import_export/import_wizard_controller.dart` (`Notifier` with the state below)
- `app/lib/import_export/pages/choose_source_page.dart`, `pick_source_page.dart`, `options_page.dart`, `preview_page.dart`, `progress_page.dart`, `report_page.dart`
- `app/lib/import_export/widgets/csv_mapping_editor.dart`, `widgets/warnings_list.dart`, `widgets/step_rail.dart`
- `app/lib/import_export/export_dialog.dart`, `export_dialog_controller.dart`
- `app/lib/core/settings/…` (the export options keys below, in the app settings file `<appSupportDir>/settings.json`, per device)
- `app/lib/l10n/app_en.arb`
- tests under `app/test/import_export/`

**Implementation.**
1. **Import wizard state machine** (`ImportWizardState { step, importerId?, pickedSource?, spec?, options, preview?, targetFolder, progress, report?, error? }`, steps in order):
   1. `chooseSource` — a list (phone) / 3-column grid (desktop) of the 13 importers from `importerCatalog`: icon, label, one-line help. Tap selects and goes on. Bear's tile shows "TextBundle, Markdown export or .bear2bk".
   2. `pickSource` — explains what to select (help text) and shows buttons per `PickKind` (e.g. "Choose folder", "Choose .zip file", "Choose files…"); after picking, shows the name/count and **Next**. Android folder picks that return a SAF tree show "Preparing files…" while `SourceStager` copies them.
   3. `options` — importer-specific, skipped when there are none:
      - Obsidian and Tephra backup: conflict policy radio (**Keep both** default, **Skip existing**, **Replace (old version goes to trash)**); hidden for SAF vaults with a hint. Backup: password field (obscured, show/hide) and, when wrong, the error "Wrong password or damaged backup".
      - Notion, Evernote, Keep, Bear, Roam, Logseq: none, except Keep → switch "Create stickies instead of notes (Tephra stickies)" (`asStickies`), Roam and Logseq → text fields "Daily notes folder" and "Daily note format" pre-filled from the vault's daily-notes settings (folder, format) with a live example (`DailyNoteFormat.format(today)`), Roam also "Convert daily pages to daily notes" switch (`dailyAsDailyNotes`) and "Roam date format" (default `MMMM Do, YYYY`).
      - CSV: the **column-mapping editor** (below) after the first `preview` returns `columns`.
      - Time zone: not shown (importers use the device time zone).
   4. `preview` — runs `previewInIsolate` (spinner), then shows: counts (`N notes · M attachments · K skipped`), up to 10 sample titles, a collapsible warnings list, and the **target folder** field (default `defaultImportFolder`, with a folder picker for vault folders; for Obsidian/backup the default is the vault root and an explicit note "Notes keep their original folders"). **Start import** button.
   5. `progress` — determinate bar `done/total`, current item name, **Cancel** (confirm dialog "Stop the import? Notes already imported are kept"); warnings counter live. On `ImportFinished` goes to `report`.
   6. `report` — summary "Imported N notes and M attachments", warnings list (selectable, **Copy all** button copies the warnings as text), buttons **Open folder** (reveals the target folder in the explorer) and **Done**; on cancel the title reads "Cancelled after N notes". Errors show a plain-language message (from `TephraException` kinds) and **Try again**.
   Back button returns to the previous step except during `progress`.
2. **CSV mapping editor:** a table of the CSV's columns (from `preview.columns`) with per-column controls: radio "Title" (exactly one), radio "Body" (zero or one, "None" option), and for the others a dropdown Type (Auto, Text, Number, Checkbox, Date, Date and time, List) plus a checkbox "Skip". Header row suggests via `CsvMapping.suggest`. A small live preview shows the first 3 titles. Switch "Also create a table view (.base)". Delimiter dropdown (Auto, Comma, Semicolon, Tab).
   Phone: each column is a card (title, radio chips, dropdown); desktop: a real `Table`/`DataTable` layout.
3. **Layouts.** Desktop (width ≥ 840): a modal dialog 760 × 600 with a left **step rail** (6 steps, current highlighted) and content on the right, action buttons at the bottom right. Phone: a full-screen route with a top stepper ("Step 3 of 6") and a **bottom bar** with Back/Next buttons, each ≥ 48 dp high; content scrolls; the keyboard does not hide the buttons (`SafeArea`, `resizeToAvoidBottomInset`).
   Provide both through one `ImportWizard` widget that picks the host by `MediaQuery.sizeOf(context).width`.
4. **Export dialog** (`ExportDialog(paths:, …)`): header line with the scope ("Note: Syntax test", "Folder: Projects (14 notes)", "Whole vault (1,204 notes)", counted with the index's `allNotes()` filtered by path prefix) → **Format** selector (segmented buttons on desktop, dropdown list on phone):
   Zip archive, Encrypted backup, PDF, HTML, Word (.docx), Portable Markdown. Options per format:
   - Zip: none. Portable Markdown: switch "Keep properties (frontmatter)" (default on) + one-line explanation "Links become standard Markdown links; embedded notes are copied in".
   - HTML: switch "Include properties".
   - PDF: Page size (A4/Letter), Margins slider 10–40 mm (default 20), switches Title, Header, Footer, Page numbers, Include properties; footnote text "Bengali and some other scripts may not be shaped perfectly in PDF."
   - Word: Page size, Margins, switches Title, Header, Footer, Page numbers, Include properties.
   - Encrypted backup: Password and Confirm (obscured), live strength hint (length < 8 → error "Use at least 8 characters"; 8–11 "OK"; ≥ 12 "Strong" — length only, no word lists), a warning card "Only Tephra can open this file. If you forget the password the backup cannot be recovered." and a required checkbox "I understand".
   **Export** button → progress (determinate; "Protecting…" indeterminate spinner for the backup's key derivation) → result card: file name and size, warnings (collapsible), buttons — Windows: **Save as…** (primary), **Show in folder**; Android: **Share** (primary), **Save to device** (when `canSaveAs`). **Done** closes and deletes the temp folder.
   Last-used values are remembered per device in app settings: `export.format`, `export.pdf.pageSize`, `export.pdf.marginMm`, `export.pdf.title`, `export.pdf.header`, `export.pdf.footer`, `export.pdf.pageNumbers`, `export.pdf.properties`, `export.docx.*` (same five keys + `pageSize`, `marginMm`), `export.html.properties`, `export.markdown.frontmatter`. **The backup password is never stored.**
   Layouts: desktop dialog 520 wide; phone: bottom sheet that expands to a full-height sheet (`DraggableScrollableSheet`) with ≥ 48 dp controls.
5. **l10n keys** (all in `app_en.arb`, `lowerCamelCase`, with `@key` descriptions for ambiguous ones; no concatenated fragments — use ICU placeholders `{count}`, `{name}`):
   | Area | Keys |
   |---|---|
   | wizard | `importWizardTitle`, `importStepChoose`, `importStepPick`, `importStepOptions`, `importStepPreview`, `importStepRun`, `importStepReport`, `importStepOf` (`Step {n} of {total}`), `importChooseFolder`, `importChooseZip`, `importChooseFiles`, `importPreparingFiles`, `importNext`, `importBack`, `importStart`, `importCancel`, `importCancelConfirmTitle`, `importCancelConfirmBody`, `importDone`, `importTryAgain` |
   | options | `importPolicyKeepBoth`, `importPolicySkip`, `importPolicyReplace`, `importPolicySafHint`, `importPasswordLabel`, `importWrongPassword`, `importKeepAsStickies`, `importDailyFolder`, `importDailyFormat`, `importDailyExample` (`Example: {example}`), `importRoamDailyAsNotes`, `importRoamDateFormat`, `importTargetFolder`, `importKeepsOriginalFolders` |
   | csv | `csvMappingTitle`, `csvColumnTitle`, `csvColumnBody`, `csvColumnNone`, `csvColumnType`, `csvTypeAuto`, `csvTypeText`, `csvTypeNumber`, `csvTypeCheckbox`, `csvTypeDate`, `csvTypeDateTime`, `csvTypeList`, `csvColumnSkip`, `csvCreateBase`, `csvDelimiter`, `csvDelimiterAuto`, `csvDelimiterComma`, `csvDelimiterSemicolon`, `csvDelimiterTab`, `csvPreviewTitles` |
   | preview/report | `importPreviewCounts` (`{notes} notes · {attachments} attachments · {skipped} skipped` as a plural-aware message), `importSampleTitles`, `importWarnings`, `importCopyWarnings`, `importReportTitle`, `importReportCancelled`, `importOpenFolder`, `importErrorGeneric`, `importErrorWrongPassword`, `importErrorNotBackup` |
   | export | `exportDialogTitle`, `exportScopeNote`, `exportScopeFolder`, `exportScopeVault`, `exportFormat`, `exportFormatZip`, `exportFormatBackup`, `exportFormatPdf`, `exportFormatHtml`, `exportFormatDocx`, `exportFormatMarkdown`, `exportPageSize`, `exportPageA4`, `exportPageLetter`, `exportMargins`, `exportShowTitle`, `exportHeader`, `exportFooter`, `exportPageNumbers`, `exportIncludeProperties`, `exportKeepFrontmatter`, `exportMarkdownHint`, `exportPdfScriptsHint`, `exportPassword`, `exportPasswordConfirm`, `exportPasswordTooShort`, `exportPasswordMismatch`, `exportPasswordOk`, `exportPasswordStrong`, `exportBackupWarning`, `exportBackupUnderstand`, `exportRun`, `exportProtecting`, `exportPreparing`, `exportResultTitle`, `exportSaveAs`, `exportShare`, `exportSaveToDevice`, `exportShowInFolder`, `exportSaved`, `exportDone` |
   Warning strings generated by `tephra_io` are English-only (05 "Shared conventions"); everything else in the UI is localised.
6. Accessibility: every control has a semantic label; focus order follows reading order; the step rail is not focusable; error messages use `liveRegion`.

**Tests.** (`flutter test`; fake `ImportExportService`)
- `import_wizard_test.dart`: `choose source lists thirteen importers`, `desktop width shows step rail` (pump at 1200×800), `phone width shows bottom bar with 48dp buttons` (pump at 400×800, check button heights ≥ 48), `back and next navigate`, `cancel asks confirmation`, `report shows warnings and copy button`, `error shows try again`, `roam options prefilled from daily settings`, `obsidian policy hidden for saf`.
- `csv_mapping_editor_test.dart`: `suggested mapping preselected`, `exactly one title column`, `skip checkbox excludes column from json`, `mapping json matches CsvMapping.toJson`.
- `export_dialog_test.dart`: `format list has six entries`, `pdf options visible only for pdf`, `backup requires matching passwords of length 8 and the checkbox`, `export button disabled until valid`, `desktop shows Save as, phone shows Share` (fake `FileSaveService` flags), `last used options restored`, `password not stored` (settings file does not contain the password).
- Golden tests are not required; if added, tag `@Tags(['golden'])`.

**Verify.**
```powershell
cd app; flutter test test/import_export; cd ..
flutter analyze --fatal-infos
```
Manual (record in `PROGRESS.md`): run `dart run tool/dev.dart` (Dev Launcher), open the web preview at both a narrow and a wide window and walk through the wizard with a fake service; on a real Android phone (if available — otherwise write "not verified on device") import a small zip and share an exported PDF.

**Pitfalls.** Nothing in the wizard may block the UI isolate: previews and runs go through isolates (05.5). Do not hard-code English strings in widgets. Warnings from the package are shown verbatim.

---

### 05.22 — Integration, registry completeness, licences and notices

**Purpose.** Close the phase: every id wired, end-to-end tests from source file to Obsidian-compatible output, licence check, documentation.

**Files.**
- `packages/tephra_io/test/registry_complete_test.dart`
- `packages/tephra_io/test/integration/import_then_reparse_test.dart`
- `packages/tephra_io/test/integration/export_import_roundtrip_test.dart`
- `packages/tephra_io/README.md` (update: public API, importer/exporter table, supported inputs, limitations)
- `THIRD_PARTY_NOTICES.md` (regenerated by the tool)
- `PROGRESS.md`

**Implementation.**
1. `registry_complete_test.dart`: every id in `IoRegistry.importerIds` and `exporterIds` can be created with default/minimal options (`backup`: password `password1`; `pdf`: a font directory), has a non-empty `label`, and `createImporter('x', {})` still throws `ArgumentError`. No `UnimplementedError` remains anywhere in `IoRegistry`.
2. `import_then_reparse_test.dart`: run **every** importer fixture (05.6–05.15) with `runInline` into a `MemoryVaultFileSystem`, then parse every produced `.md` with `MarkdownParser.parse` and assert: `frontmatterValid` is true for every note that starts with `---`; every wikilink with a `/` in its target resolves (via `SimpleLinkResolver`) to an existing file; every embed resolves; no file name contains a character from `\ / : * ? " < > |` or ends with `.`/space; every importer finished with `ImportFinished` and **zero** exceptions (this is the "0 crashes" gate).
3. `export_import_roundtrip_test.dart`: export the fixture vault with `ZipExporter` and with `BackupExporter` (low KDF params), re-import with `ObsidianImporter`/`TephraBackupImporter` into an empty memory vault; the notes are byte-identical to the originals.
4. Licence tool: `dart run tool/check_licenses.dart` passes; `THIRD_PARTY_NOTICES.md` lists `archive`, `html`, `xml`, `pdf` (and its transitive packages), `cryptography`, `share_plus`, and the "Bundled fonts" section. If any transitive package of `pdf` or `archive` shows a disallowed licence, stop and ask the human (GEMINI.md §5).
5. Update `packages/tephra_io/README.md`: a table of the 13 importers (id, input, what is converted, what is not), the six exporters, the `.tephra-backup` format summary (point to `backup_format.dart`), and the limitations list from "Hand-off".
6. Run the whole gate (below) and record numbers in `PROGRESS.md`.

**Tests.** The three test files above plus the existing suites; `dart test` in `packages/tephra_io` must be fully green, `flutter test` in `app/`, `flutter analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`.

**Verify.**
```powershell
cd packages/tephra_io; dart test; cd ../..
cd app; flutter test; cd ..
flutter analyze --fatal-infos
dart run tool/check_licenses.dart
```

**Pitfalls.** Do not "fix" a failing integration test by loosening it; a failing assertion points at an importer bug. Update snapshots only after reading the diff.

---

## Demo script

Run on Windows with a vault that already has a few notes (use `test_vaults/syntax/` copied to a temp folder):

1. Create `D:\temp\notion-demo.zip` from `packages/tephra_io/test/fixtures/notion/input/` (or run `dart run tool/gen_notion_export.dart D:\temp\notion-1000 1000` and zip it). Open **Import…** (command palette: "Import…").
2. Choose **Notion**, pick the zip → **Next** → preview shows page/row/attachment counts and the single "links point to Notion pages that were not part of the export" warning → keep the default folder `Imported/Notion <date> <time>` → **Start import**. After the report, open `Home.md`: links to `Roadmap`, the `Tasks.base` table and the image work; open `Tasks.base` → table with the row properties.
3. Import `Work.enex` (Evernote): tasks render as checkboxes, the image embeds, tags are in the properties. Import `contacts.csv` with the mapping editor (title `Name`, body `Notes`, "Create a table view").
4. Import the Roam fixture with daily folder `Daily` and format `YYYY-MM-DD`: `Daily/2026-10-11.md` exists and `[[October 11th, 2026]]` links resolve.
5. Open `Syntax test.md` (copy `packages/tephra_io/test/fixtures/export/vault/*` into the vault) → palette **Export current note…** → PDF, A4, margins 20, header/footer/page numbers on → **Export** → **Save as…** → open the PDF: headings, lists, table, callout, image, embeds, footnote present, page numbers shown.
6. Export the same note as **Word**, **HTML** (open in a browser offline: image visible, no network requests) and **Portable Markdown** (unzip: relative links, embedded text inlined).
7. Export the vault as **Encrypted backup** with password `demo-password-1`; import that file with **Tephra backup** into an empty folder `Restore/` with the right password (works) and with a wrong one (clear error).
8. On Android (if a device is available): import a zip via the SAF folder picker flow, export a PDF and tap **Share**.

## Exit gate

All must be true; record the evidence in `PROGRESS.md`:

- [ ] `dart test` in `packages/tephra_io` is green; the integration test of 05.22 shows **0 crashes** across the importer fixtures: Obsidian, Markdown/text, HTML, Apple Notes, OneNote, Notion, Evernote, Google Keep, Bear (Markdown, TextBundle, `.textpack`, `.bear2bk`), Roam, Logseq, CSV, Tephra backup — each finished with an `ImportFinished` and the **expected report** (note count, attachment count and exact warning strings as in the fixtures' snapshots).
- [ ] The 1,000-note synthetic Notion export (`tool/gen_notion_export.dart <dir> 1000`) imports in **< 2 minutes on Windows** (`dart test -t bench`; record the seconds) and **every generated wikilink resolves** to an existing file (asserted by the bench test).
- [ ] Every imported/exported Markdown file parses with `MarkdownParser`, frontmatter is valid, and no produced file name is illegal on Windows.
- [ ] `Syntax test.md` exports: **PDF** (structural tests green — header/trailer, page count equals page-tree `/Count`, MediaBox A4/Letter, fonts embedded, outlines, text-hook contains the expected strings and not the comment; manual visual check recorded), **DOCX** (structural tests green: every part present, all XML well formed, relationships/content types/styles/numbering resolve, 6 headings, table 3×3, image EMU sizes; manual open in Word/LibreOffice recorded without a repair prompt), **HTML** (no scripts, no external requests, image inlined; manual browser check), **portable Markdown** (relative links, embeds inlined, depth ≤ 5 with cycle and missing-target markers), and **zip** + **`.tephra-backup`** round-trip byte-identical.
- [ ] Wrong password, tampered and truncated `.tephra-backup` files are rejected with `CryptoException` (tests green).
- [ ] Import wizard and export dialog work on the desktop layout (≥ 840 dp) and the phone layout (< 840 dp): widget tests green; Windows "Save as…" manually verified; Android share sheet manually verified **or** recorded as "not verified on device".
- [ ] `flutter analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`, `flutter test` (app) and `dart run tool/check_licenses.dart` all pass; fonts listed under "Bundled fonts" in `THIRD_PARTY_NOTICES.md`.
- [ ] `PROGRESS.md` updated (all steps 05.1–05.22 ticked, performance number, discovered APIs, "not verified on device" notes).
- [ ] `git checkout main; git merge --no-ff phase-05; git tag v0.05.0` — then **stop** and report to the human (GEMINI.md §3.5). The tag is `v0.05.0` (format `v0.NN.0`, GEMINI.md §3 and conventions §9).

## Hand-off

Record in `PROGRESS.md` and report to the human:
- The discovered APIs table (from "Discovery task") and which picker package Phase 1 used (`file_picker` expected) and which `share_plus` API shape was found.
- Package API deviations found against the README (archive 4 zip encoder/decoder and UTF-8 flag, `xml` event API names, `pdf` `fontFallback`/background support, `share_plus` call shape).
- The real licence of the `html` package and the manual override entry added.
- Importer limitations to tell users: Notion — relation columns need the linked database in the same export, HTML exports are refused, property types are inferred (the `.tephra/types.json` registry is not written because `tephra_io` cannot see it; Obsidian infers date types from the registry only when the user sets them);
  Evernote — notes linking to other notes keep their web links, very large `.enex` files are held in memory once; Keep — no folder structure, colours kept as `color`; Bear — the `.bear2bk` layout is unofficial (tolerant detection), Bear's `info.json` date keys are best-effort;
  Roam — block references become `^id` anchors, macros other than TODO/DONE/embed stay as text, namespaces become `a-b` names; Logseq — `SCHEDULED`/`DEADLINE`/`:LOGBOOK:` lines are kept as text, whiteboards and org-mode pages are not imported; CSV — types inferred, relations not supported.
- Export limitations: PDF has no OpenType shaping (Bengali conjuncts may look wrong; emoji missing), math is shown as source, callouts always expanded; DOCX footnotes are rendered at the end (no native Word footnotes), webp/svg images are not embedded; HTML has no syntax highlighting and shows math as source;
  portable Markdown does not include notes that are only linked (not exported); backups contain no `.tephra/` settings; the zip and backup are built in memory (warning above 300 MiB, refusal above 1.5 GiB).
- SAF vaults: import is staged to a temp folder and copied without overwriting; export stages the whole vault first.
- Conventions gaps to raise with the human (do not edit the conventions yourself):
  1. §7.7 `ExportRequest`/`ExportSink` leave the output file naming to the exporter; this phase defines `exportBaseName` and writes `<base> <YYYY-MM-DD>.<ext>` (the UI reads the produced names from `ExportFinished.files`).
  2. §6.1 lists hidden-path rules for the indexer; exporters apply the same rule (no `.obsidian`, `.tephra`, `.trash`, `.git`).
  3. The `.tephra-backup` container (format v1, `backup_format.dart`) is new file-format surface that §6 does not list; it is frozen once released.
  4. `PdfPageSize` lives in `api/export_request.dart` and is shared by PDF and DOCX.
  5. Tag spelling is inconsistent across phase files (`v0.02.0`/`v0.03.0` vs `v0.03.0`/`v0.04.0`); this phase uses `v0.05.0` as the conventions require. Ask the human to normalise the earlier files.
- Phase 6 (visual views) reads the `.base` files this phase writes (Notion and CSV importers); if Phase 6 changes the Bases syntax, update `buildBaseFile` and its tests.

