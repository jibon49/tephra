// © 2026 Tephra. All rights reserved.

/// Tracks character offsets, virtual columns, and tab expansion for a single line.
final class LineCursor {
  LineCursor(this.text, this.lineStart, this.lineEnd)
    : offset = lineStart,
      column = 0,
      partialTab = 0 {
    _recompute();
  }

  final String text;
  final int lineStart;
  final int lineEnd;

  int offset;
  int column;
  int partialTab;

  late int nextNonSpaceOffset;
  late int nextNonSpaceColumn;
  late int indent;
  late bool blank;

  bool get isEol => offset >= lineEnd && partialTab == 0;

  int? peek([int delta = 0]) {
    final pos = offset + delta;
    if (pos >= lineStart && pos < lineEnd) {
      return text.codeUnitAt(pos);
    }
    return null;
  }

  bool startsWith(String s, [int? atOffset]) {
    final pos = atOffset ?? offset;
    if (pos + s.length > lineEnd) return false;
    for (var i = 0; i < s.length; i++) {
      if (text.codeUnitAt(pos + i) != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  void _recompute() {
    var off = offset;
    var col = column;
    if (partialTab > 0) {
      col += partialTab;
    }
    while (off < lineEnd) {
      final cu = text.codeUnitAt(off);
      if (cu == 0x20) {
        col++;
        off++;
      } else if (cu == 0x09) {
        col += 4 - (col % 4);
        off++;
      } else {
        break;
      }
    }
    nextNonSpaceOffset = off;
    nextNonSpaceColumn = col;
    indent = nextNonSpaceColumn - column;
    blank = off >= lineEnd;
  }

  void advanceToNextNonSpace() {
    if (blank) {
      offset = lineEnd;
      column = nextNonSpaceColumn;
      partialTab = 0;
    } else {
      offset = nextNonSpaceOffset;
      column = nextNonSpaceColumn;
      partialTab = 0;
    }
    _recompute();
  }

  void advanceOffset(int count, {int? columns}) {
    final oldOffset = offset;
    offset += count;
    if (offset > lineEnd) offset = lineEnd;
    if (columns != null) {
      column += columns;
    } else {
      for (var i = oldOffset; i < offset; i++) {
        final cu = text.codeUnitAt(i);
        if (cu == 0x09) {
          column += 4 - (column % 4);
        } else {
          column++;
        }
      }
    }
    partialTab = 0;
    _recompute();
  }

  void advanceColumns(int count) {
    if (count <= 0) return;
    if (partialTab > 0) {
      if (count <= partialTab) {
        column += count;
        partialTab -= count;
        _recompute();
        return;
      } else {
        final rem = count - partialTab;
        column += partialTab;
        partialTab = 0;
        count = rem;
      }
    }

    while (count > 0 && offset < lineEnd) {
      final cu = text.codeUnitAt(offset);
      if (cu == 0x20) {
        offset++;
        column++;
        count--;
      } else if (cu == 0x09) {
        final tabWidth = 4 - (column % 4);
        if (tabWidth <= count) {
          offset++;
          column += tabWidth;
          count -= tabWidth;
        } else {
          // Tab is partially consumed.
          offset++;
          column += count;
          partialTab = tabWidth - count;
          count = 0;
        }
      } else {
        break;
      }
    }
    _recompute();
  }

  String rest([bool expandPartialTabs = true]) {
    final body = offset < lineEnd ? text.substring(offset, lineEnd) : '';
    if (expandPartialTabs && partialTab > 0) {
      return (' ' * partialTab) + body;
    }
    return body;
  }
}
