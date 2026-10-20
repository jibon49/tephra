// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';

/// Renders a file chip for non-image embedded files (PDF, audio, video, etc.).
class FileChip extends StatelessWidget {
  const FileChip({super.key, required this.path, this.sizeBytes, this.onTap});

  final VaultPath path;
  final int? sizeBytes;
  final VoidCallback? onTap;

  IconData _iconForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'svg':
        return Icons.image_outlined;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
      case 'flac':
        return Icons.audiotrack;
      case 'mp4':
      case 'webm':
      case 'mov':
      case 'mkv':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = path.extension;
    final icon = _iconForExtension(ext);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                path.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (sizeBytes != null) ...[
              const SizedBox(width: 8),
              Text(
                '(${_formatSize(sizeBytes!)})',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
