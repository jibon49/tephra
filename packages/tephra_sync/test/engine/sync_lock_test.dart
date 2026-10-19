// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:tephra_sync/tephra_sync.dart';
import 'package:test/test.dart';

void main() {
  group('MemorySyncLock', () {
    test('mutual exclusion between callers', () async {
      final lock = MemorySyncLock();
      expect(lock.isHeld, isFalse);

      expect(await lock.tryAcquire(), isTrue);
      expect(lock.isHeld, isTrue);

      expect(await lock.tryAcquire(), isFalse);
      expect(lock.isHeld, isTrue);

      await lock.release();
      expect(lock.isHeld, isFalse);

      expect(await lock.tryAcquire(), isTrue);
      expect(lock.isHeld, isTrue);
      await lock.release();
    });
  });

  group('FileSyncLock', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sync_lock_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('mutual exclusion on same lock file', () async {
      final lockPath = '${tempDir.path}${Platform.pathSeparator}test.lock';
      final lock1 = FileSyncLock(lockPath);
      final lock2 = FileSyncLock(lockPath);

      expect(lock1.isHeld, isFalse);
      expect(lock2.isHeld, isFalse);

      expect(await lock1.tryAcquire(), isTrue);
      expect(lock1.isHeld, isTrue);

      expect(await lock2.tryAcquire(), isFalse);
      expect(lock2.isHeld, isFalse);

      await lock1.release();
      expect(lock1.isHeld, isFalse);

      expect(await lock2.tryAcquire(), isTrue);
      expect(lock2.isHeld, isTrue);

      await lock2.release();
      expect(lock2.isHeld, isFalse);
    });

    test('re-acquiring same lock instance returns true', () async {
      final lockPath = '${tempDir.path}${Platform.pathSeparator}test2.lock';
      final lock = FileSyncLock(lockPath);

      expect(await lock.tryAcquire(), isTrue);
      expect(await lock.tryAcquire(), isTrue);

      await lock.release();
      expect(lock.isHeld, isFalse);
    });
  });
}
