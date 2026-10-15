// © 2026 Tephra. All rights reserved.

import 'exceptions.dart';
import 'moment_format.dart';
import 'vault_path.dart';

/// Computes the [VaultPath] for a daily note on [date].
///
/// Throws [InvalidPathException] if any path segment is invalid or contains `..`.
VaultPath dailyNotePath(
  DateTime date, {
  required String folder,
  required String format,
}) {
  final formatted = formatMoment(date, format);
  final segments = formatted
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (segments.isEmpty) {
    throw const InvalidPathException('empty daily note path');
  }

  final last = segments.last;
  if (!last.toLowerCase().endsWith('.md')) {
    segments[segments.length - 1] = '$last.md';
  }

  final folderSegments = folder
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  final allSegments = [...folderSegments, ...segments];
  final rawPath = allSegments.join('/');

  return VaultPath(rawPath);
}
