// © 2026 Tephra. All rights reserved.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../l10n/app_localizations.dart';
import '../model/sticky.dart';
import '../providers.dart';
import '../ui/sticky_card.dart';
import 'board_layout.dart';
import 'board_quick_editor.dart';
import 'canvas_document.dart';

/// Screen displaying the 2D infinite canvas sticky board.
class StickyBoardScreen extends ConsumerStatefulWidget {
  const StickyBoardScreen({super.key});

  @override
  ConsumerState<StickyBoardScreen> createState() => _StickyBoardScreenState();
}

class _StickyBoardScreenState extends ConsumerState<StickyBoardScreen> {
  static const double _canvasSize = 20000.0;
  static const double _canvasCenter = _canvasSize / 2.0;

  late final TransformationController _transformController;
  bool _initializedTransform = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _centerViewport(Size viewportSize) {
    if (_initializedTransform) return;
    _initializedTransform = true;

    final tx = -_canvasCenter + viewportSize.width / 2.0;
    final ty = -_canvasCenter + viewportSize.height / 2.0;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0);
  }

  double get _currentScale => _transformController.value.getMaxScaleOnAxis();

  Offset _toCanvasCoordinates(Offset globalPosition, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final local = box != null
        ? box.globalToLocal(globalPosition)
        : globalPosition;
    final scene = _transformController.toScene(local);
    return Offset(scene.dx - _canvasCenter, scene.dy - _canvasCenter);
  }

  void _zoomToFit(List<CanvasNode> nodes, Size viewportSize) {
    if (nodes.isEmpty) {
      final tx = -_canvasCenter + viewportSize.width / 2.0;
      final ty = -_canvasCenter + viewportSize.height / 2.0;
      _transformController.value = Matrix4.identity()
        ..translateByDouble(tx, ty, 0.0, 1.0);
      return;
    }

    var minX = nodes.first.x;
    var minY = nodes.first.y;
    var maxX = nodes.first.x + nodes.first.width;
    var maxY = nodes.first.y + nodes.first.height;

    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.x + n.width > maxX) maxX = n.x + n.width;
      if (n.y + n.height > maxY) maxY = n.y + n.height;
    }

    final boxWidth = (maxX - minX + 80).toDouble();
    final boxHeight = (maxY - minY + 80).toDouble();

    final scaleX = viewportSize.width / boxWidth;
    final scaleY = viewportSize.height / boxHeight;
    final scale = math.min(scaleX, scaleY).clamp(0.2, 1.5);

    final centerX = _canvasCenter + minX + (maxX - minX) / 2.0;
    final centerY = _canvasCenter + minY + (maxY - minY) / 2.0;

    final tx = viewportSize.width / 2.0 - centerX * scale;
    final ty = viewportSize.height / 2.0 - centerY * scale;

    _transformController.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boardState = ref.watch(boardControllerProvider);
    final boardController = ref.read(boardControllerProvider.notifier);
    final stickies = ref.watch(stickiesProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 840;

    final stickyByPath = {for (final s in stickies.all) s.path.value: s};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stickyBoardTitle),
        actions: [
          // Auto-layout menu
          PopupMenuButton<BoardLayoutMode>(
            tooltip: 'Layout',
            icon: const Icon(Icons.auto_awesome_mosaic),
            onSelected: (mode) {
              boardController.applyLayout(mode);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.stickyBoardLayoutApplied),
                  action: SnackBarAction(
                    label: l10n.stickyBoardUndo,
                    onPressed: () => boardController.undoLayout(),
                  ),
                ),
              );
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: BoardLayoutMode.byColor,
                child: Text(l10n.stickyBoardLayoutByColor),
              ),
              PopupMenuItem(
                value: BoardLayoutMode.byTag,
                child: Text(l10n.stickyBoardLayoutByTag),
              ),
              PopupMenuItem(
                value: BoardLayoutMode.free,
                child: Text(l10n.stickyBoardLayoutFree),
              ),
            ],
          ),

          // Zoom to fit
          LayoutBuilder(
            builder: (ctx, constraints) => IconButton(
              tooltip: l10n.stickyBoardZoomToFit,
              icon: const Icon(Icons.fit_screen),
              onPressed: () {
                final size = MediaQuery.of(context).size;
                _zoomToFit(boardState.doc.nodes, size);
              },
            ),
          ),

          // New sticky
          IconButton(
            tooltip: l10n.stickyBoardNewSticky,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final size = MediaQuery.of(context).size;
              final canvasOffset = _toCanvasCoordinates(
                Offset(size.width / 2.0, size.height / 2.0),
                context,
              );
              final sticky = await boardController.createStickyAt(canvasOffset);
              if (context.mounted) {
                await showBoardQuickEditor(
                  context,
                  sticky: sticky,
                  repository: ref.read(stickyRepositoryProvider),
                );
              }
            },
          ),

          // Open board in canvas (Phase 6)
          IconButton(
            tooltip: l10n.stickyBoardOpenCanvas,
            icon: const Icon(Icons.grid_view),
            onPressed: null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Unreadable file banner
          if (boardState.isBroken)
            MaterialBanner(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              content: Text(
                l10n.stickyBoardUnreadableBanner,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              actions: [
                FilledButton.tonal(
                  onPressed: () => boardController.createNewBoard(),
                  child: Text(l10n.stickyBoardCreateNew),
                ),
              ],
            ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _centerViewport(
                  Size(constraints.maxWidth, constraints.maxHeight),
                );

                return GestureDetector(
                  onDoubleTapDown: (details) async {
                    final canvasOffset = _toCanvasCoordinates(
                      details.globalPosition,
                      context,
                    );
                    final sticky = await boardController.createStickyAt(
                      canvasOffset,
                    );
                    if (context.mounted) {
                      await showBoardQuickEditor(
                        context,
                        sticky: sticky,
                        repository: ref.read(stickyRepositoryProvider),
                      );
                    }
                  },
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 0.2,
                    maxScale: 2.5,
                    child: SizedBox(
                      width: _canvasSize,
                      height: _canvasSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final node in boardState.doc.nodes)
                            _BoardNodeWidget(
                              key: ValueKey(node.id),
                              node: node,
                              sticky: node.file != null
                                  ? stickyByPath[node.file!]
                                  : null,
                              isSelected: boardState.selectedNodeId == node.id,
                              canvasCenter: _canvasCenter,
                              isDesktop: isDesktop,
                              getScale: () => _currentScale,
                              onSelect: () =>
                                  boardController.selectNode(node.id),
                              onOpenQuickEditor: (sticky) {
                                showBoardQuickEditor(
                                  context,
                                  sticky: sticky,
                                  repository: ref.read(
                                    stickyRepositoryProvider,
                                  ),
                                );
                              },
                              onPositionChanged: (newX, newY) {
                                boardController.updateNodePosition(
                                  node.id,
                                  Offset(newX.toDouble(), newY.toDouble()),
                                );
                              },
                              onToggleTask: (path, line) {
                                boardController.toggleTask(path, line);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single interactive node widget placed on the 2D canvas stack.
class _BoardNodeWidget extends StatefulWidget {
  const _BoardNodeWidget({
    super.key,
    required this.node,
    required this.sticky,
    required this.isSelected,
    required this.canvasCenter,
    required this.isDesktop,
    required this.getScale,
    required this.onSelect,
    required this.onOpenQuickEditor,
    required this.onPositionChanged,
    required this.onToggleTask,
  });

  final CanvasNode node;
  final Sticky? sticky;
  final bool isSelected;
  final double canvasCenter;
  final bool isDesktop;
  final double Function() getScale;
  final VoidCallback onSelect;
  final void Function(Sticky sticky) onOpenQuickEditor;
  final void Function(int newX, int newY) onPositionChanged;
  final void Function(VaultPath path, int line) onToggleTask;

  @override
  State<_BoardNodeWidget> createState() => _BoardNodeWidgetState();
}

class _BoardNodeWidgetState extends State<_BoardNodeWidget> {
  Offset _dragDelta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final sticky = widget.sticky;

    final left = widget.canvasCenter + node.x + _dragDelta.dx;
    final top = widget.canvasCenter + node.y + _dragDelta.dy;

    Widget childWidget;
    if (sticky != null) {
      childWidget = StickyCard(
        title: sticky.title,
        text: sticky.text,
        color: sticky.meta.color,
        locked: sticky.meta.locked,
        pinned: sticky.meta.pinned,
        remind: sticky.meta.remind,
        selected: widget.isSelected,
        maxBlocks: 12,
        onTap: widget.onSelect,
        onDoubleTap: () => widget.onOpenQuickEditor(sticky),
        onToggleTask: (line) => widget.onToggleTask(sticky.path, line),
      );
    } else {
      // Non-sticky node placeholder (text, link, group, external file)
      final label = node.labelOrDesc;
      childWidget = Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withValues(alpha: 0.9),
          border: Border.all(
            color: widget.isSelected ? Colors.blue : Colors.grey.shade500,
            width: widget.isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
          maxLines: 4,
        ),
      );
    }

    // Drag gesture handling: direct pan on desktop, long-press pan on mobile
    Widget gestureContainer;
    if (widget.isDesktop) {
      gestureContainer = GestureDetector(
        onPanUpdate: (details) {
          final scale = widget.getScale();
          setState(() {
            _dragDelta += details.delta / scale;
          });
        },
        onPanEnd: (_) {
          final targetX = (node.x + _dragDelta.dx).round();
          final targetY = (node.y + _dragDelta.dy).round();
          setState(() => _dragDelta = Offset.zero);
          widget.onPositionChanged(targetX, targetY);
        },
        child: childWidget,
      );
    } else {
      gestureContainer = GestureDetector(
        onLongPressMoveUpdate: (details) {
          final scale = widget.getScale();
          setState(() {
            _dragDelta += details.offsetFromOrigin / scale;
          });
        },
        onLongPressEnd: (_) {
          final targetX = (node.x + _dragDelta.dx).round();
          final targetY = (node.y + _dragDelta.dy).round();
          setState(() => _dragDelta = Offset.zero);
          widget.onPositionChanged(targetX, targetY);
        },
        child: childWidget,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: node.width.toDouble(),
      height: node.height.toDouble(),
      child: gestureContainer,
    );
  }
}

extension on CanvasNode {
  String get labelOrDesc {
    if (type == 'text' && text != null) return text!;
    if (type == 'file' && file != null) return file!;
    if (type == 'link' && url != null) return url!;
    if (extra.containsKey('label')) return extra['label'].toString();
    return '$type ($id)';
  }
}
