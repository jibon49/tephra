// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:tephra_sync/tephra_sync.dart';

/// Developer utility to generate a long-lived Google Drive OAuth refresh token for CI nightly testing.
///
/// Reads client credentials from `secrets/google_oauth.json`.
void main() async {
  final secretsFile = File('secrets/google_oauth.json');
  if (!secretsFile.existsSync()) {
    stderr.writeln(
      'Error: secrets/google_oauth.json not found. Set up human prerequisites H1-H7 first.',
    );
    exit(1);
  }

  final json =
      jsonDecode(await secretsFile.readAsString()) as Map<String, dynamic>;
  final clientId = json['TEPHRA_GOOGLE_DESKTOP_CLIENT_ID'] as String?;
  final clientSecret = json['TEPHRA_GOOGLE_DESKTOP_CLIENT_SECRET'] as String?;

  if (clientId == null ||
      clientSecret == null ||
      clientId.contains('REPLACE') ||
      clientSecret.contains('REPLACE')) {
    stderr.writeln('Error: Desktop client ID and secret must be configured.');
    exit(1);
  }

  stdout.writeln('Opening browser for Google authorization...');

  final flow = DesktopOAuthFlow(
    clientId: clientId,
    clientSecret: clientSecret,
    openBrowser: (uri) async {
      final url = uri.toString();
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else {
        await Process.run('xdg-open', [url]);
      }
    },
  );

  try {
    final tokens = await flow.signIn();
    stdout.writeln(
      '\n============================================================',
    );
    stdout.writeln('Google Drive Refresh Token Generated Successfully!');
    stdout.writeln('Account: ${tokens.email ?? "unknown"}');
    stdout.writeln('Refresh Token: ${tokens.refreshToken}');
    stdout.writeln(
      '============================================================',
    );
    stdout.writeln(
      '\nStore this as the GitHub secret TEPHRA_DRIVE_TEST_REFRESH_TOKEN. Do not share it.\n',
    );
  } catch (e) {
    stderr.writeln('Authorization failed: $e');
    exit(1);
  }
}
