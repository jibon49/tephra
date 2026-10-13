// © 2026 Tephra. All rights reserved.

/// Engine-independent coordinates for line-based editor models and operations.
final class LinePos implements Comparable<LinePos> {
  const LinePos(this.line, this.col);

  /// 0-indexed line number.
  final int line;

  /// 0-indexed UTF-16 code unit offset inside the line.
  final int col;

  @override
  int compareTo(LinePos other) {
    final cmp = line.compareTo(other.line);
    if (cmp != 0) return cmp;
    return col.compareTo(other.col);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinePos && line == other.line && col == other.col;

  @override
  int get hashCode => Object.hash(line, col);

  @override
  String toString() => 'LinePos($line, $col)';
}

/// Selection between two [LinePos] coordinates.
final class EditorSelection {
  const EditorSelection(this.base, this.extent);

  const EditorSelection.collapsed(LinePos pos) : this(pos, pos);

  final LinePos base;
  final LinePos extent;

  bool get isCollapsed => base == extent;

  LinePos get start => base.compareTo(extent) <= 0 ? base : extent;
  LinePos get end => base.compareTo(extent) <= 0 ? extent : base;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorSelection && base == other.base && extent == other.extent;

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() => 'EditorSelection($base -> $extent)';
}

/// Abstract line-based view of a document.
abstract interface class LineView {
  int get lineCount;
  String lineAt(int index);
}

/// In-memory implementation of [LineView] backed by a list of line strings.
final class ListLineView implements LineView {
  ListLineView(this.lines);

  factory ListLineView.fromText(String t) {
    if (t.isEmpty) return ListLineView(['']);
    return ListLineView(t.split('\n'));
  }

  final List<String> lines;

  @override
  int get lineCount => lines.length;

  @override
  String lineAt(int index) => lines[index];
}

/// A single text replacement edit within line coordinates [start] and [end].
final class LineEdit {
  const LineEdit(this.start, this.end, this.text);

  final LinePos start;
  final LinePos end;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LineEdit &&
          start == other.start &&
          end == other.end &&
          text == other.text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'LineEdit($start..$end: "$text")';
}

/// Atomic editing plan consisting of non-overlapping edits and a resulting selection.
final class EditPlan {
  const EditPlan({this.edits = const [], required this.selection});

  final List<LineEdit> edits;
  final EditorSelection selection;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditPlan) return false;
    if (selection != other.selection) return false;
    if (edits.length != other.edits.length) return false;
    for (var i = 0; i < edits.length; i++) {
      if (edits[i] != other.edits[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(selection, Object.hashAll(edits));

  @override
  String toString() => 'EditPlan(edits: $edits, sel: $selection)';
}

/// Converts a [LinePos] in [LineView] to a global UTF-16 document offset.
int offsetOf(LineView v, LinePos p) {
  if (v.lineCount == 0) return 0;
  if (p.line < 0) return 0;
  if (p.line >= v.lineCount) {
    var total = 0;
    for (var i = 0; i < v.lineCount; i++) {
      total += v.lineAt(i).length;
      if (i < v.lineCount - 1) total += 1;
    }
    return total;
  }

  var offset = 0;
  for (var i = 0; i < p.line; i++) {
    offset += v.lineAt(i).length + 1; // + 1 for '\n'
  }
  final lineLen = v.lineAt(p.line).length;
  final col = p.col < 0 ? 0 : (p.col > lineLen ? lineLen : p.col);
  return offset + col;
}

/// Converts a global UTF-16 document offset to a [LinePos] in [LineView].
LinePos posOf(LineView v, int offset) {
  if (v.lineCount == 0) return const LinePos(0, 0);
  if (offset <= 0) return const LinePos(0, 0);

  var remaining = offset;
  for (var i = 0; i < v.lineCount; i++) {
    final len = v.lineAt(i).length;
    if (remaining <= len) {
      return LinePos(i, remaining);
    }
    if (i == v.lineCount - 1) {
      return LinePos(i, len);
    }
    remaining -= (len + 1); // account for '\n'
  }
  return LinePos(v.lineCount - 1, v.lineAt(v.lineCount - 1).length);
}
