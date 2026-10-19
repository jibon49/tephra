// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../store/sync_state_store.dart';

/// Detects filesystem case-sensitivity for a vault.
final class CaseSensitivity {
  CaseSensitivity._();

  /// Key used to store case-sensitivity in the sync database `meta` table.
  static const String metaKey = 'caseInsensitive';

  /// Detects whether [fs] is case-insensitive by writing a lower-case probe file
  /// and attempting to stat the upper-case form of the path.
  static Future<bool> detect(VaultFileSystem fs, [Random? random]) async {
    final rand = random ?? Random();
    final hexChars = List.generate(
      8,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();

    final probeName = 'case-probe-$hexChars.tmp';
    final lowerPath = VaultPath('.tephra/cache/$probeName');
    final upperPath = VaultPath('.tephra/cache/${probeName.toUpperCase()}');

    try {
      await fs.writeBytes(lowerPath, const [0]);
      final stat = await fs.stat(upperPath);
      return stat != null;
    } catch (_) {
      return false;
    } finally {
      try {
        await fs.delete(lowerPath, mode: TrashMode.permanent);
      } catch (_) {
        // Ignore deletion failures for temporary probe
      }
    }
  }

  /// Returns the cached case-sensitivity from [store], or detects and saves it.
  static Future<bool> isCaseInsensitive(
    VaultFileSystem fs,
    SyncStateStore store, {
    bool forceDetect = false,
  }) async {
    if (!forceDetect) {
      final cached = await store.getMeta(metaKey);
      if (cached != null) {
        return cached == 'true';
      }
    }

    final detected = await detect(fs);
    await store.setMeta(metaKey, detected.toString());
    return detected;
  }
}
