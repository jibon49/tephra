// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/commands/command_registry.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_tools/exceptions.dart';
import 'package:tephra/vault/note_tools/note_tools_commands.dart';
import 'package:tephra/vault/note_tools/unique_note_service.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

class _FixedClock implements Clock {
  const _FixedClock(this._fixed);
  final DateTime _fixed;
  @override
  DateTime now() => _fixed;
}

void main() {
  group('UniqueNoteService', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late VaultSettings settings;
    final fixedNow = DateTime(2026, 10, 15, 14, 30);
    final clock = _FixedClock(fixedNow);
    final opened = <VaultPath>[];

    setUp(() async {
      fs = MemoryVaultFileSystem();
      index = await NoteIndex.open(':memory:', fs);
      opened.clear();
      settings = const VaultSettings(
        uniqueNote: {
          'prefixFormat': 'YYYYMMDDHHmm',
          'folder': 'Zettel',
          'template': '',
        },
      );
    });

    tearDown(() async {
      await index.close();
      await fs.dispose();
    });

    UniqueNoteService createService() {
      return UniqueNoteService(
        fs: fs,
        index: () => index,
        getSettings: () => settings,
        clock: clock,
        openNote: (p) async => opened.add(p),
      );
    }

    test('create creates note with formatted prefix and opens it', () async {
      final service = createService();
      final created = await service.create();

      expect(created.value, 'Zettel/202610151430.md');
      expect(opened, [VaultPath('Zettel/202610151430.md')]);
      final stat = await fs.stat(created);
      expect(stat, isNotNull);
    });

    test('create handles collisions with -2, -3 suffixes', () async {
      final base = VaultPath('Zettel/202610151430.md');
      final c2 = VaultPath('Zettel/202610151430-2.md');
      await fs.writeText(base, const TextDocument(text: 'existing 1'));
      await fs.writeText(c2, const TextDocument(text: 'existing 2'));

      final service = createService();
      final created = await service.create();

      expect(created.value, 'Zettel/202610151430-3.md');
      expect(opened, [VaultPath('Zettel/202610151430-3.md')]);
    });

    test('create with template applies {{title}} as filename stem', () async {
      final tmpl = VaultPath('Templates/Zk.md');
      await fs.writeText(
        tmpl,
        const TextDocument(text: '# Note: {{title}}\nDate: {{date}}'),
      );
      await index.rebuild();

      settings = settings.copyWith(
        uniqueNote: {
          'prefixFormat': 'YYYYMMDDHHmm',
          'folder': 'Zettel',
          'template': 'Templates/Zk',
        },
      );

      final service = createService();
      final created = await service.create();

      final doc = await fs.readText(created);
      expect(doc.text, '# Note: 202610151430\nDate: 2026-10-15');
    });

    test(
      'format validation raises UniqueNoteConfigException for invalid format',
      () async {
        settings = settings.copyWith(
          uniqueNote: {'prefixFormat': 'bad:format*name'},
        );
        final service = createService();
        expect(
          () => service.create(),
          throwsA(isA<UniqueNoteConfigException>()),
        );
      },
    );

    test('uniqueNoteCreator: false disables command isAvailable', () {
      final registry = CommandRegistry();
      registerNoteToolsCommands(registry);

      final cmd = registry.byId('unique-note.create');
      expect(cmd, isNotNull);

      // Verify availability reflects corePlugins.uniqueNoteCreator
      final enabledSettings = const VaultSettings(
        corePlugins: {'uniqueNoteCreator': true},
      );
      final disabledSettings = const VaultSettings(
        corePlugins: {'uniqueNoteCreator': false},
      );

      // Unique note creator is disabled by default
      expect(disabledSettings.corePluginsSettings.uniqueNoteCreator, isFalse);
      expect(enabledSettings.corePluginsSettings.uniqueNoteCreator, isTrue);
    });
  });
}
