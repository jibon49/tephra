// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';

import 'google_auth_android.dart';
import 'google_auth_unsupported.dart';
import 'google_auth_windows.dart';

/// Representation of a connected Google user account.
class GoogleAccount {
  const GoogleAccount({required this.email, this.displayName, this.photoUrl});

  final String email;
  final String? displayName;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoogleAccount &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl;

  @override
  int get hashCode => Object.hash(email, displayName, photoUrl);

  @override
  String toString() =>
      'GoogleAccount(email: $email, displayName: $displayName)';
}

/// App service contract for Google Sign-In and Drive authorization.
abstract interface class GoogleAuthService {
  /// Initiates interactive sign-in flow (only called from user actions).
  Future<GoogleAccount> signInInteractive();

  /// Returns the currently signed-in account, or null if signed out or revoked.
  Future<GoogleAccount?> currentAccount();

  /// Access token source for sync HTTP requests.
  AccessTokenSource get tokens;

  /// Signs out of the Google account and clears stored credentials.
  Future<void> signOut();
}

/// Creates the platform-appropriate [GoogleAuthService] implementation.
GoogleAuthService createGoogleAuthService({
  bool isWeb = false,
  bool isAndroid = false,
  bool isWindows = false,
}) {
  if (isWeb) {
    return const GoogleAuthUnsupported();
  }
  if (isAndroid) {
    return GoogleAuthAndroid();
  }
  if (isWindows) {
    return GoogleAuthWindows();
  }
  return const GoogleAuthUnsupported();
}
