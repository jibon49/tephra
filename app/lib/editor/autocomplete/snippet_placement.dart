// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/tephra_index.dart' hide Snippet;

import 'autocomplete_context.dart';
import 'autocomplete_insertion.dart';
import 'slash_commands.dart';

/// Places a slash command snippet into [text] at [ctx], preserving line prefixes
/// and blockquote/list indentation.
Insertion placeSlash(
  String text,
  SlashContext ctx,
  SlashCommand cmd,
  Snippet snippet,
) {
  // 1. Locate the caret line
  var lineStart = 0;
  for (var i = ctx.slashStart - 1; i >= 0; i--) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      lineStart = i + 1;
      break;
    }
  }

  var lineEnd = text.length;
  for (var i = ctx.replaceEnd; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A /* \n */ ) {
      lineEnd = i;
      break;
    }
  }

  final lineText = text.substring(lineStart, lineEnd);
  final slashStartInLine = ctx.slashStart - lineStart;
  final caretInLine = ctx.replaceEnd - lineStart;

  // 2. Extract linePrefix
  // - leading indentation and blockquote markers: ^(\s*(?:>\s?)*)
  final matchQuotes = RegExp(r'^(\s*(?:>\s?)*)').firstMatch(lineText);
  final quotePart = matchQuotes?.group(1) ?? '';
  final restLine = lineText.substring(quotePart.length);

  String linePrefix;
  int markerEndInLine;

  // Check for list marker following quotePart: ([-*+]|\d+[.)]) followed by optional [ ] and spaces
  final listMatch = RegExp(r'^([-*+]|\d+[.)])(\s+\[[ xX]\])?\s+')
      .firstMatch(restLine);
  if (listMatch != null) {
    final markerWidth = listMatch.group(0)!.length;
    final listSpaces = ' ' * markerWidth;
    linePrefix = quotePart + listSpaces;
    markerEndInLine = quotePart.length + markerWidth;
  } else {
    linePrefix = quotePart;
    markerEndInLine = quotePart.length;
  }

  // 3. Determine if text before slash is blank
  // "after removing linePrefix-style markers (> quote markers, and a list marker with its trailing space)
  // nothing but whitespace remains before the /."
  final bool isTextBeforeSlashBlank;
  if (slashStartInLine >= markerEndInLine) {
    final textBetween = lineText.substring(markerEndInLine, slashStartInLine);
    isTextBeforeSlashBlank = textBetween.trim().isEmpty;
  } else {
    isTextBeforeSlashBlank = true;
  }

  final textAfterCaret = lineText.substring(caretInLine);

  // 4. Heading commands (isBlock == false, prefix style)
  if (!cmd.isBlock && cmd.id.startsWith('heading')) {
    if (isTextBeforeSlashBlank) {
      final edit = TextEdit(ctx.slashStart, ctx.replaceEnd, snippet.text);
      final caretAfter = ctx.slashStart + snippet.caret;
      return Insertion([edit], caretAfter);
    } else {
      // Insert at the start of the line (after quotePart) and delete only the /query
      final insertOffset = lineStart + quotePart.length;
      final edit1 = TextEdit(insertOffset, insertOffset, snippet.text);
      final edit2 = TextEdit(ctx.slashStart, ctx.replaceEnd, '');
      final caretAfter = ctx.slashStart + snippet.text.length;
      return Insertion([edit1, edit2], caretAfter);
    }
  }

  // 5. Non-block inline commands (e.g. today, template)
  if (!cmd.isBlock) {
    final edit = TextEdit(ctx.slashStart, ctx.replaceEnd, snippet.text);
    final caretAfter = ctx.slashStart + snippet.caret;
    return Insertion([edit], caretAfter);
  }

  // 6. Block commands
  // Horizontal rule special check: blank line before it if previous line is not blank
  var extraBlankLineBefore = false;
  if (cmd.id == 'horizontal-rule' && lineStart > 0 && isTextBeforeSlashBlank) {
    var prevLineStart = 0;
    for (var i = lineStart - 2; i >= 0; i--) {
      if (text.codeUnitAt(i) == 0x0A) {
        prevLineStart = i + 1;
        break;
      }
    }
    final prevLine = text.substring(prevLineStart, lineStart - 1);
    if (prevLine.trim().isNotEmpty) {
      extraBlankLineBefore = true;
    }
  }

  String prefixToPrepend = '';
  if (!isTextBeforeSlashBlank) {
    prefixToPrepend = '\n$linePrefix';
  } else if (extraBlankLineBefore) {
    prefixToPrepend = '\n$linePrefix';
  }

  // Append '\n' + linePrefix if text after caret is non-blank
  String suffixToAppend = '';
  if (textAfterCaret.trim().isNotEmpty) {
    suffixToAppend = '\n$linePrefix';
  }

  // Transform snippet: every \n inside a block snippet is followed by linePrefix
  final transformed = StringBuffer();
  var transformedCaret = snippet.caret;

  for (var i = 0; i < snippet.text.length; i++) {
    final ch = snippet.text[i];
    transformed.write(ch);
    final isLastChar = i == snippet.text.length - 1;
    if (ch == '\n' && (!isLastChar || suffixToAppend.isNotEmpty)) {
      if (linePrefix.isNotEmpty) {
        transformed.write(linePrefix);
        if (i < snippet.caret) {
          transformedCaret += linePrefix.length;
        }
      }
    }
  }

  final replacement =
      '$prefixToPrepend${transformed.toString()}$suffixToAppend';
  final caretAfter = ctx.slashStart + prefixToPrepend.length + transformedCaret;
  final edit = TextEdit(ctx.slashStart, ctx.replaceEnd, replacement);
  return Insertion([edit], caretAfter);
}
