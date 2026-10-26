// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/android/widget_lines.dart';

void main() {
  group('widgetLinesFromMarkdown', () {
    test('skips frontmatter', () {
      const markdown = '''---
tephra-sticky: true
color: yellow
---
# Header
First line of body''';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(2));
      expect(lines[0].kind, equals(WidgetLineKind.heading));
      expect(lines[0].text, equals('Header'));
      expect(lines[0].sourceLine, equals(4));

      expect(lines[1].kind, equals(WidgetLineKind.text));
      expect(lines[1].text, equals('First line of body'));
      expect(lines[1].sourceLine, equals(5));
    });

    test('tasks carry checked state and source line', () {
      const markdown = '''- [ ] Task unchecked
- [x] Task checked
- [X] Task uppercase checked
1. [ ] Numbered task
2. [x] Numbered checked task''';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(5));

      expect(lines[0].kind, equals(WidgetLineKind.task));
      expect(lines[0].text, equals('Task unchecked'));
      expect(lines[0].checked, isFalse);
      expect(lines[0].sourceLine, equals(0));

      expect(lines[1].kind, equals(WidgetLineKind.task));
      expect(lines[1].text, equals('Task checked'));
      expect(lines[1].checked, isTrue);
      expect(lines[1].sourceLine, equals(1));

      expect(lines[2].kind, equals(WidgetLineKind.task));
      expect(lines[2].text, equals('Task uppercase checked'));
      expect(lines[2].checked, isTrue);
      expect(lines[2].sourceLine, equals(2));

      expect(lines[3].kind, equals(WidgetLineKind.task));
      expect(lines[3].text, equals('Numbered task'));
      expect(lines[3].checked, isFalse);
      expect(lines[3].sourceLine, equals(3));

      expect(lines[4].kind, equals(WidgetLineKind.task));
      expect(lines[4].text, equals('Numbered checked task'));
      expect(lines[4].checked, isTrue);
      expect(lines[4].sourceLine, equals(4));
    });

    test('nested bullets indented', () {
      const markdown = '''
- Top item
  - Level 1
    - Level 2
''';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(3));
      expect(lines[0].kind, equals(WidgetLineKind.bullet));
      expect(lines[0].text, equals('• Top item'));

      expect(lines[1].kind, equals(WidgetLineKind.bullet));
      expect(lines[1].text, equals('  • Level 1'));

      expect(lines[2].kind, equals(WidgetLineKind.bullet));
      expect(lines[2].text, equals('    • Level 2'));
    });

    test('inline markup stripped', () {
      const markdown = '**a** [[B|bee]] ![[x.png]]';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(1));
      expect(lines.first.text, equals('a bee [image]'));
    });

    test('stops at maxLines', () {
      final markdown = List.generate(20, (i) => 'Line $i').join('\n');

      final lines = widgetLinesFromMarkdown(markdown, maxLines: 5);
      expect(lines.length, equals(5));
      expect(lines.last.text, equals('Line 4'));
    });

    test('comment hidden', () {
      const markdown = '''
Line 1 %% hidden inline %% end
%% fully hidden
multiline
comment %%
Line 2
''';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Line 1  end'));
      expect(lines[1].text, equals('Line 2'));
    });

    test('Bangla text intact', () {
      const markdown = '''
# কাজের তালিকা
- [ ] বাজার করা
- [x] চিঠি পাঠানো
''';

      final lines = widgetLinesFromMarkdown(markdown);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('কাজের তালিকা'));
      expect(lines[1].text, equals('বাজার করা'));
      expect(lines[1].checked, isFalse);
      expect(lines[2].text, equals('চিঠি পাঠানো'));
      expect(lines[2].checked, isTrue);
    });
  });
}
