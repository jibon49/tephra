// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';
import 'package:tephra_core/tephra_core.dart';

import '../crypto/encrypting_object_cipher.dart';
import '../crypto/kdf_calibrator.dart';
import '../crypto/kdf_params.dart';
import '../crypto/key_wrap.dart';
import '../crypto/master_key.dart';
import '../crypto/plaintext_object_cipher.dart';
import '../crypto/recovery_key.dart';
import '../errors/sync_exceptions.dart';
import '../model/device_identity.dart';
import '../provider/sync_provider.dart';
import 'device_registry.dart';
import 'remote_layout.dart';
import 'vault_header.dart';

/// Result of a successful remote vault initialization.
final class CreatedVault {
  /// Creates a [CreatedVault] result.
  const CreatedVault({
    required this.header,
    this.masterKey,
    this.recoveryKeyDisplay,
  });

  /// The initialized remote vault header written to `vault.json`.
  final VaultHeader header;

  /// 256-bit root master key (null if vault is created without encryption).
  final SecretKey? masterKey;

  /// Canonical formatted display string for the emergency recovery key
  /// (null if vault is created without encryption).
  final String? recoveryKeyDisplay;
}

/// Manages remote vault discovery, creation, unlocking, and re-keying.
///
/// **Concurrent password changes:**
/// When two devices attempt to change or rotate the password concurrently,
/// last writer wins on `vault.json`. Because both password wraps protect the
/// exact same 256-bit master key, no data or file encryption integrity is lost.
final class RemoteVaultManager {
  /// Creates a [RemoteVaultManager].
  RemoteVaultManager(
    this.provider, {
    this.clock = const SystemClock(),
    this.random,
    @visibleForTesting this.floorOverride,
  });

  /// Underlying remote storage provider.
  final SyncProvider provider;

  /// Clock used for timestamping vault creation and updates.
  final Clock clock;

  /// Secure random generator.
  final Random? random;

  /// Test-only KDF parameters override to bypass slow Argon2id derivation in tests.
  @visibleForTesting
  final KdfParams? floorOverride;

  /// Creates and initializes a new remote vault.
  ///
  /// If [password] is null, creates an unencrypted vault (`encryption: 'none'`).
  /// Otherwise, calibrates Argon2id KDF parameters, generates a 256-bit [MasterKey]
  /// and emergency [RecoveryKey], wraps the master key twice, registers [device],
  /// and writes `vault.json` strictly last.
  Future<CreatedVault> create({
    required String vaultName,
    required String? password,
    required DeviceIdentity device,
    required bool isAndroid,
  }) async {
    final vaultId = generateUuidV4(random);
    final now = clock.now().toUtc();
    final createdBy = {
      'deviceId': device.deviceId,
      'deviceName': device.deviceName,
    };

    if (password == null) {
      final header = VaultHeader(
        vaultId: vaultId,
        vaultName: vaultName,
        createdAt: now,
        createdBy: createdBy,
        updatedAt: now,
        encryption: 'none',
      );

      // Write device file first
      final registry = DeviceRegistry(
        provider,
        const PlaintextObjectCipher(),
        clock: clock,
      );
      await registry.register(device);

      // Write vault.json last
      await provider.put(
        RemoteLayout.vaultHeader,
        utf8.encode(header.toPrettyJson()),
      );

      return CreatedVault(header: header);
    }

    // Encrypted vault
    final masterKey = MasterKey.generate(random: random);

    // KDF calibration
    final KdfParams kdf;
    if (floorOverride != null) {
      final s = _generateSalt(random);
      kdf = floorOverride!.copyWith(salt: s);
    } else {
      kdf = await KdfCalibrator.calibrate(isAndroid: isAndroid, random: random);
    }

    // Derive password KEK in isolate
    final passwordKek = await _derivePasswordKekInIsolate(kdf, password);
    final passwordWrap = await WrappedKey.wrap(
      kek: passwordKek,
      masterKey: masterKey,
      vaultId: vaultId,
      purpose: 'password',
      random: random,
    );

    // Generate recovery key and wrap master key
    final recoveryKey = RecoveryKey.generate(random: random);
    final recoverySalt = _generateSalt(random);
    final recoveryKek = await recoveryKey.deriveRecoveryKek(
      recoverySalt: recoverySalt,
    );
    final recoveryWrap = await WrappedKey.wrap(
      kek: recoveryKek,
      masterKey: masterKey,
      vaultId: vaultId,
      purpose: 'recovery',
      salt: recoverySalt,
      random: random,
    );

    final header = VaultHeader(
      vaultId: vaultId,
      vaultName: vaultName,
      createdAt: now,
      createdBy: createdBy,
      updatedAt: now,
      encryption: 'aes-256-gcm',
      kdf: kdf,
      wrappedKeys: {'password': passwordWrap, 'recovery': recoveryWrap},
    );

    // Write device file first
    final cipher = EncryptingObjectCipher(
      masterKey: masterKey.secretKey,
      vaultId: vaultId,
      random: random,
    );
    final registry = DeviceRegistry(provider, cipher, clock: clock);
    await registry.register(device);

    // Write vault.json last
    await provider.put(
      RemoteLayout.vaultHeader,
      utf8.encode(header.toPrettyJson()),
    );

    return CreatedVault(
      header: header,
      masterKey: masterKey.secretKey,
      recoveryKeyDisplay: recoveryKey.displayString,
    );
  }

  /// Downloads and parses the remote [VaultHeader] from `vault.json`.
  ///
  /// Throws [RemoteVaultMissingException] if `vault.json` does not exist,
  /// or [RemoteFormatException] if the JSON structure is malformed.
  Future<VaultHeader> readHeader() async {
    try {
      final bytes = await provider.get(RemoteLayout.vaultHeader);
      final jsonStr = utf8.decode(bytes);
      final json = jsonDecode(jsonStr);
      if (json is! Map) {
        throw const RemoteFormatException('vault.json must be a JSON object');
      }
      return VaultHeader.fromJson(json.cast<String, Object?>());
    } on RemoteNotFoundException catch (e) {
      throw RemoteVaultMissingException('vault.json not found: ${e.key}');
    } on FormatException catch (e) {
      throw RemoteFormatException('Invalid JSON in vault.json: $e');
    }
  }

  /// Derives the master key from [password] using the Argon2id parameters in [h].
  ///
  /// Computation runs in a background isolate via [Isolate.run].
  /// Throws [WrongPasswordException] if authentication tag fails,
  /// or [StateError] if vault is not encrypted.
  Future<SecretKey> unlockWithPassword(VaultHeader h, String password) async {
    if (!h.isEncrypted) {
      throw StateError('Cannot unlock unencrypted vault');
    }
    final kdf = h.kdf;
    final passwordWrap = h.wrappedKeys?['password'];
    if (kdf == null || passwordWrap == null) {
      throw const RemoteFormatException(
        'Missing kdf or password wrappedKey in vault.json',
      );
    }

    final kek = await _derivePasswordKekInIsolate(kdf, password);
    final masterKey = await passwordWrap.unwrap(
      kek: kek,
      vaultId: h.vaultId,
      purpose: 'password',
    );
    return masterKey.secretKey;
  }

  /// Derives the master key from [recoveryKey] string.
  ///
  /// Throws [WrongRecoveryKeyException] on invalid key string, checksum mismatch,
  /// or GCM authentication tag failure.
  Future<SecretKey> unlockWithRecoveryKey(
    VaultHeader h,
    String recoveryKey,
  ) async {
    if (!h.isEncrypted) {
      throw StateError('Cannot unlock unencrypted vault');
    }
    final recoveryWrap = h.wrappedKeys?['recovery'];
    if (recoveryWrap == null) {
      throw const RemoteFormatException(
        'Missing recovery wrappedKey in vault.json',
      );
    }
    if (recoveryWrap.salt == null) {
      throw const RemoteFormatException(
        'Missing recovery salt in recovery wrappedKey',
      );
    }

    final parsed = RecoveryKey.parse(recoveryKey);
    final kek = await parsed.deriveRecoveryKek(
      recoverySalt: recoveryWrap.salt!,
    );
    final masterKey = await recoveryWrap.unwrap(
      kek: kek,
      vaultId: h.vaultId,
      purpose: 'recovery',
    );
    return masterKey.secretKey;
  }

  /// Changes the vault password by re-wrapping the existing [masterKey].
  ///
  /// Generates a fresh Argon2id salt (and re-calibrates on Android),
  /// keeps the existing recovery key wrap unchanged, updates `updatedAt`,
  /// and writes the updated `vault.json`.
  /// No ciphertext blobs are modified or re-uploaded.
  Future<void> changePassword({
    required VaultHeader h,
    required SecretKey masterKey,
    required String newPassword,
    required bool isAndroid,
  }) async {
    if (!h.isEncrypted) {
      throw StateError('Cannot change password on unencrypted vault');
    }

    final KdfParams newKdf;
    if (floorOverride != null) {
      final s = _generateSalt(random);
      newKdf = floorOverride!.copyWith(salt: s);
    } else {
      newKdf = await KdfCalibrator.calibrate(
        isAndroid: isAndroid,
        random: random,
      );
    }

    final newKek = await _derivePasswordKekInIsolate(newKdf, newPassword);
    final mk = MasterKey(await masterKey.extractBytes());
    final newPasswordWrap = await WrappedKey.wrap(
      kek: newKek,
      masterKey: mk,
      vaultId: h.vaultId,
      purpose: 'password',
      random: random,
    );

    final updatedWrapped = Map<String, WrappedKey>.from(h.wrappedKeys ?? {});
    updatedWrapped['password'] = newPasswordWrap;

    final now = clock.now().toUtc();
    final updatedHeader = h.copyWith(
      kdf: newKdf,
      wrappedKeys: updatedWrapped,
      updatedAt: now,
    );

    await provider.put(
      RemoteLayout.vaultHeader,
      utf8.encode(updatedHeader.toPrettyJson()),
    );
  }

  /// Generates a fresh emergency recovery key and updates `vault.json`.
  ///
  /// Keeps the password wrap unchanged, updates `updatedAt`, writes the
  /// updated `vault.json`, and returns the canonical display string.
  Future<String> regenerateRecoveryKey({
    required VaultHeader h,
    required SecretKey masterKey,
  }) async {
    if (!h.isEncrypted) {
      throw StateError('Cannot regenerate recovery key on unencrypted vault');
    }

    final newRecovery = RecoveryKey.generate(random: random);
    final recoverySalt = _generateSalt(random);
    final recoveryKek = await newRecovery.deriveRecoveryKek(
      recoverySalt: recoverySalt,
    );

    final mk = MasterKey(await masterKey.extractBytes());
    final newRecoveryWrap = await WrappedKey.wrap(
      kek: recoveryKek,
      masterKey: mk,
      vaultId: h.vaultId,
      purpose: 'recovery',
      salt: recoverySalt,
      random: random,
    );

    final updatedWrapped = Map<String, WrappedKey>.from(h.wrappedKeys ?? {});
    updatedWrapped['recovery'] = newRecoveryWrap;

    final now = clock.now().toUtc();
    final updatedHeader = h.copyWith(
      wrappedKeys: updatedWrapped,
      updatedAt: now,
    );

    await provider.put(
      RemoteLayout.vaultHeader,
      utf8.encode(updatedHeader.toPrettyJson()),
    );

    return newRecovery.displayString;
  }

  static Future<SecretKey> _derivePasswordKekInIsolate(
    KdfParams kdf,
    String password,
  ) async {
    final kekBytes = await Isolate.run(() async {
      final argon2 = Argon2id(
        parallelism: kdf.parallelism,
        memory: kdf.memoryKiB,
        iterations: kdf.iterations,
        hashLength: 32,
      );
      final kek = await argon2.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: kdf.salt,
      );
      return kek.extractBytes();
    });
    return SecretKey(kekBytes);
  }

  static Uint8List _generateSalt(Random? random) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }
}
