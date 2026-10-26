// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart' as sync;

/// Outcome of a three-way text merge between sticky window edits and vault storage.
sealed class MergeOutcome {
  const MergeOutcome();
}

/// The merge succeeded without conflict, producing [text].
final class MergeClean extends MergeOutcome {
  const MergeClean(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MergeClean && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MergeClean(len: ${text.length})';
}

/// The merge detected a conflict.
final class MergeConflict extends MergeOutcome {
  const MergeConflict();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MergeConflict;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'MergeConflict()';
}

/// Abstraction for three-way text merge.
abstract interface class TextMerger {
  MergeOutcome merge({
    required String base,
    required String local,
    required String remote,
  });
}

/// Production implementation of [TextMerger] using Tephra's frontmatter-aware 3-way merge.
class SyncTextMerger implements TextMerger {
  const SyncTextMerger();

  @override
  MergeOutcome merge({
    required String base,
    required String local,
    required String remote,
  }) {
    final outcome = sync.mergeMarkdown(base, local, remote);
    if (outcome.isClean && outcome.text != null) {
      return MergeClean(outcome.text!);
    }
    return const MergeConflict();
  }
}
