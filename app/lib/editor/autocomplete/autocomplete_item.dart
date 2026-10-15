// © 2026 Tephra. All rights reserved.

/// Kind of autocomplete item.
enum AcKind {
  note,
  alias,
  attachment,
  heading,
  block,
  tag,
  propertyKey,
  propertyValue,
  slash,
  template,
}

/// A single candidate item in the autocomplete popup.
final class AcItem {
  const AcItem({
    required this.kind,
    required this.primary,
    this.secondary,
    required this.score,
    this.matchRanges = const [],
    this.payload,
  });

  final AcKind kind;
  final String primary;
  final String? secondary;
  final int score;
  final List<(int, int)> matchRanges;
  final Object? payload;

  @override
  String toString() =>
      'AcItem($kind, "$primary", sec: $secondary, score: $score)';
}
