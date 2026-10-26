// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';

/// Computes a stable, non-negative 31-bit integer identifier for a reminder
/// using FNV-1a 32-bit over UTF-8 encoded `'$vaultId\n${path.value}'`.
int reminderId(String vaultId, VaultPath path) {
  final bytes = utf8.encode('$vaultId\n${path.value}');
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
