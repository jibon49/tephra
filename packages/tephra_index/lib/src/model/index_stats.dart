// © 2026 Tephra. All rights reserved.

/// High-level counts of indexed entities in the vault.
final class IndexStats {
  const IndexStats({
    required this.files,
    required this.notes,
    required this.links,
    required this.unresolvedLinks,
    required this.tags,
  });

  /// Total files indexed (notes and non-notes).
  final int files;

  /// Total Markdown notes indexed.
  final int notes;

  /// Total links extracted.
  final int links;

  /// Count of links whose targets could not be resolved.
  final int unresolvedLinks;

  /// Distinct tag count.
  final int tags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexStats &&
          files == other.files &&
          notes == other.notes &&
          links == other.links &&
          unresolvedLinks == other.unresolvedLinks &&
          tags == other.tags;

  @override
  int get hashCode => Object.hash(files, notes, links, unresolvedLinks, tags);

  @override
  String toString() =>
      'IndexStats(files: $files, notes: $notes, links: $links, unresolved: $unresolvedLinks, tags: $tags)';
}
