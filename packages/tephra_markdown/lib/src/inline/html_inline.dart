// © 2026 Tephra. All rights reserved.

import '../nodes.dart';
import '../util/offset_map.dart';

final class HtmlInlineResult {
  HtmlInlineResult(this.node, this.nextIndex);

  final MdHtmlInline node;
  final int nextIndex;
}

// CommonMark 0.31.2 raw HTML inline patterns
const _tagName = r'[A-Za-z][A-Za-z0-9-]*';
const _attrName = r'[a-zA-Z_:][a-zA-Z0-9:._-]*';
const _unquotedValue = r'''[^ \t\r\n\f"'=<>`]+''';
const _singleQuotedValue = r"'[^']*'";
const _doubleQuotedValue = r'"[^"]*"';
const _attrValue =
    '(?:$_unquotedValue|$_singleQuotedValue|$_doubleQuotedValue)';
const _attrValueSpec = '(?:\\s*=\\s*$_attrValue)';
const _attribute = '(?:\\s+$_attrName$_attrValueSpec?)';

final RegExp _rawHtmlRegex = RegExp(
  '(?:'
  '<$_tagName$_attribute*\\s*/?>'
  '|</$_tagName\\s*>'
  r'|<!--(?:[^-]|-(?!->))*-->'
  r'|<\?[\s\S]*?\?>'
  r'|<![A-Z]+\s+[^>]*>'
  r'|<!\[CDATA\[[\s\S]*?\]\]>'
  ')',
);

/// Tries to parse a raw HTML inline tag starting at [index] in [text].
HtmlInlineResult? parseHtmlInline({
  required String text,
  required int index,
  required OffsetMap map,
}) {
  if (text.codeUnitAt(index) != 0x3C) return null; // '<'

  final match = _rawHtmlRegex.matchAsPrefix(text, index);
  if (match == null) return null;

  final html = match.group(0)!;
  final end = index + html.length;

  final node = MdHtmlInline(
    map.toSource(index),
    map.toSourceEnd(end),
    html: html,
  );

  return HtmlInlineResult(node, end);
}
