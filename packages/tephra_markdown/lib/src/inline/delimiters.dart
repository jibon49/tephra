// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';
import '../util/unicode.dart';
import 'inline_scanner.dart';

final class Delimiter {
  Delimiter({
    required this.char,
    required this.count,
    required this.origCount,
    required this.canOpen,
    required this.canClose,
    required this.item,
  });

  final int char;
  int count;
  final int origCount;
  final bool canOpen;
  final bool canClose;
  final InlineItem item;

  Delimiter? prev;
  Delimiter? next;
}

final class DelimiterStack {
  Delimiter? head;
  Delimiter? tail;

  void push(Delimiter d) {
    if (tail == null) {
      head = d;
      tail = d;
    } else {
      tail!.next = d;
      d.prev = tail;
      tail = d;
    }
  }

  void remove(Delimiter d) {
    if (d.prev != null) {
      d.prev!.next = d.next;
    } else {
      head = d.next;
    }
    if (d.next != null) {
      d.next!.prev = d.prev;
    } else {
      tail = d.prev;
    }
    d.prev = null;
    d.next = null;
  }

  /// Processes emphasis from [stackBottom] to the end of the stack per CommonMark spec.
  void processEmphasis(
    OffsetMap map,
    Delimiter? stackBottom,
    InlineItemList itemList,
  ) {
    var closer = stackBottom == null ? head : stackBottom.next;

    // openers_bottom table: char -> canOpen (0/1) -> (origCount % 3) -> Delimiter?
    final openersBottom = <int, Map<int, Map<int, Delimiter?>>>{};

    Delimiter? getBottom(int char, bool canOpen, int mod) {
      return openersBottom[char]?[canOpen ? 1 : 0]?[mod];
    }

    void setBottom(int char, bool canOpen, int mod, Delimiter? d) {
      openersBottom
              .putIfAbsent(char, () => {})
              .putIfAbsent(canOpen ? 1 : 0, () => {})[mod] =
          d;
    }

    void resetBottomForChar(int char) {
      openersBottom.remove(char);
    }

    while (closer != null) {
      if (!closer.canClose) {
        closer = closer.next;
        continue;
      }

      // Look back for an opener
      var opener = closer.prev;
      var openerFound = false;
      final bottom = getBottom(
        closer.char,
        closer.canOpen,
        closer.origCount % 3,
      );

      while (opener != null && opener != stackBottom && opener != bottom) {
        if (opener.char == closer.char && opener.canOpen) {
          // Check Rule of 3 for '*' and '_'
          var ruleOf3Violated = false;
          if (opener.char == 0x2A || opener.char == 0x5F) {
            // '*' or '_'
            if ((opener.canOpen && opener.canClose) ||
                (closer.canOpen && closer.canClose)) {
              if ((opener.origCount + closer.origCount) % 3 == 0) {
                if (opener.origCount % 3 != 0 || closer.origCount % 3 != 0) {
                  ruleOf3Violated = true;
                }
              }
            }
          }

          if (!ruleOf3Violated) {
            openerFound = true;
            break;
          }
        }
        opener = opener.prev;
      }

      if (!openerFound || opener == null) {
        setBottom(
          closer.char,
          closer.canOpen,
          closer.origCount % 3,
          closer.prev,
        );
        final nextCloser = closer.next;
        if (!closer.canOpen) {
          remove(closer);
        }
        closer = nextCloser;
        continue;
      }

      // Matched opener and closer!
      final delimsUsed =
          (opener.char == 0x7E || opener.char == 0x3D) // '~' or '='
          ? 2
          : ((opener.count >= 2 && closer.count >= 2) ? 2 : 1);

      // Virtual ranges of the formatted span
      final vStart = opener.item.virtualEnd - delimsUsed;
      final vEnd = closer.item.virtualStart + delimsUsed;
      final srcStart = map.toSource(vStart);
      final srcEnd = map.toSourceEnd(vEnd);

      // Collect children strictly between opener.item and closer.item
      final children = itemList.collectChildrenBetween(
        opener.item,
        closer.item,
        map,
      );

      // Create new AST node
      final MdNode newNode;
      if (opener.char == 0x2A || opener.char == 0x5F) {
        // '*' or '_'
        if (delimsUsed == 2) {
          newNode = MdStrong(srcStart, srcEnd, children: children);
        } else {
          newNode = MdEmphasis(srcStart, srcEnd, children: children);
        }
      } else if (opener.char == 0x7E) {
        // '~'
        newNode = MdStrikethrough(srcStart, srcEnd, children: children);
      } else {
        // '='
        newNode = MdHighlight(srcStart, srcEnd, children: children);
      }

      // Update opener
      opener.count -= delimsUsed;
      opener.item.virtualEnd -= delimsUsed;
      opener.item.text = opener.item.text.substring(0, opener.count);

      // Update closer
      closer.count -= delimsUsed;
      closer.item.virtualStart += delimsUsed;
      closer.item.text = closer.item.text.substring(delimsUsed);

      // Replace items between opener.item and closer.item with newNode
      final nodeItem = InlineItem.node(newNode, vStart, vEnd);
      itemList.replaceBetween(opener.item, closer.item, nodeItem);

      // Remove any delimiters strictly between opener and closer from delimiter stack
      var d = opener.next;
      while (d != null && d != closer) {
        final nextD = d.next;
        remove(d);
        d = nextD;
      }

      resetBottomForChar(opener.char);

      // If opener is exhausted, remove it
      if (opener.count == 0) {
        itemList.remove(opener.item);
        remove(opener);
      }

      // If closer is exhausted, remove it and advance
      if (closer.count == 0) {
        final nextCloser = closer.next;
        itemList.remove(closer.item);
        remove(closer);
        closer = nextCloser;
      }
    }
  }
}

/// Checks flanking conditions for a delimiter run per CommonMark spec §6.2.
(bool leftFlanking, bool rightFlanking) computeFlanking({
  required String text,
  required int start,
  required int end,
}) {
  final int? prevChar = start > 0 ? text.codeUnitAt(start - 1) : null;
  final int? nextChar = end < text.length ? text.codeUnitAt(end) : null;

  final prevIsWhitespace = prevChar == null || isUnicodeWhitespace(prevChar);
  final prevIsPunctuation = prevChar != null && isUnicodePunctuation(prevChar);
  final nextIsWhitespace = nextChar == null || isUnicodeWhitespace(nextChar);
  final nextIsPunctuation = nextChar != null && isUnicodePunctuation(nextChar);

  final leftFlanking =
      !nextIsWhitespace &&
      (!nextIsPunctuation || (prevIsWhitespace || prevIsPunctuation));
  final rightFlanking =
      !prevIsWhitespace &&
      (!prevIsPunctuation || (nextIsWhitespace || nextIsPunctuation));

  return (leftFlanking, rightFlanking);
}
