// © 2026 Tephra. All rights reserved.

import '../parser/search_expr.dart';
import 'compiled_query.dart';
import 'fts_escape.dart';

/// Compiles a [SearchExpr] into an optimized SQL candidate query for SQLite.
final class SqlCompiler {
  const SqlCompiler._();

  static const String _allSql = 'SELECT id FROM notes';

  /// Compiles [expr] into a [CompiledQuery].
  static CompiledQuery compile(SearchExpr expr, {required bool caseSensitive}) {
    return _compile(
      expr,
      caseSensitive: caseSensitive,
      fileScope: true,
      depth: 0,
    );
  }

  static CompiledQuery _compile(
    SearchExpr expr, {
    required bool caseSensitive,
    required bool fileScope,
    required int depth,
  }) {
    if (depth > 40) {
      return const CompiledQuery(sql: _allSql, args: [], exact: false);
    }

    switch (expr) {
      case EmptyExpr():
        return const CompiledQuery(sql: _allSql, args: [], exact: true);

      case TermExpr(:final text):
      case PhraseExpr(:final text):
        if (text.isEmpty) {
          return const CompiledQuery(sql: _allSql, args: [], exact: true);
        }
        if (text.runes.length >= 3) {
          return CompiledQuery(
            sql:
                'SELECT rowid AS id FROM fts_trigram WHERE fts_trigram MATCH ?',
            args: [ftsPhrase(text)],
            exact: !caseSensitive && fileScope,
          );
        } else {
          return const CompiledQuery(sql: _allSql, args: [], exact: false);
        }

      case RegexExpr():
        return const CompiledQuery(sql: _allSql, args: [], exact: false);

      case NotExpr(:final child):
        final inner = _compile(
          child,
          caseSensitive: caseSensitive,
          fileScope: fileScope,
          depth: depth + 1,
        );
        if (inner.exact && fileScope) {
          return CompiledQuery(
            sql: 'SELECT id FROM notes EXCEPT SELECT id FROM (${inner.sql})',
            args: inner.args,
            exact: true,
          );
        } else {
          return const CompiledQuery(sql: _allSql, args: [], exact: false);
        }

      case OperatorExpr(:final op, :final value):
        return _compileOperator(
          op,
          value,
          caseSensitive: caseSensitive,
          fileScope: fileScope,
          depth: depth,
        );

      case PropertyExpr(:final name, :final value):
        return _compileProperty(name, value, caseSensitive: caseSensitive);

      case AndExpr(:final children):
        final compiled = children
            .map(
              (c) => _compile(
                c,
                caseSensitive: caseSensitive,
                fileScope: fileScope,
                depth: depth + 1,
              ),
            )
            .toList();

        final nonAll = compiled
            .where((q) => q.sql != _allSql || q.args.isNotEmpty)
            .toList();

        if (nonAll.isEmpty) {
          return CompiledQuery(
            sql: _allSql,
            args: const [],
            exact: compiled.every((c) => c.exact),
          );
        }

        if (nonAll.length == 1) {
          return CompiledQuery(
            sql: nonAll.first.sql,
            args: nonAll.first.args,
            exact: compiled.every((c) => c.exact),
          );
        }

        final sql = nonAll
            .map((q) => 'SELECT id FROM (${q.sql})')
            .join(' INTERSECT ');
        final args = <Object?>[for (final q in nonAll) ...q.args];
        return CompiledQuery(
          sql: sql,
          args: args,
          exact: compiled.every((c) => c.exact),
        );

      case OrExpr(:final children):
        final compiled = children
            .map(
              (c) => _compile(
                c,
                caseSensitive: caseSensitive,
                fileScope: fileScope,
                depth: depth + 1,
              ),
            )
            .toList();

        final anyAll = compiled.any((q) => q.sql == _allSql && q.args.isEmpty);
        if (anyAll) {
          return const CompiledQuery(sql: _allSql, args: [], exact: false);
        }

        if (compiled.length == 1) {
          return compiled.first;
        }

        final sql = compiled
            .map((q) => 'SELECT id FROM (${q.sql})')
            .join(' UNION ');
        final args = <Object?>[for (final q in compiled) ...q.args];
        return CompiledQuery(
          sql: sql,
          args: args,
          exact: compiled.every((c) => c.exact),
        );
    }
  }

  static CompiledQuery _compileOperator(
    SearchOperator op,
    SearchExpr value, {
    required bool caseSensitive,
    required bool fileScope,
    required int depth,
  }) {
    switch (op) {
      case SearchOperator.content:
        if (value is TermExpr || value is PhraseExpr) {
          final text = value is TermExpr
              ? value.text
              : (value as PhraseExpr).text;
          if (text.isEmpty) {
            return const CompiledQuery(sql: _allSql, args: [], exact: true);
          }
          if (text.runes.length >= 3) {
            return CompiledQuery(
              sql: 'SELECT rowid AS id FROM fts_trigram WHERE fts_trigram MATCH ?',
              args: ['body : ${ftsPhrase(text)}'],
              exact: !caseSensitive && fileScope,
            );
          }
        }
        return const CompiledQuery(sql: _allSql, args: [], exact: false);

      case SearchOperator.file:
        if (value is TermExpr || value is PhraseExpr) {
          final text = value is TermExpr
              ? value.text
              : (value as PhraseExpr).text;
          return CompiledQuery(
            sql: 'SELECT n.id FROM notes n JOIN files f ON f.path = n.path WHERE instr(f.name_key, ?) > 0',
            args: [text.toLowerCase()],
            exact: !caseSensitive,
          );
        }
        return const CompiledQuery(sql: _allSql, args: [], exact: false);

      case SearchOperator.path:
        if (value is TermExpr || value is PhraseExpr) {
          final text = value is TermExpr
              ? value.text
              : (value as PhraseExpr).text;
          return CompiledQuery(
            sql: 'SELECT n.id FROM notes n JOIN files f ON f.path = n.path WHERE instr(f.case_key, ?) > 0',
            args: [text.toLowerCase()],
            exact: !caseSensitive,
          );
        }
        return const CompiledQuery(sql: _allSql, args: [], exact: false);

      case SearchOperator.tag:
        if (value is EmptyExpr) {
          return const CompiledQuery(
            sql: 'SELECT n.id FROM notes n JOIN tags t ON t.path = n.path',
            args: [],
            exact: true,
          );
        }
        if (value is TermExpr || value is PhraseExpr) {
          var text = value is TermExpr
              ? value.text
              : (value as PhraseExpr).text;
          if (text.startsWith('#')) {
            text = text.substring(1);
          }
          final x = text.toLowerCase();
          return CompiledQuery(
            sql: 'SELECT n.id FROM notes n JOIN tags t ON t.path = n.path WHERE t.tag_lower = ? OR substr(t.tag_lower, 1, ?) = ?',
            args: [x, x.runes.length + 1, '$x/'],
            exact: true,
          );
        }
        return const CompiledQuery(
          sql: 'SELECT n.id FROM notes n JOIN tags t ON t.path = n.path',
          args: [],
          exact: false,
        );

      case SearchOperator.task:
      case SearchOperator.taskTodo:
      case SearchOperator.taskDone:
        final statusFilter = op == SearchOperator.taskTodo
            ? " AND k.status_char = ' '"
            : op == SearchOperator.taskDone
            ? " AND k.status_char <> ' '"
            : '';

        if (value is EmptyExpr ||
            (value is TermExpr && value.text.isEmpty) ||
            (value is PhraseExpr && value.text.isEmpty)) {
          final where = statusFilter.isNotEmpty
              ? ' WHERE ${statusFilter.substring(5)}'
              : '';
          return CompiledQuery(
            sql:
                'SELECT n.id FROM notes n JOIN tasks k ON k.path = n.path$where',
            args: const [],
            exact: true,
          );
        }

        if (value is TermExpr || value is PhraseExpr) {
          final text = value is TermExpr
              ? value.text
              : (value as PhraseExpr).text;
          return CompiledQuery(
            sql:
                'SELECT n.id FROM notes n JOIN tasks k ON k.path = n.path WHERE instr(k.task_lower, ?) > 0$statusFilter',
            args: [text.toLowerCase()],
            exact: !caseSensitive,
          );
        }

        final where = statusFilter.isNotEmpty
            ? ' WHERE ${statusFilter.substring(5)}'
            : '';
        return CompiledQuery(
          sql: 'SELECT n.id FROM notes n JOIN tasks k ON k.path = n.path$where',
          args: const [],
          exact: false,
        );

      case SearchOperator.line:
      case SearchOperator.block:
      case SearchOperator.section:
        final inner = _compile(
          value,
          caseSensitive: caseSensitive,
          fileScope: false,
          depth: depth + 1,
        );
        return CompiledQuery(sql: inner.sql, args: inner.args, exact: false);

      case SearchOperator.matchCase:
        return _compile(
          value,
          caseSensitive: true,
          fileScope: fileScope,
          depth: depth + 1,
        );

      case SearchOperator.ignoreCase:
        return _compile(
          value,
          caseSensitive: false,
          fileScope: fileScope,
          depth: depth + 1,
        );
    }
  }

  static CompiledQuery _compileProperty(
    String name,
    PropertyValue value, {
    required bool caseSensitive,
  }) {
    final keyLower = name.toLowerCase();

    switch (value) {
      case PropertyExists():
        return CompiledQuery(
          sql: 'SELECT n.id FROM notes n JOIN properties p ON p.path = n.path WHERE p.key_lower = ?',
          args: [keyLower],
          exact: true,
        );

      case PropertyIsEmpty():
        return CompiledQuery(
          sql: 'SELECT n.id FROM notes n JOIN properties p ON p.path = n.path WHERE p.key_lower = ? AND (p.value_text IS NULL OR p.value_text = \'\')',
          args: [keyLower],
          exact: true,
        );

      case PropertyMatches(:final expr):
        if (expr is TermExpr || expr is PhraseExpr) {
          final text = expr is TermExpr ? expr.text : (expr as PhraseExpr).text;
          return CompiledQuery(
            sql: 'SELECT n.id FROM notes n JOIN properties p ON p.path = n.path WHERE p.key_lower = ? AND instr(p.value_lower, ?) > 0',
            args: [keyLower, text.toLowerCase()],
            exact: !caseSensitive,
          );
        }
        return CompiledQuery(
          sql: 'SELECT n.id FROM notes n JOIN properties p ON p.path = n.path WHERE p.key_lower = ?',
          args: [keyLower],
          exact: false,
        );
    }
  }
}
