// © 2026 Tephra. All rights reserved.

/// Metadata of an immutable or mutable object stored in a [SyncProvider].
final class RemoteObject {
  /// Creates a [RemoteObject].
  const RemoteObject({
    required this.key,
    required this.size,
    required this.modified,
    this.created,
  });

  /// Decodes a [RemoteObject] from JSON map.
  factory RemoteObject.fromJson(Map<String, Object?> json) {
    return RemoteObject(
      key: json['key']! as String,
      size: (json['size']! as num).toInt(),
      modified: DateTime.parse(json['modified']! as String).toUtc(),
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created']! as String).toUtc(),
    );
  }

  /// Opaque remote key (e.g. 'blobs/9f86d0...').
  final String key;

  /// Object payload size in bytes.
  final int size;

  /// Last modification timestamp in UTC (server time).
  final DateTime modified;

  /// Creation timestamp in UTC (server time), if recorded by provider.
  final DateTime? created;

  /// Encodes this object to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'key': key,
    'size': size,
    'modified': modified.toIso8601String(),
    if (created != null) 'created': created!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteObject &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          size == other.size &&
          modified == other.modified &&
          created == other.created;

  @override
  int get hashCode => Object.hash(key, size, modified, created);

  @override
  String toString() =>
      'RemoteObject(key: $key, size: $size, modified: $modified, created: $created)';
}
