// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_sync/tephra_sync.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

import 'invariants.dart';
import 'sim_world.dart';

void main() {
  group('Simulator Scenarios (PHASE_PLAN demo sequences)', () {
    late SimWorld world;

    setUp(() async {
      world = await SimWorld.create(42);
    });

    tearDown(() async {
      await world.close();
    });

    test('offline edit on A + different paragraph on B -> clean merge', () async {
      final devA = world.devices[0]; // Pixel 8
      final devB = world.devices[1]; // Desktop PC

      final path = VaultPath('article.md');
      final baseText =
          '# Article\n\nParagraph 1: initial text.\n\nParagraph 2: middle text.\n\nParagraph 3: ending text.\n';
      await devA.fs.writeBytes(path, utf8.encode(baseText));

      // Initial sync
      await world.syncDevice(devA);
      await world.syncDevice(devB);

      // B goes offline
      devB.offlineSwitch.isOnline = false;

      // A edits top paragraph while B is offline
      final textA =
          '# Article\n\nParagraph 1: edited by A.\n\nParagraph 2: middle text.\n\nParagraph 3: ending text.\n';
      await devA.fs.writeBytes(path, utf8.encode(textA));
      await world.syncDevice(devA);

      // B edits bottom paragraph while offline
      final textB =
          '# Article\n\nParagraph 1: initial text.\n\nParagraph 2: middle text.\n\nParagraph 3: edited by B.\n';
      await devB.fs.writeBytes(path, utf8.encode(textB));

      // B comes back online and syncs
      devB.offlineSwitch.isOnline = true;
      final reportB = await devB.syncOnce();
      expect(reportB?.merged, equals(1));

      // Complete full convergence
      await world.convergeAll();

      await SimulatorInvariants.checkNoLoss(
        mustSurvive: world.mustSurvive,
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );
      await SimulatorInvariants.checkConvergence(
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );

      final mergedText = utf8.decode(await devA.fs.readBytes(path));
      expect(mergedText, contains('Paragraph 1: edited by A.'));
      expect(mergedText, contains('Paragraph 3: edited by B.'));
    });

    test(
      'same line -> conflict copy on the right device with the right name',
      () async {
        final devA = world.devices[0];
        final devB = world.devices[1];

        final path = VaultPath('shared.md');
        final baseText = '# Shared Note\nLine to be edited concurrently.\n';
        await devA.fs.writeBytes(path, utf8.encode(baseText));

        await world.syncDevice(devA);
        await world.syncDevice(devB);

        // B goes offline
        devB.offlineSwitch.isOnline = false;

        // A edits line 2 and publishes
        final textA = '# Shared Note\nLine edited by Device A.\n';
        await devA.fs.writeBytes(path, utf8.encode(textA));
        await world.syncDevice(devA);

        // B edits line 2 concurrently
        final textB = '# Shared Note\nLine edited by Device B.\n';
        await devB.fs.writeBytes(path, utf8.encode(textB));

        // B comes online and syncs -> conflict copy created
        devB.offlineSwitch.isOnline = true;
        final reportB = await devB.syncOnce();
        expect(reportB?.conflicts, equals(1));

        // Check conflict copy name on B
        final filesB = await devB.fs.list();
        final conflictFile = filesB.firstWhere(
          (f) =>
              f.path.value.contains('(conflict') &&
              f.path.value.contains(devB.identity.deviceName),
        );
        expect(conflictFile, isNotNull);

        await world.convergeAll();

        await SimulatorInvariants.checkNoLoss(
          mustSurvive: world.mustSurvive,
          devices: world.devices,
          provider: world.provider,
          cipher: world.cipher,
        );
        await SimulatorInvariants.checkConvergence(
          devices: world.devices,
          provider: world.provider,
          cipher: world.cipher,
        );
      },
    );

    test('delete on A while B edits -> file kept', () async {
      final devA = world.devices[0];
      final devB = world.devices[1];

      final path = VaultPath('keep_me.md');
      await devA.fs.writeBytes(
        path,
        utf8.encode('Original content to preserve.'),
      );

      await world.syncDevice(devA);
      await world.syncDevice(devB);

      // B goes offline
      devB.offlineSwitch.isOnline = false;

      // A deletes file and syncs
      await devA.fs.delete(path, mode: TrashMode.vaultTrash);
      final reportA = await devA.syncOnce();
      expect(reportA?.deletedRemote, equals(1));

      // B edits file while offline
      await devB.fs.writeBytes(
        path,
        utf8.encode('Preserved edits by Device B.'),
      );

      // B goes online and syncs -> edit wins over delete
      devB.offlineSwitch.isOnline = true;
      final reportB = await devB.syncOnce();
      expect(reportB?.uploaded, equals(1));

      await world.convergeAll();

      await SimulatorInvariants.checkNoLoss(
        mustSurvive: world.mustSurvive,
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );
      await SimulatorInvariants.checkConvergence(
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );

      // Verify file is restored on all devices
      for (final dev in world.devices) {
        expect(await dev.fs.stat(path), isNotNull);
        final content = utf8.decode(await dev.fs.readBytes(path));
        expect(content, equals('Preserved edits by Device B.'));
      }
    });

    test('rename on A while B edits -> edit follows the file', () async {
      final devA = world.devices[0];
      final devB = world.devices[1];

      final oldPath = VaultPath('docs/old_name.md');
      final newPath = VaultPath('docs/new_name.md');
      await devA.fs.writeBytes(
        oldPath,
        utf8.encode('Original content in old path.\n'),
      );

      await world.syncDevice(devA);
      await world.syncDevice(devB);

      // B goes offline
      devB.offlineSwitch.isOnline = false;

      // A renames file and syncs
      await devA.fs.move(oldPath, newPath);
      await world.syncDevice(devA);

      // B edits old_name.md while offline
      await devB.fs.writeBytes(
        oldPath,
        utf8.encode('Original content in old path.\nAppended edit from B.\n'),
      );

      // B goes online and syncs
      devB.offlineSwitch.isOnline = true;
      await world.syncDevice(devB);

      await world.convergeAll();

      await SimulatorInvariants.checkNoLoss(
        mustSurvive: world.mustSurvive,
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );
      await SimulatorInvariants.checkConvergence(
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );

      for (final dev in world.devices) {
        expect(await dev.fs.stat(oldPath), isNull);
        expect(await dev.fs.stat(newPath), isNotNull);
        final content = utf8.decode(await dev.fs.readBytes(newPath));
        expect(content, contains('Appended edit from B.'));
      }
    });

    test(
      'Android Note.md + note.md reaching B -> note (case conflict).md for all',
      () async {
        final devA = world.devices[0]; // Android (case-sensitive)
        final devB = world.devices[1]; // Windows (case-insensitive)

        final pathLower = VaultPath('casing_test.md');
        final pathUpper = VaultPath('Casing_test.md');

        await devA.fs.writeBytes(pathLower, utf8.encode('Lower case content'));
        await devA.fs.writeBytes(pathUpper, utf8.encode('Upper case content'));

        // Publish both from Android
        await devA.syncOnce();

        // Windows device B syncs -> detects case conflict and resolves
        await devB.syncOnce();

        await devA.syncOnce();

        await world.convergeAll();

        await SimulatorInvariants.checkNoLoss(
          mustSurvive: world.mustSurvive,
          devices: world.devices,
          provider: world.provider,
          cipher: world.cipher,
        );
        await SimulatorInvariants.checkConvergence(
          devices: world.devices,
          provider: world.provider,
          cipher: world.cipher,
        );

        // Check that one of the files has '(case conflict)' in name
        final files = await devA.fs.list();
        final hasCaseConflict = files.any(
          (f) => f.path.value.contains('(case conflict)'),
        );
        expect(hasCaseConflict, isTrue);
      },
    );

    test('60 deletes -> held, then approved', () async {
      final devA = world.devices[0];
      final devB = world.devices[1];

      // Create 60 notes on A
      for (var i = 0; i < 60; i++) {
        await devA.fs.writeBytes(
          VaultPath('batch_note_$i.md'),
          utf8.encode('Batch content $i'),
        );
      }

      await world.syncDevice(devA);
      await world.syncDevice(devB);

      // A deletes all 60 notes
      for (var i = 0; i < 60; i++) {
        await devA.fs.delete(
          VaultPath('batch_note_$i.md'),
          mode: TrashMode.vaultTrash,
        );
      }

      // Sync on A -> delete guard holds deletes
      final reportA = await devA.syncOnce();
      expect(reportA?.heldDeletes, equals(60));
      expect(reportA?.deletedRemote, equals(0));

      // Approve held deletes on A
      await devA.approveHeldDeletes();
      final reportA2 = await devA.syncOnce();
      expect(reportA2?.deletedRemote, equals(60));

      // B syncs -> delete guard holds deletes on B
      final reportB1 = await devB.syncOnce();
      expect(reportB1?.heldDeletes, equals(60));
      expect(reportB1?.deletedLocal, equals(0));

      // Approve held deletes on B
      await devB.approveHeldDeletes();
      final reportB2 = await devB.syncOnce();
      expect(reportB2?.deletedLocal, equals(60));

      await world.convergeAll();

      await SimulatorInvariants.checkNoLoss(
        mustSurvive: world.mustSurvive,
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );
      await SimulatorInvariants.checkConvergence(
        devices: world.devices,
        provider: world.provider,
        cipher: world.cipher,
      );
    });

    test('device clone -> new device id, no loss', () async {
      final devA = world.devices[0];
      final path = VaultPath('clone_test.md');
      await devA.fs.writeBytes(path, utf8.encode('Content before clone'));
      await world.syncDevice(devA);

      // Simulate a cloned device with devA's deviceId publishing a batch remotely
      final nextSeq = int.parse(await devA.store.getMeta('nextSeq') ?? '1');
      final cloneData = utf8.encode('clone data');
      final clonePlainHash = contentHash(cloneData);
      final sealedBlob = await world.cipher.seal(cloneData, ObjectPurpose.blob);
      final blobKey = RemoteLayout.blob(contentHash(sealedBlob));
      await world.provider.put(blobKey, sealedBlob);

      final fakeCloneBatch = JournalBatch(
        deviceId: devA.identity.deviceId,
        firstSeq: nextSeq,
        lastSeq: nextSeq,
        createdAt: DateTime.utc(2026, 10, 15, 14, 0),
        entries: [
          JournalEntry(
            entryId: '${devA.identity.deviceId}:$nextSeq',
            deviceId: devA.identity.deviceId,
            op: 'put',
            path: 'clone_foreign_file.md',
            seq: nextSeq,
            hlc: '20261015T140000.000Z-000001-${devA.identity.deviceId}',
            time: DateTime.utc(2026, 10, 15, 14, 0).millisecondsSinceEpoch,
            hash: clonePlainHash,
            size: cloneData.length,
            parent: null,
            blobKeys: [blobKey],
          ),
        ],
      );

      final key = RemoteLayout.journal(devA.identity.deviceId, nextSeq);
      final jsonBytes = utf8.encode(jsonEncode(fakeCloneBatch.toJson()));
      final sealed = await world.cipher.seal(jsonBytes, ObjectPurpose.journal);
      await world.provider.put(key, sealed);

      // devA runs syncOnce() -> clone detection recovers with new device ID
      final report = await devA.syncOnce();
      expect(report, isNotNull);

      // Verify devA deviceId has been renewed
      expect(devA.identity.deviceId, isNot(equals(fakeCloneBatch.deviceId)));

      // File is still intact locally
      expect(await devA.fs.stat(path), isNotNull);
    });
  });
}
