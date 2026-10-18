// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../engine/search_result.dart';
import '../parser/search_expr.dart';
import 'note_doc.dart';
import 'search_matcher.dart';

/// Input bundle for a batch of candidate notes to verify.
final class VerifyBatchInput {
  const VerifyBatchInput({
    required this.expr,
    required this.caseSensitive,
    required this.notes,
  });

  final SearchExpr expr;
  final bool caseSensitive;
  final List<(VaultPath path, String text)> notes;
}

/// Verifies a batch of candidate notes against [input.expr].
/// Returns null for non-matching notes.
List<SearchResult?> verifyBatch(VerifyBatchInput input) {
  final results = <SearchResult?>[];
  for (final item in input.notes) {
    final path = item.$1;
    final text = item.$2;
    final parsed = MarkdownParser.parse(text);
    final doc = NoteDoc.create(path: path, text: text, parsed: parsed);
    final outcome = evaluate(
      input.expr,
      doc,
      caseSensitive: input.caseSensitive,
    );
    if (outcome.matched) {
      results.add(SearchResult(path, outcome.matches));
    } else {
      results.add(null);
    }
  }
  return results;
}
