// © 2026 Tephra. All rights reserved.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_markdown/tephra_markdown.dart';
import 'package:tephra_vault/tephra_vault.dart';

import '../l10n/app_localizations.dart';
import '../vault/providers.dart';
import 'file_chip.dart';
import 'link_actions.dart';
import 'reading_scope.dart';
import 'simple_link_resolver.dart';

final fileStatProvider = FutureProvider.family<VaultEntry?, VaultPath>((
  ref,
  path,
) {
  final fs = ref.watch(vaultFsProvider);
  return fs.stat(path);
});

class _ImageCacheEntry {
  _ImageCacheEntry(this.bytes, this.size);
  final Uint8List bytes;
  final int size;
}

final Map<String, _ImageCacheEntry> _memoryImageCache = {};
int _currentImageCacheSize = 0;
const int _maxImageCacheSize = 30 * 1024 * 1024;
const int _maxCacheEntries = 20;

final readingImageBytesProvider = FutureProvider.family<Uint8List?, VaultPath>((
  ref,
  path,
) async {
  final fs = ref.watch(vaultFsProvider);
  final stat = await fs.stat(path);
  final mod = stat?.modified.millisecondsSinceEpoch ?? 0;
  final cacheKey = '${path.value}:$mod';

  final cached = _memoryImageCache[cacheKey];
  if (cached != null) {
    return cached.bytes;
  }

  try {
    final bytesList = await fs.readBytes(path);
    final bytes = bytesList is Uint8List
        ? bytesList
        : Uint8List.fromList(bytesList);

    if (_memoryImageCache.containsKey(cacheKey)) {
      _currentImageCacheSize -= _memoryImageCache[cacheKey]!.size;
    }
    while (_memoryImageCache.length >= _maxCacheEntries ||
        (_currentImageCacheSize + bytes.lengthInBytes > _maxImageCacheSize &&
            _memoryImageCache.isNotEmpty)) {
      final oldestKey = _memoryImageCache.keys.first;
      _currentImageCacheSize -= _memoryImageCache.remove(oldestKey)!.size;
    }
    _memoryImageCache[cacheKey] = _ImageCacheEntry(bytes, bytes.lengthInBytes);
    _currentImageCacheSize += bytes.lengthInBytes;

    return bytes;
  } catch (_) {
    return null;
  }
});

/// Displays a placeholder box for note embeds.
class EmbeddedNoteBox extends StatelessWidget {
  const EmbeddedNoteBox({super.key, required this.target, this.onTap});

  final String target;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📄', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              target,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an in-vault image from decoded bytes.
class VaultImageView extends ConsumerWidget {
  const VaultImageView({
    super.key,
    required this.path,
    this.size,
    this.semanticsLabel,
  });

  final VaultPath path;
  final EmbedSize? size;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBytes = ref.watch(readingImageBytesProvider(path));

    return asyncBytes.when(
      data: (bytes) {
        if (bytes == null) {
          return FileChip(path: path);
        }

        final dpr = MediaQuery.devicePixelRatioOf(context);
        final maxWidth = MediaQuery.sizeOf(context).width;
        final cacheWidth = (min(maxWidth, 1600.0) * dpr).round();

        Widget img = Image.memory(
          bytes,
          cacheWidth: cacheWidth,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          semanticLabel: semanticsLabel,
          errorBuilder: (_, _, _) => FileChip(path: path),
        );

        if (size != null) {
          img = SizedBox(
            width: size!.width.toDouble(),
            height: size!.height?.toDouble(),
            child: img,
          );
        }

        return img;
      },
      loading: () => const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => FileChip(path: path),
    );
  }
}

/// Renders Markdown inline image links: `![alt](url)`.
class ReadingMarkdownImage extends ConsumerWidget {
  const ReadingMarkdownImage({
    super.key,
    required this.url,
    required this.alt,
    required this.from,
  });

  final String url;
  final String alt;
  final VaultPath from;

  static (EmbedSize?, String) parseAltSize(String rawAlt) {
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
    final (size, cleanAlt) = parseAltSize(alt);

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? url;

      Widget networkImg = Image.network(
        url,
        fit: BoxFit.contain,
        semanticLabel: cleanAlt,
        errorBuilder: (context, _, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, size: 16),
                const SizedBox(width: 4),
                Text(host, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      );

      if (size != null) {
        networkImg = SizedBox(
          width: size.width.toDouble(),
          height: size.height?.toDouble(),
          child: networkImg,
        );
      }
      return networkImg;
    }

    final decoded = Uri.decodeComponent(url);
    final filesAsync = ref.watch(vaultFilesProvider);

    return filesAsync.maybeWhen(
      data: (files) {
        VaultPath? resolved;
        if (from.parent != null) {
          final relPath = from.parent!.join(decoded);
          if (files.contains(relPath)) {
            resolved = relPath;
          }
        }
        resolved ??= const SimpleLinkResolver().resolve(
          decoded,
          from: from,
          files: files,
        );

        if (resolved == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.imageNotFound(decoded),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return VaultImageView(
          path: resolved,
          size: size,
          semanticsLabel: cleanAlt,
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Renders WikiLink embeds: `![[target]]`.
class ReadingWikiEmbed extends ConsumerWidget {
  const ReadingWikiEmbed({super.key, required this.node, required this.from});

  final MdWikiLink node;
  final VaultPath from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ReadingScope.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final filesAsync = ref.watch(vaultFilesProvider);

    return filesAsync.maybeWhen(
      data: (files) {
        final resolved = const SimpleLinkResolver().resolve(
          node.target,
          from: from,
          files: files,
        );

        if (resolved == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.embedNotFound(node.target),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final ext = resolved.extension;
        const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

        if (imageExtensions.contains(ext)) {
          return VaultImageView(
            path: resolved,
            size: node.size,
            semanticsLabel: node.alias ?? resolved.name,
          );
        }

        if (resolved.isMarkdown || ext.isEmpty) {
          return EmbeddedNoteBox(
            target: node.alias ?? resolved.stem,
            onTap: () {
              scope?.onOpenWikiLink?.call(
                WikiLinkTap(
                  target: resolved.value,
                  heading: node.heading,
                  blockRef: node.blockRef,
                ),
              );
            },
          );
        }

        final statAsync = ref.watch(fileStatProvider(resolved));
        final sizeBytes = statAsync.value?.size;

        return FileChip(
          path: resolved,
          sizeBytes: sizeBytes,
          onTap: () {
            LinkActions(
              ref: ref,
              context: context,
              from: from,
            ).openResolvedFile(resolved);
          },
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
