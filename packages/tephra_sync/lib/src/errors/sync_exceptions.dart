// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Thrown when authentication is revoked, invalid_grant occurs, or HTTP 401 persists.
class AuthRevokedException extends SyncException {
  /// Creates an [AuthRevokedException] with a technical description.
  const AuthRevokedException([
    super.message = 'Authentication revoked or token invalid',
  ]);
}

/// Thrown when network connection is unavailable or timeout occurs after retries.
class NetworkUnavailableException extends SyncException {
  /// Creates a [NetworkUnavailableException] with a technical description.
  const NetworkUnavailableException([
    super.message = 'Network connection unavailable',
  ]);
}

/// Thrown when rate limiting (429 or 403 quota) occurs.
class RateLimitedException extends SyncException {
  /// Creates a [RateLimitedException] with an optional [retryAfter] duration.
  const RateLimitedException({
    this.retryAfter,
    String message = 'Remote rate limit exceeded',
  }) : super(message);

  /// Suggested duration to wait before retrying, if provided by the remote server.
  final Duration? retryAfter;

  @override
  String toString() => retryAfter == null
      ? 'RateLimitedException: $message'
      : 'RateLimitedException: $message (retry after ${retryAfter!.inSeconds}s)';
}

/// Thrown when remote server returns 5xx HTTP errors after retries.
class RemoteServerException extends SyncException {
  /// Creates a [RemoteServerException] with the HTTP [statusCode].
  const RemoteServerException(
    this.statusCode, [
    String message = 'Remote server error',
  ]) : super('$message (HTTP $statusCode)');

  /// HTTP status code returned by the server.
  final int statusCode;
}

/// Thrown when remote storage quota is exceeded.
class RemoteQuotaExceededException extends SyncException {
  /// Creates a [RemoteQuotaExceededException] with a technical description.
  const RemoteQuotaExceededException([
    super.message = 'Remote storage quota exceeded',
  ]);
}

/// Thrown when getting a remote key that does not exist.
class RemoteNotFoundException extends SyncException {
  /// Creates a [RemoteNotFoundException] for the missing [key].
  const RemoteNotFoundException(
    this.key, [
    String message = 'Remote key not found',
  ]) : super('$message: $key');

  /// The remote object key that was not found.
  final String key;
}

/// Thrown when remote JSON or vault header format is invalid or unsupported.
class RemoteFormatException extends SyncException {
  /// Creates a [RemoteFormatException] with a technical description.
  const RemoteFormatException([
    super.message = 'Invalid or unsupported remote format',
  ]);
}

/// Thrown when the remote vault folder or vault.json disappeared.
class RemoteVaultMissingException extends SyncException {
  /// Creates a [RemoteVaultMissingException] with a technical description.
  const RemoteVaultMissingException([
    super.message = 'Remote vault missing or removed',
  ]);
}

/// Thrown when another process holds the sync lock for this vault.
class SyncLockedException extends SyncException {
  /// Creates a [SyncLockedException] with a technical description.
  const SyncLockedException([
    super.message = 'Sync lock held by another process',
  ]);
}

/// Thrown when this device has been revoked on the remote backend.
class DeviceRevokedException extends SyncException {
  /// Creates a [DeviceRevokedException] with a technical description.
  const DeviceRevokedException([super.message = 'Device has been revoked']);
}

/// Thrown when another installation is detected writing journals with this device ID.
class DeviceCloneDetectedException extends SyncException {
  /// Creates a [DeviceCloneDetectedException] with a technical description.
  const DeviceCloneDetectedException([
    super.message = 'Cloned device identity detected',
  ]);
}

/// Thrown when the local vault folder does not exist or cannot be accessed.
class VaultFolderUnavailableException extends SyncException {
  /// Creates a [VaultFolderUnavailableException] with a technical description.
  const VaultFolderUnavailableException([
    super.message = 'Local vault folder unavailable',
  ]);
}
