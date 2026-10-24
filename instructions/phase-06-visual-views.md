# Phase 06 — Visual views

> **Duration:** 8 weeks (36 steps: 06.1–06.24 visual views, 06.25–06.36 database views and templates).
> **Goal:** add the views that make an Obsidian vault visual: Graph view (global and local), Canvas (JSON Canvas 1.0),
> Bases (`.base` table and cards views), math, Mermaid diagrams, better code blocks, a PDF viewer, image/audio/video viewers
> with embeds, and Slides. Steps 06.25–06.36 extend this with Notion-style database views (Board, Calendar, List, Gallery, Timeline, a "New"
> button, inline databases) and Notion-style templates (prompts, choices, cursor, date offsets, frontmatter merge, folder defaults,
> a template gallery with packs, and `tephra-button` blocks). Everything works on Android and Windows, offline, and every file Tephra
> writes opens unchanged in Obsidian.

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
- **Database views** (steps 06.25–06.33; `packages/tephra_search/lib/src/bases/views/` + `app/lib/bases/view/`): `.base` view types `table`, `cards`,
  `list`, **`kanban` (Board)** — Obsidian's own types, same YAML — and the Tephra-only `tephra-calendar`, `tephra-gallery`, `tephra-timeline`; typed `tephra*`
  options preserved losslessly; view switcher tabs in the Base tab, in ` ```base ` blocks and in `![[x.base]]` / `![[x.base#View]]` embeds; Board with lane
  order and hidden lanes in `groupBy`/`groupOrder` and card order in `tephraCardOrder`; Calendar (month, week, agenda, multi-day bars, drag to reschedule keeping
  the original date format); Gallery with a disk thumbnail cache (`.tephra/cache/thumbs/`, 256 px, LRU 200 MB); Timeline (zoom, drag, resize, groups, today line);
  safe note writes with a Bases undo stack; a **New** button on every view (folder, name, template and properties prefilled from filters and from the clicked
  lane/day/group); the command "Create database here".
- **Templates** (steps 06.25–06.26, 06.34–06.35; `packages/tephra_core` + `app/lib/vault/note_tools/` + `app/lib/editor/tephra_button/`): template variables
  `prompt`, `select`, `cursor`, date offsets, `folder`, `vault`, `filename`; frontmatter merge when applying a template; insert / append / new-note modes; per-folder
  default templates and an "ask on new note" picker with preview; a gallery of 12 bundled templates and 4 installable packs (Projects & tasks, Reading list, Habit
  tracker, Simple CRM); ` ```tephra-button ` blocks.
- **Budgets** for the new views: Board and Calendar open in < 500 ms (Windows) / < 1 s (Android) with 2,000 matching notes; all new views stay responsive with 10,000 rows.

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
| Bundled content `app/assets/template_gallery/` (12 templates, 4 packs, `manifest.json`) | Written for Tephra (own content, no third-party licence) | Template gallery and packs | 06.34 |
| **No new packages in steps 06.25–06.36.** Everything uses packages already listed here or present from earlier phases (`yaml`, `yaml_edit`, `crypto` for thumbnail keys, `intl`, `path`, `flutter_riverpod`, `logging`, `flutter_svg` for SVG covers). PNG thumbnails use `dart:ui`; the bench tool's PNG encoder uses `dart:io` `ZLibEncoder`. | — | — | — |
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

### 06.25 Template variables v2: prompts, choices, cursor, date offsets, folder, vault, file name

**Purpose.** Extend the 02.22 template engine (backward compatible) with the variables that make templates feel like Notion's:
questions asked when a template is applied, a caret marker, relative dates and location variables. This step is the engine and the
prompt dialog only; applying templates to notes is 06.26.

**Obsidian compatibility rule (read first).** Obsidian's core Templates plugin only knows `{{title}}`, `{{date}}`, `{{time}}` and their
`:FORMAT` forms and leaves every other `{{...}}` exactly as written. Therefore a template that uses a Tephra-only variable still opens
and works in Obsidian, but the variable appears **literally** (for example `{{prompt:Topic}}`) when that template is inserted by
Obsidian. This is accepted and must be stated in the template gallery text (06.34, l10n `templateGalleryObsidianNote`).
Tephra-only variables: `prompt`, `select`, `cursor`, `folder`, `vault`, `filename`, and date offsets.

**Files**
- `packages/tephra_core/lib/src/template_engine.dart` (modify; `applyTemplate` keeps its exact signature and behaviour for 02.22 inputs)
- `packages/tephra_core/lib/src/template_prompt.dart` (new: `TemplatePrompt`, `TextPrompt`, `ChoicePrompt`, `templatePrompts`, `collectTemplateAnswers`)
- `packages/tephra_core/lib/src/template_date_offset.dart` (new: `shiftDate`)
- `packages/tephra_core/lib/src/template_cancelled_exception.dart` (new)
- `packages/tephra_core/lib/tephra_core.dart` (exports)
- `packages/tephra_core/test/template_engine_v2_test.dart`, `template_prompt_test.dart`, `template_date_offset_test.dart` (new)
- `app/lib/vault/note_tools/template_prompt_dialog.dart` (new)
- `app/test/vault/note_tools/template_prompt_dialog_test.dart` (new)
- `app/lib/l10n/app_en.arb`

**Implementation**
1. Name map: before coding, add to `PROGRESS.md` → "Phase 6 notes → Name map" the real names of: `TemplateService` / `insertTemplate` /
   `TemplatePicker` (02.27), `FrontmatterEditor` and `PropertyTypeRegistry` (02.26), `frontmatterRange`/`splitFrontmatter` (Phase 1),
   `applyTemplate`/`TemplateContext` (02.22), `NoteCreator` (Phase 1), `EditorController.applyEdits`, `editorRegistryProvider`,
   `pendingJumpProvider`, `focusEditorOnOpenProvider`. Use the real names everywhere in steps 06.25–06.36.
2. `TemplateContext` gets three **optional** named fields (existing callers compile unchanged):
   ```dart
   const TemplateContext({required this.title, required this.date, required this.now, this.dateFormat = 'YYYY-MM-DD',
     this.timeFormat = 'HH:mm', this.locale = 'en',
     this.folder = '', this.vaultName = '', this.fileName});
   final String folder;     // vault-relative folder of the note being created/edited, '' = vault root; no leading or trailing '/'
   final String vaultName;  // display name of the vault
   final String? fileName;  // file name with extension; null → '${title}.md'
   ```
3. **Grammar (exact).** One regular expression, case-sensitive, applied left to right in a single pass (an inserted value is never
   re-scanned):
   ```
   \{\{\s*(title|date|time|folder|vault|filename|cursor|prompt|select)(?:([+-])(\d{1,4})([dwmy]))?\s*(?::([^}]*))?\}\}
   ```
   Groups: 1 = name, 2 = offset sign, 3 = offset amount, 4 = offset unit, 5 = argument (everything after the first `:` up to `}`;
   an argument cannot contain `}`). A match is **replaced** according to the table; a match that violates its row's "valid when" column
   is left **exactly as written** (like any unknown variable).
   | Name | Valid when | Replacement |
   |---|---|---|
   | `title` | no offset | `ctx.title` (argument ignored) |
   | `date` | offset optional | `formatMoment(shiftDate(ctx.date, offset), FORMAT)`; `FORMAT` = argument, or `ctx.dateFormat` when the argument is missing or empty |
   | `time` | no offset | `formatMoment(ctx.now, FORMAT)`; `FORMAT` = argument or `ctx.timeFormat` |
   | `folder` | no offset | `ctx.folder` (empty string at the vault root; argument ignored) |
   | `vault` | no offset | `ctx.vaultName` (argument ignored) |
   | `filename` | no offset | `ctx.fileName ?? '${ctx.title}.md'` (argument ignored) |
   | `cursor` | no offset | empty string; the first occurrence records `cursorOffset` (below); later occurrences are also removed |
   | `prompt` | no offset; argument present and its question part non-empty after trimming | the answer for this prompt (below); when no answer is available the match stays literal |
   | `select` | no offset; argument contains `|`; question non-empty; at least one non-empty option | the answer for this choice; when no answer is available the match stays literal |
   Offsets: `+7d` = 7 days later, `-1w` = 7 days earlier, `+1m` = one calendar month later, `-2y` = two calendar years earlier.
   `shiftDate(DateTime t, int amount, String unit)` (`template_date_offset.dart`): `d` adds `amount` days, `w` adds `7*amount` days
   (both via `DateTime(y, m, d + n, h, mi, s)` so daylight-saving changes never move the wall-clock time); `m` adds months and `y` adds
   12 months each, clamping the day to the last day of the target month (31 Jan + 1m = 28/29 Feb; 29 Feb 2028 + 1y = 28 Feb 2029).
   `{{time+1d}}`, `{{title+1d}}` and every other offset on a non-`date` name are invalid → left literal. Amount `0` is valid (`{{date+0d}}`).
4. **Prompt syntax.**
   - `{{prompt:Question}}` and `{{prompt:Question|default}}`: the argument is split at the **first** `|`; the question and the default
     are trimmed; the default may contain further `|` characters. Example: `{{prompt:Topic|Weekly sync}}`.
   - `{{select:Question|a,b,c}}`: question = text before the first `|`; options = the rest split on `,`, each trimmed, empty ones
     dropped, duplicates kept once (first wins). The default answer is the first option.
   - **Same question asked once:** prompts are keyed by `kind:question` (`prompt:Topic`, `select:Topic`; question text trimmed,
     case-sensitive; a `prompt` and a `select` with the same question are two different prompts). Every occurrence of a key renders
     the same answer. The default (or options) of the **first** occurrence in the text wins.
   - Answers are inserted verbatim (a newline in an answer stays a newline). An empty answer to a `prompt` is allowed and renders as
     the empty string.
4a. **Variables inside quoted frontmatter values.** Answers and names are inserted verbatim, which would break YAML for `topic: "{{prompt:Topic}}"` when the answer contains `"` or `\`.
   Rule (applies to the text-valued variables `title`, `folder`, `vault`, `filename`, `prompt` and `select`; never to `date`/`time`): when the template starts with a line `---` and the match lies before the next line that is exactly `---` (the
   frontmatter block), look at the text of the match's line before the match with a leading list marker and a leading `key:` part removed (regular expression `^\s*(?:-\s+)?(?:[^\s:"'][^:]*:\s+)?`):
   - it starts with `"` and contains no further unescaped `"` → the value is inside a double-quoted YAML scalar: in the replacement text `\` becomes `\\`, `"` becomes `\"`, a newline becomes `\n`, a carriage return is dropped;
   - it starts with `'` and contains no further `'` → inside a single-quoted scalar: `'` becomes `''`, newlines become a space;
   - otherwise the value is inserted verbatim.
   Outside the frontmatter block nothing is escaped. `cursorOffset` is computed on the escaped output. Gallery templates (06.34) therefore always quote text variables in their frontmatter.
5. API (`template_prompt.dart`, `template_engine.dart`):
   ```dart
   sealed class TemplatePrompt { const TemplatePrompt(this.question); final String question; String get key; }
   final class TextPrompt extends TemplatePrompt { const TextPrompt(super.question, {this.defaultValue}); final String? defaultValue; }  // key 'prompt:<question>'
   final class ChoicePrompt extends TemplatePrompt { const ChoicePrompt(super.question, this.options); final List<String> options; }   // key 'select:<question>'
   /// Valid prompts of [template] in order of first appearance, one per key.
   List<TemplatePrompt> templatePrompts(String template);
   /// Answers used for previews: text prompt → its default, or '[question]' when it has none; choice → first option.
   Map<String, String> previewAnswers(List<TemplatePrompt> prompts);
   typedef TemplateAsker = Future<String?> Function(TemplatePrompt prompt, int index, int total);   // null = the user cancelled
   /// Asks every prompt of [prompts] not already in [preset], in order; returns key → answer.
   /// Throws [TemplateCancelledException] as soon as one answer is null; nothing else happens before that.
   Future<Map<String, String>> collectTemplateAnswers(List<TemplatePrompt> prompts, TemplateAsker asker, {Map<String, String> preset = const {}});
   final class TemplateCancelledException extends TephraException { const TemplateCancelledException() : super('Template cancelled'); }
   final class RenderedTemplate { const RenderedTemplate(this.text, this.cursorOffset); final String text; final int? cursorOffset; } // UTF-16 offset into text
   RenderedTemplate renderTemplate(String template, TemplateContext ctx, {Map<String, String> answers = const {}});
   String applyTemplate(String template, TemplateContext ctx);   // = renderTemplate(template, ctx).text  (no answers: prompt/select stay literal)
   ```
   `renderTemplate` builds the output in one `StringBuffer`; when it meets the first valid `cursor` it stores `buffer.length` as
   `cursorOffset`. `applyTemplate` therefore removes `{{cursor}}` and leaves unanswered prompts literal. A template without any `{{`
   is returned unchanged (same string instance is acceptable).
6. **Cancel rule.** Callers must call `templatePrompts` + `collectTemplateAnswers` **before** touching any file or editor. A
   `TemplateCancelledException` aborts the whole operation silently (no snackbar, nothing written, no empty note created). Every
   caller in 06.26, 06.33 and 06.35 follows this; there is no partial application.
7. `template_prompt_dialog.dart`: `Future<String?> askTemplatePrompt(BuildContext context, TemplatePrompt p, int index, int total)` is the
   app's `TemplateAsker` (wrap with the `BuildContext` of the root navigator).
   - `TextPrompt`: `AlertDialog` with title = question, a single-line autofocused `TextField` whose initial text = default (all text
     selected), subtitle `"<index+1> of <total>"` only when `total > 1`; Enter = OK; buttons "Cancel" / "OK". Returns the text (possibly empty).
   - `ChoicePrompt`: `SimpleDialog` with one 48 dp `ListTile` per option (the first has focus; Up/Down/Enter work on desktop); tapping
     an option returns it; "Cancel" returns null.
   - Back button, Esc, tapping the scrim: return null (= cancel).
   - Phone width < 840 dp: the same dialogs; the dialog is inset above the keyboard (`MediaQuery.viewInsetsOf`).
8. l10n keys: `templatePromptCount` ("{index} of {total}"), `templatePromptOk`, `templatePromptCancel`, `templateGalleryObsidianNote`
   (the sentence from "Obsidian compatibility rule").

**Tests** (`DateTime(2026, 10, 11, 14, 5, 9)` is `now` and `date`, title `Plan`, `folder: 'Work/Notes'`, `vaultName: 'My Vault'`)
- Backward compatibility: every case of `template_engine_test.dart` from 02.22 still passes unchanged.
- `template_engine_v2_test.dart`:
  - `{{folder}}` → `Work/Notes`; with `folder: ''` → empty string; `{{vault}}` → `My Vault`; `{{filename}}` → `Plan.md`; with
    `fileName: 'Other.md'` → `Other.md`.
  - `{{date+7d:YYYY-MM-DD}}` → `2026-10-18`; `{{date-1w}}` → `2026-10-04`; `{{date+1m:MMM D}}` → `Nov 11`; `{{date-2y:YYYY}}` → `2024`;
    `{{date+0d}}` → `2026-10-11`; `{{date+7d}}` (no format) uses `ctx.dateFormat`; with `dateFormat: 'DD/MM/YYYY'` → `18/10/2026`;
    month clamp: date 2026-01-31, `{{date+1m}}` → `2026-02-28`; leap: date 2028-02-29, `{{date+1y}}` → `2029-02-28`; `{{date+12345d}}`
    (five digits) → literal; `{{date+7x}}` → literal; `{{time+1d}}` → literal; `{{title+1d}}` → literal; `{{ date+7d }}` → `2026-10-18`.
  - `{{cursor}}`: template `A{{cursor}}B{{cursor}}C` → text `ABC`, `cursorOffset == 1`; a template without cursor → `cursorOffset == null`;
    `{{title}}{{cursor}}` → text `Plan`, offset 4; a multi-byte answer before the marker counts UTF-16 units (`{{prompt:X}}{{cursor}}`
    with answer `😀` → offset 2).
  - `{{prompt:Topic}}` with `answers: {'prompt:Topic': 'Sync'}` → `Sync`; without answers → literal `{{prompt:Topic}}`;
    `{{prompt:Topic}} and {{prompt:Topic|x}}` → both `Sync` and `templatePrompts` returns one prompt with `defaultValue == null`
    (first occurrence wins); `{{prompt:Topic|a|b}}` → default `a|b`; `{{prompt:}}`, `{{prompt: }}` → literal; `{{prompt}}` → literal.
  - `{{select:Kind|a, b ,,c}}` → options `[a, b, c]`; `{{select:Kind}}` and `{{select:Kind|}}` and `{{select:|a}}` → literal;
    `{{prompt:Kind}}` plus `{{select:Kind|a,b}}` → two prompts.
  - An answer containing `{{title}}` is inserted verbatim (not re-expanded); an answer with a newline keeps it.
  - Frontmatter quoting (4a), template `---\ntopic: "{{prompt:T}}"\nnote: '{{prompt:T}}'\nplain: {{prompt:T}}\n---\n{{prompt:T}}` with answer `a "b" \ c` → `topic: "a \"b\" \\ c"`, `note: 'a "b" \ c'`, `plain: a "b" \ c`, and the body line `a "b" \ c`; answer `it's` in the single-quoted position → `'it''s'`; an answer with a newline inside the double-quoted position → `\n` (backslash n); `{{date:YYYY}}` inside quotes is untouched; `- "{{prompt:T}}"` (list item) is escaped like a scalar; a `{{prompt:T}}` after the closing `---` is never escaped.
  - Unknown `{{foo}}`, `{{Date}}` (capital D), `{{ title ` (unclosed) → unchanged.
- `template_prompt_test.dart`: `previewAnswers` for `{{prompt:A|x}}{{prompt:B}}{{select:C|p,q}}` → `{prompt:A: x, prompt:B: [B], select:C: p}`;
  `collectTemplateAnswers` asks in order, skips keys in `preset`, passes `(index, total)` = `(0,2)`, `(1,2)`; an asker returning
  null on the second prompt throws `TemplateCancelledException` after exactly 2 asks; zero prompts → zero asks.
- `template_date_offset_test.dart`: the clamp cases above; a DST case (`Europe/Berlin` is not available in tests, so assert with
  `DateTime(2026, 3, 28, 12, 0)` + `1d` → `DateTime(2026, 3, 29, 12, 0)` wall-clock hour unchanged).
- `template_prompt_dialog_test.dart` (widget): text prompt shows default selected; typing + Enter returns the text; Cancel returns null;
  choice prompt returns the tapped option; Esc returns null; at 400 dp option rows are ≥ 48 dp.

**Verify**
```
cd packages/tephra_core; dart test; cd ../..
cd app; flutter test test/vault/note_tools; cd ..
```
Success: all pass; the 02.22 tests are unchanged and green.

**Pitfalls**
- Do not make `applyTemplate` ask or fail: daily notes and the unique note creator call it (06.26 moves them to the prompt-aware path
  with prompts disabled).
- Never add an escape syntax (`\{{`): Obsidian has none, and templates must mean the same thing in both apps for the shared variables.
- `{{date+7d}}` uses `ctx.date`, not `ctx.now`: in a daily note it is relative to the note's own date.

---

### 06.26 Applying templates: frontmatter merge, insert/append, new-note picker, folder defaults

**Purpose.** One service applies a template three ways (insert at the caret, append to a note, create a new note), merges template
properties into existing frontmatter without reformatting it, and lets "New note" use a per-folder default template or ask.

**Files** (new unless marked; folder `app/lib/vault/note_tools/`)
- `template_applier.dart`, `template_merge.dart`, `note_factory.dart`, `template_resolution.dart`, `new_note_flow.dart`,
  `template_preview.dart`
- modify: `template_service.dart`, `template_picker.dart`, `daily_notes_service.dart`, `unique_note_service.dart`, `note_tools_commands.dart`,
  `note_tools_settings.dart`, `providers.dart`
- vault settings model/store (add keys below), explorer folder context menu and header "New note" action (modify), Phase 1 "new note" command (modify to call `NewNoteFlow`)
- `app/lib/l10n/app_en.arb`
- tests: `app/test/vault/note_tools/template_merge_test.dart`, `template_applier_test.dart`, `note_factory_test.dart`,
  `template_resolution_test.dart`, `new_note_flow_test.dart`, `template_picker_v2_test.dart`

**Implementation**
1. **Settings** (vault, `.tephra/settings.json`, nested `templates` object; unknown keys preserved; Phase 7 registry names in column 1):
   | Registry name | JSON path | Type | Default |
   |---|---|---|---|
   | `templates.askOnNewNote` | `templates.askOnNewNote` | bool | `false` |
   | `templates.folderDefaults` | `templates.folderDefaults` | map folder path → template path | `{}` |
   Example:
   ```json
   { "templates": { "folder": "Templates", "askOnNewNote": true,
       "folderDefaults": { "Projects/Tasks": "Templates/Task.md", "Journal": "Templates/Daily journal.md", "Archive": "" } } }
   ```
   Keys are normalised when read: backslashes → `/`, leading/trailing `/` removed; `""` and `"/"` both mean the vault root. A value of
   `""` means **explicitly no template** for that folder (it also suppresses asking). Values are vault paths of `.md` files (with or without
   `.md`). Invalid shapes (a list, a non-string value) → entry ignored with a `warning`. The settings screen section "Templates" (02.27)
   gets one switch, "Ask for a template when creating a note" (`settingTemplatesAskOnNew`); the folder map has no editor in this phase
   except the explorer menu items of sub-step 9 (Phase 7 may add a table).
2. `template_resolution.dart` (pure Dart, no Flutter):
   ```dart
   sealed class FolderTemplate { }
   final class FolderTemplateNone extends FolderTemplate { }          // explicit "" entry
   final class FolderTemplatePath extends FolderTemplate { const FolderTemplatePath(this.path); final String path; }
   final class FolderTemplateNoMatch extends FolderTemplate { }
   FolderTemplate resolveFolderTemplate(Map<String, String> folderDefaults, String folder);
   ```
   Algorithm: normalise `folder` (same rules as keys); for every normalised key `k`, `k` matches when `k == ''`, or
   `folder.toLowerCase() == k.toLowerCase()`, or `folder.toLowerCase().startsWith('${k.toLowerCase()}/')`. Choose the match with the
   **longest** `k` (path-segment prefix, never a raw string prefix: `Proj` does not match `Projects`). Value `''` → `FolderTemplateNone`;
   else `FolderTemplatePath`; no match → `FolderTemplateNoMatch`.
3. `note_factory.dart`:
   ```dart
   String sanitizeFileName(String raw);   // see below
   final class NoteFactory {
     NoteFactory(this.fs);
     /// First free path: folder/<name>.md, then "<name> 1", "<name> 2", … (stat-based; case-insensitive on Windows via fs.stat).
     Future<VaultPath> reserve(VaultPath folder, String baseName);
     /// Writes [text] atomically to [path]. If [path] was taken meanwhile, writes to the next free suffix. Returns the path used.
     Future<VaultPath> create(VaultPath path, String text);
   }
   ```
   `sanitizeFileName`: replace each of `\ / : * ? " < > | [ ] ^ #` and every control character (< U+0020) with `-`; trim spaces and dots from both ends;
   collapse runs of spaces to one; cut to 120 runes; empty result → `Untitled`; a Windows reserved device name (`CON PRN AUX NUL COM1`…`COM9`
   `LPT1`…`LPT9`, case-insensitive, with or without extension) gets `_` appended. Text is written with `TextDocument(text: text)` (LF, no BOM).
4. `template_merge.dart` — frontmatter merge and edit planning (pure functions over note text; uses `FrontmatterEditor` of 02.26):
   ```dart
   /// Merge rules, per template key K with template value T and note value N (N absent, or null, or '' , or an empty list = "empty"):
   ///  - N empty → K := T.
   ///  - K is 'tags', 'aliases' or 'cssclasses' → union as lists: N and T are first turned into lists (a string is split on commas
   ///    (and, for tags, whitespace), a leading '#' of a tag is removed); result = N items in order, then T items not already present (case-sensitive). Written as a YAML list.
   ///  - otherwise (scalar or any other list) → N wins; T is ignored.
   Map<String, Object?> mergeProperties(Map<String, Object?> note, Map<String, Object?> template);
   final class TemplateEditPlan { const TemplateEditPlan(this.edits, this.caretAfter); final List<TextEdit> edits; final int? caretAfter; } // edits in OLD-text coordinates; caretAfter in NEW-text coordinates
   TemplateEditPlan planInsertTemplate({required String noteText, required RenderedTemplate rendered, required int caret, required int selectionEnd});
   TemplateEditPlan planAppendTemplate({required String noteText, required RenderedTemplate rendered});
   String applyPrefill(String text, Map<String, Object?> prefill);    // sets each key (prefill WINS over the template), via FrontmatterEditor.setValue; creates the block when missing
   ```
   (Differences from 02.27, intentional: only `tags`, `aliases` and `cssclasses` are unioned; other lists keep the note's value; "empty"
   note values are filled from the template. Update the 02.27 tests that asserted the old rule for other list keys, if any, and record
   it in `PROGRESS.md` → Conflicts.)
   `planInsertTemplate`: split `rendered.text` with `frontmatterRange`: `tplProps` = `FrontmatterEditor.read` of the template's block (`{}` if none), `tplBody` = text after the block.
   `noteProps` = `FrontmatterEditor.read(noteText)`. Edit A (only when `tplProps` is non-empty and the merge changes something): computed by applying
   `FrontmatterEditor.setValue` for each key whose merged value differs from the note's value, one after another on the evolving text; the edit is the
   smallest single replacement within the frontmatter region (or a whole new block at offset 0 when the note had none). Edit B: insert `tplBody` at
   `bodyAt` = `caret` when `caret >= fmEnd` (replace `[caret, selectionEnd)` when the selection lies fully after `fmEnd`), else at `fmEnd`, where `fmEnd` is `frontmatterRange(noteText).end`
   (the offset after the closing `---` line including its newline; 0 when none, unless Edit A creates a block, then B goes right after the new block).
   Edits starting at the same offset are merged into one (block first). `caretAfter` = start of the inserted body in the new text + the cursor offset **within the body**
   (`rendered.cursorOffset − bodyStartInRendered`, only when the marker is inside the body); without a marker, the end of the inserted body.
   `planAppendTemplate`: Edit A as above. Edit B inserts at the end of the note's text: let `base` = the text after Edit A; if `base` is non-empty and does not end with `\n`
   add `\n`; if the part of `base` after its frontmatter contains a non-blank line and does not end with a blank line, add one more `\n`; then `tplBody`. `caretAfter` = marker position
   inside the appended body, else `null` (caret untouched).
5. `template_applier.dart` (`templateApplierProvider`):
   ```dart
   final class TemplateApplier {
     /// Reads the template (resolving 'Name' → 'Name.md' like 02.27), asks all prompts (cancel → TemplateCancelledException), renders.
     Future<RenderedTemplate> render(VaultPath templatePath, TemplateContext ctx, {required TemplateAsker? asker, Map<String, String> preset = const {}, Iterable<String> extraTemplates = const []});
     Future<void> insertIntoActiveEditor(EditorController c, VaultPath templatePath, TemplateAsker asker);   // planInsertTemplate → one applyEdits
     Future<void> appendToNote(VaultPath note, VaultPath templatePath, TemplateAsker asker);                // open editor: applyEdits; else read, plan, writeText only if changed
     /// Creates a note. [nameTemplate] is rendered like body text (title = 'Untitled', cursor removed) and sanitised.
     Future<VaultPath> createFromTemplate({required VaultPath folder, String nameTemplate = 'Untitled', VaultPath? templatePath,
       Map<String, Object?> prefill = const {}, Set<String> removeKeys = const {}, required TemplateAsker? asker, bool open = true});
   }
   ```
   - **Prompt gathering:** `templatePrompts` is run on the template text **and** on `nameTemplate` (and for the button of 06.35 on `folder`), the lists are merged
     by key, and one `collectTemplateAnswers` call asks them all, so a question shared by name and body is asked once. `asker == null` means "no UI" (daily notes,
     unique notes): every text prompt answers with its default, or `''` when it has none (never the `[question]` placeholder of `previewAnswers`), and every choice answers with its first option.
   - Context: `TemplateContext(title: noteStem, date: now, now: now, dateFormat/timeFormat from settings, folder: folder.value, vaultName: vaultNameProvider, fileName: '<stem>.md')`.
   - `createFromTemplate` order (nothing is written before step 6): (1) read template (missing/unreadable → throw `TemplateMissingException(path)`, extends `TephraException`; callers show
     `templateUnreadable`), (2) collect answers, (3) render the name → `baseName = sanitizeFileName(...)`, (4) `path = factory.reserve(folder, baseName)`, (5) render the body with
     `title = path.stem`, (6) `text = applyPrefill(body, prefill)` when `prefill` is non-empty (no template: `text = applyPrefill('', prefill)`), then `FrontmatterEditor.removeKey` for every key of `removeKeys` (this also deletes keys the template wrote; used by 06.33), (7) `factory.create(path, text)`,
     (8) when `open`: `openFile(ref, usedPath)`, set `focusEditorOnOpenProvider` true and `pendingJumpProvider` to the offset `cursorOffset + (block length added by applyPrefill)`
     when the template had a cursor marker (else offset 0 stays default).
   - `insertIntoActiveEditor` / `appendToNote` use the editor's current text when an editor is registered (`editorRegistryProvider`), otherwise `fs.readText`; the write path
     preserves BOM/line ending (§6.2). Both call `collectTemplateAnswers` before computing the plan.
6. **Migrate old callers:** `TemplateService.insertTemplate` (02.27) now calls `insertIntoActiveEditor`. `DailyNotesService.openOrCreate` and `UniqueNoteService.create` call
   `TemplateApplier.render(..., asker: null)` so they gain the new variables (`{{cursor}}` is removed; `{{folder}}`, `{{vault}}`, `{{filename}}`, date offsets work; prompts use
   the no-UI rule). Their 02.27 tests must still pass unchanged (the new variables do not occur in them).
7. `new_note_flow.dart`:
   ```dart
   /// Entry point for every user-initiated "New note" (explorer, header button, command, phone FAB). Returns the created path or null if cancelled.
   Future<VaultPath?> newNoteInFolder(WidgetRef ref, BuildContext context, {VaultPath? folder, bool forcePicker = false});
   ```
   Algorithm: `folder ??=` the folder Phase 1's `NoteCreator` would use (add `NoteCreator.defaultFolder()` as a pure refactor of that rule if it has no such method).
   `r = resolveFolderTemplate(settings.templates.folderDefaults, folder.value)`.
   (a) `forcePicker` → open the picker (sub-step 8).
   (b) `FolderTemplatePath(p)` and the file exists → `createFromTemplate(folder, templatePath: p, asker: askTemplatePrompt)`; the file does not exist → snackbar
       `templateDefaultMissing` and continue as `FolderTemplateNoMatch`.
   (c) `FolderTemplateNone` → empty note via Phase 1's `noteCreatorProvider` (unchanged behaviour).
   (d) `FolderTemplateNoMatch` and `askOnNewNote` → picker; the picker's first row "Empty note" gives the Phase 1 behaviour; closing the picker (Esc/back/scrim) creates **nothing**.
   (e) otherwise → Phase 1's empty note (unchanged behaviour, exactly as before this step).
   `TemplateCancelledException` anywhere → return null silently. With no `templates.folder` configured the picker still opens but lists only "Empty note" plus a hint
   `templatesFolderNotSet`.
8. Picker (`template_picker.dart`, extend 02.27): rows = optional "Empty note" row (only when opened from `newNoteInFolder`) + `templateFiles()` filtered by `FuzzyScorer` on the
   file stem (subtitle = path relative to the templates folder). **Preview:** desktop (≥ 840 dp) shows a right pane with the selected template rendered by the reading view of
   Phase 1 (`ReadingView`/its text widget) from `renderTemplate(text, ctx(title: 'Untitled'), answers: previewAnswers(templatePrompts(text))).text` with the frontmatter shown as
   a plain properties list; phone: each row has a "Preview" icon button (48 dp) that opens a bottom sheet with the same content; tapping the row itself selects. `template_preview.dart`
   builds that preview text. Keyboard: Up/Down move, Enter selects, Esc closes.
9. Commands (ids final; palette on; no default shortcuts; labels in l10n): `templates.new-note-from-template` ("New note from template": `newNoteInFolder(forcePicker: true)` in the explorer-selected folder, else
   the active note's folder, else the default folder), `templates.append-template` ("Append template to note": picker → `appendToNote(activeNote, …)`, unavailable without an active note),
   existing `templates.insert-template` (02.27). Explorer folder context menu gets "New note from template…" and "Set default template…" (opens the picker; choosing writes
   `templates.folderDefaults[folder] = <template path>`; the picker's "Empty note" row in this mode is labelled "No template" and writes `""`) and, when an entry exists for
   exactly that folder, "Clear default template" (removes the entry). All three write `.tephra/settings.json` through `vaultSettingsProvider` only if the map changed.
10. l10n keys: `commandNewNoteFromTemplate`, `commandAppendTemplate`, `explorerNewNoteFromTemplate`, `explorerSetDefaultTemplate`, `explorerClearDefaultTemplate`,
    `templatePickerEmptyNote`, `templatePickerNoTemplate`, `templatePickerPreview`, `templateDefaultMissing`, `settingTemplatesAskOnNew`.

**Tests**
- `template_merge_test.dart` (note `N`, template `T`; compare with `FrontmatterEditor.read` and, where stated, bytes):
  - `N = "---\ntags: [a]\nstatus: x\n---\nText"`, `T` props `{tags:[b,a], status:y, new:1}` → `tags == [a,b]`, `status == x`, `new == 1`, and the lines `status: x` and `Text` are byte-identical.
  - `N` without frontmatter, `T` props `{tags:[t]}` → block `---\ntags:\n  - t\n---\n` at offset 0 (compare parsed value), body inserted after it.
  - `N` has `title:` (null) and `status: ""` → both filled from the template; `N` has `rating: 5`, template `rating: 1` → 5.
  - `N` has `tags: "a, b"` (string) and template `tags: [c]` → `[a, b, c]`; template `tags: "#x y"` → items `x`, `y`.
  - Other list keys: `N: related: [p]`, `T: related: [q]` → `[p]` (note wins).
  - Comments and key order in `N`'s frontmatter survive (`# keep` line byte-identical).
  - `planInsertTemplate`: caret inside the note's frontmatter → body inserted at `fmEnd`; caret in body with selection `[5,8)` → selection replaced; template body `Hi {{cursor}}there` (rendered cursorOffset 3) inserted at 10 → `caretAfter == 13`.
  - `planAppendTemplate`: `N = "Hello"` + body `B` → `"Hello\n\nB"`; `N = "Hello\n"` → `"Hello\n\nB"`; `N = "Hello\n\n"` → `"Hello\n\nB"`; `N = "---\na: 1\n---\n"` (empty body) → `"---\na: 1\n---\nB"`; empty note `""` → `"B"`.
  - `applyPrefill('Body', {'status': 'todo'})` → block created; `applyPrefill` over a template block with `status: backlog` and prefill `status: todo` → `status: todo` (prefill wins) and other lines identical; list value `['a']` writes a list.
- `template_resolution_test.dart`: map `{Projects: A.md, "Projects/Tasks": T.md, "": R.md, Archive: ""}`; `Projects/Tasks/Sub` → `T.md`; `Projects/Other` → `A.md`; `ProjectsX` → `R.md` (root key); `Archive/Old` → none; `projects/tasks` (case) → `T.md`; a map without `""` and folder `Elsewhere` → no match; key `/Projects/` normalises to `Projects`; value of the wrong type ignored.
- `note_factory_test.dart` (`MemoryVaultFileSystem(caseInsensitive: true)`): `Untitled` free → `Untitled.md`; with `Untitled.md` and `untitled 1.md` present → `Untitled 2.md`; `a/b:c?` → `a-b-c-`→ trimmed `a-b-c`; `CON` → `CON_`; 130-rune name cut to 120; empty → `Untitled`; `create` when the target appears between `reserve` and `create` → written to the next suffix, no overwrite (assert both files' contents).
- `template_applier_test.dart`: `createFromTemplate` with template `---\nstatus: backlog\n---\n# {{title}}\n{{prompt:Topic}}{{cursor}}` and name `{{date:YYYY-MM-DD}} {{prompt:Topic}}`, answer `Sync` → file `2026-10-11 Sync.md`, **one** prompt asked, text `---\nstatus: backlog\n---\n# 2026-10-11 Sync\nSync`, pending jump offset = text length; a cancelling asker → no file, no exception escapes `newNoteInFolder`, `fs` write count 0; prefill `{status: todo, tags: ['x']}` wins over the template's `status`; missing template → `TemplateMissingException`, nothing written; `appendToNote` on a closed note writes once per call (two calls append twice, in order); `insertIntoActiveEditor` calls `applyEdits` exactly once (one undo step) and `controller.undo` restores the original text byte-for-byte.
- `new_note_flow_test.dart`: folder default hit → note created from the template without any picker; `Archive` entry `""` with `askOnNewNote: true` → empty note, no picker; no entry + `askOnNewNote: true` → picker shown, choosing "Empty note" creates the Phase 1 empty note; picker dismissed → nothing created; `askOnNewNote: false` and no entry → Phase 1 behaviour; default template file missing → snackbar + empty note.
- `template_picker_v2_test.dart`: preview pane at 1200 dp shows rendered text with `[Topic]` for an unanswered prompt; at 400 dp rows have a Preview button of ≥ 48 dp; "Set default template…" writes `templates.folderDefaults` once and a second identical choice writes 0 times.

**Verify**
```
cd app; flutter test test/vault/note_tools; cd ..
```
Manual (both platforms): configure `Templates` with a template using `{{prompt:Topic}}`, `{{select:Kind|Idea,Bug}}` and `{{cursor}}`; set a folder default through the explorer menu; "New note" in that folder asks both questions once each and puts the caret at the marker; Cancel at the second question leaves no file; "Insert template" into a note that already has `tags:` merges them (open the note in Obsidian: properties intact).

**Pitfalls**
- Prompts first, writes later: never create the file before the last question is answered.
- `frontmatterRange(...).end` includes the closing line's newline; inserting the body one character earlier corrupts the closing `---`.
- Do not apply a folder default to notes created by other features (daily, unique, link-created, capture): only user-initiated "New note" paths call `newNoteInFolder`.

---

### 06.27 Bases model v2: Obsidian view types, Tephra-only views, typed options, lossless option edits

**Purpose.** Teach the Bases model (06.16) and executor (06.18) the view types Tephra now renders and their options, without ever
changing what an Obsidian-only reader sees: Obsidian's own YAML for Obsidian's own view types, Tephra-only types and keys that Obsidian
simply preserves, and byte-lossless edits for all of it.

**Decision: which view types exist (checked against Obsidian's help, `https://obsidian.md/help/bases/views`, in October 2026).**
Obsidian's core Bases supports the layouts **Table** (1.9), **Cards** (1.9), **List** (1.10), **Kanban** (1.14) and **Map** (1.10, needs
Obsidian's Maps plugin); community plugins may add more. The public syntax page (`https://obsidian.md/help/bases/syntax`) shows
`type: table` and `type: kanban`, and for a Kanban view the general view keys `groupBy` (`property`, `direction`) and `groupOrder` (list of
the groups to show, in order; `null` stands for files without a value; omitting `groupOrder` shows all groups; an empty list hides all).
The YAML key names of the other per-view options (list markers, kanban column width, kanban image keys) are **not** documented on those pages.
Consequences, all binding:
| Tephra feature | `type` value | Reason |
|---|---|---|
| Table, Cards | `table`, `cards` | unchanged (06.16) |
| List | `list` | Obsidian has it; Tephra renders the same type |
| **Board** | **`kanban`** (not `tephra-board`) | Obsidian has Kanban; the user's own `.base` boards must be the same views in both apps. Lane order and hidden lanes use Obsidian's `groupBy` + `groupOrder`; card order and lane width use Tephra-only keys |
| Calendar | `tephra-calendar` | Tephra-only |
| Gallery | `tephra-gallery` | Tephra-only (Obsidian's `cards` with an image property is similar, but Gallery has thumbnails, sizes and body-image fallback) |
| Timeline | `tephra-timeline` | Tephra-only |
| Map | `map` | Obsidian-only; shown as unsupported and preserved |
Tephra-only **option keys** always start with `tephra` (camelCase). Where Tephra reuses an Obsidian key it reuses its documented meaning:
`groupBy`, `groupOrder`, `order`, `sort`, `filters`, `limit`, and for images the three Cards keys already used in 06.16 (`image`,
`imageFit`, `imageAspectRatio`). **Assumption to verify (06.36):** a Kanban view made by Obsidian stores its image settings under the same
keys as Cards; if the manual check shows different key names, record them in `PROGRESS.md`, keep reading the Cards names as a fallback and
additionally read the Obsidian names; never delete unknown keys. Everything unknown stays untouched by every edit (06.16 model).

**Files**
- `packages/tephra_search/lib/src/bases/base_view.dart` (modify), `base_document.dart` (modify), `base_editor.dart` (modify), `base_query.dart` (modify)
- `packages/tephra_search/lib/src/bases/views/view_types.dart`, `view_options.dart`, `property_ids.dart` (new)
- `packages/tephra_search/lib/tephra_search.dart` (exports)
- `test_vaults/syntax/bases/` new fixtures: `kanban.base`, `list.base`, `tephra-views.base`, `map-unsupported.base`, `tephra-options-invalid.base`
- `packages/tephra_search/test/bases/views/view_options_test.dart`, `property_ids_test.dart`, `base_editor_v2_test.dart`, `base_query_v2_test.dart` (new)

**Implementation**
1. `view_types.dart`:
   ```dart
   abstract final class BaseViewTypes {
     static const table = 'table', cards = 'cards', list = 'list', kanban = 'kanban', map = 'map';
     static const calendar = 'tephra-calendar', gallery = 'tephra-gallery', timeline = 'tephra-timeline';
     static const supported = {table, cards, list, kanban, calendar, gallery, timeline};
     static const tephraOnly = {calendar, gallery, timeline};
     /// Types written by "New view": order of the "+" menu.
     static const creatable = [table, cards, list, kanban, calendar, gallery, timeline];
   }
   ```
   `BaseView.isSupported` becomes `BaseViewTypes.supported.contains(type)` (it was `table || cards`). `BaseView` gets
   `final List<Object?>? groupOrder` (parsed from `groupOrder`; `null` list = key absent; the YAML `null` element stays a Dart `null` element).
   `BaseDocument` gets `final Map<String, Object?> raw` (the whole decoded top-level map, for `tephra*` top-level keys).
2. `property_ids.dart`:
   ```dart
   /// Frontmatter key a property id writes to, or null when the id is not an editable note property.
   String? frontmatterKeyOf(String propertyId);
   ```
   `note.<x>` → `<x>`; `file.tags` → `tags`; any id starting with `file.` (other) or `formula.` → `null`; any other id (a bare name, which may
   contain dots) → itself. Boards, calendars and timelines write only through this function; `null` makes the view read-only for that property
   (dragging is disabled and a tooltip `basesPropertyReadOnly` explains why).
3. `view_options.dart`: immutable typed readers over `BaseView.raw` / `BaseDocument.raw`. A bad value never throws: the default is used and
   one `BaseIssue(code: 'invalidViewOption', viewIndex, key)` is added to `doc.issues`.
   | Key (in the view map unless noted) | Used by | Type / allowed values | Default |
   |---|---|---|---|
   | `groupBy.property`, `groupBy.direction` | kanban (required), table, cards, list, gallery, timeline (row groups) | property id; `ASC`/`DESC` | none / `ASC` |
   | `groupOrder` | kanban | list of scalars and `null` | absent (all lanes shown, sorted by direction) |
   | `tephraLaneWidth` | kanban | int 200–480 | 280 |
   | `tephraCardOrder` | kanban | map laneKey → list of vault paths (strings). `laneKey` = the lane value as text (`done`, `true`, `3`), and `__none__` for the "No value" lane | `{}` |
   | `tephraStartProperty` | calendar, timeline | property id | calendar `note.date`; timeline `note.start` |
   | `tephraEndProperty` | calendar, timeline | property id | calendar none; timeline `note.end` |
   | `tephraCalendarMode` | calendar | `month` \| `week` \| `agenda` | `month` |
   | `tephraWeekStart` | calendar | `sunday` \| `monday` \| `saturday` | absent → vault setting `bases.firstDayOfWeek` |
   | `tephraZoom` | timeline | `day` \| `week` \| `month` \| `quarter` | `week` |
   | `tephraGallerySize` | gallery | `small` \| `medium` \| `large` | `medium` |
   | `image`, `imageFit` | gallery, kanban, cards | property id; `cover` \| `contain` | none; `cover` |
   | `tephraCoverFromBody` | gallery | bool | `true` |
   | `tephraListMarker` | list | `bullet` \| `number` \| `none` | `bullet` |
   | `tephraListSeparator` | list | string | `, ` |
   | `tephraNewNoteFolder`, `tephraNewNoteName`, `tephraNewNoteTemplate` | all views; read from the **view** first, then from the **top level** of the document | string | folder of the `.base` file; `Untitled`; none |
   Classes: `BoardOptions`, `CalendarOptions`, `TimelineOptions`, `GalleryOptions`, `ListOptions`, `NewNoteOptions` each with
   `factory X.fromView(BaseView view)`; `NewNoteOptions.resolve(BaseDocument doc, BaseView view)` applies the view-then-top-level rule.
   Enums: `CalendarMode { month, week, agenda }`, `WeekStart { sunday, monday, saturday }`, `TimelineZoom { day, week, month, quarter }`,
   `GallerySize { small, medium, large }`, `ListMarker { bullet, number, none }`.
4. **Example of a `.base` using everything** (this exact text is the fixture `tephra-views.base`; the pack files of 06.34 follow the same shapes):
   ```yaml
   filters:
     and:
       - file.inFolder("Projects")
       - 'file.ext == "md"'
   tephraNewNoteFolder: Projects
   tephraNewNoteTemplate: Templates/Project brief.md
   properties:
     note.status:
       displayName: Status
   views:
     - type: table
       name: Table
       order:
         - file.name
         - note.status
     - type: kanban
       name: Board
       groupBy:
         property: note.status
         direction: ASC
       groupOrder:
         - Planned
         - Active
         - null
       order:
         - file.name
         - note.due
       image: note.cover
       tephraLaneWidth: 300
       tephraCardOrder:
         Planned:
           - Projects/Alpha.md
           - Projects/Beta.md
     - type: list
       name: List
       order:
         - file.name
         - note.status
       tephraListMarker: number
     - type: tephra-calendar
       name: Calendar
       tephraStartProperty: note.due
       tephraEndProperty: note.end
       tephraCalendarMode: month
     - type: tephra-gallery
       name: Gallery
       image: note.cover
       imageFit: cover
       tephraGallerySize: medium
     - type: tephra-timeline
       name: Timeline
       tephraStartProperty: note.start
       tephraEndProperty: note.due
       tephraZoom: week
       groupBy:
         property: note.status
         direction: ASC
     - type: map
       name: Map
       futureKey: 1
   ```
5. `BaseEditor` additions (additive; all through `YamlEditor`; every method is a no-op that leaves `changed == false` when the new value equals the old one):
   ```dart
   void setViewKey(int viewIndex, String key, Object? value);        // value: String/num/bool/List/Map (JSON-like); null → removes the key
   void removeViewKey(int viewIndex, String key);
   void setTopLevelKey(String key, Object? value);                     // null → removes
   void setGroupBy(int viewIndex, String property, {bool descending = false});   // writes groupBy: {property, direction}
   void setGroupOrder(int viewIndex, List<Object?>? order);            // null removes the key; [] writes an empty list
   void setCardOrder(int viewIndex, String laneKey, List<String> paths);          // empty list removes that lane entry; empty map removes tephraCardOrder
   void removeFromCardOrder(int viewIndex, String laneKey, String path);
   void duplicateView(int viewIndex);                                  // appends a copy named '<name> copy' (comments inside the copy are not kept)
   void addView(String type, String name, {Map<String, Object?> extra = const {}});    // extra keys appended after type and name
   ```
   Scalars that `yaml_edit` would misparse (a date-like or `null`-like string, a string with `: `) are written with `wrapAsYamlNode(v, scalarStyle: ScalarStyle.DOUBLE_QUOTED)`. A `null` **element** inside `groupOrder` is written as the YAML `null` scalar, never the string `"null"`.
   Edits inside flow-style nodes (`groupOrder: [A, B]`) are rewritten by replacing the whole `groupOrder` node, which keeps the key's position; if `yaml_edit` throws, use the 06.16 `basesEditUnsupported` path.
6. `runBaseQuery` additions (named parameters, defaults keep 06.18 behaviour):
   ```dart
   BaseQueryResult runBaseQuery(BaseDocument doc, int viewIndex, BaseDataset data, {VaultPath? thisPath, required DateTime now,
     List<String> extraColumns = const [], bool skipGroupBy = false});
   ```
   `BaseResultRow` gets `final Map<String, Object?> extraRaw`: for every property id in `extraColumns`: a `note.*`/bare id → the **raw frontmatter value** (YAML-decoded: String, num, bool, List, Map, null),
   `file.ctime`/`file.mtime` → ISO text `YYYY-MM-DDTHH:mm`, `file.tags` → `List<String>` of tags, any other `file.*` and `formula.*` → `displayValue(...)` as String. `skipGroupBy: true` does not partition rows by `groupBy` (the Board builds its own lanes from `extraRaw`, 06.29)
   but still applies the sort and `limit`. The row also exposes `final String title` (file basename without extension) so views never call the index per row. Kanban/calendar/timeline/gallery views pass the ids they need
   (`groupBy.property`, start/end/image properties, and all `order` columns).
7. Unsupported or unknown types: `BaseViewTypes.map` and any other string stay `isSupported == false`: the UI shows the 06.19 "unsupported" card with the view's YAML; they are never rewritten.

**Tests**
- `view_options_test.dart`: `tephra-views.base` → kanban `BoardOptions`: group `note.status` ASC, `groupOrder == ['Planned','Active',null]`, `laneWidth 300`, `cardOrder['Planned'] == ['Projects/Alpha.md','Projects/Beta.md']`;
  calendar: start `note.due`, end `note.end`, mode `month`, `weekStart == null`; timeline: zoom `week`, group by `note.status`; gallery: `image note.cover`, fit `cover`, size `medium`; list: marker `number`;
  `map` view → `isSupported == false` and `raw['futureKey'] == 1`; defaults: a bare `{type: tephra-calendar}` view → start `note.date`, end null, mode month; bare `{type: tephra-timeline}` → start `note.start`, end `note.end`, zoom week;
  `tephra-options-invalid.base` (`tephraLaneWidth: 9999`, `tephraCalendarMode: year`, `tephraZoom: 3`, `tephraGallerySize: huge`, `tephraListMarker: dots`, `tephraCardOrder: [1,2]`) → every option falls back to its default, 6 `invalidViewOption` issues, no exception;
  `NewNoteOptions.resolve`: view value wins over top-level; top-level used when the view has none; empty strings count as absent.
- `property_ids_test.dart`: `note.status` → `status`; `status` → `status`; `file.tags` → `tags`; `file.name` → null; `formula.x` → null; `a.b` → `a.b`; `note.a.b` → `a.b`.
- `base_editor_v2_test.dart` (base text = `tephra-views.base`): `setGroupOrder(1, ['Planned', null])` changes only the `groupOrder` lines of view 1 (line diff) and the `null` stays the YAML `null` (re-parse gives a Dart `null` element);
  `setCardOrder(1, 'Active', ['Projects/C.md'])` adds an `Active:` entry under `tephraCardOrder` without touching `Planned`; `setCardOrder(1,'Planned', [])` removes only that lane, and removing the last lane removes `tephraCardOrder`;
  `setViewKey(3, 'tephraCalendarMode', 'week')` changes one line; `setViewKey(3,'tephraCalendarMode','week')` on a text that already has it → `changed == false`; `setTopLevelKey('tephraNewNoteFolder', null)` removes that line only;
  `addView('tephra-timeline','Timeline 2', extra: {'tephraZoom':'month'})` appends a map after the last view and leaves every other byte equal; `duplicateView(1)` → new view named `Board copy` with the same keys;
  flow-style `groupOrder: [A, B]` → `setGroupOrder(…, ['B','A'])` succeeds; the unknown top-level key `myPluginKey` and the `map` view's `futureKey` survive every method; comments of `comments-and-quotes.base` survive `setViewKey`.
- Round-trip: parse + `BaseEditor` with zero calls + write → 0 changed bytes for every fixture in `test_vaults/syntax/bases/` (including the five new ones).
- `base_query_v2_test.dart` (12-file dataset from 06.18): `extraColumns: ['note.status','file.mtime','file.tags']` → `extraRaw['note.status']` is the raw String (`'todo'`), a list property stays a `List`, a missing property → `null`; `skipGroupBy: true` with `groupBy` set → `groups` empty and rows sorted by `sort`; `title` equals the basename without extension; default parameters reproduce the 06.18 results exactly (rerun the 06.18 cases).

**Verify**
```
cd packages/tephra_search; dart test test/bases; cd ../..
```
Success: all pass, including the unchanged 06.16–06.18 suites.

**Pitfalls**
- Never normalise or re-order the `views` list, and never rewrite `type` values: a view type Tephra does not know is someone else's.
- `groupOrder` semantics are Obsidian's: a value that is **not listed** is hidden. Tephra must not "helpfully" append new values to a present `groupOrder`; it shows a "N hidden lanes" control instead (06.29).
- YAML `null` inside a list is a real null; `yaml_edit` writes the string `"null"` if you hand it the string. Pass Dart `null`.

---

### 06.28 View framework: switcher tabs, renderer registry, safe note writes, undo, base embeds

**Purpose.** Everything the new views share: one tab strip to switch views (in the Base tab, in ` ```base ` blocks and in `![[x.base]]`
embeds), a registry that maps `type` to a renderer, one safe way to write note properties and `.base` config, a small undo stack for
those writes, and `.base` embeds.

**Files** (new unless marked; `app/lib/bases/view/framework/`)
- `base_view_host.dart`, `base_view_registry.dart`, `base_view_tabs.dart`, `note_text_writer.dart`, `base_property_writer.dart`,
  `base_undo_stack.dart`, `base_session_overlay.dart`, `base_embed.dart`, `view_empty_states.dart`
- modify: `app/lib/bases/view/base_view.dart`, `base_controller.dart`, `base_toolbar.dart` (the view dropdown is removed), `base_code_block.dart`, `base_table_view.dart`, `base_cards_view.dart` (register as renderers), `app/lib/bases/commands.dart`
- modify: the Phase 2 embed renderer (`EmbedView` / `lp_embed.dart`) to route `.base` targets to `BaseEmbed`
- `app/test/bases/view/framework/` : `base_view_tabs_test.dart`, `note_text_writer_test.dart`, `base_property_writer_test.dart`, `base_undo_stack_test.dart`, `base_embed_test.dart`, `base_view_registry_test.dart`

**Implementation**
1. **Renderer registry.**
   ```dart
   abstract interface class BaseViewRenderer {
     String get type;                                              // 'table', 'cards', 'list', 'kanban', 'tephra-calendar', …
     IconData get icon;
     String label(AppLocalizations l10n);                          // "Table", "Board" for kanban, "Calendar", …
     /// Property ids the query must return in BaseResultRow.extraRaw for this view (06.27 item 6).
     List<String> extraColumns(BaseDocument doc, BaseView view);
     bool get skipGroupBy;                                         // true for kanban
     Widget build(BuildContext context, BaseViewHost host);
   }
   final baseViewRegistryProvider = Provider<BaseViewRegistry>((ref) => BaseViewRegistry([...]));   // byType(String) → renderer?
   ```
   Renderers registered by this phase: `table` and `cards` (existing widgets wrapped), then 06.29 `kanban`, 06.31 `list` and `tephra-gallery`, 06.30 `tephra-calendar`, 06.32 `tephra-timeline`.
   A type without a renderer → the 06.19 unsupported card.
2. **`BaseViewHost`** (an `InheritedWidget`-backed interface given to every renderer):
   ```dart
   abstract interface class BaseViewHost {
     BaseDocument get document; int get viewIndex; BaseView get view; BaseQueryResult get result;
     VaultPath? get basePath;          // null for a ```base block
     VaultPath? get thisPath;          // the note that contains the block/embed, or the base file itself for the Base tab
     bool get isEmbedded;
     bool get persistsConfig;          // false only for ```base blocks (their YAML lives in a note: never written, 06.19 pitfall)
     Future<void> editConfig(String undoLabel, void Function(BaseEditor e) edit);
     Future<WriteOutcome> writeNote(VaultPath note, Map<String, Object?> setKeys, {Set<String> removeKeys = const {}, String undoLabel = '', void Function(BaseEditor e)? alsoEditConfig});
     void openNote(VaultPath path, {bool newTab = false});
     Future<VaultPath?> createNote(NewNoteContext context);          // 06.33
     String propertyType(String propertyId, Object? sample);          // registry type name ('text','multitext','number','checkbox','date','datetime','aliases','tags')
     DateTime get now;                                                // Clock
     WeekStart get firstDayOfWeek;                                    // view override, else vault setting bases.firstDayOfWeek
   }
   enum WriteOutcome { written, unchanged, failed }
   ```
   `editConfig` applies `edit` to a `BaseEditor` of the current file text; when `persistsConfig` it writes (debounced 500 ms for resize-like calls, immediate otherwise; atomic; preserves BOM/line ending; re-parses); when not
   (a ` ```base ` block) it stores the change in `BaseSessionOverlay` — an in-memory `Map<String, String>` (key = note path + block start offset) holding the edited YAML text for the block — so lane/card/view changes work during the session and are **lost on restart**; the block's YAML in the note is never written.
3. `note_text_writer.dart` — **the only way Bases writes a note or a `.base`**:
   ```dart
   final class NoteTextWriter {
     /// Replaces the text of [path] with [newText] if it differs. Open editor → one applyEdits (minimal prefix/suffix replacement); else readText + writeText atomically (BOM and line ending preserved, §6.2).
     Future<WriteOutcome> write(VaultPath path, String newText);
     Future<String> read(VaultPath path);                       // open editor buffer text, else file text
   }
   ```
   `BasePropertyWriter.writeNote` = read the note → apply `FrontmatterEditor.setValue` for each `setKeys` entry and `removeKey` for each `removeKeys` entry in a fixed order (remove first, then set, keys sorted
   alphabetically so results are deterministic) → `NoteTextWriter.write`. If `alsoEditConfig` is given, the `.base` text is edited with a `BaseEditor` and written **in the same logical action**. Both file changes are recorded as one `UndoEntry`.
   The note is written before the `.base`; if the `.base` write fails, the note write is reverted with its `before` text and the outcome is `failed` (snackbar `basesWriteFailed`).
4. `base_undo_stack.dart`:
   ```dart
   final class FileChange { const FileChange(this.path, this.before, this.after); final VaultPath path; final String before; final String after; }
   final class UndoEntry { const UndoEntry(this.label, this.changes); final String label; final List<FileChange> changes; }
   final class BaseUndoStack { void push(UndoEntry e); Future<UndoResult> undo(NoteTextWriter w); Future<UndoResult> redo(NoteTextWriter w); bool get canUndo; bool get canRedo; }   // max 50 entries; push clears redo
   enum UndoResult { done, conflict, empty }
   ```
   `undo` checks for every change that the current text of `path` equals `after`; any mismatch → nothing is written and the result is `conflict` (snackbar `basesUndoConflict`: "A file changed since; nothing was undone"). Otherwise it writes the `before` texts (notes first, `.base` last). One stack per open Base tab / embed (provider family keyed by tab id or embed key). Commands `bases.undo` and `bases.redo` (palette, default shortcuts `Ctrl+Z` / `Ctrl+Shift+Z`, `isAvailable` only when the active tab is a Base tab and focus is not in a text field) call it; the board, calendar and timeline also bind the same shortcuts when focused.
5. **View tabs** (`base_view_tabs.dart`) replace the 06.19 dropdown everywhere. A horizontally scrollable strip, height 40 dp desktop / 48 dp phone, one tab per `BaseView` showing the renderer's icon + `view.name` (an unsupported type shows a lock icon); the selected tab is underlined; `selectedViewIndex` lives in `BaseController` (memory only; default 0; if the embed has a `#View name` fragment, that view).
   - Base tab: trailing "+" button → menu of `BaseViewTypes.creatable` (labels from the renderers) → `BaseEditor.addView(type, uniqueName)` where `uniqueName` = renderer label, then ` 2`, ` 3`… when taken; new view gets selected. Tab context menu (right-click / long-press): Rename (inline text field), Duplicate (`duplicateView`), Delete (confirm, as 06.19), "Move left", "Move right" (rewrites the `views` order by `removeView` + insert at index: implement as `BaseEditor.moveView(from, to)` using `YamlEditor.remove` + `insertIntoList`; add it to `BaseEditor`). Dragging tabs is not supported.
   - `![[x.base]]` embeds and ` ```base ` blocks: the strip is shown when the document has ≥ 2 views and no `#View` fragment pins one; no "+" and no context menu (read-only strip) in embeds.
   - Keyboard (desktop): `Ctrl+Alt+1` … `Ctrl+Alt+9` select view 1–9 when the Base tab has focus (commands `bases.select-view-1`…`9`, `showInPalette: false`).
6. **`BaseController` changes:** keeps `selectedViewIndex`; on selection change or dataset change it runs the query for the selected view only, with `extraColumns` and `skipGroupBy` from the renderer; exposes `BaseViewHost`; exposes `undoStack`. Results of an unselected view are never computed.
   **Isolate rule:** the query already runs in an isolate above 1,000 files (06.18); renderers must run their pure layout (`buildBoard`, `layoutCalendar`, `layoutTimeline`, 06.29–06.32) through `Isolate.run` when the row count exceeds **500**, inline otherwise; results are plain sendable data.
7. **`.base` embeds** (`base_embed.dart`): in Reading view and Live Preview, `![[Name.base]]` and `![[Name.base#View name]]` (the Phase 2 embed renderer receives `MdWikiLink(embed: true)` whose resolved target has extension `base`; `heading` holds `View name`) render `BaseEmbed(path, viewName?, fromNote)`.
   Layout: header (file stem as a link that opens the base in a tab, the "New" button of 06.33, view strip) + body of fixed height: **320 dp** for table/cards/list/gallery (virtualised, scrolls inside) and **480 dp** for board/calendar/timeline; width = the note column width; on phones the body scrolls vertically inside while the page scroll continues outside (use `NeverScrollableScrollPhysics` on the outer when the pointer is inside: standard nested scroll rules). `thisPath` = the embedding note (so `this.file` filters work). `persistsConfig == true` (the target is a real file), so lane/card/zoom changes made inside an embed are written to that `.base` file; the embed never writes anything on open. In Live Preview, the embed turns into source when the caret enters the `![[…]]` text (Phase 2 rule). Missing file → the Phase 2 "not found" embed chip. A base that lists the embedding note among its rows is fine (no recursion: rows are links, not embeds).
8. Empty/error states (`view_empty_states.dart`): `NoResults` ("No notes match this view" + the "New" button), `ChooseProperty(label, onPick)` (dropdown of every property id seen in the dataset, used by Board "group by", Calendar "date property", Timeline "start property"), `ReadOnlyProperty`.
9. l10n keys: `basesViewTypeTable`, `basesViewTypeCards`, `basesViewTypeList`, `basesViewTypeBoard`, `basesViewTypeCalendar`, `basesViewTypeGallery`, `basesViewTypeTimeline`, `basesViewMoveLeft`, `basesViewMoveRight`, `basesViewDuplicate`, `basesUndo`, `basesRedo`,
   `basesUndoConflict`, `basesWriteFailed`, `basesPropertyReadOnly`, `basesChoosePropertyTitle`, `basesNoMatches`, `commandBasesUndo`, `commandBasesRedo`, `commandBasesSelectView` (with `{n}`).

**Tests**
- `base_view_tabs_test.dart`: 3 views → 3 tabs; tap tab 2 → controller `selectedViewIndex == 1` and zero writes; "+" → "Calendar" writes a view `{type: tephra-calendar, name: Calendar}` (re-parse); adding "Calendar" twice names the second `Calendar 2`; "Move left" on view 2 swaps order and every other byte is unchanged; in an embed no "+" exists; `#View` fragment pins the view and hides the strip; at 400 dp tabs are 48 dp high.
- `note_text_writer_test.dart`: closed note, new text equal to old → 0 writes; different → 1 atomic write with CRLF preserved for a CRLF file and BOM preserved; open editor → exactly one `applyEdits` whose edit is the minimal replacement; reading an open note returns the buffer text, not the file.
- `base_property_writer_test.dart`: `writeNote(note, {status:'done'})` → only the `status` line changes (byte diff); remove+set order deterministic; with `alsoEditConfig` both files are written, one `UndoEntry` with two changes; `.base` write failing (fake fs throws) → note text restored, outcome `failed`; no-op set (`status` already `done`) → `unchanged`, no `UndoEntry`.
- `base_undo_stack_test.dart`: push 3, undo twice restores both files' `before`, redo once; a file edited externally between push and undo → `conflict`, nothing written; 51 pushes keep 50; push after undo clears redo.
- `base_embed_test.dart` (note text `![[Tasks.base#Board]]`): renders the Board view without the strip; `![[Tasks.base]]` with 2 views shows the strip; opening and closing writes 0 files; a ```base block's `editConfig` writes 0 files and the overlay holds the edited YAML.
- `base_view_registry_test.dart`: every type of `BaseViewTypes.supported` has a renderer once 06.29–06.32 are done (this test is added in 06.32; until then it asserts table, cards); unknown type → null.

**Verify**
```
cd app; flutter test test/bases; cd ..
```
Manual: open `test_vaults/syntax/bases/tephra-views.base` → seven tabs (map shows the lock icon); embed it in a note with `![[tephra-views.base#Board]]`.

**Pitfalls**
- Never let a renderer call `fs.writeText` for a note or a `.base`: only `NoteTextWriter` (it is what keeps BOM, line endings and open editors consistent).
- Selected view, scroll position, collapsed lanes and calendar anchor date are view state: memory only, never written to the `.base`.
- Writing a note changes the index and re-runs the query; keep UI selection by path (06.19 pitfall), and ignore the query refresh that the app's own write caused for **200 ms** (`BaseController.suppressRefreshUntil`) so a dropped card does not jump back and forth.

---

### 06.29 Board view (`type: kanban`)

**Purpose.** A lane board grouped by any property. Lane order and hidden lanes use Obsidian's `groupBy` + `groupOrder`; card order inside a
lane is stored in `tephraCardOrder` in the `.base` (never in notes); dragging a card to another lane writes the grouped property on that note.

**Files**
- pure (`packages/tephra_search/lib/src/bases/views/`): `board_model.dart`, `board_moves.dart` (new); exports in `tephra_search.dart`
- app (`app/lib/bases/view/board/`): `board_renderer.dart`, `board_view.dart`, `board_lane.dart`, `board_card.dart`, `board_drag.dart`, `board_menus.dart` (new)
- register the renderer in `base_view_registry.dart`
- tests: `packages/tephra_search/test/bases/views/board_model_test.dart`, `board_moves_test.dart`; `app/test/bases/view/board/board_view_test.dart`, `board_keyboard_test.dart`

**Implementation**
1. **Pure model** (`board_model.dart`):
   ```dart
   const noneLaneKey = '__none__';
   final class BoardCard { const BoardCard({required this.path, required this.title, required this.rowIndex, this.cover}); final VaultPath path; final String title; final int rowIndex; final Object? cover; }
   final class BoardLane { const BoardLane({required this.key, required this.value, required this.cards}); final String key; final Object? value /* typed lane value, null for the No-value lane */; final List<BoardCard> cards; bool get isNone => key == noneLaneKey; }
   final class BoardModel { final List<BoardLane> lanes; final List<BoardLane> hiddenLanes; final int cardCount; final bool groupPropertyMissing; }
   BoardModel buildBoard({required List<BaseResultRow> rows, required BoardOptions options, String? coverPropertyId});
   List<String> laneKeysOf(Object? raw);
   ```
   `laneKeysOf(raw)`: `null`, `''`, a whitespace-only string, an empty list, a map → `[noneLaneKey]`; a String → `[raw]` (exact, not trimmed); an `int` or an integral `double` → its integer text (`3`); another `num` → `toString()`; a `bool` → `true`/`false`;
   a list → the keys of its non-empty elements in order, duplicates removed (an all-empty list → `[noneLaneKey]`). The group value of a row is `row.extraRaw[options.groupProperty]` (06.27 item 6: the Board renderer passes `groupBy.property` in `extraColumns`).
   `buildBoard`: if `options.groupProperty == null` → `groupPropertyMissing: true`, no lanes. Otherwise every row is placed into **every** lane of `laneKeysOf(value)` (a list-valued property shows the card in several lanes). Lane set and order:
   - `options.groupOrder == null` (Obsidian's "automatic"): all lanes that have cards, sorted by `direction`: if every key parses as a number → numeric; else if every key is `true`/`false` → `false` before `true`; else case-insensitive text order with case-sensitive tie-break; `DESC` reverses; the No-value lane is always **last**.
   - `options.groupOrder != null` (Obsidian's "manual"): lanes exactly in that order, **including empty ones**; an element `null` is the No-value lane; non-string elements are turned into keys with the same rules as above; duplicates ignored. Data lanes not listed (including No value when no `null` is listed) are **hidden**: returned in `hiddenLanes` (in automatic order) and their cards are not shown. An empty `groupOrder` list hides every lane.
   - Cards inside a lane: first the paths listed in `options.cardOrder[laneKey]` that are present (in that order), then the remaining cards in `rows` order (the query's sort order). Paths in `cardOrder` that are not in the lane are ignored (stale entries are removed lazily, sub-step 5).
   `BoardLane.value`: the typed value for writing (`laneValueOf(key, typeName)`, in `board_moves.dart`).
2. **Pure move planning** (`board_moves.dart`):
   ```dart
   sealed class PropertyChange { const PropertyChange(); }
   final class SetProperty extends PropertyChange { const SetProperty(this.value); final Object? value; }
   final class RemoveProperty extends PropertyChange { const RemoveProperty(); }
   final class NoChange extends PropertyChange { const NoChange(); }
   final class UnsupportedChange extends PropertyChange { const UnsupportedChange(this.reason); final String reason; }
   Object? laneValueOf(String laneKey, String typeName);                 // checkbox: 'true'/'false' → bool, else null→ treated Unsupported by the caller; number: num.tryParse (int when integral); everything else: the String
   PropertyChange planLaneMove({required Object? current, required String typeName, required String fromLaneKey, required String toLaneKey});
   List<String> planCardOrder({required List<String> lanePaths, required String movedPath, required int toIndex});
   ```
   `planLaneMove` (a **list-typed** property = `current is List`, or `typeName` in `multitext`, `tags`, `aliases`):
   - `fromLaneKey == toLaneKey` → `NoChange`.
   - `current` is a `Map` → `UnsupportedChange('map')`.
   - Scalar property: `toLaneKey == noneLaneKey` → `RemoveProperty`; else `v = laneValueOf(toLaneKey, typeName)`; if `v` cannot be produced (checkbox with another text, number that does not parse) → `UnsupportedChange('value')`; if the current value already equals `v` → `NoChange`; else `SetProperty(v)`.
   - List property: `items` = `current` as a list of its non-empty elements; a String `current` is split first (tags: on commas and whitespace with a leading `#` removed; others: on commas; trimmed). If `fromLaneKey != noneLaneKey` and no item's text equals `fromLaneKey` → `UnsupportedChange('source-not-in-frontmatter')` (the card is in this lane through an inline `#tag`, which Tephra never edits). Otherwise `result` = `items` without the element equal to `fromLaneKey`, then, when `toLaneKey != noneLaneKey` and not already present, `toLaneKey` appended (typed with `laneValueOf`). Empty `result` → `RemoveProperty`; `result` equal to `items` → `NoChange`; else `SetProperty(result)` (a `List<Object?>`; other elements keep their original order and type).
   `planCardOrder`: `rest = lanePaths` without `movedPath`; `toIndex` clamped to `0..rest.length`; returns `rest` with `movedPath` inserted at `toIndex`. `lanePaths` is the lane's **displayed** order.
3. **Renderer** (`board_renderer.dart`): `type: 'kanban'`, icon `view_kanban`, label `basesViewTypeBoard`, `skipGroupBy: true`, `extraColumns` = `groupBy.property` + every id in `order` + `image` (when set). The view `order` list decides the properties shown on cards (`file.name` is the title and is skipped; the group property is skipped; at most 6 are shown).
4. **Layout** (`board_view.dart`): a horizontal `ListView` of lanes, each `view.tephraLaneWidth` dp wide (phone: min(laneWidth, 82 % of the screen width) so the next lane peeks in, snapping with `PageScrollPhysics`-like `ScrollPhysics` is **not** used: free scroll). Each lane = header + `ListView.builder` of cards (virtualised; `cacheExtent: 600`) + footer "+ New". Lane header: label (the No-value lane label is l10n `basesNoValueLane`), card count, a ⋮ menu (Hide lane, Move left, Move right, New note here). Above the lanes a thin bar: **Group by** property picker (`ChooseProperty`; writes `groupBy` via `setGroupBy`, direction kept), the group direction toggle (writes `direction`; only meaningful while `groupOrder` is absent), "Hidden lanes (N)" (popup listing hidden lanes with a "Show" button each; hidden when N = 0) and "+ Add lane".
   - `groupPropertyMissing` → `ChooseProperty` empty state "Choose a property to group by".
   - **Hide lane:** new `groupOrder` = the currently shown lanes' values (No-value as `null`) without this one → `setGroupOrder` (this turns an automatic board into a manual one, like Obsidian). **Show** hidden lane: append its value. **Move left/right** and lane-header drag (desktop: drag the header; phone: via the menu only): reorder the shown lanes and write the full `groupOrder`. **Add lane:** a text field; the value is typed with `laneValueOf` for the property's registry type, appended to `groupOrder` (created from the shown lanes when absent); the lane exists immediately (empty) because it is listed. No note is changed by lane operations.
   - Card (`board_card.dart`): optional cover on top (the `image` property value resolved exactly as in the 06.19 cards view; 06.31 later switches it to the thumbnail cache), title (tap or Enter opens the note; Ctrl/middle click or the ⋮ menu "Open in new tab"), then `Display name: value` lines, then nothing else. A card whose group property is read-only (`frontmatterKeyOf == null`) shows no drag affordance and its ⋮ menu has "Move to…" disabled with the tooltip `basesPropertyReadOnly`.
   - Card ⋮ menu (always available, 48 dp target; also the non-drag way on phones): "Open", "Open in new tab", "Move to ▸ (list of shown lanes)". "Move to" performs the same write as a drop at the end of that lane.
5. **Drag and drop** (`board_drag.dart`). Payload `BoardDrag(path, fromLaneKey)`. Drag starts with `LongPressDraggable` whose `delay` is **120 ms** when the window width ≥ 840 dp and **400 ms** below (so touch scrolling still works); feedback = a copy of the card with elevation and 90 % opacity; the source card is shown at 30 % opacity while dragging. Each lane is a `DragTarget<BoardDrag>`; while hovering it computes the insertion index from the pointer's y against the **built** cards' render boxes (first card whose vertical centre is below the pointer; none → the end of the built range; the first built index offsets the result) and draws a 2 dp accent line there. Auto-scroll: a 16 ms timer scrolls a lane vertically by 10 dp per tick when the pointer is within 48 dp of its top/bottom edge, and the board horizontally by 14 dp per tick within 48 dp of its left/right edge, while a drag is active.
   On drop at index `i` in lane `L` (display order `lanePaths`, dragged path `p` from lane `F`):
   1. `current` = the note's raw value of the group property (`row.extraRaw`); `typeName = host.propertyType(groupProperty, current)`; `key = frontmatterKeyOf(groupProperty)` (null → drop rejected, snackbar `basesPropertyReadOnly`).
   2. `change = planLaneMove(current, typeName, F, L)`. `UnsupportedChange` → snackbar `basesMoveUnsupported` and nothing is written.
   3. New order of the target lane: `planCardOrder(lanePaths(L), p, i)`; when `F != L` also remove `p` from `cardOrder[F]` (only if `F` has an entry).
   4. One call `host.writeNote(path, setKeys / removeKeys from change, undoLabel: 'Move card', alsoEditConfig: (e) { e.setCardOrder(viewIndex, L, newOrder); if (F != L) e.removeFromCardOrder(viewIndex, F, p); })`: **one `UndoEntry`**, so one Ctrl+Z reverts the property and the order. `NoChange` with `F == L` and an unchanged order → nothing is written. For `NoChange` with a changed order only the `.base` is written.
   - **List-typed property:** only the grouped value is replaced (`planLaneMove`), other values stay; the card remains visible in its other lanes.
   - Tags: `file.tags` / `tags` groupings write the frontmatter `tags` list only; lane keys are tag names without `#`.
   - In a ` ```base ` block (`persistsConfig == false`) the note property is still written and the order goes to the session overlay.
6. **Keyboard (desktop)** — each card is focusable (`FocusableActionDetector`, focus ring): Up/Down move focus within a lane, Left/Right to the card at the same index (clamped) of the previous/next shown lane, Enter opens the note, `Alt+Left`/`Alt+Right` move the focused card to the previous/next shown lane (inserted at the same index, clamped; same write as a drop), `Alt+Up`/`Alt+Down` move it one place within its lane (writes `cardOrder` only), `Delete` does nothing (cards are notes; no deletion from here), `Ctrl+Z`/`Ctrl+Shift+Z` undo/redo (06.28). After a move the moved card keeps focus (by path).
7. **Large lanes:** `buildBoard` runs through `Isolate.run` above 500 rows (06.28 item 6). Lanes with more than 200 cards still scroll smoothly because only built cards exist; drop-index maths uses built cards only (documented limitation: dropping into the middle of an unbuilt region places the card at the nearest built boundary).
8. l10n keys: `basesNoValueLane`, `basesGroupBy`, `basesGroupDirection`, `basesHiddenLanes`, `basesShowLane`, `basesHideLane`, `basesAddLane`, `basesAddLaneHint`, `basesMoveLaneLeft`, `basesMoveLaneRight`, `basesNewNoteInLane`, `basesCardMoveTo`, `basesCardOpen`, `basesCardOpenNewTab`, `basesMoveUnsupported`, `basesChooseGroupProperty`, `commandBasesBoardMoveLeft`, `commandBasesBoardMoveRight`.

**Tests**
- `board_model_test.dart` (rows A `todo`, B `doing`, C `todo`, D no status, E `status: [x, y]`, F `status: "  "`):
  - automatic ASC → lanes `doing`, `todo`, `x`, `y`, `__none__`; `doing=[B]`, `todo=[A,C]`, `x=[E]`, `y=[E]`, none `=[D,F]`; `direction: DESC` → `y, x, todo, doing, __none__`.
  - `groupOrder: ['todo', null, 'review']` → lanes `todo`, `__none__`, `review` (empty); hiddenLanes `doing`, `x`, `y`; `cardCount` counts shown cards only.
  - `groupOrder: []` → no lanes, all hidden. `groupOrder: ['todo']` hides No value.
  - numeric property `priority` values `10`, `2`, `2.5`, missing → ASC `2`, `2.5`, `10`, none; checkbox `done` true/false/missing → `false`, `true`, none.
  - `cardOrder: {todo: ['C.md','A.md']}` → `todo=[C,A]`; `{todo: ['C.md']}` → `[C,A]`; `{todo: ['Gone.md','A.md']}` → `[A,C]`.
  - no `groupBy` → `groupPropertyMissing`; a map-valued property → No-value lane.
- `board_moves_test.dart`: scalar `todo` → lane `doing` → `SetProperty('doing')`; → none → `RemoveProperty`; none → `doing` (current null) → `SetProperty`; same lane → `NoChange`; number type, lane `3` → `SetProperty(3)` (int); checkbox lane `true` → `SetProperty(true)`, lane `maybe` → `UnsupportedChange('value')`; list `[x,y]` from `x` to `z` → `SetProperty([y,z])`; `[x]` from `x` to none → `RemoveProperty`; `[x,y]` from `x` to `y` → `SetProperty([y])`; none → `z` with `[]` → `SetProperty([z])`; tags with string `'a, b'` from `a` to `c` → `SetProperty([b,c])`; list lacking the source value → `UnsupportedChange('source-not-in-frontmatter')`; map value → `UnsupportedChange('map')`; `planCardOrder([A,B,C], C, 0)` → `[C,A,B]`; `([A,B,C], A, 2)` → `[B,C,A]`; `([A,B], X, 1)` → `[A,X,B]`; `([A], X, 99)` → `[A,X]`; `([A], X, -3)` → `[X,A]`.
- `board_view_test.dart` (widget, fake `BaseViewHost` recording `writeNote`/`editConfig`): 3 lanes render with counts; long-press-drag card A from `todo` to `doing` at index 0 → exactly one `writeNote(A, set {status: doing}, alsoEditConfig …)` call and the `alsoEditConfig` edit produces `tephraCardOrder: {doing: [A.md, B.md]}` in the `.base` text; dropping in the same lane at the same place → 0 calls; list property move keeps the other value (`[todo, urgent]` → `[doing, urgent]`); dropping on a read-only group property (`file.folder`) → snackbar and 0 calls; hide lane writes `groupOrder` without it; "Hidden lanes (1)" → Show appends it; "Add lane" `Review` writes `groupOrder` ending `Review`; ⋮ → "Move to ▸ doing" performs the same write as the drag; at 400 dp drag delay is 400 ms (a 150 ms press does not start a drag) and at 1200 dp 120 ms; the ⋮ target is 48 dp at 400 dp.
- `board_keyboard_test.dart`: `Alt+Right` on a focused card moves it one lane right (one write); `Alt+Down` writes only the `.base` order; arrows move focus; `Ctrl+Z` after a move restores both texts.

**Verify**
```
cd packages/tephra_search; dart test test/bases/views; cd ../..
cd app; flutter test test/bases/view/board; cd ..
```
Manual (both platforms): open `tephra-views.base`'s Board; drag a card to another lane → the note's `status:` line changes and nothing else (check the file in a text editor); Ctrl+Z reverts it; phone: long-press, drag, auto-scroll at the screen edge.

**Pitfalls**
- Obsidian's `groupOrder` hides unlisted values; do not "repair" it. A board created by Tephra with a new value appearing later therefore shows "Hidden lanes (1)", never silently drops a card.
- The order inside a lane is view state stored in the `.base`; two devices editing it concurrently is a normal sync conflict (Phase 3 handles `.base` as text).
- The write of the property triggers an index refresh; `suppressRefreshUntil` (06.28) prevents the card flickering back.

---

### 06.30 Calendar view (`type: tephra-calendar`)

**Purpose.** Month, week and agenda calendars over a start date property and an optional end property, with multi-day bars, drag-to-reschedule
that keeps each date's original format, and "tap an empty day → New".

**Files**
- pure (`packages/tephra_search/lib/src/bases/views/`): `date_text.dart`, `calendar_layout.dart`, `calendar_moves.dart` (new)
- app (`app/lib/bases/view/calendar/`): `calendar_renderer.dart`, `calendar_view.dart`, `calendar_month.dart`, `calendar_week.dart`, `calendar_agenda.dart`, `calendar_day_sheet.dart`, `calendar_drag.dart`
- vault setting `bases.firstDayOfWeek`; the settings model/store; l10n; register the renderer
- tests: `packages/tephra_search/test/bases/views/date_text_test.dart`, `calendar_layout_test.dart`, `calendar_moves_test.dart`; `app/test/bases/view/calendar/calendar_view_test.dart`

**Implementation**
1. **Vault setting:** `bases.firstDayOfWeek` (JSON `bases.firstDayOfWeek`, values `sunday`, `monday`, `saturday`; default `monday`; unknown value → default). View key `tephraWeekStart` overrides it for one view. Settings screen: one dropdown in a new "Bases" section (Phase 7 lists it). l10n `settingBasesFirstDayOfWeek`, `weekStartSunday`, `weekStartMonday`, `weekStartSaturday`.
2. **`DateText`** (`date_text.dart`) — a date value as written in YAML, split so that edits keep everything except the calendar date:
   ```dart
   final class DateText {
     const DateText(this.year, this.month, this.day, [this.rest = '']);
     final int year, month, day;
     final String rest;                         // everything after 'YYYY-MM-DD': '' (date only) or e.g. 'T09:30', ' 14:00:00', 'T09:30:00+06:00', 'T09:30:00Z'
     static DateText? tryParse(Object? raw);    // String only (trimmed); anything else → null
     bool get hasTime => rest.isNotEmpty;
     String? get timeOfDay;                     // 'HH:mm' when hasTime
     int get dayNumber;                         // days since 1970-01-01 of DateTime.utc(year, month, day) (no time zone, no DST)
     DateText shiftDays(int n);                 // calendar arithmetic through DateTime.utc; rest unchanged
     DateText withDay(int dayNumber);           // same rest, other date
     String format();                           // 'YYYY-MM-DD' + rest, zero-padded
     static DateText fromDayNumber(int n, {String rest = ''});
     static DateText newFor(int y, int m, int d, String typeName);   // typeName 'datetime' → rest 'T00:00'; any other → ''
   }
   ```
   `tryParse` accepts exactly `^(\d{4})-(\d{2})-(\d{2})` followed by `rest`, where `rest` is empty or matches `^[T ]\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}(:?\d{2})?)?$`, and the date must be a real calendar date (`2026-02-30` → null).
   **Time-zone decision:** values are always treated as **local wall time as written**: no conversion, no offset arithmetic. A `Z` or `+06:00` suffix stays in `rest` untouched and is ignored for placement.
3. **Items** (`calendar_layout.dart`):
   ```dart
   final class CalendarItem { final int index; final VaultPath path; final String title; final DateText start; final DateText end /* effective: ≥ start, equals start when missing or earlier */;
     final bool hasExplicitEnd; final bool invalidRange; final bool draggable; final Object? startRaw; final Object? endRaw; int get startDay; int get endDay; bool get isMultiDay; }
   final class CalendarBuild { final List<CalendarItem> items /* scheduled, sorted */; final List<VaultPath> unscheduled; }
   CalendarBuild buildCalendarItems(List<BaseResultRow> rows, {required String startProperty, String? endProperty, required String Function(String propertyId) typeNameOf});
   ```
   A row is **unscheduled** when `DateText.tryParse(extraRaw[startProperty])` is null (missing, invalid, a list). `end`: `tryParse(extraRaw[endProperty])`; null or `endDay < startDay` → `end = start` (and `invalidRange = true` when an end value existed but was earlier). `draggable = frontmatterKeyOf(startProperty) != null && (end value absent || frontmatterKeyOf(endProperty) != null)`.
   Sort order of `items` (stable, total): `startDay` ascending; then multi-day before single-day, longer span first; then date-only before timed; then `timeOfDay` ascending; then `title.toLowerCase()`; then `path.value`.
4. **Month layout:**
   ```dart
   enum WeekStart { sunday, monday, saturday }   // from 06.27
   final class MonthSegment { final int itemIndex; final int row; final int startCol; final int endCol; final int lane; final bool continuesBefore; final bool continuesAfter; }
   final class MonthLayout { final int gridStartDay; final int rows; final List<MonthSegment> segments; final Map<int, int> hiddenPerDay /* dayNumber → items with lane ≥ maxLanes */; }
   MonthLayout layoutMonth(List<CalendarItem> items, {required int year, required int month, required WeekStart weekStart, required int maxLanes});
   ```
   `gridStartDay` = the latest day ≤ the 1st of the month whose weekday is the week start; `rows = ceil((offset + daysInMonth) / 7)` (5 or 6; `offset` = days from `gridStartDay` to the 1st). For every grid row (7 days) take the items intersecting it (binary search on the sorted `items` by `startDay`, then scan while `startDay ≤ rowEnd`), clip to the row (`continuesBefore`/`continuesAfter` mark clipping), and assign `lane` = the lowest lane index not occupied in any column of `[startCol, endCol]` (occupancy per column kept as a bitset), in the sorted order. Lanes beyond `maxLanes − 1` are still assigned (they are not drawn); `hiddenPerDay[d]` counts, for each day of such a segment, the segments on that day with lane ≥ `maxLanes`. The UI draws "+N more" in the cell when `hiddenPerDay[d] > 0`. `maxLanes = max(1, floor((cellHeight − 24) / 22))`.
5. **Week layout:** `layoutWeek(items, {required int weekStartDay})` → `WeekLayout { List<MonthSegment> bars /* multi-day items, lanes as in month, row = 0 */; List<List<int>> perDay /* 7 lists of item indexes of single-day items, sorted: date-only first, then by time, then title */ }`. Decision: the week mode is a 7-column view with a bar strip on top and a scrolling list per day (no hour grid).
6. **Agenda layout:** `layoutAgenda(items, {required int fromDay, required int toDay})` → `List<AgendaDay { int day; List<int> itemIndexes }>`: only days with at least one item; an item appears on `max(startDay, fromDay)` only (a multi-day item shows "→ <end date>" / "(continues)" text), in the sorted order. The agenda range is the displayed month (first to last day of the anchor month).
7. **Reschedule planning** (`calendar_moves.dart`):
   ```dart
   Map<String, String>? planReschedule(CalendarItem item, {required int grabDay, required int dropDay, required String startProperty, String? endProperty});
   ```
   `delta = dropDay − grabDay` (for a multi-day bar `grabDay` is the day under the pointer when the drag began, so grabbing the middle moves relative to the grab point; for an agenda/popover "Reschedule…" date picker `grabDay = startDay`, `dropDay = picked`). Returns `{frontmatterKey(start): item.start.shiftDays(delta).format()}` plus, when an end value existed and parsed, `{frontmatterKey(end): parsedEnd.shiftDays(delta).format()}`. `delta == 0` or `!item.draggable` → `null`. The original format of each value (date vs datetime, separator `T` or space, seconds, offset) is kept because only the date digits change. An end value that did not parse is **left untouched**.
8. **UI** (`calendar_view.dart`): header row: previous/next (`PageUp`/`PageDown`), title (month name + year via `intl`, `en`), "Today" (`T`), segmented control Month / Week / Agenda (a change writes `tephraCalendarMode` with `host.editConfig`, immediately; the anchor date is memory only), and an "Unscheduled (N)" button (hidden when N = 0) listing those notes with a "Set date…" action (date picker → writes the start property in the property's own format: `DateText.newFor(y, m, d, typeName)`). Weekday header uses `host.firstDayOfWeek`; "today" cell highlighted using `host.now`; days outside the anchor month dimmed.
   - **Month** (`calendar_month.dart`): a fixed grid of `rows × 7` cells, bars drawn with `MonthSegment`s (height 20 dp + 2 dp gap; continuation edges squared with a small chevron; single timed items show `HH:mm title`), "+N more" opens the day sheet. The grid is a `Column` of week rows (≤ 6), each a `Stack` (cells below, bars above) — nothing scrolls except the day sheet, so 2,000 items cost only the visible segments.
   - **Week** (`calendar_week.dart`): 7 columns; top strip of bars; each column below is a `ListView.builder` of that day's items; header shows `ddd D`.
   - **Agenda** (`calendar_agenda.dart`): `ListView.builder` of day headers (`dddd, MMMM D`) and item rows (time or "All day", title, "→ date"); no drag; each row has a "Reschedule…" item in its ⋮ menu (48 dp).
   - **Day sheet** (`calendar_day_sheet.dart`): opened by tapping the day number or an empty part of a cell (phone: bottom sheet; desktop: popover anchored on the cell). Lists the day's items (tap opens the note) and a **New** button creating a note with the clicked day prefilled (06.33: `NewNoteContext(clicked: {startProperty: DateText.newFor(y, m, d, typeName).format()})`). Desktop: double-click an empty cell skips the sheet and creates immediately.
   - **Drag** (`calendar_drag.dart`): `LongPressDraggable<CalendarDrag(itemIndex, grabDay)>` on every bar/item (delay 120 ms ≥ 840 dp, 400 ms below); every day cell/column is a `DragTarget`; the hovered day is highlighted; on drop `planReschedule` → `host.writeNote(path, setKeys, undoLabel: 'Reschedule')` (one undo step). Items with `draggable == false` show a lock tooltip (`basesPropertyReadOnly`) and cannot be dragged. Dragging near the left/right edge of the month grid does not change months (use the arrows); this is a documented limitation.
   - **Keyboard:** items are focusable; `Alt+Left`/`Alt+Right` = −1/+1 day, `Alt+Up`/`Alt+Down` = −7/+7 days (same `planReschedule`, one write each), Enter opens the note, `Ctrl+Z` undo.
9. The renderer (`calendar_renderer.dart`): `type: 'tephra-calendar'`, icon `calendar_month`, label `basesViewTypeCalendar`, `skipGroupBy: false` (the executor's `groupBy` is ignored by this view), `extraColumns` = start, end (if any), and the `order` columns. Missing start property in the view → `ChooseProperty` empty state; the choice writes `tephraStartProperty` (`editConfig`). The layout functions run in `Isolate.run` above 500 rows.
10. l10n keys: `basesCalendarToday`, `basesCalendarMonth`, `basesCalendarWeek`, `basesCalendarAgenda`, `basesCalendarUnscheduled`, `basesCalendarSetDate`, `basesCalendarMore`, `basesCalendarAllDay`, `basesCalendarContinues`, `basesCalendarReschedule`, `basesCalendarChooseStart`, `basesCalendarNewOnDay`.

**Tests** (2026-10-01 is a Thursday)
- `date_text_test.dart`: `tryParse('2026-10-11')` → `(2026,10,11,'')`; `'2026-10-30T09:30'` + `shiftDays(3)` → `format() == '2026-11-02T09:30'`; `'2026-10-11 14:00:00'` + 0 → same string (space kept); `'2026-10-11T09:30:00+06:00'` `shiftDays(-11)` → `'2026-09-30T09:30:00+06:00'`; `'2026-12-31'` +1 → `'2027-01-01'`; `'2028-02-28'` +1 → `'2028-02-29'`; `'2026-02-30'`, `'2026-10-11T9:30'`, `'20261011'`, `'2026-13-01'`, `42`, `null`, `['2026-10-11']` → null; `' 2026-10-11 '` (spaces) → parses; `newFor(2026,10,5,'datetime').format()` → `'2026-10-05T00:00'`; `newFor(2026,10,5,'date')` → `'2026-10-05'`; `timeOfDay` of `'T09:30:15'` → `'09:30'`.
- `calendar_layout_test.dart`: `buildCalendarItems`: row without start → `unscheduled`; end earlier than start → `end == start`, `invalidRange`; sort order case: same day items `Zed` (date-only), `Amy` (09:00), `Bob` (08:00), a 3-day item `Long` → order `Long, Zed, Bob, Amy`.
  `layoutMonth` October 2026 (`monday`): `gridStartDay` = 2026-09-28, `rows == 5`; `sunday` → grid start 2026-09-27, `rows == 5`; `saturday` → 2026-09-26, `rows == 6`. With A = Oct 5–8, B = Oct 6, C = Oct 7–13 (monday grid): segments A (row 1, cols 0–3, lane 0), B (row 1, col 1, lane 1), C row 1 (cols 2–6, lane 1, `continuesAfter`) and C row 2 (cols 0–1, lane 0, `continuesBefore`). Three items on Oct 5 with `maxLanes: 2` → `hiddenPerDay[Oct 5] == 1`. An item Sep 20–Oct 2 → one segment in row 0 (cols 0–4, `continuesBefore`). An item in November is absent. 2,000 random items (seed 7) lay out in < 50 ms (assert < 200 ms in `dart test`, record the real number).
  `layoutWeek` (week of Mon 2026-10-05): the multi-day item is a bar; single-day items per day sorted date-only, 08:00, 09:00. `layoutAgenda` Oct 1–31: only days with items; item starting Sep 30 appears on Oct 1; multi-day appears once.
- `calendar_moves_test.dart`: item start `2026-10-05T09:30`, end `2026-10-07T17:00`, grab Oct 6, drop Oct 10 → `{due: '2026-10-09T09:30', end: '2026-10-11T17:00'}`; start-only date item +7 → one key; delta 0 → null; `startProperty: file.mtime` → `draggable == false` → null; end property `formula.x` with an end value → not draggable; unparsable end value is not in the result map; Bangla key names are irrelevant (keys come from `frontmatterKeyOf`).
- `calendar_view_test.dart` (widget, fake host, `now` = 2026-10-11): month grid shows 5 rows; Monday first column at default, Saturday when `firstDayOfWeek: saturday`; drag the bar of a note with `due: 2026-10-05` to the cell of Oct 12 → one `writeNote(…, {due: '2026-10-12'}, undoLabel 'Reschedule')`; same for a datetime keeping `T09:30`; tap an empty cell → day sheet; its New button → `createNote` with `clicked == {'note.due': '2026-10-20'}`; mode switch to Week writes `tephraCalendarMode: week` once (re-parse); Agenda mode has no drag; "Unscheduled (1)" shows and "Set date…" for a `datetime`-typed property writes `…T00:00`; `Alt+Right` moves the focused item one day; today's cell highlighted; at 400 dp the cell shows dots/"+N" rather than overflowing (no overflow exceptions, `tester.takeException()` is null).

**Verify**
```
cd packages/tephra_search; dart test test/bases/views; cd ../..
cd app; flutter test test/bases/view/calendar; cd ..
```
Manual: reschedule by drag on both platforms; the note's date line changes only in the digits; open the note in Obsidian → unchanged otherwise.

**Pitfalls**
- Never use `DateTime.local` arithmetic for dates (daylight saving makes "+1 day" 23/25 hours): use `dayNumber` maths via `DateTime.utc`.
- `yaml` returns dates as strings (02.26 pitfall); never expect a `DateTime` in `extraRaw`.
- A multi-day item has one bar segment per week row; every segment is draggable and all segments share the same `itemIndex`, so the drag payload and the write are identical whichever segment was grabbed.

---

### 06.31 List view, Gallery view and the thumbnail cache

**Purpose.** A compact list (`type: list`, Obsidian's own type) and an image-first gallery (`type: tephra-gallery`) with covers from a
property or from the first image in the note, and a disk thumbnail cache (`.tephra/cache/thumbs/`) shared by Gallery, Board and Cards.

**Files**
- pure (`packages/tephra_search/lib/src/bases/views/`): `cover_ref.dart`, `gallery_model.dart`, `list_model.dart` (new); `base_dataset.dart` (modify: add `firstImageEmbed`)
- app, list: `app/lib/bases/view/list/list_renderer.dart`, `list_view.dart`
- app, gallery: `app/lib/bases/view/gallery/gallery_renderer.dart`, `gallery_view.dart`, `gallery_card.dart`
- app, thumbnails (`app/lib/bases/view/thumbs/`): `thumb_key.dart`, `thumb_lru.dart` (pure Dart, no Flutter imports), `thumb_decoder.dart`, `thumb_service.dart`, `thumb_image.dart`, `providers.dart`
- modify: `app/lib/bases/view/base_cards_view.dart`, `app/lib/bases/view/board/board_card.dart` (use `ThumbImage`), `app/lib/bases/view/base_data_provider.dart` (fill `firstImageEmbed`)
- tests: `packages/tephra_search/test/bases/views/cover_ref_test.dart`, `gallery_model_test.dart`, `list_model_test.dart`; `app/test/bases/view/thumbs/thumb_key_test.dart`, `thumb_lru_test.dart`, `thumb_service_test.dart`; `app/test/bases/view/gallery/gallery_view_test.dart`, `app/test/bases/view/list/list_view_test.dart`

**Implementation**
1. **List view** (`list_model.dart`, `list_view.dart`). Rows come from the normal query (groups honoured). The first column of `order` (default `file.name`) is the **primary text** (a link that opens the note); the remaining `order` columns are appended after the primary text, their displayed values (`displayValue`, empty values skipped) joined with `tephraListSeparator` (default `, `), in a muted style. Marker: `bullet` = `•`, `number` = `1.`, `2.`… (restarting at 1 in every group), `none` = no marker. Rows are a `ListView.builder` (row height 36 dp desktop / 48 dp phone); group headers like the table view. No inline editing in the list. Renderer: `type: 'list'`, icon `view_list`, `skipGroupBy: false`.
   Obsidian's own list options (markers, indent properties, separators) are stored by Obsidian under key names that its public help does not document; Tephra neither reads nor changes them (they are preserved); Tephra's equivalents are `tephraListMarker` and `tephraListSeparator` (06.27).
2. **`CoverRef`** (`cover_ref.dart`, pure):
   ```dart
   sealed class CoverRef { const CoverRef(); }
   final class VaultCover extends CoverRef { const VaultCover(this.path); final VaultPath path; }
   final class UrlCover extends CoverRef { const UrlCover(this.url); final String url; }      // http or https only
   final class NoCover extends CoverRef { const NoCover(); }
   const coverImageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};          // must equal imageExtensions of view_kind.dart (a test in the app asserts it)
   CoverRef resolveCover(Object? raw, {required VaultPath from, required VaultPath? Function(String target, VaultPath from) resolve});
   ```
   Accepted `raw` forms (a `List` uses its first element; anything that is not a String after that → `NoCover`; the string is trimmed): `[[x.png]]`, `[[x.png|alt]]`, `![[x.png]]`, `![[x.png|300]]`, `[[folder/x.png#ignored]]`; Markdown image `![alt](path/x.png)`, `![alt](<path with spaces/x.png>)`, `![alt](path/with%20space.png "title")` (percent-decoded; the optional title dropped); a plain path `path/x.png` or `x.png`; `http://…` and `https://…` (→ `UrlCover`, any extension). Every other scheme (`file:`, `data:`, `ftp:`, `javascript:`) → `NoCover`. For the vault forms the target text goes through `resolve` (the app passes `NoteIndex.resolveLink`-compatible resolution for attachments: exact vault path first, then the unique file name); unresolved, or an extension not in `coverImageExtensions` → `NoCover`.
3. **Body fallback.** `BaseDataset.firstImageEmbed: Map<String, String>` (source path → image path): built in `base_data_provider.dart` from `allLinks()` in one pass: for each note, the first edge with `embed == true`, `target != null` and `target.extension` in `coverImageExtensions`, in source order. It is used only by the Gallery (when `tephraCoverFromBody` is true) and only when the `image` property gave `NoCover`. Limitation (documented in the UI help text `basesGalleryBodyHint`): only wikilink image embeds (`![[x.png]]`) are found, not Markdown images or HTML.
4. **Gallery model** (`gallery_model.dart`): `GalleryItem { VaultPath path; String title; CoverRef cover; List<(String label, String value)> lines /* max 2, from order columns except file.name */ }`; `buildGallery(rows, options, resolveCover, firstImageEmbed)`; groups come from the executor (`groupBy` honoured, `skipGroupBy: false`).
5. **Gallery view**: per group a header (`value (count)`, sticky not required) and a `SliverGrid` with `maxCrossAxisExtent` = 120 / 180 / 260 dp for `small` / `medium` / `large` (`tephraGallerySize`), `childAspectRatio` 0.8 (square image area + up to 2 lines of title/properties), spacing 8 dp. The image uses `BoxFit.cover` for `imageFit: cover` (default; crops) and `BoxFit.contain` for `contain` (fits, with a neutral background). No cover → a neutral box with the first letter of the title (never a broken-image icon). Tap/Enter opens the note; a note's ⋮ menu (hover on desktop, long-press on phone): Open, Open in new tab, Copy link. Only built cells exist, so 10,000 rows scroll smoothly. Renderer: `type: 'tephra-gallery'`, icon `photo_library`, `extraColumns` = `image` property + `order` columns.
6. **Thumbnail cache.**
   - Location: `<vault>/.tephra/cache/thumbs/<first two hex chars of key>/<key>.png` plus `<vault>/.tephra/cache/thumbs/index.json`. Everything under `.tephra/cache/` is rebuildable and never synced (§6.6). Record the new folder in `PROGRESS.md` → Contract additions.
   - `thumbKey(VaultPath path, int sizeBytes, int mtimeMs, int maxEdge)` = lower-case hex SHA-256 (`package:crypto`) of the UTF-8 text `"${path.value}|$sizeBytes|$mtimeMs|$maxEdge"`. A changed file therefore gets a new key; old entries age out.
   - Thumbnails are PNG (dart:ui has no JPEG encoder) with the **longest edge ≤ 256 px** (only ever downscaled). A source image whose both edges are ≤ 256 px **and** whose size ≤ 200 KB is not cached: its original bytes are used. SVG is not thumbnailed (drawn with `flutter_svg` at display size). Animated GIF/WebP: first frame.
   - `ThumbLru` (pure): entries `{key, bytes, lastUsedMs}`; `touch(key, nowMs)`, `add(key, bytes, nowMs)`, `remove(key)`, `totalBytes`, `List<String> evict({required int maxBytes})`: when `totalBytes > maxBytes` returns the oldest-used keys (least `lastUsedMs` first, ties by key) until `totalBytes ≤ 0.9 × maxBytes`, removing them from the map. Constant `thumbCacheMaxBytes = 200 * 1024 * 1024`.
   - Index file shape `{"version": 1, "entries": {"<key>": [<bytes>, <lastUsedMs>]}}` (2-space indent, trailing newline), saved debounced 2 s after the last change and only when it differs; if it is missing or invalid it is rebuilt from the folder listing (bytes = file size, lastUsed = modified time). Entries whose file is missing are dropped when first requested.
   - `ThumbDecoder` (interface, so tests need no GPU): `Future<ThumbBytes?> makeThumbnail(List<int> sourceBytes, int maxEdge)` where `ThumbBytes {Uint8List png; int width; int height}`; the real implementation (`thumb_decoder.dart`) uses `ui.ImageDescriptor.encoded` to read the size, `descriptor.instantiateCodec(targetWidth:/targetHeight:)` to decode already downscaled, `getNextFrame()`, `image.toByteData(format: ui.ImageByteFormat.png)`, and disposes every native object. Undecodable input → `null`.
   - `ThumbService` (`thumbServiceProvider`): `Future<ThumbSource> thumbnail(VaultPath path)` where `ThumbSource` is `ThumbBytesSource(Uint8List)` | `ThumbOriginalSource` | `ThumbFailed`. Flow: `fs.stat` → key → in-memory LRU of the 200 most recent decoded byte arrays → disk hit (touch the entry) → otherwise queue a job. Jobs: **at most 3 run concurrently**; the queue is LIFO (the most recently requested, i.e. the cell currently on screen, goes first); requests for the same key share one future; a job whose requester was disposed before it started is skipped. Written with `fs.writeBytes` (atomic), then `ThumbLru.add` and eviction (`fs.delete(..., mode: TrashMode.permanent)` is allowed here because the files are cache). A failed decode is remembered for the session (no retry loop).
   - `ThumbImage(path, {fit, width, height})` widget: asks `thumbnail`, shows a neutral box meanwhile, `Image.memory(bytes, fit: fit, gaplessPlayback: true)`; `ThumbFailed` → neutral box with an image-off icon. `UrlCover` uses `Image.network(url, cacheWidth: 512)` (no disk cache). Board cards and Cards view now use `ThumbImage` for `VaultCover`.
7. l10n keys: `basesViewTypeList` (06.28), `basesGalleryBodyHint`, `basesGalleryNoCover`, `basesCopyLink`, `commandBasesNewList`.

**Tests**
- `cover_ref_test.dart` (resolver maps `a.png`→`img/a.png`): `'[[a.png]]'`, `'![[a.png|300]]'`, `'[[a.png|alt]]'`, `'![alt](img/a.png)'`, `'![alt](<img/a.png>)'`, `'![x](img/my%20pic.png "t")'` (needs the resolver to know `img/my pic.png`), `'img/a.png'`, `['[[a.png]]','[[b.png]]']` → `VaultCover(img/a.png)`; `'https://x.test/a.jpg'` → `UrlCover`; `'file:///c:/a.png'`, `'data:image/png;base64,AA'`, `'javascript:alert(1)'` → `NoCover`; `'[[missing.png]]'` → `NoCover`; `'[[doc.pdf]]'` → `NoCover`; `42`, `null`, `''` → `NoCover`; a test in the app asserts `coverImageExtensions == imageExtensions`.
- `gallery_model_test.dart`: property cover wins over the body image; no property cover + `tephraCoverFromBody: true` + `firstImageEmbed[note]` → that image; with `tephraCoverFromBody: false` → `NoCover`; `lines` capped at 2 and never contain `file.name`; groups keep the executor order.
- `list_model_test.dart`: primary + separator joining (`Alpha`, `todo, 2026-10-05`), empty values skipped, `tephraListSeparator: ' | '`, numbered markers restart per group.
- `thumb_key_test.dart`: same inputs → same key (64 hex chars); changed `mtimeMs`, `sizeBytes`, `maxEdge` or path → different key.
- `thumb_lru_test.dart`: add 5 entries of 50 MB with `maxBytes` 200 MB → `evict` returns the 2 oldest (total 150 MB ≤ 180 MB); `touch` on the oldest saves it (another key is evicted); empty cache → empty list; equal timestamps → ordered by key.
- `thumb_service_test.dart` (fake `ThumbDecoder` counting calls, `MemoryVaultFileSystem`): first request decodes once and writes `index.json` + one png under the folder; second request → 0 decodes (memory hit); after a service restart (new instance) → 0 decodes (disk hit); modified file (new mtime) → 1 decode and a new key; a 100×100, 10 KB source → `ThumbOriginalSource`, nothing written; decoder returns null → `ThumbFailed`, a second request does not call the decoder again; 10 concurrent requests → never more than 3 decoder calls in flight (fake decoder with a completer); LIFO order (request 1…6, release: jobs 4,5,6 start first among the queued); eviction: cache filled past the limit deletes the oldest files and index entries; corrupt `index.json` → rebuilt from the folder, no exception; the cache folder is never written when no thumbnail is requested.
- Real decoder smoke test (`flutter test`, tagged `@Tags(['gpu'])`, runs on Windows): a 1000×500 PNG generated with `PictureRecorder` → thumbnail 256×128.
- `gallery_view_test.dart`: at 1200 dp with `medium` the grid has ≥ 5 columns; `large` fewer than `small`; `contain` uses `BoxFit.contain`; item without cover shows its first letter; 10,000 items build with `tester.pumpWidget` in < 1 s and only a screenful of cards exists in the tree; tap opens.
- `list_view_test.dart`: marker types render; tap on the primary text opens the note; group headers show `value (count)`.

**Verify**
```
cd packages/tephra_search; dart test test/bases/views; cd ../..
cd app; flutter test test/bases/view/thumbs test/bases/view/gallery test/bases/view/list; cd ..
cd app; flutter test --tags gpu test/bases/view/thumbs; cd ..
```
Manual: open a Gallery over a folder with 300 photos on the phone: scrolling is smooth, `.tephra/cache/thumbs/` fills, a second visit is instant, the folder never exceeds 200 MB (lower `thumbCacheMaxBytes` temporarily to test eviction).

**Pitfalls**
- Decode with a **target size** (never decode a 12 MP photo at full size to shrink it afterwards): it costs ~48 MB per image and crashes low-memory phones.
- The cache folder is inside the vault: the file watcher, indexer and sync must keep ignoring `.tephra/` (§6.1). A test lists the vault after thumbnail creation and asserts no thumbnail appears in the explorer or the index.
- Do not put the thumbnail cache index in a provider that rebuilds on `vaultRevisionProvider`: writing thumbnails would then retrigger the gallery.

---

### 06.32 Timeline view (`type: tephra-timeline`)

**Purpose.** A horizontal time axis with one bar per note (start + end date), drag to move, drag the bar ends to resize, optional group rows,
four zoom levels and a today line.

**Files**
- pure (`packages/tephra_search/lib/src/bases/views/`): `timeline_layout.dart`, `timeline_moves.dart` (new)
- app (`app/lib/bases/view/timeline/`): `timeline_renderer.dart`, `timeline_view.dart`, `timeline_painter.dart`, `timeline_gestures.dart`, `timeline_header.dart`
- register the renderer; add the "all supported types have a renderer" assertion to `base_view_registry_test.dart`
- tests: `packages/tephra_search/test/bases/views/timeline_layout_test.dart`, `timeline_moves_test.dart`; `app/test/bases/view/timeline/timeline_view_test.dart`

**Implementation**
1. **Data:** reuses `buildCalendarItems` (06.30) with `startProperty`/`endProperty` from `TimelineOptions` (defaults `note.start` / `note.end`). An item **without an end value takes one day** (`end == start`). Items without a valid start → `unscheduled`. The executor's `groupBy` (not skipped) provides the row groups: `result.groups` (ordered; each with the row index range) → `groupOfRow[i]`.
2. **Layout** (`timeline_layout.dart`, pure):
   ```dart
   enum TimelineZoom { day, week, month, quarter }
   double pxPerDay(TimelineZoom z);   // day 48, week 14, month 4, quarter 1.2   (decision; one day is never narrower than 1.2 px)
   final class TimelineBar { final int itemIndex; final int startDay; final int endDay /* inclusive */; final int lane; }
   final class TimelineGroup { final String label; final List<TimelineBar> bars /* sorted by startDay */; final int laneCount; }
   final class TimelineLayout { final List<TimelineGroup> groups; final int minDay; final int maxDay; }
   TimelineLayout layoutTimeline(List<CalendarItem> items, {List<int>? groupOfItem, List<String> groupLabels = const ['']});
   final class TimelineTick { const TimelineTick(this.day, {required this.major}); final int day; final bool major; }
   List<TimelineTick> timelineTicks(TimelineZoom z, {required int fromDay, required int toDay, required WeekStart weekStart});
   ```
   Lane packing per group: items sorted as in 06.30 (`startDay`, longer first, …); each takes the lowest lane whose last `endDay` is **strictly less** than its `startDay`. `minDay`/`maxDay` = min start / max end over all bars (0/0 when none). Ticks: `day` zoom → every day (major on the 1st of a month); `week` → every week-start day (major on the first week-start of a month); `month` → the 1st of every month (major on 1 Jan); `quarter` → 1 Jan, 1 Apr, 1 Jul, 1 Oct (major on 1 Jan). The app formats tick labels with `formatMoment` (day: `D`, with `MMM YYYY` on majors; week: `D MMM`; month: `MMM`, majors `YYYY`; quarter: `MMM YYYY`).
   Visible day range = `[min(minDay, today) − 30, max(maxDay, today) + 90]`; it grows by 30 days whenever a drag or scroll reaches an edge (memory only).
3. **Moves** (`timeline_moves.dart`):
   ```dart
   enum TimelineDrag { move, resizeStart, resizeEnd }
   Map<String, String>? planTimelineChange(CalendarItem item, TimelineDrag mode, int deltaDays, {required String startProperty, required String endProperty});
   ```
   - `deltaDays == 0` or not writable (start key null, or end key null for `resizeEnd`/for `move` when an end value exists) → `null`.
   - `move`: start and (when an end value exists) end both `shiftDays(delta)` — formats preserved (06.30 `DateText`).
   - `resizeEnd`: `newEndDay = max(item.startDay, item.endDay + delta)`; unchanged → `null`; when no end value existed the end is **created** as `DateText.fromDayNumber(newEndDay, rest: item.start.rest).format()` (same format and time of day as the start); otherwise the existing end value is shifted by `newEndDay − endDay` days.
   - `resizeStart`: `newStartDay = min(item.endDay, item.startDay + delta)`; unchanged → `null`; result `{start: item.start.withDay(newStartDay).format()}`; when no end value existed it also writes `{end: item.start.format()}` (the **old** start becomes the end so the right edge stays).
   - Never produces an end earlier than the start; a bar is ≥ 1 day.
4. **UI.** Left column (group labels, 140 dp desktop / 96 dp phone; absent when there is a single unlabeled group) + a horizontally scrollable body, one vertical `ListView.builder` of group blocks (block height = `laneCount × 28 dp + 8 dp padding`); a sticky header with ticks. Drawing is a `CustomPainter` per group block (`timeline_painter.dart`) that paints **only bars intersecting the horizontal viewport** (binary search on `startDay` per group, limited by the maximum span) — so 10,000 bars cost only the visible ones; today line = 2 dp accent line spanning the body; bar = rounded rectangle (radius 6) filled with the accent colour at 85 %, title clipped inside, a lock icon when `!draggable`. Zoom control: segmented Day / Week / Month / Quarter in the toolbar (writes `tephraZoom` immediately via `host.editConfig`); a "Today" button scrolls the body so today is at 30 % of the width; "Unscheduled (N)" like the calendar (its "Set date…" writes start only).
   - **Hit testing** (`hitTestBar`, pure, in `timeline_layout.dart`): `(TimelineHit? hit) hitTestBar(TimelineLayout, {required double x, required double y, required double pxPerDay, required int originDay, required double laneHeight, required double groupGap, required double handleWidth})` → `TimelineHit(itemIndex, zone)` with `zone` ∈ `body`, `startHandle` (x within `handleWidth` of the bar's left edge), `endHandle` (within `handleWidth` of the right edge); `handleWidth` = 8 dp for mouse, 16 dp for touch; a bar narrower than `3 × handleWidth` has handles of one third of its width each.
   - **Gestures** (`timeline_gestures.dart`, `RawGestureDetector`): mouse/stylus/trackpad → `PanGestureRecognizer` (the hit decides the mode: handle zones resize, body moves; the cursor changes to `resizeLeftRight` over handles and `grab` over bodies); touch → `LongPressGestureRecognizer(duration: 350 ms)` then move updates (so a normal swipe still scrolls); haptic tick on drag start on Android. While dragging, a ghost bar shows the snapped result (`delta = round(dx / pxPerDay)`), a tooltip shows the resulting start/end dates; release → `planTimelineChange` → `host.writeNote(path, sets, undoLabel: 'Reschedule')`. Auto-scroll when within 48 dp of the viewport edges (14 dp per 16 ms tick) and the visible range extends.
   - **Empty-area tap** (desktop click, phone tap) on a row: popover "New on <date>" with the **New** button (`NewNoteContext(clicked: {startProperty: <date in the property's format>, groupProperty: <group value if the group has a non-empty text key>})`).
   - **Keyboard:** bars focusable; `Alt+Left`/`Alt+Right` move −1/+1 day; `Alt+Shift+Left`/`Alt+Shift+Right` resize the end −1/+1 day; Enter opens the note; `Ctrl+Z` undo.
5. Renderer: `type: 'tephra-timeline'`, icon `timeline`, `skipGroupBy: false`, `extraColumns` = start, end, group property and `order` columns; layout in `Isolate.run` above 500 rows. Missing start property → `ChooseProperty` empty state (writes `tephraStartProperty`).
6. l10n keys: `basesViewTypeTimeline` (06.28), `basesTimelineZoomDay`, `basesTimelineZoomWeek`, `basesTimelineZoomMonth`, `basesTimelineZoomQuarter`, `basesTimelineToday`, `basesTimelineUnscheduled`, `basesTimelineNewOnDay`, `basesTimelineDragTip` ("{start} → {end}").

**Tests** (day numbers written as dates; `weekStart: monday`)
- `timeline_layout_test.dart`: A 10-05..10-08, B 10-06..10-07, C 10-09..10-10, D 10-08..10-08 → lanes A0, B1, C0, D1, `laneCount == 2`; two groups → lanes counted per group; `minDay`/`maxDay` = 10-05 / 10-10; no items → empty layout; ticks: `day` zoom from 2026-10-29 to 2026-11-03 → 6 ticks, the one on 11-01 is major; `week` zoom over 2026-10-01..2026-11-01 → Mondays 10-05, 10-12, 10-19, 10-26 (major none; 11-02 is outside), with `sunday` → 10-04…; `month` → firsts, 2027-01-01 major; `quarter` → 2026-10-01 and 2027-01-01 (major) for the range 2026-09-01..2027-02-01; `pxPerDay` values.
  `hitTestBar` cases: bar 10-05..10-08 at 14 px/day, point in the middle → `body`; 4 px from the left edge → `startHandle`; 4 px from the right edge → `endHandle`; a 1-day bar at 4 px/day (width 4) → handles of 1/3 width each; point in the gap between groups → null; wrong lane → null.
- `timeline_moves_test.dart`: item start `2026-10-05`, end `2026-10-08` → `move +3` → `{start: 2026-10-08, end: 2026-10-11}`; `resizeEnd +2` → `{end: 2026-10-10}`; `resizeEnd −10` → `{end: 2026-10-05}` (clamped to start); item without end, `resizeEnd +4` → `{end: 2026-10-09}`; same item datetime `2026-10-05T09:30` → `{end: 2026-10-09T09:30}`; item without end, `resizeEnd −3` → `null`; `resizeStart −3` on an item with end → `{start: 2026-10-02}`; without end → `{start: 2026-10-02, end: 2026-10-05}`; `resizeStart +10` on `10-05..10-08` → `{start: 2026-10-08}`; delta 0 → null; end property `formula.x` with an end value → `move` null; `file.ctime` start → null.
- `timeline_view_test.dart` (fake host): a mouse drag of a bar by `3 × 48` px at day zoom writes `{start, end}` shifted by 3 days (`tester.timedDrag`); dragging the right handle by 2 days writes only the end; a touch press shorter than 350 ms scrolls instead of dragging (no write); a long-press drag writes; today line exists; zoom switch writes `tephraZoom` once; at 400 dp the label column is 96 dp; groups show their labels; unscheduled button lists a note without a start; `Alt+Right` moves one day; 10,000 bars: first frame build < 300 ms (record) and only intersecting bars are painted (painter counter).

**Verify**
```
cd packages/tephra_search; dart test test/bases/views; cd ../..
cd app; flutter test test/bases/view/timeline test/bases/view/framework; cd ..
```
Manual: on the phone, long-press a bar, drag it two days, release → date lines change; resize by the right handle; swipe scrolls normally.

**Pitfalls**
- A bar's pixel width is `(endDay − startDay + 1) × pxPerDay`; forgetting the `+ 1` makes one-day items invisible.
- Drag deltas are in whole days even at the quarter zoom (1.2 px per day): show the tooltip so the user sees the exact dates; keyboard moves are the precise alternative.
- Do not allocate a widget per bar; use the painter plus the focus proxy of the one focused bar.

---

### 06.33 The "New" button, prefilled notes and "Create database here"

**Purpose.** Every view can create a note that belongs in the view: right folder, name pattern, template and properties prefilled from the
view's filters and from what the user clicked (lane, day, group). A command creates a ready-made database next to the current note.

**Files**
- pure (`packages/tephra_search/lib/src/bases/views/`): `new_note_prefill.dart` (new)
- app (`app/lib/bases/view/new_note/`): `new_note_context.dart`, `new_note_service.dart`, `new_note_button.dart`, `create_database_service.dart`, `create_database_dialog.dart` (new)
- modify: `base_toolbar.dart`, `base_embed.dart`, `base_code_block.dart`, `view_empty_states.dart`, `board_lane.dart`, `calendar_day_sheet.dart`, `timeline_view.dart` (call the service), `app/lib/bases/commands.dart`, `app/lib/vault/note_tools/note_factory.dart` (add an `ext` parameter), explorer folder context menu
- tests: `packages/tephra_search/test/bases/views/new_note_prefill_test.dart`; `app/test/bases/view/new_note/new_note_service_test.dart`, `new_note_button_test.dart`, `create_database_service_test.dart`

**Implementation**
1. `NoteFactory.reserve`/`create` (06.26) gain a named `String ext = 'md'` parameter (so `.base` files use the same collision rule: `<name>.base`, `<name> 1.base`, …).
2. **Prefill from filters** (`new_note_prefill.dart`, pure):
   ```dart
   final class NewNotePrefill { const NewNotePrefill(this.properties, this.folder); final Map<String, Object?> properties; /* frontmatter key → value */ final String? folder; }
   NewNotePrefill deriveNewNotePrefill(BaseDocument doc, BaseView view, {required String Function(String frontmatterKey) typeNameOf});
   ```
   Conjuncts are collected from `doc.filters` first, then `view.filters`: a `FilterExpr` is itself; a `FilterAnd` contributes all its children (recursively); `FilterOr` and `FilterNot` subtrees are **ignored** (they do not guarantee a value). Each expression is parsed with `BaseExpr.parse`; a syntax error skips that expression. Recognised shapes (everything else is ignored):
   - `Binary('==', A, B)` where one side is a **property reference** and the other a **literal** (`StrLit`, `NumLit`, `BoolLit`; either order): property reference = `Ident(name)` when `name` is not `file`, `note`, `formula`, `this` or a function name; `Member(Ident('note'), name)`; `Index(Ident('note'), StrLit)`. Result: `properties[name] = literal`. A string literal for a property whose registry type is `multitext`, `tags` or `aliases` becomes a one-item list.
   - `Binary('==', Member(Ident('file'), 'folder'), StrLit f)` → `folder = f`.
   - `Call(Member(Ident('file'), 'inFolder'), [StrLit f])` → `folder = f` (an empty string or `/` is ignored).
   For each key and for `folder` the **first** conjunct found wins. `!=`, `<`, `contains`, `hasTag`, formulas and `file.name` conditions never prefill anything (decision: only equality and `inFolder`).
3. **Context** (`new_note_context.dart`):
   ```dart
   final class NewNoteContext {
     const NewNoteContext({this.clicked = const {}, this.clearProperties = const {}});
     final Map<String, Object?> clicked;        // propertyId → value the user clicked (Board lane value, Calendar/Timeline day text, group value). Ids go through frontmatterKeyOf; non-note ids are dropped
     final Set<String> clearProperties;         // propertyIds that must NOT be set (the Board's "No value" lane)
   }
   ```
4. **`NewNoteService.create(BaseViewHost host, NewNoteContext ctx)`** → `Future<VaultPath?>`:
   1. `opts = NewNoteOptions.resolve(host.document, host.view)` (view key, else top-level key).
   2. **Folder**, first that applies: `opts.folder` (a vault-relative folder; an invalid path → snackbar `basesNewFolderInvalid` and continue with the next rule); the `inFolder`/`file.folder ==` folder of `deriveNewNotePrefill`; the folder of the `.base` file (`host.basePath`); for a ` ```base ` block the folder of the containing note (`host.thisPath`); Phase 1's default new-note folder.
   3. **Name:** `opts.name ?? 'Untitled'`, rendered like every name template (06.26: variables allowed, prompts asked once, sanitised, collision suffix ` 1`, ` 2`, …).
   4. **Template:** `opts.template` (a vault path; missing file → snackbar `templateDefaultMissing` and continue without a template); else the folder default of the target folder when `resolveFolderTemplate` returns a path (never the picker, never "ask on new note": a database button must not interrupt with a picker); else none.
   5. **Properties:** `prefill = derived.properties`, then drop the keys of `ctx.clearProperties` from it (and pass those keys as `removeKeys`), then overlay `ctx.clicked` (typed as the Board/Calendar/Timeline produced them; a clicked value for a list-typed property is a one-item list). The clicked values **win** over filter-derived values (clicking the "Done" lane of a board filtered by `status == "todo"` creates a `done` note, which will not appear in that filtered board; this is accepted and not warned about).
   6. `TemplateApplier.createFromTemplate(folder, nameTemplate, templatePath, prefill, asker: askTemplatePrompt, open: false)`; on `TemplateCancelledException` return `null` (nothing written).
   7. Open: `host.openNote(path, newTab: width ≥ 840)` and request focus into the editor (`focusEditorOnOpenProvider`). The new note appears in the view when the index reports it.
   Without a template the file text is only the frontmatter block built from `prefill` (via `applyPrefill('', prefill)`), or the empty string when `prefill` is empty (an empty file, same as Phase 1's "New note").
5. **Where the button is:** Base tab toolbar (right side, filled tonal button "New", `Ctrl+Alt+N` shortcut on command `bases.new-note`, available when a Base tab is active); embed/block header (compact "+ New"); `NoResults` empty state; Board lane footer ("+ New": `NewNoteContext(clicked: {groupProperty: laneValue})`, and `NewNoteContext(clearProperties: {groupProperty})` for the No-value lane); Calendar day sheet and double-click on an empty day (06.30); Timeline empty-area popover (06.32); Gallery/List/Table/Cards: toolbar button only. Phone toolbar: icon-only 48 dp button. The button is hidden in a ` ```base ` block rendered in a note that is read-only (`sticky-locked: true`, 00-conventions §6.5).
6. **"Create database here"** (`create_database_service.dart`): command `bases.create-database-here` (label "Create database here", palette on, no default shortcut; also in the explorer folder context menu). Folder = the explorer-selected folder when invoked from the explorer; else the folder of the active note; else the vault root.
   1. Dialog (`create_database_dialog.dart`): one text field "Database name", initial value = the folder's name (vault root: `Database`), Enter = Create, Esc = Cancel; the name goes through `sanitizeFileName`.
   2. File `folder/<name>.base` reserved with `NoteFactory.reserve(folder, name, ext: 'base')`.
   3. Content (exactly; `\n` line endings; for the root folder the `inFolder` line is omitted):
      ```yaml
      filters:
        and:
          - 'file.inFolder("Projects/Tasks")'
          - 'file.ext == "md"'
      views:
        - type: table
          name: Table
          order:
            - file.name
      ```
      The folder text is escaped for the expression (`\` → `\\`, `"` → `\"`) and then for single-quoted YAML (`'` → `''`). `tephraNewNoteFolder` is **not** written (the default is the folder of the `.base`).
   4. If an editor of a note is active (Source or Live Preview): insert `![[<file name>]]` (the file name with `.base`, e.g. `![[Tasks database.base]]`) at the caret with **one** `applyEdits`: a `\n` is prepended when the caret is not at the start of a line, and a `\n` is appended when the rest of the line after the caret is not empty. Show a snackbar "Created <file name>" with an "Open" action. If no editor is active (explorer, palette without a note): open the new base in a tab.
   5. Cancelling the dialog creates nothing. A write failure shows `basesCreateFailed` and creates no embed text.
7. l10n keys: `basesNew`, `basesNewNote`, `basesNewFolderInvalid`, `commandBasesNewNote`, `commandCreateDatabaseHere`, `explorerCreateDatabaseHere`, `basesCreateDatabaseTitle`, `basesCreateDatabaseName`, `basesCreateDatabaseCreate`, `basesDatabaseCreated`, `basesCreateFailed`.

**Tests**
- `new_note_prefill_test.dart` (type lookup: `tags` → `tags`, everything else `text`): global `and: ['file.inFolder("Projects")', 'status == "todo"']` + view `and: ['priority == 3', 'done == false']` → properties `{status: todo, priority: 3, done: false}`, folder `Projects`; `or: ['status == "a"', 'status == "b"']` → nothing; `not: ['status == "a"']` → nothing; reversed `"todo" == status`; `note.status == "x"`; `note["my prop"] == "y"` → key `my prop`; `file.folder == "A/B"` → folder `A/B`; `file.inFolder("/")` and `file.inFolder("")` → no folder; `file.name == "x"`, `status != "done"`, `status == other`, `formula.f == 1`, `rating >= 4`, `file.hasTag("t")` → nothing; `tags == "x"` → `tags: [x]`; two `status ==` conjuncts → first wins; a filter with a syntax error is skipped and the others still apply; a single-expression `filters: 'status == "todo"'` works.
- `new_note_service_test.dart` (fake host, `MemoryVaultFileSystem`, fixed clock 2026-10-11, `Templates/Task.md` = `---\nstatus: backlog\n---\n# {{title}}\n`): Base at `Projects/Projects.base`, no options → `Projects/Untitled.md`, then `Projects/Untitled 1.md`; option `tephraNewNoteFolder: Work` → `Work/Untitled.md` (folder created); folder precedence: option > `inFolder` > base folder; invalid option `../x` → falls back and shows `basesNewFolderInvalid`; name `{{date:YYYY-MM-DD}} {{prompt:Who}}` with answer `Ana` → `2026-10-11 Ana.md`, one prompt; template + filter `status == "todo"` + clicked lane `doing` → the file has `status: doing` (clicked beats filter beats template) and `# <stem>`; lane `__none__` (`clearProperties: {note.status}`) with filter `status == "todo"` → no `status` key in the file (the template's `backlog`, too, is overridden by removal: `clearProperties` removes the key from the final text); calendar click `{note.due: '2026-10-20'}` with no template → file text exactly `---\ndue: 2026-10-20\n---\n`; list-typed lane (`tags`) → `tags:` list with the value; no template and no prefill → 0-byte file; template missing → snackbar and plain note; folder default (`templates.folderDefaults`) used when the base has no template option and never opens a picker; cancel in a prompt → `null`, `fs` write count 0; the new note opened exactly once (`openNote` called with the path); embedded block → default folder is the containing note's folder; a read-only (`sticky-locked`) note's block shows no button.
- `new_note_button_test.dart`: the toolbar button exists in Table, Board, Calendar, Gallery, List, Timeline hosts; icon-only 48 dp at 400 dp; `NoResults` shows a New button; embed header shows "+ New"; `Ctrl+Alt+N` runs the service once.
- `create_database_service_test.dart`: folder `Projects/Tasks` → exactly the text above; vault root → only the `file.ext` filter; folder `Bob's` → line `- 'file.inFolder("Bob''s")'` and re-parsing the base gives the filter source `file.inFolder("Bob's")`; folder with `"` → `file.inFolder("a\"b")`; existing `Projects database.base` → `Projects database 1.base`; the produced text parses with `BaseDocument.parse` with no issues and round-trips with 0 changed bytes; embed insertion: caret mid-line in `ab|cd` → `ab\n![[X.base]]\ncd`; caret on an empty line → the embed alone; caret at the end of text → `\n![[X.base]]` appended after the line when the line is non-empty; exactly one `applyEdits` and one Ctrl+Z removes the embed text (the `.base` file stays); no active editor → the base opens in a tab and no text is inserted; dialog cancel → nothing written; name `a/b` → sanitised `a-b`.

**Verify**
```
cd packages/tephra_search; dart test test/bases/views; cd ../..
cd app; flutter test test/bases/view/new_note test/bases/view; cd ..
```
Manual (both platforms): in a board lane press "+ New" → a note with that lane's status opens; on a calendar double-click an empty day → note with that date; run "Create database here" from a note → the embed appears and shows a table of the folder.

**Pitfalls**
- `clearProperties` must also delete a key that the **template** wrote; apply it after the template text is rendered (`FrontmatterEditor.removeKey`), not only to the prefill map.
- Never open the template picker from a database button; interrupting a "+ New" with a chooser makes boards unusable on a phone.
- Escape the folder for **two** languages (the expression and then YAML); a unit test with a quote in the folder name is mandatory.

---

### 06.34 Template gallery: bundled templates, template packs, installer and gallery UI

**Purpose.** Twelve ready-made templates and four installable packs (folder + `.base` + templates + folder default), shown in a gallery
with search, categories and a rendered preview. Everything installed is plain Markdown / `.base` that Obsidian opens unchanged.

**Files**
- assets (`app/assets/template_gallery/`): `manifest.json`; `templates/meeting-notes.md`, `daily-journal.md`, `weekly-review.md`, `project-brief.md`, `task.md`, `book.md`, `recipe.md`, `contact.md`, `lecture-notes.md`, `trip-plan.md`, `bug-report.md`, `decision-record.md`; `packs/projects-tasks/` (`pack.json`, `projects.base`, `tasks.base`, `example-project.md`, `example-task.md`), `packs/reading-list/` (`pack.json`, `reading-list.base`, `example-book.md`), `packs/habit-tracker/` (`pack.json`, `habits.base`, `habit-day.md`, `example-day.md`), `packs/simple-crm/` (`pack.json`, `contacts.base`, `example-contact.md`)
- `app/pubspec.yaml` (`flutter: assets:` lists each directory with a trailing slash: `assets/template_gallery/`, `assets/template_gallery/templates/`, and the four `assets/template_gallery/packs/<id>/` folders)
- app code (`app/lib/vault/note_tools/gallery/`): `gallery_manifest.dart`, `gallery_catalog.dart`, `pack_plan.dart`, `pack_installer.dart`, `template_gallery_service.dart`, `template_gallery_dialog.dart` (desktop), `template_gallery_screen.dart` (phone), `gallery_preview.dart`, `providers.dart`
- modify: `note_tools_commands.dart` (command), explorer header "New…" menu, `template_picker.dart` (footer link "Browse gallery…"), `app/lib/l10n/app_en.arb`
- tests: `app/test/vault/note_tools/gallery/` : `gallery_assets_test.dart`, `pack_plan_test.dart`, `pack_installer_test.dart`, `template_gallery_service_test.dart`, `template_gallery_ui_test.dart`

**Implementation**
1. **Conventions for bundled templates.** Every template is a Markdown file with YAML frontmatter and uses only the 06.25 grammar. Text-valued variables in the frontmatter are **always inside double quotes** (`topic: "{{prompt:Topic}}"`), so
   the template file is valid YAML in both apps and answers are escaped (06.25 item 4a). Dates in frontmatter are quoted too (`date: "{{date:YYYY-MM-DD}}"`). Every body contains at most one `{{cursor}}`. In Obsidian the Tephra-only
   variables appear literally (06.25); the gallery shows the sentence `templateGalleryObsidianNote` under each template that uses `prompt`, `select`, `cursor`, `folder`, `vault`, `filename` or a date offset (detected with `templatePrompts` and a simple scan).
2. **The twelve templates** (file content is exactly the listing; a list item with no text is written as `- ` or `- [ ] ` with one trailing space; a table row with empty cells is written exactly as shown; every file ends with a single `\n`):
   1. `meeting-notes.md` — category Work; keywords `agenda minutes attendees`
      ```
      ---
      type: meeting
      topic: "{{prompt:Topic}}"
      date: "{{date:YYYY-MM-DD}}"
      attendees: []
      project: ""
      tags:
        - meeting
      ---
      # {{prompt:Topic}}

      **When:** {{date:dddd, MMMM Do YYYY}}, {{time}}
      **Attendees:**

      ## Agenda

      - {{cursor}}

      ## Notes

      ## Decisions

      ## Action items

      - [ ] 
      ```
   2. `daily-journal.md` — Personal; `diary reflection gratitude`
      ```
      ---
      type: journal
      date: "{{date:YYYY-MM-DD}}"
      mood: ""
      tags:
        - journal
      ---
      # {{date:dddd, MMMM Do YYYY}}

      ## Gratitude

      - {{cursor}}

      ## Today's focus

      - [ ] 

      ## Notes

      ## Evening reflection

      **What went well?**

      **What could be better?**
      ```
   3. `weekly-review.md` — Work; `review retrospective planning`
      ```
      ---
      type: weekly-review
      week-start: "{{date:YYYY-MM-DD}}"
      week-end: "{{date+6d:YYYY-MM-DD}}"
      tags:
        - review
      ---
      # Week of {{date:MMMM D, YYYY}}

      ## Wins

      - {{cursor}}

      ## Challenges

      ## Lessons learned

      ## Metrics

      | Metric | Target | Actual |
      | --- | --- | --- |
      |   |   |   |

      ## Priorities for next week

      - [ ] 
      - [ ] 
      - [ ] 
      ```
   4. `project-brief.md` — Work; `project plan scope goals`
      ```
      ---
      type: project
      status: Planned
      owner: ""
      start: "{{date:YYYY-MM-DD}}"
      due: "{{date+30d:YYYY-MM-DD}}"
      tags:
        - project
      ---
      # {{title}}

      ## Summary

      {{cursor}}

      ## Goals

      - 

      ## Non-goals

      - 

      ## Success metrics

      - 

      ## Milestones

      | Milestone | Owner | Due | Status |
      | --- | --- | --- | --- |
      |   |   |   |   |

      ## Risks

      - 

      ## Stakeholders

      - 

      ## Links
      ```
   5. `task.md` — Work; `todo ticket action`
      ```
      ---
      type: task
      status: Todo
      priority: "{{select:Priority|Low,Medium,High}}"
      due: "{{date+7d:YYYY-MM-DD}}"
      project: ""
      tags:
        - task
      ---
      # {{title}}

      ## Description

      {{cursor}}

      ## Checklist

      - [ ] 

      ## Notes
      ```
   6. `book.md` — Personal; `reading library author`
      ```
      ---
      type: book
      author: "{{prompt:Author}}"
      status: To read
      rating:
      started:
      finished:
      cover:
      tags:
        - book
      ---
      # {{title}}

      **Author:** {{prompt:Author}}

      ## Why I want to read it

      {{cursor}}

      ## Notes

      ## Favourite quotes

      > 

      ## Summary

      ## Takeaways

      - 
      ```
   7. `recipe.md` — Personal; `cooking food ingredients`
      ```
      ---
      type: recipe
      servings: 2
      prep-minutes:
      cook-minutes:
      cuisine: ""
      source: ""
      rating:
      cover:
      tags:
        - recipe
      ---
      # {{title}}

      ## Ingredients

      - {{cursor}}

      ## Method

      1. 

      ## Notes

      ## Nutrition
      ```
   8. `contact.md` — Work; `crm person customer lead`
      ```
      ---
      type: contact
      company: ""
      role: ""
      email: ""
      phone: ""
      stage: Lead
      last-contact: "{{date:YYYY-MM-DD}}"
      next-follow-up: "{{date+14d:YYYY-MM-DD}}"
      tags:
        - contact
      ---
      # {{title}}

      ## About

      {{cursor}}

      ## Interactions

      | Date | Channel | Summary |
      | --- | --- | --- |
      |   |   |   |

      ## Follow-ups

      - [ ] 

      ## Links
      ```
   9. `lecture-notes.md` — Study; `class course university`
      ```
      ---
      type: lecture
      course: "{{prompt:Course}}"
      topic: "{{prompt:Topic}}"
      lecturer: ""
      date: "{{date:YYYY-MM-DD}}"
      tags:
        - lecture
      ---
      # {{prompt:Course}}: {{prompt:Topic}}

      ## Key points

      - {{cursor}}

      ## Notes

      ## Definitions

      ## Questions

      ## Summary

      ## To review

      - [ ] 
      ```
   10. `trip-plan.md` — Personal; `travel holiday itinerary`
       ```
       ---
       type: trip
       destination: "{{prompt:Destination}}"
       start: "{{date+30d:YYYY-MM-DD}}"
       end: "{{date+37d:YYYY-MM-DD}}"
       status: Planning
       budget:
       tags:
         - trip
       ---
       # Trip to {{prompt:Destination}}

       ## Overview

       {{cursor}}

       ## Itinerary

       ### Day 1

       ## Bookings

       | What | Where | Date | Confirmation | Cost |
       | --- | --- | --- | --- | --- |
       |   |   |   |   |   |

       ## Packing list

       - [ ] 

       ## Budget

       ## Notes
       ```
   11. `bug-report.md` — Engineering; `defect issue qa`
       ```
       ---
       type: bug
       status: Open
       severity: "{{select:Severity|Low,Medium,High,Critical}}"
       reported: "{{date:YYYY-MM-DD}}"
       component: ""
       version: ""
       tags:
         - bug
       ---
       # {{title}}

       ## Summary

       {{cursor}}

       ## Steps to reproduce

       1. 

       ## Expected result

       ## Actual result

       ## Environment

       - OS:
       - App version:
       - Device:

       ## Logs and screenshots

       ## Workaround

       ## Notes
       ```
   12. `decision-record.md` — Engineering; `adr architecture choice`
       ```
       ---
       type: decision
       status: "{{select:Status|Proposed,Accepted,Rejected,Superseded}}"
       date: "{{date:YYYY-MM-DD}}"
       deciders: []
       tags:
         - decision
       ---
       # {{title}}

       ## Context

       {{cursor}}

       ## Decision

       ## Options considered

       ### Option A

       - Pros:
       - Cons:

       ## Consequences

       ## Follow-up

       - [ ] 

       ## References
       ```
3. **`manifest.json`** (exact shape; `description` texts are one sentence each, written by you, ≤ 120 characters; `title` values are the names above: "Meeting notes", "Daily journal", "Weekly review", "Project brief", "Task", "Book", "Recipe", "Contact", "Lecture notes", "Trip plan", "Bug report", "Decision record"):
   ```json
   {
     "version": 1,
     "categories": ["work", "personal", "study", "engineering"],
     "templates": [
       { "id": "meeting-notes", "title": "Meeting notes", "category": "work", "description": "…", "file": "templates/meeting-notes.md", "keywords": ["agenda", "minutes", "attendees"] }
     ],
     "packs": [
       { "id": "projects-tasks", "title": "Projects & tasks", "category": "work", "description": "…", "dir": "packs/projects-tasks", "keywords": ["kanban", "calendar", "todo"] },
       { "id": "reading-list", "title": "Reading list", "category": "personal", "description": "…", "dir": "packs/reading-list", "keywords": ["books", "library"] },
       { "id": "habit-tracker", "title": "Habit tracker", "category": "personal", "description": "…", "dir": "packs/habit-tracker", "keywords": ["daily", "routine"] },
       { "id": "simple-crm", "title": "Simple CRM", "category": "work", "description": "…", "dir": "packs/simple-crm", "keywords": ["contacts", "pipeline", "sales"] }
     ]
   }
   ```
   Decision (exception to GEMINI.md §4 rule 11, record it in `PROGRESS.md` → Conflicts): template and pack **titles and descriptions are bundled content** in the manifest (like the templates' own text), not UI strings; the gallery's category names and all UI chrome are in `app_en.arb`
   (`templateCategoryAll`, `templateCategoryPacks`, `templateCategoryWork`, `templateCategoryPersonal`, `templateCategoryStudy`, `templateCategoryEngineering`). A Bangla manifest (`manifest_bn.json`) can be added later without code changes: the loader tries `manifest_<locale>.json` first.
4. **Pack format** (`pack.json`):
   ```json
   {
     "id": "projects-tasks",
     "version": 1,
     "files": [
       { "key": "project-template", "asset": "templates/project-brief.md", "target": "{templates}/Project brief.md" },
       { "key": "task-template", "asset": "templates/task.md", "target": "{templates}/Task.md" },
       { "key": "projects-base", "asset": "packs/projects-tasks/projects.base", "target": "Projects/Projects.base" },
       { "key": "tasks-base", "asset": "packs/projects-tasks/tasks.base", "target": "Tasks/Tasks.base" },
       { "key": "example-project", "asset": "packs/projects-tasks/example-project.md", "target": "Projects/Example project.md", "render": true },
       { "key": "example-task", "asset": "packs/projects-tasks/example-task.md", "target": "Tasks/Example task.md", "render": true }
     ],
     "folderDefaults": { "Projects": "@{pack:project-template}", "Tasks": "@{pack:task-template}" }
   }
   ```
   - `asset` is a path relative to `app/assets/template_gallery/`. `target` is a vault-relative path; the token `{templates}` is replaced by the vault's `templates.folder` (unset → `Templates`, and the setting is then written); a target is also passed through `renderTemplate` (so `Habits/{{date:YYYY-MM-DD}}.md` works).
   - **Content tokens** inside any installed file: `@{pack:<key>}` → the vault path (with extension) where the file with that `key` was **actually** installed; `@{pack:<key>:link}` → the same path without the `.md` extension (for wikilinks). A token naming an unknown key makes the pack invalid (`PackFormatException`, caught by `gallery_assets_test.dart`, never at runtime for bundled packs).
   - `"render": true` marks files that are rendered with `renderTemplate` at install time (title = the installed file stem; no prompts allowed) — used for example notes so their dates are relative to the install day. Files without `render` are copied byte-for-byte after token replacement (templates stay raw, with their variables).
5. **The four packs.** Pack file list (order of installation = order in `files`; templates first, then bases, then notes), `folderDefaults`, and the content of the pack-specific assets:
   **Projects & tasks** (`projects-tasks`): files exactly as in the `pack.json` above; folder defaults as above.
   `projects.base`:
   ```yaml
   filters:
     and:
       - 'file.inFolder("Projects")'
       - 'file.ext == "md"'
   tephraNewNoteFolder: Projects
   tephraNewNoteTemplate: "@{pack:project-template}"
   properties:
     note.status:
       displayName: Status
     note.owner:
       displayName: Owner
     note.due:
       displayName: Due
   views:
     - type: kanban
       name: Board
       groupBy:
         property: note.status
         direction: ASC
       groupOrder:
         - Planned
         - Active
         - Done
       order:
         - file.name
         - note.owner
         - note.due
     - type: table
       name: All projects
       order:
         - file.name
         - note.status
         - note.owner
         - note.start
         - note.due
       sort:
         - property: note.due
           direction: ASC
     - type: tephra-timeline
       name: Timeline
       tephraStartProperty: note.start
       tephraEndProperty: note.due
       tephraZoom: month
   ```
   `tasks.base`:
   ```yaml
   filters:
     and:
       - 'file.inFolder("Tasks")'
       - 'file.ext == "md"'
   tephraNewNoteFolder: Tasks
   tephraNewNoteTemplate: "@{pack:task-template}"
   properties:
     note.status:
       displayName: Status
     note.priority:
       displayName: Priority
     note.due:
       displayName: Due
   views:
     - type: tephra-calendar
       name: Calendar
       tephraStartProperty: note.due
       tephraCalendarMode: month
       order:
         - file.name
     - type: kanban
       name: Board
       groupBy:
         property: note.status
         direction: ASC
       groupOrder:
         - Todo
         - Doing
         - Done
       order:
         - file.name
         - note.priority
         - note.due
     - type: table
       name: Table
       order:
         - file.name
         - note.status
         - note.priority
         - note.due
         - note.project
       sort:
         - property: note.due
           direction: ASC
   ```
   `example-project.md` (rendered):
   ```
   ---
   type: project
   status: Active
   owner: ""
   start: "{{date:YYYY-MM-DD}}"
   due: "{{date+30d:YYYY-MM-DD}}"
   tags:
     - project
   ---
   # Example project

   This is a sample project created by the "Projects & tasks" pack. Drag it between lanes on the Board in [[Projects.base]], or delete it.
   ```
   `example-task.md` (rendered):
   ```
   ---
   type: task
   status: Todo
   priority: Medium
   due: "{{date+3d:YYYY-MM-DD}}"
   project: "[[@{pack:example-project:link}]]"
   tags:
     - task
   ---
   # Example task

   - [ ] Try dragging this task on the calendar in [[Tasks.base]].
   ```
   **Reading list** (`reading-list`): files `book-template` (`templates/book.md` → `{templates}/Book.md`), `reading-base` (`packs/reading-list/reading-list.base` → `Reading list/Reading list.base`), `example-book` (`packs/reading-list/example-book.md` → `Reading list/Example book.md`, render); `folderDefaults`: `{"Reading list": "@{pack:book-template}"}`.
   `reading-list.base`:
   ```yaml
   filters:
     and:
       - 'file.inFolder("Reading list")'
       - 'file.ext == "md"'
   tephraNewNoteFolder: Reading list
   tephraNewNoteTemplate: "@{pack:book-template}"
   views:
     - type: tephra-gallery
       name: Covers
       image: note.cover
       imageFit: cover
       tephraGallerySize: medium
       order:
         - file.name
         - note.author
     - type: kanban
       name: Board
       groupBy:
         property: note.status
         direction: ASC
       groupOrder:
         - To read
         - Reading
         - Finished
       image: note.cover
       order:
         - file.name
         - note.author
         - note.rating
     - type: table
       name: Table
       order:
         - file.name
         - note.author
         - note.status
         - note.rating
         - note.finished
   ```
   `example-book.md` (rendered): frontmatter `type: book`, `author: "Unknown"`, `status: Reading`, `started: "{{date:YYYY-MM-DD}}"`, `tags: [book]` as a block list, body `# Example book` and one sentence naming the pack and the `cover` property ("Add a cover with `cover: [[image.png]]` in the properties").
   **Habit tracker** (`habit-tracker`): files `habit-template` (`packs/habit-tracker/habit-day.md` → `{templates}/Habit day.md`), `habits-base` (`packs/habit-tracker/habits.base` → `Habits/Habits.base`), `today` (`packs/habit-tracker/example-day.md` → `Habits/{{date:YYYY-MM-DD}}.md`, render); `folderDefaults`: `{"Habits": "@{pack:habit-template}"}`.
   `habit-day.md` (template, not rendered at install):
   ```
   ---
   type: habit-day
   date: "{{date:YYYY-MM-DD}}"
   exercise: false
   read: false
   meditate: false
   water: false
   sleep-hours:
   mood: ""
   ---
   # {{date:dddd, MMMM Do YYYY}}

   ## Notes

   {{cursor}}
   ```
   `example-day.md` = the same text as `habit-day.md` (rendered at install; the `{{cursor}}` is removed).
   `habits.base`:
   ```yaml
   filters:
     and:
       - 'file.inFolder("Habits")'
       - 'file.ext == "md"'
   tephraNewNoteFolder: Habits
   tephraNewNoteName: "{{date:YYYY-MM-DD}}"
   tephraNewNoteTemplate: "@{pack:habit-template}"
   views:
     - type: table
       name: Table
       order:
         - file.name
         - note.exercise
         - note.read
         - note.meditate
         - note.water
         - note.sleep-hours
         - note.mood
       sort:
         - property: note.date
           direction: DESC
     - type: tephra-calendar
       name: Calendar
       tephraStartProperty: note.date
       tephraCalendarMode: month
       order:
         - file.name
   ```
   **Simple CRM** (`simple-crm`): files `contact-template` (`templates/contact.md` → `{templates}/Contact.md`), `contacts-base` (`packs/simple-crm/contacts.base` → `CRM/Contacts.base`), `example-contact` (`packs/simple-crm/example-contact.md` → `CRM/Example contact.md`, render); `folderDefaults`: `{"CRM": "@{pack:contact-template}"}`.
   `contacts.base`:
   ```yaml
   filters:
     and:
       - 'file.inFolder("CRM")'
       - 'file.ext == "md"'
   tephraNewNoteFolder: CRM
   tephraNewNoteTemplate: "@{pack:contact-template}"
   views:
     - type: table
       name: Contacts
       order:
         - file.name
         - note.company
         - note.role
         - note.email
         - note.stage
         - note.last-contact
       sort:
         - property: note.last-contact
           direction: DESC
     - type: kanban
       name: Pipeline
       groupBy:
         property: note.stage
         direction: ASC
       groupOrder:
         - Lead
         - Contacted
         - Meeting
         - Proposal
         - Won
         - Lost
       order:
         - file.name
         - note.company
         - note.next-follow-up
     - type: tephra-calendar
       name: Follow-ups
       tephraStartProperty: note.next-follow-up
       order:
         - file.name
   ```
   `example-contact.md` (rendered): the Contact template's frontmatter with `company: "Example Co"`, `stage: Lead`, dates as in the template, and the body `# Example contact` plus one sentence about dragging it across the Pipeline.
6. **Catalog** (`gallery_catalog.dart`): loads `manifest.json` (locale variant first) and each `pack.json` through `rootBundle.loadString`; `GalleryEntry { id, title, description, category, keywords, isPack }`; `search(query)` = `FuzzyScorer` over title (weight 1.0), keywords and description (weight 0.5; use `score − 50` like the slash menu), empty query → manifest order (templates first, then packs); `byCategory`. A malformed manifest or pack → the entry is skipped with a `warning`, never a crash.
7. **Planning** (`pack_plan.dart`, no Flutter):
   ```dart
   final class PlannedFile { final String key; final String asset; final VaultPath wantedPath; final VaultPath actualPath; final bool renamed; final bool render; final bool isTemplate; }
   final class PackPlan { final List<PlannedFile> files; final Map<String, String> folderDefaultsToAdd; final List<String> folderDefaultsSkipped; final String templatesFolder; final bool willSetTemplatesFolder; }
   Future<PackPlan> planPack(PackManifest pack, {required VaultFileSystem fs, required VaultSettings settings, required DateTime now});
   ```
   Algorithm: resolve `templatesFolder`; for each file compute `wantedPath` from `target` (`{templates}` replaced, then `renderTemplate` with the context date `now`); make it unique: if `fs.stat` finds it, **or** an earlier planned file has the same `caseKey`, try `<stem> 1.<ext>`, `<stem> 2.<ext>`, … (the same ` N` rule as notes) → `actualPath`, `renamed = actualPath != wantedPath`; **nothing is ever overwritten**. `folderDefaultsToAdd`: every pack entry whose (normalised) key is not yet in `settings.templates.folderDefaults`, with the token replaced by the actual path of the referenced file; entries whose key already exists are listed in `folderDefaultsSkipped` and are left alone.
8. **Installing** (`pack_installer.dart`): `Future<PackInstallResult> installPack(PackPlan plan, PackManifest pack)`: for each planned file in order: read the asset text; replace tokens (`@{pack:key}`, `@{pack:key:link}`); if `render`, `renderTemplate(text, ctx)` (ctx: title = actual stem, date = now, folder = the file's folder, vaultName; prompts must not exist: an unanswered prompt would stay literal, and `gallery_assets_test` fails on that); write with `NoteTextWriter`-style atomic `fs.writeText(TextDocument(text: text))` (LF, no BOM); `.base` files are plain text. After all files: **one** `vaultSettingsProvider.update` that sets `templates.folder` when it was unset and merges `folderDefaultsToAdd`. If any write throws: every file created so far in this run is moved to the vault trash (`fs.delete(path, mode: TrashMode.vaultTrash)`), settings are untouched, and `PackInstallException` is thrown (snackbar `templateGalleryInstallFailed`). Result: created paths, renamed pairs, defaults added/skipped.
9. **Use template** (`template_gallery_service.dart`): `Future<VaultPath> useTemplate(GalleryEntry e)` copies the asset text **byte-for-byte** to `<templatesFolder>/<Title>.md` (`templatesFolder` = `templates.folder`, or `Templates` when unset, then the setting is written), never overwriting (` 1` suffix); returns the path. The success snackbar has the action "New note from it" (`TemplateApplier.createFromTemplate` in the default new-note folder).
10. **UI.** Command `templates.open-gallery` ("Template gallery", palette on; also "Template gallery…" in the explorer header "New…" menu and a "Browse gallery…" link at the bottom of the template picker). Desktop (≥ 840 dp): a dialog 920 × 640 dp — left rail (search field on top, categories: All, Packs, Work, Personal, Study, Engineering), middle list of entries (title, one-line description, a "Pack" badge), right detail pane. Phone: a full-screen route — search field, a horizontally scrolling row of category chips (48 dp), the list; tapping an entry pushes the detail screen.
    - **Detail for a template:** title, category, description, the Obsidian note when applicable, tabs **Preview** (the template rendered with `previewAnswers` and `title: 'Untitled'` through the reading view of Phase 1; frontmatter shown as a property list) and **Source** (raw text, monospace, selectable), button **Use template** (disabled while running; result snackbar).
    - **Detail for a pack:** description, the list of files it will create — one row per `PlannedFile` with the path, a badge "New" or "Exists → will be created as `<actual name>`", and for folder defaults a line "Default template for new notes in `Projects`: `Templates/Project brief.md`" (or "already set, unchanged") — tapping a row previews that file (Markdown rendered; `.base` as read-only YAML text); button **Install pack** → confirmation dialog "Create N files? Nothing will be overwritten." listing only the count and renamed files, then installs, then a result sheet with "Open `<first .base>`" and "Close". If any `.base` target already exists the detail shows the warning `templateGalleryAlreadyInstalled`.
    - The planned list is computed when the detail opens (`planPack` is cheap), recomputed if the vault changes.
11. l10n keys: `commandOpenTemplateGallery`, `templateGalleryTitle`, `templateGallerySearchHint`, `templateCategoryAll`, `templateCategoryPacks`, `templateCategoryWork`, `templateCategoryPersonal`, `templateCategoryStudy`, `templateCategoryEngineering`, `templateGalleryPackBadge`, `templateGalleryUse`, `templateGalleryInstall`, `templateGalleryPreviewTab`, `templateGallerySourceTab`, `templateGalleryFilesTitle`, `templateGalleryFileNew`, `templateGalleryFileRenamed`, `templateGalleryDefaultFor`, `templateGalleryDefaultKept`, `templateGalleryInstallConfirm`, `templateGalleryAlreadyInstalled`, `templateGalleryInstalled`, `templateGalleryInstallFailed`, `templateGalleryOpenBase`, `templateGalleryNewNoteFromIt`, `templateGalleryUsed`, `templateGalleryBrowse`, `templateGalleryObsidianNote` (06.25).

**Tests**
- `gallery_assets_test.dart` (reads the real assets from disk): the manifest lists exactly the 12 ids of item 2 and 4 packs; every `file`/`dir`/`asset` exists; `pubspec.yaml` lists the six directory entries; for every template: `renderTemplate(text, ctx, answers: previewAnswers(templatePrompts(text)))` yields text with **no** `{{`, a frontmatter that `FrontmatterEditor.read` parses (non-empty map with `type`), exactly ≤ 1 `cursorOffset`, and unrendered raw text that `loadYaml` can parse as frontmatter (quoted variables); `meeting-notes` has the prompt keys `prompt:Topic` only; `task` has `select:Priority`; `bug-report` has `select:Severity`; `decision-record` has `select:Status`; every pack: keys unique, every `asset` exists, every `@{pack:…}` token resolves, every `folderDefaults` value resolves to a template file of the same pack, every `render: true` file has no prompts; every `.base` of the packs: `BaseDocument.parse` has **zero issues**, every view `type` is in `BaseViewTypes.supported`, a `BaseEditor` with no calls gives 0 changed bytes, and the YAML parses with plain `loadYaml` (Obsidian-compatibility proxy); every Obsidian-type view uses only keys documented in 06.27 or `groupBy`/`groupOrder`/`order`/`sort`/`image`/`imageFit`/`filters`/`limit`/`name`/`type` (Tephra keys only start with `tephra`).
- `pack_plan_test.dart` (`MemoryVaultFileSystem(caseInsensitive: true)`, clock 2026-10-11): empty vault, `templates.folder` unset → `Templates/Project brief.md`, `Projects/Projects.base`, …, `willSetTemplatesFolder == true`; existing `Templates/Task.md` → `Templates/Task 1.md` (`renamed`), and a second `Task.md` target in the same plan would become `Task 2.md`; existing `projects/projects.base` (other case) → `Projects/Projects 1.base`; custom `templates.folder: _tpl` → `_tpl/Task.md`; target `Habits/{{date:YYYY-MM-DD}}.md` → `Habits/2026-10-11.md`; `folderDefaults` already containing `Projects` → in `folderDefaultsSkipped`, not in `ToAdd`.
- `pack_installer_test.dart`: install on an empty vault writes the 6 files of "Projects & tasks"; `Projects/Projects.base` contains `tephraNewNoteTemplate: "Templates/Project brief.md"` (token replaced) and `BaseDocument.parse` of every written `.base` has 0 issues; with the existing `Templates/Task.md` (content `KEEP`) the old file still reads `KEEP`, the new one is `Templates/Task 1.md` and `Tasks/Tasks.base` references `Templates/Task 1.md`, `folderDefaults.Tasks == "Templates/Task 1.md"`; `example-task` project link is `"[[Projects/Example project]]"`; rendered examples contain no `{{` and `due: "2026-10-14"`; installing twice → the second run creates ` 1` copies of everything and leaves the first set byte-identical; a write failure on the 4th file (fake fs) → the first 3 files are in `.trash`, settings unchanged, `PackInstallException`; settings written exactly once; `templates.folder` set to `Templates` only when it was unset; `folderDefaults` added without touching existing entries; written files use LF and no BOM.
- `template_gallery_service_test.dart`: `useTemplate(task)` writes bytes equal to the asset; again → `Task 1.md`; with `templates.folder` unset → `Templates/Task.md` and the setting becomes `Templates`.
- `template_gallery_ui_test.dart`: search `recipe` → only Recipe; category Engineering → Bug report and Decision record; category Packs → the 4 packs; at 1200 dp a dialog with a right detail pane, at 400 dp a full-screen route and 48 dp chips; template detail shows Preview with `[Topic]` for `meeting-notes` prompt and the Source tab shows the raw `{{prompt:Topic}}`; pack detail lists 6 files with "New" badges before any install (zero writes while browsing); **Install pack** → confirmation, then files exist; with an existing target the row shows the "will be created as" text; the Obsidian note (`templateGalleryObsidianNote`) appears on the detail of all 12 templates (each contains `{{cursor}}`, a prompt, a choice or a date offset) and does **not** appear for a synthetic test template containing only `{{title}}` and `{{date}}`.

**Verify**
```
cd app; flutter test test/vault/note_tools/gallery; cd ..
```
Manual (both platforms): open the gallery, preview "Meeting notes", "Use template", then "New note from it" → the two prompts; install "Projects & tasks" → files exist; open `Projects/Projects.base`, `Tasks/Tasks.base`; install it again → nothing overwritten.

**Pitfalls**
- Asset directories are **not** recursive in `pubspec.yaml`: every folder must be listed, or `rootBundle.loadString` throws at runtime only on that platform.
- Do not render templates when copying them to the vault (`Use template`): the user's copy must keep its variables.
- Never write pack files through `createFromTemplate` (no folder defaults, no prompts); the installer is a plain file copier with token replacement.

---

### 06.35 Template buttons: ` ```tephra-button ` blocks

**Purpose.** A fenced block that renders as a button in Reading view and Live Preview and runs a template action, so notes can carry
"New meeting", "Add task" or "Open dashboard" buttons. In Obsidian it is just a code block.

**Format (final).** The block body is YAML:
````
```tephra-button
label: New meeting
action: new-note-from-template
template: Templates/Meeting notes.md
folder: Meetings
name: "{{date:YYYY-MM-DD}} {{prompt:Topic}}"
style: filled
```
````
| Key | Required | Type | Meaning |
|---|---|---|---|
| `label` | always | text, 1–60 characters | button text |
| `action` | always | `new-note-from-template` \| `insert-template` \| `append-template` \| `open-note` \| `run-command` | what the click does |
| `template` | for the three template actions | vault path of a template (`Templates/Task.md`, `Templates/Task`, or a bare name resolved with the template folder then the index) | template to apply |
| `folder` | no | text (variables allowed) | `new-note-from-template`: target folder; default = the folder of the note containing the button |
| `name` | no | text (variables allowed) | `new-note-from-template`: file name pattern; default `Untitled` |
| `target` | for `open-note`; optional for `append-template` | text: vault path or note name (a `#Heading` suffix is allowed for `open-note`) | note to open / to append to; default for `append-template` = the note containing the button |
| `command` | for `run-command` | a registered command id (`editor.toggle-bold`) | command to run |
| `style` | no | `filled` (default) \| `outlined` | look |
Keys that do not apply to the chosen action are ignored; unknown keys are ignored. In `folder`, `name` and `target`, variables are rendered with the **hosting note** as context: `{{title}}` = the host note's stem, `{{folder}}` = its folder, `{{filename}}` = its file name, dates = now.
The template's **own** body is rendered with the **new** note as context (title = the new note's stem).

**Files**
- `app/lib/editor/tephra_button/button_spec.dart`, `button_runner.dart`, `button_widget.dart`, `button_block.dart` (new)
- modify: reading view code-block dispatch (language `tephra-button`), Live Preview `lp_decoration.dart` (`LpWidgetKind.tephraButton`), `block_decorator.dart`, widget registry (`widgets/lp_tephra_button.dart` new), `slash_commands.dart` (new item), `snippet_placement.dart` (no change expected), `commands` (one command)
- `app/lib/l10n/app_en.arb`
- tests: `app/test/editor/tephra_button/button_spec_test.dart`, `button_runner_test.dart`, `button_widget_test.dart`, `button_live_preview_test.dart`, `button_slash_test.dart`

**Implementation**
1. `button_spec.dart`:
   ```dart
   enum ButtonAction { newNoteFromTemplate, insertTemplate, appendTemplate, openNote, runCommand }   // YAML names: new-note-from-template, insert-template, append-template, open-note, run-command
   enum ButtonStyleKind { filled, outlined }
   final class ButtonSpec { const ButtonSpec({required this.label, required this.action, this.template, this.folder, this.name, this.target, this.command, this.style = ButtonStyleKind.filled}); … }
   sealed class ButtonParse { }
   final class ButtonOk extends ButtonParse { const ButtonOk(this.spec); final ButtonSpec spec; }
   final class ButtonError extends ButtonParse { const ButtonError(this.message, {this.line}); final String message; final int? line; }   // line is 1-based inside the block body
   ButtonParse parseButtonSpec(String yamlText);
   ```
   Rules, checked in this order, the **first** failure is reported: YAML syntax error → `Invalid YAML: <message>` with the line; not a map → `A button needs key: value lines`; `label` missing/empty → `label is required`; `label` not a string → `label must be text`; longer than 60 characters → `label is longer than 60 characters`; `action` missing → `action is required`; `action` not one of the five → `Unknown action "<x>". Use one of: new-note-from-template, insert-template, append-template, open-note, run-command`; required key of the action missing (`template` / `target` / `command`) → `<key> is required for <action>`; an optional or required key present but not a string → `<key> must be text`; `style` not `filled`/`outlined` → `style must be filled or outlined`. Messages are English constants in the parser and are shown through the l10n template `buttonErrorChip` ("Button error: {message}"); they are not translated (YAML keys are English).
2. **Rendering.**
   - Reading view: the reading view's code-block dispatch (the same place 06.19 hooks `base` and 06.21 `mermaid`) maps language `tephra-button` to `TephraButtonBlock(yaml, hostPath, blockRange)`.
   - Live Preview: `block_decorator.dart` produces for a fenced `MdCodeBlock` whose language is `tephra-button`: `LpWidget(tephraButton, data: {yaml, start, end})` over the whole block (fences included), `reveal` = the whole block (so the caret inside the block shows the source), and no other decoration for it. Add `tephraButton` to `LpWidgetKind` and implement `widgets/lp_tephra_button.dart` with the same pattern as the `base` block widget of 06.19.
   - Source mode: unchanged (plain text with code styling).
   - `TephraButtonWidget`: `FilledButton.icon` / `OutlinedButton.icon`, left aligned, min height 40 dp (desktop) / 48 dp (phone layout), icon by action (`add`, `post_add`, `note_add`, `open_in_new`, `play_arrow`), tooltip = a plain description ("New note from Templates/Task.md"), shows a small spinner and is disabled while the action runs; clicks within 500 ms after the previous click are ignored. Invalid spec → an error `Chip` (error colours, `buttonErrorChip` text, the line when known); in Live Preview tapping the chip moves the caret into the block (reveals the source).
   - A block that is not inside a note (a button in a canvas card) renders the same; `hostPath` = the canvas file's note-less context: actions needing a host note (`insert-template`, `append-template` without `target`) show the chip `buttonNeedsNote`.
3. **Running** (`button_runner.dart`, `ButtonRunner.run(WidgetRef ref, BuildContext context, ButtonSpec spec, ButtonHost host)` where `ButtonHost { VaultPath? note; EditorController? editor; bool isReadingView; int? blockEnd /* offset right after the closing fence line, in the editor's current text */ }`):
   - **new-note-from-template:** resolve `template` (sub-step 4); `folder` = rendered `spec.folder` or the host note's folder (vault root when no host); `name` = rendered `spec.name` or `Untitled`; call `TemplateApplier.createFromTemplate(folder, nameTemplate: name, templatePath, asker: askTemplatePrompt)` — prompts of the template, the name and the folder are gathered together and asked once each (06.26); the created note opens (new tab on desktop). The button never prefills properties.
   - **insert-template:** with an editor (Source/Live Preview): `planInsertTemplate(caret: blockEnd, selectionEnd: blockEnd)` — the template body is inserted on the line **after** the button block; in Reading view (no caret) it behaves exactly like `append-template` on the host note.
   - **append-template:** `TemplateApplier.appendToNote(target ?? host.note, templatePath, …)`; a missing target → snackbar `buttonTargetMissing`.
   - **open-note:** resolve `target` (exact vault path, with or without `.md`; else `index.resolveLink(target, from: host)`); open it with `openFile(ref, path, subpath: '#Heading' when given)`; missing → snackbar `buttonTargetMissing`.
   - **run-command:** `registry.byId(command)`: unknown id → snackbar `buttonCommandUnknown`; `isAvailable == false` → snackbar `buttonCommandUnavailable`; else a confirmation dialog "This button will run: <command label>" with "Run" / "Cancel" and a checkbox "Don't ask again for this command until I close the app" (the choice is kept in memory, per command id; never persisted). On "Run": `command.run(ref, context)`. No arguments can be passed; **no shell, no URL, no file path is ever executed**.
   - Insert/append into a note with `sticky-locked: true` (§6.5) → snackbar `buttonNoteLocked`, nothing written.
   - `TemplateCancelledException` → silent; `TemplateMissingException` → snackbar `templateUnreadable`; other `TephraException` → snackbar `buttonFailed` and a `warning` log (never the note text).
4. **Template path resolution** (`resolveButtonTemplate`): try `VaultPath(t)`; if `t` has no extension add `.md`; if not found try `<templates.folder>/<t>[.md]`; finally `index.resolveLink(t, from: host)`; the result must be a Markdown file.
5. **Slash menu:** add `SlashCommand(id: 'tephra-button', label: slashButton, keywords: ['button', 'action', 'template'], isBlock: true)` after the `template` item (02.22 list; update that list in `PROGRESS.md` notes). Snippet (the caret `|` marks where it ends up):
   ````
   ```tephra-button
   label: |
   action: new-note-from-template
   template: Templates/
   style: filled
   ```
   ````
   Command `editor.insert-template-button` ("Insert template button", palette on, no shortcut) inserts the same snippet at the caret using the block placement rules of `snippet_placement.dart` (new line before/after as needed).
6. l10n keys: `buttonErrorChip`, `buttonNeedsNote`, `buttonTargetMissing`, `buttonCommandUnknown`, `buttonCommandUnavailable`, `buttonRunCommandConfirm`, `buttonRunCommandRun`, `buttonRunCommandDontAsk`, `buttonNoteLocked`, `buttonFailed`, `buttonTooltipNewNote`, `buttonTooltipInsert`, `buttonTooltipAppend`, `buttonTooltipOpen`, `buttonTooltipCommand`, `slashButton`, `commandInsertTemplateButton`.

**Tests**
- `button_spec_test.dart`: the example block parses to `ButtonOk` with every field; minimal `label: A\naction: open-note\ntarget: B` → ok, style `filled`; `label: A\naction: run-command\ncommand: editor.toggle-bold` ok; errors (message exact): empty body → `A button needs key: value lines`; `label: [` → message starts `Invalid YAML:` with `line == 1`; `action: open-note` only → `label is required`; `label: 5` → `label must be text`; 61-character label → `label is longer than 60 characters`; `label: A` only → `action is required`; `action: explode` → `Unknown action "explode". Use one of: …`; `action: open-note` without target → `target is required for open-note`; `action: new-note-from-template` without template → `template is required for new-note-from-template`; `template: 3` → `template must be text`; `style: round` → `style must be filled or outlined`; unknown key `colour: red` is ignored; `append-template` without `target` is ok.
- `button_runner_test.dart` (fakes for applier, registry, index, editor): `new-note-from-template` with name `{{date:YYYY-MM-DD}} {{prompt:Topic}}` and a template with `{{prompt:Topic}}` → **one** prompt, created `Meetings/2026-10-11 Sync.md`; folder default = the host note's folder when `folder` is absent; `{{title}}` in `name` = the host note's stem; cancel → nothing created; `insert-template` in a Live Preview editor → one `applyEdits` inserting after `blockEnd`; in Reading view → append at the end of the note; `append-template` with `target: Log` resolves `Log.md` and appends; missing target → `buttonTargetMissing`, 0 writes; `open-note` with `target: Notes/A#Plan` → `openFile(path, subpath: '#Plan')`; `run-command` unknown id → snackbar, nothing runs; known id → confirmation shown, Cancel → not run, Run → `run` called once; "Don't ask again" skips the dialog for the second click of the same id only; `sticky-locked` host + `append-template` → `buttonNoteLocked`, 0 writes; a second click within 500 ms is ignored; template path forms `Templates/Task`, `Task` (found under the templates folder) and a name resolved by the index.
- `button_widget_test.dart`: filled vs outlined; error chip text for `action: explode`; at 400 dp the button is ≥ 48 dp high; spinner while running; the widget never writes a file by itself on build (0 writes).
- `button_live_preview_test.dart`: a note with a `tephra-button` block yields exactly one `LpWidget(tephraButton)` covering the fenced block with `reveal` = the same range; caret inside the block → `isRevealed` true (source shown); the decorations of `base` and `mermaid` blocks are unchanged; Source mode text of the block is untouched; parse→save of a note containing the block writes 0 bytes.
- `button_slash_test.dart`: typing `/butt` lists "Button"; Enter inserts exactly the snippet above with the caret after `label: `; one undo removes it; `editor.insert-template-button` on a non-empty line inserts a line break before the block.

**Verify**
```
cd app; flutter test test/editor/tephra_button test/editor/live_preview; cd ..
```
Manual (both platforms): create a note with the four example buttons (new note, insert, append, run-command `editor.toggle-bold`); click each; open the note in Obsidian → shows the YAML as a normal code block, nothing else.

**Pitfalls**
- A button is a **code block**: never add syntax outside fences (conventions §6.3, GEMINI.md rule 2).
- `run-command` is a privilege escalation vector in a shared vault; the confirmation dialog is mandatory and must not be skipped by a setting in this phase.
- `blockEnd` must be recomputed from the live text at click time (the user may have typed above the block since the widget was built).

---

### 06.36 Views performance, Obsidian compatibility check and consolidation

**Purpose.** Prove the speed budgets for the new views, record what Obsidian does with a `.base` that contains Tephra-only views, and make
sure every command, setting and string introduced in 06.25–06.35 is registered.

**Files**
- `tool/gen_bench_vault.dart` (modify: new flag `--db 2000`)
- `app/integration_test/bases_views_perf_test.dart` (new)
- `app/lib/bases/view/framework/view_ready_key.dart` (new: `const basesViewReadyKey = ValueKey('bases-view-ready')`; every renderer puts it on the widget that exists only after the first non-empty layout)
- `test_vaults/syntax/bases/tephra-views.base` (06.27), `test_vaults/syntax/Projects/*.md` (new: `Alpha.md`, `Beta.md`, `Gamma.md` with `status`, `due`, `start`, `cover`)
- `app/test/commands/bases_templates_commands_test.dart`, `app/test/l10n/phase06b_keys_test.dart` (new)
- `PROGRESS.md` (numbers, "Obsidian compatibility of Tephra views")

**Implementation**
1. **Bench data.** `dart run tool/gen_bench_vault.dart --db 2000` (in addition to the normal 10k notes) adds the folder `Db/` with **2,000 notes** whose frontmatter is generated with a seeded `Random(42)`: `status` one of `Todo`, `Doing`, `Review`, `Done`, `Blocked`; `due` = 2026-01-01 + a uniform 0–364 days (`YYYY-MM-DD`); `start` = `due` − 0–14 days; `end` = `due`; `tags` one of five; `cover` = `[[img-<n>.png]]` for 30 % of the notes with `n` in 0–199; and 200 generated 800×600 PNG files `Db/img-<n>.png` written by a small PNG encoder in the tool (`dart:io` `ZLibEncoder`, 8-bit RGB, no new package). It also writes `Db/Bench.base` with the views `table`, `kanban` (group `note.status`), `tephra-calendar` (`note.due`, month mode, anchored at the date given by the test: the test sets the anchor to 2026-06-15), `tephra-gallery` (`image: note.cover`), `tephra-timeline` (`note.start`/`note.end`, zoom week), `list`, all with the filter `file.inFolder("Db")`. For the **10k-row** scenario the flag `--db 10000` creates 10,000 such notes.
2. **Budgets** (record in `PROGRESS.md` exactly like this; profile mode; median of 3 runs; the test reports each run):
   - Open time = from `openFile(Db/Bench.base)` (view already selected by the test) until the widget with `basesViewReadyKey` exists after `pumpAndSettle`. Scenario: 2,000 matching notes, warm index (after first index).
     - Board: Windows **< 500 ms**, Android **< 1 s**. Calendar (month mode): Windows **< 500 ms**, Android **< 1 s**.
     - Table, List, Gallery, Timeline over the same 2,000 notes: **recorded, not gated** (expected to be in the same range; if any exceeds 1 s on Windows, apply the tuning list below and record the result).
   - Responsiveness over **10,000** matching notes (`--db 10000`), scripted 10 s interaction per view (Board: scroll the longest lane 5 s and drag one card between lanes; Calendar: switch months 10×, switch month/week/agenda; Gallery and List and Table: fling-scroll 6 s; Timeline: pan 4 s and change zoom twice): average frame ≤ 16.7 ms and p90 ≤ 20 ms on Windows; average ≤ 33.3 ms and p90 ≤ 40 ms on the phone (same measurement as 06.11, `FrameTiming.totalSpan`).
   - No frame of the scripted interactions blocks the UI isolate for more than 100 ms (assert with the timing list: max `buildDuration + rasterDuration` ≤ 100 ms except the first frame of each view; record the worst).
3. **Tuning order if a budget is missed** (re-measure after each, record each): (1) make sure the executor result is reused when only the selected view changes (one query per (document text hash, view index, dataset revision)); (2) run layout (`buildBoard`, `layoutMonth`, `layoutTimeline`, `buildGallery`) in `Isolate.run` from **200** rows instead of 500; (3) Board: `cacheExtent` 300 and no cover images for cards outside the viewport; (4) Calendar: pass only items intersecting the visible grid to the painter; (5) Gallery: cap concurrent thumbnail jobs to 2 on the phone. If the budget is still missed by more than 25 %, stop and ask the human (GEMINI.md §5).
4. **Manual check: Obsidian opens a `.base` with Tephra-only views (do it on Windows; it needs Obsidian installed; if it is not available, stop and ask the human to run it — do not tick the gate without it).**
   1. Copy `test_vaults/syntax` to a scratch folder (never edit the fixture), open the copy as a vault in Obsidian (a version that has Bases; note its version number).
   2. Open `bases/tephra-views.base`. Record in `PROGRESS.md` → "Obsidian compatibility of Tephra views", **for each of the seven views** (Table, Board, List, Calendar, Gallery, Timeline, Map): what Obsidian shows (tab present or not; the exact text of any error or "unsupported" message; whether its Table, Cards-like, List, Kanban views display the right notes and lanes — the Board's lanes must be `Planned`, `Active`, No value, in that order, proving `groupOrder` is honoured), and whether the file opened at all.
   3. In Obsidian, edit the Table view (change its sort, add a column) and let Obsidian save the file; close it. Compare the saved file with the original (`git diff --no-index`): record whether the Tephra-only views (`tephra-calendar`, `tephra-gallery`, `tephra-timeline`), the `tephra*` keys (top-level and inside views), `tephraCardOrder` and the `map` view survived Obsidian's save.
   4. Open the Obsidian-saved file in Tephra: all seven tabs must still exist if Obsidian preserved them (record any loss). Then make one edit in Tephra (drag a board card, change the calendar mode), open the file in Obsidian again: it must still open and its own views must work.
   5. **Success criteria:** the file opens in Obsidian; Obsidian's own views (table, cards, list, kanban) show correctly and Obsidian's own view settings are unchanged by Tephra's edits; every observation is recorded. **If Obsidian refuses to open the file, or drops Tephra-only views or keys when it saves, stop and ask the human** (GEMINI.md §5) with the recorded evidence; do not invent a workaround. The human may then choose between (a) accepting the loss, (b) keeping Tephra-only views in a Tephra sidecar file under `.tephra/`, or (c) dropping Tephra-only view types.
   6. Also record in `PROGRESS.md` the YAML key names Obsidian wrote for a Kanban view's image settings and for a List view's marker options (create both in Obsidian via its UI, save, read the file) — the 06.27 assumption check. If they differ from `image`/`imageFit`/`imageAspectRatio`, add the Obsidian names as read-only fallbacks to `BoardOptions`/`ListOptions` (read, never rewritten unless the user changes that setting in Tephra) and update the fixture and the Hand-off.
5. **Command registry test** (`bases_templates_commands_test.dart`): asserts these ids exist in `commandRegistryProvider`, have a label and are in the palette (unless noted): `templates.insert-template`, `templates.append-template`, `templates.new-note-from-template`, `templates.open-gallery`, `bases.create-base`, `bases.insert-base-block`, `bases.add-view`, `bases.new-note`, `bases.undo`, `bases.redo`, `bases.create-database-here`, `bases.select-view-1` … `bases.select-view-9` (`showInPalette: false`), `editor.insert-template-button`. And that `bases.new-note`, `bases.undo`, `bases.redo` are unavailable when the active tab is not a Base tab.
6. **l10n test** (`phase06b_keys_test.dart`): reads `app_en.arb` and asserts that every key named in the `l10n keys` lists of steps 06.25–06.35 exists and has a non-empty value (the list is copied into the test as a constant), and that no `Text('…')`/`SnackBar(content: Text('…'))` with a hard-coded English literal exists in `app/lib/bases`, `app/lib/vault/note_tools`, `app/lib/editor/tephra_button` (regular-expression scan of those folders; `button_spec.dart` parser messages are the documented exception).
7. **Settings registry (for Phase 7):** verify and list in `PROGRESS.md`: `templates.askOnNewNote`, `templates.folderDefaults`, `bases.firstDayOfWeek` (and the unchanged 02.22/02.27 template keys); the `.base` option keys of 06.27; the `tephra-button` format of 06.35; the template variables of 06.25.
8. Update `PROGRESS.md` → "Phase 6 notes → Contract additions": `.tephra/cache/thumbs/` and its `index.json`; new `.tephra/settings.json` keys; new `NoteFactory`/`TemplateApplier`/`BaseViewHost` public APIs; `TemplateContext` optional fields; `BaseViewTypes`; `BaseEditor` methods; `runBaseQuery` parameters; `NoteIndex` unchanged.

**Tests**
- `bases_views_perf_test.dart` itself (both platforms; skipped without `--dart-define=TEPHRA_BENCH_VAULT`).
- `phase06b_keys_test.dart` and `bases_templates_commands_test.dart` (above).
- A unit test for the PNG encoder of the bench tool: a 4×4 image decodes with `ui.instantiateImageCodec` (tagged `gpu`) or, in a plain `dart test`, has the PNG signature, correct IHDR width/height and a valid CRC for every chunk.

**Verify**
```
dart run tool/gen_bench_vault.dart --db 2000
cd app; flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/bases_views_perf_test.dart -d windows --dart-define=TEPHRA_BENCH_VAULT=D:\script\tephra-gemini\test_vaults\bench; cd ..
cd app; flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/bases_views_perf_test.dart -d <android-id> --dart-define=TEPHRA_BENCH_VAULT=/sdcard/Documents/TephraBench; cd ..
cd app; flutter test test/commands test/l10n; cd ..
```
(Regenerate with `--db 10000` for the responsiveness scenario and copy it to the phone as in 06.11.) Success: numbers recorded and within budget; the Obsidian check recorded.

**Pitfalls**
- Never record emulator numbers as the phone budget (06.11 rule). Never measure in debug mode.
- Obsidian may rewrite the `.base` on its own saves and may not know Tephra's keys; that is why the check is manual and recorded, not assumed.
- The bench vault is git-ignored (`test_vaults/bench/`); never commit generated notes or PNGs.

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
12. Open the template gallery (command "Template gallery") → search "projects", open the pack, read the list of files it will create, **Install pack** "Projects & tasks"
    → `Projects/Projects.base`, `Tasks/Tasks.base`, two templates and two example notes exist; nothing existing was changed (install it a second time: copies with ` 1` suffix appear, originals untouched).
13. Open `Projects/Projects.base` → tab "Board": drag the example project from `Active` to `Done` (phone: long-press, drag; or ⋮ → Move to) → open the note: only its `status:` line changed
    (`Done`); press `Ctrl+Z` in the base (phone: command palette "Undo in base") → the line is back. Hide the `Planned` lane, restart the app → still hidden (`groupOrder` in the `.base`).
14. In the board press "+ New" in the `Active` lane → a note appears in `Projects/` with `status: Active`, created from the Project brief template, opened in a tab; the new-note name `Untitled`; do it twice → `Untitled 1`.
15. Open `Tasks/Tasks.base` → tab "Calendar": drag the example task to another day → its `due:` changes (only the date digits); switch to Week and Agenda; set the first day of week to Saturday in
    settings (`bases.firstDayOfWeek`) → columns follow; tap an empty day → day sheet → New → the note has that `due`. Switch to the Board tab and drag a task to `Doing`.
16. Create a template with `{{prompt:Topic}}`, `{{select:Kind|Idea,Bug}}`, `{{date+7d:YYYY-MM-DD}}` and `{{cursor}}`; set it as the default template of a folder (explorer menu "Set default template…") →
    "New note" in that folder asks Topic and Kind once each, the caret is at the marker; cancelling the second question creates nothing. Apply the template with "Insert template" to a note that already has `tags:` → tags merged, other properties unchanged.
17. In a note add a ` ```tephra-button ` block (slash menu "Button") with `new-note-from-template` → click it (Reading view and Live Preview) → the note is created; add a `run-command` button → a confirmation appears first. Source mode shows the YAML text.
18. In a note run "Create database here" → `<folder> database.base` is created and `![[… .base]]` appears at the cursor and renders a table of that folder; use the view tabs and "+ New" inside the embed.
19. Open `Projects/Projects.base` and `test_vaults/syntax/bases/tephra-views.base` (copied to a scratch vault) in **Obsidian** → the files open; Obsidian's own views work; what Obsidian shows for the Tephra-only views is recorded in `PROGRESS.md`.

## Exit gate

All boxes must be ticked in `PROGRESS.md` with evidence (numbers or file names).

- [ ] Every step 06.1–06.36 is ticked, with tests passing: `flutter analyze --fatal-infos` clean, `dart format` clean, all package
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
- [ ] **Template engine v2:** all `template_engine_v2_test`, `template_prompt_test`, `template_date_offset_test` and `template_merge_test` cases pass, and every 02.22 / 02.27 template test still passes unchanged (except the documented 02.27 list-merge rule change, recorded in `PROGRESS.md` → Conflicts).
- [ ] **Template cancel safety:** cancelling any prompt (new note, insert, append, button, "+ New" in a view) leaves **0** files written and no empty note (tests `template_applier_test`, `new_note_flow_test`, `button_runner_test` pass).
- [ ] **Template gallery:** all 12 bundled templates and 4 packs pass `gallery_assets_test` (no unresolved `{{`, valid frontmatter, every pack `.base` parses with 0 issues and round-trips with 0 changed bytes); installing a pack never overwrites an existing file (`pack_installer_test`); a failed install leaves no new files.
- [ ] **Base round-trip with Tephra views:** every fixture in `test_vaults/syntax/bases/` (including `kanban.base`, `list.base`, `tephra-views.base`, `map-unsupported.base`, `tephra-options-invalid.base`) opens and closes in Tephra with **0 changed bytes**; a drag, a lane hide, a calendar mode change and a timeline resize each change only the intended keys (diff checked in `base_editor_v2_test` and `board_view_test`); every `tephra*` key, the `map` view and unknown keys survive every edit.
- [ ] **Property writes are minimal:** dragging a board card or rescheduling a calendar/timeline item changes only the affected frontmatter lines of that note (byte diff in `base_property_writer_test`, `calendar_view_test`, `timeline_view_test`), each action is **one** Bases undo step, and undo restores the exact original bytes.
- [ ] **Obsidian-open check recorded:** `tephra-views.base` and one pack `.base` were opened in Obsidian (version recorded); the file opened; Obsidian's table/cards/list/kanban views displayed correctly; what Obsidian shows for `tephra-calendar`, `tephra-gallery`, `tephra-timeline` and `map`, and whether its own save preserved the Tephra-only views and `tephra*` keys, are written in `PROGRESS.md` → "Obsidian compatibility of Tephra views"; the Kanban image-key and List-option key names written by Obsidian are recorded. (If Obsidian is unavailable on this machine, stop and ask the human to perform this check.)
- [ ] **Board/Calendar open budget (Windows):** 2,000 matching notes, profile mode, median of 3: Board open **< 500 ms** and Calendar (month) open **< 500 ms**. Numbers recorded.
- [ ] **Board/Calendar open budget (Android phone):** same scenario on the real phone: Board **< 1 s**, Calendar **< 1 s**. Device model and numbers recorded.
- [ ] **10k-row responsiveness:** with 10,000 matching notes, Table, List, Gallery, Board, Calendar and Timeline pass the scripted interaction: Windows average frame ≤ 16.7 ms and p90 ≤ 20 ms; phone average ≤ 33.3 ms and p90 ≤ 40 ms; no frame over 100 ms after the first frame of a view. Numbers recorded per view.
- [ ] **Thumbnail cache:** `.tephra/cache/thumbs/` never exceeds 200 MB (eviction test), thumbnails are ≤ 256 px, and no cache file is visible in the explorer, the index or sync (test + manual).
- [ ] **Templates in Obsidian:** a template made from the gallery and a note created from it open in Obsidian with intact properties; Tephra-only variables appear literally only in the **template** file when inserted by Obsidian (documented behaviour); `tephra-button` blocks show as plain code blocks in Obsidian.
- [ ] **Button safety:** `run-command` always asks for confirmation, only runs registered command ids, and `button_runner_test` proves no other action runs anything (no shell, no URL).
- [ ] `bases_templates_commands_test` and `phase06b_keys_test` pass (all new commands registered, all new l10n keys present, no hard-coded UI strings).
- [ ] Demo script 1–19 passes on Windows and Android.

## Hand-off

When the gate is green:
1. Update `PROGRESS.md`: tick the gate, record the performance numbers, the name map, the contract additions (new `NoteIndex` methods,
   `splitSlides`, canvas codec, Bases engine, `.tephra/graph.json`, `.tephra/cache/mermaid/`, `.tephra/cache/link-previews.json`,
   `.tephra/cache/pdf-state.json`, `.tephra/cache/thumbs/` with its `index.json`, vault settings `codeBlockLineNumbers`, `canvas.fetchLinkPreviews`,
   `templates.askOnNewNote`, `templates.folderDefaults` and `bases.firstDayOfWeek`), the WebView package actually used (primary or fallback), the
   Mermaid version, the Obsidian version used for the Bases compatibility check and its findings, and the conflicts listed below.
2. `git checkout main`, `git merge --no-ff phase-06`, `git tag v0.06.0`.
3. Stop and report to the human: what was built, gate results with numbers, anything "not verified on device" or "not verified in
   Obsidian", and the contract additions that should be folded into `00-conventions.md`.

What Phase 7 relies on from this phase:
- `HeadlessWebRunner`/the chosen WebView package (Phase 7 web viewer uses the same package's visible WebView on Windows).
- `ViewRegistry` + `TabContent` (Phase 7 adds a `WebViewerTabContent` and extends workspace features).
- Graph and canvas `CustomPainter`s (Phase 7 adds accessibility semantics and list alternatives).
- Theme colour mappings in `GraphColors` and `CanvasColors` (Phase 7 replaces them with theme tokens).
- Vault settings keys added here (Phase 7 lists them in the settings registry).

What Phases 7, 8 and 9 rely on from steps 06.25–06.36 (reference these names; do not rename them):
- **New vault settings keys** (`.tephra/settings.json`; Phase 7 settings screens): `templates.askOnNewNote` (bool, default `false`), `templates.folderDefaults` (map folder → template path; `""` value = explicitly none; longest folder-prefix match, case-insensitive),
  `bases.firstDayOfWeek` (`sunday` | `monday` | `saturday`, default `monday`). Existing and reused: `templates.folder`, `templates.dateFormat`, `templates.timeFormat`, `corePlugins.templates`.
- **`.base` view types:** Obsidian's `table`, `cards`, `list`, `kanban` (= Tephra Board; Obsidian's Kanban shipped in Obsidian 1.14, `https://obsidian.md/help/bases/views`), `map` (preserved, unsupported); Tephra-only `tephra-calendar`, `tephra-gallery`, `tephra-timeline`.
  `BaseViewTypes` (`tephra_search`) is the single list; Phase 8's query/AI features and Phase 9's docs must use it.
- **`.base` option keys** (view level unless noted): Obsidian's `groupBy {property, direction}`, `groupOrder`, `order`, `sort`, `filters`, `limit`, `image`, `imageFit`, `imageAspectRatio`, `columnSize`, `cardSize`; Tephra's `tephraLaneWidth`, `tephraCardOrder`, `tephraStartProperty`, `tephraEndProperty`,
  `tephraCalendarMode`, `tephraWeekStart`, `tephraZoom`, `tephraGallerySize`, `tephraCoverFromBody`, `tephraListMarker`, `tephraListSeparator`; and the "New" options `tephraNewNoteFolder`, `tephraNewNoteName`, `tephraNewNoteTemplate` (view level or top level of the document).
- **Public APIs:** `BaseEditor` option methods, `runBaseQuery(..., extraColumns, skipGroupBy)`, `BaseResultRow.extraRaw`, `buildBoard`, `planLaneMove`, `buildCalendarItems`, `layoutMonth`/`layoutWeek`/`layoutAgenda`, `planReschedule`, `layoutTimeline`, `planTimelineChange`, `resolveCover`,
  `deriveNewNotePrefill` (all `tephra_search`); `BaseViewHost`, `BaseViewRenderer`/`baseViewRegistryProvider`, `NoteTextWriter`, `BaseUndoStack`, `NewNoteService`, `ThumbService` (`app/lib/bases/view/`); `renderTemplate`, `templatePrompts`, `collectTemplateAnswers`, `TemplateContext` (new optional fields), `TemplateCancelledException` (`tephra_core`);
  `TemplateApplier`, `NoteFactory`, `newNoteInFolder`, `resolveFolderTemplate`, `planPack`/`installPack` (`app/lib/vault/note_tools/`).
- **Template variables** (grammar in 06.25): `{{title}}`, `{{date[+Nd|-Nw|+Nm|-Ny][:FORMAT]}}`, `{{time[:FORMAT]}}`, `{{folder}}`, `{{vault}}`, `{{filename}}`, `{{cursor}}`, `{{prompt:Question[|default]}}`, `{{select:Question|a,b,c}}`. Obsidian leaves all but `title`, `date`, `time` literal.
- **`tephra-button` block** (06.35): fenced block, YAML body with keys `label`, `action` (`new-note-from-template` | `insert-template` | `append-template` | `open-note` | `run-command`), `template`, `folder`, `name`, `target`, `command`, `style` (`filled` | `outlined`); `run-command` needs a confirmation and a registered command id.
- **New commands:** `templates.new-note-from-template`, `templates.append-template`, `templates.open-gallery`, `bases.new-note`, `bases.undo`, `bases.redo`, `bases.create-database-here`, `bases.select-view-1`…`9`, `editor.insert-template-button` (Phase 7 hotkey screen lists them; none has a default shortcut except `bases.new-note` `Ctrl+Alt+N`, `bases.undo` `Ctrl+Z`, `bases.redo` `Ctrl+Shift+Z` in a Base tab, `Ctrl+Alt+1`…`9` for view selection).
- **Slash menu:** item `tephra-button` ("Button") added after `template` (Phase 7's slash-command settings list must include it).
- **Bundled content:** `app/assets/template_gallery/` (manifest + 12 templates + 4 packs); Phase 9 documentation chapters "Database views" and "Templates" describe exactly the formats above; a `manifest_<locale>.json` can supply translated titles later.
- **Conflicts and deviations recorded for the human** (copy into `PROGRESS.md` → Conflicts): (1) the Board uses `type: kanban`, not a Tephra-only `tephra-board`, because Obsidian now ships Kanban; (2) 02.27's merge rule (union of **all** list properties) is narrowed to `tags`, `aliases`, `cssclasses`, and empty note values are filled from the template;
  (3) bundled template/pack titles and descriptions live in `manifest.json` rather than `app_en.arb` (content, not UI chrome); (4) `.tephra/cache/thumbs/` and the `templates`/`bases` settings keys are new contract entries; (5) conventions §2 lists no `templates/` app folder, so template code lives in `app/lib/vault/note_tools/`.
