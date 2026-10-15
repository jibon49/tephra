// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';

/// Contract for line-level editor decorators (e.g. Live Preview).
abstract interface class EditorDecorator {
  /// Notifies when decorations or the reveal state changed.
  Listenable get changes;

  /// Decorates a single line of the document.
  ///
  /// [lineStart] and [lineEnd] are absolute UTF-16 offsets into the buffer.
  /// [lineEnd] excludes the trailing `\n`.
  TextSpan decorateLine({
    required int lineStart,
    required int lineEnd,
    required TextSpan plain,
    required TextStyle base,
  });
}
