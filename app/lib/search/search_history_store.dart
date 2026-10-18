// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

final _logger = Logger('search.history');

/// Manages persisted search queries in `.tephra/cache/search-history.json`.
final class SearchHistoryStore {
  SearchHistoryStore(this.fs);

  final VaultFileSystem fs;
  static final VaultPath historyPath = VaultPath(
    '.tephra/cache/search-history.json',
  );

  /// Loads the history list. Returns an empty list if missing or corrupt.
  Future<List<String>> load() async {
    try {
      final doc = await fs.readText(historyPath);
      final json = jsonDecode(doc.text);
      if (json is Map<String, Object?> && json['queries'] is List) {
        final list = (json['queries'] as List)
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(20)
            .toList();
        return list;
      }
      _logger.warning('Invalid search history format, resetting.');
      return const [];
    } on FileNotFoundException {
      return const [];
    } catch (e, st) {
      _logger.warning('Failed to load search history', e, st);
      return const [];
    }
  }

  /// Adds [query] to the front of history, keeping max 20 entries.
  Future<List<String>> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final current = await load();
    final updated = <String>[trimmed];
    for (final q in current) {
      if (q != trimmed) {
        updated.add(q);
      }
    }
    final capped = updated.take(20).toList();

    try {
      final json = jsonEncode({'queries': capped});
      await fs.writeText(historyPath, TextDocument(text: json));
    } catch (e, st) {
      _logger.warning('Failed to save search history', e, st);
    }
    return capped;
  }

  /// Clears the history file.
  Future<void> clear() async {
    try {
      await fs.delete(historyPath, mode: TrashMode.permanent);
    } catch (e, st) {
      _logger.warning('Failed to clear search history', e, st);
    }
  }
}
