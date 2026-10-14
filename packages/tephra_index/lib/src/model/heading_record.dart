// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// A heading within a note.
final class HeadingRecord {
  const HeadingRecord({
    required this.path,
    required this.level,
    required this.text,
    required this.start,
    required this.end,
    required this.line,
    required this.ordinal,
  });

  final VaultPath path;
  final int level;
  final String text;
  final int start;
  final int end;
  final int line;
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadingRecord &&
          path == other.path &&
          level == other.level &&
          text == other.text &&
          start == other.start &&
          end == other.end &&
          line == other.line &&
          ordinal == other.ordinal;

  @override
  int get hashCode => Object.hash(path, level, text, start, end, line, ordinal);

  @override
  String toString() =>
      'HeadingRecord(path: ${path.value}, level: $level, text: $text)';
}
