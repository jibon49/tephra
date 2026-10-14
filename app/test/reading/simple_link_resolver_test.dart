// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/reading/simple_link_resolver.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('SimpleLinkResolver', () {
    const resolver = SimpleLinkResolver();
    final from = VaultPath('Index.md');
    final files = [
      VaultPath('Note.md'),
      VaultPath('Folder/Note.md'),
      VaultPath('Deep/x/y/Target.md'),
      VaultPath('Images/pic.png'),
      VaultPath('Folder/pic.png'),
      VaultPath('বাংলা.md'),
    ];

    test('resolves shortest matching note name', () {
      final res = resolver.resolve('Note', from: from, files: files);
      expect(res, equals(VaultPath('Note.md')));
    });

    test('resolves case-insensitively', () {
      final res = resolver.resolve('note', from: from, files: files);
      expect(res, equals(VaultPath('Note.md')));
    });

    test('resolves path with folder', () {
      final res = resolver.resolve('Folder/Note', from: from, files: files);
      expect(res, equals(VaultPath('Folder/Note.md')));
    });

    test('resolves deeply nested target by stem', () {
      final res = resolver.resolve('Target', from: from, files: files);
      expect(res, equals(VaultPath('Deep/x/y/Target.md')));
    });

    test('tie-break: segments -> length -> compareTo', () {
      // Images/pic.png and Folder/pic.png:
      // Both have 2 segments, both length 14, Folder/ comes before Images/
      final res = resolver.resolve('pic.png', from: from, files: files);
      expect(res, equals(VaultPath('Folder/pic.png')));
    });

    test('resolves by suffix path', () {
      final res = resolver.resolve('y/Target', from: from, files: files);
      expect(res, equals(VaultPath('Deep/x/y/Target.md')));
    });

    test('missing target returns null', () {
      final res = resolver.resolve('Missing', from: from, files: files);
      expect(res, isNull);
    });

    test('empty target returns from path', () {
      final res = resolver.resolve('', from: from, files: files);
      expect(res, equals(from));
    });

    test('normalises backslashes in target', () {
      final res = resolver.resolve(r'Folder\Note', from: from, files: files);
      expect(res, equals(VaultPath('Folder/Note.md')));
    });

    test('resolves non-ASCII Bangla name', () {
      final res = resolver.resolve('বাংলা', from: from, files: files);
      expect(res, equals(VaultPath('বাংলা.md')));
    });

    test('resolves target with explicit .md extension', () {
      final res = resolver.resolve('Note.md', from: from, files: files);
      expect(res, equals(VaultPath('Note.md')));
    });
  });
}
