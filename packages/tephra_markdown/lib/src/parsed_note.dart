// © 2026 Tephra. All rights reserved.

import 'line_index.dart';
import 'nodes.dart';
import 'note_models.dart';

/// A fully parsed Markdown note containing AST and pre-extracted convenience lists.
final class ParsedNote {
  const ParsedNote({
    required this.text,
    required this.root,
    required this.frontmatter,
    required this.frontmatterValid,
    required this.headings,
    required this.wikiLinks,
    required this.links,
    required this.tags,
    required this.aliases,
    required this.blockIds,
    required this.tasks,
    required this.linkDefinitions,
    required this.lines,
  });

  /// The original note source text.
  final String text;

  /// Root AST document node.
  final MdDocument root;

  /// Decoded YAML frontmatter key-value pairs (empty if none or invalid).
  final Map<String, Object?> frontmatter;

  /// True if frontmatter is absent or parsed validly; false if invalid YAML.
  final bool frontmatterValid;

  /// All headings in document order.
  final List<MdHeading> headings;

  /// All wikilinks (including embeds) in document order.
  final List<MdWikiLink> wikiLinks;

  /// All inline links and image links in document order.
  final List<MdLink> links;

  /// Deduplicated tags without leading '#', preserving first occurrence.
  final List<String> tags;

  /// Aliases from frontmatter.
  final List<String> aliases;

  /// Block reference identifiers and their owning blocks in document order.
  final List<BlockRef> blockIds;

  /// Task items in list items with status and range.
  final List<TaskItem> tasks;

  /// All link reference definitions in the document.
  final Map<String, LinkDefinition> linkDefinitions;

  /// Line index for offset/line conversions.
  final LineIndex lines;
}
