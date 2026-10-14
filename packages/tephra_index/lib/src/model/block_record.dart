// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// A block identifier defined in a note.
final class BlockRecord {
  const BlockRecord({
    required this.path,
    required this.id,
    required this.start,
    required this.end,
    required this.line,
    required this.preview,
  });

  final VaultPath path;
  final String id;
  final int start;
  final int end;
  final int line;
  final String preview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockRecord &&
          path == other.path &&
          id == other.id &&
          start == other.start &&
          end == other.end &&
          line == other.line &&
          preview == other.preview;

  @override
  int get hashCode => Object.hash(path, id, start, end, line, preview);

  @override
  String toString() => 'BlockRecord(path: ${path.value}, id: $id, line: $line)';
}
