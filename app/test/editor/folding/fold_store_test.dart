// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/json_file_store.dart';
import 'package:tephra/editor/folding/fold_regions.dart';
import 'package:tephra/editor/folding/fold_store.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

void main() {
  late MemoryVaultFileSystem fs;
  late ManualClock clock;
  const deviceId = 'device-1';
  const otherDeviceId = 'device-2';
  final workspacePath = VaultPath('.tephra/workspace.json');

  setUp(() {
    clock = ManualClock(DateTime(2026, 10, 15, 12));
    fs = MemoryVaultFileSystem(clock: clock);
  });

  group('FoldStore persistence', () {
    test('save modifies only this device entry, preserves other device and unknown keys byte-identically', () async {
      final initialWorkspace = {
        'schemaVersion': 1,
        'unknownTopKey': {'foo': 'bar'},
        otherDeviceId: {
          'panes': <Object?>[],
          'folds': {
            'Other.md': {
              't': 1000,
              'items': [
                {'k': 'h', 'line': 2, 'text': '## Other'},
              ],
            },
          },
        },
        deviceId: {
          'panes': <Object?>[],
          'customKey': 42,
          'folds': {
            'Old.md': {
              't': 2000,
              'items': [
                {'k': 'h', 'line': 5, 'text': '# Old'},
              ],
            },
          },
        },
      };

      final jsonStore = TephraJsonStore(clock);
      await jsonStore.writeMap(fs, workspacePath, initialWorkspace);

      final store = FoldStore(
        fs: fs,
        deviceId: deviceId,
        clock: clock,
        jsonStore: jsonStore,
      );

      final notePath = VaultPath('Notes/Plan.md');
      const items = [
        FoldItem(kind: FoldKind.heading, line: 12, text: '## Tasks'),
        FoldItem(kind: FoldKind.list, line: 30, text: '- group'),
      ];

      store.save(notePath, items);
      await store.flush();

      final root = await jsonStore.readMap(fs, workspacePath);
      expect(root['schemaVersion'], 1);
      expect(root['unknownTopKey'], {'foo': 'bar'});

      // otherDeviceId is completely untouched
      expect(root[otherDeviceId], initialWorkspace[otherDeviceId]);

      // this device preserved customKey
      final devMap = root[deviceId] as Map<String, Object?>;
      expect(devMap['customKey'], 42);

      final folds = devMap['folds'] as Map<String, Object?>;
      expect(folds.containsKey('Old.md'), isTrue);
      expect(folds.containsKey('Notes/Plan.md'), isTrue);

      final planFolds = folds['Notes/Plan.md'] as Map<String, Object?>;
      expect(planFolds['t'], clock.now().millisecondsSinceEpoch);
      final storedItems = planFolds['items'] as List<dynamic>;
      expect(storedItems.length, 2);
      expect(storedItems[0], {'k': 'h', 'line': 12, 'text': '## Tasks'});
      expect(storedItems[1], {'k': 'l', 'line': 30, 'text': '- group'});

      // Verify load
      final loaded = await store.load(notePath);
      expect(loaded, items);
    });

    test('empty list removes the note entry', () async {
      final store = FoldStore(fs: fs, deviceId: deviceId, clock: clock);
      final notePath = VaultPath('Notes/Plan.md');
      store.save(notePath, [
        const FoldItem(kind: FoldKind.heading, line: 10, text: '# Heading'),
      ]);
      await store.flush();

      var loaded = await store.load(notePath);
      expect(loaded.length, 1);

      // Now save empty list
      store.save(notePath, const []);
      await store.flush();

      loaded = await store.load(notePath);
      expect(loaded, isEmpty);

      final root = await TephraJsonStore(clock).readMap(fs, workspacePath);
      final dev = root[deviceId] as Map<String, Object?>?;
      final folds = dev?['folds'] as Map<String, Object?>?;
      expect(folds?.containsKey('Notes/Plan.md') ?? false, isFalse);
    });

    test('501 notes -> the oldest dropped', () async {
      final store = FoldStore(fs: fs, deviceId: deviceId, clock: clock);

      // Add 501 notes with increasing timestamps
      for (var i = 1; i <= 501; i++) {
        clock.advance(const Duration(milliseconds: 10));
        store.save(VaultPath('Note$i.md'), [
          FoldItem(kind: FoldKind.heading, line: i, text: '# Note $i'),
        ]);
        await store.flush();
      }

      final root = await TephraJsonStore(clock).readMap(fs, workspacePath);
      final folds =
          (root[deviceId] as Map<String, Object?>)['folds']
              as Map<String, Object?>;

      expect(folds.length, 500);
      // Note1 was the oldest, it should be dropped
      expect(folds.containsKey('Note1.md'), isFalse);
      // Note2 .. Note501 should be present
      expect(folds.containsKey('Note2.md'), isTrue);
      expect(folds.containsKey('Note501.md'), isTrue);
    });

    test('retarget re-keys entries including folder moves', () async {
      final store = FoldStore(fs: fs, deviceId: deviceId, clock: clock);
      store.save(VaultPath('Direct.md'), [
        const FoldItem(kind: FoldKind.heading, line: 1, text: '# Direct'),
      ]);
      store.save(VaultPath('Folder/Sub/Note.md'), [
        const FoldItem(kind: FoldKind.heading, line: 5, text: '# Sub Note'),
      ]);
      await store.flush();

      final moves = {
        VaultPath('Direct.md'): VaultPath('DirectRenamed.md'),
        VaultPath('Folder'): VaultPath('Archive'),
      };

      await store.retarget(moves);

      final root = await TephraJsonStore(clock).readMap(fs, workspacePath);
      final folds =
          (root[deviceId] as Map<String, Object?>)['folds']
              as Map<String, Object?>;

      expect(folds.containsKey('Direct.md'), isFalse);
      expect(folds.containsKey('DirectRenamed.md'), isTrue);

      expect(folds.containsKey('Folder/Sub/Note.md'), isFalse);
      expect(folds.containsKey('Archive/Sub/Note.md'), isTrue);
    });

    test('saving twice with identical content writes once', () async {
      final store = FoldStore(fs: fs, deviceId: deviceId, clock: clock);
      final notePath = VaultPath('A.md');
      const items = [
        FoldItem(kind: FoldKind.heading, line: 2, text: '# Hello'),
      ];

      store.save(notePath, items);
      await store.flush();

      final bytes1 = await fs.readBytes(workspacePath);

      // Now save exact same items with same clock time
      store.save(notePath, items);
      await store.flush();

      final bytes2 = await fs.readBytes(workspacePath);
      expect(identical(bytes1, bytes2) || bytes1 == bytes2, isTrue);
    });

    test('restore: edit so header moved +3 lines -> item re-anchored by text; text changed -> item dropped', () {
      // Original note had:
      // Line 2: ## Tasks
      // Line 5: ## Notes
      const storedItems = [
        FoldItem(kind: FoldKind.heading, line: 1, text: '## Tasks'),
        FoldItem(kind: FoldKind.heading, line: 5, text: '## Old Notes Title'),
      ];

      // Now note was edited:
      // 3 blank lines inserted at top, so ## Tasks is at Line 5.
      // And ## Old Notes Title was renamed to ## New Notes Title.
      const newText = '''
Intro line 1
Intro line 2
Intro line 3

## Tasks
Some task content

## New Notes Title
Some notes content
''';
      final parsed = MarkdownParser.parse(newText);
      final regions = computeFoldRegions(newText, parsed);

      final restored = FoldStore.restore(
        regions: regions,
        storedItems: storedItems,
        text: newText,
        lines: parsed.lines,
      );

      // ## Tasks was at line 2, now at line 5 (+3 lines). Within 200 lines with same text -> restored!
      // ## Old Notes Title was renamed to ## New Notes Title -> dropped!
      expect(restored.length, 1);
      final restoredTasks = restored[0];
      expect(restoredTasks.kind, FoldKind.heading);
      expect(parsed.lines.lineOf(restoredTasks.headerStart), 4);
    });
  });
}
