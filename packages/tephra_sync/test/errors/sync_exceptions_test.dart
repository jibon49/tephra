// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('SyncException hierarchy', () {
    test('AuthRevokedException', () {
      const e = AuthRevokedException();
      expect(e, isA<SyncException>());
      expect(e, isA<TephraException>());
      expect(e.toString(), contains('AuthRevokedException'));
      expect(e.message, contains('Authentication revoked'));
    });

    test('NetworkUnavailableException', () {
      const e = NetworkUnavailableException('Connection timed out');
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('NetworkUnavailableException'));
      expect(e.message, equals('Connection timed out'));
    });

    test('RateLimitedException stores retryAfter and formats string', () {
      const e1 = RateLimitedException();
      expect(e1, isA<SyncException>());
      expect(e1.retryAfter, isNull);
      expect(e1.toString(), contains('RateLimitedException'));

      const e2 = RateLimitedException(
        retryAfter: Duration(seconds: 45),
        message: 'Too many requests',
      );
      expect(e2.retryAfter, equals(const Duration(seconds: 45)));
      expect(e2.toString(), contains('45s'));
      expect(e2.message, equals('Too many requests'));
    });

    test('RemoteServerException stores statusCode and formats string', () {
      const e = RemoteServerException(503, 'Service unavailable');
      expect(e, isA<SyncException>());
      expect(e.statusCode, equals(503));
      expect(e.toString(), contains('HTTP 503'));
      expect(e.toString(), contains('RemoteServerException'));
    });

    test('RemoteQuotaExceededException', () {
      const e = RemoteQuotaExceededException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('RemoteQuotaExceededException'));
    });

    test('RemoteNotFoundException stores key and formats string', () {
      const e = RemoteNotFoundException('blobs/deadbeef');
      expect(e, isA<SyncException>());
      expect(e.key, equals('blobs/deadbeef'));
      expect(e.toString(), contains('blobs/deadbeef'));
      expect(e.toString(), contains('RemoteNotFoundException'));
    });

    test('RemoteFormatException', () {
      const e = RemoteFormatException('Invalid JSON syntax');
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('RemoteFormatException'));
      expect(e.message, equals('Invalid JSON syntax'));
    });

    test('RemoteVaultMissingException', () {
      const e = RemoteVaultMissingException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('RemoteVaultMissingException'));
    });

    test('SyncLockedException', () {
      const e = SyncLockedException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('SyncLockedException'));
    });

    test('DeviceRevokedException', () {
      const e = DeviceRevokedException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('DeviceRevokedException'));
    });

    test('DeviceCloneDetectedException', () {
      const e = DeviceCloneDetectedException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('DeviceCloneDetectedException'));
    });

    test('VaultFolderUnavailableException', () {
      const e = VaultFolderUnavailableException();
      expect(e, isA<SyncException>());
      expect(e.toString(), contains('VaultFolderUnavailableException'));
    });
  });

  group('CryptoException hierarchy', () {
    test('WrongPasswordException', () {
      const e = WrongPasswordException();
      expect(e, isA<CryptoException>());
      expect(e, isA<TephraException>());
      expect(e.toString(), contains('WrongPasswordException'));
    });

    test('WrongRecoveryKeyException', () {
      const e = WrongRecoveryKeyException();
      expect(e, isA<CryptoException>());
      expect(e.toString(), contains('WrongRecoveryKeyException'));
    });

    test('TamperedDataException stores key and formats string', () {
      const e1 = TamperedDataException();
      expect(e1, isA<CryptoException>());
      expect(e1.key, isNull);
      expect(e1.toString(), contains('TamperedDataException'));

      const e2 = TamperedDataException(
        key: 'journals/dev1/0000000001.json.enc',
        message: 'GCM tag check failed',
      );
      expect(e2.key, equals('journals/dev1/0000000001.json.enc'));
      expect(e2.toString(), contains('journals/dev1/0000000001.json.enc'));
      expect(e2.toString(), contains('TamperedDataException'));
    });

    test('UnsupportedEnvelopeException', () {
      const e = UnsupportedEnvelopeException();
      expect(e, isA<CryptoException>());
      expect(e.toString(), contains('UnsupportedEnvelopeException'));
    });

    test('KeyNotAvailableException', () {
      const e = KeyNotAvailableException();
      expect(e, isA<CryptoException>());
      expect(e.toString(), contains('KeyNotAvailableException'));
    });
  });
}
