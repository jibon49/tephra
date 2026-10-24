// © 2026 Tephra. All rights reserved.

import 'dart:ui';

import '../model/sticky.dart';
import '../model/sticky_color.dart';
import 'board_color_map.dart';
import 'canvas_document.dart';

/// Layout modes supported by the sticky board.
enum BoardLayoutMode { free, byColor, byTag }

/// Computes updated positions for canvas nodes according to the requested [mode].
///
/// Returns a map of node id -> target [Offset] in canvas coordinate space.
Map<String, Offset> layoutBoard(
  List<CanvasNode> stickyNodes,
  Map<String, Sticky> stickyByPath,
  BoardLayoutMode mode,
) {
  final result = <String, Offset>{};

  if (mode == BoardLayoutMode.free) {
    for (final node in stickyNodes) {
      result[node.id] = Offset(node.x.toDouble(), node.y.toDouble());
    }
    return result;
  }

  Sticky? findSticky(CanvasNode node) {
    if (node.file == null) return null;
    final file = node.file!;
    if (stickyByPath.containsKey(file)) return stickyByPath[file];
    for (final entry in stickyByPath.entries) {
      if (entry.key.toLowerCase() == file.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  if (mode == BoardLayoutMode.byColor) {
    // Group nodes by color
    final colorGroups = <StickyColor, List<CanvasNode>>{};

    for (final node in stickyNodes) {
      final sticky = findSticky(node);
      final color = sticky?.meta.color ?? canvasColorToStickyColor(node.color);

      // Normalize color instance for map grouping
      StickyColor groupKey = color;
      for (final existing in colorGroups.keys) {
        if (existing == color) {
          groupKey = existing;
          break;
        }
      }

      colorGroups.putIfAbsent(groupKey, () => []).add(node);
    }

    // Sort color groups in order: yellow, pink, blue, green, purple, gray, then hex by value
    final sortedColors = colorGroups.keys.toList()
      ..sort((a, b) {
        final rankA = _colorRank(a);
        final rankB = _colorRank(b);
        if (rankA != rankB) return rankA.compareTo(rankB);
        if (a is HexStickyColor && b is HexStickyColor) {
          return a.argb.compareTo(b.argb);
        }
        return 0;
      });

    var colIndex = 0;
    for (final color in sortedColors) {
      final nodes = colorGroups[color]!;
      // Sort within column by modified descending
      nodes.sort((a, b) {
        final modA =
            findSticky(a)?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        final modB =
            findSticky(b)?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        return modB.compareTo(modA);
      });

      for (var rowIndex = 0; rowIndex < nodes.length; rowIndex++) {
        final node = nodes[rowIndex];
        result[node.id] = Offset(colIndex * 300.0, rowIndex * 240.0);
      }
      colIndex++;
    }

    return result;
  }

  if (mode == BoardLayoutMode.byTag) {
    // Group nodes by first tag (lower-case) or "" (no tag)
    final tagGroups = <String, List<CanvasNode>>{};

    for (final node in stickyNodes) {
      final sticky = findSticky(node);
      final tags = sticky?.tags ?? const [];
      final tag = tags.isNotEmpty ? tags.first.toLowerCase() : '';
      tagGroups.putIfAbsent(tag, () => []).add(node);
    }

    // Sort tag groups alphabetically, with "" (no tag) last
    final sortedTags = tagGroups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return a.compareTo(b);
      });

    var colIndex = 0;
    for (final tag in sortedTags) {
      final nodes = tagGroups[tag]!;
      // Sort within column by modified descending
      nodes.sort((a, b) {
        final modA =
            findSticky(a)?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        final modB =
            findSticky(b)?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        return modB.compareTo(modA);
      });

      for (var rowIndex = 0; rowIndex < nodes.length; rowIndex++) {
        final node = nodes[rowIndex];
        result[node.id] = Offset(colIndex * 300.0, rowIndex * 240.0);
      }
      colIndex++;
    }

    return result;
  }

  return result;
}

int _colorRank(StickyColor c) {
  if (c is NamedStickyColor) {
    switch (c.name) {
      case StickyColorName.yellow:
        return 0;
      case StickyColorName.pink:
        return 1;
      case StickyColorName.blue:
        return 2;
      case StickyColorName.green:
        return 3;
      case StickyColorName.purple:
        return 4;
      case StickyColorName.gray:
        return 5;
    }
  }
  return 6;
}
