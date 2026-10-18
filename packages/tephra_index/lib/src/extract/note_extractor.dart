// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../links/heading_matcher.dart';
import '../model/link_record.dart';
import 'extracted_note.dart';
import 'link_target_key.dart';
import 'property_typing.dart';
import 'word_counter.dart';

/// Pure deterministic extractor turning a [ParsedNote] into indexed entities.
abstract final class NoteExtractor {
  static ExtractedNote extract(VaultPath path, ParsedNote parsed) {
    final title = path.stem;
    final ftsName = path.stem;
    final ftsBody = parsed.text;

    // 1. Frontmatter JSON and valid flag
    final bool frontmatterValid = parsed.frontmatterValid;
    final String frontmatterJson;
    if (!frontmatterValid || parsed.frontmatter.isEmpty) {
      frontmatterJson = '{}';
    } else {
      frontmatterJson = jsonEncode(
        parsed.frontmatter,
        toEncodable: (e) => e.toString(),
      );
    }

    // 2. Word count (excluding frontmatter)
    var contentStart = 0;
    if (parsed.root.children.isNotEmpty &&
        parsed.root.children.first is MdFrontmatter) {
      contentStart = parsed.root.children.first.end;
    }
    final wordCount = countWords(parsed.text, contentStart);

    // 3. Aliases
    final aliases = <String>[];
    final seenAliasKeys = <String>{};
    if (frontmatterValid) {
      for (final a in parsed.aliases) {
        final trimmed = a.trim();
        if (trimmed.isEmpty) continue;
        if (seenAliasKeys.add(trimmed.toLowerCase())) {
          aliases.add(trimmed);
        }
      }
    }

    // 4. Headings
    final headings = <ExtractedHeading>[];
    for (var i = 0; i < parsed.headings.length; i++) {
      final h = parsed.headings[i];
      final headingText = _extractHeadingText(h);
      final key = normalizeHeading(headingText);
      final line = parsed.lines.lineOf(h.start);
      headings.add(
        ExtractedHeading(
          level: h.level,
          text: headingText,
          key: key,
          start: h.start,
          end: h.end,
          line: line,
          ordinal: i,
        ),
      );
    }

    // 5. Blocks
    final blocks = <ExtractedBlock>[];
    final seenBlockKeys = <String>{};
    for (final ref in parsed.blockIds) {
      final key = ref.id.toLowerCase();
      if (!seenBlockKeys.add(key)) continue;

      final owner = _findBlockOwner(ref, parsed);
      final ownerStart = owner.start;
      final ownerEnd = owner.end;
      final ownerLine = parsed.lines.lineOf(ownerStart);
      final ownerRaw = parsed.text.substring(ownerStart, ownerEnd);

      var preview = ownerRaw.replaceAll(
        RegExp(r'\^' + RegExp.escape(ref.id)),
        '',
      );
      preview = preview.replaceAll(RegExp(r'[\r\n]+'), ' ');
      preview = preview.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (preview.length > 120) {
        preview = preview.substring(0, 120);
      }

      blocks.add(
        ExtractedBlock(
          id: ref.id,
          start: ownerStart,
          end: ownerEnd,
          line: ownerLine,
          preview: preview,
        ),
      );
    }

    // 6. Links (walk whole AST in document order)
    final links = extractLinks(path, parsed);

    // 7. Tags (inline from AST + frontmatter tags)
    final tags = <ExtractedTag>[];
    _extractInlineTags(parsed.root, parsed, tags);
    if (frontmatterValid) {
      if (parsed.frontmatter.containsKey('tags')) {
        for (final t in extractTagStrings(parsed.frontmatter['tags'])) {
          tags.add(ExtractedTag(tag: t, start: null, line: null));
        }
      }
      if (parsed.frontmatter.containsKey('tag')) {
        for (final t in extractTagStrings(parsed.frontmatter['tag'])) {
          tags.add(ExtractedTag(tag: t, start: null, line: null));
        }
      }
    }

    // 8. Properties
    final properties = <ExtractedProperty>[];
    if (frontmatterValid) {
      for (final entry in parsed.frontmatter.entries) {
        properties.addAll(inferPropertyRows(entry.key, entry.value));
      }
    }

    // 9. Tasks
    final tasks = <ExtractedTask>[];
    final dueRegex = RegExp(r'📅\s*(\d{4}-\d{2}-\d{2})');
    for (final task in parsed.tasks) {
      final line = parsed.lines.lineOf(task.start);
      final dueMatch = dueRegex.firstMatch(task.text);
      tasks.add(
        ExtractedTask(
          line: line,
          statusChar: task.status.char,
          text: task.text.trim(),
          start: task.start,
          end: task.end,
          due: dueMatch?.group(1),
        ),
      );
    }

    return ExtractedNote(
      title: title,
      frontmatterJson: frontmatterJson,
      frontmatterValid: frontmatterValid,
      wordCount: wordCount,
      aliases: aliases,
      headings: headings,
      blocks: blocks,
      links: links,
      tags: tags,
      properties: properties,
      tasks: tasks,
      ftsName: ftsName,
      ftsBody: ftsBody,
    );
  }

  /// Extracts links from [parsed] in document order.
  static List<ExtractedLink> extractLinks(VaultPath path, ParsedNote parsed) {
    final links = <ExtractedLink>[];
    _extractLinks(parsed.root, parsed, links);
    return links;
  }

  static String _extractHeadingText(MdHeading h) {
    final buffer = StringBuffer();
    for (final child in h.children) {
      if (child is MdBlockId) continue;
      buffer.write(_visibleText(child));
    }
    return buffer.toString().trim();
  }

  static String _visibleText(MdNode node) {
    if (node is MdBlockId) return '';
    if (node is MdText) return node.text;
    if (node is MdInlineCode) return node.code;
    if (node is MdInlineMath) return node.tex;
    if (node is MdWikiLink) return node.alias ?? node.target;
    if (node is MdLink) {
      return node.children.map(_visibleText).join();
    }
    if (node is MdTag) return '#${node.name}';
    return node.children.map(_visibleText).join();
  }

  static ({int start, int end}) _findBlockOwner(
    BlockRef ref,
    ParsedNote parsed,
  ) {
    // 1. Look for innermost paragraph, list item, or heading containing ref.start
    MdNode? innermost;
    void search(MdNode node) {
      if (node.start <= ref.start && node.end >= ref.end) {
        if (node is MdParagraph || node is MdListItem || node is MdHeading) {
          innermost = node;
        }
        for (final child in node.children) {
          search(child);
        }
      }
    }

    search(parsed.root);
    if (innermost != null) {
      return (start: innermost!.start, end: innermost!.end);
    }

    // 2. Standalone on its own line directly after table, block quote, callout, or code block
    final refLine = parsed.lines.lineOf(ref.start);
    for (final node in parsed.root.children) {
      if (node is MdTable ||
          node is MdBlockQuote ||
          node is MdCallout ||
          node is MdCodeBlock) {
        final nodeEndLine = parsed.lines.lineOf(node.end);
        if (nodeEndLine == refLine - 1 || nodeEndLine == refLine) {
          return (start: node.start, end: node.end);
        }
      }
    }

    // 3. Fallback: line containing ^id
    final lineStart = parsed.lines.lineStart(refLine);
    final lineEnd = parsed.lines.lineEnd(refLine);
    return (start: lineStart, end: lineEnd);
  }

  static void _extractLinks(
    MdNode node,
    ParsedNote parsed,
    List<ExtractedLink> out,
  ) {
    if (node is MdWikiLink) {
      final targetRaw = node.target.trim();
      final sizeStr = node.size != null
          ? (node.size!.height == null
                ? '${node.size!.width}'
                : '${node.size!.width}x${node.size!.height}')
          : null;
      out.add(
        ExtractedLink(
          targetRaw: targetRaw,
          targetKey: linkTargetKey(targetRaw),
          kind: node.embed ? LinkKind.embed : LinkKind.link,
          syntax: LinkSyntax.wiki,
          heading: node.heading,
          blockRef: node.blockRef,
          alias: node.alias,
          embedSize: sizeStr,
          start: node.start,
          end: node.end,
          line: parsed.lines.lineOf(node.start),
        ),
      );
    } else if (node is MdLink) {
      final url = node.url.trim();
      final isScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url);
      final isNetwork = url.startsWith('//');
      if (!isScheme && !isNetwork) {
        final hashIndex = url.indexOf('#');
        String rawPath;
        String? fragment;
        if (hashIndex != -1) {
          rawPath = url.substring(0, hashIndex);
          fragment = url.substring(hashIndex + 1);
        } else {
          rawPath = url;
          fragment = null;
        }

        String targetRaw;
        try {
          targetRaw = Uri.decodeComponent(rawPath);
        } catch (_) {
          targetRaw = rawPath;
        }

        String? heading;
        String? blockRef;
        if (fragment != null && fragment.isNotEmpty) {
          if (fragment.startsWith('^')) {
            blockRef = fragment.substring(1);
          } else {
            try {
              heading = Uri.decodeComponent(fragment);
            } catch (_) {
              heading = fragment;
            }
          }
        }

        final aliasText = node.children.map(_visibleText).join();
        out.add(
          ExtractedLink(
            targetRaw: targetRaw,
            targetKey: linkTargetKey(targetRaw),
            kind: node.image ? LinkKind.embed : LinkKind.link,
            syntax: LinkSyntax.markdown,
            heading: heading,
            blockRef: blockRef,
            alias: aliasText.isEmpty ? null : aliasText,
            embedSize: null,
            start: node.start,
            end: node.end,
            line: parsed.lines.lineOf(node.start),
          ),
        );
      }
    }

    for (final child in node.children) {
      _extractLinks(child, parsed, out);
    }
  }

  static void _extractInlineTags(
    MdNode node,
    ParsedNote parsed,
    List<ExtractedTag> out,
  ) {
    if (node is MdTag) {
      out.add(
        ExtractedTag(
          tag: node.name,
          start: node.start,
          line: parsed.lines.lineOf(node.start),
        ),
      );
    }
    for (final child in node.children) {
      _extractInlineTags(child, parsed, out);
    }
  }
}
