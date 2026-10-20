// © 2026 Tephra. All rights reserved.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('CaseSensitivity', () {
    test(
      'detects case-insensitive filesystem on MemoryVaultFileSystem',
      () async {
        final fs = MemoryVaultFileSystem(caseInsensitive: true);
        final isCaseInsensitive = await CaseSensitivity.detect(fs);
        expect(isCaseInsensitive, isTrue);

        // Verify probe file was cleaned up
        final probeEntries = await fs.list(
          folder: VaultPath('.tephra/cache'),
          recursive: false,
        );
        expect(probeEntries, isEmpty);
      },
    );

    test(
      'detects case-sensitive filesystem on MemoryVaultFileSystem',
      () async {
        final fs = MemoryVaultFileSystem(caseInsensitive: false);
        final isCaseInsensitive = await CaseSensitivity.detect(fs);
        expect(isCaseInsensitive, isFalse);

        // Verify probe file was cleaned up
        final probeEntries = await fs.list(
          folder: VaultPath('.tephra/cache'),
          recursive: false,
        );
        expect(probeEntries, isEmpty);
      },
    );

    test('caches detection in SyncStateStore meta table', () async {
      final fs = MemoryVaultFileSystem(caseInsensitive: true);
      final store = await SyncStateStore.openMemory();
      addTearDown(store.close);

      expect(await store.getMeta(CaseSensitivity.metaKey), isNull);

      final result1 = await CaseSensitivity.isCaseInsensitive(fs, store);
      expect(result1, isTrue);
      expect(await store.getMeta(CaseSensitivity.metaKey), equals('true'));

      // If store is cached, it does not re-detect unless forceDetect is true
      final storeMock = await SyncStateStore.openMemory();
      addTearDown(storeMock.close);
      await storeMock.setMeta(CaseSensitivity.metaKey, 'false');

      final cachedResult = await CaseSensitivity.isCaseInsensitive(
        fs,
        storeMock,
      );
      expect(cachedResult, isFalse); // returns cached value

      final forceResult = await CaseSensitivity.isCaseInsensitive(
        fs,
        storeMock,
        forceDetect: true,
      );
      expect(forceResult, isTrue); // re-detected
      expect(await storeMock.getMeta(CaseSensitivity.metaKey), equals('true'));
    });
  });
}
