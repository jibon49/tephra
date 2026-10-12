// © 2026 Tephra. All rights reserved.

import 'package:tephra_markdown/src/block/block_parser.dart';
import 'package:tephra_markdown/src/nodes.dart';
import 'package:tephra_markdown/src/parser_options.dart';
import 'package:test/test.dart';

import '../helpers/dump.dart';

void main() {
  group('List tight vs loose', () {
    test('tight bullet list', () {
      expect(
        dump(parseBlocks('- a\n- b').root),
        'doc(ul(li(p(t"a")),li(p(t"b"))))',
      );
    });

    test('loose bullet list due to blank line between items', () {
      expect(
        dump(parseBlocks('- a\n\n- b').root),
        'doc(ul{loose}(li(p(t"a")),li(p(t"b"))))',
      );
    });

    test('loose list due to item containing blank line between blocks', () {
      expect(
        dump(parseBlocks('- a\n\n  b').root),
        'doc(ul{loose}(li(p(t"a"),p(t"b"))))',
      );
    });
  });

  group('Start numbers and list delimiters', () {
    test('ordered list starting at 1', () {
      expect(
        dump(parseBlocks('1. a\n2. b').root),
        'doc(ol(li(p(t"a")),li(p(t"b"))))',
      );
    });

    test('ordered list starting at 7', () {
      expect(
        dump(parseBlocks('7. a\n8. b').root),
        'doc(ol{start=7}(li(p(t"a")),li(p(t"b"))))',
      );
    });

    test('* then + starts a new list', () {
      expect(
        dump(parseBlocks('* a\n+ b').root),
        'doc(ul(li(p(t"a"))),ul(li(p(t"b"))))',
      );
    });

    test('1. vs 1) delimiter', () {
      expect(
        dump(parseBlocks('1) a\n2) b').root),
        'doc(ol(li(p(t"a")),li(p(t"b"))))',
      );
    });
  });

  group('Paragraph interruption by list', () {
    test('ordered list interrupts paragraph only with 1', () {
      expect(dump(parseBlocks('para\n2. x').root), 'doc(p(t"para⏎2. x"))');
      expect(
        dump(parseBlocks('para\n1. x').root),
        'doc(p(t"para"),ol(li(p(t"x"))))',
      );
    });

    test('bullet list interrupts paragraph', () {
      expect(
        dump(parseBlocks('para\n- x').root),
        'doc(p(t"para"),ul(li(p(t"x"))))',
      );
    });

    test('empty item cannot interrupt paragraph', () {
      expect(dump(parseBlocks('para\n-').root), 'doc(h2(t"para"))');
      expect(dump(parseBlocks('para\n1.').root), 'doc(p(t"para⏎1."))');
    });
  });

  group('Nesting and lazy continuation', () {
    test('nested list by 2 spaces', () {
      expect(
        dump(parseBlocks('- a\n  - b').root),
        'doc(ul(li(p(t"a"),ul(li(p(t"b"))))))',
      );
    });

    test('nested list by tab', () {
      expect(
        dump(parseBlocks('- a\n\t- b').root),
        'doc(ul(li(p(t"a"),ul(li(p(t"b"))))))',
      );
    });

    test('lazy continuation inside an item', () {
      expect(dump(parseBlocks('- a\nb').root), 'doc(ul(li(p(t"a⏎b"))))');
    });

    test('list inside a block quote', () {
      expect(
        dump(parseBlocks('> - a\n> - b').root),
        'doc(bq(ul(li(p(t"a")),li(p(t"b")))))',
      );
    });
  });

  group('Task detection', () {
    test('standard tasks', () {
      expect(
        dump(parseBlocks('- [ ] a').root),
        'doc(ul(li{task=SP}(p(t"a"))))',
      );
      expect(dump(parseBlocks('- [x] a').root), 'doc(ul(li{task=x}(p(t"a"))))');
      expect(dump(parseBlocks('- [X] a').root), 'doc(ul(li{task=X}(p(t"a"))))');
    });

    test('Obsidian task marks', () {
      expect(dump(parseBlocks('- [/] a').root), 'doc(ul(li{task=/}(p(t"a"))))');
      expect(dump(parseBlocks('- [-] a').root), 'doc(ul(li{task=-}(p(t"a"))))');
      expect(dump(parseBlocks('- [>] a').root), 'doc(ul(li{task=>}(p(t"a"))))');
      expect(dump(parseBlocks('- [<] a').root), 'doc(ul(li{task=<}(p(t"a"))))');
      expect(dump(parseBlocks('- [?] a').root), 'doc(ul(li{task=?}(p(t"a"))))');
      expect(dump(parseBlocks('- [!] a').root), 'doc(ul(li{task=!}(p(t"a"))))');
    });

    test('ordered task item', () {
      expect(
        dump(parseBlocks('1. [x] a').root),
        'doc(ol(li{task=x}(p(t"a"))))',
      );
    });

    test('nested task list', () {
      expect(
        dump(parseBlocks('* [ ] a\n  * [x] b').root),
        'doc(ul(li{task=SP}(p(t"a"),ul(li{task=x}(p(t"b"))))))',
      );
    });

    test('non-tasks', () {
      expect(dump(parseBlocks('- [ ]a').root), 'doc(ul(li(p(t"[ ]a"))))');
      expect(dump(parseBlocks('- [] a').root), 'doc(ul(li(p(t"[] a"))))');
      expect(dump(parseBlocks('- [xx] a').root), 'doc(ul(li(p(t"[xx] a"))))');
      expect(dump(parseBlocks('[ ] a').root), 'doc(p(t"[ ] a"))');
    });

    test('commonMark options disable extended task marks', () {
      final res = parseBlocks('- [/] a', options: ParserOptions.commonMark);
      expect(dump(res.root), 'doc(ul(li(p(t"[/] a"))))');
    });
  });

  group('Item offsets', () {
    test('exact item start and end offsets', () {
      final res = parseBlocks('- a\n- b');
      final list = res.root.children.first as MdList;
      expect(list.children.length, 2);
      expect(list.children[0].start, 0);
      expect(list.children[0].end, 3);
      expect(list.children[1].start, 4);
      expect(list.children[1].end, 7);
      expect(list.start, 0);
      expect(list.end, 7);
    });
  });
}
