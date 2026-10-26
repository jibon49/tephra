// © 2026 Tephra. All rights reserved.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/headless_config.dart';
import 'package:tephra/stickies/android/overlay_protocol.dart';
import 'package:tephra/stickies/android/overlay_writer.dart';
import 'package:tephra/stickies/android/widget_data.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  group('OverlayWriterFallback', () {
    late MemoryVaultFileSystem fs;
    const headlessConfig = HeadlessConfig(
      vaultId: 'vault-1',
      vaultRoot: 'mock-root',
      fsKind: 'io',
      stickyFolder: 'Stickies',
      dailyNote: HeadlessDailyNoteConfig(
        folder: 'Daily',
        format: 'YYYY-MM-DD',
        template: '',
      ),
      quickTarget: 'dailyNote',
      inboxPath: 'Inbox.md',
      deviceName: 'Pixel 8',
    );

    setUp(() {
      fs = MemoryVaultFileSystem();
    });

    test('no ack within timeout writes via StickyFileWriter', () async {
      final path = VaultPath('Stickies/TestNote.md');
      const initialText = '# Title\nFirst line of note\n';
      await fs.writeText(path, const TextDocument(text: initialText));
      final baseHash = stickyProtocolHash(initialText);

      final sentMessages = <OverlayMessage>[];
      final writer = OverlayWriterFallback(
        sendToMain: (msg) async => sentMessages.add(msg),
        fsFactory: (_) => fs,
        headlessConfigReader: () async => headlessConfig,
        ackTimeout: const Duration(milliseconds: 1500),
      );

      OverlaySaveStatus? resultStatus;
      fakeAsync((async) {
        writer
            .sendEdit(
              path: path,
              text: '# Title\nEdited offline in bubble\n',
              baseHash: baseHash,
            )
            .then((s) => resultStatus = s);

        expect(sentMessages, hasLength(1));
        expect(sentMessages.first, isA<OverlayContentChangedMessage>());
        expect(resultStatus, isNull);

        // Before timeout, nothing written to disk yet
        async.elapse(const Duration(milliseconds: 1000));
        async.flushMicrotasks();
        expect(resultStatus, isNull);

        // After 1500ms timeout, headless fallback writes directly to disk
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        expect(resultStatus, equals(OverlaySaveStatus.savedFallback));

        writer.dispose();
      });

      final doc = await fs.readText(path);
      expect(doc.text, equals('# Title\nEdited offline in bubble\n'));
    });

    test('hash mismatch writes conflict copy', () async {
      final path = VaultPath('Stickies/TestNote.md');
      const diskText = '# Title\nModified by PC\n';
      await fs.writeText(path, const TextDocument(text: diskText));

      // Stale base hash from an older revision
      final staleBaseHash = stickyProtocolHash('# Title\nOld local note\n');

      final writer = OverlayWriterFallback(
        sendToMain: (msg) async {},
        fsFactory: (_) => fs,
        headlessConfigReader: () async => headlessConfig,
        conflictNamer: (p) => VaultPath('${p.stem} (Conflict).md'),
        ackTimeout: const Duration(milliseconds: 1500),
      );

      OverlaySaveStatus? resultStatus;
      fakeAsync((async) {
        writer
            .sendEdit(
              path: path,
              text: '# Title\nLocal bubble change\n',
              baseHash: staleBaseHash,
            )
            .then((s) => resultStatus = s);

        async.elapse(const Duration(milliseconds: 1600));
        async.flushMicrotasks();
        expect(resultStatus, equals(OverlaySaveStatus.savedConflictFallback));

        writer.dispose();
      });

      // Original note was not overwritten
      final original = await fs.readText(path);
      expect(original.text, equals(diskText));

      // Conflict copy holds local bubble text
      final conflictPath = VaultPath('TestNote (Conflict).md');
      final conflictDoc = await fs.readText(conflictPath);
      expect(conflictDoc.text, equals('# Title\nLocal bubble change\n'));
    });

    test(
      'ack within timeout completes savedViaMain without disk fallback',
      () async {
        final path = VaultPath('Stickies/TestNote.md');
        const initialText = 'Hello\n';
        await fs.writeText(path, const TextDocument(text: initialText));
        final baseHash = stickyProtocolHash(initialText);

        final writer = OverlayWriterFallback(
          sendToMain: (msg) async {},
          fsFactory: (_) => fs,
          headlessConfigReader: () async => headlessConfig,
          ackTimeout: const Duration(milliseconds: 1500),
        );

        OverlaySaveStatus? resultStatus;
        fakeAsync((async) {
          writer
              .sendEdit(path: path, text: 'Hello World\n', baseHash: baseHash)
              .then((s) => resultStatus = s);

          async.elapse(const Duration(milliseconds: 500));
          expect(resultStatus, isNull);

          // Ack received
          writer.onAckReceived(path.value, stickyProtocolHash('Hello World\n'));
          async.flushMicrotasks();

          expect(resultStatus, equals(OverlaySaveStatus.savedViaMain));

          // Let remaining time pass to ensure timer was cancelled and no disk fallback ran
          async.elapse(const Duration(milliseconds: 2000));
          async.flushMicrotasks();

          writer.dispose();
        });

        final doc = await fs.readText(path);
        expect(doc.text, equals(initialText));
      },
    );
  });
}
