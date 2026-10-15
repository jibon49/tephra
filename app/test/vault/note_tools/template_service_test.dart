// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/settings/vault_settings.dart';
import 'package:tephra/vault/note_tools/exceptions.dart';
import 'package:tephra/vault/note_tools/template_service.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_vault/tephra_vault.dart';

final class _FakeEditorTarget implements NoteEditorTarget {
  _FakeEditorTarget({
    required this.path,
    required this.text,
    this.selectionStart = 0,
    this.selectionEnd = 0,
  });

  @override
  final VaultPath path;
  @override
  String text;
  @override
  int selectionStart;
  @override
  int selectionEnd;

  int applyEditsCallCount = 0;
  List<TextEdit> lastEdits = [];

  @override
  void applyEdits(List<TextEdit> edits) {
    applyEditsCallCount++;
    lastEdits = edits;
    text = applyTextEdits(text, edits);
  }

  @override
  void select(int offset) {
    selectionStart = offset;
    selectionEnd = offset;
  }
}

class _FixedClock implements Clock {
  const _FixedClock(this._fixed);
  final DateTime _fixed;
  @override
  DateTime now() => _fixed;
}

void main() {
  group('TemplateService', () {
    late MemoryVaultFileSystem fs;
    late NoteIndex index;
    late VaultSettings settings;
    final fixedNow = DateTime(2026, 10, 15, 14, 30);
    final clock = _FixedClock(fixedNow);
    final snackbars = <String>[];

    setUp(() async {
      fs = MemoryVaultFileSystem();
      index = await NoteIndex.open(':memory:', fs);
      snackbars.clear();
      settings = const VaultSettings(
        templates: {
          'folder': 'Templates',
          'dateFormat': 'YYYY-MM-DD',
          'timeFormat': 'HH:mm',
        },
      );
    });

    tearDown(() async {
      await index.close();
      await fs.dispose();
    });

    TemplateService createService() {
      return TemplateService(
        fs: fs,
        index: () => index,
        getSettings: () => settings,
        clock: clock,
        showSnackbar: (msg) => snackbars.add(msg),
      );
    }

    test(
      'templateFiles lists .md notes in templates.folder recursively',
      () async {
        final t1 = VaultPath('Templates/Meeting.md');
        final t2 = VaultPath('Templates/Sub/Daily.md');
        final nonMd = VaultPath('Templates/image.png');
        final outside = VaultPath('Notes/Other.md');

        for (final p in [t1, t2, nonMd, outside]) {
          await fs.writeText(p, const TextDocument(text: 'sample'));
        }
        await index.rebuild();

        final service = createService();
        final templates = await service.templateFiles();

        expect(templates, [t1, t2]);
      },
    );

    test(
      'templateFiles throws TemplatesNotConfiguredException if folder empty',
      () async {
        settings = settings.copyWith(templates: {'folder': ''});
        final service = createService();
        expect(
          () => service.templateFiles(),
          throwsA(isA<TemplatesNotConfiguredException>()),
        );
      },
    );

    test(
      'insertTemplate into empty note replaces caret and sets caret at end',
      () async {
        final tmplPath = VaultPath('Templates/Basic.md');
        await fs.writeText(
          tmplPath,
          const TextDocument(text: 'Hello, {{title}}! Time is {{time}}.'),
        );

        final service = createService();
        final target = _FakeEditorTarget(
          path: VaultPath('Notes/My Note.md'),
          text: '',
          selectionStart: 0,
          selectionEnd: 0,
        );

        final ok = await service.insertTemplate(target, tmplPath);
        expect(ok, isTrue);
        expect(target.text, 'Hello, My Note! Time is 14:30.');
        expect(target.selectionStart, target.text.length);
        expect(target.applyEditsCallCount, 1);
      },
    );

    test('insertTemplate into note with frontmatter merges properties in ONE applyEdits call', () async {
      final tmplPath = VaultPath('Templates/Work.md');
      // Template has tags: [work, project], author: Jane, status: template_status
      await fs.writeText(
        tmplPath,
        const TextDocument(
          text: '---\ntags:\n  - work\n  - project\nauthor: Jane\nstatus: template_status\n---\n## Work Log\nBody here.',
        ),
      );

      // Existing note has tags: [journal, work], status: draft (existing scalar kept)
      final existingNote =
          '---\ntags:\n  - journal\n  - work\nstatus: draft\n---\nInitial note body.';
      final target = _FakeEditorTarget(
        path: VaultPath('Notes/Task.md'),
        text: existingNote,
        selectionStart: existingNote.length,
        selectionEnd: existingNote.length,
      );

      final service = createService();
      final ok = await service.insertTemplate(target, tmplPath);
      expect(ok, isTrue);

      // Verify one applyEdits call
      expect(target.applyEditsCallCount, 1);

      // Verify merged frontmatter
      expect(target.text, contains('journal'));
      expect(target.text, contains('work'));
      expect(target.text, contains('project'));
      expect(target.text, contains('author: Jane')); // missing key added
      expect(
        target.text,
        contains('status: draft'),
      ); // existing scalar unchanged
      expect(target.text, isNot(contains('template_status')));

      // Verify body appended
      expect(target.text, contains('Initial note body.'));
      expect(target.text, contains('## Work Log\nBody here.'));
    });

    test('insertTemplate with frontmatter into note WITHOUT frontmatter creates frontmatter block in ONE applyEdits call', () async {
      final tmplPath = VaultPath('Templates/WithFm.md');
      await fs.writeText(
        tmplPath,
        const TextDocument(
          text: '---\ncategory: meeting\n---\nTemplate body content.',
        ),
      );

      final target = _FakeEditorTarget(
        path: VaultPath('Notes/QuickNote.md'),
        text: 'Existing content without frontmatter.',
        selectionStart: 0,
        selectionEnd: 0,
      );

      final service = createService();
      final ok = await service.insertTemplate(target, tmplPath);
      expect(ok, isTrue);

      expect(target.applyEditsCallCount, 1);
      expect(target.text.startsWith('---\ncategory: meeting\n---\n'), isTrue);
      expect(target.text, contains('Template body content.'));
      expect(target.text, contains('Existing content without frontmatter.'));
    });

    test('insertTemplate when template unreadable shows snackbar and returns false without modifying target', () async {
      final unreadable = VaultPath('Templates/DoesNotExist.md');
      final target = _FakeEditorTarget(
        path: VaultPath('Notes/Safe.md'),
        text: 'Original untouched content.',
        selectionStart: 5,
        selectionEnd: 5,
      );

      final service = createService();
      final ok = await service.insertTemplate(target, unreadable);
      expect(ok, isFalse);
      expect(target.text, 'Original untouched content.');
      expect(target.applyEditsCallCount, 0);
      expect(snackbars, contains('templateUnreadable'));
    });
  });
}
