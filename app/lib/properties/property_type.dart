// © 2026 Tephra. All rights reserved.

/// Supported frontmatter property types.
enum PropertyType {
  text,
  multitext,
  number,
  checkbox,
  date,
  datetime,
  aliases,
  tags;

  /// Lower-case identifier matching Obsidian's `types.json`.
  String get jsonName => name;

  /// Parses a [PropertyType] from its JSON name.
  static PropertyType? fromJson(String value) {
    for (final t in PropertyType.values) {
      if (t.name == value) return t;
    }
    return null;
  }
}
