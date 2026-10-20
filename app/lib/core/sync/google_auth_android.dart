// © 2026 Tephra. All rights reserved.

import 'package:google_sign_in/google_sign_in.dart';
import 'package:tephra_sync/tephra_sync.dart';

import 'google_auth_service.dart';
import 'oauth_config.dart';
import 'secure_secret_store.dart';

/// Android implementation of [GoogleAuthService] and [AccessTokenSource]
/// backed by `google_sign_in` 7.x Credential Manager and [SecureSecretStore].
class GoogleAuthAndroid implements GoogleAuthService, AccessTokenSource {
  GoogleAuthAndroid({GoogleSignIn? signIn, SecretStore? secretStore})
    : _signIn = signIn ?? GoogleSignIn.instance,
      _secretStore = secretStore ?? SecureSecretStore();

  final GoogleSignIn _signIn;
  final SecretStore _secretStore;

  bool _initialized = false;
  String? _cachedToken;
  DateTime? _cachedExpiry;
  String? _cachedEmail;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _signIn.initialize(
      serverClientId: googleOAuthConfig.androidServerClientId.isNotEmpty
          ? googleOAuthConfig.androidServerClientId
          : null,
    );
    _initialized = true;
  }

  @override
  AccessTokenSource get tokens => this;

  @override
  Future<GoogleAccount> signInInteractive() async {
    await _ensureInitialized();

    final GoogleSignInAccount account = await _signIn.authenticate();
    final authz = await account.authorizationClient.authorizeScopes(
      GoogleOAuthConfig.scopes,
    );

    final token = authz.accessToken;
    final expiry = DateTime.now().toUtc().add(const Duration(minutes: 55));

    _cachedToken = token;
    _cachedExpiry = expiry;
    _cachedEmail = account.email;

    await _secretStore.write(SyncSecretKeys.accessToken, token);
    await _secretStore.write(
      SyncSecretKeys.accessTokenExpiry,
      expiry.toIso8601String(),
    );
    await _secretStore.write(SyncSecretKeys.accountEmail, account.email);

    return GoogleAccount(
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  @override
  Future<GoogleAccount?> currentAccount() async {
    final email = await _getEmail();
    if (email == null || email.isEmpty) {
      return null;
    }

    try {
      await accessToken();
      return GoogleAccount(email: email);
    } on AuthRevokedException {
      return null;
    } catch (_) {
      return GoogleAccount(email: email);
    }
  }

  Future<String?> _getEmail() async {
    if (_cachedEmail != null) return _cachedEmail;
    final stored = await _secretStore.read(SyncSecretKeys.accountEmail);
    if (stored != null && stored.isNotEmpty) {
      _cachedEmail = stored;
    }
    return _cachedEmail;
  }

  @override
  Future<String> accessToken({bool forceRefresh = false}) async {
    final now = DateTime.now().toUtc();

    // 1. Memory cache check
    if (!forceRefresh &&
        _cachedToken != null &&
        _cachedExpiry != null &&
        _cachedExpiry!.subtract(const Duration(minutes: 2)).isAfter(now)) {
      return _cachedToken!;
    }

    // 2. SecretStore check if memory was empty
    if (!forceRefresh && _cachedToken == null) {
      final storedToken = await _secretStore.read(SyncSecretKeys.accessToken);
      final storedExpiryStr = await _secretStore.read(
        SyncSecretKeys.accessTokenExpiry,
      );
      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedExpiryStr != null) {
        final storedExpiry = DateTime.tryParse(storedExpiryStr)?.toUtc();
        if (storedExpiry != null &&
            storedExpiry.subtract(const Duration(minutes: 2)).isAfter(now)) {
          _cachedToken = storedToken;
          _cachedExpiry = storedExpiry;
          return storedToken;
        }
      }
    }

    // 3. Invalidate old token on forceRefresh
    if (forceRefresh && _cachedToken != null) {
      try {
        await _signIn.authorizationClient.clearAuthorizationToken(
          accessToken: _cachedToken!,
        );
      } catch (_) {}
    }

    // 4. Silent authorization
    await _ensureInitialized();
    final GoogleSignInAccount? acct = await _signIn
        .attemptLightweightAuthentication();
    if (acct == null) {
      await _clearStored();
      throw const AuthRevokedException('No authenticated account');
    }

    final silent = await acct.authorizationClient.authorizationForScopes(
      GoogleOAuthConfig.scopes,
    );
    if (silent == null) {
      throw const AuthRevokedException(
        'User interaction required to authorize scopes',
      );
    }

    final newToken = silent.accessToken;
    final newExpiry = now.add(const Duration(minutes: 55));

    _cachedToken = newToken;
    _cachedExpiry = newExpiry;
    _cachedEmail = acct.email;

    await _secretStore.write(SyncSecretKeys.accessToken, newToken);
    await _secretStore.write(
      SyncSecretKeys.accessTokenExpiry,
      newExpiry.toIso8601String(),
    );
    await _secretStore.write(SyncSecretKeys.accountEmail, acct.email);

    return newToken;
  }

  @override
  Future<void> signOut() async {
    try {
      await _signIn.disconnect();
    } catch (_) {
      try {
        await _signIn.signOut();
      } catch (_) {}
    }
    await _clearStored();
  }

  Future<void> _clearStored() async {
    _cachedToken = null;
    _cachedExpiry = null;
    _cachedEmail = null;
    await _secretStore.delete(SyncSecretKeys.accessToken);
    await _secretStore.delete(SyncSecretKeys.accessTokenExpiry);
    await _secretStore.delete(SyncSecretKeys.accountEmail);
  }
}
