// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';
import '../model/hlc.dart';

/// Distributed GC lease record stored under `locks/gc-<deviceId>.json.enc`.
final class GcLease implements Comparable<GcLease> {
  /// Creates a [GcLease].
  const GcLease({
    this.version = 1,
    required this.deviceId,
    required this.hlc,
    required this.createdAt,
  });

  /// Parses lease record from JSON map.
  factory GcLease.fromJson(Map<String, dynamic> json) {
    return GcLease(
      version: (json['v'] as num?)?.toInt() ?? 1,
      deviceId: json['deviceId'] as String,
      hlc: Hlc.parse(json['hlc'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }

  /// Schema version.
  final int version;

  /// Originating device identifier.
  final String deviceId;

  /// Hybrid Logical Clock timestamp.
  final Hlc hlc;

  /// UTC ISO timestamp when the lease was claimed.
  final DateTime createdAt;

  /// Converts lease record to JSON map.
  Map<String, dynamic> toJson() => {
    'v': version,
    'deviceId': deviceId,
    'hlc': hlc.encoded,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Encodes and seals this lease using [cipher] with [ObjectPurpose.lock].
  Future<List<int>> seal(ObjectCipher cipher) async {
    final jsonStr = jsonEncode(toJson());
    return cipher.seal(utf8.encode(jsonStr), ObjectPurpose.lock);
  }

  /// Opens, decrypts, and parses a [GcLease] from remote bytes.
  static Future<GcLease> open(List<int> bytes, ObjectCipher cipher) async {
    final opened = await cipher.open(bytes, ObjectPurpose.lock);
    final map = jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
    return GcLease.fromJson(map);
  }

  @override
  int compareTo(GcLease other) {
    // Winner is smallest (hlc, deviceId)
    final cmp = hlc.compareTo(other.hlc);
    if (cmp != 0) return cmp;
    return deviceId.compareTo(other.deviceId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GcLease &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          deviceId == other.deviceId &&
          hlc == other.hlc &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(version, deviceId, hlc, createdAt);

  @override
  String toString() => 'GcLease(device: $deviceId, hlc: ${hlc.encoded})';
}
