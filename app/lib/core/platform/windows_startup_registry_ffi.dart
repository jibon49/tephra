// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:win32_registry/win32_registry.dart';

final _log = Logger('windows_startup');

const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _runValueName = 'Tephra';

bool isWindowsLaunchAtStartupEnabled(String exePath) {
  if (!Platform.isWindows) return false;
  try {
    final key = CURRENT_USER.open(_runKeyPath);
    try {
      final val = key.getString(_runValueName);
      if (val == null) return false;
      final expectedPrefix = '"$exePath"';
      return val.startsWith(expectedPrefix);
    } finally {
      key.close();
    }
  } catch (_) {
    return false;
  }
}

void setWindowsLaunchAtStartup(bool enabled, String exePath) {
  if (!Platform.isWindows) return;
  try {
    final key = CURRENT_USER.create(_runKeyPath);
    try {
      if (enabled) {
        final data = '"$exePath" --autostart';
        key.setValue(_runValueName, RegistryValue.string(data));
      } else {
        try {
          key.removeValue(_runValueName);
        } catch (_) {
          // Ignore not found
        }
      }
    } finally {
      key.close();
    }
  } catch (e, st) {
    _log.warning('Failed to update Run registry key', e, st);
  }
}
