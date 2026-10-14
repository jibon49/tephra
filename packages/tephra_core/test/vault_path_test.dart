// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';
import 'package:test/test.dart';

void main() {
  test('1. normalises backslashes', () {
    expect(VaultPath(r'Folder\Note.md').value, equals('Folder/Note.md'));
  });

  test('2. strips leading and trailing slashes', () {
    expect(VaultPath('/Folder/Note.md/').value, equals('Folder/Note.md'));
  });

  test('3. collapses double slashes', () {
    expect(VaultPath('a//b///c.md').value, equals('a/b/c.md'));
  });

  test('4. resolves dot segments', () {
    expect(VaultPath('./a/./b.md').value, equals('a/b.md'));
  });

  test('5. resolves dot-dot inside the vault', () {
    expect(VaultPath('a/b/../c.md').value, equals('a/c.md'));
    expect(VaultPath('a/../b.md').value, equals('b.md'));
  });

  test('6. rejects dot-dot escaping the root', () {
    expect(() => VaultPath('../a.md'), throwsA(isA<InvalidPathException>()));
    expect(
      () => VaultPath('a/../../b.md'),
      throwsA(isA<InvalidPathException>()),
    );
    expect(() => VaultPath('..'), throwsA(isA<InvalidPathException>()));
  });

  test('7. rejects empty results', () {
    expect(() => VaultPath(''), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('/'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('.'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('a/..'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath(r'\'), throwsA(isA<InvalidPathException>()));
  });

  test('8. rejects NUL', () {
    expect(
      () => VaultPath('a\u0000b.md'),
      throwsA(isA<InvalidPathException>()),
    );
  });

  test('9. rejects control characters', () {
    expect(() => VaultPath('a\tb.md'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('a\nb.md'), throwsA(isA<InvalidPathException>()));
  });

  test('10. rejects each Windows-invalid character', () {
    const invalidChars = ['<', '>', ':', '"', '|', '?', '*'];
    for (final c in invalidChars) {
      expect(
        () => VaultPath('a${c}b.md'),
        throwsA(isA<InvalidPathException>()),
        reason: 'character $c must throw',
      );
    }
  });

  test('11. rejects reserved device names', () {
    expect(() => VaultPath('CON'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('con.md'), throwsA(isA<InvalidPathException>()));
    expect(
      () => VaultPath('Folder/NUL.txt'),
      throwsA(isA<InvalidPathException>()),
    );
    expect(() => VaultPath('com1'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('LPT9.md'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('aux.tar.gz'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('x/PRN'), throwsA(isA<InvalidPathException>()));
  });

  test('12. accepts names that only look reserved', () {
    expect(VaultPath('CONSOLE.md').value, equals('CONSOLE.md'));
    expect(VaultPath('COM0.md').value, equals('COM0.md'));
    expect(VaultPath('COM10.md').value, equals('COM10.md'));
    expect(VaultPath('Cons.md').value, equals('Cons.md'));
    expect(VaultPath('LPT.md').value, equals('LPT.md'));
    expect(VaultPath('NULL.md').value, equals('NULL.md'));
  });

  test('13. rejects trailing dot or space', () {
    expect(() => VaultPath('Note.'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('Note '), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('a /b.md'), throwsA(isA<InvalidPathException>()));
    expect(() => VaultPath('a./b.md'), throwsA(isA<InvalidPathException>()));
  });

  test('14. accepts leading dot and inner spaces', () {
    expect(VaultPath('.hidden').value, equals('.hidden'));
    expect(VaultPath('My Note.md').value, equals('My Note.md'));
  });

  test('15. segment length limit', () {
    final name255 = 'a' * 255;
    expect(VaultPath(name255).value, equals(name255));
    final name256 = 'a' * 256;
    expect(() => VaultPath(name256), throwsA(isA<InvalidPathException>()));
  });

  test('16. name stem extension', () {
    final note = VaultPath('Folder/Note.md');
    expect(note.name, equals('Note.md'));
    expect(note.stem, equals('Note'));
    expect(note.extension, equals('md'));

    final tar = VaultPath('a.tar.gz');
    expect(tar.stem, equals('a.tar'));
    expect(tar.extension, equals('gz'));

    final readme = VaultPath('README');
    expect(readme.extension, equals(''));

    final hidden = VaultPath('.hidden');
    expect(hidden.stem, equals('.hidden'));
    expect(hidden.extension, equals(''));

    final image = VaultPath('Image.PNG');
    expect(image.name, equals('Image.PNG'));
    expect(image.extension, equals('png'));
  });

  test('17. parent chain', () {
    final p = VaultPath('a/b/c.md');
    expect(p.parent?.value, equals('a/b'));
    expect(p.parent?.parent?.value, equals('a'));
    expect(p.parent?.parent?.parent, equals(VaultPath.root));
    expect(p.parent?.parent?.parent?.parent, isNull);
  });

  test('18. root properties', () {
    expect(VaultPath.root.value, equals(''));
    expect(VaultPath.root.isRoot, isTrue);
    expect(VaultPath.root.parent, isNull);
    expect(VaultPath.root.name, equals(''));
    expect(VaultPath.root.extension, equals(''));
  });

  test('19. caseKey and case-sensitive equality', () {
    expect(VaultPath('A.md') == VaultPath('a.md'), isFalse);
    expect(VaultPath('A.md').caseKey, equals(VaultPath('a.md').caseKey));
  });

  test('20. join', () {
    expect(VaultPath('a').join('b/c.md').value, equals('a/b/c.md'));
    expect(VaultPath.root.join('x.md').value, equals('x.md'));
    expect(VaultPath('a/b').join('../x.md').value, equals('a/x.md'));
    expect(
      () => VaultPath('a').join('../../x'),
      throwsA(isA<InvalidPathException>()),
    );
  });

  test('21. withName', () {
    expect(VaultPath('a/b.md').withName('c.md').value, equals('a/c.md'));
    expect(
      () => VaultPath('a/b.md').withName('x/y'),
      throwsA(isA<InvalidPathException>()),
    );
    expect(
      () => VaultPath.root.withName('x'),
      throwsA(isA<InvalidPathException>()),
    );
    expect(
      () => VaultPath('a/b.md').withName('bad:name'),
      throwsA(isA<InvalidPathException>()),
    );
  });

  test('22. isWithin', () {
    final p = VaultPath('a/b/c.md');
    expect(p.isWithin(VaultPath('a')), isTrue);
    expect(p.isWithin(VaultPath('a/b')), isTrue);
    expect(VaultPath('a/b').isWithin(VaultPath('a/b')), isFalse);
    expect(VaultPath('ab/c').isWithin(VaultPath('a')), isFalse);
    expect(VaultPath('x.md').isWithin(VaultPath.root), isTrue);
    expect(VaultPath.root.isWithin(VaultPath.root), isFalse);
  });

  test('23. compareTo orders by code units', () {
    final list = [VaultPath('b.md'), VaultPath('A.md'), VaultPath('a.md')];
    list.sort();
    expect(list.map((p) => p.value).toList(), equals(['A.md', 'a.md', 'b.md']));
  });

  test('24. equality and hashCode', () {
    final p1 = VaultPath(r'a\b');
    final p2 = VaultPath('a/b');
    expect(p1, equals(p2));
    expect(p1.hashCode, equals(p2.hashCode));
    final map = {p1: 'ok'};
    expect(map[p2], equals('ok'));
  });

  test('25. unicode names', () {
    expect(VaultPath('নোট.md').value, equals('নোট.md'));
    expect(VaultPath('🌋 Volcano.md').value, equals('🌋 Volcano.md'));
    const nfd = 'Cafe\u0301.md';
    final pNfd = VaultPath(nfd);
    expect(pNfd.value, equals(nfd));
    expect(
      pNfd.value.length == 9 || utf8.encode(pNfd.value).length == 9,
      isTrue,
    );
  });

  test('26. tryParse', () {
    expect(VaultPath.tryParse('../x'), isNull);
    expect(VaultPath.tryParse('x')?.value, equals('x'));
  });

  test('27. checkName', () {
    expect(VaultPath.checkName(''), equals('empty'));
    expect(VaultPath.checkName('a/b'), equals('separator'));
    expect(VaultPath.checkName(r'a\b'), equals('separator'));
    expect(VaultPath.checkName('ok.md'), isNull);
    expect(VaultPath.checkName('a:b'), equals('invalid-char'));
    expect(VaultPath.checkName('con'), equals('reserved-name'));
  });

  test('28. toString returns value', () {
    expect(VaultPath('a/b/c.md').toString(), equals('a/b/c.md'));
  });
}
