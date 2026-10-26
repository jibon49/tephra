// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:window_manager/window_manager.dart';

import '../model/sticky_color.dart';
import '../ui/sticky_mini_renderer.dart';
import 'sticky_window_controller.dart';

/// The standalone Flutter application UI running inside each secondary sticky note engine.
class StickyWindowApp extends StatefulWidget {
  const StickyWindowApp({super.key, required this.controller});

  final StickyWindowController controller;

  @override
  State<StickyWindowApp> createState() => _StickyWindowAppState();
}

class _StickyWindowAppState extends State<StickyWindowApp> {
  bool _isEditing = false;
  String _frontmatterPrefix = '';
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _bodyFocusNode = FocusNode();
  double? _expandedHeight;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _bodyFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _bodyFocusNode.removeListener(_onFocusChanged);
    _bodyFocusNode.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (!_bodyFocusNode.hasFocus && _isEditing) {
      _exitEditMode();
      widget.controller.onFocusLost();
    }
  }

  void _enterEditMode() {
    if (widget.controller.locked) return;
    final fullText = widget.controller.localText;
    final split = splitFrontmatter(fullText);
    if (split != null) {
      _frontmatterPrefix = fullText.substring(0, split.bodyStart);
      _bodyController.text = fullText.substring(split.bodyStart);
    } else {
      _frontmatterPrefix = '';
      _bodyController.text = fullText;
    }
    setState(() {
      _isEditing = true;
    });
    _bodyFocusNode.requestFocus();
  }

  void _exitEditMode() {
    if (!_isEditing) return;
    final newBody = _bodyController.text;
    final recombined = '$_frontmatterPrefix$newBody';
    widget.controller.onTextChanged(recombined);
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _toggleCollapse() async {
    final willCollapse = !widget.controller.collapsed;
    try {
      final size = await windowManager.getSize();
      if (willCollapse) {
        _expandedHeight = size.height;
        await windowManager.setSize(Size(size.width, 32));
      } else {
        final targetH = _expandedHeight ?? 260.0;
        await windowManager.setSize(Size(size.width, targetH));
      }
      final pos = await windowManager.getPosition();
      widget.controller.onGeometryChanged(
        x: pos.dx.toInt(),
        y: pos.dy.toInt(),
        w: size.width.toInt(),
        h: (_expandedHeight ?? size.height).toInt(),
        screen: 'primary',
        collapsed: willCollapse,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final stickyColor = StickyColor.parse(widget.controller.color);
    final bgColor = Color(stickyColor.argb);
    final textColor = Color(stickyColor.textArgb);
    final isDark = stickyColor.textArgb == 0xFFFFFFFF;
    final iconColor = textColor.withValues(alpha: 0.75);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bgColor,
      ),
      home: Scaffold(
        backgroundColor: bgColor,
        body: DragToResizeArea(
          child: Column(
            children: [
              // Custom Title Bar (32 dp)
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: DragToMoveArea(
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.controller.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Pin toggle
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        widget.controller.pinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: iconColor,
                      ),
                      tooltip: widget.controller.pinned
                          ? 'Unpin'
                          : 'Always on top',
                      onPressed: () async {
                        final next = !widget.controller.pinned;
                        await windowManager.setAlwaysOnTop(next);
                        await widget.controller.setPinned(next);
                      },
                    ),

                    // Color picker popup
                    PopupMenuButton<String>(
                      tooltip: 'Color',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        Icons.palette_outlined,
                        size: 16,
                        color: iconColor,
                      ),
                      onSelected: (val) {
                        widget.controller.setColor(val);
                      },
                      itemBuilder: (ctx) => [
                        for (final name in StickyColorName.values.map(
                          (v) => v.name,
                        ))
                          PopupMenuItem(
                            value: name,
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Color(StickyColor.parse(name).argb),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black26),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  name[0].toUpperCase() + name.substring(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Collapse / Expand
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        widget.controller.collapsed
                            ? Icons.unfold_more
                            : Icons.unfold_less,
                        color: iconColor,
                      ),
                      tooltip: widget.controller.collapsed
                          ? 'Expand'
                          : 'Collapse',
                      onPressed: _toggleCollapse,
                    ),

                    // More menu (⋯)
                    PopupMenuButton<String>(
                      tooltip: 'More actions',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 32,
                      ),
                      icon: Icon(Icons.more_horiz, size: 16, color: iconColor),
                      onSelected: (val) {
                        switch (val) {
                          case 'lock':
                            widget.controller.setLocked(
                              !widget.controller.locked,
                            );
                          case 'openInTephra':
                            widget.controller.requestOpenInMain();
                          case 'newSticky':
                            widget.controller.requestNewSticky();
                          case 'close':
                            widget.controller.requestClose();
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'lock',
                          child: Text(
                            widget.controller.locked ? 'Unlock' : 'Lock',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'openInTephra',
                          child: Text(
                            'Open in Tephra',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'newSticky',
                          child: Text(
                            'New sticky',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'close',
                          child: Text('Close', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    // Close (×)
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 32,
                      ),
                      icon: Icon(Icons.close, color: iconColor),
                      tooltip: 'Close',
                      onPressed: () => widget.controller.requestClose(),
                    ),
                  ],
                ),
              ),

              // Note body if not collapsed
              if (!widget.controller.collapsed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: _isEditing
                        ? Focus(
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.escape) {
                                _exitEditMode();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              controller: _bodyController,
                              focusNode: _bodyFocusNode,
                              maxLines: null,
                              expands: true,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onChanged: (text) {
                                final recombined = '$_frontmatterPrefix$text';
                                widget.controller.onTextChanged(recombined);
                              },
                            ),
                          )
                        : GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _enterEditMode,
                            child: StickyMiniRenderer(
                              text: widget.controller.localText,
                              textColor: textColor,
                              onToggleTask: widget.controller.locked
                                  ? null
                                  : (line) =>
                                        widget.controller.toggleTask(line),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
