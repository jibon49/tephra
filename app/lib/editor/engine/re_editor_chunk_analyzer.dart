// © 2026 Tephra. All rights reserved.

import 'package:re_editor/re_editor.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../folding/fold_regions.dart';

/// Analyzer that creates [CodeChunk]s from Markdown headings and list items.
final class MarkdownChunkAnalyzer implements CodeChunkAnalyzer {
  const MarkdownChunkAnalyzer({
    this.foldHeadings = true,
    this.foldIndent = true,
  });

  final bool foldHeadings;
  final bool foldIndent;

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final text = codeLines.asString(TextLineBreak.lf, true);
    if (text.isEmpty) return const [];

    final parsed = MarkdownParser.parse(text);
    final regions = computeFoldRegions(
      text,
      parsed,
      headings: foldHeadings,
      lists: foldIndent,
    );

    final chunks = <CodeChunk>[];
    for (final r in regions) {
      final headerLine = parsed.lines.lineOf(r.headerStart);
      final lastHiddenLine = parsed.lines.lineOf(r.to);
      if (lastHiddenLine > headerLine) {
        chunks.add(CodeChunk(headerLine, lastHiddenLine + 1));
      }
    }

    chunks.sort((a, b) => a.index.compareTo(b.index));
    return chunks;
  }
}
