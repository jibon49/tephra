// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/workspace/tab_content.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  group('TabContent and FileTabContent', () {
    test('JSON round trip of FileTabContent with and without subpath', () {
      final withSub = FileTabContent(
        VaultPath('folder/note.md'),
        subpath: '#heading-1',
      );
      final jsonWithSub = withSub.toJson();
      expect(
        jsonWithSub,
        equals({
          'kind': 'file',
          'path': 'folder/note.md',
          'subpath': '#heading-1',
          'mode': 'livePreview',
        }),
      );

      final restoredWithSub = TabContent.fromJson(jsonWithSub);
      expect(restoredWithSub, equals(withSub));

      final withoutSub = FileTabContent(VaultPath('root.md'));
      final jsonWithoutSub = withoutSub.toJson();
      expect(
        jsonWithoutSub,
        equals({'kind': 'file', 'path': 'root.md', 'mode': 'livePreview'}),
      );

      final restoredWithoutSub = TabContent.fromJson(jsonWithoutSub);
      expect(restoredWithoutSub, equals(withoutSub));
    });

    test('legacy {"path":"A.md"} deserializes to FileTabContent', () {
      final legacy = TabContent.fromJson({'path': 'A.md'});
      expect(legacy, isA<FileTabContent>());
      expect((legacy! as FileTabContent).path, equals(VaultPath('A.md')));
      expect((legacy as FileTabContent).subpath, isNull);
    });

    test('invalid or unknown kind returns null', () {
      expect(TabContent.fromJson({'kind': 'bogus'}), isNull);
    });

    test('invalid path returns null', () {
      expect(TabContent.fromJson({'kind': 'file', 'path': '../x'}), isNull);
      expect(TabContent.fromJson({'path': ''}), isNull);
    });

    test('value equality and hashCode', () {
      final a1 = FileTabContent(VaultPath('a.md'), subpath: '#1');
      final a2 = FileTabContent(VaultPath('a.md'), subpath: '#1');
      final aDiffSub = FileTabContent(VaultPath('a.md'), subpath: '#2');
      final b = FileTabContent(VaultPath('b.md'));

      expect(a1, equals(a2));
      expect(a1.hashCode, equals(a2.hashCode));
      expect(a1, isNot(equals(aDiffSub)));
      expect(a1, isNot(equals(b)));
    });
  });
}
