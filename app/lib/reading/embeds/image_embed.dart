// © 2026 Tephra. All rights reserved.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../vault/providers.dart';
import 'file_chip.dart';

/// Renders embedded image files using [Image.file].
class ImageEmbed extends ConsumerWidget {
  const ImageEmbed({
    super.key,
    required this.path,
    this.size,
    this.semanticsLabel,
  });

  final VaultPath path;
  final EmbedSize? size;
  final String? semanticsLabel;

  static const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = path.extension.toLowerCase();
    if (!imageExtensions.contains(ext)) {
      return FileChip(path: path);
    }

    final session = ref.watch(vaultSessionProvider);
    final absPath = session != null
        ? p.join(session.rootDir, path.value)
        : path.value;
    final file = File(absPath);

    Widget buildImage({
      double? width,
      double? height,
      BoxFit fit = BoxFit.contain,
    }) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticsLabel,
        errorBuilder: (_, _, _) => FileChip(path: path),
      );
    }

    final s = size;
    if (s != null) {
      if (s.height != null) {
        return SizedBox(
          width: s.width.toDouble(),
          height: s.height!.toDouble(),
          child: buildImage(fit: BoxFit.contain),
        );
      } else {
        return buildImage(width: s.width.toDouble(), fit: BoxFit.contain);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: buildImage(fit: BoxFit.contain),
        );
      },
    );
  }
}
