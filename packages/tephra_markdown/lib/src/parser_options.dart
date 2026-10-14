// © 2026 Tephra. All rights reserved.

/// Configuration toggles for the Markdown parser extensions.
final class ParserOptions {
  const ParserOptions({this.obsidian = true, this.gfm = true});

  /// Standard strict CommonMark 0.31.2 configuration without extensions.
  static const ParserOptions commonMark = ParserOptions(
    obsidian: false,
    gfm: false,
  );

  /// Standard GitHub Flavored Markdown (GFM) configuration.
  static const ParserOptions gfmOnly = ParserOptions(
    obsidian: false,
    gfm: true,
  );

  /// Full Obsidian Markdown configuration (GFM + Obsidian syntax).
  static const ParserOptions full = ParserOptions(obsidian: true, gfm: true);

  /// Enables Obsidian extensions: frontmatter, wikilinks/embeds, tags,
  /// highlight, comments, block IDs, callouts, math, footnotes, custom tasks.
  final bool obsidian;

  /// Enables GitHub Flavored Markdown: tables, strikethrough, task lists,
  /// extended autolinks.
  final bool gfm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParserOptions && obsidian == other.obsidian && gfm == other.gfm;

  @override
  int get hashCode => Object.hash(obsidian, gfm);

  @override
  String toString() => 'ParserOptions(obsidian: $obsidian, gfm: $gfm)';
}
