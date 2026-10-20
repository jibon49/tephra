// © 2026 Tephra. All rights reserved.

/// Secure storage contract for sync secrets and credentials.
abstract interface class SecretStore {
  /// Reads the value for [key], or null if not found.
  Future<String?> read(String key);

  /// Writes [value] for [key].
  Future<void> write(String key, String value);

  /// Deletes the entry for [key].
  Future<void> delete(String key);
}

/// Constant secret keys used by Tephra synchronization and authentication.
abstract final class SyncSecretKeys {
  /// Refresh token for desktop (Windows) OAuth flow.
  static const desktopRefreshToken = 'tephra.google.desktop.refreshToken';

  /// Cached OAuth access token.
  static const accessToken = 'tephra.google.accessToken';

  /// Expiry timestamp of the cached access token in ISO 8601 UTC format.
  static const accessTokenExpiry = 'tephra.google.accessTokenExpiry';

  /// Connected user's Google account email.
  static const accountEmail = 'tephra.google.accountEmail';

  /// Remote vault master key in base64 (32 bytes).
  static String masterKey(String remoteVaultId) =>
      'tephra.sync.$remoteVaultId.masterKey';
}
