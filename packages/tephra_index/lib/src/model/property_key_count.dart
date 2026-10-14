// © 2026 Tephra. All rights reserved.

/// Distinct property key with inferred value type and occurrence count.
final class PropertyKeyCount {
  const PropertyKeyCount({
    required this.key,
    required this.valueType,
    required this.count,
  });

  final String key;
  final String valueType;
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyKeyCount &&
          key == other.key &&
          valueType == other.valueType &&
          count == other.count;

  @override
  int get hashCode => Object.hash(key, valueType, count);

  @override
  String toString() =>
      'PropertyKeyCount(key: $key, type: $valueType, count: $count)';
}
