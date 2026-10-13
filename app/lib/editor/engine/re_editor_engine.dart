// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../editor_engine.dart';
import '../highlight/source_highlighter.dart';
import '../line_view.dart';

/// Adapter implementing [EditorEngine] on top of `re_editor`'s [CodeEditor].
class ReEditorEngine implements EditorEngine {
  ReEditorEngine([String initialText = '']) {
    _initController(initialText);
  }

  late CodeLineEditingController _controller;
  late final CodeScrollController _scrollController = CodeScrollController();
  late final FocusNode _focusNode = FocusNode();

  final _changeController = StreamController<EngineChange>.broadcast();
  final _selectionController = StreamController<void>.broadcast();
  final _focusController = StreamController<bool>.broadcast();

  SourceHighlighter? _highlighter;
  late List<String> _prevLines;
  bool _isUndoRedo = false;
  bool _isDisposed = false;

  void _initController(String initialText) {
    _controller = CodeLineEditingController(
      codeLines: initialText.isEmpty
          ? CodeLines.fromText('')
          : CodeLines.fromText(initialText),
      options: const CodeLineOptions(
        indentSize: 4,
        lineBreak: TextLineBreak.lf,
      ),
      spanBuilder:
          ({
            required BuildContext context,
            required int index,
            required CodeLine codeLine,
            required TextSpan textSpan,
            required TextStyle style,
          }) {
            if (_highlighter != null) {
              return _highlighter!.spanFor(
                index,
                textSpan.toPlainText(),
                style,
                Theme.of(context),
              );
            }
            return textSpan;
          },
    );

    _prevLines = _extractLines(_controller.codeLines);
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  LineView get lines => _ReEditorLineView(_controller);

  @override
  String get text => _controller.text;

  @override
  EditorSelection get selection {
    final sel = _controller.selection;
    return EditorSelection(
      LinePos(sel.baseIndex, sel.baseOffset),
      LinePos(sel.extentIndex, sel.extentOffset),
    );
  }

  @override
  set selection(EditorSelection s) {
    _controller.selection = CodeLineSelection(
      baseIndex: s.base.line,
      baseOffset: s.base.col,
      extentIndex: s.extent.line,
      extentOffset: s.extent.col,
    );
  }

  @override
  bool get canUndo => _controller.canUndo;

  @override
  bool get canRedo => _controller.canRedo;

  @override
  Stream<EngineChange> get changes => _changeController.stream;

  @override
  Stream<void> get selectionChanges => _selectionController.stream;

  @override
  Stream<bool> get focusChanges => _focusController.stream;

  @override
  bool get hasFocus => _focusNode.hasFocus;

  @override
  void requestFocus() {
    _focusNode.requestFocus();
  }

  @override
  void clearUndoHistory() {
    _controller.clearHistory();
  }

  @override
  void setText(String text, {required bool clearHistory}) {
    if (clearHistory) {
      _controller.clearHistory();
    }
    _controller.codeLines = CodeLines.fromText(text);
    _prevLines = _extractLines(_controller.codeLines);
  }

  @override
  void applyPlan(EditPlan plan) {
    _controller.runRevocableOp(() {
      final currentLines = lines;
      // Sort edits descending
      final sortedEdits = List<LineEdit>.from(plan.edits)
        ..sort((a, b) {
          final aOffset = offsetOf(currentLines, a.start);
          final bOffset = offsetOf(currentLines, b.start);
          return bOffset.compareTo(aOffset);
        });

      for (final edit in sortedEdits) {
        _controller.replaceSelection(
          edit.text,
          CodeLineSelection(
            baseIndex: edit.start.line,
            baseOffset: edit.start.col,
            extentIndex: edit.end.line,
            extentOffset: edit.end.col,
          ),
        );
      }
    });

    selection = plan.selection;
  }

  @override
  void replaceRange(int startOffset, int endOffset, String text) {
    final currentLines = lines;
    final startPos = posOf(currentLines, startOffset);
    final endPos = posOf(currentLines, endOffset);

    _controller.runRevocableOp(() {
      _controller.replaceSelection(
        text,
        CodeLineSelection(
          baseIndex: startPos.line,
          baseOffset: startPos.col,
          extentIndex: endPos.line,
          extentOffset: endPos.col,
        ),
      );
    });
  }

  @override
  void undo() {
    if (!_controller.canUndo) return;
    _isUndoRedo = true;
    try {
      _controller.undo();
    } finally {
      _isUndoRedo = false;
    }
  }

  @override
  void redo() {
    if (!_controller.canRedo) return;
    _isUndoRedo = true;
    try {
      _controller.redo();
    } finally {
      _isUndoRedo = false;
    }
  }

  @override
  void reveal(int offset, {required bool center}) {
    final pos = posOf(lines, offset);
    final linePos = CodeLinePosition(index: pos.line, offset: pos.col);
    if (center) {
      _controller.makePositionCenterIfInvisible(linePos);
    } else {
      _controller.makePositionVisible(linePos);
    }
  }

  @override
  Rect? caretRectGlobal() => null;

  @override
  void setHighlighter(SourceHighlighter highlighter) {
    _highlighter = highlighter;
  }

  @override
  void repaintLines(int firstLine, int lastLine) {
    _controller.forceRepaint();
  }

  @override
  Widget buildView(BuildContext context, EditorViewConfig config) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final overrideActions = <Type, Action<Intent>>{
      CodeShortcutNewLineIntent: CallbackAction<CodeShortcutNewLineIntent>(
        onInvoke: (intent) {
          if (config.handlers.onEnter()) return null;
          _controller.applyNewLine();
          return null;
        },
      ),
      CodeShortcutIndentIntent: CallbackAction<CodeShortcutIndentIntent>(
        onInvoke: (intent) {
          if (config.handlers.onTab(false)) return null;
          _controller.applyIndent();
          return null;
        },
      ),
      CodeShortcutOutdentIntent: CallbackAction<CodeShortcutOutdentIntent>(
        onInvoke: (intent) {
          if (config.handlers.onTab(true)) return null;
          _controller.applyOutdent();
          return null;
        },
      ),
      CodeShortcutDeleteIntent: CallbackAction<CodeShortcutDeleteIntent>(
        onInvoke: (intent) {
          if (!intent.forward && _controller.selection.isCollapsed) {
            if (config.handlers.onBackspace()) return null;
          }
          if (intent.forward) {
            _controller.deleteForward();
          } else {
            _controller.deleteBackward();
          }
          return null;
        },
      ),
      CodeShortcutPasteIntent: CallbackAction<CodeShortcutPasteIntent>(
        onInvoke: (intent) {
          config.handlers.onPaste().then((handled) {
            if (!handled) {
              _controller.paste();
            }
          });
          return null;
        },
      ),
    };

    return CodeEditor(
      controller: _controller,
      wordWrap: true,
      readOnly: config.readOnly,
      autofocus: config.autofocus,
      focusNode: _focusNode,
      scrollController: _scrollController,
      chunkAnalyzer: const NonCodeChunkAnalyzer(),
      indicatorBuilder: null,
      style: CodeEditorStyle(
        fontSize: config.options.fontSize,
        fontHeight: 1.5,
        textColor: theme.colorScheme.onSurface,
        backgroundColor: Colors.transparent,
        selectionColor: primary.withValues(alpha: 0.30),
        cursorColor: primary,
      ),
      shortcutsActivatorsBuilder: const _NoCommandShortcuts(),
      shortcutOverrideActions: overrideActions,
    );
  }

  void _onControllerChanged() {
    if (_isDisposed) return;

    final currentLines = _extractLines(_controller.codeLines);
    if (_linesEqual(_prevLines, currentLines)) {
      _selectionController.add(null);
      return;
    }

    // Compute diff between _prevLines and currentLines
    var top = 0;
    while (top < _prevLines.length &&
        top < currentLines.length &&
        _prevLines[top] == currentLines[top]) {
      top++;
    }

    var bottomPrev = _prevLines.length - 1;
    var bottomCurr = currentLines.length - 1;
    while (bottomPrev >= top &&
        bottomCurr >= top &&
        _prevLines[bottomPrev] == currentLines[bottomCurr]) {
      bottomPrev--;
      bottomCurr--;
    }

    var startOffset = 0;
    for (var i = 0; i < top; i++) {
      startOffset += _prevLines[i].length + 1;
    }

    final deletedText = _prevLines.sublist(top, bottomPrev + 1).join('\n');
    final insertedText = currentLines.sublist(top, bottomCurr + 1).join('\n');

    _prevLines = currentLines;

    _changeController.add(
      EngineChange(
        start: startOffset,
        deletedLength: deletedText.length,
        insertedText: insertedText,
        isUndoRedo: _isUndoRedo,
      ),
    );
  }

  void _onFocusChanged() {
    if (!_isDisposed) {
      _focusController.add(_focusNode.hasFocus);
    }
  }

  bool _linesEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);

    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();

    _changeController.close();
    _selectionController.close();
    _focusController.close();
  }
}

class _ReEditorLineView implements LineView {
  _ReEditorLineView(this.controller);
  final CodeLineEditingController controller;

  @override
  int get lineCount => controller.codeLines.length;

  @override
  String lineAt(int index) => controller.codeLines[index].text;
}

class _NoCommandShortcuts extends DefaultCodeShortcutsActivatorsBuilder {
  const _NoCommandShortcuts();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    switch (type) {
      case CodeShortcutType.undo:
      case CodeShortcutType.redo:
      case CodeShortcutType.find:
      case CodeShortcutType.replace:
      case CodeShortcutType.save:
        return null;
      default:
        return super.build(type);
    }
  }
}

List<String> _extractLines(CodeLines codeLines) {
  final list = <String>[];
  for (var i = 0; i < codeLines.length; i++) {
    list.add(codeLines[i].text);
  }
  return list;
}
