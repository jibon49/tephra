// © 2026 Tephra. All rights reserved.

import 'note_models.dart';

/// Base class for all Markdown Abstract Syntax Tree (AST) nodes.
sealed class MdNode {
  MdNode(this.start, this.end);

  /// Start offset in UTF-16 code units in the source document.
  final int start;

  /// End offset (exclusive) in UTF-16 code units in the source document.
  final int end;

  /// Child nodes of this AST node, or empty list if leaf.
  List<MdNode> get children => const [];
}

/// The root node of a parsed markdown document.
final class MdDocument extends MdNode {
  MdDocument(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// YAML frontmatter block at the very top of a document.
final class MdFrontmatter extends MdNode {
  MdFrontmatter(
    super.start,
    super.end, {
    required this.yaml,
    required this.contentStart,
  });

  /// The raw YAML text between the opening and closing `---` delimiters.
  final String yaml;

  /// UTF-16 source offset of the first character after the opening `---` line.
  final int contentStart;
}

/// An ATX or Setext heading (`# Heading` or `Heading\n===`).
final class MdHeading extends MdNode {
  MdHeading(
    super.start,
    super.end, {
    required this.level,
    this.blockId,
    this.isSetext = false,
    List<MdNode> children = const [],
  }) : children = List.unmodifiable(children);

  /// Heading level 1 to 6.
  final int level;

  /// Trailing block reference ID if present: `# Heading ^sec-1`.
  final String? blockId;

  /// True if parsed from Setext syntax (`===` or `---`).
  final bool isSetext;

  @override
  final List<MdNode> children;
}

/// A standard text paragraph containing inline elements.
final class MdParagraph extends MdNode {
  MdParagraph(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// A block quotation (`> text`).
final class MdBlockQuote extends MdNode {
  MdBlockQuote(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// An Obsidian-style callout block (`> [!type] Title`).
final class MdCallout extends MdNode {
  MdCallout(
    super.start,
    super.end, {
    required this.type,
    this.title,
    this.fold = CalloutFold.none,
    List<MdNode> children = const [],
  }) : children = List.unmodifiable(children);

  /// Lower-case callout type name (e.g. `note`, `tip`, `warning`).
  final String type;

  /// Raw title text following the marker, trimmed; null if empty.
  final String? title;

  /// Foldable status: none (not foldable), expanded (`+`), or collapsed (`-`).
  final CalloutFold fold;

  @override
  final List<MdNode> children;
}

/// An ordered or unordered list container.
final class MdList extends MdNode {
  MdList(
    super.start,
    super.end, {
    required this.ordered,
    this.startNumber = 1,
    this.tight = true,
    List<MdListItem> children = const [],
  }) : children = List.unmodifiable(children);

  final bool ordered;
  final int startNumber;
  final bool tight;

  @override
  final List<MdListItem> children;
}

/// An item within a list.
final class MdListItem extends MdNode {
  MdListItem(
    super.start,
    super.end, {
    this.task,
    List<MdNode> children = const [],
  }) : children = List.unmodifiable(children);

  /// Optional task checkbox status: `[ ]`, `[x]`, `[-]`, etc.
  final TaskStatus? task;

  @override
  final List<MdNode> children;
}

/// A fenced (```) or indented code block.
final class MdCodeBlock extends MdNode {
  MdCodeBlock(
    super.start,
    super.end, {
    this.language,
    this.info = '',
    required this.code,
    this.fenced = true,
  });

  /// Lower-case first word of info string, null if empty.
  final String? language;

  /// Full raw info string after the opening fence.
  final String info;

  /// The code content.
  final String code;

  /// True for fenced code blocks, false for 4-space indented blocks.
  final bool fenced;
}

/// A display math block (`$$ ... $$`).
final class MdMathBlock extends MdNode {
  MdMathBlock(super.start, super.end, {required this.tex});

  /// The LaTeX mathematics string.
  final String tex;
}

/// A GFM table.
final class MdTable extends MdNode {
  MdTable(
    super.start,
    super.end, {
    this.aligns = const [],
    List<MdTableRow> children = const [],
  }) : children = List.unmodifiable(children);

  /// Alignment per column.
  final List<TableAlign> aligns;

  @override
  final List<MdTableRow> children;
}

/// A row in a table. First row is typically header.
final class MdTableRow extends MdNode {
  MdTableRow(
    super.start,
    super.end, {
    this.header = false,
    List<MdTableCell> children = const [],
  }) : children = List.unmodifiable(children);

  final bool header;

  @override
  final List<MdTableCell> children;
}

/// A single cell in a table row.
final class MdTableCell extends MdNode {
  MdTableCell(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// A horizontal rule or thematic break (`---`, `***`, `___`).
final class MdThematicBreak extends MdNode {
  MdThematicBreak(super.start, super.end);
}

/// A block-level raw HTML chunk.
final class MdHtmlBlock extends MdNode {
  MdHtmlBlock(super.start, super.end, {required this.html});

  final String html;
}

/// A footnote definition block (`[^label]: content`).
final class MdFootnoteDefinition extends MdNode {
  MdFootnoteDefinition(
    super.start,
    super.end, {
    required this.label,
    List<MdNode> children = const [],
  }) : children = List.unmodifiable(children);

  final String label;

  @override
  final List<MdNode> children;
}

/// A multi-line Obsidian comment block (`%% comment %%`).
final class MdCommentBlock extends MdNode {
  MdCommentBlock(super.start, super.end, {required this.text});

  final String text;
}

/// A leaf text inline node with decoded entities and backslash escapes.
final class MdText extends MdNode {
  MdText(super.start, super.end, {required this.text});

  /// Decoded text content.
  final String text;
}

/// Emphasised / italic text (`*text*` or `_text_`).
final class MdEmphasis extends MdNode {
  MdEmphasis(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// Strong / bold text (`**text**` or `__text__`).
final class MdStrong extends MdNode {
  MdStrong(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// Strikethrough text (`~~text~~`).
final class MdStrikethrough extends MdNode {
  MdStrikethrough(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// Highlighted text (`==text==`).
final class MdHighlight extends MdNode {
  MdHighlight(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// Inline code span (`code`).
final class MdInlineCode extends MdNode {
  MdInlineCode(super.start, super.end, {required this.code});

  final String code;
}

/// An Obsidian wikilink or media embed (`[[target]]` or `![[image.png]]`).
final class MdWikiLink extends MdNode {
  MdWikiLink(
    super.start,
    super.end, {
    required this.target,
    this.heading,
    this.blockRef,
    this.alias,
    this.embed = false,
    this.size,
    this.pdfPage,
  });

  /// The link destination path/name.
  final String target;

  /// Sub-heading anchor (`#heading`) if present.
  final String? heading;

  /// Block reference anchor (`#^block-id`) if present.
  final String? blockRef;

  /// Custom alias text (`[[target|alias]]`) if present.
  final String? alias;

  /// True if prefixed by `!` for embedded transclusion.
  final bool embed;

  /// Embedded image/media dimensions if specified: `![[img.png|100x200]]`.
  final EmbedSize? size;

  /// PDF page anchor if present: `[[doc.pdf#page=4]]`.
  final String? pdfPage;
}

/// A standard markdown hyperlink or image: `[text](url)` or `![alt](url)`.
final class MdLink extends MdNode {
  MdLink(
    super.start,
    super.end, {
    required this.url,
    this.title,
    this.image = false,
    List<MdNode> children = const [],
  }) : children = List.unmodifiable(children);

  final String url;
  final String? title;
  final bool image;

  @override
  final List<MdNode> children;
}

/// An autolink (`<https://example.com>`).
final class MdAutolink extends MdNode {
  MdAutolink(super.start, super.end, {required this.url});

  final String url;
}

/// An Obsidian tag (`#tag` or `#nested/tag`).
final class MdTag extends MdNode {
  MdTag(super.start, super.end, {required this.name});

  /// Tag name without the leading `#`, in original case.
  final String name;
}

/// An Obsidian block identifier at line end (`^block-id`).
final class MdBlockId extends MdNode {
  MdBlockId(super.start, super.end, {required this.id});

  final String id;
}

/// Inline LaTeX mathematics (`$x^2$`).
final class MdInlineMath extends MdNode {
  MdInlineMath(super.start, super.end, {required this.tex});

  final String tex;
}

/// A footnote reference marker (`[^1]`).
final class MdFootnoteRef extends MdNode {
  MdFootnoteRef(super.start, super.end, {required this.label});

  final String label;
}

/// An inline footnote (`^[footnote text]`).
final class MdInlineFootnote extends MdNode {
  MdInlineFootnote(super.start, super.end, {List<MdNode> children = const []})
    : children = List.unmodifiable(children);

  @override
  final List<MdNode> children;
}

/// An inline Obsidian comment (`%% comment %%`).
final class MdCommentInline extends MdNode {
  MdCommentInline(super.start, super.end, {required this.text});

  final String text;
}

/// Inline raw HTML tag (`<span>`).
final class MdHtmlInline extends MdNode {
  MdHtmlInline(super.start, super.end, {required this.html});

  final String html;
}

/// A hard line break (two trailing spaces or backslash + newline).
final class MdHardBreak extends MdNode {
  MdHardBreak(super.start, super.end);
}

/// A soft line break (regular newline within a paragraph).
final class MdSoftBreak extends MdNode {
  MdSoftBreak(super.start, super.end);
}
