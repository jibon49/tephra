// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_vault/tephra_vault.dart';

import 'line_codec.dart';
import 'line_diff.dart';

/// The result of a three-way merge operation.
final class MergeOutcome {
  /// Successful, non-conflicting merge.
  const MergeOutcome.clean(this.text, [this.bytes]) : isClean = true;

  /// Conflicting merge requiring user resolution or conflict copy.
  const MergeOutcome.conflict([this.text]) : isClean = false, bytes = null;

  /// Whether the merge succeeded without conflict.
  final bool isClean;

  /// Merged text content if clean.
  final String? text;

  /// Merged and re-encoded bytes (matching local BOM and line ending) if clean.
  final List<int>? bytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MergeOutcome && isClean == other.isClean && text == other.text;

  @override
  int get hashCode => Object.hash(isClean, text);

  @override
  String toString() => isClean
      ? 'MergeOutcome.clean(len: ${text?.length})'
      : 'MergeOutcome.conflict()';
}

/// Checks whether two hunks [a] and [b] from opposite branches clash.
bool hunksClash(Hunk a, Hunk b) {
  // Identical hunks from both sides are benign and do not clash
  if (a == b) return false;

  // Both are insertions at the exact same base line
  if (a.baseStart == a.baseEnd && b.baseStart == b.baseEnd) {
    if (a.baseStart == b.baseStart) return true;
  }

  // Non-empty ranges overlap: max(start) < min(end)
  if (a.baseStart < a.baseEnd && b.baseStart < b.baseEnd) {
    if (max(a.baseStart, b.baseStart) < min(a.baseEnd, b.baseEnd)) {
      return true;
    }
  }

  // Insertion inside a non-empty range
  if (a.baseStart == a.baseEnd && b.baseStart < b.baseEnd) {
    if (a.baseStart > b.baseStart && a.baseStart < b.baseEnd) {
      return true;
    }
  }
  if (b.baseStart == b.baseEnd && a.baseStart < a.baseEnd) {
    if (b.baseStart > a.baseStart && b.baseStart < a.baseEnd) {
      return true;
    }
  }

  // Touching ranges: neighboring line edits or edit adjacent to insert
  if (a.baseEnd == b.baseStart || b.baseEnd == a.baseStart) {
    return true;
  }

  return false;
}

/// Performs a conservative three-way line merge between [base], [local], and [remote].
MergeOutcome merge3(String base, String local, String remote) {
  // Fast paths
  if (local == remote) return MergeOutcome.clean(local);
  if (local == base) return MergeOutcome.clean(remote);
  if (remote == base) return MergeOutcome.clean(local);

  final baseLines = splitLines(base);
  final localLines = splitLines(local);
  final remoteLines = splitLines(remote);

  final codec = LineCodec();
  final hl = lineHunks(baseLines, localLines, codec: codec);
  final hr = lineHunks(baseLines, remoteLines, codec: codec);

  if (hl == null || hr == null || codec.hasOverflow) {
    return const MergeOutcome.conflict();
  }

  // Check for clashes between any hunk in hl and any hunk in hr
  for (final a in hl) {
    for (final b in hr) {
      if (hunksClash(a, b)) {
        return const MergeOutcome.conflict();
      }
    }
  }

  // Combine non-clashing hunks, deduplicating identical hunks
  final allHunks = <Hunk>[...hl];
  for (final h in hr) {
    if (!allHunks.contains(h)) {
      allHunks.add(h);
    }
  }

  // Apply in descending order of baseStart
  allHunks.sort((x, y) => y.baseStart.compareTo(x.baseStart));
  final resultLines = List<String>.from(baseLines);

  for (final h in allHunks) {
    resultLines.replaceRange(h.baseStart, h.baseEnd, h.lines);
  }

  return MergeOutcome.clean(resultLines.join(''));
}

/// Decodes raw file byte arrays using [TextDocument], applies [textMerger] (or [merge3]),
/// and re-encodes the clean result with [localBytes]'s BOM and line ending.
MergeOutcome mergeDocuments({
  required List<int> baseBytes,
  required List<int> localBytes,
  required List<int> remoteBytes,
  MergeOutcome Function(String base, String local, String remote)? textMerger,
}) {
  final baseDoc = TextDocument.decode(baseBytes);
  final localDoc = TextDocument.decode(localBytes);
  final remoteDoc = TextDocument.decode(remoteBytes);

  if (baseDoc.malformed || localDoc.malformed || remoteDoc.malformed) {
    return const MergeOutcome.conflict();
  }

  final merger = textMerger ?? merge3;
  final textOutcome = merger(baseDoc.text, localDoc.text, remoteDoc.text);
  if (!textOutcome.isClean || textOutcome.text == null) {
    return textOutcome;
  }

  final mergedDoc = localDoc.copyWith(text: textOutcome.text);
  final encodedBytes = mergedDoc.encode();
  return MergeOutcome.clean(textOutcome.text, encodedBytes);
}
