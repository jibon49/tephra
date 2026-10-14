// © 2026 Tephra. All rights reserved.

/// Escapes [s] for safe use as a phrase/token in SQLite FTS5 queries.
String ftsPhrase(String s) => '"${s.replaceAll('"', '""')}"';
