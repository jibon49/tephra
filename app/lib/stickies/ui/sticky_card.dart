// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../model/sticky_color.dart';
import '../model/sticky_meta.dart';
import 'sticky_mini_renderer.dart';

/// A card widget displaying a sticky note with title, metadata status icons,
/// and mini rendered body.
class StickyCard extends StatelessWidget {
  const StickyCard({
    super.key,
    required this.title,
    required this.text,
    required this.color,
    this.locked = false,
    this.pinned = false,
    this.remind,
    this.onToggleTask,
    this.onTap,
    this.onDoubleTap,
    this.maxBlocks = 12,
    this.selected = false,
  });

  final String title;
  final String text;
  final StickyColor color;
  final bool locked;
  final bool pinned;
  final LocalDateTime? remind;
  final void Function(int line)? onToggleTask;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final int maxBlocks;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textColor = Color(color.textArgb);
    final cardColor = Color(color.argb);

    return Material(
      color: cardColor,
      elevation: selected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected
            ? BorderSide(color: textColor.withValues(alpha: 0.6), width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: title and status icons
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pinned)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.lock,
                        size: 16,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  if (remind != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.alarm,
                        size: 16,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Mini renderer body with bottom overflow fade
              Flexible(
                child: ClipRect(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.85, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: StickyMiniRenderer(
                      text: text,
                      textColor: textColor,
                      onToggleTask: locked ? null : onToggleTask,
                      maxBlocks: maxBlocks,
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
