// © 2026 Tephra. All rights reserved.

/// Result of querying changes from a [SyncProvider] since a given cursor.
final class RemoteChanges {
  /// Creates a [RemoteChanges] instance.
  const RemoteChanges({
    required this.changedKeys,
    required this.removedKeys,
    required this.cursor,
    this.cursorWasReset = false,
  });

  /// Decodes [RemoteChanges] from a JSON map.
  factory RemoteChanges.fromJson(Map<String, Object?> json) {
    return RemoteChanges(
      changedKeys: (json['changedKeys']! as List<Object?>).cast<String>(),
      removedKeys: (json['removedKeys']! as List<Object?>).cast<String>(),
      cursor: json['cursor']! as String,
      cursorWasReset: json['cursorWasReset'] as bool? ?? false,
    );
  }

  /// Keys created or updated since the requested cursor.
  final List<String> changedKeys;

  /// Keys deleted since the requested cursor.
  final List<String> removedKeys;

  /// Opaque token representing the current remote state, to be passed to future calls.
  final String cursor;

  /// True if the previous cursor was expired, unknown, or reset, requiring a full listing.
  final bool cursorWasReset;

  /// Encodes this change set to a JSON-compatible map.
  Map<String, Object?> toJson() => {
    'changedKeys': changedKeys,
    'removedKeys': removedKeys,
    'cursor': cursor,
    'cursorWasReset': cursorWasReset,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteChanges &&
          runtimeType == other.runtimeType &&
          cursor == other.cursor &&
          cursorWasReset == other.cursorWasReset &&
          _listEquals(changedKeys, other.changedKeys) &&
          _listEquals(removedKeys, other.removedKeys);

  @override
  int get hashCode => Object.hash(
    cursor,
    cursorWasReset,
    Object.hashAll(changedKeys),
    Object.hashAll(removedKeys),
  );

  @override
  String toString() =>
      'RemoteChanges(changed: ${changedKeys.length}, removed: ${removedKeys.length}, cursor: $cursor, reset: $cursorWasReset)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
