// © 2026 Tephra. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/board/board_layout.dart';
import 'package:tephra/stickies/board/canvas_document.dart';
import 'package:tephra/stickies/model/sticky.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  Sticky makeSticky({
    required String path,
    StickyColor color = NamedStickyColor.yellow,
    DateTime? modified,
    String? body,
  }) {
    return Sticky(
      path: VaultPath(path),
      meta: StickyMeta(isSticky: true, color: color),
      text:
          '---\ntephra-sticky: true\nsticky-color: ${color.yamlValue}\n---\n${body ?? 'Body'}',
      hash: 'hash1',
      modified: modified ?? DateTime(2026, 10, 11, 9, 30),
    );
  }

  group('BoardLayout', () {
    test('byColor column order', () {
      final sYellowOld = makeSticky(
        path: 'Stickies/YOld.md',
        color: NamedStickyColor.yellow,
        modified: DateTime(2026, 10, 1),
      );
      final sYellowNew = makeSticky(
        path: 'Stickies/YNew.md',
        color: NamedStickyColor.yellow,
        modified: DateTime(2026, 10, 2),
      );
      final sPink = makeSticky(
        path: 'Stickies/Pink.md',
        color: NamedStickyColor.pink,
      );
      final sGray = makeSticky(
        path: 'Stickies/Gray.md',
        color: NamedStickyColor.gray,
      );
      final sHex = makeSticky(
        path: 'Stickies/Hex.md',
        color: const HexStickyColor(0xFF112233),
      );

      final nodes = [
        CanvasNode(
          id: 'n-y-old',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/YOld.md',
        ),
        CanvasNode(
          id: 'n-y-new',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/YNew.md',
        ),
        CanvasNode(
          id: 'n-pink',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/Pink.md',
        ),
        CanvasNode(
          id: 'n-gray',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/Gray.md',
        ),
        CanvasNode(
          id: 'n-hex',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/Hex.md',
        ),
      ];

      final map = {
        'Stickies/YOld.md': sYellowOld,
        'Stickies/YNew.md': sYellowNew,
        'Stickies/Pink.md': sPink,
        'Stickies/Gray.md': sGray,
        'Stickies/Hex.md': sHex,
      };

      final layout = layoutBoard(nodes, map, BoardLayoutMode.byColor);

      // Yellow column is index 0: x = 0
      // Within yellow column: sYellowNew is newer -> row 0 (y = 0), sYellowOld -> row 1 (y = 240)
      expect(layout['n-y-new'], const Offset(0, 0));
      expect(layout['n-y-old'], const Offset(0, 240));

      // Pink column is index 1: x = 300
      expect(layout['n-pink'], const Offset(300, 0));

      // Gray column is index 2: x = 600
      expect(layout['n-gray'], const Offset(600, 0));

      // Hex column is index 3: x = 900
      expect(layout['n-hex'], const Offset(900, 0));
    });

    test('byTag groups with untagged last', () {
      final sWork = makeSticky(
        path: 'Stickies/Work.md',
        body: '#work Note body',
      );
      final sApple = makeSticky(
        path: 'Stickies/Apple.md',
        body: '#apple Note body',
      );
      final sNoTag = makeSticky(
        path: 'Stickies/NoTag.md',
        body: 'Plain note body',
      );

      final nodes = [
        CanvasNode(
          id: 'n-work',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/Work.md',
        ),
        CanvasNode(
          id: 'n-apple',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/Apple.md',
        ),
        CanvasNode(
          id: 'n-notag',
          type: 'file',
          x: 0,
          y: 0,
          width: 260,
          height: 220,
          file: 'Stickies/NoTag.md',
        ),
      ];

      final map = {
        'Stickies/Work.md': sWork,
        'Stickies/Apple.md': sApple,
        'Stickies/NoTag.md': sNoTag,
      };

      final layout = layoutBoard(nodes, map, BoardLayoutMode.byTag);

      // 'apple' comes first alphabetically: col 0, x = 0
      expect(layout['n-apple'], const Offset(0, 0));

      // 'work' comes second: col 1, x = 300
      expect(layout['n-work'], const Offset(300, 0));

      // Untagged '' comes last: col 2, x = 600
      expect(layout['n-notag'], const Offset(600, 0));
    });

    test('free returns same positions', () {
      final nodes = [
        CanvasNode(
          id: 'n1',
          type: 'file',
          x: 120,
          y: 340,
          width: 260,
          height: 220,
        ),
        CanvasNode(
          id: 'n2',
          type: 'file',
          x: -50,
          y: 80,
          width: 260,
          height: 220,
        ),
      ];

      final layout = layoutBoard(nodes, const {}, BoardLayoutMode.free);

      expect(layout['n1'], const Offset(120, 340));
      expect(layout['n2'], const Offset(-50, 80));
    });
  });
}
