// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/providers.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_tools/daily_notes_service.dart';
import 'package:tephra/vault/note_tools/exceptions.dart';
import 'package:tephra/vault/note_tools/providers.dart';
import 'package:tephra/vault/providers.dart';
import 'package:tephra/vault/vault_session.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class _TrackingFs implements VaultFileSystem {
  _TrackingFs(this.inner);
  final VaultFileSystem inner;
  int writeCount = 0;

  @override
  String get rootDisplayPath => inner.rootDisplayPath;

  @override
  Future<List<VaultEntry>> list({
    VaultPath folder = VaultPath.root,
    bool recursive = true,
  }) => inner.list(folder: folder, recursive: recursive);

  @override
  Future<VaultEntry?> stat(VaultPath path) => inner.stat(path);

  @override
  Future<List<int>> readBytes(VaultPath path) => inner.readBytes(path);

  @override
  Future<TextDocument> readText(VaultPath path) => inner.readText(path);

  @override
  Future<void> writeBytes(VaultPath path, List<int> bytes) {
    writeCount++;
    return inner.writeBytes(path, bytes);
  }

  @override
  Future<void> writeText(VaultPath path, TextDocument doc) {
    writeCount++;
    return inner.writeText(path, doc);
  }

  @override
  Future<void> createFolder(VaultPath path) => inner.createFolder(path);

  @override
  Future<void> move(VaultPath from, VaultPath to) => inner.move(from, to);

  @override
  Future<void> delete(
    VaultPath path, {
    TrashMode mode = TrashMode.vaultTrash,
  }) => inner.delete(path, mode: mode);

  @override
  Stream<VaultChange> watch() => inner.watch();

  @override
  Future<void> dispose() => inner.dispose();
}

class _FixedClock implements Clock {
  const _FixedClock(this._fixed);
  final DateTime _fixed;
  @override
  DateTime now() => _fixed;
}

class _FakeNoteIndexNotifier extends NoteIndexNotifier {
  _FakeNoteIndexNotifier(this.index);
  final NoteIndex index;
  @override
  Future<NoteIndex> build() async => index;
}

class _FixedSessionNotifier extends VaultSessionNotifier {
  _FixedSessionNotifier(this.initialSession);
  final VaultSession initialSession;
  @override
  VaultSession? build() => initialSession;
}

void main() {
  group('DailyNotesService', () {
    late MemoryVaultFileSystem memoryFs;
    late _TrackingFs fs;
    late NoteIndex index;
    late VaultSettings settings;
    final fixedDate = DateTime(2026, 10, 15, 14, 30);
    final clock = _FixedClock(fixedDate);
    final openedPaths = <VaultPath>[];
    final snackbars = <String>[];

    setUp(() async {
      memoryFs = MemoryVaultFileSystem();
      fs = _TrackingFs(memoryFs);
      index = await NoteIndex.open(':memory:', fs);
      openedPaths.clear();
      snackbars.clear();
      settings = const VaultSettings(
        dailyNotes: {'format': 'YYYY-MM-DD', 'folder': 'Daily', 'template': ''},
        templates: {'dateFormat': 'YYYY-MM-DD', 'timeFormat': 'HH:mm'},
      );
    });

    tearDown(() async {
      await index.close();
      await fs.dispose();
    });

    DailyNotesService createService() {
      return DailyNotesService(
        fs: fs,
        index: () => index,
        getSettings: () => settings,
        clock: clock,
        openNote: (p, {newTab = false}) async {
          openedPaths.add(p);
        },
        showSnackbar: (msg) {
          snackbars.add(msg);
        },
      );
    }

    test(
      'openOrCreate on empty creates file using format and opens in editor tab',
      () async {
        final service = createService();
        final targetDate = DateTime(2026, 10, 15);
        final path = await service.openOrCreate(targetDate);

        expect(path.value, 'Daily/2026-10-15.md');
        expect(openedPaths, [VaultPath('Daily/2026-10-15.md')]);
        expect(fs.writeCount, 1);
        final stat = await fs.stat(path);
        expect(stat, isNotNull);
      },
    );

    test(
      'openOrCreate on existing note opens it with ZERO file writes',
      () async {
        final targetDate = DateTime(2026, 10, 15);
        final expectedPath = VaultPath('Daily/2026-10-15.md');
        await memoryFs.writeText(
          expectedPath,
          const TextDocument(text: 'existing daily content'),
        );

        final service = createService();
        final path = await service.openOrCreate(targetDate);

        expect(path, expectedPath);
        expect(openedPaths, [expectedPath]);
        expect(fs.writeCount, 0); // ZERO writes!
      },
    );

    test('openOrCreate with template inserts processed template', () async {
      final tmplPath = VaultPath('Templates/DailyTmpl.md');
      await memoryFs.writeText(
        tmplPath,
        const TextDocument(
          text: '# {{title}}\nCreated on {{date}} at {{time}}',
        ),
      );
      await index.rebuild();

      settings = settings.copyWith(
        dailyNotes: {
          'format': 'YYYY-MM-DD',
          'folder': 'Daily',
          'template': 'Templates/DailyTmpl',
        },
      );

      final service = createService();
      final targetDate = DateTime(2026, 10, 15);
      final path = await service.openOrCreate(targetDate);

      final doc = await fs.readText(path);
      expect(doc.text, '# 2026-10-15\nCreated on 2026-10-15 at 14:30');
    });

    test('openOrCreate with missing template creates empty file, notifies snackbar, does not crash', () async {
      settings = settings.copyWith(
        dailyNotes: {
          'format': 'YYYY-MM-DD',
          'folder': 'Daily',
          'template': 'Templates/DoesNotExist',
        },
      );

      final service = createService();
      final targetDate = DateTime(2026, 10, 15);
      final path = await service.openOrCreate(targetDate);

      expect(path.value, 'Daily/2026-10-15.md');
      expect(snackbars, contains('dailyTemplateMissing'));
      final doc = await fs.readText(path);
      expect(doc.text, '');
    });

    test('throws DailyNotesConfigException on invalid format', () async {
      settings = settings.copyWith(
        dailyNotes: {'format': 'invalid/slash/date', 'folder': 'Daily'},
      );
      final service = createService();
      expect(
        () => service.openOrCreate(DateTime(2026, 10, 15)),
        throwsA(isA<DailyNotesConfigException>()),
      );
    });

    test(
      'dateOfPath returns date for valid note in folder, null otherwise',
      () {
        final service = createService();

        expect(
          service.dateOfPath(VaultPath('Daily/2026-10-15.md')),
          DateTime(2026, 10, 15),
        );
        // Outside configured folder
        expect(service.dateOfPath(VaultPath('Other/2026-10-15.md')), isNull);
        // Non-md file
        expect(service.dateOfPath(VaultPath('Daily/2026-10-15.png')), isNull);
        // Does not match format
        expect(service.dateOfPath(VaultPath('Daily/not-a-date.md')), isNull);
      },
    );

    test('neighbour returns previous and next notes by date, ignoring invalid files', () async {
      final p1 = VaultPath('Daily/2026-10-10.md');
      final p2 = VaultPath('Daily/2026-10-15.md');
      final p3 = VaultPath('Daily/2026-10-20.md');
      final pInvalid = VaultPath('Daily/invalid.md');
      final pOther = VaultPath('Other/2026-10-12.md');

      for (final p in [p1, p2, p3, pInvalid, pOther]) {
        await memoryFs.writeText(p, const TextDocument(text: 'x'));
      }
      await index.rebuild();

      final service = createService();

      final prev = await service.neighbour(p2, previous: true);
      expect(prev, p1);

      final next = await service.neighbour(p2, previous: false);
      expect(next, p3);

      final beforeFirst = await service.neighbour(p1, previous: true);
      expect(beforeFirst, isNull);

      final afterLast = await service.neighbour(p3, previous: false);
      expect(afterLast, isNull);
    });
  });

  group('dailyStartupProvider', () {
    test('runs openOrCreate once when openOnStartup is true, does not run when false', () async {
      final memoryFs = MemoryVaultFileSystem();
      final index = await NoteIndex.open(':memory:', memoryFs);
      final clock = _FixedClock(DateTime(2026, 10, 15));

      var openedCount = 0;
      final session = VaultSession(
        vaultId: 'test-vault',
        rootDir: '/memory',
        name: 'Test',
        fs: memoryFs,
        settings: const VaultSettings(
          dailyNotes: {
            'format': 'YYYY-MM-DD',
            'folder': 'Daily',
            'openOnStartup': true,
          },
          corePlugins: {'dailyNotes': true},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session),
          ),
          clockProvider.overrideWithValue(clock),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          dailyNotesServiceProvider.overrideWith(
            (ref) => DailyNotesService(
              fs: memoryFs,
              index: () => index,
              getSettings: () => ref.watch(vaultSettingsProvider),
              clock: clock,
              openNote: (p, {newTab = false}) async {
                openedCount++;
              },
            ),
          ),
        ],
      );

      final runner = container.read(dailyStartupProvider);
      await runner.run();
      expect(openedCount, 1);

      // Second run in same session should NOT re-run
      await runner.run();
      expect(openedCount, 1);

      // Verify when openOnStartup is false
      final session2 = VaultSession(
        vaultId: 'test-vault-2',
        rootDir: '/memory',
        name: 'Test 2',
        fs: memoryFs,
        settings: const VaultSettings(
          dailyNotes: {
            'format': 'YYYY-MM-DD',
            'folder': 'Daily',
            'openOnStartup': false,
          },
          corePlugins: {'dailyNotes': true},
        ),
      );

      final container2 = ProviderContainer(
        overrides: [
          vaultSessionProvider.overrideWith(
            () => _FixedSessionNotifier(session2),
          ),
          clockProvider.overrideWithValue(clock),
          noteIndexProvider.overrideWith(() => _FakeNoteIndexNotifier(index)),
          dailyNotesServiceProvider.overrideWith(
            (ref) => DailyNotesService(
              fs: memoryFs,
              index: () => index,
              getSettings: () => ref.watch(vaultSettingsProvider),
              clock: clock,
              openNote: (p, {newTab = false}) async {
                openedCount++;
              },
            ),
          ),
        ],
      );
      final runner2 = container2.read(dailyStartupProvider);
      await runner2.run();
      expect(openedCount, 1); // Still 1

      await index.close();
      await memoryFs.dispose();
      container.dispose();
      container2.dispose();
    });
  });
}
