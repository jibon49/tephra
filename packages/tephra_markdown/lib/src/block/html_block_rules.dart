// © 2026 Tephra. All rights reserved.

import 'line_cursor.dart';

const Set<String> htmlBlockTags = {
  'address',
  'article',
  'aside',
  'base',
  'basefont',
  'blockquote',
  'body',
  'caption',
  'center',
  'col',
  'colgroup',
  'dd',
  'details',
  'dialog',
  'dir',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'frame',
  'frameset',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hr',
  'html',
  'iframe',
  'legend',
  'li',
  'link',
  'main',
  'menu',
  'menuitem',
  'nav',
  'noframes',
  'ol',
  'optgroup',
  'option',
  'p',
  'param',
  'search',
  'section',
  'summary',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'title',
  'tr',
  'track',
  'ul',
};

final RegExp _type1Start = RegExp(
  r'^<(?:script|pre|style|textarea)(?:\s|>|$)',
  caseSensitive: false,
);
final RegExp _type1End = RegExp(
  r'</(?:script|pre|style|textarea)>',
  caseSensitive: false,
);

final RegExp _type4Start = RegExp(r'^<![a-zA-Z]');

final RegExp _type6Start = RegExp(
  r'^</?(?:'
  r'address|article|aside|base|basefont|blockquote|body|caption|center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|header|hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul'
  r')(?:\s|[/]?>|$)',
  caseSensitive: false,
);

final RegExp _type7OpenTag = RegExp(
  r'^<([a-zA-Z][a-zA-Z0-9-]*)'
  r'(?:\s+[a-zA-Z_:][a-zA-Z0-9_.:-]*(?:\s*=\s*(?:[^\s"'
  '=<>`]+|'
  '[^'
  ']*'
  '|"[^"]*"))?)*'
  r'\s*/?>\s*$',
);

final RegExp _type7CloseTag = RegExp(r'^</([a-zA-Z][a-zA-Z0-9-]*)\s*>\s*$');

/// Checks if [cursor] matches an HTML block start (types 1..7).
///
/// Returns the HTML block type (1..7) or 0 if no match.
/// [canInterruptParagraph] is false when testing against an open paragraph.
int checkHtmlBlockStart(
  LineCursor cursor, {
  required bool canInterruptParagraph,
}) {
  if (cursor.indent > 3) return 0;
  if (cursor.blank) return 0;

  final rest = cursor.text.substring(cursor.nextNonSpaceOffset, cursor.lineEnd);
  if (!rest.startsWith('<')) return 0;

  // Type 1: <script, <pre, <style, <textarea
  if (_type1Start.hasMatch(rest)) {
    return 1;
  }

  // Type 2: <!--
  if (rest.startsWith('<!--')) {
    return 2;
  }

  // Type 3: <?
  if (rest.startsWith('<?')) {
    return 3;
  }

  // Type 4: <! + ASCII letter
  if (_type4Start.hasMatch(rest)) {
    return 4;
  }

  // Type 5: <![CDATA[
  if (rest.startsWith('<![CDATA[')) {
    return 5;
  }

  // Type 6: 62 block tags
  if (_type6Start.hasMatch(rest)) {
    return 6;
  }

  // Type 7: complete open/close tag, followed only by whitespace to end of line
  if (canInterruptParagraph) {
    // Type 7 cannot interrupt a paragraph
    final openMatch = _type7OpenTag.firstMatch(rest);
    if (openMatch != null) {
      final tagName = openMatch.group(1)!.toLowerCase();
      if (tagName != 'script' &&
          tagName != 'style' &&
          tagName != 'pre' &&
          tagName != 'textarea') {
        return 7;
      }
    }
    final closeMatch = _type7CloseTag.firstMatch(rest);
    if (closeMatch != null) {
      final tagName = closeMatch.group(1)!.toLowerCase();
      if (tagName != 'script' &&
          tagName != 'style' &&
          tagName != 'pre' &&
          tagName != 'textarea') {
        return 7;
      }
    }
  }

  return 0;
}

/// Checks if [line] satisfies the end condition for HTML block of [htmlType].
bool checkHtmlBlockEnd(String line, int htmlType) {
  switch (htmlType) {
    case 1:
      return _type1End.hasMatch(line);
    case 2:
      return line.contains('-->');
    case 3:
      return line.contains('?>');
    case 4:
      return line.contains('>');
    case 5:
      return line.contains(']]>');
    case 6:
    case 7:
      return line.trim().isEmpty;
    default:
      return true;
  }
}
