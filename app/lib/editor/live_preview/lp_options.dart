// © 2026 Tephra. All rights reserved.

/// Options for Live Preview decoration generation.
final class LpOptions {
  const LpOptions({this.hideFrontmatter = false});

  final bool hideFrontmatter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LpOptions && hideFrontmatter == other.hideFrontmatter;

  @override
  int get hashCode => hideFrontmatter.hashCode;

  @override
  String toString() => 'LpOptions(hideFrontmatter: $hideFrontmatter)';
}
