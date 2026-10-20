// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('engine isolation: only app/lib/editor/engine/ may import re_editor', () {
    final libDir = Directory(p.join(Directory.current.path, 'lib')).existsSync()
        ? Directory(p.join(Directory.current.path, 'lib'))
        : Directory(p.join(Directory.current.path, 'app', 'lib'));
    expect(libDir.existsSync(), isTrue, reason: 'app/lib directory must exist');

    final violatingFiles = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final rel = p.relative(entity.path, from: libDir.path);
        final normalized = rel.replaceAll(r'\', '/');
        final isAllowedEngineFile = normalized.startsWith('editor/engine/');

        final content = entity.readAsStringSync();
        if (content.contains('package:re_editor')) {
          if (!isAllowedEngineFile) {
            violatingFiles.add(normalized);
          }
        }
      }
    }

    expect(
      violatingFiles,
      isEmpty,
      reason:
          're_editor package should only be imported within editor/engine/ but found in: $violatingFiles',
    );
  });
}
