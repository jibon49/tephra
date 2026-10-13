// © 2026 Tephra. All rights reserved.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tephra/editor/editor_engine.dart';
import 'package:tephra/editor/highlight/source_highlighter.dart';
import 'package:tephra/editor/line_view.dart';

final class _HistoryEntry {
  const _HistoryEntry(this.text, this.selection);
  final String text;
  final EditorSelection selection;
}

/// In-memory fake implementation of [EditorEngine] for unit tests.
class FakeEditorEngine implements EditorEngine {
  FakeEditorEngine([String initialText = '']) {
    _text = initialText;
    _lines = ListLineView.fromText(initialText);
  }

  String _text = '';
  late ListLineView _lines;
  EditorSelection _selection = const EditorSelection.collapsed(LinePos(0, 0));

  final List<_HistoryEntry> _undoStack = [];
  final List<_HistoryEntry> _redoStack = [];

  final _changeController = StreamController<EngineChange>.broadcast(
    sync: true,
  );
  final _selectionController = StreamController<void>.broadcast(sync: true);
  final _focusController = StreamController<bool>.broadcast(sync: true);

  bool _hasFocus = false;
  SourceHighlighter? highlighter;

  @override
  LineView get lines => _lines;

  @override
  String get text => _text;

  @override
  EditorSelection get selection => _selection;

  @override
  set selection(EditorSelection s) {
    if (_selection != s) {
      _selection = s;
      _selectionController.add(null);
    }
  }

  @override
  bool get canUndo => _undoStack.isNotEmpty;

  @override
  bool get canRedo => _redoStack.isNotEmpty;

  @override
  Stream<EngineChange> get changes => _changeController.stream;

  @override
  Stream<void> get selectionChanges => _selectionController.stream;

  @override
  Stream<bool> get focusChanges => _focusController.stream;

  @override
  bool get hasFocus => _hasFocus;

  void setFocus(bool focus) {
    if (_hasFocus != focus) {
      _hasFocus = focus;
      _focusController.add(focus);
    }
  }

  @override
  void requestFocus() => setFocus(true);

  @override
  void clearUndoHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  @override
  void setText(String text, {required bool clearHistory}) {
    if (clearHistory) {
      clearUndoHistory();
    }
    _text = text;
    _lines = ListLineView.fromText(text);
    _selection = const EditorSelection.collapsed(LinePos(0, 0));
    _changeController.add(
      EngineChange(
        start: 0,
        deletedLength: 0,
        insertedText: text,
        isUndoRedo: false,
      ),
    );
  }

  @override
  void applyPlan(EditPlan plan) {
    _undoStack.add(_HistoryEntry(_text, _selection));
    _redoStack.clear();

    final prevLines = _lines;
    // Sort edits descending by start offset
    final sortedEdits = List<LineEdit>.from(plan.edits)
      ..sort((a, b) {
        final aOffset = offsetOf(prevLines, a.start);
        final bOffset = offsetOf(prevLines, b.start);
        return bOffset.compareTo(aOffset);
      });

    for (final edit in sortedEdits) {
      final currentLines = _lines;
      final start = offsetOf(currentLines, edit.start);
      final end = offsetOf(currentLines, edit.end);
      final delLen = end - start;
      _text = _text.substring(0, start) + edit.text + _text.substring(end);
      _lines = ListLineView.fromText(_text);

      _changeController.add(
        EngineChange(
          start: start,
          deletedLength: delLen,
          insertedText: edit.text,
          isUndoRedo: false,
        ),
      );
    }

    _selection = plan.selection;
    _selectionController.add(null);
  }

  @override
  void replaceRange(int startOffset, int endOffset, String replacement) {
    _undoStack.add(_HistoryEntry(_text, _selection));
    _redoStack.clear();

    final delLen = endOffset - startOffset;
    _text =
        _text.substring(0, startOffset) +
        replacement +
        _text.substring(endOffset);
    _lines = ListLineView.fromText(_text);

    _changeController.add(
      EngineChange(
        start: startOffset,
        deletedLength: delLen,
        insertedText: replacement,
        isUndoRedo: false,
      ),
    );
  }

  @override
  void undo() {
    if (!canUndo) return;
    _redoStack.add(_HistoryEntry(_text, _selection));
    final entry = _undoStack.removeLast();

    final oldText = _text;
    _text = entry.text;
    _lines = ListLineView.fromText(_text);
    _selection = entry.selection;

    _changeController.add(
      EngineChange(
        start: 0,
        deletedLength: oldText.length,
        insertedText: _text,
        isUndoRedo: true,
      ),
    );
    _selectionController.add(null);
  }

  @override
  void redo() {
    if (!canRedo) return;
    _undoStack.add(_HistoryEntry(_text, _selection));
    final entry = _redoStack.removeLast();

    final oldText = _text;
    _text = entry.text;
    _lines = ListLineView.fromText(_text);
    _selection = entry.selection;

    _changeController.add(
      EngineChange(
        start: 0,
        deletedLength: oldText.length,
        insertedText: _text,
        isUndoRedo: true,
      ),
    );
    _selectionController.add(null);
  }

  @override
  void reveal(int offset, {required bool center}) {}

  @override
  Rect? caretRectGlobal() => null;

  @override
  void setHighlighter(SourceHighlighter highlighter) {
    this.highlighter = highlighter;
  }

  @override
  void repaintLines(int firstLine, int lastLine) {}

  @override
  Widget buildView(BuildContext context, EditorViewConfig config) {
    return Container();
  }

  @override
  void dispose() {
    _changeController.close();
    _selectionController.close();
    _focusController.close();
  }
}
