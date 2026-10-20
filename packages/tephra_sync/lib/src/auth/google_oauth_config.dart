// © 2026 Tephra. All rights reserved.

/// Pure Dart OAuth configuration model for Google authentication.
class GoogleOAuthConfig {
  const GoogleOAuthConfig({
    required this.androidServerClientId,
    required this.desktopClientId,
    required this.desktopClientSecret,
  });

  /// Scopes required for Google Drive sync.
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// The web application OAuth client ID used by Android Google Sign-In / Credential Manager.
  final String androidServerClientId;

  /// The desktop application OAuth client ID used on Windows.
  final String desktopClientId;

  /// The desktop application OAuth client secret used on Windows.
  final String desktopClientSecret;

  /// Returns true if all required client IDs and secrets are non-empty.
  bool get isComplete =>
      androidServerClientId.trim().isNotEmpty &&
      desktopClientId.trim().isNotEmpty &&
      desktopClientSecret.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoogleOAuthConfig &&
          runtimeType == other.runtimeType &&
          androidServerClientId == other.androidServerClientId &&
          desktopClientId == other.desktopClientId &&
          desktopClientSecret == other.desktopClientSecret;

  @override
  int get hashCode =>
      Object.hash(androidServerClientId, desktopClientId, desktopClientSecret);

  @override
  String toString() =>
      'GoogleOAuthConfig(androidServerClientId: $androidServerClientId, desktopClientId: $desktopClientId, isComplete: $isComplete)';
}
