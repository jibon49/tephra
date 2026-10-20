// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import '../crypto/object_cipher.dart';
import '../crypto/object_purpose.dart';

/// Two-phase sweep state persisted in `locks/gc-state.json.enc`.
final class GcState {
  /// Creates a [GcState].
  const GcState({
    this.version = 1,
    required this.updatedAt,
    this.candidates = const {},
  });

  /// Parses [GcState] from a JSON map.
  factory GcState.fromJson(Map<String, dynamic> json) {
    final rawCandidates =
        json['candidates'] as Map<String, dynamic>? ?? const {};
    final candidates = <String, DateTime>{};
    for (final entry in rawCandidates.entries) {
      try {
        candidates[entry.key] = DateTime.parse(entry.value as String).toUtc();
      } catch (_) {}
    }

    return GcState(
      version: (json['v'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      candidates: candidates,
    );
  }

  /// Schema version.
  final int version;

  /// UTC timestamp of the last state update.
  final DateTime updatedAt;

  /// Map of `blobKey -> firstSeenUnreferencedAt (UTC DateTime)`.
  final Map<String, DateTime> candidates;

  /// Converts this state to JSON map.
  Map<String, dynamic> toJson() => {
    'v': version,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'candidates': {
      for (final e in candidates.entries)
        e.key: e.value.toUtc().toIso8601String(),
    },
  };

  /// Encodes and seals this state using [cipher] with [ObjectPurpose.gcState].
  Future<List<int>> seal(ObjectCipher cipher) async {
    final jsonStr = jsonEncode(toJson());
    return cipher.seal(utf8.encode(jsonStr), ObjectPurpose.gcState);
  }

  /// Opens, decrypts, and parses [GcState] from remote bytes.
  static Future<GcState> open(List<int> bytes, ObjectCipher cipher) async {
    final opened = await cipher.open(bytes, ObjectPurpose.gcState);
    final map = jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
    return GcState.fromJson(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GcState &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          updatedAt == other.updatedAt &&
          _mapEquals(candidates, other.candidates);

  @override
  int get hashCode =>
      Object.hash(version, updatedAt, Object.hashAll(candidates.entries));

  @override
  String toString() =>
      'GcState(updatedAt: $updatedAt, candidates: ${candidates.length})';
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}
