// © 2026 Tephra. All rights reserved.

import 'package:diff_match_patch/diff_match_patch.dart';

import 'line_codec.dart';

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Represents an edit operation on a range of lines in the base document.
final class Hunk {
  /// Creates a [Hunk] replacing lines `[baseStart, baseEnd)` with [lines].
  const Hunk({
    required this.baseStart,
    required this.baseEnd,
    required this.lines,
  });

  /// 0-indexed start line index in base (inclusive).
  final int baseStart;

  /// 0-indexed end line index in base (exclusive).
  ///
  /// For pure insertions, [baseStart] == [baseEnd].
  final int baseEnd;

  /// Replacement lines.
  final List<String> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hunk &&
          baseStart == other.baseStart &&
          baseEnd == other.baseEnd &&
          _listEquals(lines, other.lines);

  @override
  int get hashCode => Object.hash(baseStart, baseEnd, Object.hashAll(lines));

  @override
  String toString() =>
      'Hunk(base: [$baseStart, $baseEnd), lines: ${lines.length})';
}

/// Computes line-level edit [Hunk]s transforming [base] lines into [other] lines.
///
/// Returns `null` if distinct lines exceed the codec's maximum capacity (conflict).
List<Hunk>? lineHunks(
  List<String> base,
  List<String> other, {
  LineCodec? codec,
}) {
  final activeCodec = codec ?? LineCodec();
  final encBase = activeCodec.encode(base);
  final encOther = activeCodec.encode(other);

  if (encBase == null || encOther == null || activeCodec.hasOverflow) {
    return null;
  }

  final dmp = DiffMatchPatch()..diffTimeout = 5.0;
  final diffs = dmp.diff(encBase, encOther, false);

  final hunks = <Hunk>[];
  var baseIndex = 0;
  var i = 0;

  while (i < diffs.length) {
    final d = diffs[i];
    if (d.operation == DIFF_EQUAL) {
      baseIndex += d.text.length;
      i++;
    } else {
      final start = baseIndex;
      var deleteCount = 0;
      final insertedEncoded = StringBuffer();

      while (i < diffs.length && diffs[i].operation != DIFF_EQUAL) {
        final current = diffs[i];
        if (current.operation == DIFF_DELETE) {
          deleteCount += current.text.length;
        } else if (current.operation == DIFF_INSERT) {
          insertedEncoded.write(current.text);
        }
        i++;
      }

      final insertedLines = activeCodec.decode(insertedEncoded.toString());
      hunks.add(
        Hunk(
          baseStart: start,
          baseEnd: start + deleteCount,
          lines: insertedLines,
        ),
      );
      baseIndex += deleteCount;
    }
  }

  return hunks;
}
