// © 2026 Tephra. All rights reserved.

import 'quota.dart';
import 'remote_changes.dart';
import 'remote_object.dart';

/// Validates that [key] conforms to remote storage naming rules:
/// 1-512 characters from `[A-Za-z0-9._/-]`, no leading/trailing `/`,
/// no `//`, and no `.` or `..` path segments.
///
/// Throws [ArgumentError] if the key is invalid.
void validateRemoteKey(String key) {
  if (key.isEmpty) {
    throw ArgumentError.value(key, 'key', 'Remote key cannot be empty');
  }
  if (key.length > 512) {
    throw ArgumentError.value(
      key,
      'key',
      'Remote key cannot exceed 512 characters',
    );
  }
  if (key.startsWith('/') || key.endsWith('/')) {
    throw ArgumentError.value(
      key,
      'key',
      'Remote key cannot have leading or trailing slash: $key',
    );
  }
  if (key.contains('//')) {
    throw ArgumentError.value(
      key,
      'key',
      'Remote key cannot contain consecutive slashes: $key',
    );
  }
  final validChars = RegExp(r'^[A-Za-z0-9._/-]+$');
  if (!validChars.hasMatch(key)) {
    throw ArgumentError.value(
      key,
      'key',
      'Remote key contains invalid characters: $key',
    );
  }
  final segments = key.split('/');
  for (final seg in segments) {
    if (seg == '.' || seg == '..') {
      throw ArgumentError.value(
        key,
        'key',
        'Remote key cannot contain "." or ".." segments: $key',
      );
    }
  }
}

/// Abstract contract for remote vault storage backends (Google Drive, Tephra Cloud, in-memory).
///
/// Follows conventions §7.6:
/// - All keys are opaque forward-slash-delimited paths (e.g. `blobs/<hash>`, `journals/<dev>/<seq>.json.enc`).
/// - All keys are validated against [validateRemoteKey].
/// - [connect] is idempotent and verifies credentials / remote setup.
/// - [list] returns all objects matching the prefix string, sorted ascending by key.
/// - [get] returns object bytes or throws `RemoteNotFoundException`.
/// - [put] creates or replaces an object with the specified bytes.
/// - [delete] removes an object; deleting a non-existent key is a no-op.
/// - [changesSince] returns changes and a new cursor since the given cursor.
/// - [quota] returns capacity and usage metrics, or null if unsupported.
abstract interface class SyncProvider {
  /// Unique provider identifier (e.g. 'gdrive', 'tephra-cloud', 'memory').
  String get id;

  /// Authenticates and initializes the remote provider session.
  ///
  /// Idempotent. Throws `AuthRevokedException` or `NetworkUnavailableException`.
  Future<void> connect();

  /// Lists all remote objects whose key starts with [prefix], sorted ascending by key.
  ///
  /// Passing an empty string `list('')` returns all remote objects.
  /// Returns an empty list if no keys match the prefix.
  Future<List<RemoteObject>> list(String prefix);

  /// Downloads full bytes for the object at [key].
  ///
  /// Throws `RemoteNotFoundException` if the key does not exist.
  Future<List<int>> get(String key);

  /// Uploads or replaces the object at [key] with [bytes].
  ///
  /// Validates [key] using [validateRemoteKey].
  Future<void> put(String key, List<int> bytes);

  /// Deletes the object at [key].
  ///
  /// Deleting a missing key completes normally without error.
  Future<void> delete(String key);

  /// Queries changed and removed keys since the given [cursor].
  ///
  /// If [cursor] is null, returns no keys and a fresh cursor representing current state.
  /// If [cursor] is unknown or expired, [RemoteChanges.cursorWasReset] will be true.
  Future<RemoteChanges> changesSince(String? cursor);

  /// Returns storage usage and quota information, or null if unavailable.
  Future<Quota?> quota();
}
