// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/settings/app_settings.dart';
import 'package:tephra/settings/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_opener.dart';

void main() {
  late Directory tempDir;
  late ProviderContainer container;
  final recordedHooks = <String>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vault_opener_test_');
    recordedHooks.clear();

    container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(deviceId: 'test-device-uuid'),
        ),
        vaultOpenedHooksProvider.overrideWith(
          (ref) => [
            (ref) async {
              recordedHooks.add('hook-executed');
            },
          ],
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('opens a folder, session is set, metadata created, recents updated and hooks called', () async {
    final vaultDir = Directory(p.join(tempDir.path, 'MyTestVault'));
    await vaultDir.create();

    // Use a Provider to get a Ref
    late VaultOpener opener;
    final testProvider = Provider((ref) {
      opener = VaultOpener(ref);
    });
    container.read(testProvider);

    final session = await opener.open(vaultDir.path);
    expect(session.name, equals('MyTestVault'));
    expect(session.rootDir, equals(vaultDir.path));

    // Session is set in vaultSessionProvider
    expect(container.read(vaultSessionProvider), equals(session));

    // .tephra/vault.json exists on disk
    final metaFile = File(p.join(vaultDir.path, '.tephra', 'vault.json'));
    expect(metaFile.existsSync(), isTrue);

    // Recent list has the vault first
    final appSettings = container.read(appSettingsProvider);
    expect(appSettings.recentVaults, isNotEmpty);
    expect(appSettings.recentVaults.first.path, equals(vaultDir.path));
    expect(appSettings.recentVaults.first.name, equals('MyTestVault'));
    expect(appSettings.lastVaultPath, equals(vaultDir.path));

    // Hooks were awaited
    expect(recordedHooks, equals(['hook-executed']));

    // Opening twice keeps the same vaultId
    final session2 = await opener.open(vaultDir.path);
    expect(session2.vaultId, equals(session.vaultId));
  });

  test('opening a missing folder throws VaultOpenException(missing)', () async {
    late VaultOpener opener;
    final testProvider = Provider((ref) {
      opener = VaultOpener(ref);
    });
    container.read(testProvider);

    final missingPath = p.join(tempDir.path, 'NonExistent');
    expect(
      () => opener.open(missingPath),
      throwsA(
        isA<VaultOpenException>().having((e) => e.code, 'code', 'missing'),
      ),
    );
  });

  test('opening a file path throws VaultOpenException(not-a-folder)', () async {
    late VaultOpener opener;
    final testProvider = Provider((ref) {
      opener = VaultOpener(ref);
    });
    container.read(testProvider);

    final filePath = p.join(tempDir.path, 'file.txt');
    await File(filePath).writeAsString('contents');

    expect(
      () => opener.open(filePath),
      throwsA(
        isA<VaultOpenException>().having((e) => e.code, 'code', 'not-a-folder'),
      ),
    );
  });
}
