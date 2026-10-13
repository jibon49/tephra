// © 2026 Tephra. All rights reserved.

/// Parsed metadata from a list line.
final class ListLine {
  const ListLine({
    required this.indent,
    required this.marker,
    required this.ordered,
    required this.number,
    required this.delimiter,
    required this.gap,
    this.taskChar,
    this.taskGap,
    required this.contentStart,
  });

  final String indent;
  final String marker;
  final bool ordered;
  final int number;
  final String delimiter;
  final String gap;
  final String? taskChar;
  final String? taskGap;
  final int contentStart;
}

final _listRegex = RegExp(
  r'^([ \t]*)([-*+]|\d{1,9}([.)]))([ \t]+)(?:\[(.)\]([ \t]+))?',
);

/// Parses a line into [ListLine] metadata, or returns `null` if the line is not a list item.
///
/// A line that is only a marker (`-`, `1.`) with no following space is not a list line.
ListLine? parseListLine(String line) {
  final match = _listRegex.firstMatch(line);
  if (match == null) return null;

  final indent = match.group(1) ?? '';
  final marker = match.group(2) ?? '';
  final delimiter = match.group(3) ?? '';
  final gap = match.group(4) ?? '';
  final taskChar = match.group(5);
  final taskGap = match.group(6);

  final ordered = delimiter.isNotEmpty;
  var number = 0;
  if (ordered) {
    number =
        int.tryParse(marker.substring(0, marker.length - delimiter.length)) ??
        0;
  }

  return ListLine(
    indent: indent,
    marker: marker,
    ordered: ordered,
    number: number,
    delimiter: delimiter,
    gap: gap,
    taskChar: taskChar,
    taskGap: taskGap,
    contentStart: match.end,
  );
}
