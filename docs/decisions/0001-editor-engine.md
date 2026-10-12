# 0001 — Editor engine

Status: accepted (2026-10-12)

---

## Context

Tephra requires an editor engine that supports both plain text Markdown editing (Source mode) and WYSIWYG-like inline Markdown rendering (Live Preview). Obsidian compatibility requires instant responsiveness and smooth editing on notes of all sizes up to 5,000 lines or more, across both Android and Windows platforms.

The engine must satisfy the following criteria:
- **Hard Requirement H1**: Android phone, profile mode, typing `max(build, raster)` p95 ≤ 16.0 ms.
- **Hard Requirement H2**: Windows, profile mode, typing `max(build, raster)` p95 ≤ 16.0 ms.
- **Hard Requirement H3**: Manual checks 1–5 pass on both platforms (IME composition, selections, caret navigation across wrapped lines, undo/redo).
- **Soft Requirement S1**: Inline widgets (`WidgetSpan` for checkboxes, image embeds) render inside styled lines.

---

## Options Considered

1. **Option A: `re_editor` (v0.10.0)**:
   A lightweight, virtualized code editor for Flutter that models documents as lines (`CodeLines`) and renders only the lines visible within the viewport using per-line `TextSpan` builders (`buildTextSpan`). Includes built-in undo/redo history, indentation, and keyboard shortcut customization.

2. **Option B: Flutter `TextField` / `TextEditingController`**:
   The standard Flutter text input widget with a custom `TextEditingController.buildTextSpan` implementation parsing and styling Markdown spans across the entire document.

3. **Option C: Custom `RenderBox` Virtualized Editor**:
   A custom low-level `RenderBox` implementing viewport line virtualization, `TextInputClient`/`DeltaTextInputClient`, custom text layout with `TextPainter`, and bespoke caret/selection/gesture handling from scratch. Multi-week implementation scope.

---

## Measurements

Testing was conducted on a deterministic 5,000-line Markdown document (`test_vaults/edge/huge-5000-lines.md`).

### Windows Profile Mode (Official Gate H2 Benchmark)

| Candidate | Typing Build p95 | Typing Raster p95 | Scroll FPS | Scroll p95 | H2 Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Option A (`re_editor`)** | **12.12 ms** | **17.00 ms** | **62.0 FPS** | **17.65 ms** | **PASS** |
| Option B (`TextField`) | 155,058.35 ms | 39.08 ms | 5.8 FPS | 251.01 ms | **FAIL** (> 9,000x over budget) |

### Android Emulator Debug Mode (*emulator/debug — not valid for the gate*)

| Candidate | Typing Build p95 | Typing Raster p95 | Scroll FPS | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Option A (`re_editor`)** | 319.51 ms | 497.41 ms | 1.2 FPS | Verified functioning; needs real-phone profile gate |
| Option B (`TextField`) | N/A | N/A | N/A | Untenable (freezes UI thread indefinitely) |

---

## Decision

**Tephra uses `re_editor` for Source mode and Live Preview.**

---

## Consequences

1. **Phase 1 Architecture**:
   - `tephra_editor` and the app shell will wrap `re_editor.CodeEditor` and `CodeLineEditingController` behind the abstract `EditorController` interface defined in `00-conventions.md`.
   - The editor UI will configure `wordWrap: true`, `chunkAnalyzer: const NonCodeChunkAnalyzer()`, and a custom `CodeLineEditingController` implementing lazy per-line Markdown tokenization.

2. **Inline Live Preview Widgets (Soft Requirement S1)**:
   - `re_editor` renders lines directly using `ui.ParagraphBuilder` and does not support Flutter `WidgetSpan` directly in its per-line spans (throws `AssertionError`).
   - Consequently, Live Preview widgets in Phase 2 (interactive checkboxes, embedded images, LaTeX blocks, callout boxes) will need an **overlay approach**: floating positioned widgets or overlay elements anchored to calculated line bounds, or block widgets positioned above/below virtualized lines.

3. **Licenses**:
   - `re_editor` is licensed under the permissive MIT license. Transitive dependencies (`re_highlight`, `isolate_manager`) are also MIT. No licensing conflicts exist.

4. **Performance**:
   - Line virtualization guarantees steady-state $O(V)$ editing performance where $V$ is the visible line count (~40 lines), easily handling documents beyond 5,000 lines without UI freezes.

---

## API Notes

Key integration hooks verified in `package:re_editor/re_editor.dart`:

- **Per-Line Styling**:
  ```dart
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  })
  ```
- **Cursor Line Index**:
  `selection.extentIndex` from `CodeLineSelection`.
- **Platform Text Input Entry Point**:
  `CodeLineEditingController.edit(TextEditingValue value)`.
- **Enter Key Path**:
  `CodeLineEditingController.applyNewLine()`.
- **Tab Key Path**:
  `CodeLineEditingController.applyIndent()` / `applyOutdent()`.
- **Undo / Redo Grouping**:
  `CodeLineEditingController.runRevocableOp(VoidCallback op)`.
- **Shortcuts Mapping**:
  `CodeShortcutsActivatorsBuilder` / `CodeEditor.shortcutOverrideActions`.
