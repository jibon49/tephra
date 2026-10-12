// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/core/logging.dart';

void main() {
  group('formatLogRecord', () {
    test('formats level, logger and message', () {
      final record = LogRecord(Level.INFO, 'hello', 'vault.fs');
      final formatted = formatLogRecord(record);
      expect(
        formatted,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\S+ INFO    vault\.fs: hello$')),
      );
    });

    test('appends error and stack', () {
      final record = LogRecord(
        Level.SEVERE,
        'boom',
        'x',
        StateError('x'),
        StackTrace.current,
      );
      final formatted = formatLogRecord(record);
      expect(formatted, contains('\n  error: Bad state: x'));
      expect(formatted.split('\n').length, greaterThanOrEqualTo(3));
    });
  });

  group('rotateLogs', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tephra_log_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('does nothing when file is small', () async {
      final logFile = File(p.join(tempDir.path, 'tephra.log'));
      logFile.writeAsStringSync('0123456789'); // 10 bytes

      await rotateLogs(tempDir, maxBytes: 100);

      expect(logFile.existsSync(), isTrue);
      expect(tempDir.listSync().map((e) => p.basename(e.path)).toList(), [
        'tephra.log',
      ]);
    });

    test('shifts files and drops the oldest', () async {
      File(p.join(tempDir.path, 'tephra.log'))
          .writeAsStringSync('A' * 200); // 200 bytes
      File(p.join(tempDir.path, 'tephra.1.log')).writeAsStringSync('B');
      File(p.join(tempDir.path, 'tephra.2.log')).writeAsStringSync('C');
      File(p.join(tempDir.path, 'tephra.3.log')).writeAsStringSync('D');
      File(p.join(tempDir.path, 'tephra.4.log')).writeAsStringSync('E');

      await rotateLogs(tempDir, maxBytes: 100, keep: 4);

      expect(File(p.join(tempDir.path, 'tephra.log')).existsSync(), isFalse);
      expect(
        File(p.join(tempDir.path, 'tephra.1.log')).readAsStringSync(),
        'A' * 200,
      );
      expect(
        File(p.join(tempDir.path, 'tephra.2.log')).readAsStringSync(),
        'B',
      );
      expect(
        File(p.join(tempDir.path, 'tephra.3.log')).readAsStringSync(),
        'C',
      );
      expect(
        File(p.join(tempDir.path, 'tephra.4.log')).readAsStringSync(),
        'D',
      );
      expect(File(p.join(tempDir.path, 'tephra.5.log')).existsSync(), isFalse);
    });

    test('when only tephra.log exists', () async {
      final logFile = File(p.join(tempDir.path, 'tephra.log'))
        ..writeAsStringSync('A' * 200);

      await rotateLogs(tempDir, maxBytes: 100);

      expect(logFile.existsSync(), isFalse);
      final rotated = File(p.join(tempDir.path, 'tephra.1.log'));
      expect(rotated.existsSync(), isTrue);
      expect(rotated.readAsStringSync(), 'A' * 200);
    });
  });
}
