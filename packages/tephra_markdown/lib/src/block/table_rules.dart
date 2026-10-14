// © 2026 Tephra. All rights reserved.

import '../note_models.dart';

/// Splits a Markdown table row into cell source ranges `(start, end)`.
///
/// Handles unescaped pipe separators, stripping an optional leading and trailing
/// pipe, and trimming each cell range of whitespace.
List<(int start, int end)> splitTableRow(String line, [int baseOffset = 0]) {
  var startIdx = 0;
  while (startIdx < line.length &&
      (line[startIdx] == ' ' || line[startIdx] == '\t')) {
    startIdx++;
  }
  if (startIdx >= line.length) return const [];

  var endIdx = line.length;
  while (endIdx > startIdx &&
      (line[endIdx - 1] == ' ' || line[endIdx - 1] == '\t')) {
    endIdx--;
  }

  // Check leading pipe
  if (line[startIdx] == '|') {
    startIdx++;
  }

  // Check trailing unescaped pipe
  if (endIdx > startIdx && line[endIdx - 1] == '|') {
    var slashes = 0;
    var k = endIdx - 2;
    while (k >= startIdx && line[k] == '\\') {
      slashes++;
      k--;
    }
    if (slashes.isEven) {
      endIdx--;
    }
  }

  final cells = <(int start, int end)>[];
  var cellStart = startIdx;
  var i = startIdx;

  while (i < endIdx) {
    if (line[i] == '|') {
      var slashes = 0;
      var k = i - 1;
      while (k >= cellStart && line[k] == '\\') {
        slashes++;
        k--;
      }
      if (slashes.isEven) {
        // Unescaped pipe
        cells.add(_trimRange(line, cellStart, i, baseOffset));
        cellStart = i + 1;
      }
    }
    i++;
  }

  cells.add(_trimRange(line, cellStart, endIdx, baseOffset));
  return cells;
}

(int start, int end) _trimRange(
  String line,
  int start,
  int end,
  int baseOffset,
) {
  var s = start;
  while (s < end && (line[s] == ' ' || line[s] == '\t')) {
    s++;
  }
  var e = end;
  while (e > s && (line[e - 1] == ' ' || line[e - 1] == '\t')) {
    e--;
  }
  return (baseOffset + s, baseOffset + e);
}

final RegExp _delimiterCellRegex = RegExp(r'^:?-+:?$');

/// Checks if [line] is a valid table delimiter row.
///
/// Returns the alignments if valid, or `null` if not.
List<TableAlign>? parseDelimiterRow(String line, [int baseOffset = 0]) {
  if (!line.contains('|')) return null;

  final cells = splitTableRow(line, baseOffset);
  if (cells.isEmpty) return null;

  final aligns = <TableAlign>[];
  for (final cell in cells) {
    final s = line.substring(cell.$1 - baseOffset, cell.$2 - baseOffset).trim();
    if (!_delimiterCellRegex.hasMatch(s)) return null;

    final left = s.startsWith(':');
    final right = s.endsWith(':');
    if (left && right) {
      aligns.add(TableAlign.center);
    } else if (left) {
      aligns.add(TableAlign.left);
    } else if (right) {
      aligns.add(TableAlign.right);
    } else {
      aligns.add(TableAlign.none);
    }
  }

  return aligns;
}
