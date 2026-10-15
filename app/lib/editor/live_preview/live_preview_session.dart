// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

import '../editor_controller.dart';
import 'live_preview_decorator.dart';
import 'live_preview_engine.dart';
import 'lp_options.dart';
import 'reveal.dart' as reveal;

/// Target interface consumed by [LivePreviewSession].
abstract interface class LivePreviewEditorTarget {
  String get text;
  TextSelection get selection;
  TextRange get composing;
  Stream<EditorEdit> get edits;
  Stream<void> get selectionChanges;
}

/// Manages Live Preview state, incremental decoration synchronization,
/// active reveal range computation, and IME composition freezing.
final class LivePreviewSession {
  LivePreviewSession({
    required this.target,
    LivePreviewEngine? engine,
    this.useWidgets = false,
    LpOptions options = const LpOptions(),
  }) : engine = engine ?? LivePreviewEngine(options: options) {
    decorator = LivePreviewDecorator(this);
    this.engine.setText(target.text);
    _lastActive = _computeActive();

    _editsSub = target.edits.listen(_onEdit);
    _selectionSub = target.selectionChanges.listen(_onSelectionChange);
  }

  void updateOptions(LpOptions newOptions) {
    if (engine.options == newOptions) return;
    engine.options = newOptions;
    engine.setText(target.text, sync: true);
    decorator.notifyChanges();
  }

  final LivePreviewEditorTarget target;
  final LivePreviewEngine engine;
  final bool useWidgets;
  late final LivePreviewDecorator decorator;

  StreamSubscription<EditorEdit>? _editsSub;
  StreamSubscription<void>? _selectionSub;
  reveal.TextRange? _frozenActive;
  late reveal.TextRange _lastActive;
  bool _isDisposed = false;

  /// Active range combining selection and IME composing range.
  reveal.TextRange get active {
    if (_frozenActive != null) return _frozenActive!;
    return _computeActive();
  }

  reveal.TextRange _computeActive() {
    final sel = target.selection;
    final selStart = min(sel.baseOffset, sel.extentOffset);
    final selEnd = max(sel.baseOffset, sel.extentOffset);
    final comp = target.composing;
    if (comp.isValid && !comp.isCollapsed) {
      return reveal.TextRange(
        start: min(selStart, comp.start),
        end: max(selEnd, comp.end),
      );
    }
    return reveal.TextRange(start: selStart, end: selEnd);
  }

  void _onEdit(EditorEdit edit) {
    if (_isDisposed) return;
    engine.applyEdit(
      start: edit.start,
      deletedLength: edit.deletedLength,
      insertedText: edit.insertedText,
      newText: target.text,
    );
    _lastActive = _computeActive();
    decorator.notifyChanges();
  }

  void _onSelectionChange(void _) {
    if (_isDisposed) return;
    final comp = target.composing;
    final isComposing = comp.isValid && !comp.isCollapsed;

    if (isComposing) {
      if (_frozenActive == null) {
        _frozenActive = _computeActive();
        decorator.notifyChanges();
      }
      return;
    }

    if (_frozenActive != null) {
      _frozenActive = null;
    }

    final newActive = _computeActive();
    var differs = false;
    if (_lastActive != newActive) {
      final minPos = max(0, min(_lastActive.start, newActive.start) - 100);
      final maxPos = max(_lastActive.end, newActive.end) + 100;
      final candidates = engine.decorationsFor(minPos, maxPos);
      for (final d in candidates) {
        if (d.reveal == null) continue;
        if (reveal.isRevealed(d, _lastActive) !=
            reveal.isRevealed(d, newActive)) {
          differs = true;
          break;
        }
      }
    }

    _lastActive = newActive;
    if (differs) {
      decorator.notifyChanges();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _editsSub?.cancel();
    _selectionSub?.cancel();
    decorator.dispose();
  }
}
