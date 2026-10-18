// © 2026 Tephra. All rights reserved.

/// Strategy for generating link paths.
enum NewLinkFormat {
  shortest,
  relative,
  absolute;

  /// Parses [s] into [NewLinkFormat], defaulting to [shortest] if unknown.
  static NewLinkFormat fromJson(String? s) {
    return switch (s?.toLowerCase()) {
      'relative' => NewLinkFormat.relative,
      'absolute' => NewLinkFormat.absolute,
      _ => NewLinkFormat.shortest,
    };
  }

  /// Serializes to string.
  String toJson() => name;
}

/// Settings controlling link generation.
final class LinkFormatSettings {
  const LinkFormatSettings({
    this.format = NewLinkFormat.shortest,
    this.useMarkdownLinks = false,
  });

  final NewLinkFormat format;
  final bool useMarkdownLinks;
}
