// © 2026 Tephra. All rights reserved.

/// Result of compiling a search expression into SQL candidate query.
final class CompiledQuery {
  const CompiledQuery({
    required this.sql,
    this.args = const [],
    required this.exact,
  });

  /// SQL subquery returning one column `id` (= notes.id).
  final String sql;

  /// Positional arguments for parameter substitution.
  final List<Object?> args;

  /// True if the set of notes is exactly the matching set for negation purposes;
  /// false if it is a superset that requires verification.
  final bool exact;
}
