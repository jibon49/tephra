// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/core/headless_config.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('headless_config_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HeadlessConfig', () {
    test('round trip', () async {
      const config = HeadlessConfig(
        version: 1,
        vaultId: 'vault-1234',
        vaultRoot: r'C:\Users\User\Documents\Vault',
        fsKind: 'io',
        stickyFolder: 'Stickies',
        dailyNote: HeadlessDailyNoteConfig(
          folder: 'Daily',
          format: 'YYYY-MM-DD',
          template: 'Templates/Daily.md',
        ),
        quickTarget: 'dailyNote',
        inboxPath: 'Inbox.md',
        deviceName: 'Pixel 8',
      );

      final file = File('${tempDir.path}/headless.json');
      await config.save(file);

      expect(file.existsSync(), isTrue);

      final loaded = await HeadlessConfig.load(file);
      expect(loaded, isNotNull);
      expect(loaded, equals(config));
      expect(loaded!.vaultId, equals('vault-1234'));
      expect(loaded.vaultRoot, equals(r'C:\Users\User\Documents\Vault'));
      expect(loaded.fsKind, equals('io'));
      expect(loaded.stickyFolder, equals('Stickies'));
      expect(loaded.dailyNote.folder, equals('Daily'));
      expect(loaded.dailyNote.format, equals('YYYY-MM-DD'));
      expect(loaded.dailyNote.template, equals('Templates/Daily.md'));
      expect(loaded.quickTarget, equals('dailyNote'));
      expect(loaded.inboxPath, equals('Inbox.md'));
      expect(loaded.deviceName, equals('Pixel 8'));

      // Also test synchronous round-trip
      final syncFile = File('${tempDir.path}/headless_sync.json');
      config.saveSync(syncFile);
      final syncLoaded = HeadlessConfig.loadSync(syncFile);
      expect(syncLoaded, equals(config));
    });

    test('unknown version returns null', () async {
      final json = {
        'v': 99,
        'vaultId': 'v1',
        'vaultRoot': '/path',
        'fsKind': 'io',
        'stickyFolder': 'Stickies',
        'dailyNote': {
          'folder': 'Daily',
          'format': 'YYYY-MM-DD',
          'template': '',
        },
        'quickTarget': 'dailyNote',
        'inboxPath': 'Inbox.md',
        'deviceName': 'Device',
      };

      expect(HeadlessConfig.fromJson(json), isNull);

      final missingV = Map<String, Object?>.from(json)..remove('v');
      expect(HeadlessConfig.fromJson(missingV), isNull);
    });

    test('atomic write leaves no temp file', () async {
      const config = HeadlessConfig(
        version: 1,
        vaultId: 'vault-test',
        vaultRoot: '/data/vault',
        fsKind: 'io',
        stickyFolder: 'Stickies',
        dailyNote: HeadlessDailyNoteConfig(
          folder: 'Daily',
          format: 'YYYY-MM-DD',
          template: '',
        ),
        quickTarget: 'dailyNote',
        inboxPath: 'Inbox.md',
        deviceName: 'TestDevice',
      );

      final file = File('${tempDir.path}/headless.json');
      await config.save(file);

      // Verify the target exists
      expect(file.existsSync(), isTrue);

      // Verify no temporary files remain in directory
      final files = await tempDir.list().toList();
      expect(files.length, equals(1));
      expect(
        p.canonicalize(files.first.path),
        equals(p.canonicalize(file.path)),
      );

      // Overwrite test
      await config.save(file);
      final filesAfterSecondWrite = await tempDir.list().toList();
      expect(filesAfterSecondWrite.length, equals(1));
      expect(
        p.canonicalize(filesAfterSecondWrite.first.path),
        equals(p.canonicalize(file.path)),
      );
    });
  });
}
