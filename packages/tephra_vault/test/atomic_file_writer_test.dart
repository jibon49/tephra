// © 2026 Tephra. All rights reserved.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_vault/tephra_vault.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late AtomicFileWriter writer;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('atomic_writer_test_');
    writer = AtomicFileWriter();
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('1. crash before rename leaves the original untouched', () async {
    final target = File(p.join(tempDir.path, 'note.md'));
    await target.writeAsString('old');

    expect(
      () => writer.write(
        target,
        utf8.encode('new'),
        beforeRename: (_) async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await target.readAsString(), equals('old'));
    final tmpFiles = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('.tephra-tmp-'))
        .toList();
    expect(tmpFiles.length, equals(1));
    expect(await tmpFiles.first.readAsString(), equals('new'));
  });

  test(
    '2. crash after flush of a brand-new file leaves no target file',
    () async {
      final target = File(p.join(tempDir.path, 'brand_new.md'));

      expect(
        () => writer.write(
          target,
          utf8.encode('content'),
          beforeRename: (_) async => throw StateError('boom'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(target.existsSync(), isFalse);
    },
  );

  test('3. no empty file is ever visible', () async {
    final target = File(p.join(tempDir.path, 'stream.txt'));
    final validLengths = <int>{};
    var sawIncomplete = false;

    // Concurrent reader
    var reading = true;
    final readerTimer = Timer.periodic(const Duration(milliseconds: 1), (_) {
      if (!reading) return;
      if (target.existsSync()) {
        try {
          final bytes = target.readAsBytesSync();
          if (bytes.isEmpty) {
            sawIncomplete = true;
          } else if (!validLengths.contains(bytes.length)) {
            sawIncomplete = true;
          }
        } catch (_) {}
      }
    });

    for (var i = 1; i <= 200; i++) {
      final content = 'Line $i: ${"x" * (i * 10)}\n';
      final bytes = utf8.encode(content);
      validLengths.add(bytes.length);
      await writer.write(target, bytes);
    }

    reading = false;
    readerTimer.cancel();

    expect(
      sawIncomplete,
      isFalse,
      reason: 'Reader must never observe an empty or partial file',
    );
  });

  test('4. temp file lives in the same folder and starts with a dot', () async {
    final target = File(p.join(tempDir.path, 'doc.md'));
    File? seenTemp;

    await writer.write(
      target,
      utf8.encode('data'),
      beforeRename: (tmp) async {
        seenTemp = tmp;
      },
    );

    expect(seenTemp, isNotNull);
    expect(seenTemp!.parent.path, equals(target.parent.path));
    final basename = p.basename(seenTemp!.path);
    expect(
      RegExp(r'^\..+\.tephra-tmp-[0-9a-f]{8}$').hasMatch(basename),
      isTrue,
    );
  });

  test('5. locked target fallback', () async {
    if (!Platform.isWindows) {
      return;
    }

    final target = File(p.join(tempDir.path, 'locked.md'));
    await target.writeAsString('initial');

    // Case A: Lock target briefly, write retries and succeeds
    final raf = await target.open(mode: FileMode.write);
    final writeFuture = writer.write(
      target,
      utf8.encode('updated'),
      beforeRename: (_) async {},
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await raf.close();

    await writeFuture;
    expect(await target.readAsString(), equals('updated'));

    // Case B: Handle never closed -> throws PermissionDeniedException
    final target2 = File(p.join(tempDir.path, 'locked_perm.md'));
    await target2.writeAsString('initial2');
    final raf2 = await target2.open(mode: FileMode.write);

    final lockedWriter = AtomicFileWriter(
      retryDelay: const Duration(milliseconds: 10),
      retries: 3,
    );

    try {
      await expectLater(
        lockedWriter.write(target2, utf8.encode('new_data')),
        throwsA(isA<PermissionDeniedException>()),
      );
      final tmps = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.tephra-tmp-'))
          .toList();
      expect(tmps, isNotEmpty);
      expect(await tmps.last.readAsString(), equals('new_data'));
    } finally {
      await raf2.close();
    }
  });

  test('6. non-windows failure rethrows and deletes the temp', () async {
    final nonWinWriter = AtomicFileWriter(isWindows: false);
    final target = File(p.join(tempDir.path, 'target_dir_conflict'));

    expect(
      () => nonWinWriter.write(
        target,
        utf8.encode('data'),
        beforeRename: (_) async {
          // Create directory at target path to make rename fail
          Directory(target.path).createSync();
        },
      ),
      throwsA(isA<FileSystemException>()),
    );

    final tmpFiles = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('.tephra-tmp-'))
        .toList();
    expect(
      tmpFiles,
      isEmpty,
      reason: 'Temp file must be cleaned up on non-windows failure',
    );
  });
}
