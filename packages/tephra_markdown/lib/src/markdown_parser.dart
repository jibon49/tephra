// © 2026 Tephra. All rights reserved.

import 'block/block_parser.dart';
import 'frontmatter.dart';
import 'inline/inline_parser.dart';
import 'line_index.dart';
import 'nodes.dart';
import 'note_models.dart';
import 'parsed_note.dart';
import 'parser_options.dart';
import 'util/offset_map.dart';

/// Public entry point for parsing Markdown text into AST and extractions.
abstract final class MarkdownParser {
  /// Parses [text] with default [ParserOptions].
  static ParsedNote parse(String text) =>
      parseWith(text, const ParserOptions());

  /// Parses [text] with given [options].
  static ParsedNote parseWith(String text, ParserOptions options) {
    final lines = LineIndex(text);
    final blockResult = parseBlocks(text, options: options);

    final Map<String, Object?> frontmatter;
    final bool frontmatterValid;

    if (options.obsidian && blockResult.frontmatter != null) {
      final decoded = decodeFrontmatterYaml(blockResult.frontmatter!.yaml);
      if (decoded != null) {
        frontmatter = Map<String, Object?>.unmodifiable(decoded);
        frontmatterValid = true;
      } else {
        frontmatter = const <String, Object?>{};
        frontmatterValid = false;
      }
    } else {
      frontmatter = const <String, Object?>{};
      frontmatterValid = true;
    }

    final headings = <MdHeading>[];
    final wikiLinks = <MdWikiLink>[];
    final links = <MdLink>[];
    final inlineTags = <String>[];
    final tasks = <TaskItem>[];

    void visit(MdNode node) {
      if (node is MdHeading) {
        headings.add(node);
      } else if (node is MdWikiLink) {
        wikiLinks.add(node);
      } else if (node is MdLink) {
        links.add(node);
      } else if (node is MdTag) {
        inlineTags.add(node.name);
      } else if (node is MdListItem && node.task != null) {
        final task = node.task!;
        var textStart = task.offset + 2; // after ']'
        while (textStart < text.length &&
            (text[textStart] == ' ' || text[textStart] == '\t')) {
          textStart++;
        }
        var textEnd = textStart;
        for (final child in node.children) {
          if (child is MdParagraph) {
            textEnd = child.end;
            break;
          }
        }
        final taskText = textEnd > textStart
            ? text.substring(textStart, textEnd).trim()
            : '';
        tasks.add(
          TaskItem(
            status: task,
            text: taskText,
            start: node.start,
            end: node.end,
            statusOffset: task.offset,
            line: lines.lineOf(node.start),
          ),
        );
      }

      for (final child in node.children) {
        visit(child);
      }
    }

    visit(blockResult.root);

    final List<String> tags;
    final List<String> aliases;
    final List<BlockRef> blockIds;

    if (options.obsidian) {
      final fmTags = <String>[];
      final rawTags = frontmatter['tags'] ?? frontmatter['tag'];
      if (rawTags is List) {
        for (final item in rawTags) {
          if (item is String) {
            var s = item.trim();
            if (s.startsWith('#')) s = s.substring(1);
            if (s.isNotEmpty) fmTags.add(s);
          }
        }
      } else if (rawTags is String) {
        final parts = rawTags.split(RegExp(r'[\s,]+'));
        for (final part in parts) {
          var s = part.trim();
          if (s.startsWith('#')) s = s.substring(1);
          if (s.isNotEmpty) fmTags.add(s);
        }
      }

      final tagSet = <String>{};
      for (final t in inlineTags) {
        tagSet.add(t);
      }
      for (final t in fmTags) {
        tagSet.add(t);
      }
      tags = List<String>.unmodifiable(tagSet);

      final fmAliases = <String>[];
      final rawAliases = frontmatter['aliases'] ?? frontmatter['alias'];
      if (rawAliases is List) {
        for (final item in rawAliases) {
          if (item is String) {
            final s = item.trim();
            if (s.isNotEmpty) fmAliases.add(s);
          }
        }
      } else if (rawAliases is String) {
        final parts = rawAliases.split(',');
        for (final part in parts) {
          final s = part.trim();
          if (s.isNotEmpty) fmAliases.add(s);
        }
      }
      aliases = List<String>.unmodifiable(fmAliases);

      blockIds = List<BlockRef>.unmodifiable(blockResult.blockIds);
    } else {
      tags = const <String>[];
      aliases = const <String>[];
      blockIds = const <BlockRef>[];
    }

    return ParsedNote(
      text: text,
      root: blockResult.root,
      frontmatter: frontmatter,
      frontmatterValid: frontmatterValid,
      headings: List<MdHeading>.unmodifiable(headings),
      wikiLinks: List<MdWikiLink>.unmodifiable(wikiLinks),
      links: List<MdLink>.unmodifiable(links),
      tags: tags,
      aliases: aliases,
      blockIds: blockIds,
      tasks: List<TaskItem>.unmodifiable(tasks),
      linkDefinitions: Map<String, LinkDefinition>.unmodifiable(
        blockResult.definitions,
      ),
      lines: lines,
    );
  }

  /// Parses an inline snippet into inline AST nodes (used e.g. for callout titles).
  static List<MdNode> parseInline(String text) {
    final map = OffsetMap()..addSegment(0, text.length);
    return parseInlines(
      InlineSource(text: text, map: map),
      InlineContext(options: const ParserOptions(), definitions: const {}),
    );
  }
}
