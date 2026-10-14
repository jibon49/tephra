// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

import 'model_helpers.dart';

/// Summary metadata for a note stored in the index.
final class NoteSummary {
  const NoteSummary({
    required this.path,
    required this.title,
    required this.size,
    required this.modified,
    this.created,
    required this.wordCount,
    required this.aliases,
    required this.tags,
  });

  final VaultPath path;
  final String title;
  final int size;
  final DateTime modified;
  final DateTime? created;
  final int wordCount;
  final List<String> aliases;
  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteSummary &&
          path == other.path &&
          title == other.title &&
          size == other.size &&
          modified == other.modified &&
          created == other.created &&
          wordCount == other.wordCount &&
          listEquals(aliases, other.aliases) &&
          listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(
    path,
    title,
    size,
    modified,
    created,
    wordCount,
    Object.hashAll(aliases),
    Object.hashAll(tags),
  );

  @override
  String toString() =>
      'NoteSummary(path: ${path.value}, title: $title, wordCount: $wordCount)';
}
