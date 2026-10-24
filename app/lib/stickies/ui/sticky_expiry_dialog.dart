// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../model/sticky_frontmatter.dart';
import '../model/sticky_meta.dart';

/// Shows a date picker dialog to set, change, or remove a sticky note expiry date.
Future<Optional<LocalDate>?> showStickyExpiryDialog(
  BuildContext context, {
  LocalDate? initialValue,
  DateTime? now,
}) async {
  final currentNow = now ?? DateTime.now();
  final l10n = AppLocalizations.of(context);

  final initialDate = initialValue != null
      ? DateTime(initialValue.year, initialValue.month, initialValue.day)
      : currentNow;

  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: currentNow.subtract(const Duration(days: 365)),
    lastDate: currentNow.add(const Duration(days: 3650)),
    helpText: l10n.stickyExpiryTitle,
  );

  if (picked != null) {
    return Optional.of(LocalDate(picked.year, picked.month, picked.day));
  }

  return null;
}

/// Dialog allowing explicit selection or removal of a sticky note's expiry date.
class StickyExpiryDialog extends StatelessWidget {
  const StickyExpiryDialog({super.key, this.initialValue, this.now});

  final LocalDate? initialValue;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentNow = now ?? DateTime.now();

    return AlertDialog(
      title: Text(l10n.stickyExpiryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(
              initialValue != null
                  ? initialValue!.format()
                  : l10n.stickyExpiryTitle,
            ),
            subtitle: Text(l10n.propertyTypeDate),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final initialDate = initialValue != null
                  ? DateTime(
                      initialValue!.year,
                      initialValue!.month,
                      initialValue!.day,
                    )
                  : currentNow;

              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: currentNow.subtract(const Duration(days: 365)),
                lastDate: currentNow.add(const Duration(days: 3650)),
              );

              if (picked != null && context.mounted) {
                Navigator.of(context).pop(
                  Optional.of(LocalDate(picked.year, picked.month, picked.day)),
                );
              }
            },
          ),
          if (initialValue != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                l10n.stickyExpiryRemove,
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop(const Optional<LocalDate>.none());
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
