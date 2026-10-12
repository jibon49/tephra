# Phase 02 — Links, index, search & Live Preview (MVP)

> **Duration estimate:** 5 weeks (one full-time developer), 28 steps.
> **Goal:** the "second brain" core. Every note is indexed in SQLite (drift + FTS5) by a background isolate; links resolve exactly
> like Obsidian; renaming or moving a file rewrites every link to it as one undoable operation; backlinks, outgoing links, outline,
> tags, bookmarks, page preview and embeds work; Obsidian search syntax works (search panel, quick switcher, ` ```query ` blocks);
> the editor gets autocomplete, slash commands, Live Preview, folding and a properties editor; daily notes, templates and unique
> notes work. At the end of this phase Tephra can replace Obsidian for daily use (MVP).

This file is authoritative for Phase 2. It builds on `instructions/00-conventions.md` (called "conventions" below; section numbers
like "§7.4" refer to it). Where this file adds to a conventions contract, it only **adds** members; it never renames or removes one.
Every addition is listed in "Contract additions" at the end of "Before you start" so you can see them in one place.

**Reading tables in this file:** read this file as raw Markdown source. Inside a table cell, a `|` that appears within backticks
(for example `` `[[Note|Alias]]` ``) is part of the code text, not a column separator.

Rules you already follow (from `GEMINI.md`) apply to every step: verify after each step, `dart format` + `flutter analyze --fatal-infos`,
tests of every touched package, tick `PROGRESS.md`, commit `phase 02.S: <summary>` (for example `phase 02.7: add NoteIndex facade`).

---

## Before you start

### Prerequisite gate

1. Open `PROGRESS.md`. Every checkbox of the **Phase 1 exit gate** must be ticked. If any is not ticked, stop and tell the human.
2. `git status` must be clean on `main`. Then: `git checkout -b phase-02`.
3. Run, at the repo root, and confirm all pass before changing anything:
   ```
   flutter pub get
   dart format --output=none --set-exit-if-changed app/lib app/test packages tool
   flutter analyze --fatal-infos
   ```
   and `dart test` in every `packages/tephra_*` directory, and `flutter test` in `app/`. If anything fails, fix it first as a
   separate commit `phase 02.0: fix pre-existing failure <what>`, and note it in `PROGRESS.md`.

### What exists from Phase 1 (inventory — do this first, record results)

Phase 1 delivered the items below. File names are the expected ones; **locate each with the given search** and, if the real name
differs, use the real name everywhere this file mentions it. Write a short table "Phase 1 inventory" into `PROGRESS.md` under the
Phase 2 heading, with one row per item: expected name → actual file/class. Do not rename Phase 1 code to match this file.

| # | Item | Expected location | Find it with |
|---|---|---|---|
| 1 | `VaultPath`, `TephraException` family, `Clock`, `contentHash` | `packages/tephra_core/lib/src/` | `git grep -n "class VaultPath"` |
| 2 | `VaultFileSystem`, `IoVaultFileSystem`, `MemoryVaultFileSystem`, `TextDocument`, `VaultChange` + subclasses | `packages/tephra_vault/lib/src/` | `git grep -n "class IoVaultFileSystem"` |
| 3 | `MarkdownParser.parse`, `ParsedNote`, all `Md*` nodes (§7.3), `BlockRef`, `TaskItem` | `packages/tephra_markdown/lib/src/` | `git grep -n "class ParsedNote"`, `git grep -n "class BlockRef"`, `git grep -n "class TaskItem"` |
| 4 | Reading view (AST → widgets) | `app/lib/reading/reading_view.dart` | `git grep -n "class ReadingView"` |
| 5 | Source-mode editor behind the app-side `EditorController` | `app/lib/editor/editor_controller.dart` | `git grep -n "class EditorController"` |
| 6 | Editor engine decision | `docs/decisions/0001-editor-engine.md` | open it; note the chosen engine: **A** (`re_editor`), **B** (`TextField` + `buildTextSpan`) or **C** (custom `RenderObject`) |
| 7 | Explorer (tree, rename, move, delete) | `app/lib/explorer/` | `git grep -n "rename" app/lib/explorer` |
| 8 | Workspace: tabs, splits, sidebars, phone drawers, per-tab history | `app/lib/workspace/` | `git grep -n "class .*Tab" app/lib/workspace` |
| 9 | Command registry + palette (`TephraCommand`, `commandRegistryProvider`) | `app/lib/commands/` | `git grep -n "commandRegistryProvider"` |
| 10 | Simple quick switcher (file names) | `app/lib/commands/` or `app/lib/workspace/` | `git grep -n -i "quick.\?switcher"` |
| 11 | Attachments (paste/drop/pick) | `app/lib/editor/` | `git grep -n "Pasted image"` |
| 12 | Vault picker, vault session providers, vault id from `.tephra/vault.json` | `app/lib/vault/` | `git grep -n "vault.json"` |
| 13 | Vault settings model + store for `.tephra/settings.json` (and the JSON store used for other `.tephra/*.json` files) | `app/lib/settings/` or `app/lib/core/` | `git grep -n "settings.json"` |
| 14 | `.obsidian` settings importer (attachment folder, new-note location, daily notes, templates, hotkeys, bookmarks) | `app/lib/vault/` or `app/lib/settings/` | `git grep -n "daily-notes.json"` |
| 15 | Fuzzy matcher used by the command palette | `app/lib/commands/` | `git grep -n -i "fuzzy"` |
| 16 | Bench vault generator | `tool/gen_bench_vault.dart` | file exists? |
| 17 | Line/offset helper (offset → line number) | `packages/tephra_markdown/lib/src/` | `git grep -n "class LineIndex"` |

Also record, in the same table, the **exact field names** of `BlockRef` and `TaskItem` (Phase 1 defined them). This file assumes:

- `BlockRef`: `String id`, `int start`, `int end` — `start`/`end` is the range of the **block that owns the ID** (the paragraph,
  list item or heading the `^id` belongs to), not the range of the `^id` text itself. If Phase 1's `BlockRef` stores only the
  `^id` text range, compute the owning block yourself in step 02.4 (rule given there).
- `TaskItem`: `String status` (one character, `' '` for open), `String text` (the task text after `- [x] `), `int start`, `int end`
  (range of the whole list item line(s)). If Phase 1 used `TaskStatus` or another name, map it.

If item 16 (`tool/gen_bench_vault.dart`) does not exist, you will create it in step 02.28; nothing before that needs it.
If item 17 (`LineIndex`) does not exist, step 02.3 creates it in `tephra_index`.

### Contract additions made in this phase (all additive)

| Contract | Addition | Why |
|---|---|---|
| §7.4 `NoteIndex.open` | extra optional named parameter `IndexOptions options = const IndexOptions()` | user's "excluded folders" setting must reach the indexer |
| §7.4 `NoteIndex` | `Stream<IndexEvent> get changes` | UI panes refresh when the index changes |
| §7.4 `NoteIndex` | `allFiles()`, `allAliases()`, `allHeadings()`, `blocks(path)`, `propertyKeys()`, `propertyValues(key)`, `loadNameTable()`, `rawSelect(sql, args)`, `stats()` | needed by switcher, autocomplete, rename planner, search |
| §7.5 `SearchEngine.run` | extra optional named parameters `SearchSort sort = SearchSort.fileNameAsc` and `bool matchCase = false` | sort options; the panel's global match-case toggle |
| §7.5 `SearchMatch` | extra fields `snippetStart`, `snippetEnd`, `inFileName` | highlight inside the snippet; file-name matches |
| §7.5 `CancelToken` | defined in `tephra_search` (conventions name it but do not define it) | cancellation |
| §7.1 `tephra_core` | new public files `moment_format.dart` (`formatMoment`, `parseMoment`, `validateMomentFormat`), `template_engine.dart` (`applyTemplate`, `TemplateContext`), `daily_note_path.dart` (`dailyNotePath`) — pure Dart, no existing member changes (step 02.22) | one shared date/template implementation for the app and for Phase 4's headless writers |
| §6.6 `.tephra/workspace.json` | new per-device keys: tab entry `"mode"` (`"livePreview"` or `"source"`) and device entry `"folds"` (steps 02.24, 02.25) | per-tab editing mode and per-note fold state; unknown keys stay untouched |
| §7.2 `IoVaultFileSystem` | public getter `String get rootDir` **only if Phase 1 did not already expose the root directory** | the index worker isolate opens its own read-only `IoVaultFileSystem` |

If you find you need any other change to a conventions contract, **stop and ask the human** (GEMINI.md §5).

---

## What exists when this phase is done

- `packages/tephra_index`: drift database (`TephraIndexDatabase`) with tables `files`, `notes`, `aliases`, `headings`, `blocks`,
  `links`, `tags`, `properties`, `tasks`, `index_meta` and FTS5 tables `fts_words` (unicode61, Bangla-aware) and `fts_trigram`
  (substring search); a pure link resolver; a link formatter; a rename planner; the `IndexerCore` (full index, reconcile,
  incremental updates with the dirty-targets algorithm); `NoteIndex` (§7.4) running the indexer in a long-lived worker isolate;
  a 10,000-operation consistency fuzz test.
- `packages/tephra_search`: Obsidian search grammar parser (`SearchParser`), SQL/FTS compiler, verification matcher, `SearchEngine`
  with streaming results, sorting and cancellation, and the shared `FuzzyScorer`.
- App: index lifecycle tied to the vault session, progress indicator, `Rebuild index` command; links open/create notes; rename/move
  rewrites links with an undo action; panes: backlinks (linked + unlinked mentions), outgoing links, outline (drag to move sections
  on desktop), tags (nested tree), bookmarks; page preview (hover / long-press); embeds and transclusion in reading view;
  search panel (desktop sidebar, phone full screen) with history, sort, copy results; ` ```query ` blocks; index-backed quick
  switcher with headings mode; editor autocomplete (`[[`, `![[`, `#`, frontmatter keys/values) and slash commands; Live Preview
  mode (Ctrl+Shift+E per tab; Ctrl+E stays reading view toggle; default-mode setting); heading/list folding with persisted fold state; properties editor; daily notes,
  templates and unique note creator; performance harness with recorded budget numbers.
- Test fixture vault `test_vaults/search/` (created in step 02.16) with 30+ sample queries and their expected results.

---

## Dependencies added in this phase

Add each dependency with the command shown (never by hand-editing versions). After each addition run
`dart run tool/check_licenses.dart` at the repo root; it must pass. Then run `flutter pub get` at the repo root.

| Package | Where | Command (run in that directory) | Purpose | Licence |
|---|---|---|---|---|
| `drift` | `packages/tephra_index` | `dart pub add drift` | typed SQLite access, migrations, batching | MIT |
| `sqlite3` (major version **3** or later) | `packages/tephra_index` | `dart pub add sqlite3` | SQLite bindings; v3 bundles a recent SQLite with FTS5 through Dart build hooks (native assets) for Windows, Android and `dart test` | MIT |
| `drift_dev` | `packages/tephra_index` (dev) | `dart pub add dev:drift_dev` | code generator for drift tables | MIT |
| `build_runner` | `packages/tephra_index` (dev) | `dart pub add dev:build_runner` | runs `drift_dev` | BSD-3-Clause |
| `path` | `packages/tephra_index` | `dart pub add path` (skip if present) | path joins in tests/tools | BSD-3-Clause |
| `logging` | `packages/tephra_index`, `packages/tephra_search` | `dart pub add logging` (skip if present) | logging | BSD-3-Clause |
| `yaml_edit` | `app` | `flutter pub add yaml_edit` | edit frontmatter while keeping formatting (§6.4) | BSD-3-Clause |
| `yaml` | `app` | `flutter pub add yaml` (skip if present) | source spans of frontmatter keys (rename/reorder) | MIT |
| `url_launcher` | `app` | `flutter pub add url_launcher` (skip if Phase 1 added it) | open audio/video/PDF attachments with the system app on Windows | BSD-3-Clause |
| `intl` | `packages/tephra_core` | `dart pub add intl` (skip if present) | Moment-style date formatting for daily notes, templates and unique notes (step 02.22) | BSD-3-Clause |

**Decisions recorded here:**

- **SQLite bundling:** use `sqlite3` **≥ 3.0.0** (build-hooks based; no `sqlite3_flutter_libs`). It ships SQLite ≥ 3.45 with FTS5,
  the `trigram` tokenizer and `contentless_delete`, on Windows, Android and in plain `dart test`. If Phase 0's spike
  (`docs/spikes/`) recorded a different working combination, keep that combination **only if** the smoke tests of step 02.1 pass with
  it. If `dart pub add sqlite3` cannot resolve a 3.x version together with `drift`, stop and ask the human (do not fall back to
  2.x — on 2.x `dart test` on Windows has no bundled SQLite).
- **Code generation:** conventions §5.3 forbids code generation **for models**. drift table classes are not models; they need
  `drift_dev`. The generated file `packages/tephra_index/lib/src/db/index_database.g.dart` **is committed** (so a fresh clone builds
  without running `build_runner`), and is re-formatted with `dart format` after every generation (generated output may differ from
  the SDK formatter; the format check in GEMINI.md §3 covers `packages/`).
- **Audio, video and PDF embeds:** shown as a **file chip** in Phase 2 (name, type icon, size; tap opens the file with the system
  application on Windows via `url_launcher`; on Android tap shows the message `embedMediaLaterPhase`). Real players
  (`just_audio`, video) and the PDF viewer (`pdfrx`) arrive in Phase 6.5. Reason: their Windows support needs extra native
  packages whose licences and stability belong to the Phase 6 media work.
- **Math in Live Preview/embeds:** rendered with whatever Phase 1's reading view uses for `MdInlineMath`/`MdMathBlock` (expected:
  monospace TeX source in a tinted box). Typeset math (`flutter_math_fork`) is Phase 6.4.

---

## Steps

### 02.1 Add drift + sqlite3 and prove FTS5, trigram and Bangla tokenisation

**Purpose:** before writing schema code, prove on this machine that the bundled SQLite has FTS5, the trigram tokenizer,
`contentless_delete`, and that the chosen unicode61 configuration keeps Bangla words whole.

**Files**
- `packages/tephra_index/pubspec.yaml` (dependencies added by command)
- `packages/tephra_index/test/sqlite_smoke_test.dart` (new)

**Implementation**
1. In `packages/tephra_index`: `dart pub add drift sqlite3 path logging` and `dart pub add dev:drift_dev dev:build_runner`.
   Then at the repo root: `flutter pub get`, then `dart run tool/check_licenses.dart`.
2. Run `dart pub deps --style=compact` in `packages/tephra_index` and confirm the resolved `sqlite3` version starts with `3.` or
   higher. Write the resolved versions of `drift`, `sqlite3`, `drift_dev`, `build_runner` into `PROGRESS.md` (step notes).
3. Write `sqlite_smoke_test.dart`. It opens a raw in-memory database with `sqlite3.openInMemory()` (from
   `package:sqlite3/sqlite3.dart`) — no drift yet — and closes it in `tearDown` (`close()`; in sqlite3 3.x `dispose()` was renamed).
   The tests (exact names):
   - `'sqlite version is at least 3.45'`: `SELECT sqlite_version() AS v` → parse `major.minor.patch`; expect
     `(major, minor) >= (3, 45)`. Log the version with `Logger('index')` at info level — never `print`.
   - `'fts5 is compiled in'`: `CREATE VIRTUAL TABLE t USING fts5(body)` succeeds; insert `'hello world'`;
     `SELECT rowid FROM t WHERE t MATCH 'hello'` returns 1 row.
   - `'contentless_delete works'`: `CREATE VIRTUAL TABLE c USING fts5(body, content='', contentless_delete=1)`; insert rowid 7
     `'alpha beta'`; `DELETE FROM c WHERE rowid = 7` succeeds; `MATCH 'alpha'` then returns 0 rows.
   - `'trigram finds substrings case-insensitively'`: `CREATE VIRTUAL TABLE g USING fts5(body, content='', contentless_delete=1, tokenize='trigram case_sensitive 0')`;
     insert `'The Meeting is on Monday'`; `MATCH '"eetin"'` → 1 row; `MATCH '"MEETING"'` → 1 row; `MATCH '"meetings"'` → 0 rows.
   - `'trigram finds Bangla substrings'`: same table; insert `'আমি বাংলায় গান গাই।'`; `MATCH '"বাংলা"'` → 1 row.
   - `'unicode61 with mark categories keeps Bangla words whole'`: create
     ```sql
     CREATE VIRTUAL TABLE w USING fts5(body, content='', contentless_delete=1,
       tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'");
     CREATE VIRTUAL TABLE wv USING fts5vocab('w', 'row');
     ```
     insert `'আমি বাংলায় গান গাই। কম্পিউটার'`; `SELECT term FROM wv ORDER BY term` must return exactly the 5 terms
     `{'আমি', 'বাংলায়', 'গান', 'গাই', 'কম্পিউটার'}` (compare as a `Set<String>`); `MATCH 'বাংলায়'` → 1 row; `MATCH 'কম্পিউটার'` → 1 row.
   - `'unicode61 folds Latin diacritics'`: same table; insert `'Café crème'`; `MATCH 'cafe'` → 1 row; `MATCH 'creme'` → 1 row.
   - `'default unicode61 splits Bangla (documents why categories is needed)'`: create a table with plain
     `tokenize='unicode61 remove_diacritics 2'` and the same Bangla text; assert the vocab term count is **greater than 5**.
     If this assertion fails (meaning default unicode61 already keeps Bangla whole), delete this one test and note it in `PROGRESS.md`;
     keep the `categories` option anyway (it is harmless).

**Decision (FTS design, used from step 02.2 on):**
- Two FTS5 tables, both **contentless** (`content=''`) with `contentless_delete=1`. *Contentless* because the note text already
  lives in the vault files; storing it again (external-content or normal tables) would double the database size, and every place
  that needs text (snippets, verification, unlinked mentions) reads the file anyway. `contentless_delete=1` makes per-row delete and
  re-insert possible, which incremental indexing needs.
- `fts_words` — `unicode61 remove_diacritics 2 categories 'L* N* Co M*'`, used by `NoteIndex.fullText` (word queries, bm25 ranking).
  The `M*` categories keep Bangla (and other Indic) words whole, because their vowel signs and virama are combining marks.
- `fts_trigram` — `trigram case_sensitive 0`, used by search and unlinked mentions. Obsidian's search matches **substrings**
  (`meet` finds `meeting`), which word tokens cannot do; trigram does it for terms of ≥ 3 characters, in any script.
- If the `'unicode61 with mark categories keeps Bangla words whole'` test fails on this machine: keep `fts_words` (it still serves Latin
  scripts), change that test to assert the trigram Bangla search instead, record "unicode61 cannot tokenise Bangla; Bangla served by
  fts_trigram" in `PROGRESS.md`, and continue. Search correctness does not depend on `fts_words`.

**Tests:** the 8 tests above.

**Verify**
```
cd packages/tephra_index; dart test test/sqlite_smoke_test.dart
```
All 8 pass (or 7 + the documented deletion). Then the standard format/analyze commands. Commit `phase 02.1: add drift and sqlite3, prove fts5 and bangla tokenising`.

**Pitfalls**
- First `dart test` after adding `sqlite3` 3.x runs its build hook (downloads/compiles SQLite); it can take a minute. That is normal.
- FTS5 `MATCH` strings use double quotes for phrases. In Dart, write SQL in single-quoted or raw (`r'''...'''`) strings and keep the
  inner `"` and `'` exactly as shown.
- Never use `print` in tests; `analyze --fatal-infos` fails on `avoid_print`.

---

### 02.2 Index schema: drift tables, FTS tables, indices, migrations, database open + recovery

**Purpose:** the complete database schema with versioning and a guaranteed rebuild path.

**Files**
- `packages/tephra_index/lib/src/db/tables.dart` (new)
- `packages/tephra_index/lib/src/db/fts.dart` (new)
- `packages/tephra_index/lib/src/db/index_database.dart` (new) + generated `index_database.g.dart`
- `packages/tephra_index/lib/src/db/open_index_database.dart` (new)
- `packages/tephra_index/test/db/index_database_test.dart` (new)

**Implementation**
1. Column naming: drift turns `lowerCamelCase` getters into `snake_case` columns. **Never** name columns `start` / `end`
   (`end` is an SQL keyword, and raw SQL in `tephra_search` would need quoting) — use `startOffset` / `endOffset`. Never name a getter
   `text` (it would shadow drift's `text()` builder) — use `headingText`, `taskText`, `valueText`. All offsets are UTF-16 offsets into
   the note text as normalised to `\n` (§7.3). All times are **milliseconds since epoch, UTC**, stored as integers. All `*Key` / `*Lower`
   columns are produced in Dart with `String.toLowerCase()` (never with SQL `lower()`, which is ASCII-only).
2. `tables.dart` — write exactly these tables (copyright header first line; doc comment on each class and column):
   ```dart
   // © 2026 Tephra. All rights reserved.
   import 'package:drift/drift.dart';

   /// Every vault file the indexer knows (notes and attachments).
   @DataClassName('FileRow')
   @TableIndex(name: 'files_case_key', columns: {#caseKey})
   @TableIndex(name: 'files_name_key', columns: {#nameKey})
   class Files extends Table {
     TextColumn get path => text()();               // VaultPath.value
     TextColumn get caseKey => text()();            // VaultPath.caseKey
     TextColumn get nameKey => text()();            // name.toLowerCase(), with extension: 'note.md', 'image.png'
     TextColumn get stemKey => text()();            // stem.toLowerCase(): 'note'
     TextColumn get folder => text()();             // parent value, '' for root
     TextColumn get extension => text()();          // 'md', 'png', '' (lower-case)
     IntColumn get size => integer()();
     IntColumn get mtime => integer()();            // ms UTC
     IntColumn get created => integer().nullable()(); // ms UTC, null if the platform has no creation time
     TextColumn get hash => text()();               // contentHash() of raw bytes
     BoolColumn get isNote => boolean()();          // extension == 'md'
     @override
     Set<Column<Object>> get primaryKey => {path};
   }

   /// One row per Markdown note. [id] is the rowid of both FTS tables.
   @DataClassName('NoteRow')
   class Notes extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get path => text().unique().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get title => text()();              // file stem (Obsidian's title is the file name)
     TextColumn get frontmatterJson => text()();    // jsonEncode(parsed.frontmatter), '{}' if none/invalid
     BoolColumn get frontmatterValid => boolean()();
     IntColumn get wordCount => integer()();
   }

   @DataClassName('AliasRow')
   @TableIndex(name: 'aliases_key', columns: {#aliasKey})
   class Aliases extends Table {
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get alias => text()();              // original case
     TextColumn get aliasKey => text()();           // alias.toLowerCase()
     IntColumn get ordinal => integer()();          // position in the aliases list
     @override
     Set<Column<Object>> get primaryKey => {path, ordinal};
   }

   @DataClassName('HeadingRow')
   @TableIndex(name: 'headings_path', columns: {#path})
   class Headings extends Table {
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     IntColumn get ordinal => integer()();          // 0-based order in the note
     IntColumn get level => integer()();            // 1..6
     TextColumn get headingText => text()();        // heading text without '#' markers and without a trailing ^blockid
     TextColumn get headingKey => text()();         // normalizeHeading(headingText), see step 02.5
     IntColumn get startOffset => integer()();
     IntColumn get endOffset => integer()();
     IntColumn get line => integer()();             // 0-based line of the heading
     @override
     Set<Column<Object>> get primaryKey => {path, ordinal};
   }

   @DataClassName('BlockRow')
   @TableIndex(name: 'blocks_key', columns: {#blockKey})
   class Blocks extends Table {
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get blockId => text()();            // without '^', original case
     TextColumn get blockKey => text()();           // blockId.toLowerCase()
     IntColumn get startOffset => integer()();      // range of the owning block
     IntColumn get endOffset => integer()();
     IntColumn get line => integer()();
     TextColumn get preview => text()();            // first 120 chars of the block text, single line
     @override
     Set<Column<Object>> get primaryKey => {path, blockId};
   }

   @DataClassName('LinkRow')
   @TableIndex(name: 'links_source', columns: {#source})
   @TableIndex(name: 'links_target_path', columns: {#targetPath})
   @TableIndex(name: 'links_target_key', columns: {#targetKey})
   class Links extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get source => text().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get targetRaw => text()();          // target exactly as written, without #subpath and |alias; '' for [[#Heading]]
     TextColumn get targetKey => text()();          // linkTargetKey(targetRaw), see step 02.5
     TextColumn get targetPath => text().nullable()(); // resolved VaultPath.value, null if unresolved
     TextColumn get kind => text()();               // 'link' | 'embed'
     TextColumn get syntax => text()();             // 'wiki' | 'markdown'
     TextColumn get heading => text().nullable()(); // 'H1#H2' chain as written, null if none
     TextColumn get blockRef => text().nullable()();// without '^'
     TextColumn get alias => text().nullable()();   // display text: wikilink alias or markdown link text
     TextColumn get embedSize => text().nullable()(); // '300' or '300x200'
     IntColumn get startOffset => integer()();      // whole link, including '!' for embeds
     IntColumn get endOffset => integer()();
     IntColumn get line => integer()();
     BoolColumn get resolved => boolean()();
     BoolColumn get viaAlias => boolean()();        // resolved through a frontmatter alias
   }

   @DataClassName('TagRow')
   @TableIndex(name: 'tags_lower', columns: {#tagLower})
   @TableIndex(name: 'tags_path', columns: {#path})
   class Tags extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get tag => text()();                // without '#', original case
     TextColumn get tagLower => text()();
     IntColumn get startOffset => integer().nullable()(); // null for frontmatter tags
     IntColumn get line => integer().nullable()();
   }

   @DataClassName('PropertyRow')
   @TableIndex(name: 'properties_key', columns: {#keyLower})
   @TableIndex(name: 'properties_path', columns: {#path})
   class Properties extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     TextColumn get key => text()();                // original case
     TextColumn get keyLower => text()();
     TextColumn get valueType => text()();          // inferred: text|multitext|number|checkbox|date|datetime|aliases|tags
     IntColumn get ordinal => integer()();          // element index for lists, 0 for scalars
     TextColumn get valueText => text().nullable()();  // string form; null for YAML null / empty list
     TextColumn get valueLower => text().nullable()(); // valueText?.toLowerCase()
     RealColumn get valueNum => real().nullable()();
     BoolColumn get valueBool => boolean().nullable()();
     TextColumn get valueDate => text().nullable()();  // 'YYYY-MM-DD' or 'YYYY-MM-DDTHH:mm[:ss]' as written
   }

   @DataClassName('TaskRow')
   @TableIndex(name: 'tasks_path', columns: {#path})
   class Tasks extends Table {
     IntColumn get id => integer().autoIncrement()();
     TextColumn get path => text().references(Files, #path, onDelete: KeyAction.cascade)();
     IntColumn get line => integer()();
     TextColumn get statusChar => text()();         // one character; ' ' = open
     TextColumn get taskText => text()();
     TextColumn get taskLower => text()();
     IntColumn get startOffset => integer()();
     IntColumn get endOffset => integer()();
     TextColumn get due => text().nullable()();     // 'YYYY-MM-DD' from '📅 YYYY-MM-DD' (Tasks plugin format), else null
   }

   /// Key/value facts about the index itself (parserVersion, lastReconcile, vaultRoot).
   @DataClassName('MetaRow')
   class IndexMeta extends Table {
     TextColumn get key => text()();
     TextColumn get value => text()();
     @override
     Set<Column<Object>> get primaryKey => {key};
   }
   ```
   Deviation from the plan's column list, on purpose: `files` has extra lookup columns (`nameKey`, `stemKey`, `folder`, `extension`,
   `created`); `notes` has an integer `id` (FTS rowid) besides the unique `path`; `links` has `targetKey`, `syntax`, `embedSize`,
   `line`, `viaAlias` (needed by the dirty-targets algorithm and rename rewriting).
3. `fts.dart` — constants and helpers:
   ```dart
   const String ftsWordsDdl = '''
   CREATE VIRTUAL TABLE IF NOT EXISTS fts_words USING fts5(
     name, body, content='', contentless_delete=1,
     tokenize="unicode61 remove_diacritics 2 categories 'L* N* Co M*'")''';
   const String ftsTrigramDdl = '''
   CREATE VIRTUAL TABLE IF NOT EXISTS fts_trigram USING fts5(
     name, body, content='', contentless_delete=1,
     tokenize='trigram case_sensitive 0')''';
   ```
   Column `name` = the note's file stem; column `body` = the full note text (normalised to `\n`, frontmatter included — Obsidian's
   search covers frontmatter text and the file name). Only notes (`*.md`) get FTS rows. Helper functions (top-level, documented):
   `Future<void> ftsInsert(DatabaseConnectionUser db, int noteId, String name, String body)` runs
   `INSERT INTO fts_words(rowid, name, body) VALUES (?, ?, ?)` and the same for `fts_trigram`;
   `Future<void> ftsDelete(DatabaseConnectionUser db, int noteId)` runs `DELETE FROM fts_words WHERE rowid = ?` and the same for
   `fts_trigram`. (Use `db.customStatement(sql, [args])`.)
4. `index_database.dart`:
   ```dart
   @DriftDatabase(tables: [Files, Notes, Aliases, Headings, Blocks, Links, Tags, Properties, Tasks, IndexMeta])
   class TephraIndexDatabase extends _$TephraIndexDatabase {
     TephraIndexDatabase(super.e);
     /// Bump when the schema changes. Any change rebuilds the index from scratch (it is a cache).
     @override
     int get schemaVersion => 1;
     /// Bump when extraction output changes (parser or NoteExtractor); a mismatch forces a full rebuild on open.
     static const int parserVersion = 1;
     @override
     MigrationStrategy get migration => MigrationStrategy(
       onCreate: (m) async { await m.createAll(); await customStatement(ftsWordsDdl); await customStatement(ftsTrigramDdl); },
       onUpgrade: (m, from, to) async { await _dropEverything(m); await m.createAll();
         await customStatement(ftsWordsDdl); await customStatement(ftsTrigramDdl); },
       beforeOpen: (details) async { await customStatement('PRAGMA foreign_keys = ON'); },
     );
   }
   ```
   `_dropEverything` drops `fts_words`, `fts_trigram` (`DROP TABLE IF EXISTS`) and every drift table in **child-first** order
   (`links, tags, properties, tasks, headings, blocks, aliases, notes, files, index_meta`) using `m.deleteTable(name)` or
   `customStatement('DROP TABLE IF EXISTS <name>')`. Downgrades (opening a DB whose `user_version` is newer than `schemaVersion`) also
   go through the delete-and-recreate path in step 6. **Decision:** no incremental migrations ever — the index is a rebuildable cache, so
   a schema change simply drops and recreates everything and triggers a full index. This is simpler and cannot leave a half-migrated DB.
5. Generate: in `packages/tephra_index` run `dart run build_runner build --delete-conflicting-outputs`, then
   `dart format lib/src/db/index_database.g.dart`. Commit the `.g.dart`.
6. `open_index_database.dart`:
   ```dart
   /// Result of opening: the database plus whether it was (re)created empty and therefore needs a full index.
   final class OpenedIndexDatabase { const OpenedIndexDatabase(this.db, {required this.needsFullIndex}); final TephraIndexDatabase db; final bool needsFullIndex; }
   /// Opens [dbFile] synchronously-on-this-isolate (used by the worker isolate and by tests).
   Future<OpenedIndexDatabase> openIndexDatabase(String dbFile);
   /// Opens an in-memory database (tests, in-process runner).
   Future<OpenedIndexDatabase> openMemoryIndexDatabase();
   /// Opens [dbFile] for reading from the UI isolate; SQLite runs in a drift background isolate.
   TephraIndexDatabase openReaderIndexDatabase(String dbFile);
   ```
   Behaviour of `openIndexDatabase`:
   1. Create the parent folder of `dbFile` if missing (`Directory(p.dirname(dbFile)).create(recursive: true)`).
   2. Build `NativeDatabase(File(dbFile), setup: _setup)` where `_setup(Database raw)` executes, in order:
      `PRAGMA journal_mode = WAL`, `PRAGMA synchronous = NORMAL`, `PRAGMA foreign_keys = ON`, `PRAGMA busy_timeout = 5000`,
      `PRAGMA temp_store = MEMORY`, `PRAGMA cache_size = -16000`.
   3. Open by running `SELECT value FROM index_meta WHERE key = 'parserVersion'` inside `try`. drift runs the migration on first use.
   4. If the query (or migration) throws any `Exception` (corrupt file, `SqliteException`, downgrade `user_version`): close the database,
      delete `dbFile`, `dbFile-wal`, `dbFile-shm` (ignore missing), log a warning `index database unreadable, recreating`, and retry
      steps 2–3 **once**. A second failure rethrows as `IndexCorruptException extends TephraException` (define it in
      `packages/tephra_index/lib/src/index_exceptions.dart`).
   5. `needsFullIndex` is true when: the DB was just created (no `parserVersion` row), or the stored `parserVersion` differs from
      `TephraIndexDatabase.parserVersion`, or the file was recreated in step 4. When the stored parser version differs, delete all rows
      from every table (child-first) and both FTS tables before returning. Then write the current `parserVersion` row.
   `openReaderIndexDatabase` uses `NativeDatabase.createInBackground(File(dbFile), setup: _readerSetup)` with
   `PRAGMA busy_timeout = 5000` and `PRAGMA query_only = ON`. It must only be called **after** the worker has opened (and migrated) the
   file — `NoteIndex.open` guarantees this order (step 02.7).
7. Where the file lives (app, step 02.9): `<appSupportDir>/index/<vaultId>.sqlite` (§6.6), `appSupportDir` from
   `getApplicationSupportDirectory()`. Never inside the vault.

**Tests** (`index_database_test.dart`, all with temp directories from `Directory.systemTemp.createTemp('tephra_idx_')`, deleted in `tearDown`):
- `'fresh database needs full index and has all tables'`: open → `needsFullIndex == true`; `SELECT name FROM sqlite_master WHERE type IN ('table')`
  contains all 10 drift tables + `fts_words` + `fts_trigram`.
- `'reopen does not need full index'`: open, close, open → `needsFullIndex == false`.
- `'parser version change wipes rows'`: open, insert a `files` row, update `index_meta.parserVersion` to `'0'`, close, reopen →
  `needsFullIndex == true` and `files` is empty.
- `'corrupt file is recreated'`: write the bytes `'not a database'` to `dbFile`, open → succeeds, `needsFullIndex == true`.
- `'foreign key cascade deletes children'`: insert a file + note + heading + link rows for `A.md`; `DELETE FROM files WHERE path='A.md'`
  → headings/links/notes rows for `A.md` are gone.
- `'fts insert and delete'`: `ftsInsert(db, 1, 'Note', 'Meeting minutes')`; `SELECT rowid FROM fts_trigram WHERE fts_trigram MATCH '"eeting"'` → `[1]`;
  `ftsDelete(db, 1)` → 0 rows.
- `'wal mode is on'`: `PRAGMA journal_mode` → `wal`.

**Verify:** `cd packages/tephra_index; dart test`. All pass. `flutter analyze --fatal-infos` at the root is clean (the `.g.dart` is excluded
by `analysis_options.yaml`). Commit `phase 02.2: add index schema, fts tables and recovery`.

**Pitfalls**
- `contentless_delete` tables reject `UPDATE`; always delete + insert.
- drift's `@TableIndex` needs a recent drift; if the annotation is unknown, create the same indices with `customStatement('CREATE INDEX IF NOT EXISTS ...')`
  in `onCreate` and note it.
- `PRAGMA journal_mode = WAL` must run outside a transaction — that is why it is in `setup`, not in `beforeOpen`.
- Run `build_runner` from `packages/tephra_index`, not from the root.

---

### 02.3 Index models and `LineIndex`

**Purpose:** the immutable value types that cross the `NoteIndex` boundary, and the offset → line helper.

**Files** (all new, in `packages/tephra_index/lib/src/model/` unless stated; one public type per file, named after the file)
`note_summary.dart`, `file_record.dart`, `link_record.dart`, `unlinked_mention.dart`, `tag_count.dart`, `heading_record.dart`,
`block_record.dart`, `alias_record.dart`, `task_record.dart`, `fts_hit.dart`, `property_key_count.dart`, `index_progress.dart`,
`index_event.dart`, `index_options.dart`, `index_stats.dart`; `packages/tephra_index/lib/src/util/line_index.dart`;
`packages/tephra_index/lib/tephra_index.dart` (export lines); tests `test/model/models_test.dart`, `test/util/line_index_test.dart`.

**Implementation**
1. All models: `final class`, `final` fields, `const` constructor, `==`/`hashCode` via `Object.hash`/`Object.hashAll`, `toString()`
   (no note content in `toString`; paths are fine). No JSON needed except `IndexProgress` (none needed either — they cross isolates as
   objects). Fields:
   - `NoteSummary { VaultPath path; String title; int size; DateTime modified; DateTime? created; int wordCount; List<String> aliases; List<String> tags; }`
   - `FileRecord { VaultPath path; int size; DateTime modified; DateTime? created; bool isNote; }`
   - `enum LinkKind { link, embed }`, `enum LinkSyntax { wiki, markdown }` (put both in `link_record.dart`; enums may share the file).
   - `LinkRecord { VaultPath source; String targetRaw; VaultPath? targetPath; LinkKind kind; LinkSyntax syntax; String? heading; String? blockRef; String? alias; String? embedSize; int start; int end; int line; bool resolved; bool viaAlias; }`
   - `UnlinkedMention { VaultPath source; int start; int end; int line; String matchedText; String snippet; int snippetStart; int snippetEnd; }`
     (`snippetStart/End` = range of the match inside `snippet`).
   - `TagCount { String tag /* display form: the most frequent original casing, ties → first alphabetically */; String tagLower; int count /* distinct notes having this tag or a descendant */; int directCount /* distinct notes having exactly this tag */; }`
   - `HeadingRecord { VaultPath path; int level; String text; int start; int end; int line; int ordinal; }`
   - `BlockRecord { VaultPath path; String id; int start; int end; int line; String preview; }`
   - `AliasRecord { VaultPath path; String alias; }`
   - `TaskRecord { VaultPath path; int line; String statusChar; String text; int start; int end; String? due; bool get done => statusChar != ' '; }`
   - `FtsHit { VaultPath path; double rank; }` (bm25; lower is better).
   - `PropertyKeyCount { String key; String valueType; int count; }`
   - `enum IndexPhase { idle, scanning, indexing, resolving, done }`; `IndexProgress { IndexPhase phase; int done; int total; }`.
   - `IndexEvent { Set<VaultPath> changedPaths; bool fullRebuild; }` — emitted after every committed index transaction.
   - `IndexOptions { List<String> excludedFolders = const []; int batchSize = 200; }` — `excludedFolders` are vault-relative folder
     paths (`'Archive/Old'`); a file is excluded when `path.isWithin(VaultPath(folder))` for any entry.
   - `IndexStats { int files; int notes; int links; int unresolvedLinks; int tags; }`.
2. `LineIndex` (skip creating it if Phase 1 already has an equivalent in `tephra_markdown`; then use that and re-export nothing):
   ```dart
   /// Maps UTF-16 offsets to 0-based line numbers and back for a '\n'-normalised text.
   final class LineIndex {
     LineIndex(String text);                 // records the offset of every line start (0 and each index after '\n')
     int get lineCount;                      // text '' → 1; 'a\n' → 2
     int lineOf(int offset);                 // binary search; offset == text.length → last line; throws RangeError if < 0 or > length
     int lineStart(int line);
     int lineEnd(int line);                  // offset of the '\n' ending the line, or text.length for the last line
     String lineText(String text, int line); // without '\n'
   }
   ```
3. `tephra_index.dart` exports every model, `LineIndex`, and (in later steps) `NoteIndex`, `LinkResolver`, `NameTable`,
   `LinkFormatter`, `LinkFormatSettings`, `RenamePlanner`, `TextEdit`, `FileEdit`, `IndexCorruptException`. It does **not** export
   the drift database or tables.

**Tests**
- `line_index_test.dart`: `''` → `lineCount 1`, `lineOf(0) == 0`; `'a\nb\n'` → `lineCount 3`, `lineOf(0)=0, lineOf(1)=0, lineOf(2)=1, lineOf(4)=2`,
  `lineStart(1)=2`, `lineEnd(1)=3`, `lineText(t,1)=='b'`; `lineOf(-1)` throws `RangeError`; a 100,000-line text: `lineOf` of the last
  offset returns 99,999 (and the test runs < 50 ms).
- `models_test.dart`: equality and hashCode for `LinkRecord` (two equal instances equal; changing `resolved` makes them differ);
  `TaskRecord('x').done == true`, `TaskRecord(' ').done == false`.

**Verify:** `cd packages/tephra_index; dart test`. Commit `phase 02.3: add index models and line index`.

**Pitfalls:** `List` fields break `==` if compared by identity — use `Object.hashAll` and a list-equality helper (write a private
`_listEquals`; do not add `collection` just for this unless it is already a dependency).

---

### 02.4 Note extraction: `ParsedNote` → index rows

**Purpose:** a pure, deterministic function that turns one parsed note into everything the index stores. The indexer, the fuzz test's
"fresh rebuild" and the incremental path all use this one function, so they cannot disagree.

**Files**
- `packages/tephra_index/lib/src/extract/extracted_note.dart`, `note_extractor.dart`, `property_typing.dart`, `word_counter.dart`,
  `link_target_key.dart` (all new)
- tests: `test/extract/note_extractor_test.dart`, `test/extract/property_typing_test.dart`, `test/extract/word_counter_test.dart`

**Implementation**
1. `ExtractedNote` (plain immutable data, no drift types):
   ```dart
   final class ExtractedNote {
     final String title; final String frontmatterJson; final bool frontmatterValid; final int wordCount;
     final List<String> aliases;                       // trimmed, empty strings dropped, duplicates (case-insensitive) dropped keeping first
     final List<ExtractedHeading> headings;            // level, text, key, start, end, line, ordinal
     final List<ExtractedBlock> blocks;                // id, start, end, line, preview
     final List<ExtractedLink> links;                  // everything of LinkRecord except targetPath/resolved/viaAlias
     final List<ExtractedTag> tags;                    // tag, start?, line?
     final List<ExtractedProperty> properties;         // key, valueType, ordinal, valueText, valueNum, valueBool, valueDate
     final List<ExtractedTask> tasks;                  // line, statusChar, text, start, end, due
     final String ftsName; final String ftsBody;       // stem; full text
   }
   ```
   (Each `Extracted*` is a small `final class` in `extracted_note.dart` — the "one public type per file" rule allows small companion types
   in the same file because they are not exported.)
2. `abstract final class NoteExtractor { static ExtractedNote extract(VaultPath path, ParsedNote parsed); }` rules:
   - **title** = `path.stem`.
   - **frontmatterJson** = `jsonEncode(parsed.frontmatter)`; values YAML cannot express in JSON (none expected, since the parser already
     decoded to Dart primitives/lists/maps) → convert with `toString()`. `'{}'` when empty or invalid.
   - **aliases** = `parsed.aliases` cleaned as described.
   - **headings**: for each `MdHeading` in `parsed.headings` (document order, `ordinal` from 0): `text` = the heading's inline text content
     (concatenate `MdText` and the visible text of inline children; drop a trailing `MdBlockId`), trimmed; `key` = `normalizeHeading(text)`
     (defined in step 02.5 — import it); `line` via `LineIndex`.
   - **blocks**: for each `BlockRef`: `start/end` = owning block range. If Phase 1's `BlockRef` gives only the `^id` text range, find the
     owning block: the innermost `MdParagraph`, `MdListItem` or `MdHeading` whose range contains the `^id` start; if the `^id` stands alone on
     its own line directly after a table, block quote, callout or code block (no blank line between), the owner is that preceding block. If
     no owner is found, use the line containing the `^id`. `preview` = owner text with newlines replaced by spaces, `^id` removed, trimmed,
     cut to 120 characters.
   - **links**: walk the whole AST (`root` recursively) in document order:
     - `MdWikiLink` → `syntax: wiki`, `kind: embed ? embed : link`, `targetRaw` = `target` (trimmed; may be `''` for `[[#Heading]]`),
       `heading`, `blockRef`, `alias`, `embedSize` = size formatted as `'W'` or `'WxH'` (null if none), `start/end` = node range.
     - `MdLink` whose `url` is **internal** → `syntax: markdown`, `kind: image ? embed : link`, `targetRaw` = URL-decoded path part before the
       first `#` (decode with `Uri.decodeComponent`; on `ArgumentError`/`FormatException` keep the raw text); `heading`/`blockRef` from the
       fragment (`#^id` → blockRef `id`; `#Some%20Heading` → heading `Some Heading` decoded); `alias` = link text (concatenated visible inline text).
       A URL is **internal** when it has no scheme (`!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url)`), does not start with `//`, `#` alone
       counts as same-note heading link (targetRaw `''`). `mailto:`, `http:`, `https:`, `file:`, `obsidian:` and every other scheme are external
       and are **not** stored.
     - `MdAutolink` and external links are not stored. Links inside code (`MdInlineCode`, `MdCodeBlock`) and comments (`MdCommentInline`,
       `MdCommentBlock`) never appear because the parser does not produce link nodes there; do not add special handling.
     - `targetKey` = `linkTargetKey(targetRaw)` (below). `line` via `LineIndex`.
   - **tags**: inline `MdTag` nodes → tag `name`, `start`, `line`. Frontmatter tags: from `parsed.frontmatter['tags']` (also key `tag`, as
     Obsidian accepts both): a list → each element `toString()`; a string → split on commas and whitespace; strip a leading `#`; drop empty;
     `start = null`, `line = null`. Do not de-duplicate (counts are per note anyway; the tags query uses `DISTINCT path`).
   - **properties**: one or more rows per top-level frontmatter key (in map order), typed by `inferPropertyRows(key, value)` from
     `property_typing.dart`:
     | YAML value | `valueType` | rows |
     |---|---|---|
     | key `tags`/`tag` (any value) | `tags` | one row per tag string (cleaned as above) |
     | key `aliases`/`alias` (any value) | `aliases` | one row per alias |
     | `bool` | `checkbox` | 1 row, `valueBool`, `valueText` `'true'`/`'false'` |
     | `int`/`double` | `number` | 1 row, `valueNum`, `valueText` = `value.toString()` |
     | `String` matching `^\d{4}-\d{2}-\d{2}$` | `date` | 1 row, `valueDate` = `valueText` = the string |
     | `String` matching `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$` | `datetime` | 1 row, same |
     | other `String` | `text` | 1 row |
     | `List` (non-empty) | `multitext` | one row per element; element → `toString()`; `ordinal` = index |
     | empty `List` | `multitext` | 1 row, `valueText` null |
     | `null` | `text` | 1 row, `valueText` null |
     | `Map` | `text` | 1 row, `valueText` = `jsonEncode(value)` |
     `valueLower` = `valueText?.toLowerCase()`. Invalid frontmatter (`frontmatterValid == false`) → no properties, no frontmatter tags/aliases.
   - **tasks**: each `TaskItem` → `statusChar` (single character), `text` (trimmed), `start/end`, `line` (line of `start`),
     `due` = first match of `RegExp(r'📅\s*(\d{4}-\d{2}-\d{2})')` in the text, else null.
   - **wordCount** (`word_counter.dart`): count matches of `RegExp(r"[\p{L}\p{N}\p{M}][\p{L}\p{N}\p{M}'’_-]*", unicode: true)` in the text
     **after** the frontmatter (`MdFrontmatter.contentStart`, or 0). Examples: `'Hello, world!'` → 2; `"don't stop"` → 2; `'আমি বাংলায় গান গাই।'` → 4;
     `'---\ntitle: x\n---\nOne two'` → 2; `''` → 0.
   - **ftsName** = `path.stem`; **ftsBody** = `parsed.text`.
3. `link_target_key.dart`:
   ```dart
   /// Key used to find links whose resolution may change when a file named like [targetRaw] appears or disappears.
   /// Last path segment, lower-case, with a trailing '.md' removed. '' for same-note links.
   String linkTargetKey(String targetRaw);
   /// Keys a file contributes: notes → {stemKey}; other files → {nameKey}. ('Folder/Note.md' → {'note'}; 'img/a.png' → {'a.png'})
   Set<String> fileTargetKeys(VaultPath path);
   ```
   Algorithm of `linkTargetKey`: replace `\` with `/`; trim; strip trailing `/`; take the substring after the last `/`; lower-case; if it ends
   with `.md` remove those 3 characters. Examples: `'Folder/Note'` → `'note'`; `'Note.md'` → `'note'`; `'../a/Image.PNG'` → `'image.png'`;
   `'v1.2 release'` → `'v1.2 release'`; `''` → `''`.

**Tests**
- `note_extractor_test.dart` — parse fixture strings with `MarkdownParser.parse` and assert extracted rows:
  1. `'# Title\nText [[Other]] and ![[img.png|300]].'` → headings `[('Title', level 1, line 0)]`; links: `Other` (wiki, link, key `'other'`,
     line 1), `img.png` (wiki, embed, size `'300'`, key `'img.png'`).
  2. `'[[Note#Sec|Shown]] [[#Local]] [[Note#^abc]]'` → heading `'Sec'` + alias `'Shown'`; targetRaw `''` heading `'Local'`; blockRef `'abc'`.
  3. `'[a](Folder/My%20Note.md#Part%20Two) [b](https://x.y) [c](mailto:a@b) ![i](pics/p.png)'` → exactly 2 links: markdown link targetRaw
     `'Folder/My Note.md'` heading `'Part Two'` alias `'a'`; markdown embed `'pics/p.png'`.
  4. Frontmatter `'---\ntags: [a, "#b"]\naliases: First\nstatus: draft\nn: 3\ndone: true\nd: 2026-10-11\ndt: 2026-10-11T09:30\nlist: [x, y]\nempty:\n---\nBody #c'`
     → tags `a`, `b` (frontmatter, start null), `c` (inline, line 11); aliases `['First']`; property rows: `status` text, `n` number 3.0,
     `done` checkbox true, `d` date, `dt` datetime, `list` multitext 2 rows, `empty` text null, plus `tags` (2 rows, type tags) and `aliases` (1 row).
  5. `'- [ ] call Bob 📅 2026-10-20\n- [x] done\n- [/] half'` → 3 tasks: statuses `' '`, `'x'`, `'/'`; first `due == '2026-10-20'`.
  6. `'Para one ^p1\n\n- item ^i1\n\n| a |\n|---|\n| b |\n^t1'` → blocks `p1` (paragraph), `i1` (list item), `t1` (table range).
  7. Invalid YAML `'---\na: [\n---\nx'` → `frontmatterValid == false`, no properties, frontmatterJson `'{}'`.
  8. `'`[[NotALink]]`\n```\n[[Nope]]\n```'` → 0 links.
- `property_typing_test.dart`: one test per table row above.
- `word_counter_test.dart`: the 5 examples above.

**Verify:** `cd packages/tephra_index; dart test`. Commit `phase 02.4: add note extractor`.

**Pitfalls**
- Keep `extract` pure: no I/O, no clock, no randomness. The fuzz test depends on it being deterministic.
- `jsonEncode` fails on `DateTime`; the YAML decoder in Phase 1 should produce strings for dates — if it produces `DateTime`, convert to the
  ISO string first (and note it).

---

### 02.5 Link resolver, `NameTable`, heading and block matching

**Purpose:** resolve link targets exactly like Obsidian, as a pure algorithm with an in-memory lookup, tested by a 38-case matrix.

**Files**
- `packages/tephra_index/lib/src/links/name_table.dart`, `link_resolver.dart`, `resolved_target.dart`, `heading_matcher.dart` (new)
- tests: `test/links/link_resolver_test.dart`, `test/links/heading_matcher_test.dart`, `test/links/name_table_test.dart`

**Implementation**
1. `NameTable` — in-memory lookup of every vault file and alias:
   ```dart
   final class NameTable implements LinkTargetLookup {
     NameTable();
     factory NameTable.from(Iterable<VaultPath> files, Map<VaultPath, List<String>> aliases);
     void addFile(VaultPath path); void removeFile(VaultPath path);
     void setAliases(VaultPath note, List<String> aliases);   // replaces; [] removes
     @override VaultPath? byCaseKey(String caseKey);         // exact path, lower-case
     @override List<VaultPath> byNameKey(String nameKey);    // files whose name.toLowerCase() == nameKey
     @override List<VaultPath> byAliasKey(String aliasKey);  // notes having an alias whose toLowerCase() == aliasKey
     NameTable copy();                                       // deep copy, used to simulate a rename
     Iterable<VaultPath> get files;
   }
   abstract interface class LinkTargetLookup { VaultPath? byCaseKey(String k); List<VaultPath> byNameKey(String k); List<VaultPath> byAliasKey(String k); }
   ```
   Internals: `Map<String, VaultPath> _byCase`, `Map<String, Set<VaultPath>> _byName`, `Map<String, Set<VaultPath>> _byAlias`,
   `Map<VaultPath, List<String>> _aliasesOf`. If two files differ only by case (possible on Android), `_byCase` keeps the one that sorts first
   by `VaultPath.value` (and both are in `_byName`).
2. `ResolvedTarget { VaultPath path; bool viaAlias; }`.
3. `LinkResolver`:
   ```dart
   final class LinkResolver {
     const LinkResolver(this.lookup);
     final LinkTargetLookup lookup;
     /// [target] is the link path only: no '#subpath', no '|alias', already URL-decoded for markdown links.
     ResolvedTarget? resolve(String target, {required VaultPath from});
   }
   ```
   Algorithm (implement exactly; every step is case-insensitive through `caseKey`/`nameKey`):
   1. `t = target.trim().replaceAll('\\', '/')`. If `t` is empty → return `ResolvedTarget(from, viaAlias: false)` (same-note link).
   2. `absoluteOnly = t.startsWith('/')`; if so strip all leading `/`. `relativeOnly = t.startsWith('./') || t.startsWith('../')`.
   3. Candidate spellings `C`: if `t.toLowerCase().endsWith('.md')` → `[t]`; otherwise → `[t + '.md', t]` (in this order: a note wins over a
      same-named extension-less file).
   4. **Step A — exact vault path** (skipped when `relativeOnly`): for each `c` in `C`: `vp = tryVaultPath(c)` (catch `InvalidPathException` → skip);
      `hit = lookup.byCaseKey(vp.caseKey)`; if non-null → return it.
   5. If `absoluteOnly` → return null.
   6. **Step B — relative to the source folder**: `base = from.parent` (root if null). For each `c` in `C`: `vp = tryVaultPath(base.value.isEmpty ? c : '${base.value}/$c')`
      (the `VaultPath` factory normalises `.` and `..`; escaping above the root throws → skip); `byCaseKey` → return if found.
   7. If `relativeOnly` → return null.
   8. **Step C — by file name anywhere**: for each `c` in `C` (stop at the first `c` that yields matches): `name = lastSegment(c).toLowerCase()`;
      `matches = lookup.byNameKey(name)`; if `c` contains `/`, keep only matches whose `caseKey` equals `c.toLowerCase()` or ends with
      `'/' + c.toLowerCase()` (suffix match on a segment boundary, so `[[Sub/Note]]` finds `A/Sub/Note.md` but not `A/XSub/Note.md`).
      If `matches` is non-empty → return `pickShortest(matches)`.
   9. **Step D — aliases** (only when `t` contains no `/`): `matches = lookup.byAliasKey(t.toLowerCase())` (the alias key is the target text
      as written, **without** adding `.md`); if non-empty → return `ResolvedTarget(pickShortest(matches), viaAlias: true)`.
   10. Return null (unresolved).
   `pickShortest(list)`: sort by (number of path segments ascending, then `caseKey` ascending, then `value` ascending) and take the first.
   Do **not** filter by extension in step C: `[[photo.png]]` matches `photo.png`; `[[Note]]` produces candidates `Note.md` then `Note`, so it
   matches `Note.md` (and a file literally named `Note` only if no `Note.md` exists anywhere). `[[Note]]` never matches `Note.canvas`.
4. `heading_matcher.dart`:
   ```dart
   /// Obsidian-style heading normalisation for matching: removes the characters # | ^ : % [ ] \ and the sequence '%%',
   /// collapses runs of whitespace to one space, trims, lower-cases.
   String normalizeHeading(String text);
   /// Resolves 'H1' or a chain 'H1#H2#H3' against [headings] (document order). Each next heading must come after the previous one and have
   /// a deeper level than it. Returns the last matched heading, or null.
   HeadingRecord? findHeading(List<HeadingRecord> headings, String headingChain);
   /// Case-insensitive block id lookup ('^' stripped if present).
   BlockRecord? findBlock(List<BlockRecord> blocks, String blockRef);
   /// Section range of [heading]: from heading.start to the start of the next heading with level <= heading.level, or [textLength].
   (int, int) sectionRange(List<HeadingRecord> headings, HeadingRecord heading, int textLength);
   ```

**Tests**
- `link_resolver_test.dart` — build `NameTable.from` with this vault (aliases in brackets):
  ```
  Note.md
  Folder/Note.md
  Folder/Sub/Deep.md
  Other/Deep.md
  a/b/Note.md
  Projects/Alpha.md            [aliases: A1, Project Alpha]
  Beta.md                      [aliases: Alpha, Gamma]
  Gamma Notes/Gamma.md
  Images/photo.png
  photo.png.md
  Café.md
  বাংলা নোট.md
  v1.2 release.md
  README
  Assets/diagram.canvas
  Daily/2026-10-11.md
  Archive/2026-10-11.md
  UPPER.md
  Folder/Sub/Same.md
  Same.md
  ```
  Then one `test(...)` per row (name = `'#NN <target> from <source>'`):

  | # | target | from | expected | reason |
  |---|---|---|---|---|
  | 01 | `Note` | `X.md` | `Note.md` | name match, shortest path (root) |
  | 02 | `note` | `X.md` | `Note.md` | case-insensitive |
  | 03 | `Note.md` | `X.md` | `Note.md` | explicit extension |
  | 04 | `Folder/Note` | `X.md` | `Folder/Note.md` | exact path |
  | 05 | `folder/NOTE.md` | `X.md` | `Folder/Note.md` | exact path, case-insensitive |
  | 06 | `Note` | `Folder/Y.md` | `Note.md` | step A: `Note.md` is an exact vault path, checked before step B |
  | 07 | `b/Note` | `X.md` | `a/b/Note.md` | suffix match on segment boundary |
  | 08 | `/Note` | `Folder/Y.md` | `Note.md` | leading slash = vault root only |
  | 09 | `/Missing` | `X.md` | null | absolute, no fallback |
  | 10 | `Deep` | `X.md` | `Other/Deep.md` | fewer segments wins |
  | 11 | `Deep` | `Folder/Sub/Z.md` | `Folder/Sub/Deep.md` | step B |
  | 12 | `../Note` | `Folder/Sub/Z.md` | `Folder/Note.md` | relative `..` |
  | 13 | `./Deep` | `Other/Z.md` | `Other/Deep.md` | relative `./` |
  | 14 | `./Note` | `Other/Z.md` | null | relativeOnly, no name fallback |
  | 15 | `../../../Note` | `Folder/Z.md` | null | escapes root → skipped → null |
  | 16 | `Alpha` | `X.md` | `Projects/Alpha.md` (viaAlias false) | file beats alias `Alpha` of Beta |
  | 17 | `A1` | `X.md` | `Projects/Alpha.md` (viaAlias true) | alias |
  | 18 | `project alpha` | `X.md` | `Projects/Alpha.md` (viaAlias true) | alias, case-insensitive |
  | 19 | `Gamma` | `X.md` | `Gamma Notes/Gamma.md` (viaAlias false) | file beats alias `Gamma` |
  | 20 | `Projects/A1` | `X.md` | null | aliases never match a path with `/` |
  | 21 | `photo.png` | `X.md` | `photo.png.md` | candidate `photo.png.md` is tried first |
  | 22 | `Images/photo.png` | `X.md` | `Images/photo.png` | exact path (`.md` spelling misses) |
  | 23 | `cafe` | `X.md` | null | no diacritic folding |
  | 24 | `Café` | `X.md` | `Café.md` | unicode name |
  | 25 | `বাংলা নোট` | `X.md` | `বাংলা নোট.md` | Bangla name |
  | 26 | `v1.2 release` | `X.md` | `v1.2 release.md` | dot in name is not an extension |
  | 27 | `README` | `X.md` | `README` | extension-less file found by second candidate |
  | 28 | `diagram` | `X.md` | null | `.canvas` needs its extension |
  | 29 | `diagram.canvas` | `X.md` | `Assets/diagram.canvas` | non-md file by name |
  | 30 | `2026-10-11` | `X.md` | `Archive/2026-10-11.md` | tie on segment count → alphabetical caseKey (`archive/...` < `daily/...`) |
  | 31 | `2026-10-11` | `Daily/T.md` | `Daily/2026-10-11.md` | step B |
  | 32 | `upper` | `X.md` | `UPPER.md` | case-insensitive |
  | 33 | `Same` | `Folder/Sub/Q.md` | `Same.md` | step A (root exact path) beats step B |
  | 33b | `Sub/Same` | `Folder/Q.md` | `Folder/Sub/Same.md` | step B with a folder part |
  | 34 | `` (empty) | `Folder/Note.md` | `Folder/Note.md` | same-note link |
  | 35 | `Missing Note` | `X.md` | null | unresolved |
  | 36 | `  Note  ` | `X.md` | `Note.md` | trimmed |
  | 37 | `Folder\Note` | `X.md` | `Folder/Note.md` | backslash normalised |
- `heading_matcher_test.dart`: `normalizeHeading('  My: [Big]  Heading ')` == `'my big heading'`; `normalizeHeading('A#B|C^D')` == `'abcd'`;
  `findHeading` for headings `[H1 'Intro'(1), H2 'Setup'(2), H1 'Usage'(1), H2 'Setup'(2)]`: `'setup'` → first Setup (ordinal 1);
  `'Usage#Setup'` → ordinal 3; `'Intro#Usage'` → null (Usage is not deeper); `'Missing'` → null. `findBlock(..., '^ABC')` matches id `abc`.
  `sectionRange` of `Intro` in that list = `(Intro.start, Usage.start)`; of the last `Setup` = `(Setup.start, textLength)`.
- `name_table_test.dart`: add/remove/setAliases update all three lookups; `copy()` is independent (mutating the copy leaves the original unchanged);
  two files `a.md` and `A.md` → `byNameKey('a.md')` has 2 entries, `byCaseKey('a.md')` returns `A.md` (sorts first: `'A' < 'a'`).

**Verify:** `cd packages/tephra_index; dart test test/links`. All 38 matrix cases (01–37 plus 33b) + other tests pass. Commit `phase 02.5: add obsidian link resolver`.

**Pitfalls**
- Do not resolve through the file system; the resolver only consults the lookup. The same algorithm runs on the worker (`NameTable`) and
  in the rename planner (a modified `NameTable.copy()`), so results agree.
- Unicode normalisation (NFC vs NFD names from macOS-created vaults) is **not** handled in Phase 2; note it under "Ideas" if you meet it.

### 02.6 `IndexerCore`: full index, reconcile, incremental updates, dirty targets (in-process)

**Purpose:** all indexing logic in one isolate-agnostic class, tested in-process on `MemoryVaultFileSystem`.

**Files**
- `packages/tephra_index/lib/src/indexer/indexer_core.dart`, `ignore_rules.dart` (new)
- `packages/tephra_index/lib/src/links/name_table.dart` (add `List<String> aliasesOf(VaultPath note)`)
- tests: `test/indexer/indexer_core_test.dart`, `test/indexer/ignore_rules_test.dart`

**Implementation**
1. `ignore_rules.dart`: `bool isIndexable(VaultPath path, IndexOptions options)` → false when any path segment starts with `.` (covers
   `.obsidian`, `.tephra`, `.trash`, `.git` and hidden files), when any segment equals `node_modules`, or when the path is within any
   `options.excludedFolders` entry (compare with `caseKey` so `archive/old` excludes `Archive/Old/x.md`). Otherwise true. The indexer applies
   this even if `fs.list` already filters, so the index never depends on Phase 1's filter details.
2. Class shape:
   ```dart
   final class IndexerCore {
     IndexerCore({required this.db, required this.fs, required this.options, required this.clock,
                  required this.onProgress, required this.onEvent});
     final TephraIndexDatabase db; final VaultFileSystem fs; final IndexOptions options; final Clock clock;
     final void Function(IndexProgress) onProgress; final void Function(IndexEvent) onEvent;
     Future<void> loadNameTable();                 // build the in-memory NameTable from files + aliases tables
     Future<void> reconcile();                     // startup / full index
     Future<void> apply(VaultChange change);       // incremental
     Future<void> rebuild();                       // wipe + reconcile
     NameTable get nameTable;                      // for tests
   }
   ```
   Calls are **not re-entrant**; the runner (step 02.7) serialises them. Logger: `Logger('index')`.
3. **Writing one file** — private `Future<_WriteResult> _writeFile(VaultPath path, VaultEntry entry, List<int> bytes, String hash)`,
   always called inside a `db.transaction`:
   1. `oldAliases` = `nameTable.aliasesOf(path)`. Look up the existing note id: `SELECT id FROM notes WHERE path = ?`.
   2. If a note id exists: `ftsDelete(db, id)`; delete rows of this path from `aliases`, `headings`, `blocks`, `tags`, `properties`, `tasks`
      (`WHERE path = ?`), `links` (`WHERE source = ?`), and `notes`.
   3. Upsert the `files` row (`insertOnConflictUpdate`) with all columns (`mtime = entry.modified.toUtc().millisecondsSinceEpoch`,
      `created` likewise or null).
   4. If `path.isMarkdown`: `doc = TextDocument.decode(bytes)`; `parsed = MarkdownParser.parse(doc.text)`;
      `x = NoteExtractor.extract(path, parsed)`; insert the `notes` row and read back its `id`; `ftsInsert(db, id, x.ftsName, x.ftsBody)`;
      insert all child rows with one `db.batch` (`insertAll`). For each `ExtractedLink`, resolve now:
      `r = LinkResolver(nameTable).resolve(link.targetRaw, from: path)` → `targetPath = r?.path.value`, `resolved = r != null`,
      `viaAlias = r?.viaAlias ?? false`. Then `nameTable.setAliases(path, x.aliases)`.
   5. Return `_WriteResult(oldAliasKeys, newAliasKeys)` (lower-cased).
4. **Deleting one file** — `_deleteFile(VaultPath path)` inside a transaction: note id → `ftsDelete`; `DELETE FROM files WHERE path = ?`
   (children cascade); `nameTable.removeFile(path)`; `nameTable.setAliases(path, [])`. Returns the dirty keys
   `fileTargetKeys(path) ∪ oldAliasKeys`.
5. **Dirty-targets re-resolution** — `_reresolve(Set<String> dirtyKeys)`:
   *Why it is correct:* a link's resolution can only change when a file or alias appears or disappears whose key equals the link's
   `targetKey`. Resolution steps A–C compare the link's last path segment (minus `.md`) with a file's stem (notes) or name (other files);
   step D compares the whole target with an alias. `fileTargetKeys` and alias keys are exactly those strings, and `targetKey` is exactly the
   link-side string. So re-checking only links whose `targetKey` is in the dirty set finds every link whose answer can differ.
   (An alias-resolved link `[[A1]]` has `targetKey 'a1'`; the alias key is `'a1'`; it is covered.)
   Algorithm:
   ```
   remove '' from dirtyKeys; if empty → return {}
   changedTargets = {}
   for chunk of 500 keys:
     rows = SELECT id, source, target_raw, target_path, resolved, via_alias FROM links WHERE target_key IN (?, ?, ...)
     for row in rows:
       r = LinkResolver(nameTable).resolve(row.target_raw, from: VaultPath(row.source))
       newPath = r?.path.value; newVia = r?.viaAlias ?? false
       if newPath != row.target_path || newVia != row.via_alias:
         UPDATE links SET target_path = ?, resolved = ?, via_alias = ? WHERE id = ?   (batched, one transaction per chunk)
         changedTargets += {row.target_path, newPath} (non-null) and row.source
   return changedTargets   (added to the IndexEvent)
   ```
6. **`reconcile()`** (startup and full index):
   ```
   onProgress(scanning, 0, 0)
   entries = (await fs.list(recursive: true)).where(e => !e.isFolder && isIndexable(e.path, options))
   dbRows  = SELECT path, size, mtime, hash FROM files           → map by path
   wasEmpty = dbRows.isEmpty
   deleted  = dbRows.keys − entries.paths
   dirty = {}
   for path in deleted (transactions of options.batchSize): dirty ∪= _deleteFile(path)
   toIndex = []; touchOnly = []
   for e in entries:
     row = dbRows[e.path]
     if row == null: toIndex.add(e); nameTable.addFile(e.path); dirty ∪= fileTargetKeys(e.path)   // add BEFORE parsing anything
     else if row.size == e.size && row.mtime == ms(e.modified): continue                          // fast path
     else: bytes = await fs.readBytes(e.path); h = contentHash(bytes)
           if h == row.hash: touchOnly.add((e, ...))  // UPDATE files SET size, mtime only
           else: toIndex.add(e) (keep bytes to avoid a second read)
   apply touchOnly in one transaction
   onProgress(indexing, 0, toIndex.length)
   for batch of options.batchSize in toIndex:
     read missing bytes for the batch (await, outside the transaction); compute hashes
     db.transaction: for each file → r = _writeFile(...); dirty ∪= symmetricDifference(r.oldAliasKeys, r.newAliasKeys)
     onProgress(indexing, doneSoFar, toIndex.length); onEvent(IndexEvent(batch paths, fullRebuild: wasEmpty))
   onProgress(resolving, toIndex.length, toIndex.length)
   if wasEmpty:   // every file was in the NameTable before any link was resolved; only aliases can still be missing
     re-resolve rows: SELECT id, source, target_raw, ... FROM links WHERE resolved = 0 AND target_key != ''
   else:
     changed = _reresolve(dirty)
   upsert index_meta('lastReconcile', clock.now().toUtc().toIso8601String())
   onEvent(IndexEvent(changed ∪ indexed paths, fullRebuild: wasEmpty)); onProgress(done, n, n)
   ```
   A file that fails to read or parse (any exception) is logged at `warning` with its path (never its content) and skipped; the reconcile
   continues. A skipped file keeps no rows (delete its old rows) so the next reconcile retries it.
7. **`apply(VaultChange change)`** — exhaustive `switch` over the sealed `VaultChange`:
   - `FileCreated(path)` / `FileModified(path)`: `entry = await fs.stat(path)`. If null → handle as `FileDeleted(path)`. If `entry.isFolder`
     → list it recursively and apply `FileCreated` for each indexable file inside. If `!isIndexable` → return. Read bytes, `hash`; if a
     `files` row exists with the same hash → update `size`/`mtime` only, return. (**No mtime/size fast path here** — edits within the same
     millisecond with equal size must still re-index.) Otherwise: `isNew = row == null`; if new `nameTable.addFile(path)`;
     transaction `_writeFile`; `dirty = (isNew ? fileTargetKeys(path) : {}) ∪ symmetricDifference(oldAliasKeys, newAliasKeys)`;
     `changed = _reresolve(dirty)`; `onEvent(IndexEvent({path} ∪ changed, fullRebuild: false))`.
   - `FileDeleted(path)`: `victims` = every `files.path` equal to `path` or within it (select all paths and filter with
     `VaultPath.isWithin` in Dart — do **not** use SQL `LIKE`, which is case-insensitive for ASCII and treats `%`/`_` specially). For each →
     `_deleteFile`; then `_reresolve`; event.
   - `FileMoved(from, path)`: `victims` = files equal to or within `from`. For each old path `o`: `n = VaultPath(path.value + o.value.substring(from.value.length))`;
     `_deleteFile(o)`; then (after all deletes) for each `n` that `fs.stat` reports and `isIndexable`: `nameTable.addFile(n)` and
     `_writeFile`. Dirty = keys of all old and new paths + old/new aliases. `_reresolve`; one event with all old and new paths.
     Re-indexing moved files (rather than updating paths in place) is deliberate: the moved notes' own relative links must re-resolve from
     their new folder, and it keeps a single code path.
8. **`rebuild()`**: in one transaction delete all rows from every drift table (child-first order of step 02.2) except `index_meta`;
   `DROP TABLE fts_words`, `DROP TABLE fts_trigram`, then re-run both DDLs; replace `nameTable` with an empty one; then `reconcile()`
   (which sees `wasEmpty == true`).
9. **`loadNameTable()`**: `SELECT path FROM files` + `SELECT path, alias, ordinal FROM aliases ORDER BY path, ordinal` → `NameTable.from`.

**Tests** (`indexer_core_test.dart`; use `openMemoryIndexDatabase()` and `MemoryVaultFileSystem`; helper `write(fs, 'A.md', 'text')`):
- `'full index stores notes, links and fts rows'`: files `A.md` = `'[[B]] #x'`, `B.md` = `'# Hi'`, `img.png` (bytes `[1,2,3]`) → after
  `reconcile`: `files` 3 rows, `notes` 2 rows, link A→B `resolved = 1`, tag `x` on A, heading `Hi` on B, `fts_trigram MATCH '"Hi"'` → B's id.
- `'alias resolution after full index'`: `A.md` = `'[[First]]'`, `Z.md` = `'---\naliases: [First]\n---\n'` → link A resolves to `Z.md`, `viaAlias = 1`
  (Z is parsed after A, so this proves the final alias pass).
- `'reconcile fast path does not re-read unchanged files'`: wrap the fs in a counting decorator (test-only class) → second `reconcile` performs 0
  `readBytes` calls.
- `'reconcile re-reads changed mtime but skips equal hash'`: touch `A.md` (rewrite identical bytes so mtime changes) → 1 `readBytes`, 0 re-parses
  (assert `notes.id` of A unchanged).
- `'creating a note resolves previously unresolved links'` (dirty targets): `A.md` = `'[[New]]'` → unresolved; write `New.md`, `apply(FileCreated('New.md'))`
  → link resolved to `New.md`; event contains `A.md` and `New.md`.
- `'deleting a note unresolves links'`: then `delete New.md`, `apply(FileDeleted)` → `target_path` null, `resolved = 0`.
- `'deleting a note falls back to the next candidate'`: `Note.md`, `Sub/Note.md`, `A.md` = `'[[Note]]'` → resolves `Note.md`; delete `Note.md` → resolves `Sub/Note.md`.
- `'renaming a note re-resolves'`: `A.md` = `'[[Old]] [[New]]'`, `Old.md` → move `Old.md` → `New.md`, `apply(FileMoved(from: Old.md, path: New.md))` →
  `[[Old]]` unresolved, `[[New]]` resolved to `New.md`; no rows left with path `Old.md`.
- `'alias edit re-resolves'`: `A.md` = `'[[Nick]]'`, `P.md` without aliases → unresolved; change P to have `aliases: [Nick]` and `apply(FileModified)` →
  resolved via alias; remove the alias again → unresolved.
- `'folder move moves every file'`: `F/a.md`, `F/G/b.md`, `X.md` = `'[[F/a]] [[b]]'` → move folder `F` → `H`, `apply(FileMoved(from: F, path: H))` →
  files rows `H/a.md`, `H/G/b.md`; `[[F/a]]` unresolved; `[[b]]` resolved to `H/G/b.md`.
- `'folder delete removes every file'`.
- `'ignored paths are never indexed'`: `.obsidian/app.json`, `.trash/x.md`, `node_modules/y.md`, excluded folder `Archive` with `Archive/z.md` → 0 rows for them.
- `'same-size edit in same millisecond is picked up'`: with a fixed `Clock` in the memory fs (if it supports one), rewrite `A.md` from `'aaaa'` to `'bbbb'`
  and `apply(FileModified)` → fts finds `"bbbb"`.
- `'unreadable file is skipped and retried'`: a test fs whose `readBytes` throws for `Bad.md` once → reconcile completes, `Bad.md` has no row; second
  reconcile indexes it.
- `'rebuild produces the same rows'`: index a 20-file vault, record `dumpRows()` (a test helper selecting all non-id columns sorted), `rebuild()`, compare equal.

**Verify:** `cd packages/tephra_index; dart test`. Commit `phase 02.6: add indexer core with dirty-target resolution`.

**Pitfalls**
- Add new files to the `NameTable` **before** parsing any batch in `reconcile`, otherwise links between two new files resolve wrongly and the
  fuzz test in 02.8 fails.
- `symmetricDifference` of alias keys, not just "new aliases": removing an alias must also re-resolve.
- Never hold a transaction open across `await fs.readBytes` — read first, then open the transaction.

---

### 02.7 `NoteIndex` facade, queries and the worker isolate

**Purpose:** the public `NoteIndex` (§7.4 + additions) running `IndexerCore` in a long-lived background isolate on real vaults and
in-process in tests.

**Files**
- `packages/tephra_index/lib/src/note_index.dart` (new)
- `packages/tephra_index/lib/src/indexer/index_runner.dart`, `in_process_runner.dart`, `isolate_runner.dart`, `worker_protocol.dart`, `index_worker.dart` (new)
- `packages/tephra_index/lib/src/index_exceptions.dart` (add `IndexQueryException extends TephraException`)
- tests: `test/note_index_test.dart`, `test/isolate_runner_test.dart`

**Implementation**
1. Public API (exact; add doc comments):
   ```dart
   final class NoteIndex {
     /// [dbFile] == ':memory:' → in-memory database. A [MemoryVaultFileSystem] (or any fs that is not an [IoVaultFileSystem]) or ':memory:'
     /// → indexer runs on the calling isolate (tests). Otherwise → long-lived worker isolate.
     static Future<NoteIndex> open(String dbFile, VaultFileSystem fs,
         {Clock clock = const SystemClock(), IndexOptions options = const IndexOptions()});
     Stream<IndexProgress> get progress;          // broadcast
     IndexProgress get currentProgress;           // last value, initially IndexProgress(idle, 0, 0)
     Stream<IndexEvent> get changes;              // broadcast
     Future<void> reconcile();
     Future<void> onChange(VaultChange change);
     Future<void> rebuild();
     Future<List<NoteSummary>> allNotes();
     Future<NoteSummary?> note(VaultPath path);
     Future<VaultPath?> resolveLink(String target, {required VaultPath from});
     Future<List<LinkRecord>> backlinks(VaultPath target);
     Future<List<UnlinkedMention>> unlinkedMentions(VaultPath target);   // implemented in step 02.12
     Future<List<LinkRecord>> outgoing(VaultPath source);
     Future<List<TagCount>> tags();
     Future<List<HeadingRecord>> headings(VaultPath path);
     Future<List<TaskRecord>> tasks({bool? done});
     Future<List<FtsHit>> fullText(String ftsQuery, {int limit = 200});
     // additions
     Future<List<FileRecord>> allFiles();
     Future<List<AliasRecord>> allAliases();
     Future<List<HeadingRecord>> allHeadings();
     Future<List<BlockRecord>> blocks(VaultPath path);
     Future<List<PropertyKeyCount>> propertyKeys();
     Future<List<String>> propertyValues(String key, {int limit = 50});
     Future<NameTable> loadNameTable();
     Future<List<Map<String, Object?>>> rawSelect(String sql, [List<Object?> args = const []]);
     Future<IndexStats> stats();
     Future<void> close();
   }
   ```
2. `IndexRunner` (internal interface): `Future<void> reconcile()`, `Future<void> apply(VaultChange c)`, `Future<void> rebuild()`,
   `Stream<IndexProgress> progress`, `Stream<IndexEvent> events`, `Future<void> dispose()`. Requests are queued and run strictly one after
   another (FIFO). Consecutive queued `apply` calls for the **same path and same change type** are coalesced (keep one).
3. `InProcessIndexRunner`: owns an `IndexerCore` on the current isolate and a `Future` chain as the queue. The reader database for queries is
   the same `TephraIndexDatabase` instance.
4. `IsolateIndexRunner` + `index_worker.dart`:
   - Messages (`worker_protocol.dart`, all `final class`, sent as objects through `SendPort`; the worker is spawned with `Isolate.spawn` from the
     same program, so plain Dart objects are sendable):
     `WorkerStartup { SendPort replyTo; String rootDir; String dbFile; IndexOptions options; }`;
     requests `sealed class WorkerRequest { int id; }` → `ReconcileRequest`, `ChangeRequest { VaultChange change; }`, `RebuildRequest`, `ShutdownRequest`;
     replies `sealed class WorkerReply` → `WorkerReady { SendPort requests; bool needsFullIndex; }`, `WorkerDone { int id; }`,
     `WorkerFailed { int id; String error; String stack; }`, `WorkerProgress { IndexProgress progress; }`, `WorkerEvent { IndexEvent event; }`,
     `WorkerLog { String level; String message; }`.
   - `Future<void> indexWorkerMain(WorkerStartup s)` (top-level function): set `Logger.root.level = Level.INFO` and forward every record as
     `WorkerLog` to `s.replyTo`; `opened = await openIndexDatabase(s.dbFile)`; `fs = IoVaultFileSystem(s.rootDir)` (**never** call `watch()`
     in the worker; the UI isolate owns the watcher and forwards changes); create `IndexerCore` with `SystemClock`; `await core.loadNameTable()`;
     create a `ReceivePort`, send `WorkerReady`; then process requests one at a time (`await` each), replying `WorkerDone` or `WorkerFailed`
     (catch everything, include `toString()` and stack). On `ShutdownRequest`: close the DB, close the port, `Isolate.exit()`.
   - Main side: `Isolate.spawn(indexWorkerMain, startup, errorsAreFatal: false, onError: errorPort.sendPort, onExit: exitPort.sendPort)`.
     Pending requests are kept in `Map<int, Completer<void>>`. `WorkerLog` records are re-logged to `Logger('index.worker')` at the same level.
     If the worker exits unexpectedly: log `severe`, fail all pending completers with `IndexQueryException('index worker stopped')`, and respawn
     the worker on the next request (once; a second unexpected exit within 60 s leaves the runner failed and every call throws).
   - `rootDir`: from `IoVaultFileSystem`. If Phase 1's class has no public getter for its root directory, add `String get rootDir` (contract
     addition listed above) — do not parse `rootDisplayPath`.
5. `NoteIndex.open` sequence: (1) choose the runner; (2) for the isolate runner wait for `WorkerReady` (which means the worker has opened and
   migrated the DB) and only then call `openReaderIndexDatabase(dbFile)`; (3) return. `open` never starts a reconcile by itself.
6. Query implementations (all on the reader database; map rows to models; `VaultPath(row.path)`; times from ms with `isUtc: true` then `.toLocal()`):
   - `allNotes()`: `SELECT f.path, n.title, f.size, f.mtime, f.created, n.word_count FROM notes n JOIN files f ON f.path = n.path ORDER BY f.path`,
     plus `SELECT path, alias FROM aliases ORDER BY path, ordinal` and `SELECT path, tag FROM tags` grouped in Dart into the summaries.
   - `note(path)`: same, filtered.
   - `resolveLink(target, from)`: strip everything from the first `|`, then from the first `#`; build the exact candidate keys the resolver can ask for
     (`C` spellings; their case keys for step A and step B; their last-segment name keys for step C; `t.toLowerCase()` for step D) and fetch only
     those rows: `SELECT path FROM files WHERE case_key IN (...) OR name_key IN (...)` and
     `SELECT path, alias FROM aliases WHERE alias_key = ?`; build a small `NameTable.from(...)` and run `LinkResolver`. This returns the same
     answer as the full table because the resolver never looks at other keys.
   - `backlinks(target)`: `SELECT * FROM links WHERE target_path = ? AND source <> ? ORDER BY source, start_offset`.
   - `outgoing(source)`: `SELECT * FROM links WHERE source = ? ORDER BY start_offset`.
   - `tags()`: `SELECT DISTINCT path, tag, tag_lower FROM tags`; in Dart: for every row and every ancestor prefix of `tag_lower` (`a/b/c` → `a`, `a/b`,
     `a/b/c`) add the path to `Set` per prefix; `count` = set size; `directCount` = distinct paths with exactly that tag; display form per the
     `TagCount` rule (for a prefix that never appears as a tag itself, use the casing of the first descendant's segment). Sort by `tagLower`.
   - `headings(path)`, `blocks(path)`: ordered by `ordinal` / `start_offset`.
   - `tasks({done})`: `done == null` → all; `true` → `status_char <> ' '`; `false` → `status_char = ' '`; order by path, line.
   - `fullText(q, limit)`: `SELECT n.path, bm25(fts_words) AS r FROM fts_words JOIN notes n ON n.id = fts_words.rowid WHERE fts_words MATCH ? ORDER BY r LIMIT ?`.
     An FTS syntax error (`SqliteException`) is rethrown as `IndexQueryException('invalid full-text query')`.
   - `allFiles()`, `allAliases()`, `allHeadings()` — straightforward selects ordered by path.
   - `propertyKeys()`: `SELECT key_lower, key, value_type, COUNT(DISTINCT path) AS c FROM properties GROUP BY key_lower, value_type`; in Dart keep per
     `key_lower` the row with the highest `c` (ties → first alphabetical type); `count` = sum over types; sort by count desc, then key.
   - `propertyValues(key, limit)`: `SELECT MIN(value_text) AS v, COUNT(*) AS c FROM properties WHERE key_lower = ? AND value_text IS NOT NULL AND value_text <> '' GROUP BY value_lower ORDER BY c DESC, v LIMIT ?`.
   - `loadNameTable()`: same as `IndexerCore.loadNameTable` but on the reader DB.
   - `rawSelect(sql, args)`: throw `ArgumentError` unless the trimmed SQL starts (case-insensitive) with `SELECT` or `WITH`; run
     `customSelect(sql, variables: [for (a in args) Variable(a)])`; return `row.data` maps. Document: "read-only; used by tephra_search".
   - `stats()`: five `COUNT(*)` queries (`unresolvedLinks` = links with `resolved = 0 AND target_key <> ''`).
   - `unlinkedMentions`: body `throw UnimplementedError('step 02.12')` for now.
7. `close()`: send `ShutdownRequest` and wait for exit up to 5 s, then `isolate.kill(priority: Isolate.immediate)`; close the reader DB, close all
   `StreamController`s and `ReceivePort`s.

**Tests**
- `note_index_test.dart` (in-process, `':memory:'` + `MemoryVaultFileSystem`): vault `A.md` = `'---\naliases: [Ay]\ntags: [p]\n---\n# H1\n[[B]] [[Missing]] ![[img.png]] #q/r\n- [ ] t1\n- [x] t2'`,
  `B.md` = `'[[A#H1]] [[Ay]]'`, `img.png`. After `reconcile`:
  `allNotes()` → 2 summaries, A has aliases `['Ay']`, tags contain `p` and `q/r`; `resolveLink('ay', from: B.md)` → `A.md`;
  `resolveLink('B#x|y', from: A.md)` → `B.md`; `backlinks(A.md)` → 2 records from B (one `viaAlias`); `outgoing(A.md)` → 3 records
  (`Missing` unresolved, `img.png` embed); `tags()` → `p`(1), `q`(1, direct 0), `q/r`(1, direct 1); `tasks(done: false)` → `t1`;
  `headings(A.md)` → `H1`; `fullText('h1')` → contains A; `fullText('"unterminated')` throws `IndexQueryException`;
  `rawSelect('DELETE FROM files')` throws `ArgumentError`; `stats().unresolvedLinks == 1`; `propertyKeys()` contains `aliases` and `tags`.
- `'changes stream emits after onChange'`: listen, write `C.md`, `onChange(FileCreated(C.md))` → an `IndexEvent` containing `C.md`.
- `'progress reaches done'`: collect progress during reconcile of 450 files with `batchSize: 200` → phases include `indexing` and end with `done`, and
  `done` counts are non-decreasing; 3 indexing updates (200, 400, 450).
- `isolate_runner_test.dart` (real `IoVaultFileSystem` on a temp dir, real temp DB file): create `A.md`/`B.md` on disk, `open`, `reconcile`, `backlinks`
  correct; write `C.md` to disk + `onChange(FileCreated)` → `allNotes()` has 3; `close()`; reopen the same DB file → `allNotes()` still 3 without
  reconcile; `close()` completes within 5 s and leaves no running isolate (assert `close()` future completes).

**Verify:** `cd packages/tephra_index; dart test`. Commit `phase 02.7: add NoteIndex facade and worker isolate`.

**Pitfalls**
- Do not send `MemoryVaultFileSystem` or a `StreamController` to the worker; only the startup data above.
- Two SQLite connections (worker writer + UI reader) on one file need WAL (step 02.2) and `busy_timeout`; never open the reader before
  `WorkerReady`.
- Use `Isolate.spawn`, not `Isolate.run`; the worker lives until `close()`.

---

### 02.8 Index consistency fuzz test

**Purpose:** prove that incremental updates always equal a fresh rebuild (PHASE_PLAN 2 exit gate: 10,000 operations, 0 differences).

**Files**
- `packages/tephra_index/lib/testing.dart` (new library, exports `src/testing/index_dump.dart`)
- `packages/tephra_index/lib/src/testing/index_dump.dart` (new)
- `packages/tephra_index/test/fuzz/index_fuzz_test.dart` (new), `packages/tephra_index/dart_test.yaml` (new)

**Implementation**
1. `Future<Map<String, List<String>>> dumpIndex(NoteIndex index)` — uses `rawSelect` to read every table **without** auto-increment ids and note ids:
   `files` (all columns except none — `mtime`/`created` included), `notes` (path, title, frontmatter_json, frontmatter_valid, word_count), `aliases`,
   `headings`, `blocks`, `links` (all except `id`), `tags` (except `id`), `properties` (except `id`), `tasks` (except `id`), and for FTS:
   for every note the result of `SELECT n.path FROM fts_trigram JOIN notes n ON n.id = fts_trigram.rowid WHERE fts_trigram MATCH ?` for a fixed probe
   list of 10 words used by the generator (proves FTS rows exist and match). Each row is rendered as `jsonEncode` of its values in column order;
   each list is sorted.
2. `dart_test.yaml`:
   ```yaml
   tags:
     fuzz:
       timeout: 10x
   ```
3. The test (`@Tags(['fuzz'])` on the library):
   - Seeds: if the environment variable `TEPHRA_FUZZ_SEED` is set, use only that seed; otherwise seeds `[1, 2, 3]`. Ops per seed: `TEPHRA_FUZZ_OPS`
     or **10,000**. Call `printOnFailure('seed=$seed op=$i last=$lastOpDescription')` before every comparison (this is the test API, not `print`).
   - `fs = MemoryVaultFileSystem()` (with an injected incrementing `Clock` if its constructor supports one, so mtimes differ), `index = NoteIndex.open(':memory:', fs)`,
     `rng = Random(seed)`.
   - Pools: folders `['', 'A', 'A/B', 'C', 'বাংলা']`; note names `Note0`…`Note29`, `Café0`, `Café1`, `নোট0`, `নোট1`; alias names `Alias0`…`Alias7`;
     tags `t0`…`t5`, `t0/sub`; attachments `img0.png`…`img3.png`.
   - Note content generator (deterministic from `rng`): optional frontmatter (50%) with `aliases` (0–2 from the alias pool), `tags` (0–2), `status`
     (`draft`/`done`), `n` (int); then 3–12 body lines, each one of: `# Heading k` / `## Heading k`, a paragraph containing 0–3 of
     `[[<name>]]`, `[[<folder>/<name>]]`, `[[<name>#Heading 1]]`, `[[<alias>]]`, `![[img<k>.png]]`, `[t](<name>.md)`, `[t](<encoded folder/name>.md)`,
     `#<tag>`, a task `- [ ] task k` / `- [x] task k`, a block id suffix ` ^b<k>`, or one probe word.
   - Operation mix per step (`rng.nextInt(100)`): 0–24 create note (random folder + unused name), 25–49 edit existing note (new content), 50–64 rename/move a
     note (50% same folder new name, 50% other folder same name; skip if target exists), 65–74 delete a note, 75–81 create/overwrite an attachment,
     82–89 move a folder (random existing non-root folder to a new name under a random parent; skip if target exists or is inside itself), 90–94 delete a
     folder, 95–99 edit only the frontmatter aliases of an existing note. If the chosen op is impossible (e.g. no notes yet), create a note instead.
   - After each fs operation call exactly one `await index.onChange(change)` with the matching `VaultChange` (`FileCreated` for new files,
     `FileModified` for edits/overwrites, `FileMoved(from:, path:)` for renames and folder moves, `FileDeleted` for deletes). Do **not** subscribe to
     `fs.watch()` in this test.
   - Every 1,000 operations and at the end: `fresh = await NoteIndex.open(':memory:', fs); await fresh.reconcile();`
     `expect(await dumpIndex(index), equals(await dumpIndex(fresh)));` then `await fresh.close()`.
4. Also add a fast variant in the same file without the tag: `'fuzz smoke (300 ops, seed 7)'` so normal `dart test` runs exercise the code path.

**Tests:** the fuzz test itself (3 seeds × 10,000 ops) and the smoke variant.

**Verify**
```
cd packages/tephra_index; dart test                       # includes the 300-op smoke
cd packages/tephra_index; dart test --tags fuzz            # 3 × 10,000 ops
```
Both pass. Record the run time of the tagged run in `PROGRESS.md`. If a difference appears, the failure message has the seed and op; reproduce with
`$env:TEPHRA_FUZZ_SEED='<seed>'; dart test --tags fuzz`, fix the indexer (never the test), add a regression test for the minimal case in
`indexer_core_test.dart`. Commit `phase 02.8: add index consistency fuzz test`.

**Pitfalls**
- `files.mtime` must come from the fs (not the clock at index time), otherwise incremental and fresh dumps differ.
- If the memory fs reuses the same `modified` time for two versions, that is fine for `apply` (no fast path) and for the fresh rebuild (empty DB).

---

### 02.9 App integration: index lifecycle, indexing file-system decorator, progress, `Rebuild index`, link settings

**Purpose:** the app opens one `NoteIndex` per vault session, keeps it current from the watcher and from Tephra's own writes, and shows progress.

**Files**
- `app/lib/core/providers.dart` (add providers)
- `app/lib/vault/indexing_vault_file_system.dart` (new)
- `app/lib/vault/index_session.dart` (new: `NoteIndexNotifier`)
- `app/lib/workspace/index_status.dart` (new: status-bar item + phone progress bar)
- `app/lib/commands/index_commands.dart` (new) and registration where Phase 1 registers commands
- Vault settings model/store from Phase 1 (add fields), `.obsidian` importer from Phase 1 (add keys), settings screen (add "Files & links" section)
- `app/lib/l10n/app_en.arb`
- tests: `app/test/vault/indexing_vault_file_system_test.dart`, `app/test/workspace/index_status_test.dart`

**Implementation**
1. `IndexingVaultFileSystem implements VaultFileSystem`: wraps the session's real fs. Every method delegates. After a **successful**
   `writeBytes`/`writeText` → report `FileModified(path)`; `move(from, to)` → `FileMoved(from: from, path: to)`; `delete(path)` → `FileDeleted(path)`;
   `createFolder` → nothing. Reporting = `attachIndex(void Function(VaultChange) sink)`; until attached, changes are appended to a list and flushed in
   order on attach. The sink call is fire-and-forget: `unawaited(index.onChange(c).catchError(...))` logging failures to `Logger('index')` at `warning`.
   (The indexer treats `FileModified` for a new file like `FileCreated`, so writes never need a pre-`stat`.)
2. Find the provider through which Phase 1 code obtains the vault's `VaultFileSystem` (inventory item 12). Make it return the
   `IndexingVaultFileSystem` wrapper, so **every** app write is reported. The raw fs's `watch()` stream (external changes; our own writes are already
   excluded by Phase 1) is forwarded to `index.onChange` by the notifier below.
3. Providers (in `app/lib/core/providers.dart`):
   ```dart
   final noteIndexProvider = AsyncNotifierProvider<NoteIndexNotifier, NoteIndex>(NoteIndexNotifier.new);
   final indexProgressProvider = StreamProvider<IndexProgress>((ref) async* { final i = await ref.watch(noteIndexProvider.future); yield i.currentProgress; yield* i.progress; });
   final indexChangesProvider = StreamProvider<IndexEvent>((ref) async* { final i = await ref.watch(noteIndexProvider.future); yield* i.changes; });
   ```
   `NoteIndexNotifier.build()`: watch the current vault session (Phase 1 provider); read `vaultId` (from `.tephra/vault.json`);
   `dir = await getApplicationSupportDirectory()`; `dbFile = p.join(dir.path, 'index', '$vaultId.sqlite')`;
   `index = await NoteIndex.open(dbFile, rawFs, options: IndexOptions(excludedFolders: settings.excludedFolders))` (pass the **raw** fs, not the wrapper —
   the worker builds its own `IoVaultFileSystem` anyway); `wrapper.attachIndex(index.onChange-sink)`; subscribe `rawFs.watch()` → `index.onChange`;
   `ref.onDispose` cancels the subscription and calls `index.close()`; start `unawaited(index.reconcile())` (log errors). Return the index immediately
   (the UI stays usable during indexing; queries return partial results while indexing).
4. Progress UI: desktop status bar (Phase 1 shell) gets `IndexStatusItem`: visible while `phase` is `scanning`, `indexing` or `resolving`; text
   `indexStatusScanning` ("Scanning vault…"), `indexStatusIndexing` ("Indexing {done} / {total}"), `indexStatusResolving` ("Resolving links…"); hidden at
   `done`/`idle`. Phone layout: a 2 dp `LinearProgressIndicator` (determinate during `indexing`, indeterminate otherwise) directly under the app bar of the
   note screen while not done.
5. Command `index.rebuild` (label `commandRebuildIndex` = "Rebuild index", no default shortcut, in palette): shows a confirm dialog
   (`rebuildIndexConfirmTitle`, `rebuildIndexConfirmBody` = "Rebuild the search index for this vault? Tephra stays usable while it runs.");
   on confirm `unawaited(index.rebuild())`; when it completes show snackbar `rebuildIndexDone`.
6. Vault settings fields (add to the Phase 1 vault settings model if missing, with `fromJson`/`toJson`; JSON keys use Obsidian's names):
   `newLinkFormat` (`'shortest'|'relative'|'absolute'`, default `'shortest'`), `useMarkdownLinks` (bool, default `false`), `alwaysUpdateLinks` (bool,
   default `true`), `excludedFolders` (`List<String>`, default `[]` — Obsidian stores this as `userIgnoreFilters` in `app.json`; import from there).
   Importer: when `.tephra/settings.json` lacks a key above and `.obsidian/app.json` has it, copy it (one-time, read-only access to `.obsidian`).
7. Settings screen, section "Files & links": dropdown "New link format" (Shortest path when possible / Relative path to file / Absolute path in vault),
   switch "Use [[Wikilinks]]" (on = `useMarkdownLinks == false`), switch "Automatically update internal links", list editor "Excluded folders". Changing
   excluded folders shows `excludedFoldersRebuildPrompt` and, on confirm, re-opens the index with the new options (invalidate `noteIndexProvider`) and runs
   `rebuild()`.

**Tests**
- `indexing_vault_file_system_test.dart` (wrapping `MemoryVaultFileSystem`): `writeText` before attach → nothing reported; attach → `FileModified` flushed;
  `move` → `FileMoved(from, path)`; `delete` → `FileDeleted`; a failing inner `writeText` (fake throwing fs) reports nothing.
- `index_status_test.dart`: override `indexProgressProvider` with a stream of `IndexProgress(indexing, 5, 10)` → desktop-width (1200 dp) pump shows
  "Indexing 5 / 10"; phone width (400 dp) shows a `LinearProgressIndicator` with value 0.5; `IndexProgress(done, 10, 10)` → neither visible.
- Settings JSON round-trip test for the 4 new fields (missing keys → defaults).

**Verify**
`flutter test` in `app/`; then `flutter run -d windows` with a real vault: status bar shows indexing, then disappears; run "Rebuild index" from the
palette (Ctrl+P) → indexing shows again. Confirm the DB exists at `%APPDATA%\com.tephra\...\index\<vaultId>.sqlite` (path printed in the log at info level).
Commit `phase 02.9: wire index into app with progress and rebuild command`.

**Pitfalls**
- `NoteIndexNotifier` must not await `reconcile()` in `build()`, or the UI waits for the full index.
- Disposing the vault session must close the index (worker isolate) — check with two vault switches in a row that only one worker runs (log line
  `index worker started` / `index worker stopped`).

---

### 02.10 Link formatting and link navigation (open, create on click)

**Purpose:** generate link text per the "new link format" settings, and make clicking links open targets or create missing notes.

**Files**
- `packages/tephra_index/lib/src/links/link_formatter.dart`, `link_format_settings.dart` (new)
- `app/lib/links/link_navigator.dart`, `app/lib/links/providers.dart` (new)
- `app/lib/editor/editor_controller.dart` (Phase 1; add capabilities if missing) and `app/lib/editor/editor_registry.dart` (new if missing)
- Reading view link tap handler (Phase 1) and editor Ctrl+click handler
- tests: `packages/tephra_index/test/links/link_formatter_test.dart`, `app/test/links/link_navigator_test.dart`

**Implementation**
1. `EditorController` capabilities this phase relies on. Open Phase 1's `EditorController`. For each item below that is missing, add it
   (additive; implement it for the chosen engine) and add a unit test for it in `app/test/editor/editor_controller_test.dart`:
   | Member | Behaviour |
   |---|---|
   | `String get text` | current buffer text (`\n`-normalised) |
   | `TextSelection get selection` / `void select(int start, [int? end])` | caret/selection in UTF-16 offsets |
   | `Stream<EditorEdit> get edits` | one event per text change: `start`, `deletedLength`, `insertedText`, `isUndoRedo` |
   | `void applyEdits(List<EditOperation> edits)` | **already defined by Phase 1** (01.18) with `EditOperation(start, end, replacement)`; applies non-overlapping edits back-to-front as **one** undo step. Phase 2 code that holds `TextEdit`s (from `tephra_index`, same three fields) converts them with an app-side helper `List<EditOperation> toEditOps(List<TextEdit> e)` in `app/lib/editor/edit_adapters.dart` before calling it. Do not change Phase 1's signature. |
   | `void revealOffset(int offset, {bool center = true})` | scrolls so the offset is visible |
   | `Rect? caretRectGlobal()` | caret rectangle in global coordinates (null when not laid out) |
   | `bool get isDirty` | unsaved changes exist |
   | `VaultPath get path` | note path (updated when the file is moved) |
   `EditorRegistry` (`Provider<EditorRegistry>` in `app/lib/editor/providers.dart`): editors register on attach and unregister on dispose;
   `EditorController? controllerFor(VaultPath path)`; `Iterable<EditorController> get all`. If Phase 1 already tracks open editors per path, use that
   instead and note it.
2. `LinkFormatSettings { const LinkFormatSettings({this.format = NewLinkFormat.shortest, this.useMarkdownLinks = false}); final NewLinkFormat format; final bool useMarkdownLinks; }`,
   `enum NewLinkFormat { shortest, relative, absolute }` with `fromJson(String)` (unknown → shortest).
3. `LinkFormatter`:
   ```dart
   final class LinkFormatter {
     const LinkFormatter(this.lookup, this.settings);
     final LinkTargetLookup lookup; final LinkFormatSettings settings;
     /// Link path text (no brackets) from [from] to [target] for [syntax].
     String linkPath(VaultPath target, {required VaultPath from, required LinkSyntax syntax});
     /// Complete new link in the syntax chosen by settings.useMarkdownLinks.
     String buildLink(VaultPath target, {required VaultPath from, String? heading, String? blockRef, String? alias, bool embed = false, String? embedSize});
     static String encodeMarkdownPath(String path);
     static String decodeMarkdownPath(String path);
     static String sanitizeHeadingForLink(String heading);
   }
   ```
   `linkPath` rules (`name(p)` = for wiki syntax `p.stem` if `p.isMarkdown` else `p.name`; for markdown syntax always `p.name`;
   `full(p)` = `p.value` with a trailing `.md` removed for wiki syntax and markdown notes keep `.md`):
   - **absolute** → `full(target)`.
   - **relative** → path from `from.parent` to `target`: count the common leading folder segments; emit `'../'` once per remaining folder segment of
     `from.parent`, then the remaining segments of `target` (last segment per `name`). Same folder → just `name(target)`.
   - **shortest** → if `LinkResolver(lookup).resolve(bare, from: from)` returns `target` with `viaAlias == false`, where `bare` = `name(target)`
     (for markdown syntax the resolver receives the decoded name) → `bare`; otherwise `full(target)`.
   - Markdown syntax: the result is passed through `encodeMarkdownPath`.
   `encodeMarkdownPath`: percent-encode (UTF-8 bytes, upper-case hex) each of these characters: space, `%`, `(`, `)`, `[`, `]`, `<`, `>`, `#`, `^`, `|`,
   `?`, `` ` ``, `"`, `\`, `{`, `}`; leave every other character (including `/` and all non-ASCII letters) unchanged.
   `decodeMarkdownPath`: `Uri.decodeComponent`, returning the input unchanged on `ArgumentError`/`FormatException`.
   `sanitizeHeadingForLink`: replace each of `[ ] | # ^ \` with a space, remove `%%`, collapse spaces, trim.
   `buildLink`: `subpath` = `heading != null ? '#${sanitizeHeadingForLink(heading)}' : blockRef != null ? '#^$blockRef' : ''`.
   Wiki: `'${embed ? '!' : ''}[[${linkPath(wiki)}$subpath${alias != null && alias != name(target) ? '|$alias' : ''}${embedSize != null ? '|$embedSize' : ''}]]'`.
   Markdown: `'${embed ? '!' : ''}[${alias ?? target.stem}](${linkPath(markdown)}${encodeMarkdownPath(subpath)})'` (the `#` of the subpath itself is not encoded:
   encode only the part after it).
4. `LinkNavigator` (`app/lib/links/link_navigator.dart`), provided by `linkNavigatorProvider`:
   ```dart
   Future<void> open({required VaultPath from, required String target, String? heading, String? blockRef, bool newTab = false});
   ```
   1. `path = await index.resolveLink(target, from: from)`.
   2. Resolved → open it with Phase 1's workspace API (new tab if `newTab`). Then: `heading` → `findHeading(await index.headings(path), heading)` →
      `revealOffset(h.start)` in the editor or scroll the reading view to it; `blockRef` → `findBlock(await index.blocks(path), blockRef)` → same. A missing
      heading/block just opens the note at the top and shows snackbar `linkHeadingNotFound`.
   3. Unresolved, `target` empty → nothing. Unresolved with a non-`md` extension in the last segment (e.g. `img.png`, `doc.pdf`) → snackbar
      `linkTargetFileMissing` ("{name} doesn't exist in this vault"), no file is created.
   4. Unresolved otherwise → **create the note**: if `target` contains `/` → `newPath = VaultPath(target.endsWith('.md') ? target : '$target.md')` (vault-root
      relative; `InvalidPathException` → snackbar `linkInvalidTarget`); else `folder` = the Phase 1 "new note location" setting (vault root, same folder as
      `from`, or the configured folder) and `newPath = folder.join('$target.md')`. If `newPath` exists (race) → open it. Else `fs.writeText(newPath, const TextDocument(text: ''))`
      and open it (new tab if `newTab`), in the tab's default mode.
5. Wire it: the reading view's internal-link tap (Phase 1) and the editor's Ctrl+click on a link (Source and, later, Live Preview mode) call
   `LinkNavigator.open`. Ctrl+click or middle-click in the reading view → `newTab: true`. Markdown links: decode the URL with `decodeMarkdownPath`, split at the
   first `#` (`#^id` → `blockRef`, other → `heading`).
6. Unresolved-link styling in the reading view: `linkResolutionProvider = FutureProvider.family<VaultPath?, (VaultPath from, String target)>` calling
   `index.resolveLink`, invalidated whenever `indexChangesProvider` emits (`ref.watch(indexChangesProvider)` inside the family). Unresolved internal links render
   with the link colour at 60 % opacity (Obsidian shows them dimmer).

**Tests**
- `link_formatter_test.dart` — `NameTable` vault: `Note.md`, `Folder/Note.md`, `Folder/Other Note.md`, `Images/a b.png`, `Deep/x/y/Target.md`, `Unique.md`, `বাংলা নোট.md`:
  | # | call | expected |
  |---|---|---|
  | 1 | shortest wiki `Unique.md` from `X.md` | `Unique` |
  | 2 | shortest wiki `Folder/Note.md` from `X.md` | `Folder/Note` (bare `Note` resolves to root `Note.md`) |
  | 3 | shortest wiki `Note.md` from `Folder/Y.md` | `Note` |
  | 4 | shortest markdown `Folder/Other Note.md` from `X.md` | `Other%20Note.md` |
  | 5 | shortest wiki `Images/a b.png` | `a b.png` |
  | 6 | shortest markdown `Images/a b.png` | `a%20b.png` |
  | 7 | relative wiki `Deep/x/y/Target.md` from `Folder/Y.md` | `../Deep/x/y/Target` |
  | 8 | relative wiki `Folder/Note.md` from `Folder/Y.md` | `Note` |
  | 9 | relative markdown `Note.md` from `Deep/x/y/Z.md` | `../../../Note.md` |
  | 10 | absolute wiki `Deep/x/y/Target.md` | `Deep/x/y/Target` |
  | 11 | absolute markdown `Folder/Other Note.md` | `Folder/Other%20Note.md` |
  | 12 | `buildLink(Images/a b.png, embed: true, embedSize: '300')` wiki | `![[a b.png|300]]` |
  | 13 | `buildLink(Unique.md, heading: 'Part Two', alias: 'shown')` wiki | `[[Unique#Part Two|shown]]` |
  | 14 | same with `useMarkdownLinks: true`, no alias | `[Unique](Unique.md#Part%20Two)` |
  | 15 | `encodeMarkdownPath('(draft) 100%.md')` / decode back | `%28draft%29%20100%25.md` / original |
  | 16 | `decodeMarkdownPath('%E0%A4')` | `%E0%A4` (unchanged) |
  | 17 | shortest markdown `বাংলা নোট.md` | `বাংলা%20নোট.md` |
  | 18 | `buildLink(Unique.md, heading: 'A [b] | c')` wiki | `[[Unique#A b c]]` |
  | 19 | `buildLink(Unique.md, blockRef: 'x1')` wiki | `[[Unique#^x1]]` |
- `link_navigator_test.dart` (fake workspace + in-process index): resolved target opens that path; `heading` reveals the heading offset; unresolved `New Idea`
  with new-note location "vault root" creates `New Idea.md` and opens it; unresolved `Projects/Plan` creates `Projects/Plan.md`; unresolved `pic.png` creates
  nothing and shows `linkTargetFileMissing`.

**Verify:** `dart test` in `packages/tephra_index`; `flutter test` in `app/`. Manual (Windows): click `[[Does not exist]]` in reading view → note created in the
configured folder and opened. Commit `phase 02.10: add link formatter and link navigation`.

**Pitfalls**
- The shortest-path check must use the resolver, never string heuristics; otherwise generated links may silently point at a different file.
- Do not create a note when the click comes from a page-preview popup's "create" action twice (debounce the button for 500 ms).

---

### 02.11 Rename/move link maintenance as one undoable operation

**Purpose:** renaming or moving a note, attachment or folder rewrites every link to it (and the moved notes' own relative links) and can be undone.

**Files**
- `packages/tephra_index/lib/src/links/rename_planner.dart`, `text_edit.dart`, `link_span_locator.dart` (new)
- `packages/tephra_index/lib/src/extract/note_extractor.dart` (expose `static List<ExtractedLink> extractLinks(VaultPath path, ParsedNote parsed)` publicly
  through the planner only — keep it in `src/`)
- `app/lib/links/link_rename_service.dart`, `app/lib/vault/vault_undo.dart` (new)
- Explorer rename / drag-drop move / "Move to…" (Phase 1) — call the service
- tests: `packages/tephra_index/test/links/rename_planner_test.dart`, `packages/tephra_index/test/links/rename_500_test.dart`,
  `app/test/links/link_rename_service_test.dart`, `app/test/vault/vault_undo_test.dart`

**Implementation**
1. `text_edit.dart`:
   ```dart
   final class TextEdit { const TextEdit(this.start, this.end, this.replacement); final int start; final int end; final String replacement; }
   final class FileEdit { const FileEdit(this.path, this.edits); final VaultPath path /* path BEFORE the move */; final List<TextEdit> edits; }
   /// Applies [edits] back-to-front. Throws ArgumentError if two edits overlap or one is out of range.
   String applyTextEdits(String text, List<TextEdit> edits);
   ```
2. `link_span_locator.dart` — `(int, int) locateLinkPathSpan(String text, ExtractedLink link)` returns the range of **only the path part** of the link source:
   - Wiki: `i = link.start + (kind == embed ? 3 : 2)`; advance `j` from `i` until `text[j]` is `#`, `|` or `]`, or `text[j] == '\\' && text[j+1] == '|'`
     (escaped pipe inside a table cell). Span `(i, j)`.
   - Markdown: find the `(` that opens the destination: scan backwards from `link.end - 1` (which is `)`), counting nested `)`/`(`, to the matching `(` → `p`.
     If `text[p+1] == '<'`: span = `(p+2, index of first '#' or '>' after p+2)`, flag `angle = true`. Else span = `(p+1, first index after p+1 of '#', ' ' or ')' )`
     (a space starts an optional title).
   The span text is replaced by the new path text; everything else (`!`, `[[`, `#heading`, `#^block`, `|alias`, `|300x200`, link text, title, `)`) stays byte-identical.
3. `RenamePlanner`:
   ```dart
   final class RenamePlan { const RenamePlan(this.moves, this.fileEdits); final Map<VaultPath, VaultPath> moves; final List<FileEdit> fileEdits;
     int get linkCount; int get fileCount; }
   final class RenamePlanner {
     RenamePlanner({required this.before, required this.settings});
     final NameTable before; final LinkFormatSettings settings;
     /// [moves]: every moved file old → new (a folder move lists every file inside it).
     /// [sources]: current text of every note to inspect (old path → text).
     RenamePlan plan(Map<VaultPath, VaultPath> moves, Map<VaultPath, String> sources);
   }
   ```
   Algorithm:
   ```
   after = before.copy()
   for (old, new) in moves: aliases = before.aliasesOf(old); after.removeFile(old); after.addFile(new); after.setAliases(new, aliases)
   rBefore = LinkResolver(before); rAfter = LinkResolver(after); fmt = LinkFormatter(after, settings)
   for (srcOld, text) in sources:
     srcNew = moves[srcOld] ?? srcOld
     links = extractLinks(srcOld, MarkdownParser.parse(text))
     edits = []
     for L in links:
       if L.targetRaw.trim().isEmpty: continue                         // [[#Heading]] same-note
       b = rBefore.resolve(L.targetRaw, from: srcOld)
       if b == null || b.viaAlias: continue                            // unresolved or alias links never change
       tgtNew = moves[b.path] ?? b.path
       if !moves.containsKey(b.path) && !moves.containsKey(srcOld): continue
       a = rAfter.resolve(L.targetRaw, from: srcNew)
       if a != null && !a.viaAlias && a.path == tgtNew: continue        // the user's text still points to the right file → keep it
       (s, e, angle) = locateLinkPathSpan(text, L)
       newPath = angle ? fmt.linkPath(tgtNew, from: srcNew, syntax: markdown) decoded (no percent-encoding)
                       : fmt.linkPath(tgtNew, from: srcNew, syntax: L.syntax)
       edits.add(TextEdit(s, e, newPath))
     if edits not empty: fileEdits.add(FileEdit(srcOld, edits))
   return RenamePlan(moves, fileEdits)
   ```
   Offsets come from parsing the **exact text that will be edited** (an open buffer or the file as read now), not from stored index offsets: the index only
   tells us *which* notes link to the moved files. Reason: the stored offsets can be stale (unsaved buffer, a file changed after indexing), and an edit at a
   wrong offset corrupts the note. `linkCount` = total edits, `fileCount` = `fileEdits.length`.
4. `LinkRenameService` (`app/lib/links/link_rename_service.dart`, `linkRenameServiceProvider`):
   ```dart
   Future<RenameOutcome> renameOrMove(VaultPath from, VaultPath to);   // RenameOutcome { int links; int files; VaultOperation? undo; List<VaultPath> skipped; }
   ```
   1. `if (await fs.stat(to) != null && from.caseKey != to.caseKey)` → throw `FileConflictException(to)` (UI shows `renameTargetExists`).
   2. `moves`: if `from` is a folder → every file under it (`fs.list(folder: from)`) mapped to `to` + the remainder; else `{from: to}`.
   3. If `settings.alwaysUpdateLinks == false` → after planning (step 6) show a dialog `renameUpdateLinksPrompt` ("Update {links} links in {files} files?")
      with buttons "Update" / "Don't update". "Don't update" → only move.
   4. Sources: for each moved file `m` → `index.backlinks(m)` sources; plus every moved `.md` file itself. De-duplicate.
   5. Texts: for each source, if `editorRegistry.controllerFor(path)` exists → its `text` (buffer is the truth while open); else `fs.readText(path)` (keep the
      `TextDocument`). A source whose `TextDocument.malformed == true` is skipped (added to `skipped`; never write a malformed file).
   6. `table = await index.loadNameTable()`; `plan = await Isolate.run(() => RenamePlanner(before: table, settings: s).plan(moves, texts))`.
   7. `await fs.move(from, to)` (the wrapper reports it to the index). If it throws → stop; nothing was edited; rethrow.
   8. For each `FileEdit`: `newPath = moves[e.path] ?? e.path`; `newText = applyTextEdits(oldText, e.edits)`. Open buffer → `controller.applyEdits(e.edits)`
      (one undo step in that editor; autosave writes it). Otherwise → `fs.writeText(newPath, TextDocument(text: newText, hasBom: doc.hasBom, lineEnding: doc.lineEnding))`.
      Record `FileChange(newPath, oldText, newText, inBuffer: bool)`.
   9. Retarget open tabs whose path is `from` or within it (Phase 1 workspace API; if missing, add `retargetPath(VaultPath from, VaultPath to)` handling folders).
   10. Push `VaultOperation(moves: moves, changes: changes)` onto the undo stack; show the snackbar `renameLinksUpdated` with action "Undo" when `links > 0`
       (ICU message, one string: `"{links, plural, =1{Updated 1 link} other{Updated {links} links}} in {files, plural, =1{1 file} other{{files} files}}"`).
5. `vault_undo.dart`: `VaultOperation { Map<VaultPath, VaultPath> moves; List<FileChange> changes; DateTime at; }`,
   `vaultUndoStackProvider` (`NotifierProvider`, max 20 entries, newest last). `Future<UndoResult> undo(VaultOperation op)`:
   1. For each change in reverse: current = open buffer text or `fs.readText(change.path).text`. If `current == change.newText` → restore `oldText` (buffer:
      `applyEdits([TextEdit(0, current.length, oldText)])`; disk: `writeText` keeping BOM/line ending of the current doc). Else → conflict (skip, count it).
   2. Then move back: for a folder operation move `to` → `from` once; otherwise each file `new` → `old`, in reverse order. Skip (count as conflict) when
      the destination exists or the source is missing.
   3. Snackbar `undoRenameDone` or `undoRenamePartial` ("Undo finished; {count} files had changed and were left as they are").
   Command `vault.undo-last-rename` (label "Undo last rename", palette only, no default shortcut) undoes the newest operation.
6. Replace every Phase 1 rename/move call site in the explorer (inline rename, drag-and-drop, "Move to…") with `LinkRenameService.renameOrMove`, and delete the
   Phase 1 notice that said links are not updated.

**Tests**
- `rename_planner_test.dart` — vault table: `Target.md` (aliases `[A1]`), `Other.md`, `Note.md`, `Folder/Sibling.md`, `Folder/Src.md`. Rename `Target.md` →
  `Folder/Renamed Note.md`, shortest format, wiki default. Source `S.md` lines and expected after-applying text:
  | before | after |
  |---|---|
  | `[[Target]]` | `[[Renamed Note]]` |
  | `[[target|Alias]]` | `[[Renamed Note|Alias]]` |
  | `[[Target#Head]]` | `[[Renamed Note#Head]]` |
  | `[[Target#^b1]]` | `[[Renamed Note#^b1]]` |
  | `![[Target]]` | `![[Renamed Note]]` |
  | `![[Target|300]]` | `![[Renamed Note|300]]` |
  | `[t](Target.md)` | `[t](Renamed%20Note.md)` |
  | `[t](Target.md#Head%20Two)` | `[t](Renamed%20Note.md#Head%20Two)` |
  | `[t](<Target.md>)` | `[t](<Renamed Note.md>)` |
  | `[t](Target.md "title")` | `[t](Renamed%20Note.md "title")` |
  | `| [[Target\|x]] |` (table row) | `| [[Renamed Note\|x]] |` |
  | `[[A1]]` | unchanged (alias) |
  | `[[Other]]`, `[[Missing]]`, `` `[[Target]]` `` (inline code) | unchanged |
  Plus these separate cases:
  - Move `Target.md` → `Archive/Target.md` (no other `Target.md` in the vault): `[[Target]]` unchanged.
  - Vault additionally contains `Other/Target.md`. Before the move `[[Target]]` resolves to root `Target.md` (step A). After moving root `Target.md` →
    `Archive/Target.md`, `[[Target]]` resolves by name to `Archive/Target.md` (tie on 2 segments, `archive/…` sorts before `other/…`) → still correct → unchanged.
  - Vault additionally contains `Aaa/Target.md`; move root `Target.md` → `Zzz/Target.md`: after the move `[[Target]]` would resolve to `Aaa/Target.md` (wrong)
    → rewritten to `[[Zzz/Target]]` (shortest: the bare name does not resolve to the target, so the full path is used).
  - Format `absolute`, simple move `Target.md` → `Archive/Target.md`: `[[Target]]` unchanged (rule "text still points to the right file"). Moved note's own links:
  `Folder/Src.md` = `'[x](../Note.md) [[Sibling]]'` moved to `Deep/x/Src.md` → `'[x](Note.md) [[Sibling]]'` (relative `../Note.md` breaks → regenerated
  shortest; `[[Sibling]]` still resolves by name). Folder rename `Folder` → `Renamed` with `X.md` = `'[[Folder/Sibling]]'` → `'[[Sibling]]'` (bare name unique →
  shortest). `applyTextEdits` with overlapping edits throws `ArgumentError`.
- `rename_500_test.dart` (in-process `NoteIndex` + `MemoryVaultFileSystem` + planner + a minimal apply loop identical to the service's disk branch): 500 notes
  `N000.md`…`N499.md`, each `'Intro line\n[[Target]] and [[Target#H|al]]\n![[Target]] [m](Target.md)\nEnd'`; notes 0–49 saved with CRLF line endings, 50–99 with a
  BOM. Rename `Target.md` → `Folder/Renamed.md`. Assert: every note's bytes equal the expected bytes (same note text with `Target` → `Renamed` in those four
  links, encoded with the note's original BOM/line ending); an unrelated note `Untouched.md` is byte-identical; total `linkCount == 2000`, `fileCount == 500`;
  the whole plan+apply takes < 5 s (`Stopwatch`; record the time in `PROGRESS.md`).
- `link_rename_service_test.dart`: (a) disk files rewritten, toast text "Updated 3 links in 2 files"; (b) a note open in a fake `EditorController` with unsaved edits
  receives `applyEdits` and its disk file is **not** written by the service; (c) `alwaysUpdateLinks == false` + "Don't update" → move only; (d) target exists →
  `FileConflictException`; (e) malformed source skipped and reported.
- `vault_undo_test.dart`: rename then undo → all files byte-identical to before and the file back at the old path; edit one rewritten note after the rename, then
  undo → that note left as is, others restored, result reports 1 conflict.

**Verify:** `dart test` in `packages/tephra_index` (includes the 500-note test); `flutter test` in `app/`. Manual (Windows + Android): rename a note linked from
3 notes in the explorer → toast "Updated 3 links in 3 files" → open the linking notes → links updated → tap "Undo" → old name and old links back.
Commit `phase 02.11: rewrite links on rename and move with undo`.

**Pitfalls**
- Apply edits back-to-front per file; never apply one edit and then recompute offsets of the others from the old parse.
- Case-only rename on Windows (`note.md` → `Note.md`): Phase 1's `move` must handle it (temp name). If it does not, fix it there with a test; do not
  special-case it in the service.
- Never write a file whose text did not change (conventions §6.2) — skip `FileEdit`s that produce identical text.

### 02.12 Backlinks and outgoing-links panes (linked + unlinked mentions)

**Purpose:** Obsidian's backlinks pane (linked mentions with context, unlinked mentions with a "Link" button) and the outgoing-links pane.

**Files**
- `packages/tephra_index/lib/src/links/mention_finder.dart`, `packages/tephra_index/lib/src/util/snippet.dart` (new)
- `packages/tephra_index/lib/src/note_index.dart` (implement `unlinkedMentions`)
- `app/lib/links/backlinks_pane.dart`, `outgoing_links_pane.dart`, `unlinked_mention_linker.dart`, `providers.dart` (new/extend)
- `app/lib/workspace/` — register the panes (desktop right sidebar tabs, phone right drawer tabs) using the mechanism Phase 1 uses for the explorer pane;
  add `activeNotePathProvider` if Phase 1 has no provider for "path of the note in the focused tab"
- tests: `packages/tephra_index/test/links/mention_finder_test.dart`, `test/util/snippet_test.dart`, `app/test/links/backlinks_pane_test.dart`,
  `app/test/links/unlinked_mention_linker_test.dart`

**Implementation**
1. `snippet.dart`: `Snippet makeSnippet(String lineText, int matchStart, int matchEnd, {int maxLength = 160})` → `Snippet { String text; int start; int end; }`.
   If the line fits, return it whole. Otherwise keep up to 60 characters before the match and fill the rest after it; add `'…'` at a cut start and/or
   end; `start/end` are the match range inside the returned text. Leading whitespace of the line is trimmed (adjusting offsets). Shared with `tephra_search`.
2. `mention_finder.dart` (pure):
   ```dart
   /// Finds whole-word, case-insensitive occurrences of [terms] in [text] outside links, code, frontmatter, comments, math, tags and HTML.
   List<UnlinkedMention> findMentions(VaultPath source, String text, List<String> terms);
   ```
   - Excluded ranges = ranges of every `MdWikiLink`, `MdLink`, `MdAutolink`, `MdInlineCode`, `MdCodeBlock`, `MdFrontmatter`, `MdCommentInline`,
     `MdCommentBlock`, `MdInlineMath`, `MdMathBlock`, `MdTag`, `MdHtmlInline`, `MdHtmlBlock` in `MarkdownParser.parse(text)`.
   - For each term (longest first, so `Project Alpha` wins over `Alpha` at the same place): `RegExp('(?<![\\p{L}\\p{N}\\p{M}_])${RegExp.escape(term)}(?![\\p{L}\\p{N}\\p{M}_])', caseSensitive: false, unicode: true)`.
     A match is kept when it does not overlap an excluded range or an already-kept match.
   - `matchedText` = the text as written; `line` and `snippet` via `LineIndex` + `makeSnippet`. Result sorted by `start`.
3. `NoteIndex.unlinkedMentions(target)`:
   1. `terms` = `[target.stem]` + the target's aliases; drop terms shorter than 2 characters; de-duplicate case-insensitively.
   2. Candidates: for each term of ≥ 3 characters (count `runes`): `SELECT n.path FROM fts_trigram JOIN notes n ON n.id = fts_trigram.rowid WHERE fts_trigram MATCH ?`
      with the argument `'body : ' + ftsPhrase(term)` where `ftsPhrase(s) = '"' + s.replaceAll('"', '""') + '"'`. If any term is shorter than 3 characters
      → candidates = all notes. Union; remove `target` itself.
   3. In batches of 100 paths: read texts with `fs.readText` on the calling isolate (async I/O), then `Isolate.run(() => [for each] findMentions(...))`.
   4. Stop after 500 mentions in total. Return sorted by source path, then `start`.
4. Panes. Both follow `activeNotePathProvider`; both refresh when `indexChangesProvider` emits (debounced 300 ms).
   - **Backlinks pane** (`backlinks_pane.dart`):
     - Section "Linked mentions" with a count badge, expanded by default. Data: `backlinksProvider.family(path)` → `index.backlinks(path)` grouped by
       source. Each group: a header row with the source note title (tap → open it) and a collapse chevron; under it one tile per link with a 3-line
       context: the link's line plus one line before and after (read the source text from its open buffer if any, else `fs.readText`), the link text
       shown bold. Tap a tile → open the source note, `select(link.start, link.end)` and `revealOffset`.
     - Section "Unlinked mentions" with a count badge, **collapsed by default**; the query runs only when the section is expanded
       (`unlinkedMentionsProvider.family(path)`). Tiles show the snippet with the match highlighted and a "Link" button (`TextButton`, 48 dp tall on phone).
     - Pane toolbar: sort (file name A–Z / Z–A, modified new–old) and "collapse all".
   - **Outgoing links pane** (`outgoing_links_pane.dart`): `index.outgoing(path)` grouped by `(targetPath ?? targetRaw.toLowerCase(), kind)` with a count.
     Resolved targets: title + folder; tap → `LinkNavigator.open` (with heading/block of the first link). Embeds get an embed icon. Unresolved targets in a
     second section "Unresolved", text at 60 % opacity, each with a "Create" button → `LinkNavigator.open` (which creates).
5. `UnlinkedMentionLinker.link(UnlinkedMention m, VaultPath target)`:
   1. Text = open buffer text or `fs.readText(m.source)`. If `text.substring(m.start, m.end) != m.matchedText` → snackbar `mentionChangedRefresh` and refresh;
      stop.
   2. `path = LinkFormatter(table, settings).linkPath(target, from: m.source, syntax: wiki-or-markdown per settings)`.
      Wiki: `[[path]]` when `m.matchedText == path` (exact, case-sensitive), else `[[path|matchedText]]`. Markdown: `[matchedText](path)`.
   3. Apply as one `TextEdit(m.start, m.end, link)`: buffer → `applyEdits`; disk → `writeText` (keep BOM/line ending) and push a `VaultOperation`
      (no moves, one `FileChange`) so "Undo last rename" style undo also covers it — label the snackbar `mentionLinked` with an "Undo" action.

**Tests**
- `snippet_test.dart`: short line returned whole; 400-character line with match at 300 → result ≤ 162 characters, starts with `'…'`, `text.substring(start, end)` equals the match.
- `mention_finder_test.dart` (terms `['Alpha', 'Project Alpha']`):
  `'Alpha is here'` → 1 at 0; `'alphabet'` → 0; `'the ALPHA.'` → 1 (`matchedText 'ALPHA'`); `'[[Alpha]] and Alpha'` → 1 (the second);
  `` '`Alpha`' `` → 0; `'#Alpha'` → 0 (tag); `'---\ntitle: Alpha\n---\nAlpha'` → 1 (body only); `'Project Alpha rocks'` → 1 with `matchedText 'Project Alpha'`;
  `'%%Alpha%%'` → 0; Bangla term `'বাংলা'` in `'আমি বাংলা জানি'` → 1, in `'বাংলায়'` → 0 (followed by a mark/letter).
- `NoteIndex` test: `Alpha.md` (alias `Al1`), `B.md` = `'I like alpha.\n[[Alpha]]'`, `C.md` = `'al1 rules'`, `D.md` = `'alphabet'` → `unlinkedMentions(Alpha.md)` returns
  exactly B (line 0) and C.
- `unlinked_mention_linker_test.dart`: disk file `'I like alpha.'` → becomes `'I like [[Alpha|alpha]].'`; text `'Alpha'` exact → `'[[Alpha]]'`; with
  `useMarkdownLinks` → `'[alpha](Alpha.md)'`; changed text → no write, refresh message.
- `backlinks_pane_test.dart`: with a fake index returning 2 sources × 1 link → 2 group headers and 2 tiles with the linked word bold; unlinked section collapsed and
  the fake's `unlinkedMentions` **not** called until expanded.

**Verify:** package + app tests. Manual (both platforms): open a note linked from 3 notes → backlinks show 3 linked mentions with context; expand unlinked
mentions → tap "Link" → the mention becomes a link and moves to linked mentions within 1 s. Commit `phase 02.12: add backlinks and outgoing links panes`.

**Pitfalls**
- Never run `unlinkedMentions` automatically for every note switch — it reads files; it runs only when the section is expanded.
- `RegExp.escape` on the term, always; note names contain `(`, `+`, `?`.

---

### 02.13 Outline pane (headings tree, jump, drag sections on desktop)

**Purpose:** headings of the active note as a tree, live while typing; click to jump; on desktop drag a heading to move its whole section.

**Files**
- `app/lib/outline/outline_pane.dart`, `outline_tree.dart`, `section_mover.dart`, `providers.dart` (new)
- `app/lib/editor/providers.dart` (add `activeParsedNoteProvider` if Phase 1 has no live parse provider for the active editor)
- Reading view: `scrollToOffset(int offset)` (add if missing — see sub-step 4)
- tests: `app/test/outline/outline_tree_test.dart`, `app/test/outline/section_mover_test.dart`, `app/test/outline/outline_pane_test.dart`

**Implementation**
1. Source of headings: the **live** text of the active tab (open buffer), not the index (the buffer can be unsaved). `activeParsedNoteProvider` re-parses the
   active editor's text 300 ms after the last edit: texts ≤ 50,000 characters are parsed synchronously, longer ones with `Isolate.run`. In reading view it uses
   the parse the reading view already has.
2. `outline_tree.dart`: `List<OutlineNode> buildOutline(List<MdHeading> headings)`; `OutlineNode { MdHeading heading; String text; List<OutlineNode> children; }`.
   Parent = nearest previous heading with a **lower** level; a heading with no such heading is a root (so `### A` before any `#` is a root).
3. `section_mover.dart`:
   ```dart
   /// Range of the section of headings[index]: heading start → start of the next heading with level <= its level, or text.length.
   (int, int) sectionOf(List<MdHeading> headings, int index, int textLength);
   /// Edits that move section [index] so it starts at [insertAt] (a heading start or text.length). Returns null when insertAt is inside the section
   /// (including its start and end) — the move is not allowed.
   List<TextEdit>? moveSectionEdits(String text, List<MdHeading> headings, int index, int insertAt);
   ```
   `moveSectionEdits`: `(s, e) = sectionOf(...)`; `moved = text.substring(s, e)`; if `moved` does not end with `'\n'` (the section ends at EOF) → `moved += '\n'`
   and the deletion range becomes `(s - 1 if text[s-1] == '\n' and s > 0 else s, e)` so no blank line is left at the end; if `insertAt == text.length` and
   `text` does not end with `'\n'` → insert `'\n' + moved` instead. Return `[TextEdit(s', e, ''), TextEdit(insertAt, insertAt, moved')]` (non-overlapping because
   `insertAt` is outside the section). Heading levels are not changed (Obsidian keeps them).
4. Jump: tap a node → editor modes: `controller.select(h.start)` + `revealOffset(h.start)`; reading view: `scrollToOffset(h.start)`. If Phase 1's reading view
   has no way to scroll to a block, add `ReadingViewController.scrollToOffset(int offset)`: find the block index containing the offset; if the reading view
   uses `ListView.builder` without index scrolling, add the dependency `scrollable_positioned_list` (BSD-3-Clause; run the licence check) and use
   `ItemScrollController.jumpTo(index: i)`. Record which approach you used.
5. Pane UI: indented rows (16 dp per depth), chevron to collapse children, heading text, the heading containing the caret highlighted (background tint).
   Desktop (width ≥ 840): each row is a `Draggable<int>` (data = heading index) with drop targets as 4 dp gaps above each row and one at the end; while dragging,
   gaps that `moveSectionEdits` rejects are not highlighted. Drop → `controller.applyEdits(edits)` (one undo step). Phone: no drag; long-press a row opens a menu
   with "Copy link to heading" (wikilink `[[Stem#Heading]]` via `LinkFormatter.buildLink`) and "Bookmark heading" (wired in step 02.18).
6. Panes placement: desktop right sidebar tab "Outline"; phone right drawer tab "Outline".

**Tests**
- `outline_tree_test.dart`: `# A, ## B, ### C, ## D, # E` → roots `A, E`; `A.children = [B, D]`; `B.children = [C]`. `### X, # Y` → roots `X, Y`.
- `section_mover_test.dart` (text `'# A\na\n## B\nb\n# C\nc'`): `sectionOf(B)` = `'## B\nb\n'`; `sectionOf(A)` = `'# A\na\n## B\nb\n'`; `sectionOf(C)` = `'# C\nc'`.
  Move C before A → `'# C\nc\n# A\na\n## B\nb\n'`; move B to end → `'# A\na\n# C\nc\n## B\nb\n'`; move A to `insertAt` = B.start → `null`; move A to end →
  `'# C\nc\n# A\na\n## B\nb\n'`.
- `outline_pane_test.dart`: tree renders 3 levels; tapping a row calls `select` on a fake controller with the heading start; at 1200 dp rows are draggable, at 400 dp they are not.

**Verify:** app tests; manual on Windows: drag a `##` section above another → moved, Ctrl+Z restores in one step. Commit `phase 02.13: add outline pane with section moving`.

**Pitfalls:** headings inside code blocks are not headings — use the parser's `MdHeading` list only, never a regex.

---

### 02.14 Embeds and transclusion in reading view; page preview

**Purpose:** render `![[...]]`/`![](...)` embeds (notes, sections, blocks, images; chips for other files) with a recursion guard, and show a page-preview popup on
hover (desktop) or long-press (phone).

**Files**
- `app/lib/reading/embeds/embed_view.dart`, `embed_context.dart`, `note_embed.dart`, `image_embed.dart`, `file_chip.dart`, `embed_slice.dart` (new)
- `app/lib/links/page_preview.dart`, `page_preview_controller.dart` (new)
- Reading view renderer (Phase 1): call `EmbedView` for embed nodes; wrap internal links with the preview trigger
- Settings: `pagePreviewReadingRequiresCtrl` (default `false`), `pagePreviewEditorRequiresCtrl` (default `true`) — app-level settings
- tests: `app/test/reading/embeds/embed_slice_test.dart`, `embed_view_test.dart`, `app/test/links/page_preview_test.dart`

**Implementation**
1. `embed_slice.dart` (pure Dart, no Flutter): `EmbedSlice? sliceForEmbed(String text, ParsedNote parsed, {String? heading, String? blockRef})` →
   `EmbedSlice { int start; int end; }`:
   - no heading/block → whole note **after** the frontmatter (`MdFrontmatter.contentStart`, else 0) to the end;
   - heading → `findHeading` (convert the parser's `MdHeading`s to `HeadingRecord`-like values) then `sectionRange` (heading line included, like Obsidian);
     not found → null;
   - block → the owning block range of the `BlockRef` with that id (case-insensitive) — for a list item, the item including its nested children; not found → null.
2. `EmbedContext` — an `InheritedWidget` carrying `int depth` and `Set<VaultPath> chain` (paths of the notes currently being rendered, outermost first). The reading
   view root provides `depth 0, chain {thisNote}`.
3. `EmbedView` (for `MdWikiLink(embed: true)` and `MdLink(image: true)` with an internal URL): resolve the target with `linkResolutionProvider((from, target))`.
   Then by extension of the resolved path (lower-case):
   - unresolved → grey box (`embedNotFound` "“{target}” could not be found") with a "Create" button (`LinkNavigator.open`), except non-`md` targets which have no button;
   - `md` → `NoteEmbed`: if `context.depth >= 5` → chip `embedTooDeep`; if `path` is in `chain` → chip `embedCircular`; else read the note text (open buffer or
     `fs.readText`, via `embedTextProvider.family(path)` invalidated on `indexChangesProvider` events for that path), slice it, `MarkdownParser.parse(sliceText)`, and
     render it with the reading-view renderer inside a bordered container (left border 2 dp, accent colour) with a header row (note title, plus `> Heading` for
     sections) whose tap opens the note at that place. Wrap the child in `EmbedContext(depth + 1, chain ∪ {path})`. Missing heading/block → box
     `embedSectionNotFound`. Embedded content is read-only (task checkboxes inside embeds are disabled in Phase 2).
   - `png, jpg, jpeg, gif, webp, bmp` → `ImageEmbed` with `Image.file`; size `W` → width W, height auto (aspect kept); `WxH` → `SizedBox(width: W, height: H)` with
     `BoxFit.contain`; no size → natural size capped at the reading width. Decode errors → chip. `svg` → chip (unless Phase 1 already renders SVG — then reuse it).
   - `mp3, wav, m4a, ogg, flac, 3gp, mp4, webm, ogv, mov, mkv, pdf, canvas, base` and every other extension → `FileChip` (icon by type, file name, size, for PDF
     `#page=N` shown as "page N"). Tap: Windows → `launchUrl(Uri.file(absolutePath))` (absolute path = `p.join(rootDir, path.value)`); Android → snackbar
     `embedMediaLaterPhase` ("Playing and viewing this file type arrives in a later version").
   Embeds whose markdown image URL is external (`http(s)://`) → `Image.network` only if Phase 1 already does that; otherwise unchanged Phase 1 behaviour.
4. Page preview:
   - `PagePreviewController` (one per window, `pagePreviewControllerProvider`) manages one popup stack (max **3** nested popups; a link inside a popup can open a
     child popup; depth 3 links do not open more).
   - Desktop triggers (any pointer with hover): `MouseRegion` around each internal link span in reading view (and, from step 02.23, in Live Preview). Enter starts
     a 600 ms timer; when it fires, if the setting for that view requires Ctrl and `HardwareKeyboard.instance.isControlPressed` is false → do nothing; else show
     the popup. Exit from link and popup for 300 ms → close (and close its children).
   - Phone/touch trigger: long-press on an internal link (`onLongPress` on the link gesture recognizer) → popup; tap outside closes; Android back closes.
   - Popup: `OverlayPortal`/`Overlay` entry, `Material` with elevation 8, size `min(400, screenWidth − 32)` × `min(500, screenHeight × 0.7)`; placed below the
     link if it fits, else above; clamped inside the window with 8 dp margins. Content: a scrollable reading view of the target — notes scroll to the
     heading/block given in the link (use `scrollToOffset`), images show the image, other files a `FileChip`, unresolved targets show `previewNotCreated` and a
     "Create" button. Esc closes the top popup.

**Tests**
- `embed_slice_test.dart`: text `'---\na: 1\n---\nIntro\n# H\nx ^b1\n## Sub\ny\n# Next\nz'` → whole = from `'Intro'` to end; heading `H` = `'# H\nx ^b1\n## Sub\ny\n'`;
  heading `h#sub` = `'## Sub\ny\n'`; block `B1` = `'x ^b1'`; heading `Missing` → null.
- `embed_view_test.dart` (fake index/fs): note A embeds B embeds A → B renders once, inner A shows `embedCircular`; a chain of 7 notes each embedding the next →
  the 6th level shows `embedTooDeep`; `![[pic.png|120]]` → `Image` widget with width 120; `![[song.mp3]]` → `FileChip`; unresolved `![[Nope]]` → not-found box
  with a Create button.
- `page_preview_test.dart`: desktop width, hover a link for 599 ms → no popup; 601 ms → popup; with "requires Ctrl" → no popup unless Ctrl is held
  (simulate with `simulateKeyDownEvent(LogicalKeyboardKey.controlLeft)`); phone width long-press → popup; nested depth: opening a 4th popup is refused.

**Verify:** app tests; manual on both platforms with `test_vaults/syntax` embed notes: note embed, section embed, block embed, sized image, an mp4 chip, a
self-embedding note shows the circular chip. Commit `phase 02.14: add embeds, transclusion and page preview`.

**Pitfalls**
- Never parse an embedded note on the UI isolate if it is longer than 50,000 characters — use `Isolate.run`.
- `Image.file` needs an absolute path; never build it by string concatenation (`p.join`).

### 02.15 Search query parser (`tephra_search`)

**Purpose:** parse Obsidian's search syntax into a `SearchExpr` tree, exactly and leniently where Obsidian is lenient.

**Files**
- `packages/tephra_search/lib/src/parser/search_expr.dart`, `search_parser.dart`, `search_syntax_exception.dart`, `search_expr_printer.dart` (new)
- `packages/tephra_search/lib/tephra_search.dart` (exports)
- `packages/tephra_search/pubspec.yaml`: dependencies `tephra_core`, `tephra_markdown`, `tephra_index` (path/workspace deps as Phase 0 set up for other
  packages), `logging`; dev `test`
- tests: `packages/tephra_search/test/parser/search_parser_test.dart`

**Implementation**
1. AST (`search_expr.dart`, sealed, immutable, value equality):
   ```dart
   sealed class SearchExpr { const SearchExpr(); }
   final class EmptyExpr extends SearchExpr { const EmptyExpr(); }                       // empty query or empty operator value
   final class AndExpr extends SearchExpr { const AndExpr(this.children); final List<SearchExpr> children; }   // ≥ 2 children, flattened
   final class OrExpr extends SearchExpr { const OrExpr(this.children); final List<SearchExpr> children; }     // ≥ 2 children, flattened
   final class NotExpr extends SearchExpr { const NotExpr(this.child); final SearchExpr child; }
   final class TermExpr extends SearchExpr { const TermExpr(this.text); final String text; }
   final class PhraseExpr extends SearchExpr { const PhraseExpr(this.text); final String text; }               // may be ''
   final class RegexExpr extends SearchExpr { const RegexExpr(this.pattern, this.flags); final String pattern; final String flags; } // flags ⊆ 'imsu'
   enum SearchOperator { file, path, content, tag, line, block, section, task, taskTodo, taskDone, matchCase, ignoreCase }
   final class OperatorExpr extends SearchExpr { const OperatorExpr(this.op, this.value); final SearchOperator op; final SearchExpr value; }
   sealed class PropertyValue { const PropertyValue(); }
   final class PropertyExists extends PropertyValue { const PropertyExists(); }     // [prop]
   final class PropertyIsEmpty extends PropertyValue { const PropertyIsEmpty(); }   // [prop:] or [prop:null]
   final class PropertyMatches extends PropertyValue { const PropertyMatches(this.expr); final SearchExpr expr; }
   final class PropertyExpr extends SearchExpr { const PropertyExpr(this.name, this.value); final String name; final PropertyValue value; }
   ```
   `SearchSyntaxException extends ParseException` with `int offset` (0-based character offset in the query).
2. Grammar (EBNF; `ws` = one or more Unicode whitespace characters):
   ```ebnf
   query      = [ws], [ orExpr ], [ws] ;
   orExpr     = andExpr, { ws, "OR", ws, andExpr } ;
   andExpr    = unary, { ws, unary } ;
   unary      = "-", primary            (* only when "-" is directly followed by a non-whitespace character *)
              | primary ;
   primary    = group | operator | property | phrase | regex | term ;
   group      = "(", [ws], orExpr, [ws], ")" ;
   operator   = opName, ":", [ opValue ] ;           (* opName matched case-insensitively *)
   opName     = "file" | "path" | "content" | "tag" | "line" | "block" | "section"
              | "task" | "task-todo" | "task-done" | "match-case" | "ignore-case" ;
   opValue    = group | phrase | regex | word ;      (* for match-case / ignore-case: primary *)
   property   = "[", propName, [ ":", [ propBody ] ], "]" ;
   propName   = { char - ( ":" | "]" ) }- ;           (* trimmed *)
   propBody   = orExpr over the text up to the closing "]" | "null" ;
   phrase     = '"', { '\"' | '\\' | char - '"' }, ( '"' | end ) ;
   regex      = "/", { "\/" | char - "/" }-, "/", { "i" | "m" | "s" | "u" } ;   (* must be followed by ws, ")" or end *)
   term       = word ;
   word       = { char - ( ws | "(" | ")" ) }- ;      (* a word may contain '"', ':', '-', '[', '#', '/' after its first character *)
   ```
   Precedence: `OR` lowest; implicit AND (whitespace) binds tighter than `OR`; unary `-` binds tightest. `a OR b c` = `a OR (b AND c)`.
3. Parser: hand-written, **scannerless recursive descent** over the query string with a position index. Exact rules:
   - `OR` is the keyword only when it is exactly the uppercase two letters, preceded by whitespace and followed by whitespace, `(` or end, **and** there is an
     operand on both sides. Otherwise it is the term `OR` (so `OR a` → `and(term(OR), term(a))` and `a OR` → `and(term(a), term(OR))`). `or` lowercase is a term.
     There is no `AND` keyword (`AND` is a term).
   - `-` followed by whitespace or end → the term `-`. `-` followed by anything else → `NotExpr(primary)`.
   - At a primary position: `(` → group; `"` → phrase; `/` → try regex, and if no valid closing (`/` + optional flags + ws/`)`/end) is found → word; `[` → try property:
     find the next `]` that is not inside double quotes; if none → word; else parse it. Otherwise check `^([A-Za-z-]+):` at the position: if the name (lower-cased)
     is an `opName` → operator; else → word.
   - Operator value: the character after `:`: `(` → group; `"` → phrase; `/` → regex (fallback word); whitespace, `)` or end → `EmptyExpr`; else → word. For `tag`,
     a leading `#` of a word value is removed (`tag:#work` ≡ `tag:work`). For `match-case`/`ignore-case` the value is a full `primary` (so `match-case:file:X` works).
   - Phrase: backslash escapes only `\"` → `"` and `\\` → `\`; any other backslash is kept literally. Unterminated → phrase to the end of the query.
   - Regex: pattern text between the slashes with `\/` kept as `\/` (Dart's `RegExp` accepts it). Validate with
     `RegExp(pattern, caseSensitive: !flags.contains('i'), multiLine: flags.contains('m'), dotAll: flags.contains('s'), unicode: flags.contains('u'))`;
     `FormatException` → `SearchSyntaxException('Invalid regular expression', offset of '/')`. Empty `//` → word `//`.
   - Property body: the text between `:` and `]`, trimmed. `''` or `null` (case-insensitive) → `PropertyIsEmpty`. Otherwise parse it with a **nested parser
     instance** (same rules, but `[` inside is a plain word character) → `PropertyMatches(expr)`. Offsets in errors from the nested parser are shifted to the
     outer query.
   - Errors: `)` with no open group → exception at its offset; end of input inside a group → exception at the `(`; `()` (empty group) → exception at the `(`.
   - Result normalisation: an `AndExpr`/`OrExpr` with one child is replaced by the child; nested ones of the same type are flattened. Whitespace-only query →
     `EmptyExpr`.
4. `search_expr_printer.dart`: `String printExpr(SearchExpr e)` canonical form used by tests and logs: `empty`, `and(a, b)`, `or(a, b)`, `not(x)`, `term(x)`,
   `phrase(x)`, `regex(pattern/flags)`, `<op-name>(value)` with op names as written in the grammar (`task-todo`, `match-case`, …), `prop(name)`,
   `prop(name:empty)`, `prop(name:<expr>)`.

**Tests** (`search_parser_test.dart`; each row is one `test`, comparing `printExpr(SearchParser.parse(q))`):
| # | query | expected |
|---|---|---|
| 1 | `meeting` | `term(meeting)` |
| 2 | `meeting bob` | `and(term(meeting), term(bob))` |
| 3 | `a OR b c` | `or(term(a), and(term(b), term(c)))` |
| 4 | `a b OR c` | `or(and(term(a), term(b)), term(c))` |
| 5 | `-a b` | `and(not(term(a)), term(b))` |
| 6 | `(a OR b) c` | `and(or(term(a), term(b)), term(c))` |
| 7 | `"meeting notes"` | `phrase(meeting notes)` |
| 8 | `"say \"hi\""` | `phrase(say "hi")` |
| 9 | `/55\d/` | `regex(55\d/)` |
| 10 | `/a/i` | `regex(a/i)` |
| 11 | `/usr/bin` | `term(/usr/bin)` |
| 12 | `file:alpha` | `file(term(alpha))` |
| 13 | `file:"Epsilon Notes"` | `file(phrase(Epsilon Notes))` |
| 14 | `path:(a OR b)` | `path(or(term(a), term(b)))` |
| 15 | `tag:#work` | `tag(term(work))` |
| 16 | `line:(meeting bob)` | `line(and(term(meeting), term(bob)))` |
| 17 | `section:(a -b)` | `section(and(term(a), not(term(b))))` |
| 18 | `task-todo:report` | `task-todo(term(report))` |
| 19 | `task-done:""` | `task-done(phrase())` |
| 20 | `match-case:Meeting` | `match-case(term(Meeting))` |
| 21 | `[status]` | `prop(status)` |
| 22 | `[status:draft]` | `prop(status:term(draft))` |
| 23 | `[status:draft OR done]` | `prop(status:or(term(draft), term(done)))` |
| 24 | `[status:]` and `[status:null]` | `prop(status:empty)` |
| 25 | `http://x.y` | `term(http://x.y)` |
| 26 | `foo-bar` | `term(foo-bar)` |
| 27 | `-` | `term(-)` |
| 28 | `OR a` | `and(term(OR), term(a))` |
| 29 | `a OR` | `and(term(a), term(OR))` |
| 30 | `` and `   ` | `empty` |
| 31 | `a)` | throws `SearchSyntaxException`, offset 1 |
| 32 | `(a` | throws, offset 0 |
| 33 | `()` | throws, offset 0 |
| 34 | `/(/` | throws, offset 0 |
| 35 | `"unterminated` | `phrase(unterminated)` |
| 36 | `FILE:x` | `file(term(x))` |
| 37 | `unknown:x` | `term(unknown:x)` |
| 38 | `[a b` | `and(term([a), term(b))` |
| 39 | `-(a OR b)` | `not(or(term(a), term(b)))` |
| 40 | `বাংলায়` | `term(বাংলায়)` |
| 41 | `task:` | `task(empty)` |
| 42 | `match-case:file:X` | `match-case(file(term(X)))` |
| 43 | `a OR b OR c` | `or(term(a), term(b), term(c))` |
| 44 | `[due:(2026 OR 2027)]` | `prop(due:or(term(2026), term(2027)))` |

**Verify:** `cd packages/tephra_search; dart test`. Commit `phase 02.15: add obsidian search query parser`.

**Pitfalls:** do not build a separate tokenizer that splits on whitespace first — phrases, regexes and property bodies contain whitespace.

---

### 02.16 Search engine: SQL/FTS compilation, verification, streaming, sorting, cancellation

**Purpose:** run a `SearchExpr` against the index fast (SQL candidate set) and exactly (verification on the note text), streaming sorted results.

**Files**
- `packages/tephra_search/lib/src/compile/sql_compiler.dart`, `compiled_query.dart`, `fts_escape.dart` (new)
- `packages/tephra_search/lib/src/verify/note_doc.dart`, `search_matcher.dart`, `verify_batch.dart` (new)
- `packages/tephra_search/lib/src/engine/search_engine.dart`, `search_result.dart`, `search_match.dart`, `search_sort.dart`, `cancel_token.dart` (new)
- `test_vaults/search/` (new fixture vault, 10 notes — exact content below)
- tests: `packages/tephra_search/test/compile/sql_compiler_test.dart`, `test/verify/search_matcher_test.dart`, `test/engine/search_engine_test.dart`,
  `test/engine/search_parity_test.dart`

**Implementation**
1. Public types:
   ```dart
   final class CancelToken { bool get isCancelled; void cancel(); }
   enum SearchSort { fileNameAsc, fileNameDesc, modifiedDesc, modifiedAsc, createdDesc, createdAsc }
   final class SearchMatch { const SearchMatch({required this.line, required this.start, required this.end, required this.snippet,
       required this.snippetStart, required this.snippetEnd, this.inFileName = false});
     final int line; final int start; final int end; final String snippet; final int snippetStart; final int snippetEnd; final bool inFileName; }
   final class SearchResult { const SearchResult(this.path, this.matches); final VaultPath path; final List<SearchMatch> matches; }
   final class SearchEngine {
     SearchEngine(this.index, this.fs);
     Stream<SearchResult> run(SearchExpr expr, {CancelToken? cancel, SearchSort sort = SearchSort.fileNameAsc, bool matchCase = false});
   }
   ```
   (`matchCase` is the panel's global "Match case" toggle; `match-case:`/`ignore-case:` override it locally.) For a file-name match, `line = -1`,
   `start = end = 0`, `snippet` = the file name.
2. Semantics (what "matches" means; the verification pass implements exactly this):
   - A **term** or **phrase** matches a note when its text occurs as a **substring** of the note content (frontmatter included) **or** of the file name
     (`path.name`), case-insensitively unless match-case is active. A phrase is the same with spaces included. `""` matches every note.
   - `content:X` — like a term but content only (not the file name). `file:X` — X evaluated against `path.name`; `path:X` — against `path.value`.
   - `tag:X` — the note has a tag (inline or frontmatter) equal to X or starting with `X/`, case-insensitive. `tag:` empty → the note has any tag.
   - `task:X` / `task-todo:X` / `task-done:X` — some task item (any status / status `' '` / status not `' '`) whose text matches X. Empty value or `""` → any such task.
   - `line:(X)`, `block:(X)`, `section:(X)` — some single line / block / section satisfies X as a whole (all terms inside the same unit). Block = each top-level
     child of the document except the frontmatter (a whole list, block quote, callout, table, code block, paragraph or heading is one block). Section = the text
     from the start of the body (after frontmatter) to the first heading, and from each heading to the next heading of **any** level.
   - `[p]` — frontmatter has key p (case-insensitive key). `[p:]`/`[p:null]` — key present and value null, `''` or an empty list. `[p:X]` — some value (each list
     element separately; numbers/booleans by their string form) matches X as a substring expression (case-insensitive by default).
   - `/re/flags` — Dart `RegExp` over the content (not the file name); case-sensitive unless the `i` flag is given; `match-case:`/`ignore-case:` do not change regexes.
   - `match-case:X` / `ignore-case:X` — evaluate X case-sensitively / case-insensitively.
   - `-X` — X does not match. `A B` — both. `A OR B` — either.
   - Only notes (`*.md`) are searched.
3. **Compilation to SQL** (`sql_compiler.dart`) — `CompiledQuery compile(SearchExpr e, {required bool caseSensitive})` → `CompiledQuery { String sql; List<Object?> args; bool exact; }`
   where `sql` is a `SELECT` returning one column `id` (= `notes.id`) and `exact == true` means the set is exactly the matching notes **for the purpose of
   negation**; `exact == false` means it is a superset. Every leaf is compiled with a context `(caseSensitive, fileScope)`; `fileScope` is false inside
   `line:`/`block:`/`section:`.
   | Node | SQL (subquery) | exact |
   |---|---|---|
   | ALL (helper) | `SELECT id FROM notes` | false |
   | `EmptyExpr` | ALL | true |
   | term/phrase, ≥ 3 runes | `SELECT rowid AS id FROM fts_trigram WHERE fts_trigram MATCH ?` arg `ftsPhrase(t)` | `!caseSensitive && fileScope` |
   | term/phrase, < 3 runes (not `""`) | ALL | false |
   | `content:` term/phrase ≥ 3 runes | same with arg `'body : ' + ftsPhrase(t)` | `!caseSensitive && fileScope` |
   | `file:` term/phrase | `SELECT n.id FROM notes n JOIN files f ON f.path = n.path WHERE instr(f.name_key, ?) > 0` arg `t.toLowerCase()` | `!caseSensitive` |
   | `path:` term/phrase | same with `f.case_key` | `!caseSensitive` |
   | `tag:` word | `SELECT n.id FROM notes n JOIN tags t ON t.path = n.path WHERE t.tag_lower = ? OR substr(t.tag_lower, 1, ?) = ?` args `[x, x.runes.length + 1, '$x/']` (x lower-case) | true |
   | `tag:` empty | `SELECT n.id FROM notes n JOIN tags t ON t.path = n.path` | true |
   | `task*:` term/phrase | `SELECT n.id FROM notes n JOIN tasks k ON k.path = n.path WHERE instr(k.task_lower, ?) > 0` + status filter (`AND k.status_char = ' '` / `AND k.status_char <> ' '`) | `!caseSensitive` |
   | `task*:` empty or `""` | same without `instr` | true |
   | `[p]` | `SELECT n.id FROM notes n JOIN properties p ON p.path = n.path WHERE p.key_lower = ?` | true |
   | `[p:]` | that `AND (p.value_text IS NULL OR p.value_text = '')` | true |
   | `[p:X]`, X a single term/phrase | that `AND instr(p.value_lower, ?) > 0` | `!caseSensitive` |
   | `file:`/`path:`/`task*:`/`[p:X]` with any other value (group, regex, negation) | the operator's "has any" query (`[p]`, notes with tasks of that status, ALL for file/path) | false |
   | regex | ALL | false |
   | `line:`/`block:`/`section:`(X) | `compile(X, fileScope: false).sql` | false |
   | `match-case:`(X) / `ignore-case:`(X) | `compile(X, caseSensitive: true/false)` | from X |
   | `A B …` | `SELECT id FROM (a) INTERSECT SELECT id FROM (b) …`; children that are ALL are dropped (if all are ALL → ALL) | all children exact |
   | `A OR B …` | `SELECT id FROM (a) UNION SELECT id FROM (b) …`; any ALL child → ALL | all children exact |
   | `-X`, X exact and `fileScope` | `SELECT id FROM notes EXCEPT SELECT id FROM (x)` | true |
   | `-X` otherwise | ALL | false |
   `ftsPhrase(s) = '"' + s.replaceAll('"', '""') + '"'` (FTS5 escaping: the whole term is one quoted string, internal quotes doubled; this also neutralises
   FTS operators like `AND`, `NEAR`, `*`, `:` inside user text). Compound nesting deeper than 40 levels → compile the whole query as ALL (verification still gives
   correct results). Final query:
   ```sql
   SELECT f.path, f.mtime, f.created FROM notes n JOIN files f ON f.path = n.path
   WHERE n.id IN (<compiled>) ORDER BY <order>
   ```
   Orders: `fileNameAsc` → `f.name_key ASC, f.path ASC`; `fileNameDesc` → `f.name_key DESC, f.path DESC`; `modifiedDesc` → `f.mtime DESC, f.path ASC`;
   `modifiedAsc` → `f.mtime ASC, f.path ASC`; `createdDesc` → `COALESCE(f.created, f.mtime) DESC, f.path ASC`; `createdAsc` → `COALESCE(f.created, f.mtime) ASC, f.path ASC`.
4. **Verification** (`search_matcher.dart`, pure): `MatchOutcome evaluate(SearchExpr e, NoteDoc doc, {required bool caseSensitive})` →
   `MatchOutcome { bool matched; List<SearchMatch> matches; }`. `NoteDoc` holds `path`, `text`, `ParsedNote parsed`, `LineIndex lines`, precomputed block ranges,
   section ranges, tasks (range + status + text), lower-cased tags, frontmatter map. Evaluation is recursive over a **scope** = a region `[start, end)` of a source
   string plus a flag "file name also counts" (true only at file scope). Rules: term/phrase → all occurrences in the region via
   `RegExp(RegExp.escape(t), caseSensitive: cs, unicode: true)` (never compare lower-cased copies — lower-casing can change string length); file-name fallback
   when allowed; `line`/`block`/`section` iterate the units intersecting the current region and evaluate the inner expression with each unit as the region (file
   name not allowed); task operators iterate task items; `NotExpr` evaluates its child with hit collection switched off; And/Or evaluate **all** children (to
   collect highlight ranges) and combine. Hits are converted to `SearchMatch` (line of the hit start, `makeSnippet` of that line from `tephra_index`; a hit
   spanning lines is clamped to its first line), de-duplicated, sorted by `start`, capped at 100 per note.
5. `verify_batch.dart`: top-level `List<SearchResult?> verifyBatch(VerifyBatchInput input)` (input = expr, caseSensitive, list of `(path, text)`), parsing each text
   with `MarkdownParser.parse` and evaluating; returns null for non-matching notes. Runs inside `Isolate.run`.
6. `SearchEngine.run`:
   1. `EmptyExpr` at the top → the stream closes with no results.
   2. `compile` → `rows = await index.rawSelect(finalSql, args)` (already sorted).
   3. For batches of candidates — first batch 20, then 100 each: stop if `cancel?.isCancelled`; read texts with `fs.readText` (skip a path that no longer exists);
      `out = await Isolate.run(() => verifyBatch(...))`; check cancel again; `yield` each non-null result in candidate order.
   4. SQL errors surface as `IndexQueryException` (from `rawSelect`) and are passed to the stream as errors; cancellation simply ends the stream without an error.
7. Fixture vault `test_vaults/search/` — create exactly these files (UTF-8, LF):
   - `Alpha.md`:
     ```
     ---
     tags: [project, work]
     status: draft
     priority: 2
     aliases: [First]
     ---
     # Alpha plan
     The meeting is on Monday.
     - [ ] write report
     - [x] book room

     ## Notes
     Budget review with Bob.
     ```
   - `Beta.md`:
     ```
     ---
     status: done
     tags: project/sub
     ---
     # Beta
     Meeting notes from Tuesday. #urgent
     - [ ] call Alice

     Report finished.
     ```
   - `Gamma.md`:
     ```
     # Gamma
     Nothing about meetings here, only a recipe.
     Flour, sugar and eggs.
     ```
   - `Projects/Delta.md`:
     ```
     ---
     status:
     ---
     # Delta
     Project kickoff with the Team.
     ```
   - `Projects/Epsilon Notes.md`:
     ```
     # Epsilon
     - [/] partial task about report
     - [-] cancelled item

     The quick brown fox.
     ```
   - `Archive/Zeta.md`:
     ```
     ---
     tags:
       - archive
     reviewed: true
     ---
     Old meeting minutes. #work/old
     "exact phrase here"
     ```
   - `Daily/2026-10-11.md`:
     ```
     # 2026-10-11
     ## Morning
     Coffee and code.
     ## Evening
     Meeting with Bob about budget.
     ```
   - `বাংলা.md`:
     ```
     # বাংলা নোট
     আমি বাংলায় গান গাই।
     ```
   - `Case.md`:
     ```
     Apple apple APPLE
     color colour
     ```
   - `Regex.md`:
     ```
     Call 555-1234 or 555-9876.
     Order #123 shipped.
     ```

**Sample queries** (the parity set; `search_parity_test.dart` opens `test_vaults/search` with `IoVaultFileSystem`, `NoteIndex.open(':memory:', fs)`, reconciles,
runs each query with the default sort and asserts the **set of paths** equals the expected set; matches must be non-empty for every result except the
file-name-only and empty-phrase cases):
| # | query | expected notes | semantics shown |
|---|---|---|---|
| Q1 | `meeting` | Alpha, Beta, Gamma, Archive/Zeta, Daily/2026-10-11 | case-insensitive substring (`meetings`, `Meeting`) |
| Q2 | `meeting bob` | Alpha, Daily/2026-10-11 | implicit AND across the file |
| Q3 | `meeting OR recipe` | Alpha, Beta, Gamma, Archive/Zeta, Daily/2026-10-11 | OR |
| Q4 | `meeting -bob` | Beta, Gamma, Archive/Zeta | negation |
| Q5 | `"meeting notes"` | Beta | phrase |
| Q6 | `"Meeting with Bob"` | Daily/2026-10-11 | phrase, case-insensitive |
| Q7 | `match-case:Meeting` | Beta, Daily/2026-10-11 | match-case |
| Q8 | `match-case:aPPLE` | (none) | match-case, no match |
| Q9 | `ignore-case:APPLE` | Case | ignore-case |
| Q10 | `file:alpha` | Alpha | file name |
| Q11 | `file:"Epsilon Notes"` | Projects/Epsilon Notes | file name phrase |
| Q12 | `path:Projects` | Projects/Delta, Projects/Epsilon Notes | path |
| Q13 | `path:archive meeting` | Archive/Zeta | path + term |
| Q14 | `tag:#project` | Alpha, Beta | tag incl. nested child `project/sub` |
| Q15 | `tag:project/sub` | Beta | nested tag |
| Q16 | `tag:#work` | Alpha, Archive/Zeta | frontmatter tag + inline nested `#work/old` |
| Q17 | `tag:#urgent OR tag:#archive` | Beta, Archive/Zeta | OR of operators |
| Q18 | `task:report` | Alpha, Projects/Epsilon Notes | any task status; `Report finished.` is not a task |
| Q19 | `task-todo:report` | Alpha | open tasks only (`[/]` counts as done) |
| Q20 | `task-done:""` | Alpha, Projects/Epsilon Notes | any done task |
| Q21 | `task-todo:call` | Beta | `Call 555…` in Regex.md is not a task |
| Q22 | `line:(meeting bob)` | Daily/2026-10-11 | same line |
| Q23 | `section:(coffee budget)` | (none) | different sections |
| Q24 | `section:(meeting budget)` | Daily/2026-10-11 | same section; Alpha has them in different sections |
| Q25 | `block:(flour recipe)` | Gamma | same paragraph block |
| Q26 | `line:(recipe flour)` | (none) | different lines |
| Q27 | `[status]` | Alpha, Beta, Projects/Delta | property exists (Delta has an empty value) |
| Q28 | `[status:draft]` | Alpha | property value |
| Q29 | `[status:draft OR done]` | Alpha, Beta | property sub-expression |
| Q30 | `[status:]` | Projects/Delta | empty property |
| Q31 | `[reviewed:true]` | Archive/Zeta | boolean property |
| Q32 | `/555-\d{4}/` | Regex | regex |
| Q33 | `/colou?r/` | Case | regex |
| Q34 | `বাংলায়` | বাংলা | Bangla substring |
| Q35 | `-meeting -recipe` | Projects/Delta, Projects/Epsilon Notes, বাংলা, Case, Regex | pure negation |
| Q36 | `(meeting OR coffee) budget` | Alpha, Daily/2026-10-11 | grouping |
| Q37 | `"exact phrase here"` | Archive/Zeta | phrase containing quotes in the text |
| Q38 | `#urgent` | Beta | a plain term with `#` is text search |
| Q39 | `#123` | Regex | not a tag, still text |
| Q40 | `ox` | Projects/Epsilon Notes | short term (< 3 characters) via full scan |
| Q41 | `notes` | Alpha, Beta, Projects/Epsilon Notes | Epsilon matches by file name only |
| Q42 | `content:"epsilon notes"` | (none) | content excludes the file name |
| Q43 | `first` | Alpha | frontmatter text is searched |
| Q44 | `[priority:2]` | Alpha | number property by string form |
(Paths in the table omit `.md`.)

**Tests**
- `sql_compiler_test.dart`: `exact` flags for `meeting` (true), `ox` (false), `match-case:meeting` (false), `-meeting` (true), `line:(-a)` (false), `tag:x` (true),
  `/x/` (false); the generated SQL for `a -b` contains `EXCEPT`; `ftsPhrase('say "hi" AND x')` == `'"say ""hi"" AND x"'`; a 60-deep nested group compiles to ALL.
- `search_matcher_test.dart`: one test per semantic bullet in sub-step 2 using in-memory `NoteDoc`s (e.g. `line:(a b)` true for `'a b'`, false for `'a\nb'`;
  `section:` boundaries with `#`/`##` mixes; `[p:]` with `p: []`; regex with `m` flag; match-case vs ignore-case nesting `match-case:(A ignore-case:b)`).
  Matches: `meeting` in `'The meeting. Meeting!'` → 2 matches on line 0 with correct `snippetStart/End`.
- `search_engine_test.dart`: results stream in sort order for all 6 sorts (fixture with controlled mtimes); a `CancelToken` cancelled after the first result ends the
  stream with no more results; 250 matching notes arrive as batches (20 then 100 then 100 then 30).
- `search_parity_test.dart`: Q1–Q44 above.

**Verify:** `cd packages/tephra_search; dart test` — all pass. Commit `phase 02.16: add search engine with fts candidates and verification`.

**Pitfalls**
- Never put user text into SQL by string concatenation; always `?` arguments.
- SQLite `substr`/`length` count characters (code points), Dart `.length` counts UTF-16 units — use `.runes.length` when passing lengths to SQL.
- `INTERSECT`/`UNION`/`EXCEPT` operands must be plain `SELECT`s; wrap every child as `SELECT id FROM (<child>)`.

---

### 02.17 Search UI, search history, copy results, in-note highlights, ` ```query ` blocks

**Purpose:** the search panel (desktop sidebar, phone full screen), embedded query blocks and opening results with highlights.

**Files**
- `app/lib/search/search_pane.dart`, `search_screen.dart`, `search_controller.dart`, `search_history_store.dart`, `copy_results.dart`, `search_highlights.dart`,
  `providers.dart`, `query_block_view.dart` (new)
- Reading view renderer (Phase 1): code block with language `query` → `QueryBlockView`; apply search highlights
- Command registrations
- tests: `app/test/search/search_controller_test.dart`, `copy_results_test.dart`, `search_history_store_test.dart`, `search_pane_test.dart`, `query_block_view_test.dart`

**Implementation**
1. `SearchController` (`NotifierProvider<SearchController, SearchState>`): `SearchState { String query; bool matchCase; SearchSort sort; bool collapseAll;
   List<SearchResult> results; bool running; String? error; int? elapsedMs; }`. `setQuery(q)` debounces **250 ms**, cancels the previous `CancelToken`, parses
   (`SearchSyntaxException` → `error` = `searchSyntaxError` with the offset; results cleared), then listens to `SearchEngine.run` and appends results as they arrive
   (`running` until done). Re-runs (debounced 500 ms) when `indexChangesProvider` emits while a query is shown. Sort/matchCase changes re-run immediately.
2. Search pane UI (desktop: a tab "Search" in the left sidebar next to the explorer; phone: `SearchScreen` pushed as a full-screen route):
   - Query `TextField` (autofocus when opened by the command), clear button, toggle button "Match case" (`Aa`), sort menu with the 6 options
     (labels: "File name (A to Z)", "File name (Z to A)", "Modified time (new to old)", "Modified time (old to new)", "Created time (new to old)",
     "Created time (old to new)"), "Collapse results" toggle, overflow menu: "Copy search results", "Bookmark this search" (enabled from step 02.18).
   - Result header: `searchResultCount` ("{count, plural, =1{1 result} other{{count} results}}"), plus a small progress indicator while `running`.
   - Results: `ListView.builder` (virtualised). One group per note: title row (note stem, folder in secondary text, match count badge, chevron) and up to all
     matches as rows showing the snippet with the match range highlighted (`TextSpan` with background). File-name matches show the label `searchMatchedFileName`.
     Collapsed groups show only the title row.
   - Tap a match → open the note (current tab; Ctrl+click → new tab) and highlight (sub-step 4). Tap a title → open the note with all of its matches highlighted.
   - History: when the field is focused and empty, show the last 20 queries; tapping one runs it. A query is added when the user presses Enter or opens a result.
3. `SearchHistoryStore`: `.tephra/cache/search-history.json` = `{ "queries": ["newest", ...] }`, max 20, de-duplicated (moving a repeat to the front), written
   atomically via the vault fs; missing/corrupt file → empty history (log warning). (`.tephra/cache/` = rebuildable, never synced — §6.6.)
4. In-note highlights (`search_highlights.dart`): `searchHighlightsProvider.family<List<(int, int)>, VaultPath>` set when a result is opened. Editor modes:
   `select(first.start, first.end)` + `revealOffset`. Reading view: paint each range with the highlight colour (wrap overlapping text spans) and scroll to the first;
   the highlights clear on the first edit of that note or when another search result is opened.
5. "Copy search results" (`copy_results.dart`): `String formatResultsAsMarkdown(List<SearchResult> results, LinkFormatter fmt, VaultPath from)` →
   ```
   - [[Alpha]]
   	- The meeting is on Monday.
   - [[Folder/Note]]
   	- line text
   ```
   One `- ` line per note with a link built by `fmt.buildLink(path, from: from)` (`from` = the active note, or a fictional `VaultPath('_.md')` when none is open);
   under it up to 10 matches as tab-indented `- ` lines with the full line text (trimmed) of each match (file-name matches are skipped). Lines end with `\n`.
   Copied with `Clipboard.setData`; snackbar `searchResultsCopied`.
6. ` ```query ` blocks (`QueryBlockView`): the block's code is the query. Parse it; syntax error → a red-bordered box with the message. Otherwise run
   `SearchEngine.run(expr)` (default sort, no match-case) and render: a header row (`queryBlockHeader` "{count} results" + an "open in search" icon that opens the
   search pane with the query), then up to **50** notes, each with its title (tap → open) and up to 3 match snippets; if more → "Show all {count} results" button
   (opens the search pane). Re-run on `indexChangesProvider` (debounced 500 ms). In Live Preview the same widget is used (step 02.23).
7. Commands: `search.open` "Search in all files" (Ctrl+Shift+F) — focuses the pane on desktop / pushes the screen on phone, and pre-fills the editor selection
   if any; `search.copy-results` (palette, available when results exist).

**Tests**
- `search_controller_test.dart` (fake engine): typing 3 characters within 250 ms triggers one run; a new query cancels the previous token; syntax error sets `error`
  and clears results.
- `copy_results_test.dart`: two results (one with 12 matches, one file-name match only) → exact expected string (10 sub-lines for the first, none for the second).
- `search_history_store_test.dart`: add 25 → 20 kept newest first; re-adding an old one moves it to the front; corrupt JSON → empty.
- `search_pane_test.dart`: results grouped with counts; "Collapse results" hides match rows; history list shown for an empty focused field; at 400 dp the command
  pushes `SearchScreen`.
- `query_block_view_test.dart`: valid query renders the count and titles; `(a` renders the error box; 60 results → 50 rows + "Show all 60 results".

**Verify:** app tests; manual: Ctrl+Shift+F on Windows, search `tag:#project task-todo:report` in a real vault, open a result → note opens with the match selected;
a ` ```query ` block in reading view lists results. Commit `phase 02.17: add search panel, history, query blocks and highlights`.

**Pitfalls:** never keep more than one engine run alive; always cancel the previous token before starting a new run.

---

### 02.18 Tags pane and bookmarks

**Purpose:** nested tag tree with counts; Obsidian-compatible bookmarks.

**Files**
- `app/lib/tags/tags_pane.dart`, `tag_tree.dart`, `providers.dart` (new)
- `app/lib/bookmarks/bookmark.dart`, `bookmarks_store.dart`, `bookmarks_pane.dart`, `bookmark_commands.dart`, `providers.dart` (new)
- `app/lib/links/link_rename_service.dart` (bookmark path updates), outline pane and search pane menus (bookmark actions)
- tests: `app/test/tags/tag_tree_test.dart`, `tags_pane_test.dart`, `app/test/bookmarks/bookmark_json_test.dart`, `bookmarks_store_test.dart`, `bookmarks_pane_test.dart`

**Implementation**
1. Tags: `tagTreeProvider` = `index.tags()` (refresh on `indexChangesProvider`, debounced 500 ms) → `TagNode { String segment; String fullTag; int count; List<TagNode> children; }`
   built by splitting `tagLower` on `/` (display segments from `TagCount.tag`). Pane: tree rows `#segment` + count on the right; chevrons for nodes with children;
   toolbar: sort "Name (A to Z)" / "Frequency (high to low)" (ties → name), toggle "Show nested tags" (off → flat list of all tags with their `count`). Tap a tag → open
   the search pane with query `tag:#<fullTag>`. Desktop: right-sidebar tab "Tags"; phone: left-drawer tab "Tags".
2. Bookmark model (`bookmark.dart`), sealed, mirroring Obsidian's `bookmarks.json`:
   ```dart
   sealed class Bookmark { int get ctime; String? get title; Map<String, Object?> get extra; }   // extra = unknown keys, written back unchanged
   final class FileBookmark extends Bookmark { VaultPath path; String? subpath; }   // subpath '#Heading' → heading bookmark, '#^id' → block bookmark
   final class FolderBookmark extends Bookmark { VaultPath path; }
   final class SearchBookmark extends Bookmark { String query; }
   final class GroupBookmark extends Bookmark { List<Bookmark> items; }
   final class UnknownBookmark extends Bookmark { Map<String, Object?> raw; }       // e.g. 'graph', 'url' types — kept and shown as read-only rows
   ```
   JSON: `{"items": [...]}`; each item has `type` (`file|folder|search|group|…`), `ctime` (ms), optional `title`, and per type `path`, `subpath`, `query`, `items`.
   Unknown top-level keys of the file are preserved. Parsing never throws for unknown types; malformed entries become `UnknownBookmark`.
3. `BookmarksStore`: loads `.tephra/bookmarks.json` on vault open (missing → empty), saves atomically through the same `.tephra` JSON mechanism Phase 1 uses for
   settings, after every change. Operations: `add(Bookmark, {GroupBookmark? into})`, `remove`, `rename(title)`, `move(bookmark, newParent, index)`, `isBookmarked(path, subpath)`.
4. Pane: tree; rows show an icon per kind (file, heading, block, folder, search, group, unknown) and `title ?? derived label` (file stem, `Stem > Heading`, `Stem > ^id`,
   folder name, query). Missing targets (file/folder not in the index) shown at 60 % opacity. Tap: file → open (with heading/block via `LinkNavigator`-style reveal);
   folder → reveal in explorer; search → open the search pane with the query; group → expand/collapse. Desktop: drag-and-drop reorder within and across groups
   (dropping on a group row inserts at its end). Phone: long-press menu "Move up", "Move down", "Move to group…", "Rename", "Remove". Desktop: same menu on right-click.
   Desktop left-sidebar tab "Bookmarks"; phone left-drawer tab "Bookmarks".
5. Commands: `bookmarks.toggle-current-file` ("Bookmark current file" / "Remove bookmark"), `bookmarks.add-heading` (from the outline row menu),
   `bookmarks.add-search` (from the search pane menu), `bookmarks.new-group`. No default shortcuts.
6. Rename hook: after `LinkRenameService` moves files, call `bookmarksStore.retarget(moves, folderMove: (from, to)?)`: file bookmarks whose path is in `moves` get the
   new path; folder bookmarks equal to or within a moved folder get the new prefix. Include these changes in the `VaultOperation` undo (store the old bookmarks JSON
   text and restore it on undo).

**Tests**
- `tag_tree_test.dart`: tags `a`(2), `a/b`(1), `A/c`(1) → root `a` count from `TagCount`, children `b`, `c`; flat mode lists 3 tags.
- `tags_pane_test.dart`: tapping `#a/b` sets the search query to `tag:#a/b`.
- `bookmark_json_test.dart`: this Obsidian sample round-trips to identical JSON (compare decoded maps):
  `{"items":[{"type":"file","ctime":1,"path":"A.md"},{"type":"file","ctime":2,"path":"A.md","subpath":"#Intro","title":"Intro"},{"type":"group","ctime":3,"title":"G","items":[{"type":"search","ctime":4,"query":"tag:#x"},{"type":"folder","ctime":5,"path":"F"}]},{"type":"graph","ctime":6,"options":{"a":1}}],"custom":true}`.
- `bookmarks_store_test.dart`: add/remove/move/rename persist; retarget on file and folder moves; undo restores the old JSON.
- `bookmarks_pane_test.dart`: icons per kind; missing file greyed; desktop drag reorder changes order.

**Verify:** app tests; manual on both platforms: bookmark a file, a heading (outline menu) and a search; restart the app → bookmarks persist; open the same vault's
`.tephra/bookmarks.json` and check it is valid Obsidian structure. Commit `phase 02.18: add tags pane and bookmarks`.

**Pitfalls:** never write `.obsidian/bookmarks.json` (§6.1).

---

### 02.19 Fuzzy scorer and index-backed quick switcher

**Purpose:** one shared ranking function, and the quick switcher upgraded to names + aliases + headings from the index with create-on-enter.

**Files**
- `packages/tephra_search/lib/src/fuzzy/fuzzy_scorer.dart` (new)
- Phase 1 quick switcher files (inventory item 10) — upgrade in place
- tests: `packages/tephra_search/test/fuzzy/fuzzy_scorer_test.dart`, `app/test/commands/quick_switcher_test.dart` (or the Phase 1 test file)

**Implementation**
1. `FuzzyScorer` (pure):
   ```dart
   abstract final class FuzzyScorer {
     /// Score of [candidate] for [query]; null = no match. Higher is better. Case-insensitive.
     static int? score(String query, String candidate);
     /// Character ranges of [candidate] matched by [query] (for bold rendering).
     static List<(int, int)> matchRanges(String query, String candidate);
   }
   ```
   Algorithm (`q` = query lower-cased and trimmed, `c` = candidate lower-cased; separators = space, `-`, `_`, `/`, `.`, `(`, `[`):
   1. `q` empty → 0.
   2. `c == q` → 1000.
   3. `c.startsWith(q)` → `900 - min(100, c.length - q.length)`.
   4. `q` occurs in `c` at index `i` where `c[i-1]` is a separator (word start) → `700 - min(100, i)`.
   5. `q` occurs anywhere at index `i` → `500 - min(100, i)`.
   6. Subsequence: match each character of `q` greedily in order in `c`; if any is missing → null. Score = `300 - 2 × (number of gaps between consecutive matched
      positions) - min(50, first matched index) + 10 × (matched characters at word starts)`, clamped to `[1, 399]`.
   This gives the required order: exact > prefix > word-start > substring > subsequence.
2. Switcher items (cached in `switcherItemsProvider`, rebuilt from the index on `indexChangesProvider`): one item per note (`primary` = stem, `secondary` = folder),
   one per alias (`primary` = alias, `secondary` = `→ stem`), and attachments when the app setting `switcherShowAttachments` (default `false`) is on
   (`primary` = file name). Lower-cased strings are precomputed once.
3. Ranking per keystroke: `score = max(score(q, primary), score(q, path) - 100 when q contains '/')`; add the recent boost `max(0, 50 - 5 × recentRank)` for
   notes in the recent-files list (Phase 1's recent list; rank 0 = most recent; only the first 10 count). Keep the top 50 by score (ties → shorter path, then
   alphabetical). Empty query → the recent files list (max 50).
4. Headings mode: query starting with `#` → items from `index.allHeadings()` (cached), `primary` = heading text, `secondary` = `stem`, scored on the heading text with
   the rest of the query. Query `name#head` → take the best-scoring note for `name`, then list its headings scored by `head`. Selecting a heading opens the note at it.
5. Keys: Up/Down move, Enter opens the selection; **Enter with no results** creates a note named after the query in the new-note location (same rules as
   `LinkNavigator` creation) and opens it; **Shift+Enter** always creates (even when results exist); Ctrl+Enter opens in a new tab; Esc closes. Phone: tapping a row
   opens it; a "Create “{query}”" row is always last when the query is non-empty and no item matches exactly.
6. Timing: wrap the ranking in a `Stopwatch` and log `perf switcher <ms>` at `fine` level (used by step 02.28).

**Tests**
- `fuzzy_scorer_test.dart` (a "word start" is index 0 or an index whose previous character is a separator; "gaps" = number of consecutive matched-position pairs
  that are not adjacent): `score('note','note')` = 1000; `score('no','notes')` = 897; `score('pl','project plan')` = 692 (word start at 8);
  `score('ject','project')` = 497 (substring at 3); `score('mtg','meeting')` = 306 (positions 0, 3, 6 → 2 gaps → 300 − 4 − 0 + 10);
  `score('xyz','meeting')` = null; for query `al`: `Alpha` 897, `Gallery` 499, `Total` 497, `A l` 318 (positions 0 and 2, 1 gap, both word starts).
  `matchRanges('mtg','meeting')` = `[(0,1),(3,4),(6,7)]`; `matchRanges('no','notes')` = `[(0,2)]` (adjacent ranges merged).
- `quick_switcher_test.dart` (fake index): alias row selects its note; `#Set` lists headings; Enter with no results creates `Query.md`; Shift+Enter with results creates;
  recent note ranks above an equally scored non-recent one; 10,000 items rank in < 50 ms in a test (`Stopwatch`; record the number).

**Verify:** tests; manual: Ctrl+O, type part of an alias → note found; `#` mode works. Commit `phase 02.19: add fuzzy scorer and index-backed quick switcher`.

**Pitfalls:** the exact score numbers in the tests follow from the algorithm; if a test number disagrees, re-check the implementation against sub-step 1 before
changing the test.

---

### 02.20 Editor autocomplete core: popup, `[[` and `![[` links, headings, blocks, aliases

**Purpose:** typing `[[` shows a ranked note list; `#` continues into that note's headings; `#^` or `^` into its blocks (creating a block ID when
needed); `|` into its aliases. `![[` is the same list plus attachments. One reusable popup and controller that steps 02.21 and 02.22 also use.

**Files** (all new unless stated; `app/lib/editor/autocomplete/`)
- `autocomplete_context.dart` (sealed context types + `detectAutocompleteContext`), `lexical_guard.dart`
- `autocomplete_item.dart` (`AcItem`, `AcKind`), `autocomplete_ranker.dart`
- `block_candidates.dart` (`BlockCandidate`, `listBlockCandidates`, `generateBlockId`, `blockIdEdit`)
- `autocomplete_insertion.dart` (`Insertion`, `Snippet`, builders), `autocomplete_controller.dart`, `autocomplete_popup.dart`, `autocomplete_overlay.dart`
- `app/lib/editor/providers.dart` (add `autocompleteControllerProvider`), `app/lib/editor/editor_controller.dart` (additions in sub-step 1)
- `app/lib/l10n/app_en.arb` (`autocompleteNoResults`, `autocompleteContinue`, `autocompleteBlockCreated`, `commandTriggerAutocomplete`)
- tests: `app/test/editor/autocomplete/context_test.dart`, `ranker_test.dart`, `block_candidates_test.dart`, `insertion_test.dart`, `autocomplete_controller_test.dart`, `autocomplete_popup_test.dart`

**Implementation**
1. `EditorController` additions (additive; skip any member Phase 1 already has under the same name; implement for the engine named in `docs/decisions/0001-editor-engine.md`; unit-test each in
   `app/test/editor/editor_controller_test.dart`):
   | Member | Behaviour |
   |---|---|
   | `FocusNode get focusNode` | the node of the editing widget (engine A and B both accept a `focusNode`; if the engine does not, use its shortcut-override hook from the ADR "API notes") |
   | `void setKeyInterceptor(KeyEventResult Function(KeyEvent event)? fn)` | installs `fn` as `focusNode.onKeyEvent` (the focused node is asked first, so Up/Down/Enter/Tab reach `fn` before the engine moves the caret). `null` removes it. At most one interceptor; the autocomplete controller owns it |
   | `TextRange composing` | current IME composing range (`TextRange.empty` when none) |
   | `Stream<void> get selectionChanges` | fires on every caret/selection change (needed because arrows change the caret without changing text) |
   `caretRectGlobal()`, `edits`, `applyEdits`, `select`, `revealOffset`, `text`, `selection`, `path` come from step 02.10.
2. `lexical_guard.dart` — `LexicalState lexicalStateAt(String text, int offset)` returns `{ bool inFrontmatter, bool inFence, bool inMathBlock, bool inInlineCode, bool inComment }`
   computed **without the parser** (the parse can be 300 ms stale while typing): scan lines from 0 to the caret line once —
   frontmatter = line 0 is exactly `---` (trailing spaces allowed) and no later line before the caret is `---` or `...`; fence = toggled by a line whose trimmed start is
   `` ``` `` or `~~~` (a closing fence needs the same character and at least the same length); math block = toggled by a line whose trimmed text is exactly `$$`; inline code = the count
   of `` ` `` characters before the caret on the caret line is odd; comment = count of `%%` before the caret in the text since the last blank line is odd. The scan is O(lines);
   a test proves it takes < 2 ms for a 5,000-line text.
3. `autocomplete_context.dart`:
   ```dart
   sealed class AutocompleteContext {
     const AutocompleteContext({required this.replaceStart, required this.replaceEnd, required this.query});
     final int replaceStart;   // first offset replaced when a candidate is accepted
     final int replaceEnd;     // == caret
     final String query;       // text between replaceStart and caret
   }
   final class NoteLinkContext extends AutocompleteContext { final bool embed; final bool closerPresent; final int openStart; }   // openStart = offset of '!' (embed) or first '['
   final class HeadingLinkContext extends AutocompleteContext { final String noteText; final bool embed; final bool closerPresent; final int openStart; }
   final class BlockLinkContext extends AutocompleteContext { final String noteText; final bool embed; final bool closerPresent; final int openStart; }
   final class AliasLinkContext extends AutocompleteContext { final String noteText; final String? heading; final bool embed; final bool closerPresent; final int openStart; }
   // TagContext, PropertyKeyContext, PropertyValueContext, SlashContext are added by steps 02.21 and 02.22 in the same file.
   AutocompleteContext? detectAutocompleteContext(String text, int caret, {bool force = false});
   ```
   Algorithm for the link family (applies only when the selection is collapsed, the lexical state has no `inFence`, `inMathBlock`, `inInlineCode`, `inComment`, and not `inFrontmatter`):
   1. `lineStart` = offset after the previous `\n`; `before = text.substring(lineStart, caret)`; `after = text.substring(caret, lineEnd)`.
   2. `open = before.lastIndexOf('[[')`; if `-1` → not a link context. `inner = before.substring(open + 2)`. If `inner` contains `]` → the link is already closed → not a context.
   3. `embed = open > 0 && before[open - 1] == '!'`; `openStart = embed ? lineStart + open - 1 : lineStart + open`; `closerPresent = after.startsWith(']]')`.
   4. Classify `inner`:
      - contains `|` → `AliasLinkContext`; the pipe used is the **last** `|` (if it is preceded by `\` it is an escaped pipe inside a table cell — treat it as the pipe and the backslash stays as typed, see sub-step 11); `query = after the last pipe`; `noteText` = part before the first `#`/`|`; `heading` = text between the first `#` and the first `|` (null if none).
      - else contains `#` → let `h = inner.substring(firstHash + 1)`; if `h` starts with `^` → `BlockLinkContext(query: h.substring(1))`, else `HeadingLinkContext(query: text after the LAST '#')`
        (a chain `[[A#B#C` offers headings of `A` filtered by `C`); `noteText = inner.substring(0, firstHash)`.
      - else contains `^` → `BlockLinkContext(noteText: before the first '^', query: after it)`; this also covers `[[^q` (empty `noteText` = the current note). Accepting rewrites the `^` to `#^`.
      - else → `NoteLinkContext(query: inner)`.
   5. `replaceStart` = offset right after the character that introduced the part (`[[`, last `#`, `^` or `#^`, last `|`); `replaceEnd = caret`.
   Contexts that need no popup (not returned): `inner` longer than 200 characters; `inner` containing `[` ; `force == false` and the line is a table delimiter row.
4. `autocomplete_item.dart`: `enum AcKind { note, alias, attachment, heading, block, tag, propertyKey, propertyValue, slash, template }`;
   `AcItem { AcKind kind; String primary; String? secondary; int score; List<(int, int)> matchRanges; Object? payload; }` (`payload` = `VaultPath`, `HeadingRecord`, `BlockCandidate`, … per kind).
5. `autocomplete_ranker.dart` (pure; uses `FuzzyScorer` from step 02.19 — its tiers are exact 1000 > prefix 900 > word-start 700 > substring 500 > subsequence ≤ 399):
   - `List<AcItem> rankNotes(String query, List<SwitcherItem> items, List<VaultPath> recent, {bool includeAttachments, List<FileRecord> attachments = const [], int max = 50})`:
     score exactly as in 02.19 sub-step 3 (`max(score(q, primary), score(q, path) - 100 when q contains '/')`, recent boost `max(0, 50 - 5 × recentRank)` for the first 10 recent paths,
     ties → shorter path, then alphabetical). Empty query → the recent list (max 50) then, if fewer than 50, the most recently modified notes. Alias items carry `secondary = '→ <stem>'`.
     **Narrowing:** the controller passes the previous candidate subset when the new query extends the old query (`newQuery.startsWith(oldQuery)`); the ranker then scores only that subset.
     Attachments (only for `![[`) are added as `AcKind.attachment` with `primary = file name` (extension included) and are scored the same way.
   - `List<AcItem> rankHeadings(String query, List<HeadingRecord> headings, {int max = 50})`: empty query → document order; else `FuzzyScorer.score(query, headingText)`, descending, ties by document order. `secondary = 'H<level>'`.
   - `List<AcItem> rankBlocks(String query, List<BlockCandidate> blocks, {int max = 50})`: scored on `preview` (and on the existing id when `query` has no space); empty query → document order. `secondary = existingId == null ? null : '^id'`.
   - `List<AcItem> rankAliases(String query, List<String> aliases)`: scored with `FuzzyScorer`; empty query → list order.
   Log `perf autocomplete <ms>` at `fine` level around each rank call (used by step 02.28). Budget: ranking 10,000 note items ≤ 16 ms on the UI isolate; the test in 02.20 asserts the first-keystroke (full set) case in < 16 ms
   on the development machine and records the number; if it fails, run the first full ranking in `Isolate.run` and keep narrowing on the UI isolate.
6. `block_candidates.dart`:
   ```dart
   final class BlockCandidate { final int start; final int end; final int line; final BlockKind kind; final String? existingId; final String preview; }
   enum BlockKind { paragraph, listItem, quote, callout, table, code, math }
   List<BlockCandidate> listBlockCandidates(String text, ParsedNote parsed);
   String generateBlockId(Random rng, Set<String> takenLowercase);   // 6 chars from 'abcdefghijklmnopqrstuvwxyz0123456789'; regenerate while taken (after 20 clashes use 7 chars)
   TextEdit blockIdEdit(String text, BlockCandidate c, String id);
   ```
   `listBlockCandidates`: walk `parsed.root` in document order; candidates are top-level and nested `MdParagraph` (not inside a list item, quote or callout), each `MdListItem` at any depth (range = the item's own first paragraph only: `start` = item start, `end` = end of its first paragraph),
   `MdBlockQuote` (not callout), `MdCallout`, `MdTable`, `MdCodeBlock`, `MdMathBlock`. Headings are **not** candidates (use `[[Note#Heading]]`). Empty paragraphs are skipped.
   `existingId` = the `BlockRef.id` whose owner start equals the candidate start. `preview` = candidate text with newlines → spaces, `^id` removed, trimmed, cut to 120 characters (same as step 02.4).
   `blockIdEdit` (the position is the end of the block's content, never after trailing newlines/spaces): `e = c.end`; while `e > c.start` and `text[e-1]` is `\n`, space or tab → `e--`.
   - `paragraph`, `listItem`, `quote`, `callout` → `TextEdit(e, e, ' ^$id')`.
   - `table`, `code`, `math` → `TextEdit(e, e, '\n^$id')` (the ID goes on its own line **directly** after the block, no blank line — the rule step 02.4 uses to find the owner).
7. `autocomplete_insertion.dart`:
   ```dart
   final class Snippet { const Snippet(this.text, {int? caret}); final String text; final int caret; }   // caret defaults to text.length (offset inside [text])
   final class Insertion { const Insertion(this.edits, this.caretAfter, {this.continueCompletion = false, this.sideEffects = const []}); final List<TextEdit> edits; final int caretAfter; final bool continueCompletion; final List<Future<void> Function()> sideEffects; }
   ```
   `caretAfter` is an offset in the **new** text (the builder computes it; all edits of one insertion are non-overlapping, listed in ascending order).
   `Insertion buildLinkInsertion(String text, NoteLinkContext/Heading/Block/Alias ctx, AcItem item, {required LinkFormatter formatter, required VaultPath from, required bool continueIntoSubpath})`:
   - Settings `useMarkdownLinks == false` (wiki):
     - **note / attachment** item (`path = payload`): `p = formatter.linkPath(path, from: from, syntax: wiki)`. Enter (`continueIntoSubpath == false`): replace `[replaceStart, caret)` with `p`; if `closerPresent` the closing `]]` already exists → `caretAfter = replaceStart + p.length + 2`
       (jump over it); else insert `p + ']]'` and `caretAfter = replaceStart + p.length + 2`. If the text after the caret up to the next `]]` is not empty (the user edits in the middle of a link) → insert only `p` and `caretAfter = replaceStart + p.length`.
       Tab (`continueIntoSubpath == true`, notes only): insert `p + '#'` (+ `']]'` when no closer exists) and `caretAfter = replaceStart + p.length + 1`; `continueCompletion = true` (the controller re-detects immediately and shows headings).
     - **alias** item (alias row in `NoteLinkContext`, payload `(VaultPath, String alias)`): insert `p + '|' + alias` + closer handling as above.
     - **heading** item: insert `headingText` sanitized with `LinkFormatter.sanitizeHeadingForLink` + closer handling. **block** item: described in sub-step 8. **alias** (in `AliasLinkContext`): insert the alias text + closer handling; if the context used an escaped pipe (`\|`), the inserted text is unchanged (the backslash before the pipe is already in the text).
   - `useMarkdownLinks == true`: for note/attachment items replace `[openStart, caret + (closerPresent ? 2 : 0))` with `formatter.buildLink(path, from: from, embed: ctx.embed, alias: aliasOrNull)` and put the caret after it (Tab behaves as Enter). Heading/block/alias rows are only offered in wiki mode (typed `#` in markdown mode produces no popup because `[[` would not be completed that way; they still work when the user types wikilinks manually).
   - `ctx.embed` with `NoteLinkContext` and an image attachment: no size is added (the user adds `|300` by typing).
8. Block pick (`BlockLinkContext`, item payload `BlockCandidate c`; `targetPath` = resolved path or current note):
   1. `id = c.existingId ?? generateBlockId(Random(), taken)` where `taken` = lower-cased ids of all candidates of the target.
   2. Link insertion text = `^$id` (+ closer handling); if the user typed `[[Note^q` the `^` is rewritten: `replaceStart` is moved back by one so the result reads `#^id`.
   3. If `c.existingId == null`, add a **side effect** that writes the ID into the target note, run **after** the link edit succeeded:
      - target is the current note → add `blockIdEdit(text, c, id)` to the **same** `edits` list (one undo step); offsets of the link edit are computed on the new text order: both edits are in the same coordinate system of the old text, the ID edit lies
        before or after the link edit (never inside the replaced range because the link is on the caret line and the block is a different block — if the block is the caret's own line, apply the ID edit first and then shift the link edit; the test covers this).
      - target is another note: `controllerFor(targetPath)` open → `applyEdits([blockIdEdit])` on that buffer (autosave writes it); otherwise `doc = await fs.readText(targetPath)`; skip when `doc.malformed`; re-parse `doc.text`, re-locate the same block by `preview` + `kind`
        (not by offsets, they may be stale); if not found → snackbar `autocompleteBlockMissing`; else `writeText(targetPath, TextDocument(text: newText, hasBom: doc.hasBom, lineEnding: doc.lineEnding))`. Show snackbar `autocompleteBlockCreated` ("Added block ID ^{id}").
9. `AutocompleteController` (`NotifierProvider.family<AutocompleteController, AutocompleteState, String /*tabId*/>`):
   ```dart
   final class AutocompleteState { final AutocompleteContext? context; final List<AcItem> items; final int selected; final bool visible; final bool loading; }
   ```
   - Subscribes to `controller.edits` and `controller.selectionChanges`; on each event (ignored while `controller.composing` is non-empty — IME text is not completed until committed; when composing ends re-detect):
     `ctx = detectAutocompleteContext(text, caret)`; null → hide. If `dismissedAt == ctx.replaceStart` (set by Esc) and the context kind is unchanged → stay hidden; `dismissedAt` resets when the context is null or its `replaceStart` changes.
   - Items: `NoteLinkContext` → `rankNotes` over `switcherItemsProvider` (02.19) + recent files; `HeadingLinkContext` → `noteText.isEmpty ? headings of the live parse (activeParsedNoteProvider) : index.headings(index.resolveLink(noteText, from))`;
     `BlockLinkContext` → `listBlockCandidates` of the live parse (current note) or of the target text (open buffer, else `fs.readText`; parse with `Isolate.run` when longer than 50,000 characters); `AliasLinkContext` → aliases of the resolved note
     from `index.allAliases()` (cached in a provider) plus its stem. Every async lookup carries a sequence number; a result older than the latest request is dropped.
   - `visible = items.isNotEmpty`. A `NoteLinkContext` with a non-empty query and no items hides the popup (no "create" row; the user can finish the link by typing).
   - Keyboard (installed with `setKeyInterceptor` only while `visible`; removed when hidden): `ArrowDown`/`ArrowUp` move the selection with wrap-around; `PageDown`/`PageUp` move by 8; `Enter` accepts (`continueIntoSubpath: false`); `Tab` accepts with
     `continueIntoSubpath: true` for note rows and behaves as Enter for every other row kind; `Escape` hides and sets `dismissedAt`; every other key is passed on (`KeyEventResult.ignored`). Keys are never intercepted while `controller.composing` is non-empty.
     Handled key-down events return `handled`; the matching key-up and repeat events are also swallowed (keep a `Set<LogicalKeyboardKey> swallowed`).
   - `accept(AcItem item, {bool continueIntoSubpath})`: build the `Insertion`, `controller.applyEdits(edits)` (one undo step), `controller.select(caretAfter)`, run side effects, then re-run detection if `continueCompletion`, else hide.
   - Command `editor.trigger-autocomplete` (label `commandTriggerAutocomplete`, default shortcut `Ctrl+Space`): `force = true` detection for the caret (also clears `dismissedAt`).
10. `AutocompletePopup` / overlay:
   - Row: `primary` with matched characters bold (`matchRanges`), `secondary` in 60 % opacity on the right/below, a leading icon per `AcKind` (note, alias arrow, attachment clip, heading `H<n>`, block pilcrow, …). The selected row has the selection background and is kept scrolled into view.
   - **Desktop layout** (width ≥ 840): a `Material` card, elevation 6, width `min(480, windowWidth − 16)`, rows 32 dp, at most 8 rows visible (then scrolls). Anchor: `caretRectGlobal()`; place the card **below** the caret line (top = caret bottom + 4) when `windowHeight − caret.bottom ≥ min(rowCount, 8) × 32 + 12`, otherwise **above** (bottom = caret top − 4); left edge = caret left, clamped to 8 dp inside the window. Mouse: hover selects, click accepts, mouse wheel scrolls; clicking in the editor elsewhere hides.
   - **Phone layout**: a full-width sheet docked directly **above the keyboard toolbar**: `bottom = MediaQuery.viewInsetsOf(context).bottom + keyboardToolbarHeight` (the Phase 1 toolbar height; 48 dp if there is no provider), rows 48 dp, at most 5 visible. After showing, call `controller.revealOffset(caret, center: false)` so the caret line is not hidden behind the sheet.
     Tap = accept. Note rows have a trailing 48×48 dp "continue" button (`autocompleteContinue` tooltip, `#` glyph) = Tab behaviour. Dragging inside the list scrolls it; touching outside hides it. The Android back button hides the popup first (`PopScope(canPop: !visible)` on the note screen).
   - Accessibility: `Semantics(liveRegion: true)` announces "{count} suggestions"; each row has a `Semantics(label: primary + secondary, selected: …)`.
11. Table cells: inside a table row (the line starts with `|`) an unescaped `|` would end the cell, so Obsidian users type `\|`. `detectAutocompleteContext` treats both a bare `|` and a `\|` pair as the alias pipe (the last one on the line before the caret wins); insertion never adds or removes backslashes — the text already typed stays as typed.

**Tests**
- `context_test.dart` (caret shown as `|`): `[[ab|` → `NoteLinkContext(query: 'ab', embed: false, replaceStart: 2)`; `![[ab|` → `embed: true`; `[[ab|]]` → `closerPresent: true`; `[[Note#He|` → `HeadingLinkContext(noteText: 'Note', query: 'He')`;
  `[[#He|` → `noteText: ''`; `[[A#B#C|` → `HeadingLinkContext(noteText: 'A', query: 'C')`; `[[Note#^ab|` → `BlockLinkContext(query: 'ab')`; `[[Note^ab|` → `BlockLinkContext(noteText: 'Note', query: 'ab')`;
  `[[^ab|` → `noteText: ''`; `[[Note|Al|` → `AliasLinkContext(noteText: 'Note', query: 'Al')`; `[[Note#Head|Al|` → `heading: 'Head'`; `[[a]] b|` → null; `[[a]]|` → null; `` `[[a| `` (inside inline code) → null;
  text with an open fence before the caret → null; caret in frontmatter → null; selection not collapsed → null (the function takes only a caret, the controller skips non-collapsed selections — test the controller).
- `ranker_test.dart`: items `Project Plan`, `Plan`, `Planet`, `Alpha Plan`, alias `Planner → Project Plan`; query `plan` → scores from the 02.19 formulas: `Plan` 1000 (exact), `Planet` 898 (`900 − (6 − 4)`), `Planner` 897 (`900 − (7 − 4)`), `Alpha Plan` 694 (word start at 6: `700 − 6`), `Project Plan` 692 (word start at 8: `700 − 8`) → order
  `Plan, Planet, Planner, Alpha Plan, Project Plan`; with recent list `[Project Plan]` (rank 0 → +50) `Project Plan` scores 742 and ranks above `Alpha Plan` but below `Planner`; 60 matching items → exactly 50 returned; empty query → recents first.
  `rankHeadings('', …)` keeps document order; `rankBlocks('milk', …)` finds the block whose preview contains `milk`. Narrowing: ranking `'pla'` then `'plan'` with the subset equals ranking `'plan'` over the full set. Timing test: 10,000 items, query `a` → < 16 ms (record).
- `block_candidates_test.dart`: text `'Para one\n\n- item a\n  - nested b ^keep\n\n> quote line\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```\ncode\n```\n'` → candidates in order: paragraph, listItem (a), listItem (nested b, `existingId: 'keep'`), quote, table, code (kinds exactly these). `blockIdEdit` results:
  paragraph → `'Para one ^x1y2z3'`; list item a → `'- item a ^x1y2z3'` (the nested item stays below); table → the line `^x1y2z3` is inserted directly after the last row `| 1 | 2 |` (result lines: `| 1 | 2 |`, `^x1y2z3`, blank, the opening fence); code → a new line `^x1y2z3` directly after the closing fence. `generateBlockId(Random(1), {})` has length 6 and only characters from `[a-z0-9]`; clash path: with a fake `Random` that returns the same sequence twice and `taken` containing the first id, the second id returned differs.
- `insertion_test.dart` (wiki settings, shortest format, vault `Folder/Other Note.md`, `Unique.md`): Enter on `Unique` in `[[Uni|` → text `[[Unique]]`, caret after `]]`; with an existing `]]` (`[[Uni|]]`) → still `[[Unique]]`, caret after `]]`; Tab → `[[Unique#|]]`, `continueCompletion: true`; markdown mode → `[Unique](Unique.md)`; heading row `Part Two` in `[[Unique#Pa|` → `[[Unique#Part Two]]`;
  alias row → `[[Unique|Short]]`; block with existing id → `[[Unique#^keep]]` and no side effect; block without id in the current note → one `edits` list of 2 edits that applied together give both the link and the ` ^id` suffix; typing `[[Note^ab|` then accepting → `[[Note#^id]]`; the middle-of-link case `[[Un|ique]]` inserts only the path.
- `autocomplete_controller_test.dart` (fake `EditorController`, in-process index): typing `[[` after `Hello ` shows the popup with items; Esc hides and typing another character in the same context keeps it hidden; moving the caret out hides; Down ×2 + Enter accepts the third item as ONE `applyEdits` call; composing non-empty → no popup and no key interception; `Ctrl+Space` forces the popup in an empty query; stale async result is dropped (resolve two heading lookups out of order).
- `autocomplete_popup_test.dart`: at 1200 dp the card is below the caret rect; with the caret 100 dp above the window bottom it flips above; at 400 dp the sheet sits above the keyboard (set `MediaQuery` `viewInsets.bottom = 300` and keyboard toolbar 48) and rows are 48 dp; tapping the continue button calls accept with `continueIntoSubpath: true`; 20 items at desktop show 8 rows.

**Verify:** `flutter test` in `app/` (these files). Manual (both platforms, a vault with ≥ 100 notes): type `[[` → list appears < 100 ms after the keystroke; type `proj` → ranking is exact/prefix first; Tab on a note → `#` and its headings appear; `[[Note#^` → blocks; picking a block without ID appends ` ^abc123` to that block in the target note and inserts the link; type `[[Note|` → aliases; `![[` also lists a PNG; Esc closes; Ctrl+Z after accepting removes the whole link in one step; on the phone the list sits above the keyboard and tapping a row works.
Commit `phase 02.20: add editor autocomplete core for links, headings, blocks and aliases`.

**Pitfalls**
- Never intercept keys when the popup is hidden — Enter and arrows must reach the editor untouched, or typing breaks.
- Do not insert a second `]]` when the editor auto-paired one (`editor.autoPairBrackets` on): always check `closerPresent`.
- A block ID is written to the target note only after the link edit was applied; if the second write fails, log at `severe` and show `autocompleteBlockMissing`, but keep the link (a link to a missing block still resolves to the note).
- Never compute `lexicalStateAt` on every key for notes > 5,000 lines more than once per event; cache by `(text.hashCode, caretLine)` only within one event.

---

### 02.21 Autocomplete for tags and frontmatter keys and values

**Purpose:** `#` in the body completes tags; inside the frontmatter, a new line completes property keys from the vault, and values complete from values already used in the vault.

**Files**
- `app/lib/editor/autocomplete/autocomplete_context.dart` (add contexts), `frontmatter_scanner.dart` (new), `yaml_scalar.dart` (new), `autocomplete_ranker.dart` (add `rankTags`, `rankPropertyKeys`, `rankPropertyValues`), `autocomplete_insertion.dart`, `autocomplete_controller.dart`
- `app/lib/editor/autocomplete/providers.dart` (new: `tagListProvider`, `propertyKeysProvider`, `propertyValuesProvider.family<String>`; each refreshes on `indexChangesProvider`, debounced 500 ms)
- tests: `app/test/editor/autocomplete/tag_context_test.dart`, `frontmatter_context_test.dart`, `yaml_scalar_test.dart`, `tag_property_insertion_test.dart`

**Implementation**
1. New contexts (same sealed base): `TagContext(inFrontmatter: bool)`, `PropertyKeyContext`, `PropertyValueContext(key: String, inInlineList: bool, forceEmpty: bool)`.
2. Tag detection (body only; same lexical guard; not in frontmatter): `before` must match `(?<![\p{L}\p{N}\p{M}_/&#\\])#([\p{L}\p{N}\p{M}_\-/]*)$` (Unicode flag). `query` = group 1, `replaceStart` = offset after the `#`.
   Suppressed when: `before` matches `^\s*#{1,6}$` (the user is typing a heading marker); the character after the caret is a letter/digit (editing in the middle of a word); `query` is non-empty and all digits (`#123` is not a tag); the `#` follows `](` or `[[` (link context wins, links are checked first).
3. Frontmatter scanner (`frontmatter_scanner.dart`, pure): `FrontmatterRange? frontmatterRange(String text)` → `(contentStart, contentEnd, closeLineStart)`. When the note has a closed block it is derived from Phase 1's `splitFrontmatter(text)` (`contentStart` = its `contentStart`, `contentEnd` = `contentStart + yaml.length`, `closeLineStart` = offset of the closing `---` line). When line 0 is `---` but there is **no** closing line (the user is still typing the block), the whole rest of the file counts as frontmatter, and only for lines ≥ 1 (so typing a new `---` block at the top completes before the close exists).
   `String? propertyKeyForLine(String text, FrontmatterRange fm, int line)`: returns the key that owns the line — for `key: value` lines the key itself; for a list item line (`^\s*-\s`) scan upward over lines that are list items, deeper-indented, or blank until a line matching `^([^\s#:][^:]*):\s*$` (a key with no inline value) → that key; otherwise null. Quoted keys (`"a b":`) are unquoted.
4. `PropertyKeyContext`: caret inside the frontmatter range, line is not the `---` delimiter, `before` matches `^[A-Za-z0-9_][A-Za-z0-9_ \-]*$` (the line has no `:` yet and starts in column 0), `replaceStart = lineStart`, `query = before`. With `force == true` (Ctrl+Space) an empty line at column 0 also qualifies.
   `PropertyValueContext`: caret inside the frontmatter and either
   - `before` matches `^([^\s#:][^:]*):[ \t]+(.*)$` → key = group 1, `rest` = group 2. If `rest` starts with `[` → inline list: `query` = text after the last `,` or `[` with leading spaces trimmed, `inInlineList = true`; else if `rest` starts with `"` or `'` or `|` or `>` → no context; else `query = rest`;
   - `before` matches `^\s+-\s+(.*)$` or `^-\s+(.*)$` and `propertyKeyForLine` gives a key → `query = group 1`, `inInlineList = false`;
   - or the controller was told `forceEmpty` (set after accepting a key): the line is `key: ` with the caret at its end → `query = ''`.
5. Candidates:
   - Tags: `tagListProvider` = `index.tags()` (every ancestor prefix is already a `TagCount`). `rankTags(query, tags)`: `FuzzyScorer.score(query, tagLower)`; ties → `count` descending, then alphabetical; max 50; empty query → top 50 by `count`. `primary = '#' + tag.tag` (display casing), `secondary = '<count>'`. In frontmatter lists (`TagContext(inFrontmatter: true)` is produced for items under `tags:`/`tag:` — i.e. `PropertyValueContext(key: 'tags')`) the `#` is not shown or inserted.
   - Keys: `propertyKeysProvider` = `index.propertyKeys()` plus the standard keys `tags`, `aliases`, `cssclasses` (count 0 when absent from the vault); drop keys already present in this note's frontmatter (case-insensitive). `rankPropertyKeys`: fuzzy on key; ties by `count` descending. `secondary = valueType`.
   - Values: key `tags`/`tag` → tag names without `#` (`tagListProvider`); key `aliases` → no candidates; otherwise `index.propertyValues(key)` (limit 50). If the index says the key's `valueType` is `checkbox` → candidates `true`, `false`; `date` → today formatted `YYYY-MM-DD` (`formatMoment`, step 02.22); `datetime` → now formatted `YYYY-MM-DDTHH:mm`. Values already present in the same list are dropped.
6. Insertion:
   - Tag (body): replace `[replaceStart, caret)` with the tag text (original casing as displayed, no `#`, no trailing space). Frontmatter tag: the tag text, quoted by `yamlScalarForInsert` only if needed.
   - Key: scalar-like keys insert `key: ` and set `controllerHint.forceValueAfterKey = true` (the next detection yields a `PropertyValueContext` with `forceEmpty`); keys whose index type is `multitext`, `tags` or `aliases` (and the standard `tags`, `aliases`, `cssclasses`) insert `key:\n  - ` with the caret at the end. The replaced range is the whole line before the caret.
   - Value: replace `[replaceStart, caret)` with `yamlScalarForInsert(value)`; in an inline list nothing else is added (the user types `,` or `]`).
   `String yamlScalarForInsert(String v)` (`yaml_scalar.dart`): plain when it is safe; otherwise a double-quoted string with `\` → `\\` and `"` → `\"`. Quote when: empty; leading or trailing space; starts with any of `- ? : , [ ] { } # & * ! | > ' " % @` `` ` ``; contains `: ` or ` #`; equals (case-insensitively) `true`, `false`, `yes`, `no`, `on`, `off`, `null`, `~`; parses as a number (`num.tryParse`) and the key's index type is not `number`; looks like a date (`^\d{4}-\d{2}-\d{2}`) and the key's type is `text`.
7. The popup, keyboard handling and touch behaviour are exactly those of step 02.20 (same controller).

**Tests**
- `tag_context_test.dart`: `Text #pro|` → `TagContext(query: 'pro')`; `# |` → null (space); `#|` at line start → null (heading marker); `a#b|` → null (preceded by a word character); `https://x.com/#frag|` → null (`/` before `#`); `#123|` → null; `#12a|` → context; `` `#a| `` → null; `[[a#b|` → `HeadingLinkContext` (not a tag); `#বাংলা|` → context; `#a/b|` → `query 'a/b'`.
- `frontmatter_context_test.dart` (text with caret `|`): `---\nsta|\n---\n` → `PropertyKeyContext(query: 'sta')`; `---\nstatus: dr|\n---\n` → `PropertyValueContext(key: 'status', query: 'dr')`; `---\ntags:\n  - pro|\n---\n` → key `tags`; `---\naliases: [A, B|\n---\n` → `inInlineList`, query `B`; `---\ntitle: "x|\n---\n` → null; body line `sta|` after the closing `---` → null; frontmatter never closed: `---\nsta|` → key context.
- `yaml_scalar_test.dart`: `draft` → `draft`; `a: b` → `"a: b"`; `true` → `"true"`; `2026-10-11` for a text key → `"2026-10-11"`; `-x` → `"-x"`; `say "hi"` → `"say \"hi\""`; `বাংলা` → plain.
- `tag_property_insertion_test.dart`: accepting `project/alpha` for `#pro|` → `#project/alpha`; accepting key `tags` → `tags:\n  - ` with the caret at the end; accepting key `status` → `status: ` and the next detection is a forced value context listing the vault's values by count; accepting value `in progress` → `in progress` (plain: spaces inside are safe); a vault with `status` used 5× `done` and 2× `draft` lists `done` first; keys already in the note are not offered.

**Verify:** app tests. Manual: in a note's frontmatter type `sta` → `status` offered; Enter → `status: ` then values popup; in the body type `#pro` → tags with counts. Commit `phase 02.21: add tag and frontmatter autocomplete`.

**Pitfalls**
- Never offer completions inside a quoted YAML string or a block scalar; the guards above return null instead.
- Tag casing: insert the display casing from `TagCount.tag`, but searches and the index stay case-insensitive.

---

### 02.22 Date formatting, template engine, and the slash command menu

**Purpose:** the shared Moment-style formatter and template variables (also used by step 02.27 and Phase 4), then the `/` menu on top of the autocomplete popup.

**Files**
- `packages/tephra_core/lib/src/moment_format.dart`, `template_engine.dart`, `daily_note_path.dart` (new; exported from `tephra_core.dart`); `packages/tephra_core/pubspec.yaml` (`intl`)
- tests: `packages/tephra_core/test/moment_format_test.dart`, `template_engine_test.dart`, `daily_note_path_test.dart`
- `app/lib/editor/autocomplete/slash_commands.dart` (new), `autocomplete_context.dart` (add `SlashContext`), `autocomplete_controller.dart`, `app/lib/editor/autocomplete/snippet_placement.dart` (new)
- Vault settings model/store (add `templates` group and `corePlugins.slashCommands`), `app/lib/l10n/app_en.arb`
- tests: `app/test/editor/autocomplete/slash_context_test.dart`, `snippet_placement_test.dart`, `slash_menu_test.dart`

**Implementation**
1. In `packages/tephra_core`: `dart pub add intl` then `dart run tool/check_licenses.dart`. Add `import 'package:intl/intl.dart';` only inside `moment_format.dart`.
2. `moment_format.dart` — Moment.js-style tokens, as Obsidian uses them in daily notes and templates:
   ```dart
   /// Formats [t] with a Moment-style [format]. Unknown characters are copied as written. [locale] affects names (MMMM, ddd…) only; 'en' needs no initialisation.
   String formatMoment(DateTime t, String format, {String locale = 'en'});
   /// Parses [text] written with [format]; null when it does not match or the date is invalid. Needs year, month and day tokens; time tokens are optional.
   DateTime? parseMoment(String text, String format, {String locale = 'en'});
   /// Null when valid. [forFileName] also rejects characters that cannot appear in a file name; [requireDate] demands year, month and day tokens (daily notes).
   MomentFormatError? validateMomentFormat(String format, {bool forFileName = false, bool requireDate = false});
   enum MomentFormatError { empty, unbalancedBracket, forbiddenCharacter, parentSegment, noDateTokens }
   ```
   Tokenizer (longest match first, case-sensitive): regular expression `\[([^\]]*)\]|YYYY|YY|MMMM|MMM|MM|M|Do|DD|D|dddd|ddd|HH|H|hh|h|mm|m|ss|s|A|a`. A bracketed part is a **literal** (text without the brackets); every other character is a literal as written.
   Each token is formatted separately with `DateFormat(<intl pattern>, locale).format(t)` and the pieces are concatenated (never build one combined intl pattern: intl would treat unquoted letters as pattern characters).
   | Moment token | Meaning | intl pattern | Output for Sunday 2026-10-11 14:05:09 (`en`) |
   |---|---|---|---|
   | `YYYY` | 4-digit year | `yyyy` | `2026` |
   | `YY` | 2-digit year | `yy` | `26` |
   | `MMMM` | full month name | `MMMM` | `October` |
   | `MMM` | short month name | `MMM` | `Oct` |
   | `MM` | month, 2 digits | `MM` | `10` |
   | `M` | month, no padding | `M` | `10` (for March: `3`) |
   | `DD` | day of month, 2 digits | `dd` | `11` |
   | `D` | day of month | `d` | `11` (for the 1st: `1`) |
   | `Do` | day with ordinal | `d` + English suffix `st`/`nd`/`rd`/`th` (11, 12, 13 → `th`; ends in 1 → `st`, 2 → `nd`, 3 → `rd`, else `th`); for locales other than `en` the suffix is omitted | `11th` |
   | `dddd` | full weekday | `EEEE` | `Sunday` |
   | `ddd` | short weekday | `EEE` | `Sun` |
   | `HH` | 24-hour, 2 digits | `HH` | `14` |
   | `H` | 24-hour | `H` | `14` |
   | `hh` | 12-hour, 2 digits | `hh` | `02` |
   | `h` | 12-hour | `h` | `2` (midnight and noon give `12`) |
   | `mm` | minutes, 2 digits | `mm` | `05` |
   | `m` | minutes | `m` | `5` |
   | `ss` | seconds, 2 digits | `ss` | `09` |
   | `s` | seconds | `s` | `9` |
   | `A` | AM/PM upper case | `a` | `PM` |
   | `a` | am/pm lower case | `a`, then `toLowerCase()` | `pm` |
   | `[text]` | literal | — | `text` |
   (`m` and `s` are additions to the required list; every other Moment token, e.g. `Q`, `W`, `Z`, `SSS`, is **not** supported and is copied as written. `validateMomentFormat` does not reject them.)
   `parseMoment`: build one `RegExp` from the tokens — `YYYY` → `(\d{4})`, `YY` → `(\d{2})` (value > 68 → 19xx else 20xx), `MMMM`/`MMM`/`dddd`/`ddd` → an alternation of the locale's names (case-insensitive; `dddd`/`ddd` are matched and ignored),
   `MM`/`DD`/`HH`/`hh`/`mm`/`ss` → `(\d{2})`, `M`/`D`/`H`/`h`/`m`/`s` → `(\d{1,2})`, `Do` → `(\d{1,2})(?:st|nd|rd|th)`, `A`/`a` → `(AM|PM|am|pm)`, literals → `RegExp.escape`; anchor with `^…$`. Result must satisfy `DateTime(y, m, d)` round-trip (reject 2026-02-30); 12-hour `h` with `PM` adds 12 except 12 PM.
   `validateMomentFormat`: empty → `empty`; a `[` without `]` → `unbalancedBracket`; `forFileName` and an unbracketed or bracketed character from `\ : * ? " < > |` → `forbiddenCharacter` (`/` is allowed: it makes subfolders); a `..` segment → `parentSegment`; `requireDate` and not (a year token `YYYY`/`YY` and a month token `MMMM`/`MMM`/`MM`/`M` and a day token `DD`/`D`/`Do` outside brackets) → `noDateTokens`.
3. `template_engine.dart`:
   ```dart
   final class TemplateContext { const TemplateContext({required this.title, required this.date, required this.now, this.dateFormat = 'YYYY-MM-DD', this.timeFormat = 'HH:mm', this.locale = 'en'}); final String title; final DateTime date; final DateTime now; final String dateFormat; final String timeFormat; final String locale; }
   String applyTemplate(String template, TemplateContext ctx);
   ```
   Variables (regex `\{\{\s*(title|date|time)\s*(?::([^}]*))?\}\}`; whitespace around the name is ignored; unknown names such as `{{foo}}` are left exactly as written): `{{title}}` → `ctx.title`; `{{date}}` → `formatMoment(ctx.date, ctx.dateFormat)`; `{{time}}` → `formatMoment(ctx.now, ctx.timeFormat)`;
   `{{date:FORMAT}}` → `formatMoment(ctx.date, FORMAT)`; `{{time:FORMAT}}` → `formatMoment(ctx.now, FORMAT)`; an empty `FORMAT` (`{{date:}}`) falls back to the default format. For an ordinary template `date == now`; for a daily note `date` is the note's date and `now` is the current moment (like Obsidian's Daily notes).
   Text is processed in one pass (an inserted value is never re-scanned); a template without variables is returned unchanged.
4. `daily_note_path.dart`: `VaultPath dailyNotePath(DateTime date, {required String folder, required String format})`: `name = formatMoment(date, format)`; split on `/`, drop empty segments, append `.md` to the last segment unless it already ends with `.md` (case-insensitive); prefix with `folder` (vault-relative, may be empty); `VaultPath(raw)` (throws `InvalidPathException` for `..`).
5. Vault settings additions (Phase 1's `VaultSettings` model and `VaultSettingsStore`; JSON in `.tephra/settings.json`; nested objects, unknown keys preserved): `templates` = `{ "folder": "", "dateFormat": "YYYY-MM-DD", "timeFormat": "HH:mm" }`, `corePlugins` = `{ "slashCommands": true }`. Registry names for Phase 7: `templates.folder`, `templates.dateFormat`, `templates.timeFormat`, `corePlugins.slashCommands`. Add `fromJson`/`toJson` and defaults for missing keys; the `.obsidian` importer reads `.obsidian/templates.json` (`folder`, `dateFormat`, `timeFormat`) once, read-only, when the Tephra keys are absent.
6. `SlashContext(replaceStart, replaceEnd, query, slashStart)`: only when `corePlugins.slashCommands` is true, selection collapsed, lexical guard clean (no fence/math/inline code/comment/frontmatter), and `before` matches `(^|[ \t])/([^\s/]*)$` (the `/` is at the line start or after whitespace; `https://`, `and/or` and `a/b` never match). `replaceStart = slashStart` (the `/` itself is replaced), `query` = text after the `/`.
7. `slash_commands.dart`: `final class SlashCommand { String id; String Function(AppLocalizations) label; List<String> keywords; bool isBlock; Snippet Function(SlashInput) build; bool Function(WidgetRef)? isAvailable; }`. The list, in this order (labels are l10n keys `slash<Id>`):
   (In the "result" column `{caret}` marks where the caret ends up; it is not inserted. `\n` is a newline.)
   | id | label | keywords | result | block? |
   |---|---|---|---|---|
   | `heading1` … `heading6` | Heading 1 … Heading 6 | `h1 title` … `h6` | `# `, `## `, … `###### ` | no (line prefix, see sub-step 8) |
   | `callout-note`, `callout-abstract`, `callout-info`, `callout-todo`, `callout-tip`, `callout-success`, `callout-question`, `callout-warning`, `callout-failure`, `callout-danger`, `callout-bug`, `callout-example`, `callout-quote` | Callout: Note, Abstract, Info, To-do, Tip, Success, Question, Warning, Failure, Danger, Bug, Example, Quote | `callout admonition <type>` | `> [!note]\n> {caret}` (type per row) | yes |
   | `table` | Table (3 × 3) | `table grid` | `|   |   |   |\n| --- | --- | --- |\n|   |   |   |\n|   |   |   |\n` — 3 columns, 1 header row, 2 body rows; caret inside the first header cell (offset 2 of the snippet) | yes |
   | `code-block` | Code block | `code fence` | three backticks, `\n{caret}\n`, three backticks (caret on the empty middle line) | yes |
   | `math-block` | Math block | `math latex equation` | `$$\n{caret}\n$$` | yes |
   | `horizontal-rule` | Horizontal rule | `divider hr line` | `---` (`***` when it would be on line 0, because `---` there starts frontmatter); a blank line is added before it when the previous line is not blank (otherwise `---` would turn the previous paragraph into a heading) | yes |
   | `task` | Task | `todo checkbox` | `- [ ] {caret}` | yes |
   | `today` | Today's date | `date` | `formatMoment(now, settings.templates.dateFormat)` inline; no line break | no |
   | `template` | Insert template | `template` | runs command `templates.insert-template` (step 02.27) after deleting the `/query`; item is available only when that command is registered | no |
8. `snippet_placement.dart`: `Insertion placeSlash(String text, SlashContext ctx, SlashCommand cmd, Snippet snippet)`:
   - Replace range = `[slashStart, caret)`.
   - `linePrefix` = the leading indentation and blockquote markers of the caret line (regex `^(\s*(?:>\s?)*)`), plus, when what follows them is a list marker (`[-*+]` or `\d+[.)]`, optionally followed by a task box `[ ]`) and a space, that many **spaces** (the marker's width, so continuation lines align with the item text). Every `\n` inside a **block** snippet is followed by `linePrefix`, so a callout typed inside a list item or quote keeps its container.
     "Text before the slash is blank" means: after removing `linePrefix`-style markers (`> ` quote markers, and a list marker with its trailing space) nothing but whitespace remains before the `/`.
   - Block commands: if the text before `slashStart` on the line (after removing `linePrefix`) is non-blank → prepend `'\n' + linePrefix` (the construct starts on a new line). If the text after the caret on the line is non-blank → append `'\n'` + `linePrefix` after the snippet.
   - Heading commands (`isBlock == false`, prefix style): if the line before the slash is blank, insert the `#…# ` prefix there; otherwise insert it at the **start of the line** (after `linePrefix`) and delete only the `/query`: two edits.
   - Caret = `replaceStart + offsetOfCaretInsideSnippet` (computed after prefixes are added).
9. Controller + UI: `SlashContext` uses the same controller/popup. Items = commands filtered by `FuzzyScorer.score(query, label)` or any keyword (keyword score − 50); empty query → all items in list order (max 8 visible, scrolls). Enter/Tab/tap accept (a single `applyEdits` = one undo step). Esc hides and sets `dismissedAt`. The menu hides when the query contains a space or no command matches.
   Phone: the same docked sheet, rows 48 dp. The slash menu can be turned off with `corePlugins.slashCommands = false` (no UI in Phase 2; Phase 7 adds the switch).
10. l10n keys: `slashHeading1`…`slashHeading6`, `slashCalloutNote`…`slashCalloutQuote` (13), `slashTable`, `slashCodeBlock`, `slashMathBlock`, `slashHorizontalRule`, `slashTask`, `slashToday`, `slashTemplate`.

**Tests**
- `moment_format_test.dart` (fixed `DateTime(2026, 10, 11, 14, 5, 9)`): `formatMoment(t,'YYYY-MM-DD')` = `2026-10-11`; `'YY/M/D'` = `26/10/11`; `'dddd, MMMM Do YYYY'` = `Sunday, October 11th 2026`; `'ddd MMM D'` = `Sun Oct 11`; `'HH:mm:ss'` = `14:05:09`; `'hh:mm A'` = `02:05 PM`; `'h:m a'` = `2:5 pm`; `'[Week] D'` = `Week 11`; `'YYYY-MM-DD[T]HH:mm'` = `2026-10-11T14:05`;
  `'Q'` = `Q`; ordinals: day 1 → `1st`, 2 → `2nd`, 3 → `3rd`, 4 → `4th`, 11 → `11th`, 12 → `12th`, 13 → `13th`, 21 → `21st`, 22 → `22nd`, 23 → `23rd`, 31 → `31st`; midnight `h` → `12`, `hh` → `12`, `A` → `AM`; noon `A` → `PM`.
  `parseMoment('2026-10-11','YYYY-MM-DD')` = `DateTime(2026,10,11)`; `parseMoment('Sunday, October 11th 2026','dddd, MMMM Do YYYY')` = same; `parseMoment('2026-02-30','YYYY-MM-DD')` = null; `parseMoment('2026-10-11 02:05 PM','YYYY-MM-DD hh:mm A')` = `DateTime(2026,10,11,14,5)`; `parseMoment('x','YYYY')` = null.
  `validateMomentFormat('')` = `empty`; `'[abc'` = `unbalancedBracket`; `'YYYY:MM'` with `forFileName: true` = `forbiddenCharacter`; `'YYYY/MM/DD'` with `forFileName: true, requireDate: true` = null; `'HH:mm'` with `forFileName: true` = `forbiddenCharacter`; `'YYYY-MM'` with `requireDate: true` = `noDateTokens`; `'HHmm'` with `forFileName: true` (no `requireDate`) = null.
- `template_engine_test.dart` (title `Plan`, date = now = the instant above): `{{title}}` → `Plan`; `{{date}}` → `2026-10-11`; `{{time}}` → `14:05`; `{{date:dddd}}` → `Sunday`; `{{time:hh:mm A}}` → `02:05 PM`; `{{ date }}` → `2026-10-11`; `{{foo}}` unchanged; `{{date:}}` → `2026-10-11`; `{{date:Q}}` → `Q`; with `date = 2026-10-09` and now = the instant: `{{date}}` → `2026-10-09`, `{{time}}` → `14:05`; text `a {{title}} b {{title}}` → both replaced; a title containing `{{date}}` is not re-expanded.
- `daily_note_path_test.dart`: folder `Daily`, `YYYY-MM-DD` → `Daily/2026-10-11.md`; folder `''`, `YYYY/MM/YYYY-MM-DD` → `2026/10/2026-10-11.md`; format `YYYY-MM-DD[.md]` → `2026-10-11.md`; format `../x` → throws `InvalidPathException`.
- `slash_context_test.dart` (caret shown as `|`): `/he|` at line start → context (`query: 'he'`); `foo /he|` → context; `foo/he|` → null; `https://x|` → null; inside a code fence → null; `/|` (caret right after the slash) → context with `query: ''`; `/a b|` → null (a space ends the query); with `corePlugins.slashCommands = false` → null.
- `snippet_placement_test.dart`: `/h2|` at line start in `'a\n/h2'` → `'a\n## '`; `foo /h2|` → `'## foo '` (the `/h2` is deleted and the prefix inserted at the line start); `- item /callout-tip|` → `linePrefix` is two spaces (the width of `- `), result `'- item \n  > [!tip]\n  > '`; `> /callout-tip|` (inside a quote) → `'> > [!tip]\n> > '` (the text before the slash is blank once the `> ` marker is ignored, so there is no extra line break; the second line gets `linePrefix` `> ` in front of the snippet's own `> `);
  `/table|` on an empty line → exactly the 4-line table text above with the caret after the first `| `; `/hr|` after a paragraph line → blank line + `---`; `/hr|` on line 0 → `***`; `/today|` → today's date, no newline; `/task|` → `- [ ] `.
- `slash_menu_test.dart`: typing `/` shows 8 rows at desktop width; query `call` lists the 13 callouts first; query `tab` ranks `Table` first; Enter inserts and one Ctrl+Z (a fake controller counting `applyEdits` calls = 1) undoes; the `template` item is hidden while the command is unregistered.

**Verify:** `dart test` in `packages/tephra_core`; `flutter test` in `app/`. Manual: type `/` at a line start → menu; `/h2` Enter → `## `; `/callout` → pick Tip → `> [!tip]` + `> ` with the caret; `/today` → date. Commit `phase 02.22: add moment date format, template engine and slash menu`.

**Pitfalls**
- intl treats unquoted letters as pattern characters — that is why each token is formatted on its own. Never pass a whole Moment string to `DateFormat`.
- `DateFormat` for locales other than `en` needs `initializeDateFormatting(locale)` first; Phase 2 only passes `en`.
- The `---` slash item must never be inserted on line 0 (it would create frontmatter) or directly under a paragraph (it would create a setext heading).

---

### 02.23 Live Preview I: decoration model, incremental engine and inline widgets

**Purpose:** a pure-Dart model that turns the Markdown AST into *decorations* (hidden syntax markers, styles, replaced ranges), recomputes it incrementally per changed block, and the widgets that fill the replaced ranges.
This step has **no engine-specific code**; step 02.24 plugs it into the editor. Decorations never change the text: every offset of the buffer stays valid.

**Files** (new, `app/lib/editor/live_preview/`; the model files import **no** `package:flutter`, so they run under `flutter test` quickly and could move to a package later)
- `lp_decoration.dart`, `lp_options.dart`, `chunk_splitter.dart`, `block_decorator.dart`, `live_preview_engine.dart`, `reveal.dart`
- `widgets/lp_checkbox.dart`, `widgets/lp_embed.dart`, `widgets/lp_math.dart`, `widgets/lp_callout_header.dart`, `widgets/lp_rule.dart`, `widgets/lp_table.dart`, `widgets/lp_query_block.dart`
- tests: `app/test/editor/live_preview/chunk_splitter_test.dart`, `block_decorator_test.dart`, `live_preview_engine_test.dart`, `reveal_test.dart`, `lp_widgets_test.dart`

**Implementation**
1. Read `docs/decisions/0001-editor-engine.md` and `docs/spikes/editor.md` (API notes, check 7 "inline widgets"). Write into `PROGRESS.md` under 02.23: engine chosen (A/B/C) and whether spike check 7 (WidgetSpan inside a line) passed. Sub-step 6 and step 02.24 branch on that answer.
2. `lp_decoration.dart` (all offsets are absolute UTF-16 offsets into the `\n`-normalised buffer):
   ```dart
   /// When a decoration is shown as source instead of rendered. null = never (always rendered).
   final class LpReveal { const LpReveal(this.start, this.end); final int start; final int end; }   // inclusive on both ends, see reveal.dart
   sealed class LpDecoration { const LpDecoration(this.start, this.end, {this.reveal}); final int start; final int end; final LpReveal? reveal; }
   final class LpHide extends LpDecoration { }                              // syntax marker: zero-width when inactive
   final class LpStyle extends LpDecoration { const LpStyle(super.start, super.end, this.kind, {this.level = 0, this.data}); final LpStyleKind kind; final int level; final String? data; }   // never revealed
   final class LpReplaceChar extends LpDecoration { final String char; }    // one UTF-16 unit replaced by another one unit (bullet); reveal = null
   final class LpWidget extends LpDecoration { final LpWidgetKind kind; final Map<String, Object?> data; }   // replaced range
   enum LpStyleKind { heading, bold, italic, strike, highlight, inlineCode, internalLink, externalLink, tag, blockId, footnoteRef, comment, quoteLine, calloutLine, codeLine, taskDone, syntaxMarker, searchMatch }
   enum LpWidgetKind { checkbox, embed, image, inlineMath, mathBlock, calloutHeader, horizontalRule, table, queryBlock }
   ```
   `data` carries only JSON-like values (strings, ints, bools, lists of those) so decoration lists can cross isolates. `LpStyle.level`: heading level (1–6). `LpStyle.data`: link target, callout type, tag name.
   `lp_options.dart`: `LpOptions { bool hideFrontmatter = false; }` (true when the properties panel of step 02.26 is shown).
3. `reveal.dart`: `bool isRevealed(LpDecoration d, TextRange active)` = `d.reveal != null && active.start <= d.reveal!.end && active.end >= d.reveal!.start` — the **reveal rule**: a decoration is shown as source when the caret or any part of the selection touches its reveal range (touching = inclusive at both ends, so a caret directly after `**bold**` still reveals it).
   `active` = the selection range, extended to cover the IME composing range when one exists (step 02.24). Reveal ranges are assigned by the block decorator (next sub-step): **inline constructs** use their own node range; **line-level markers** (heading `#`, quote `>`, setext underline) use the range of their line(s);
   **multi-line constructs** (callout, table, math block, query block, frontmatter, code fence lines) use the range of the **whole construct**, so when the cursor is anywhere inside, every marker and widget of that construct turns into source at once.
4. `chunk_splitter.dart`: `List<ChunkSpan> splitChunks(String text)` (`ChunkSpan(start, end)`; the chunks tile the text exactly: first `start == 0`, last `end == text.length`, each `end` = next `start`). A chunk is a run of lines; a new chunk starts at the first non-blank line after one or more blank lines **unless**
   one of these keeps it joined to the previous chunk: (a) the scanner is inside frontmatter (line 0 is `---` until the next `---`/`...` line), a fenced code block (opened by a line starting with `` ``` `` or `~~~` after optional spaces, closed by the same character with at least the same length), a `$$` block (opened by a line whose trimmed text starts with `$$` and does not end with `$$` on the same line,
   closed by a line containing `$$`) or an open `%%` comment (odd number of `%%` so far); (b) the next non-blank line starts with a space or tab (indented continuation or indented code); (c) the next non-blank line starts with a list marker (`-`, `*`, `+` or `digits.`/`digits)` followed by a space) **and** the first non-blank line of the current chunk also starts with a list marker.
   One pass over the lines, no regular expressions per character; 5,000 lines must split in < 3 ms (test; record the number).
5. `block_decorator.dart`: `List<LpDecoration> decorateChunk(String chunkText, ParsedNote parsed, int base, LpOptions o)` walks `parsed.root` and returns decorations with offsets `base + node offset`. Rules (marker positions are found from the node range and the source text; `line(x)` = range from the start to the end (excluding `\n`) of the line containing `x`):
   | Node | Decorations |
   |---|---|
   | `MdHeading(level)` | `LpHide` from node start to the end of the `#` run plus following spaces/tabs (up to 3 leading spaces count), `reveal` = `line(start)`; `LpHide` for an ATX closing sequence (` ##` at the end), same reveal; `LpStyle(heading, level)` over the text between. Setext heading: `LpHide` over the underline line (`===`/`---`), reveal = both lines |
   | `MdStrong` | `LpHide` over the opening and closing marker runs (`**` or `__`, 2 chars each), reveal = node range; `LpStyle(bold)` over the inner range |
   | `MdEmphasis` | same with 1-character markers, `LpStyle(italic)` |
   | `MdStrikethrough` | markers `~~`, `LpStyle(strike)`; `MdHighlight`: markers `==`, `LpStyle(highlight)` |
   | `MdInlineCode` | `LpHide` over each backtick run (length n), reveal = node range; `LpStyle(inlineCode)` over the inner range |
   | `MdWikiLink` (not embed) | `LpHide` over `[[`; if an alias exists `LpHide` over `target#heading\|` (from after `[[` up to and including the alias separator); `LpHide` over `]]`; all with reveal = node range; `LpStyle(internalLink, data: target)` over the visible text |
   | `MdWikiLink` (embed) | `LpWidget(embed)` over the node range, `data: {target, heading, blockRef, size, pdfPage, from}`, reveal = node range |
   | `MdLink` (not image) | `LpHide` over `[` and over `](…)` (from the end of the text to the node end), reveal = node range; `LpStyle(internalLink or externalLink, data: url)` over the text |
   | `MdLink` (image) | `LpWidget(image)` over the node range, `data: {url, alt}` |
   | `MdAutolink` | `LpHide` over `<` and `>` when present; `LpStyle(externalLink)` |
   | `MdTag` | `LpStyle(tag, data: name)` |
   | `MdBlockId` | `LpStyle(blockId)` (shown, muted) |
   | `MdFootnoteRef` | `LpStyle(footnoteRef)` |
   | `MdInlineMath` | `LpWidget(inlineMath, data: {tex})` over the node range, reveal = node range |
   | `MdCommentInline` / `MdCommentBlock` | `LpStyle(comment)` over the whole comment (kept visible, muted — Obsidian shows comments in the editor) |
   | `MdListItem` (not a task) | `LpReplaceChar('•')` for `-`, `*`, `+` markers (ordered markers are untouched), `reveal` = null |
   | `MdListItem` (task) | `LpHide` over the bullet marker (the marker character only), reveal = the 3 box characters; `LpWidget(checkbox, data: {status})` over the 3 box characters `[x]`, reveal = those 3 characters; when the status is `x` or `X`: `LpStyle(taskDone)` over the task text |
   | `MdBlockQuote` (not callout) | per line: `LpHide` over `>` and one following space, reveal = that line; `LpStyle(quoteLine)` over the line's text |
   | `MdCallout` | first line: `LpWidget(calloutHeader, data: {type, title, fold})` over the **whole first line** (excluding `\n`), reveal = whole callout; every other line: `LpHide` over its `>` marker(s) and following space, reveal = whole callout; `LpStyle(calloutLine, data: type)` over every line of the callout |
   | `MdCodeBlock` (fenced) | `LpStyle(codeLine)` over every line of the block including fence lines; the fence characters themselves are **not** hidden in Phase 2 (the language word stays visible). Language `query` → `LpWidget(queryBlock, data: {query})` over the whole block, reveal = whole block. Language `mermaid`/`base` → just `codeLine` styling (their rendering is later phases) |
   | `MdCodeBlock` (indented) | `LpStyle(codeLine)` |
   | `MdMathBlock` | `LpWidget(mathBlock, data: {tex})` over the whole block, reveal = whole block |
   | `MdTable` | `LpWidget(table, data: {cellRanges: [[start,end]…], aligns})` over the whole table, reveal = whole table; no hiding (the widget replaces the lines) |
   | `MdThematicBreak` | `LpWidget(horizontalRule)` over the line, reveal = the line |
   | `MdFrontmatter` | only when `options.hideFrontmatter`: `LpHide` over the whole range, reveal = whole range; otherwise `LpStyle(comment)` |
   | `MdFootnoteDefinition`, `MdHtml*` | no decoration |
   When a revealed `LpHide` is shown, the adapter styles it with `LpStyleKind.syntaxMarker` (muted colour) so revealed source looks like Source mode; the decorator emits no extra decoration for that.
   Widget decorations never start with a non-BMP character (a rule of the adapter in step 02.24); the decorator does not need to check it.
6. `live_preview_engine.dart`:
   ```dart
   final class LivePreviewEngine {
     LivePreviewEngine({this.options = const LpOptions(), ParsedNote Function(String)? parse});   // parse defaults to MarkdownParser.parse
     LpOptions options;
     void setText(String text);                                   // full recompute
     void applyEdit({required int start, required int deletedLength, required String insertedText, required String newText});
     List<LpDecoration> decorationsFor(int start, int end);       // absolute offsets, sorted by (start, end); returns those overlapping [start, end)
     int get revision;                                            // +1 after every change; the adapter repaints when it changes
     LpEngineStats get lastStats;                                 // chunksReparsed, chunkCount, microseconds
   }
   ```
   `setText`: `splitChunks`, then parse + `decorateChunk` for every chunk; texts longer than **50,000** characters are computed with `Isolate.run` (decoration lists contain only sendable data); until the result arrives `decorationsFor` returns an empty list (the editor shows plain source styling) and `revision` increments when it arrives.
   `applyEdit` (the incremental path, always synchronous): `delta = insertedText.length − deletedLength`; `newChunks = splitChunks(newText)`; for each new chunk `c` reuse the old chunk's decorations (shifted by `delta` when after the edit) **iff**
   (i) `c.end <= start` and an old chunk has identical `start` and `end`, or (ii) `c.start >= start + insertedText.length` and an old chunk has `start == c.start − delta`, `end == c.end − delta` and `start >= start + deletedLength` (entirely after the deleted range); every other chunk is re-parsed (`parse(newText.substring(c.start, c.end))`, `decorateChunk` with `base = c.start`).
   Chunks store decorations with **chunk-relative** offsets plus `chunkStart`, so shifting is `chunkStart += delta` (no per-decoration work). `decorationsFor` binary-searches the chunk list.
   Typical edit: 1–2 chunks re-parsed. Budget on the 5,000-line note: `applyEdit` ≤ 6 ms median (test records it).
7. Widgets (`widgets/`, all take `LpWidget` data and an `LpWidgetHost` with callbacks `selectOffset(int)`, `applyEdits(List<TextEdit>)`, `path`, `ref`):
   - `lp_checkbox.dart`: 18 dp `Checkbox`, checked for status `x`/`X`, indeterminate look for other non-space statuses (custom statuses show their character in a 14 dp chip instead). Toggle → `applyEdits([TextEdit(i, i + 1, newStatus)])` where `i` = offset of the status character, `newStatus` = `'x'` if the current status is `' '`, else `' '`. 48 × 48 dp hit area on phone layout.
   - `lp_embed.dart`: embed/image → the Phase 2 `EmbedView` from step 02.14 with `EmbedContext(depth 0, chain {path})`, read-only; a tap on the embed's own background calls `selectOffset(start)` (caret enters → source revealed); taps on links inside the embed behave as in reading view.
   - `lp_math.dart`: whatever Phase 1's reading view uses for `MdInlineMath` / `MdMathBlock` (tinted monospace TeX box); tap → `selectOffset(start)`.
   - `lp_callout_header.dart`: icon + title (title or the capitalised type) + fold chevron when `fold != none`. Icons by type: note `edit`, abstract `assignment`, info `info`, todo `check_circle`, tip `lightbulb`, success `check`, question `help`, warning `warning`, failure `close`, danger `bolt`, bug `bug_report`, example `format_list_bulleted`, quote `format_quote`; unknown type → note. Colours: reuse Phase 1's reading-view callout palette (`git grep -n -i "callout" app/lib/reading`); do not define a second palette. The chevron toggles the **view-only** fold state `foldedCallouts` (a `Set<int>` of callout start anchors kept by the adapter and mapped through edits; initial = `fold == collapsed`); it never edits the note. Tap elsewhere on the header → `selectOffset(start)`.
   - `lp_rule.dart`: a 1 dp divider across the line width; tap → `selectOffset(start)`.
   - `lp_table.dart`: reuse the reading view's table widget on `MarkdownParser.parse(slice)`; a tap on a cell calls `selectOffset(cellRanges[row][col].start)` (the caret enters the table → the whole table becomes source).
   - `lp_query_block.dart`: the `QueryBlockView` of step 02.17 (same widget as reading view), with a small "Edit" icon button at its top right → `selectOffset(start)`.
   Page preview and link navigation hooks (promised by steps 02.14 and 02.17): link spans (`LpStyleKind.internalLink`) are handed to the adapter with their `data` target; the adapter (02.24) calls `PagePreviewController.requestHover(target, rect)` on pointer hover (desktop, with the Ctrl requirement of the setting `pagePreviewEditorRequiresCtrl`, default `true`), `PagePreviewController.show(target)` on long-press (phone),
   and `LinkNavigator.open(newTab: true)` on Ctrl+click (desktop) or on a plain tap on an **inactive** (rendered) link (phone). A plain click on desktop only places the caret.

**Tests**
- `chunk_splitter_test.dart`: `'a\n\nb'` → 2 chunks `[0,3)`, `[3,4)`; `'a\n\n\nb'` → `[0,4)`, `[4,5)`; a fenced block with a blank line inside stays one chunk; `$$\nx\n\ny\n$$` one chunk; `'- a\n\n- b'` one chunk; `'- a\n\nText'` two chunks; `'Para\n\n    code'` one chunk (indent continuation); frontmatter with a blank line inside stays attached to the first chunk; chunks tile the text (property test over every note in `test_vaults/syntax` and `edge`); 5,000-line text splits in < 3 ms.
- `block_decorator_test.dart`: one test per table row with exact decoration lists, for example `'**bold** x'` → `[LpHide(0,2, reveal 0..8), LpHide(6,8, reveal 0..8), LpStyle(2,6, bold)]`; `'# T'` → `[LpHide(0,2, reveal 0..3), LpStyle(2,3, heading, level 1)]`; `'[[N|a]] z'` → hides `[[` (0,2), `N|` (2,4) and `]]` (5,7), style internalLink over (4,5) with `data: 'N'`; `'[t](u) z'` → hides (0,1) and (2,6), style over (1,2); `'- [ ] t'` → hide (0,1), `LpWidget(checkbox)` (2,5), no `taskDone`; `'- [x] t'` → plus `LpStyle(taskDone)` over (6,7); `'- a'` → `LpReplaceChar('•')` at (0,1); callout `'> [!note] T\n> b'` → one `LpWidget(calloutHeader)` over (0,11), hide (12,14), `calloutLine` over both lines.
  The no-text-change guarantee: for every note of `test_vaults/syntax` and `edge`, every decoration satisfies `0 <= start <= end <= text.length` and `LpReplaceChar` spans exactly 1 UTF-16 unit; hidden ranges never overlap each other.
- `live_preview_engine_test.dart`: **equivalence** — for each note of `test_vaults/syntax`, `decorationsFor(0, len)` from `setText` equals the decorations of a single-chunk full parse (build the reference by calling `decorateChunk` once on the whole text); then 500 random single-character edits (inserts and deletes at random offsets, `Random(seed)`, seed printed on failure) applied with `applyEdit`: after every 25 edits the incremental result equals a fresh `setText(newText)` result.
  An edit inside a paragraph re-parses exactly 1 chunk (`lastStats.chunksReparsed == 1`); typing a line that opens a code fence (`` ``` ``) re-parses the following chunks until the fence state matches the old one and the result still equals a fresh `setText`; deleting the blank line between two paragraphs merges two chunks into one.
  Performance (record numbers): 5,000-line note `applyEdit` ≤ 6 ms median, `decorationsFor` of a 60-line window < 1 ms, `setText` of the 5,000-line note ≤ 400 ms (run inside the test isolate).
- `reveal_test.dart` (inclusive rule): decoration with reveal 0..8 and active range `(8,8)` → revealed; `(9,9)` → not; selection `(3,12)` → revealed; a decoration with `reveal == null` is never revealed. Multi-line: a callout reveal covering lines 0–1 is revealed by a caret on line 1.
- `lp_widgets_test.dart`: checkbox toggling produces `TextEdit(i, i+1, 'x')` and then `' '`; a custom status `/` toggles to `' '`; callout chevron toggles the view-only set and produces **no** edit; table cell tap selects the cell's start offset; embed widget renders `EmbedView` for `![[Other]]`; query block shows an Edit button that selects the block start.

**Verify:** `flutter test` for these files; the equivalence and performance tests print their numbers into `PROGRESS.md`. Commit `phase 02.23: add live preview decoration model, incremental engine and widgets`.

**Pitfalls**
- Never put a `TextSpan`, `Color` or other Flutter type in a decoration; the lists must stay sendable to an isolate.
- A decoration must never claim more than one line unless it is a multi-line construct listed in sub-step 5 (the adapter's line cache depends on it).
- Chunk equivalence failures are splitter bugs: fix `splitChunks` (never loosen the test); the safe direction is to join more lines into one chunk.

---

### 02.24 Live Preview II: editor adapter, reveal on the caret, mode toggle (Ctrl+Shift+E), default mode

**Purpose:** show the decorations in the editor of the chosen engine, with the reveal rule driven by the caret/selection/IME state, per-tab mode, and the default-mode setting. Offsets never change.

**Files**
- `app/lib/editor/editor_decorator.dart` (interface), `app/lib/editor/editor_controller.dart` (additions), engine adapter files named in the table of sub-step 2
- `app/lib/editor/live_preview/live_preview_decorator.dart`, `span_builder.dart`, `live_preview_session.dart`, `editing_mode.dart`, `editing_mode_commands.dart`, `providers.dart` (extend)
- Workspace tab model + `.tephra/workspace.json` reader/writer (Phase 1; add `mode`), vault settings (add `editor` group), note screen app-bar overflow menu, settings screen ("Editor" section)
- tests: `app/test/editor/live_preview/span_builder_test.dart`, `live_preview_session_test.dart`, `editing_mode_test.dart`, `live_preview_no_write_test.dart`, `app/integration_test/live_preview_ime_test.dart`

**Implementation**
1. **Mode model.** `enum EditingMode { livePreview, source }` (`editing_mode.dart`). Per-tab state: add field `EditingMode editingMode` to Phase 1's `FileTabContent` (the tab content that holds an open note; additive; missing in an old `workspace.json` = the default below). Persist it in the tab entry of the device's layout in `.tephra/workspace.json` as `"mode": "livePreview" | "source"` (read-modify-write of this device's entry only; other keys and other devices untouched).
   Vault setting (nested JSON `editor`): `{ "defaultEditingMode": "livePreview" }` (values `livePreview` or `source`; registry name `editor.defaultEditingMode`; the settings screen "Editor" section gets a dropdown "Default editing mode"). New tabs start with the default; opening a note into an existing tab keeps that tab's mode.
   Reading view stays a separate tab *view* (Phase 1): a tab has a view (`editing` / `reading`) and, while editing, a mode.
2. **Engine adapters.** Define in `editor_decorator.dart`:
   ```dart
   abstract interface class EditorDecorator {
     Listenable get changes;                         // notifies when decorations or the reveal state changed
     TextSpan decorateLine({required int lineStart, required int lineEnd, required TextSpan plain, required TextStyle base});   // lineEnd excludes '\n'
   }
   ```
   `EditorController` gets `void setDecorator(EditorDecorator? d)`, `void setTapInterceptor(bool Function(int offset, PointerDeviceKind kind, bool control)? fn)` and `Rect? rectForRange(int start, int end)`; `setDecorator(null)` = Source mode (the Phase 1 source highlighter).
   Implement per engine (the hiding technique is fixed per engine; record the engine in `PROGRESS.md`):
   | Engine (from the ADR) | Where the decorator plugs in | How text is hidden | Widgets (`LpWidget`) |
   |---|---|---|---|
   | **A — `re_editor`** | the `buildTextSpan({context, index, textSpan, style})` override of the controller subclass (Phase 1 already has one for source highlighting): when a decorator is set, return `decorator.decorateLine(...)` for line `index` | per-line `TextSpan` pieces with `TextStyle(fontSize: 0.01, color: Colors.transparent, letterSpacing: 0, height: 0.01)` ("zero-size"); the buffer is untouched, so offsets are identical | `WidgetSpan` trick of sub-step 4 (spike check 7 must have passed; otherwise sub-step 6) |
   | **B — `TextField` + `buildTextSpan`** | the `buildTextSpan({context, style, withComposing})` override of the controller: split the text into lines, call `decorateLine` for each, join with `TextSpan(text: '\n')` | same zero-size style | same `WidgetSpan` trick (spike check 7) |
   | **C — custom `RenderObject`** | the editor's own line painter: hidden ranges get **zero advance** in layout (a hidden-range table maps buffer offsets to layout offsets) | native: the range is skipped in layout | native widget layers |
   (Phase 1 stops if the ADR chose engine C, so row C is informational: it states what a custom engine would have to provide.)
   **Fallback when the platform clamps tiny fonts** (check during the manual test below: if a hidden marker such as `**` still leaves a visible gap on Android): set `LpHideMode.transparent` for that platform — the marker is drawn with the **same size** but `color: Colors.transparent` (the text keeps its width, so the line looks slightly padded; offsets are still identical). Choose the mode with the constant `kLpHideMode` in `span_builder.dart` (`zeroSize` default) and record the decision per platform in `PROGRESS.md`.
3. `span_builder.dart` — `TextSpan buildLpLine(...)` (pure function of the line text, its decorations, the active range and style tokens; unit-testable without an engine):
   1. `decos = engine.decorationsFor(lineStart, lineEnd + 1)`; cut every decoration to the line `[lineStart, lineEnd)`.
   2. Boundaries = all decoration starts/ends inside the line; walk the segments left to right.
   3. For each segment compute: `hidden` = covered by an `LpHide` with `!isRevealed(d, active)`; `revealedMarker` = covered by an `LpHide` that **is** revealed → style `syntaxMarker` (muted); `replaced` = covered by an `LpWidget` with `!isRevealed`; `replaceChar` from `LpReplaceChar`; styles from `LpStyle`s.
   4. Style merge priority (later wins on conflicting fields, fields merge otherwise): `codeLine` < `quoteLine` < `calloutLine` < `heading` < `bold` < `italic` < `strike` < `highlight` < `inlineCode` < `internalLink`/`externalLink` < `tag` < `taskDone` < `comment` < `blockId` < `footnoteRef` < `searchMatch`. Heading levels 1–6 use font scales `2.0, 1.6, 1.35, 1.2, 1.1, 1.0` and bold; callout/quote lines get a tinted `backgroundColor` (tint only behind glyphs in Phase 2 — a full-width line background needs an engine hook; use it if the ADR API notes list one, otherwise accept the glyph-width tint).
   5. Emit one `TextSpan` per segment with the **same text** as the source segment, except: `replaceChar` → the replacement unit (length 1 → length 1); hidden → the source text in the zero-size (or transparent) style; widget → see sub-step 4.
   6. Invariant (asserted in tests and by `assert` in debug builds): `span.toPlainText(includePlaceholders: true).length == lineEnd − lineStart`.
   7. Internal links get `mouseCursor: SystemMouseCursors.click` and `onEnter`/`onExit` callbacks (hover → page preview request, see step 02.23 hooks).
4. **Widgets with W1 (the offset-preserving `WidgetSpan` trick; used when spike check 7 passed):** a replaced range `[s, e)` is emitted as: a `WidgetSpan(alignment: PlaceholderAlignment.middle, child: …)` that stands for the **first UTF-16 unit** of the range (a placeholder counts as exactly 1 unit in the span tree), followed by the remaining `[s+1, e)` text in the hidden style. Offsets after the range are therefore unchanged. Rules:
   - A widget is used only if `text[s]` is a BMP character (not a surrogate); otherwise render the range as plain source.
   - **Multi-line widgets** (callout header over one line + hidden body lines; table; math block; query block): the widget goes on the **first** line of the construct; every other line of the construct is emitted completely hidden (zero-size), so the lines occupy ~0 height. Blank lines inside such a construct (possible only in math blocks and query blocks) keep one normal line height — accepted and listed as a known limit in `PROGRESS.md`.
   - A callout whose view-only fold state is *collapsed* hides its body lines in the same way (header widget only).
   - The widget's width is capped at the editor width minus 16 dp; its height is whatever it needs (the line grows).
   - Hit-testing: the widget handles its own taps (checkbox toggle, chevron); `setTapInterceptor` handles the rest (sub-step 7).
5. **Selection, composing and reveal state (`live_preview_session.dart`):** `LivePreviewSession` owns the `LivePreviewEngine`, subscribes to `controller.edits` (→ `engine.applyEdit`, passing `controller.text` as `newText`) and `controller.selectionChanges`, and exposes `active = selection ∪ composing` as one `TextRange` (the smallest range covering both). Whenever `active` changes, the decorator notifies `changes` **only if** some decoration's revealed state differs between the old and new `active`
   (compare `isRevealed` for the decorations near both ranges) — arrow-key moves inside plain text cause no repaint. While `controller.composing` is non-empty the revealed set is **frozen**: the construct containing the composing range counts as revealed and no other construct changes state until composition ends, so an IME never sees text jump under it.
   A selection across several constructs reveals all of them (rule of step 02.23). Mouse drag-selection updates `active` on every change; a click that puts the caret into hidden text reveals the construct on the next frame (the caret position is the same offset, the layout shifts as the markers appear — this is the same as Obsidian).
6. **If spike check 7 failed** (no inline widgets in this engine): `LpWidget` decorations are not rendered as widgets. Instead `buildLpLine` renders their source range with styles only — `embed`/`image` → `LpStyleKind.internalLink` look, `inlineMath`/`mathBlock`/`table`/`queryBlock` → monospace `codeLine` style, `horizontalRule` → muted source, `checkbox` → source `[ ]` in a monospace chip style (toggle with the existing command `editor.toggle-task` or Ctrl+Enter from Phase 1; if Phase 1 has no such command add `editor.toggle-task` — it applies the same `TextEdit` as the widget), `calloutHeader` → hide the `> ` and `[!type]` markers, show the title bold with the callout tint.
   Callouts, headings, lists, links and emphasis still look rendered (they need only hide/style). Record "Live Preview widgets limited by engine <A|B>: <list>" in `PROGRESS.md` and tell the human in the phase report (it is the documented fallback of the ADR, not a failure). Everything else in this step is identical.
7. **Pointer handling:** `setTapInterceptor((offset, kind, control) …)`: find the `internalLink`/`externalLink` style whose range contains `offset` and whose line's constructs are **not** revealed: desktop (`kind` mouse) + `control` → `LinkNavigator.open(newTab: true)` (external links: `launchUrl`); touch/stylus → open the link (this is "tap a rendered link opens it"; the caret is not moved). Return `true` when handled. Everything else returns `false` (the engine places the caret).
8. **Mode toggle.** Commands (registered in `editing_mode_commands.dart`): `editor.toggle-editing-mode` — label `commandToggleEditingMode` "Toggle Live Preview / Source mode", default shortcut `Ctrl+Shift+E`, available when the active tab is a note; in editing view it flips the tab's `editingMode` (`controller.setDecorator(session.decorator)` or `null`; the caret, selection, scroll position and undo history are kept — the buffer is the same); in reading view it switches the tab to editing view in its current `editingMode`.
   **Shortcuts (fixed decision, matches Obsidian):** `Ctrl+E` stays bound to Phase 1's `editor.toggle-reading-view` (reading ↔ editing). Do **not** rebind it. This command uses `Ctrl+Shift+E`. Run `git grep -n "Ctrl+Shift+E" app/lib` first; if anything else already uses it, stop and report. Hotkey overrides in `.tephra/hotkeys.json` (imported from Obsidian) still win over defaults.
   Phone: the note screen's overflow menu gets the item "Live Preview" / "Source mode" (label shows the mode you would switch **to**) calling the same command; `showInMobileToolbar: false`.
9. **Frontmatter:** `LpOptions.hideFrontmatter = (editor.propertiesInDocument != 'source')` — wired in step 02.26 (the setting is created there); until then `false`.
10. Settings JSON: `editor.defaultEditingMode` only. Add l10n: `commandToggleEditingMode`, `editingModeLivePreview`, `editingModeSource`, `settingEditorDefaultEditingMode`.

**Tests**
- `span_builder_test.dart` (helper `visibleText(span)` = concatenation of non-hidden segments, widget → `U+FFFC`; caret/selection given as `TextRange`): `'**bold** text'` with caret 13 → `'bold text'`; caret 3 → `'**bold** text'`; caret 8 (touching the end) → `'**bold** text'`; caret 9 → `'bold text'`; selection (0,13) → source;
  `'# Title'` caret in another line → `'Title'` with heading scale 2.0; caret on the line → `'# Title'` and the `#` muted; `'[[Note|alias]] x'` caret 15 → `'alias x'`; caret 5 → source; `'[t](http://a.b) z'` caret at end → `'t z'`; `'- item'` → `'• item'` for any caret; `'- [ ] todo'` caret elsewhere → ` U+FFFC todo` (a space, the placeholder, a space and `todo`) (bullet hidden, one placeholder for the 3 box characters); caret inside the box → source.
  Callout `'> [!note] Title\n> body'`: caret outside → line 0 visible text `U+FFFC`, line 1 `body`; caret anywhere in either line → both lines show full source. Table: caret in any row → all rows source. Invariant test: for every line of every note in `test_vaults/syntax`, with active ranges at the start, middle and end of the note, `toPlainText(includePlaceholders: true).length` equals the source line length (both widget modes: W1, and with widgets disabled).
- `live_preview_session_test.dart` (fake `EditorController` emitting events): caret moves within plain text → `changes` does not fire; caret entering `**bold**` → fires once; typing inside a bold run → `applyEdit` called with the right delta; composing range set → reveal frozen: moving the caret to another construct does not change its state until composing is cleared; selection spanning two constructs reveals both.
- `editing_mode_test.dart`: toggle sets `setDecorator(null)` and back; new tab uses `defaultEditingMode`; mode persisted into `workspace.json` of this device only (another device's entry byte-identical); unknown keys of the entry preserved; the command is registered with default Ctrl+Shift+E and `editor.toggle-reading-view` keeps Ctrl+E (test with the real registry).
- `live_preview_no_write_test.dart` (`MemoryVaultFileSystem` counting writes): open every note of `test_vaults/syntax` and `edge` in Live Preview, move the caret through the whole note, toggle the mode 4 times, close → **0** `writeText`/`writeBytes` calls (Live Preview never changes text; conventions §6.2).
- `integration_test/live_preview_ime_test.dart` (needs a device; marked "not verified on device" in `PROGRESS.md` if none): with the caret inside `**bo|ld**` simulate composing text via `TestTextInput` deltas (`replaceComposing`) → the final text is exactly what was composed, no duplicated characters, and the reveal state was frozen while composing.
- Manual (both platforms; record in `PROGRESS.md`): (1) type `**bold**`, move away → markers disappear, move back → they reappear; (2) Android Gboard Bangla and English autocorrect inside a revealed `**…**` → text intact; (3) Windows IME (Bengali Phonetic or Japanese) inside a link text → intact; (4) select from inside a heading to inside a bold run and copy → copied text is the **source** text including markers; (5) hidden-marker gap check on Android (decides `kLpHideMode`); (6) Ctrl+Shift+E on Windows and the overflow-menu item on Android flip the mode without moving the caret.

**Verify:** `flutter test` in `app/`; `flutter run -d windows` and a real Android device, a vault with `test_vaults/syntax` — open each syntax note in Live Preview: headings sized, bold/italic/strike/highlight styled, links show their text, checkboxes clickable (if widgets supported), images and embeds rendered, callout header, table and math as widgets that turn back into source when the caret enters. Commit `phase 02.24: add live preview adapter, mode toggle and default mode`.

**Pitfalls**
- Never let a decorator change the length of a line (see the invariant in sub-step 3). One extra or missing code unit shifts every caret position after it.
- Do not recompute decorations inside `buildTextSpan` — only read the cache (`decorationsFor`) there; parsing belongs to `applyEdit`/`setText`, which run on edits.
- Do not repaint every line on every caret move; use the changed-reveal check of sub-step 5, or typing in a 5,000-line note will miss the 16 ms budget.
- Source mode must stay exactly as Phase 1 delivered it (`setDecorator(null)`); do not route Source mode through the Live Preview code.

---

### 02.25 Folding of headings and list items with persisted fold state

**Purpose:** collapse a heading's section or a list item's children in the editor (Source and Live Preview); fold state is remembered per note in `.tephra/workspace.json`.

**Files** (new, `app/lib/editor/folding/`)
- `fold_regions.dart`, `fold_anchors.dart`, `fold_state.dart`, `fold_store.dart`, `fold_controller.dart`, `fold_gutter.dart`, `fold_commands.dart`, `providers.dart`
- Phase 1 workspace store (add per-device `folds` map access), `LinkRenameService` (call `foldStore.retarget`), vault settings (`editor.foldHeadings`, `editor.foldIndent`), settings screen, l10n
- tests: `app/test/editor/folding/fold_regions_test.dart`, `fold_anchors_test.dart`, `fold_store_test.dart`, `fold_controller_test.dart`, `fold_gutter_test.dart`

**Implementation**
1. Settings (nested JSON `editor`, booleans, default `true`; registry names `editor.foldHeadings`, `editor.foldIndent`): "Fold heading" and "Fold indent" switches in the settings screen "Editor" section. When one is turned off its chevrons disappear and its folds are unfolded in open editors (stored folds of that kind are kept but ignored).
2. `fold_regions.dart` (pure): `List<FoldRegion> computeFoldRegions(String text, ParsedNote parsed, {bool headings = true, bool lists = true})`; `FoldRegion { FoldKind kind /* heading | list */; int headerStart; int from; int to; int level }`; `from` = end of the header line (offset of its `\n`), `to` = end of the last content line (no trailing newline); the hidden lines are those after the header line up to the line containing `to`.
   - Heading `h`: `to` = start of the next heading with `level <= h.level` (or `text.length`) minus one if the previous character is `\n`; then move `to` back over trailing blank lines. A heading with `to <= from` is not foldable.
   - List item: the item must contain a nested list item or continuation lines after its first line; `from` = end of the item's first line, `to` = end of the item (children included), trimmed of trailing newlines.
   Example (`'# A\na\n## B\nb\n# C\nc'`): regions `A (headerStart 0, from 3, to 12)`, `B (6, 10, 12)`, `C (13, 16, 18)`; for `'- a\n  - b\n  - c\n- d\n'` one region `(0, 3, 15)`.
   Frontmatter, code blocks and tables are never foldable.
3. `fold_anchors.dart`: `FoldState` keeps the folded set as **anchors** = `headerStart` offsets. `FoldState mapThroughEdit(int start, int deletedLength, int insertedLength)`: anchors before `start` unchanged; anchors at or after `start + deletedLength` shift by `inserted − deleted`; an anchor inside the deleted range is dropped. After every re-computation of regions (the live parse of `activeParsedNoteProvider`) a folded anchor is **active** iff a region with `headerStart == anchor` exists; anchors without a region are dropped.
4. `FoldController` (per editor, `foldControllerProvider.family<..., String /*tabId*/>`): API `toggle(int headerStart)`, `foldAll()` (every region), `unfoldAll()`, `isFolded(int headerStart)`, `foldedRanges` (list of `(from, to)`), `revealOffset(int offset)` (unfolds every fold containing `offset`; called by `EditorController.revealOffset`, by search/link navigation and by the caret entering a folded range: when the selection lands inside a folded range its fold is removed). Listens to `edits` (→ `mapThroughEdit`) and to new parses (→ drop dead anchors, notify).
   **Engine specifics:** A (`re_editor`): implement the engine's chunk analyzer from the ADR API notes (a `CodeChunkAnalyzer` implementation returning one chunk per `FoldRegion`, header line → last hidden line) and drive its collapse/expand API from `FoldController` (hidden lines then collapse natively, blank lines included). B and C: fold = every line after the header up to `to` is emitted by the decorator as fully hidden (`LpHide`-style zero-size) and the header line gets a trailing `…` hint drawn by the gutter widget; blank lines inside a folded range keep one line height in engine B (known limit, record it).
   Select-all + delete deletes the folded text too (it is inside the selection) — same as Obsidian. Copy of a selection containing a folded range copies the full text.
5. Gutter (`fold_gutter.dart`): a 20 dp strip left of the text (desktop: chevron appears when the pointer is over the heading/list line, always shown for folded lines; phone: chevrons are always visible, 24 dp wide with a **48 × 48 dp** hit area centred on the chevron). Chevron down = expanded, right = folded. Tap/click toggles. Folded header lines show a muted `…` after the text. If the engine has no gutter API, draw the strip as a `Stack` layer aligned with `rectForRange(headerStart, headerStart)`.
6. Commands (registered; palette; no default shortcuts): `editor.toggle-fold-at-cursor` (folds/unfolds the innermost region whose header line contains the caret, or the nearest enclosing region), `editor.fold-all`, `editor.unfold-all`. l10n `commandToggleFold`, `commandFoldAll`, `commandUnfoldAll`.
7. Persistence in `.tephra/workspace.json`, inside **this device's** entry (key = device id, conventions §6.6):
   ```json
   "folds": { "Notes/Plan.md": { "t": 1760000000000, "items": [ { "k": "h", "line": 12, "text": "## Tasks" }, { "k": "l", "line": 30, "text": "- group" } ] } }
   ```
   `k` = `h` heading or `l` list; `line` = 0-based line of the header; `text` = the header line trimmed, cut to 80 characters; `t` = last write time (ms). At most **500** notes are kept (drop the oldest `t`).
   `FoldStore`: `load(path)` → items; `save(path, items)` debounced **1 s** after the last change and flushed when the tab closes or the app pauses; saving an empty list removes the note's entry. A write re-reads the current file text, parses it, replaces only `deviceEntry.folds[path]`, preserves every other key and every other device's entry, and writes atomically via the vault file system only if the serialised text changed (never rewrite an unchanged file).
   `retarget(Map<VaultPath, VaultPath> moves)` re-keys entries (called by `LinkRenameService` after a successful move, folder moves map every prefix); `remove(path)` is called when a note is deleted (the explorer delete flow).
   Restore on open: compute regions from the first parse; for each stored item find the region of the same `k` whose header line number equals `line` and whose header text equals `text`; if none, the region with the same text nearest to `line` (within ±200 lines) not yet used; if none, drop the item.
8. Folds never change the text, so they never cause a write; opening and closing a note with folds writes only `workspace.json` (not the note).

**Tests**
- `fold_regions_test.dart`: the two examples above; heading inside a fenced block is not a region (it is not an `MdHeading`); a heading directly followed by another heading of the same level → not foldable; trailing blank lines are excluded from `to`; `headings: false` removes heading regions.
- `fold_anchors_test.dart`: anchors `{0, 6}`; insert 3 characters at 2 → `{0, 9}`; delete 3 characters at offset 1 (range 1–4, before the second anchor) → `{0, 3}`; delete the range 5–8 (contains the anchor 6) → `{0}`; anchor without a region after a re-compute is dropped.
- `fold_store_test.dart` (`MemoryVaultFileSystem`): save → file contains only this device's entry changed (another device's entry byte-identical, an unknown key preserved); empty list removes the note entry; 501 notes → the oldest dropped; `retarget` re-keys incl. a folder move; saving twice with identical content writes once; restore: edit the note so the header moved by +3 lines → item re-anchored by text; header text changed → item dropped.
- `fold_controller_test.dart`: toggle/foldAll/unfoldAll; caret moved into a folded range unfolds it; `revealOffset` unfolds all containing folds; edits above a fold keep it folded (anchor shift); `editor.foldHeadings = false` unfolds heading folds.
- `fold_gutter_test.dart`: at 1200 dp a chevron appears on hover for a heading line; at 400 dp chevrons are always present with a 48 dp hit area; tapping toggles.

**Verify:** `flutter test`. Manual: fold a heading and a nested list in a 500-line note, close and reopen the note → folds restored; edit above the fold → still folded; open the note in Source and in Live Preview mode → both fold; open `.tephra/workspace.json` → valid JSON with only your device's entry changed. Commit `phase 02.25: add heading and list folding with persisted fold state`.

**Pitfalls**
- Do not store absolute offsets in `workspace.json` (they go stale as soon as the note is edited elsewhere); store line + header text as above.
- Never write the note itself when folds change.
- Keep `FoldStore` writes off the typing path (debounce); one write per second at most.

---

### 02.26 Properties editor (typed widgets, type registry, `yaml_edit`)

**Purpose:** a panel above the note (Live Preview) that shows the frontmatter as typed properties and edits it **without reformatting anything the user did not touch**; the property type registry `.tephra/types.json`; a raw YAML editor for broken frontmatter.

**Files** (new, `app/lib/properties/`)
- `property_type.dart`, `property_type_registry.dart`, `property_value_codec.dart`, `frontmatter_editor.dart`, `properties_exceptions.dart`
- `properties_panel.dart`, `property_row.dart`, `raw_yaml_editor.dart`, `widgets/text_value_field.dart`, `chips_value_field.dart`, `number_value_field.dart`, `checkbox_value_field.dart`, `date_value_field.dart`, `datetime_value_field.dart`, `providers.dart`
- note screen (Phase 1 workspace/editor host): place the panel above the editor; vault settings (`editor.propertiesInDocument`); Live Preview wiring of `LpOptions.hideFrontmatter` (step 02.24); `.obsidian/types.json` import; l10n
- tests: `app/test/properties/frontmatter_editor_test.dart`, `property_type_registry_test.dart`, `property_value_codec_test.dart`, `properties_panel_test.dart`, `raw_yaml_editor_test.dart`

**Implementation**
1. Dependencies (already in the "Dependencies" table; add now if not yet): `cd app; flutter pub add yaml_edit yaml` then `dart run tool/check_licenses.dart`. Use `YamlEditor` for every change of an existing document, and `loadYaml`/`loadYamlNode` (source spans) for reading and for the two operations `YamlEditor` lacks (rename and reorder, sub-step 3).
2. `property_type.dart`: `enum PropertyType { text, multitext, number, checkbox, date, datetime, aliases, tags }` with `String get jsonName` (exactly these lower-case names, the same strings as Obsidian's `types.json`) and `static PropertyType? fromJson(String)`.
   `PropertyTypeRegistry` (`property_type_registry.dart`, file `.tephra/types.json`, shape `{ "types": { "<key>": "<type>" } }` — conventions §6.4/§6.6):
   - `load(fs)`: if `.tephra/types.json` exists, parse it (invalid JSON → log `warning`, start empty, never overwrite the broken file until the user changes a type; then keep a copy `.tephra/types.json.bak`). If it does **not** exist and `.obsidian/types.json` exists, import its `types` map once (**read-only** access to `.obsidian`), write `.tephra/types.json`.
   - `PropertyType typeFor(String key, Object? value)`: (1) registry entry by exact key, else by case-insensitive key; (2) built-ins: `tags` → `tags`, `aliases` → `aliases`, `cssclasses` → `multitext`; (3) from the vault index (`index.propertyKeys()` gives the most common `valueType` of the key); (4) inferred from `value`: `bool` → checkbox; `num` → number; `List` → multitext; `String` matching `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$` → datetime; matching `^\d{4}-\d{2}-\d{2}$` → date; anything else → text.
   - `Future<void> setType(String key, PropertyType t)`: updates the map, writes the file atomically (pretty-printed, 2-space indent; keys keep their order; unknown top-level keys and unknown type strings preserved) **only if the serialised text changed**.
   - Exposed through `propertyTypeRegistryProvider` (an `AsyncNotifierProvider`); the file is in the synced set of Phase 3.
3. `frontmatter_editor.dart` — pure functions on the note text (`\n`-normalised). Every function returns **one `TextEdit` against the whole note** (so the caller applies it with `EditorController.applyEdits` = one undo step) computed like this: locate the frontmatter with Phase 1's `splitFrontmatter(text)` (a closed block only; `null` = no frontmatter); take `contentStart = split.contentStart`, `yaml = split.yaml` (the body between the delimiters, last `\n` removed, so the body range is `[contentStart, contentStart + yaml.length)`); produce `newYaml`; the edit is the smallest single replacement between `yaml` and `newYaml` (strip the common prefix and the common suffix, then offset by `contentStart`). Returns `null` when nothing changes.
   ```dart
   abstract final class FrontmatterEditor {
     static Map<String, Object?> read(String text);                          // loadYaml → plain Dart maps/lists, insertion order of the source; {} when none
     static TextEdit? setValue(String text, String key, Object? value);      // add (appended at the end) or replace the value of an existing key
     static TextEdit? removeKey(String text, String key);
     static TextEdit? renameKey(String text, String oldKey, String newKey);  // throws PropertyKeyExistsException when newKey exists (case-insensitive)
     static TextEdit? moveKey(String text, String key, int newIndex);        // newIndex = position in the resulting key order
     static TextEdit? replaceRaw(String text, String newYaml);               // throws PropertiesYamlException(message, line) when newYaml is not valid YAML or not a map
   }
   ```
   - `setValue` / `removeKey`: `YamlEditor(yaml)` then `update([key], v)` / `remove([key])`. Values: `String`, `bool`, `int`, `double`, `null`, `List<Object?>` of those. A string that `yamlScalarForInsert` (step 02.21) would quote is passed as `wrapAsYamlNode(v, scalarStyle: ScalarStyle.DOUBLE_QUOTED)`. Keys are matched exactly first, then case-insensitively.
   - No frontmatter (text does not start with `---\n`) or an **empty** body (`---\n---`): `setValue` builds the block by hand instead of `YamlEditor` (it cannot edit an empty document): `key: scalar`, `key:\n  - a\n  - b` for lists (`key: []` for an empty list), `key:` for null; the edit inserts `---\n<block>\n---\n` at offset 0 (no frontmatter) or `<block>\n` after the first `---\n` (empty body).
   - `renameKey`: parse with `loadYamlNode(yaml)` (a `YamlMap`); find the entry whose key is `oldKey`; replace exactly the key scalar's source span (`node.span.start.offset`..`end.offset` of the key node) with the new key (written plain if it matches `^[A-Za-z0-9_][A-Za-z0-9_ .\-]*$` or contains only letters/digits of any script, else double-quoted). The value, inline comment and indentation stay byte-identical.
   - `moveKey`: from the `YamlMap` entry spans compute one **segment** per entry: it starts at the beginning of the first line of the contiguous full-line comments directly above the key (stopping at a blank line or at the previous entry's end), or at the key's line start, and ends where the next segment starts (the last one ends at the end of the YAML text). Text before the first segment is a fixed prefix. New YAML = prefix + segments in the new order, each segment made to end with `\n` (the original last segment's missing final newline is removed again at the very end). Verify with `loadYaml(newYaml)`: same keys and equal values; otherwise throw `StateError` (a bug, never write).
   - `replaceRaw`: `loadYaml(newYaml)` must give a map (or empty/null); errors → `PropertiesYamlException(error.message, error.span?.start.line ?? 0)`; the edit replaces the whole YAML body.
   `properties_exceptions.dart`: `PropertyKeyExistsException(key)` and `PropertiesYamlException(message, line)`, both `extends TephraException`.
4. `property_value_codec.dart`: `ConvertResult convert(Object? value, PropertyType to)` → `ConvertResult { Object? value; bool ok; }` used when the user changes a property's type: to `text` → scalar `toString()`, list → joined with `, `; to `multitext`/`aliases` → string split on `,` (trimmed, empty parts dropped), number/bool → one-item list; to `tags` → split on commas and whitespace, leading `#` removed, characters other than letters, digits, `_`, `-`, `/` removed, empty and all-digit items dropped; to `number` → `num.tryParse(trimmed)` (fail → `ok: false`, value unchanged); to `checkbox` → `true`/`yes` → true, `false`/`no` → false (case-insensitive; else `ok: false`); to `date` → first 10 characters of a date or datetime string that match `^\d{4}-\d{2}-\d{2}$` (else `ok: false`); to `datetime` → a date becomes `<date>T00:00` (else `ok: false`).
5. Panel (`properties_panel.dart`), shown **above the editor in the note screen** (not inside the editor text, so it is independent of the engine) when: the tab is in editing view, `editingMode == livePreview`, and `editor.propertiesInDocument == 'visible'`. Vault setting (nested JSON `editor`, registry `editor.propertiesInDocument`, default `"visible"`, values `visible`, `hidden`, `source`): `visible` = panel shown and the YAML lines hidden in Live Preview (`LpOptions.hideFrontmatter = true`); `hidden` = no panel and YAML hidden; `source` = no panel, YAML shown as text (`hideFrontmatter = false`). Source mode always shows the YAML as text and no panel. Reading view is unchanged from Phase 1.
   Layout: header row ("Properties", count, collapse chevron, "+ Add property" button); collapsed state is per tab (memory only, default expanded); body height at most 40 % of the pane height and scrolls internally. A note without frontmatter shows only the header with "+ Add property".
   Row: `[drag handle (desktop) | ⋮ menu button (phone, 48 dp)] [type icon — tap opens the type menu] [key field] [value widget]`. Source of truth: `FrontmatterEditor.read(controller.text)` re-read on every `controller.edits` event (debounced 150 ms) so the panel follows typing in the YAML source.
   Value widgets by `PropertyType`:
   - `text`: one-line `TextField`; commit on blur, Enter or the keyboard's Done; empty → `null`.
   - `multitext` and `aliases`: chips with an ✕, plus an input; Enter or `,` commits a chip, Backspace in the empty input removes the last chip; suggestions (max 8, `FuzzyScorer`) from `index.propertyValues(key)` for `multitext` (none for `aliases`). Each add/remove is one commit.
   - `tags`: chips shown as `#tag`; the input normalises (leading `#` removed, whitespace → `-`, characters other than letters/digits/`_`/`-`/`/` removed, empty or all-digit rejected with the error `propertiesInvalidTag`); suggestions from `tagListProvider` (step 02.21).
   - `number`: numeric `TextField`; valid input → `int` when integral else `double`; invalid → red border + `propertiesInvalidNumber`, no commit; empty → `null`.
   - `checkbox`: `Checkbox`, immediate commit with `true`/`false`.
   - `date`: a read-only field showing `YYYY-MM-DD` with a calendar button (`showDatePicker`) and a clear (✕) button; typing is allowed and validated against `^\d{4}-\d{2}-\d{2}$` plus a real calendar date.
   - `datetime`: like date, then `showTimePicker`; value written as `YYYY-MM-DDTHH:mm`.
   A list-valued property whose current value is a **string** (`tags: a, b`) is displayed split (tags: on commas/whitespace; others: on commas) and converted to a YAML list on its first edit. A value of an unexpected shape for its type (a map, or a list in a `number` property) is shown as read-only text with the message `propertiesUnsupportedValue` and cannot be edited in the panel (edit it in Source mode).
   Commits: every change → `edit = FrontmatterEditor.<op>(controller.text, …)`; `if (edit != null) controller.applyEdits([edit])` (one undo step per commit, so Ctrl+Z in the editor undoes the property change exactly).
   Row menu / context menu: "Remove property" (`removeKey`), "Move up", "Move down" (`moveKey`), "Change type" (submenu of the 8 types; applies `convert` and, if `ok`, a `setValue` commit, then `registry.setType`; if `!ok` the registry is still updated and a snackbar `propertiesConvertFailed` says the value was kept), "Edit as YAML". Desktop: drag handle reorders (`ReorderableListView`, one `moveKey` commit on drop).
   Key field: commit on blur/Enter → `renameKey`; an existing key → error text `propertiesKeyExists` and the field reverts. "+ Add property": a new row with the key field focused and a suggestion list from `propertyKeysProvider` (step 02.21) excluding keys already in the note; committing a key → type = `registry.typeFor(key, null)`; the initial value written is `null` for text/number/date/datetime, `false` for checkbox, `[]` for multitext/aliases/tags (whatever `YamlEditor` writes for these is accepted — tests compare parsed values, not bytes, for these additions).
6. Invalid YAML: `parsed.frontmatterValid == false` while a frontmatter block exists → the panel shows a banner (`propertiesInvalidYaml`) and `RawYamlEditor` (a monospace multi-line `TextField`, ≥ 6 lines, initial text = the YAML body) with buttons "Apply" (`replaceRaw` → `applyEdits`; on `PropertiesYamlException` show its message and `line + 1` under the field and keep the field) and "Revert". Structured rows are not shown while invalid. The same editor opens for a valid note from the row menu "Edit as YAML" (and from the header menu).
7. l10n keys: `propertiesTitle`, `propertiesAdd`, `propertiesRemove`, `propertiesMoveUp`, `propertiesMoveDown`, `propertiesChangeType`, `propertiesEditAsYaml`, `propertiesKeyExists`, `propertiesInvalidTag`, `propertiesInvalidNumber`, `propertiesInvalidYaml`, `propertiesApply`, `propertiesRevert`, `propertiesConvertFailed`, `propertiesUnsupportedValue`, `propertyType<Text|Multitext|Number|Checkbox|Date|Datetime|Aliases|Tags>` (8), `settingEditorPropertiesInDocument`.

**Tests**
- `frontmatter_editor_test.dart` — base note `B`:
  ```
  ---
  title: My note # keep
  tags:
    - a
    - b

  # comment before status
  status: draft
  ---
  Body
  ```
  (1) `setValue(B,'status','done')` → the `status` line becomes `status: done` and **every other line is byte-identical**. (2) `setValue(B,'tags',['a','b','c'])` → `read` gives `tags == [a,b,c]`; the `title`, comment and `status` lines are identical; the `Body` line is identical. (3) `removeKey(B,'title')` → the title line is gone, all other lines identical. (4) `renameKey(B,'status','state')` → `state: draft`; the comment line above is identical; `renameKey(B,'status','title')` throws `PropertyKeyExistsException`; `renameKey(B,'Status','state')` (different case) works.
  (5) `moveKey(B,'status',0)` → `read` key order `status, title, tags`; the comment line moved together with `status`; the multiset of lines of the YAML is unchanged. (6) no frontmatter: `setValue('Body\n','a','x')` → `'---\na: x\n---\nBody\n'`; `setValue('Body\n','a',['x','y'])` → `'---\na:\n  - x\n  - y\n---\nBody\n'`. (7) empty block: `setValue('---\n---\nBody','a',1)` → `'---\na: 1\n---\nBody'`.
  (8) `setValue(B,'status','a: b')` → `status: "a: b"` parsed back as the string `a: b`. (9) `setValue(B,'n',3)` then `read(...)['n'] == 3` (int); `setValue(...,'checked',true)` → bool; Bangla key and value: `setValue(B,'শিরোনাম','বাংলা')` round-trips. (10) `replaceRaw(B,'a: [')` throws `PropertiesYamlException` with `line == 0`; `replaceRaw(B,'- x')` (a list, not a map) throws; `replaceRaw(B,'a: 1')` returns an edit that yields `---\na: 1\n---\nBody`. (11) CRLF is not tested here (text is normalised before the editor).
  If any assertion "every other line is byte-identical" fails because of `yaml_edit` behaviour, **do not patch around it by hand**: write the case and the observed output into `PROGRESS.md` under "yaml_edit limits", keep the test with the observed behaviour only if the difference is confined to the edited entry itself, and tell the human in the phase report.
- `property_type_registry_test.dart`: `.obsidian/types.json` `{"types":{"due":"date"}}` imported once into `.tephra/types.json` and `.obsidian` is never written; precedence registry > built-in > index > inference; `typeFor('x', true)` = checkbox, `typeFor('x', 2)` = number, `typeFor('x', ['a'])` = multitext, `typeFor('x', '2026-10-11')` = date, `typeFor('x', '2026-10-11T09:30')` = datetime, `typeFor('tags', 'a')` = tags; `setType` twice with the same value writes once; unknown top-level key `"extra": 1` preserved; broken JSON → backup file created on the first change.
- `property_value_codec_test.dart`: `convert('a, b', multitext)` = `['a','b']`; `convert('#x y', tags)` = `['x','y']`; `convert('12', number)` = 12; `convert('abc', number).ok == false`; `convert('yes', checkbox)` = true; `convert('2026-10-11T09:30', date)` = `'2026-10-11'`; `convert('2026-10-11', datetime)` = `'2026-10-11T00:00'`; `convert(['a','b'], text)` = `'a, b'`.
- `properties_panel_test.dart` (fake `EditorController`, widget test): one row per key in order; `tags: [x]` renders chip `#x`; checkbox toggle → one `applyEdits` call whose edit turns `done: false` into `done: true`; text field edit then blur → exactly one commit; invalid number shows the error and makes no commit; key rename to an existing key shows `propertiesKeyExists` and reverts; "Remove property" → one commit; at 1200 dp drag handles exist, at 400 dp a ⋮ button with 48 dp height exists; `editor.propertiesInDocument = 'source'` → no panel; Source mode → no panel; invalid YAML → banner + raw editor, Apply with `a: [` shows the error with line 1 and no edit.
- `raw_yaml_editor_test.dart`: Apply with valid text → one `applyEdits`; Revert restores the original text.
- Undo check (controller-level): apply a `setValue` edit, then the controller's undo restores the exact original note text.

**Verify:** `flutter test` in `app/`. Manual (both platforms): open a note with `tags`, `aliases`, a date, a checkbox and a number → each shows its widget; edit each; open the file in Obsidian → properties show the same values and the YAML formatting of untouched properties (comments, quotes, order) is unchanged; break the YAML in Source mode → Live Preview shows the banner and the raw editor; fix it → rows return. Commit `phase 02.26: add properties editor with yaml_edit and type registry`.

**Pitfalls**
- Never rewrite the whole frontmatter with `jsonEncode`/`toYaml`; only the minimal edit from `FrontmatterEditor` may touch the note.
- `loadYaml` converts dates like `2026-10-11` to **strings** (the `yaml` package does not resolve timestamps) — do not treat them as `DateTime`.
- A key containing `: ` or starting with a special character must be double-quoted when renamed; the rename helper handles it, do not build keys by string concatenation elsewhere.
- Obsidian keeps `tags` and `aliases` as lists; never write them as a comma string.

---

### 02.27 Daily notes, templates and the unique note creator

**Purpose:** Obsidian-compatible daily notes (format, folder, template, open on startup, previous/next), template insertion (`{{title}}`, `{{date}}`, `{{time}}` and their `:FORMAT` forms) and the unique note creator. The Android launcher shortcut and the ribbon button come in Phases 4 and 7.

**Files** (new, `app/lib/vault/note_tools/`)
- `daily_notes_service.dart`, `template_service.dart`, `unique_note_service.dart`, `template_picker.dart`, `note_tools_commands.dart`, `note_tools_settings.dart`, `providers.dart`
- vault settings model/store (add groups below), `.obsidian` importer (add keys), settings screen sections "Daily notes", "Templates", "Unique note creator", l10n
- tests: `app/test/vault/note_tools/daily_notes_service_test.dart`, `template_service_test.dart`, `unique_note_service_test.dart`, `note_tools_settings_test.dart`, `template_picker_test.dart`

**Implementation**
1. Settings (vault, `.tephra/settings.json`, nested objects; unknown keys preserved; the registry names in the first column are what Phase 7 lists):
   | Registry name | JSON path | Type | Default |
   |---|---|---|---|
   | `dailyNotes.format` | `dailyNotes.format` | Moment format string | `YYYY-MM-DD` |
   | `dailyNotes.folder` | `dailyNotes.folder` | vault-relative folder, `''` = vault root | `''` |
   | `dailyNotes.template` | `dailyNotes.template` | vault path of a template note (with or without `.md`), `''` = none | `''` |
   | `dailyNotes.openOnStartup` | `dailyNotes.openOnStartup` | bool | `false` |
   | `templates.folder` | `templates.folder` (added in step 02.22) | folder holding template notes, `''` = not configured | `''` |
   | `templates.dateFormat` / `templates.timeFormat` | `templates.dateFormat` / `templates.timeFormat` (02.22) | Moment format | `YYYY-MM-DD` / `HH:mm` |
   | `uniqueNote.prefixFormat` | `uniqueNote.prefixFormat` | Moment format used as the file name | `YYYYMMDDHHmm` |
   | `uniqueNote.folder` | `uniqueNote.folder` | folder, `''` = the Phase 1 "new note location" rule | `''` |
   | `uniqueNote.template` | `uniqueNote.template` | template note path, `''` = none | `''` |
   | `corePlugins.dailyNotes` | `corePlugins.dailyNotes` | bool | `true` |
   | `corePlugins.templates` | `corePlugins.templates` | bool | `true` |
   | `corePlugins.uniqueNoteCreator` | `corePlugins.uniqueNoteCreator` | bool | `false` |
   An empty `format` string in the file (Obsidian writes `""` for "default") is read as the default. The commands of this step are unavailable (`isAvailable` false, hidden from the palette) while their `corePlugins.*` switch is off; each settings section starts with that switch (Phase 7 later moves the switches to its Core plugins screen).
   `.obsidian` import (read-only, once, only for keys absent in `.tephra/settings.json`): `.obsidian/daily-notes.json` (`folder`, `format`, `template`, `autorun` → `openOnStartup`), `.obsidian/templates.json` (`folder`, `dateFormat`, `timeFormat`), `.obsidian/zk-prefixer.json` (`format` → `prefixFormat`, `folder`, `template`). If Phase 1's importer already maps the first two, only add the third and verify the key names with a test.
   Settings screen: each format field shows the live preview `formatMoment(clock.now(), format)` under the field and the validation error text (`validateMomentFormat(forFileName: true, requireDate: true)` for the daily format; `forFileName: true` for the unique-note format; plain `validateMomentFormat` for the template date/time formats); an invalid value is not saved. Folder and template fields have a text input and a picker button (the quick switcher in folder / file pick mode).
2. `DailyNotesService` (provided by `dailyNotesServiceProvider`):
   ```dart
   VaultPath pathFor(DateTime date);                                   // dailyNotePath(date, folder, format)
   DateTime? dateOfPath(VaultPath p);                                  // null when p is outside the folder or does not match the format
   Future<VaultPath> openOrCreate(DateTime date, {bool newTab = false});
   Future<VaultPath?> neighbour(VaultPath? from, {required bool previous});
   ```
   `dateOfPath`: `rel = p.value` with the folder prefix and `/` removed (the note must be inside the folder), `.md` removed, then `parseMoment(rel, format)` (formats with `/` subfolders match the whole relative path).
   `openOrCreate(date)`:
   1. Validate the daily format (`validateMomentFormat(forFileName: true, requireDate: true)`); on error throw `DailyNotesConfigException` → the command shows snackbar `dailyFormatInvalid` with an "Open settings" action.
   2. `path = pathFor(date)`. If `fs.stat(path) != null` → open it (focus its tab if already open; else current tab, or a new tab when `newTab`) and return. **No write happens.**
   3. Otherwise build the content: template path `t` = `dailyNotes.template`; if non-empty try `VaultPath(t)`, then `VaultPath('$t.md')` when `t` has no extension, then `index.resolveLink(t, from: path)`; read it with `fs.readText` (a `malformed` template counts as missing). Text = `applyTemplate(templateText, TemplateContext(title: path.stem, date: date, now: clock.now(), dateFormat: templates.dateFormat, timeFormat: templates.timeFormat))`. Missing/unreadable template → empty text and snackbar `dailyTemplateMissing`.
   4. Re-`stat(path)` immediately before writing; if it now exists (created meanwhile) open it and stop. Else `fs.writeText(path, TextDocument(text: text))` (parent folders are created by the file system; line ending `\n`, no BOM) and open it in the tab's `defaultEditingMode`.
   `neighbour(from, previous)`: `current = from == null ? today : dateOfPath(from) ?? today`; candidates = every file of `index.allFiles()` whose `dateOfPath` is non-null (cached by `dailyNoteListProvider`, refreshed on `indexChangesProvider`); previous = the latest date `< current` (date part only), next = the earliest `> current`; none → `null` → snackbar `dailyNoNeighbour`.
   Commands: `daily-notes.open-today` ("Open today's daily note"), `daily-notes.open-previous` ("Open previous daily note"), `daily-notes.open-next` ("Open next daily note"); no default shortcuts; palette on; `showInMobileToolbar: false`. "Today" is computed from `Clock.now()` each time the command runs (midnight rollover).
   Startup: `dailyStartupProvider` runs once per vault session after the workspace layout has been restored: if `corePlugins.dailyNotes` and `dailyNotes.openOnStartup` → `openOrCreate(today)` (an already restored tab of today's note is simply focused). It never runs again on vault re-focus or index refresh.
3. `TemplateService`:
   - `Future<List<VaultPath>> templateFiles()`: all `.md` files within `templates.folder` (recursive, from `index.allFiles()`), sorted by path; `templates.folder == ''` → throws `TemplatesNotConfiguredException` (snackbar `templatesFolderNotSet` with an "Open settings" action).
   - Command `templates.insert-template` ("Insert template", palette, no default shortcut; also reachable from the slash menu item of step 02.22): opens `TemplatePicker` (a list with `FuzzyScorer` filtering by file stem; phone: full-screen route with 48 dp rows; desktop: a centred dialog; Enter/tap selects) and then `insertTemplate(controller, templatePath)`.
   - `insertTemplate`: `raw = await fs.readText(templatePath)` (malformed → snackbar `templateUnreadable`, stop); `processed = applyTemplate(raw.text, TemplateContext(title: controller.path.stem, date: now, now: now, …settings))`. Split `processed` with `frontmatterRange`:
     - template **without** frontmatter → one `TextEdit(caret, selectionEnd, processed)`, caret placed after the inserted text.
     - template **with** frontmatter: `bodyText` = text after its closing `---` line. Properties are merged into the note: for each key of the template's YAML (`FrontmatterEditor.read`): key absent in the note → `setValue`; key present and both values are lists → union keeping the note's order, template items appended when not already present (case-sensitive); key present otherwise → the note's value is kept. The property edits are computed one after another on the evolving text and combined into one edit against the original note. `bodyText` is inserted at `max(caret, end of the note's frontmatter block)` (the body is never inserted inside the frontmatter). If the note had no frontmatter the new block goes to offset 0.
     - All edits go in **one** `controller.applyEdits` call (one undo step); two edits that start at the same offset (new block at 0 and body at 0) are merged into one edit (block first).
4. `UniqueNoteService.create()` (command `unique-note.create`, label "Create unique note", palette, no default shortcut, available only when `corePlugins.uniqueNoteCreator` is on):
   1. Validate `prefixFormat` (`forFileName: true`); `base = formatMoment(clock.now(), prefixFormat)`.
   2. Folder = `uniqueNote.folder`, or when empty the same rule as `LinkNavigator` uses for new notes (Phase 1 setting: vault root / folder of the active note / configured folder).
   3. `name = base`; while `fs.stat(folder/name.md) != null` → `name = '$base-$n'` with `n = 2, 3, …`.
   4. Content: `uniqueNote.template` processed like the daily template with `title: name`, `date: now`; empty when no template. `fs.writeText`, open in a new tab if the current tab has unsaved changes else in the current tab (Phase 1 open API decides), default editing mode.
5. l10n keys: `commandOpenToday`, `commandOpenPreviousDaily`, `commandOpenNextDaily`, `commandInsertTemplate`, `commandCreateUniqueNote`, `dailyFormatInvalid`, `dailyTemplateMissing`, `dailyNoNeighbour`, `templatesFolderNotSet`, `templateUnreadable`, `settingsDailyNotes`, `settingsTemplates`, `settingsUniqueNote`, `settingDailyFormat`, `settingDailyFolder`, `settingDailyTemplate`, `settingDailyOpenOnStartup`, `settingTemplatesFolder`, `settingTemplatesDateFormat`, `settingTemplatesTimeFormat`, `settingUniquePrefix`, `settingFormatPreview`, `openSettings`.

**Tests**
- `daily_notes_service_test.dart` (`MemoryVaultFileSystem`, fixed `Clock` = 2026-10-11 14:05:09, in-process index; settings folder `Daily`, format `YYYY-MM-DD`, template `Templates/Daily` whose text is `# {{date:dddd, MMMM Do YYYY}}\nTime: {{time}}\nTitle: {{title}}\n`):
  `openOrCreate(2026-10-11)` creates `Daily/2026-10-11.md` with text `# Sunday, October 11th 2026\nTime: 14:05\nTitle: 2026-10-11\n` and opens it (fake workspace); a second call performs **0** writes (counting fs) and opens it; template missing → empty file + `dailyTemplateMissing`; `openOrCreate(2026-10-09)` → `{{date}}`-style variables use that date (`# Friday, October 9th 2026`), `Time: 14:05`; format `YYYY/MM/YYYY-MM-DD`, folder `''` → path `2026/10/2026-10-11.md`; invalid format `HH:mm` → `DailyNotesConfigException`; race: a fake fs that creates the file between the first and the second `stat` → no write, note opened.
  `dateOfPath`: `Daily/2026-10-11.md` → `DateTime(2026,10,11)`; `Other/2026-10-11.md` → null; `Daily/notes.md` → null. `neighbour` with files `Daily/2026-10-09.md`, `2026-10-10.md`, `2026-10-12.md`, `notes.md`: from `2026-10-11` (a date with no file) → previous `2026-10-10`, next `2026-10-12`; from `2026-10-12` next → null; `from == null` → relative to today.
  Startup: `openOnStartup: true` → today's note opened once; a second trigger does nothing; setting off → nothing; `corePlugins.dailyNotes: false` → nothing.
- `template_service_test.dart`: picker lists only `Templates/*.md`; unconfigured folder → exception; note `Note.md` with text `Hello\n`, caret 5, template `Body {{title}}` → text `HelloBody Note\n` (title = the note's stem `Note`) in one `applyEdits` call; template `---\ntags: [t]\n---\nBody` into `Note.md` without frontmatter (text `Hello\n`), caret 5 → `read` of the result gives `{tags: [t]}`, the text after the closing `---` line is `HelloBody\n`, one `applyEdits` call with two edits (offsets 0 and 5, both in old-text coordinates); note `---\ntags: [a]\nstatus: x\n---\nText` + template `---\ntags: [b, a]\nstatus: y\nnew: 1\n---\nT\n` → result keys `tags == [a, b]`, `status == x`, `new == 1`, and the text after the closing `---` line is `T\nText` (the body is inserted after the frontmatter even when the caret was inside the frontmatter); malformed template → `templateUnreadable`, no edit.
- `unique_note_service_test.dart`: `202610111405.md` created in the configured folder; a second call within the same minute → `202610111405-2.md`, third → `-3`; template `# {{title}}` → `# 202610111405`; `prefixFormat` `YYYY/MM` is accepted (a `/` creates a subfolder) and creates `2026/10.md`; `prefixFormat` `HH:mm` → `forbiddenCharacter` error, nothing created; switch `corePlugins.uniqueNoteCreator` off → the command is unavailable.
- `note_tools_settings_test.dart`: defaults for missing keys; JSON round-trip preserves unknown keys; `.obsidian/daily-notes.json` `{"folder":"Journal","format":"","template":"Templates/Daily","autorun":true}` imports to folder `Journal`, format default, template `Templates/Daily`, `openOnStartup` true; existing Tephra values are not overwritten by the import; `.obsidian` is never written; `.obsidian/zk-prefixer.json` `{"format":"YYYYMMDD","folder":"Z","template":""}` imports.
- `template_picker_test.dart`: typing filters by fuzzy stem; Enter selects; at 400 dp rows are 48 dp.

**Verify:** `flutter test` in `app/`. Manual (both platforms): set daily folder `Daily` and a template with `{{date:dddd}}`; run "Open today's daily note" → created from the template and opened; run it again → opens the same note, file untouched (check the modified time in the explorer); previous/next navigation among 3 existing daily notes; "Insert template" in a normal note; enable the unique note creator, run it twice within a minute → two files. Open the vault in Obsidian → the daily note and its template output are identical to what Obsidian would create for the same settings. Commit `phase 02.27: add daily notes, templates and unique note creator`.

**Pitfalls**
- The daily note is created **only** when the command runs (or on startup if enabled) — never by opening the app with the setting off, and never overwritten.
- `{{date}}` in a daily-note template is the note's date, not today's (the context has separate `date` and `now`); `{{time}}` is always the current time.
- `Do`, `dddd` and month names are English only in Phase 2 (`en` locale); other locales come with Phase 7 localisation.

---

### 02.28 Web preview guard, performance harness, bench vault with demo pack, recorded budgets

**Purpose:** (a) keep the Dev Launcher web preview compiling now that the index uses SQLite through FFI; (b) measure every conventions §10 budget on the 10,000-note bench vault in `--profile` builds and record the numbers; (c) extend Phase 0's bench generator with the demo notes the Demo script needs. The Rebuild-index command already exists (step 02.9) and is only *used* here.

**Files**
- `packages/tephra_index/lib/src/db/open_index_database.dart` (becomes a conditional export), `open_index_database_native.dart`, `open_index_database_stub.dart` (new)
- `app/lib/vault/index_session.dart` (web guard), `app/lib/core/isolate_utils.dart` (new or reuse Phase 1's helper), index-driven panes (empty state), `app/lib/l10n/app_en.arb` (`indexUnavailableOnWeb`, `commandRunBenchmarks`)
- `tool/src/bench_generator.dart` (add `demoPack`), `tool/gen_bench_vault.dart` (flag `--demo`), `tool/test/bench_generator_test.dart` (add tests)
- `app/lib/core/perf/perf_probe.dart`, `perf_stats.dart`, `perf_scenarios.dart`, `perf_runner.dart`, `perf_command.dart` (new); `app/lib/main.dart` (one line: `PerfProbe.markAppStart();` as the first statement of `main`); the editor widget (one line: `PerfProbe.mark('editable')` in the post-frame callback after the controller attaches)
- `tool/perf_report.dart`, `tool/test/perf_report_test.dart` (new)
- tests: `app/test/core/perf/perf_stats_test.dart`, `perf_probe_test.dart`

**Implementation**
1. **Web preview guard** (Phase 3's prerequisite list expects "the same web stub"; steps 02.2 and 02.9 did not add it, so do it now):
   1. In `packages/tephra_index`, confine every `dart:ffi`-dependent import (`package:drift/native.dart`, `package:sqlite3/sqlite3.dart`, `dart:io` file handling) to `open_index_database_native.dart`, which holds the current bodies of `openIndexDatabase`, `openMemoryIndexDatabase`, `openReaderIndexDatabase`. `open_index_database_stub.dart` exports the same three functions and the class `OpenedIndexDatabase`, each function throwing `UnsupportedError('The index is not available on this platform')`.
      `open_index_database.dart` contains only: `export 'open_index_database_native.dart' if (dart.library.js_interop) 'open_index_database_stub.dart';`. Nothing else under `lib/` may import `drift/native.dart` or `sqlite3` (grep: `git grep -n "drift/native\|package:sqlite3" packages/tephra_index/lib` → only `open_index_database_native.dart`). `dart:isolate` stays allowed (it compiles on web; spawning throws at runtime and is never reached).
   2. `NoteIndexNotifier.build()` (step 02.9): `if (kIsWeb) throw const IndexUnavailableException()` (new `class IndexUnavailableException extends TephraException` in `index_exceptions.dart`, message `index unavailable on web`). Every pane that reads the index (backlinks, outgoing links, tags, search, quick switcher, bookmarks resolution, daily-note neighbours, autocomplete) must treat an `AsyncError(IndexUnavailableException)` as an **empty state** showing `indexUnavailableOnWeb` ("Search and links are not available in the web preview.") — never an error screen. Editing, reading, Live Preview, properties, folding, slash commands and templates (which need no index) keep working on web.
   3. Every `Isolate.run` added by Phase 2 **app** code (rename planner, unlinked mentions, search verification, embed parse, `LivePreviewEngine.setText` for long notes, block candidates of other notes) goes through one helper: `Future<T> runInIsolate<T>(FutureOr<T> Function() f)` in `app/lib/core/isolate_utils.dart` = `kIsWeb ? Future.sync(f) : Isolate.run(f)` (reuse Phase 1's equivalent if `git grep -n "kIsWeb" app/lib/reading` shows one; do not keep two). Replace the direct `Isolate.run` calls.
   4. Check: `cd app; flutter build web` succeeds; `dart run tool/dev.dart` starts and prints `Local:` and `Network:` lines (conventions §11); open the page in a browser → the app shell loads, indexed panes show the web empty state.
2. **Demo pack for the bench generator** (additive; default off, so existing output and tests are unchanged): `BenchOptions.demoPack` (`bool`, default `false`) and `BenchOptions.hugeNoteSource` (`String?`, default `null`). After **all** other files are written, and **without drawing from the random generator**, `generateBenchVault` with `demoPack: true` writes (UTF-8, LF):
   - `Demo/Quokka Hub.md`: `---\ntags: [project]\n---\n# Quokka Hub\nThe target note of the demo.\n`
   - `Demo/Linker 1.md`, `Demo/Linker 2.md`, `Demo/Linker 3.md`: `See [[Quokka Hub]] for details.\n`
   - `Demo/Mention 1.md`: `Ideas about the quokka hub for later.\n`; `Demo/Mention 2.md`: `Quokka Hub is only a placeholder name in this note.\n`
   - `Demo/Report Task.md`: `---\ntags: [project]\n---\n# Report Task\n- [ ] write the quarterly report\n- [x] file the old report\n`
   - `Templates/Daily.md`: `# {{date:dddd, MMMM Do YYYY}}\n\n## Tasks\n- [ ] \n\n## Notes\nCreated at {{time}}\n`
   - `Huge-5000-lines.md` at the vault root: a byte copy of `hugeNoteSource` when it is non-null and exists (the CLI passes `<repoRoot>/test_vaults/edge/huge-5000-lines.md`), otherwise 5,000 generated lines `Line N: the quick brown fox jumps over the lazy dog.` with a heading `## Section K` every 100 lines.
   `BenchReport` gets `demoNotes` (int, 0 without the pack). CLI flag `--demo` sets `demoPack: true`; the printed report mentions it. The word `quokka` is not in the generator's word pools; the test below proves the phrase `quokka hub` occurs in no other bench note.
3. **Bench generator tests** (add to `tool/test/bench_generator_test.dart`): `demo pack off by default` (count 200: no `Demo/` folder, output identical to a run created before this change — compare with `same seed gives identical output`); `demo pack writes the notes` (all files above exist, `Templates/Daily.md` contains `{{date:`); `quokka hub appears only in the demo notes` (count 2,000, seed 42, demo on: scan every `.md`; the case-insensitive phrase `quokka hub` occurs in exactly six files — `Demo/Quokka Hub.md` itself (its heading), `Linker 1`, `Linker 2`, `Linker 3`, `Mention 1`, `Mention 2` — and in no other note); `huge note copied` (temp source file → identical bytes).
4. **`PerfProbe`** (`app/lib/core/perf/perf_probe.dart`; `const bool.fromEnvironment('TEPHRA_PERF')` gates everything; without the define every method is a no-op and the benchmark command is not registered):
   ```dart
   abstract final class PerfProbe {
     static bool get enabled;                      // bool.fromEnvironment('TEPHRA_PERF')
     static void markAppStart();                   // starts one Stopwatch (first call only)
     static void mark(String name);                // first call per name: record(name, elapsed ms since app start, 'ms')
     static Future<T> measure<T>(String name, Future<T> Function() body);   // Stopwatch around body → record(name, ms, 'ms')
     static void record(String name, double value, String unit);            // keeps it in results and prints one line: PERF <name> <value> <unit>
     static List<PerfResult> get results;
     static void installLogBridge();               // listens to Logger.root.onRecord; every record whose message starts with 'perf ' is re-recorded (see below)
   }
   ```
   Every printed line has exactly the form `PERF <name> <value> <unit>` (value with at most 3 decimals, unit `ms`, `MB`, `fps` or `bytes`). `installLogBridge` is called from the bootstrap when `enabled` (set `Logger.root.level = Level.ALL`): the earlier steps log `perf switcher <ms>` and `perf autocomplete <ms>` (and `perf index ...`) at `fine` level; the bridge turns `perf <name> <number>` into `PERF <name> <number> ms`.
   `perf_stats.dart`: `double percentile(List<double> values, double p)` (nearest-rank on a sorted copy: `values.sorted[ceil(p/100 × n) − 1]`), `FrameStats frameStats(List<FrameTiming>)` returning count, p50, p90, p95, p99, max and `over16` (frames whose `max(buildDuration, rasterDuration)` > 16.0 ms), as in the Phase 0 editor spike.
5. **Scenarios** (`perf_scenarios.dart`; run by `perf_runner.dart`; started from the command `dev.run-benchmarks`, label `commandRunBenchmarks`, no shortcut, registered only when `PerfProbe.enabled`). The runner shows a dialog with the numbers when done and prints all `PERF` lines. Each scenario states the exact metric name it records:
   | # | Scenario | How it is measured | Records |
   |---|---|---|---|
   | S1 | Cold start → editable note | `markAppStart` at the start of `main`; `mark('editable')` when the restored tab's editor has attached and a frame has been drawn. Procedure: run S2 once; open 5 notes including `Huge-5000-lines`; quit; relaunch 5 times; median of the 5 | `editable` (ms) — budget Android < 2,500, Windows < 1,500 |
   | S2 | First full index of the 10k vault, UI usable | Close the app, delete `<appSupportDir>/index/<vaultId>.sqlite*`, launch, `PerfProbe.measure('index.full', () => index.rebuild())`. In parallel scroll the explorer from top to bottom over 5 s and collect `FrameTiming`s | `index.full` (ms) — budget Android < 60,000, Windows < 20,000; `ui.index.frame.p95` ≤ 16.0 and `ui.index.frame.max` < 100 (UI usable) |
   | S3 | Typing latency, 5,000-line note | Open `Huge-5000-lines.md`, caret at the start of line 2,500; for mode in Source, Live Preview: insert 500 characters (`'The quick brown fox jumps over the lazy dog. '` cycled) **one per frame** through `controller.applyEdits`, collecting `FrameTiming`s as in the Phase 0 spike; also read `LivePreviewEngine.lastStats.microseconds` per keystroke | `typing.source.p95`, `typing.lp.p95` (ms of `max(build, raster)`) — budget < 16.0 each; `lp.applyEdit.median` ≤ 6 ms (internal target of step 02.23) |
   | S4 | Plain-text search, 10k notes | 3 warm-up + 20 measured runs per query with `SearchEngine.run`: common queries `report`, `meeting notes`, `"project alpha"`; rare queries `quokka`, `"quarterly report"`. `first` = time until 20 results (or stream end) ; `total` = stream completion | `search.first.p95` (all five queries) — budget < 200; `search.total.p95` for the rare queries (≤ 200 matches) — budget < 200; `search.total.p95` of the common queries is recorded for information |
   | S5 | Quick switcher | 50 random 1–6 character queries taken from note titles, ranking time as logged by step 02.19 (`perf switcher`) | `switcher.p95` — budget < 50 ms; `autocomplete.p95` (step 02.20 log, `[[` + 1 character) ≤ 16 ms (internal) |
   | S6 | Memory | After S2 finished, open 5 notes (incl. the huge one), wait 60 s, read `ProcessInfo.currentRss` and `maxRss` (`dart:io`; 1 MB = 1,048,576 bytes) | `memory.rss` (MB) — budget Android < 350, Windows < 500; `memory.maxRss` recorded. Android cross-check (information only): `adb shell dumpsys meminfo com.tephra.app` TOTAL PSS |
   | S7 | Release APK size | `cd app; flutter build apk --release --split-per-abi` (debug signing is fine); sizes of the three APKs, e.g. `Get-Item build\app\outputs\flutter-apk\app-*-release.apk \| Select-Object Name, Length` | `apk.arm64`, `apk.armv7`, `apk.x64` (bytes) — budget each < 40,000,000 bytes |
   S1, S6 and S7 are driven by hand (their numbers come from the printed lines or the commands above); S2–S5 run inside `dev.run-benchmarks`. All numbers in the table of sub-step 7 must come from `--profile` builds on a real device or the Windows laptop; emulator or debug numbers are marked "not valid for the gate" (as in Phase 0).
6. `tool/perf_report.dart`: `dart run tool/perf_report.dart <log-file> [<log-file> ...] [--platform windows|android]` reads console logs (any line containing `PERF <name> <value> <unit>`), takes the **median** value per metric when it occurs several times, compares with the budget map below and prints a Markdown table `| metric | budget | value | result |` (result `PASS`, `FAIL`, or `info` for metrics without a budget) plus a final line `RESULT: all budgets met` or `RESULT: <n> budget(s) missed`; exit code 0/1. Budget map (constants in the tool): `editable` 1500 (windows) / 2500 (android); `index.full` 20000 / 60000; `ui.index.frame.p95` 16.0; `ui.index.frame.max` 100; `typing.source.p95` 16.0; `typing.lp.p95` 16.0; `search.first.p95` 200; `search.total.p95` 200 (rare queries only — the log names them `search.total.rare.p95`); `switcher.p95` 50; `memory.rss` 500 / 350; `apk.arm64`, `apk.armv7`, `apk.x64` 40,000,000. Capture logs with: `flutter run --profile -d windows --dart-define=TEPHRA_PERF=true | Tee-Object -FilePath perf-windows.log` (PowerShell) and the same with `-d <android-id>` and `perf-android.log`.
   `perf_report_test.dart`: a sample log with two `editable` lines (1,300 and 1,500; the median of an even count is the mean of the two middle values) → 1,400 → `PASS` on Windows (a metric passes when `value < budget`, strictly); the same value is `PASS` on Android; `editable 1500` alone on Windows → `FAIL`; `index.full 25000` on Windows → `FAIL` and exit code 1; unknown metrics → `info`; lines without `PERF` ignored.
7. **Record the numbers** in `PROGRESS.md` under "Phase 2 performance" using this table (one row per metric and platform; copy the report output; add device model, OS version, build mode `profile`, date):
   | Metric | Budget | Windows | Android | Device / notes |
   |---|---|---|---|---|
   | Cold start → editable | < 1.5 s / < 2.5 s | … | … | … |
   | … (one row for each metric listed in sub-step 5) | | | | |
   Also copy into `PROGRESS.md`: the index fuzz run time (step 02.8), the 500-note rename time (02.11), `perf switcher` and `perf autocomplete` numbers, `LivePreviewEngine` equivalence/perf numbers (02.23), and the Phase 0 typing p95 for comparison.
8. **If a budget is missed**, work through this list in order, re-measuring after each item (and note what you changed in `PROGRESS.md`): (1) confirm `--profile` (not debug) and, for Android, a real device; (2) for typing: check `buildLpLine` is not recomputing decorations (sub-step 3 pitfall of 02.24), that reveal changes do not repaint every line, and that the decorator reads only the cache; (3) for index time: raise `IndexOptions.batchSize` (200 → 500), ensure all inserts of a batch run in **one** transaction, ensure `PRAGMA synchronous = NORMAL` and WAL are active, and that FTS inserts happen after the batch's table inserts; (4) for search: check the trigram stage returns candidates (`exact` flag) and that verification batches are read from the open-buffer cache; (5) for memory: dispose per-tab providers, avoid holding all note texts (the autocomplete and switcher caches hold only names/headings); (6) for APK size: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols` and remove unused fonts/assets.
   If a budget is still missed by **more than 25 %** after these attempts, stop and ask the human (GEMINI.md §5); if the miss is within 25 %, write it in `PROGRESS.md` with the numbers and ask the human whether to accept it.

**Tests**
- `perf_stats_test.dart`: `percentile([1..100], 95) == 95`; `percentile([5], 99) == 5`; `percentile([], 50)` throws `ArgumentError`; `frameStats` over 4 fake timings counts the one over 16.0 ms.
- `perf_probe_test.dart`: with `enabled == false` (the test default) `record` stores nothing and prints nothing; the log bridge test calls the bridge's static parser directly: `'perf switcher 12'` → `('switcher', 12.0, 'ms')`, `'perf x'` → null.
- `perf_report_test.dart` and the bench generator tests above.
- `index_database_stub_test.dart` (in `packages/tephra_index/test/db/`): importing the stub library directly and calling `openIndexDatabase('x')` throws `UnsupportedError`.

**Verify**
```
cd tool; dart test
cd packages/tephra_index; dart test
cd app; flutter test; flutter build web
dart run tool/gen_bench_vault.dart --clean --demo
```
The last command prints 10,000 generated notes plus the demo pack (`demoNotes: 7` = the seven files under `Demo/`: `Quokka Hub`, `Linker 1–3`, `Mention 1–2`, `Report Task`) and finishes in < 60 s; `(Get-ChildItem test_vaults\bench -Recurse -File -Filter *.md).Count` prints **10009** (10,000 + 7 + `Templates/Daily.md` + `Huge-5000-lines.md`).
Then run S1–S7 on Windows and on a real Android phone, produce the report with `tool/perf_report.dart`, paste the table into `PROGRESS.md`. Commit `phase 02.28: add web guard, perf harness, bench demo pack and recorded budgets`.

**Pitfalls**
- `BenchReport.demoNotes` counts exactly the 7 files under `Demo/`; `Templates/Daily.md` and `Huge-5000-lines.md` are written by the pack but are not counted in `demoNotes`. Make the generator, its report and the test agree on these numbers.
- Never measure in debug mode; never compare Windows numbers with Android budgets.
- The perf scenarios must not run in release builds (the define is absent → the command is not registered).
- Do not leave `Logger.root.level = Level.ALL` outside perf mode; it floods the log.

---

## Demo script

Run it at the end of the phase, **on both Windows and a real Android phone**, in `--profile` builds. Record pass/fail and observed numbers in `PROGRESS.md`. If any "expected" result does not happen, the phase is not done.

0. **Prepare the bench vault.** On Windows: `dart run tool/gen_bench_vault.dart --clean --demo` (10,000 generated notes + the `Demo/` notes, `Templates/Daily.md` and `Huge-5000-lines.md`). For Android copy it to the phone: `adb push test_vaults\bench /sdcard/Documents/TephraBench` (takes several minutes), and make sure Tephra has "All files access" (Phase 1 permission flow).
1. **Open the 10k vault and index while working.** Launch Tephra (`flutter run --profile -d windows`, and `--profile -d <android-id>`), choose the bench folder as vault. *Expected:* the explorer and the last/new note are usable immediately; the desktop status bar shows "Indexing {done} / {total}" (phone: a thin progress bar under the app bar); while it runs open `Demo/Quokka Hub`, type a sentence and scroll the explorer — no visible stutter; indexing ends in **< 20 s on Windows, < 60 s on Android** and the indicator disappears. Restart the app → no full re-index (the indicator is gone within 2 s).
2. **Search.** Open the search pane (desktop sidebar / phone full screen) and enter `tag:#project task-todo:report`. *Expected:* results appear in < 200 ms; `Demo/Report Task` is among them (shown with its matching line `- [ ] write the quarterly report`); the closed task line `- [x] file the old report` does not count. Tap the result → the note opens with the matching line highlighted/selected.
3. **Backlinks.** Open `Demo/Quokka Hub`; open the Backlinks pane (desktop right sidebar / phone right drawer). *Expected:* "Linked mentions" shows **3** entries (Linker 1, 2, 3) each with its context line `See [[Quokka Hub]] for details.`; expand "Unlinked mentions" → **2** entries (Mention 1 with `quokka hub`, Mention 2 with `Quokka Hub`).
4. **Link an unlinked mention.** Tap "Link" on Mention 1. *Expected:* within 1 s linked mentions show 4, unlinked 1; the file `Demo/Mention 1.md` now reads `Ideas about the [[Quokka Hub|quokka hub]] for later.`
5. **Rename and undo.** Rename `Quokka Hub` to `Quokka Base` in the explorer. *Expected:* a toast "Updated 4 links in 4 files" with an Undo action; opening Linker 1 shows `See [[Quokka Base]] for details.` and Mention 1 shows `[[Quokka Base|quokka hub]]`. Tap Undo → the file is `Quokka Hub` again and all four notes read as before (byte-identical). Rename again to `Quokka Base` and keep it.
6. **New note in Live Preview.** Create the note `Demo/Live Test` (explorer or command). *Expected:* it opens in Live Preview (the default mode). Type `# Live Preview test` and Enter, then `**bold**` followed by a space and more text: the `**` markers disappear when the caret leaves them and reappear when it returns.
   - **Autocomplete:** type `See [[Quokka` → a list appears with `Quokka Base` first; press Tab (phone: tap the `#` button on the row) → the text becomes `[[Quokka Base#` and the note's headings are listed; choose `Quokka Hub` → `[[Quokka Base#Quokka Hub]]`. Type `[[Quokka Base#^` → blocks are listed; pick the paragraph → ` ^xxxxxx` was appended to that paragraph in `Quokka Base.md` and the link reads `[[Quokka Base#^xxxxxx]]`.
   - **Callout:** on a new line type `/tip`, choose "Callout: Tip" (it is the first row), type `Remember this` → the callout renders with an icon header and tint (or the documented styled-source fallback for engines without inline widgets).
   - **Property:** in the Properties panel above the note tap "+ Add property", type `status` (suggested from the vault), pick it, set the value `draft`; add `tags` and a chip `demo`. Press Ctrl+Shift+E (Android: overflow menu "Source mode") → the YAML at the top reads `status: draft` and a `tags` list containing `demo`; Ctrl+Z (Android: undo button) removes the last property change as **one** step; Ctrl+Shift+E back to Live Preview.
7. **Daily note from a template.** Settings → Daily notes: folder `Daily`, template `Templates/Daily`, format `YYYY-MM-DD`. Run "Open today's daily note" from the command palette. *Expected:* `Daily/<today>.md` is created with the first line `# <weekday>, <Month> <day>th <year>` (for example `# Sunday, October 11th 2026`), a `## Tasks` section and `Created at HH:mm`; run the command again → the same note opens, **no** new file and the modified time did not change.
8. **Restart persistence.** Fold a heading in `Huge-5000-lines`, close the app and reopen: tabs, each tab's mode and the fold are restored.
9. **Obsidian check (Windows).** Open the bench vault folder in Obsidian: `Demo/Live Test`, the renamed `Quokka Base` and `Daily/<today>` open normally; the links and properties are intact; Obsidian reports no errors.
10. **Phone-only checks.** The autocomplete list and the slash menu sit above the keyboard toolbar and rows are tappable (48 dp); the Properties rows have a ⋮ menu; the outline pane (right drawer) jumps to a heading; page preview opens on long-press of a link.

---

## Exit gate

Tick each item in `PROGRESS.md` (copy this list there) only when it is true; write the number or the command output next to it.

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

---

## Hand-off to the next phase

What Phase 3 (sync) and later phases rely on from Phase 2 — do not change these without asking the human:

1. **The index is a rebuildable local cache and is never synced.** It lives in `<appSupportDir>/index/<vaultId>.sqlite` (outside the vault). `TephraIndexDatabase.parserVersion` / `schemaVersion` mismatches rebuild it automatically. A vault that has just been downloaded by sync is indexed by `NoteIndex.reconcile()` (mtime + size + hash fast path).
2. **Index freshness after sync writes.** Writes made through the app's `vaultFsProvider` (the `IndexingVaultFileSystem` wrapper of step 02.9) are reported to the index automatically. Phase 3 writes files from a **sync worker isolate with its own `VaultFileSystem` instance**; those writes are seen by the UI isolate's watcher as external changes (self-write suppression is per instance) and reach `index.onChange`. To be certain, Phase 3 must call `noteIndex.reconcile()` on the UI isolate after every sync run that wrote, moved or deleted files (it is cheap when nothing changed). Sync never imports `tephra_index` (package rule, conventions §3).
3. **Link rewriting is local.** Renames/moves inside Tephra rewrite links as ordinary file edits (`LinkRenameService`); sync sees them as normal content edits and renames. The undo stack (`vaultUndoStackProvider`) is in memory only and is not synced.
4. **`.tephra/` files Phase 2 writes** (all inside the Phase 3 synced set, conventions §6.6): `settings.json` (new nested groups `templates`, `dailyNotes`, `uniqueNote`, `corePlugins`, `editor`), `bookmarks.json` (Obsidian structure, unknown keys preserved), `types.json` (`{ "types": {…} }`, unknown keys preserved), `workspace.json` (top-level keys are device ids; Phase 2 only ever modifies the **current device's** entry: tab `"mode"` and `"folds"`). All writers pretty-print with stable key order, preserve unknown keys, and write only when the serialised text changed — this keeps three-way JSON merges clean. `.tephra/cache/` is unused by Phase 2.
5. **Daily-note recognition** (`DailyNotesService.dateOfPath`) matches the whole relative path against the configured format, so Phase 3 conflict copies (`… (conflict …)`) are ignored by previous/next navigation and never mistaken for daily notes.
6. **Shared pure code for later phases:** `formatMoment`, `parseMoment`, `validateMomentFormat`, `applyTemplate`, `TemplateContext`, `dailyNotePath` in `tephra_core` (Phase 4's headless quick-note writers must use `dailyNotePath` and `formatMoment`; `applyTemplate` is available too); `FrontmatterEditor` (`app/lib/properties/`) for any phase that edits properties (stickies, Bases, import); `LinkFormatter`, `RenamePlanner`, `LinkResolver`, `NameTable` in `tephra_index`; `FuzzyScorer` in `tephra_search`; `SearchParser`/`SearchEngine` (Phase 6 Bases and Phase 8 AI reuse them).
7. **Editor seams later phases may use:** `EditorController` members `applyEdits`, `select`, `revealOffset`, `caretRectGlobal`, `setKeyInterceptor`, `setDecorator`, `setTapInterceptor`, `rectForRange`, `composing`, `selectionChanges`; `EditorDecorator`; `EditingMode`; `LivePreviewEngine` (pure, sendable decorations). Phase 7 (vim, multi-cursor, spell-check) plugs into the same controller; hide/reveal is offset-preserving, so any feature that works on buffer offsets keeps working in Live Preview.
8. **Settings registry names introduced here** (for the Phase 7 registry): `editor.defaultEditingMode`, `editor.foldHeadings`, `editor.foldIndent`, `editor.propertiesInDocument`, `templates.folder`, `templates.dateFormat`, `templates.timeFormat`, `dailyNotes.format`, `dailyNotes.folder`, `dailyNotes.template`, `dailyNotes.openOnStartup`, `uniqueNote.prefixFormat`, `uniqueNote.folder`, `uniqueNote.template`, `corePlugins.dailyNotes`, `corePlugins.templates`, `corePlugins.uniqueNoteCreator`, `corePlugins.slashCommands`; from earlier steps: `newLinkFormat`, `useMarkdownLinks`, `alwaysUpdateLinks`, `excludedFolders` (JSON keys as written in step 02.9; Phase 7 maps them to `links.*`/`files.*` names) and the two app-level page-preview switches `pagePreviewReadingRequiresCtrl`, `pagePreviewEditorRequiresCtrl` (Phase 7's single `pagePreview.requireCtrl` needs a mapping decision there).
9. **Perf harness:** `TEPHRA_PERF` + `dev.run-benchmarks` + `tool/perf_report.dart` + the bench vault with `--demo` stay in the repo; every later phase re-runs them for its own exit gate ("Phase 2 budgets still hold").
10. **Web preview:** the index is unavailable on web by design (`IndexUnavailableException`); Phase 3 follows the same pattern (no worker on web, status "not available in the web preview").
11. **Known limits carried forward** (also in `PROGRESS.md`): audio/video/PDF embeds are file chips until Phase 6.5; math is shown as TeX source until Phase 6.4; English-only date names; unlinked-mention search and property editing of non-map/odd YAML are intentionally conservative; Live Preview widget coverage depends on the engine decision (see `PROGRESS.md`).
