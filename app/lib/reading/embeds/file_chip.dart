// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';

/// Renders a file chip for non-image embedded files (PDF, audio, video, etc.).
class FileChip extends ConsumerWidget {
  const FileChip({
    super.key,
    required this.path,
    this.subpath,
    this.sizeBytes,
    this.onTap,
  });

  final VaultPath path;
  final String? subpath;
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
      case '3gp':
      case 'mp4':
      case 'webm':
      case 'ogv':
      case 'mov':
      case 'mkv':
        return Icons.video_library;
      case 'canvas':
        return Icons.dashboard_customize;
      case 'base':
        return Icons.storage;
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

  String? _formatPage(String? sub) {
    if (sub == null || !sub.startsWith('#page=')) return null;
    final pageNum = sub.substring(6);
    return 'page $pageNum';
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (onTap != null) {
      onTap!();
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (!kIsWeb && Platform.isWindows) {
      final session = ref.read(vaultSessionProvider);
      if (session != null) {
        final absPath = p.join(session.rootDir, path.value);
        launchUrl(Uri.file(absPath));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.embedMediaLaterPhase),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = path.extension;
    final icon = _iconForExtension(ext);
    final pageText = _formatPage(subpath);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _handleTap(context, ref),
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
            Text(
              path.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (pageText != null) ...[
              const SizedBox(width: 6),
              Text(
                '($pageText)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
