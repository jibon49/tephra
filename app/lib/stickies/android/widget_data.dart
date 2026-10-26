// © 2026 Tephra. All rights reserved.

import 'dart:convert';

import 'package:tephra_core/tephra_core.dart';

import '../model/sticky.dart';
import 'widget_lines.dart';

/// Protocol hash of note text normalized with '\n' line endings.
String stickyProtocolHash(String text) =>
    contentHash(utf8.encode(text.replaceAll('\r\n', '\n')));

/// Serializes a [Sticky] note into a single-sticky widget JSON map.
Map<String, Object?> stickyWidgetJson(
  Sticky? s, {
  required String vaultId,
  required bool configured,
  String? missingPath,
}) {
  if (!configured) {
    return {'v': 1, 'configured': false};
  }

  if (s == null) {
    return {
      'v': 1,
      'configured': true,
      'missing': true,
      'path': missingPath ?? '',
    };
  }

  final allLines = widgetLinesFromMarkdown(s.text, maxLines: 999999);
  final lines = allLines.take(10).toList();
  final more = allLines.length > 10 ? allLines.length - 10 : 0;

  final color = s.meta.color;
  final bg = color.argb;
  final fg = color.textArgb;
  final hash = stickyProtocolHash(s.text);

  return {
    'v': 1,
    'configured': true,
    'vaultId': vaultId,
    'path': s.path.value,
    'title': s.title,
    'bg': bg,
    'fg': fg,
    'locked': s.meta.locked,
    'hash': hash,
    'more': more,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
}

/// Serializes a list of active [Sticky] notes into the sticky-stack widget JSON map.
Map<String, Object?> stackWidgetJson(
  List<Sticky> active, {
  required String vaultId,
}) {
  final sorted = List.of(active)
    ..sort((a, b) => b.modified.compareTo(a.modified));

  final items = sorted.take(6).map((s) {
    final color = s.meta.color;
    final bg = color.argb;
    final fg = color.textArgb;

    final bodyLines = s.body.split('\n');
    var preview = '';
    for (final line in bodyLines) {
      final stripped = stripInlineMarkup(line.trim());
      if (stripped.isNotEmpty) {
        preview = stripped;
        break;
      }
    }
    if (preview.length > 120) {
      preview = preview.substring(0, 120);
    }

    return <String, Object?>{
      'path': s.path.value,
      'title': s.title,
      'bg': bg,
      'fg': fg,
      'preview': preview,
    };
  }).toList();

  return {'v': 1, 'vaultId': vaultId, 'total': active.length, 'items': items};
}
