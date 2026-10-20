// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';

/// Application Google OAuth configuration loaded from compile-time environment variables.
///
/// Compile-time variables are passed via `--dart-define-from-file=../secrets/google_oauth.json`
/// (path relative to the `app/` directory).
///
/// When omitted or when placeholder values are present, [googleOAuthConfig.isComplete] will be false.
const googleOAuthConfig = GoogleOAuthConfig(
  androidServerClientId: String.fromEnvironment(
    'TEPHRA_GOOGLE_ANDROID_SERVER_CLIENT_ID',
  ),
  desktopClientId: String.fromEnvironment('TEPHRA_GOOGLE_DESKTOP_CLIENT_ID'),
  desktopClientSecret: String.fromEnvironment(
    'TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET',
  ),
);
