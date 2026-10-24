// © 2026 Tephra. All rights reserved.

import 'dart:math';

import 'package:tephra_core/tephra_core.dart';

import '../model/sticky.dart';
import 'board_color_map.dart';
import 'canvas_document.dart';

/// The result of running a board reconciliation cycle.
final class BoardReconcileResult {
  const BoardReconcileResult({required this.doc, required this.changed});

  final CanvasDocument doc;
  final bool changed;
}

/// Generates a 16-character lower-case hex identifier for JSON Canvas nodes.
String generateCanvasNodeId([Random? random]) {
  final rng = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(rng.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}

/// Reconciles a JSON Canvas board document against the current list of active stickies.
///
/// Ensures all active stickies have nodes, unpinned/deleted stickies in [stickyFolder]
/// are pruned, colours are mirrored from note frontmatter, and orphaned edges are pruned.
BoardReconcileResult reconcileBoard(
  CanvasDocument doc,
  List<Sticky> stickies, {
  required Random random,
  VaultPath? stickyFolder,
}) {
  final folder = stickyFolder ?? VaultPath('Stickies');
  final folderPrefix = folder.value.isEmpty
      ? ''
      : '${folder.value.toLowerCase()}/';

  // 1. Index active stickies by case-insensitive path
  final activeByCaseKey = <String, Sticky>{};
  for (final s in stickies) {
    activeByCaseKey[s.path.caseKey] = s;
  }

  var changed = false;

  // 2. Identify and prune nodes
  final survivingNodes = <CanvasNode>[];
  final removedNodeIds = <String>{};

  for (final node in doc.nodes) {
    if (node.type == 'file' && node.file != null) {
      final nodePathStr = node.file!;
      final nodeVaultPath = VaultPath(nodePathStr);
      final isSticky = activeByCaseKey.containsKey(nodeVaultPath.caseKey);

      if (isSticky) {
        survivingNodes.add(node);
      } else {
        final isMd = nodePathStr.toLowerCase().endsWith('.md');
        final isInsideFolder =
            folderPrefix.isNotEmpty &&
            nodePathStr.toLowerCase().startsWith(folderPrefix);

        if (isMd && isInsideFolder) {
          // Unpinned, deleted, or archived sticky note inside sticky folder -> remove
          removedNodeIds.add(node.id);
          changed = true;
        } else {
          // Non-markdown file (e.g. image) or markdown outside sticky folder -> keep
          survivingNodes.add(node);
        }
      }
    } else {
      // Non-file nodes (text, link, group) -> keep
      survivingNodes.add(node);
    }
  }

  // 3. Mirror colours on existing sticky nodes
  final updatedNodes = <CanvasNode>[];
  final nodesByStickyCaseKey = <String, CanvasNode>{};

  for (final node in survivingNodes) {
    if (node.type == 'file' && node.file != null) {
      final sticky = activeByCaseKey[VaultPath(node.file!).caseKey];
      if (sticky != null) {
        nodesByStickyCaseKey[sticky.path.caseKey] = node;
        final expectedColor = stickyColorToCanvasColor(sticky.meta.color);
        if (node.color != expectedColor) {
          updatedNodes.add(
            node.copyWith(
              color: expectedColor,
              clearColor: expectedColor == null,
            ),
          );
          changed = true;
          continue;
        }
      }
    }
    updatedNodes.add(node);
  }

  // 4. Calculate bounding box for placing new nodes
  int startX;
  int startY;

  if (updatedNodes.isEmpty) {
    startX = 0;
    startY = 0;
  } else {
    var maxX = updatedNodes.first.x + updatedNodes.first.width;
    var minY = updatedNodes.first.y;

    for (final n in updatedNodes) {
      final right = n.x + n.width;
      if (right > maxX) maxX = right;
      if (n.y < minY) minY = n.y;
    }

    startX = maxX + 40;
    startY = minY;
  }

  // 5. Add missing active stickies
  var missingIndex = 0;
  for (final sticky in stickies) {
    if (!nodesByStickyCaseKey.containsKey(sticky.path.caseKey)) {
      final col = missingIndex ~/ 5;
      final row = missingIndex % 5;
      final x = startX + col * 280;
      final y = startY + row * 240;

      final newNode = CanvasNode(
        id: generateCanvasNodeId(random),
        type: 'file',
        x: x,
        y: y,
        width: 260,
        height: 220,
        file: sticky.path.value,
        color: stickyColorToCanvasColor(sticky.meta.color),
      );

      updatedNodes.add(newNode);
      changed = true;
      missingIndex++;
    }
  }

  // 6. Prune edges connected to removed nodes
  final survivingIds = updatedNodes.map((n) => n.id).toSet();
  final survivingEdges = <Map<String, Object?>>[];

  for (final edge in doc.edges) {
    final from = edge['fromNode']?.toString();
    final to = edge['toNode']?.toString();

    if (from != null &&
        to != null &&
        survivingIds.contains(from) &&
        survivingIds.contains(to)) {
      survivingEdges.add(edge);
    } else {
      changed = true;
    }
  }

  return BoardReconcileResult(
    doc: doc.copyWith(nodes: updatedNodes, edges: survivingEdges),
    changed: changed,
  );
}
