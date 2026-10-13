// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/vault/vault_metadata.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  final clock = ManualClock(DateTime.utc(2026, 10, 11, 9, 30));

  test(
    'missing vault.json creates metadata with UUID and UTC timestamp',
    () async {
      final fs = MemoryVaultFileSystem(clock: clock);
      final meta = await ensureVaultMetadata(fs, clock);

      expect(
        meta.id,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
      expect(meta.createdAt, equals(DateTime.utc(2026, 10, 11, 9, 30)));
      expect(meta.formatVersion, equals(1));

      const store = TephraJsonStore();
      final map = await store.readMap(fs, VaultPath('.tephra/vault.json'));
      expect(map['id'], equals(meta.id));
      expect(map['createdAt'], equals('2026-10-11T09:30:00.000Z'));
      expect(map['formatVersion'], equals(1));
    },
  );

  test('second call returns the same id and writes nothing', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    final meta1 = await ensureVaultMetadata(fs, clock);
    final initialWriteCount = fs.writeCount;

    final meta2 = await ensureVaultMetadata(fs, clock);
    expect(meta2.id, equals(meta1.id));
    expect(meta2.createdAt, equals(meta1.createdAt));
    expect(meta2.formatVersion, equals(meta1.formatVersion));
    expect(fs.writeCount, equals(initialWriteCount));
  });

  test('file with existing keys keeps them and adds id', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    const store = TephraJsonStore();
    await store.writeMap(fs, VaultPath('.tephra/vault.json'), {'foo': 1});

    final meta = await ensureVaultMetadata(fs, clock);
    expect(meta.formatVersion, equals(1));

    final map = await store.readMap(fs, VaultPath('.tephra/vault.json'));
    expect(map['foo'], equals(1));
    expect(map['id'], equals(meta.id));
    expect(map['createdAt'], equals('2026-10-11T09:30:00.000Z'));
  });

  test('formatVersion > 1 throws VaultTooNewException', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    const store = TephraJsonStore();
    await store.writeMap(fs, VaultPath('.tephra/vault.json'), {
      'id': 'v2-vault',
      'formatVersion': 2,
    });

    expect(
      () => ensureVaultMetadata(fs, clock),
      throwsA(
        isA<VaultTooNewException>().having((e) => e.version, 'version', 2),
      ),
    );
  });

  test('invalid JSON creates new metadata and leaves a .bad- copy', () async {
    final fs = MemoryVaultFileSystem(clock: clock);
    await fs.writeText(
      VaultPath('.tephra/vault.json'),
      const TextDocument(text: '{corrupt json'),
    );

    final meta = await ensureVaultMetadata(fs, clock);
    expect(
      meta.id,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );

    // Look for bad file in writeLog
    final badLogEntry = fs.writeLog.firstWhere(
      (path) => RegExp(r'^\.tephra/vault\.json\.bad-\d{14}$').hasMatch(path),
    );
    final badBytes = await fs.readBytes(VaultPath(badLogEntry));
    expect(utf8.decode(badBytes), equals('{corrupt json'));
  });
}
