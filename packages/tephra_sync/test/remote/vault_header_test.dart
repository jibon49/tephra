// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:typed_data';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('VaultHeader', () {
    test('JSON round-trip for encrypted vault', () {
      final header = VaultHeader(
        vaultId: '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        vaultName: 'My Encrypted Vault',
        createdAt: DateTime.utc(2026, 10, 11, 9, 30),
        createdBy: {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        updatedAt: DateTime.utc(2026, 10, 11, 9, 30),
        encryption: 'aes-256-gcm',
        kdf: KdfParams(
          memoryKiB: 65536,
          iterations: 3,
          parallelism: 1,
          salt: Uint8List(16),
          calibratedMs: 120,
        ),
        wrappedKeys: {
          'password': WrappedKey(
            nonce: Uint8List(12),
            ciphertext: Uint8List(48),
          ),
          'recovery': WrappedKey(
            nonce: Uint8List(12),
            ciphertext: Uint8List(48),
            salt: Uint8List(16),
          ),
        },
      );

      final json = header.toJson();
      expect(json['format'], equals('tephra-remote'));
      expect(json['formatVersion'], equals(1));
      expect(json['encryption'], equals('aes-256-gcm'));
      expect(json['kdf'], isA<Map<String, Object?>>());
      expect(json['wrappedKeys'], isA<Map<String, Object?>>());

      final prettyJson = header.toPrettyJson();
      expect(prettyJson, contains('  "format": "tephra-remote"'));

      final parsed = VaultHeader.fromJson(
        jsonDecode(prettyJson) as Map<String, Object?>,
      );
      expect(parsed.vaultId, equals(header.vaultId));
      expect(parsed.vaultName, equals(header.vaultName));
      expect(parsed.createdAt, equals(header.createdAt));
      expect(parsed.updatedAt, equals(header.updatedAt));
      expect(parsed.encryption, equals('aes-256-gcm'));
      expect(parsed.isEncrypted, isTrue);
      expect(parsed.kdf, equals(header.kdf));
      expect(
        parsed.wrappedKeys?['password'],
        equals(header.wrappedKeys?['password']),
      );
      expect(
        parsed.wrappedKeys?['recovery'],
        equals(header.wrappedKeys?['recovery']),
      );
    });

    test('JSON round-trip for plaintext vault (no kdf, no wrappedKeys)', () {
      final header = VaultHeader(
        vaultId: '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        vaultName: 'My Plain Vault',
        createdAt: DateTime.utc(2026, 10, 11, 9, 30),
        createdBy: {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        updatedAt: DateTime.utc(2026, 10, 11, 9, 30),
        encryption: 'none',
      );

      final json = header.toJson();
      expect(json['encryption'], equals('none'));
      expect(json.containsKey('kdf'), isFalse);
      expect(json.containsKey('wrappedKeys'), isFalse);

      final prettyJson = header.toPrettyJson();
      final parsed = VaultHeader.fromJson(
        jsonDecode(prettyJson) as Map<String, Object?>,
      );
      expect(parsed.isEncrypted, isFalse);
      expect(parsed.kdf, isNull);
      expect(parsed.wrappedKeys, isNull);
      expect(parsed.vaultName, equals('My Plain Vault'));
    });

    test(
      'unknown extra fields are preserved across parse and serialization',
      () {
        final raw = {
          'format': 'tephra-remote',
          'formatVersion': 1,
          'vaultId': '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
          'vaultName': 'Test Vault',
          'createdAt': '2026-10-11T09:30:00.000Z',
          'createdBy': {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
          'updatedAt': '2026-10-11T09:30:00.000Z',
          'encryption': 'none',
          'chunking': VaultHeader.defaultChunking,
          'customExtensionField': 'tephra-future-feature',
          'nestedFutureConfig': {'flag': true, 'count': 42},
        };

        final parsed = VaultHeader.fromJson(raw);
        expect(
          parsed.extraFields['customExtensionField'],
          equals('tephra-future-feature'),
        );
        expect(
          (parsed.extraFields['nestedFutureConfig'] as Map)['count'],
          equals(42),
        );

        final serialized = parsed.toJson();
        expect(
          serialized['customExtensionField'],
          equals('tephra-future-feature'),
        );
        expect((serialized['nestedFutureConfig'] as Map)['count'], equals(42));
      },
    );

    test('formatVersion > 1 throws RemoteFormatException', () {
      final raw = {
        'format': 'tephra-remote',
        'formatVersion': 2,
        'vaultId': '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        'vaultName': 'Future Vault',
        'createdAt': '2026-10-11T09:30:00.000Z',
        'createdBy': {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        'updatedAt': '2026-10-11T09:30:00.000Z',
        'encryption': 'none',
      };

      expect(
        () => VaultHeader.fromJson(raw),
        throwsA(
          isA<RemoteFormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported formatVersion: 2'),
          ),
        ),
      );
    });

    test('unsupported format string throws RemoteFormatException', () {
      final raw = {
        'format': 'unknown-remote-format',
        'formatVersion': 1,
        'vaultId': '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        'vaultName': 'Bad Format Vault',
        'createdAt': '2026-10-11T09:30:00.000Z',
        'createdBy': {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        'updatedAt': '2026-10-11T09:30:00.000Z',
        'encryption': 'none',
      };

      expect(
        () => VaultHeader.fromJson(raw),
        throwsA(
          isA<RemoteFormatException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported vault format'),
          ),
        ),
      );
    });

    test('missing required field throws RemoteFormatException', () {
      final raw = {
        'format': 'tephra-remote',
        'formatVersion': 1,
        'vaultId': '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        // missing vaultName
        'createdAt': '2026-10-11T09:30:00.000Z',
        'createdBy': {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        'updatedAt': '2026-10-11T09:30:00.000Z',
        'encryption': 'none',
      };

      expect(
        () => VaultHeader.fromJson(raw),
        throwsA(
          isA<RemoteFormatException>().having(
            (e) => e.message,
            'message',
            contains('Missing required field'),
          ),
        ),
      );
    });

    test('encrypted vault missing kdf throws RemoteFormatException', () {
      final raw = {
        'format': 'tephra-remote',
        'formatVersion': 1,
        'vaultId': '6f1c2a9e-3b0d-4c8e-9a51-2d7f0e4b8c11',
        'vaultName': 'Encrypted Without Kdf',
        'createdAt': '2026-10-11T09:30:00.000Z',
        'createdBy': {'deviceId': 'dev-1', 'deviceName': 'Office PC'},
        'updatedAt': '2026-10-11T09:30:00.000Z',
        'encryption': 'aes-256-gcm',
        // missing kdf
        'wrappedKeys': {
          'password': {
            'alg': 'aes-256-gcm',
            'nonce': base64Encode(Uint8List(12)),
            'ciphertext': base64Encode(Uint8List(48)),
          },
        },
      };

      expect(
        () => VaultHeader.fromJson(raw),
        throwsA(
          isA<RemoteFormatException>().having(
            (e) => e.message,
            'message',
            contains('Missing kdf configuration'),
          ),
        ),
      );
    });
  });
}
