// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import '../model/model_helpers.dart';

/// Single replacement within a text document.
final class TextEdit {
  const TextEdit(this.start, this.end, this.replacement);

  final int start;
  final int end;
  final String replacement;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextEdit &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          replacement == other.replacement;

  @override
  int get hashCode => Object.hash(start, end, replacement);

  @override
  String toString() => 'TextEdit($start, $end, "$replacement")';
}

/// Collection of text edits targeted at a specific file prior to moving/renaming.
final class FileEdit {
  const FileEdit(this.path, this.edits);

  final VaultPath path /* path BEFORE the move */;
  final List<TextEdit> edits;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileEdit &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          listEquals(edits, other.edits);

  @override
  int get hashCode => Object.hash(path, Object.hashAll(edits));

  @override
  String toString() => 'FileEdit(${path.value}, $edits)';
}

/// Applies [edits] to [text].
///
/// Throws [ArgumentError] if two edits overlap or if an edit is out of range.
String applyTextEdits(String text, List<TextEdit> edits) {
  if (edits.isEmpty) return text;

  for (final edit in edits) {
    if (edit.start < 0 || edit.end < edit.start || edit.end > text.length) {
      throw ArgumentError(
        'Edit out of range: [${edit.start}, ${edit.end}] for text length ${text.length}',
      );
    }
  }

  final sorted = List<TextEdit>.from(edits)
    ..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.end.compareTo(b.end);
    });

  for (var i = 0; i < sorted.length - 1; i++) {
    if (sorted[i].end > sorted[i + 1].start ||
        sorted[i].start == sorted[i + 1].start) {
      throw ArgumentError(
        'Overlapping edits: ${sorted[i]} and ${sorted[i + 1]}',
      );
    }
  }

  final buffer = StringBuffer();
  var cursor = 0;
  for (final edit in sorted) {
    buffer.write(text.substring(cursor, edit.start));
    buffer.write(edit.replacement);
    cursor = edit.end;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}
