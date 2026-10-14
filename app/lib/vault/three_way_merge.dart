// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:logging/logging.dart';

final _logger = Logger('ThreeWayMerge');

/// Represents the outcome of a three-way text merge.
final class MergeResult {
  const MergeResult({required this.clean, required this.text});

  final bool clean;
  final String text;

  @override
  String toString() => 'MergeResult(clean: $clean, textLength: ${text.length})';
}

/// Computes a three-way merge between [base], [mine], and [theirs].
MergeResult threeWayMerge({
  required String base,
  required String mine,
  required String theirs,
}) {
  // 1. Trivial clean cases
  if (mine == theirs) {
    _logger.fine('Trivial merge (mine == theirs): length=${mine.length}');
    return MergeResult(clean: true, text: mine);
  }
  if (mine == base) {
    _logger.fine(
      'Trivial merge (mine == base): taking theirs length=${theirs.length}',
    );
    return MergeResult(clean: true, text: theirs);
  }
  if (theirs == base) {
    _logger.fine(
      'Trivial merge (theirs == base): taking mine length=${mine.length}',
    );
    return MergeResult(clean: true, text: mine);
  }

  // 2. Safety limit
  if (base.length + mine.length + theirs.length > 3000000) {
    _logger.fine(
      'Three-way merge aborted: input size exceeded 3M chars '
      '(base=${base.length}, mine=${mine.length}, theirs=${theirs.length})',
    );
    return MergeResult(clean: false, text: mine);
  }

  // 3. Configure diff_match_patch for strict exact-context patching
  final dmp = DiffMatchPatch()
    ..diffTimeout = 1.0
    ..matchThreshold = 0.001
    ..matchDistance = 1000000000
    ..patchDeleteThreshold = 0.0;

  // 4. Compute patches and enforce exact context matching
  final patches = dmp.patch(base, mine);
  for (final p in patches) {
    final text1 = p.diffs
        .where((d) => d.operation != DIFF_INSERT)
        .map((d) => d.text)
        .join();
    if (text1.isNotEmpty && !theirs.contains(text1)) {
      _logger.fine(
        'Three-way merge context mismatch: patch context not found in theirs',
      );
      return MergeResult(clean: false, text: mine);
    }
  }

  final result = dmp.patch_apply(patches, theirs);
  final merged = result[0] as String;
  final applied = (result[1] as List).cast<bool>();

  // 5. Clean check: all patches must apply and size explosion must not occur
  final maxLen = max(mine.length, theirs.length);
  var clean = applied.every((a) => a) && merged.length <= 4 * maxLen;

  // 6. Safety net: if mine != base, merged must differ from theirs
  if (clean && mine != base && merged == theirs) {
    clean = false;
  }

  _logger.fine(
    'Three-way merge: base=${base.length}, mine=${mine.length}, '
    'theirs=${theirs.length}, clean=$clean, '
    'merged=${clean ? merged.length : mine.length}',
  );

  return MergeResult(clean: clean, text: clean ? merged : mine);
}
