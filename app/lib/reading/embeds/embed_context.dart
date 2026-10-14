// © 2026 Tephra. All rights reserved.

import 'package:flutter/widgets.dart';
import 'package:tephra_core/tephra_core.dart';

/// InheritedWidget carrying recursion depth and path chain for embedded notes.
class EmbedContext extends InheritedWidget {
  const EmbedContext({
    super.key,
    required this.depth,
    required this.chain,
    required super.child,
  });

  /// Current nesting depth (0 for root note in reading view).
  final int depth;

  /// Ordered set of vault paths of notes in the current embedding ancestry.
  final Set<VaultPath> chain;

  static EmbedContext? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<EmbedContext>();
  }

  static EmbedContext of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null, 'No EmbedContext found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(EmbedContext oldWidget) {
    return depth != oldWidget.depth || chain != oldWidget.chain;
  }
}
