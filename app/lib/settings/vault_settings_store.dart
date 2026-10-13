// © 2026 Tephra. All rights reserved.

import 'package:tephra/core/json_file_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import 'vault_settings.dart';

/// Store for reading and persisting [VaultSettings] in `.tephra/settings.json`.
final class VaultSettingsStore {
  VaultSettingsStore(this.fs, {TephraJsonStore? jsonStore})
    : _jsonStore = jsonStore ?? const TephraJsonStore();

  final VaultFileSystem fs;
  final TephraJsonStore _jsonStore;

  static final VaultPath settingsPath = VaultPath('.tephra/settings.json');

  /// Reads [VaultSettings] from `.tephra/settings.json`.
  ///
  /// Returns default settings if missing or empty.
  Future<VaultSettings> load() async {
    final map = await _jsonStore.readMap(fs, settingsPath);
    return VaultSettings.fromJson(map);
  }

  /// Saves [settings] by updating `.tephra/settings.json`, preserving unknown keys.
  Future<void> save(VaultSettings settings) async {
    await _jsonStore.update(fs, settingsPath, (map) {
      final updated = settings.toJson();
      map.addAll(updated);
    });
  }
}
