// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../reading/parse_service.dart';
import '../vault/note_document.dart';
import 'edit_operation.dart';
import 'editor_decorator.dart';
import 'editor_engine.dart';
import 'editor_input_handlers.dart';
import 'editor_options.dart';
import 'editor_registry.dart';
import 'find/find_controller.dart';
import 'helpers/auto_pair.dart';
import 'highlight/source_highlighter.dart';
import 'line_view.dart';
import 'live_preview/live_preview_session.dart';
import 'offset_map_utils.dart';

/// Single change event emitted by [EditorController].
final class EditorEdit {
  const EditorEdit({
    required this.start,
    required this.deletedLength,
    required this.insertedText,
    required this.isUndoRedo,
  });

  final int start;
  final int deletedLength;
  final String insertedText;
  final bool isUndoRedo;

  @override
  String toString() =>
      'EditorEdit(start: $start, del: $deletedLength, ins: "$insertedText", undo: $isUndoRedo)';
}

/// Controller connecting a [NoteDocument] to an [EditorEngine] with parse-driven highlighting.
final class EditorController
    implements NoteEditorBinding, LivePreviewEditorTarget {
  EditorController({
    required this.document,
    required this.engine,
    required this.options,
    required this.parseService,
    this.clock = const SystemClock(),
    this.registry,
    SourceHighlighter? highlighter,
  }) : highlighter = highlighter ?? SourceHighlighter() {
    if (document.editor != null) {
      throw StateError(
        'Document ${document.path} already has an attached editor.',
      );
    }

    document.attachEditor(this);
    registry?.register(this);

    engine.setHighlighter(this.highlighter);
    engine.setText(document.text, clearHistory: true);

    _changesSub = engine.changes.listen(_onEngineChange);
    _selectionSub = engine.selectionChanges.listen((_) {
      if (!_isDisposed) {
        _selectionChangesController.add(null);
      }
    });
    _focusSub = engine.focusChanges.listen((focused) {
      if (!focused && !_isDisposed) {
        unawaited(document.save());
      }
    });

    // Initial parse
    _scheduleParse();
  }

  final NoteDocument document;
  final EditorEngine engine;
  final ParseService parseService;
  final Clock clock;
  final EditorRegistry? registry;
  final SourceHighlighter highlighter;

  final AutoPairTracker tracker = AutoPairTracker();
  late final FindController findController = FindController(this);

  LineView get lines => engine.lines;

  void runPlan(EditPlan? plan) {
    if (plan != null) {
      engine.applyPlan(plan);
    }
  }

  void repaintLines(int firstLine, int lastLine) {
    engine.repaintLines(firstLine, lastLine);
  }

  EditorOptions options;

  final _editsController = StreamController<EditorEdit>.broadcast();
  final _selectionChangesController = StreamController<void>.broadcast();
  final _parsedChangesController = StreamController<ParsedNote>.broadcast();

  StreamSubscription<EngineChange>? _changesSub;
  StreamSubscription<void>? _selectionSub;
  StreamSubscription<bool>? _focusSub;
  Timer? _parseTimer;

  bool _isDisposed = false;
  ParsedNote? _parsed;

  VaultPath get path => document.path;

  @override
  String get text => engine.text;

  @override
  TextSelection get selection {
    final v = engine.lines;
    final sel = engine.selection;
    return TextSelection(
      baseOffset: offsetOf(v, sel.base),
      extentOffset: offsetOf(v, sel.extent),
    );
  }

  void select(int start, [int? end]) {
    end ??= start;
    final totalLen = text.length;
    final clampedStart = start.clamp(0, totalLen);
    final clampedEnd = end.clamp(0, totalLen);

    final v = engine.lines;
    engine.selection = EditorSelection(
      posOf(v, clampedStart),
      posOf(v, clampedEnd),
    );
  }

  @override
  Stream<EditorEdit> get edits => _editsController.stream;

  @override
  Stream<void> get selectionChanges => _selectionChangesController.stream;

  Stream<ParsedNote> get parsedChanges => _parsedChangesController.stream;

  ParsedNote? get parsed => _parsed;

  bool get canUndo => engine.canUndo;

  bool get canRedo => engine.canRedo;

  void undo() => engine.undo();

  void redo() => engine.redo();

  bool get isDirty => document.isDirty;

  bool get hasFocus => engine.hasFocus;

  Stream<bool> get focusChanges => engine.focusChanges;

  void focus() => engine.requestFocus();

  void revealOffset(int offset, {bool center = true}) {
    engine.reveal(offset, center: center);
  }

  Rect? caretRectGlobal() => engine.caretRectGlobal();

  EditorDecorator? _decorator;
  EditorDecorator? get decorator => _decorator;

  /// Sets the line decorator (e.g. for Live Preview mode). Passing null restores Source mode highlighting.
  void setDecorator(EditorDecorator? d) {
    _decorator = d;
    engine.setDecorator(d);
  }

  /// Installs an interceptor for pointer/tap events on the editor.
  void setTapInterceptor(
    bool Function(int offset, PointerDeviceKind kind, bool control)? fn,
  ) {
    engine.setTapInterceptor(fn);
  }

  /// Global screen coordinates of [start] to [end] range, or null if unrendered.
  Rect? rectForRange(int start, int end) {
    return engine.rectForRange(start, end);
  }

  /// Focus node of the editor input widget.
  FocusNode get focusNode => engine.focusNode;

  /// Installs [fn] as [focusNode.onKeyEvent]. Passing `null` removes it.
  void setKeyInterceptor(KeyEventResult Function(KeyEvent event)? fn) {
    if (fn == null) {
      focusNode.onKeyEvent = null;
    } else {
      focusNode.onKeyEvent = (FocusNode node, KeyEvent event) => fn(event);
    }
  }

  /// Current IME composing range, or [TextRange.empty] when none.
  @override
  TextRange get composing => engine.composing;

  void updateOptions(EditorOptions o) {
    options = o;
  }

  void apply(EditOperation op, {bool selectAfter = false}) {
    engine.replaceRange(op.start, op.end, op.replacement);
    if (selectAfter) {
      final caret = op.start + op.replacement.length;
      select(caret);
    }
  }

  void applyEdits(List<dynamic> ops) {
    if (ops.isEmpty) return;

    final operations = ops.map((op) {
      if (op is EditOperation) return op;
      if (op is TextEdit) {
        return EditOperation(op.start, op.end, op.replacement);
      }
      throw ArgumentError('Unsupported edit operation: ${op.runtimeType}');
    }).toList();

    final currentText = text;
    for (final op in operations) {
      if (!op.isValidFor(currentText)) {
        throw ArgumentError('Invalid edit operation for current text: $op');
      }
    }

    final sorted = List<EditOperation>.from(operations)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < sorted.length - 1; i++) {
      if (sorted[i].end > sorted[i + 1].start) {
        throw ArgumentError('Overlapping edit operations detected');
      }
    }

    final v = engine.lines;
    final lineEdits = sorted.map((op) {
      return LineEdit(posOf(v, op.start), posOf(v, op.end), op.replacement);
    }).toList();

    // Map selection through the edits
    final currentSel = selection;
    final mappedSel = mapSelectionThroughEdits(currentSel, sorted);

    // Compute post-edit text to obtain posOf coordinates for selection
    var postText = currentText;
    final revSorted = List<EditOperation>.from(sorted)
      ..sort((a, b) => b.start.compareTo(a.start));
    for (final op in revSorted) {
      postText = op.applyTo(postText);
    }
    final postView = ListLineView.fromText(postText);
    final finalSelection = EditorSelection(
      posOf(postView, mappedSel.baseOffset),
      posOf(postView, mappedSel.extentOffset),
    );

    engine.applyPlan(EditPlan(edits: lineEdits, selection: finalSelection));
  }

  @override
  void replaceAll(
    String newText, {
    required bool keepCursor,
    bool clearHistory = false,
  }) {
    final oldText = text;
    if (oldText == newText) return;

    final oldLen = oldText.length;
    final newLen = newText.length;

    final prefix = commonPrefixLength(oldText, newText);
    final maxSuffix = min(oldLen - prefix, newLen - prefix);
    final suffix = commonSuffixLength(oldText, newText, maxSuffix);

    final edit = EditOperation(
      prefix,
      oldLen - suffix,
      newText.substring(prefix, newLen - suffix),
    );

    final currentSel = selection;
    applyEdits([edit]);

    tracker.clear();

    if (keepCursor) {
      final middleLen = edit.replacement.length;
      int mapOne(int o) {
        if (o <= prefix) return o;
        if (o >= oldLen - suffix) return o + (newLen - oldLen);
        return prefix + min(o - prefix, middleLen);
      }

      select(mapOne(currentSel.baseOffset), mapOne(currentSel.extentOffset));
    } else {
      select(0);
    }

    if (clearHistory) {
      engine.clearUndoHistory();
    }
  }

  Widget buildView(
    BuildContext context, {
    bool autofocus = false,
    Future<bool> Function()? onPaste,
  }) {
    final theme = Theme.of(context);
    final baseStyle = TextStyle(
      fontSize: options.fontSize,
      fontFamily: 'Roboto',
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );

    final config = EditorViewConfig(
      options: options,
      readOnly: options.readOnly || document.isReadOnly,
      baseStyle: baseStyle,
      handlers: buildHandlers(this, tracker, onPaste: onPaste),
      autofocus: autofocus,
    );

    return engine.buildView(context, config);
  }

  void _onEngineChange(EngineChange change) {
    if (_isDisposed) return;

    document.notifyEditorChanged();

    _editsController.add(
      EditorEdit(
        start: change.start,
        deletedLength: change.deletedLength,
        insertedText: change.insertedText,
        isUndoRedo: change.isUndoRedo,
      ),
    );

    final lineEdit = LineEdit(
      change.startPos,
      change.endPos,
      change.insertedText,
    );
    tracker.onEdit(lineEdit);
    tracker.prune(engine.lines);

    highlighter.onEdit(change, engine.lines);
    _scheduleParse();
  }

  void _scheduleParse() {
    _parseTimer?.cancel();
    _parseTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_isDisposed) return;
      final targetRevision = document.revision;
      final parsedDoc = await document.parsed();
      if (_isDisposed) return;

      if (document.revision == targetRevision) {
        _parsed = parsedDoc;
        highlighter.applyParse(parsedDoc, revision: targetRevision);
        _parsedChangesController.add(parsedDoc);
      }
    });
  }

  // NoteEditorBinding implementation
  @override
  String readText() => engine.text;

  @override
  void applyEdit(EditOperation op) => apply(op);

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _parseTimer?.cancel();
    _changesSub?.cancel();
    _selectionSub?.cancel();
    _focusSub?.cancel();

    findController.dispose();
    document.detachEditor(this);
    registry?.unregister(this);

    _editsController.close();
    _selectionChangesController.close();
    _parsedChangesController.close();

    engine.dispose();
  }
}
