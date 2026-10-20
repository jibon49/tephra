// © 2026 Tephra. All rights reserved.

/// Result of an OAuth authorization and token exchange flow.
class OAuthTokens {
  const OAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scope,
    this.email,
  });

  /// The OAuth 2.0 bearer access token.
  final String accessToken;

  /// The OAuth 2.0 refresh token.
  final String refreshToken;

  /// The expiration timestamp in UTC.
  final DateTime expiresAt;

  /// Granted OAuth scopes.
  final String scope;

  /// Connected user's email address extracted from the ID token.
  final String? email;

  /// Returns true if the token is expired or within [skew] of expiring.
  bool isExpired({DateTime? now, Duration skew = const Duration(minutes: 2)}) {
    final current = now?.toUtc() ?? DateTime.now().toUtc();
    return expiresAt.subtract(skew).isBefore(current);
  }

  @override
  String toString() =>
      'OAuthTokens(expiresAt: $expiresAt, scope: $scope, email: $email)';
}
