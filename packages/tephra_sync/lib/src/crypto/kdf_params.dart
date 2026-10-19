// © 2026 Tephra. All rights reserved.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Parameters for Argon2id key derivation function.
final class KdfParams {
  /// Creates a [KdfParams] configuration.
  const KdfParams({
    this.alg = defaultAlg,
    this.version = defaultVersion,
    this.memoryKiB = floorMemoryKiB,
    this.iterations = floorIterations,
    this.parallelism = floorParallelism,
    required this.salt,
    this.calibratedMs = 0,
  });

  /// Factory creating floor parameters with fresh random [salt] (or injected [random]).
  factory KdfParams.floor({
    Random? random,
    List<int>? salt,
    int? calibratedMs,
  }) {
    final s = salt != null
        ? Uint8List.fromList(salt)
        : _randomBytes(saltLength, random: random);
    return KdfParams(salt: s, calibratedMs: calibratedMs ?? 0);
  }

  /// Parses [KdfParams] from JSON representation.
  factory KdfParams.fromJson(Map<String, Object?> json) {
    final saltStr = json['salt'] as String;
    return KdfParams(
      alg: json['alg'] as String? ?? defaultAlg,
      version: (json['version'] as num?)?.toInt() ?? defaultVersion,
      memoryKiB: (json['memoryKiB'] as num?)?.toInt() ?? floorMemoryKiB,
      iterations: (json['iterations'] as num?)?.toInt() ?? floorIterations,
      parallelism: (json['parallelism'] as num?)?.toInt() ?? floorParallelism,
      salt: base64Decode(saltStr),
      calibratedMs: (json['calibratedMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Algorithm identifier.
  static const String defaultAlg = 'argon2id';

  /// Argon2 version 0x13 (19).
  static const int defaultVersion = 19;

  /// Floor memory requirement in KiB (65536 KiB = 64 MiB).
  static const int floorMemoryKiB = 65536;

  /// Floor iteration count (passes).
  static const int floorIterations = 3;

  /// Floor parallelism (lanes).
  static const int floorParallelism = 1;

  /// Salt length in bytes.
  static const int saltLength = 16;

  /// Algorithm name (always 'argon2id').
  final String alg;

  /// Algorithm version (always 19).
  final int version;

  /// Memory size in KiB (1 KiB blocks).
  final int memoryKiB;

  /// Number of iterations.
  final int iterations;

  /// Degree of parallelism (lanes).
  final int parallelism;

  /// Random salt bytes (16 bytes).
  final List<int> salt;

  /// Time in milliseconds measured during device calibration (or 0).
  final int? calibratedMs;

  /// Derives the 32-byte Password Key Encryption Key (KEK) using [password].
  ///
  /// Passwords are used exactly as typed without trimming or Unicode normalization.
  Future<SecretKey> derivePasswordKek(String password) async {
    final argon2 = Argon2id(
      parallelism: parallelism,
      memory: memoryKiB,
      iterations: iterations,
      hashLength: 32,
    );
    return argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// Encodes this [KdfParams] configuration to JSON.
  Map<String, Object?> toJson() => {
    'alg': alg,
    'version': version,
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'salt': base64Encode(salt),
    'calibratedMs': calibratedMs ?? 0,
  };

  /// Returns a copy of [KdfParams] with optional field overrides.
  KdfParams copyWith({
    String? alg,
    int? version,
    int? memoryKiB,
    int? iterations,
    int? parallelism,
    List<int>? salt,
    int? calibratedMs,
  }) {
    return KdfParams(
      alg: alg ?? this.alg,
      version: version ?? this.version,
      memoryKiB: memoryKiB ?? this.memoryKiB,
      iterations: iterations ?? this.iterations,
      parallelism: parallelism ?? this.parallelism,
      salt: salt ?? this.salt,
      calibratedMs: calibratedMs ?? this.calibratedMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KdfParams &&
          runtimeType == other.runtimeType &&
          alg == other.alg &&
          version == other.version &&
          memoryKiB == other.memoryKiB &&
          iterations == other.iterations &&
          parallelism == other.parallelism &&
          calibratedMs == other.calibratedMs &&
          _bytesEqual(salt, other.salt);

  @override
  int get hashCode => Object.hash(
    alg,
    version,
    memoryKiB,
    iterations,
    parallelism,
    calibratedMs,
    Object.hashAll(salt),
  );

  @override
  String toString() =>
      'KdfParams(alg: $alg, v: $version, mem: ${memoryKiB}KiB, iters: $iterations, lanes: $parallelism, calMs: $calibratedMs)';

  static Uint8List _randomBytes(int length, {Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
