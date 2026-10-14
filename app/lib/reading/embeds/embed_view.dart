// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../../links/providers.dart';
import '../reading_images.dart' show fileStatProvider;
import 'file_chip.dart';
import 'image_embed.dart';
import 'note_embed.dart';

/// Top-level dispatcher for embedded content (`![[...]]` or `![](...)`).
class EmbedView extends ConsumerWidget {
  const EmbedView({
    super.key,
    required this.target,
    required this.from,
    this.heading,
    this.blockRef,
    this.size,
    this.alt,
    this.isExternal = false,
    this.externalUrl,
  });

  factory EmbedView.wiki({
    Key? key,
    required MdWikiLink node,
    required VaultPath from,
  }) {
    return EmbedView(
      key: key,
      target: node.target,
      from: from,
      heading: node.heading,
      blockRef: node.blockRef,
      size: node.size,
      alt: node.alias,
    );
  }

  factory EmbedView.markdown({
    Key? key,
    required String url,
    required String alt,
    required VaultPath from,
  }) {
    final isHttp = url.startsWith('http://') || url.startsWith('https://');
    if (isHttp) {
      final (size, cleanAlt) = _parseAltSize(alt);
      return EmbedView(
        key: key,
        target: url,
        from: from,
        alt: cleanAlt,
        size: size,
        isExternal: true,
        externalUrl: url,
      );
    }

    final decoded = Uri.decodeComponent(url);
    final hashIndex = decoded.indexOf('#');
    final rawPath = hashIndex != -1 ? decoded.substring(0, hashIndex) : decoded;
    final fragment = hashIndex != -1 ? decoded.substring(hashIndex + 1) : null;

    String? heading;
    String? blockRef;
    if (fragment != null && fragment.isNotEmpty) {
      if (fragment.startsWith('^')) {
        blockRef = fragment.substring(1);
      } else {
        heading = fragment;
      }
    }

    final (size, cleanAlt) = _parseAltSize(alt);

    return EmbedView(
      key: key,
      target: rawPath,
      from: from,
      heading: heading,
      blockRef: blockRef,
      size: size,
      alt: cleanAlt,
    );
  }

  final String target;
  final VaultPath from;
  final String? heading;
  final String? blockRef;
  final EmbedSize? size;
  final String? alt;
  final bool isExternal;
  final String? externalUrl;

  static (EmbedSize?, String) _parseAltSize(String rawAlt) {
    final idx = rawAlt.lastIndexOf('|');
    if (idx != -1) {
      final sizePart = rawAlt.substring(idx + 1).trim();
      final altText = rawAlt.substring(0, idx).trim();
      final xIdx = sizePart.indexOf('x');
      if (xIdx != -1) {
        final w = int.tryParse(sizePart.substring(0, xIdx));
        final h = int.tryParse(sizePart.substring(xIdx + 1));
        if (w != null && h != null) {
          return (EmbedSize(w, h), altText);
        }
      } else {
        final w = int.tryParse(sizePart);
        if (w != null) {
          return (EmbedSize(w), altText);
        }
      }
    }
    return (null, rawAlt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (isExternal && externalUrl != null) {
      Widget netImg = Image.network(
        externalUrl!,
        fit: BoxFit.contain,
        semanticLabel: alt,
        errorBuilder: (context, _, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 16),
              const SizedBox(width: 4),
              Text(
                Uri.tryParse(externalUrl!)?.host ?? externalUrl!,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

      final s = size;
      if (s != null) {
        if (s.height != null) {
          netImg = SizedBox(
            width: s.width.toDouble(),
            height: s.height!.toDouble(),
            child: netImg,
          );
        } else {
          netImg = SizedBox(width: s.width.toDouble(), child: netImg);
        }
      }
      return netImg;
    }

    final targetPath = target;
    final res = ref.watch(linkResolutionProvider((from, targetPath)));

    return res.when(
      data: (resolved) {
        if (resolved == null) {
          final ext = p
              .extension(targetPath)
              .replaceFirst('.', '')
              .toLowerCase();
          final isMarkdownTarget = ext.isEmpty || ext == 'md';

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.embedNotFound(targetPath),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                if (isMarkdownTarget) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(linkNavigatorProvider)
                          .open(
                            from: from,
                            target: targetPath,
                            heading: heading,
                            blockRef: blockRef,
                          );
                    },
                    child: Text(l10n.previewCreate),
                  ),
                ],
              ],
            ),
          );
        }

        final ext = resolved.extension.toLowerCase();
        if (ext == 'md' || ext.isEmpty) {
          return NoteEmbed(
            path: resolved,
            from: from,
            heading: heading,
            blockRef: blockRef,
          );
        }

        if (ImageEmbed.imageExtensions.contains(ext)) {
          return ImageEmbed(
            path: resolved,
            size: size,
            semanticsLabel: alt ?? resolved.name,
          );
        }

        final statAsync = ref.watch(fileStatProvider(resolved));
        final subpath = () {
          if (heading != null && heading!.isNotEmpty) {
            return '#$heading';
          }
          if (blockRef != null && blockRef!.isNotEmpty) {
            return '#^$blockRef';
          }
          return null;
        }();

        return FileChip(
          path: resolved,
          subpath: subpath,
          sizeBytes: statAsync.value?.size,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          l10n.embedNotFound(targetPath),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
