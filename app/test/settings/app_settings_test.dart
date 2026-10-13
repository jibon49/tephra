// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/app_settings_store.dart';

void main() {
  group('AppSettings', () {
    test('fromJson({}) generates a device id using callback', () {
      var counter = 0;
      final settings = AppSettings.fromJson(
        {},
        newDeviceId: () {
          counter++;
          return 'device-uuid-$counter';
        },
      );
      expect(counter, equals(1));
      expect(settings.deviceId, equals('device-uuid-1'));
      expect(settings.themeMode, equals('system'));
      expect(settings.recentVaults, isEmpty);
    });

    test('unknown keys round-trip in extra', () {
      final json = {
        'deviceId': 'my-id',
        'themeMode': 'dark',
        'customFeature': true,
        'nested': {'foo': 'bar'},
      };
      final settings = AppSettings.fromJson(json, newDeviceId: () => 'never');
      expect(settings.extra['customFeature'], isTrue);
      expect(settings.extra['nested'], equals({'foo': 'bar'}));

      final exported = settings.toJson();
      expect(exported['customFeature'], isTrue);
      expect(exported['nested'], equals({'foo': 'bar'}));
    });

    test('addRecentVault moves existing path to front and enforces max 12', () {
      var s = const AppSettings(deviceId: 'test');
      for (var i = 0; i < 15; i++) {
        s = s.addRecentVault('/path/$i', 'Vault $i');
      }

      expect(s.recentVaults.length, equals(12));
      expect(s.recentVaults.first.path, equals('/path/14'));
      expect(s.lastVaultPath, equals('/path/14'));

      // Re-add /path/5 -> should move to front
      s = s.addRecentVault('/path/5', 'Vault 5 re-opened');
      expect(s.recentVaults.first.path, equals('/path/5'));
      expect(s.recentVaults.first.name, equals('Vault 5 re-opened'));
      expect(s.recentVaults.length, equals(12));
    });

    test('touchCommand keeps 10 newest unique', () {
      var s = const AppSettings(deviceId: 'test');
      for (var i = 0; i < 15; i++) {
        s = s.touchCommand('cmd-$i');
      }

      expect(s.recentCommands.length, equals(10));
      expect(s.recentCommands.first, equals('cmd-14'));

      // Touch existing command cmd-5 -> moves to front
      s = s.touchCommand('cmd-5');
      expect(s.recentCommands.first, equals('cmd-5'));
      expect(s.recentCommands.where((c) => c == 'cmd-5').length, equals(1));
      expect(s.recentCommands.length, equals(10));
    });
  });

  group('AppSettingsStore', () {
    late Directory tempDir;
    late File file;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('app_settings_store_');
      file = File('${tempDir.path}/settings.json');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('load() on a missing file creates the file with a deviceId', () {
      expect(file.existsSync(), isFalse);

      final store = AppSettingsStore(
        AppJsonFile(file),
        newDeviceId: () => 'fixed-test-uuid',
      );
      final loaded = store.load();

      expect(loaded.deviceId, equals('fixed-test-uuid'));
      expect(file.existsSync(), isTrue);

      final reloaded = store.load();
      expect(reloaded.deviceId, equals('fixed-test-uuid'));
    });
  });
}
