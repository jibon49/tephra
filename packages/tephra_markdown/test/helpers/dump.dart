// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/nodes.dart';
import 'package:tephra_markdown/src/note_models.dart';

/// Dumps an AST node to the canonical test string format defined in Step 01.10.
String dump(MdNode node) {
  final buf = StringBuffer();
  _dumpNode(node, buf);
  return buf.toString();
}

/// Dumps an AST node and its descendants with source ranges: `kind@start-end`.
String dumpWithRanges(MdNode node) {
  final items = <String>[];
  _dumpRanges(node, items);
  return items.join(' ');
}

void _dumpRanges(MdNode node, List<String> out) {
  final kind = switch (node) {
    MdDocument() => 'doc',
    MdFrontmatter() => 'fm',
    MdHeading(:final level) => 'h$level',
    MdParagraph() => 'p',
    MdBlockQuote() => 'bq',
    MdCallout() => 'callout',
    MdList(:final ordered) => ordered ? 'ol' : 'ul',
    MdListItem() => 'li',
    MdCodeBlock(:final fenced) => fenced ? 'code' : 'icode',
    MdMathBlock() => 'math',
    MdCommentBlock() => 'cmt',
    MdHtmlBlock() => 'html',
    MdThematicBreak() => 'hr',
    MdTable() => 'table',
    MdTableRow(:final header) => header ? 'trh' : 'tr',
    MdTableCell() => 'td',
    MdFootnoteDefinition() => 'fn',
    MdText() => 't',
    MdEmphasis() => 'em',
    MdStrong() => 'strong',
    MdStrikethrough() => 'del',
    MdHighlight() => 'mark',
    MdInlineCode() => 'c',
    MdWikiLink(:final embed) => embed ? 'embed' : 'wiki',
    MdLink(:final image) => image ? 'img' : 'link',
    MdAutolink() => 'auto',
    MdTag() => 'tag',
    MdBlockId() => 'bid',
    MdInlineMath() => 'imath',
    MdFootnoteRef() => 'fref',
    MdInlineFootnote() => 'ifn',
    MdCommentInline() => 'icmt',
    MdHtmlInline() => 'ihtml',
    MdHardBreak() => 'br',
    MdSoftBreak() => 'sb',
  };

  out.add('$kind@${node.start}-${node.end}');
  for (final child in node.children) {
    _dumpRanges(child, out);
  }
}

void _dumpNode(MdNode node, StringBuffer buf) {
  switch (node) {
    case MdDocument():
      if (node.children.isEmpty) {
        buf.write('doc');
      } else {
        buf.write('doc(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdFrontmatter():
      buf.write('fm');

    case MdHeading():
      buf.write('h${node.level}');
      if (node.blockId != null) {
        buf.write('{id=${node.blockId}}');
      }
      if (node.children.isNotEmpty) {
        buf.write('(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdParagraph():
      buf.write('p(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdBlockQuote():
      buf.write('bq(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdCallout():
      buf.write('callout{type=${node.type}');
      if (node.title != null) {
        buf.write(',title=${node.title}');
      }
      if (node.fold == CalloutFold.expanded) {
        buf.write(',f=+');
      } else if (node.fold == CalloutFold.collapsed) {
        buf.write(',f=-');
      }
      buf.write('}');
      if (node.children.isNotEmpty) {
        buf.write('(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdList():
      if (node.ordered) {
        buf.write('ol');
        final attrs = <String>[];
        if (node.startNumber != 1) {
          attrs.add('start=${node.startNumber}');
        }
        if (!node.tight) {
          attrs.add('loose');
        }
        if (attrs.isNotEmpty) {
          buf.write('{${attrs.join(',')}}');
        }
      } else {
        buf.write('ul');
        if (!node.tight) {
          buf.write('{loose}');
        }
      }
      buf.write('(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdListItem():
      buf.write('li');
      if (node.task != null) {
        final taskChar = node.task!.char == ' ' ? 'SP' : node.task!.char;
        buf.write('{task=$taskChar}');
      }
      buf.write('(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdCodeBlock():
      if (node.fenced) {
        buf.write('code');
        if (node.language != null && node.language!.isNotEmpty) {
          buf.write('{lang=${node.language}}');
        }
      } else {
        buf.write('icode');
      }

    case MdMathBlock():
      buf.write('math"${node.tex.replaceAll('\n', '⏎')}"');

    case MdCommentBlock():
      buf.write('cmt');

    case MdHtmlBlock():
      buf.write('html');

    case MdThematicBreak():
      buf.write('hr');

    case MdTable():
      final aligns = node.aligns
          .map(
            (a) => switch (a) {
              TableAlign.none => 'n',
              TableAlign.left => 'l',
              TableAlign.center => 'c',
              TableAlign.right => 'r',
            },
          )
          .join(',');
      buf.write('table{aligns=$aligns}(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdTableRow():
      buf.write(node.header ? 'trh(' : 'tr(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdTableCell():
      buf.write('td');
      if (node.children.isNotEmpty) {
        buf.write('(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdFootnoteDefinition():
      buf.write('fn{label=${node.label}}');
      if (node.children.isNotEmpty) {
        buf.write('(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdText():
      buf.write('t"${node.text.replaceAll('\n', '⏎')}"');

    case MdEmphasis():
      buf.write('em(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdStrong():
      buf.write('strong(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdStrikethrough():
      buf.write('del(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdHighlight():
      buf.write('mark(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdInlineCode():
      buf.write('c"${node.code.replaceAll('\n', '⏎')}"');

    case MdWikiLink():
      buf.write(node.embed ? 'embed{' : 'wiki{');
      buf.write('t=${node.target}');
      if (node.heading != null) {
        buf.write(',h=${node.heading}');
      }
      if (node.blockRef != null) {
        buf.write(',b=${node.blockRef}');
      }
      if (node.alias != null) {
        buf.write(',a=${node.alias}');
      }
      if (node.pdfPage != null) {
        buf.write(',p=${node.pdfPage}');
      }
      if (node.size != null) {
        buf.write(',w=${node.size!.width}');
        if (node.size!.height != null) {
          buf.write(',x=${node.size!.height}');
        }
      }
      buf.write('}');

    case MdLink():
      buf.write(node.image ? 'img{' : 'link{');
      buf.write('url=${node.url}');
      if (node.title != null) {
        buf.write(',title=${node.title}');
      }
      buf.write('}');
      if (node.children.isNotEmpty) {
        buf.write('(');
        _dumpChildren(node.children, buf);
        buf.write(')');
      }

    case MdAutolink():
      buf.write('auto{url=${node.url}}');

    case MdTag():
      buf.write('tag"${node.name}"');

    case MdBlockId():
      buf.write('bid"${node.id}"');

    case MdInlineMath():
      buf.write('imath"${node.tex.replaceAll('\n', '⏎')}"');

    case MdFootnoteRef():
      buf.write('fref"${node.label}"');

    case MdInlineFootnote():
      buf.write('ifn(');
      _dumpChildren(node.children, buf);
      buf.write(')');

    case MdCommentInline():
      buf.write('icmt"${node.text.replaceAll('\n', '⏎')}"');

    case MdHtmlInline():
      buf.write('ihtml"${node.html.replaceAll('\n', '⏎')}"');

    case MdHardBreak():
      buf.write('br');

    case MdSoftBreak():
      buf.write('sb');
  }
}

void _dumpChildren(List<MdNode> children, StringBuffer buf) {
  for (var i = 0; i < children.length; i++) {
    if (i > 0) buf.write(',');
    _dumpNode(children[i], buf);
  }
}
