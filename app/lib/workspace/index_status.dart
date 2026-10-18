// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_index/tephra_index.dart';

import '../core/providers.dart';
import '../l10n/app_localizations.dart';

/// Desktop status bar item showing active index operations and progress.
class IndexStatusItem extends ConsumerWidget {
  const IndexStatusItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(indexProgressProvider);
    final progress = progressAsync.value;
    if (progress == null ||
        progress.phase == IndexPhase.idle ||
        progress.phase == IndexPhase.done) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final String text;
    switch (progress.phase) {
      case IndexPhase.scanning:
        text = l10n.indexStatusScanning;
      case IndexPhase.indexing:
        text = l10n.indexStatusIndexing(progress.done, progress.total);
      case IndexPhase.resolving:
        text = l10n.indexStatusResolving;
      case IndexPhase.idle:
      case IndexPhase.done:
        return const SizedBox.shrink();
    }

    return Row(
      key: const Key('desktop.index_status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            value: progress.phase == IndexPhase.indexing && progress.total > 0
                ? (progress.done / progress.total).clamp(0.0, 1.0)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}

/// Phone layout 2 dp progress bar placed directly under the app bar.
class PhoneIndexProgressBar extends ConsumerWidget
    implements PreferredSizeWidget {
  const PhoneIndexProgressBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(indexProgressProvider);
    final progress = progressAsync.value;
    if (progress == null ||
        progress.phase == IndexPhase.idle ||
        progress.phase == IndexPhase.done) {
      return const SizedBox.shrink();
    }

    final double? value;
    if (progress.phase == IndexPhase.indexing && progress.total > 0) {
      value = (progress.done / progress.total).clamp(0.0, 1.0);
    } else {
      value = null; // indeterminate
    }

    return SizedBox(
      key: const Key('phone.index_progress'),
      height: 2,
      child: LinearProgressIndicator(value: value, minHeight: 2),
    );
  }
}
