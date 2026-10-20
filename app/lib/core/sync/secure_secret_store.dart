// © 2026 Tephra. All rights reserved.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tephra_sync/tephra_sync.dart';

/// App implementation of [SecretStore] backed by [FlutterSecureStorage].
///
/// Uses Android Keystore and Windows DPAPI protected storage.
class SecureSecretStore implements SecretStore {
  SecureSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            wOptions: WindowsOptions(),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
