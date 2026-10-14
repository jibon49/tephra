// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tephra/vault/vault_creator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vault_creator_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('creates folder when it does not exist', () async {
    final path = await createVault(parentDir: tempDir.path, name: 'MyVault');
    expect(Directory(path).existsSync(), isTrue);
    expect(p.basename(path), equals('MyVault'));
  });

  test(
    'name with invalid characters throws VaultCreateException(invalid)',
    () async {
      expect(
        () => createVault(parentDir: tempDir.path, name: 'a:b'),
        throwsA(
          isA<VaultCreateException>().having((e) => e.code, 'code', 'invalid'),
        ),
      );
    },
  );

  test('empty name throws VaultCreateException(empty)', () async {
    expect(
      () => createVault(parentDir: tempDir.path, name: ''),
      throwsA(
        isA<VaultCreateException>().having((e) => e.code, 'code', 'empty'),
      ),
    );
  });

  test(
    'existing non-empty folder throws VaultCreateException(not-empty)',
    () async {
      final sub = Directory(p.join(tempDir.path, 'Existing'));
      await sub.create();
      await File(p.join(sub.path, 'note.md')).writeAsString('hello');

      expect(
        () => createVault(parentDir: tempDir.path, name: 'Existing'),
        throwsA(
          isA<VaultCreateException>().having(
            (e) => e.code,
            'code',
            'not-empty',
          ),
        ),
      );
    },
  );

  test('existing empty folder succeeds', () async {
    final sub = Directory(p.join(tempDir.path, 'EmptyVault'));
    await sub.create();

    final path = await createVault(parentDir: tempDir.path, name: 'EmptyVault');
    expect(path, equals(sub.path));
  });

  test('existing folder containing only .tephra succeeds', () async {
    final sub = Directory(p.join(tempDir.path, 'TephraOnly'));
    await sub.create();
    await Directory(p.join(sub.path, '.tephra')).create();
    await File(p.join(sub.path, '.tephra', 'some.json')).writeAsString('{}');

    final path = await createVault(parentDir: tempDir.path, name: 'TephraOnly');
    expect(path, equals(sub.path));
  });
}
