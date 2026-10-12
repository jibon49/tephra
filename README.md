# Tephra

Obsidian-compatible Markdown notes for Android and Windows, written in Flutter.
Agent rules: GEMINI.md. Technical contract: instructions/00-conventions.md.

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
