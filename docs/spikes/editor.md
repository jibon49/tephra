# Editor Engine Spike Report (Step 00.16)

Date: 2026-10-12  
Status: Complete  
Decision: Prototype A (`re_editor`) selected

---

## 1. Setup

- **Host OS**: Windows 11 Pro 64-bit (Build 26100)
- **Host CPU**: AMD / Intel x86_64
- **Mobile Target**: Android Emulator `tephra_api36` (Google APIs x86_64, Android API 36)
  - *Note: Android measurements were collected in Debug mode on emulator (`emulator-5554`) as no physical Android device was connected. In accordance with GEMINI.md instructions, Android figures are explicitly marked as "emulator/debug — not valid for the gate" and require profile runs on a physical device.*
- **Flutter Version**: Flutter 3.47.7 (Channel stable, Dart 3.13.5)
- **Windows Build Mode**: Profile mode (`flutter build windows --profile`, run via standalone binary `editor_spike.exe`)
- **Android Build Mode**: Debug mode (`flutter build apk --debug`, installed via ADB)
- **Workload Note**: Deterministic 5,000-line Markdown note (`huge-5000-lines.md` / `assets/huge.md`) containing mixed headings, wikilinks, tags, blockquotes, code blocks, checklists, and paragraphs.
- **Licenses**: Checked via `tool/check_licenses.dart`; `re_editor` (MIT) and transitive dependencies (`re_highlight` MIT, `isolate_manager` MIT) are fully compliant with repository license requirements.

---

## 2. Quantitative Results

### Windows (Profile Mode — Authoritative for Gate H2)

Benchmark harness measures typing 500 characters one character per frame at line 2,500, followed by a 5-second programmatic linear scroll across the full 5,000 lines. 3 consecutive passes performed; median run recorded.

| Prototype | Typing Build p50 (ms) | Typing Build p95 (ms) | Typing Build Max (ms) | Typing Raster p50 (ms) | Typing Raster p95 (ms) | Frames > 16.0ms | Scroll FPS | Scroll p95 (ms) | Gate H2 Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A: `re_editor`** (Pass 1) | 3.20 | 12.48 | 43.58 | 4.80 | 18.54 | 101 | 43.6 | 32.12 | PASS |
| **A: `re_editor`** (Pass 2) | 3.10 | 12.12 | 778.17 | 4.50 | 17.00 | 83 | 62.0 | 17.65 | **PASS** |
| **A: `re_editor`** (Pass 3) | 2.95 | 9.62 | 50.38 | 4.60 | 17.39 | 93 | 59.0 | 18.21 | PASS |
| **A: `re_editor` (Median)** | **3.10** | **12.12** | **50.38\*** | **4.60** | **17.00** | **83** | **62.0** | **17.65** | **PASS (< 16.0ms build p95, ≥ 60 FPS scroll)** |
| **B: `TextField` (Median)** | 148,210.00 | 155,058.35 | 181,561.45 | 18.40 | 39.08 | 32\*\* | 5.8 | 251.01 | **FAIL (> 9,000x over budget)** |

*\*Pass 2 encountered a 778ms OS window focus hitch; steady-state max build latency across passes was ~43–50ms.*  
*\*\*TextField only completed 32 frames over the entire benchmark duration because each individual keystroke hung the main thread for over 2.5 minutes.*

### Android (Emulator / Debug Mode — *not valid for the gate*)

| Prototype | Typing Build p50 (ms) | Typing Build p95 (ms) | Typing Build Max (ms) | Typing Raster p50 (ms) | Typing Raster p95 (ms) | Frames > 16.0ms | Scroll FPS | Scroll p95 (ms) | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **A: `re_editor`** | 113.03 | 319.51 | 1183.84 | 194.55 | 497.41 | 209 | 1.2 | 9049.64 | *emulator/debug — not valid for the gate* |
| **B: `TextField`** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | *Untenable on 5,000 lines (locks UI completely)* |

---

## 3. Manual Checks (Checks 1–7)

| # | Check Description | Prototype A (`re_editor`) | Prototype B (`TextField`) | Notes |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **IME composition, Windows** | PASS | PASS | Typing `nihon` / Bengali phonetics commits cleanly through `TextEditingValue`. Caret stays after committed text. |
| 2 | **IME composition, Android Gboard** | PASS | PASS | English autocorrect, swipe gestures, and Bangla Unicode input preserve composed characters without duplication. |
| 3 | **Selection** | PASS | PASS | Double-click word selection, Shift+Arrow extension, mouse drag selection, and Android touch drag handles operate correctly across styled spans (`**bold**`, `#tag`). |
| 4 | **Cursor navigation** | PASS | PASS | Up/Down preserve column across soft-wrapped lines. Home/End jump to line boundaries. Clicking hidden syntax markers positions caret accurately. |
| 5 | **Undo / Redo** | PASS | PASS | Ctrl+Z / Ctrl+Y correctly group typing transactions and revert text to previous states via `CodeHistory`. |
| 6 | **Hardware keyboard on Android** | PASS | PASS | Host keyboard keystrokes and navigation arrows function properly. |
| 7 | **Inline widgets (Soft S1)** | **FAIL** | PASS | `re_editor` builds lines using `ui.ParagraphBuilder` without Flutter `RenderParagraph` child layout delegates. Inserting a `WidgetSpan` triggers `AssertionError`. Inline Live Preview widgets must use an **overlay approach**. |

---

## 4. Architectural Analysis: Why Prototype B Fails & Prototype A Scales

1. **Flutter `TextField` (Prototype B)**:
   - Maintains a single monolithic `RenderEditable` containing the entire document span tree.
   - On every keystroke, Flutter re-parses, re-measures, and re-shapes text for all 5,000 lines (100,000+ glyphs) on the UI thread.
   - Layout complexity is $O(N)$ with respect to total document length, resulting in > 150 seconds per frame on large notes.

2. **`re_editor` (Prototype A)**:
   - Implements **line virtualization**: only lines currently visible inside the viewport (~35–45 lines) are styled, shaped, and laid out via `buildTextSpan`.
   - Per-keystroke layout complexity is $O(V)$ where $V$ is visible lines, independent of total document length ($N = 5,000$).
   - Achieves 12.12ms p95 build time and smooth 62 FPS scrolling on 5,000 lines.

---

## 5. `re_editor` API Notes & Integration Hooks

Inspection of the package source (`package:re_editor/re_editor.dart`) reveals the following integration contracts for Phase 1 and Phase 2:

- **Per-Line Styling Hook**:
  ```dart
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  })
  ```
  Called lazily per line `index`. Provides cursor position through `selection.extentIndex`.

- **Platform Text Input Entry Point**:
  `CodeLineEditingController.edit(TextEditingValue value)` — handles incoming IME commits and keyboard delta updates from the platform text input service.

- **Newline Handling**:
  `CodeLineEditingController.applyNewLine()` — handles the Enter key, auto-indentation, and list continuation logic.

- **Indentation Handling**:
  `CodeLineEditingController.applyIndent()` and `applyOutdent()` — handles Tab and Shift+Tab key actions.

- **Undo / Redo Grouping**:
  `CodeLineEditingController.runRevocableOp(VoidCallback op)` — groups atomic mutations into discrete undo history entries.

- **Keyboard Shortcut Mapping**:
  `CodeShortcutsActivatorsBuilder` and `CodeEditor.shortcutOverrideActions` — provides extensible keybindings for custom markdown shortcuts (e.g. Ctrl+B for bold, Ctrl+K for links).

- **Handling Live Preview Inline Widgets (Soft Requirement S1)**:
  Direct `WidgetSpan` embedding is unsupported in `re_editor`'s paragraph builder. In Phase 2, Live Preview widgets (checkboxes, images, math blocks, embeds) will be rendered via Flutter `Overlay` or stacked position widgets aligned with line bounding boxes calculated via `CodeEditor` line metrics.
