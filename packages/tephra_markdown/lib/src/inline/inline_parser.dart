// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../note_models.dart';
import '../parser_options.dart';
import '../util/entities.dart';
import '../util/offset_map.dart';
import '../util/unicode.dart';
import 'autolinks.dart';
import 'block_id_inline.dart';
import 'brackets.dart';
import 'code_spans.dart';
import 'delimiters.dart';
import 'footnotes_inline.dart';
import 'html_inline.dart';
import 'inline_scanner.dart';
import 'math_inline.dart';
import 'tags.dart';
import 'wikilinks.dart';

/// Source text and source offset mapping for inline parsing.
final class InlineSource {
  InlineSource({required this.text, required this.map});

  final String text;
  final OffsetMap map;
}

/// Context passed to inline parsing rules.
final class InlineContext {
  InlineContext({
    required this.options,
    required this.definitions,
    this.inTableCell = false,
    this.blockIdRange,
  });

  final ParserOptions options;
  final Map<String, LinkDefinition> definitions;
  final bool inTableCell;
  final (int start, int end)? blockIdRange;

  InlineContext withInTableCell(bool inTableCell) => InlineContext(
    options: options,
    definitions: definitions,
    inTableCell: inTableCell,
    blockIdRange: blockIdRange,
  );

  InlineContext withBlockIdRange((int start, int end)? range) => InlineContext(
    options: options,
    definitions: definitions,
    inTableCell: inTableCell,
    blockIdRange: range,
  );
}

bool _isAsciiPunctuation(int code) {
  return (code >= 33 && code <= 47) ||
      (code >= 58 && code <= 64) ||
      (code >= 91 && code <= 96) ||
      (code >= 123 && code <= 126);
}

bool _isSpecial(int c, ParserOptions options, String text, int index) {
  if (c == 0x0A || // '\n'
      c == 0x5C || // '\\'
      c == 0x60 || // '`'
      c == 0x21 || // '!'
      c == 0x5B || // '['
      c == 0x5D || // ']'
      c == 0x3C || // '<'
      c == 0x26 || // '&'
      c == 0x2A || // '*'
      c == 0x5F) {
    // '_'
    return true;
  }
  if (options.gfm && c == 0x7E) return true; // '~'
  if (options.obsidian) {
    if (c == 0x3D || // '='
        c == 0x25 || // '%'
        c == 0x24 || // '$'
        c == 0x23 || // '#'
        c == 0x5E) {
      // '^'
      return true;
    }
  }
  if (options.gfm &&
      (c == 0x68 || c == 0x48 || c == 0x77 || c == 0x57) &&
      isExtendedAutolinkBoundary(text, index)) {
    return true;
  }
  return false;
}

/// Parses inline markdown in [source] given [ctx].
List<MdNode> parseInlines(InlineSource source, InlineContext ctx) {
  final text = source.text;
  if (text.isEmpty) return const [];

  final map = source.map;
  final options = ctx.options;
  final itemList = InlineItemList();
  final delimiterStack = DelimiterStack();
  final bracketStack = BracketStack();

  var index = 0;

  while (index < text.length) {
    // 0. Check block ID range first
    if (ctx.blockIdRange != null && index == ctx.blockIdRange!.$1) {
      final blkRes = parseBlockId(text: text, index: index, map: map, ctx: ctx);
      if (blkRes != null) {
        itemList.appendNode(blkRes.node, index, blkRes.nextIndex);
        index = blkRes.nextIndex;
        continue;
      }
    }

    final c = text.codeUnitAt(index);

    // 1. Newline
    if (c == 0x0A) {
      // Check 2 or more trailing spaces
      if (index >= 2 &&
          text.codeUnitAt(index - 1) == 0x20 &&
          text.codeUnitAt(index - 2) == 0x20) {
        var sp = index - 1;
        while (sp >= 0 && text.codeUnitAt(sp) == 0x20) {
          sp--;
        }
        final spaceStart = sp + 1;
        itemList.trimTrailingSpaces(spaceStart);
        itemList.appendNode(
          MdHardBreak(map.toSource(spaceStart), map.toSourceEnd(index + 1)),
          spaceStart,
          index + 1,
        );
      } else {
        itemList.trimAllTrailingSpaces();
        itemList.appendNode(
          MdSoftBreak(map.toSource(index), map.toSourceEnd(index + 1)),
          index,
          index + 1,
        );
      }
      index++;
      continue;
    }

    // 2. Backslash
    if (c == 0x5C) {
      if (index + 1 < text.length) {
        final next = text.codeUnitAt(index + 1);
        if (next == 0x0A) {
          // Backslash hard break
          itemList.appendNode(
            MdHardBreak(map.toSource(index), map.toSourceEnd(index + 2)),
            index,
            index + 2,
          );
          index += 2;
          continue;
        } else if (_isAsciiPunctuation(next)) {
          // Escaped punctuation -> literal text
          itemList.appendText(
            text.substring(index + 1, index + 2),
            index,
            index + 2,
          );
          index += 2;
          continue;
        }
      }
      itemList.appendText(r'\', index, index + 1);
      index++;
      continue;
    }

    // 3. Code spans
    if (c == 0x60) {
      final codeRes = parseCodeSpan(
        text: text,
        index: index,
        map: map,
        inTableCell: ctx.inTableCell,
      );
      if (codeRes != null) {
        itemList.appendNode(codeRes.node, index, codeRes.nextIndex);
        index = codeRes.nextIndex;
        continue;
      }
      var runLen = 0;
      while (index + runLen < text.length &&
          text.codeUnitAt(index + runLen) == 0x60) {
        runLen++;
      }
      itemList.appendText(
        text.substring(index, index + runLen),
        index,
        index + runLen,
      );
      index += runLen;
      continue;
    }

    // 4. '!' (embed or image opener)
    if (c == 0x21) {
      if (options.obsidian && text.startsWith('![[', index)) {
        final wikiRes = parseWikiLink(text: text, index: index, map: map);
        if (wikiRes != null) {
          itemList.appendNode(wikiRes.node, index, wikiRes.nextIndex);
          index = wikiRes.nextIndex;
          continue;
        }
      }
      if (text.startsWith('![', index)) {
        final item = InlineItem.bracket(
          text: '![',
          vStart: index,
          vEnd: index + 2,
        );
        itemList.append(item);
        bracketStack.push(
          Bracket(
            isImage: true,
            item: item,
            delimiterBefore: delimiterStack.tail,
          ),
        );
        index += 2;
        continue;
      }
      itemList.appendText('!', index, index + 1);
      index++;
      continue;
    }

    // 5. '[' (footnote ref, wikilink, or link opener)
    if (c == 0x5B) {
      if (options.obsidian && text.startsWith('[^', index)) {
        final fnRes = parseFootnoteRef(text: text, index: index, map: map);
        if (fnRes != null) {
          itemList.appendNode(fnRes.node, index, fnRes.nextIndex);
          index = fnRes.nextIndex;
          continue;
        }
      }
      if (options.obsidian && text.startsWith('[[', index)) {
        final wikiRes = parseWikiLink(text: text, index: index, map: map);
        if (wikiRes != null) {
          itemList.appendNode(wikiRes.node, index, wikiRes.nextIndex);
          index = wikiRes.nextIndex;
          continue;
        }
      }
      final item = InlineItem.bracket(
        text: '[',
        vStart: index,
        vEnd: index + 1,
      );
      itemList.append(item);
      bracketStack.push(
        Bracket(
          isImage: false,
          item: item,
          delimiterBefore: delimiterStack.tail,
        ),
      );
      index++;
      continue;
    }

    // 6. ']' (link closer)
    if (c == 0x5D) {
      final b = bracketStack.tail;
      if (b == null) {
        itemList.appendText(']', index, index + 1);
        index++;
        continue;
      }
      if (!b.active) {
        bracketStack.pop();
        itemList.appendText(']', index, index + 1);
        index++;
        continue;
      }

      final innerText = text.substring(
        b.item.virtualStart + (b.isImage ? 2 : 1),
        index,
      );

      final inlineRes = parseInlineLinkTail(text, index + 1);
      final (String url, String? title, int nextIdx)? linkRes;
      if (inlineRes != null) {
        linkRes = inlineRes;
      } else {
        linkRes = parseReferenceLinkTail(
          text: text,
          indexAfterBracket: index + 1,
          bracketInnerText: innerText,
          definitions: ctx.definitions,
        );
      }

      if (linkRes != null) {
        delimiterStack.processEmphasis(map, b.delimiterBefore, itemList);
        if (!b.isImage) {
          var prevB = b.prev;
          while (prevB != null) {
            if (!prevB.isImage) prevB.active = false;
            prevB = prevB.prev;
          }
        }
        final children = itemList.collectChildrenFrom(b.item, map);
        final vStart = b.item.virtualStart;
        final vEnd = linkRes.$3;
        final node = MdLink(
          map.toSource(vStart),
          map.toSourceEnd(vEnd),
          url: linkRes.$1,
          title: linkRes.$2,
          image: b.isImage,
          children: children,
        );
        itemList.replaceFrom(b.item, InlineItem.node(node, vStart, vEnd));
        bracketStack.pop();
        index = linkRes.$3;
        continue;
      } else {
        bracketStack.pop();
        itemList.appendText(']', index, index + 1);
        index++;
        continue;
      }
    }

    // 7. '<' (autolink or raw HTML)
    if (c == 0x3C) {
      final autoRes = parseCommonMarkAutolink(
        text: text,
        index: index,
        map: map,
      );
      if (autoRes != null) {
        itemList.appendNode(autoRes.node, index, autoRes.nextIndex);
        index = autoRes.nextIndex;
        continue;
      }
      final htmlRes = parseHtmlInline(text: text, index: index, map: map);
      if (htmlRes != null) {
        itemList.appendNode(htmlRes.node, index, htmlRes.nextIndex);
        index = htmlRes.nextIndex;
        continue;
      }
      itemList.appendText('<', index, index + 1);
      index++;
      continue;
    }

    // 8. '&' (entity)
    if (c == 0x26) {
      final semi = text.indexOf(';', index + 1);
      if (semi != -1 && semi - index <= 32) {
        final body = text.substring(index + 1, semi);
        if (body.startsWith('#')) {
          final cp = parseNumericEntity(body);
          if (cp != null) {
            itemList.appendText(String.fromCharCode(cp), index, semi + 1);
            index = semi + 1;
            continue;
          }
        } else {
          final decoded = decodeEntity(body);
          if (decoded != null) {
            itemList.appendText(decoded, index, semi + 1);
            index = semi + 1;
            continue;
          }
        }
      }
      itemList.appendText('&', index, index + 1);
      index++;
      continue;
    }

    // 9. '*' or '_' (delimiters)
    if (c == 0x2A || c == 0x5F) {
      var runLen = 0;
      while (index + runLen < text.length &&
          text.codeUnitAt(index + runLen) == c) {
        runLen++;
      }
      final flanking = computeFlanking(
        text: text,
        start: index,
        end: index + runLen,
      );
      final bool canOpen;
      final bool canClose;
      if (c == 0x2A) {
        canOpen = flanking.$1;
        canClose = flanking.$2;
      } else {
        final prevPunct =
            index > 0 && isUnicodePunctuation(text.codeUnitAt(index - 1));
        final nextPunct =
            index + runLen < text.length &&
            isUnicodePunctuation(text.codeUnitAt(index + runLen));
        canOpen = flanking.$1 && (!flanking.$2 || prevPunct);
        canClose = flanking.$2 && (!flanking.$1 || nextPunct);
      }

      final rawText = text.substring(index, index + runLen);
      final item = InlineItem.delimiter(
        text: rawText,
        vStart: index,
        vEnd: index + runLen,
      );
      itemList.append(item);
      if (canOpen || canClose) {
        final delim = Delimiter(
          char: c,
          count: runLen,
          origCount: runLen,
          canOpen: canOpen,
          canClose: canClose,
          item: item,
        );
        delimiterStack.push(delim);
      }
      index += runLen;
      continue;
    }

    // 10. '~' (GFM strikethrough)
    if (options.gfm && c == 0x7E) {
      var runLen = 0;
      while (index + runLen < text.length &&
          text.codeUnitAt(index + runLen) == 0x7E) {
        runLen++;
      }
      if (runLen == 2) {
        final flanking = computeFlanking(
          text: text,
          start: index,
          end: index + 2,
        );
        final item = InlineItem.delimiter(
          text: '~~',
          vStart: index,
          vEnd: index + 2,
        );
        itemList.append(item);
        if (flanking.$1 || flanking.$2) {
          final delim = Delimiter(
            char: 0x7E,
            count: 2,
            origCount: 2,
            canOpen: flanking.$1,
            canClose: flanking.$2,
            item: item,
          );
          delimiterStack.push(delim);
        }
        index += 2;
        continue;
      }
      itemList.appendText(
        text.substring(index, index + runLen),
        index,
        index + runLen,
      );
      index += runLen;
      continue;
    }

    // 11. '=' (Obsidian highlight)
    if (options.obsidian && c == 0x3D) {
      var runLen = 0;
      while (index + runLen < text.length &&
          text.codeUnitAt(index + runLen) == 0x3D) {
        runLen++;
      }
      if (runLen == 2) {
        final flanking = computeFlanking(
          text: text,
          start: index,
          end: index + 2,
        );
        final item = InlineItem.delimiter(
          text: '==',
          vStart: index,
          vEnd: index + 2,
        );
        itemList.append(item);
        if (flanking.$1 || flanking.$2) {
          final delim = Delimiter(
            char: 0x3D,
            count: 2,
            origCount: 2,
            canOpen: flanking.$1,
            canClose: flanking.$2,
            item: item,
          );
          delimiterStack.push(delim);
        }
        index += 2;
        continue;
      }
      itemList.appendText(
        text.substring(index, index + runLen),
        index,
        index + runLen,
      );
      index += runLen;
      continue;
    }

    // 12. '%' (Obsidian comment)
    if (options.obsidian && text.startsWith('%%', index)) {
      final close = text.indexOf('%%', index + 2);
      if (close != -1) {
        final comment = text.substring(index + 2, close);
        final end = close + 2;
        final node = MdCommentInline(
          map.toSource(index),
          map.toSourceEnd(end),
          text: comment,
        );
        itemList.appendNode(node, index, end);
        index = end;
        continue;
      }
      itemList.appendText('%', index, index + 1);
      index++;
      continue;
    }

    // 13. '$' (Obsidian inline math)
    if (options.obsidian && c == 0x24) {
      final mathRes = parseMathInline(text: text, index: index, map: map);
      if (mathRes != null) {
        itemList.appendNode(mathRes.node, index, mathRes.nextIndex);
        index = mathRes.nextIndex;
        continue;
      }
      itemList.appendText(r'$', index, index + 1);
      index++;
      continue;
    }

    // 14. '#' (Obsidian tags)
    if (options.obsidian && c == 0x23) {
      final tagRes = parseTag(text: text, index: index, map: map);
      if (tagRes != null) {
        itemList.appendNode(tagRes.node, index, tagRes.nextIndex);
        index = tagRes.nextIndex;
        continue;
      }
      itemList.appendText('#', index, index + 1);
      index++;
      continue;
    }

    // 15. '^' (Obsidian inline footnote)
    if (options.obsidian && text.startsWith('^[', index)) {
      final fnRes = parseInlineFootnote(
        text: text,
        index: index,
        map: map,
        ctx: ctx,
        parseInlinesFn: parseInlines,
      );
      if (fnRes != null) {
        itemList.appendNode(fnRes.node, index, fnRes.nextIndex);
        index = fnRes.nextIndex;
        continue;
      }
      itemList.appendText('^', index, index + 1);
      index++;
      continue;
    }

    // 16. GFM extended autolink
    if (options.gfm && (c == 0x68 || c == 0x48 || c == 0x77 || c == 0x57)) {
      final autoRes = parseExtendedAutolink(text: text, index: index, map: map);
      if (autoRes != null) {
        itemList.appendNode(autoRes.node, index, autoRes.nextIndex);
        index = autoRes.nextIndex;
        continue;
      }
    }

    // 17. Literal run
    var end = index + 1;
    while (end < text.length &&
        !_isSpecial(text.codeUnitAt(end), options, text, end)) {
      end++;
    }
    itemList.appendText(text.substring(index, end), index, end);
    index = end;
  }

  // Final emphasis pass across remaining delimiters
  delimiterStack.processEmphasis(map, null, itemList);

  return itemList.toNodes(map);
}
