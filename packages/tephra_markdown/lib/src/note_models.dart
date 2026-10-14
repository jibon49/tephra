// © 2026 Tephra. All rights reserved.

/// Folding state for callout blocks.
enum CalloutFold { none, expanded, collapsed }

/// Alignment for table columns.
enum TableAlign { none, left, center, right }

/// Dimensions for embedded media.
final class EmbedSize {
  const EmbedSize(this.width, [this.height]);

  final int width;
  final int? height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbedSize && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() =>
      height == null ? 'EmbedSize($width)' : 'EmbedSize($width, $height)';
}

/// The character and offset of a task list checkbox status.
final class TaskStatus {
  const TaskStatus(this.char, this.offset);

  /// Exactly one Unicode code point inside `[ ]`.
  final String char;

  /// UTF-16 offset of the status character in the source text.
  final int offset;

  bool get isOpen => char == ' ';
  bool get isDone => char == 'x' || char == 'X';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatus && char == other.char && offset == other.offset;

  @override
  int get hashCode => Object.hash(char, offset);

  @override
  String toString() => 'TaskStatus($char, $offset)';
}

/// A reference link or image definition: `[label]: url "title"`.
final class LinkDefinition {
  const LinkDefinition(this.label, this.url, [this.title]);

  final String label;
  final String url;
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkDefinition &&
          label == other.label &&
          url == other.url &&
          title == other.title;

  @override
  int get hashCode => Object.hash(label, url, title);

  @override
  String toString() => 'LinkDefinition($label, $url, $title)';
}

/// Source range of an Obsidian block reference identifier `^block-id`.
final class BlockRef {
  const BlockRef({
    required this.id,
    required this.start,
    required this.end,
    required this.idStart,
    required this.idEnd,
  });

  /// The block ID string (without the leading `^`).
  final String id;

  /// Start offset of the block reference including the `^` marker.
  final int start;

  /// End offset of the block reference.
  final int end;

  /// Start offset of the ID itself (after `^`).
  final int idStart;

  /// End offset of the ID itself.
  final int idEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockRef &&
          id == other.id &&
          start == other.start &&
          end == other.end &&
          idStart == other.idStart &&
          idEnd == other.idEnd;

  @override
  int get hashCode => Object.hash(id, start, end, idStart, idEnd);

  @override
  String toString() => 'BlockRef($id, $start-$end)';
}

/// A task list item with its source location, status character, and text.
final class TaskItem {
  const TaskItem({
    required this.status,
    required this.text,
    required this.start,
    required this.end,
    required this.statusOffset,
    required this.line,
  });

  final TaskStatus status;
  final String text;
  final int start;
  final int end;
  final int statusOffset;
  final int line;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem &&
          status == other.status &&
          text == other.text &&
          start == other.start &&
          end == other.end &&
          statusOffset == other.statusOffset &&
          line == other.line;

  @override
  int get hashCode => Object.hash(status, text, start, end, statusOffset, line);

  @override
  String toString() => 'TaskItem(${status.char}, line: $line, $start-$end)';
}
