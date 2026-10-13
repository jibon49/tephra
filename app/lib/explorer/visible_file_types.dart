// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_vault/tephra_vault.dart';

const Set<String> _visibleFileExtensions = {
  'md',
  'canvas',
  'base',
  'pdf',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'svg',
  'mp3',
  'wav',
  'm4a',
  'ogg',
  'flac',
  '3gp',
  'aac',
  'opus',
  'mp4',
  'webm',
  'mov',
  'mkv',
  'ogv',
};

const Set<String> _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'svg',
};

const Set<String> _audioExtensions = {
  'mp3',
  'wav',
  'm4a',
  'ogg',
  'flac',
  '3gp',
  'aac',
  'opus',
};

const Set<String> _videoExtensions = {'mp4', 'webm', 'mov', 'mkv', 'ogv'};

/// Returns whether [e] is visible in the file explorer.
bool isVisibleInExplorer(VaultEntry e) {
  if (e.isFolder) return true;
  final ext = e.path.extension.toLowerCase();
  return _visibleFileExtensions.contains(ext);
}

/// Returns the display name for [e] (markdown without extension, others with).
String displayName(VaultEntry e) {
  if (!e.isFolder && e.path.extension.toLowerCase() == 'md') {
    return e.path.stem;
  }
  return e.path.name;
}

/// Returns the icon for [e].
IconData iconFor(VaultEntry e, {bool isOpen = false}) {
  if (e.isFolder) {
    return isOpen ? Icons.folder_open_outlined : Icons.folder_outlined;
  }
  final ext = e.path.extension.toLowerCase();
  if (ext == 'md') return Icons.description_outlined;
  if (ext == 'canvas') return Icons.dashboard_outlined;
  if (ext == 'base') return Icons.table_chart_outlined;
  if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
  if (_imageExtensions.contains(ext)) return Icons.image_outlined;
  if (_audioExtensions.contains(ext)) return Icons.audiotrack_outlined;
  if (_videoExtensions.contains(ext)) return Icons.movie_outlined;
  return Icons.insert_drive_file_outlined;
}
