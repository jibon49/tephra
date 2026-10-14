// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/core/platform/system_trash_windows.dart';

void main() {
  test('WindowsSystemTrash moves file to recycle bin and handles missing path', () async {
    final trash = WindowsSystemTrash();

    final tempDir = Directory.systemTemp.createTempSync('trash_test_');
    final tempFile = File('${tempDir.path}/test_file.txt');
    tempFile.writeAsStringSync('trash me');
    expect(tempFile.existsSync(), isTrue);

    final result = await trash.moveToTrash(tempFile.path, isFolder: false);
    expect(result, isTrue);
    expect(tempFile.existsSync(), isFalse);

    // Non-existent path returns false
    final nonExistentResult = await trash.moveToTrash(
      '${tempDir.path}/does_not_exist_${DateTime.now().millisecondsSinceEpoch}.txt',
      isFolder: false,
    );
    expect(nonExistentResult, isFalse);

    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }, skip: !Platform.isWindows ? 'Windows only test' : null);
}
