// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';

/// Host environment callbacks and state provided to Live Preview inline widgets.
class LpWidgetHost {
  const LpWidgetHost({
    required this.selectOffset,
    required this.applyEdits,
    this.path,
    this.ref,
    this.foldedCallouts = const {},
    this.onToggleCallout,
  });

  /// Places the editor caret at [offset] and requests focus.
  final void Function(int offset) selectOffset;

  /// Applies atomic text edits to the underlying document buffer.
  final void Function(List<TextEdit> edits) applyEdits;

  /// Vault path of the currently open note.
  final VaultPath? path;

  /// Riverpod ref if available in widget context.
  final WidgetRef? ref;

  /// Currently folded callout start offsets.
  final Set<int> foldedCallouts;

  /// Toggles view-only fold state for the callout starting at [startOffset].
  final void Function(int startOffset)? onToggleCallout;
}
