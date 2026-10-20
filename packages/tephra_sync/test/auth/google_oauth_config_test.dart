// © 2026 Tephra. All rights reserved.

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('GoogleOAuthConfig', () {
    test('isComplete returns true when all three fields are non-empty', () {
      const config = GoogleOAuthConfig(
        androidServerClientId: '123.apps.googleusercontent.com',
        desktopClientId: '456.apps.googleusercontent.com',
        desktopClientSecret: 'GOCSPX-secret',
      );

      expect(config.isComplete, isTrue);
    });

    test(
      'isComplete returns false if androidServerClientId is empty or blank',
      () {
        const empty = GoogleOAuthConfig(
          androidServerClientId: '',
          desktopClientId: '456.apps.googleusercontent.com',
          desktopClientSecret: 'GOCSPX-secret',
        );
        expect(empty.isComplete, isFalse);

        const blank = GoogleOAuthConfig(
          androidServerClientId: '   ',
          desktopClientId: '456.apps.googleusercontent.com',
          desktopClientSecret: 'GOCSPX-secret',
        );
        expect(blank.isComplete, isFalse);
      },
    );

    test('isComplete returns false if desktopClientId is empty or blank', () {
      const empty = GoogleOAuthConfig(
        androidServerClientId: '123.apps.googleusercontent.com',
        desktopClientId: '',
        desktopClientSecret: 'GOCSPX-secret',
      );
      expect(empty.isComplete, isFalse);

      const blank = GoogleOAuthConfig(
        androidServerClientId: '123.apps.googleusercontent.com',
        desktopClientId: '   ',
        desktopClientSecret: 'GOCSPX-secret',
      );
      expect(blank.isComplete, isFalse);
    });

    test(
      'isComplete returns false if desktopClientSecret is empty or blank',
      () {
        const empty = GoogleOAuthConfig(
          androidServerClientId: '123.apps.googleusercontent.com',
          desktopClientId: '456.apps.googleusercontent.com',
          desktopClientSecret: '',
        );
        expect(empty.isComplete, isFalse);

        const blank = GoogleOAuthConfig(
          androidServerClientId: '123.apps.googleusercontent.com',
          desktopClientId: '456.apps.googleusercontent.com',
          desktopClientSecret: '   ',
        );
        expect(blank.isComplete, isFalse);
      },
    );

    test('scopes contains drive.file', () {
      expect(
        GoogleOAuthConfig.scopes,
        contains('https://www.googleapis.com/auth/drive.file'),
      );
    });

    test('equality and hashCode', () {
      const a = GoogleOAuthConfig(
        androidServerClientId: '123',
        desktopClientId: '456',
        desktopClientSecret: '789',
      );
      const b = GoogleOAuthConfig(
        androidServerClientId: '123',
        desktopClientId: '456',
        desktopClientSecret: '789',
      );
      const c = GoogleOAuthConfig(
        androidServerClientId: 'other',
        desktopClientId: '456',
        desktopClientSecret: '789',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
