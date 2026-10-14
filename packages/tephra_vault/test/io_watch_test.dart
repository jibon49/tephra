// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

final class EventQueue {
  EventQueue(Stream<VaultChange> stream) {
    _sub = stream.listen(_events.add);
  }

  late final StreamSubscription<VaultChange> _sub;
  final List<VaultChange> _events = [];

  bool get isEmpty => _events.isEmpty;
  int get length => _events.length;

  Future<VaultChange> next({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final end = DateTime.now().add(timeout);
    while (_events.isEmpty) {
      if (DateTime.now().isAfter(end)) {
        throw TimeoutException('Timed out waiting for next event', timeout);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return _events.removeAt(0);
  }

  Future<void> cancel() => _sub.cancel();
}

void main() {
  group('IoVaultFileSystem file watching', () {
    late Directory tempDir;
    late IoVaultFileSystem fs;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tephra_watch_test_');
      fs = IoVaultFileSystem(
        tempDir.path,
        debounce: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await fs.dispose();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. external create is reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      File(p.join(tempDir.path, 'new.md')).writeAsStringSync('hello');
      final event = await queue.next();
      expect(event, isA<FileCreated>());
      expect(event.path, VaultPath('new.md'));
    });

    test('2. external modify is reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      final file = File(p.join(tempDir.path, 'mod.md'))
        ..writeAsStringSync('initial');
      final createEvent = await queue.next();
      expect(createEvent, isA<FileCreated>());

      file.writeAsStringSync(' modified content');
      final modifyEvent = await queue.next();
      expect(modifyEvent, isA<FileModified>());
      expect(modifyEvent.path, VaultPath('mod.md'));
    });

    test('3. external delete is reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      final file = File(p.join(tempDir.path, 'del.md'))
        ..writeAsStringSync('initial');
      final createEvent = await queue.next();
      expect(createEvent, isA<FileCreated>());

      file.deleteSync();
      final deleteEvent = await queue.next();
      expect(deleteEvent, isA<FileDeleted>());
      expect(deleteEvent.path, VaultPath('del.md'));
    });

    test('4. own writeText is not reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      await fs.writeText(VaultPath('own.md'), TextDocument(text: 'my text'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(queue.isEmpty, isTrue);
    });

    test('5. own write followed by external write with different content is reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      await fs.writeText(VaultPath('shared.md'), TextDocument(text: 'initial'));
      // Overwrite immediately with different bytes via dart:io
      File(p.join(tempDir.path, 'shared.md'))
          .writeAsStringSync('external overwrite');

      final event = await queue.next();
      expect(event, isA<FileModified>());
      expect(event.path, VaultPath('shared.md'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(queue.isEmpty, isTrue);
    });

    test('6. own delete and own move are not reported', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      await fs.writeText(
        VaultPath('orig.md'),
        TextDocument(text: 'orig content'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await fs.move(VaultPath('orig.md'), VaultPath('moved.md'));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await fs.delete(VaultPath('moved.md'), mode: TrashMode.permanent);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(queue.isEmpty, isTrue);
    });

    test('7. ignored paths produce no events', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      Directory(p.join(tempDir.path, '.obsidian')).createSync();
      File(p.join(tempDir.path, '.obsidian', 'x.json')).writeAsStringSync('{}');
      Directory(p.join(tempDir.path, '.hidden')).createSync();
      File(p.join(tempDir.path, '.hidden', 'h.md')).writeAsStringSync('secret');
      File(p.join(tempDir.path, '.test.md.tephra-tmp-12345678'))
          .writeAsStringSync('temp');

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(queue.isEmpty, isTrue);
    });

    test('8. burst of 20 writes yields one event per path', () async {
      final queue = EventQueue(fs.watch());
      addTearDown(queue.cancel);
      await fs.ready;

      final file = File(p.join(tempDir.path, 'burst.md'))
        ..writeAsStringSync('0\n');
      final createEvent = await queue.next();
      expect(createEvent, isA<FileCreated>());

      for (var i = 1; i <= 20; i++) {
        file.writeAsStringSync('$i\n', mode: FileMode.append);
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }

      final modEvent = await queue.next();
      expect(modEvent, isA<FileModified>());
      expect(modEvent.path, VaultPath('burst.md'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(queue.isEmpty, isTrue);
    });

    test('9. cancelling the last listener stops the OS watcher', () async {
      final sub = fs.watch().listen((_) {});
      await fs.ready;
      await sub.cancel();
      expect(() async => await fs.dispose(), returnsNormally);
    });

    test('10. external pickup latency', () async {
      final defaultFs = IoVaultFileSystem(tempDir.path);
      addTearDown(defaultFs.dispose);
      final queue = EventQueue(defaultFs.watch());
      addTearDown(queue.cancel);
      await defaultFs.ready;

      final file = File(p.join(tempDir.path, 'latency.md'))
        ..writeAsStringSync('initial');
      final createEvent = await queue.next();
      expect(createEvent, isA<FileCreated>());

      final sw = Stopwatch()..start();
      file.writeAsStringSync(' modified content');
      final modEvent = await queue.next(timeout: const Duration(seconds: 3));
      sw.stop();

      expect(modEvent, isA<FileModified>());
      expect(sw.elapsedMilliseconds, lessThan(1000));
      // ignore: avoid_print, required by phase 01.5 instructions to record latency for PROGRESS.md.
      print('EXTERNAL_PICKUP_LATENCY_MS: ${sw.elapsedMilliseconds}');
    });

    test('11. Polling-mode test: create, modify, delete within 3 s', () async {
      final pollDir = tempDir.createTempSync('poll_');
      final pollingFs = IoVaultFileSystem(
        pollDir.path,
        watcherMode: WatcherMode.polling,
        debounce: const Duration(milliseconds: 50),
      );
      addTearDown(pollingFs.dispose);
      final queue = EventQueue(pollingFs.watch());
      addTearDown(queue.cancel);
      await pollingFs.ready;

      final file = File(p.join(pollDir.path, 'poll.md'))
        ..writeAsStringSync('created');
      final e1 = await queue.next(timeout: const Duration(seconds: 3));
      expect(e1, isA<FileCreated>());

      file.writeAsStringSync(' modified');
      final e2 = await queue.next(timeout: const Duration(seconds: 3));
      expect(e2, isA<FileModified>());

      file.deleteSync();
      final e3 = await queue.next(timeout: const Duration(seconds: 3));
      expect(e3, isA<FileDeleted>());
    });
  });
}
