// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/capture/capture_service.dart';
import 'package:tephra/capture/providers.dart';
import 'package:tephra/capture/share_intake.dart';
import 'package:tephra/core/platform/share_intent_service.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/editor/attachment_service.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_tools/daily_notes_service.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CaptureService', () {
    late MemoryVaultFileSystem fs;
    late VaultSettings vaultSettings;
    late ManualClock testClock;
    late DailyNotesService dailyNotesService;
    late AttachmentService attachmentService;
    late ProviderContainer container;
    late CaptureService captureService;

    setUp(() {
      fs = MemoryVaultFileSystem();
      vaultSettings = const VaultSettings();
      testClock = ManualClock(DateTime(2026, 10, 26, 14, 30));

      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/vault',
        name: 'Test Vault',
        fs: fs,
        settings: vaultSettings,
      );

      container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => FixedVaultSessionNotifier(session),
          ),
          clockProvider.overrideWithValue(testClock),
        ],
      );

      dailyNotesService = DailyNotesService(
        fs: fs,
        index: () => null,
        getSettings: () => container.read(vaultSettingsProvider),
        clock: testClock,
        openNote: (path, {newTab = false}) async {},
      );

      attachmentService = container.read(attachmentServiceProvider);

      captureService = CaptureService(
        fs: fs,
        dailyNotesService: dailyNotesService,
        attachmentService: attachmentService,
        getVaultSettings: () => container.read(vaultSettingsProvider),
        clock: testClock,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'append to existing daily note keeps previous bytes (prefix identical)',
      () async {
        final dailyPath = dailyNotesService.pathFor(testClock.now());
        const initialText = '# Daily Note\n\nMorning reflections and tasks\n';
        await fs.writeText(dailyPath, const TextDocument(text: initialText));

        const draft = CaptureDraft(
          text: 'Afternoon quick capture note',
          files: [],
        );

        final resultPath = await captureService.appendToDailyNote(draft);
        expect(resultPath, dailyPath);

        final updatedDoc = await fs.readText(dailyPath);
        final updatedText = updatedDoc.text;

        expect(updatedText.startsWith(initialText), isTrue);
        expect(
          updatedText,
          '$initialText- 14:30 Afternoon quick capture note\n',
        );
      },
    );

    test('creates daily note from template when missing', () async {
      container
          .read(vaultSettingsProvider.notifier)
          .update(
            (s) => s.copyWith(
              dailyNotes: const {'template': 'Templates/Daily.md'},
            ),
          );

      await fs.createFolder(VaultPath('Templates'));
      await fs.writeText(
        VaultPath('Templates/Daily.md'),
        const TextDocument(text: '# Daily: {{title}}\n\n*Log*\n'),
      );

      final dailyPath = dailyNotesService.pathFor(testClock.now());
      expect(await fs.stat(dailyPath), isNull);

      const draft = CaptureDraft(
        text: 'First captured item of the day',
        files: [],
      );

      final resultPath = await captureService.appendToDailyNote(draft);
      expect(resultPath, dailyPath);

      final doc = await fs.readText(dailyPath);
      expect(doc.text.contains('# Daily: 2026-10-26'), isTrue);
      expect(
        doc.text.contains('- 14:30 First captured item of the day'),
        isTrue,
      );
    });

    test('new note name collision adds suffix', () async {
      await fs.writeText(
        VaultPath('Captured.md'),
        const TextDocument(text: 'First'),
      );
      await fs.writeText(
        VaultPath('Captured 1.md'),
        const TextDocument(text: 'Second'),
      );

      const draft = CaptureDraft(
        title: 'Captured',
        text: 'Third entry content',
        files: [],
      );

      final savedPath = await captureService.saveAsNewNote(draft);
      expect(savedPath, VaultPath('Captured 2.md'));

      final doc = await fs.readText(savedPath);
      expect(doc.text, 'Third entry content\n');
    });

    test('attachment embed lines added', () async {
      // PNG header bytes
      final dummyPngBytes = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
      ];
      final files = [
        SharedFile(
          path: '/temp/snapshot.png',
          mimeType: 'image/png',
          bytes: dummyPngBytes,
        ),
      ];

      final draft = CaptureDraft(
        title: 'Photo Note',
        text: 'Look at this screenshot',
        files: files,
      );

      final savedPath = await captureService.saveAsNewNote(draft);
      final doc = await fs.readText(savedPath);

      expect(doc.text.contains('Look at this screenshot'), isTrue);
      expect(doc.text.contains('![[Pasted image 20261026143000.png]]'), isTrue);
    });

    test('inbox created when missing', () async {
      final inboxPath = VaultPath('Inbox.md');
      expect(await fs.stat(inboxPath), isNull);

      const draft = CaptureDraft(
        text: 'Buy groceries on the way home',
        files: [],
      );

      final resultPath = await captureService.appendToInbox(draft);
      expect(resultPath, inboxPath);
      expect(await fs.stat(inboxPath), isNotNull);

      final doc = await fs.readText(inboxPath);
      expect(doc.text, '- 14:30 Buy groceries on the way home\n');
    });
  });
}
