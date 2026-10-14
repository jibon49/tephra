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
