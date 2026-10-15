// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../editor_decorator.dart';
import '../editor_engine.dart';
import '../folding/fold_controller.dart';
import '../folding/fold_gutter.dart';
import '../highlight/source_highlighter.dart';
import '../line_view.dart';
import '../offset_map_utils.dart';
import 're_editor_chunk_analyzer.dart';

/// Adapter implementing [EditorEngine] on top of `re_editor`'s [CodeEditor].
class ReEditorEngine implements EditorEngine {
  ReEditorEngine([String initialText = '']) {
    _initController(initialText);
  }

  late final _InterceptingCodeLineController _controller;
  late final _CustomCodeScrollController _scrollController =
      _CustomCodeScrollController();
  late final FocusNode _focusNode = FocusNode();

  final _changeController = StreamController<EngineChange>.broadcast(
    sync: true,
  );
  final _selectionController = StreamController<void>.broadcast(sync: true);
  final _focusController = StreamController<bool>.broadcast(sync: true);

  SourceHighlighter? _highlighter;
  EditorDecorator? _decorator;
  bool Function(int offset, PointerDeviceKind kind, bool control)?
  _tapInterceptor;
  DateTime? _suppressSelectionUntil;
  List<int> _lineStarts = const [0];
  late List<String> _prevLines;
  bool _isUndoRedo = false;
  bool _isDisposed = false;

  /// Predicate indicating whether an IME/text edit should be intercepted.
  static bool shouldInterceptEdit(TextEditingValue value) =>
      _InterceptingCodeLineController.shouldIntercept(value);

  /// Feeds a text editing value into the engine's intercepting controller.
  void edit(TextEditingValue value) => _controller.edit(value);

  /// Collapses lines from [start] to [end] natively in `re_editor`.
  void collapseChunk(int start, int end) =>
      _controller.collapseChunk(start, end);

  /// Expands lines at [index] natively in `re_editor`.
  void expandChunk(int index) => _controller.expandChunk(index);

  /// Returns true if the line at [index] is currently collapsed.
  bool isLineCollapsed(int index) {
    if (index < 0 || index >= _controller.codeLines.length) return false;
    return _controller.codeLines[index].chunkParent;
  }

  /// Simulates typing text character-by-character at the current cursor position.
  void typeText(String text) {
    for (final char in text.characters) {
      if (char == '\n') {
        if (_controller.handlers?.onEnter() ?? false) {
          continue;
        }
        _controller.applyNewLine();
        continue;
      }
      final handled = _controller.handlers?.onTypedText(char) ?? false;
      if (!handled) {
        _controller.replaceSelection(char);
      }
    }
  }

  void _initController(String initialText) {
    final base = CodeLineEditingController(
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
            if (_decorator != null) {
              final lineStart = index < _lineStarts.length
                  ? _lineStarts[index]
                  : 0;
              final lineEnd = lineStart + codeLine.text.length;
              return _decorator!.decorateLine(
                lineStart: lineStart,
                lineEnd: lineEnd,
                plain: textSpan,
                base: style,
              );
            }
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
    _controller = _InterceptingCodeLineController(delegate: base);

    _prevLines = _extractLines(_controller.codeLines);
    _rebuildLineStarts();
    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  FocusNode get focusNode => _focusNode;

  @override
  TextRange get composing {
    final c = _controller.value.composing;
    if (!c.isValid || c == const TextRange(start: -1, end: -1)) {
      return TextRange.empty;
    }
    return c;
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
    _rebuildLineStarts();
  }

  @override
  void applyPlan(EditPlan plan) {
    if (plan.edits.isEmpty) {
      selection = plan.selection;
      return;
    }

    final currentLines = lines;
    // Sort edits descending
    final sortedEdits = List<LineEdit>.from(plan.edits)
      ..sort((a, b) {
        final aOffset = offsetOf(currentLines, a.start);
        final bOffset = offsetOf(currentLines, b.start);
        return bOffset.compareTo(aOffset);
      });

    if (sortedEdits.length == 1) {
      final edit = sortedEdits.first;
      _controller.runRevocableOp(() {
        _controller.replaceSelection(
          edit.text,
          CodeLineSelection(
            baseIndex: edit.start.line,
            baseOffset: edit.start.col,
            extentIndex: edit.end.line,
            extentOffset: edit.end.col,
          ),
        );
      });
      selection = plan.selection;
      return;
    }

    // Multiple edits: apply descending to form new text and update value once
    var newText = text;
    for (final edit in sortedEdits) {
      final start = offsetOf(currentLines, edit.start);
      final end = offsetOf(currentLines, edit.end);
      newText = newText.replaceRange(start, end, edit.text);
    }

    final targetSelection = CodeLineSelection(
      baseIndex: plan.selection.base.line,
      baseOffset: plan.selection.base.col,
      extentIndex: plan.selection.extent.line,
      extentOffset: plan.selection.extent.col,
    );

    _controller.runRevocableOp(() {
      _controller.value = CodeLineEditingValue(
        codeLines: CodeLines.fromText(newText),
        selection: targetSelection,
      );
    });
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
  Rect? caretRectGlobal() {
    final render = _scrollController.editorKey?.currentContext
        ?.findRenderObject();
    if (render == null || render is! RenderBox) return null;
    final dynamic fieldRender = render;
    try {
      final sel = selection.extent;
      final pos = CodeLinePosition(index: sel.line, offset: sel.col);
      final Offset? top =
          // ignore: avoid_dynamic_calls // _CodeFieldRender is a private class in package:re_editor
          fieldRender.calculateTextPositionScreenOffset(pos, false) as Offset?;
      final Offset? bottom =
          // ignore: avoid_dynamic_calls // _CodeFieldRender is a private class in package:re_editor
          fieldRender.calculateTextPositionScreenOffset(pos, true) as Offset?;
      if (top == null || bottom == null) return null;
      return Rect.fromPoints(top, bottom);
    } catch (_) {
      return null;
    }
  }

  @override
  void setHighlighter(SourceHighlighter highlighter) {
    _highlighter = highlighter;
  }

  @override
  void setDecorator(EditorDecorator? decorator) {
    if (_decorator != decorator) {
      _decorator?.changes.removeListener(_onDecoratorChanged);
      _decorator = decorator;
      _decorator?.changes.addListener(_onDecoratorChanged);
      _controller.forceRepaint();
    }
  }

  void _onDecoratorChanged() {
    _controller.forceRepaint();
  }

  @override
  void setTapInterceptor(
    bool Function(int offset, PointerDeviceKind kind, bool control)? fn,
  ) {
    _tapInterceptor = fn;
  }

  @override
  Rect? rectForRange(int start, int end) {
    final render = _scrollController.editorKey?.currentContext
        ?.findRenderObject();
    if (render == null || render is! RenderBox) return null;
    final dynamic fieldRender = render;
    try {
      final startPos = posOf(lines, start);
      final endPos = posOf(lines, end);
      final Offset? startOffset =
          // ignore: avoid_dynamic_calls // _CodeFieldRender is a private class in package:re_editor
          fieldRender.calculateTextPositionScreenOffset(
            CodeLinePosition(index: startPos.line, offset: startPos.col),
            false,
          ) as Offset?;
      final Offset? endOffset =
          // ignore: avoid_dynamic_calls // _CodeFieldRender is a private class in package:re_editor
          fieldRender.calculateTextPositionScreenOffset(
            CodeLinePosition(index: endPos.line, offset: endPos.col),
            true,
          ) as Offset?;
      if (startOffset == null || endOffset == null) return null;
      return Rect.fromPoints(startOffset, endOffset);
    } catch (_) {
      return null;
    }
  }

  @override
  void repaintLines(int firstLine, int lastLine) {
    _controller.forceRepaint();
  }

  @override
  Widget buildView(BuildContext context, EditorViewConfig config) {
    _controller.handlers = config.handlers;
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

    final editorWidget = CodeEditor(
      controller: _controller,
      autocompleteSymbols: false,
      wordWrap: true,
      readOnly: config.readOnly,
      autofocus: config.autofocus,
      focusNode: _focusNode,
      scrollController: _scrollController,
      chunkAnalyzer: MarkdownChunkAnalyzer(
        foldHeadings: config.foldController?.foldHeadings ?? true,
        foldIndent: config.foldController?.foldIndent ?? true,
      ),
      indicatorBuilder: config.foldController != null
          ? (context, editingController, chunkController, notifier) {
              return _ReEditorFoldGutter(
                controller: config.foldController!,
                indicatorNotifier: notifier,
              );
            }
          : null,
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_tapInterceptor == null) return;
        final render = _scrollController.editorKey?.currentContext
            ?.findRenderObject();
        if (render == null || render is! RenderBox) return;
        final dynamic fieldRender = render;
        try {
          final local = render.globalToLocal(event.position);
          final CodeLinePosition? linePos =
              // ignore: avoid_dynamic_calls // _CodeFieldRender is a private class in package:re_editor
              fieldRender.calculateTextPosition(local) as CodeLinePosition?;
          if (linePos != null) {
            final lineIndex = linePos.index;
            final lineOffset = linePos.offset;
            final lineStart = lineIndex < _lineStarts.length
                ? _lineStarts[lineIndex]
                : 0;
            final offset = lineStart + lineOffset;
            final isCtrl =
                HardwareKeyboard.instance.isControlPressed ||
                HardwareKeyboard.instance.isMetaPressed;
            final handled = _tapInterceptor!(offset, event.kind, isCtrl);
            if (handled) {
              _suppressSelectionUntil = DateTime.now().add(
                const Duration(milliseconds: 300),
              );
            }
          }
        } catch (_) {}
      },
      child: editorWidget,
    );
  }

  void _onControllerChanged() {
    if (_isDisposed) return;

    final currentLines = _extractLines(_controller.codeLines);
    if (_linesEqual(_prevLines, currentLines)) {
      if (_suppressSelectionUntil != null &&
          DateTime.now().isBefore(_suppressSelectionUntil!)) {
        return;
      }
      _selectionController.add(null);
      return;
    }

    _rebuildLineStarts();

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

    final deletedChunk = _prevLines.sublist(top, bottomPrev + 1).join('\n');
    final insertedChunk = currentLines.sublist(top, bottomCurr + 1).join('\n');

    final prefix = commonPrefixLength(deletedChunk, insertedChunk);
    final maxSuffix = min(
      deletedChunk.length - prefix,
      insertedChunk.length - prefix,
    );
    final suffix = commonSuffixLength(deletedChunk, insertedChunk, maxSuffix);

    final actualStartOffset = startOffset + prefix;
    final actualDeletedLength = deletedChunk.length - prefix - suffix;
    final actualInsertedText = insertedChunk.substring(
      prefix,
      insertedChunk.length - suffix,
    );

    final prevView = ListLineView(_prevLines);
    final startPos = posOf(prevView, actualStartOffset);
    final endPos = posOf(prevView, actualStartOffset + actualDeletedLength);

    _prevLines = currentLines;

    _changeController.add(
      EngineChange(
        start: actualStartOffset,
        deletedLength: actualDeletedLength,
        insertedText: actualInsertedText,
        isUndoRedo: _isUndoRedo,
        startPos: startPos,
        endPos: endPos,
      ),
    );
  }

  void _rebuildLineStarts() {
    final codeLines = _controller.codeLines;
    final starts = List<int>.filled(codeLines.length, 0);
    var offset = 0;
    for (var i = 0; i < codeLines.length; i++) {
      starts[i] = offset;
      offset += codeLines[i].text.length + 1;
    }
    _lineStarts = starts;
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

    _decorator?.changes.removeListener(_onDecoratorChanged);
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
      case CodeShortcutType.lineMoveUp:
      case CodeShortcutType.lineMoveDown:
        return null;
      case CodeShortcutType.newLine:
        return const [
          SingleActivator(LogicalKeyboardKey.enter),
          SingleActivator(LogicalKeyboardKey.enter, shift: true),
          SingleActivator(LogicalKeyboardKey.numpadEnter),
          SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true),
        ];
      default:
        return super.build(type);
    }
  }
}

/// Wrapper that intercepts [edit] calls to give [EngineInputHandlers.onTypedText]
/// a chance to handle typed characters before the default engine behavior.
///
/// Composing text (active IME) is never intercepted to avoid breaking CJK input.
class _InterceptingCodeLineController
    extends CodeLineEditingControllerDelegate {
  _InterceptingCodeLineController({required super.delegate});

  /// Handlers set by [ReEditorEngine.buildView] each frame.
  EngineInputHandlers? handlers;

  /// Returns `true` when the value is safe to intercept (not composing).
  static bool shouldIntercept(TextEditingValue value) {
    final c = value.composing;
    return !c.isValid || c == const TextRange(start: -1, end: -1);
  }

  @override
  void edit(TextEditingValue newValue) {
    if (handlers != null && shouldIntercept(newValue)) {
      final String textBefore = startLine.text.substring(
        0,
        selection.startOffset,
      );
      final String textAfter = selection.isSameLine
          ? startLine.text.substring(selection.endOffset)
          : endLine.text.substring(selection.endOffset);

      if (newValue.text.startsWith(textBefore) &&
          newValue.text.endsWith(textAfter) &&
          newValue.text.length >= textBefore.length + textAfter.length) {
        final inserted = newValue.text.substring(
          textBefore.length,
          newValue.text.length - textAfter.length,
        );
        if (inserted.length == 1) {
          if (handlers!.onTypedText(inserted)) return;
        }
      }
    }
    super.edit(newValue);
  }
}

List<String> _extractLines(CodeLines codeLines) {
  final list = <String>[];
  for (var i = 0; i < codeLines.length; i++) {
    list.add(codeLines[i].text);
  }
  return list;
}

class _CustomCodeScrollController extends CodeScrollController {
  GlobalKey? editorKey;

  @override
  void bindEditor(GlobalKey key) {
    editorKey = key;
    super.bindEditor(key);
  }
}

final class _ReEditorFoldGutter extends StatefulWidget {
  const _ReEditorFoldGutter({
    required this.controller,
    required this.indicatorNotifier,
  });

  final FoldController controller;
  final ValueNotifier<CodeIndicatorValue?> indicatorNotifier;

  @override
  State<_ReEditorFoldGutter> createState() => _ReEditorFoldGutterState();
}

final class _ReEditorFoldGutterState extends State<_ReEditorFoldGutter> {
  late final ValueNotifier<List<FoldGutterParagraph>?> _paragraphsNotifier;

  @override
  void initState() {
    super.initState();
    _paragraphsNotifier = ValueNotifier(
      _convert(widget.indicatorNotifier.value),
    );
    widget.indicatorNotifier.addListener(_onIndicatorChanged);
  }

  @override
  void didUpdateWidget(covariant _ReEditorFoldGutter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.indicatorNotifier != widget.indicatorNotifier) {
      oldWidget.indicatorNotifier.removeListener(_onIndicatorChanged);
      widget.indicatorNotifier.addListener(_onIndicatorChanged);
      _paragraphsNotifier.value = _convert(widget.indicatorNotifier.value);
    }
  }

  @override
  void dispose() {
    widget.indicatorNotifier.removeListener(_onIndicatorChanged);
    _paragraphsNotifier.dispose();
    super.dispose();
  }

  void _onIndicatorChanged() {
    _paragraphsNotifier.value = _convert(widget.indicatorNotifier.value);
  }

  static List<FoldGutterParagraph>? _convert(CodeIndicatorValue? val) {
    if (val == null) return null;
    return val.paragraphs
        .map(
          (p) =>
              FoldGutterParagraph(index: p.index, top: p.top, height: p.height),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FoldGutter(
      controller: widget.controller,
      paragraphsNotifier: _paragraphsNotifier,
    );
  }
}
