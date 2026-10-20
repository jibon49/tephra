// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';

import 'google_auth_service.dart';

/// Fallback [GoogleAuthService] for unsupported platforms (e.g. web).
class GoogleAuthUnsupported implements GoogleAuthService {
  const GoogleAuthUnsupported();

  @override
  Future<GoogleAccount> signInInteractive() =>
      throw UnsupportedError('Google sync is not supported on this platform');

  @override
  Future<GoogleAccount?> currentAccount() =>
      throw UnsupportedError('Google sync is not supported on this platform');

  @override
  AccessTokenSource get tokens =>
      throw UnsupportedError('Google sync is not supported on this platform');

  @override
  Future<void> signOut() =>
      throw UnsupportedError('Google sync is not supported on this platform');
}
