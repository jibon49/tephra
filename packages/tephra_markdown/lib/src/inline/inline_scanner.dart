// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';

enum InlineItemKind { text, node, delimiter, bracket }

final class InlineItem {
  InlineItem({
    required this.kind,
    required this.text,
    required this.virtualStart,
    required this.virtualEnd,
    this.node,
  });

  factory InlineItem.text(String text, int vStart, int vEnd) => InlineItem(
    kind: InlineItemKind.text,
    text: text,
    virtualStart: vStart,
    virtualEnd: vEnd,
  );

  factory InlineItem.node(MdNode node, int vStart, int vEnd) => InlineItem(
    kind: InlineItemKind.node,
    text: '',
    virtualStart: vStart,
    virtualEnd: vEnd,
    node: node,
  );

  factory InlineItem.delimiter({
    required String text,
    required int vStart,
    required int vEnd,
  }) => InlineItem(
    kind: InlineItemKind.delimiter,
    text: text,
    virtualStart: vStart,
    virtualEnd: vEnd,
  );

  factory InlineItem.bracket({
    required String text,
    required int vStart,
    required int vEnd,
  }) => InlineItem(
    kind: InlineItemKind.bracket,
    text: text,
    virtualStart: vStart,
    virtualEnd: vEnd,
  );

  final InlineItemKind kind;
  String text;
  int virtualStart;
  int virtualEnd;
  MdNode? node;

  InlineItem? prev;
  InlineItem? next;
}

final class InlineItemList {
  InlineItem? head;
  InlineItem? tail;

  void append(InlineItem item) {
    if (tail == null) {
      head = item;
      tail = item;
    } else {
      tail!.next = item;
      item.prev = tail;
      tail = item;
    }
  }

  void appendText(String text, int vStart, int vEnd) {
    append(InlineItem.text(text, vStart, vEnd));
  }

  void appendNode(MdNode node, int vStart, int vEnd) {
    append(InlineItem.node(node, vStart, vEnd));
  }

  void remove(InlineItem item) {
    if (item.prev != null) {
      item.prev!.next = item.next;
    } else {
      head = item.next;
    }
    if (item.next != null) {
      item.next!.prev = item.prev;
    } else {
      tail = item.prev;
    }
    item.prev = null;
    item.next = null;
  }

  /// Trims trailing spaces from the previous text item back to [spaceStart].
  void trimTrailingSpaces(int spaceStart) {
    var cur = tail;
    while (cur != null) {
      if (cur.kind == InlineItemKind.text) {
        if (cur.virtualStart >= spaceStart) {
          final p = cur.prev;
          remove(cur);
          cur = p;
        } else {
          final spacesToTrim = cur.virtualEnd - spaceStart;
          if (spacesToTrim > 0) {
            if (cur.text.length > spacesToTrim) {
              cur.text = cur.text.substring(0, cur.text.length - spacesToTrim);
              cur.virtualEnd = spaceStart;
            } else {
              remove(cur);
            }
          }
          break;
        }
      } else {
        break;
      }
    }
  }

  /// Trims all trailing spaces from the last text item.
  void trimAllTrailingSpaces() {
    var cur = tail;
    while (cur != null) {
      if (cur.kind == InlineItemKind.text) {
        var t = cur.text;
        while (t.endsWith(' ') || t.endsWith('\t')) {
          t = t.substring(0, t.length - 1);
        }
        if (t.isEmpty) {
          final p = cur.prev;
          remove(cur);
          cur = p;
        } else {
          cur.virtualEnd -= (cur.text.length - t.length);
          cur.text = t;
          break;
        }
      } else {
        break;
      }
    }
  }

  /// Replaces items strictly between [start] and [end] with [newItem].
  void replaceBetween(InlineItem start, InlineItem end, InlineItem newItem) {
    var cur = start.next;
    while (cur != null && cur != end) {
      final next = cur.next;
      remove(cur);
      cur = next;
    }
    newItem.prev = start;
    newItem.next = end;
    start.next = newItem;
    end.prev = newItem;
  }

  /// Replaces all items from [start] to the end of the list with [newItem].
  void replaceFrom(InlineItem start, InlineItem newItem) {
    InlineItem? cur = start;
    while (cur != null) {
      final next = cur.next;
      remove(cur);
      cur = next;
    }
    append(newItem);
  }

  /// Collects children strictly between [start] and [end], merging adjacent [MdText] nodes.
  List<MdNode> collectChildrenBetween(
    InlineItem start,
    InlineItem end,
    OffsetMap map,
  ) {
    final rawNodes = <MdNode>[];
    var cur = start.next;
    while (cur != null && cur != end) {
      if (cur.kind == InlineItemKind.node && cur.node != null) {
        rawNodes.add(cur.node!);
      } else if (cur.text.isNotEmpty) {
        rawNodes.add(
          MdText(
            map.toSource(cur.virtualStart),
            map.toSourceEnd(cur.virtualEnd),
            text: cur.text,
          ),
        );
      }
      cur = cur.next;
    }
    return _mergeAdjacentTextNodes(rawNodes);
  }

  /// Collects children strictly after [start] to the end of the list.
  List<MdNode> collectChildrenFrom(InlineItem start, OffsetMap map) {
    final rawNodes = <MdNode>[];
    var cur = start.next;
    while (cur != null) {
      if (cur.kind == InlineItemKind.node && cur.node != null) {
        rawNodes.add(cur.node!);
      } else if (cur.text.isNotEmpty) {
        rawNodes.add(
          MdText(
            map.toSource(cur.virtualStart),
            map.toSourceEnd(cur.virtualEnd),
            text: cur.text,
          ),
        );
      }
      cur = cur.next;
    }
    return _mergeAdjacentTextNodes(rawNodes);
  }

  /// Converts all items in the list into [MdNode]s, merging adjacent [MdText] nodes.
  List<MdNode> toNodes(OffsetMap map) {
    final rawNodes = <MdNode>[];
    var cur = head;
    while (cur != null) {
      if (cur.kind == InlineItemKind.node && cur.node != null) {
        rawNodes.add(cur.node!);
      } else if (cur.text.isNotEmpty) {
        rawNodes.add(
          MdText(
            map.toSource(cur.virtualStart),
            map.toSourceEnd(cur.virtualEnd),
            text: cur.text,
          ),
        );
      }
      cur = cur.next;
    }
    return _mergeAdjacentTextNodes(rawNodes);
  }
}

List<MdNode> _mergeAdjacentTextNodes(List<MdNode> nodes) {
  if (nodes.length <= 1) return nodes;
  final result = <MdNode>[];
  MdText? pendingText;

  for (final node in nodes) {
    if (node is MdText) {
      if (pendingText == null) {
        pendingText = node;
      } else {
        pendingText = MdText(
          pendingText.start,
          node.end,
          text: '${pendingText.text}${node.text}',
        );
      }
    } else {
      if (pendingText != null) {
        result.add(pendingText);
        pendingText = null;
      }
      result.add(node);
    }
  }

  if (pendingText != null) {
    result.add(pendingText);
  }

  return result;
}
