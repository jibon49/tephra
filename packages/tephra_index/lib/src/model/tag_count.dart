// © 2026 Tephra. All rights reserved.

/// Count of notes possessing a tag.
final class TagCount {
  const TagCount({
    required this.tag,
    required this.tagLower,
    required this.count,
    required this.directCount,
  });

  /// Display form of the tag with original casing.
  final String tag;

  /// Lower-case form of the tag for normalized comparison.
  final String tagLower;

  /// Distinct notes having this tag or any of its descendant sub-tags.
  final int count;

  /// Distinct notes having exactly this tag directly.
  final int directCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagCount &&
          tag == other.tag &&
          tagLower == other.tagLower &&
          count == other.count &&
          directCount == other.directCount;

  @override
  int get hashCode => Object.hash(tag, tagLower, count, directCount);

  @override
  String toString() =>
      'TagCount(tag: $tag, count: $count, direct: $directCount)';
}
