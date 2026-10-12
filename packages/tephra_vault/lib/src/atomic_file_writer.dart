// © 2026 Tephra. All rights reserved.

import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';

final class AtomicFileWriter {
  AtomicFileWriter({
    Random? random,
    this.retries = 5,
    this.retryDelay = const Duration(milliseconds: 50),
    bool? isWindows,
  }) : _random = random ?? Random.secure(),
       isWindows = isWindows ?? Platform.isWindows;

  final Random _random;
  final int retries;
  final Duration retryDelay;
  final bool isWindows;

  final _log = Logger('tephra.atomic_file_writer');

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[_random.nextInt(16)]);
    }
    return sb.toString();
  }

  /// Writes [bytes] to [target]: temp file `.<name>.tephra-tmp-<random>` in
  /// the SAME folder → flush → close → rename over target.
  /// [beforeRename] is a test hook (simulates a crash by throwing).
  Future<void> write(
    File target,
    List<int> bytes, {
    Future<void> Function(File temp)? beforeRename,
  }) async {
    final dir = target.parent;
    await dir.create(recursive: true);

    final tmp = File(
      p.join(
        dir.path,
        '.${p.basename(target.path)}.tephra-tmp-${_randomHex(8)}',
      ),
    );

    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }

    await beforeRename?.call(tmp);

    try {
      await tmp.rename(target.path);
      return;
    } on FileSystemException catch (e) {
      final code = e.osError?.errorCode;
      final isLockError = isWindows && (code == 5 || code == 32);
      if (!isLockError) {
        try {
          await tmp.delete();
        } catch (_) {}
        rethrow;
      }
    }

    for (var attempt = 1; attempt <= retries; attempt++) {
      await Future<void>.delayed(retryDelay);
      try {
        if (target.existsSync()) {
          final backup = File(
            p.join(
              dir.path,
              '${p.basename(target.path)}.tephra-bak-${_randomHex(8)}',
            ),
          );
          try {
            await target.rename(backup.path);
          } on FileSystemException {
            continue;
          }

          try {
            await tmp.rename(target.path);
            try {
              await backup.delete();
            } catch (_) {}
            return;
          } on FileSystemException {
            try {
              await backup.rename(target.path);
            } catch (re) {
              _log.severe(
                'Failed to restore backup ${backup.path} to target ${target.path}: $re',
              );
            }
            continue;
          }
        } else {
          await tmp.rename(target.path);
          return;
        }
      } catch (_) {}
    }

    _log.severe(
      'Could not replace ${p.basename(target.path)}: file is locked. Temp preserved at: ${tmp.path}',
    );
    throw PermissionDeniedException(
      'Could not replace ${p.basename(target.path)}: file is locked',
    );
  }
}
