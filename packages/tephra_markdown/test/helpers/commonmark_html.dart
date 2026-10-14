// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_markdown/src/nodes.dart';

/// Renders a CommonMark document AST to standard CommonMark HTML.
String renderHtml(MdDocument doc, String source) {
  final buf = StringBuffer();
  _renderNodes(doc.children, buf, tight: false);
  return buf.toString();
}

void _renderNodes(List<MdNode> nodes, StringBuffer buf, {required bool tight}) {
  for (var i = 0; i < nodes.length; i++) {
    _renderNode(nodes[i], buf, tight: tight);
  }
}

void _renderNode(MdNode node, StringBuffer buf, {required bool tight}) {
  switch (node) {
    case MdDocument():
      _renderNodes(node.children, buf, tight: false);

    case MdParagraph():
      if (tight) {
        _renderInlines(node.children, buf);
      } else {
        buf.write('<p>');
        _renderInlines(node.children, buf);
        buf.write('</p>\n');
      }

    case MdHeading():
      buf.write('<h${node.level}>');
      _renderInlines(node.children, buf);
      buf.write('</h${node.level}>\n');

    case MdBlockQuote():
      buf.write('<blockquote>\n');
      _renderNodes(node.children, buf, tight: false);
      buf.write('</blockquote>\n');

    case MdList():
      if (node.ordered) {
        if (node.startNumber != 1) {
          buf.write('<ol start="${node.startNumber}">\n');
        } else {
          buf.write('<ol>\n');
        }
      } else {
        buf.write('<ul>\n');
      }

      for (final item in node.children) {
        _renderListItem(item, buf, tight: node.tight);
      }

      if (node.ordered) {
        buf.write('</ol>\n');
      } else {
        buf.write('</ul>\n');
      }

    case MdListItem():
      _renderListItem(node, buf, tight: false);

    case MdCodeBlock():
      if (node.language != null && node.language!.isNotEmpty) {
        buf.write(
          '<pre><code class="language-${_escapeHtml(node.language!)}">',
        );
      } else {
        buf.write('<pre><code>');
      }
      buf.write(_escapeHtml(node.code));
      buf.write('</code></pre>\n');

    case MdThematicBreak():
      buf.write('<hr />\n');

    case MdHtmlBlock():
      buf.write(node.html);
      buf.write('\n');

    default:
      // Other block types (Obsidian extensions not active in CommonMark mode)
      break;
  }
}

void _renderListItem(MdListItem item, StringBuffer buf, {required bool tight}) {
  if (item.children.isEmpty) {
    buf.write('<li></li>\n');
    return;
  }

  if (tight) {
    buf.write('<li>');
    for (var i = 0; i < item.children.length; i++) {
      final child = item.children[i];
      if (i == 0 && child is MdParagraph) {
        _renderInlines(child.children, buf);
      } else if (child is MdParagraph) {
        buf.write('\n<p>');
        _renderInlines(child.children, buf);
        buf.write('</p>');
      } else {
        buf.write('\n');
        _renderNode(child, buf, tight: false);
      }
    }
    buf.write('</li>\n');
  } else {
    buf.write('<li>\n');
    _renderNodes(item.children, buf, tight: false);
    buf.write('</li>\n');
  }
}

void _renderInlines(List<MdNode> inlines, StringBuffer buf) {
  for (final inline in inlines) {
    _renderInline(inline, buf);
  }
}

void _renderInline(MdNode node, StringBuffer buf) {
  switch (node) {
    case MdText():
      buf.write(_escapeHtml(node.text));

    case MdEmphasis():
      buf.write('<em>');
      _renderInlines(node.children, buf);
      buf.write('</em>');

    case MdStrong():
      buf.write('<strong>');
      _renderInlines(node.children, buf);
      buf.write('</strong>');

    case MdInlineCode():
      buf.write('<code>');
      buf.write(_escapeHtml(node.code));
      buf.write('</code>');

    case MdHtmlInline():
      buf.write(node.html);

    case MdSoftBreak():
      buf.write('\n');

    case MdHardBreak():
      buf.write('<br />\n');

    case MdLink():
      if (node.image) {
        buf.write('<img src="${_encodeUrl(node.url)}" alt="');
        buf.write(_escapeHtml(_plainText(node.children)));
        buf.write('"');
        if (node.title != null) {
          buf.write(' title="${_escapeHtml(node.title!)}"');
        }
        buf.write(' />');
      } else {
        buf.write('<a href="${_encodeUrl(node.url)}"');
        if (node.title != null) {
          buf.write(' title="${_escapeHtml(node.title!)}"');
        }
        buf.write('>');
        _renderInlines(node.children, buf);
        buf.write('</a>');
      }

    case MdAutolink():
      buf.write('<a href="${_encodeUrl(node.url)}">');
      final text = node.url.startsWith('mailto:')
          ? node.url.substring(7)
          : node.url;
      buf.write(_escapeHtml(text));
      buf.write('</a>');

    default:
      break;
  }
}

String _plainText(List<MdNode> nodes) {
  final buf = StringBuffer();
  for (final node in nodes) {
    switch (node) {
      case MdText():
        buf.write(node.text);
      case MdInlineCode():
        buf.write(node.code);
      case MdSoftBreak():
      case MdHardBreak():
        buf.write(' ');
      default:
        buf.write(_plainText(node.children));
    }
  }
  return buf.toString();
}

String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// CommonMark URL percent-encoding: encode characters outside ASCII/safe set as UTF-8 percent bytes.
/// Safe chars per spec: [A-Za-z0-9-._~:/?#@!$&'()*+,;=%]
String _encodeUrl(String url) {
  final buf = StringBuffer();
  final bytes = utf8.encode(url);
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    // Check if b is ASCII
    if (b < 128) {
      final c = String.fromCharCode(b);
      if (_isSafeUriChar(c)) {
        if (c == '%') {
          // Keep existing %XX valid escape
          if (i + 2 < bytes.length &&
              _isHex(bytes[i + 1]) &&
              _isHex(bytes[i + 2])) {
            buf.write('%');
            buf.write(String.fromCharCode(bytes[i + 1]));
            buf.write(String.fromCharCode(bytes[i + 2]));
            i += 3;
            continue;
          } else {
            buf.write('%25');
          }
        } else {
          buf.write(c);
        }
      } else {
        buf.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
      i++;
    } else {
      buf.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      i++;
    }
  }
  return _escapeHtml(buf.toString());
}

bool _isSafeUriChar(String c) {
  final code = c.codeUnitAt(0);
  if ((code >= 0x30 && code <= 0x39) || // 0-9
      (code >= 0x41 && code <= 0x5A) || // A-Z
      (code >= 0x61 && code <= 0x7A)) {
    // a-z
    return true;
  }
  return '-._~:/?#@!\$&\'()*+,;=%'.contains(c);
}

bool _isHex(int b) {
  return (b >= 0x30 && b <= 0x39) ||
      (b >= 0x41 && b <= 0x46) ||
      (b >= 0x61 && b <= 0x66);
}
