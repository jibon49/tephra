// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

import '../../l10n/app_localizations.dart';
import '../model/sticky_frontmatter.dart';
import '../model/sticky_meta.dart';
import '../providers.dart';
import 'sticky_color_picker.dart';
import 'sticky_expiry_dialog.dart';
import 'sticky_reminder_dialog.dart';

/// A 32dp header strip displayed above the note editor or reading view
/// when the active note is a sticky note.
class StickyNoteBanner extends ConsumerWidget {
  const StickyNoteBanner({super.key, required this.path});

  final VaultPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickies = ref.watch(stickiesProvider);
    final sticky = stickies.all.where((s) => s.path == path).firstOrNull;

    if (sticky == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meta = sticky.meta;
    final repo = ref.read(stickyRepositoryProvider);

    return Container(
      key: const ValueKey('sticky.banner'),
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color(meta.color.argb).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(meta.color.argb).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colour dot
          Tooltip(
            message: l10n.stickyCommandSetColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final picked = await showStickyColorPicker(
                  context,
                  initialColor: meta.color,
                );
                if (picked != null) {
                  await repo.patch(path, StickyPatch(color: picked));
                }
              },
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Color(meta.color.argb),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Lock toggle
          Tooltip(
            message: meta.locked
                ? l10n.stickyBannerLocked
                : l10n.stickyBannerUnlocked,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await repo.patch(path, StickyPatch(locked: !meta.locked));
              },
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  meta.locked ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: meta.locked
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Reminder chip
          Tooltip(
            message: l10n.stickyCommandSetReminder,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final result = await showStickyReminderDialog(
                  context,
                  initialValue: meta.remind,
                );
                if (result != null) {
                  await repo.patch(path, StickyPatch(remind: result));
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    meta.remind != null
                        ? Icons.alarm_on
                        : Icons.alarm_add_outlined,
                    size: 15,
                    color: meta.remind != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  if (meta.remind != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      meta.remind!.format().replaceFirst('T', ' '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Expiry chip
          Tooltip(
            message: l10n.stickyCommandSetExpiry,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final result = await showDialog<Optional<LocalDate>>(
                  context: context,
                  builder: (ctx) =>
                      StickyExpiryDialog(initialValue: meta.expire),
                );
                if (result != null) {
                  await repo.patch(path, StickyPatch(expire: result));
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    meta.expire != null
                        ? Icons.event_available
                        : Icons.event_outlined,
                    size: 15,
                    color: meta.expire != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  if (meta.expire != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      meta.expire!.format(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
