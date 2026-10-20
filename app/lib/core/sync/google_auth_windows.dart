// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_auth_service.dart';
import 'oauth_config.dart';
import 'secure_secret_store.dart';

/// Windows implementation of [GoogleAuthService] using system browser loopback OAuth.
class GoogleAuthWindows implements GoogleAuthService {
  GoogleAuthWindows({
    SecretStore? secretStore,
    DesktopOAuthFlow? flow,
    DesktopTokenSource? tokenSource,
  }) : _secretStore = secretStore ?? SecureSecretStore(),
       _flow =
           flow ??
           DesktopOAuthFlow(
             clientId: googleOAuthConfig.desktopClientId,
             clientSecret: googleOAuthConfig.desktopClientSecret,
             openBrowser: (uri) =>
                 launchUrl(uri, mode: LaunchMode.externalApplication),
           ) {
    _tokenSource =
        tokenSource ?? DesktopTokenSource(flow: _flow, store: _secretStore);
  }

  final SecretStore _secretStore;
  final DesktopOAuthFlow _flow;
  late final DesktopTokenSource _tokenSource;

  @override
  AccessTokenSource get tokens => _tokenSource;

  @override
  Future<GoogleAccount> signInInteractive() async {
    final oauthTokens = await _flow.signIn();
    await _tokenSource.saveTokens(oauthTokens);
    return GoogleAccount(email: oauthTokens.email ?? '');
  }

  @override
  Future<GoogleAccount?> currentAccount() async {
    final email = await _tokenSource.getAccountEmail();
    if (email == null || email.isEmpty) {
      return null;
    }

    try {
      await _tokenSource.accessToken();
      return GoogleAccount(email: email);
    } on AuthRevokedException {
      return null;
    } catch (_) {
      // In offline conditions, return the known cached account
      return GoogleAccount(email: email);
    }
  }

  @override
  Future<void> signOut() => _tokenSource.signOut();
}
