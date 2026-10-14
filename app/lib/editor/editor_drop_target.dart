// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import 'attachment_actions.dart';
import 'editor_controller.dart';
import 'providers.dart';

/// Wraps [child] with desktop drag-and-drop attachment insertion on Windows.
class EditorDropTarget extends ConsumerStatefulWidget {
  const EditorDropTarget({
    super.key,
    required this.child,
    this.isWindowsOverride,
    this.controller,
  });

  final Widget child;
  final bool? isWindowsOverride;
  final EditorController? controller;

  @override
  ConsumerState<EditorDropTarget> createState() => _EditorDropTargetState();
}

class _EditorDropTargetState extends ConsumerState<EditorDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isWindows =
        widget.isWindowsOverride ?? (!kIsWeb && Platform.isWindows);
    if (!isWindows) {
      return widget.child;
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DropTarget(
      onDragEntered: (_) {
        setState(() => _dragging = true);
      },
      onDragExited: (_) {
        setState(() => _dragging = false);
      },
      onDragDone: (details) async {
        setState(() => _dragging = false);
        final c = widget.controller ?? ref.read(activeEditorProvider);
        if (c == null || details.files.isEmpty) return;

        final inputs = <AttachmentInput>[];
        for (final xfile in details.files) {
          try {
            final bytes = await xfile.readAsBytes();
            final name = xfile.name;
            final ext = p.extension(name).toLowerCase();
            final isImg = const [
              '.png',
              '.jpg',
              '.jpeg',
              '.gif',
              '.webp',
              '.bmp',
            ].contains(ext);
            inputs.add(
              AttachmentInput(bytes: bytes, fileName: name, isImage: isImg),
            );
          } catch (_) {
            // Ignore unreadable files
          }
        }

        if (inputs.isNotEmpty && context.mounted) {
          await insertAttachmentsInto(c, ref, inputs, context: context);
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.primaryContainer.withAlpha(180),
                alignment: Alignment.center,
                child: Card(
                  elevation: 6,
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.attachmentDropHint,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
