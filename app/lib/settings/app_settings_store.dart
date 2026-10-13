// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/core/uuid.dart';

import 'app_settings.dart';

/// Store for managing [AppSettings] persistence in `<appSupportDir>/settings.json`.
final class AppSettingsStore {
  AppSettingsStore(this.file, {String Function()? newDeviceId})
    : _newDeviceId = newDeviceId ?? generateUuidV4;

  final AppJsonFile file;
  final String Function() _newDeviceId;
  final _log = Logger('settings');

  /// Loads [AppSettings] from [file].
  ///
  /// Generates a new `deviceId` if absent, and writes the settings file back.
  AppSettings load() {
    final raw = file.readSync();
    var createdId = false;
    final settings = AppSettings.fromJson(
      raw,
      newDeviceId: () {
        createdId = true;
        return _newDeviceId();
      },
    );

    if (createdId || raw.isEmpty) {
      saveSync(settings);
    }
    return settings;
  }

  /// Synchronously writes [settings] to disk.
  void saveSync(AppSettings settings) {
    try {
      final encoded =
          '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n';
      final dir = file.file.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      file.file.writeAsStringSync(encoded);
    } catch (e, st) {
      _log.warning('Failed to sync-save app settings: $e', e, st);
    }
  }

  /// Asynchronously writes [settings] to disk using atomic rename.
  Future<void> save(AppSettings settings) async {
    try {
      await file.write(settings.toJson());
    } catch (e, st) {
      _log.warning('Failed to save app settings: $e', e, st);
    }
  }
}
