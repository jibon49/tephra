// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/core/sync/google_auth_android.dart';
import 'package:tephra/core/sync/google_auth_unsupported.dart';
import 'package:tephra/core/sync/google_auth_windows.dart';

void main() {
  group('GoogleAuthService platform selection', () {
    test('returns GoogleAuthUnsupported when isWeb is true', () {
      final service = createGoogleAuthService(isWeb: true);
      expect(service, isA<GoogleAuthUnsupported>());

      expect(() => service.signInInteractive(), throwsUnsupportedError);
      expect(() => service.currentAccount(), throwsUnsupportedError);
      expect(() => service.tokens, throwsUnsupportedError);
      expect(() => service.signOut(), throwsUnsupportedError);
    });

    test('returns GoogleAuthAndroid when isAndroid is true', () {
      final service = createGoogleAuthService(isAndroid: true);
      expect(service, isA<GoogleAuthAndroid>());
    });

    test('returns GoogleAuthWindows when isWindows is true', () {
      final service = createGoogleAuthService(isWindows: true);
      expect(service, isA<GoogleAuthWindows>());
    });

    test(
      'googleAuthServiceProvider provides a GoogleAuthService in Riverpod',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(googleAuthServiceProvider);
        expect(service, isA<GoogleAuthService>());
      },
    );
  });

  group('GoogleAccount model', () {
    test('equality and hashCode', () {
      const a = GoogleAccount(
        email: 'user@example.com',
        displayName: 'User Name',
        photoUrl: 'https://example.com/photo.jpg',
      );
      const b = GoogleAccount(
        email: 'user@example.com',
        displayName: 'User Name',
        photoUrl: 'https://example.com/photo.jpg',
      );
      const c = GoogleAccount(email: 'other@example.com');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('user@example.com'));
    });
  });
}
