# Phase 06 — Visual views

> **Duration:** 6 weeks (24 steps).
> **Goal:** add the views that make an Obsidian vault visual: Graph view (global and local), Canvas (JSON Canvas 1.0),
> Bases (`.base` table and cards views), math, Mermaid diagrams, better code blocks, a PDF viewer, image/audio/video viewers
> with embeds, and Slides. Everything works on Android and Windows, offline, and every file Tephra writes opens unchanged in Obsidian.

---

## Before you start

1. Read `GEMINI.md`, then `instructions/00-conventions.md` in full. This file references conventions sections as "§N"; it never
   redefines them. Where this file adds something the conventions do not cover (new `.tephra/` files, new public methods), it says so
   explicitly and you must record the addition in `PROGRESS.md` under the step's notes.
2. Confirm in `PROGRESS.md` that the Phase 5 exit gate is fully ticked. If not, stop (GEMINI.md §3).
3. Create the branch: `git checkout main`, `git pull` (if a remote exists), `git checkout -b phase-06`.
4. Run the full test suite once before changing anything and record the result in `PROGRESS.md`:
   ```
   flutter pub get
   dart format --output=none --set-exit-if-changed app/lib app/test packages tool
   flutter analyze --fatal-infos
   cd packages/tephra_core; dart test; cd ../..
   cd packages/tephra_markdown; dart test; cd ../..
   cd packages/tephra_vault; dart test; cd ../..
   cd packages/tephra_index; dart test; cd ../..
   cd packages/tephra_search; dart test; cd ../..
   cd packages/tephra_sync; dart test; cd ../..
   cd packages/tephra_io; dart test; cd ../..
   cd app; flutter test; cd ..
   ```
   (PowerShell: replace `cd x; cmd; cd ..` with `Push-Location x; cmd; Pop-Location`.) Everything must pass before Step 06.1.
5. **Names of existing code.** This file refers to code built in Phases 1–5 by role. The expected names are below. Before Step 06.1,
   search the code (`grep -rn "class <Name>" app/lib packages`) and find the real name of each item. **If a real name differs, use the
   real name everywhere this file uses the expected name. Never rename existing code to match this file.** Write the mapping
   (expected → real, with file path) into `PROGRESS.md` under "Phase 6 notes → Name map".

   | Role (built in) | Expected name / location |
   |---|---|
   | Vault file system provider (Ph. 1) | `vaultFsProvider` in `app/lib/vault/providers.dart`, type `VaultFileSystem` (§7.2) |
   | Vault root directory of the open vault (Ph. 1) | `vaultSessionProvider` exposing `rootDir` (absolute path string) |
   | Index provider (Ph. 2) | `noteIndexProvider` in `app/lib/core/providers.dart`, type `NoteIndex` (§7.4) |
   | Index change notifications (Ph. 2) | a `Stream` or `Listenable` that fires after the index applied changes, e.g. `indexChangesProvider` |
   | Search engine (Ph. 2) | `searchEngineProvider`, type `SearchEngine` (§7.5) |
   | Reading view (Ph. 1) | `ReadingView` widget in `app/lib/reading/`; per-block builder used inside its `ListView.builder` (e.g. `ReadingBlockBuilder`) |
   | Embed renderer (Ph. 2) | the function/widget that renders `MdWikiLink(embed: true)` in reading view (e.g. `EmbedView`) |
   | Live Preview inline blocks (Ph. 2) | the mechanism that renders math/images/callouts as inline blocks in the editor (e.g. `LivePreviewBlockWidget`) |
   | Editor controller (Ph. 0/1) | `EditorController` in `app/lib/editor/` |
   | Code highlighter (Ph. 1) | e.g. `CodeHighlighter` in `app/lib/reading/` using `re_highlight` or `highlight` |
   | Workspace tabs (Ph. 1) | tab model + notifier in `app/lib/workspace/` (e.g. `WorkspaceTab`, `workspaceProvider`), persisted in `.tephra/workspace.json` |
   | Right sidebar panels (Ph. 2) | panel registry in `app/lib/workspace/` (backlinks, outline, tags panels) |
   | Vault settings (Ph. 1) | `vaultSettingsProvider` reading/writing `.tephra/settings.json` |
   | App settings (Ph. 0/1) | `appSettingsProvider` reading/writing `<appSupportDir>/settings.json` |
   | Frontmatter edit service (Ph. 2) | the service the properties editor uses to change one property via `yaml_edit` (e.g. `PropertiesService.setProperty`) |
   | Property type registry (Ph. 2) | `.tephra/types.json` loader (e.g. `PropertyTypesRegistry`) |
   | Rename with link update (Ph. 2) | e.g. `LinkMaintenance.renameFile(from, to)` |
   | Create note for unresolved link (Ph. 2) | e.g. `NoteCreator.createForLink(target, from)` |
   | Window service (Ph. 0/4) | `WindowService` in `app/lib/core/platform/` (§5.9) |
   | Sticky board `.canvas` read/write (Ph. 4) | code in `app/lib/stickies/` that reads/writes the board `.canvas` file |
   | HTML → Markdown converter (Ph. 5) | e.g. `HtmlToMarkdown` in `packages/tephra_io` |
   | File picker / URL launcher / clipboard packages (Ph. 1) | `file_picker`, `url_launcher`, `pasteboard` (record the real choices) |

6. **Additions to contracts made by this phase (permitted; existing signatures must not change).**
   - New public query methods on `NoteIndex` (Step 06.3). Adding methods is allowed by this phase file; changing or removing existing
     §7.4 members is not.
   - New public APIs: `splitSlides` in `tephra_markdown` (Step 06.24), the JSON Canvas codec in `tephra_io` (Step 06.12),
     the Bases engine in `tephra_search` (Steps 06.16–06.18). Each is exported through the package's `lib/tephra_x.dart`.
   - New per-vault files: `.tephra/graph.json` (graph settings, synced like other `.tephra/*.json`),
     `.tephra/cache/mermaid/` (rendered diagrams), `.tephra/cache/link-previews.json`, `.tephra/cache/pdf-state.json`.
     Everything under `.tephra/cache/` is rebuildable and never synced (§6.6).
   - Record all of these in `PROGRESS.md` → "Phase 6 notes → Contract additions" so the human can fold them into the conventions.
7. Re-check every package README on pub.dev **before** using it. APIs in this file were correct when written (October 2026), but if
   the current README shows different names, follow the README and note the difference in `PROGRESS.md`.

---

## What exists when done

- **View registry**: opening any vault file routes by extension to the right view (Markdown editor/reading, Canvas, Base, PDF, image,
  audio/video), and non-file tabs exist for Graph and Local graph. All tab kinds are saved in `.tephra/workspace.json`.
- **Graph view** (`app/lib/graph/`): global graph tab and local graph (right-sidebar panel and tab), force-directed layout with a
  Barnes–Hut quadtree in a worker isolate streaming positions at ≤ 30 Hz, `CustomPainter` rendering with batched raw points and
  vertices, level of detail, spatial-grid hit testing, pan/zoom/drag/hover/tap, Obsidian-style settings panel (Filters, Groups,
  Display, Forces) persisted in `.tephra/graph.json`. Budget: 10k nodes at 60 fps on Windows, 30 fps on the phone.
- **Canvas** (`packages/tephra_io/lib/src/canvas/` + `app/lib/canvas/`): byte-exact JSON Canvas 1.0 codec that preserves unknown
  fields and the original formatting; an infinite board with text, file (note, image, PDF, media), link and group nodes; Bézier edges
  with arrows and labels; create, drag, resize, multi-select, snap to grid, alignment guides, connect, copy/paste, delete, undo/redo,
  zoom to fit, keyboard shortcuts and touch gestures. The Phase 4 sticky board uses the same codec.
- **Bases** (`packages/tephra_search/lib/src/bases/` + `app/lib/bases/`): `.base` YAML model with lossless edits, an expression
  language (tokenizer, Pratt parser, evaluator, function library), query execution in an isolate, table view (sortable, resizable
  columns, inline property edits) and cards view, plus embedded ` ```base ` blocks.
- **Math** (`flutter_math_fork`) inline and block in reading view, Live Preview and canvas cards, with readable error boxes.
- **Mermaid** rendered offline in a hidden WebView with a bundled `mermaid.min.js`, returned as SVG, drawn with `flutter_svg`,
  cached in `.tephra/cache/mermaid/`.
- **Code blocks**: copy button, optional line numbers, ≥ 100 highlighted languages.
- **PDF viewer** (`pdfrx`): search, outline, zoom, thumbnails, text selection/copy, `#page=N` deep links and page embeds, last page remembered.
- **Image viewer** (zoom/pan, folder gallery) and **audio/video player** (`video_player` + `video_player_win`), as tabs and as embeds.
- **Slides**: full-screen presentation from a note split on `---` lines.

---

## Dependencies

Add each with `flutter pub add <name>` inside `app/` (or `dart pub add` inside a package dir), then run
`dart run tool/check_licenses.dart` (GEMINI.md §4 rule 6). Do not add anything not in this table without asking.

| Package / asset | Licence | Used for | Added in step |
|---|---|---|---|
| `flutter_inappwebview` (app) | Apache-2.0 | Hidden (headless) WebView for Mermaid on Android + Windows (WebView2); reused by the Phase 7 web viewer | 06.1 |
| `flutter_svg` (app) | MIT | Drawing Mermaid SVG output and `.svg` images | 06.1 |
| `flutter_math_fork` (app) | Apache-2.0 | TeX math rendering | 06.1 |
| `pdfrx` (app) | MIT (bundles PDFium binaries: BSD-3-Clause / Apache-2.0) | PDF viewer, page thumbnails | 06.1 |
| `video_player` (app) | BSD-3-Clause | Audio + video playback (Android implementation) | 06.1 |
| `video_player_win` (app) | BSD-3-Clause | Windows implementation of `video_player` (Media Foundation) | 06.1 |
| `http` (app) | BSD-3-Clause | Link-card title/favicon fetch (skip if already a dependency) | 06.1 |
| `html` (app) | MIT | Parsing `<title>` and icon links of fetched pages (skip if already a dependency from Phase 5) | 06.1 |
| `mermaid` JS (asset `app/assets/mermaid/mermaid.min.js`) | MIT | Diagram rendering inside the WebView | 06.21 |
| Already present (do not re-add): `yaml`, `yaml_edit`, `crypto`, `url_launcher`, `path`, `path_provider`, `flutter_riverpod`, `logging`, `pasteboard` (the Phase 1 clipboard package), `file_picker` | MIT / BSD | — | — |

**Fallback (only if Step 06.1's WebView spike fails, see there):** `webview_flutter` (BSD-3-Clause, Android) +
`webview_windows` (BSD-3-Clause, Windows, needs the WebView2 runtime). You may not use the fallback unless the spike's failure
criteria are met and recorded.

**Rejected (do not use):** `media_kit` (its Windows/Android native libraries bundle libmpv/FFmpeg builds under LGPL/GPL — forbidden by
GEMINI.md §4 rule 6), `just_audio` on Windows (needs a third-party Windows backend; one player package for audio and video is simpler),
any WebView-based PDF viewer.

---

## Steps

### 06.1 Inventory, dependencies and WebView spike

**Purpose.** Add every Phase 6 dependency once, prove the two risky native pieces (headless WebView on Windows + Android, `pdfrx` and
`video_player_win` builds) before building features on them, and record the name map from "Before you start".

**Files**
- `app/pubspec.yaml` (dependencies; `flutter: assets:` gets `assets/mermaid/` later in 06.21)
- `app/lib/core/platform/headless_web_runner.dart` (new)
- `app/lib/core/platform/inapp_headless_web_runner.dart` (new)
- `app/test/core/platform/headless_web_runner_test.dart` (new)
- `app/integration_test/headless_web_runner_test.dart` (new)
- `THIRD_PARTY_NOTICES.md` (regenerated by the licence tool)
- `PROGRESS.md` (name map, contract additions, spike results)

**Implementation**
1. Fill in the name map (Before you start, item 5) in `PROGRESS.md`.
2. In `app/`: `flutter pub add flutter_inappwebview flutter_svg flutter_math_fork pdfrx video_player video_player_win`. Add `http`
   and `html` only if `app/pubspec.yaml` does not already list them. Run `flutter pub get` at the repo root, then
   `dart run tool/check_licenses.dart`. Every new package must be on the allowed list; if the tool reports an unknown licence for a
   package in the table above, read the package's LICENSE file, and if it matches the table, add the package to the tool's
   known-licence map with a comment naming the licence.
3. Android setup required by the packages (check each README; at minimum):
   - `app/android/app/src/main/AndroidManifest.xml`: `INTERNET` permission already exists from Phase 3; nothing else is needed for
     local files. Do **not** add `usesCleartextTraffic`.
   - `minSdk` stays 26 (§1). If a package needs a higher minSdk, stop and ask.
4. Windows setup: `flutter_inappwebview` on Windows uses WebView2 and needs the NuGet CLI on `PATH` at build time. Check
   `where nuget`. If missing, download `nuget.exe` (Microsoft, Apache-2.0 tooling, build-time only) into `D:\dev\tools\nuget\` and add
   that folder to the user `PATH`; record this in `PROGRESS.md`. WebView2 Runtime is part of Windows 11 and current Windows 10;
   the app must still check it at runtime (item 6).
5. Define the interface used by Mermaid (06.21) so the WebView package can be swapped:
   ```dart
   // app/lib/core/platform/headless_web_runner.dart
   /// Runs JavaScript in an invisible browser page. One instance serves one HTML page.
   abstract interface class HeadlessWebRunner {
     /// Loads [htmlFile] (absolute path of a local .html file). Completes when the page fired `load`.
     Future<void> start(String htmlFile);
     /// Evaluates [script]; the page answers by calling the JS function
     /// `window.tephraReply(requestId, jsonString)`; the returned future completes with that jsonString.
     Future<String> request(String requestId, String script, {Duration timeout = const Duration(seconds: 10)});
     bool get isRunning;
     Future<void> dispose();
   }
   final headlessWebRunnerFactoryProvider = Provider<HeadlessWebRunner Function()>((ref) => InAppHeadlessWebRunner.new);
   ```
   Implement `InAppHeadlessWebRunner` with `HeadlessInAppWebView`:
   - `initialUrlRequest: URLRequest(url: WebUri(Uri.file(htmlFile).toString()))`;
   - settings: `javaScriptEnabled: true`, `allowFileAccess: true`, `allowFileAccessFromFileURLs: true`,
     `allowUniversalAccessFromFileURLs: false`, `transparentBackground: true`, `cacheEnabled: false`, `incognito: true`;
   - in `onWebViewCreated`, `controller.addJavaScriptHandler(handlerName: 'tephraReply', callback: (args) { ... })` where
     `args[0]` is the request id (String) and `args[1]` the JSON string; complete the matching `Completer<String>`;
   - the HTML page defines `window.tephraReply = (id, json) => window.flutter_inappwebview.callHandler('tephraReply', id, json);`;
   - `request` registers a completer under `requestId`, calls `controller.evaluateJavascript(source: script)`, and fails with
     `TimeoutException` after `timeout` (remove the completer on timeout);
   - `start` completes on `onLoadStop`; fails with a `StateError` after 15 s;
   - on Windows, before `start`, call `WebViewEnvironment`/`getAvailableVersion` as documented by the package README for Windows to
     check that a WebView2 runtime exists; if none, throw `HeadlessWebUnavailableException` (new, extends `TephraException`, in the
     same file) with message `'WebView2 runtime not found'`.
   - On web (dev preview), the factory returns a runner whose `start` throws `HeadlessWebUnavailableException` (use `kIsWeb`).
6. **Spike (must pass before 06.21 starts; run it now):** write `app/integration_test/headless_web_runner_test.dart` that writes a
   temp HTML file containing the `tephraReply` shim and
   `<script>function add(id,a,b){ setTimeout(()=>window.tephraReply(id, JSON.stringify({sum:a+b})), 50); }</script>`,
   starts the runner, calls `request('r1', 'add("r1", 2, 3)')` and expects `{"sum":5}`; then 50 sequential requests complete in
   < 5 s total. Run it on Windows (`flutter test integration_test/headless_web_runner_test.dart -d windows`) and on the phone or
   emulator (`-d <android-device-id>`).
7. **Spike failure criteria → fallback.** If on either platform (a) the app fails to build because of `flutter_inappwebview` and the
   build error is not fixed by following the package README within the step, or (b) `HeadlessInAppWebView` does not load the page or
   the handler never fires, then: remove `flutter_inappwebview`, add `webview_flutter` and `webview_windows`, and implement
   `HeadlessWebRunner` as a widget-hosted runner (an `Offstage` 1×1 `WebViewWidget` on Android with a `JavaScriptChannel` named
   `tephraReply`; on Windows a `WebviewController` with `executeScript` and `webMessageReceived` inside an `Offstage` `Webview`
   widget mounted by a `HeadlessWebHost` widget placed once in `app.dart`). Record the exact failure and the switch in `PROGRESS.md`.
   If the fallback fails too, stop and ask the human.
8. Build smoke test for the other native packages (build only, no code uses them yet):
   `flutter build windows --debug` and `flutter build apk --debug` in `app/` must succeed with `pdfrx`, `video_player`,
   `video_player_win` and `flutter_math_fork` added (they are not used yet).

**Tests**
- `headless_web_runner_test.dart` (unit, with a fake controller wrapper): `request` times out after the given duration and removes the
  pending completer; two concurrent requests with different ids complete independently; `dispose` fails all pending requests with
  `StateError`.
- Integration spike test as in item 6 (Windows and Android).

**Verify**
```
dart run tool/check_licenses.dart          → exits 0, lists the new packages with allowed licences
cd app; flutter test test/core/platform; cd ..
cd app; flutter test integration_test/headless_web_runner_test.dart -d windows; cd ..
cd app; flutter test integration_test/headless_web_runner_test.dart -d <android-id>; cd ..
cd app; flutter build windows --debug; flutter build apk --debug; cd ..
```
Success: all pass; `PROGRESS.md` has the name map, contract additions list and spike timings (ms for 50 requests per platform).

**Pitfalls**
- `flutter_inappwebview` 6.1.x was last released in 2024; if the Android build complains about `namespace` or AGP versions, follow the
  package issue tracker's documented workaround only if it is a Gradle setting in **our** `android/` folder; never patch the package
  in the pub cache.
- `evaluateJavascript` does not wait for promises on every platform; that is why replies come back through `tephraReply`.
- Do not create the headless WebView at app start; it costs memory. It is created lazily on the first Mermaid block (06.21).

---

### 06.2 View registry and new tab kinds

**Purpose.** One place decides which view shows a file, and the workspace can hold non-note tabs (Graph, Local graph) and non-Markdown
file tabs, all persisted.

**Files**
- `app/lib/workspace/view_kind.dart` (new)
- `app/lib/workspace/view_registry.dart` (new)
- `app/lib/workspace/tab_content.dart` (new, unless Phase 1 already has an equivalent sealed type — then extend that one)
- the Phase 1 tab model/notifier and workspace persistence files (modify)
- `app/lib/explorer/` context menu (modify: "New canvas", "New base")
- `app/test/workspace/view_registry_test.dart`, `app/test/workspace/tab_content_test.dart` (new)

**Implementation**
1. `view_kind.dart`:
   ```dart
   enum ViewKind { markdown, canvas, base, pdf, image, audio, video, unsupported }
   const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};
   const audioExtensions = {'mp3', 'wav', 'm4a', 'ogg', 'flac', '3gp', 'aac', 'opus'};
   const videoExtensions = {'mp4', 'webm', 'mov', 'mkv', 'ogv'};
   ViewKind viewKindFor(VaultPath path); // 'md' → markdown, 'canvas' → canvas, 'base' → base, 'pdf' → pdf, sets above, else unsupported
   ```
   `webm` is treated as video (the player shows audio-only controls when the video size is 0×0, see 06.23).
2. `tab_content.dart` — the payload of a tab:
   ```dart
   sealed class TabContent { const TabContent(); Map<String, Object?> toJson(); static TabContent fromJson(Map<String, Object?> j); }
   final class FileTabContent extends TabContent { const FileTabContent(this.path, {this.subpath}); final VaultPath path; final String? subpath; }
   final class GraphTabContent extends TabContent { const GraphTabContent(); }
   final class LocalGraphTabContent extends TabContent { const LocalGraphTabContent(); }   // follows the active file tab
   ```
   JSON: `{"kind":"file","path":"A/B.md","subpath":"#page=3"}`, `{"kind":"graph"}`, `{"kind":"local-graph"}`.
   `fromJson` treats an entry **without** `kind` but with `path` as `file` (backward compatibility with Phase 1 workspace files).
   Unknown `kind` → `null` is not allowed; return `FileTabContent` only if `path` exists, otherwise skip the tab and log a warning.
   If Phase 1's tab model stored only a `VaultPath`, replace that field with `TabContent content` and update every call site; keep the
   per-tab back/forward history working with `TabContent` values (history entries compare with `==`).
3. `view_registry.dart`:
   ```dart
   typedef TabViewBuilder = Widget Function(BuildContext context, WidgetRef ref, TabContent content, String tabId);
   final class ViewRegistry {
     Widget build(BuildContext context, WidgetRef ref, TabContent content, String tabId);
     String titleFor(TabContent content, AppLocalizations l10n); // file stem for md; file name with extension for others; l10n for graph tabs
     IconData iconFor(TabContent content);
   }
   final viewRegistryProvider = Provider<ViewRegistry>((ref) => ViewRegistry());
   ```
   Routing: `FileTabContent` → `viewKindFor(path)`: `markdown` → the existing editor/reading tab widget (unchanged), `canvas` →
   `CanvasView` (06.14), `base` → `BaseView` (06.19), `pdf` → `PdfView` (06.22), `image` → `ImageViewerView` (06.23), `audio`/`video`
   → `MediaPlayerView` (06.23), `unsupported` → `UnsupportedFileView` (new, small: icon, file name, size, button "Open with system
   app" on Windows via `url_launcher` `launchUrl(Uri.file(absPath))`, hidden on Android). `GraphTabContent` → `GraphView` (06.9);
   `LocalGraphTabContent` → `LocalGraphView` (06.10). Until a view exists, return a `PlaceholderView` showing the l10n string
   `viewNotReadyYet` — each later step replaces its placeholder.
4. Make every "open file" path in the app (explorer tap, quick switcher, link click, search result, bookmark) go through one function
   `openFile(WidgetRef ref, VaultPath path, {String? subpath, bool newTab = false})` in `app/lib/workspace/open_file.dart`. If it
   already exists from Phase 1/2, extend it to build `FileTabContent(path, subpath: subpath)`. Wikilinks with `pdfPage` pass
   `subpath: '#page=N'`.
5. Explorer context menu on folders and the explorer header "New…" menu get two entries: **New canvas** and **New base**. Commands:
   `canvas.create-canvas` and `bases.create-base` (§7.8; labels in l10n). New file names: `Untitled.canvas` / `Untitled.base`, and
   if taken `Untitled 1.canvas`, `Untitled 2.canvas`, … (same rule for `.base`). Created in the folder of the context menu, or for the
   commands in the vault's "new note location" folder. Initial content: canvas → the empty document written by the codec of 06.12
   (until 06.12 exists, write the string `{\n\t"nodes":[],\n\t"edges":[]\n}`); base → exactly
   `views:\n  - type: table\n    name: Table\n`. Open the new file in a new tab.
6. l10n keys (add to `app_en.arb` with descriptions): `viewNotReadyYet`, `tabGraph` ("Graph view"), `tabLocalGraph`
   ("Local graph"), `explorerNewCanvas`, `explorerNewBase`, `commandCreateCanvas`, `commandCreateBase`, `unsupportedFileTitle`,
   `unsupportedFileOpenExternally`.

**Tests**
- `view_registry_test.dart`: `viewKindFor` for `a.md`, `A.MD` (extension is lower-cased by `VaultPath`), `x.canvas`, `x.base`,
  `doc.pdf`, `p.PNG`, `s.svg`, `song.mp3`, `clip.webm` (video), `file.xyz` (unsupported), `noext` (unsupported).
- `tab_content_test.dart`: JSON round-trip of all three kinds; legacy `{"path":"A.md"}` → `FileTabContent`; `{"kind":"graph"}` →
  `GraphTabContent`; `{"kind":"bogus"}` without path → skipped with warning.
- Widget test: opening `x.canvas` through `openFile` creates a tab whose body is the placeholder; the workspace JSON written contains
  `"kind":"file"`.
- Widget test: explorer "New canvas" twice creates `Untitled.canvas` then `Untitled 1.canvas`.

**Verify**
```
cd app; flutter test test/workspace test/explorer; cd ..
```
Run the app on Windows (`flutter run -d windows`), create a canvas and a base from the explorer, restart the app: both tabs are
restored. Success: tests pass; restart restores tabs.

**Pitfalls**
- Do not break the existing Markdown tab state (scroll position, mode) when wrapping paths in `FileTabContent`.
- Quick switcher should list `.canvas`, `.base`, `.pdf`, images and media files too (Obsidian does). If Phase 2's switcher only lists
  notes, add non-Markdown files from `NoteIndex.allFiles()` (06.3) after 06.3 is done — note it as a follow-up inside 06.3.

---

### 06.3 Index queries for graph and bases

**Purpose.** Graph and Bases need the whole vault's files, links, tags and properties in a few bulk queries (calling `outgoing()` 10,000
times would be far too slow).

**Files**
- `packages/tephra_index/lib/src/bulk_queries.dart` (new: record types)
- `packages/tephra_index/lib/src/note_index.dart` (modify: add methods)
- `packages/tephra_index/lib/tephra_index.dart` (export the new records)
- `packages/tephra_index/test/bulk_queries_test.dart` (new)

**Implementation**
1. Record types (immutable, value equality, doc comments, per §5.3):
   ```dart
   /// One vault file (note or attachment) as stored in the index.
   final class FileRecord { const FileRecord({required this.path, required this.size, required this.modified, this.created});
     final VaultPath path; final int size; final DateTime modified; final DateTime? created; }
   /// One link occurrence, already resolved where possible.
   final class LinkEdge { const LinkEdge({required this.source, required this.rawTarget, this.target, required this.embed});
     final VaultPath source; final String rawTarget; final VaultPath? target; /* null = unresolved */ final bool embed; }
   /// All tags of one note (inline + frontmatter), without '#', original case.
   final class NoteTags { const NoteTags(this.path, this.tags); final VaultPath path; final List<String> tags; }
   /// Decoded frontmatter of one note.
   final class NoteProperties { const NoteProperties(this.path, this.properties); final VaultPath path; final Map<String, Object?> properties; }
   ```
2. New `NoteIndex` methods (additive; doc comments):
   ```dart
   Future<List<FileRecord>> allFiles();               // every indexed file, notes and attachments, sorted by path
   Future<List<LinkEdge>> allLinks();                 // every link and embed in every note, in source order per note
   Future<List<NoteTags>> allNoteTags();              // notes with ≥ 1 tag
   Future<List<NoteProperties>> allProperties();      // notes with valid, non-empty frontmatter
   ```
   Each is one SQL query (or two joined in Dart) over the Phase 2 tables. `allLinks` resolves targets with the stored resolution
   column if Phase 2 stores one; otherwise it resolves in Dart using the same resolver as `resolveLink`, building the name lookup map
   once per call (never one query per link).
3. If the Phase 2 `files` table does not contain non-Markdown files, `allFiles()` must still return them: add them by listing the
   vault (`VaultFileSystem.list(recursive: true)`, applying the §6.1 ignore rules) and merging by path. Do **not** change the schema
   in this step unless the existing migration framework makes it a one-line addition; if you change the schema, add a migration and a
   migration test.
4. `allProperties()` returns the frontmatter map decoded the same way `ParsedNote.frontmatter` is (§7.3). If Phase 2 stores
   properties as typed rows, rebuild the map from rows; lists stay lists, dates stay strings exactly as written (Bases converts them).
5. Performance target (Windows, 10k-note bench vault, profile or `dart test` on a release-mode build is not possible, so measure in a
   test with a `Stopwatch` and record): each method < 400 ms; `allLinks` for ~50k links < 800 ms.
6. Follow-up from 06.2: if the quick switcher lacks non-Markdown files, add them now from `allFiles()`.

**Tests** (`bulk_queries_test.dart`, using `MemoryVaultFileSystem` + an in-memory/temporary SQLite file, as Phase 2 tests do)
- `allFiles includes attachments`: vault with `a.md`, `img/p.png`, `doc.pdf` → three records with correct sizes.
- `allLinks resolves and keeps unresolved`: `a.md` links `[[b]]`, `[[missing]]`, `![[p.png]]` → three edges; `missing` has
  `target == null`; the embed has `embed == true`.
- `allLinks after rename`: rename `b.md` → `c.md` (with Phase 2 link maintenance) → edge target is `c.md`.
- `allNoteTags merges frontmatter and inline`: `tags: [x]` + `#y` in body → `['x', 'y']` (order: frontmatter first, then body order).
- `allProperties skips invalid frontmatter`: a note with broken YAML is absent; a note with `rating: 4` has `{'rating': 4}`.
- `bulk queries are consistent with per-note queries`: for 200 random notes of a generated vault, `allLinks` filtered by source equals
  `outgoing(source)` (compare targets).
- `bench timing` (tagged `@Tags(['bench'])`, skipped in CI unless `TEPHRA_BENCH=1`): prints timings on the 10k bench vault.

**Verify**
```
cd packages/tephra_index; dart test; cd ../..
cd packages/tephra_index; $env:TEPHRA_BENCH='1'; dart test --tags bench; Remove-Item Env:TEPHRA_BENCH; cd ../..
```
Success: all tests pass; timings recorded in `PROGRESS.md`.

**Pitfalls**
- Keep the drift queries on the index's own connection/isolate; never open a second connection to the same SQLite file from the app.
- `VaultPath` is case-sensitive; resolution is case-insensitive (§7.1, Phase 2). Do not lower-case stored paths.

---

### 06.4 Graph settings and graph model builder

**Purpose.** Turn index data plus user settings (filters, groups) into an immutable `GraphModel` (nodes, edges, colours) ready for layout
and painting, and persist settings in `.tephra/graph.json`.

**Files**
- `app/lib/graph/model/graph_settings.dart` (new)
- `app/lib/graph/model/graph_settings_store.dart` (new)
- `app/lib/graph/model/graph_model.dart` (new)
- `app/lib/graph/model/graph_builder.dart` (new)
- `app/lib/graph/providers.dart` (new)
- `app/test/graph/model/graph_settings_test.dart`, `app/test/graph/model/graph_builder_test.dart` (new)

**Implementation**
1. `GraphSettings` (immutable, `copyWith`, value equality, `fromJson`/`toJson`). Fields, JSON keys, defaults and ranges:

   | Field | JSON key | Type | Default | Range / values |
   |---|---|---|---|---|
   | search | `search` | String | `''` | any search query (§7.5 syntax) |
   | showTags | `showTags` | bool | `false` | |
   | showAttachments | `showAttachments` | bool | `false` | |
   | existingFilesOnly | `existingFilesOnly` | bool | `true` | true = hide unresolved-link nodes |
   | showOrphans | `showOrphans` | bool | `true` | |
   | groups | `colorGroups` | List<GraphGroup> | `[]` | ordered; first match wins |
   | showArrows | `showArrows` | bool | `false` | |
   | textFade | `textFadeMultiplier` | double | `0.0` | −3.0 … 3.0, step 0.1 |
   | nodeSize | `nodeSizeMultiplier` | double | `1.0` | 0.1 … 5.0, step 0.1 |
   | lineSize | `lineSizeMultiplier` | double | `1.0` | 0.1 … 5.0, step 0.1 |
   | centerForce | `centerStrength` | double | `0.5` | 0.0 … 1.0, step 0.01 |
   | repelForce | `repelStrength` | double | `10.0` | 0.0 … 20.0, step 0.1 |
   | linkForce | `linkStrength` | double | `1.0` | 0.0 … 1.0, step 0.01 |
   | linkDistance | `linkDistance` | double | `250` | 30 … 500, step 1 |
   | localDepth (local only) | `depth` | int | `1` | 1 … 5 |
   | localIncoming (local only) | `incomingLinks` | bool | `true` | |
   | localOutgoing (local only) | `outgoingLinks` | bool | `true` | |
   | localNeighbors (local only) | `neighborLinks` | bool | `false` | |

   `GraphGroup { final String query; final int color; }` — JSON `{"query":"tag:#work","color":"#E5534B"}` (colour as `#RRGGBB`;
   parse case-insensitively; invalid → group skipped with a warning). `fromJson` clamps out-of-range numbers and ignores unknown keys
   **but keeps them**: store the original map in a private field `_extra` and write unknown keys back in `toJson` (so a newer Tephra's
   keys survive). Missing keys take defaults.
2. `.tephra/graph.json` file shape (written with 2-space indentation via `JsonEncoder.withIndent('  ')`, trailing `\n`):
   ```json
   {
     "version": 1,
     "global": { "search": "", "showTags": false, "...": "..." },
     "local":  { "depth": 1, "...": "..." }
   }
   ```
   `GraphSettingsStore` (Riverpod `AsyncNotifier`) loads it (missing/invalid file → defaults, invalid file logged at `warning` and
   **not overwritten until the user changes a setting**), exposes `global` and `local`, and saves debounced 500 ms after a change via
   `VaultFileSystem.writeText` (atomic). Never write when the serialised text equals the loaded text.
3. `GraphModel` (immutable; built off the UI isolate when large — see item 6):
   ```dart
   enum GraphNodeKind { note, attachment, tag, unresolved }
   final class GraphModel {
     final List<String> ids;            // stable id per node: path value | 'tag:#<name>' | 'unresolved:<lower-case target>'
     final List<String> labels;         // note: stem; attachment: file name; tag: '#name'; unresolved: raw target
     final Uint8List kinds;             // GraphNodeKind.index
     final Int32List groupIndex;        // -1 = no group
     final Int32List degree;            // undirected degree after filtering
     final Int32List edgeSource, edgeTarget;   // directed, unique (source,target) pairs, no self-loops
     final Int32List layoutA, layoutB;  // undirected unique pairs for the simulation
     final List<VaultPath?> paths;      // null for tag/unresolved
     final Float64List ctimeMs;         // creation time for "Animate" (0 if unknown)
     int get nodeCount; int get edgeCount;
     Map<String, int> get indexOfId;    // built lazily once
   }
   ```
4. `GraphBuilder.build(GraphInput input, GraphSettings s, {Set<VaultPath>? searchMatches, List<Set<VaultPath>> groupMatches})`
   where `GraphInput { List<FileRecord> files; List<LinkEdge> links; List<NoteTags> tags; }` is fetched from the index (06.3). Algorithm:
   ```
   notes       = files where path.isMarkdown
   attachments = files where !path.isMarkdown and extension not in {'canvas','base'}   // canvas/base files are not graph nodes
   nodes = {}
   add every note as kind=note
   if s.showAttachments: add attachments that are the target of ≥1 link/embed from a note, kind=attachment
   if !s.existingFilesOnly: for each link with target==null: add node 'unresolved:'+lower(rawTarget without #heading/^block/|alias)
   if s.showTags: for each tag t of each note: add node 'tag:#'+t (case-insensitive merge: id uses lower-case, label keeps first-seen case)
   edges: note→note (resolved links + embeds), note→attachment (if both present), note→unresolved, note→tag
   if searchMatches != null (non-empty s.search):
       keep note nodes in searchMatches
       keep attachment/unresolved/tag nodes only if connected to a kept note
   drop edges whose endpoints were dropped; dedupe (source,target); drop self-loops
   compute undirected degree
   if !s.showOrphans: drop nodes with degree 0 (do not iterate: one pass)
   groupIndex[n] = index of first group whose match set contains paths[n] (notes and attachments only; tags/unresolved: -1)
   layout pairs = unique unordered {min(a,b),max(a,b)} of edges
   ```
5. Search and groups use the Phase 2 `SearchEngine`: `searchMatches` = set of result paths of `SearchParser.parse(s.search)`; each
   group's match set likewise. Run them **before** `GraphBuilder.build`, in the provider (item 6), with a `CancelToken` so a newer
   settings change cancels an older build. A `SearchSyntaxException` makes the panel show the error under the field (06.9) and the
   builder treats that query as empty (search) or matching nothing (group).
6. Provider `graphModelProvider` (`AsyncNotifierProvider.family<GraphModelNotifier, GraphModel, GraphScope>` where
   `enum GraphScope { global, local }` — the local model is derived in 06.10). It: fetches `GraphInput` from the index, runs searches,
   then calls `Isolate.run(() => GraphBuilder.build(...))` when `files.length > 2000`, otherwise builds inline. It rebuilds when graph
   settings that affect structure change (search, toggles, groups) and when the index reports changes (debounced 1 s). Display and
   force settings do **not** rebuild the model.
7. Node colours are not stored in the model; the painter maps kind/group to colours (06.7).

**Tests**
- `graph_settings_test.dart`: defaults; JSON round-trip; out-of-range values clamped (`nodeSizeMultiplier: 99` → 5.0); unknown key
  `"futureKey": 1` preserved on `toJson`; invalid group colour skipped; store does not write when nothing changed (use
  `MemoryVaultFileSystem` and count writes); store writes once after three changes within 500 ms (fake async).
- `graph_builder_test.dart` with a hand-built `GraphInput` of 6 notes, 2 attachments, 1 unresolved link, 3 tags:
  `default settings → only notes, existing only, orphans shown`; `showTags adds tag nodes and note→tag edges`;
  `showAttachments adds only linked attachments`; `existingFilesOnly=false adds unresolved node with lower-case id`;
  `showOrphans=false removes degree-0 notes`; `search keeps matching notes and their tags only`;
  `groups first match wins` (two groups both matching a note → first group's index);
  `duplicate links produce one edge`; `self-link dropped`; `A→B and B→A give two directed edges and one layout pair`;
  `canvas and base files are never nodes`.
- `graph_builder 10k timing` (`@Tags(['bench'])`): 10k notes / 50k links builds in < 300 ms on Windows.

**Verify**
```
cd app; flutter test test/graph/model; cd ..
```
Success: all pass.

**Pitfalls**
- Tag matching is case-insensitive in Obsidian (`#Work` = `#work`); nested tags are separate nodes (`#a/b` is not merged into `#a`).
- Unresolved targets: strip `#heading`, `#^block` and `|alias` before building the id, so `[[X#h]]` and `[[x]]` share one node.

---

### 06.5 Force simulation with a Barnes–Hut quadtree

**Purpose.** A deterministic, allocation-free force-directed layout in pure Dart (no Flutter imports) that the worker isolate (06.6) runs.

**Files**
- `app/lib/graph/layout/force_params.dart` (new)
- `app/lib/graph/layout/quadtree.dart` (new)
- `app/lib/graph/layout/force_simulation.dart` (new)
- `app/test/graph/layout/quadtree_test.dart`, `app/test/graph/layout/force_simulation_test.dart` (new)

These files must not import `package:flutter` (they run in an isolate and are unit-tested). Add a test that reads the three source
files and fails if any contains `package:flutter`.

**Implementation**
1. `ForceParams` (immutable) and the mapping from `GraphSettings`:
   ```dart
   final class ForceParams {
     const ForceParams({this.centerStrength = 0.05, this.charge = -600, this.linkStrengthScale = 1.0, this.linkDistance = 250,
       this.theta = 0.9, this.velocityDecay = 0.4, this.alphaMin = 0.001, this.alphaDecay = 0.0228, this.alphaTarget = 0.0,
       this.distanceMin2 = 1.0, this.distanceMax2 = double.infinity});
     factory ForceParams.fromSettings(GraphSettings s) => ForceParams(
       centerStrength: s.centerForce * 0.1,      // slider 0..1 → 0..0.1
       charge: -s.repelForce * 60,               // slider 0..20 → 0..-1200
       linkStrengthScale: s.linkForce,           // slider 0..1
       linkDistance: s.linkDistance);            // 30..500 world units
   }
   ```
   `alphaDecay = 1 - pow(alphaMin, 1/300)` ≈ 0.0228 (the simulation cools to `alphaMin` in ~300 ticks, as in d3-force).
2. State (all flat typed arrays, allocated once per graph, length `n` or `2n`):
   `Float64List x, y, vx, vy; Float64List fx, fy; Uint8List pinned; Int32List linkA, linkB; Float64List linkBias, linkStrength;
   Int32List count /* undirected degree */; double alpha = 1.0;`
3. **Initial positions** (when the caller gives none for a node): phyllotaxis, exactly as d3:
   ```
   initialRadius = 10; initialAngle = pi * (3 - sqrt(5))
   for i in 0..n-1: r = initialRadius * sqrt(0.5 + i); a = i * initialAngle
                    x[i] = r * cos(a); y[i] = r * sin(a); vx[i] = vy[i] = 0
   ```
   When the caller passes previous positions for some nodes (graph rebuilt after an index change), use them; place each new node at
   the position of its first already-placed neighbour plus a jitter of ±20 from the seeded `Random`, or phyllotaxis if it has none.
4. **Link precomputation** (once per graph):
   ```
   count[i] = number of layout pairs touching i
   for each pair k=(a,b): linkBias[k] = count[a] / (count[a] + count[b])
                          linkStrength[k] = linkStrengthScale / min(count[a], count[b])
   ```
5. **Quadtree** (`quadtree.dart`), flat arrays, rebuilt every tick, capacity grows only (never shrinks):
   ```
   arrays per cell c: x0[c], y0[c], size[c]      // square cell: [x0, x0+size) × [y0, y0+size)
                      child[4c..4c+3]            // Int32, -1 = none
                      point[c]                   // Int32: first point index if leaf, -1 if internal or empty
                      cx[c], cy[c], strength[c]  // filled by accumulate()
   per point i:       nextInLeaf[i]              // Int32 chain of coincident points, -1 = end
   build(x, y, n):
     compute minX, minY, maxX, maxY over all points; size = max(maxX-minX, maxY-minY) + 1; root = cell 0 at (minX, minY, size)
     cellCount = 1; point[0] = -1; child[0..3] = -1
     for i in 0..n-1: insert(i)
   insert(i):
     c = 0; depth = 0
     loop:
       if point[c] == -1 and all child[4c+q] == -1:   point[c] = i; nextInLeaf[i] = -1; return      // empty leaf
       if point[c] != -1:                                                                       // occupied leaf
         j = point[c]
         if (abs(x[i]-x[j]) < 1e-9 and abs(y[i]-y[j]) < 1e-9) or depth >= 32:
             nextInLeaf[i] = nextInLeaf[j]; nextInLeaf[j] = i; return                           // coincident chain
         point[c] = -1                                                                          // split
         qj = quadrant(c, x[j], y[j]); cj = newCell(c, qj); point[cj] = j    // j keeps its own chain (nextInLeaf[j] unchanged)
       q = quadrant(c, x[i], y[i])
       if child[4c+q] == -1: cn = newCell(c, q); point[cn] = i; nextInLeaf[i] = -1; return
       c = child[4c+q]; depth += 1
   quadrant(c, px, py): half = size[c]/2; right = px >= x0[c]+half; bottom = py >= y0[c]+half; return (bottom?2:0) + (right?1:0)
   newCell(parent, q): c = cellCount++ (grow arrays ×2 if needed); size[c] = size[parent]/2;
                       x0[c] = x0[parent] + (q&1)*size[c]; y0[c] = y0[parent] + (q>>1)*size[c]
                       child[4c..4c+3] = -1; point[c] = -1; child[4*parent+q] = c; return c
   accumulate(chargePerNode):           // children always have larger indices than parents → reverse order is post-order
     for c from cellCount-1 down to 0:
       if point[c] != -1:                // leaf
         k = 0; sx = 0; sy = 0; p = point[c]
         while p != -1: sx += x[p]; sy += y[p]; k++; p = nextInLeaf[p]
         strength[c] = chargePerNode * k; cx[c] = sx / k; cy[c] = sy / k
       else:
         s = 0; ws = 0; sx = 0; sy = 0
         for q in 0..3: d = child[4c+q]; if d != -1 and strength[d] != 0:
             w = abs(strength[d]); s += strength[d]; ws += w; sx += cx[d]*w; sy += cy[d]*w
         strength[c] = s; if ws > 0: cx[c] = sx/ws; cy[c] = sy/ws
   ```
6. **Tick** (`force_simulation.dart`, method `void tick()`), same order every tick:
   ```
   alpha += (alphaTarget - alpha) * alphaDecay
   // 1. link force (one iteration)
   for each pair k=(a,b):
     dx = x[b] + vx[b] - x[a] - vx[a]; dy = y[b] + vy[b] - y[a] - vy[a]
     if dx == 0: dx = jiggle(); if dy == 0: dy = jiggle()
     l = sqrt(dx*dx + dy*dy)
     l = (l - linkDistance) / l * alpha * linkStrength[k]
     dx *= l; dy *= l
     vx[b] -= dx * linkBias[k];       vy[b] -= dy * linkBias[k]
     vx[a] += dx * (1 - linkBias[k]); vy[a] += dy * (1 - linkBias[k])
   // 2. charge (repulsion) with Barnes–Hut
   quadtree.build(x, y, n); quadtree.accumulate(charge)
   theta2 = theta * theta
   for i in 0..n-1: applyCharge(i)
   applyCharge(i):                       // explicit stack (Int32List, reused), no recursion
     push 0
     while stack not empty:
       c = pop
       if strength[c] == 0: continue
       dx = cx[c] - x[i]; dy = cy[c] - y[i]; w = size[c]; l = dx*dx + dy*dy
       if w*w / theta2 < l:                                    // far enough: treat cell as one body
         if l < distanceMax2:
           if dx == 0: dx = jiggle(); l += dx*dx
           if dy == 0: dy = jiggle(); l += dy*dy
           if l < distanceMin2: l = sqrt(distanceMin2 * l)
           vx[i] += dx * strength[c] * alpha / l; vy[i] += dy * strength[c] * alpha / l
         continue                                              // do not open children
       if point[c] == -1:                                      // internal: open it
         for q in 0..3: if child[4c+q] != -1: push child[4c+q]
         continue
       // leaf that is too close to approximate: visit its points one by one
       if l >= distanceMax2: continue
       p = point[c]
       while p != -1:
         if p != i:
           dx = x[p] - x[i]; dy = y[p] - y[i]
           if dx == 0: dx = jiggle(); if dy == 0: dy = jiggle()
           l = dx*dx + dy*dy
           if l < distanceMin2: l = sqrt(distanceMin2 * l)
           vx[i] += dx * charge * alpha / l; vy[i] += dy * charge * alpha / l
         p = nextInLeaf[p]
   // 3. centre force (gravity towards the origin, like d3 forceX/forceY)
   for i: vx[i] += (0 - x[i]) * centerStrength * alpha; vy[i] += (0 - y[i]) * centerStrength * alpha
   // 4. integrate: semi-implicit Euler with velocity damping (d3-force's integrator)
   for i:
     if pinned[i] == 1: x[i] = fx[i]; y[i] = fy[i]; vx[i] = 0; vy[i] = 0
     else: vx[i] *= (1 - velocityDecay); vy[i] *= (1 - velocityDecay); x[i] += vx[i]; y[i] += vy[i]
   tickCount += 1
   jiggle() = (random.nextDouble() - 0.5) * 1e-6      // random = Random(seed) given to the constructor
   ```
   Decision: we use d3-force's damped semi-implicit Euler integrator, not full velocity Verlet; it is stable with alpha cooling and
   matches the behaviour users know from Obsidian.
7. Public API:
   ```dart
   final class ForceSimulation {
     ForceSimulation({required int nodeCount, required Int32List linkA, required Int32List linkB, required ForceParams params,
       Float64List? initialXY /* 2n, NaN = no previous position */, int seed = 42});
     void tick();
     bool get isSettled;                 // alpha < alphaMin and no node pinned
     double get alpha; set alphaTarget(double v); void reheat([double alpha = 0.3]);
     void updateParams(ForceParams p);   // recomputes link strengths; does not reset positions
     void pin(int i, double x, double y); void unpin(int i);
     void writePositions(Float32List out); // out.length == 2n: [x0, y0, x1, y1, ...]
   }
   ```
8. Performance target: one `tick()` for 10k nodes / 20k pairs < 25 ms on the Windows laptop in a profile/AOT build and < 60 ms on
   the phone. Measured in 06.11. Inner loops must not allocate (no closures, no `List` growth, no `math.Point`).

**Tests**
- `quadtree_test.dart`: 1 point → root is a leaf; 2 points in different quadrants → root internal with 2 leaves; 5 coincident points →
  one leaf with a chain of 5 and `strength == 5 * charge`; centroid of 4 symmetric points is (0,0); 10,000 random points (seed 1) →
  sum of leaf counts == 10,000 and every point is inside its leaf cell bounds.
- `force_simulation_test.dart`:
  - `single link converges to linkDistance`: 2 nodes, 1 link, charge 0, centre 0, 500 ticks → distance within ±2% of 250.
  - `two nodes repel`: 2 nodes at (−1,0),(1,0), no links, centre 0 → distance grows monotonically over 50 ticks.
  - `centre pulls a lone node`: 1 node at (1000,0), centre 0.05 → |x| decreases.
  - `Barnes–Hut equals brute force at theta 0`: 300 random nodes, compute velocity change of one tick with θ = 0 and with an
    O(n²) reference implementation in the test → max abs difference < 1e-9.
  - `Barnes–Hut error at theta 0.9 is small`: same, θ = 0.9 → mean relative error of the charge velocity < 10%.
  - `deterministic`: two simulations with the same seed and input → identical positions after 100 ticks.
  - `alpha cools to settled in ~300 ticks`: `isSettled` false at tick 250, true by tick 320 (alphaTarget 0).
  - `pinned node stays put`: pin node 0 at (5,5), 100 ticks → exactly (5,5).
  - `no NaN`: 1,000 nodes all starting at (0,0) (initialXY all zeros) → after 50 ticks no NaN/Infinity.
  - `no flutter import` source check (see Files).
  - `tick timing` (`@Tags(['bench'])`): 10k nodes / 20k random pairs, mean of 20 ticks printed.

**Verify**
```
cd app; flutter test test/graph/layout; cd ..
```
Success: all pass; bench timing recorded (JIT number; the AOT number comes in 06.11).

**Pitfalls**
- `w*w / theta2 < l` compares squared quantities — do not take square roots in the hot loop.
- Re-allocate the quadtree arrays only when `cellCount` exceeds capacity (start with `4 * n + 16` cells).
- Never use `double.nan` checks inside the hot loop; validate inputs once in the constructor.

---

### 06.6 Layout worker isolate and position streaming

**Purpose.** Run the simulation off the UI isolate and stream positions to the UI at ≤ 30 Hz with zero-copy transfers.

**Files**
- `app/lib/graph/layout/layout_messages.dart` (new; pure Dart)
- `app/lib/graph/layout/layout_worker.dart` (new; pure Dart, the isolate entry point)
- `app/lib/graph/layout/layout_client.dart` (new; UI-side handle)
- `app/test/graph/layout/layout_worker_test.dart` (new)

**Implementation**
1. Messages (plain Dart classes; only sendable fields: numbers, strings, typed data, `TransferableTypedData`, `SendPort`):
   ```dart
   // UI → worker
   final class LayoutInit { final int nodeCount; final TransferableTypedData linkA, linkB; final TransferableTypedData? initialXY; final ForceParamsData params; }
   final class LayoutUpdateParams { final ForceParamsData params; }
   final class LayoutPin { final int node; final double x, y; }
   final class LayoutUnpin { final int node; }
   final class LayoutReheat { final double alpha; final double alphaTarget; }
   final class LayoutStop {}
   // worker → UI
   final class LayoutReady { final SendPort commands; }
   final class LayoutFrame { final TransferableTypedData positions /* Float32List 2n */; final double alpha; final int tick; final bool settled; final double tickMs; }
   ```
   `ForceParamsData` = `ForceParams` flattened to doubles (ForceParams itself is fine if it only holds doubles; then reuse it).
2. Worker loop (`layoutWorkerMain(SendPort toUi)`):
   ```
   create ReceivePort commands; send LayoutReady(commands.sendPort)
   sim = null; lastEmit = Stopwatch()
   listen to commands, handling each message immediately:
     LayoutInit → build ForceSimulation from materialized typed data; start ticking
     LayoutUpdateParams → sim.updateParams(p); sim.reheat(0.3)
     LayoutPin → sim.pin(...); sim.alphaTarget = 0.3; ensure ticking
     LayoutUnpin → sim.unpin(...); sim.alphaTarget = 0
     LayoutReheat → sim.reheat(alpha); sim.alphaTarget = alphaTarget; ensure ticking
     LayoutStop → close port; Isolate.exit()
   ticking loop (async, so messages are handled between batches):
     while running and not settled:
       t0 = now; sim.tick(); tickMs = now - t0
       if lastEmit.elapsedMilliseconds >= 33 or sim.isSettled: emit()
       await Future<void>.delayed(Duration.zero)        // yields to the message queue
     emit() once more when settled; stop ticking until a message re-arms it
   emit(): buf = Float32List(2n); sim.writePositions(buf);
           toUi.send(LayoutFrame(TransferableTypedData.fromList([buf]), alpha, tick, settled, tickMs)); lastEmit.reset()
   ```
3. `LayoutClient` (UI isolate):
   ```dart
   final class LayoutClient {
     static Future<LayoutClient> spawn();                      // Isolate.spawn(layoutWorkerMain, receivePort.sendPort)
     void init(GraphModel model, ForceParams params, {Float32List? previous});
     void updateParams(ForceParams p); void pin(int node, double x, double y); void unpin(int node); void reheat(double alpha, {double target = 0});
     ValueListenable<Float32List?> get positions;              // latest frame, materialized with .materialize().asFloat32List()
     ValueListenable<LayoutStats> get stats;                   // alpha, tick, settled, tickMs
     Future<void> dispose();                                   // sends LayoutStop, kills isolate after 500 ms if still alive
   }
   ```
   One `LayoutClient` per graph view instance (global tab, each local graph). Dispose it in the view's `dispose`.
4. `previous` positions: when the model is rebuilt (index change, filter change), the view builds `initialXY` (Float64 2n, NaN for
   unknown) by mapping old ids → new indices, then calls `init` again on the same worker, followed by `reheat(0.3)`.

**Tests** (`layout_worker_test.dart`, real isolates, `flutter test` supports them)
- `spawn, init, receive frames`: 100-node ring graph → at least 3 frames within 2 s; each frame has length 200; alpha decreasing.
- `frames are rate limited`: count frames during 1 s of ticking a 2k-node graph → ≤ 32.
- `settles and stops`: small graph → a frame with `settled == true` arrives, and no further frames for 500 ms afterwards.
- `pin moves node`: pin node 0 at (1000, 1000) → a later frame has node 0 at exactly (1000,1000).
- `dispose kills isolate`: after `dispose`, the isolate's exit port fires within 1 s.

**Verify**
```
cd app; flutter test test/graph/layout/layout_worker_test.dart; cd ..
```
Success: all pass.

**Pitfalls**
- `TransferableTypedData` can be materialized only once; materialize immediately on receipt.
- Do not send `GraphModel` objects with `List<VaultPath>` to the worker; it needs only counts and link pairs.
- On web (dev preview) isolates differ; it is acceptable to run the simulation on the UI thread there with a `Timer.periodic(33 ms)`
  doing up to 2 ticks. Use `kIsWeb` in `LayoutClient.spawn`.

### 06.7 Graph viewport and painter

**Purpose.** Draw 10k nodes and their edges in a few batched GPU calls, with level of detail, culling and fading labels.

**Files**
- `app/lib/graph/view/graph_viewport.dart` (new)
- `app/lib/graph/view/graph_colors.dart` (new)
- `app/lib/graph/view/graph_painter.dart` (new)
- `app/lib/graph/view/label_cache.dart` (new)
- `app/test/graph/view/graph_viewport_test.dart`, `app/test/graph/view/graph_painter_test.dart` (new)

**Implementation**
1. `GraphViewport` (mutable `ChangeNotifier`, one per view):
   ```dart
   final class GraphViewport extends ChangeNotifier {
     double scale = 1.0;            // screen px per world unit; clamped to [0.02, 8.0]
     Offset offset = Offset.zero;   // screen position of world origin
     Offset worldToScreen(double wx, double wy) => Offset(wx * scale + offset.dx, wy * scale + offset.dy);
     Offset screenToWorld(Offset s) => Offset((s.dx - offset.dx) / scale, (s.dy - offset.dy) / scale);
     Rect visibleWorldRect(Size size);                 // screenToWorld of (0,0) and (w,h)
     void zoomAt(Offset focal, double factor);         // ns = clamp(scale*factor); offset = focal - (focal - offset) * (ns / scale); scale = ns
     void panBy(Offset delta);                         // offset += delta
     void fitTo(Rect worldBounds, Size size, {double padding = 40});  // scale = min((w-2p)/bw, (h-2p)/bh) clamped; centre bounds
   }
   ```
2. `GraphColors` resolves colours from the current theme. Until Phase 7 adds theme tokens, read them from a `GraphColors.fromTheme(ThemeData)`
   mapping: note = `colorScheme.onSurfaceVariant`, attachment = `colorScheme.tertiary`, tag = `colorScheme.secondary`,
   unresolved = `colorScheme.outline`, line = `colorScheme.outlineVariant`, focused = `colorScheme.primary`, label = `colorScheme.onSurface`.
   Group colours come from `GraphGroup.color`. (Phase 7 replaces this mapping with the `graphNode*`/`graphLine` theme tokens.)
3. **Sizes.** Node radius in world units: `r = nodeSize * (3.0 + 1.2 * sqrt(degree))`, capped at `30 * nodeSize`. Quantise to one of 8
   buckets: `bucket = min(7, ((r / nodeSize - 3.0) / 3.0).floor())`, bucket radius `rb = nodeSize * (3.0 + 3.0 * bucket + 1.5)`.
   Precompute `Uint8List sizeBucket` per node when the model changes.
   Screen-space minimum: drawn radius = `max(rb, 1.5 / scale)` so nodes never vanish when zoomed out.
   Line width in screen px: `lw = clamp(lineSize * 1.0 * scale, 0.5, 4.0)`; world stroke width = `lw / scale`.
4. **Batches.** Bucket key = `(colourIndex, sizeBucket)` where `colourIndex` enumerates: kinds (4) + groups (G). Precompute, when the
   model or groups change, `Int32List bucketOrder` (node indices grouped by bucket) and `bucketStart` offsets. Per paint, for each
   bucket gather visible nodes' `x,y` into a reused, grow-only `Float32List` and call
   `canvas.drawRawPoints(PointMode.points, points, paint)` with `paint.strokeCap = StrokeCap.round`, `paint.strokeWidth = 2 * drawnRadius`,
   `paint.color = bucketColour` (dimmed: alpha 0.2 when a highlight is active and the node is not highlighted — dimmed and highlighted
   nodes go into separate gathers).
   Edges: gather endpoint pairs into a reused `Float32List` per category (normal, highlighted, dimmed) and call
   `canvas.drawRawPoints(PointMode.lines, pairs, paint)` with `strokeWidth = lw / scale`.
   Arrows (only if `showArrows` and `scale >= 0.4`): for each visible edge, a triangle at the target end, tip at distance `r_target`
   from the target centre along the edge, length `6 * lineSize / max(scale, 0.5)` world units, half-width 0.5 × length; collect into a
   `Float32List` of triangle vertices per category and draw with
   `canvas.drawVertices(Vertices.raw(VertexMode.triangles, positions), BlendMode.srcOver, paint)` (no per-vertex colours; one call per
   category colour).
   Everything above is drawn after `canvas.save(); canvas.translate(offset.dx, offset.dy); canvas.scale(scale);` so positions are passed
   in world units; then `canvas.restore()`.
5. **Culling.** `visible = viewport.visibleWorldRect(size).inflate(40 / scale)`. If the graph bounds (computed per frame from positions
   in the same loop) are fully inside `visible`, skip per-node tests and draw everything. Otherwise include a node only if its centre is
   in `visible` (inflated by its radius), and an edge if either endpoint is inside or the segment's bounding box intersects `visible`.
6. **Labels (level of detail).** Threshold `t = 0.8 * pow(1.6, -textFade)`. Label opacity
   `o = smoothstep(t, 1.4 * t, scale)` where `smoothstep(a,b,v) = clamp((v-a)/(b-a),0,1)^2 * (3 - 2*clamp(...))`. If `o == 0`, draw no
   labels except for the hovered/selected node and its neighbours (always drawn at full opacity). Labels are drawn **after** `restore()`
   in screen space: font size `12 * clamp(scale, 0.8, 1.4)` (rounded to 0.5), centred horizontally, top at
   `worldToScreen(node).dy + drawnRadius * scale + 2`. At most 300 labels per frame: iterate a precomputed `Int32List byDegreeDesc`
   and take the first 300 visible nodes. `LabelCache` caches laid-out `TextPainter`s keyed by `(nodeIndex, fontSizeTimes2)` in an LRU
   of 2,000 entries; it is cleared when the model or theme changes. Labels use `GraphColors.label` with opacity `o`.
7. `GraphPainter extends CustomPainter` takes: model, positions `ValueListenable<Float32List?>`, viewport, settings (display part),
   colours, highlight state (`int? focused`, `Set<int> neighbours`), and passes `repaint: Listenable.merge([positions, viewport, highlight])`.
   `shouldRepaint` returns true only when model/settings/colours identity changed. Never allocate per node in `paint`.
8. Wrap the `CustomPaint` in a `RepaintBoundary`.

**Tests**
- `graph_viewport_test.dart`: `worldToScreen(screenToWorld(p)) == p`; `zoomAt` keeps the focal world point under the focal screen
  point; scale clamps at 0.02 and 8; `fitTo` centres a rect and leaves ≥ padding on the tight axis.
- `graph_painter_test.dart` (widget tests with a fixed 3-node model and positions):
  - golden `goldens/graph_basic.png` at 400×300 (`@Tags(['golden'])`): 3 nodes, 2 edges, labels visible at scale 1.5.
  - `labels hidden below threshold`: at scale 0.3 with textFade 0, a `Canvas` recorder (use `PictureRecorder` + a test helper that counts
    `drawParagraph` calls via a custom `Canvas` subclass, or check `LabelCache.lookups == 0`) shows no label drawn.
  - `arrows only when enabled`: count `drawVertices` calls = 0 with `showArrows false`, > 0 with true at scale 1.
  - `culling`: 1,000 nodes spread over 10,000×10,000, viewport showing 1/100 of the area → gathered node count < 50.
  - `dimming`: with `focused = 0`, non-neighbour nodes are drawn in the dimmed batch (inspect the painter's debug counters
    `debugLastDimmedCount`, exposed with `@visibleForTesting`).

**Verify**
```
cd app; flutter test test/graph/view; cd ..
cd app; flutter test --tags golden test/graph/view; cd ..
```
Success: all pass (goldens generated on Windows with `--update-goldens` the first time, then committed).

**Pitfalls**
- `drawRawPoints` with `PointMode.points` draws squares unless `strokeCap` is `round`.
- Keep the gather buffers as fields of the painter's state object (not the `CustomPainter`, which is recreated); pass a
  `GraphPaintBuffers` object owned by the view's `State`.

---

### 06.8 Graph interactions: hit testing, pan/zoom, drag, hover, open

**Purpose.** Make the graph usable with mouse, keyboard and touch.

**Files**
- `app/lib/graph/view/spatial_grid.dart` (new; pure Dart)
- `app/lib/graph/view/graph_canvas.dart` (new: the interactive widget containing the `CustomPaint`)
- `app/test/graph/view/spatial_grid_test.dart`, `app/test/graph/view/graph_canvas_test.dart` (new)

**Implementation**
1. **Decision:** custom gesture handling (a `Listener` for pointer signals plus a `GestureDetector` with scale callbacks), **not**
   `InteractiveViewer`, because the painter needs the world transform for culling and labels, wheel zoom must zoom at the cursor, and
   node dragging must win over panning.
2. `SpatialGrid` (rebuilt whenever a new positions frame arrives, at most 30 Hz):
   ```dart
   final class SpatialGrid {
     SpatialGrid({this.cellSize = 64});            // world units
     void rebuild(Float32List xy, int n);          // counting sort: cellKey(i) → Int32List cellIndexStart/cellItems via a Map<int,int> from key to slot
     int? hitTest(double wx, double wy, Float32List xy, Float64List radius, double slop);   // nearest node whose distance ≤ radius+slop
   }
   cellKey(cx, cy) = ((cx & 0xFFFF) << 16) | (cy & 0xFFFF)  where cx = (x / cellSize).floor(), cy likewise
   hitTest: check the 3×3 cells around (wx, wy); if radius+slop > cellSize, widen the ring to ceil((radius+slop)/cellSize)
   ```
   `slop = 6 / viewport.scale` (6 screen px), `radius` = drawn radius per node.
3. Gestures in `GraphCanvas`:
   - **Mouse wheel** (`PointerScrollEvent` in `Listener.onPointerSignal`): `viewport.zoomAt(event.localPosition, exp(-event.scrollDelta.dy / 300))`.
   - **Trackpad pinch / two-finger pan** and **touch pinch**: `GestureDetector.onScaleUpdate`: when `pointerCount >= 2` or the gesture
     comes from a trackpad, `zoomAt(focalPoint, details.scale / lastScale)` and `panBy(details.focalPointDelta)`.
   - **One-pointer drag**: on `onScaleStart` with `pointerCount == 1`, hit test at the start point. If a node is hit → *drag node*
     mode: `client.pin(node, wx, wy)` and `client.reheat(alpha: 0.3, target: 0.3)` on start; on each update (throttled to one message
     per 16 ms) `client.pin(node, newWx, newWy)`; on end `client.unpin(node)` and `reheat(alpha: current, target: 0)`. Otherwise →
     *pan* mode: `panBy(focalPointDelta)`.
   - **Hover** (desktop, `MouseRegion.onHover`): hit test; set `highlight.focused` to the node or null; neighbours from a precomputed
     adjacency (`Int32List adjStart`, `adjItems` built with the model). Cursor `SystemMouseCursors.click` over a node.
   - **Long press** (touch, `onLongPressStart`): same as hover (focus + neighbours + labels) until the next tap on empty space.
   - **Tap / click** (`onTapUp`): node hit → open it (item 4). Empty space → clear focus.
   - **Keyboard** (when the graph has focus; `Focus` + `Shortcuts`/`Actions`): arrow keys pan 50 px; `+`/`=` zoom in ×1.2 at the
     centre; `-` zoom out; `0` zoom to fit. Esc clears focus highlight.
4. **Open behaviour:** note/attachment node → `openFile(ref, path)`; with Ctrl held (desktop) or middle click → `newTab: true`.
   Tag node → open the search panel with the query `tag:#<name>` (use the Phase 2 command/provider that sets the search query).
   Unresolved node → create the note via the Phase 2 "create note for unresolved link" service (target = node label, from = the
   first note linking to it), then open it.
5. **Auto-fit:** on the first frames after a model is first shown, call `viewport.fitTo(bounds)` when alpha drops below 0.3, unless the
   user has already panned/zoomed (track a `userMoved` flag).
6. Phone layout: minimum hit slop 16 screen px instead of 6 (48 dp touch target rule §5.8 cannot apply to dots; the slop compensates).

**Tests**
- `spatial_grid_test.dart`: 10,000 random nodes; 1,000 random queries: grid result equals brute-force nearest-within-radius result;
  query on empty area → null; a node larger than a cell is still found from a point near its edge.
- `graph_canvas_test.dart` (widget tests with a fake `LayoutClient` that returns fixed positions):
  `mouse wheel zooms at cursor` (world point under cursor unchanged); `drag on empty space pans`;
  `drag on a node sends pin/unpin` (fake client records calls in order: pin…, unpin); `tap on node opens file` (override `openFile`
  dependency with a recorder); `tap on tag node opens search with tag query`; `hover highlights neighbours` (painter highlight
  state contains the neighbour set); `long press highlights on touch`; `keyboard 0 fits`.

**Verify**
```
cd app; flutter test test/graph/view; cd ..
```
Success: all pass.

**Pitfalls**
- `GestureDetector` scale gestures also fire for a single pointer; branch on `pointerCount`.
- Throttle pin messages; sending one per pointer event floods the worker at 240 Hz on high-rate mice.

---

### 06.9 Global graph tab and settings panel

**Purpose.** The Graph view tab with an Obsidian-style settings panel (Filters, Groups, Display, Forces) bound to `.tephra/graph.json`.

**Files**
- `app/lib/graph/view/graph_view.dart` (new: tab body for `GraphTabContent`)
- `app/lib/graph/view/graph_settings_panel.dart` (new)
- `app/lib/graph/view/graph_animate_controller.dart` (new)
- `app/lib/graph/commands.dart` (new: registers graph commands)
- `app/lib/l10n/app_en.arb` (keys)
- `app/test/graph/view/graph_settings_panel_test.dart`, `app/test/graph/view/graph_view_test.dart` (new)

**Implementation**
1. `GraphView` = `Stack`: `GraphCanvas` filling the area; top-right a settings button (gear, tooltip/semantics `graphSettings`);
   the panel opens as a right-side overlay 320 dp wide on desktop layout and as a modal bottom sheet (max 70% height) on phone layout
   (width < 840 dp, §5.8). A small status chip bottom-left shows `"N notes · M links"` (l10n `graphStats` with plurals).
2. Panel sections (each an `ExpansionTile`, expansion state kept in memory per view):
   - **Filters:** search `TextField` (debounce 400 ms, shows `SearchSyntaxException.message` in `errorText`), switches **Tags**,
     **Attachments**, **Existing files only**, **Orphans**.
   - **Groups:** `ReorderableListView` of rows: colour swatch (tap → colour picker dialog with 12 preset swatches + hex field
     `#RRGGBB`), query field (debounce 400 ms, error text like Filters), delete icon button. Button **New group** appends
     `GraphGroup(query: '', color: next preset)`. Presets (in order): `#E5534B #E8912D #D9B30F #3FB950 #2DA8B8 #4A8CF0 #8E6CEF #D35FB7
     #8B949E #B08800 #1F883D #0969DA`.
   - **Display:** switch **Arrows**; sliders **Text fade threshold** (−3…3), **Node size** (0.1…5), **Link thickness** (0.1…5);
     button **Animate** (item 4).
   - **Forces:** sliders **Center force** (0…1), **Repel force** (0…20), **Link force** (0…1), **Link distance** (30…500).
   - Footer button **Restore defaults** (resets the current scope's settings to defaults, keeps unknown keys).
   Each slider shows its value; changes apply live: display settings repaint only; force settings call
   `client.updateParams(ForceParams.fromSettings(s))`; filter/group settings rebuild the model (06.4). All changes go to
   `GraphSettingsStore` (debounced save).
3. Commands (§7.8, registered in `app/lib/graph/commands.dart`, called from the app's command registration entry point):
   `graph.open-graph` (label "Open graph view", default shortcut Ctrl+G, icon `Icons.hub_outlined`) opens or focuses the single
   global graph tab; `graph.open-local-graph` (06.10). Add a ribbon button (desktop) and a drawer entry (phone) for
   `graph.open-graph`. `showInMobileToolbar: false`.
4. **Animate** (`GraphAnimateController`): sorts node indices by `ctimeMs` (unknown ctime last, then by path); over 10 s (60 steps)
   reveals nodes in that order: the painter receives a `visibleCutoff` (int) and draws only nodes with rank < cutoff and edges whose
   both endpoints are visible; at start calls `client.reheat(alpha: 1.0)`. Pressing Animate again while running stops it and shows all.
5. l10n keys: `graphSettings`, `graphFilters`, `graphSearchHint`, `graphTags`, `graphAttachments`, `graphExistingOnly`,
   `graphOrphans`, `graphGroups`, `graphNewGroup`, `graphGroupQueryHint`, `graphDisplay`, `graphArrows`, `graphTextFade`,
   `graphNodeSize`, `graphLinkThickness`, `graphAnimate`, `graphForces`, `graphCenterForce`, `graphRepelForce`, `graphLinkForce`,
   `graphLinkDistance`, `graphRestoreDefaults`, `graphStats` (ICU plural for notes and links), `commandOpenGraph`,
   `commandOpenLocalGraph`, `graphEmpty` ("No notes match these filters").
6. Empty model (0 nodes) → centred message `graphEmpty` instead of the canvas.

**Tests**
- `graph_settings_panel_test.dart`: toggling **Tags** updates `GraphSettingsStore` (`showTags == true`); moving the Repel slider calls
  `updateParams` on the fake client with charge = −value×60; invalid search `tag:(` shows the error text; reordering groups changes
  their order in the store; **Restore defaults** resets values; phone width 400 dp opens a bottom sheet, 1200 dp opens a side panel.
- `graph_view_test.dart`: with an overridden index returning 5 notes, the stats chip reads "5 notes · 4 links"; empty vault shows
  `graphEmpty`; command `graph.open-graph` twice leaves exactly one graph tab.

**Verify**
```
cd app; flutter test test/graph; cd ..
cd app; flutter run -d windows; cd ..   (open the real vault → Ctrl+G → change every setting → restart → settings kept)
```
Success: tests pass; manual check passes on Windows and Android (open via drawer on the phone).

**Pitfalls**
- Do not rebuild the `GraphModel` for display/force changes; it restarts the layout and loses positions.
- Sliders fire on every pixel; debounce persistence, not the live preview.

---

### 06.10 Local graph

**Purpose.** A graph of the active note's neighbourhood (depth 1–5), in the right sidebar and as a tab.

**Files**
- `app/lib/graph/model/local_graph.dart` (new; pure function)
- `app/lib/graph/view/local_graph_view.dart` (new)
- right-sidebar panel registration (modify the Phase 2 panel registry)
- `app/test/graph/model/local_graph_test.dart`, `app/test/graph/view/local_graph_view_test.dart` (new)

**Implementation**
1. `GraphModel buildLocalGraph(GraphModel full, int centre, GraphSettings local)`:
   ```
   depthOf = {centre: 0}; queue = [centre]
   while queue not empty:
     u = queue.removeFirst(); if depthOf[u] == local.localDepth: continue
     neighbours = (local.localOutgoing ? out(u) : []) + (local.localIncoming ? in(u) : [])
     for v in neighbours: if v not in depthOf: depthOf[v] = depthOf[u] + 1; queue.add(v)
   keep nodes in depthOf
   keep edge (a,b) if both kept and (local.localNeighbors or depthOf[a] != depthOf[b])
   ```
   `out`/`in` come from directed adjacency built from `edgeSource/edgeTarget`. The full model for the local graph is built with the
   **local** settings' filters (search, tags, attachments, existing only — orphans is ignored for local graphs) via the same builder.
   If the active tab is not a Markdown note (or the note is not in the full model), show the l10n message `localGraphNoNote`.
2. `LocalGraphView` reuses `GraphCanvas`, its own `LayoutClient` and viewport. It follows the active file tab (listen to the workspace's
   active tab; debounce 150 ms). The centre node is drawn with the `focused` colour and a ring (`drawCircle` stroke 2 px screen).
   Panel controls: a compact header with a **Depth** slider (1…5, integer) and a gear opening the same settings panel as 06.9 bound to
   the **local** scope plus three extra switches: **Incoming links**, **Outgoing links**, **Neighbor links**.
3. Placement: register a right-sidebar panel "Local graph" (icon `Icons.bubble_chart_outlined`) on desktop layout. Command
   `graph.open-local-graph` (Ctrl+Shift+G) opens a `LocalGraphTabContent` tab (desktop) or pushes a full-screen page (phone layout).
4. Clicking a node in the local graph opens that note in the **main** active pane (not inside the sidebar), which then re-centres the
   local graph.

**Tests**
- `local_graph_test.dart` on a chain A→B→C→D plus E→A: depth 1 around B → {A,B,C}; depth 2 around B → {A,B,C,D,E};
  outgoing only, depth 1 around B → {B,C}; incoming only, depth 1 around B → {A,B}.
- `neighbour links`: graph A→B, A→C, B→C; depth 1 around A → nodes {A,B,C}; with `neighborLinks: false` the edges are A→B and A→C only
  (B and C are both at depth 1, so B→C is dropped); with `neighborLinks: true` B→C is included.
- `local_graph_view_test.dart`: switching the active tab from note A to note B re-centres (fake layout client receives a new `init`);
  a non-note active tab shows `localGraphNoNote`; depth slider change rebuilds with depth 2.

**Verify**
```
cd app; flutter test test/graph; cd ..
```
Success: all pass; on Windows the sidebar local graph follows the active note; on the phone the command opens a full-screen page.

**Pitfalls**
- Each local graph instance owns a worker; dispose it when the panel is hidden, not only when the app closes.

---

### 06.11 Graph performance measurement and tuning

**Purpose.** Prove the §10-style graph budget: 10k nodes at 60 fps on Windows and 30 fps on the phone, and record the numbers.

**Files**
- `app/lib/graph/view/graph_perf_overlay.dart` (new; debug/profile only)
- `app/integration_test/graph_perf_test.dart` (new)
- `tool/gen_bench_vault.dart` (modify only if it cannot produce 10k linked notes; it should already, from Phase 0)

**Implementation**
1. Budget definition (record in `PROGRESS.md` exactly in this form):
   - Scenario: 10k-note bench vault (`dart run tool/gen_bench_vault.dart` output, ~10,000 notes, ~50,000 links), global graph,
     default settings, simulation **running** (alpha > alphaMin for the whole measurement: call `reheat(alpha: 1.0)` at start), and a
     scripted interaction of 10 s: 3 s pan, 3 s zoom in/out around the centre, 2 s hover over nodes, 2 s idle.
   - Windows pass: average frame time (build + raster, from `FrameTiming.totalSpan`) ≤ 16.7 ms **and** 90th percentile ≤ 20 ms.
   - Phone pass: average ≤ 33.3 ms **and** 90th percentile ≤ 40 ms.
   - Layout tick time (from `LayoutFrame.tickMs`): Windows mean ≤ 25 ms, phone mean ≤ 60 ms. (Rendering does not wait for ticks;
     slower ticks only make the layout settle more slowly.)
2. `GraphPerfOverlay`: shown when a debug setting `debugShowGraphPerf` (in-memory provider, toggled by a command
   `graph.toggle-perf-overlay` that is `showInPalette: kProfileMode || kDebugMode`) is on. It collects `FrameTiming`s via
   `SchedulerBinding.instance.addTimingsCallback`, and shows: fps (last 1 s), average/p90 build ms, average/p90 raster ms, node count,
   drawn node count, drawn label count, last `tickMs`.
3. `graph_perf_test.dart`: uses `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and
   `binding.traceAction(() async { ...scripted gestures via tester.timedDrag / tester.sendEventToBinding PointerScrollEvent... },
   reportKey: 'graph_10k')`; then compute the summary with `FrameTimingSummarizer` (from `package:integration_test`, or compute
   percentiles from collected `FrameTiming`s) and `expect` against the budget of the current platform (choose by `Platform.isAndroid`
   — this is measurement, not layout). It opens a vault path given by `--dart-define=TEPHRA_BENCH_VAULT=<abs path>`; if not given,
   the test is skipped with a message.
4. Run it in **profile** mode:
   `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/graph_perf_test.dart -d windows --dart-define=TEPHRA_BENCH_VAULT=D:\script\tephra-gemini\test_vaults\bench`
   (create `app/test_driver/integration_test.dart` with the standard `integrationDriver()` if missing). For Android, copy the bench vault
   to the phone (`adb push test_vaults/bench /sdcard/Documents/TephraBench`), grant all-files access, and use
   `-d <android-id> --dart-define=TEPHRA_BENCH_VAULT=/sdcard/Documents/TephraBench`.
5. Tuning order if the budget is missed (do them in this order, re-measure after each, record each result):
   1. Make sure labels are capped (300) and the label cache hit rate is > 90% (overlay shows it).
   2. Skip arrows when `scale < 0.6`.
   3. When the visible node count > 5,000, draw edges with `lw = 0.5` px in a single batch (no highlight split).
   4. Reduce positions frame rate to 20 Hz on phone layout (worker emits every 50 ms).
   5. On phone, cap the simulation to 2 ticks per frame period and stop at `alphaMin = 0.005`.
   If after all five the budget is missed by > 25%, stop and ask the human (GEMINI.md §5).

**Tests**
- The integration test itself (both platforms).
- Unit test for the percentile helper: `[1..100]` → p90 = 90.

**Verify**
```
cd app; flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/graph_perf_test.dart -d windows --dart-define=TEPHRA_BENCH_VAULT=<abs path>; cd ..
cd app; flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/graph_perf_test.dart -d <android-id> --dart-define=TEPHRA_BENCH_VAULT=/sdcard/Documents/TephraBench; cd ..
```
Success: both pass; `PROGRESS.md` has: avg/p90 frame ms, mean tick ms, per platform, device model name.

**Pitfalls**
- Debug builds are 5–10× slower; never measure in debug.
- If no real phone is connected, stop and ask the human (GEMINI.md §5) — do not record emulator numbers as the phone budget.

---

### 06.12 JSON Canvas codec (byte-exact, lossless)

**Purpose.** Read and write `.canvas` files per JSON Canvas 1.0, preserving unknown fields, key order and the original formatting,
so opening and saving without edits changes nothing, and Obsidian opens every file Tephra writes.

**JSON Canvas 1.0 essentials (the spec, summarised — implement exactly this):**
- Top level: an object with optional arrays `nodes` and `edges`. Nodes are listed in ascending z-order (first = bottom).
- Every node: `id` (string, unique), `type` (`"text"` | `"file"` | `"link"` | `"group"`), `x`, `y` (integers, px), `width`,
  `height` (integers, px), optional `color` (canvasColor).
- Text node: `text` (string, Markdown). File node: `file` (vault path string), optional `subpath` (string starting with `#`, heading
  or block). Link node: `url` (string). Group node: optional `label` (string), optional `background` (image path), optional
  `backgroundStyle` (`"cover"` | `"ratio"` | `"repeat"`).
- Edge: `id`, `fromNode`, `toNode` (node ids, required), optional `fromSide`/`toSide` (`"top"` | `"right"` | `"bottom"` | `"left"`),
  optional `fromEnd` (`"none"` | `"arrow"`, default `"none"`), optional `toEnd` (`"none"` | `"arrow"`, default `"arrow"`),
  optional `color`, optional `label`.
- canvasColor: a hex string like `"#FF0000"`, or a preset `"1"` red, `"2"` orange, `"3"` yellow, `"4"` green, `"5"` cyan, `"6"`
  purple. Exact preset colours are up to the app (ours: theme tokens `canvasColor1..6`, see 06.14).

**Obsidian's on-disk style (verified on the official sample file):** a tab-indented top-level object; each array element (node/edge)
is a compact one-line JSON object on its own line indented with two tabs; no space after colons; **no trailing newline**:
```
{
	"nodes":[
		{"id":"754a8ef995f366bc","type":"group","x":-300,"y":-460,"width":610,"height":200,"label":"JSON Canvas"},
		{"id":"8132d4d894c80022","type":"file","file":"readme.md","x":-280,"y":-200,"width":570,"height":560,"color":"6"}
	],
	"edges":[
		{"id":"6fa11ab87f90b8af","fromNode":"7efdbbe0c4742315","fromSide":"right","toNode":"59e896bc8da20699","toSide":"left"}
	]
}
```
(Tabs shown as indentation above; in the file they are `\t` characters.)

**Files**
- `packages/tephra_io/lib/src/canvas/canvas_document.dart` (new)
- `packages/tephra_io/lib/src/canvas/canvas_node.dart`, `canvas_edge.dart`, `canvas_color.dart` (new)
- `packages/tephra_io/lib/src/canvas/canvas_codec.dart` (new)
- `packages/tephra_io/lib/tephra_io.dart` (exports)
- `packages/tephra_io/test/canvas/canvas_codec_test.dart` (new)
- `test_vaults/syntax/canvas/` fixtures (new): `obsidian-style.canvas`, `pretty-2-spaces.canvas`, `minified.canvas`,
  `unknown-fields.canvas`, `empty-file.canvas` (0 bytes), `crlf-pretty.canvas`, `unicode.canvas`

**Implementation**
1. Model (immutable; every object keeps its raw JSON map, a `LinkedHashMap<String, Object?>` in original key order):
   ```dart
   enum CanvasNodeType { text, file, link, group, unknown }
   final class CanvasNode {
     const CanvasNode._(this.raw);
     final Map<String, Object?> raw;                     // unmodifiable view of the original/updated map
     String get id; CanvasNodeType get type;             // 'unknown' for other type strings (kept verbatim)
     int get x; int get y; int get width; int get height;   // num → round(); missing → 0 (and node flagged invalid)
     String? get color; String? get text; String? get file; String? get subpath; String? get url;
     String? get label; String? get background; String? get backgroundStyle;
     CanvasNode withFields(Map<String, Object?> changes);   // see item 4; a value of null removes the key
     factory CanvasNode.create({required String id, required CanvasNodeType type, required int x, required int y,
       required int width, required int height, String? color, String? text, String? file, String? subpath, String? url,
       String? label, String? background, String? backgroundStyle});  // canonical key order, item 5
   }
   final class CanvasEdge { /* same pattern: raw, id, fromNode, fromSide, fromEnd, toNode, toSide, toEnd, color, label, withFields, create */ }
   final class CanvasDocument {
     final List<CanvasNode> nodes; final List<CanvasEdge> edges;
     final Map<String, Object?> topLevelExtra;          // unknown top-level keys, original order
     final List<String> topLevelKeyOrder;               // e.g. ['nodes','edges','metadata']
     final CanvasFormat format;                         // detected on decode, reused on encode
   }
   ```
2. `CanvasFormat`:
   ```dart
   sealed class CanvasFormat { }
   final class ObsidianFormat extends CanvasFormat { }                          // the style shown above
   final class PrettyFormat extends CanvasFormat { final String indent; }        // JsonEncoder.withIndent(indent) output ('  ', '    ', '\t')
   final class MinifiedFormat extends CanvasFormat { }                          // jsonEncode output
   // plus, for all: final bool trailingNewline; final LineEnding lineEnding (lf/crlf, from TextDocument)
   ```
3. Decode (`CanvasCodec.decode(TextDocument doc) → CanvasDocument`):
   - Empty or whitespace-only text → empty document, `format = ObsidianFormat`, no trailing newline, and a flag `wasEmpty = true`.
   - `jsonDecode`; the result must be a `Map<String, Object?>`, else throw `CanvasFormatException` (new, extends `ParseException`).
   - `nodes`/`edges` must be lists of maps when present; elements that are not maps are kept in a separate `invalidElements` list and
     written back unchanged in place (store per array: list of `Object?` with typed wrappers for maps). Simplest correct approach:
     store `List<Object?> rawNodes` where each map is wrapped as `CanvasNode` and any other value is kept as-is (`CanvasRawItem`).
   - **Format detection:** compute `text` (normalised `\n`) without a final `\n` if present (`trailingNewline = true`). Then try, in
     order: `ObsidianFormat`, `PrettyFormat('\t')`, `PrettyFormat('  ')`, `PrettyFormat('    ')`, `MinifiedFormat`. For each, encode
     the decoded document with that format and compare with `text`. The first exact match is the format. If none matches, use
     `ObsidianFormat` and set `formatExact = false` (the file will be reformatted only if the user edits it).
4. `withFields(changes)`: copy `raw` into a new `LinkedHashMap` keeping every existing key in place; for each change: value `null` →
   remove key; existing key → replace value in place (order kept); new key → append at the position given by the canonical order
   (item 5): insert it right after the last existing key that precedes it in canonical order, else at the end. Numbers for
   `x, y, width, height` are always written as `int` (round half away from zero).
5. Canonical key order (used by `create` and for inserting new keys):
   - text: `id, type, text, x, y, width, height, color`
   - file: `id, type, file, subpath, x, y, width, height, color`
   - link: `id, type, url, x, y, width, height, color`
   - group: `id, type, x, y, width, height, color, label, background, backgroundStyle`
   - edge: `id, fromNode, fromSide, fromEnd, toNode, toSide, toEnd, color, label`
   - top level of a new document: `nodes, edges`
6. Encode (`CanvasCodec.encode(CanvasDocument d) → TextDocument`):
   - **ObsidianFormat:**
     ```
     out = '{\n'
     for each top-level key k in topLevelKeyOrder (index i, last = i == count-1):
       if k is 'nodes' or 'edges' and value is a list:
         if list empty: out += '\t"' + k + '":[]'
         else: out += '\t"' + k + '":[\n' + join(items.map(e => '\t\t' + jsonEncode(e)), ',\n') + '\n\t]'
       else: out += '\t' + jsonEncode(k) + ':' + jsonEncode(value)
       out += last ? '\n' : ',\n'
     out += '}'
     if document has no keys at all: out = '{}'
     ```
   - **PrettyFormat(indent):** `JsonEncoder.withIndent(indent).convert(map)`; **MinifiedFormat:** `jsonEncode(map)`.
   - Then append `\n` if `trailingNewline`; return `TextDocument(text, hasBom: original, lineEnding: original)` (§6.2 re-applies CRLF).
   - `jsonEncode` of strings matches JavaScript's `JSON.stringify` for all characters we produce (no escaping of `/` or non-ASCII,
     `\n`, `\t`, `\"`, `\\`, `\u00XX` for other control characters). Add a test for each.
7. New empty document written by Tephra (06.2, 06.13): `{nodes: [], edges: []}` in `ObsidianFormat`, no trailing newline, i.e. exactly
   `{\n\t"nodes":[],\n\t"edges":[]\n}`.
8. Validation (`CanvasDocument.validate() → List<CanvasIssue>`): duplicate ids, edges pointing to missing nodes, unknown node types,
   missing required fields. Issues are shown as a dismissible banner in the view (06.14) and **never** auto-fixed on load. Edges to
   missing nodes are not drawn but are kept and written back.
9. Fixtures: write the fixture files by hand in this step (do not copy files from other projects), covering: every node type, every
   edge field, preset and hex colours, `subpath`, group with background, Unicode text (Bangla, emoji, CJK), text with `\n`, `"`, `\`,
   tab characters, unknown keys at node, edge and top level (`"styleAttributes":{}`, `"metadata":{"version":"1.0"}`), floats
   (`"x":10.5` — kept as written because unedited), and a CRLF pretty-printed file.

**Tests** (`canvas_codec_test.dart`)
- `byte round-trip`: for every fixture, `encode(decode(bytes))` produces identical bytes (compare `List<int>`), including the 0-byte
  file (decoded as empty; the caller must not write it unless edited — test asserts `wasEmpty`).
- `format detection`: each fixture detects the expected format (`obsidian-style` → Obsidian, `pretty-2-spaces` → Pretty('  '), …).
- `unknown fields preserved after edit`: move one node in `unknown-fields.canvas` (`withFields({'x': 99})`) → the encoded output still
  contains `styleAttributes` and `metadata`, the moved node's keys are in the original order, and every other line is byte-identical.
- `new key inserted in canonical position`: node `{id,type,text,x,y,width,height}` + `color: '1'` → key appended after `height`;
  file node without subpath + `subpath: '#H'` → inserted after `file`.
- `null removes key`: `withFields({'color': null})` removes `color`.
- `ints written as ints`: `withFields({'x': 10.6})` → `"x":11`.
- `empty doc encode` equals `{\n\t"nodes":[],\n\t"edges":[]\n}`.
- `escaping matches JSON.stringify`: text `a"b\\c\nd\te\u0001` encodes as `"a\"b\\\\c\nd\te\u0001"`; `é`, `অ`, `😀` are not escaped.
- `invalid JSON throws CanvasFormatException`; `top-level array throws`; `non-map element in nodes kept and re-encoded in place`.
- `validate` reports a duplicate id and a dangling edge.

**Verify**
```
cd packages/tephra_io; dart test test/canvas; cd ../..
```
Success: all pass.

**Pitfalls**
- Dart's `jsonDecode` returns `int` for `10` and `double` for `10.0`; re-encoding keeps them distinct — good; never convert
  untouched values.
- Do not sort keys anywhere. Use `LinkedHashMap` (Dart's default `{}` map literal is a `LinkedHashMap`).
- A file node's `file` is a vault path that may contain characters like `#`; never parse it as a URL.

---

### 06.13 Canvas document controller: operations, undo/redo, saving

**Purpose.** All canvas edits go through reversible operations on an immutable document, with undo/redo, debounced atomic saves, and
external-change handling. The Phase 4 sticky board switches to the same codec.

**Files**
- `app/lib/canvas/model/canvas_ops.dart` (new)
- `app/lib/canvas/model/canvas_controller.dart` (new)
- `app/lib/canvas/model/canvas_ids.dart` (new)
- `app/lib/canvas/providers.dart` (new)
- Phase 4 sticky board files in `app/lib/stickies/` (modify: use `CanvasCodec`)
- `app/test/canvas/model/canvas_ops_test.dart`, `app/test/canvas/model/canvas_controller_test.dart` (new)

**Implementation**
1. IDs: `String newCanvasId(Random rng, Set<String> taken)` → 16 lower-case hex characters from `Random.secure()` (injected for tests),
   regenerated until not in `taken`.
2. Operations (command pattern; each has `apply(CanvasDocument) → CanvasDocument` and `CanvasOp get inverse`, computed from the document
   **before** apply):
   ```dart
   sealed class CanvasOp { CanvasDocument apply(CanvasDocument d); CanvasOp inverseFor(CanvasDocument before); }
   final class AddNodes extends CanvasOp { final List<CanvasNode> nodes; final List<int> indices; }        // insert at z-indices (ascending)
   final class RemoveNodes extends CanvasOp { final Set<String> ids; }      // inverse = Composite[AddNodes(removed, original indices), AddEdges(edges removed because they touched these nodes, original indices)]
   final class UpdateNodes extends CanvasOp { final Map<String, Map<String, Object?>> changes; }   // id → field changes; inverse holds previous values (null for keys that did not exist)
   final class ReorderNode extends CanvasOp { final String id; final int toIndex; }                  // bring to front / send to back
   final class AddEdges extends CanvasOp { final List<CanvasEdge> edges; final List<int> indices; }
   final class RemoveEdges extends CanvasOp { final Set<String> ids; }
   final class UpdateEdges extends CanvasOp { final Map<String, Map<String, Object?>> changes; }
   final class CompositeOp extends CanvasOp { final List<CanvasOp> ops; }  // inverse = reversed list of inverses
   ```
   Moves and resizes are `UpdateNodes` with `x/y/width/height` changes.
3. `CanvasController` (`Notifier` per canvas path; `NotifierProvider.family<CanvasController, CanvasState, VaultPath>`):
   ```dart
   final class CanvasState { final CanvasDocument doc; final bool dirty; final bool loading; final Object? error;
     final List<CanvasIssue> issues; final bool externalChangePending; }
   void execute(CanvasOp op);          // doc = op.apply(doc); push inverse to undo stack (cap 200, drop oldest); clear redo; schedule save
   void undo(); void redo();           // move between stacks; schedule save
   bool get canUndo; bool get canRedo;
   Future<void> saveNow();             // used on dispose / app pause / tab close
   void beginGesture(); void endGesture();   // while a drag is in progress, live updates use `preview(op)` (state only, no undo entry); endGesture commits ONE op
   void preview(CanvasDocument d);
   ```
4. Saving: debounced 1,000 ms after the last `execute`/`undo`/`redo`; encode with `CanvasCodec.encode`; **write only if the encoded
   bytes differ from the bytes last read or written** (§6.2); atomic via `VaultFileSystem.writeText`. Also save on tab close, on
   `AppLifecycleState.paused`/`inactive`, and on `dispose`.
5. Loading: read via `readText`; decode; malformed UTF-8 → open read-only with a banner (§6.2). `CanvasFormatException` → error view
   with the message and a button "Open as text" disabled (Phase 6 has no plain-text editor for non-Markdown files; show raw text
   read-only in a scrollable monospace view instead).
6. External changes: listen to `VaultFileSystem.watch()` for this path. If not dirty → reload silently (keep viewport and selection where
   ids still exist). If dirty → set `externalChangePending`; the view shows a banner: **Reload** (discard local changes after copying
   them to `.tephra/history` via the Phase 3 snapshot service) or **Keep mine** (next save overwrites).
7. Phase 4 sticky board: find its `.canvas` read/write code and replace it with `CanvasCodec` + `withFields`, so unknown fields added by
   Obsidian survive. Keep the board's own behaviour. Re-run the Phase 4 sticky tests.

**Tests**
- `canvas_ops_test.dart`: for each op type, `inverse.apply(op.apply(d)) == d` (compare encoded bytes) on the `unknown-fields` fixture;
  `RemoveNodes` restores connected edges at their original indices; `UpdateNodes` inverse removes keys that did not exist before;
  `CompositeOp` inverse order; `ReorderNode` inverse.
- `canvas_controller_test.dart` (with `MemoryVaultFileSystem`, fake async): open + no edit → zero writes after 5 s; move + undo →
  zero writes (bytes equal original); 3 moves within 500 ms → one write; undo stack capped at 200; external change while clean →
  reloaded; external change while dirty → `externalChangePending` true and no write until the user chooses; drag gesture with 30
  previews → one undo entry.
- Phase 4 sticky board tests still pass.

**Verify**
```
cd app; flutter test test/canvas test/stickies; cd ..
```
Success: all pass.

**Pitfalls**
- Undo after save must still work (the stacks are in memory and independent of saving).
- Never write a canvas just because it was opened or because the viewport moved; the viewport is not part of the file.

### 06.14 Canvas rendering

**Purpose.** Show a canvas: infinite board, grid, groups, cards with real content, Bézier edges with arrows and labels, with level of
detail so large boards stay smooth.

**Files**
- `app/lib/canvas/view/canvas_view.dart` (new: tab body for `.canvas` files)
- `app/lib/canvas/view/canvas_viewport.dart` (new; same API as `GraphViewport` — copy the class shape, do not share state)
- `app/lib/canvas/view/canvas_background_painter.dart` (new: grid + groups + edges + LOD cards)
- `app/lib/canvas/view/canvas_overlay_painter.dart` (new: selection, handles, guides, rubber band — used in 06.15)
- `app/lib/canvas/view/edge_geometry.dart` (new; pure Dart)
- `app/lib/canvas/view/nodes/text_card.dart`, `file_card.dart`, `link_card.dart`, `group_label.dart` (new)
- `app/lib/canvas/view/link_preview_service.dart` (new)
- `app/lib/canvas/view/canvas_colors.dart` (new)
- `app/test/canvas/view/edge_geometry_test.dart`, `app/test/canvas/view/canvas_view_test.dart`, `app/test/canvas/view/link_preview_service_test.dart` (new)

**Implementation**
1. **Layers** (bottom to top), decided: (1) background painter: dot grid, then **all group nodes** (array order), then edges;
   (2) non-group node widgets in array order; (3) overlay painter (screen space). Decision: groups always render below other nodes
   and edges above groups (this matches how Obsidian displays canvases); among non-group nodes the array order is the z-order (spec).
2. Grid: dots every 20 world units, drawn only when `scale >= 0.5` (every 100 units between 0.2 and 0.5, none below 0.2), colour
   `canvasGrid` (Phase 7 token; now `colorScheme.outlineVariant` at 50% alpha). Draw with one `drawRawPoints` call over the visible rect.
3. Colours (`CanvasColors`): preset `"1"`…`"6"` → red `#E5534B`, orange `#E8912D`, yellow `#D9B30F`, green `#3FB950`, cyan `#2DA8B8`,
   purple `#8E6CEF` (Phase 7 moves these into theme tokens `canvasColor1..6`); hex `#RGB`/`#RRGGBB` parsed; anything else → no colour.
   Card border: 2 px (screen) in the node colour, or `colorScheme.outlineVariant` if none; card fill: `colorScheme.surface` blended with
   the node colour at 8% alpha. Group: border 2 px node colour (or outline), fill node colour at 6% (or `surfaceContainerLow` at 50%).
4. **Node widgets.** A `Transform` with the viewport matrix wraps a `Stack` of `Positioned` widgets in world coordinates (one per
   visible non-group node; culled by the visible world rect inflated by 200 units). Each card is a `RepaintBoundary` with a fixed
   `SizedBox(width, height)` and `ClipRRect(radius 8)`.
   - **Text card** (`TextCard`): renders `text` with the reading-view block builder in **non-lazy** mode (a `Column` of block widgets
     inside a `SingleChildScrollView`; scrolling enabled only when the card is selected, see 06.15), padding 12, using a provider that
     parses the text with `MarkdownParser.parse` (memoised by text hash). Links inside work (tap opens).
   - **File card** (`FileCard`) by `viewKindFor(file)`: `markdown` → header with the note name (tap opens the note), body = reading view
     of the note (non-lazy, scroll only when selected); if `subpath` is `#Heading`, render only that section (from the heading to the next
     heading of the same or higher level); if `#^blockid`, only that block; missing heading → whole note plus a small warning line.
     `image` → `Image` (`BoxFit.contain`, `cacheWidth` = card width × device pixel ratio), SVG via `SvgPicture`. `pdf` → first page
     (or `#page=N` from subpath) via `pdfrx`'s page widget (06.22 builds `PdfPageThumbnail`; until then show a PDF icon + name).
     `audio`/`video` → compact player (06.23; until then icon + name). `canvas`/`base`/other → icon + file name. File not found →
     card with a broken-link icon and the path, in the error colour.
   - **Link card** (`LinkCard`): favicon (16 px) + page title (bold, 2 lines max) + host (muted). Click/tap opens the URL in the system
     browser via `url_launcher` (`LaunchMode.externalApplication`). No WebView on the board (decided: performance and security).
   - **Group label** (`GroupLabel`): drawn as a widget above the group's top-left corner (outside the rect, 4 px gap), font 14,
     semi-bold, colour = group colour or `onSurfaceVariant`. Group `background` image: painted inside the group rect by the background
     painter, with `backgroundStyle`: `cover` → `BoxFit.cover`, `ratio` → `BoxFit.contain` keeping aspect, `repeat` → tiled at natural
     size; images loaded once via `ImageStream` and cached by path.
5. **Level of detail.** When `scale < 0.35`, do not build node widgets at all; the background painter draws every non-group node as a
   rounded rect (fill + border) with its first line of text / file name as a single `TextPainter` label if `scale >= 0.15`.
   Switching LOD must not lose selection or editing state (editing forces widget mode for the edited node only).
6. **Edge geometry** (`edge_geometry.dart`):
   ```
   anchor(rect, side): top → (x + w/2, y); right → (x + w, y + h/2); bottom → (x + w/2, y + h); left → (x, y + h/2)
   normal(side): top → (0,-1); right → (1,0); bottom → (0,1); left → (-1,0)
   if fromSide or toSide missing: choose the missing side(s) from the 4 (or 16 when both missing) combinations minimising
       distance(anchor(from, fs), anchor(to, ts)); ties broken in the order top, right, bottom, left
   p0 = anchor(from, fs); p3 = anchor(to, ts); d = distance(p0, p3)
   k = clamp(d * 0.5, 40, 250)
   p1 = p0 + normal(fs) * k; p2 = p3 + normal(ts) * k
   curve = cubic Bézier p0, p1, p2, p3
   arrow at end if toEnd != 'none' (default arrow): tip = p3, direction = normalise(p3 - p2) (if zero, -normal(ts)),
       length 12 world units, half-width 6; at start if fromEnd == 'arrow' (default none): tip = p0, direction = normalise(p0 - p1)
   label: at B(0.5); drawn centred in a rounded rect (padding 4×2, radius 4, fill surface, border outlineVariant)
   hit test: sample 32 points along the curve; distance from the pointer to each segment ≤ 6 screen px → hit
   ```
   Edges are stroked 2 px (screen) in the edge colour or `onSurfaceVariant`; arrowheads filled. Draw all edges as `Path`s in the
   background painter (edges count on real canvases is small; no batching needed).
7. **Link previews** (`LinkPreviewService`): for each link node URL, fetch once: `http.get` with 5 s timeout, `User-Agent: Tephra`,
   only `http`/`https`, read at most 512 KB, parse with `package:html`: title = `og:title` meta content, else `<title>` text, else host;
   icon = first `<link rel~="icon">` href resolved against the URL, else `<origin>/favicon.ico`. Download the icon (≤ 64 KB) and store it
   base64 in the cache. Cache file `.tephra/cache/link-previews.json`: `{ "<url>": { "title": "...", "icon": "<base64 or null>",
   "fetchedAt": ISO } }`; entries older than 30 days are refetched. Failures cache `{"title": null}` for 1 day. The fetch is skipped when
   the vault setting `canvas.fetchLinkPreviews` (bool, default `true`; add to vault settings now) is false. Never send cookies.
8. Initial viewport: if the controller has a remembered viewport for this path in memory (per session), use it; otherwise zoom to fit all
   nodes (padding 60) capped at scale 1.0. Empty canvas → scale 1, origin centred, and an empty-state hint
   `canvasEmptyHint` ("Double-click (or double-tap) to add a card").
9. Banners at the top of the view: validation issues (06.12 item 8), read-only (malformed UTF-8), external change (06.13 item 6).

**Tests**
- `edge_geometry_test.dart`: anchors for all sides; auto side choice for two rects side by side horizontally → `right`→`left`;
  vertically stacked → `bottom`→`top`; control distance clamps at 40 and 250; arrow direction at the end equals the curve tangent;
  hit test true at B(0.5), false 20 px away.
- `canvas_view_test.dart` (widget, `MemoryVaultFileSystem` with fixtures): opens `obsidian-style.canvas` → finds the group label text
  "JSON Canvas" and one card per non-group node; at scale 0.2 no `TextCard` widgets exist (LOD); a file node pointing to a missing file
  shows the broken-link card; golden `goldens/canvas_basic.png` (800×600, `@Tags(['golden'])`) of a canvas with one text card, one
  group, one edge with label and arrow.
- `link_preview_service_test.dart` with a `MockClient` (`package:http/testing.dart`): extracts `og:title` over `<title>`; resolves a
  relative icon href; times out → cached failure; setting off → no request made.

**Verify**
```
cd app; flutter test test/canvas; cd ..
```
Open a canvas made in Obsidian (or the fixture) on Windows and Android: all node types render; zooming out switches to rectangles
smoothly. Success: tests pass and manual check done on both platforms.

**Pitfalls**
- Do not put a lazy `ListView` inside a card; use the non-lazy block builder (cards are small).
- `Transform` scales text as vectors; do not pre-render cards to images.

---

### 06.15 Canvas editing and input

**Purpose.** Create, select, move, resize, connect, edit, copy/paste, delete, undo/redo, snap and align — with mouse/keyboard on Windows
and touch on Android.

**Files**
- `app/lib/canvas/view/canvas_input.dart` (new: central pointer handling state machine)
- `app/lib/canvas/view/canvas_hit_test.dart` (new; pure Dart geometry)
- `app/lib/canvas/view/canvas_snapping.dart` (new; pure Dart)
- `app/lib/canvas/view/canvas_toolbar.dart` (new)
- `app/lib/canvas/view/canvas_clipboard.dart` (new)
- `app/lib/canvas/view/card_editor.dart` (new)
- `app/lib/canvas/commands.dart` (new)
- `app/test/canvas/view/canvas_hit_test_test.dart`, `canvas_snapping_test.dart`, `canvas_input_test.dart`, `canvas_clipboard_test.dart` (new)

**Implementation**
1. **Selection state** (in the view's state, not in the file): `Set<String> selectedNodes`, `Set<String> selectedEdges`,
   `String? editingNode`, `String? editingEdgeLabel`.
2. **Central input.** One `Listener` (raw pointer events) wraps the whole board and implements a state machine; node content widgets are
   wrapped in `IgnorePointer` **except** the node being edited (its editor) and the content area (rect inset by 12 screen px) of a
   **single selected** node (so its content can scroll and its links can be tapped). Pointer-downs inside that content area are ignored
   by the central handler.
   Hit-test order (`canvas_hit_test.dart`, all in world coordinates with screen-px tolerances divided by scale): (1) resize handles of the
   single selected node (8 handles, 8 px square, 12 px tolerance on desktop, 24 px on phone layout); (2) connection handles (4 side
   midpoints, circles radius 6 px, tolerance 12/24 px) of the hovered or selected node; (3) non-group nodes, topmost first; (4) edge
   labels, then edges (06.14 item 6); (5) group label areas, then group rects (only their 24 px border band and label, so clicks inside a
   group's empty interior go to the board); (6) empty board.
3. **Mouse/desktop gestures**
   | Input | On | Result |
   |---|---|---|
   | Left click | node | select it (Shift/Ctrl: toggle in selection) |
   | Left click | edge | select edge |
   | Left click | empty | clear selection, stop editing |
   | Left drag | node (selected or not) | move selection (select the node first if unselected) |
   | Left drag | empty | rubber-band select (nodes whose rects intersect the band; Shift adds) |
   | Left drag | resize handle | resize (Shift keeps aspect ratio; min 50×30) |
   | Left drag | connection handle | draw a new edge; drop on a node → edge to that node's nearest side to the pointer; drop on empty → create a 250×60 text card centred at the pointer, connect to its nearest side, start editing it |
   | Double click | empty | create text card 250×60 centred at pointer; start editing |
   | Double click | text card | start editing |
   | Double click | file card (note) | open the note in a new tab |
   | Double click | edge | edit label |
   | Middle drag, or Space + left drag | anywhere | pan |
   | Wheel | anywhere except selected card content | pan vertically (Shift: horizontally) by `delta` |
   | Ctrl + wheel, trackpad pinch | anywhere | zoom at pointer, factor `exp(-dy/300)` |
   | Right click | node / edge / empty | context menu (item 8) |
   Moving a **group** also moves every node whose rect lies fully inside the group rect at drag start (computed once at drag start).
4. **Touch/phone gestures** (and touch on Windows touchscreens)
   | Input | On | Result |
   |---|---|---|
   | Tap | node / edge | select (replaces selection) |
   | Tap | empty | clear selection |
   | Double tap | empty | create text card and edit |
   | Double tap | text card | edit |
   | Drag (one finger) | selected node | move selection |
   | Drag (one finger) | unselected node or empty | pan |
   | Long press | empty, then drag | rubber-band select |
   | Long press | node / edge | select it and open the context menu |
   | Two-finger pinch/pan | anywhere | zoom and pan around the focal point |
   | Drag | handles of the selected node (24 px tolerance) | resize / connect |
   Implement tap / double-tap (≤ 300 ms, ≤ 24 px apart) / long-press (500 ms, moved < 8 px) recognition inside the state machine from raw
   events (not with nested `GestureDetector`s, to avoid arena conflicts with the content widgets).
5. **Snapping** (`canvas_snapping.dart`):
   ```
   grid = 20 world units; enabled by the canvas toolbar toggle (in-memory per session, default ON); holding Alt disables while dragging
   moving: candidate = original + pointer delta (world)
     guides: for the moving selection's bbox edges {left, centreX, right} and {top, centreY, bottom}, compare with the same 3 lines of
       every other visible node (not in the selection); best match per axis with |diff| ≤ 6 / scale → snap that axis and record a guide
       line spanning both boxes
     axes not snapped by a guide snap to the grid if enabled (top-left corner rounded to the nearest multiple of 20)
   resizing: the moving edges snap to guides first, then to the grid
   ```
   Guides are drawn by the overlay painter as 1 px accent-colour lines during the drag only.
6. **Card editor** (`CardEditor`): for text cards, an editor occupying the card rect (in world space inside the Transform). Use the
   app's editor widget in Source mode if `EditorController` can be created for an in-memory string (check its constructor; it may take a
   `TextDocument` or a `String`); otherwise use a multiline `TextField` with the editor's monospace style. Record which in `PROGRESS.md`.
   Commit (one `UpdateNodes` op with the new `text`) on: Esc, click outside, or switching selection. If the text is unchanged → no op.
   A new card created by double-click that is committed empty is removed (and the create+remove produce no undo entry).
   Edge label editing: a `TextField` at the label position; empty → remove the `label` key.
7. **Clipboard** (`canvas_clipboard.dart`): Copy/Cut put a JSON Canvas fragment on the system clipboard as plain text:
   `{"nodes":[...selected nodes...],"edges":[...edges whose both ends are selected...]}` (compact `jsonEncode`). Paste:
   - text that decodes to a map with a `nodes` list → paste with **new ids** for nodes and edges (edges remapped), positions offset so the
     pasted bbox's top-left lands at the pointer (or +30,+30 from the original if pasted via keyboard with the pointer outside);
   - other plain text → one text card 400 wide, height estimated (20 px per line, min 60, max 400) at the pointer;
   - image data (via the Phase 1 clipboard package) → save as attachment exactly like the editor does (§6.7, `Pasted image
     YYYYMMDDHHmmss.png`) and add a file node 400×(aspect) at the pointer;
   - a URL alone (`^https?://\S+$`) → link node 400×200.
   Paste is one undoable op.
8. **Context menus** (desktop right-click / phone long-press), items:
   - Node: Edit (text cards), Open (file cards), Open link (link cards), Colour ▸ (None, 1–6 with swatches, Custom… hex dialog),
     Bring to front, Send to back, Duplicate, Delete, Create group from selection (when ≥ 1 selected).
   - Edge: Edit label, Colour ▸, Arrow ▸ (None, Forward [toEnd arrow], Backward [fromEnd arrow], Both), Delete.
   - Empty: Add card, Add note from vault…, Add media from vault…, Add web link…, Add group, Paste.
9. **Toolbar** (`CanvasToolbar`, bottom-centre floating, icons with tooltips/semantics): Add card, Add note from vault (opens the quick
   switcher in "pick file" mode filtered to `.md`), Add media from vault (same, filtered to image/pdf/audio/video), Add web link (URL
   dialog), Add group, Snap to grid toggle, Zoom out, Zoom to fit, Zoom in, Undo, Redo. New nodes from the toolbar are placed at the
   viewport centre, offset by +30,+30 per consecutive add. "Add group" around a selection: rect = selection bbox inflated by 40, label
   `Group`, inserted in the node array **before** the first selected node so it renders below them.
10. **Keyboard** — every item is a command (§7.8) in `app/lib/canvas/commands.dart`, `isAvailable` = active tab is a canvas and no text
    field has focus (except Esc):
    | Command id | Default shortcut | Action |
    |---|---|---|
    | `canvas.delete-selection` | Delete, Backspace | delete selected nodes and edges |
    | `canvas.select-all` | Ctrl+A | select all nodes |
    | `canvas.copy` / `canvas.cut` / `canvas.paste` | Ctrl+C / Ctrl+X / Ctrl+V | clipboard (item 7) |
    | `canvas.duplicate-selection` | Ctrl+D | duplicate selection +30,+30 with new ids |
    | `canvas.undo` / `canvas.redo` | Ctrl+Z / Ctrl+Shift+Z and Ctrl+Y | undo / redo |
    | `canvas.zoom-to-fit` | Shift+1 | fit all nodes |
    | `canvas.zoom-to-selection` | Shift+2 | fit selection |
    | `canvas.zoom-in` / `canvas.zoom-out` | Ctrl+= / Ctrl+- | ×1.2 / ÷1.2 at viewport centre |
    | `canvas.zoom-reset` | Ctrl+0 | scale 1.0 keeping the centre |
    | `canvas.edit-selected` | Enter | edit the single selected text card / open file card |
    | `canvas.group-selection` | Ctrl+Alt+G | create group around selection |
    | `canvas.toggle-snap` | (none) | toggle snap to grid |
    | `canvas.add-text-card` / `canvas.add-note-card` / `canvas.add-media-card` / `canvas.add-link-card` / `canvas.add-group` | (none) | toolbar actions |
    | (local, not commands) | Arrow keys / Shift+Arrow | nudge selection by 1 / 10 world units (one op per key press) |
    | (local) | Esc | stop editing, else clear selection |
    **How these shortcuts are bound (decided):** the canvas commands are registered in the command registry with
    `defaultShortcuts: const []` (so the global hotkey map has no conflicts with editor commands that use Ctrl+A/C/V/Z/D). The shortcuts
    in the table are bound **locally** by a `Shortcuts` + `Actions` widget wrapping the canvas view, whose actions call the commands by
    id through the registry. The hotkeys settings screen lists them in a read-only "Canvas" section (l10n `hotkeysCanvasSection`).
    The palette still lists every canvas command (available only while a canvas tab is active).
11. Every operation goes through `CanvasController.execute` (06.13); drags/resizes use `beginGesture` / `preview` / `endGesture`.

**Tests**
- `canvas_hit_test_test.dart`: handle beats node; topmost of two overlapping nodes wins; click inside a group's interior hits the board;
  edge hit near the curve.
- `canvas_snapping_test.dart`: grid snap rounds to 20; guide snap aligns left edges within 6 px/scale and returns a guide line; guide wins
  over grid on that axis; Alt disables.
- `canvas_input_test.dart` (widget tests on a small canvas): double-click empty creates a card and an editor appears; typing + Esc commits
  one op; Esc on an empty new card leaves no node and no undo entry; drag moves the node by the delta (snapped); rubber band selects two
  of three nodes; drag from a connection handle onto another node creates an edge with `toSide` = nearest side; drag a group moves its
  contained card; Delete removes selection and connected edges; Ctrl+Z restores both; touch: double-tap creates, long-press opens the
  context menu, one-finger drag on empty pans, pinch zooms.
- `canvas_clipboard_test.dart`: copy two connected nodes then paste → 2 new nodes + 1 edge with new ids remapped; plain text paste → text
  card; URL paste → link node.
- Round-trip after editing: edit one text card in the `unknown-fields` fixture via the UI, save, then decode the written file: unknown
  fields still present and every untouched node line byte-identical to the original.

**Verify**
```
cd app; flutter test test/canvas; cd ..
```
Manual on Windows and Android: build a canvas with each node type, connect, group, undo/redo, close and reopen; then open the file in
Obsidian (if installed on the Windows machine; otherwise mark "not verified in Obsidian" in `PROGRESS.md`) — it displays correctly.
Success: tests pass; manual checks recorded.

**Pitfalls**
- Raw `Listener` receives events even if a child also handles them; the "ignore pointer-downs inside the selected node's content area"
  rule prevents double handling.
- Keep the file's node order stable when moving nodes; only "Bring to front"/"Send to back" reorder.

---

### 06.16 Bases document model with lossless YAML edits

**Purpose.** Read `.base` files into a typed model while keeping the original text for `yaml_edit`, so Tephra's edits change only the
touched keys and unknown keys survive.

**Bases syntax subset supported** (read Obsidian's public help pages "Bases syntax" and "Functions" at
`https://obsidian.md/help/bases/syntax` and `https://obsidian.md/help/bases/functions` **at implementation time** and implement this
subset; if the help pages show different key names than below, follow the help pages and record the difference in `PROGRESS.md`):
- Top-level keys: `filters`, `formulas`, `properties`, `summaries` (preserved, not evaluated), `views`. Any other key: preserved.
- `filters`: either a single expression string, or a map with exactly one of `and` / `or` / `not`, whose value is a list of filters
  (strings or nested maps). `not` = none of the children is true. Global filters AND view filters.
- `formulas`: map `name → expression string`; referenced as `formula.name`.
- `properties`: map `propertyId → { displayName: string, ... }` (other keys preserved).
- `views`: list of maps: `type` (`table` | `cards` supported; any other type is shown as unsupported but preserved), `name`, `limit`
  (int), `filters`, `order` (list of property ids = visible columns, in order), `sort` (list of `{property, direction: ASC|DESC}`),
  `groupBy` (`{property, direction}`), `columnSize` (map property id → int px, table only), `image` (property id, cards only),
  `cardSize` (number, cards only), `imageFit` (`cover` | `contain`, cards only), `imageAspectRatio` (number, cards only). Other view keys
  preserved.
- Property ids: `file.<field>`, `note.<name>`, `formula.<name>`, or a bare `<name>` (= `note.<name>`).

**Files**
- `packages/tephra_search/lib/src/bases/base_document.dart` (new)
- `packages/tephra_search/lib/src/bases/base_filter.dart` (new)
- `packages/tephra_search/lib/src/bases/base_view.dart` (new)
- `packages/tephra_search/lib/src/bases/base_editor.dart` (new: lossless edits)
- `packages/tephra_search/lib/tephra_search.dart` (exports)
- `packages/tephra_search/pubspec.yaml` (add `yaml` and `yaml_edit` with `dart pub add yaml yaml_edit` if not present)
- `packages/tephra_search/test/bases/base_document_test.dart`, `base_editor_test.dart` (new)
- `test_vaults/syntax/bases/` fixtures (new): `simple.base`, `nested-filters.base`, `formulas.base`, `cards.base`, `unknown-keys.base`,
  `comments-and-quotes.base`, `unsupported-view.base`, `empty.base` (0 bytes), `invalid.base`

**Implementation**
1. Model:
   ```dart
   sealed class BaseFilter { }
   final class FilterExpr extends BaseFilter { final String source; }           // parsed later (06.17); parse errors kept per filter
   final class FilterAnd extends BaseFilter { final List<BaseFilter> children; }
   final class FilterOr extends BaseFilter { final List<BaseFilter> children; }
   final class FilterNot extends BaseFilter { final List<BaseFilter> children; }
   final class BaseSort { final String property; final bool descending; }
   final class BaseView {
     final int index; final String type; final String name; final int? limit; final BaseFilter? filters;
     final List<String> order; final List<BaseSort> sort; final BaseSort? groupBy;
     final Map<String, int> columnSize; final String? image; final double? cardSize; final String? imageFit; final double? imageAspectRatio;
     final Map<String, Object?> raw;   // full decoded map, for unknown keys
     bool get isSupported => type == 'table' || type == 'cards';
   }
   final class BaseDocument {
     final String sourceText;                                 // exactly as read (normalised \n per §6.2)
     final BaseFilter? filters; final Map<String, String> formulas;
     final Map<String, String> displayNames;                  // propertyId → displayName
     final List<BaseView> views; final List<BaseIssue> issues;
     static BaseDocument parse(String text);                  // never throws for semantic problems; collects issues
   }
   ```
   Parsing uses `package:yaml` `loadYaml`. Empty text → document with zero views and an issue `noViews`; the view shows a default table
   of all notes **in memory only** (nothing is written unless the user changes something). YAML syntax error → `BaseFormatException`
   (new, extends `ParseException`) with line/column.
   Property id normalisation: a bare `name` becomes `note.name` **for evaluation only**; the stored strings are never rewritten.
2. Lossless edits (`BaseEditor`), all through `YamlEditor(sourceText)`:
   ```dart
   final class BaseEditor {
     BaseEditor(String sourceText);
     void setViewSort(int viewIndex, List<BaseSort> sort);          // writes [{property: x, direction: ASC}] or removes 'sort' when empty
     void setViewOrder(int viewIndex, List<String> order);
     void setColumnSize(int viewIndex, String propertyId, int px);
     void setViewName(int viewIndex, String name);
     void addView(String type, String name);                         // appends {type, name}; creates 'views' if missing
     void removeView(int viewIndex);
     void setFiltersYaml(List<Object> path, String yamlFragment);    // replaces the 'filters' node at path (['filters'] or ['views', i, 'filters']) with the parsed fragment; empty fragment removes the key
     String get text;                                                // result
     bool get changed;                                               // text != original
   }
   ```
   Writes happen in the view controller (06.19) only when `changed`, atomically, preserving BOM/line endings (§6.2).
3. Unknown keys, comments, quoting style and key order of untouched nodes are preserved by `yaml_edit`. New maps written by Tephra use
   block style (`yaml_edit` default for new nodes on block parents).

**Tests**
- `base_document_test.dart`: parse each fixture: counts of views, filters tree shape (`nested-filters.base` → And[Expr, Or[Expr, Not[Expr]]]),
  formulas map, displayNames, `cards.base` → `image == 'note.cover'`; `unsupported-view.base` → `isSupported false` and raw keys kept;
  `empty.base` → zero views + `noViews` issue; `invalid.base` → `BaseFormatException` with line number.
- `base_editor_test.dart`: `setViewSort` on `comments-and-quotes.base` changes only the sort lines (diff of old vs new text touches only
  lines inside view 0); comments remain; `setColumnSize` adds `columnSize` map under the view; `removeView` then `addView` keeps top-level
  keys; an editor with no calls → `changed == false` and `text` identical; unknown top-level key `myPluginKey` survives every edit.

**Verify**
```
cd packages/tephra_search; dart test test/bases; cd ../..
```
Success: all pass.

**Pitfalls**
- `yaml_edit` throws on some flow-style collections when editing inside them; catch `YamlException`/`ArgumentError` from it, show
  "This change cannot be saved without reformatting the file" (l10n `basesEditUnsupported`) and do not write.
- Do not use `yaml`'s `toString` to write YAML; only `yaml_edit`.

---

### 06.17 Bases expression language

**Purpose.** Tokenize, parse (Pratt) and evaluate Bases expressions over a row context, with the function library listed below.

**Files** (all pure Dart in `packages/tephra_search/lib/src/bases/expr/`)
- `token.dart`, `lexer.dart`, `ast.dart`, `parser.dart`, `value.dart`, `evaluator.dart`, `functions.dart`, `durations.dart`, `moment_format.dart`
- `packages/tephra_search/test/bases/expr/lexer_test.dart`, `parser_test.dart`, `evaluator_test.dart`, `functions_test.dart` (new)

**Implementation**
1. **Tokens:** numbers (`12`, `3.5`, `.5` not allowed), strings in `'…'` or `"…"` with escapes `\\ \' \" \n \t`, identifiers
   `[A-Za-z_][A-Za-z0-9_]*`, keywords `true false null`, regex literal `/…/flags` (only where an operand is expected; flags `gimsu`),
   operators `+ - * / % == != < <= > >= ! && || ( ) [ ] , .`. Whitespace ignored. Errors carry the offset.
2. **Grammar** (Pratt; binding powers low → high):
   | Level | Operators | Assoc |
   |---|---|---|
   | 1 | `\|\|` | left |
   | 2 | `&&` | left |
   | 3 | `==` `!=` | left |
   | 4 | `<` `<=` `>` `>=` | left |
   | 5 | `+` `-` | left |
   | 6 | `*` `/` `%` | left |
   | 7 (prefix) | `!` `-` | right |
   | 8 (postfix) | `.name`, `.name(args)`, `(args)` call, `[expr]` index | left |
   Primary: literal, identifier, `(expr)`, list literal `[a, b, …]`.
3. **AST** (sealed): `NumLit, StrLit, BoolLit, NullLit, RegexLit, ListLit, Ident(name), Member(target, name), Call(callee, args)`
   (callee is `Ident` for globals or `Member` for methods), `Index(target, index)`, `Unary(op, operand)`, `Binary(op, left, right)`.
4. **Values** (sealed `BValue`): `BNull, BBool, BNum(double), BStr, BDate(DateTime, bool hasTime), BDuration(int ms, int months)`
   (months kept separately so `"1M"` adds calendar months), `BList(List<BValue>)`, `BObject(Map<String, BValue>)`, `BLink(VaultPath? path,
   String raw, String? display)`, `BFile(FileRef)`, `BRegex(RegExp)`, `BImage(String source)`, `BError(String message)`.
   Truthiness: null/false/0/NaN/''/empty list/empty object → false; error → false; everything else true.
5. **Row context:**
   ```dart
   final class BaseRowContext {
     final FileRef file;                         // path, name, basename, ext, folder, size, ctime, mtime, tags, links, embeds, properties
     final Map<String, Object?> properties;      // frontmatter (YAML-decoded)
     final Map<String, String> propertyTypes;    // from .tephra/types.json ('date', 'datetime', 'number', ...)
     final FileRef? thisFile;                    // the base file, or the embedding note for ```base blocks
     final BaseDatasetIndex dataset;             // for backlinks, file(), link resolution: name → path map, reverse link map
     final DateTime now;                         // injected (Clock) — same value for the whole run
   }
   ```
   Identifier resolution: `file` → `BFile(row.file)`; `note` → `BObject(properties)`; `formula` → formula accessor (memoised per row,
   cycle detection with an in-progress set → `BError('Circular formula: x')`); `this` → `BFile(thisFile)` (or null); a global function
   name followed by `(` → function; any other identifier → note property `name` (missing → `BNull`). `note["my prop"]` via Index.
   YAML → value conversion: num → BNum; bool → BBool; string → if the property type is `date`/`datetime` or the string matches
   `^\d{4}-\d{2}-\d{2}([ T]\d{2}:\d{2}(:\d{2})?)?$` **and** the type registry says date/datetime → BDate, else if it matches
   `^\[\[(.+?)(\|(.+))?\]\]$` → BLink (resolved via the dataset), else BStr; list → BList; map → BObject; null → BNull.
6. **Operators:**
   - `==`/`!=`: same kind compare by value (num numeric, str exact, bool, date instant, link/file by path, list element-wise); link vs file
     compare paths; str vs date: parse the string as date then compare; otherwise not equal.
   - `< <= > >=`: num/num, str/str (`compareTo`), date/date, date/str (parsed); other combos → false.
   - `+`: num+num; str + any → concatenation with `toString` of the other; date + duration / date + str(duration) → date; duration + duration.
     `-`: num−num; date − duration/str(duration) → date; date − date → BNum(milliseconds). `* / %`: num only (÷0 → `BError`).
   - `&&`/`||`: short-circuit, return BBool of truthiness. `!x` → BBool(!truthy). Unary `-` num only.
   - Any operator with a `BError` operand returns that error. With `BNull`: arithmetic → null; comparisons → false except `null == null`.
7. **Durations** (`durations.dart`): string like `"1d"`, `"2 weeks"`, `"1M"`, `"3h 30m"`, `"-1y"`: sequence of `<number><spaces?><unit>`,
   units: `y year years` (12 months), `M month months` (months), `w week weeks`, `d day days`, `h hour hours`, `m minute minutes`,
   `s second seconds` (case-sensitive for `M` vs `m`; long forms case-insensitive). Adding months uses calendar arithmetic (clamp the day
   to the month's length).
8. **Functions** (implement exactly these; anything else → `BError('Unknown function: name')`):
   - Global: `if(cond, then, else?)` (lazy branches), `now()`, `today()`, `date(string)` (`YYYY-MM-DD` or `YYYY-MM-DD HH:mm[:ss]`),
     `duration(string)`, `number(any)` (bool → 1/0, numeric string → num, date → ms since epoch, else error), `list(any)`,
     `link(path or file, display?)`, `file(path or link)`, `image(path or url)`, `max(n, …)`, `min(n, …)`.
   - Any value: `isTruthy()`, `isType(name)` (`'null','boolean','number','string','date','duration','list','object','link','file'`),
     `toString()`.
   - Date fields `year month day hour minute second millisecond`; methods `date()`, `time()` (`HH:mm:ss`), `format(momentFormat)`,
     `relative()` ("3 days ago" / "in 2 hours", English, via l10n-free plain strings in the package — the app may re-render), `isEmpty()`
     (false).
   - String field `length`; methods `contains(s)`, `containsAll(…)`, `containsAny(…)`, `startsWith(s)`, `endsWith(s)`, `isEmpty()`,
     `lower()`, `title()`, `trim()`, `replace(patternOrRegex, replacement)` (string pattern replaces all occurrences; regex supports `$1`),
     `repeat(n)`, `reverse()`, `slice(start, end?)`, `split(separatorOrRegex, n?)`.
   - Number methods: `abs()`, `ceil()`, `floor()`, `round(digits?)`, `toFixed(n)`, `isEmpty()`.
   - List field `length`; methods `contains(v)`, `containsAll(…)`, `containsAny(…)`, `isEmpty()`, `join(sep)`, `reverse()`,
     `slice(start, end?)`, `sort()`, `unique()`, `flat()`, `filter(expr)`, `map(expr)` — inside `filter`/`map` the identifiers `value`
     and `index` are bound to the element and its position (the argument is evaluated lazily per element).
   - Link methods: `asFile()`, `linksTo(file)`.
   - File fields `name basename path folder ext size properties tags links embeds backlinks ctime mtime`; methods `asLink(display?)`,
     `hasLink(fileOrPath)`, `hasProperty(name)`, `hasTag(tag, …)` (any of; case-insensitive; `#` optional; nested: `hasTag("a")` is true
     for `a/b`), `inFolder(folder)` (folder or any subfolder; `""` or `"/"` = vault root → true).
   - Object methods: `isEmpty()`, `keys()`, `values()`. Regex method: `matches(string)`.
   - Not implemented (return `BError('Not supported in Tephra yet: name')`): `escapeHTML`, `html`, `icon`, `random`, `list.reduce`.
9. **Moment format subset** (`moment_format.dart`): `YYYY YY MMMM MMM MM M DD D dddd ddd HH H hh h mm m ss s A a` and `[literal]`;
   other letters are copied literally.
10. Public entry points:
    ```dart
    abstract final class BaseExpr { static Expr parse(String source); }       // throws BaseExprSyntaxException (extends ParseException) with offset
    final class BaseEvaluator { BValue eval(Expr e, BaseRowContext row, Map<String, Expr> formulas); }
    String displayValue(BValue v);                                             // used by table cells: dates 'YYYY-MM-DD' or 'YYYY-MM-DD HH:mm', lists joined with ', '
    ```

**Tests** (each named case is one `test`)
- Lexer: strings with both quote kinds and escapes; regex literal vs division (`a / b` vs `/x/i`); unterminated string error offset.
- Parser: precedence `1 + 2 * 3` → 7; `!a && b || c` shape; method chain `file.name.lower().contains("x")`; index `note["my prop"]`;
  list literal; syntax error message has the offset.
- Evaluator: `file.hasTag("project")` true for tag `project/alpha`; `file.inFolder("Notes")` true for `Notes/Sub/a.md`, false for
  `NotesX/a.md`; `status != "done"` with missing status → true (null != "done"); `rating >= 4`; `date(due) < today()`;
  `due - now()` is a number; `today() + "1M"` on Jan 31 → Feb 28/29; `formula.a` referencing `formula.b` works; circular formulas →
  BError; `if(price > 10, "high", "low")`; `[1,2,3].map(value * 2)` → [2,4,6]; `["a","b"].filter(value != "a")` → ["b"];
  `"Hello".slice(1,3)` → "el"; `(3.14159).round(2)` → 3.14; `file.links.length`; `this.file.name` inside an embedded context; unknown
  function → BError, and in a filter it counts as false; `/^a/i.matches("Abc")` true; `date("2026-10-11").format("dddd, MMMM D YYYY")`
  → "Sunday, October 11 2026".

**Verify**
```
cd packages/tephra_search; dart test test/bases/expr; cd ../..
```
Success: all pass.

**Pitfalls**
- Regex vs division: a `/` starts a regex only at an operand position (start, after `(`, `,`, `[`, an operator, or `!`).
- Keep evaluation pure: no I/O, no `DateTime.now()` inside (use `row.now`).

---

### 06.18 Bases query execution

**Purpose.** Build the dataset from the index, evaluate filters, formulas, sort, group and limit for one view in an isolate, fast
enough for 10k notes.

**Files**
- `packages/tephra_search/lib/src/bases/base_dataset.dart` (new: sendable plain data + indexes)
- `packages/tephra_search/lib/src/bases/base_query.dart` (new: executor)
- `app/lib/bases/base_data_provider.dart` (new: builds the dataset from `NoteIndex`, cached)
- `packages/tephra_search/test/bases/base_query_test.dart` (new)

**Implementation**
1. `BaseDataset` (all plain, sendable to an isolate): `List<FileRef> files` (every vault file from `allFiles()`, with tags from
   `allNoteTags()`, outgoing link/embed paths from `allLinks()`, frontmatter from `allProperties()`), `Map<String, String> propertyTypes`
   (from `.tephra/types.json`), and derived indexes built once in the isolate: lower-case name → paths (for link resolution), reverse
   link map (backlinks).
2. `BaseDataProvider` (app) builds the dataset on demand, caches it per vault, and invalidates it when the index reports changes
   (debounced 1 s). Building runs the four index queries in parallel (`Future.wait`).
3. Executor:
   ```dart
   final class BaseQueryResult {
     final List<String> columns;                       // property ids, from view.order or default ['file.name']
     final List<BaseResultRow> rows;                   // path + List<BValue> cells (one per column) + sort keys
     final List<BaseGroup> groups;                     // empty if no groupBy; else ordered groups with row index ranges
     final int totalBeforeLimit; final List<String> errors;   // filter parse errors etc.
   }
   BaseQueryResult runBaseQuery(BaseDocument doc, int viewIndex, BaseDataset data, {VaultPath? thisPath, required DateTime now});
   ```
   Algorithm:
   ```
   parse global filter + view filter expressions once (syntax errors → errors list; the broken expression counts as false)
   parse formulas once
   for each file in data.files:
     ctx = row context
     if global filter present and !truthy(eval(global)) continue
     if view filter present and !truthy(eval(view)) continue
     keep
   sort kept rows by view.sort keys in order (stable sort; nulls last in ASC and first in DESC; compare num/str(case-insensitive, then
     case-sensitive)/date/bool; mixed kinds ordered null < bool < num < date < str < other); default sort when none: file.name ASC
   if groupBy: stable-partition by displayValue(eval(groupBy.property)) in the group's direction, rows keep their sort inside groups
   totalBeforeLimit = kept count; apply limit (after sorting, across groups in order)
   cells: for each column id, evaluate (file.x → field; formula.x → formula; else note property) → BValue
   ```
   Filter semantics per filter node: `FilterAnd` all true, `FilterOr` any true, `FilterNot` none true, `FilterExpr` truthy(eval).
4. The app calls `Isolate.run(() => runBaseQuery(...))` when `data.files.length > 1000`, otherwise inline.
   Budget: 10k files, a filter with 2 conditions, 5 columns, sort by one property: < 300 ms on Windows, < 900 ms on the phone (record).
5. `BValue`s returned from the isolate must be sendable (they are plain Dart objects; `RegExp` inside `BRegex` is not guaranteed
   sendable → convert regex cells to `BStr(pattern)` before returning).

**Tests** (`base_query_test.dart`, hand-built dataset of 12 files incl. 2 attachments)
- `global and view filters AND together`; `not filter`; `or filter`; `default columns`; `order columns`; `sort desc with nulls first`;
  `multi-key sort`; `groupBy status asc with counts`; `limit 3 after sort`; `formula column`; `broken filter → error listed and no rows`;
  `this context` (embedded with thisPath = a note, filter `file.hasLink(this.file)` returns notes linking to it);
  `attachments included only when filter allows` (`file.ext == "pdf"` returns the pdf);
  `bench 10k` (`@Tags(['bench'])`): prints timing.

**Verify**
```
cd packages/tephra_search; dart test test/bases; cd ../..
```
Success: all pass; bench numbers recorded.

**Pitfalls**
- Rows include **all** vault files (Obsidian does); most real bases filter by folder/tag/extension. The default view of an empty
  `.base` (no filters) therefore lists every file — that is expected.

---

### 06.19 Bases UI: table, cards, inline edits, embedded blocks

**Purpose.** Show and edit `.base` files and ` ```base ` blocks.

**Files**
- `app/lib/bases/view/base_view.dart` (new: tab body)
- `app/lib/bases/view/base_controller.dart` (new: loads file, holds `BaseDocument`, runs queries, saves edits)
- `app/lib/bases/view/base_toolbar.dart`, `base_table_view.dart`, `base_cards_view.dart`, `base_cell_editor.dart`,
  `base_filters_dialog.dart`, `base_columns_dialog.dart` (new)
- `app/lib/bases/view/base_code_block.dart` (new: embedded block renderer)
- `app/lib/bases/commands.dart` (new)
- reading view + Live Preview code-block dispatch (modify: language `base`)
- `app/test/bases/view/base_table_view_test.dart`, `base_cards_view_test.dart`, `base_controller_test.dart`, `base_code_block_test.dart` (new)

**Implementation**
1. `BaseController` (`AsyncNotifierProvider.family` by path): reads text (§6.2), `BaseDocument.parse`, selected view index (in memory;
   default 0), runs the query (06.18), re-runs when the dataset changes. Edits go through `BaseEditor`; write only if `changed`; atomic;
   re-parse after write. External file changes reload (no unsaved state exists — edits are written immediately, debounced 500 ms for
   column resizes).
2. **Toolbar:** view picker (dropdown of view names; unsupported types marked), result count `"N results"` (l10n plural; if limited:
   `"N of M results"`), **Sort** menu (choose property + direction; writes `sort`), **Columns** (dialog with a checklist of available
   property ids — all `file.*` fields, every frontmatter key seen in the dataset, every formula — and drag to reorder; writes `order`),
   **Filters** (dialog with two YAML text areas: global filters and view filters; validated by parsing with `BaseDocument.parse` on a
   temp document and by parsing each expression; writes via `setFiltersYaml`), view menu (**New table view**, **New cards view**,
   **Rename view**, **Delete view** with confirmation). Display names from `properties.<id>.displayName`, else the id without `note.`.
3. **Table view** (`BaseTableView`): header row + rows virtualised (`ListView.builder` for rows; both directions scroll with a shared
   horizontal `ScrollController` for header and body). Column width from `columnSize` (default 160; min 60); drag the header's right edge
   to resize (writes `columnSize` debounced 500 ms). Click a header → sort cycle for that column: ASC → DESC → none (replaces the sort list
   with that single key; "none" removes `sort`). Groups render as sticky-ish group header rows ("value (count)"). Cell rendering by
   value kind: link/file → link text (tap opens), list → chips, bool → checkbox (editable if note property), date → formatted, image →
   thumbnail 32 px, error → warning icon with tooltip message. `file.name` cell is a link to the file.
4. **Inline edit:** cells of `note.*` (or bare) properties on Markdown rows: double-click (desktop) / tap on an already selected cell
   (phone) opens `BaseCellEditor` using the property's type from the registry (text, number, checkbox, date, datetime, list) — reuse the
   Phase 2 properties editor input widgets. Commit writes through the Phase 2 frontmatter edit service (`yaml_edit`, untouched keys keep
   formatting, §6.4). A checkbox toggles immediately. `file.name` edit → rename via the Phase 2 rename-with-link-update service.
   `formula.*` and other `file.*` cells are read-only. Attachments' cells are read-only.
5. **Cards view** (`BaseCardsView`): responsive grid (`SliverGrid` with max cross-axis extent = `cardSize` or 200), each card: cover image
   from the `image` property value (vault path, `[[wikilink]]` resolved via the index, or `http(s)` URL with `Image.network`), fit per
   `imageFit` (default cover), aspect per `imageAspectRatio` (default 0.5 = height/width); title = file basename (tap opens); then each
   column in `order` except `file.name` as `Display name: value` lines (max 6). No cover → no image area.
6. **Unsupported view types** → a card with the view name, `basesViewTypeUnsupported` message and the view's YAML (read-only).
   Parse error → error view with the message, line, and the raw text read-only.
7. **Embedded blocks:** in reading view and Live Preview, a fenced code block with language `base` renders `BaseCodeBlock`: the YAML is
   parsed with `BaseDocument.parse`; `thisPath` = the note containing the block; the view picker works (session only); header clicks sort
   **in memory only** (never write into the note); inline cell edits still edit the target notes. Height: up to 15 rows then scroll inside
   (fixed height 15 × row height + header). In Live Preview the block turns back into source when the cursor enters it (Phase 2 rule).
8. Commands: `bases.create-base` (06.2), `bases.insert-base-block` (inserts at the cursor:
   "```base\nviews:\n  - type: table\n    name: Table\n```\n"), `bases.add-view` (current base; table). Labels in l10n.
9. l10n keys: `basesResults`, `basesResultsLimited`, `basesSort`, `basesColumns`, `basesFilters`, `basesGlobalFilters`, `basesViewFilters`,
   `basesNewTableView`, `basesNewCardsView`, `basesRenameView`, `basesDeleteView`, `basesDeleteViewConfirm`, `basesViewTypeUnsupported`,
   `basesEditUnsupported`, `basesParseError`, `basesNoResults`, `commandCreateBase`, `commandInsertBaseBlock`, `commandAddBaseView`.

**Tests**
- `base_controller_test.dart`: open + no interaction → zero writes; header click writes exactly the `sort` key change; resizing a column
  three times within 500 ms → one write; deleting a view writes and the picker updates.
- `base_table_view_test.dart`: renders columns in `order` with display names; checkbox toggle calls the frontmatter service with
  `(path, 'done', true)`; double-click a text cell, type, Enter → service called; `formula.*` cell not editable; error cell shows tooltip.
- `base_cards_view_test.dart`: cover from a `[[img.png]]` property resolves to the attachment; no cover → no image widget; tap title opens.
- `base_code_block_test.dart`: a note containing a ```base block with `file.hasLink(this.file)` filter lists backlinking notes; sorting
  in the block does not modify the note (zero writes).
- Round-trip: open every `test_vaults/syntax/bases/*.base` fixture in `BaseView`, close → zero writes.

**Verify**
```
cd app; flutter test test/bases; cd ..
```
Manual: open a `.base` made by Obsidian (or the Notion-imported `.base` from Phase 5) on both platforms; sort, resize, edit a property;
then open it in Obsidian (if available): the view and its sort/columns are intact. Success: tests pass; manual checks recorded.

**Pitfalls**
- Inline edits change notes, which changes the index, which re-runs the query: keep the edited row's selection by path, not by row index.
- Never write the `.base` file for viewport-only state (scroll position, selected view in an embedded block).

### 06.20 Math rendering and code-block upgrades

**Purpose.** Render `$inline$` and `$$block$$` TeX with `flutter_math_fork` everywhere Markdown is rendered, and give code blocks a copy
button, optional line numbers and a verified ≥ 100-language highlighter.

**Files**
- `app/lib/reading/math/math_view.dart` (new)
- `app/lib/reading/code/code_block_view.dart` (modify the Phase 1 code-block widget, or create it here if Phase 1 inlined it)
- reading view inline builder (modify: `MdInlineMath` → `WidgetSpan`), block builder (modify: `MdMathBlock`)
- Live Preview inline-block renderer (modify: math uses `MathView`)
- vault settings model (modify: add `codeBlockLineNumbers`)
- `app/test/reading/math/math_view_test.dart`, `app/test/reading/code/code_block_view_test.dart` (new)

**Implementation**
1. `MathView`:
   ```dart
   class MathView extends StatelessWidget {
     const MathView({super.key, required this.tex, required this.display, this.textStyle});
     final String tex; final bool display; final TextStyle? textStyle;
     // build: Math.tex(tex, mathStyle: display ? MathStyle.display : MathStyle.text, textStyle: style,
     //   onErrorFallback: (err) => MathErrorBox(tex: tex, message: err.messageWithType))
   }
   ```
   `MathErrorBox`: 1 px border in the error colour, radius 4, padding 4; first line the message (error colour, 12 sp), second line the
   original source `$…$` / `$$…$$` in monospace. Never throws.
   Block math: centred, horizontal scroll (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) when wider than the column,
   vertical padding 8. Inline math: `WidgetSpan(alignment: PlaceholderAlignment.middle, child: MathView(display: false, textStyle:
   surrounding style))`.
2. Use `MathView` in: reading view (inline + block), Live Preview inline blocks (the Phase 2 mechanism; cursor inside → source), canvas
   text/file cards (automatic through the reading view), and the Phase 5 PDF export **only if** that exporter renders reading-view widgets
   to images; otherwise leave export unchanged and note it in `PROGRESS.md`.
3. Copy of a reading-view selection that contains math: the copied text contains the original `$…$` source (if the Phase 1 selection
   copy works from source offsets this is automatic; otherwise note the limitation in `PROGRESS.md`).
4. Code blocks (`CodeBlockView`): header row with the language label (muted, left) and a **Copy** icon button (right; tooltip and
   semantics `codeCopy`; visible on hover on desktop layout, always visible on phone layout); click copies the code **without** fences
   and shows a snackbar `codeCopied`. Optional line-number gutter (right-aligned numbers, muted, monospace, not selectable) when the vault
   setting `codeBlockLineNumbers` (bool, default `false`, stored in `.tephra/settings.json`) is true. Long lines scroll horizontally.
   Languages `mermaid`, `base`, `query` are dispatched to their special renderers before this widget.
5. Verify the highlighter's language count: add a test that asserts the Phase 1 highlighter registers ≥ 100 languages (e.g. `re_highlight`'s
   `builtinAllLanguages.length`). Unknown languages render as plain monospace. Language aliases to support: `js`→javascript,
   `ts`→typescript, `py`→python, `sh`/`shell`→bash, `yml`→yaml, `md`→markdown, `cs`→csharp, `c++`→cpp, `kt`→kotlin, `ps1`/`pwsh`→powershell.

**Tests**
- `math_view_test.dart`: `\frac{a}{b}` builds without error box; `\frac{a}` (invalid) shows `MathErrorBox` containing the source;
  inline math inside a paragraph produces a `WidgetSpan`; golden `goldens/math_inline_block.png` (`@Tags(['golden'])`) of the
  `test_vaults/syntax` math note.
- `code_block_view_test.dart`: copy puts exactly the code on the clipboard (mock `Clipboard` via
  `TestDefaultBinaryMessengerBinding`); line numbers appear only when the setting is true; ≥ 100 languages; alias `py` highlights as Python
  (span count > 1).

**Verify**
```
cd app; flutter test test/reading; cd ..
```
Success: all pass; the syntax vault's math note renders identically on Windows and Android (manual check).

**Pitfalls**
- `flutter_math_fork`'s `onErrorFallback` runs during build; keep it cheap and side-effect free.
- If `flutter_math_fork` fails to compile with Flutter 3.47.7, do not fork or patch it; stop and ask the human (GEMINI.md §5).

---

### 06.21 Mermaid diagrams (offline, cached)

**Purpose.** Render ` ```mermaid ` blocks offline on both platforms: a hidden WebView runs the bundled `mermaid.min.js`, returns SVG,
Flutter draws it with `flutter_svg`, and results are cached by content hash.

**Files**
- `app/assets/mermaid/mermaid.min.js`, `app/assets/mermaid/LICENSE`, `app/assets/mermaid/VERSION` (new assets)
- `app/assets/mermaid/render.html` (new asset)
- `app/pubspec.yaml` (`flutter: assets: - assets/mermaid/`)
- `app/lib/reading/mermaid/mermaid_service.dart` (new)
- `app/lib/reading/mermaid/mermaid_cache.dart` (new)
- `app/lib/reading/mermaid/mermaid_view.dart` (new)
- `app/lib/reading/mermaid/commands.dart` (new: clear cache)
- `app/test/reading/mermaid/mermaid_cache_test.dart`, `mermaid_service_test.dart` (new)
- `app/integration_test/mermaid_render_test.dart` (new)
- `THIRD_PARTY_NOTICES.md` (add Mermaid, MIT)

**Implementation**
1. Asset: download the latest **12.x** release (12.1.0 at the time of writing) `dist/mermaid.min.js` from
   `https://cdn.jsdelivr.net/npm/mermaid@<version>/dist/mermaid.min.js` and its `LICENSE` from the npm package; write the exact version
   string (e.g. `12.1.0`) into `VERSION`. Check the Mermaid configuration docs for this version for the option names used in item 3
   (`htmlLabels`, `flowchart.htmlLabels`, `securityLevel`, `theme`, `startOnLoad`) and adjust if renamed; record what you used.
2. Runtime files: on first use, copy `render.html` and `mermaid.min.js` from assets to
   `<appSupportDir>/mermaid-runtime/<version>/` (skip if already present) and start the `HeadlessWebRunner` (06.1) on that `render.html`.
   (Loading from a file avoids the WebView2 `NavigateToString` 2 MB size limit.)
3. `render.html` (write it yourself):
   ```html
   <!doctype html><html><head><meta charset="utf-8"><script src="mermaid.min.js"></script></head>
   <body><div id="work" style="position:absolute;left:-10000px;top:0;width:2000px"></div>
   <script>
     window.tephraReply = (id, json) => window.flutter_inappwebview.callHandler('tephraReply', id, json);
     const PROPS = ['fill','fill-opacity','stroke','stroke-width','stroke-opacity','stroke-dasharray','stroke-linecap','stroke-linejoin',
       'opacity','font-family','font-size','font-weight','font-style','text-anchor','dominant-baseline','visibility'];
     function inlineStyles(svgText) {
       const work = document.getElementById('work'); work.innerHTML = svgText;
       const svg = work.querySelector('svg');
       svg.querySelectorAll('*').forEach(el => {
         const cs = getComputedStyle(el);
         if (cs.display === 'none') { el.remove(); return; }
         for (const p of PROPS) { const v = cs.getPropertyValue(p); if (v && v !== 'normal' && v !== 'auto') el.setAttribute(p, v); }
       });
       svg.querySelectorAll('style').forEach(s => s.remove());
       const out = new XMLSerializer().serializeToString(svg); work.innerHTML = ''; return out;
     }
     window.tephraRender = async (id, source, theme) => {
       try {
         mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: theme === 'dark' ? 'dark' : 'default',
           htmlLabels: false, flowchart: { htmlLabels: false }, fontFamily: 'Segoe UI, Roboto, sans-serif' });
         const { svg } = await mermaid.render('m' + id.replace(/[^a-zA-Z0-9]/g, ''), source);
         window.tephraReply(id, JSON.stringify({ ok: true, svg: inlineStyles(svg) }));
       } catch (e) { window.tephraReply(id, JSON.stringify({ ok: false, error: String((e && e.message) || e) })); }
     };
   </script></body></html>
   ```
   Decision: `htmlLabels: false` makes Mermaid emit `<text>` instead of `<foreignObject>` HTML (which `flutter_svg` cannot draw), and
   `inlineStyles` converts CSS class styling into attributes because `flutter_svg` ignores `<style>` sheets.
4. `MermaidService` (app-wide `Provider`, lazy):
   ```dart
   final class MermaidResult { final String? svg; final Uint8List? png; final String? error; }
   final class MermaidService {
     Future<MermaidResult> render(String source, {required Brightness theme});   // serial queue, one request at a time
     Future<void> clearCache();
   }
   ```
   Flow: key = lower-case hex SHA-256 of UTF-8 `"<mermaidVersion>\n<light|dark>\n<source>"` → memory LRU (64 entries) → disk cache
   `.tephra/cache/mermaid/<key>.svg` → else WebView: `runner.request(id, 'tephraRender(${jsonEncode(id)}, ${jsonEncode(source)},
   ${jsonEncode(theme)})', timeout: 10 s)`; parse JSON; on `ok` write the SVG to the cache (atomic, through `VaultFileSystem.writeBytes`
   — `.tephra/` writes are allowed, §6.1) and the LRU. Errors and timeouts are **not** cached. The runner is disposed after 60 s without
   requests and restarted on demand. `HeadlessWebUnavailableException` → result with error `mermaidUnavailable` (l10n).
5. PNG fallback for diagrams `flutter_svg` cannot draw: `MermaidView` renders `SvgPicture.string(svg, errorBuilder: ...)`. If
   `errorBuilder` fires, request a PNG instead: add a JS function `tephraRenderPng(id, source, theme)` that renders as above, draws the
   style-inlined SVG into an `<canvas>` at 2× via an `Image` with a `data:image/svg+xml` URL, and replies
   `{ok: true, png: canvas.toDataURL('image/png').split(',')[1]}`; Dart decodes base64, caches `<key>.png`, and shows `Image.memory`.
   Keep a `const Set<String> kMermaidPngTypes` (initially empty) of diagram keywords (first word of the source, e.g. `mindmap`) that go
   straight to PNG; add a type to it only if the integration test (item 8) shows it renders wrongly as SVG, and record why.
6. `MermaidView` (used for ```mermaid blocks in reading view, Live Preview inline blocks, canvas cards): loading → a 120 px placeholder
   with a small progress indicator; success → the SVG, scaled down to the available width (never scaled up beyond its intrinsic width),
   horizontally centred; tap → full-screen viewer with `InteractiveViewer` (pan/zoom); error → error card: title `mermaidError`, the error
   message, the source in monospace, a **Copy source** button. Theme follows the current app brightness; theme switch re-renders (cache
   key differs). Web (dev preview) → shows the source as a normal code block with a note `mermaidDesktopOnly`.
7. Command `mermaid.clear-cache` ("Clear diagram cache") deletes `.tephra/cache/mermaid/` contents.
8. `app/integration_test/mermaid_render_test.dart` renders these sources and asserts `ok` and non-empty SVG, then pumps `MermaidView`
   and asserts no error card: `graph TD; A-->B; B-->C`, a `sequenceDiagram` with 2 participants, `classDiagram` with 2 classes,
   `stateDiagram-v2`, `erDiagram`, `gantt` with 2 tasks, `pie` with 3 slices, `mindmap` with 3 nodes, `journey`, `gitGraph`; plus
   invalid source `graph TD; A-->` → error result. Run on Windows and Android **with networking disabled** (Windows: run the test with
   the network adapter disabled or in airplane mode; Android: airplane mode) to prove offline rendering. Visually check each in the app
   and add types that look wrong to `kMermaidPngTypes`.

**Tests**
- `mermaid_cache_test.dart`: key changes with version, theme and source; LRU evicts oldest at 65 entries; disk cache hit avoids the runner
  (fake runner counts requests); errors not cached.
- `mermaid_service_test.dart` (fake `HeadlessWebRunner`): requests are serialised (second waits for first); timeout → error result;
  runner disposed after 60 s idle (fake async) and restarted on the next request.
- Integration test as in item 8 (both platforms, offline).

**Verify**
```
cd app; flutter test test/reading/mermaid; cd ..
cd app; flutter test integration_test/mermaid_render_test.dart -d windows; cd ..
cd app; flutter test integration_test/mermaid_render_test.dart -d <android-id>; cd ..
dart run tool/check_licenses.dart
```
Success: all pass offline on both platforms; `PROGRESS.md` lists the Mermaid version and any PNG-fallback types.

**Pitfalls**
- `securityLevel: 'strict'` must stay: diagram text comes from notes and must not run scripts.
- The cache is per vault (`.tephra/cache/`) and never synced (§6.6).
- Large diagrams can exceed 10 s on slow phones; the error card offers **Retry** (one more attempt with a 30 s timeout).

---

### 06.22 PDF viewer, deep links and page embeds

**Purpose.** Open PDFs in a tab with search, outline, zoom, thumbnails and text selection; support `[[file.pdf#page=N]]` links and
`![[file.pdf#page=N]]` embeds; remember the last page.

**Files**
- `app/lib/media/local_file.dart` (new: absolute path or temp copy for a vault file)
- `app/lib/media/pdf/pdf_view.dart`, `pdf_toolbar.dart`, `pdf_outline_panel.dart`, `pdf_thumbnails_panel.dart`, `pdf_search_bar.dart` (new)
- `app/lib/media/pdf/pdf_state_store.dart` (new: `.tephra/cache/pdf-state.json`)
- `app/lib/media/pdf/pdf_embed.dart`, `pdf_page_thumbnail.dart` (new)
- `app/lib/media/commands.dart` (new)
- embed renderer (modify: `.pdf` targets → `PdfEmbed`)
- `app/test/media/pdf/pdf_state_store_test.dart`, `pdf_view_test.dart`, `local_file_test.dart` (new)
- `test_vaults/syntax/media/sample.pdf` (new: generate a 5-page PDF with an outline and text using the `pdf` package from Phase 5 in a
  small script `tool/gen_media_fixtures.dart`, so no third-party file is copied)

**Implementation**
1. `local_file.dart`:
   ```dart
   /// Returns an absolute file-system path for [path]. For IoVaultFileSystem vaults this is join(rootDir, path) (no copy).
   /// Otherwise (e.g. SAF fallback) copies the bytes once to <tempDir>/tephra-media/<sha256>.<ext> and returns that path.
   Future<String> localFilePath(WidgetRef ref, VaultPath path);
   ```
2. `PdfView` (tab body): open with `pdfrx`'s document reference for a file path (check the README for the current class names:
   `PdfViewer.file(path, controller: ..., params: PdfViewerParams(...))` in 2.x). Features:
   - **Toolbar:** sidebar toggle (outline / thumbnails tabs), page field `"[n] / total"` (type a number + Enter → go to page), zoom out,
     zoom percentage, zoom in, fit width, fit page, search toggle (Ctrl+F when the PDF tab is focused).
   - **Search:** the package's text searcher (`PdfTextSearcher` in 2.x): case-insensitive; shows "k of m"; Enter/F3 next, Shift+Enter/
     Shift+F3 previous; matches highlighted through the viewer's page paint callbacks as documented.
   - **Outline:** `document.loadOutline()` → tree (`ExpansionTile`s); tap → go to that destination.
   - **Thumbnails:** `ListView.builder` of page thumbnails (width 120) using the package's page widget; current page highlighted; tap → go.
   - **Text selection & copy:** enable the viewer's text selection; Ctrl+C / context-menu Copy copies the selected text.
   - **Password-protected PDFs:** the viewer's password provider shows a password dialog; cancelled → error view.
   - On the phone layout the sidebar is a modal bottom sheet; pinch zoom works natively in the viewer.
3. Deep links: `FileTabContent.subpath` `#page=N` (from `[[file.pdf#page=N]]`, 06.2) → open at page N (1-based; clamp to range). If the
   same PDF is already open in the active tab, just go to the page.
4. Last page (`PdfStateStore`): on page change, debounced 1 s, save `{ "<path>": { "page": n, "updatedAt": ISO } }` to
   `.tephra/cache/pdf-state.json` (keep at most 500 entries, dropping the oldest). Opening without `#page` → restore that page.
   Rename/move/delete of the PDF: entries are keyed by path; stale entries are harmless (cache).
5. `PdfPageThumbnail({path, page, width})`: renders one page (used by canvas file cards from 06.14 — replace the placeholder there now).
6. `PdfEmbed` for `![[file.pdf]]` / `![[file.pdf#page=N]]` in reading view and Live Preview: one page at a time, fit to the available
   width, height = embed size height if given (`|width x height` → height) else 480 dp (page scaled to fit inside); a footer with ‹ ›
   buttons and `n / total`; double-click/tap on the page → opens the PDF tab at the shown page. Page embeds never write anything.
7. Commands: `pdf.find` (Ctrl+F, local binding inside the PDF view like canvas), `pdf.go-to-page`, `pdf.zoom-in`, `pdf.zoom-out`,
   `pdf.fit-width` — registered with `defaultShortcuts: const []` and bound locally (same pattern as 06.15 item 10).
8. l10n keys: `pdfPageOf`, `pdfSearchHint`, `pdfMatchesOf`, `pdfOutline`, `pdfThumbnails`, `pdfNoOutline`, `pdfPasswordTitle`,
   `pdfPasswordWrong`, `pdfOpenError`, `pdfFitWidth`, `pdfFitPage`.

**Tests**
- `local_file_test.dart`: IoVaultFileSystem vault → joined path, no copy; memory FS → a temp copy whose bytes equal the source, reused on
  the second call (same path).
- `pdf_state_store_test.dart`: save/restore; 501st entry evicts the oldest; invalid JSON file → empty store, file not overwritten until
  a change.
- `pdf_view_test.dart` (widget test where `pdfrx` works in tests; if the PDFium binary cannot load under `flutter test` on Windows, move
  these cases to `app/integration_test/pdf_view_test.dart`): opening `sample.pdf#page=3` shows `3 / 5`; search "Chapter" finds ≥ 1 match;
  outline lists the fixture's 3 entries; thumbnails tap → page changes; reopen without page → last page restored.

**Verify**
```
dart run tool/gen_media_fixtures.dart
cd app; flutter test test/media; cd ..
cd app; flutter test integration_test/pdf_view_test.dart -d windows; cd ..       (only if cases were moved there)
```
Manual on both platforms: a note with `[[sample.pdf#page=4]]` opens page 4; `![[sample.pdf#page=2]]` shows page 2 inline; select and
copy text. Success: all pass.

**Pitfalls**
- `pdfrx` downloads/bundles PDFium per platform at build time; the first Windows build may take longer. Do not commit any downloaded
  binary.
- PDF page numbers in links are 1-based; `pdfrx` page numbers are 1-based too — do not subtract 1 twice.

---

### 06.23 Image viewer, audio/video players and media embeds

**Purpose.** View images (zoom/pan, folder gallery) and play audio/video in tabs and inside notes, on both platforms with one player package.

**Decision:** `video_player` (Android, ExoPlayer) + `video_player_win` (Windows, Media Foundation) for **both** audio and video.
`video_player` plays audio-only files; the UI shows audio controls when the decoded video size is 0×0 or the extension is an audio
extension. (`media_kit` is rejected for licence reasons; `just_audio` would add a second engine.)

**Files**
- `app/lib/media/image/image_viewer_view.dart`, `image_gallery_strip.dart` (new)
- `app/lib/media/player/media_player_controller.dart`, `media_controls.dart`, `media_player_view.dart`, `media_embed.dart` (new)
- embed renderer (modify: audio/video targets → `MediaEmbed`; images keep the Phase 2 image embed)
- canvas file cards (modify: audio/video → compact `MediaEmbed`)
- `app/test/media/image/image_viewer_view_test.dart`, `app/test/media/player/media_controls_test.dart` (new)
- `app/integration_test/media_player_test.dart` (new)
- `tool/gen_media_fixtures.dart` (extend: a 3-second 440 Hz sine `tone.wav` written by hand-built WAV header; video fixture: none — see Tests)

**Implementation**
1. **Image viewer** (tab for `imageExtensions`): `InteractiveViewer` (minScale 0.05, maxScale 20, `boundaryMargin: EdgeInsets.all(200)`),
   image fit to the view initially; double-click/double-tap toggles fit ↔ 100% at the tap point; mouse wheel zooms at the cursor
   (factor `exp(-dy/300)`); toolbar: zoom out, zoom %, zoom in, fit, 100%, rotate 90° (view only, never saved), previous/next.
   SVG files use `SvgPicture.file`. Undecodable image → error view with the file name.
   **Gallery:** images in the same folder (non-recursive), sorted by name case-insensitively; Left/Right keys and toolbar buttons go to
   previous/next (wrap around); phone layout: horizontal swipe (`PageView`) when the image is at fit scale; a bottom strip of 64 px
   thumbnails (`Image` with `cacheWidth: 128`) toggled by a toolbar button, current item highlighted and auto-scrolled into view.
   Navigating replaces the tab content (`FileTabContent` of the new image), keeping one tab.
2. **Player controller** (`MediaPlayerController` wraps `VideoPlayerController.file(File(await localFilePath(...)))`): `initialize`,
   `play/pause/toggle`, `seekTo`, `setSpeed` (0.5, 0.75, 1, 1.25, 1.5, 2), `setVolume` (desktop), exposes position/duration/isPlaying,
   and an `error` string when initialization fails (unsupported codec) → l10n `mediaUnsupportedFormat`.
3. **Controls** (`MediaControls`): play/pause button, position slider (seek on release), `mm:ss / mm:ss` (or `h:mm:ss`), speed menu,
   volume slider (desktop layout only), full-screen button (video only; pushes a full-screen route with the same controller; Windows
   uses `WindowService` full screen if Phase 4 added it, else just the route), loop toggle. Keyboard when focused: Space toggle,
   Left/Right seek ∓5 s, Up/Down volume ±10% (desktop).
4. `MediaPlayerView` (tab): video centred with aspect ratio from the controller, controls below; audio → a large audio icon + file name +
   controls.
5. `MediaEmbed` (reading view, Live Preview, canvas): audio → a 56 px high bar with controls; video → video at embed width (`|width`
   honoured) with aspect ratio, controls overlay shown on hover/tap. **The controller is created lazily on first play** (embeds show a
   poster: video → a play button over a neutral surface; audio → the bar) so a note with 20 embeds does not open 20 decoders. Only one
   embed plays at a time per tab (starting one pauses others).
6. Windows notes: Media Foundation plays mp3, m4a/aac, wav, mp4 (H.264), mov (H.264), and webm/mkv/ogg/opus only if the system codecs are
   installed; show `mediaUnsupportedFormat` with a hint `mediaWindowsCodecHint` otherwise. Android plays all listed formats except some mkv/ogv codecs.
7. l10n keys: `imageZoomFit`, `imageZoomActual`, `imageRotate`, `imagePrevious`, `imageNext`, `imageGallery`, `imageDecodeError`,
   `mediaPlay`, `mediaPause`, `mediaSpeed`, `mediaVolume`, `mediaFullScreen`, `mediaLoop`, `mediaUnsupportedFormat`, `mediaWindowsCodecHint`.

**Tests**
- `image_viewer_view_test.dart`: gallery order is case-insensitive by name; Right on the last image wraps to the first; rotate does not
  write the file (zero writes); double-tap toggles scale between fit and 1.0 (inspect `TransformationController`).
- `media_controls_test.dart` (fake controller): time formatting (`65 s` → `1:05`, `3725 s` → `1:02:05`); seek on slider release only;
  speed menu sets 1.5; volume slider hidden on phone width.
- `media_player_test.dart` (integration, Windows and Android): plays `tone.wav` for 1 s → position > 500 ms; pause stops position;
  an invalid file (`broken.mp4` = 100 random bytes from `tool/gen_media_fixtures.dart`) shows `mediaUnsupportedFormat`.

**Verify**
```
dart run tool/gen_media_fixtures.dart
cd app; flutter test test/media; cd ..
cd app; flutter test integration_test/media_player_test.dart -d windows; cd ..
cd app; flutter test integration_test/media_player_test.dart -d <android-id>; cd ..
```
Manual: an mp4 recorded on the phone plays on both platforms (record the formats tried in `PROGRESS.md`). Success: all pass.

**Pitfalls**
- Dispose every `VideoPlayerController` (lint `close_sinks` won't catch it) — leaking decoders crashes Android after a few dozen.
- `video_player_win` must be listed in `app/pubspec.yaml` to be registered on Windows; `video_player` alone does nothing there.

---

### 06.24 Slides

**Purpose.** Present a note as slides split on `---` lines.

**Files**
- `packages/tephra_markdown/lib/src/slides.dart` (new) + export in `lib/tephra_markdown.dart`
- `packages/tephra_markdown/test/slides_test.dart` (new)
- `app/lib/reading/slides/slides_presentation.dart` (new)
- `app/lib/reading/slides/commands.dart` (new)
- `app/lib/core/platform/` `WindowService` (modify: add `Future<void> setFullScreen(bool value)` if not present; Windows via
  `window_manager.setFullScreen`; no-op elsewhere)
- `app/test/reading/slides/slides_presentation_test.dart` (new)

**Implementation**
1. Split rule (pure function, uses the AST so `---` inside code blocks, setext headings and frontmatter are never split points):
   ```dart
   final class SlideRange { const SlideRange(this.start, this.end); final int start, end; }   // UTF-16 offsets into note text
   List<SlideRange> splitSlides(ParsedNote note);
   ```
   ```
   contentStart = frontmatter != null ? frontmatter.contentStart : 0
   breaks = top-level children of note.root that are MdThematicBreak and whose source line text.substring(start, end) with trailing
            spaces/tabs and the final '\n' removed is exactly '---'
   slides = ranges between contentStart, each break (excluded), and text.length; drop ranges that contain only whitespace
   if no breaks: one slide = whole content
   ```
   Note: in CommonMark a `---` line directly below a paragraph line is a setext heading underline, not a break — the parser already
   handles this, matching Obsidian (users separate slides with a blank line before `---`).
2. `SlidesPresentation` (full-screen route pushed with `PageRouteBuilder(opaque: true)`): parses each slide's substring with
   `MarkdownParser.parse` and renders it with the reading-view block builder in non-lazy mode. Layout (decided):
   `ColoredBox(background) > Center > AspectRatio(16/9) > FittedBox(BoxFit.contain) > SizedBox(1280 × 720) > Padding(64) >
   FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter) > SizedBox(width: 1152, child: Column(blocks))`, with a reading text
   theme whose base font size is 32 (headings scale as in reading view). A slide that is too tall therefore scales down to fit.
   Embedded images, math, Mermaid and code blocks work (same widgets). Links are tappable (open after exiting).
3. Navigation: Right, Down, Space, PageDown, Enter, N → next; Left, Up, PageUp, Backspace, P → previous; Home → first; End → last;
   Esc → exit (also the Android back gesture). Phone: horizontal swipe (velocity > 300 px/s or distance > 20% width); tap the right
   third → next, left third → previous. Counter `"n / total"` bottom-right (muted, 14 sp); a thin progress bar at the bottom.
4. Full screen: on enter, `WindowService.setFullScreen(true)` (Windows) / `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`
   (Android, platform-only feature allowed by §5.9 via `WindowService`'s Android implementation); on exit restore both. Wakelock: not
   added (no new dependency); note it in Ideas.
5. Command `slides.start-presentation` ("Start presentation"), available when the active tab is a Markdown note; starts at the slide
   containing the cursor (or the first). Ribbon/menu: add to the note's "more" menu.
6. l10n: `commandStartPresentation`, `slidesCounter`, `slidesExitHint` ("Press Esc to exit", shown for 2 s at start).

**Tests**
- `slides_test.dart`: 3 slides split by `\n\n---\n\n`; frontmatter `---` lines are not split points; `---` inside a fenced code block not
  split; `Text\n---` (setext heading) not split; `--- ` with trailing spaces splits; `----` does not split; `***` does not split;
  no breaks → one slide; empty slides dropped.
- `slides_presentation_test.dart`: Right/Space/PageDown advance, Left/PageUp go back, End jumps to last, Esc pops the route and calls
  `setFullScreen(false)` (fake `WindowService`); tap on right third advances; counter shows `2 / 3`; a slide with 60 lines is scaled
  down (no overflow error in the test).

**Verify**
```
cd packages/tephra_markdown; dart test test/slides_test.dart; cd ../..
cd app; flutter test test/reading/slides; cd ..
```
Manual on both platforms with a 5-slide note containing an image and a Mermaid diagram. Success: all pass.

**Pitfalls**
- Always restore window/system UI mode in `dispose` as well as on Esc, so a crash inside the presentation does not leave the window full
  screen.

---

## Demo script

Run on **Windows** and on a **real Android phone**, with the 10k bench vault for the graph and a real/fixture vault for the rest.
Record each line as pass/fail in `PROGRESS.md`.

1. Open the 10k bench vault → Ctrl+G (phone: drawer → Graph view). The layout animates; enable the perf overlay → fps ≥ 60 (Windows) /
   ≥ 30 (phone) while panning and zooming.
2. Open settings → Filters: type `tag:#project` → only matching notes remain; turn on Tags and Attachments; add group `path:Daily` with
   a colour; set Repel 15 and Link distance 120; restart the app → the settings are kept (`.tephra/graph.json`).
3. Drag a node (it follows the pointer and the others react); hover (phone: long-press) highlights neighbours; click opens the note.
4. Open a note → the right-sidebar local graph shows it; depth 2 shows more; phone: command "Open local graph".
5. Create a canvas from the explorer → double-click to add a card with `**bold**` and `$e^{i\pi}+1=0$`; add a note card, an image, a
   PDF (first page shows), a web link (title and favicon appear); group two cards; connect cards with an edge, label it, add an arrow
   at both ends; snap and alignment guides appear while dragging; copy/paste a card; undo three times; redo once; zoom to fit.
6. Close the canvas and open the same file in Obsidian (Windows) → identical layout and content. Open an Obsidian-made canvas in Tephra,
   close without editing → file bytes unchanged (`Get-FileHash` before/after).
7. Open a `.base` (made in Obsidian or the Notion import) → table view; sort by a column; resize a column; edit a checkbox and a text
   property inline; switch to a cards view with a cover image; embed the base in a note with ` ```base ` and see it render.
   Open the `.base` in Obsidian → still valid; close an unedited `.base` in Tephra → bytes unchanged.
8. Put the phone in airplane mode (Windows: disable networking) → open the syntax vault's Mermaid note → flowchart, sequence and gantt
   render; math renders inline and as blocks; the code block copy button works; turn on line numbers.
9. `[[sample.pdf#page=4]]` opens page 4; search "Chapter"; open the outline; select and copy text; close and reopen → last page restored;
   `![[sample.pdf#page=2]]` shows page 2 inside the note.
10. Open an image → zoom, rotate, Next/Previous through the folder; play an mp3 and an mp4 in tabs and as embeds in a note.
11. Run "Start presentation" on a 5-slide note → arrows/space navigate; swipe on the phone; Esc exits and the window leaves full screen.

## Exit gate

All boxes must be ticked in `PROGRESS.md` with evidence (numbers or file names).

- [ ] Every step 06.1–06.24 is ticked, with tests passing: `flutter analyze --fatal-infos` clean, `dart format` clean, all package
      `dart test` and `app` `flutter test` suites green.
- [ ] **Graph budget (Windows):** 10k-note bench vault, `graph_perf_test` in profile mode: average frame ≤ 16.7 ms and p90 ≤ 20 ms; mean
      layout tick ≤ 25 ms. Numbers recorded.
- [ ] **Graph budget (Android phone):** same test on the real phone: average frame ≤ 33.3 ms and p90 ≤ 40 ms; mean tick ≤ 60 ms. Device
      model and numbers recorded.
- [ ] **Canvas round-trip:** every `test_vaults/syntax/canvas/*.canvas` fixture and at least 3 canvases created in Obsidian open and close
      in Tephra with **0 changed bytes** (codec test + manual `Get-FileHash` check).
- [ ] **Canvas compatibility:** a canvas created and edited in Tephra (all four node types, edges with labels, colours, a group) opens in
      Obsidian with the same layout; unknown fields added in Obsidian survive a Tephra edit. (If Obsidian is unavailable on this machine,
      stop and ask the human to perform this check.)
- [ ] **Base round-trip:** every `test_vaults/syntax/bases/*.base` fixture and at least 2 Obsidian-made bases open and close with **0
      changed bytes**; a sort/column/rename edit made in Tephra changes only those keys (diff checked) and the file opens in Obsidian.
- [ ] **Mermaid offline:** `mermaid_render_test` passes on Windows and on the phone with networking disabled.
- [ ] **Math offline:** the syntax vault math note renders on both platforms (golden test + manual), invalid TeX shows the error box.
- [ ] PDF `#page=N` links and embeds, search, outline, thumbnails, copy text and last-page memory work on both platforms.
- [ ] Image viewer, audio and video playback (tab + embed) work on both platforms (formats tried recorded).
- [ ] Slides work on both platforms (keyboard on Windows, swipe on the phone).
- [ ] `dart run tool/check_licenses.dart` passes; `THIRD_PARTY_NOTICES.md` lists every new package and Mermaid.
- [ ] The Phase 1 round-trip test (all fixture vaults, 0 changed bytes) and the Phase 2 performance budgets still pass.
- [ ] Demo script 1–11 passes on Windows and Android.

## Hand-off

When the gate is green:
1. Update `PROGRESS.md`: tick the gate, record the performance numbers, the name map, the contract additions (new `NoteIndex` methods,
   `splitSlides`, canvas codec, Bases engine, `.tephra/graph.json`, `.tephra/cache/mermaid/`, `.tephra/cache/link-previews.json`,
   `.tephra/cache/pdf-state.json`, vault settings `codeBlockLineNumbers` and `canvas.fetchLinkPreviews`), the WebView package actually
   used (primary or fallback), and the Mermaid version.
2. `git checkout main`, `git merge --no-ff phase-06`, `git tag v0.06.0`.
3. Stop and report to the human: what was built, gate results with numbers, anything "not verified on device" or "not verified in
   Obsidian", and the contract additions that should be folded into `00-conventions.md`.

What Phase 7 relies on from this phase:
- `HeadlessWebRunner`/the chosen WebView package (Phase 7 web viewer uses the same package's visible WebView on Windows).
- `ViewRegistry` + `TabContent` (Phase 7 adds a `WebViewerTabContent` and extends workspace features).
- Graph and canvas `CustomPainter`s (Phase 7 adds accessibility semantics and list alternatives).
- Theme colour mappings in `GraphColors` and `CanvasColors` (Phase 7 replaces them with theme tokens).
- Vault settings keys added here (Phase 7 lists them in the settings registry).
