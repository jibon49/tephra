// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'three_way_merge.dart';

bool _deepJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepJsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

Map<String, dynamic>? _mergeJsonMaps(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> remote, {
  bool recurseOneLevel = true,
}) {
  final allKeys = <String>{...base.keys, ...local.keys, ...remote.keys};
  final result = <String, dynamic>{};

  for (final key in allKeys) {
    final inBase = base.containsKey(key);
    final inLocal = local.containsKey(key);
    final inRemote = remote.containsKey(key);

    final baseVal = base[key];
    final localVal = local[key];
    final remoteVal = remote[key];

    final localSameAsBase =
        inLocal == inBase && _deepJsonEquals(localVal, baseVal);
    final remoteSameAsBase =
        inRemote == inBase && _deepJsonEquals(remoteVal, baseVal);

    if (localSameAsBase && remoteSameAsBase) {
      if (inLocal) result[key] = localVal;
      continue;
    }

    if (localSameAsBase) {
      if (inRemote) result[key] = remoteVal;
    } else if (remoteSameAsBase) {
      if (inLocal) result[key] = localVal;
    } else {
      // Both sides changed from base
      if (inLocal == inRemote && _deepJsonEquals(localVal, remoteVal)) {
        if (inLocal) result[key] = localVal;
      } else {
        // Recurse one level into child maps if applicable
        if (recurseOneLevel && localVal is Map && remoteVal is Map) {
          final subBase = baseVal is Map
              ? Map<String, dynamic>.from(baseVal)
              : <String, dynamic>{};
          final subLocal = Map<String, dynamic>.from(localVal);
          final subRemote = Map<String, dynamic>.from(remoteVal);
          final subMerged = _mergeJsonMaps(
            subBase,
            subLocal,
            subRemote,
            recurseOneLevel: false,
          );
          if (subMerged == null) {
            return null;
          }
          result[key] = subMerged;
        } else {
          return null; // Conflict
        }
      }
    }
  }

  return result;
}

/// Performs a key-wise three-way merge on JSON documents.
///
/// Recurses one level into child objects (e.g. per-device maps in `workspace.json`).
/// Pretty-prints output with two-space indentation and a trailing newline.
MergeOutcome mergeJson(String base, String local, String remote) {
  final Map<String, dynamic> baseMap;
  final Map<String, dynamic> localMap;
  final Map<String, dynamic> remoteMap;

  try {
    final b = json.decode(base);
    final l = json.decode(local);
    final r = json.decode(remote);
    if (b is! Map || l is! Map || r is! Map) {
      return const MergeOutcome.conflict();
    }
    baseMap = Map<String, dynamic>.from(b);
    localMap = Map<String, dynamic>.from(l);
    remoteMap = Map<String, dynamic>.from(r);
  } catch (_) {
    return const MergeOutcome.conflict();
  }

  final merged = _mergeJsonMaps(baseMap, localMap, remoteMap);
  if (merged == null) {
    return const MergeOutcome.conflict();
  }

  const encoder = JsonEncoder.withIndent('  ');
  final output = '${encoder.convert(merged)}\n';
  return MergeOutcome.clean(output);
}
