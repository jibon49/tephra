// © 2026 Tephra. All rights reserved.

import 'dart:isolate';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../compile/sql_compiler.dart';
import '../parser/search_expr.dart';
import '../verify/verify_batch.dart';
import 'cancel_token.dart';
import 'search_result.dart';
import 'search_sort.dart';

/// Full-text and structured search engine executing queries against the vault index
/// and verifying candidate matches against note text.
final class SearchEngine {
  SearchEngine(this.index, this.fs);

  final NoteIndex index;
  final VaultFileSystem fs;

  /// Runs [expr] against the vault index and note files, streaming verified [SearchResult]s.
  Stream<SearchResult> run(
    SearchExpr expr, {
    CancelToken? cancel,
    SearchSort sort = SearchSort.fileNameAsc,
    bool matchCase = false,
  }) async* {
    if (expr is EmptyExpr) {
      return;
    }

    final compiled = SqlCompiler.compile(expr, caseSensitive: matchCase);
    final order = _sortClause(sort);
    final finalSql =
        'SELECT f.path, f.mtime, f.created FROM notes n JOIN files f ON f.path = n.path '
        'WHERE n.id IN (${compiled.sql}) ORDER BY $order';

    final rows = await index.rawSelect(finalSql, compiled.args);

    var idx = 0;
    while (idx < rows.length) {
      if (cancel?.isCancelled ?? false) break;

      final batchSize = idx == 0 ? 20 : 100;
      final end = (idx + batchSize < rows.length)
          ? idx + batchSize
          : rows.length;
      final batchRows = rows.sublist(idx, end);
      idx = end;

      final notes = <(VaultPath, String)>[];
      for (final r in batchRows) {
        if (cancel?.isCancelled ?? false) break;
        final pathStr = r['path'] as String;
        final vp = VaultPath(pathStr);
        try {
          final doc = await fs.readText(vp);
          notes.add((vp, doc.text));
        } on FileNotFoundException {
          // Skip if missing.
        } catch (_) {
          // Skip if unreadable.
        }
      }

      if (cancel?.isCancelled ?? false) break;
      if (notes.isEmpty) continue;

      final batchInput = VerifyBatchInput(
        expr: expr,
        caseSensitive: matchCase,
        notes: notes,
      );

      final out = await Isolate.run(() => verifyBatch(batchInput));

      for (final res in out) {
        if (cancel?.isCancelled ?? false) break;
        if (res != null) {
          yield res;
        }
      }
    }
  }

  String _sortClause(SearchSort sort) {
    switch (sort) {
      case SearchSort.fileNameAsc:
        return 'f.name_key ASC, f.path ASC';
      case SearchSort.fileNameDesc:
        return 'f.name_key DESC, f.path DESC';
      case SearchSort.modifiedDesc:
        return 'f.mtime DESC, f.path ASC';
      case SearchSort.modifiedAsc:
        return 'f.mtime ASC, f.path ASC';
      case SearchSort.createdDesc:
        return 'COALESCE(f.created, f.mtime) DESC, f.path ASC';
      case SearchSort.createdAsc:
        return 'COALESCE(f.created, f.mtime) ASC, f.path ASC';
    }
  }
}
