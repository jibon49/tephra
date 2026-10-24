# Implementation Plan — Obsidian-compatible Notes App (Flutter)

App name: **Tephra**. Package names use the `tephra_` prefix; Android/Windows id `com.tephra.app`.

## 1. Is it possible?

Yes. Obsidian's core is a folder of plain Markdown files plus an index and a set of views. All of that
can be rebuilt in Flutter, and because the files are plain Markdown, a vault stays readable and editable
by Obsidian itself. That is the compatibility goal: **open the same folder in Obsidian or Tephra, get the same notes.**

What cannot be copied 1:1, and what we do instead:

| Obsidian thing | Why it can't be copied directly | Our approach |
|---|---|---|
| Community plugins (JS on Electron APIs) | Flutter doesn't run Obsidian's JS/DOM API | Build the most popular plugins in (Dataview-lite, Tasks, Kanban, Calendar, Excalidraw-like sketching, Templater-lite). Later, an optional sandboxed JS plugin API with our own interface (QuickJS). |
| CSS themes & snippets | Flutter doesn't render with CSS | JSON theme files (colors, fonts, spacing) plus a theme editor. Import the colour variables from popular Obsidian themes where we can. |
| Mermaid diagrams | Mermaid is a JS library | Render in an off-screen WebView / JS engine and cache as SVG. |
| Obsidian Sync / Publish servers | Proprietary, paid | v1: sync & backup through the user's own Google Drive; v2: our own hosted Tephra Cloud. Both end-to-end encrypted. Static-site export instead of Publish. |

Realistic scale: Obsidian took a funded team several years. For one full-time developer: MVP in about
**3 months**, v1.0 with full core parity, sync, stickies and extras in about **44 weeks**, and our own hosted backup (v2.0) about 6 weeks later (see [PHASE_PLAN.md](PHASE_PLAN.md)).
The phases are ordered so the app is useful from Phase 2 on.

## 2. Target platforms

**Two first-class targets, built together from day one, from one Flutter codebase:**

- **Android app** (phones and tablets) — full features, touch-first layout.
- **Windows PC app** — full features, keyboard/mouse layout, multiple windows.

The same vault is used on both, kept in step by the sync engine (§7). Every feature in §4 ships on both,
adapted to the device (e.g. floating sticky windows on PC, floating bubbles + home-screen widgets on Android).

Later, if wanted, with little extra work: iOS, macOS, Linux. A web build is used only as a quick dev preview
from Dev Launcher (§12), not as a product.

**Android specifics**
- Vault location: the user picks a folder in shared storage (e.g. `Documents/MyVault`) so other apps (and Obsidian
  for Android) can open the same files. This needs the "All files access" permission, the same one Obsidian uses;
  an app-private folder is the fallback when the user doesn't grant it.
- Min SDK 26 (Android 8), target the latest SDK. Background sync with WorkManager; respects battery saver and Wi-Fi-only setting.
- Phone layout = single pane + swipe sidebars; tablet/landscape layout = PC-like split panes.

**Windows specifics**
- Vault anywhere on disk; system tray icon, global hotkeys, multiple windows, always-on-top sticky windows.
- Distributed as a `.exe` installer (Inno Setup) and a portable `.zip`, with in-app updates. Microsoft Store (MSIX) later.

## 3. File format (the compatibility contract)

All of this must round-trip byte-for-byte when a file is opened and saved without edits.

- **Vault** = a normal folder. Notes are `.md` files, UTF-8, kept as written (no reformatting on save).
- **Attachments**: any file type stored in the vault; location setting matches Obsidian (vault root, same folder, or a set subfolder).
- **Markdown flavour**: CommonMark + GFM (tables, task lists, strikethrough, autolinks) + Obsidian extensions:
  - `[[Wikilink]]`, `[[Note|alias]]`, `[[Note#Heading]]`, `[[Note#^block-id]]`
  - Embeds: `![[Note]]`, `![[Note#Heading]]`, `![[image.png|300]]`, `![[file.pdf#page=3]]`, audio/video embeds
  - Block IDs `^block-id`, tags `#tag/nested`, highlights `==text==`, comments `%%hidden%%`
  - Callouts `> [!note] Title` with fold state `+`/`-`, all built-in callout types
  - Math `$inline$` and `$$block$$` (LaTeX), footnotes (normal and inline `^[...]`), Mermaid code blocks
- **Properties**: YAML frontmatter, with typed properties (text, list, number, checkbox, date, datetime) and `aliases`, `tags`, `cssclasses`.
- **Canvas**: `.canvas` files in the open JSON Canvas format.
- **Bases**: `.base` YAML files (Obsidian's database views) — read and write the same format.
- **Obsidian settings**: Tephra keeps its own settings in `.tephra/` inside the vault. On first open of an existing
  Obsidian vault it imports `.obsidian/` settings it understands (daily notes, templates folder, attachment folder,
  bookmarks, hotkeys) and never modifies `.obsidian/`.

## 4. Feature list

### 4.1 Obsidian parity (core plugins and built-in features)

**Editing**
- Three modes: Source, Live Preview (syntax hides except where the cursor is), Reading view.
- Syntax highlighting, auto-pair brackets, smart lists, indent/outdent, move line up/down, multi-cursor.
- Autocomplete for `[[links]]`, headings, block refs, tags, properties.
- Slash commands, folding (headings and lists), vim mode (desktop), spell check, RTL support.
- Paste images / drag-and-drop files into notes, auto-convert pasted HTML to Markdown.
- Properties editor UI above the note.

**Navigation & organisation**
- File explorer (create, rename, move, drag-and-drop, sort options); renaming a note updates every link to it.
- Tabs, split panes (horizontal and vertical), pop-out windows (desktop), stacked tabs, pinned tabs.
- Saved workspaces (layouts).
- Quick switcher, command palette, configurable hotkeys.
- Backlinks, outgoing links, unlinked mentions (with "link this" action).
- Outline (headings), tags pane, bookmarks, random note.
- Page preview: hover over a link to see the note.

**Search**
- Full-text search with Obsidian operators: `file:`, `path:`, `tag:`, `line:`, `block:`, `section:`, `task:`,
  `task-todo:`, `task-done:`, `[property:value]`, `match-case:`, regex `/.../`, boolean `OR` / `-` / quotes.
- Embedded search results via ` ```query ` blocks.

**Views**
- Graph view (global and local), with filters, groups/colours, depth, forces settings, orphans toggle.
- Canvas: cards, embedded notes, media, web pages, groups, connections, zoom/pan.
- Bases: table and card views over notes, with filters, sorting, formulas.
- Slides (presentation from a note split on `---`).
- PDF viewer with links to pages; image and audio/video viewers.

**Core plugins**
- Daily notes, unique note creator (Zettelkasten), templates (with `{{date}}`, `{{time}}`, `{{title}}`).
- Note composer (merge notes, extract selection to a new note), format converter.
- Audio recorder, word count, file recovery (local snapshots).
- Web viewer (desktop), footnotes view.

**Settings & look**
- Light/dark/system theme, accent colour, fonts and sizes, readable line length, custom themes.
- Per-vault settings, multiple vaults with a vault switcher.

### 4.2 The difference: backup, sync, import, export

**Online backup & sync** (detailed in §7)
- **v1.0: Google Drive.** Sync and backup through the user's own Google Drive (15 GB free). Nothing for us to host or pay for.
- **v2.0: Tephra Cloud.** Our own hosted backup & sync service (instant sync, no Google account needed, built-in history).
  The same server can also be self-hosted. Vaults can be moved from Drive to Tephra Cloud in one step.
- Later if wanted: WebDAV (Nextcloud/NAS), S3-compatible, Dropbox, OneDrive, Git.
- Two modes: **Live sync** (continuous, multi-device) and **Backup** (scheduled versioned snapshots, e.g. hourly/daily, with retention rules).
- End-to-end encryption with a vault password; the provider only sees encrypted blobs.
- Version history per note with a diff view and one-click restore; conflict handling that merges where safe.
- Selective sync (exclude folders/file types, e.g. skip large videos on mobile).

**Export**
- Whole vault as `.zip` (optionally encrypted), single note or folder.
- Note → PDF (with embeds resolved, page size, margins, headers), HTML, DOCX, plain Markdown with embeds
  inlined and wikilinks converted to standard Markdown links.
- Vault → static website (an offline "Publish" replacement) with graph, backlinks and search.

**Import**
- Open an existing Obsidian vault directly (no conversion needed).
- Importers: Notion (export zip), Evernote (`.enex`), Bear, Google Keep (Takeout), Apple Notes (exported),
  Roam Research (JSON), Logseq, OneNote (via exported files), HTML files, plain text / Markdown folders, CSV → notes.
- Every importer writes Obsidian-compatible Markdown and attachments, and reports what it couldn't convert.

### 4.3 Sticky notes

A sticky note is a normal `.md` file, so it syncs, backs up, searches and links like any other note, and
Obsidian still opens it. What makes it sticky is its frontmatter:

```yaml
---
tephra-sticky: true
sticky-color: yellow        # yellow, pink, blue, green, purple, or a hex value
sticky-pinned: true         # always on top (desktop)
sticky-remind: 2026-10-12T09:00
---
Call the printer guy
- [ ] ask about toner
```

- **Windows floating stickies**: each sticky can open as its own small window without borders. It can stay on top of other apps,
  remembers its position and size per device (stored in `.tephra/stickies.json`, not in the note, since screens differ), and can be collapsed to its title bar. A global hotkey (e.g. `Ctrl+Alt+N`) creates one from anywhere.
  "Show/hide all stickies" is available from the tray icon.
- **Sticky board**: a view showing every sticky as a coloured card on an endless board. Cards can be dragged, grouped by colour or tag,
  and sorted. Under the hood it's a JSON Canvas, so the board is also a valid `.canvas` file.
- **Android**: home-screen widgets (one sticky per widget, or a stack), floating sticky bubbles over other apps
  ("draw over other apps" permission, `flutter_overlay_window`), quick-add from the notification shade, and the sticky board screen.
- **Any note can become a sticky** ("Pin as sticky" command) and turn back into a normal note. Stickies support checklists, links, images and Markdown.
- Stickies can have a reminder notification, can expire (auto-archive after a date), and can be locked (read-only).
- Stickies go in a `Stickies/` folder by default (this can be changed in settings).

### 4.4 Extra advanced features (beyond Obsidian, built in)

- **AI assistant** (opt-in, uses the user's own API key; Claude by default, e.g. `claude-sonnet-5-5`):
  ask questions about the vault with cited notes, summarise, rewrite, auto-suggest tags and links, generate
  flashcards, "explain this note".
- **Semantic search**: embeddings index stored locally; find notes by meaning, show "related notes" in a sidebar.
- **OCR**: search text inside images and scanned PDFs (ML Kit on mobile, Tesseract on desktop).
- **Voice notes with transcription** attached to the note as text.
- **Built-in Dataview-lite**: ` ```tephra-query ` blocks — list/table/task queries over properties, tags, links.
- **Tasks dashboard**: every `- [ ]` across the vault with due dates (`📅 2026-10-20` format, compatible with the Tasks plugin), reminders and notifications.
- **Kanban boards** stored as Markdown (compatible with the obsidian-kanban format).
- **Sketching / handwriting** canvas with stylus support, saved as a file next to the note.
- **Spaced-repetition flashcards** from `question :: answer` or `?` lines.
- **Encrypted notes/folders** inside an otherwise plain vault.
- **Mobile quick capture**: home-screen widget, share-to-Tephra from any app, quick note from notification.
- **Web clipper** (browser extension, later phase) saving pages as Markdown.
- **Real-time collaboration** on a shared vault (CRDT-based, later phase, via Tephra Cloud).

### 4.5 Notion-style templates and database views (added 2026-10-20)

Built in Phase 6, still stored as plain Markdown + frontmatter + `.base` files, so Obsidian opens everything.

**Templates**
- Template gallery with ready-made templates (meeting notes, journal, weekly review, project brief, task, book, recipe,
  contact, lecture notes, trip plan, bug report, decision record) and **template packs** that set up a whole workspace
  (Projects & tasks, Reading list, Habit tracker, Simple CRM): folder + database view + templates.
- Template picker on "New note", and default templates per folder (e.g. new note in `Projects/` uses the Project template).
- Smarter template variables: questions (`{{prompt:Client name}}`), choices (`{{select:Status|todo,doing,done}}`),
  cursor position, date offsets (`{{date+7d}}`), folder/file names. Template properties merge into the note's properties.
- Template buttons inside notes (a `tephra-button` block): "New meeting note", "Add today's log", run a command.

**Database views** (extending Bases)
- Board (Kanban by any property — drag a card to change the note's status), Calendar (by date, drag to reschedule),
  Gallery (cover images), Timeline (start/end dates, drag to move or resize), List, plus the existing Table and Cards.
- "New" button in every view: creates a note from the database's template with properties pre-filled
  (e.g. clicking + in the "Doing" lane creates a note with `status: doing`).
- Inline databases: insert a database view inside any note.

## 5. Architecture

```
┌─────────────────────────── Flutter UI (app/) ───────────────────────────┐
│ Workspace (tabs, splits) · Editor · Reading view · Graph · Canvas · Bases│
│ Sidebars (explorer, search, backlinks, outline, tags) · Settings · Sync  │
└──────────────┬──────────────────────────────────────────────────────────┘
               │ Riverpod providers
┌──────────────▼───────────── Pure Dart core packages ────────────────────┐
│ tephra_markdown  parser + Obsidian syntax extensions, AST, renderer model │
│ tephra_vault     file system abstraction, watcher, attachments, rename    │
│ tephra_index     SQLite (drift) index: notes, links, tags, props, FTS5     │
│ tephra_search    query parser for Obsidian search syntax → SQL/FTS         │
│ tephra_sync      sync engine, providers, encryption, history              │
│ tephra_io        importers / exporters                                    │
│ tephra_ai        LLM + embeddings (optional)                              │
└──────────────────────────────────────────────────────────────────────────┘
```

Key decisions:

- **Files are the source of truth.** The SQLite index is a cache that can always be rebuilt from the files.
  External edits (Obsidian open on the same vault, Git pulls) are picked up by a file watcher.
- **Heavy work runs in isolates**: indexing, search, graph layout, sync, import/export — the UI thread only renders.
- **Core packages are pure Dart** (no Flutter imports), so they are fast to unit-test and reusable by the sync server and a CLI.
- **Monorepo with melos**: `app/`, `packages/*`, `server/` (Tephra Cloud server for v2.0, Dart `shelf`).

### Recommended packages

| Need | Package |
|---|---|
| State management | `flutter_riverpod` |
| Markdown parsing | `markdown` (extended with custom inline/block syntaxes) |
| Editor base | `re_editor` (code-editor engine) customised for Live Preview — see risk §10 |
| Database / FTS | `drift` + `sqlite3_flutter_libs` (FTS5) |
| File watching | `watcher` |
| YAML frontmatter | `yaml` + `yaml_edit` (edits keep the user's formatting) |
| Math | `flutter_math_fork` |
| Syntax highlighting | `highlight` / `re_highlight` |
| PDF view / export | `pdfrx` (view), `pdf` (generate) |
| Mermaid, web viewer | `webview_flutter` / `flutter_inappwebview` |
| Desktop windows & menus | `window_manager`, `desktop_multi_window`, `hotkey_manager`, `tray_manager` (also used by floating stickies) |
| Mobile widgets & reminders | `home_widget`, `flutter_local_notifications` |
| Sync targets | v1: `googleapis` + `google_sign_in` (Drive); v2: own server (`shelf`, `web_socket_channel`) |
| Encryption | `cryptography` (AES-256-GCM, Argon2id) |
| Secure key storage | `flutter_secure_storage` |
| Diff / merge | `diff_match_patch` |
| Zip | `archive` |
| Audio | `record`, `just_audio` |

## 6. Indexing & search details

Tables: `files`, `notes` (title, aliases, mtime, hash), `headings`, `blocks`, `links` (source, target, kind:
link/embed, resolved?), `tags`, `properties` (key, typed value), `tasks`, `fts_notes` (FTS5).

- Link resolution follows Obsidian rules: shortest unique path, case-insensitive, aliases count.
- On file change: re-parse only that file, diff its links/tags, update backlinks incrementally.
- Startup: compare mtime + size with the index; re-index only changed files. Target: 10,000-note vault opens in under 2 s after first index.
- Search operators compile to SQL + FTS5 queries; regex and `line:`/`section:` are evaluated on candidate files in an isolate.

## 7. Sync & backup engine

**Provider interface** (each backend implements this):
`list(prefix)`, `get(path)`, `put(path, bytes, ifMatch)`, `delete(path)`, `getManifest()`, `putManifest()`.

**How live sync works**
1. Each device keeps a local record of the last synced state: path → content hash, plus a copy of the last synced text of each Markdown file (the "base").
2. Remote stores encrypted files plus a `manifest` (path → hash, device, version) and a `history/` folder.
3. Sync cycle: compare local, base and remote:
   - changed on one side only → copy over;
   - changed on both sides, Markdown → three-way merge (base, local, remote) with diff-match-patch; if lines truly clash,
     keep both versions and create `Note (conflict 2026-10-11 Device).md`;
   - binary file changed on both sides → keep both;
   - renames detected by hash so links and history follow the file.
4. Manifest updates use compare-and-swap (`ifMatch` / ETag) so two devices can't overwrite each other's manifest.
5. Triggers: on file save (debounced), remote-change polling/push, every N minutes, on app resume; Android uses WorkManager in the background.

**Encryption**: vault password → Argon2id → master key. Each file encrypted with AES-256-GCM; file names are
encrypted too (remote paths are random IDs). The key is never uploaded; a recovery key is shown once at setup.

**Backup mode**: a scheduled job uploads a deduplicated, encrypted snapshot (content-addressed chunks, so daily
backups only upload what changed). Retention: e.g. keep hourly for 2 days, daily for 30 days, monthly for a year.
Restore a single note, a folder, or the whole vault to any point in time.

**Google Drive (v1)**: `drive.file` scope; visible `Tephra/<vault>/` folder holding encrypted content-addressed blobs and one append-only journal per device (Drive has no reliable compare-and-swap, so no file is ever written by two devices); remote changes found with the Drive Changes API (~30 s polling while open). Step 4 above therefore uses per-device journals on Drive instead of a shared manifest.

**Tephra Cloud (v2)**: our server implements the same provider interface, plus WebSocket push for instant sync, accounts, per-device tokens and server-side history. It only stores encrypted blobs. Because the remote format is the same, moving a vault from Drive is a straight copy.

## 8. UI layout

- Windows PC (and Android tablets in landscape): left ribbon + left sidebar (explorer/search/bookmarks), centre workspace (tabs + splits),
  right sidebar (backlinks/outline/tags/properties/AI), status bar (word count, sync status). Mirrors Obsidian so users feel at home.
- Android phone: single pane with swipe-in sidebars, bottom toolbar above the keyboard (formatting, link, tag, undo), quick switcher on pull-down.
- Every action is a **command** (id, name, default hotkey, handler) → feeds the command palette, hotkeys and the mobile toolbar from one registry.

## 9. Project structure

```
tephra/
  melos.yaml
  app/                      Flutter app (all platforms)
    lib/
      main.dart
      workspace/            tabs, splits, layouts
      editor/               live preview editor, autocomplete, toolbar
      views/                reading, graph, canvas, bases, pdf, media
      sidebars/             explorer, search, backlinks, outline, tags
      sync_ui/  settings/  commands/  theme/
  packages/
    tephra_markdown/  tephra_vault/  tephra_index/  tephra_search/
    tephra_sync/      tephra_io/     tephra_ai/
  server/                   Tephra Cloud server (v2.0, Dart shelf)
  test_vaults/              real-world fixture vaults for compatibility tests
```

## 10. Risks and how we handle them

| Risk | Mitigation |
|---|---|
| **Live Preview editor** is the hardest part (Flutter has no rich Markdown editor like CodeMirror 6) | Phase 0 prototype on `re_editor`: render styled spans, hide syntax on non-cursor lines, inline widgets (images, checkboxes, math) as placeholders. If it can't reach 60 fps on 5,000-line notes, fall back to a custom `RenderObject`-based editor. Source mode and Reading view ship first regardless. |
| Big vaults (50k+ notes) | Incremental indexing in isolates, lazy file tree, virtualised lists, graph layout off-thread with Barnes-Hut. |
| Sync data loss | Never delete without a history copy; three-way merge; conflict files; fuzz tests simulating multiple devices offline. |
| Breaking Obsidian compatibility | Round-trip tests: open → save every file in fixture vaults and assert byte equality; parse tests against Obsidian's documented syntax. |
| Android file access (scoped storage) | Request "All files access" for a shared vault folder (no review needed for direct APKs; Play Store allows it for file-based note apps with justification); fall back to an app-private folder or Storage Access Framework. |
| Two platforms doubling the work | One codebase; layout chosen by screen size, not by platform; platform-only features (tray, overlays, widgets) isolated behind small interfaces. CI builds and tests both on every commit. |
| Google Drive OAuth setup | Create the Google Cloud project and Android + Windows OAuth clients at the start of Phase 3. Use the `drive.file` scope (non-sensitive, no paid security assessment). Until Google verifies the consent screen, up to 100 test users can sign in, enough for early direct-download use; submit for verification before wider release. |
| Drive sync is slower than a push server (polling) | ~30 s polling while open is acceptable for v1; instant sync arrives with Tephra Cloud in v2.0. |
| Self-hosted server reachability (v2.0) | Guide uses Tailscale (free, encrypted, no port forwarding); Cloudflare Tunnel as alternative. |

## 11. Phases & milestones

The detailed phase-by-phase plan — steps in build order, tests, demo scripts and exit gates for every phase — is in
**[PHASE_PLAN.md](PHASE_PLAN.md)**. Summary:

| # | Phase | Weeks | Milestone |
|---|---|---|---|
| 0 | Foundation (tooling, CI, editor spike) | 2 | |
| 1 | Vault, files & basic editor | 5 | |
| 2 | Links, index, search, Live Preview | 5 | **MVP** |
| 3 | Sync & backup via Google Drive | 5 | **Beta** |
| 4 | Sticky notes & quick capture | 3 | |
| 5 | Import & export | 3 | |
| 6 | Visual views (graph, canvas, bases, media) | 6 | |
| 7 | Remaining parity & polish | 4 | |
| 8 | Advanced extras (AI, tasks, OCR, encryption…) | 8 | |
| 9 | Release hardening | 3 | **v1.0** |
| 10 | Tephra Cloud: our own hosted backup & sync | 6 | **v2.0** |
| 11 | Ecosystem | later | |

## 12. Running during development (Dev Launcher)

Per the standing rule, the project will be registered in Dev Launcher (`d:/script/dev-launcher`):

- `README.md` with `## Install` (`flutter pub get` / `melos bootstrap`) and `## Run`:
  `flutter run -d web-server --web-hostname 0.0.0.0 --web-port ${PORT:-8093}` — one long-running process, logs to stdout.
  A tiny wrapper is avoided; if the launcher needs the `Local:` / `Network:` lines, a Dart `tool/dev.dart` entry prints them and execs Flutter in-process.
- From v2.0, the Tephra Cloud server (`server/`) reads `PORT` (default `8094` in this build), binds `0.0.0.0`, prints `Local:` and `Network:` URLs, and is registered as a second service.
- Registration via `POST /api/inspect` → `POST /api/projects` (`autoStart: false`) → start and check logs.
- The real apps run from VS Code: `flutter run -d windows` for the PC app, `flutter run -d <android-device>` for the phone (USB or wireless debugging).

## 13. Testing & quality

- Unit tests for the parser (every syntax element), link resolver, search query compiler, sync merge logic.
- Round-trip compatibility tests against fixture vaults (including the Obsidian help vault).
- Sync simulation tests: 3 virtual devices, random offline edits, renames, deletes → assert no data lost and states converge.
- Widget/golden tests for editor rendering; performance benchmarks (open time, typing latency, search latency) in CI.

## 14. Decisions (agreed 2026-10-11)

1. **Name: Tephra** (volcanic fragments, a sibling of obsidian). A web search found no note-taking app with this name; "Lumen", Basalt, Tektite and Rhyolite were already used by note apps. Package id `com.tephra.app`. (Not a formal trademark search.)
2. **Sync & backup:** v1.0 uses Google Drive (user's own account). v2.0 adds Tephra Cloud, our own hosted online backup & sync (Phase 10).
3. **Distribution:** direct downloads first: signed APK for Android, `.exe` installer for Windows, with in-app updates.
   Play Store and Microsoft Store later, when ready (Phase 10).
4. **Source code: closed (private) for now; may be open-sourced later.** To keep both doors open:
   - Only use dependencies with permissive licences (MIT, BSD, Apache-2.0, zlib, MPL-2.0 for unmodified files).
     No GPL/AGPL/LGPL code linked into the app or server, since that would force us to publish our code or block closing it.
     A licence check runs in CI and fails the build on a non-allowed licence (see PHASE_PLAN 0.3).
   - All code is written by us (no copied code from Obsidian or other apps); third-party notices kept in `THIRD_PARTY_NOTICES.md`
     and shown on an "About → Licences" screen (`showLicensePage`).
   - No secrets in the repo (OAuth client IDs/keys, signing keys, keystore passwords) — they live in local config / CI secrets,
     so the repo could be made public later without leaking anything.
   - Private Git repository. Copyright header per source file: `© 2026 Tephra. All rights reserved.` (easy to swap for a licence later).
   - Binaries ship with an end-user licence (free to use, no redistribution of modified copies) and a privacy policy.
