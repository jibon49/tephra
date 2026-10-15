// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../../reading/embeds/embed_view.dart';
import 'lp_widget_host.dart';

/// An inline embed/image widget for Live Preview.
class LpEmbedWidget extends StatelessWidget {
  const LpEmbedWidget({
    super.key,
    required this.start,
    required this.end,
    required this.data,
    required this.host,
  });

  final int start;
  final int end;
  final Map<String, Object?> data;
  final LpWidgetHost host;

  @override
  Widget build(BuildContext context) {
    final fromPath = host.path ?? VaultPath('note.md');
    final rawTarget =
        (data['target'] as String?) ?? (data['url'] as String?) ?? '';
    final isExternal =
        rawTarget.startsWith('http://') || rawTarget.startsWith('https://');

    EmbedSize? embedSize;
    final rawSize = data['size'];
    if (rawSize is String && rawSize.isNotEmpty) {
      final parts = rawSize.split('x');
      final w = int.tryParse(parts[0]);
      if (w != null) {
        final h = parts.length > 1 ? int.tryParse(parts[1]) : null;
        embedSize = EmbedSize(w, h);
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => host.selectOffset(start),
      child: EmbedView(
        target: rawTarget,
        from: fromPath,
        heading: data['heading'] as String?,
        blockRef: data['blockRef'] as String?,
        size: embedSize,
        alt: data['alt'] as String?,
        isExternal: isExternal,
        externalUrl: isExternal ? rawTarget : null,
      ),
    );
  }
}
