// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra_vault/tephra_vault.dart';

// Value copied from docs/spikes/android-storage.md "Phase 1 watcher" (ANDROID_WATCHER in PROGRESS.md): native or polling.
const WatcherMode androidWatcherMode = WatcherMode.native;

/// Factory function creating an [IoVaultFileSystem] with platform-appropriate settings.
VaultFileSystem createVaultFileSystem(
  String rootDir,
  VaultSettings settings, {
  SystemTrash? systemTrash,
}) {
  return IoVaultFileSystem(
    rootDir,
    ignore: VaultIgnore(showHidden: settings.showHidden),
    systemTrash: systemTrash,
    watcherMode: (!kIsWeb && Platform.isAndroid)
        ? androidWatcherMode
        : WatcherMode.native,
  );
}
