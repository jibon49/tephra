// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/editor/folding/fold_controller.dart';
import 'package:tephra/editor/folding/fold_regions.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

void main() {
  group('FoldController', () {
    const text = '''# Heading 1
Line 1
Line 2

## Heading 2
Line 3
- item
  - nested child

# Heading 3
Line 4
''';

    late ParsedNote parsed;
    late FoldController controller;

    setUp(() {
      parsed = MarkdownParser.parse(text);
      controller = FoldController(
        tabId: 'test-tab',
        path: VaultPath('test.md'),
      );
      controller.updateParse(text, parsed);
    });

    test('toggle / foldAll / unfoldAll', () {
      expect(controller.regions.length, greaterThanOrEqualTo(3));
      final h1 = controller.regions.firstWhere((r) => r.level == 1);

      expect(controller.isFolded(h1.headerStart), isFalse);
      expect(controller.foldedRanges, isEmpty);

      // Toggle folds h1
      controller.toggle(h1.headerStart);
      expect(controller.isFolded(h1.headerStart), isTrue);
      expect(controller.foldedRanges.length, 1);
      expect(controller.foldedRanges.first, (h1.from, h1.to));

      // Toggle again unfolds h1
      controller.toggle(h1.headerStart);
      expect(controller.isFolded(h1.headerStart), isFalse);
      expect(controller.foldedRanges, isEmpty);

      // foldAll folds every region
      controller.foldAll();
      expect(controller.foldedRanges.length, controller.regions.length);
      for (final r in controller.regions) {
        expect(controller.isFolded(r.headerStart), isTrue);
      }

      // unfoldAll unfolds everything
      controller.unfoldAll();
      expect(controller.foldedRanges, isEmpty);
      for (final r in controller.regions) {
        expect(controller.isFolded(r.headerStart), isFalse);
      }
    });

    test('caret moved into a folded range unfolds it', () {
      final h1 = controller.regions.firstWhere((r) => r.level == 1);
      controller.toggle(h1.headerStart);
      expect(controller.isFolded(h1.headerStart), isTrue);

      // Offset inside Line 1 (after h1.from and before h1.to)
      final offsetInside = h1.from + 2;
      final unfolded = controller.revealOffset(offsetInside);

      expect(unfolded, isTrue);
      expect(controller.isFolded(h1.headerStart), isFalse);
    });

    test('revealOffset unfolds all containing folds (nested)', () {
      // Fold both Heading 1 and Heading 2
      final h1 = controller.regions[0]; // # Heading 1
      final h2 = controller.regions.firstWhere((r) => r.level == 2);

      controller.toggle(h1.headerStart);
      controller.toggle(h2.headerStart);
      expect(controller.isFolded(h1.headerStart), isTrue);
      expect(controller.isFolded(h2.headerStart), isTrue);

      // An offset inside Heading 2 content is contained in BOTH H1 and H2
      final offsetInH2 = h2.from + 2;
      final unfolded = controller.revealOffset(offsetInH2);

      expect(unfolded, isTrue);
      expect(controller.isFolded(h1.headerStart), isFalse);
      expect(controller.isFolded(h2.headerStart), isFalse);
    });

    test('edits above a fold keep it folded (anchor shift)', () {
      // Fold Heading 3
      final h3 = controller.regions.lastWhere((r) => r.level == 1);
      final initialStart = h3.headerStart;
      controller.toggle(initialStart);
      expect(controller.isFolded(initialStart), isTrue);

      // Edit above Heading 3: insert 10 characters at offset 0
      controller.handleEdit(0, 0, 10);
      expect(controller.state.anchors, {initialStart + 10});

      // Update parse with new text that has 10 extra characters at start
      final newText = '0123456789$text';
      final newParsed = MarkdownParser.parse(newText);
      controller.updateParse(newText, newParsed);

      // It should still be folded at the shifted offset!
      expect(controller.isFolded(initialStart + 10), isTrue);
    });

    test('editor.foldHeadings = false unfolds heading folds', () {
      final h1 = controller.regions.firstWhere((r) => r.level == 1);
      controller.toggle(h1.headerStart);
      expect(controller.isFolded(h1.headerStart), isTrue);

      // Turn off foldHeadings
      controller.updateSettings(foldHeadings: false, foldIndent: true);

      // Headings must be unfolded!
      expect(controller.isFolded(h1.headerStart), isFalse);
      expect(
        controller.regions.every((r) => r.kind != FoldKind.heading),
        isTrue,
      );
    });
  });
}
