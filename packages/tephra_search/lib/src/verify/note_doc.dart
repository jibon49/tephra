// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

/// Precomputed structural and content document information for search evaluation.
final class NoteDoc {
  const NoteDoc({
    required this.path,
    required this.text,
    required this.parsed,
    required this.lines,
    required this.blockRanges,
    required this.sectionRanges,
    required this.tasks,
    required this.lowerTags,
    required this.frontmatter,
  });

  /// Factory that extracts all indices and structure from [parsed] note.
  factory NoteDoc.create({
    required VaultPath path,
    required String text,
    required ParsedNote parsed,
  }) {
    final lines = parsed.lines;

    // Block ranges: each top-level child of document except frontmatter
    final blockRanges = <(int start, int end)>[];
    for (final child in parsed.root.children) {
      if (child is! MdFrontmatter) {
        blockRanges.add((child.start, child.end));
      }
    }

    // Section ranges: body start to first heading, then heading to next heading
    final sectionRanges = <(int start, int end)>[];
    final fmNode = parsed.root.children.whereType<MdFrontmatter>().firstOrNull;
    final bodyStart = fmNode?.end ?? 0;
    if (parsed.headings.isEmpty) {
      if (bodyStart < text.length) {
        sectionRanges.add((bodyStart, text.length));
      } else {
        sectionRanges.add((0, text.length));
      }
    } else {
      if (parsed.headings.first.start > bodyStart) {
        sectionRanges.add((bodyStart, parsed.headings.first.start));
      }
      for (var i = 0; i < parsed.headings.length; i++) {
        final h = parsed.headings[i];
        final nextStart = i + 1 < parsed.headings.length
            ? parsed.headings[i + 1].start
            : text.length;
        sectionRanges.add((h.start, nextStart));
      }
    }

    // Task items
    final tasks = <({int start, int end, String statusChar, String text})>[
      for (final t in parsed.tasks)
        (start: t.start, end: t.end, statusChar: t.status.char, text: t.text),
    ];

    // Tags: parsed.tags contains both inline and frontmatter tags
    final lowerTags = <String>{};
    for (final tag in parsed.tags) {
      var s = tag.trim();
      if (s.startsWith('#')) s = s.substring(1);
      if (s.isNotEmpty) lowerTags.add(s.toLowerCase());
    }

    return NoteDoc(
      path: path,
      text: text,
      parsed: parsed,
      lines: lines,
      blockRanges: blockRanges,
      sectionRanges: sectionRanges,
      tasks: tasks,
      lowerTags: lowerTags,
      frontmatter: parsed.frontmatter,
    );
  }

  final VaultPath path;
  final String text;
  final ParsedNote parsed;
  final LineIndex lines;
  final List<(int start, int end)> blockRanges;
  final List<(int start, int end)> sectionRanges;
  final List<({int start, int end, String statusChar, String text})> tasks;
  final Set<String> lowerTags;
  final Map<String, Object?> frontmatter;
}
