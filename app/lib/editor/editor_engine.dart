// © 2026 Tephra. All rights reserved.

import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'editor_decorator.dart';
import 'editor_options.dart';
import 'folding/fold_controller.dart';
import 'highlight/source_highlighter.dart';
import 'line_view.dart';

/// Single change event emitted by an [EditorEngine].
final class EngineChange {
  const EngineChange({
    required this.start,
    required this.deletedLength,
    required this.insertedText,
    required this.isUndoRedo,
    required this.startPos,
    required this.endPos,
  });

  /// UTF-16 offset in the text BEFORE the change.
  final int start;

  /// Number of UTF-16 code units deleted from [start].
  final int deletedLength;

  /// Text inserted at [start].
  final String insertedText;

  /// True if the change was produced by an undo or redo action.
  final bool isUndoRedo;

  /// Line position where the change starts in the text BEFORE the change.
  final LinePos startPos;

  /// Line position where the deleted range ends in the text BEFORE the change.
  final LinePos endPos;

  @override
  String toString() =>
      'EngineChange(start: $start, del: $deletedLength, ins: "$insertedText", undo: $isUndoRedo, startPos: $startPos, endPos: $endPos)';
}

/// Handlers called by an engine adapter before applying a user input.
///
/// Returning `true` indicates the input was handled and should not execute default engine behavior.
final class EngineInputHandlers {
  const EngineInputHandlers({
    required this.onTypedText,
    required this.onEnter,
    required this.onBackspace,
    required this.onTab,
    required this.onPaste,
  });

  /// Called when text is typed or committed by an IME.
  final bool Function(String typed) onTypedText;

  /// Called on the Enter key.
  final bool Function() onEnter;

  /// Called on the Backspace key.
  final bool Function() onBackspace;

  /// Called on Tab (with [shift] indicating Shift+Tab).
  final bool Function(bool shift) onTab;

  /// Called on paste actions.
  final Future<bool> Function() onPaste;
}

/// Configuration passed to [EditorEngine.buildView].
final class EditorViewConfig {
  const EditorViewConfig({
    required this.options,
    required this.readOnly,
    required this.baseStyle,
    required this.handlers,
    this.autofocus = false,
    this.foldController,
  });

  final EditorOptions options;
  final bool readOnly;
  final TextStyle baseStyle;
  final EngineInputHandlers handlers;
  final bool autofocus;
  final FoldController? foldController;
}

/// Abstract contract for editor engine implementations.
abstract interface class EditorEngine {
  /// Live view of the document lines.
  LineView get lines;

  /// Full text normalized with `\n`.
  String get text;

  /// Current selection.
  EditorSelection get selection;
  set selection(EditorSelection s);

  /// Applies all edits in [plan] and updates selection as a single undoable step.
  void applyPlan(EditPlan plan);

  /// Replaces text in `[startOffset, endOffset)` as a single undoable step.
  void replaceRange(int startOffset, int endOffset, String text);

  /// Replaces the entire text, optionally clearing undo/redo history.
  void setText(String text, {required bool clearHistory});

  bool get canUndo;
  bool get canRedo;
  void undo();
  void redo();
  void clearUndoHistory();

  /// Stream of text modifications.
  Stream<EngineChange> get changes;

  /// Stream of cursor/selection movements without text modification.
  Stream<void> get selectionChanges;

  /// Stream of focus gain/loss events.
  Stream<bool> get focusChanges;

  void requestFocus();
  bool get hasFocus;

  /// Scrolls the viewport so [offset] is visible.
  void reveal(int offset, {required bool center});

  /// Global screen coordinates of the caret rectangle, or null if unrendered.
  Rect? caretRectGlobal();

  /// Sets the token highlighter for per-line rendering.
  void setHighlighter(SourceHighlighter highlighter);

  /// Sets the line decorator (e.g. for Live Preview mode). Passing null restores Source mode highlighting.
  void setDecorator(EditorDecorator? decorator);

  /// Installs an interceptor for tap/pointer events on the editor.
  void setTapInterceptor(
    bool Function(int offset, PointerDeviceKind kind, bool control)? fn,
  );

  /// Global screen coordinates of [start] to [end] range, or null if unrendered.
  Rect? rectForRange(int start, int end);

  /// Requests repainting of line indices from [firstLine] to [lastLine].
  void repaintLines(int firstLine, int lastLine);

  /// Builds the engine's Flutter widget.
  Widget buildView(BuildContext context, EditorViewConfig config);

  /// Focus node of the editor input widget.
  FocusNode get focusNode;

  /// Active IME composing range, or [TextRange.empty] if none.
  TextRange get composing;

  void dispose();
}
