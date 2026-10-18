// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';
import 'package:tephra_index/tephra_index.dart';
import 'package:tephra_markdown/tephra_markdown.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../vault/providers.dart';
import '../providers.dart';
import '../reading_blocks.dart';
import '../reading_scope.dart';
import '../reading_styles.dart';
import 'embed_context.dart';
import 'embed_slice.dart';

/// Provider for raw text of a note to embed, prioritizing open editor buffers
/// and invalidated on index change events.
final embedTextProvider = FutureProvider.family<String?, VaultPath>((
  ref,
  path,
) async {
  // Invalidate if index emits change for this path
  ref.listen<AsyncValue<IndexEvent>>(indexChangesProvider, (prev, next) {
    if (next.hasValue &&
        (next.value!.fullRebuild || next.value!.changedPaths.contains(path))) {
      ref.invalidateSelf();
    }
  });

  // Check open buffer
  final store = ref.watch(noteDocumentStoreProvider);
  final doc = store.peek(path);
  if (doc != null) {
    void onDocChanged() {
      ref.invalidateSelf();
    }

    doc.addListener(onDocChanged);
    ref.onDispose(() => doc.removeListener(onDocChanged));
    return doc.text;
  }

  // Read from filesystem
  final fs = ref.watch(vaultFsProvider);
  try {
    final doc = await fs.readText(path);
    return doc.text;
  } catch (_) {
    return null;
  }
});

sealed class EmbedContentResult {
  const EmbedContentResult();
}

final class EmbedNotFoundResult extends EmbedContentResult {
  const EmbedNotFoundResult();
}

final class EmbedSectionNotFoundResult extends EmbedContentResult {
  const EmbedSectionNotFoundResult();
}

final class EmbedSuccessResult extends EmbedContentResult {
  const EmbedSuccessResult(this.parsed, this.sliceText);
  final ParsedNote parsed;
  final String sliceText;
}

final embedParsedSliceProvider =
    FutureProvider.family<
      EmbedContentResult,
      ({VaultPath path, String? heading, String? blockRef})
    >((ref, arg) async {
      final text = await ref.watch(embedTextProvider(arg.path).future);
      if (text == null) {
        return const EmbedNotFoundResult();
      }

      final parseService = ref.watch(parseServiceProvider);
      final fullParsed = await parseService.parse(text);
      final slice = sliceForEmbed(
        text,
        fullParsed,
        heading: arg.heading,
        blockRef: arg.blockRef,
      );
      if (slice == null) {
        return const EmbedSectionNotFoundResult();
      }

      final sliceText = slice.substringOf(text);
      final sliceParsed = await parseService.parse(sliceText);
      return EmbedSuccessResult(sliceParsed, sliceText);
    });

/// Renders embedded Markdown notes or sections with recursion guards.
class NoteEmbed extends ConsumerWidget {
  const NoteEmbed({
    super.key,
    required this.path,
    required this.from,
    this.heading,
    this.blockRef,
  });

  final VaultPath path;
  final VaultPath from;
  final String? heading;
  final String? blockRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final embedCtx = EmbedContext.maybeOf(context);
    final depth = embedCtx?.depth ?? 0;
    final chain = embedCtx?.chain ?? const <VaultPath>{};

    if (depth >= 5) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.embedTooDeep,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (chain.contains(path)) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Text(
              l10n.embedCircular,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final asyncResult = ref.watch(
      embedParsedSliceProvider((
        path: path,
        heading: heading,
        blockRef: blockRef,
      )),
    );

    return asyncResult.when(
      data: (result) {
        switch (result) {
          case EmbedNotFoundResult():
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                l10n.embedNotFound(path.value),
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            );

          case EmbedSectionNotFoundResult():
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.embedSectionNotFound,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );

          case EmbedSuccessResult(:final parsed, :final sliceText):
            final headerTitle = () {
              if (heading != null && heading!.isNotEmpty) {
                return '${path.stem} > $heading';
              }
              if (blockRef != null && blockRef!.isNotEmpty) {
                return '${path.stem} > ^$blockRef';
              }
              return path.stem;
            }();

            final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16.0;
            final styles = ReadingStyles.of(theme, fontSize);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      ref
                          .read(linkNavigatorProvider)
                          .open(
                            from: from,
                            target: path.value,
                            heading: heading,
                            blockRef: blockRef,
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              headerTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  EmbedContext(
                    depth: depth + 1,
                    chain: {...chain, path},
                    child: ReadingScope(
                      path: path,
                      parsed: parsed,
                      text: sliceText,
                      styles: styles,
                      footnoteNumbers: const {},
                      readOnly: true,
                      toggledCallouts: const {},
                      onOpenWikiLink: (tap) {
                        ref
                            .read(linkNavigatorProvider)
                            .open(
                              from: path,
                              target: tap.target,
                              heading: tap.heading,
                              blockRef: tap.blockRef,
                              newTab: tap.newTab,
                            );
                      },
                      child: buildBlock(context, parsed.root),
                    ),
                  ),
                ],
              ),
            );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          l10n.embedNotFound(path.value),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
