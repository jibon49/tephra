// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// A task checklist item in a note.
final class TaskRecord {
  const TaskRecord({
    required this.path,
    required this.line,
    required this.statusChar,
    required this.text,
    required this.start,
    required this.end,
    this.due,
  });

  final VaultPath path;
  final int line;
  final String statusChar;
  final String text;
  final int start;
  final int end;
  final String? due;

  bool get done => statusChar != ' ';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskRecord &&
          path == other.path &&
          line == other.line &&
          statusChar == other.statusChar &&
          text == other.text &&
          start == other.start &&
          end == other.end &&
          due == other.due;

  @override
  int get hashCode =>
      Object.hash(path, line, statusChar, text, start, end, due);

  @override
  String toString() =>
      'TaskRecord(path: ${path.value}, line: $line, done: $done, due: $due)';
}
