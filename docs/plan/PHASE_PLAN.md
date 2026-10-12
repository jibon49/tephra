# Phase-by-Phase Implementation Plan — Tephra (Android + Windows)

Companion to [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md), which describes *what* we build (features, file format,
architecture). This document describes *how and in what order*, one phase at a time.

## How every phase runs

1. **Start gate** — the previous phase's exit gate is fully green. No phase starts on top of known broken work.
2. **Build in the listed step order.** Steps are ordered by dependency; each step ends in something that runs.
3. **Every step is "done" only when:**
   - it works on **both** an Android phone and Windows (checked by hand, not just compiled);
   - unit/widget tests for it are written and passing in CI;
   - `flutter analyze` is clean; no new warnings;
   - it doesn't break round-trip compatibility (the fixture vaults still save byte-for-byte unchanged);
   - user-facing text is in the localisation file (English first, ready for translation, e.g. Bangla).
4. **Phase demo** — run the phase's demo script on a real Android device and a Windows PC with a real vault.
5. **Exit gate** — every acceptance criterion is checked. Performance budgets met. Then tag a build
   (`v0.<phase>.0`), write short release notes, and install it on your own phone and PC for daily use before the next phase.
6. **Phase review** — 30 minutes: what slipped, what to change in the next phase's plan. Update this file.

Sizes assume one full-time developer. Each phase has ~15% buffer built in; if a phase overruns by more than
its buffer, we cut scope (moved to a later phase) rather than lower the quality bar.

### Overview

| # | Phase | Weeks | Result |
|---|---|---|---|
| 0 | Foundation | 2 | Tooling, CI, editor decision |
| 1 | Vault, files & basic editor | 5 | Open a vault, browse, edit and save notes on both devices |
| 2 | Links, index, search, Live Preview | 5 | **MVP** — daily-usable with an existing Obsidian vault |
| 3 | Sync & backup via Google Drive | 5 | **Beta**: one vault on phone and PC, encrypted, versioned |
| 4 | Sticky notes & quick capture | 3 | Floating stickies (PC), widgets & bubbles (Android) |
| 5 | Import & export | 3 | Move in from other apps; PDF/HTML/DOCX/zip out |
| 6 | Visual views | 6 | Graph, Canvas, Bases, slides, media, math, Mermaid |
| 7 | Remaining parity & polish | 4 | Everything else Obsidian's core has |
| 8 | Advanced extras | 8 | AI, semantic search, tasks, Kanban, OCR, voice, sketching, encryption |
| 9 | Release hardening | 3 | **v1.0** as direct-download APK + Windows `.exe` |
| 10 | Tephra Cloud: our own online backup & sync | 6 | **v2.0**: hosted backup/sync service (also self-hostable) |
| 11 | Ecosystem | later | Play Store + Microsoft Store, collaboration, web clipper, plugin API, iOS/macOS |

Total to v1.0: **~44 weeks**; v2.0 (own hosted backup) about 6 weeks after that.

### Performance budgets (checked at every exit gate from Phase 2 on)

Measured on a mid-range Android phone (e.g. 6 GB RAM, 2022 chipset) and a normal Windows laptop, with the 10k-note benchmark vault.

| Metric | Budget |
|---|---|
| Cold start to editable note (after first index) | Android < 2.5 s, Windows < 1.5 s |
| First full index of 10k notes | < 60 s Android, < 20 s Windows, in background, UI usable |
| Typing latency (5,000-line note) | < 16 ms per keystroke (no dropped frames) |
| Search results (10k notes, plain text) | < 200 ms |
| Quick switcher results | < 50 ms |
| Memory (10k-note vault open) | < 350 MB Android, < 500 MB Windows |
| Release APK size | < 40 MB |

---

## Phase 0 — Foundation (2 weeks)

**Goal:** a working project skeleton that builds for Android and Windows in CI, plus an informed decision on the
editor (the biggest technical risk) before any feature work.

**Prerequisites:** decisions in IMPLEMENTATION_PLAN §14 answered (at least the app name).

### Steps

**0.1 Machine setup**
- Install Flutter SDK (stable), Android Studio + Android SDK + an emulator, Visual Studio 2022 "Desktop development with C++" workload.
- `flutter doctor` fully green. Connect a real Android phone (USB or wireless debugging).

**0.2 Monorepo skeleton**
- `git init`, `.gitignore`, melos workspace: `app/`, `packages/tephra_core/` (shared models), empty `tephra_markdown`,
  `tephra_vault`, `tephra_index`, `tephra_search`, `tephra_sync`, `tephra_io`.
- Shared `analysis_options.yaml` (strict lints: `strict-casts`, `strict-raw-types`, `very_good_analysis` or similar).
- App: `flutter create --platforms=android,windows,web app`. Package id `com.tephra.app` (permanent once released, so confirm before the first public APK).
- Riverpod set up, app shell with a placeholder screen, light/dark theme from one `ThemeData` source.
- Localisation scaffold (`flutter_localizations`, `intl`, ARB files).
- Logging (`logging` package) to stdout + rotating file in the app data folder; crash catcher (`FlutterError.onError`, zone).

**0.3 CI**
- Private GitHub repository + GitHub Actions: `melos run analyze`, `melos run test`, build debug APK, build Windows release; upload artefacts.
  Private repos get limited free Actions minutes (Windows runners count double), so heavy jobs (Windows build, nightly fuzz tests)
  run on push to `main` / nightly only, or on a self-hosted runner on this PC.
- **Licence check** job: lists every Dart/Flutter dependency's licence and fails on anything outside the allowed list
  (MIT, BSD, Apache-2.0, zlib, MPL-2.0). Generates `THIRD_PARTY_NOTICES.md`.
- Secrets (keystore, OAuth IDs) only in CI secrets and a git-ignored `secrets/` folder; a secret-scan step blocks accidental commits.
- Fails on any analyzer warning or test failure.

**0.4 Test vaults**
- `test_vaults/syntax/` — one note per Obsidian syntax element (wikilinks, embeds, callouts, math, footnotes, tables, block IDs, comments, highlights, tags, frontmatter of every property type, nested lists, code blocks, HTML).
- `test_vaults/real/` — a copy of a real Obsidian vault (yours, or the public Obsidian Help vault).
- `test_vaults/bench/` — a generator script producing 10k notes with realistic links, tags, attachments.
- `test_vaults/edge/` — Unicode/Bangla file names, emoji, very long lines, 5,000-line note, CRLF line endings, BOM, empty files, deeply nested folders.

**0.5 Editor spike (the key decision)**
Build three throwaway prototypes, each opening the 5,000-line note:
- A: `re_editor` with custom span styling and syntax-hiding on non-cursor lines.
- B: `TextField` + custom `TextEditingController.buildTextSpan` (simplest, limited).
- C: a minimal custom `RenderObject` editor (most control, most work).
Measure on the real phone and Windows: typing latency, scrolling fps, cursor/selection correctness, IME behaviour
(Android Gboard incl. Bangla input, Windows IME), hardware keyboard, undo/redo, inline widget placement (an image and a checkbox).

**0.6 Platform spikes**
- drift + FTS5 working on Android and Windows (insert 10k rows, search).
- Android: request "All files access", read/write a file in `Documents/TestVault`, watch it for changes.
- Windows: file watcher on a folder; tray icon; second window (`desktop_multi_window`) — needed later for stickies.

**0.7 Dev Launcher**
- README with `## Install` and `## Run`; web dev-preview run command on port 8093; register via the launcher API; confirm logs appear.

### Deliverables
- Repo with skeleton, CI green, test vaults, spike report (`docs/spikes/editor.md`) with measurements and the chosen editor approach.

### Exit gate
- [ ] CI builds APK + Windows build on every push.
- [ ] Placeholder app runs on the real phone, the emulator and Windows.
- [ ] Editor approach chosen with numbers to back it; chosen prototype meets the 16 ms typing budget on the phone.
- [ ] FTS5 search on 10k rows < 50 ms on the phone.
- [ ] Shared-folder read/write/watch works on Android.
- [ ] Project registered and starting in Dev Launcher.

---

## Phase 1 — Vault, files & basic editor (5 weeks)

**Goal:** open an existing Obsidian vault (or create one) on both devices, browse it, read notes properly rendered,
and edit/save in Source mode without ever damaging a file.

### Steps

**1.1 Vault layer (`tephra_vault`)**
- `VaultFileSystem` interface: list, read bytes/text, write (atomic: write temp → rename), create, rename, move, delete-to-trash, stat, watch.
- Implementations: `IoVaultFileSystem` (Windows + Android shared storage), `SafVaultFileSystem` fallback for Android without "All files access".
- Text decoding preserves BOM and line endings (LF/CRLF) exactly; writing a file back without edits produces identical bytes.
- Ignore rules: `.obsidian/`, `.tephra/`, `.trash/`, `.git/`, user "excluded files" setting.
- Trash behaviour matching Obsidian options: system trash, vault `.trash/`, or permanent delete.
- External change detection via watcher; debounced events; self-write suppression (don't react to our own saves).

**1.2 Vault manager & settings**
- Vault picker screen: open folder, create new vault, recent vaults list, vault switcher.
- Android permission flow with clear explanation screen; fallback path explained.
- Settings storage: app-level (JSON in app data) and vault-level (`.tephra/*.json`).
- `.obsidian` importer for settings we understand (attachment folder, new-note location, daily notes, templates, hotkeys, bookmarks) — read-only.

**1.3 Markdown parser (`tephra_markdown`)**
- Build on `markdown` package; add custom syntaxes: wikilinks + aliases + heading/block targets, embeds with size/page params,
  tags (incl. nested, Unicode, not inside code/URLs), `==highlight==`, `%%comment%%` (inline + block), block IDs `^id`,
  callouts (type, title, fold), inline + block math, footnotes (ref + inline), task lists with custom statuses (`[/]`, `[-]`, `[>]`…).
- Frontmatter extraction with exact source ranges (so the editor can edit it without touching the rest).
- Output: AST with **source offsets on every node** (needed later for Live Preview, outline, block refs).
- Parse in an isolate for large notes.
- Tests: one test per syntax element against `test_vaults/syntax`, plus tricky cases (tags inside code, links in tables, nested callouts).

**1.4 Reading view**
- AST → Flutter widgets: headings, paragraphs, lists, tasks (tappable, writes back to the file), tables (horizontal scroll),
  code blocks with syntax highlighting, callouts (icons, colours, fold), blockquotes, images (local attachments), horizontal rules,
  highlights, footnotes section, internal links (tap to open), external links.
- Text selection and copy. Readable line width setting.
- Lazy rendering (`ListView.builder` per block) so long notes scroll smoothly.

**1.5 Editor — Source mode**
- Using the editor approach chosen in Phase 0: Markdown syntax highlighting, line wrapping, undo/redo, find & replace in note.
- Editing helpers: auto-pair `[]()**` etc., smart list continuation on Enter, Tab/Shift+Tab indent, toggle bold/italic/code/link, move line up/down, duplicate line.
- Autosave (debounced ~1 s after typing stops + on blur/app pause) using atomic writes; "saved" indicator.
- Conflict on external change while editing: if no local unsaved edits, reload silently; otherwise merge or show a choice.

**1.6 File explorer**
- Tree with lazy folder expansion, file icons by type, sort options (name, modified, created; asc/desc), collapse all.
- Create note/folder, rename (inline), move (drag-and-drop on PC, "Move to…" picker on Android), delete, reveal in system explorer (Windows), duplicate.
- Rename **does not yet update links** (that needs the index — Phase 2); show a notice.

**1.7 Workspace & layout**
- Adaptive shell: width ≥ 840 dp → PC layout (left sidebar, tabs, right sidebar, status bar); otherwise phone layout (single pane, swipe drawers, bottom toolbar).
- Tabs on PC (open, close, reorder, middle-click close, Ctrl+Tab), back/forward history per tab (both platforms).
- Split pane (vertical/horizontal) on PC, resizable.
- Phone: keyboard toolbar (bold, italic, list, task, link, heading, undo/redo, indent, hide keyboard).

**1.8 Commands, quick switcher, palette**
- Command registry (id, name, icon, default hotkey, availability check, handler).
- Command palette (Ctrl+P / toolbar button) with fuzzy matching; recent commands first.
- Quick switcher (Ctrl+O) over file names — simple file list for now; index-based in Phase 2. Create note from switcher if not found.
- Hotkey settings screen (PC), with conflict detection; Obsidian hotkeys imported.

**1.9 Attachments**
- Paste/drag-drop images into the editor (PC), pick photo/camera/file (Android); saved to the configured attachment folder with Obsidian-style naming (`Pasted image 20261011093000.png`); inserts `![[...]]`.

### Tests
- Round-trip: open + save every file in all test vaults → bytes identical.
- Parser unit tests (~200 cases). Widget tests for reading view of every syntax note (golden images).
- File system tests: atomic write survives a simulated crash mid-write; rename/move/delete; watcher events.
- Editor tests: list continuation, auto-pair, undo stack, IME composition does not lose text.

### Demo script
Open your real vault on the phone and the PC → browse folders → open a long note in reading view → switch to edit →
add a task list, a callout and a pasted image → close app → reopen → content intact → open the same vault in Obsidian → identical.

### Exit gate
- [ ] All demo steps pass on Android and Windows.
- [ ] Round-trip test: 0 changed bytes across all test vaults.
- [ ] Every syntax element renders correctly in reading view (golden tests).
- [ ] Typing budget met in Source mode on the 5,000-line note on the phone.
- [ ] Obsidian edits to an open note are picked up within 1 s.
- [ ] No data loss when the app is killed during typing (tested 20 times).

---

## Phase 2 — Links, index, search & Live Preview → MVP (5 weeks)

**Goal:** the "second brain" core: everything is linked, findable and fast, and editing feels like Obsidian.
After this phase you should be able to use Tephra instead of Obsidian every day.

### Steps

**2.1 Index (`tephra_index`)**
- drift schema: `files`, `notes`, `aliases`, `headings`, `blocks`, `links`, `tags`, `properties`, `tasks`, `fts_notes` (FTS5, Unicode tokenizer — check Bangla works).
- Indexer runs in a background isolate: initial full index with progress bar; incremental updates from the watcher and from our own saves.
- Startup reconciliation by mtime + size + hash; index can be deleted and rebuilt at any time ("Rebuild index" command).
- Schema versioning + migrations.

**2.2 Link resolution & link maintenance**
- Resolver with Obsidian's rules: exact path → shortest unique name → aliases, case-insensitive; unresolved links tracked.
- Settings: link format (shortest / relative / absolute), wikilinks vs Markdown links — matching Obsidian's options.
- **Rename/move updates every link** in the vault (wikilinks, Markdown links, embeds, heading/block refs), as one undoable operation, with a summary toast.
- Clicking an unresolved link creates the note (in the configured folder).

**2.3 Linking UI**
- Backlinks panel (linked + unlinked mentions, with context snippet; "Link" button on unlinked mentions).
- Outgoing links panel; outline panel (headings, click to jump, drag to reorder sections on PC); tags pane (nested tree with counts).
- Bookmarks (files, folders, headings, searches, groups) — stored compatible with Obsidian's `bookmarks.json` structure in `.tephra/`.
- Page preview: hover (PC, Ctrl-hover option) / long-press (Android) on a link shows a scrollable preview popup.
- Embeds/transclusion in reading view: `![[Note]]`, `![[Note#Heading]]`, `![[Note#^block]]`, images with size, audio/video players; recursion guard.

**2.4 Autocomplete in the editor**
- `[[` → note names (fuzzy, by recent + relevance) → `#` heading → `^` block (creates a block ID when picking a block that has none) → `|` alias.
- `#` → tags. Frontmatter keys/values from existing properties.
- Slash commands (`/`) inserting headings, callouts, tables, templates, dates.

**2.5 Search (`tephra_search`)**
- Query parser for full Obsidian syntax: words, quotes, `OR`, `-`, parentheses, `file:`, `path:`, `tag:`, `line:()`, `block:()`, `section:()`,
  `task:`, `task-todo:`, `task-done:`, `[prop]`, `[prop:value]`, `match-case:`, `ignore-case:`, `/regex/`.
- Compiles to FTS5 + SQL; line/section/regex filters run in an isolate on the candidate set.
- Search panel: results grouped by file with highlighted matches, collapse/expand, sort options, "copy results"; search history.
- In-note highlights when opening a result. Embedded ` ```query ` blocks in reading view.
- Quick switcher upgraded to the index: names + aliases + headings (`#` mode).

**2.6 Live Preview mode**
- Using the Phase 0 approach: syntax markers hidden except on the line/selection being edited; headings sized; bold/italic/strike/highlight styled;
  links shown as link text; checkboxes clickable; images, embeds, math and callouts rendered as inline blocks that turn back into source when the cursor enters them.
- Mode toggle per tab (Ctrl+E), default mode setting.
- Folding of headings and list items in the editor.

**2.7 Properties editor**
- Visual property block above the note: typed inputs (text, list chips, number, checkbox, date, datetime), add/remove/rename, property type registry shared across vault (Obsidian `types.json` compatible).
- Edits go through `yaml_edit` so untouched YAML keeps its formatting.

**2.8 Daily notes & templates**
- Daily notes: open today (ribbon/command/Android shortcut), date format, folder, template; previous/next day navigation.
- Templates: insert from folder; variables `{{title}}`, `{{date[:format]}}`, `{{time[:format]}}`.
- Unique note creator (Zettelkasten prefix).

### Tests
- Link resolver test matrix (duplicates names in different folders, aliases, case, unicode).
- Rename test: rename a note linked from 500 notes → every link updated, round-trip of all other bytes unchanged.
- Search: a test per operator + combinations; compare result sets with Obsidian on the real vault for 30 sample queries.
- Index consistency fuzz test: random create/edit/rename/delete sequences → index equals a fresh rebuild.
- Live Preview: cursor movement, selection across hidden markers, IME composition in hidden regions.

### Demo script
Open the 10k bench vault → index finishes in budget while you keep working → search `tag:#project task-todo:report` →
open a result → backlinks show 3 linked and 2 unlinked mentions → link one → rename the note → all links updated →
write a new note in Live Preview with `[[` autocomplete, a callout and a property → open today's daily note from a template.

### Exit gate (MVP)
- [ ] Demo passes on both devices.
- [ ] Search results match Obsidian on the 30 sample queries.
- [ ] Index fuzz test: 10,000 random operations, 0 differences from rebuild.
- [ ] All performance budgets met.
- [ ] You've used it as your main notes app for 1 week with no data loss and no blocking bug.

---

## Phase 3 — Sync & backup via Google Drive (5 weeks)

**Goal:** the same vault on phone and PC, kept in sync through the user's own Google Drive, end-to-end encrypted, with version history and
scheduled backups. **Rule for this phase: no code path may lose user data, ever.**

### Steps

**3.1 Sync core (`tephra_sync`) — pure Dart, no network yet**
- Data model: local state DB (path → hash, size, mtime, synced-version), base copies of synced Markdown text, device ID, change journal.
- Planner: given local / base / remote states → list of actions (upload, download, merge, conflict-copy, delete, rename).
- Three-way Markdown merge (diff-match-patch on lines), conflict-copy naming `Note (conflict YYYY-MM-DD HH-mm DeviceName).md`.
- Rename detection by hash; folder ops; case-only renames (Windows is case-insensitive, Android isn't) handled safely.
- Deletes go to remote history first; local deletes go to trash. Large-delete safety: if a sync would delete > 20% of files or > 50 files, stop and ask.
- **In-memory provider** for testing; multi-device simulator.

**3.2 Encryption**
- Vault password → Argon2id (tuned so it takes ~0.5 s on the phone) → master key; per-file keys derived with HKDF; AES-256-GCM; encrypted file names (random remote IDs).
- Key stored in Android Keystore / Windows Credential Manager via `flutter_secure_storage`.
- Recovery key (shown once, printable) + password change without re-uploading all files (re-wrap the master key).
- Encryption is on by default; can be turned off per vault (then the notes are readable as normal files in Drive).

**3.3 Google Drive provider**
- Provider interface (list, get, put, delete, changes-since, quota). The sync core only talks to this interface, so the
  Tephra Cloud server in Phase 10 plugs in later **without changing the sync core or the remote data format**.
- Sign-in: Android via `google_sign_in` + Drive authorization; Windows via the browser loopback flow with PKCE (desktop OAuth client).
  Tokens in secure storage; silent refresh; clear "reconnect" prompt if access is revoked.
- Scope `drive.file` (the app only sees files it created). This is a non-sensitive scope, so no costly Google security
  assessment is needed; until the consent screen is verified, up to 100 test users can sign in, enough for early direct-download users.
- Remote layout in a visible `Tephra/<vault name>/` folder: content-addressed encrypted blobs + **one append-only journal per device**.
  No file is ever written by two devices, which avoids the race conditions Drive can't prevent on its own (no reliable compare-and-swap).
  Each device reads the other devices' journals to rebuild the remote state; journals are compacted into periodic snapshots.
- Detecting remote changes: Drive Changes API (`changes.list` with a saved page token): every ~30 s while the app is open,
  on app resume, and in background jobs. Expected phone-to-PC delay: under a minute.
- Resumable uploads for big attachments, exponential backoff on 403/429 rate limits, quota check with a warning before Drive is full.
- Contract test suite for the provider (nightly CI job against a dedicated test Google account) + fault injection.

**3.4 Sync runtime**
- Triggers: save (debounced), app start/resume, Drive change polling (~30 s while open), every N minutes in background, manual "Sync now".
- Android: WorkManager periodic background sync; Wi-Fi-only / charging-only options; respects Doze.
- Windows: tray icon shows status; sync keeps running while the main window is closed (optional setting).
- Selective sync: exclude folders, file types, size limit (e.g. skip videos on mobile mode).
- Offline queue; resume interrupted transfers; bandwidth limit option.

**3.5 Sync UI**
- Setup wizard: sign in with Google → choose/create the remote vault → set password → first sync (upload or download/merge) with clear progress.
- Status bar / app bar indicator; sync log screen (human-readable); conflict list with side-by-side diff and "keep mine / keep theirs / keep both / merge manually".
- Device list (name, last seen); remove a device.

**3.6 Version history**
- Per-note history from remote history + local snapshots (`.tephra/history`, every N minutes while editing).
- History screen: timeline, diff view (inline + side-by-side on PC), restore whole version or copy a part.

**3.7 Backup mode**
- Scheduled encrypted snapshots, content-addressed chunks (only changed chunks upload), retention rules (hourly × 48, daily × 30, monthly × 12 — configurable).
- Stored in a separate `Tephra/<vault>/backups/` area of the same Drive, independent from live sync (a sync mistake can't damage backups).
- "Backup only" mode for users with a single device (no live sync, just scheduled backups).
- Restore: single file, folder, or whole vault at a point in time — into the vault or into a new folder.
- Backup verification job (download + decrypt a random sample weekly; report).

### Tests
- Simulator fuzz test: 3 devices, 100k random operations including offline periods, concurrent edits, renames, deletes, crashes mid-sync →
  assert: no content ever lost (every version exists in vault, conflict copy or history), all devices converge.
- Crypto tests with known vectors; wrong-password and tampered-file detection.
- Provider contract tests; network fault injection (timeouts, 429, 500, partial uploads, revoked token, Drive full).
- Real-device test: phone in airplane mode edits for a day, PC edits same notes, reconnect → expected merges.

### Demo script
Sign in with Google on the PC → create the remote vault with a password → sign in with the same Google account on the phone, enter the password → first sync downloads the vault → turn on daily backup → edit note on phone offline, edit a different
paragraph of the same note on PC → reconnect → merged cleanly → edit the same line on both → conflict shown, resolved → delete a note → restore it from history →
restore yesterday's whole vault from backup to a new folder.

### Exit gate (Beta)
- [ ] Fuzz test: 100k operations, 0 lost content, convergence every run (run nightly for a week).
- [ ] Demo passes on a real phone and PC with a real Google account.
- [ ] A save on one device appears on the other within 60 s when both apps are open.
- [ ] Sync recovers by itself after: network loss mid-upload, Drive rate limiting, expired token, Drive storage full (with a clear warning).
- [ ] Android background sync works with the app closed for 24 h (battery usage < 2%/day for a normal vault).
- [ ] Remote storage contains no readable note text or file names when encryption is on (checked by downloading the Drive folder).
- [ ] Beta build installed on your phone + PC and used daily for 2 weeks.

---

## Phase 4 — Sticky notes & quick capture (3 weeks)

**Goal:** stickies that feel native on each device, built on normal Markdown notes so they sync for free.

### Steps

**4.1 Sticky model**
- Frontmatter keys (`tephra-sticky`, `sticky-color`, `sticky-pinned`, `sticky-remind`, `sticky-expire`, `sticky-locked`); per-device position stored in `.tephra/stickies.json` (positions differ by screen, so they are not synced into the note).
- Commands: New sticky, Pin note as sticky, Unpin, Change colour, Lock; default `Stickies/` folder.
- Index query: all stickies, by colour/tag.

**4.2 Sticky board (both platforms)**
- Endless board of coloured cards (zoom/pan), drag to arrange, group by colour/tag, quick inline edit, create by double-click/tap.
- Saved as a `.canvas` file, so it opens in Obsidian Canvas too.

**4.3 Windows floating stickies**
- Each sticky in its own small frameless window (`desktop_multi_window`), always-on-top toggle, resize, collapse to title, colour menu.
- Remembers position per monitor; restores all stickies at login (optional "start with Windows").
- Global hotkey (default `Ctrl+Alt+N`) creates a sticky from anywhere; tray menu: new sticky, show/hide all.
- Edits in a sticky window and the main window stay in step (shared index/vault service, single writer).

**4.4 Android stickies**
- Home-screen widgets: single sticky (resizable) and a sticky stack; tap opens the editor; checkbox tap toggles directly in the widget.
- Floating bubbles over other apps (opt-in, "draw over other apps" permission): tap to expand a small editor, drag to dismiss.
- Quick-add tile in the notification shade and a persistent "quick note" notification option.

**4.5 Reminders & capture**
- Reminder notifications for `sticky-remind` (and later tasks): exact alarms on Android (permission flow), Windows toast notifications.
- Share-to-Tephra on Android (text, links, images, files → new note or append to daily note).
- Quick capture widget and app shortcut ("New note", "Today's note", "New sticky").
- Auto-archive expired stickies.

### Tests
- Sticky round-trip: frontmatter added/removed without touching note body bytes.
- Multi-window consistency test on Windows (edit in sticky + main window simultaneously).
- Widget update test on Android after sync changes a sticky remotely.

### Demo script
PC: Ctrl+Alt+N anywhere → write sticky → pin on top → set reminder in 2 min → toast appears → sync → phone widget shows it →
tick a checkbox in the widget → PC sticky updates → share a web link from Chrome on Android to Tephra → appears in daily note.

### Exit gate
- [ ] Demo passes.
- [ ] Stickies survive reboot on both platforms (positions restored on Windows, widgets on Android).
- [ ] Reminders fire on time on Android with the app killed.

---

## Phase 5 — Import & export (3 weeks)

**Goal:** easy to move in from other apps and to get anything out in common formats.

### Steps

**5.1 Import framework (`tephra_io`)**
- Importer interface: pick source → preview (counts, warnings) → choose target folder → run in isolate with progress → report of what couldn't be converted.
- Shared helpers: HTML → Markdown converter, attachment copying with de-duplication, safe file names, date → frontmatter.

**5.2 Importers** (in priority order)
- Obsidian vault (just open; plus "merge another vault into this one").
- Plain Markdown/text folders; HTML files.
- Notion export zip (strip IDs from names, fix links, databases → notes with properties + a `.base` file).
- Evernote `.enex` (notes, tags, attachments, created/updated dates).
- Google Keep (Takeout JSON), Bear, Roam JSON, Logseq, Apple Notes export, OneNote exported files, CSV → one note per row.

**5.3 Export**
- Vault/folder → `.zip` (optional password encryption).
- Note → PDF: uses the reading view renderer (embeds resolved, page size, margins, header/footer, page numbers, include properties option).
- Note/folder → HTML (self-contained, images inlined), DOCX (headings, lists, tables, images, links), "portable Markdown" (wikilinks → standard links, embeds inlined).
- Share sheet integration on Android, "Save as…" on Windows.

### Tests
- Fixture exports from each source app (Notion, Evernote…) → expected Markdown snapshots.
- Export snapshot tests; PDF/DOCX opened and checked with a parser for structure.

### Exit gate
- [ ] Each importer handles its fixture with 0 crashes and a correct report.
- [ ] A 1,000-note Notion export imports in < 2 min on Windows with working links.
- [ ] Exported PDF/DOCX/HTML of the syntax test note looks right (manual check + snapshot).

---

## Phase 6 — Visual views (6 weeks)

**Goal:** Graph, Canvas, Bases, slides and rich media — the views that make Obsidian visual.

### Steps

**6.1 Graph view**
- Force-directed layout (Barnes-Hut) in an isolate, rendered with `CustomPainter`; pan/zoom/drag nodes; hover/tap highlights neighbours.
- Global graph and local graph (depth slider) as a sidebar/tab.
- Filters (search query, tags, attachments, orphans, existing files only), groups with colours (by query), display settings (arrows, labels fade, node size, link thickness), forces (centre, repel, link force, distance).
- Target: 10k nodes at 60 fps on PC, 30 fps on phone (with level-of-detail).

**6.2 Canvas (JSON Canvas)**
- Read/write `.canvas` exactly per spec (unknown fields preserved).
- Nodes: text cards (Markdown), note embeds, media, web links, groups; edges with labels, colours, arrow ends; snapping and alignment guides.
- Infinite zoom/pan, multi-select, copy/paste, undo/redo; touch gestures on Android, mouse/keyboard on PC.

**6.3 Bases**
- Parse/write `.base` YAML; table view (sortable, resizable columns, inline property edits) and cards view; filters and formulas per Obsidian's syntax; embedded ` ```base ` blocks.

**6.4 Math, Mermaid, code**
- Math with `flutter_math_fork` (inline + block, error display).
- Mermaid: rendered in a hidden WebView, cached as SVG keyed by source hash; works offline (bundled mermaid.js).
- Code blocks: highlighting for 100+ languages, copy button, line numbers option.

**6.5 Media & documents**
- PDF viewer (`pdfrx`): search, outline, zoom, open at page from `#page=N` links, copy text.
- Image viewer (zoom/pan, gallery), audio/video player, embedded players in notes.

**6.6 Slides**
- Presentation from a note split on `---`; full screen, keyboard/tap navigation.

### Exit gate
- [ ] Graph budget met on the 10k vault.
- [ ] A `.canvas` and `.base` file round-trip unchanged after open/save in Tephra, and Tephra-made ones open correctly in Obsidian.
- [ ] Mermaid and math render offline on both devices.

---

## Phase 7 — Remaining parity & polish (4 weeks)

**Goal:** close every remaining gap with Obsidian's core and make the app feel finished.

### Steps
- **7.1 Core plugins:** note composer (merge notes, extract selection/heading to new note with link), format converter, word/character count (status bar + selection),
  random note, audio recorder (inserts embed), file recovery (snapshot browser), footnotes view, web viewer (PC), outline drag-to-move.
- **7.2 Workspace:** saved workspaces (layouts), stacked tabs, pinned tabs, linked panes, pop-out windows (PC), tab groups; restore last session.
- **7.3 Editor extras:** multi-cursor (PC), vim mode (PC), spell check (system on Android, Hunspell dictionaries on Windows), RTL text, paste HTML → Markdown, drag lines/blocks.
- **7.4 Look & settings:** full settings screens mirroring Obsidian's sections; theme engine (JSON themes: colours, fonts, sizes), theme editor with live preview,
  import colour variables from popular Obsidian themes; custom fonts; accent colour; interface zoom.
- **7.5 Accessibility:** screen reader labels (TalkBack, Narrator), keyboard-only navigation on PC, contrast checks, text scaling.
- **7.6 Polish pass:** empty states, onboarding (first-run guide vault), animations, error messages in plain language, every command reachable from palette and mobile toolbar.

### Exit gate
- [ ] Feature checklist in IMPLEMENTATION_PLAN §4.1 fully ticked on both platforms.
- [ ] Accessibility audit: every screen usable with TalkBack and with keyboard only on Windows.

---

## Phase 8 — Advanced extras (8 weeks, four 2-week blocks; order can change)

**8a — AI & semantic search**
- Settings for API key (stored securely), model choice (Claude by default), privacy notice: nothing is sent unless the user invokes AI.
- Local embeddings index (chunked notes) updated incrementally; "Related notes" panel; semantic mode in search.
- Assistant panel: ask the vault (answers cite and link source notes), summarise/rewrite selection, suggest tags and links, generate flashcards.
- Exit: answers always cite notes; works offline for semantic search when a local embedding model is chosen.

**8b — Productivity**
- Dataview-lite ` ```tephra-query ` (LIST / TABLE / TASK with FROM, WHERE, SORT, GROUP BY) compiled to index queries.
- Tasks dashboard: all tasks with Tasks-plugin date emoji format, filters, due-date reminders.
- Kanban boards (obsidian-kanban Markdown format), flashcards with spaced repetition (SM-2), review screen and stats.
- Exit: query/Kanban files written by Tephra open correctly with the Obsidian Dataview/Kanban plugins.

**8c — Media intelligence**
- OCR on images and PDFs (ML Kit on Android, Tesseract/Windows OCR on PC), text added to the search index.
- Voice notes with transcription (on-device where possible); sketching/handwriting canvas with stylus pressure, saved as a file + PNG preview.

**8d — Security**
- Encrypted notes/folders inside the vault (separate password, locked/unlocked state, auto-lock timer), app lock (PIN/biometric on Android, Windows Hello).

**Exit gate for Phase 8:** each block passes its own exit check and the Phase 2 performance budgets still hold.

---

## Phase 9 — Release hardening (3 weeks)

**Goal:** v1.0 that is safe to give to other people.

### Steps
- **9.1 Stability:** crash reporting (opt-in, e.g. Sentry), fix all crash-free-rate issues from beta users; target 99.5% crash-free sessions.
- **9.2 Performance:** profile all budgets again on a low-end Android phone (4 GB RAM); fix regressions; reduce APK size (split per ABI).
- **9.3 Security & licence review:** encryption code review, dependency + licence audit, EULA and privacy policy final, secure storage check, permissions minimised and justified.
- **9.4 Data-safety drill:** simulate disk full, power loss during sync, corrupted index, corrupted remote manifest → app recovers with no loss.
- **9.5 Packaging (direct download):** signed Android APKs (per-ABI + one universal); Windows `.exe` installer (Inno Setup) plus a portable `.zip`;
  Back up the Android signing key safely: if it is lost, users can never update.
- **9.6 Distribution & updates:** download page (a project site, or a public releases-only repository so the source stays private) with checksums; in-app update check on both platforms
  (Android downloads the new APK and opens the installer; Windows downloads and runs the new setup); versioning and changelog.
  Optional Windows code-signing certificate to avoid SmartScreen warnings. Privacy policy page.
- **9.7 Docs:** user guide (as a Tephra vault shipped in the app), FAQ, migration guide from Obsidian.

### Exit gate (v1.0)
- [ ] 2 weeks of beta with ≥ 10 users (or your own heavy use) with no data-loss report.
- [ ] All performance budgets met on the low-end phone.
- [ ] Signed APK and `.exe` published with checksums; in-app update from the previous version tested on both platforms.

---

## Phase 10 — Tephra Cloud: our own online backup & sync → v2.0 (6 weeks)

**Goal:** a real hosted backup/sync service run by us, so users don't need a Google account, sync is instant, and
we control storage, history and (later) collaboration. The same server program can also be self-hosted for free.

**Prerequisites:** v1.0 released; Drive sync stable. Because Phase 3 built the sync core behind a provider interface and the
remote format is end-to-end encrypted, this phase adds a new provider + a server, not a new sync engine.

### Steps
- **10.1 Server (`server/`, Dart `shelf`)**: accounts (email + password, email verification, password reset), per-device tokens,
  encrypted blob storage (local disk or S3-compatible object storage), device journals, history retention, WebSocket push so other
  devices sync within ~1 s. It only ever sees encrypted data. Reads `PORT` (default `8094` in this build), binds `0.0.0.0`, prints `Local:` / `Network:`;
  registered in Dev Launcher as a second service.
- **10.2 Hosting**: a VPS (or container platform) + object storage; HTTPS with automatic certificates; daily server backups to a
  second location; monitoring and alerts; rate limiting and abuse protection.
- **10.3 Plans & limits**: free tier storage limit; paid plans later if wanted (payment provider integration is a separate decision).
- **10.4 App side**: "Tephra Cloud" provider, sign-up / sign-in screens, storage usage screen, **move vault from Google Drive to Tephra Cloud**
  (copies encrypted data, no re-encryption needed), option to keep Drive as an extra off-site backup.
- **10.5 Self-hosting**: the same server packaged as a Windows `.exe`, Linux binary and Docker image, with a guide
  (Tailscale or Cloudflare Tunnel for reaching it from the phone, both free).
- **10.6 Legal**: terms of service, privacy policy update, data deletion on account removal.

### Exit gate (v2.0)
- [ ] Same fuzz and data-safety tests as Phase 3 pass with the Tephra Cloud provider.
- [ ] A save on one device appears on the other within 3 s.
- [ ] Moving a 10k-note vault from Drive to Tephra Cloud completes with zero differences.
- [ ] Server survives a restore-from-backup drill; 7 days on staging without errors or memory growth.

---

## Phase 11 — Ecosystem (later)

- Play Store + Microsoft Store release when ready: store listings, Play "All files access" declaration, data-safety form, MSIX package, screenshots.
- Real-time collaboration on shared vaults through Tephra Cloud (CRDT).
- Extra sync targets if wanted: WebDAV (Nextcloud/NAS), S3-compatible, Dropbox, OneDrive, Git.
- Web clipper browser extension → saves to vault via sync.
- Sandboxed plugin API (QuickJS) with our own documented interface.
- iOS, macOS and Linux builds (mostly packaging + platform permissions, since the code is shared).
- Static-site publishing from a vault.

---

## Dependency map (why the order is what it is)

```
Phase 0 ─► 1 (vault, parser, editor) ─► 2 (index, links, search, Live Preview) ─► 3 (sync)
                                              │                                    │
                                              ├──────────────► 4 (stickies) ◄──────┘  (stickies need index + sync)
                                              ├──────────────► 5 (import/export)       (needs parser + renderer)
                                              └──────────────► 6 (graph, canvas, bases) (needs index)
                                                                  7 (parity) ─► 8 (extras) ─► 9 (v1.0) ─► 10 (Tephra Cloud, v2.0)
```

Phases 4, 5 and 6 depend only on 2 (and 4 on 3), so with a second developer they can run in parallel and v1.0 moves ~10 weeks earlier.
