// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tephra/stickies/board/board_reconciler.dart';
import 'package:tephra/stickies/board/canvas_document.dart';
import 'package:tephra/stickies/model/sticky.dart';
import 'package:tephra/stickies/model/sticky_color.dart';
import 'package:tephra/stickies/model/sticky_meta.dart';
import 'package:tephra_core/tephra_core.dart';

void main() {
  final random = Random(42);

  Sticky makeSticky({
    required String path,
    StickyColor color = NamedStickyColor.yellow,
    DateTime? modified,
  }) {
    return Sticky(
      path: VaultPath(path),
      meta: StickyMeta(isSticky: true, color: color),
      text:
          '---\ntephra-sticky: true\nsticky-color: ${color.yamlValue}\n---\nBody',
      hash: 'hash1',
      modified: modified ?? DateTime(2026, 10, 11, 9, 30),
    );
  }

  group('BoardReconciler', () {
    test('adds missing sticky', () {
      final doc = CanvasDocument(nodes: [], edges: []);
      final stickies = [
        makeSticky(
          path: 'Stickies/Sticky 1.md',
          color: NamedStickyColor.yellow,
        ),
      ];

      final result = reconcileBoard(doc, stickies, random: random);

      expect(result.changed, isTrue);
      expect(result.doc.nodes, hasLength(1));
      final node = result.doc.nodes.first;
      expect(node.file, 'Stickies/Sticky 1.md');
      expect(node.x, 0);
      expect(node.y, 0);
      expect(node.width, 260);
      expect(node.height, 220);
      expect(node.color, '3');
      expect(node.id, hasLength(16));
    });

    test('removes unpinned sticky node and its edges', () {
      final doc = CanvasDocument(
        nodes: [
          CanvasNode(
            id: 'node-pinned',
            type: 'file',
            x: 0,
            y: 0,
            width: 260,
            height: 220,
            file: 'Stickies/Active.md',
          ),
          CanvasNode(
            id: 'node-unpinned',
            type: 'file',
            x: 300,
            y: 0,
            width: 260,
            height: 220,
            file: 'Stickies/Unpinned.md',
          ),
        ],
        edges: [
          {
            'id': 'edge-1',
            'fromNode': 'node-pinned',
            'toNode': 'node-unpinned',
          },
        ],
      );

      final stickies = [makeSticky(path: 'Stickies/Active.md')];

      final result = reconcileBoard(doc, stickies, random: random);

      expect(result.changed, isTrue);
      expect(result.doc.nodes, hasLength(1));
      expect(result.doc.nodes.first.file, 'Stickies/Active.md');
      expect(result.doc.edges, isEmpty); // Edge was pruned
    });

    test('keeps text and image nodes', () {
      final doc = CanvasDocument(
        nodes: [
          CanvasNode(
            id: 'text-1',
            type: 'text',
            text: 'Important reminder',
            x: 0,
            y: 0,
            width: 200,
            height: 100,
          ),
          CanvasNode(
            id: 'img-1',
            type: 'file',
            file: 'Attachments/photo.png',
            x: 0,
            y: 120,
            width: 300,
            height: 200,
          ),
        ],
        edges: [],
      );

      final result = reconcileBoard(doc, const [], random: random);

      expect(result.changed, isFalse);
      expect(result.doc.nodes, hasLength(2));
      expect(result.doc.nodes.any((n) => n.id == 'text-1'), isTrue);
      expect(result.doc.nodes.any((n) => n.id == 'img-1'), isTrue);
    });

    test('keeps non-sticky note outside sticky folder', () {
      final doc = CanvasDocument(
        nodes: [
          CanvasNode(
            id: 'note-outside',
            type: 'file',
            file: 'Projects/Roadmap.md',
            x: 100,
            y: 100,
            width: 260,
            height: 220,
          ),
        ],
        edges: [],
      );

      final result = reconcileBoard(doc, const [], random: random);

      expect(result.changed, isFalse);
      expect(result.doc.nodes, hasLength(1));
      expect(result.doc.nodes.first.file, 'Projects/Roadmap.md');
    });

    test('colour mirrored from note', () {
      final doc = CanvasDocument(
        nodes: [
          CanvasNode(
            id: 'n-pink',
            type: 'file',
            file: 'Stickies/Pink.md',
            x: 0,
            y: 0,
            width: 260,
            height: 220,
            color: '3', // Out of sync
          ),
          CanvasNode(
            id: 'n-gray',
            type: 'file',
            file: 'Stickies/Gray.md',
            x: 300,
            y: 0,
            width: 260,
            height: 220,
            color: '1', // Should be omitted
          ),
          CanvasNode(
            id: 'n-hex',
            type: 'file',
            file: 'Stickies/Hex.md',
            x: 600,
            y: 0,
            width: 260,
            height: 220,
            color: null,
          ),
        ],
        edges: [],
      );

      final stickies = [
        makeSticky(path: 'Stickies/Pink.md', color: NamedStickyColor.pink),
        makeSticky(path: 'Stickies/Gray.md', color: NamedStickyColor.gray),
        makeSticky(
          path: 'Stickies/Hex.md',
          color: const HexStickyColor(0xFF2C3E50),
        ),
      ];

      final result = reconcileBoard(doc, stickies, random: random);

      expect(result.changed, isTrue);
      final nodes = result.doc.nodes;
      expect(nodes.firstWhere((n) => n.file == 'Stickies/Pink.md').color, '1');
      expect(
        nodes.firstWhere((n) => n.file == 'Stickies/Gray.md').color,
        isNull,
      );
      expect(
        nodes.firstWhere((n) => n.file == 'Stickies/Hex.md').color,
        '#2C3E50',
      );
    });

    test('unchanged board reports changed false', () {
      final doc = CanvasDocument(nodes: [], edges: []);
      final stickies = [
        makeSticky(path: 'Stickies/S1.md', color: NamedStickyColor.yellow),
        makeSticky(path: 'Stickies/S2.md', color: NamedStickyColor.blue),
      ];

      final firstResult = reconcileBoard(doc, stickies, random: random);
      expect(firstResult.changed, isTrue);

      final secondResult = reconcileBoard(
        firstResult.doc,
        stickies,
        random: random,
      );
      expect(secondResult.changed, isFalse);
      expect(secondResult.doc, equals(firstResult.doc));
    });
  });
}
