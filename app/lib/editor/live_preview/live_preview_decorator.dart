// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../editor_decorator.dart';
import 'live_preview_session.dart';
import 'span_builder.dart';

/// Implementation of [EditorDecorator] backed by a [LivePreviewSession].
final class LivePreviewDecorator extends ChangeNotifier
    implements EditorDecorator {
  LivePreviewDecorator(this.session);

  final LivePreviewSession session;

  @override
  Listenable get changes => this;

  /// Notifies listeners that decorations or reveal states have changed.
  void notifyChanges() => notifyListeners();

  @override
  TextSpan decorateLine({
    required int lineStart,
    required int lineEnd,
    required TextSpan plain,
    required TextStyle base,
  }) {
    final lineText = plain.toPlainText();
    final decos = session.engine.decorationsFor(lineStart, lineEnd + 1);
    return buildLpLine(
      lineText: lineText,
      lineStart: lineStart,
      lineEnd: lineEnd,
      decorations: decos,
      active: session.active,
      base: base,
      useWidgets: session.useWidgets,
    );
  }
}
