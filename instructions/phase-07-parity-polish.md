# Phase 07 — Remaining parity & polish

> **Duration:** 4 weeks (20 steps).
> **Goal:** close every remaining gap with Obsidian's core features (note composer, format converter, word count, random note, audio
> recorder, file recovery, footnotes view, web viewer, workspace features, multi-cursor, vim mode, spell check, RTL, settings, themes,
> accessibility) and make the app feel finished: empty states, onboarding guide vault, consistent animations, plain-language errors,
> and every command reachable. At the end, every item of IMPLEMENTATION_PLAN §4.1 works on Android and Windows.

---

## Before you start

1. Read `GEMINI.md` and `instructions/00-conventions.md` in full. Sections are referenced as "§N" and never redefined here.
2. Confirm in `PROGRESS.md` that the Phase 6 exit gate is fully ticked. If not, stop.
3. `git checkout main`, then `git checkout -b phase-07`.
4. Run the full check suite (same commands as Phase 6 "Before you start" item 4). Everything must pass before Step 07.1.
5. **Names of existing code.** Phase 6's `PROGRESS.md` "Name map" lists the real names of Phase 1–5 code. Use those names. Additionally
   find and record (expected name → real name, path) for:

   | Role (built in) | Expected name / location |
   |---|---|
   | Theme root (Ph. 0) | `AppTheme` in `app/lib/theme/` building `ThemeData` for light/dark |
   | Settings screen (Ph. 1+) | `app/lib/settings/` screens; hotkeys screen (Ph. 1) |
   | Status bar (Ph. 1) | desktop status bar widget in `app/lib/workspace/` |
   | Ribbon (Ph. 1) | left ribbon widget (desktop) + drawer (phone) |
   | Mobile toolbar (Ph. 1) | keyboard toolbar reading `showInMobileToolbar` commands |
   | History snapshots (Ph. 3) | local snapshot service writing `.tephra/history/` (e.g. `LocalHistoryService`) and the per-note history screen |
   | Pop-out/sticky window protocol (Ph. 4) | `desktop_multi_window` usage + the single-writer channel used by sticky windows |
   | HTML → Markdown (Ph. 5) | e.g. `HtmlToMarkdown.convert(String html)` in `tephra_io` |
   | Outline panel (Ph. 2) | outline widget; check whether drag-to-move sections already exists |
   | WebView package (Ph. 6) | `flutter_inappwebview` (or the fallback recorded in Phase 6) |
   | View registry (Ph. 6) | `ViewRegistry`, `TabContent` in `app/lib/workspace/` |
   | Device id (Ph. 0/3) | app setting `deviceId` |

   Never rename existing code. Record the map in `PROGRESS.md` → "Phase 7 notes → Name map".
6. **Additions made by this phase (permitted; record them under "Phase 7 notes → Contract additions"):**
   - New per-vault paths: `.tephra/themes/` (vault themes), and new keys inside `.tephra/workspace.json` (`saved` layouts) and
     `.tephra/settings.json` (keys in Step 07.1).
   - New app-level paths: `<appSupportDir>/themes/`, `<appSupportDir>/fonts/`, `<appSupportDir>/dictionaries/` is **not** used (spell
     check uses OS services, see 07.16).
   - New app setting keys (Step 07.1).
   - `EditorController` gains multi-selection, vim and spell-check hooks (07.14–07.16). `EditorController` is app code, not a §7
     contract, so this is allowed; keep its existing public members unchanged.
7. **Decisions that differ from the phase overview (PHASE_PLAN 7.3) and why** — copy into `PROGRESS.md`:
   - *Spell check on Windows uses the Windows Spell Checking API (`ISpellCheckerFactory`, Windows 8+) through `package:win32` COM
     bindings, not Hunspell.* Reason: no dictionaries to ship (Hunspell dictionaries are often GPL/LGPL/MPL tri-licensed and vary per
     language), the OS already has the user's languages and personal dictionary, and `win32` is BSD-3-Clause.
   - *Spell check on Android uses Flutter's `DefaultSpellCheckService`* (Android's spell checker session through the Flutter engine),
     called by our editor layer, so it works with any editor engine.
8. Re-check every package README before use; follow the README if APIs differ and note it.

---

## What exists when done

- **Settings** (`app/lib/settings/`): a registry of every setting (key, type, default, scope, section) driving screens that mirror
  Obsidian's sections: Editor, Files & links, Appearance, Hotkeys, Core plugins, Sync, About.
- **Theme engine** (`app/lib/theme/`): JSON theme files (`schemaVersion 1`) with ~50 named colour tokens, typography, spacing and radius;
  four bundled themes that pass WCAG contrast tests; per-app and per-vault theme folders; a theme editor with live preview; import of
  colour variables from an Obsidian `theme.css`; custom fonts; accent colour; interface zoom.
- **Core plugins:** note composer (merge, extract selection, extract heading), format converter, word/character count (status bar +
  selection), random note, audio recorder, file recovery (snapshot browser with diff/restore), footnotes view, web viewer (Windows),
  outline drag-to-move. Each can be turned off in Settings → Core plugins.
- **Workspace:** tab groups, pinned tabs, stacked tabs, linked panes, saved workspaces, pop-out windows (Windows), session restore.
- **Editor extras:** multi-cursor (desktop), vim mode (desktop), spell check (Android + Windows), RTL, paste HTML → Markdown, drag
  blocks by handle in Live Preview.
- **Accessibility:** semantics on every control and custom-painted view (graph/canvas list alternatives), keyboard-only navigation with
  visible focus, contrast tests, text scaling up to 200% verified by golden tests.
- **Polish:** empty states, a bundled "Tephra Guide" vault created on first run, a single animation spec, plain-language errors from l10n,
  and a test proving every command is reachable from the palette and from the mobile toolbar.

---

## Dependencies

Add with `flutter pub add <name>` in `app/`, then `dart run tool/check_licenses.dart`.

| Package | Licence | Used for | Step |
|---|---|---|---|
| `record` | BSD-3-Clause | Audio recorder (Android: AAC-LC `.m4a`; Windows: AAC-LC `.m4a` via Media Foundation) | 07.9 |
| `win32` | BSD-3-Clause | Windows Spell Checking API (COM) — add only if not already a transitive/direct dependency; pin the major version the README documents `SpellCheckerFactory` for | 07.16 |
| `ffi` | BSD-3-Clause | Needed with `win32` for COM strings/pointers (usually already present) | 07.16 |
| Already present (do not re-add): `flutter_inappwebview` (Ph. 6, web viewer), `desktop_multi_window` (Ph. 4, pop-outs), `window_manager` (Ph. 4), `pasteboard` (Ph. 1, image paste), `win32` (added in 07.16), `file_picker` (Ph. 1, fonts/theme import), `characters` (Flutter SDK), `video_player` (Ph. 6, recording playback), `path_provider`, `yaml_edit`, `url_launcher` | MIT / BSD / Apache-2.0 | — | — |

**Microphone permission:** Android `RECORD_AUDIO` in `AndroidManifest.xml` (requested at runtime through `record`'s `hasPermission()`);
Windows needs no manifest change for desktop apps, but Windows privacy settings can block microphone access — handle the error (07.9).

**Rejected:** Hunspell-based Dart packages (dictionary licensing, see Before you start item 7); `flutter_colorpicker` (write the small
colour picker yourself — a hue/saturation square is not needed; presets + hex field + HSL sliders are enough).

---

## Steps

### 07.1 Settings registry and storage

**Purpose.** One typed registry of every setting so screens, defaults, storage and tests come from the same source.

**Files**
- `app/lib/settings/setting_definition.dart` (new)
- `app/lib/settings/settings_registry.dart` (new: the complete list below)
- `app/lib/settings/settings_store.dart` (new or modify: typed get/set over app-level and vault-level JSON)
- `app/lib/settings/providers.dart` (new or modify)
- `app/test/settings/settings_registry_test.dart`, `settings_store_test.dart` (new)

**Implementation**
1. Model:
   ```dart
   enum SettingScope { app, vault }          // app = <appSupportDir>/settings.json; vault = <vault>/.tephra/settings.json
   enum SettingSection { editor, filesAndLinks, appearance, hotkeys, corePlugins, sync, about }
   sealed class SettingType<T> { }           // BoolSetting, IntSetting(min,max,step), DoubleSetting(min,max,step), StringSetting,
                                             // EnumSetting(values), StringListSetting, ColorSetting (#RRGGBB)
   final class SettingDefinition<T> {
     const SettingDefinition({required this.key, required this.type, required this.defaultValue, required this.scope,
       required this.section, required this.label, this.description, this.desktopOnly = false, this.group, this.pluginId});
     final String key; final SettingType<T> type; final T defaultValue; final SettingScope scope; final SettingSection section;
     final String Function(AppLocalizations) label; final String Function(AppLocalizations)? description;
     final bool desktopOnly;     // hidden on phone layout (width < 840)
     final String? group;        // sub-heading inside the section
     final String? pluginId;     // only shown when that core plugin is enabled
   }
   ```
2. **Existing keys:** Phases 1–6 already store some of these settings. For each row below, search for the existing key. If it exists
   under another name or in another file, **keep the existing key and scope** (do not migrate user files) and put the existing key in the
   registry instead of the one below; note every such difference in `PROGRESS.md`. If a setting in the table has no behaviour yet, its
   behaviour is implemented in the step named in the "Implemented in" column — never add a setting that does nothing.
3. The registry (exact list; `l10n` labels named `setting<UpperCamelKey>` with dots removed, e.g. `editor.vimMode` → `settingEditorVimMode`):

   **Editor** (`SettingSection.editor`)
   | Key | Type | Default | Scope | Implemented in |
   |---|---|---|---|---|
   | `editor.defaultTabView` | enum `editing`/`reading` | `editing` | vault | Ph. 2 (existing) |
   | `editor.defaultEditingMode` | enum `livePreview`/`source` | `livePreview` | vault | Ph. 2 |
   | `editor.readableLineLength` | bool | `true` | vault | Ph. 1 |
   | `editor.strictLineBreaks` | bool | `false` | vault | Ph. 1 (if absent: implement in 07.2 — reading view renders a soft break as a line break when false) |
   | `editor.propertiesInDocument` | enum `visible`/`hidden`/`source` | `visible` | vault | Ph. 2 (if absent: 07.2) |
   | `editor.foldHeadings` | bool | `true` | vault | Ph. 2 |
   | `editor.foldIndent` | bool | `true` | vault | Ph. 2 |
   | `editor.lineNumbers` | bool | `false` | vault | Ph. 1 (if absent: 07.2, only if the editor engine supports a gutter; otherwise omit the row and note it) |
   | `editor.useTabs` | bool | `true` | vault | Ph. 1 |
   | `editor.tabSize` | int 2–8 | `4` | vault | Ph. 1 |
   | `editor.autoPairBrackets` | bool | `true` | vault | Ph. 1 |
   | `editor.autoPairMarkdown` | bool | `true` | vault | Ph. 1 |
   | `editor.smartLists` | bool | `true` | vault | Ph. 1 |
   | `editor.autoConvertHtml` | bool | `true` | vault | 07.17 |
   | `editor.rightToLeft` | bool | `false` | vault | 07.17 |
   | `editor.spellcheck` | bool | `true` | app | 07.16 |
   | `editor.spellcheckLanguages` | string list (BCP-47) | `[]` (= system language) | app | 07.16 |
   | `editor.vimMode` | bool | `false` | vault, desktopOnly | 07.15 |
   | `editor.codeBlockLineNumbers` | bool | `false` | vault | Ph. 6 (key from Phase 6: `codeBlockLineNumbers`) |

   **Files & links** (`SettingSection.filesAndLinks`)
   | Key | Type | Default | Scope | Implemented in |
   |---|---|---|---|---|
   | `files.confirmDelete` | bool | `true` | vault | Ph. 1 |
   | `files.trashMode` | enum `system`/`vaultTrash`/`permanent` | `vaultTrash` | vault | Ph. 1 |
   | `files.newNoteLocation` | enum `root`/`currentFolder`/`folder` | `root` | vault | Ph. 1 |
   | `files.newNoteFolder` | string | `''` | vault | Ph. 1 |
   | `files.attachmentFolder` | string (§6.7 values) | `'/'` | vault | Ph. 1 |
   | `files.excludedFolders` | string list | `[]` | vault | Ph. 1 |
   | `files.showHidden` | bool | `false` | vault | Ph. 1 |
   | `files.detectAllExtensions` | bool | `false` | vault | Ph. 1 (if absent: 07.2 — explorer shows files of unknown types when true) |
   | `links.autoUpdate` | bool | `true` | vault | Ph. 2 |
   | `links.newLinkFormat` | enum `shortest`/`relative`/`absolute` | `shortest` | vault | Ph. 2 |
   | `links.useWikilinks` | bool | `true` | vault | Ph. 2 |
   | `canvas.fetchLinkPreviews` | bool | `true` | vault | Ph. 6 |

   **Appearance** (`SettingSection.appearance`)
   | Key | Type | Default | Scope | Implemented in |
   |---|---|---|---|---|
   | `appearance.themeMode` | enum `system`/`light`/`dark` | `system` | app | Ph. 0 |
   | `appearance.lightThemeId` | string | `tephra-light` | app | 07.3 |
   | `appearance.darkThemeId` | string | `tephra-dark` | app | 07.3 |
   | `appearance.accentColor` | color or `''` (= theme's) | `''` | app | 07.5 |
   | `appearance.interfaceFont` | string (family) or `''` (= theme's) | `''` | app | 07.5 |
   | `appearance.textFont` | string or `''` | `''` | app | 07.5 |
   | `appearance.monospaceFont` | string or `''` | `''` | app | 07.5 |
   | `appearance.fontSize` | int 10–30 | `16` | app | 07.5 |
   | `appearance.interfaceZoom` | double 0.5–2.0 step 0.1 | `1.0` | app | 07.5 |
   | `appearance.showRibbon` | bool | `true` | app, desktopOnly | 07.2 |
   | `appearance.showInlineTitle` | bool | `true` | app | 07.2 (inline title above the note in editor and reading view) |
   | `appearance.reduceMotion` | bool | `false` | app | 07.19 |

   **Core plugins** (`SettingSection.corePlugins`) — toggles (bool, scope vault, default `true` unless noted):
   `corePlugins.backlinks`, `corePlugins.outgoingLinks`, `corePlugins.outline`, `corePlugins.tags`, `corePlugins.bookmarks`,
   `corePlugins.pagePreview`, `corePlugins.dailyNotes`, `corePlugins.templates`, `corePlugins.uniqueNoteCreator` (default `false`),
   `corePlugins.slashCommands`, `corePlugins.graph`, `corePlugins.canvas`, `corePlugins.bases`, `corePlugins.slides` (default `false`),
   `corePlugins.noteComposer`, `corePlugins.formatConverter` (default `false`), `corePlugins.wordCount`, `corePlugins.randomNote`
   (default `false`), `corePlugins.audioRecorder` (default `false`), `corePlugins.fileRecovery`, `corePlugins.footnotesView`
   (default `false`), `corePlugins.webViewer` (default `false`, desktopOnly).
   Plugin options (shown under each enabled plugin):
   | Key | Type | Default | Scope | Plugin |
   |---|---|---|---|---|
   | `dailyNotes.format` / `.folder` / `.template` / `.openOnStartup` | existing Ph. 2 keys | Ph. 2 | vault | dailyNotes |
   | `templates.folder` / `.dateFormat` / `.timeFormat` | existing Ph. 2 keys | Ph. 2 | vault | templates |
   | `uniqueNote.prefixFormat` / `.folder` / `.template` | existing Ph. 2 keys | Ph. 2 | vault | uniqueNoteCreator |
   | `templates.*` and `bases.*` keys added in Phase 6 (06.25–06.36: e.g. `templates.askOnNewNote`, `templates.folderDefaults`) | existing Ph. 6 keys — copy the exact list from the Phase 6 Hand-off | Ph. 6 | vault | templates / bases |
   | `pagePreviewReadingRequiresCtrl` / `pagePreviewEditorRequiresCtrl` | existing Ph. 2 keys (02.14) | Ph. 2 | app | pagePreview |
   | `noteComposer.textAfterExtraction` | enum `link`/`embed`/`none` | `link` | vault | noteComposer |
   | `noteComposer.templateFile` | string (vault path) | `''` | vault | noteComposer |
   | `noteComposer.confirmMerge` | bool | `true` | vault | noteComposer |
   | `noteComposer.mergeSeparator` | enum `none`/`blankLine`/`horizontalRule`/`heading` | `heading` | vault | noteComposer |
   | `wordCount.showInStatusBar` | bool | `true` | vault | wordCount |
   | `fileRecovery.snapshotIntervalMinutes` | int 1–60 | existing Ph. 3 value (default `5`) | vault | fileRecovery |
   | `fileRecovery.historyDays` | int 1–365 | existing Ph. 3 value (default `7`) | vault | fileRecovery |
   | `webViewer.openExternalLinks` | bool | `true` | app, desktopOnly | webViewer |
   | `webViewer.homePage` | string URL | `'about:blank'` | app, desktopOnly | webViewer |

   **Hotkeys** — no registry rows; the section hosts the Phase 1 hotkeys screen (`.tephra/hotkeys.json`) plus the read-only local
   sections (Canvas, PDF from Phase 6; Vim from 07.15).
   **Sync** — no new keys; the section hosts the Phase 3 sync and backup screens unchanged (their keys stay as Phase 3 defined them).
   **About** — no keys; shows app name, version (`package_info_plus` if already present, otherwise the version string compiled in from
   `pubspec.yaml` via a generated constant — do **not** add a package for this), device name and id, buttons: **Licences**
   (`showLicensePage`), **Open log folder** (Windows: `url_launcher` with `Uri.file`; Android: hidden), **Rebuild index** (existing
   command), **Open guide vault** (07.20).
   App-level keys not shown in screens but stored in `<appSupportDir>/settings.json`: `deviceId`, `deviceName`, `recentVaults`,
   `guideVaultCreated` (bool, 07.20), `windowBounds` (existing). Keep them out of the registry or mark them `hidden: true` (add a
   `hidden` flag if you need it).
4. `SettingsStore`: `T get<T>(SettingDefinition<T> d)` (falls back to the default when missing or of the wrong type; logs a warning for
   the wrong type), `Future<void> set<T>(SettingDefinition<T> d, T value)` (validates range/enum; writes the scope's JSON file atomically,
   debounced 300 ms, only if the serialised text changed; unknown keys in the files are preserved), `Stream<String> changes` (keys).
   Riverpod: `settingProvider = Provider.family<Object?, String>` plus typed helpers, so widgets rebuild only for their key.
5. Core-plugin toggles drive availability: every command of a plugin gets `isAvailable: (ref) => ref.watch(pluginEnabled('<id>'))`
   (combine with existing conditions), ribbon buttons and sidebar panels of a disabled plugin are hidden. Map: backlinks/outgoingLinks/
   outline/tags/bookmarks → their panels; pagePreview → hover/long-press previews; dailyNotes/templates/uniqueNoteCreator/slashCommands →
   their commands; graph/canvas/bases/slides → Phase 6 commands and views (files still open in a read-only "plugin disabled" view:
   `pluginDisabledFileView` with a button to enable); the rest → the 07.x features.

**Tests**
- `settings_registry_test.dart`: keys unique; every key matches `^[a-zA-Z]+(\.[a-zA-Z]+)+$` or an existing legacy key listed in an
  allowlist with a comment; every default satisfies its type constraints; every row's label exists in `app_en.arb` (load the ARB JSON
  in the test); every `pluginId` refers to a `corePlugins.*` key.
- `settings_store_test.dart`: missing file → defaults; wrong type → default + warning; set writes once after 3 rapid sets; unknown keys
  preserved; out-of-range int rejected with `ArgumentError`; vault vs app scope go to the right files (memory FS + temp dir).
- Widget test: disabling `corePlugins.graph` removes `graph.open-graph` from the palette results and hides the ribbon button.

**Verify**
```
cd app; flutter test test/settings; cd ..
```
Success: all pass; the differences between this table and existing keys are listed in `PROGRESS.md`.

**Pitfalls**
- Never rewrite `.tephra/settings.json` from a model that dropped unknown keys (sync from a newer version would lose data).
- Settings that are app-level must not go into the vault file (they would sync across devices with different screens).

---

### 07.2 Settings screens

**Purpose.** Obsidian-like settings UI generated from the registry, plus the few small behaviours the registry marks as "07.2".

**Files**
- `app/lib/settings/view/settings_screen.dart` (new or replace the Phase 1 screen, keeping its route name)
- `app/lib/settings/view/settings_section_view.dart`, `setting_tile.dart`, `core_plugins_view.dart`, `about_view.dart` (new)
- files implementing the "07.2" behaviours (inline title, ribbon toggle, strict line breaks, properties-in-document, detect all
  extensions, line numbers — only those not already present)
- `app/test/settings/view/settings_screen_test.dart` (new)

**Implementation**
1. Layout: desktop layout → a modal dialog 900×640 (max 90% of the window) with a left list of sections and the selected section on the
   right; phone layout → a full-screen page listing sections, each opening its own page. Command `app.open-settings` (Ctrl+,) and a
   ribbon/drawer gear button open it. Search field at the top filters settings by label and description across all sections
   (case-insensitive substring), showing matches grouped by section.
2. `SettingTile` per type: bool → `SwitchListTile`; enum → `DropdownButton` with l10n labels `settingValue<Key><Value>`; int/double →
   `Slider` with value label + a numeric text field (desktop); string → `TextField` (commit on Enter/blur); string list → chips + add
   field; color → swatch opening the colour picker (07.5); folder/file values (`newNoteFolder`, `attachmentFolder`, `templateFile`,
   `templates.folder`) → text field + a picker button opening the quick switcher in folder/file pick mode. Each tile shows the description
   below the label (muted) and a reset-to-default icon when the value differs from the default.
3. `desktopOnly` rows are hidden on phone layout; rows with `pluginId` appear under the plugin's entry in **Core plugins** (a list of
   switches; tapping the plugin name opens its options).
4. Implement each "07.2" behaviour from the 07.1 table that does not exist yet, each with a widget test:
   - `appearance.showInlineTitle`: an editable title line (the file stem) above the note in editor and reading view; editing it renames
     the file through the Phase 2 rename-with-link-update service on Enter/blur; invalid characters `\ / : * ? " < > |` and leading `.`
     are rejected with an inline error.
   - `appearance.showRibbon`: hides the left ribbon on desktop layout.
   - `editor.strictLineBreaks`: reading view renders `MdSoftBreak` as a space when true, as a line break when false.
   - `editor.propertiesInDocument`: `hidden` → the properties block is not shown; `source` → frontmatter is shown as raw YAML in the editor.
   - `files.detectAllExtensions`: explorer lists files of unsupported types too (opening them shows Phase 6's `UnsupportedFileView`).
   - `editor.lineNumbers`: only if the editor engine supports a gutter.
5. The Hotkeys section embeds the Phase 1 hotkeys screen; the Sync section embeds the Phase 3 sync/backup screens; About as in 07.1.

**Tests** (`settings_screen_test.dart`)
- Desktop width 1280: dialog with 7 section entries; selecting **Editor** shows the `editor.vimMode` switch; phone width 400: section
  list page, vim mode row absent (desktopOnly).
- Search "wiki" shows `links.useWikilinks`; toggling it writes the vault setting.
- Reset icon appears after changing `editor.tabSize` and restores 4.
- Disabling **Graph** in Core plugins hides its options and the graph ribbon button.
- Inline title rename: change title to `New name` → rename service called with `New name.md`; `a/b` → error shown, no rename.

**Verify**
```
cd app; flutter test test/settings; cd ..
```
Manual on both platforms: every section opens; values persist after restart. Success: all pass.

**Pitfalls**
- Do not block the UI while saving; `SettingsStore.set` is fire-and-forget with debounce, but errors surface as a snackbar from l10n.

---

### 07.3 Theme engine: tokens, JSON themes, bundled themes

**Purpose.** Replace hard-coded theme colours with named tokens loaded from JSON theme files, used by every widget and custom painter.

**Files**
- `app/lib/theme/theme_tokens.dart` (new: token enum + `ThemeExtension`)
- `app/lib/theme/theme_file.dart` (new: model + JSON codec + validation)
- `app/lib/theme/theme_repository.dart` (new: discovery/loading of bundled, app and vault themes)
- `app/lib/theme/app_theme.dart` (modify: build `ThemeData` from a `ThemeFile`)
- `app/assets/themes/tephra-light.json`, `tephra-dark.json`, `tephra-high-contrast-light.json`, `tephra-high-contrast-dark.json` (new)
- `app/lib/graph/view/graph_colors.dart`, `app/lib/canvas/view/canvas_colors.dart` (modify: read tokens)
- `app/test/theme/theme_file_test.dart`, `theme_repository_test.dart`, `contrast_test.dart` (new)

**Implementation**
1. **Theme JSON schema** (`schemaVersion: 1`):
   ```json
   {
     "schemaVersion": 1,
     "id": "tephra-dark",
     "name": "Tephra Dark",
     "mode": "dark",
     "author": "Tephra",
     "colors": { "<token>": "#RRGGBB" | "#RRGGBBAA", ... },
     "typography": { "interfaceFont": "", "textFont": "", "monospaceFont": "", "baseFontSize": 16, "lineHeight": 1.5,
                     "headingScale": [2.0, 1.6, 1.37, 1.25, 1.12, 1.0], "headingWeight": 700 },
     "spacing": { "unit": 4, "contentPadding": 24, "readableLineWidth": 700 },
     "radius": { "small": 4, "medium": 8, "large": 12 }
   }
   ```
   `id`: `^[a-z0-9-]+$`, unique; `mode`: `light` | `dark`. Missing colour tokens fall back to the bundled theme of the same mode
   (`tephra-light` / `tephra-dark`) — so a theme may define only some tokens. Missing typography/spacing/radius keys take the bundled
   values. Unknown keys are ignored (and preserved when the editor saves the file). Invalid colour strings → that token falls back and a
   validation warning is listed.
2. **Tokens** (exact list; JSON keys = names below; enum `ThemeToken` in the same order):
   | Group | Tokens |
   |---|---|
   | Backgrounds | `backgroundPrimary`, `backgroundPrimaryAlt`, `backgroundSecondary`, `backgroundSecondaryAlt`, `backgroundModifierHover`, `backgroundModifierActive`, `backgroundModifierBorder`, `backgroundModifierError`, `dividerColor` |
   | Text | `textNormal`, `textMuted`, `textFaint`, `textOnAccent`, `textAccent`, `textError`, `textSuccess`, `textWarning`, `textSelection`, `textHighlightBg` |
   | Interactive | `interactiveNormal`, `interactiveHover`, `interactiveAccent`, `interactiveAccentHover`, `focusRing` |
   | Markdown | `heading1Color`, `heading2Color`, `heading3Color`, `heading4Color`, `heading5Color`, `heading6Color`, `linkInternal`, `linkExternal`, `linkUnresolved`, `tagText`, `tagBackground`, `codeBackground`, `codeNormal`, `blockquoteBorder`, `hrColor`, `checkboxBorder`, `checkboxChecked` |
   | Graph | `graphNode`, `graphNodeUnresolved`, `graphNodeTag`, `graphNodeAttachment`, `graphNodeFocused`, `graphLine`, `graphText` |
   | Canvas | `canvasBackground`, `canvasGrid`, `canvasColor1`, `canvasColor2`, `canvasColor3`, `canvasColor4`, `canvasColor5`, `canvasColor6` |
   | Callouts | keep the Phase 1 callout colours (they are per type); not tokens in v1 |
3. `TephraColors extends ThemeExtension<TephraColors>` holds every token (`Color` fields, `copyWith`, `lerp`). `AppTheme.build(ThemeFile t,
   {Color? accentOverride, ...})` builds `ThemeData` with `ColorScheme` mapped from tokens: `primary = interactiveAccent`,
   `onPrimary = textOnAccent`, `surface = backgroundPrimary`, `onSurface = textNormal`, `onSurfaceVariant = textMuted`,
   `surfaceContainerLow = backgroundSecondary`, `outline = textFaint`, `outlineVariant = backgroundModifierBorder`, `error = textError`,
   `secondary = textAccent`, `tertiary = graphNodeAttachment`; `textSelectionTheme.selectionColor = textSelection`;
   `focusColor = focusRing`; plus `extensions: [TephraColors(...)]`. Access in widgets via `Theme.of(context).extension<TephraColors>()!`
   wrapped in a helper `context.tc`.
4. **Bundled themes** — use exactly these values (they pass the 07.18 contrast test; verify with the test):
   | Token | tephra-light | tephra-dark | high-contrast-light | high-contrast-dark |
   |---|---|---|---|---|
   | backgroundPrimary | #FFFFFF | #1C1B1A | #FFFFFF | #000000 |
   | backgroundPrimaryAlt | #FAF9F7 | #211F1E | #FFFFFF | #0A0A0A |
   | backgroundSecondary | #F4F2EF | #252321 | #F0F0F0 | #121212 |
   | backgroundSecondaryAlt | #ECE9E4 | #2C2A27 | #E6E6E6 | #1A1A1A |
   | backgroundModifierHover | #0000000F | #FFFFFF14 | #0000001F | #FFFFFF29 |
   | backgroundModifierActive | #0000001A | #FFFFFF1F | #0000002E | #FFFFFF3D |
   | backgroundModifierBorder | #E0DCD6 | #3A3734 | #000000 | #FFFFFF |
   | backgroundModifierError | #FDECEA | #4A1F1C | #FFE5E5 | #3D0000 |
   | dividerColor | #E0DCD6 | #3A3734 | #595959 | #A6A6A6 |
   | textNormal | #1F1D1B | #E8E4DF | #000000 | #FFFFFF |
   | textMuted | #5C5752 | #ADA69E | #333333 | #D6D6D6 |
   | textFaint | #8A847D | #7D766F | #595959 | #A6A6A6 |
   | textOnAccent | #FFFFFF | #1C1B1A | #FFFFFF | #000000 |
   | textAccent | #A63F14 | #F2946A | #0B3D91 | #8CC8FF |
   | textError | #B42318 | #FF8A80 | #A00000 | #FF9E9E |
   | textSuccess | #1B7A3A | #6FD08C | #0A5A1F | #8EF0A8 |
   | textWarning | #8A5A00 | #F0C05A | #6A4500 | #FFD866 |
   | textSelection | #B5461B33 | #E0703F4D | #0B3D9140 | #8CC8FF4D |
   | textHighlightBg | #FFE58A | #6B5A1A | #FFF200 | #5C5200 |
   | interactiveNormal | #F4F2EF | #2C2A27 | #F0F0F0 | #1A1A1A |
   | interactiveHover | #ECE9E4 | #34312E | #E0E0E0 | #262626 |
   | interactiveAccent | #B5461B | #E0703F | #0B3D91 | #8CC8FF |
   | interactiveAccentHover | #9A3A15 | #EA8657 | #082C69 | #B3DBFF |
   | focusRing | #B5461B | #F2946A | #0B3D91 | #8CC8FF |
   | heading1Color … heading6Color | #1F1D1B | #E8E4DF | #000000 | #FFFFFF |
   | linkInternal | #A63F14 | #F2946A | #0B3D91 | #8CC8FF |
   | linkExternal | #A63F14 | #F2946A | #0B3D91 | #8CC8FF |
   | linkUnresolved | #A5532F | #C98A6D | #5A3D91 | #C9B3FF |
   | tagText | #9A3A12 | #F2946A | #0B3D91 | #8CC8FF |
   | tagBackground | #F9E7DF | #3D2B22 | #E3EBF8 | #0F2A44 |
   | codeBackground | #F1EEEA | #2B2927 | #F0F0F0 | #141414 |
   | codeNormal | #2B2826 | #E8E4DF | #000000 | #FFFFFF |
   | blockquoteBorder | #B5461B | #E0703F | #0B3D91 | #8CC8FF |
   | hrColor | #E0DCD6 | #3A3734 | #595959 | #A6A6A6 |
   | checkboxBorder | #8A847D | #7D766F | #333333 | #D6D6D6 |
   | checkboxChecked | #B5461B | #E0703F | #0B3D91 | #8CC8FF |
   | graphNode | #8A847D | #ADA69E | #333333 | #D6D6D6 |
   | graphNodeUnresolved | #C9C4BE | #5A5550 | #8C8C8C | #6E6E6E |
   | graphNodeTag | #1B7A3A | #6FD08C | #0A5A1F | #8EF0A8 |
   | graphNodeAttachment | #8A5A00 | #F0C05A | #6A4500 | #FFD866 |
   | graphNodeFocused | #B5461B | #E0703F | #0B3D91 | #8CC8FF |
   | graphLine | #D6D1CA | #45413D | #8C8C8C | #6E6E6E |
   | graphText | #1F1D1B | #E8E4DF | #000000 | #FFFFFF |
   | canvasBackground | #FAF9F7 | #1C1B1A | #FFFFFF | #000000 |
   | canvasGrid | #D6D1CA | #3A3734 | #BFBFBF | #404040 |
   | canvasColor1 … canvasColor6 | #E5534B #E8912D #D9B30F #3FB950 #2DA8B8 #8E6CEF (all four themes) |
   Typography for all bundled themes: fonts `''` (system defaults: Segoe UI on Windows, Roboto on Android; monospace: Cascadia Mono /
   Consolas on Windows, `monospace` on Android — leave `''` and let `AppTheme` pick per platform), sizes as in the schema example.
5. `ThemeRepository` discovers themes in this order (later wins on duplicate `id`): bundled assets → `<appSupportDir>/themes/*.json` →
   `<vault>/.tephra/themes/*.json`. Invalid JSON files are listed with their error in the Appearance screen and skipped. The active theme
   for each mode comes from `appearance.lightThemeId` / `appearance.darkThemeId`; missing id → bundled theme of that mode.
6. Replace hard-coded colours across `app/lib` with tokens: run `grep -rn "Color(0x\|Colors\." app/lib` and convert each UI colour to a
   token (exceptions: fully transparent, pure black/white shadows, and colours inside generated code). `GraphColors` and `CanvasColors`
   (Phase 6) read the graph/canvas tokens now.
7. Theme changes apply live (no restart) through a Riverpod provider of the built `ThemeData` pair.

**Tests**
- `theme_file_test.dart`: parse each bundled theme; partial theme (only `textNormal`) falls back for other tokens; invalid colour → warning
  and fallback; unknown keys preserved by `toJson`; invalid `id` rejected.
- `theme_repository_test.dart`: vault theme overrides app theme with the same id; broken file listed as error, not thrown.
- `contrast_test.dart` (written now, also used by 07.18): see 07.18 item 4 for the pairs; all four bundled themes pass.
- Golden tests `goldens/theme_<id>_reading.png` of the syntax note in reading view for each bundled theme (`@Tags(['golden'])`).
- Source check test: no `Color(0x` literals in `app/lib` outside `app/lib/theme/` (allowlist file for justified exceptions with comments).

**Verify**
```
cd app; flutter test test/theme; cd ..
cd app; flutter test --tags golden test/theme; cd ..
```
Success: all pass; switching theme in Settings recolours the whole app live on both platforms.

**Pitfalls**
- `#RRGGBBAA` is CSS order (alpha last); Flutter `Color(0xAARRGGBB)` is alpha first — convert carefully and test it.

---

### 07.4 Theme editor and Obsidian theme import

**Purpose.** Let users create/edit themes with a live preview and import colours from an Obsidian `theme.css`.

**Files**
- `app/lib/theme/editor/theme_editor_screen.dart`, `theme_preview.dart`, `color_picker_dialog.dart` (new)
- `app/lib/theme/import/obsidian_css_importer.dart` (new; pure Dart)
- `app/lib/theme/import/css_color.dart` (new; pure Dart: parse hex/rgb/rgba/hsl/hsla/named)
- `app/test/theme/import/obsidian_css_importer_test.dart`, `css_color_test.dart`, `app/test/theme/editor/theme_editor_screen_test.dart` (new)
- `test_vaults/themes/sample-theme.css` (new fixture, written by you; do **not** copy a real community theme's CSS)

**Implementation**
1. **Theme editor** (Settings → Appearance → Themes → "New theme" / "Edit" / "Duplicate" / "Delete" / "Import Obsidian theme…"):
   desktop layout → two panes (left: token list grouped as in 07.3 with swatch + hex field; right: `ThemePreview`); phone → token list with a
   preview toggle button. Fields for name, mode, fonts, base font size, line height, radius values. Changes update the preview instantly
   (in-memory `ThemeFile`), and the whole app only after **Save**. Save location choice: "This device" (`<appSupportDir>/themes/`) or
   "This vault" (`.tephra/themes/`, syncs). File name `<id>.json`, 2-space indented JSON with trailing newline. Editing a bundled theme
   forces "Duplicate" first (bundled themes are read-only).
2. `ThemePreview`: a fixed sample made of real widgets themed with the edited `ThemeData` (via a nested `Theme`): a mini explorer (3 items,
   one selected), a reading-view snippet (H1, H2, paragraph with a link, an unresolved link, a tag, highlighted text, inline code), a code
   block, a callout, a checkbox list, a button, a text field, a tiny graph (5 nodes painted with the graph tokens) and a canvas card with
   colour 1. Each token row shows its WCAG contrast against its background pair (07.18 pairs) with a warning icon below 4.5:1.
3. `ColorPickerDialog`: 18 preset swatches, hex field (`#RRGGBB` or `#RRGGBBAA`), HSL sliders (hue 0–360, saturation 0–100, lightness
   0–100) and an alpha slider; returns a `Color`.
4. **Obsidian CSS import** (`ObsidianCssImporter.import(String css) → ImportResult { ThemeFile? light; ThemeFile? dark; List<String> unmapped; List<String> warnings; }`):
   - Tokenise CSS just enough: strip `/* … */` comments; find rule blocks `selector { declarations }` at any nesting depth of `@media`
     (ignore the media condition); split declarations on `;` outside parentheses; keep only custom properties `--name: value`.
   - Scopes: declarations in rules whose selector list contains `.theme-light` → light scope; `.theme-dark` → dark scope; `body`,
     `:root`, `.theme-light, .theme-dark` (both) → base scope (applies to both). Later declarations override earlier ones (source order).
     Selectors with anything else (e.g. `.markdown-preview-view h1`) are ignored.
   - Resolve values per mode: lookup order mode scope → base scope. `var(--x)` and `var(--x, fallback)` resolved recursively up to depth
     10 (cycle → unresolved). `calc()` supported only as `calc(<number|percent> (+|-|*|/) <number|percent>)` after var substitution
     (enough for `hsl(var(--accent-h), var(--accent-s), calc(var(--accent-l) - 5%))`).
   - Parse colours (`css_color.dart`): `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()/rgba()` (comma or space syntax, `/ alpha`),
     `hsl()/hsla()` (deg, turn, unitless hue; percent s/l), the 148 CSS named colours, `transparent`. Anything else → unmapped.
   - Mapping table (Obsidian variable → our token). First listed variable that resolves wins when several map to one token:
     | Obsidian CSS variable(s) | Token |
     |---|---|
     | `--background-primary` | backgroundPrimary |
     | `--background-primary-alt` | backgroundPrimaryAlt |
     | `--background-secondary` | backgroundSecondary |
     | `--background-secondary-alt` | backgroundSecondaryAlt |
     | `--background-modifier-hover` | backgroundModifierHover |
     | `--background-modifier-active-hover` | backgroundModifierActive |
     | `--background-modifier-border` | backgroundModifierBorder |
     | `--background-modifier-error` | backgroundModifierError |
     | `--divider-color` | dividerColor |
     | `--text-normal` | textNormal |
     | `--text-muted` | textMuted |
     | `--text-faint` | textFaint |
     | `--text-on-accent` | textOnAccent |
     | `--text-accent` | textAccent |
     | `--text-error` | textError |
     | `--text-success` | textSuccess |
     | `--text-warning` | textWarning |
     | `--text-selection` | textSelection |
     | `--text-highlight-bg` | textHighlightBg |
     | `--interactive-normal` | interactiveNormal |
     | `--interactive-hover` | interactiveHover |
     | `--interactive-accent`, then `--color-accent` | interactiveAccent |
     | `--interactive-accent-hover`, then `--color-accent-1` | interactiveAccentHover |
     | `--h1-color` … `--h6-color` | heading1Color … heading6Color |
     | `--link-color` | linkInternal |
     | `--link-external-color` | linkExternal |
     | `--link-unresolved-color` | linkUnresolved |
     | `--tag-color` | tagText |
     | `--tag-background` | tagBackground |
     | `--code-background` | codeBackground |
     | `--code-normal` | codeNormal |
     | `--blockquote-border-color` | blockquoteBorder |
     | `--hr-color` | hrColor |
     | `--checkbox-border-color` | checkboxBorder |
     | `--checkbox-color` | checkboxChecked |
     | `--graph-node` | graphNode |
     | `--graph-node-unresolved` | graphNodeUnresolved |
     | `--graph-node-tag` | graphNodeTag |
     | `--graph-node-attachment` | graphNodeAttachment |
     | `--graph-node-focused` | graphNodeFocused |
     | `--graph-line` | graphLine |
     | `--graph-text` | graphText |
     | `--canvas-background` | canvasBackground |
     | `--canvas-dot-pattern` | canvasGrid |
     | `--color-red`, `--color-orange`, `--color-yellow`, `--color-green`, `--color-cyan`, `--color-purple` | canvasColor1 … canvasColor6 |
     | `--font-interface-theme`, then `--font-interface` | typography.interfaceFont (first family name only, quotes removed) |
     | `--font-text-theme`, then `--font-text` | typography.textFont |
     | `--font-monospace-theme`, then `--font-monospace` | typography.monospaceFont |
     Everything else is ignored and listed in `unmapped` (count shown to the user, list in a collapsible section).
   - Fallback derivations when a token is still missing after mapping: `focusRing` = interactiveAccent; `linkInternal`/`linkExternal` =
     textAccent; `checkboxChecked` = interactiveAccent; remaining tokens from the bundled theme of that mode.
   - Output: one `ThemeFile` per mode that had at least 3 mapped tokens. Name = file name without extension (user can edit); id =
     slug of the name (`[a-z0-9-]`), suffixed `-light`/`-dark`.
   - UI: pick a `.css` file (file_picker) → preview of the imported light/dark themes in `ThemePreview` → **Save** (choose location as in
     item 1). Fonts named in the CSS are used only if installed or registered (07.5); otherwise ignored with a warning.

**Tests**
- `css_color_test.dart`: `#abc`, `#abcd`, `#aabbcc`, `#aabbccdd`, `rgb(1, 2, 3)`, `rgb(1 2 3 / 50%)`, `rgba(1,2,3,.5)`,
  `hsl(210, 50%, 40%)`, `hsl(0.5turn 50% 40%)`, `hsla(…, 0.2)`, `rebeccapurple`, `transparent`, invalid → null.
- `obsidian_css_importer_test.dart` on `sample-theme.css` (contains: `body` base vars, `.theme-dark` and `.theme-light` overrides, an
  `@media` block, `var()` chains with fallback, an `hsl(var(...), calc(...))` accent, a cycle `--a: var(--b); --b: var(--a)`, a
  non-colour var, a component rule `.nav-file-title { --x: red }`): expected light/dark tokens; cycle unresolved; component rule ignored;
  `unmapped` contains the non-colour var; fallback `focusRing` equals accent.
- `theme_editor_screen_test.dart`: editing `textNormal` updates the preview text colour immediately; Save writes `<id>.json` once; editing
  a bundled theme requires duplicate; contrast warning icon appears for `#999999` on white.

**Verify**
```
cd app; flutter test test/theme; cd ..
```
Manual: import a real Obsidian theme's `theme.css` from a vault you have (do not commit it) and check the result looks close. Success:
tests pass; manual result noted.

**Pitfalls**
- Obsidian themes define many variables in terms of `--accent-h/s/l`; evaluate `var()` before parsing `hsl()`.
- Never execute or keep any CSS other than the mapped values; the import is data-only.

---

### 07.5 Custom fonts, accent colour, interface zoom

**Purpose.** Personalise typography, accent and UI scale.

**Files**
- `app/lib/theme/fonts/font_registry.dart` (new)
- `app/lib/theme/zoom/interface_zoom.dart` (new)
- `app/lib/app.dart` (modify: apply zoom + fonts + accent)
- Appearance section rows (07.2) for the related settings
- `app/test/theme/fonts/font_registry_test.dart`, `app/test/theme/zoom/interface_zoom_test.dart` (new)

**Implementation**
1. **Custom fonts:** Appearance → Fonts → **Add font file…** (file_picker, extensions `ttf`, `otf`) → copy to
   `<appSupportDir>/fonts/<original file name>` (overwrite asks for confirmation) → register:
   ```dart
   final loader = FontLoader(familyName)..addFont(File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
   await loader.load();
   ```
   `familyName` = file stem with `-Regular/-Bold/-Italic/-BoldItalic` suffix removed (so `Inter-Regular.ttf` and `Inter-Bold.ttf` both
   register into family `Inter`; Flutter picks weights from the font files' metadata). All files in the folder are registered at startup
   before `runApp` completes its first frame (await in bootstrap, with a 2 s cap; fonts that load later trigger a rebuild).
   Font dropdowns (`appearance.interfaceFont`, `.textFont`, `.monospaceFont`) list: "Theme default" (`''`), registered custom families,
   and on Windows the common installed families `Segoe UI`, `Calibri`, `Cambria`, `Georgia`, `Times New Roman`, `Arial`, `Verdana`,
   `Consolas`, `Cascadia Mono`, `Cascadia Code`, `Courier New`; on Android `Roboto`, `Noto Serif`, `monospace`. A font name typed by the
   user is also accepted (free text option "Other…"). **Remove font** deletes the file (registered families stay until restart; show
   `fontRemovedRestart`).
   Bangla: if the chosen text font lacks Bangla glyphs, Flutter falls back to system fonts automatically; no action needed.
2. **Accent colour:** `appearance.accentColor` non-empty overrides `interactiveAccent`, `interactiveAccentHover` (accent darkened 10% in
   light mode / lightened 10% in dark mode, HSL lightness), `focusRing`, `textAccent`, `linkInternal`, `linkExternal`, `checkboxChecked`,
   `blockquoteBorder`, `graphNodeFocused`, `textSelection` (accent at 20% alpha), and sets `textOnAccent` to white (`#FFFFFF`) or black
   (`#000000`) — whichever has the higher contrast (black, not the near-black theme colour, because the worse of the two is then always
   ≥ 4.58:1 for any accent colour, which a near-black cannot guarantee). If `textAccent` on `backgroundPrimary` falls below 4.5:1, adjust its lightness in
   1% steps toward the text colour until it passes (so links stay readable). Picker: the 07.4 colour picker plus "Use theme accent" (clears).
3. **Interface zoom** (`appearance.interfaceZoom`, 0.5–2.0): in `MaterialApp.builder`, wrap the child:
   ```dart
   final mq = MediaQuery.of(context);
   final z = zoom; // setting
   MediaQuery(
     data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1.0) * z)),   // keeps the OS text scale and multiplies
     child: Theme(
       data: theme.copyWith(
         visualDensity: z < 0.9 ? VisualDensity.compact : (z > 1.1 ? VisualDensity.comfortable : VisualDensity.standard),
         iconTheme: theme.iconTheme.copyWith(size: 24 * z),
         // also scale: appBarTheme toolbarHeight 56*z, listTileTheme minVerticalPadding, tab bar height (custom widgets read context.zoom)
       ),
       child: child),
   )
   ```
   Expose `context.zoom` (an `InheritedWidget`) so custom widgets (tab bar, ribbon, status bar, graph labels, canvas toolbar) scale their
   fixed sizes. Commands (Obsidian defaults): `app.zoom-in` (Ctrl+=), `app.zoom-out` (Ctrl+-), `app.zoom-reset` (Ctrl+0), step 0.1,
   clamped. In canvas/graph/PDF/image views, Ctrl+= / Ctrl+- / Ctrl+0 are bound locally to view zoom (Phase 6), which wins while those
   views have focus.
   Also `appearance.fontSize` sets the reading/editor base font size (independent of zoom).

**Tests**
- `font_registry_test.dart`: family name derivation (`Inter-Regular.ttf` → `Inter`, `My Font.otf` → `My Font`, `X-BoldItalic.ttf` → `X`);
  copying into the fonts dir; removing deletes the file.
- Accent: picking `#00FF00` (low contrast on white) produces a `textAccent` with contrast ≥ 4.5 on `backgroundPrimary`; `textOnAccent` is
  `#000000` on a light accent; for every accent in a sweep of 360 hues × (saturation 100%, lightness 30/50/70%) the contrast of
  `textOnAccent` on the accent is ≥ 4.5.
- `interface_zoom_test.dart`: zoom 1.5 → a `Text` with fontSize 14 reports `textScaler.scale(14) == 21` (with OS scale 1.0); OS scale 1.3
  × zoom 1.5 → 1.95; `app.zoom-in` from 2.0 stays 2.0.

**Verify**
```
cd app; flutter test test/theme; cd ..
```
Manual on both platforms: add a font, use it for text; zoom 0.7 and 1.5 look right. Success: all pass.

**Pitfalls**
- `FontLoader` must not be called twice for the same family in one session with different files in a way that drops earlier files; collect
  all files of a family and load them in one loader.

### 07.6 Note composer: merge and extract

**Purpose.** Obsidian's note composer: merge the current note into another, extract a selection or a heading section into a new note.

**Files**
- `app/lib/plugins/note_composer/note_composer_service.dart` (new)
- `app/lib/plugins/note_composer/commands.dart` (new)
- `app/lib/plugins/note_composer/merge_dialog.dart` (new)
- `app/test/plugins/note_composer/note_composer_service_test.dart` (new)

(`app/lib/plugins/` is a new feature folder for Phase 7 core plugins, under `app/lib/` as §2 allows feature folders; record it as a
layout addition.)

**Implementation**
1. **Merge** — command `note-composer.merge-file` ("Merge current file with another file…"), available for a Markdown note:
   1. Pick the target with the quick switcher in pick mode (excluding the current note).
   2. If `noteComposer.confirmMerge`: dialog showing source → target, the separator choice (`noteComposer.mergeSeparator`, changeable
      here for this run), and the option "Prepend instead of append" (default off). Buttons Merge / Cancel.
   3. Build the appended text from the **source body** (frontmatter removed). Separator: `none` → `\n`; `blankLine` → `\n\n`;
      `horizontalRule` → `\n\n---\n\n`; `heading` → `\n\n## <source stem>\n\n` (heading level 2; if the source body already starts with a
      heading, use `blankLine` instead). Ensure exactly one `\n` at the end of the target before appending.
   4. Merge frontmatter: for keys only in the source, add them to the target via the Phase 2 frontmatter service (`yaml_edit`); for `tags`
      and `aliases`, union the lists (keep target order, append new ones); for other keys present in both, keep the target's value.
      Do not add the source's name to the target's `aliases` (Obsidian does not either).
   5. Write the target (atomic, through the open editor's document if open so undo works there).
   6. Update links: every link to the source (wikilinks, Markdown links, embeds; including `#heading`/`^block` subpaths) is rewritten to
      the target, using the Phase 2 link maintenance code path used by rename (call its "retarget links from A to B" function; if only a
      rename function exists, add `retargetLinks(VaultPath from, VaultPath to)` beside it, sharing the rewriting code). Links inside the
      merged text that pointed to the target itself become self-links — leave them.
   7. Delete the source using the vault's trash mode (`files.trashMode`; never permanent without the setting).
   8. Open the target and scroll to the merged part; toast `noteComposerMerged` with **Undo** (restores source file from trash, restores
      the target's previous text and reverts the link rewrites — use the Phase 2 rename's undo mechanism for the links).
2. **Extract selection** — command `note-composer.extract-selection` ("Extract current selection…", editor context menu and mobile
   toolbar overflow): requires a non-empty selection.
   1. Ask for the new note name in a dialog prefilled with the first line of the selection stripped of Markdown markers (max 60
      characters, invalid file-name characters removed); location = `files.newNoteLocation`.
   2. New note content: if `noteComposer.templateFile` is set and exists → apply the Phase 2 template engine with extra variables
      `{{content}}` (the selection), `{{fromTitle}}` (source stem), `{{newTitle}}`; otherwise just the selected text plus `\n`.
   3. Replace the selection in the source by `noteComposer.textAfterExtraction`: `link` → `[[New name]]` (respecting `links.useWikilinks`
      and `links.newLinkFormat`), `embed` → `![[New name]]`, `none` → nothing. One undo step in the source editor.
   4. Create the note (atomic); if the name exists, append ` 1`, ` 2`, … Open it in a new tab only if the command was invoked with
      Shift held or from the "and open" variant `note-composer.extract-selection-open`.
3. **Extract heading** — command `note-composer.extract-heading` ("Extract this heading…"): cursor in a heading section; section =
   from the heading line to before the next heading of the same or higher level. New note name = heading text; the new note body is the
   section **without** the heading line; the source replaces the whole section with: the heading line kept + the link/embed on the next line
   (`link` mode) — decided so the outline of the source stays intact. Same template rules.
4. All write operations go through the vault FS and are recorded in `.tephra/history` by the Phase 3 snapshot service before change.

**Tests** (`note_composer_service_test.dart`, memory FS + index fake/real)
- `merge appends with heading separator`; `merge with blankLine`; `merge prepends`; `merge unions tags and keeps target values`;
  `merge retargets links` (note C linking `[[A#H]]` → `[[B#H]]`, `![[A]]` → `![[B]]`, Markdown link `[x](A.md)` → `[x](B.md)`);
  `merge deletes source to vault trash`; `undo restores everything` (bytes equal originals).
- `extract selection with link`; `with embed`; `with none`; `with template variables`; `name collision adds suffix`;
  `invalid characters removed from suggested name`.
- `extract heading` keeps the heading line and inserts the link below it; nested lower-level headings move with the section.

**Verify**
```
cd app; flutter test test/plugins/note_composer; cd ..
```
Success: all pass; manual run on both platforms.

**Pitfalls**
- Do not merge a note into itself; disable the current note in the picker.
- Link retargeting must not touch code blocks or inline code (reuse the AST-offset based rewriting from Phase 2).

---

### 07.7 Format converter

**Purpose.** Convert common foreign Markdown dialects to Obsidian syntax, for the current note or the whole vault, with a preview.

**Files**
- `packages/tephra_io/lib/src/convert/format_converter.dart` (new; pure Dart, exported)
- `app/lib/plugins/format_converter/format_converter_dialog.dart`, `commands.dart` (new)
- `packages/tephra_io/test/convert/format_converter_test.dart` (new)

**Implementation**
1. Conversions (each an independent, selectable rule; ids in parentheses):
   | Rule id | From | To | Default |
   |---|---|---|---|
   | `markdownLinksToWikilinks` | `[text](Note.md)`, `[text](Folder/Note%20Name.md#Heading)` (internal, resolvable to a vault note; URL-decoded) | `[[Note\|text]]` / `[[Folder/Note Name#Heading\|text]]`; when text equals the target stem → `[[Note]]`; image `![alt](img.png)` (internal) → `![[img.png]]` | on |
   | `wikilinksToMarkdownLinks` | `[[Note\|text]]`, `[[Note#H]]`, `![[img.png]]` | `[text](Note.md)`, `[Note](Note.md#H)` (spaces → `%20`), `![](img.png)`; mutually exclusive with the rule above | off |
   | `roamHighlights` | `^^text^^` | `==text==` | on |
   | `bearHighlights` | `::text::` (not at line start, so it is not a Dataview field) | `==text==` | on |
   | `bearMultiwordTags` | `#multi word tag#` | `#multi-word-tag` | on |
   | `roamTagLinks` | `#[[Tag Name]]` | `#Tag-Name` | on |
   | `roamTodo` | `{{[[TODO]]}} text`, `{{TODO}} text` | `- [ ] text` (keeps existing list marker if present) | on |
   | `roamDone` | `{{[[DONE]]}} text`, `{{DONE}} text` | `- [x] text` | on |
   | `strayHtmlBreaks` | `<br>`, `<br/>`, `<br />` outside tables | a hard line break (`\` + newline) | off |
   Matches inside fenced code, inline code, math and comments are never changed: use `MarkdownParser.parse` and only apply rules to
   text ranges covered by `MdText` nodes (and link node ranges for the link rules).
2. API:
   ```dart
   final class FormatConversionResult { final String text; final Map<String, int> countsByRule; }
   abstract final class FormatConverter {
     static FormatConversionResult convert(String text, Set<String> ruleIds, {required LinkTargetResolver resolve});
   }
   typedef LinkTargetResolver = VaultPath? Function(String target);   // app passes NoteIndex-based resolution (sync lookup map)
   ```
3. Commands: `format-converter.convert-current` and `format-converter.convert-vault`. Dialog: rule checkboxes (defaults above), then
   **Preview** → counts per rule (and for the vault: number of files affected; list of the first 50 file paths), then **Convert**. Vault
   conversion runs in an isolate over Markdown files in batches of 50, writes only changed files (atomic), snapshots each file to
   `.tephra/history` first, shows progress and a final report. No undo beyond history (state this in the dialog).

**Tests** (`format_converter_test.dart`): one test per rule (positive case), plus: rule inside a code block unchanged; inline code
unchanged; `::text::` at line start unchanged; external `[x](https://a.b)` unchanged; unresolvable `[x](Missing.md)` unchanged;
URL-decoding `%20`; wikilinks→Markdown with heading; counts per rule correct; converting twice is idempotent.

**Verify**
```
cd packages/tephra_io; dart test test/convert; cd ../..
cd app; flutter test test/plugins/format_converter; cd ..
```
Success: all pass.

**Pitfalls**
- Never apply both link-direction rules together (the dialog makes them radio-exclusive).

---

### 07.8 Word and character count

**Purpose.** Counts in the status bar (desktop) and note info (phone), for the whole note and for the selection.

**Files**
- `packages/tephra_markdown/lib/src/word_count.dart` (new, exported)
- `app/lib/plugins/word_count/word_count_status.dart`, `providers.dart` (new)
- `packages/tephra_markdown/test/word_count_test.dart` (new)

**Implementation**
1. Counting rules (decided, applied to the text after stripping):
   - Stripping (using the AST and offsets): remove frontmatter; remove `%%comments%%`; remove HTML tags (keep inner text); for links keep
     only the visible text (wikilink alias, else target name without path/subpath; Markdown link text; embeds contribute nothing);
     remove Markdown syntax markers (heading `#`s, emphasis/strong/strike/highlight markers, list markers, task boxes, blockquote `>`,
     table pipes, fence lines and info strings, block ids `^id`, footnote markers); keep code contents and math source.
   - **Words:** count CJK characters individually — every character in the ranges Han (U+4E00–9FFF, U+3400–4DBF, U+20000–2A6DF,
     U+F900–FAFF), Hiragana (U+3040–309F), Katakana (U+30A0–30FF, U+31F0–31FF), Hangul syllables (U+AC00–D7AF) counts as 1 word; all
     other text: count maximal runs matching `[\p{L}\p{N}\p{M}]+(?:['’_-][\p{L}\p{N}\p{M}]+)*` (Unicode regex, `unicode: true`), so
     `don't`, `e-mail`, Bangla words with combining marks count as 1 each.
   - **Characters:** number of grapheme clusters (`package:characters` `.characters.length`) of the stripped text **excluding** line
     breaks; spaces count.
2. API: `WordCount countWords(String text)` and `WordCount countWordsInRange(ParsedNote note, int start, int end)` (counts only the part of
   the stripped text that comes from `[start, end)`), `WordCount { final int words; final int characters; }`.
3. Status bar (desktop): `"1,234 words  6,789 characters"` (l10n plural + `NumberFormat.decimalPattern`); with a non-empty selection:
   `"12 of 1,234 words  60 of 6,789 characters"`. Recompute debounced 300 ms after edits; for notes > 50,000 characters compute in
   `Isolate.run`. Phone: the note's "more" menu shows **Note info** with the same counts. Hidden when `corePlugins.wordCount` or
   `wordCount.showInStatusBar` is off.

**Tests** (`word_count_test.dart`): `Hello world` → 2/11; `**bold** text` → 2 words, 9 characters; `[[Note|alias]] here` → `alias here`;
`![[img.png]]` → 0; frontmatter excluded; `%%x%%` excluded; `don't e-mail` → 2; `日本語です` → 5 words; mixed `Tephra 日本` → 3;
Bangla `আমি বাংলায় লিখি` → 3 words; emoji `👍🏽` → 1 character; code block contents counted; selection count of a range inside bold text.

**Verify**
```
cd packages/tephra_markdown; dart test test/word_count_test.dart; cd ../..
cd app; flutter test test/plugins/word_count; cd ..
```
Success: all pass.

**Pitfalls**
- Do not run the regex over 5,000-line notes on every keystroke; debounce and reuse the parse the editor already has.

---

### 07.9 Random note and audio recorder

**Purpose.** Two small core plugins.

**Files**
- `app/lib/plugins/random_note/commands.dart` (new)
- `app/lib/plugins/audio_recorder/audio_recorder_service.dart`, `recorder_sheet.dart`, `commands.dart` (new)
- `app/android/app/src/main/AndroidManifest.xml` (add `android.permission.RECORD_AUDIO`)
- `app/test/plugins/random_note/random_note_test.dart`, `app/test/plugins/audio_recorder/audio_recorder_service_test.dart` (new)

**Implementation**
1. **Random note:** command `random-note.open-random-note` ("Open random note"), ribbon button (icon `Icons.casino_outlined`) and drawer
   entry. Picks uniformly from all Markdown notes (index `allNotes()`), excluding the active note when more than one exists, using an
   injected `Random` (provider). Opens in the active tab (Ctrl+click on the ribbon → new tab). Empty vault → toast `randomNoteEmpty`.
2. **Audio recorder** (`record` package, `AudioRecorder`):
   - Command `audio-recorder.start-stop` ("Start/stop recording"), ribbon button (mic icon; red while recording), mobile toolbar entry.
   - Start: `hasPermission()` → if false, toast `audioPermissionDenied` (Windows: hint to enable microphone access in Windows Settings →
     Privacy → Microphone). Record with `RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100, numChannels: 1)` to a
     temp path in `getTemporaryDirectory()`. Check `isEncoderSupported(AudioEncoder.aacLc)` first; if false (some Windows editions without
     the AAC encoder), use `AudioEncoder.wav` and the `.wav` extension.
   - While recording: a compact sheet/bar shows elapsed time `mm:ss`, an amplitude meter (`onAmplitudeChanged`, 100 ms), **Stop**, **Cancel**.
   - Stop: file name `Recording YYYYMMDDHHmmss.m4a` (or `.wav`) using the local time at **start**; saved via the attachment rules (§6.7:
     `files.attachmentFolder` relative to the active note, or vault root if no note is open) by reading the temp file bytes and
     `writeBytes` (atomic), then deleting the temp file. If a Markdown note is active and editable, insert `![[Recording ….m4a]]` at the
     cursor (or append at the end if the note is in reading mode); otherwise open the recording in the media player tab.
   - Cancel: `cancel()` deletes the temp file; nothing saved.
   - App paused (Android) while recording: keep recording only while the app is in the foreground; on `paused`, stop and save
     automatically (Android background recording would need a foreground service — out of scope; note in Ideas).

**Tests**
- `random_note_test.dart`: with `Random(1)` and 5 notes the pick sequence is deterministic; active note excluded; one note in vault →
  that note even if active; empty → toast.
- `audio_recorder_service_test.dart` (fake recorder interface wrapping `AudioRecorder`): file name from start time (fake clock); aacLc
  unsupported → `.wav`; stop inserts the embed at the cursor of the active editor (fake editor) and saves under the attachment folder;
  cancel deletes temp and saves nothing; permission denied → no recording started.
- Manual: record 5 s on the phone and on Windows; the embed plays (Phase 6 player) on both platforms (the Android `.m4a` plays on Windows
  and vice versa — record result).

**Verify**
```
cd app; flutter test test/plugins/random_note test/plugins/audio_recorder; cd ..
dart run tool/check_licenses.dart
```
Success: all pass; manual cross-platform playback recorded.

**Pitfalls**
- The `record` package's Windows implementation writes the file only on `stop()`; never read the temp file before `stop()` returns.

---

### 07.10 File recovery and footnotes view

**Purpose.** Browse local snapshots of any file (including deleted ones) and list a note's footnotes in a sidebar.

**Files**
- `app/lib/plugins/file_recovery/file_recovery_screen.dart`, `commands.dart` (new)
- `app/lib/plugins/footnotes/footnotes_panel.dart` (new)
- `app/test/plugins/file_recovery/file_recovery_screen_test.dart`, `app/test/plugins/footnotes/footnotes_panel_test.dart` (new)

**Implementation**
1. **File recovery** (reuses the Phase 3 snapshot service; no new storage): command `file-recovery.open` ("Open local history browser"),
   Settings → Core plugins → File recovery → **View snapshots**. Screen: left — search field + list of every path that has snapshots
   (including paths that no longer exist, marked "deleted"), sorted by most recent snapshot; middle — the selected path's snapshots
   (timestamp, size, device); right — content preview with two modes: **Snapshot** (raw text, monospace, selectable) and **Diff vs
   current** (line diff using the Phase 3 diff code; for deleted files diff is disabled). Actions: **Copy to clipboard**, **Restore**
   (writes the snapshot as the file content — atomic, and first snapshots the current content so restore is itself recoverable; for a
   deleted file, recreates it at its path, or at `<path> (restored).md` if a file now exists there). Phone layout: three stacked pages.
   Settings rows (07.1): `fileRecovery.snapshotIntervalMinutes`, `fileRecovery.historyDays` (wire to the Phase 3 service if it reads other
   keys — keep Phase 3's keys). Button **Clear history** (confirmation) deletes `.tephra/history` contents.
2. **Footnotes view:** right-sidebar panel "Footnotes" (desktop; phone: note "more" menu → Footnotes, as a bottom sheet). For the active
   note, from its `ParsedNote`: list each footnote in order of first reference: label (`[^1]` or `inline`), the definition text rendered
   with the reading view inline builder (single paragraph), and the reference count. Click a footnote → scroll the editor/reading view to its
   definition; a small "↩" button per reference jumps to that reference. Inline footnotes `^[text]` appear with label `inline n`.
   Definitions without references are listed at the end under "Unreferenced"; references without definitions are shown in the error colour
   ("Missing definition").

**Tests**
- `file_recovery_screen_test.dart` (fake snapshot service): lists a deleted path; diff mode shows added/removed lines; restore writes the
  snapshot bytes exactly and snapshots the previous content first; restoring a deleted file whose path is taken writes `(restored)`.
- `footnotes_panel_test.dart`: note with `[^1]`, `[^note]`, an inline footnote, an unreferenced definition and a missing one → five
  entries in the specified order and colours; tapping jumps (fake scroll controller receives the definition offset).

**Verify**
```
cd app; flutter test test/plugins/file_recovery test/plugins/footnotes; cd ..
```
Success: all pass.

**Pitfalls**
- Large snapshot folders: list paths lazily from the snapshot index the Phase 3 service keeps; do not read every snapshot file to build the list.

---

### 07.11 Web viewer (Windows)

**Purpose.** Open external links inside a tab on desktop, with an option to use the system browser.

**Files**
- `app/lib/workspace/tab_content.dart` (modify: add `WebViewerTabContent(String url)`, JSON `{"kind":"web","url":"…"}`)
- `app/lib/plugins/web_viewer/web_viewer_view.dart`, `commands.dart`, `link_router.dart` (new)
- `app/test/plugins/web_viewer/link_router_test.dart`, `web_viewer_view_test.dart` (new)

**Implementation**
1. Availability: Windows only (`Platform.isWindows`; a platform-only feature, §5.9 rule allows the check) **and**
   `corePlugins.webViewer` on. On Android external links always open in the system browser.
2. `LinkRouter.openExternal(Uri uri, {bool forceBrowser = false})`: if the web viewer is available, `webViewer.openExternalLinks` is
   true, the scheme is `http`/`https`, and not `forceBrowser` → open a `WebViewerTabContent` (new tab); else `launchUrl(uri, mode:
   LaunchMode.externalApplication)`. Replace every external-link click path (reading view, Live Preview, canvas link cards' "Open in
   viewer" context action — canvas card click still uses the browser as decided in Phase 6) with `LinkRouter`. Ctrl+Shift+click forces the
   browser.
3. `WebViewerView`: `InAppWebView` (the Phase 6 package; on the Phase 6 fallback, `webview_windows`' `Webview` widget) with: address
   bar (shows the current URL; Enter navigates; text without a scheme gets `https://`), back, forward, reload/stop, **Open in browser**,
   **Save to vault** (gets `document.documentElement.outerHTML` via `evaluateJavascript`, converts with the Phase 5 HTML → Markdown
   converter, creates `<page title>.md` in the new-note location with frontmatter `source: <url>` and `clipped: <ISO date>`, opens it),
   zoom with Ctrl+wheel (WebView native). Tab title = page title; icon = globe.
   Security: no JavaScript handlers registered; deny `file:`, `javascript:` and custom-scheme navigations from pages
   (`shouldOverrideUrlLoading` → cancel and route non-http(s) schemes to `launchUrl` only for `mailto:`); downloads open in the system
   browser; WebView2 user data folder `<appSupportDir>/webview` (set through the package's Windows environment settings); incognito off so
   logins persist; a **Clear browsing data** button in Settings → Core plugins → Web viewer.
4. Command `web-viewer.open-url` ("Open URL…") → URL dialog → opens the viewer; `web-viewer.open-home` opens `webViewer.homePage`.

**Tests**
- `link_router_test.dart`: Windows + enabled → viewer tab; setting off → `launchUrl`; `mailto:` → `launchUrl`; Android → `launchUrl`
  (inject a platform flag provider, not `Platform` directly, for testability).
- `web_viewer_view_test.dart` (fake WebView controller interface): address normalisation (`example.com` → `https://example.com`);
  Save to vault calls the converter and writes a note with `source` frontmatter; `file:///` navigation cancelled.
- Manual on Windows: open a link from a note, navigate, save to vault.

**Verify**
```
cd app; flutter test test/plugins/web_viewer; cd ..
```
Success: all pass; manual check on Windows; on Android links open in the browser.

**Pitfalls**
- Workspace persistence: restore `WebViewerTabContent` tabs lazily (create the WebView only when the tab becomes visible).

---

### 07.12 Tabs: tab groups, pinned tabs, stacked tabs, session restore

**Purpose.** Bring the tab system to Obsidian parity on desktop layout.

**Files**
- Phase 1/2 workspace model, notifier, tab bar and split widgets in `app/lib/workspace/` (modify)
- `app/lib/workspace/stacked_tabs_view.dart` (new)
- `app/test/workspace/tab_groups_test.dart`, `pinned_tabs_test.dart`, `stacked_tabs_test.dart`, `session_restore_test.dart` (new)

**Implementation**
1. **Tab groups** = each leaf of the split tree is a *tab group* with its own tab bar (check Phase 1: if splits already hold their own
   tabs, only add the missing operations). Operations (all commands, `workspace.*`): `workspace.split-right` (Ctrl+\\ — moves a copy of
   the active tab into a new group on the right), `workspace.split-down`, `workspace.move-tab-to-new-group`, `workspace.close-group`,
   `workspace.focus-group-left/right/up/down` (Ctrl+Alt+Arrow), `workspace.close-other-tabs`, `workspace.close-tabs-to-right`.
   Drag a tab: onto another group's tab bar → move; onto the left/right/top/bottom 25% edge zone of a group's content → split that group and
   move there (drop-zone highlight shown during drag). Empty group (last tab closed) is removed unless it is the only group (then it shows
   the empty state of 07.19).
2. **Pinned tabs:** command `workspace.toggle-pin` and tab context menu "Pin"/"Unpin". A pinned tab shows a pin icon and no close button;
   Ctrl+W / middle-click do not close it (show toast `tabPinnedCannotClose`); "Close others"/"Close all" skip it; navigating from a pinned
   tab (clicking a link, choosing a file in the explorer while it is active) opens the target in a **new** tab next to it instead of
   replacing it. Pinned state persists in `workspace.json` (`"pinned": true` on the tab entry).
3. **Stacked tabs** (desktop layout only): tab-group menu "Stack tabs" / command `workspace.toggle-stacked-tabs`; per-group flag persisted
   (`"stacked": true`). Rendering (`StackedTabsView`): tabs laid out horizontally as panes of width `min(700, groupWidth)` in a horizontal
   scroll view; each pane has a 40 px vertical title spine on its left edge (rotated title text, close button); when a pane would be scrolled
   out to the left, it collapses to its spine and sticks to the left edge (stacking spines); same on the right. Activating a tab scrolls its
   pane fully into view. On phone layout the flag is ignored (normal single pane).
4. **Session restore:** on app start, restore the last layout from `.tephra/workspace.json` for this device id (Phase 1 likely does this —
   verify): groups, split sizes, tabs, active tab per group, pinned/stacked flags, per-tab mode (source/live/reading), scroll positions
   (by top line), PDF page (from its cache), and sidebars' open panels and widths. Missing files → their tabs are dropped silently with a
   single toast `sessionMissingFiles` listing the count. Setting: none (always on, like Obsidian).

**Tests**
- `tab_groups_test.dart`: split right creates two groups; dragging a tab to the right edge zone splits; closing the last tab of a group
  removes it; focus commands move focus between groups.
- `pinned_tabs_test.dart`: Ctrl+W on a pinned tab keeps it; link click from a pinned tab opens a new tab; persisted flag round-trips.
- `stacked_tabs_test.dart`: 4 tabs in a 1,200 px group → panes 700 px; activating tab 4 scrolls so its pane is visible and tabs 1–2 are
  spines.
- `session_restore_test.dart`: save a layout with 2 groups, pinned tab, stacked group, reading mode tab; restart (new ProviderContainer) →
  identical layout; a missing file's tab is dropped with one toast.

**Verify**
```
cd app; flutter test test/workspace; cd ..
```
Manual on Windows (and a tablet/landscape Android if available, else the Windows window resized narrow/wide). Success: all pass.

**Pitfalls**
- Keep `workspace.json` per device id (§6.6); never write layout of one device into another's entry.

---

### 07.13 Saved workspaces, linked panes, pop-out windows

**Purpose.** Named layouts, panes that follow each other, and tabs in separate windows on Windows.

**Files**
- `app/lib/workspace/saved_workspaces.dart`, `saved_workspaces_dialog.dart` (new)
- `app/lib/workspace/linked_panes.dart` (new)
- `app/lib/workspace/popout/popout_window_service.dart`, `popout_window_app.dart` (new)
- `app/test/workspace/saved_workspaces_test.dart`, `linked_panes_test.dart`, `popout_protocol_test.dart` (new)

**Implementation**
1. **Saved workspaces:** in `.tephra/workspace.json`, per device id entry, add `"saved": { "<name>": <layout> }` next to the current
   layout (keep the existing shape; layout = the same JSON the session restore uses). Commands: `workspace.save-layout` ("Save current
   layout…" → name dialog; existing name → confirm overwrite), `workspace.load-layout` ("Load workspace…" → list; loading replaces the
   current layout; unsaved editor changes are saved first as usual), `workspace.delete-layout`, `workspace.manage-layouts` (dialog: list,
   rename, delete, load). Ribbon button (desktop). Phone: available from the palette; loading a desktop layout on the phone opens only the
   active tab of the first group (phone shows one pane), keeping the rest in the tab switcher.
2. **Linked panes:** tab context menu "Link with pane…" → choose another group's active tab. Link groups are sets of tab ids (persisted as
   `"linkGroup": "<uuid>"` on tabs). Behaviour: when a linked tab navigates to a file, every other tab in its link group opens the same file
   (keeping its own view mode); scrolling a linked Markdown tab scrolls the others to the same source line (map top visible line →
   `scrollToLine`), throttled to 30 Hz, with a re-entrancy guard so tabs do not echo each other. A chain-link icon shows on linked tabs;
   "Unlink" removes the tab from its group. Use case: source and reading view side by side.
3. **Pop-out windows (Windows only):** tab context menu "Open in new window" / command `workspace.move-to-new-window` (no default
   shortcut). Uses `desktop_multi_window` exactly like the Phase 4 sticky windows: the pop-out window runs
   `PopoutWindowApp` (a single tab group with the moved tab(s), its own tab bar, the editor/reading/canvas/base/PDF views). **Single-writer
   rule:** only the main window writes files and owns the index; the pop-out sends all writes, index queries and commands that change the
   vault to the main window over the Phase 4 window channel (method names prefixed `popout.`), and receives vault change notifications from
   it. Reuse the sticky window message types where they fit (read file, write file, watch events); add `popout.openFile`,
   `popout.closeWindow`, `popout.query` (index query by name + JSON args → JSON result) if missing. Window bounds per pop-out are saved in
   the layout (`"popouts": [{bounds, groups}]`) and restored with the session. Closing the main window closes all pop-outs (after saving).
   Moving a tab back: tab context menu in the pop-out "Move to main window". On Android the menu items are hidden.

**Tests**
- `saved_workspaces_test.dart`: save "Writing", modify layout, load "Writing" → layout equals saved; delete removes key; other devices'
  entries untouched (two device ids in the file).
- `linked_panes_test.dart`: two linked tabs; navigation in A opens the file in B; scroll in A to line 120 → B `scrollToLine(120)` once
  (no echo loop); unlink stops it.
- `popout_protocol_test.dart`: encode/decode of every `popout.*` message; a write request from the pop-out is executed by the main
  window's handler (fake channel) and the change notification is sent back.
- Manual on Windows: pop out a note, edit in both windows, close app, reopen → pop-out restored at its position, no data loss.

**Verify**
```
cd app; flutter test test/workspace; cd ..
```
Success: all pass; manual pop-out check recorded.

**Pitfalls**
- Each `desktop_multi_window` window is a separate Flutter engine (separate isolate): never open the SQLite index or write files from it.

### 07.14 Editor overlay decorations and multi-cursor (desktop)

**Purpose.** Add (a) one engine-independent mechanism for painting extra highlights in the editor (used by multi-cursor, vim and spell
check) and (b) multi-cursor editing implemented at the `EditorController` level.

**Decision (do not revisit).** No candidate engine in `docs/decisions/0001-editor-engine.md` (A `re_editor`, B `TextField`, C custom)
supports several simultaneous carets. Therefore multi-cursor is implemented **above the engine**: the engine keeps one real selection
(the *primary* caret); extra carets live in a Tephra-owned `CaretSet`; while extra carets exist, Tephra intercepts the keys listed below
and applies every edit to all carets as **one** `applyEdits` call (one undo step). Open the decision record first; if it unexpectedly
says the chosen engine does support multiple selections, still use this design (record a note in `PROGRESS.md`).

**Files**
- `app/lib/editor/decorations/range_decoration.dart` (new)
- `app/lib/editor/decorations/decoration_style.dart` (new)
- `app/lib/editor/multicursor/caret_set.dart` (new; pure Dart, no Flutter imports apart from `TextSelection`)
- `app/lib/editor/multicursor/multi_cursor_controller.dart` (new)
- `app/lib/editor/multicursor/commands.dart` (new)
- `app/lib/editor/editor_controller.dart` (modify: additive members below)
- the engine adapter file that builds styled text per line (Phase 1/2: the Markdown highlighter / Live Preview span builder) (modify:
  merge decorations; see item 2)
- `app/test/editor/decorations/range_decoration_test.dart`, `app/test/editor/multicursor/caret_set_test.dart`,
  `multi_cursor_controller_test.dart` (new)

**Implementation**

1. **Decoration model** (`range_decoration.dart`):
   ```dart
   enum DecorationKind { extraCaret, extraSelection, vimBlockCaret, vimVisual, vimSearchMatch, spellError }
   final class RangeDecoration {
     const RangeDecoration(this.start, this.end, this.kind);   // UTF-16 offsets, start <= end; start == end allowed only for extraCaret
     final int start; final int end; final DecorationKind kind;
   }
   ```
   `EditorController` gains (additive, all new):
   - `void setDecorations(String owner, List<RangeDecoration> decorations)` — replaces everything previously set by `owner`
     (owners used in this phase: `'multicursor'`, `'vim'`, `'spell'`); an empty list is the same as `clearDecorations(owner)`.
   - `void clearDecorations(String owner)`.
   - `ValueListenable<int> get decorationRevision` — incremented on every change, so the engine adapter can re-style.
   - `Iterable<RangeDecoration> decorationsInRange(int start, int end)` — all decorations of all owners that intersect `[start, end)`,
     sorted by `start`.
   - Decorations are **mapped through edits**: when `edits` emits an `EditorEdit` that was **not** produced by the owner itself, every
     decoration offset `>= edit.start + edit.deletedLength` is shifted by `insertedText.length - deletedLength`; offsets inside the
     replaced range collapse to `edit.start`. Owners normally recompute anyway; mapping only avoids one-frame flicker.
2. **Rendering** (decoration style table; colours are theme tokens from 07.3 via `context.tc`; the decoration style is applied **after**
   Markdown styling and wins for the properties it sets):
   | Kind | Visual |
   |---|---|
   | `extraCaret` (empty range) | the character **after** the offset gets `backgroundColor = interactiveAccent` at 55% alpha and `color = textOnAccent`; if the offset is at the end of a non-empty line, the character **before** it gets the same background (so the caret looks like a highlighted last character); on an empty line nothing can be drawn without changing the text, so nothing is drawn and the caret stays active (documented limitation; the status bar shows "N cursors") |
   | `extraSelection` | `backgroundColor = textSelection` |
   | `vimBlockCaret` | same as `extraCaret` but 100% alpha accent (block cursor) |
   | `vimVisual` | `backgroundColor = textSelection` |
   | `vimSearchMatch` | `backgroundColor = textHighlightBg` |
   | `spellError` | `decoration = TextDecoration.underline`, `decorationStyle = TextDecorationStyle.wavy`, `decorationColor = textError`, `decorationThickness = 1.5` |
   Implementation point: the engine adapter already produces a `TextSpan` per line (Phase 0 spike: `buildTextSpan` per line for A, or
   one span for B). After the Markdown spans are built for a line covering `[lineStart, lineEnd)`, call
   `controller.decorationsInRange(lineStart, lineEnd)` and split the leaf `TextSpan`s at decoration boundaries, merging the decoration
   `TextStyle` into each affected leaf (`style.merge(decorationStyle)`). **Never change the text of a span** (only its style), so offsets
   stay identical. Re-style when `decorationRevision` changes (listen once in the adapter; cancel on dispose).
3. **`CaretSet`** (`caret_set.dart`, pure and fully unit-testable):
   ```dart
   final class CaretSet {
     CaretSet(TextSelection primary, [List<TextSelection> extras = const []]);   // normalises (item 4)
     final TextSelection primary; final List<TextSelection> extras;              // extras sorted ascending, never overlapping each other or primary
     List<TextSelection> get all;                                                 // primary + extras sorted ascending by start
     bool get hasExtras;
     CaretSet withAdded(TextSelection s);                                         // becomes the new primary; old primary moves to extras
     CaretSet collapsedToPrimary();
     CaretSet map(TextSelection Function(TextSelection) f);                       // apply f to each caret, then normalise
     ({List<TextEdit> edits, CaretSet carets}) applyInsert(String text);          // item 5
     ({List<TextEdit> edits, CaretSet carets}) applyBackspace(String source);     // needs source text for grapheme lookups
     ({List<TextEdit> edits, CaretSet carets}) applyDelete(String source);
   }
   ```
4. **Normalisation:** sort by `start`; two carets whose ranges overlap or are equal (empty caret inside another selection counts as
   overlapping) are merged into one range `[min start, max end)`; the primary stays primary if it was merged into another range;
   empty carets at the same offset are deduplicated. All offsets must lie in `[0, text.length]`.
5. **How an edit is applied to all carets (algorithm, used by every input kind).**
   Let carets `c_0 … c_{n-1}` be sorted ascending (`all`). For each caret build one `TextEdit` replacing `[c_i.start, c_i.end)` with the
   caret's replacement text `r_i`. Pass the list to `EditorController.applyEdits` (Phase 2: non-overlapping edits applied **back-to-front**
   as **one** undo step, so earlier offsets stay valid while later edits are applied). New caret positions are computed **without**
   relying on the engine's mapping: `delta_i = sum over j < i of (r_j.length - (c_j.end - c_j.start))`; new caret `i` =
   `collapsed at c_i.start + delta_i + r_i.length`. Then set the engine selection to the new primary position and the `CaretSet` to the
   new carets. Use the `TextEdit` field names that exist in `tephra_index` (record them in the Name map; this step writes them as
   `(start, end, newText)`).
6. **Input kinds** (all in `MultiCursorController`, active only while `caretSet.hasExtras`; the primary-only path stays the engine's):
   | Input | Replacement per caret |
   |---|---|
   | Printable character (`KeyEvent.character` non-empty, no Ctrl/Alt/Meta) | the character; selection replaced |
   | Enter | `'\n'` + the leading whitespace (spaces/tabs) of the caret's line, taken from the text **before** the edit; selection replaced. No smart-list continuation in multi-cursor mode (documented) |
   | Tab | if `editor.useTabs`: `'\t'`; else `editor.tabSize` spaces; selection replaced. Shift+Tab: remove one indent unit (one tab, or up to `tabSize` spaces) at the start of each caret's line; edits are line-start deletions (dedupe carets on the same line) |
   | Backspace | non-empty selection → delete it; empty → delete the previous **grapheme cluster** (`source.substring(0, o).characters.last.length`); at offset 0 → no edit. Edits that would overlap (adjacent carets) are merged: process ascending, drop any edit whose start < previous edit's end |
   | Delete | symmetric, next grapheme cluster |
   | Ctrl+V | if the clipboard text split by `\n` has exactly as many lines as carets (ignoring one trailing empty line) → line *i* goes to caret *i*; otherwise the whole text to every caret. (HTML-to-Markdown conversion of 07.17 is skipped in multi-cursor mode; plain text is used.) |
   | Ctrl+X | per caret: copy the selected text (joined with `\n` in caret order) to the clipboard, delete selections; empty carets cut nothing |
   | Ctrl+C | copy selected texts joined by `\n` (skip empty carets); if all are empty copy nothing |
   | Left / Right / Home / End / Up / Down (with or without Shift) | each caret moves independently; Up/Down use a per-caret **goal column** kept in a `Map<int, int>` keyed by caret index and reset on any other input; movement is over **logical lines** (not wrapped display lines — documented); with Shift the caret's `extent` moves and `base` stays; without Shift carets collapse to their `extent` |
   | Ctrl+Left / Ctrl+Right | move to the previous/next word boundary: a word is a maximal run of `[\p{L}\p{N}\p{M}_]`; carets that end on the same offset merge |
   | Escape | `collapsedToPrimary()` |
   | Everything else (Ctrl shortcuts not listed, F-keys) | **not consumed**; the key passes to the app's `Shortcuts`. Any command that changes the text through the engine (for example `editor.toggle-bold`) first calls `collapsedToPrimary()` (the command runner calls `multiCursor.collapse()` before running any command whose id starts with `editor.` and that is not in the multi-cursor command list) |
   Key handling: wrap the editor in `Focus(onKeyEvent: …)` placed **above** the engine widget; return `KeyEventResult.handled` for consumed keys
   (so the engine never sees them) and `ignored` otherwise. Skip all interception while an IME composition is active
   (`TextEditingValue.composing.isValid`) — in that case call `collapsedToPrimary()` first.
7. **Adding carets** (commands registered in `commands.dart`; all `isAvailable` only on desktop layout, editor focused, vim mode off):
   | Command id | Label | Default shortcut | Behaviour |
   |---|---|---|---|
   | `editor.add-caret-above` | Add cursor above | Ctrl+Alt+Up | for the **topmost** caret, add a caret on the previous logical line at the same column (`min(column, lineLength)`); no-op on line 0 |
   | `editor.add-caret-below` | Add cursor below | Ctrl+Alt+Down | for the **bottommost** caret, same on the next line |
   | `editor.select-next-occurrence` | Select next occurrence | Ctrl+D | see item 8 |
   | `editor.clear-extra-carets` | Collapse to one cursor | Escape (local, only while extras exist) | `collapsedToPrimary()` |
   Alt+click: in `Listener.onPointerDown` (desktop layout, `HardwareKeyboard.instance.isAltPressed`, primary mouse button) remember the
   current `CaretSet` as `before`; do **not** consume the event (the engine moves its caret to the click point). In `onPointerUp`, after
   one frame (`WidgetsBinding.instance.addPostFrameCallback`), read the engine's new selection `s` and set the `CaretSet` to
   `before.withAdded(s)`. (This needs no hit-testing API from the engine.) Alt+click on an existing extra caret removes that caret.
8. **Select next occurrence (Ctrl+D)**: let `p` = primary. If `p` is empty: select the word around the caret (word = maximal run of
   `[\p{L}\p{N}\p{M}_]`; if the caret is not on a word, do nothing) as the primary — no extra caret yet. Else: let `needle` =
   `text.substring(p.start, p.end)` (case-sensitive, plain text). Search forward from the end of the **last** selection (largest end) for
   `needle`; wrap to the start of the document; skip matches that overlap an existing caret; if found → `withAdded(match)`, scroll it into
   view with `revealOffset`; if every occurrence is already selected → toast `multiCursorNoMoreMatches`.
9. **Decorations:** after every change of the `CaretSet`, `controller.setDecorations('multicursor', …)` with one `extraCaret` (empty) or
   `extraSelection` (non-empty) decoration per extra caret. Status bar (desktop) shows `multiCursorCount` ("3 cursors") while extras
   exist (hidden otherwise).
10. **Interaction with other features:** when an `edits` event arrives that was **not** produced by `MultiCursorController`
    (undo/redo, external file change reload, another command) → `collapsedToPrimary()`. Switching tabs or losing focus does not clear carets
    (they are per editor). Autocomplete popups, slash commands and spell-check suggestion menus are closed when extras exist.

**Tests**
- `range_decoration_test.dart`: `setDecorations('a', …)` then `setDecorations('b', …)` keep both; `clearDecorations('a')` removes only a's;
  `decorationsInRange` returns intersecting ones sorted; an `EditorEdit` inserting 3 chars at offset 0 shifts a decoration at 10 to 13;
  `decorationRevision` increments once per change.
- `caret_set_test.dart` (pure): normalisation (overlap merged, duplicates removed, primary preserved); `applyInsert('x')` with carets at
  offsets 2, 5, 9 in `"abcdefghij"` → text `"abxcdexfghixj"` and carets at 3, 7, 12; selection replacement (`[0,2)` and `[4,6)` replaced by `'-'`);
  `applyBackspace` over `"a👍🏽b"` removes the whole emoji (two code points) with one caret after it; adjacent carets at 3 and 4 both
  backspace → no overlapping edits (on `"abcdef"`: assert the edit list is non-overlapping and the result is `"abef"`); `applyDelete` at end of text → no edit.
- `multi_cursor_controller_test.dart` (fake `EditorController` with a string buffer and an undo stack): Ctrl+Alt+Down twice on column 3 → 3
  carets; typing `'X'` → one `applyEdits` call, one undo entry (assert undo restores original text in **one** undo); Enter copies indentation
  of each line; Tab with `useTabs=false,tabSize=4`; Shift+Tab; paste with 3 lines into 3 carets distributes lines, paste with 2 lines into 3
  carets pastes the 2-line text three times; Ctrl+C joins selections with `\n`; Ctrl+D sequence on `"foo bar foo baz foo"`: first press selects
  `foo`, second adds offset 8, third adds offset 16, fourth wraps and toasts `multiCursorNoMoreMatches`; Escape collapses; undo (an `isUndoRedo`
  edit) collapses carets; `editor.toggle-bold` collapses first; IME composing → carets collapse and key not consumed; Alt+click flow with a
  fake pointer sequence adds a caret; commands not available at width 400.

**Verify**
```
cd app; flutter test test/editor/decorations test/editor/multicursor; cd ..
```
Manual on Windows: Alt+click three places and type; Ctrl+D on a word three times and replace it; Ctrl+Z once undoes the whole typing;
extra carets are visible as highlighted characters. Android phone: commands absent. Success: tests pass; manual notes recorded.

**Pitfalls**
- Never apply per-caret edits one by one (the undo history would have n steps and offsets would drift); always one `applyEdits` call.
- Do not store `CaretSet` offsets across an external edit; collapse instead.
- The decoration mechanism must not alter span text; a test asserts that the concatenated span text of a line is identical with and
  without decorations.

---

### 07.15 Vim mode (desktop)

**Purpose.** An optional modal editing mode for the editor with a fixed, documented command subset.

**Files**
- `app/lib/editor/vim/vim_key.dart`, `vim_state.dart`, `vim_machine.dart`, `vim_motions.dart`, `vim_registers.dart`,
  `vim_buffer.dart`, `vim_ex.dart` (new; **pure Dart**, no Flutter imports except `package:flutter/services.dart` types **only** in
  `vim_key_adapter.dart`)
- `app/lib/editor/vim/vim_key_adapter.dart`, `vim_controller.dart`, `vim_status_bar.dart`, `commands.dart` (new)
- `app/test/editor/vim/vim_motions_test.dart`, `vim_machine_test.dart`, `vim_controller_test.dart` (new)

**Scope (exact; nothing else is implemented — everything else is swallowed in Normal/Visual mode).**
Modes: Normal, Insert, Visual (characterwise), Visual Line, Command-line (`:`), Search (`/`).
| Group | Keys |
|---|---|
| Motions | `h` `j` `k` `l`, `w` `b` `e`, `0` `$` `^`, `gg` `G` |
| Operators (Normal) | `dd`, `yy`, `p`, `P`, `x` |
| Undo | `u`, `Ctrl+R` |
| Enter Insert | `i` `a` `o` `O` `A` `I` |
| Visual | `v`, `V`; inside Visual: motions above, `d`, `x`, `y`, `v`, `V`, `Esc` |
| Search | `/` then text then Enter; `n`, `N` |
| Ex | `:w` + Enter |
| Leave | `Esc` (Insert → Normal; Visual → Normal; Command-line/Search → cancel; Normal → clears pending keys) |
| Count prefix | `[1-9][0-9]*` before: `h j k l w b e x dd yy p P` (repeat), `G` (go to line n), `gg` (go to line n), `u` (n undo steps), `Ctrl+R` (n redo steps). A count before any other key is discarded. |
`Ctrl+...` combinations other than `Ctrl+R` are never consumed (they reach app shortcuts: Ctrl+S, Ctrl+O, Ctrl+P …). `Enter`, `Space`,
`Backspace`, arrow keys, Home/End and Delete in Normal mode: arrows/Home/End move like `h j k l 0 $`; the rest are swallowed.

**Implementation**

1. **Buffer abstraction** (`vim_buffer.dart`) so the machine is testable without the editor:
   ```dart
   abstract interface class VimBuffer {
     String get text;                                   // '\n'-normalised
     int get cursor;                                    // Normal mode: offset of the character the block cursor is ON
     void setCursor(int offset);                        // clamps to a valid Normal-mode position (item 3)
     void setSelection(int start, int end);             // for Visual
     void replace(int start, int end, String newText);  // ONE EditorController.applyEdits call = one undo step
     void undo(); void redo();
     Future<void> save();                               // existing "save now" path
   }
   ```
   `VimController` adapts `EditorController` to `VimBuffer` (`replace` → `applyEdits([TextEdit(start,end,newText)])`).
2. **Lines.** A *line* is the text between `\n`s (the `\n` is not part of the line). `lineStart(o)`, `lineEnd(o)` (offset of its `\n`
   or `text.length`), `lineIndex(o)`, `lineCount`. Columns are counted in UTF-16 units but moves skip over surrogate pairs and combining
   marks as one unit (use `characters`; a "character" below means a grapheme cluster).
3. **Cursor position rule (Normal mode).** The cursor is ON a character: valid offsets are `lineStart … lineEnd - 1` for a non-empty
   line and `lineStart` for an empty line. After any Normal-mode command the cursor is clamped to this range. In Insert mode the cursor
   is a normal caret (`lineStart … lineEnd`).
4. **State** (`vim_state.dart`): `mode`, `pendingKeys` (string like `"2d"`, `"g"`), `count` (int?), `desiredColumn` (int?, set by
   `j`/`k`, cleared by any other motion), `visualAnchor` (int?), `commandLine` (String, for `:` and `/`), `lastSearch` (String?),
   `searchForward` (bool), `register` (`Register { String text; bool linewise; }?`), `undoCheckpoints`, `redoCheckpoints` (item 8),
   `message` (String? transient status text).
5. **Machine** (`vim_machine.dart`): `VimResult handle(VimKey key)` where `VimKey { String? char; bool ctrl; bool shift; VimNamedKey? named; }`
   (`named`: esc, enter, backspace, left, right, up, down, home, end, delete). `VimResult { bool consumed; }`. Transition table
   (state × key → action):

   **Normal**
   | Pending | Key | Action |
   |---|---|---|
   | — | digit `1–9` (or `0` when `count != null`) | append to `count`; stay |
   | — | `h j k l w b e 0 $ ^ G` | motion × `count ?? 1`; clear count |
   | — | `g` | `pendingKeys = 'g'` |
   | `g` | `g` | motion `gg` (line `count` if set, else first line; cursor at first non-blank `^` of that line); clear |
   | `g` | anything else | clear pending; swallow |
   | — | `d` or `y` | `pendingKeys = key` |
   | `d` | `d` | `dd` × count; clear |
   | `y` | `y` | `yy` × count; clear |
   | `d`/`y` | anything else (including Esc) | clear pending and count; swallow |
   | — | `x` | delete count characters from the cursor to the end of the line (never past `lineEnd`); store in register (`linewise: false`) |
   | — | `p` / `P` | paste (item 7) × count |
   | — | `u` / `Ctrl+R` | undo/redo × count (item 8) |
   | — | `i` | Insert at cursor |
   | — | `a` | Insert after the cursor (cursor + 1 grapheme, but not when the line is empty) |
   | — | `A` | Insert at `lineEnd` |
   | — | `I` | Insert at the first non-blank character of the line (`^` position; at `lineEnd` if the line is blank) |
   | — | `o` | insert `\n` at `lineEnd`, Insert at the new line start (copy the current line's leading whitespace and list marker? **No** — plain: copy leading whitespace only) |
   | — | `O` | insert `\n` + leading whitespace at `lineStart`, Insert at the end of that new line's whitespace |
   | — | `v` | Visual, `visualAnchor = cursor` |
   | — | `V` | Visual Line, `visualAnchor = cursor` |
   | — | `/` | Search mode, `commandLine = ''` |
   | — | `:` | Command-line mode, `commandLine = ''` |
   | — | `n` / `N` | repeat last search forward/backward (item 9); `lastSearch == null` → message `vimNoPreviousSearch` |
   | — | Esc | clear pending and count |
   | — | any other printable key | swallow (consumed, no effect) |

   **Insert**: Esc → Normal, cursor moves one grapheme left unless at `lineStart`; closes the undo checkpoint (item 8). **Every other key is
   NOT consumed** (the engine types it). `Ctrl+[` is also Esc.

   **Visual / Visual Line**: motions as in Normal (count allowed) move the cursor; the engine selection is set to
   `[min(anchor,cursor), max(anchor,cursor) + 1 grapheme)` for Visual, and to whole lines (`lineStart` of the first to `lineEnd` of the last, plus the
   trailing `\n` when there is one) for Visual Line. `d` or `x` → delete the selection, register set (`linewise` = Visual Line), return to
   Normal with the cursor at the start of the deleted range (clamped); `y` → copy, cursor to the start of the selection, Normal; `v` in
   Visual → Normal; `v` in Visual Line → Visual; `V` in Visual Line → Normal; `V` in Visual → Visual Line; Esc → Normal; `/`, `n`, `N` work
   and extend the selection to the match start; any other key → swallowed.

   **Command-line (`:`)**: printable → append; Backspace → remove last char, or cancel when already empty; Esc → cancel (Normal); Enter →
   run `VimEx.run(commandLine)`: exactly `w` (trim whitespace) → `buffer.save()` and message `vimSaved`; anything else → message
   `vimNotAnEditorCommand` with the text. Return to Normal.

   **Search (`/`)**: same editing keys; Enter → `lastSearch = commandLine`, `searchForward = true`, jump to the first match after the cursor
   (item 9); empty pattern on Enter → reuse `lastSearch`.
6. **Motions** (`vim_motions.dart`, pure functions `int motion(String text, int cursor, …)`):
   - `h`/`l`: one grapheme within the line (no wrap across lines; no-op at the edge). `j`/`k`: same column on the next/previous line using
     `desiredColumn ?? column`, clamped to that line's last valid cursor position; `desiredColumn` is set on the first `j`/`k` of a run
     and preserved by consecutive `j`/`k`. No-op on the last/first line.
   - Character classes: *word* = `[\p{L}\p{N}\p{M}_]`; *punct* = any other non-whitespace character; *blank* = whitespace. A "word" for
     `w b e` is a maximal run of one of the first two classes; an **empty line** is also a word.
   - `w`: move to the start of the next word: skip the rest of the current run, then skip blanks/newlines (stopping at an empty line);
     at end of text stay on the last character. `b`: reverse (to the start of the current word if not at its start, else the previous).
     `e`: to the end (last character) of the current word if not already at it, else of the next word.
   - `0` line start; `^` first non-blank of the line (line start if the line is blank); `$` last valid cursor position of the line
     (`count > 1` → end of the line `count - 1` lines down); `gg`/`G`: line `count` (1-based, clamped) or first/last line when no count;
     cursor goes to the first non-blank of that line.
   - In Normal mode a motion result is clamped by item 3; `dd`/`yy` ignore the column.
7. **Operators and register.**
   - `dd` × n: delete n lines starting at the cursor line (fewer at the end of text). Register = the deleted text including each
     trailing `\n` (if the deleted lines include the last line and no trailing `\n`, store `text + '\n'` and also remove the `\n` before
     them so no empty line is left); `linewise: true`. Cursor: first non-blank of the line that took the place (or the new last line).
   - `yy` × n: register = the n lines + `\n` each; `linewise: true`; no text change; cursor unchanged; message `vimYanked(n lines)`.
   - `x` × n: register = the removed text (`linewise: false`); empty line → nothing.
   - `p`: linewise register → insert the register text after the current line's `\n` (if the cursor line is the last and has no `\n`,
     insert `'\n'` first), cursor to the first non-blank of the first pasted line; characterwise → insert after the cursor character,
     cursor on the last pasted character. `P`: linewise → before the current line (at `lineStart`); characterwise → at the cursor.
     × n repeats the register text n times. Empty register → message `vimRegisterEmpty`.
   - Register is also written by Visual `d x y`. It is process-local (not persisted, not the system clipboard).
8. **Undo/redo bridge** (the engine's undo is not modal). Maintain `undoCheckpoints: List<String>` — snapshots of `text` **before**
   each change step: every Normal/Visual change command (`dd x p P o O` and Visual `d x`) pushes the pre-text immediately before it
   changes the buffer; an Insert session pushes the text at the moment Insert was entered (only if the session changed the text,
   decided at Esc by comparing; if unchanged, drop the checkpoint) — `i a A I` push on entry; `o O` push their pre-text **before** their own
   newline insertion and the whole `o` + typing is one step. Cap: 200 checkpoints (drop the oldest).
   - `u`: pop `target`; push the current `text` onto `redoCheckpoints`; call `buffer.undo()` repeatedly (max 1,000 iterations) **until
     `buffer.text == target`**; if the text stops changing before matching, stop, clear both stacks and show `vimUndoLost`. Cursor: the
     start offset of the first differing character between before and after, clamped.
   - `Ctrl+R`: symmetric with `redoCheckpoints` (pop target = text after the change; `buffer.redo()` until equal), pushing the pre-text on
     `undoCheckpoints`.
   - Any edit **not** made by vim (an `edits` event while the machine is in Normal/Visual and `isUndoRedo` is false and the controller
     did not initiate it — e.g. a file reload or command) clears both stacks.
   - Count `n`: repeat n times.
9. **Search:** pattern = literal text; case-insensitive unless the pattern contains an uppercase letter (smartcase); forward search starts at
   `cursor + 1`, wraps to the document start (message `vimSearchWrapped`); `N` searches backward from `cursor - 1`, wrapping to the end;
   no match → message `vimPatternNotFound`. Matches are shown through `setDecorations('vim', …)` as `vimSearchMatch` (all matches in the
   visible area ±200 lines, recomputed in `Isolate`-free code because it is bounded) and cleared by Esc in Normal mode.
10. **Controller** (`vim_controller.dart`): created per editor when `editor.vimMode` is true and the layout is desktop; wraps the editor
    in `Focus(onKeyEvent)` **above** the engine and above `MultiCursorController` (vim and multi-cursor are mutually exclusive: turning
    vim mode on collapses extra carets; multi-cursor commands are unavailable while vim is on).
    - `vim_key_adapter.dart` converts `KeyEvent` (`KeyDownEvent` and `KeyRepeatEvent` only; ignore key-up) to `VimKey`: use
      `event.character` for printable keys (so `Shift+4` gives `$`), `LogicalKeyboardKey` for named keys.
    - Consumed key → `KeyEventResult.handled`. **Text-input leak check:** on Windows, a handled key event must not reach the text input
      client; verify manually that pressing `z` in Normal mode inserts nothing. If it does leak on a real device, set the engine to
      read-only while in Normal/Visual/Command-line/Search modes (the engine's `readOnly` flag; our own `applyEdits` calls must still
      work — verify) and record which approach was needed in `PROGRESS.md`.
    - Mode → cursor: Normal → `setDecorations('vim', [vimBlockCaret(cursor, cursor+1 grapheme)])` (+ search matches), engine caret kept at the
      cursor offset; Visual → `vimVisual` over the selection plus the block caret on the cursor; Insert → no decorations (thin caret).
    - `VimStatusBar` (a 24 dp bar at the bottom of the editor pane, desktop only): left `-- NORMAL --` / `-- INSERT --` / `-- VISUAL --` /
      `-- VISUAL LINE --` (l10n `vimModeNormal` …); in Command-line/Search mode shows `:` / `/` + the typed text with a caret; middle: pending
      keys (e.g. `2d`); right: transient `message` for 3 seconds. Semantics: `liveRegion: true` on the message.
    - Entering a note: Normal mode. Switching tabs keeps each editor's own mode. Closing/losing focus keeps the mode.
    - Autocomplete, slash commands and link suggestions are suppressed in Normal/Visual mode and work in Insert mode as usual.
11. Command `editor.toggle-vim-mode` ("Toggle vim mode", no default shortcut, desktop only) flips `editor.vimMode`. Settings →
    Hotkeys shows a read-only "Vim" section listing the table in "Scope" above (l10n `vimHelp*`).

**Tests**
- `vim_motions_test.dart` (pure; `|` marks the cursor in the fixtures, helper parses it): `h/l` stop at line edges; `j/k` keep the desired
  column across a short line (`"abcdef\nab\nabcdef"` from col 5: `j` → col 1, `j` → col 5); `w` on `"foo bar-baz  qux"` visits `foo`, `bar`, `-`,
  `baz`, `qux`; `w` across lines and onto an empty line; `b` back over the same; `e` from start and from the end of a word; `0`, `^` with leading
  tabs, `$` on empty line; `gg`, `G`, `3G`, `2gg` with count; emoji and combining marks counted as one character for `h/l/x`.
- `vim_machine_test.dart` (fake `VimBuffer`): table-driven cases `(initial text|cursor, keys, expected text|cursor, expected mode, expected register)`
  covering at least: `dd` (middle, first, last line, only line, count `2dd`, count larger than remaining); `yy` + `p` (new line below);
  `yy` + `P`; `dd` then `p` swaps lines; `x` (middle, last char, empty line, `3x` clamps at line end); charwise `p` after `x` and `P`;
  `i`, `a` (also on empty line), `A`, `I` (with leading spaces), `o`, `O` (leading whitespace copied) followed by typed text and Esc
  (cursor moves left); `u` after `dd`; `u` after an Insert session with typed text undoes the whole session; `Ctrl+R` after `u`; `3u`;
  stale stack (edit made outside vim) → `vimUndoLost`; `v` + `llld`; `V` + `jd` (linewise, register linewise); `v` + `y` + `p`; `v` then `V`
  then Esc; `/foo` Enter, `n`, `N`, wrap-around, smartcase (`/Foo` does not match `foo`), no match message; `:w` calls `save()`; `:q` → message
  `vimNotAnEditorCommand`; Esc cancels `:` and `/`; unknown printable key in Normal is consumed without changes; `Ctrl+S` is **not**
  consumed; `Ctrl+R` consumed; keys in Insert (letters) not consumed; count digits `0` handling (`10j` vs `0`).
- `vim_controller_test.dart` (widget test with a fake engine): typing `dd` through `KeyDownEvent`s changes the text; block-caret decoration
  present in Normal and absent in Insert; status bar texts; turning the setting off removes the status bar and decorations; vim command
  unavailable on phone width.

**Verify**
```
cd app; flutter test test/editor/vim; cd ..
```
Manual on Windows (10 minutes): edit a real note using only the subset; confirm `z` inserts nothing in Normal mode; Ctrl+S still saves.
Success: tests pass; manual notes recorded.

**Pitfalls**
- Vim lines are logical lines, not wrapped display lines (`j` moves by logical line); document this in the Vim help text.
- `Esc` must also close open popups first (autocomplete): if a popup is open Esc closes it and stays in Insert mode.
- `x`/`dd` must not write into the system clipboard.

### 07.16 Spell check (Android and Windows)

**Purpose.** Underline misspelled words in the editor and offer suggestions, using each operating system's own spell checker.

**Decision (do not revisit; see "Before you start" item 7).**
- **Android:** Flutter's `DefaultSpellCheckService` (`package:flutter/services.dart`, talks to Android's `TextServicesManager`). We call
  `fetchSpellCheckSuggestions(Locale, String)` ourselves, so it works with every editor engine. No new package.
- **Windows:** the Windows Spell Checking API (`ISpellCheckerFactory` / `ISpellChecker`, Windows 8+) through `package:win32` **6.x** COM
  interfaces (`ISpellCheckerFactory`, `ISpellChecker`, `ISpellingError`, `IEnumSpellingError`, `IEnumString` — all present in win32 6.x;
  licence BSD-3-Clause, verified on pub.dev 2026-10-11, latest 6.4.0). No C++ plugin and no dictionary files are needed. If the installed
  win32 version lacks any of those interfaces, **stop and ask the human** (the fallback would be a small C++ plugin; do not start it
  on your own).
- Both are hidden behind one interface so the editor code is platform-free (§5.9).

**Files**
- `app/lib/core/platform/spell_check_service.dart` (new: interface + `SpellIssue`)
- `app/lib/core/platform/spell_check_service_android.dart`, `spell_check_service_windows.dart`, `spell_check_service_noop.dart` (new)
- `app/lib/core/platform/providers.dart` (modify: `spellCheckServiceProvider`)
- `app/lib/editor/spell/checkable_ranges.dart` (new; pure Dart)
- `app/lib/editor/spell/spell_check_controller.dart` (new)
- `app/lib/editor/spell/spell_menu.dart` (new: suggestion context menu)
- `app/lib/editor/spell/commands.dart` (new)
- `app/pubspec.yaml` (add `win32: ^6.4.0` and `ffi` only if missing — run `flutter pub add win32 ffi` in `app/`, then `dart run tool/check_licenses.dart`)
- `app/test/editor/spell/checkable_ranges_test.dart`, `spell_check_controller_test.dart`, `spell_check_service_windows_test.dart` (new)

**Implementation**

1. **Interface** (`spell_check_service.dart`):
   ```dart
   final class SpellIssue {
     const SpellIssue(this.start, this.end, [this.suggestions = const []]);   // UTF-16 offsets into the checked string
     final int start; final int end; final List<String> suggestions;           // suggestions only if the platform returns them with the check
   }
   abstract interface class SpellCheckService {
     Future<bool> isAvailable();                                               // false → feature silently off
     Future<List<String>> supportedLanguages(List<String> requested);          // subset of BCP-47 tags the OS can check
     Future<List<SpellIssue>> check(String text, String languageTag);          // misspelled ranges in [text]
     Future<List<String>> suggest(String word, String languageTag);            // up to 8
     bool get canAddToDictionary;                                              // Windows true, Android false
     Future<void> addToDictionary(String word, String languageTag);
     Future<void> ignore(String word, String languageTag);                     // ignore for this session
     Future<void> dispose();
   }
   ```
   `NoopSpellCheckService` returns `false`/empty. The provider picks Android / Windows / Noop with `Platform.isAndroid` / `Platform.isWindows`.
2. **Android implementation:** hold `DefaultSpellCheckService`. `check`: `Locale locale = Locale.fromSubtags(languageCode: …, countryCode: …)`
   from the tag; `final List<SuggestionSpan>? spans = await service.fetchSpellCheckSuggestions(locale, text);` `null` → return `[]`
   (and `isAvailable` becomes false after 3 consecutive nulls: the user has no system spell checker enabled; the Settings row then
   shows `spellcheckNoSystemChecker`). Map each span to `SpellIssue(span.range.start, span.range.end, span.suggestions)`.
   The service handles one request at a time: serialise calls through a single-flight queue (a `Future` chain). `suggest` returns the
   suggestions from a one-word `check`. `supportedLanguages`: Android cannot be asked cheaply → return the requested list unchanged.
   `canAddToDictionary` = false; `ignore` keeps an in-memory `Set<String>` filtered by us.
3. **Windows implementation (COM, UI isolate only — COM objects belong to the thread that created them):**
   1. `ensureCom()`: call `CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)`; accept `S_OK`, `S_FALSE` and `RPC_E_CHANGED_MODE`
      (Flutter already initialised COM on the platform thread); any other result → `isAvailable() == false`.
   2. Create the factory: `CoCreateInstance(CLSID_SpellCheckerFactory, nullptr, CLSCTX_INPROC_SERVER, IID_ISpellCheckerFactory, …)`
      using the constants/wrapper the win32 6.x README documents (`SpellCheckerFactory.createInstance()` or equivalent; the raw values
      are CLSID `{7AB36653-1796-484B-BDFA-E74F1DB7C1DC}` and IID `{8E018A9D-2415-4677-BF08-794EA61F94BB}` — use the package's constants,
      not these strings, unless the package has none). Failure (older Windows without the API) → unavailable.
   3. `supportedLanguages(requested)`: for each tag call `factory.IsSupported(tag)`; keep the supported ones. (Windows only has
      dictionaries for languages the user installed; Bangla has none by default — the Settings row shows `spellcheckLanguageUnavailable`
      for the unsupported tags.)
   4. Per language keep one cached `ISpellChecker` from `factory.CreateSpellChecker(tag)`; release (`Release()`) all in `dispose()`.
   5. `check(text, tag)`: `checker.Check(text)` → `IEnumSpellingError`; loop `Next()` until `S_FALSE`; for each `ISpellingError` read
      `StartIndex`, `Length` (UTF-16 units — they match Dart string offsets) and `CorrectiveAction`; skip when `CorrectiveAction` is
      `CORRECTIVE_ACTION_NONE`; release every COM object (use `try/finally`). Allocate native strings with `toNativeUtf16()`/`free()`.
   6. `suggest(word, tag)`: `checker.Suggest(word)` → `IEnumString`; read up to 8 strings; release.
   7. `addToDictionary` → `checker.Add(word)` (persists in the user's Windows dictionary); `ignore` → `checker.Ignore(word)`.
   8. All calls are synchronous FFI but short (paragraph-sized text); call them from the controller below, never in a `build()` method.
4. **Checkable ranges** (`checkable_ranges.dart`): `List<TextRange> checkableRanges(ParsedNote note, String text)` returns the parts
   of the text that are prose, from the AST: the source ranges of `MdText` nodes (including inside headings, emphasis, strong,
   strikethrough, highlight, links' visible text, list items, table cells, callout titles/bodies, footnote definitions) minus everything
   else. Never checked: frontmatter, code blocks, inline code, math, HTML, `MdWikiLink` targets (but the alias text **is** checked),
   link URLs, autolinks, tags, block ids, comments, embeds. Then split every range at URLs/e-mail patterns (`https?://\S+`, `\S+@\S+\.\S+`).
   Words excluded after the service returns issues: tokens containing a digit, tokens of length < 2, tokens in ALL CAPS of length ≤ 5,
   and tokens that are in the session ignore set.
5. **Controller** (`spell_check_controller.dart`), one per open editor:
   - Active when: `editor.spellcheck` is true, the service `isAvailable()`, the vault note is editable, and (desktop layout or phone) —
     both platforms. Languages: `editor.spellcheckLanguages`; empty → the system locale (`PlatformDispatcher.instance.locale.toLanguageTag()`);
     filtered through `supportedLanguages`. With several languages a word is reported only if it is misspelled in **all** of them (check
     language 1, then re-check only the reported words against language 2, …).
   - Trigger: debounce 400 ms after each edit and once on open. Work unit = **paragraph** (text between blank lines, intersected with
     the checkable ranges). Keep `Map<int paragraphHash, List<SpellIssue>>` (hash = `Object.hash` of paragraph text + language list); only
     re-check paragraphs whose hash is missing; shift cached issues by offset when text before them changed (recompute offsets from the
     paragraph start each time instead of storing absolute offsets). Check paragraphs in this order: the paragraph containing the caret,
     then paragraphs visible on screen, then the rest of the note, at most 20 paragraphs per frame-idle slice
     (`await Future<void>.delayed(Duration.zero)` between slices), cancelling when a new edit arrives. Notes > 100,000 characters: check
     only the paragraphs within ±150 lines of the caret.
   - The word under the caret while typing is **not** underlined until the caret leaves it (do not flag half-typed words): exclude an
     issue when `issue.start <= caret <= issue.end` and the last edit was within 1 second.
   - Publish with `controller.setDecorations('spell', issues.map((i) => RangeDecoration(i.start, i.end, DecorationKind.spellError)))`.
   - Memory/perf guard: the whole pass must add < 4 ms per keystroke on the UI thread (the keystroke itself only schedules the debounce).
6. **Suggestions UI** (`spell_menu.dart`): on a secondary click (desktop) or a tap on an underlined word, or a long-press (Android;
   Android's selection toolbar already appears on long-press — add the entries to the **same** toolbar through the engine's
   context-menu hook, as the first group), show at most 5 suggestions (`suggest`) as menu items (selecting one replaces the word with one
   `applyEdits`, preserving the first letter's case when the original started upper-case); then a divider and: **Ignore** (session),
   **Add to dictionary** (only when `canAddToDictionary`), and **Disable spell check** (sets `editor.spellcheck` false after a confirm
   snackbar with Undo). Tapping a word on Android does not open the menu (it would fight with caret placement); there the toolbar
   entries appear after a double-tap/long-press selection of an underlined word.
7. Commands: `editor.toggle-spellcheck` ("Toggle spell check", no default shortcut; also reachable from the Settings switch).
   Settings rows exist from 07.1; Settings → Editor → Spell check shows the language list (chips of BCP-47 tags with an "Add language"
   field), the status line (`spellcheckStatusAvailable` / `spellcheckNoSystemChecker` / `spellcheckLanguageUnavailable(tag)`).
8. Privacy: nothing leaves the device — both OS services are local; add one line to the Settings description
   (`settingEditorSpellcheckDescription`: "Uses your device's own spell checker. Text is not sent anywhere by Tephra.").

**Tests**
- `checkable_ranges_test.dart` (pure): a note with frontmatter, a heading, a paragraph with `code`, a fenced block, `$x$`, a URL, a tag,
  `[[Target|Alias word]]`, an HTML tag and `%%comment%%` → exactly the expected ranges (assert the substrings); URL splitting; offsets in a
  note containing emoji stay correct.
- `spell_check_controller_test.dart` (fake `SpellCheckService` flagging the word `teh` and returning suggestion `the`): decorations
  appear 400 ms after typing (fake async); only changed paragraphs are re-checked (count calls); word under caret not flagged right after typing;
  all-caps/short/digit tokens ignored; two languages → intersection; `isAvailable` false → no decorations; setting off → decorations cleared;
  choosing a suggestion replaces the word in one undo step and keeps capitalisation (`Teh` → `The`); Ignore removes the underline for
  that word in the session; Add to dictionary calls the service (Windows fake) and is absent when `canAddToDictionary` is false.
- `spell_check_service_windows_test.dart` (tag `windows-only`; `skip: !Platform.isWindows`): service available on the dev machine;
  `check('This is teh test', 'en-US')` reports one issue at `[8, 11)`; `suggest('teh', 'en-US')` contains `the`; `supportedLanguages(['en-US',
  'xx-ZZ'])` returns only `en-US`.
- Manual: Android phone — type a misspelling in a note: underline appears, long-press word → suggestion replaces it; Windows — same with
  right-click, plus **Add to dictionary** removes the underline in all notes.

**Verify**
```
cd app; flutter test test/editor/spell; cd ..
cd app; flutter test --tags windows-only test/editor/spell; cd ..
dart run tool/check_licenses.dart
```
Success: tests pass; licence check passes (win32 BSD-3-Clause); manual notes recorded; the typing-latency benchmark (Phase 2 harness)
with spell check on stays under 16 ms p95.

**Pitfalls**
- COM calls must run on the UI isolate where COM was initialised; never call them inside `Isolate.run`.
- `ISpellChecker.Check` returns offsets in UTF-16 units — correct for Dart. Do not convert.
- Not every Android device has a spell checker enabled; the null result is normal, not an error (log at `fine`).

---

### 07.17 RTL text, paste HTML as Markdown, block drag handle

**Purpose.** Three editor features that all work on paragraphs/blocks: per-paragraph text direction, converting pasted rich text,
and moving blocks with a handle in Live Preview.

**Files**
- `packages/tephra_markdown/lib/src/bidi.dart` (new, exported: `ParagraphDirection`, `detectParagraphDirection`)
- `packages/tephra_markdown/test/bidi_test.dart` (new)
- `packages/tephra_io/lib/src/html/clipboard_html.dart` (new, exported: `extractClipboardHtmlFragment`) and
  `packages/tephra_io/test/html/clipboard_html_test.dart` (new)
- `app/lib/reading/` renderer files (modify: per-block `Directionality`)
- the engine adapter's per-line builder (modify: direction, see item 3)
- `app/lib/editor/paste/paste_handler.dart`, `paste_html_converter.dart` (new; extend the Phase 1 attachment-paste handler recorded in the
  Name map)
- `app/lib/editor/blocks/block_model.dart` (new; pure), `block_mover.dart` (new; pure), `block_drag_handle.dart`, `commands.dart` (new)
- `app/lib/editor/editor_controller.dart` (modify: two geometry members, item 7)
- tests listed under **Tests**

**Implementation**

A. **RTL per paragraph**
1. `enum ParagraphDirection { ltr, rtl, neutral }`. `ParagraphDirection detectParagraphDirection(String line)`:
   1. Strip a Markdown prefix with `^\s*(?:>\s*)*(?:(?:[-*+]|\d+[.)])\s+(?:\[.\]\s+)?|#{1,6}\s+)?` (blockquote markers, list markers,
      task box, heading marks) and any leading `[!type]` callout marker.
   2. Scan the remaining text by code point; skip whitespace, ASCII digits, punctuation, symbols and Markdown markers
      (`* _ ~ = ` [ ] ( ) < > |`), emoji and combining marks. The first **letter** decides: **rtl** if its code point is in
      U+0590–U+05FF (Hebrew), U+0600–U+06FF, U+0750–U+077F, U+08A0–U+08FF (Arabic), U+0700–U+074F (Syriac), U+0780–U+07BF (Thaana),
      U+07C0–U+07FF (N'Ko), U+FB1D–U+FDFF, U+FE70–U+FEFF (presentation forms), U+10800–U+10FFF, U+1E800–U+1EFFF; any other letter
      (`\p{L}`, including Bangla) → **ltr**. No letter found → **neutral**.
2. **Paragraph = block**: direction is computed per block using the block's first line (paragraph, heading, list item, blockquote line group,
   callout, table cell; code blocks, math blocks and frontmatter are always LTR). `neutral` blocks take the document default:
   `editor.rightToLeft` true → rtl, else ltr.
3. **Reading view:** wrap each block's widget in `Directionality(textDirection: d, child: …)` with `textAlign: TextAlign.start`; lists
   put bullets/numbers on the right in rtl; blockquote/callout bars on the right in rtl; table cell alignment follows the column's
   explicit alignment, else the cell's direction. Do not touch the nesting of an inline LTR phrase inside an RTL paragraph — the Unicode
   bidirectional algorithm in the text layout handles it.
4. **Editor (Source and Live Preview):** decision tree, record the branch taken in `PROGRESS.md`:
   - **Branch 1 (preferred):** the engine adapter can lay out each line with its own `TextDirection` (re_editor: check whether a line's
     `TextPainter` takes a direction from the ambient `Directionality`; for B/C: per-paragraph `RichText`/render objects). If yes:
     apply the direction of the paragraph containing the line, and align the line `TextAlign.start`.
   - **Branch 2 (fallback):** the engine uses one direction for the whole editor. Then the **whole editor** uses the direction of the
     first non-neutral paragraph of the note (re-evaluated on note open and when the first paragraph's direction changes, max once per
     second), and the reading view remains per paragraph. State this limitation in `PROGRESS.md`.
   Arrow keys and selection behave visually as the engine does; do not remap them.
5. Setting `editor.rightToLeft` (07.1) only changes the default for neutral paragraphs and for new empty notes. Command
   `editor.toggle-rtl-default` is **not** added (Settings only).

B. **Paste HTML → Markdown** (setting `editor.autoConvertHtml`, default true)
1. Clipboard reading. Phase 1 chose `pasteboard` (images/files), which cannot read HTML, and `super_clipboard` is **not** used
   (it needs a Rust toolchain). Order: image (existing Phase 1 `pasteboard` behaviour wins: pasted bitmap → attachment); then HTML via a
   `ClipboardHtmlReader` interface in `app/lib/core/platform/clipboard_html_reader.dart` → Windows implementation with `package:win32`
   (already added for spell check): `RegisterClipboardFormat('HTML Format')`, `IsClipboardFormatAvailable`, `OpenClipboard(NULL)`,
   `GetClipboardData`, `GlobalLock` / `GlobalSize` / `GlobalUnlock`, copy the bytes, `CloseClipboard()` in a `finally`; decode as UTF-8 (allowMalformed)
   and pass the string to `extractClipboardHtmlFragment` below. Android implementation returns `null` (Android paste delivers plain text through
   the editor; HTML paste is Windows-only — record that in `PROGRESS.md`). Then plain text via `Clipboard.getData(Clipboard.kTextPlain)`. Ctrl+Shift+V and the context-menu item **Paste as plain text** always use plain text (command
   `editor.paste-plain`, default Ctrl+Shift+V).
2. **Windows clipboard HTML format ("HTML Format", CF_HTML).** Windows delivers HTML as UTF-8 bytes with a text header:
   ```
   Version:0.9
   StartHTML:0000000105
   EndHTML:0000000530
   StartFragment:0000000141
   EndFragment:0000000494
   <html><body>
   <!--StartFragment-->…the copied part…<!--EndFragment-->
   </body></html>
   ```
   Offsets are **byte** offsets from the start of the clipboard data. The Win32 read returns the raw data including this header; still handle every case, because other apps write sloppy headers, so `extractClipboardHtmlFragment(String raw)` handles every case, in order:
   1. If `raw` starts with `Version:` → parse `StartFragment`/`EndFragment` (decimal ints); `bytes = utf8.encode(raw)`; if both are valid and
      `0 <= start < end <= bytes.length` → `utf8.decode(bytes.sublist(start, end), allowMalformed: true)`. Else go to step 2.
   2. If `raw` contains `<!--StartFragment-->` and `<!--EndFragment-->` → the text between them.
   3. If `raw` starts with `Version:` but nothing above worked → drop all header lines (up to the first line that begins with `<`).
   4. Otherwise `raw` unchanged. Android and web clipboards deliver plain HTML fragments → case 4.
3. **Decision (`PasteHtmlConverter.decide`)** returns `PasteDecision.plain` or `PasteDecision.markdown(String md)`:
   - plain when: setting off; caret inside a fenced code block, inline code, math, frontmatter or a `%%` comment; multi-cursor active
     (07.14); Ctrl+Shift+V; no HTML on the clipboard;
   - plain when the HTML contains **none** of the tags `a, img, h1, h2, h3, h4, h5, h6, ul, ol, li, table, blockquote, pre, strong, b, em,
     i, code, del, s, mark, hr` and the clipboard also has plain text (typical for text copied from code editors and terminals);
   - otherwise convert with `HtmlToMarkdown.convert(fragment, options: HtmlConvertOptions(rewriteImage: …, baseIndent: '\t'))` (Phase 5
     name; `rewriteLink` left null); `data:` image sources → decode base64 and save through the Phase 1/4 attachment service
     (§6.7 naming `Pasted image YYYYMMDDHHmmss.<ext>`; add `-1`, `-2` when the second collides) and return `![[<saved name>]]`; remote
     `http(s)` images stay `![alt](url)` (no download). If the converted Markdown (trimmed, whitespace-normalised) equals the plain text
     (trimmed, whitespace-normalised) → plain.
   - Conversion runs in `Isolate.run` when the fragment is > 200 KB; otherwise inline (the converter is async because of `rewriteImage`).
   - If conversion throws → log at `warning`, fall back to plain text, show no error to the user.
4. Insert through one `applyEdits` (the selection replaced); put the caret after the inserted text. Phase 1's paste interception point
   (the intent/action override for paste, from the Name map) calls `PasteHandler.handle()` for Ctrl+V, the context menu and the Android
   selection toolbar **Paste**.
5. Multi-paragraph pasted Markdown inside a list item or blockquote: if the caret line starts with a list marker or `> `, prefix every
   following pasted line with the same indentation/quote prefix (leading whitespace of the caret's line up to the content start; for `>`
   repeat the `> ` prefix). Do not do this for fenced content.

C. **Block drag handle (Live Preview, desktop layout with a pointer)**
1. **Geometry members** on `EditorController` (additive): `Rect? rectForOffset(int offset)` (global rect of the line box containing the
   offset — generalise the function that already produces `caretRectGlobal()`; `null` when not laid out) and
   `int? offsetForGlobalPosition(Offset global)` (inverse hit test). Implement for the chosen engine by reusing the layout objects the
   engine uses to place its own caret and to map pointer positions to offsets; write the exact engine members used into the Name map.
   If neither can be reached without forking the engine package, **stop and ask the human**.
2. **Block model** (`block_model.dart`, pure): from `ParsedNote` build `List<MovableBlock { int start; int end; BlockKind kind; int containerId; }>`:
   - top-level children of `MdDocument` except `MdFrontmatter`: paragraph, heading (the heading **line only**, not its section — the Outline
     pane moves sections), list (**each top-level item is its own block**, with its nested items), code block, math block, table,
     blockquote/callout (whole), thematic break, HTML block, footnote definition;
   - `containerId` = the list's node start for list items, `0` for document level. A block can only be dropped among blocks of the same
     container (list items stay in their list, document blocks stay at document level).
   - Range: `start` = start of the block's first line; `end` = start of the next block's first line in the same container (so the block
     "owns" its trailing blank lines); for the last block of a container `end` = end of its last line + its trailing `\n`s up to the end of the container.
3. **Mover** (`block_mover.dart`, pure): `TextEdit moveBlock(String text, List<MovableBlock> blocks, int fromIndex, int toIndex)` where
   `toIndex` is the **insertion slot** `0..blocks.length` among the blocks of the same container (slot `k` = before block `k`;
   `toIndex == fromIndex` or `fromIndex + 1` → no-op, return `null`). Algorithm:
   1. Units = block texts `text.substring(start, end)`. Let `sep(u)` = the trailing newline run of unit `u` (`\n`, `\n\n`, …; empty for a
      final unit that has no trailing newline).
   2. Reorder the units. For every unit that is **not last after the move**: if its trailing newline run is shorter than the
      container's `defaultSep` (the most common `sep` among the other units; `\n\n` for document level if none, `\n` for list items if none),
      pad it with `\n` up to `defaultSep`. For the unit that **is last after the move**: trim its trailing newlines and append the original
      trailing newline run of the old last unit (so the file ending is unchanged).
   3. The edit replaces `[min(start of from, start of to-slot) , max(end of …))` — the smallest contiguous range containing every
      reordered unit between the two positions — with the reordered text. Exactly **one** `TextEdit`; the caller applies it with
      `applyEdits` (one undo step); then select the moved block's first line.
4. **UI** (`block_drag_handle.dart`): only when the layout is desktop, the editor is in Live Preview, and the pointer hovers: a
   `MouseRegion` over the editor tracks the pointer; the block under it comes from `offsetForGlobalPosition` → block index. Show a
   6-dot grip (`Icons.drag_indicator`, 20 dp, `textFaint`, becomes `textMuted` on hover, 32 dp hit target) in a 24 dp gutter to the left of the
   block's first line (`rectForOffset(block.start)`); the gutter exists only in Live Preview. Hidden for single-block notes, frontmatter, and
   while text is being selected or the vim mode is in Normal/Visual (vim has no mouse handles) or extra carets exist.
   - Drag: `GestureDetector.onVerticalDragStart/Update/End` (also accept horizontal movement). During drag, the pointer's Y → nearest slot
     among same-container blocks (slot Y = `rectForOffset(block.start).top`; last slot = bottom of the last block); draw a 2 dp
     `interactiveAccent` horizontal line at the slot Y (an `OverlayEntry`), and dim the dragged block with a 40% `backgroundModifierHover`
     overlay rectangle spanning its lines. Auto-scroll the editor when the pointer is within 48 dp of the top/bottom edge
     (`revealOffset` of the neighbouring block each 50 ms). Esc cancels. Drop → `moveBlock` → `applyEdits`.
   - Accessibility: the handle has `Semantics(label: l10n.blockDragHandle, customSemanticsActions: {moveUp, moveDown})`; keyboard users
     use the commands below.
5. **Commands:** `editor.move-block-up` ("Move block up") and `editor.move-block-down` ("Move block down") — default shortcuts Ctrl+Alt+Shift+Up/Down
   (desktop) and listed in the palette on phone (no handle on phone). Block = the block containing the caret; same `moveBlock` code with
   slots `index - 1` / `index + 2`; caret stays in the moved block. Available in Source and Live Preview mode, and on phone layout.

**Tests**
- `bidi_test.dart`: `Hello` ltr; `שלום עולם` rtl; `مرحبا` rtl; `- [ ] مهمة` rtl (prefix stripped); `# 123 مرحبا` rtl (digits skipped);
  `> **שלום**` rtl; `123 - !` neutral; `আমি বাংলায়` ltr; `😀 hello` ltr; `1. שלום` rtl; mixed `hello שלום` ltr (first strong decides); empty
  string neutral.
- `clipboard_html_test.dart`: header sample above (compute offsets in the test from the string, not hard-coded, using UTF-8 byte
  lengths) returns exactly the fragment; header with multi-byte characters (`é`, `日本`) — offsets are bytes; broken offsets fall back to
  the `<!--StartFragment-->` markers; no header returns input; header without markers drops header lines.
- `paste_html_converter_test.dart` (fake attachment service): HTML with `<b>`, `<a>`, `<ul>` → Markdown; HTML of only `<span>`/`<div>` plus plain
  text → plain; data-URI image → saved `Pasted image …png` and `![[…]]`; caret in fenced code → plain; setting off → plain; Ctrl+Shift+V →
  plain; converted equals plain → plain; converter throws → plain, no UI error; list continuation prefix applied inside a list item; single
  `applyEdits` call.
- `block_model_test.dart`: frontmatter excluded; list items individual with nested children; container ids; ranges include trailing blank
  lines; last block range.
- `block_mover_test.dart` (pure, table-driven on strings): move paragraph down/up in a document with 3 paragraphs (assert the exact result
  string, blank lines preserved); move the last paragraph to the top (no trailing blank line left dangling; final newline state equals the
  original); move a list item with nested children within its list; no-op slots return null; moving a heading moves only its line; CRLF-free
  (text is `\n` normalised); moving into the slot after the last block; moving a block across a fenced code block.
- `block_drag_handle_test.dart` (widget, fake geometry): handle appears on hover only in Live Preview + desktop width; hidden on phone
  width; drag from block 0 below block 2 shows the indicator at slot 3 and drops with one `applyEdits`; Esc cancels.
- Reading-view widget test: an RTL paragraph is wrapped in `Directionality(rtl)`; a list renders markers on the right.

**Verify**
```
cd packages/tephra_markdown; dart test test/bidi_test.dart; cd ../..
cd packages/tephra_io; dart test test/html; cd ../..
cd app; flutter test test/editor test/reading; cd ..
```
Manual on Windows: copy a web page section from Edge and a formatted Word paragraph → paste → Markdown with bold/links/lists; copy code
from VS Code → plain. Drag a paragraph with the handle; Ctrl+Z restores in one step. Manual on Android: copy from Chrome → paste converts.
Success: all pass; manual notes recorded.

**Pitfalls**
- CF_HTML offsets are **bytes**, never string indices; slicing the Dart string with them corrupts non-ASCII text.
- Pasting must never lose data: when unsure, paste the plain text.
- The block mover must not change any text outside the reordered range (assert in the test: prefix and suffix identical).

### 07.18 Accessibility: semantics, list alternatives, keyboard navigation, contrast, text scaling

**Purpose.** Every screen usable with a screen reader (TalkBack on Android, Narrator on Windows) and, on Windows, with the keyboard
only; all bundled themes pass WCAG contrast; text scales to 200% without clipping.

**Files**
- `app/lib/core/a11y/focus_ring.dart`, `focus_regions.dart`, `semantic_helpers.dart` (new)
- `app/lib/theme/app_theme.dart` (modify: focus styling, item 4 of section C)
- `app/lib/theme/contrast.dart` (new; pure Dart: `relativeLuminance`, `contrastRatio`, `compositeOver`)
- `app/lib/graph/view/graph_accessible_list.dart`, `app/lib/canvas/view/canvas_accessible_list.dart` (new)
- `app/lib/graph/view/graph_view.dart`, `app/lib/canvas/view/canvas_view.dart` (modify: semantics wrapper + list toggle)
- the controls listed in the table of section A (modify)
- `app/test/theme/contrast_test.dart` (the file created in 07.3; complete it here)
- `app/test/a11y/semantics_guidelines_test.dart`, `source_rules_test.dart`, `keyboard_navigation_test.dart`,
  `graph_accessible_list_test.dart`, `canvas_accessible_list_test.dart`, `text_scale_golden_test.dart` (new)
- `docs/accessibility-audit.md` (new: the manual audit results table, filled in during the gate; this is a project document requested by
  this step, not a report file)

**Implementation**

**A. Semantics.** Rules, then the per-component table.
1. Rules: (a) every interactive widget has a non-empty spoken label from l10n; (b) state is exposed (`selected`, `checked`, `expanded`,
   `toggled`, `enabled`); (c) decorative icons/images are wrapped in `ExcludeSemantics`; (d) never rely on colour alone — error states
   also show an icon and text, unresolved links also differ by style (dashed underline), graph node kinds also differ by shape (note =
   circle, tag = rounded square, attachment = diamond, unresolved = hollow circle — update `GraphPainter` if Phase 6 used only colour);
   (e) toasts/snackbars and the vim/word-count messages are `liveRegion: true`; (f) focus is moved to the first field of every dialog and
   returned to the opener on close; (g) touch targets ≥ 48×48 dp on phone layout (≥ 32×32 dp desktop).
2. Source rules enforced by `source_rules_test.dart` (scans `app/lib/**/*.dart`; allowlist file `app/test/a11y/allowlist.txt` with one
   `path:line reason` per justified exception):
   - every `IconButton(` call has a `tooltip:` argument (the tooltip is the spoken label) — pattern check over the call's argument list
     (balanced parentheses scan);
   - every `GestureDetector(` / `InkWell(` with `onTap:`/`onLongPress:` has a `Semantics(` ancestor in the same file within 15 lines **or**
     the line `// a11y: <reason>` directly above;
   - no `Text(` receives `e.toString()`, `$e`, `e.message` or `error.toString()` (also a 07.19 rule).
3. Per-component requirements (implement each; widget tests in `semantics_guidelines_test.dart` use
   `tester.ensureSemantics()` and assert labels/flags with `find.bySemanticsLabel` and `SemanticsController`):
   | Component | Required semantics |
   |---|---|
   | Ribbon / drawer / toolbar buttons | tooltip label; toggle buttons (recording, vim) expose `toggled` |
   | Tab (desktop) | `button: true, selected: isActive`, label `"<title>, tab N of M"` (+ `, pinned`), custom action **Close** (unless pinned), custom actions **Move left/right** |
   | Explorer tree row | `label: name`, `expanded` for folders, `hint: "level N"`, custom actions **Rename**, **Delete**, **Open in new tab** |
   | Editor | one `Semantics(textField: true, multiline: true, label: l10n.editorSemanticsLabel(noteTitle))` around the engine widget; do not add per-line semantics |
   | Reading view | headings `header: true` with `headingLevel` (Flutter 3.x `SemanticsProperties.headingLevel`); links `link: true` with the target as hint; images label = alt text or file name; checkboxes `checked` |
   | Properties panel | label/value pairs read as one node per row (`MergeSemantics`) |
   | Search results | each hit: `"<file>, line N, <snippet>"`; result count announced via live region when results settle |
   | Backlinks/outgoing/tags/bookmarks/outline rows | label + `button`; outline row hint `level N` |
   | Sliders (settings, zoom) | `Semantics(value: "<n> percent/pixels")`, increase/decrease actions work |
   | Colour swatches (theme editor, picker) | label = token name + hex + contrast result (`"Text normal, #1F1D1B, contrast 14.2 to 1, passes"`) |
   | Theme preview | `ExcludeSemantics` (decorative; the token rows carry the information) |
   | Audio recorder bar | live region announcing `mm:ss` every 10 s while recording (not every second); Stop/Cancel labelled |
   | Block drag handle (07.17) | label + custom actions **Move up**, **Move down** |
   | Status bar items | label + value (`"1,234 words"`); vim mode `liveRegion` |
   | Graph / Canvas (custom painted) | container label (item 4) + accessible list alternative |
4. **Graph and canvas alternatives.**
   - `GraphView`: wrap `GraphCanvas` in `Semantics(container: true, label: l10n.graphSemanticsLabel(nodeCount, edgeCount), hint:
     l10n.graphSemanticsHint)` and exclude the painted children from semantics (`ExcludeSemantics`). Add a toolbar toggle **List view**
     (`Icons.list`, tooltip `graphShowList`). When `MediaQuery.of(context).accessibleNavigation` is true the list view is the **default**
     (user can switch back; the choice is remembered per session). `GraphAccessibleList`: a virtualised `ListView.builder` over
     `GraphModel` nodes sorted by label (case-insensitive), with a search field on top (filters labels). Each row: label, kind (note,
     attachment, tag, unresolved — l10n), `"<n> links"`; activating a note/attachment row opens the file (same as a graph click); an expand
     button lists its neighbours (outgoing and incoming) as rows (activating one opens it; a **Focus in graph** custom action selects that
     node in the graph and switches back to the graph view). Local graph: same list restricted to the local model.
   - `CanvasView`: container label `l10n.canvasSemanticsLabel(nodeCount, edgeCount)`; toolbar toggle **List view**; default list when
     `accessibleNavigation`. `CanvasAccessibleList`: nodes in reading order = sorted by `y` then `x` (nodes whose `y` differ by < 40 are
     one row group, ordered by `x`). Row text: type label (Text card / Note / Media / Web page / Group), then: text → the first 120 characters;
     file → the file name; link → the URL host; group → its label and the count of contained nodes; then the colour name (if any) and
     `"connects to <label>"` for each outgoing edge (label = the target's row text, max 40 chars). Activating a row: file nodes open the file,
     link nodes open `LinkRouter.openExternal` (canvas uses the browser — keep Phase 6 behaviour: pass `forceBrowser: true`), text/group rows
     do nothing. The list is read-only (editing a canvas needs the pointer view; state this in `canvasListReadOnlyHint`).
   - Bases (Phase 6) already render as tables/cards → ensure `Table`/`DataTable` semantics (column headers `header`, sortable columns expose
     `onTap` + `sortKey`).

**B. Keyboard-only navigation (Windows).**
1. Focus order: wrap the desktop shell in `FocusTraversalGroup(policy: OrderedTraversalPolicy())` and give each region a
   `FocusTraversalOrder(order: NumericFocusOrder(n))`: 1 ribbon, 2 left sidebar (active panel), 3 tab bar, 4 editor/view content,
   5 right sidebar, 6 status bar. Inside a region, use `ReadingOrderTraversalPolicy`.
2. **Region cycling:** commands `app.focus-next-region` (F6) and `app.focus-previous-region` (Shift+F6) move focus to the next/previous
   region that is visible, landing on its **last focused** control (remember per region; first control the first time). `focus_regions.dart`
   keeps `Map<FocusRegion, FocusNode>`. Escape inside a sidebar returns focus to the editor.
3. Required keyboard behaviour (implement what is missing; `keyboard_navigation_test.dart` covers each row):
   | Control | Keys |
   |---|---|
   | Explorer tree | Up/Down move; Right expands / moves to first child; Left collapses / moves to parent; Enter opens; F2 rename; Delete delete; Menu key or Shift+F10 context menu |
   | Tab bar | Left/Right move focus between tabs; Enter/Space activate; Ctrl+W close; Delete closes; Menu key = tab context menu |
   | Lists (search results, backlinks, outline, tags, bookmarks, command palette, quick switcher, accessible graph/canvas lists) | Up/Down; Enter activate; Home/End first/last; type-ahead not required |
   | Context menus, popups, dialogs | Escape closes; focus trapped inside dialogs; Tab/Shift+Tab cycle; initial focus on the first field or the primary button |
   | Settings | Tab order follows visual order; Space toggles switches; Left/Right adjusts sliders (step) |
   | Graph/canvas pointer views | keyboard users use the list alternative (A.4); canvas toolbar buttons are focusable |
   | Theme editor | token rows focusable; Enter opens the colour picker; arrows move between swatches |
   `ContextMenu` key and Shift+F10: add `Shortcuts` mapping `LogicalKeyboardKey.contextMenu` and `shift+f10` to `ShowContextMenuIntent` handled by
   explorer rows, tabs, links in reading view, and the editor.
4. **Visible focus indicator.** Theme (in `AppTheme.build`): `focusColor = focusRing @ 20% alpha` (fill), `hoverColor = backgroundModifierHover`;
   for **Material buttons** (`IconButton`, `TextButton`, `FilledButton`, `OutlinedButton`, `ElevatedButton`, `SegmentedButton`) set the
   theme `style` with `side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? BorderSide(color: focusRing, width: 2) : null)`
   (and `IconButtonThemeData` likewise); `inputDecorationTheme.focusedBorder = OutlineInputBorder(borderSide: BorderSide(color: focusRing, width: 2))`;
   `SwitchThemeData`/`CheckboxThemeData` `overlayColor` focused = `focusRing @ 30%`; `ListTile`/`ListTileTheme` focus = `focusColor` fill **plus**
   the 2 dp left bar `FocusRing` below. **Custom controls** (tabs, explorer rows, ribbon buttons, canvas toolbar, graph toolbar) use the new
   `FocusRing` widget: `FocusRing({required Widget child, FocusNode? focusNode, BorderRadius? radius})` draws a 2 dp `focusRing` outline offset 1 dp
   outside the child when the node has **keyboard** focus (`FocusManager.instance.highlightMode == FocusHighlightMode.traditional`), nothing on
   mouse/touch focus. The outline colour meets 3:1 against both backgrounds (07.3 tokens do).

**C. Contrast (WCAG 2.x) — automated.**
1. `contrast.dart` (pure): `double relativeLuminance(Color c)`: for each channel `v = channel / 255`, `lin = v <= 0.04045 ? v / 12.92 :
   pow((v + 0.055) / 1.055, 2.4)`, `L = 0.2126 * R + 0.7152 * G + 0.0722 * B`. `double contrastRatio(Color a, Color b)` = `(Lmax + 0.05) / (Lmin + 0.05)`.
   `Color compositeOver(Color fg, Color bg)` blends a translucent colour (`alpha` channel) over an opaque background, per channel
   `round(fg * a + bg * (1 - a))`, result opaque. Use the same functions in the theme editor (07.4) and the accent logic (07.5).
2. `contrast_test.dart`: for **each of the four bundled themes** (read from `app/assets/themes/*.json` through `ThemeFile`), assert the
   following. Failure messages must print theme id, both token names, both hex values and the ratio.
   - **Text pairs, ratio ≥ 4.5:** `textNormal` on `backgroundPrimary`, `backgroundPrimaryAlt`, `backgroundSecondary`, `backgroundSecondaryAlt`,
     `interactiveNormal`; `textNormal` on `textSelection` composited over `backgroundPrimary`; `textNormal` on `textHighlightBg`;
     `textMuted` on `backgroundPrimary`, `backgroundSecondary`, `backgroundSecondaryAlt`; `textAccent` on `backgroundPrimary`, `backgroundSecondary`,
     `backgroundSecondaryAlt`; `linkInternal`, `linkExternal`, `linkUnresolved` on `backgroundPrimary`; `heading1Color`…`heading6Color` on
     `backgroundPrimary`; `textError` on `backgroundPrimary` and on `backgroundModifierError`; `textSuccess`, `textWarning` on `backgroundPrimary`;
     `textOnAccent` on `interactiveAccent`; `tagText` on `tagBackground` and on `backgroundPrimary`; `codeNormal` on `codeBackground`;
     `graphText` on `canvasBackground`.
   - **Non-text pairs, ratio ≥ 3.0 (WCAG 1.4.11):** `focusRing` on `backgroundPrimary` and on `backgroundSecondary`; `checkboxBorder`,
     `checkboxChecked`, `interactiveAccent` on `backgroundPrimary`; `graphNode`, `graphNodeTag`, `graphNodeAttachment`, `graphNodeFocused` on
     `canvasBackground`; `textFaint` on `backgroundPrimary` (placeholder/disabled text; the 4.5 rule is waived for disabled controls only).
   - **High-contrast themes only, additionally ≥ 3.0:** `backgroundModifierBorder`, `dividerColor`, `hrColor` on `backgroundPrimary`; `graphLine`
     on `canvasBackground`.
   - **Explicitly exempt (decorative or redundant with text/shape):** `backgroundModifierBorder`, `dividerColor`, `hrColor`, `graphLine`,
     `graphNodeUnresolved`, `canvasGrid` in the two non-high-contrast themes; `canvasColor1`…`6` as fills (card labels use `textNormal` on the
     card tint, tested below).
   - Canvas card text: for each `canvasColorN`, `textNormal` on `compositeOver(canvasColorN @ CanvasColors.cardFillAlpha, canvasBackground)`
     ≥ 4.5 (use the alpha constant Phase 6's `CanvasColors` uses for card fills; if it has none, add `static const double cardFillAlpha = 0.15`
     and use it in the painter).
   Computed on 2026-10-11 these all pass for the values in 07.3 (the non-exempt non-text ratios: light focusRing 5.45 on white; dark 7.55 on
   `#1C1B1A`). If a bundled value fails, change the **theme value** (not the test) by the smallest lightness step that passes and record it.
3. **Imported/user themes:** the theme editor (07.4) shows the pair ratios; no hard block on saving. Accent override (07.5) is
   enforced by the tests of 07.5.
4. `AppTheme` runs the same checks in debug mode only for the **active** theme and logs `warning` for failures (`Logger('theme')`).

**D. Text scaling to 200%.**
1. Rules: never give a text-bearing container a fixed `height`/`width` (use `ConstrainedBox(constraints: BoxConstraints(minHeight: …))`,
   `IntrinsicHeight`, or `Flexible`/`Expanded`); icon-only controls keep fixed sizes; the desktop tab bar height = `max(36, 36 * textScale)`
   capped at 72 dp, with tab titles `maxLines: 1, overflow: TextOverflow.ellipsis`; the status bar wraps to two lines at scale > 1.5; dialog
   contents scroll (`SingleChildScrollView`); `Row`s of labelled controls that can overflow use `Wrap` or `Flexible`.
2. Goldens (`text_scale_golden_test.dart`, `@Tags(['golden'])`): for each screen below and each scale in `{1.0, 1.5, 2.0}` pump the screen inside
   `MediaQuery(data: base.copyWith(textScaler: TextScaler.linear(scale)))` at the stated size with the `tephra-light` theme, assert
   `tester.takeException() == null` (no RenderFlex overflow) and `matchesGoldenFile('goldens/a11y/<screen>_<scale>x.png')`.
   | Screen | Size (logical px) |
   |---|---|
   | Vault picker / welcome | 400 × 800 |
   | Phone shell with explorer drawer open | 400 × 800 |
   | Phone note view with keyboard toolbar | 400 × 800 |
   | Quick switcher | 400 × 800 and 1280 × 800 |
   | Command palette | 1280 × 800 |
   | Settings → Editor, Appearance, Core plugins | 400 × 800 |
   | Settings dialog | 1280 × 800 |
   | Properties panel with 5 property types | 400 × 800 |
   | Search pane with results | 400 × 800 |
   | Backlinks pane | 400 × 800 |
   | Sync status screen | 400 × 800 |
   | Theme editor | 1280 × 800 |
   | Desktop shell: tab bar + status bar | 1280 × 800 |
   | Confirm-delete dialog | 400 × 800 |
   | Every empty state (07.19), one golden each at 2.0 only | 400 × 800 |
   Generate the goldens on Windows; commit them.
3. The interface zoom (07.5) multiplies the OS scale; the golden test fixes zoom at 1.0.

**E. Manual screen-reader audit** (results go into `docs/accessibility-audit.md`, one row per flow × platform: pass/fail + note; every
fail is fixed or listed under "Known issues" with a reason).
- **TalkBack (Android phone):** enable in Settings → Accessibility → TalkBack. Gestures: swipe right/left next/previous item; double-tap
  activate; two-finger scroll; explore by touch. Flows: (1) open vault from the picker; (2) open explorer drawer, open a note; (3) read
  the note (headings navigable by the reading-controls "Headings" setting); (4) edit text and use the keyboard toolbar buttons (each
  announces its name); (5) create a note; (6) rename via the explorer row's custom actions (Actions menu); (7) search and open a result;
  (8) open Settings and change a switch and a slider; (9) open the graph (list view appears by default), open a note from it; (10) open a
  canvas list and open a file card; (11) start/stop the audio recorder; (12) trigger an error (open a read-only file) and hear the message.
- **Narrator (Windows):** start with Win+Ctrl+Enter. Keys (Narrator key = Caps Lock or Insert): Narrator+Right/Left next/previous item,
  Narrator+Enter activate, Narrator+Space toggle scan mode, Ctrl stops speech. Flows: same 12, plus (13) pop-out window title announced,
  (14) tab context-menu actions, (15) the command palette announces results as the list changes.
- **Keyboard-only (Windows, no mouse for the whole session):** (1) launch, open a vault with the picker; (2) Ctrl+O to open a note;
  (3) F6 through every region and back; (4) create, edit, rename, delete a note; (5) open Settings (Ctrl+,), change five settings of
  different types; (6) open the graph list and a canvas list; (7) split the pane and move focus between groups (Ctrl+Alt+Arrow);
  (8) open and close every dialog with Escape; (9) context menus via Shift+F10; (10) the theme editor: change a colour.
  Every focused control must show the focus ring (07.18 B.4).

**Tests** (summary — files above): `contrast_test.dart` (C.2 + `contrast.dart` unit tests: black/white = 21.0, `#777777` on white =
4.48 (fails 4.5), `#767676` on white = 4.54 (passes), alpha compositing); `semantics_guidelines_test.dart`: for the phone shell, Settings, quick
switcher, explorer, properties, search pane and tab bar run `expectLater(tester, meetsGuideline(textContrastGuideline))`,
`meetsGuideline(labeledTapTargetGuideline)` and (phone width) `meetsGuideline(androidTapTargetGuideline)`; `source_rules_test.dart`;
`keyboard_navigation_test.dart` (tab order through the six regions with F6; arrow keys in the explorer tree; Escape closes dialog; focus ring
painted on keyboard focus and not on mouse focus); `graph_accessible_list_test.dart` (list default under `accessibleNavigation`; rows sorted;
activate opens a note; neighbour expansion; focus-in-graph action); `canvas_accessible_list_test.dart` (reading order with the 40-unit row
tolerance; edges described; file row opens; link row uses the browser); `text_scale_golden_test.dart`.

**Verify**
```
cd app; flutter test test/theme/contrast_test.dart test/a11y; cd ..
cd app; flutter test --tags golden test/a11y; cd ..
```
Success: tests pass; manual audit table complete with no unexplained failures (gate item).

**Pitfalls**
- Do not add `Semantics` labels that duplicate a tooltip on the same widget (double announcement); use one or the other.
- Golden files differ between machines; generate and compare on the same OS (Windows) only.
- `accessibleNavigation` is true for TalkBack and Narrator but also for switch access; the list view default is correct for all of them.

---

### 07.19 Polish: empty states, motion, plain-language errors, command reachability

**Purpose.** Make every panel explain itself when empty, use one animation specification, show friendly errors, and prove all commands are reachable.

**Files**
- `app/lib/core/widgets/empty_state.dart` (new)
- `app/lib/theme/motion.dart` (new: `AppMotion`)
- `app/lib/core/errors/user_messages.dart` (new)
- `app/lib/commands/command_audit.dart` (new: test-support helpers; lives in `lib/` so integration tests can use it)
- each panel listed in A (modify)
- `app/lib/l10n/app_en.arb` (modify: all new keys)
- `app/test/core/widgets/empty_state_test.dart`, `app/test/theme/motion_test.dart`, `app/test/core/errors/user_messages_test.dart`,
  `app/test/commands/command_reachability_test.dart`, `app/test/a11y/source_rules_test.dart` (extend) (new/modify)

**Implementation**

**A. Empty states.**
1. Widget: `EmptyState({required IconData icon, required String title, String? body, List<EmptyStateAction> actions = const [], bool compact = false})`;
   `EmptyStateAction { String label; VoidCallback onPressed; bool primary }`. Layout: centred column, icon 48 dp (24 dp compact) in
   `textFaint`, title (`titleMedium`, `textNormal`), body (`bodyMedium`, `textMuted`, max width 320 dp, centred), actions as buttons (primary =
   `FilledButton`, others `TextButton`) in a `Wrap`. Wrapped in `Semantics(container: true, label: '<title>. <body>')`. Scrolls if it
   does not fit (200% text scale). `compact` is used in narrow sidebars (< 280 dp wide): icon 24 dp, no body.
2. Required empty states (**every** row is built; l10n key prefix in the last column — keys are `<prefix>Title`, `<prefix>Body`, `<prefix>Action…`):
   | Panel / situation | Title (English) | Body | Actions | Prefix |
   |---|---|---|---|---|
   | Explorer, vault has no notes | This vault is empty | Create your first note or open the Tephra Guide to learn the basics. | New note; New folder; Open Tephra Guide | `emptyExplorer` |
   | Explorer, filter/sort shows nothing | Nothing matches | No files match the current filter. | Clear filter | `emptyExplorerFilter` |
   | Editor area, no tab open (desktop group) | No note is open | Open a note with Quick switcher (Ctrl+O) or create one (Ctrl+N). Recent notes are listed below. | New note; Open quick switcher; up to 5 recent notes as links | `emptyWorkspace` |
   | Phone, no note open | Open a note | Choose a note from the file list or create one. | New note; Open file list | `emptyWorkspacePhone` |
   | Search, before typing | Search your vault | Type words to search. Use operators like `tag:` or `path:` to narrow results. | Show search help | `emptySearchIdle` |
   | Search, no results | No results | Nothing matches “{query}”. Check the spelling or remove an operator. | Clear search | `emptySearchNone` |
   | Backlinks — linked | No backlinks | No other note links to this note yet. | — | `emptyBacklinks` |
   | Backlinks — unlinked mentions | No unlinked mentions | No other note mentions this note's title without linking to it. | — | `emptyUnlinkedMentions` |
   | Outgoing links | No outgoing links | This note doesn't link to other notes. | — | `emptyOutgoing` |
   | Outline | No headings | Add a heading starting with # to see an outline. | — | `emptyOutline` |
   | Tags pane | No tags | Add tags like #idea in your notes and they will appear here. | — | `emptyTags` |
   | Bookmarks | No bookmarks | Bookmark notes, searches and headings to find them quickly. | Bookmark current note | `emptyBookmarks` |
   | Properties panel (note without frontmatter) | No properties | Properties store details like tags and dates at the top of a note. | Add property | `emptyProperties` |
   | Footnotes panel | No footnotes | Add a footnote with [^1] and define it below. | — | `emptyFootnotes` |
   | File recovery, no snapshots | No saved versions yet | Tephra saves a local copy of your notes as you edit. They will appear here. | — | `emptyFileRecovery` |
   | File history of one note | No earlier versions | This note has no saved versions yet. | — | `emptyNoteHistory` |
   | Graph, no notes | Nothing to show | Your vault has no notes yet. | New note | `emptyGraph` |
   | Graph, filters hide everything | All nodes are filtered out | Change the filters to see your graph. | Reset filters | `emptyGraphFiltered` |
   | Canvas, no nodes | Empty canvas | Double-click (or tap +) to add a card. Drag notes from the file list onto the canvas. | Add card; Add note | `emptyCanvas` |
   | Bases, no results | No matching notes | No notes match this base's filters. | Edit filters | `emptyBase` |
   | Stickies list | No sticky notes | Quick notes you pin or colour appear here. | New sticky | `emptyStickies` |
   | Sync, not set up | Sync isn't set up | Keep your notes on all your devices with Google Drive. Your notes are encrypted before they leave this device. | Set up sync | `emptySync` |
   | Sync history, none | No sync activity yet | Activity appears here after the first sync. | — | `emptySyncHistory` |
   | Backups, none | No backups yet | Create a backup to keep a safe copy of your vault. | Create backup | `emptyBackups` |
   | Templates folder, no templates | No templates | Put notes in your templates folder to insert them into new notes. | Open template settings | `emptyTemplates` |
   | Saved workspaces (07.13) | No saved workspaces | Save the current layout to bring it back later. | Save current layout | `emptySavedWorkspaces` |
   | Hotkeys, search no match | No matching commands | Try a different word. | Clear search | `emptyHotkeys` |
   | Command palette, no match | No matching commands | Try a different word. | — | `emptyPalette` |
   | Quick switcher, no match | No matching notes | Press Enter to create “{query}”. | Create note | `emptyQuickSwitcher` |
   | Slides, note has no `---` | One slide | Separate slides with a line containing --- . | — | `emptySlides` |
   | Web viewer (07.11), blank | Enter an address | Type a web address above. | Open home page | `emptyWebViewer` |
   | Import preview, nothing found | Nothing to import | We couldn't find any notes in that file or folder. | Choose another source | `emptyImport` |
   | Theme list, no custom themes | No custom themes | Create a theme or import colours from an Obsidian theme. | New theme; Import Obsidian theme | `emptyThemes` |
   | Accessible graph/canvas list, no nodes | Nothing to list | This view has no items yet. | — | `emptyAccessibleList` |
   Existing Phase 1–6 empty states for the same panels are **replaced** by this widget (search each panel for an existing `Text('No …')`).
3. Each panel shows the empty state while its provider reports "loaded and empty" — never while loading (show a progress indicator,
   `Semantics(label: loading)`).

**B. Motion** (`motion.dart`).
1. ```dart
   enum MotionKind { hover, menu, tooltip, tabSwitch, tabReorder, fold, checkbox, dialog, sidebar, bottomSheet, pageRoute, toast, viewportMove }
   final class AppMotion {
     const AppMotion({required this.reduce});
     final bool reduce;                               // appearance.reduceMotion || MediaQuery.disableAnimations
     Duration duration(MotionKind k);                 // Duration.zero when reduce
     Curve curve(MotionKind k);
     static AppMotion of(BuildContext context);
   }
   ```
2. The one table (milliseconds; `in` / `out` curves differ only where stated):
   | MotionKind | Duration | Curve | Used for |
   |---|---|---|---|
   | `hover` | 100 | `Curves.easeOut` | hover/focus/pressed colour changes, switch/checkbox state colour |
   | `checkbox` | 100 | `Curves.easeOut` | task checkbox tick |
   | `tooltip` | 100 | `Curves.easeOut` | tooltips fade |
   | `menu` | 120 | `Curves.easeOutCubic` (in), `Curves.easeInCubic` (out, 80 ms) | popup menus, autocomplete popups, hover page preview (fade only) |
   | `tabSwitch` | 120 | `Curves.easeInOut` | content cross-fade between tabs |
   | `tabReorder` | 150 | `Curves.easeInOut` | tab positions while dragging |
   | `fold` | 150 | `Curves.easeInOut` | heading/list/callout fold, tree expand/collapse |
   | `dialog` | 200 | `Curves.easeOutCubic` (in; fade + scale 0.96→1), `Curves.easeInCubic` (out, 150 ms) | dialogs |
   | `toast` | 200 | `Curves.easeOutCubic` | toast slide-up; visible 4 s (6 s when it has an action) |
   | `sidebar` | 250 | `Curves.easeOutCubic` (open), `Curves.easeInCubic` (close) | sidebar collapse, phone drawers |
   | `bottomSheet` | 250 | `Curves.easeOutCubic` / `easeInCubic` | bottom sheets |
   | `pageRoute` | 250 | Android: `ZoomPageTransitionsBuilder`; Windows: `FadeUpwardsPageTransitionsBuilder` | phone screen navigation (set in `PageTransitionsTheme`) |
   | `viewportMove` | 300 | `Curves.easeInOutCubic` | graph/canvas fit-to-view, zoom-to-node, scroll-to-block in editor |
   No other animation durations exist. Progress indicators (indeterminate) and the recording meter are not subject to reduce-motion.
3. `reduce` → every duration is `Duration.zero`, `pageTransitionsTheme` uses a builder that returns the child unchanged, hover colour changes
   still apply instantly. The setting `appearance.reduceMotion` (07.1) is app-level; the OS flag `MediaQuery.disableAnimations` also turns it on.
4. Replace every `Animated*`, `AnimationController(duration: …)`, `AnimatedSwitcher` and implicit-animation `duration:` in `app/lib` by
   `AppMotion.of(context).duration(MotionKind.x)` / `.curve(...)`. **Source rule** (added to `source_rules_test.dart`): in `app/lib` outside
   `theme/motion.dart`, the regex `(duration|reverseDuration):\s*(const\s+)?Duration\(` is forbidden except on lines containing the marker
   comment `// motion-ok: <reason>` (allowed reasons: tooltips' `waitDuration`, debounce timers are not matched because they use `Timer`).

**C. Plain-language errors.**
1. `UserMessages.of(l10n).forError(Object error, {String? name}) → UserMessage { String title; String? hint; bool showDetailsAction; }` maps
   exceptions to l10n strings. **Never** show `toString()`, class names, stack traces, paths outside the vault, or HTTP codes to the user;
   the technical text goes to the log (`Logger.severe`/`warning`). Rules for every message: sentence case, ≤ 2 sentences (≤ 140
   characters in total), says **what happened** and **what the user can do**, names the file or note when known, no jargon ("index", "isolate",
   "exception", "null", "stack", "parse", "FTS", "SQLite", "OAuth" are forbidden in these strings), no blame ("You must…"), no exclamation marks.
2. Mapping (all strings live in `app_en.arb`; `{name}` is a placeholder):
   | Error | Key | English text |
   |---|---|---|
   | `InvalidPathException` | `errorInvalidName` | That name can't be used. Names can't contain \ / : * ? " < > \| |
   | `FileNotFoundException` | `errorFileNotFound` | Couldn't find “{name}”. It may have been moved or deleted. |
   | `FileConflictException` | `errorFileExists` | A file named “{name}” already exists here. Choose another name. |
   | `PermissionDeniedException` (Windows) | `errorPermissionWindows` | Tephra isn't allowed to change “{name}”. Check that the file isn't read-only or open in another program. |
   | `PermissionDeniedException` (Android) | `errorPermissionAndroid` | Tephra no longer has access to this folder. Open Settings and choose the vault folder again. |
   | `ParseException` | `errorUnreadable` | “{name}” couldn't be read properly. Your file wasn't changed. |
   | malformed-bytes read-only note | `errorReadOnlyEncoding` | “{name}” uses an unusual text encoding, so Tephra opened it read-only to protect it. |
   | `CryptoException` | `errorCrypto` | Couldn't unlock the data. Check your password and try again. |
   | `IndexCorruptException` / `IndexQueryException` | `errorIndex` | Search needs to be rebuilt. This can take a minute and doesn't change your notes. (action: Rebuild) |
   | `ImportFailedException` | `errorImport` | The import stopped. Notes that were already imported are kept. |
   | `SyncException` subtypes — use the Phase 3 keys `syncErrorOffline`, `syncErrorAuthRevoked`, `syncErrorDriveFull`, `syncErrorWrongPassword`, `syncErrorWrongRecoveryKey`, `syncErrorKeyMissing`, `syncErrorRemoteFormatNewer`, `syncErrorTampered`, `syncErrorVaultFolderUnavailable`, `syncErrorVaultMissing`, `syncErrorNoOAuthConfig` | (existing) | review each existing English text against rule 1 and rewrite those that break it |
   | `SocketException` / `TimeoutException` (not already a `SyncException`) | `errorNetwork` | Couldn't reach the internet. Check your connection and try again. |
   | disk full (`FileSystemException` with `osError.errorCode` 112 on Windows, 28 on Android) | `errorDiskFull` | There isn't enough free space on this device. Free some space and try again. |
   | audio permission / no microphone (07.9) | `audioPermissionDenied`, `audioNoDevice` | Tephra can't use the microphone. Allow microphone access in your device settings. / No microphone was found. |
   | web viewer navigation failure (07.11) | `errorWebPage` | This page couldn't be loaded. Check the address and your connection. |
   | spell-check unavailable (07.16) | `spellcheckNoSystemChecker` | No system spell checker is turned on. Turn one on in your device settings. |
   | anything else | `errorUnknown` | Something went wrong. Your notes weren't lost. Details were saved to the log. (action: Copy details) |
   "Copy details" copies the error type name, message and the last 20 log lines **without** note text (the logger never records it, §5.5).
3. Presentation: transient errors → snackbar/toast (`liveRegion`), blocking errors → dialog with one primary action. Every `catch` that
   shows something to the user calls `UserMessages`. Existing hard-coded or `e.toString()` messages from Phases 1–6 are replaced (search
   `grep -rn "toString()\|\$e\b\|e\.message" app/lib` and convert every hit that reaches a widget).
4. `source_rules_test.dart` adds: no `Text(`/`SnackBar(content:`/`showDialog` content built from `error`, `e`, `exception`, `e.toString()`.

**D. Every command is reachable.**
1. Ribbon, drawer, toolbar, tab-bar and menu buttons are **data-driven**: each `RibbonItem`/toolbar entry carries a `commandId`; if a Phase 1–6
   button still calls a function directly, refactor it into a command first (additive) and use `commandId`.
2. `command_audit.dart` offers `Future<CommandAuditReport> auditCommands(ProviderContainer, List<AuditContext>)` and the context list
   below. `command_reachability_test.dart` asserts, using the real `commandRegistryProvider` after all features register their commands:
   | # | Assertion |
   |---|---|
   | 1 | Every command has a non-empty label (English) and an id matching `^[a-z0-9]+(-[a-z0-9]+)*\.[a-z0-9]+(-[a-z0-9]+)*$` (`area.verb-noun`); ids unique. |
   | 2 | Every command with `showInPalette == true` appears in the palette results when the palette is queried with its exact label **in at least one** of these contexts: C1 desktop, Markdown note focused in Source mode; C2 desktop, Live Preview; C3 desktop, Reading view; C4 desktop, no tab open; C5 desktop, canvas tab active; C6 desktop, graph tab active; C7 desktop, base tab active; C8 phone width, note open; C9 phone width, nothing open; with **all** core plugins enabled, vim off, and the vault synced-on. |
   | 3 | Commands with `showInPalette == false` are listed in `paletteHiddenAllowlist` (a constant in the test) with a reason each; the allowlist may only contain commands that are internal key handlers (e.g. `editor.clear-extra-carets`). |
   | 4 | Commands that are unreachable in **every** context are listed in `unreachableByDesign` with a reason (for example `workspace.move-to-new-window` on phone; it is reachable in C1–C7). The list must be empty or justified; the test prints it. |
   | 5 | With a core plugin disabled (one test per plugin from the 07.1 map) none of its commands appear in the palette, and its ribbon button is absent. |
   | 6 | Every command with `showInMobileToolbar == true` appears in the phone keyboard toolbar (row or overflow menu) when a Markdown note is focused in the phone layout, and each toolbar button's `commandId` exists in the registry. |
   | 7 | The following commands **must** have `showInMobileToolbar: true` (ids as recorded in the Name map; a missing command is a gap — create it): bold, italic, strikethrough, highlight, inline code, bullet list, numbered list, task toggle, blockquote, insert link, insert wikilink, insert tag, indent, outdent, undo, redo, insert template, attach file, `audio-recorder.start-stop`, open command palette, `note-composer.extract-selection`. |
   | 8 | No two commands share a default shortcut unless both are in `sharedShortcutAllowlist` with the context that disambiguates them (for example local canvas zoom vs app zoom, 07.5). |
   | 9 | Every ribbon/drawer/toolbar `commandId` exists in the registry. |
   | 10 | Every Core-plugin command added in this phase is present: `note-composer.merge-file`, `note-composer.extract-selection`, `note-composer.extract-selection-open`, `note-composer.extract-heading`, `format-converter.convert-current`, `format-converter.convert-vault`, `random-note.open-random-note`, `audio-recorder.start-stop`, `file-recovery.open`, `web-viewer.open-url`, `web-viewer.open-home`, `workspace.split-right`, `workspace.split-down`, `workspace.move-tab-to-new-group`, `workspace.close-group`, `workspace.focus-group-left`, `workspace.focus-group-right`, `workspace.focus-group-up`, `workspace.focus-group-down`, `workspace.close-other-tabs`, `workspace.close-tabs-to-right`, `workspace.toggle-pin`, `workspace.toggle-stacked-tabs`, `workspace.save-layout`, `workspace.load-layout`, `workspace.delete-layout`, `workspace.manage-layouts`, `workspace.move-to-new-window`, `editor.add-caret-above`, `editor.add-caret-below`, `editor.select-next-occurrence`, `editor.clear-extra-carets`, `editor.toggle-vim-mode`, `editor.toggle-spellcheck`, `editor.paste-plain`, `editor.move-block-up`, `editor.move-block-down`, `app.zoom-in`, `app.zoom-out`, `app.zoom-reset`, `app.open-settings`, `app.focus-next-region`, `app.focus-previous-region`. |
3. Failures print the command id and the failing assertion number.

**Tests**
- `empty_state_test.dart`: widget renders icon/title/body/actions; `compact` hides body; semantics label; scrolls at scale 2.0 in a 200 dp tall box; plus one
  parameterised widget test that pumps **each panel in A.2** with an empty fake provider and expects an `EmptyState` whose title equals the
  table's English title (loaded from the ARB), and that a loading provider shows no `EmptyState`.
- `motion_test.dart`: every `MotionKind` has the duration of the table; `reduce` → zero; `appearance.reduceMotion` and `disableAnimations` both turn
  it on; source rule passes.
- `user_messages_test.dart`: every row of C.2 maps from its exception; `{name}` substituted; every ARB string whose key starts with `error`,
  `syncError`, `audio`+`Permission/NoDevice`, `spellcheckNoSystemChecker` satisfies: length ≤ 140, no forbidden word (case-insensitive: `exception`,
  `null`, `stack`, `parse`, `fts`, `sqlite`, `oauth`, `isolate`, `index` — except the key `errorIndex`, which is checked against `rebuilt` only), no `!`,
  ends with `.` or `?`; unknown exception → `errorUnknown`; `showDetailsAction` only there.
- `command_reachability_test.dart`: the ten assertions of D.2.

**Verify**
```
cd app; flutter test test/core test/theme/motion_test.dart test/commands test/a11y/source_rules_test.dart; cd ..
```
Manual: walk through every panel with an empty vault; trigger three errors (rename to `a/b`, remove vault folder access on Android, open a read-only
file). Success: tests pass; messages read naturally.

**Pitfalls**
- Do not translate or concatenate fragments (§5.10): each message is one ARB entry with placeholders.
- Never put an exception's `message` into a user-visible string even "for convenience".

---

### 07.20 Onboarding: the "Tephra Guide" vault

**Purpose.** On first run, give the user a real, bundled vault that teaches the app, using only features that exist and Obsidian-compatible syntax.

**Files**
- `app/assets/guide_vault/` (new; the files listed below; declare the folder **and each sub-folder** in `app/pubspec.yaml` under `flutter: assets:`, because Flutter does not recurse)
- `app/lib/vault/guide/guide_vault_installer.dart`, `guide_shortcuts_note.dart` (new)
- `app/lib/vault/view/welcome_view.dart` (new or modify the vault picker's empty state)
- `app/lib/settings/view/about_view.dart` (modify: **Open guide vault**)
- `app/test/vault/guide/guide_vault_installer_test.dart`, `guide_vault_content_test.dart` (new)

**Implementation**

1. **Location and installation.** `GuideVaultInstaller.install()` copies the bundled files to
   `p.join((await getApplicationDocumentsDirectory()).path, 'Tephra Guide')` on both platforms (on Android this folder is app-private, which needs no
   storage permission; on Windows it is inside the user's Documents). Steps: list assets with `AssetManifest.loadFromAssetBundle(rootBundle)`
   keeping keys that start with `assets/guide_vault/`; for each, read bytes (`rootBundle.load`) and write with `IoVaultFileSystem.writeBytes`
   (atomic) to the relative path (strip the prefix); then create the vault metadata through the **existing Phase 1 "create vault" function**
   (so `.tephra/vault.json` gets a fresh `id` and `formatVersion`); then write the shortcuts note (item 4); finally set
   `guideVaultCreated = true` in the app settings and add the vault to `recentVaults`. **Never overwrite**: if the target folder exists and
   is non-empty, skip copying and just open it (log `info`). The copy is about 15 small files, so run it on the UI isolate behind a progress indicator (no isolate).
2. **When it runs.** First launch (`recentVaults` is empty **and** `guideVaultCreated` is false): the vault picker screen is replaced by
   `WelcomeView`: app name, one sentence, primary button **Open the Tephra Guide** (installs + opens, landing on `00 Welcome`), secondary buttons
   **Create a vault**, **Open a folder as vault**. Any later launch: the normal picker; the guide is reachable from **Settings → About →
   Open guide vault** (installs it again if its folder was deleted; otherwise opens the existing one) and from the explorer empty state (07.19).
3. **Bundled files** (all notes are original text written for Tephra; use the Obsidian syntax exactly as in §6.3; every note starts with
   frontmatter `tags: [guide]` and `aliases: []` except the shortcuts note; each note 150–450 words; headings level 1–3; **no** emoji
   requirement; links use `[[wikilinks]]`; every note ends with a `## Next` section linking to the following note):
   | File | Outline of the content (write each bullet as one short paragraph, list or example) |
   |---|---|
   | `00 Welcome.md` | What Tephra is (notes are plain Markdown files in a folder; compatible with Obsidian); how this guide works (read in order, try the examples, edit freely — it is your copy); a link list to notes 01–10; a task list `- [ ] Create your first note`, `- [ ] Add a link with [[`, `- [ ] Open the command palette (Ctrl+P)`; a callout `> [!tip]` about the quick switcher |
   | `01 Writing and formatting.md` | Headings; bold/italic/strikethrough/highlight; bullet, numbered and task lists with several statuses; quotes; callouts (`> [!note]`, `> [!warning]-` folded); inline code and a fenced code block with a language; a table; a horizontal rule; a footnote; inline math `$e^{i\pi}+1=0$` and a `$$` block; a `%%comment%%`; the three modes (Source, Live Preview, Reading) and how to switch |
   | `02 Links and backlinks.md` | `[[Note]]`, `[[Note\|alias]]`, `[[Note#Heading]]`, `[[Note#^block]]` (with a real `^block-id` paragraph in this note), embeds `![[Note]]`; unresolved links and how to create the note by clicking; the Backlinks and Outgoing links panes; unlinked mentions and "Link"; renaming a note updates links (try renaming a note in the guide) |
   | `03 Organising your notes.md` | Folders and drag-and-drop; tags (`#guide`, `#guide/nested`); properties (frontmatter) and the properties editor; bookmarks; daily notes and templates (points to `Templates/Meeting note`); the file explorer sort options |
   | `04 Finding things.md` | Quick switcher; command palette; search with the operators `file:`, `path:`, `tag:`, `line:`, `section:`, `task:`, `task-todo:`, `task-done:`, `match-case:`, regex, `OR`, `-`, quotes; a live ```query block (``` query ``` fence with `tag:#guide`) showing results |
   | `05 Graph, Canvas, Bases and Slides.md` | What each view is for, how to open it; links to `Examples/Example canvas`, `Examples/Example base`, `Examples/Example slides`; the graph's list view for screen readers |
   | `06 Sync and backup.md` | Google Drive sync in one paragraph; encryption (your notes are encrypted before upload; keep your password and recovery key safe); what a conflict copy is; backups and restore; local history (File recovery); nothing is sent anywhere unless the user sets sync up |
   | `07 Sticky notes and quick capture.md` | Stickies (colour, pin, Windows floating window), quick capture (global hotkey on Windows, share sheet/widget on Android); the `tephra-sticky` property |
   | `08 Keyboard shortcuts.md` | Generated by `GuideShortcutsNoteBuilder` (item 4) — a table of every palette command that has a default shortcut |
   | `09 Customising Tephra.md` | Settings sections; core plugins on/off; themes and the theme editor; importing colours from an Obsidian theme; fonts, accent colour and interface zoom; hotkeys; vim mode and multi-cursor (desktop); spell check; right-to-left text; accessibility notes (screen readers, text size, reduce motion) |
   | `10 Moving from other apps.md` | Opening an existing Obsidian vault (folder as vault; Tephra never writes to `.obsidian`); importing from Notion, Evernote, Roam, Logseq, Apple Notes, OneNote, Google Keep, CSV, Markdown/HTML folders; exporting (zip, PDF, HTML, DOCX, portable Markdown) |
   | `Templates/Meeting note.md` | A template using `{{title}}`, `{{date}}`, `{{time}}`: heading, Attendees list, Agenda, Notes, `- [ ] Action items` |
   | `Examples/Example canvas.canvas` | JSON Canvas 1.0: 3 text cards, one file card pointing to `00 Welcome.md`, one group, 3 edges (hand-written valid JSON; node ids 16 hex characters) |
   | `Examples/Example base.base` | A YAML base: filter `file.hasTag("guide")`, a table view with columns `file.name`, `file.mtime`, sorted by name |
   | `Examples/Example slides.md` | 4 slides separated by `---` |
   | `.tephra/settings.json` | `{ "templates.folder": "Templates", "corePlugins.templates": true }` plus any key needed so `Templates` is the templates folder (use the real Phase 2 key names from the Name map) |
   | `.tephra/bookmarks.json` | one bookmark to `00 Welcome.md` |
4. **Shortcuts note** (`08 Keyboard shortcuts.md`) is **generated, not bundled**, so it cannot drift from the registry: frontmatter `tags: [guide]`, an
   intro sentence, then `## Windows and keyboards` with a Markdown table `| Action | Shortcut |` listing every command with `showInPalette`
   and at least one default shortcut, sorted by label, shortcut formatted `Ctrl+Shift+K`; a second table for the Vim subset (from 07.15) and a
   third for Canvas/PDF/graph local shortcuts (from Phase 6 help data). Written by the installer after the copy; never regenerated automatically
   (it is the user's file afterwards).
5. **Content rules the tests enforce:** every `[[link]]` resolves to a bundled note (or a generated one) using the app's link resolver on an in-memory vault;
   every command or feature named in backticks as `` `command-id` `` exists in the registry; every note parses with `MarkdownParser` with
   `frontmatterValid == true`; no note larger than 20 KB; every note contains the heading `## Next` except `10 Moving from other apps.md`
   (which ends the tour with `## You're ready`); `Example canvas.canvas` decodes with the Phase 6 `CanvasCodec` and re-encodes byte-identically;
   `Example base.base` loads with the Phase 6 Bases loader without error; slides split into exactly 4 slides.
6. Copy/branding: the guide uses the product name **Tephra** only; it never mentions the other app's name except in the notes about compatibility and import.

**Tests**
- `guide_vault_installer_test.dart` (memory FS + fake asset bundle + fake documents dir): installs all files; `.tephra/vault.json` present with a uuid;
  second call does not overwrite a user-edited note (edit `00 Welcome.md`, call again, content unchanged); `guideVaultCreated` set; recent vaults updated;
  shortcuts note generated and contains a known command's shortcut row; installation interrupted after 5 files (throw in the fake FS) leaves no
  `guideVaultCreated` flag and a retry completes (files written atomically; existing identical files skipped).
- `guide_vault_content_test.dart`: the assertions of item 5 over the real `assets/guide_vault/` files.
- `welcome_view_test.dart`: first launch shows `WelcomeView`; later launches show the picker; tapping **Open the Tephra Guide** calls the installer then opens the vault.

**Verify**
```
cd app; flutter test test/vault; cd ..
```
Manual on both platforms: fresh app data → Welcome → guide opens at `00 Welcome`; follow the guide's tasks; every link works; open the example
canvas/base/slides. Success: all pass.

**Pitfalls**
- Declare every guide sub-folder in `pubspec.yaml` assets (`assets/guide_vault/`, `assets/guide_vault/Templates/`, `assets/guide_vault/Examples/`,
  `assets/guide_vault/.tephra/`); dot-folders are bundled only when listed explicitly.
- Asset names with spaces are valid; do not rename them.

---

## Demo script

Run on a clean profile (delete `<appSupportDir>`) on Windows, then repeat the starred steps on the Android phone.

1. Launch → `WelcomeView` → **Open the Tephra Guide** ★ → lands on `00 Welcome`. Tick the three tasks while doing them.
2. Settings (Ctrl+,) ★: search "wiki" → toggle; open **Appearance** → switch to **Tephra Dark** → the whole app recolours live; set accent to a
   light green → links stay readable; zoom to 150% ★ and back.
3. Theme editor: duplicate **Tephra Dark**, change `textAccent`, see the contrast warning, save to "This device"; import `test_vaults/themes/sample-theme.css`
   and preview the light and dark results.
4. Add a font file; select it as the text font ★.
5. Editor (Windows): Alt+click in three places and type; Ctrl+D on a word ×3 and replace it; Ctrl+Z once. Enable vim mode in Settings → use `dd`, `yy`, `p`, `3j`,
   `/guide`, `n`, `:w`, `u`; disable vim mode.
6. Spell check ★: type `teh` → underline → pick **the**. Windows: **Add to dictionary** on a made-up word.
7. RTL: type a Hebrew/Arabic sentence → the paragraph aligns right in reading view. Paste formatted text from a web page ★ → Markdown with links/bold.
   Drag a paragraph with the handle in Live Preview; undo in one step.
8. Note composer: select text → **Extract current selection** → link inserted; merge a note into another and undo.
9. Format converter on a note containing `^^x^^`; word count in the status bar (selection counts) ★; random note; record 5 seconds of audio ★ and play it back.
10. File recovery: delete a note → **Open local history browser** → restore it. Footnotes panel on `01 Writing and formatting`.
11. Web viewer (Windows): click an external link → opens in a tab → **Save to vault**.
12. Workspace (Windows): split right, pin a tab, stack tabs, link two panes, save the layout "Writing", pop out a note, close the app, reopen →
    everything restored.
13. Accessibility ★: turn on Narrator (Windows) / TalkBack (Android) and open the graph → list view; open a note from it. Keyboard only: F6 through the regions.
14. Turn on **Reduce motion** → no animations. Set the OS text size to the largest ★ → no clipped text in Settings.
15. Empty vault ★: create a new empty vault → every panel shows its empty state.

---

## Exit gate

Record the results in `PROGRESS.md`. Every box must be ticked on both platforms where applicable. "n/a" is allowed **only** where stated.

### 1. Feature checklist — IMPLEMENTATION_PLAN §4.1 (every bullet)

Legend: A = Android (phone and, where noted, ≥ 840 dp tablet with hardware keyboard), W = Windows. Tick by changing `[ ]` to `[x]`.

**Editing**
| # | Feature | A | W |
|---|---|---|---|
| E1 | Source mode | [ ] | [ ] |
| E2 | Live Preview mode (syntax hidden except at the cursor) | [ ] | [ ] |
| E3 | Reading view | [ ] | [ ] |
| E4 | Syntax highlighting in Source mode | [ ] | [ ] |
| E5 | Auto-pair brackets | [ ] | [ ] |
| E6 | Smart lists (continue, renumber) | [ ] | [ ] |
| E7 | Indent / outdent | [ ] | [ ] |
| E8 | Move line up / down | [ ] | [ ] |
| E9 | Multi-cursor (Alt+click, Ctrl+Alt+Up/Down, Ctrl+D) | n/a on phone layout (verify commands hidden; works on tablet ≥ 840 dp with keyboard if available) [ ] | [ ] |
| E10 | Autocomplete for `[[links]]` | [ ] | [ ] |
| E11 | Autocomplete for headings (`[[Note#`) | [ ] | [ ] |
| E12 | Autocomplete for block references (`[[Note#^`) | [ ] | [ ] |
| E13 | Autocomplete for tags | [ ] | [ ] |
| E14 | Autocomplete for properties (keys and values) | [ ] | [ ] |
| E15 | Slash commands | [ ] | [ ] |
| E16 | Folding of headings | [ ] | [ ] |
| E17 | Folding of lists | [ ] | [ ] |
| E18 | Vim mode (the 07.15 subset) | n/a — hidden on phone layout [ ] | [ ] |
| E19 | Spell check (underline, suggestions) | [ ] | [ ] |
| E20 | RTL support (per paragraph) | [ ] | [ ] |
| E21 | Paste images | [ ] | [ ] |
| E22 | Drag-and-drop files into notes | n/a on phone (share/pick instead) [ ] | [ ] |
| E23 | Auto-convert pasted HTML to Markdown | [ ] | [ ] |
| E24 | Properties editor UI above the note | [ ] | [ ] |
| E25 | Drag blocks by handle in Live Preview / move block commands | commands only [ ] | handle + commands [ ] |

**Navigation & organisation**
| # | Feature | A | W |
|---|---|---|---|
| N1 | File explorer: create | [ ] | [ ] |
| N2 | File explorer: rename (links updated everywhere) | [ ] | [ ] |
| N3 | File explorer: move and drag-and-drop | [ ] | [ ] |
| N4 | File explorer: sort options | [ ] | [ ] |
| N5 | Tabs | [ ] | [ ] |
| N6 | Split panes (horizontal and vertical) | tablet/landscape ≥ 840 dp [ ] | [ ] |
| N7 | Pop-out windows | n/a — hidden on Android [ ] | [ ] |
| N8 | Stacked tabs | n/a on phone layout (flag ignored) [ ] | [ ] |
| N9 | Pinned tabs | [ ] | [ ] |
| N10 | Saved workspaces (layouts) | palette only [ ] | [ ] |
| N11 | Quick switcher | [ ] | [ ] |
| N12 | Command palette | [ ] | [ ] |
| N13 | Configurable hotkeys | hardware keyboard [ ] | [ ] |
| N14 | Backlinks | [ ] | [ ] |
| N15 | Outgoing links | [ ] | [ ] |
| N16 | Unlinked mentions with "link this" | [ ] | [ ] |
| N17 | Outline (headings), including drag-to-move sections (desktop) | [ ] | [ ] |
| N18 | Tags pane | [ ] | [ ] |
| N19 | Bookmarks | [ ] | [ ] |
| N20 | Random note | [ ] | [ ] |
| N21 | Page preview on hover / long-press | [ ] | [ ] |
| N22 | Session restore (last layout) | [ ] | [ ] |
| N23 | Linked panes | n/a on phone layout [ ] | [ ] |

**Search**
| # | Feature | A | W |
|---|---|---|---|
| S1 | Full-text search | [ ] | [ ] |
| S2 | Operators `file:` `path:` `tag:` `line:` `block:` `section:` | [ ] | [ ] |
| S3 | Operators `task:` `task-todo:` `task-done:` | [ ] | [ ] |
| S4 | Property search `[property:value]` | [ ] | [ ] |
| S5 | `match-case:` and `ignore-case:` | [ ] | [ ] |
| S6 | Regex `/.../` | [ ] | [ ] |
| S7 | Boolean `OR`, `-` and quoted phrases | [ ] | [ ] |
| S8 | Embedded search results in ```query blocks | [ ] | [ ] |

**Views**
| # | Feature | A | W |
|---|---|---|---|
| V1 | Graph view, global | [ ] | [ ] |
| V2 | Graph view, local (depth) | [ ] | [ ] |
| V3 | Graph filters, groups/colours, forces settings, orphans toggle | [ ] | [ ] |
| V4 | Canvas: cards, embedded notes, media, web pages, groups, connections, zoom/pan | [ ] | [ ] |
| V5 | Bases: table and card views, filters, sorting, formulas | [ ] | [ ] |
| V6 | Slides (note split on `---`) | [ ] | [ ] |
| V7 | PDF viewer with links to pages | [ ] | [ ] |
| V8 | Image viewer | [ ] | [ ] |
| V9 | Audio and video viewers | [ ] | [ ] |

**Core plugins**
| # | Feature | A | W |
|---|---|---|---|
| C1 | Daily notes | [ ] | [ ] |
| C2 | Unique note creator | [ ] | [ ] |
| C3 | Templates (`{{date}}`, `{{time}}`, `{{title}}`) | [ ] | [ ] |
| C4 | Note composer: merge notes | [ ] | [ ] |
| C5 | Note composer: extract selection / heading to a new note with link | [ ] | [ ] |
| C6 | Format converter | [ ] | [ ] |
| C7 | Audio recorder (inserts embed) | [ ] | [ ] |
| C8 | Word and character count (note and selection) | [ ] | [ ] |
| C9 | File recovery (local snapshots, restore) | [ ] | [ ] |
| C10 | Web viewer | n/a — external links open in the system browser [ ] | [ ] |
| C11 | Footnotes view | [ ] | [ ] |
| C12 | Every core plugin can be turned off in Settings → Core plugins and its UI disappears | [ ] | [ ] |

**Settings & look**
| # | Feature | A | W |
|---|---|---|---|
| L1 | Light / dark / system theme | [ ] | [ ] |
| L2 | Accent colour | [ ] | [ ] |
| L3 | Fonts (custom font files) and font sizes | [ ] | [ ] |
| L4 | Readable line length | [ ] | [ ] |
| L5 | Custom themes (JSON), theme editor with live preview, Obsidian `theme.css` colour import | [ ] | [ ] |
| L6 | Interface zoom | [ ] | [ ] |
| L7 | Per-vault settings (vault vs app scope verified) | [ ] | [ ] |
| L8 | Multiple vaults with a vault switcher | [ ] | [ ] |
| L9 | Settings screens: Editor, Files & links, Appearance, Hotkeys, Core plugins, Sync, About | [ ] | [ ] |

### 2. Phase 7 specific
- [ ] `docs/accessibility-audit.md` complete: every flow of 07.18 E passed with TalkBack (Android phone, real device or "not verified on device" noted) and with Narrator and keyboard-only (Windows); no unexplained failures.
- [ ] Contrast test passes for all four bundled themes; text-scale goldens (1.0 / 1.5 / 2.0) pass; no RenderFlex overflow at 200%.
- [ ] Every command reachable (`command_reachability_test.dart` green; allowlists printed and justified in `PROGRESS.md`).
- [ ] Every panel in 07.19 A.2 shows its empty state; no user-visible string comes from `toString()`.
- [ ] Guide vault installs on first run on both platforms; every link in it resolves.
- [ ] Source-rule tests pass (no raw `Color(0x` outside `app/lib/theme/`, no raw animation durations, no `IconButton` without a tooltip, no error text from exceptions).
- [ ] `dart run tool/check_licenses.dart` passes (new packages: `record` BSD-3-Clause; `win32` BSD-3-Clause; `ffi` BSD-3-Clause if added).
- [ ] No data-loss regression: the Phase 1 text round-trip test, the Phase 2 rename-with-links test and the note-composer undo test are green; pop-out editing test (manual) shows no lost edits.

### 3. Performance budgets still met (§10; re-measure in a `--profile` build with the 10k-note bench vault; record numbers)
- [ ] Cold start → editable note: Android < 2.5 s, Windows < 1.5 s (custom fonts and theme loading included).
- [ ] Typing latency, 5,000-line note: < 16 ms p95 — measured **four** ways: plain; spell check on; vim mode on (Windows); two extra carets (Windows).
- [ ] Plain-text search 10k notes < 200 ms; quick switcher < 50 ms; first full index unchanged from Phase 6's numbers (±10%).
- [ ] Memory with the 10k-note vault: Android < 350 MB, Windows < 500 MB (with spell check and the web viewer tab open on Windows).
- [ ] Release APK size < 40 MB per ABI (the guide vault and theme assets included).
- [ ] Theme switch applies in < 300 ms with a 5,000-line note open (measure with `Stopwatch` around the provider change to the next frame).

### 4. Standard checks and release steps
- [ ] `dart format --output=none --set-exit-if-changed app/lib app/test packages tool`, `flutter analyze --fatal-infos`, all package tests, `flutter test` in `app/` (including `--tags golden` on Windows) pass.
- [ ] `PROGRESS.md` updated: Name map, contract additions (below), decisions (spell check APIs, multi-cursor at controller level, decoration mechanism), numbers, "not verified on device" items.
- [ ] `git checkout main`, then `git merge --no-ff phase-07`.
- [ ] `git tag v0.07.0`.
- [ ] Stop and report to the human: what was built, gate results with numbers, items not verified on a device, and the contract additions below.

---

## Hand-off

**Contract additions made by this phase** (record in `PROGRESS.md` → "Phase 7 notes → Contract additions"; the human folds them into
`00-conventions.md`):
- Paths: `<vault>/.tephra/themes/`, `<appSupportDir>/themes/`, `<appSupportDir>/fonts/`; `"saved"`, `"popouts"`, `"linkGroup"`, `"pinned"`, `"stacked"`
  keys inside `.tephra/workspace.json`; new vault/app settings keys of 07.1; app keys `guideVaultCreated` and `deviceName`.
- Folders: `app/lib/plugins/` (note composer, format converter, word count, random note, audio recorder, file recovery, footnotes, web viewer),
  `app/lib/core/a11y/`, `app/lib/editor/{decorations,multicursor,vim,spell,paste,blocks}/`, `app/lib/core/platform/spell_check_service*.dart`.
- Pure-Dart additions: `tephra_io` `FormatConverter`, `extractClipboardHtmlFragment`; `tephra_markdown` `countWords`, `detectParagraphDirection`.
- `EditorController` additions: `setDecorations`, `clearDecorations`, `decorationRevision`, `decorationsInRange`, `rectForOffset`, `offsetForGlobalPosition`.
- `ThemeFile` JSON schema `schemaVersion: 1` and the token list of 07.3; `TephraColors` theme extension; `AppMotion`; `EmptyState`; `UserMessages`.
- Possible `retargetLinks(VaultPath from, VaultPath to)` beside the Phase 2 rename service.

**What Phase 8 relies on from this phase:**
- The settings registry (`SettingDefinition`): Phase 8 adds its keys there (AI model, API-key storage is **not** a registry setting — it uses secure
  storage — but its enable switch and privacy notice are), each with an `l10n` label, and a new Core-plugins toggle per Phase 8 feature.
- Theme tokens: new panels (assistant, kanban, flashcards, tasks dashboard) use `context.tc` tokens — no raw colours; add new tokens only through a
  `schemaVersion` bump with fallbacks to existing tokens.
- `EmptyState`, `AppMotion`, `UserMessages` and the `FocusRing`/semantics rules: every new Phase 8 screen needs an empty state, motion kinds from the
  table, plain-language errors (AI errors: no provider messages shown raw) and entries in the accessibility audit.
- The command reachability test: every Phase 8 command must pass it; the `paletteHiddenAllowlist` stays minimal.
- The guide vault: Phase 8 adds notes for its features through the same installer (new files are copied; existing user-edited files are never overwritten).
- The decoration mechanism (`RangeDecoration`) for any future inline highlights (for example "related notes" or search-in-note highlights).
