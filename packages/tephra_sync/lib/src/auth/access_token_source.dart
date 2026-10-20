// © 2026 Tephra. All rights reserved.

/// Source of OAuth access tokens for sync operations.
abstract interface class AccessTokenSource {
  /// Returns a valid access token.
  ///
  /// If [forceRefresh] is true, forces a token refresh rather than returning a cached token.
  /// Throws [AuthRevokedException] if authentication is no longer valid or revoked.
  /// Throws [NetworkUnavailableException] if token refresh cannot reach the network.
  Future<String> accessToken({bool forceRefresh = false});

  /// Signs out, forgets tokens locally, and revokes remote access if possible.
  Future<void> signOut();
}
