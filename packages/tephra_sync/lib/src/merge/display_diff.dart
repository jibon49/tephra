// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:diff_match_patch/diff_match_patch.dart';

import 'line_codec.dart';

/// Type of change represented by a diff line.
enum DiffKind {
  /// Line exists identically in both versions.
  same,

  /// Line existed in original (A) but was removed in new (B).
  removed,

  /// Line did not exist in original (A) and was added in new (B).
  added,
}

/// A single line in a diff representation.
final class DiffLine {
  /// Creates a [DiffLine].
  const DiffLine({
    required this.kind,
    required this.text,
    this.aLine,
    this.bLine,
  });

  /// The change classification for this line.
  final DiffKind kind;

  /// The text content of the line without trailing newline delimiters.
  final String text;

  /// 1-based line number in version A (the original / winning file), or null if added.
  final int? aLine;

  /// 1-based line number in version B (the conflict copy / modified file), or null if removed.
  final int? bLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffLine &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          text == other.text &&
          aLine == other.aLine &&
          bLine == other.bLine;

  @override
  int get hashCode => Object.hash(kind, text, aLine, bLine);

  @override
  String toString() => 'DiffLine($kind, a:$aLine, b:$bLine, text: "$text")';
}

/// A row in a side-by-side diff representation pairing corresponding lines.
final class SideBySideRow {
  /// Creates a [SideBySideRow].
  const SideBySideRow({this.left, this.right});

  /// The line on the left side (version A), or null if this position is blank (added on right).
  final DiffLine? left;

  /// The line on the right side (version B), or null if this position is blank (removed on left).
  final DiffLine? right;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SideBySideRow &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'SideBySideRow(left: $left, right: $right)';
}

String _stripTrailingNewline(String line) {
  if (line.endsWith('\r\n')) {
    return line.substring(0, line.length - 2);
  }
  if (line.endsWith('\n') || line.endsWith('\r')) {
    return line.substring(0, line.length - 1);
  }
  return line;
}

int _countLines(String text) {
  if (text.isEmpty) return 0;
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) count++;
  }
  if (!text.endsWith('\n')) count++;
  return count;
}

/// Computes a line-by-line diff between original text [a] and modified text [b].
///
/// Uses [LineCodec] to encode distinct lines into UTF-16 code points, diffs them
/// with [DiffMatchPatch], applies semantic cleanup, and decodes back to [DiffLine]s.
List<DiffLine> lineDiff(String a, String b) {
  if (a.isEmpty && b.isEmpty) {
    return const [];
  }

  final linesA = splitLines(a);
  final linesB = splitLines(b);

  final codec = LineCodec();
  final encA = codec.encode(linesA);
  final encB = codec.encode(linesB);

  // If distinct lines exceed codec capacity, fallback to line-by-line comparison
  if (encA == null || encB == null || codec.hasOverflow) {
    return _fallbackLineDiff(linesA, linesB);
  }

  final dmp = DiffMatchPatch();
  final diffs = dmp.diff(encA, encB, false);
  dmp.diffCleanupSemantic(diffs);

  final result = <DiffLine>[];
  var aLineNumber = 1;
  var bLineNumber = 1;

  for (final diff in diffs) {
    final decodedLines = codec.decode(diff.text);
    switch (diff.operation) {
      case DIFF_EQUAL:
        for (final line in decodedLines) {
          result.add(
            DiffLine(
              kind: DiffKind.same,
              text: _stripTrailingNewline(line),
              aLine: aLineNumber++,
              bLine: bLineNumber++,
            ),
          );
        }
      case DIFF_DELETE:
        for (final line in decodedLines) {
          result.add(
            DiffLine(
              kind: DiffKind.removed,
              text: _stripTrailingNewline(line),
              aLine: aLineNumber++,
              bLine: null,
            ),
          );
        }
      case DIFF_INSERT:
        for (final line in decodedLines) {
          result.add(
            DiffLine(
              kind: DiffKind.added,
              text: _stripTrailingNewline(line),
              aLine: null,
              bLine: bLineNumber++,
            ),
          );
        }
    }
  }

  return result;
}

List<DiffLine> _fallbackLineDiff(List<String> linesA, List<String> linesB) {
  final result = <DiffLine>[];
  var aLineNumber = 1;
  for (final line in linesA) {
    result.add(
      DiffLine(
        kind: DiffKind.removed,
        text: _stripTrailingNewline(line),
        aLine: aLineNumber++,
        bLine: null,
      ),
    );
  }
  var bLineNumber = 1;
  for (final line in linesB) {
    result.add(
      DiffLine(
        kind: DiffKind.added,
        text: _stripTrailingNewline(line),
        aLine: null,
        bLine: bLineNumber++,
      ),
    );
  }
  return result;
}

/// Pairs removed and added diff runs row by row into a side-by-side presentation.
List<SideBySideRow> sideBySide(List<DiffLine> diffs) {
  final rows = <SideBySideRow>[];
  var i = 0;

  while (i < diffs.length) {
    final current = diffs[i];
    if (current.kind == DiffKind.same) {
      rows.add(SideBySideRow(left: current, right: current));
      i++;
    } else {
      final removed = <DiffLine>[];
      final added = <DiffLine>[];

      while (i < diffs.length && diffs[i].kind != DiffKind.same) {
        if (diffs[i].kind == DiffKind.removed) {
          removed.add(diffs[i]);
        } else if (diffs[i].kind == DiffKind.added) {
          added.add(diffs[i]);
        }
        i++;
      }

      final maxCount = removed.length > added.length
          ? removed.length
          : added.length;
      for (var r = 0; r < maxCount; r++) {
        rows.add(
          SideBySideRow(
            left: r < removed.length ? removed[r] : null,
            right: r < added.length ? added[r] : null,
          ),
        );
      }
    }
  }

  return rows;
}

/// Computes [lineDiff] asynchronously, delegating to [Isolate.run] when inputs
/// exceed 2,000 lines to avoid blocking UI frame rates.
Future<List<DiffLine>> computeLineDiff(String a, String b) async {
  if (_countLines(a) > 2000 || _countLines(b) > 2000) {
    return Isolate.run(() => lineDiff(a, b));
  }
  return lineDiff(a, b);
}

/// Computes [SideBySideRow]s asynchronously, delegating to [Isolate.run] when
/// inputs exceed 2,000 lines.
Future<List<SideBySideRow>> computeSideBySide(String a, String b) async {
  if (_countLines(a) > 2000 || _countLines(b) > 2000) {
    return Isolate.run(() => sideBySide(lineDiff(a, b)));
  }
  return sideBySide(lineDiff(a, b));
}
