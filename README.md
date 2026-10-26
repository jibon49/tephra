# Tephra

Obsidian-compatible Markdown notes for Android and Windows, written in Flutter.
Agent rules: GEMINI.md. Technical contract: instructions/00-conventions.md.

## Features

- **Vault Management**: Open existing Obsidian vaults or create new ones; recent vaults history; `.obsidian` settings import; Android All-files-access storage permission flow.
- **Adaptive Workspace**: Responsive layout switching between desktop (≥ 840 dp: split panes, tabs, sidebar, status bar) and mobile (< 840 dp: navigation drawer, app bar).
- **Fast CommonMark + Obsidian Parser**: Pure Dart parser supporting CommonMark 0.31.2, GFM tables/tasks, callouts, wikilinks, math, footnotes, and block references.
- **Reading View**: Complete markdown rendering with syntax-highlighted code blocks, interactive task toggling, callout folding, and table formatting.
- **Source Editor**: Syntax highlighting, auto-pairing, smart indentation, list continuation, keyboard shortcuts, find & replace, and a mobile formatting toolbar.
- **Data Safety & Autosave**: 1-second debounced autosave, atomic file writes (`write temp -> flush -> rename`), external change detection, three-way merge, and conflict resolution.
- **Attachments**: Drag-and-drop, clipboard image paste, attachment subfolder routing, and file pickers.
- **Sticky Notes & Quick Capture**: Floating desktop windows and Android bubble sticky notes with lightweight mini renderer, interactive task toggles, JSON Canvas 1.0 board view, system tray and global hotkeys, home-screen widgets, Quick Settings tile, Android share target, and auto-archiving of expired stickies.

## Install

```
flutter pub get
```

## Run

```
dart run tool/dev.dart
```

Starts the web development preview on `PORT` (default 8093) and prints the Local and Network URLs.
The real apps run with `flutter run -d windows` or `flutter run -d <android-device>` inside `app/`.

### Running with Google Drive sync

To run with Google Drive synchronization enabled, configure `secrets/google_oauth.json` (see `secrets/google_oauth.example.json`) and run from the `app/` directory:

```bash
flutter run -d windows --dart-define-from-file=../secrets/google_oauth.json
flutter run -d <android-device-id> --dart-define-from-file=../secrets/google_oauth.json
```

Dev Launcher's web preview (`dart run tool/dev.dart`) is unchanged and does not sync (the web preview shows "Sync is not available in the web preview").
