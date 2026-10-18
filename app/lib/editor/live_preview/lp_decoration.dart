// © 2026 Tephra. All rights reserved.

/// When a decoration is shown as source instead of rendered. null = never (always rendered).
final class LpReveal {
  const LpReveal(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpReveal && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'LpReveal($start..$end)';
}

/// Base sealed class for all Live Preview decorations.
sealed class LpDecoration {
  const LpDecoration(this.start, this.end, {this.reveal});

  final int start;
  final int end;
  final LpReveal? reveal;
}

/// A syntax marker that is hidden (zero width) when rendered, and shown when revealed.
final class LpHide extends LpDecoration {
  const LpHide(super.start, super.end, {super.reveal});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpHide &&
          start == other.start &&
          end == other.end &&
          reveal == other.reveal;

  @override
  int get hashCode => Object.hash(start, end, reveal);

  @override
  String toString() => 'LpHide($start..$end, reveal: $reveal)';
}

/// A style span applied to a range of text.
final class LpStyle extends LpDecoration {
  const LpStyle(
    super.start,
    super.end,
    this.kind, {
    this.level = 0,
    this.data,
    super.reveal,
  });

  final LpStyleKind kind;
  final int level;
  final String? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpStyle &&
          start == other.start &&
          end == other.end &&
          kind == other.kind &&
          level == other.level &&
          data == other.data &&
          reveal == other.reveal;

  @override
  int get hashCode => Object.hash(start, end, kind, level, data, reveal);

  @override
  String toString() =>
      'LpStyle($start..$end, $kind, level: $level, data: $data, reveal: $reveal)';
}

/// A single UTF-16 code unit replaced by another unit (e.g. list bullet).
final class LpReplaceChar extends LpDecoration {
  const LpReplaceChar(super.start, super.end, this.char)
    : assert(end == start + 1),
      super(reveal: null);

  final String char;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpReplaceChar &&
          start == other.start &&
          end == other.end &&
          char == other.char;

  @override
  int get hashCode => Object.hash(start, end, char);

  @override
  String toString() => 'LpReplaceChar($start..$end, "$char")';
}

/// A widget replacing a range of text.
final class LpWidget extends LpDecoration {
  const LpWidget(
    super.start,
    super.end,
    this.kind, {
    this.data = const {},
    super.reveal,
  });

  final LpWidgetKind kind;
  final Map<String, Object?> data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpWidget &&
          start == other.start &&
          end == other.end &&
          kind == other.kind &&
          _mapEquals(data, other.data) &&
          reveal == other.reveal;

  @override
  int get hashCode => Object.hash(start, end, kind, reveal);

  @override
  String toString() =>
      'LpWidget($start..$end, $kind, data: $data, reveal: $reveal)';
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    _deepEquals(a, b);

enum LpStyleKind {
  heading,
  bold,
  italic,
  strike,
  highlight,
  inlineCode,
  internalLink,
  externalLink,
  tag,
  blockId,
  footnoteRef,
  comment,
  quoteLine,
  calloutLine,
  codeLine,
  taskDone,
  syntaxMarker,
  searchMatch,
}

enum LpWidgetKind {
  checkbox,
  embed,
  image,
  inlineMath,
  mathBlock,
  calloutHeader,
  horizontalRule,
  table,
  queryBlock,
}

int _decorationPriority(LpDecoration d) {
  if (d is LpHide) return 0;
  if (d is LpReplaceChar) return 1;
  if (d is LpWidget) return 2;
  if (d is LpStyle) return 3;
  return 4;
}

/// Deterministic comparator for LpDecorations.
int compareDecorations(LpDecoration a, LpDecoration b) {
  var cmp = a.start.compareTo(b.start);
  if (cmp != 0) return cmp;
  cmp = a.end.compareTo(b.end);
  if (cmp != 0) return cmp;
  cmp = _decorationPriority(a).compareTo(_decorationPriority(b));
  if (cmp != 0) return cmp;
  if (a is LpStyle && b is LpStyle) {
    cmp = a.kind.index.compareTo(b.kind.index);
    if (cmp != 0) return cmp;
  } else if (a is LpWidget && b is LpWidget) {
    cmp = a.kind.index.compareTo(b.kind.index);
    if (cmp != 0) return cmp;
  }
  return a.toString().compareTo(b.toString());
}
